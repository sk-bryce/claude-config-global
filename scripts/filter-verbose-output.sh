#!/usr/bin/env bash
#
# filter-verbose-output.sh - shared PreToolUse hook logic that rewrites verbose test/build/lint
# commands so only failures reach the agent's context, instead of a full passing run's output.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it
# (settings.json's PreToolUse entry) is a separate, human step. This script does not register
# itself anywhere.
#
# Accepts an optional claude|cursor positional argument selecting the hook response shape (see
# Usage below) and defaults to Claude Code. See
# ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/cursor-projection/SKILL.md for what generates and
# consumes the "cursor" form.
#
# Both harnesses put the command at .tool_input.command on stdin
# (skills/cursor-projection/references/harness-matrix.md, Hooks section: "Pattern: put the real
# logic in scripts/<name>.sh and register it in both places with thin wrappers"). Only the
# RESPONSE shape differs between them:
#   Claude Code wants: {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"<filtered>"}}}
#   Cursor wants:       {"permission":"allow","updated_input":{"command":"<filtered>"}}
# Select the shape with the first positional argument ("claude" or "cursor"), falling back to the
# FILTER_VERBOSE_OUTPUT_SHAPE env var, defaulting to "claude" when neither is set or the value is
# unrecognized. A registered wrapper picks the shape it needs; see
# skills/cursor-projection/references/harness-matrix.md's Hooks section for how the two
# registrations are meant to share this one script.
#
# Usage: filter-verbose-output.sh [claude|cursor]
#   Reads a PreToolUse JSON payload from stdin, prints a PreToolUse JSON response to stdout.
#
# Behavior:
#   - Recognizes command prefixes: go test, go build, npm test, npm run build, pytest, mage,
#     golangci-lint. Anything else is left alone (prints {}, meaning "no rewrite").
#   - Skips (prints {}, no rewrite) any command that already contains a pipe, a redirect, or an
#     explicit filter/pager (grep, tail, tee, less, more) - appending a second filter onto a
#     command the user already piped or redirected would corrupt it rather than help it.
#   - Uses jq for both parsing the input and re-encoding the rewritten command as JSON, so no
#     user-controlled string is ever hand-assembled into a JSON literal.
#   - Fails open on every path: missing jq, unparsable input, or an empty/absent command all
#     print {} and exit 0. A broken filter must never block a tool call. Per Cursor's hooks docs
#     (cited in skills/cursor-projection/references/harness-matrix.md), a malformed hook response
#     on that harness also fails open, so emitting {} (rather than nothing, or invalid JSON) is a
#     deliberate, valid no-op in both harnesses, not a fallback that depends on the fail-open
#     behavior to be safe.
#
set -uo pipefail  # deliberately not -e: any single check failing (e.g. jq missing) must fall
                  # through to the fail-open {} response below, not abort the script unhandled

shape="${1:-${FILTER_VERBOSE_OUTPUT_SHAPE:-claude}}"
case "$shape" in
  claude|cursor) ;;
  *) shape="claude" ;;
esac

emit_no_rewrite() {
  echo '{}'
  exit 0
}

command -v jq >/dev/null 2>&1 || emit_no_rewrite

input="$(cat)"
[[ -z "$input" ]] && emit_no_rewrite

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[[ -z "$cmd" ]] && emit_no_rewrite

# Refuse to touch a command that already redirects or filters its own output - rewriting it again
# would either corrupt the pipeline or double-filter it.
case "$cmd" in
  *'|'*|*'>'*) emit_no_rewrite ;;
esac

# A bare filter/pager with no pipe (e.g. `tail -f app.log`) is also left alone. Matched on word
# boundaries, not as a substring: a substring match would silently disable this filter for any
# command containing one of these words inside a path, e.g. `go test ./retail/...` ("tail") or
# `go test ./internal/detail/...`.
if [[ "$cmd" =~ (^|[[:space:]])(grep|tail|tee|less|more)([[:space:]]|$) ]]; then
  emit_no_rewrite
fi

# Trim leading whitespace only, for prefix matching; the rewrite below still uses $cmd verbatim.
trimmed="${cmd#"${cmd%%[![:space:]]*}"}"

category=""
if [[ "$trimmed" =~ ^go[[:space:]]+test([[:space:]]|$) ]]; then
  category="go_test"
elif [[ "$trimmed" =~ ^go[[:space:]]+build([[:space:]]|$) ]]; then
  category="go_build"
elif [[ "$trimmed" =~ ^npm[[:space:]]+test([[:space:]]|$) ]]; then
  category="npm_test"
elif [[ "$trimmed" =~ ^npm[[:space:]]+run[[:space:]]+build([[:space:]]|$) ]]; then
  category="npm_build"
elif [[ "$trimmed" =~ ^pytest([[:space:]]|$) ]]; then
  category="pytest"
elif [[ "$trimmed" =~ ^mage([[:space:]]|$) ]]; then
  category="mage"
elif [[ "$trimmed" =~ ^golangci-lint([[:space:]]|$) ]]; then
  category="golangci_lint"
fi

[[ -z "$category" ]] && emit_no_rewrite

# Per category: most test/build runners are mostly noise on success, so grep down to failure
# markers with a few lines of trailing context. golangci-lint and a bare `go build` are the
# exception - their entire stdout/stderr already *is* the finding list on failure and is silent
# on success, so grepping would risk dropping real findings; just cap the volume instead.
#
# Every rewrite must re-raise the ORIGINAL command's exit status. If it did not, the pipeline would
# report the status of `head`, which is 0 whether the run passed or failed - so a failing run whose
# output happened not to match the grep pattern would come back silent and successful. That is the
# one failure mode this filter must not have: it would turn a real failure into a reported pass.
#
# The output is therefore captured first, the status saved, and only then filtered. Do NOT "simplify"
# this back to a straight pipeline ending in `exit ${PIPESTATUS[0]}`: PIPESTATUS is a bash builtin
# that zsh does not define at all (zsh spells it `pipestatus` and indexes arrays from 1), and the
# rewritten command runs in whatever shell the harness uses - zsh on this machine. There the
# expansion is empty, `exit` takes the last command's status instead, and the bug above comes back
# silently. The capture-then-filter form below behaves identically in sh, bash, and zsh.
# Tradeoff accepted: output is buffered in the subshell rather than streamed. That costs a variable
# the size of the run's output inside a process that is being spawned to discard it anyway.
# $1 = grep arguments selecting the lines to keep, or empty to keep everything (cap volume only).
# Every $ below is escaped: these expansions must survive into the rewritten command as literal
# text, to be evaluated later by the shell that actually runs it, not by this script.
mk_filter() {
  local capture="out=\$( $cmd 2>&1 ); rc=\$?; printf '%s\n' \"\$out\""
  if [[ -z "$1" ]]; then
    printf '%s' "$capture | head -100; exit \$rc"
  else
    printf '%s' "$capture | grep -E -A5 $1 | head -100; exit \$rc"
  fi
}

# golangci-lint and a bare `go build` keep everything: their entire output already *is* the finding
# list on failure and is silent on success, so grepping them would risk dropping real findings.
case "$category" in
  go_test)       filtered="$(mk_filter "'(FAIL|--- FAIL|panic:|error:)'")" ;;
  go_build)      filtered="$(mk_filter "")" ;;
  npm_test)      filtered="$(mk_filter "-i '(fail|error|✗|not ok)'")" ;;
  npm_build)     filtered="$(mk_filter "-i '(error|failed to compile|✖)'")" ;;
  pytest)        filtered="$(mk_filter "'(FAILED|ERROR|Error|assert)'")" ;;
  mage)          filtered="$(mk_filter "-i '(fail|error|panic:)'")" ;;
  golangci_lint) filtered="$(mk_filter "")" ;;
esac

case "$shape" in
  cursor)
    jq -n --arg cmd "$filtered" '{"permission":"allow","updated_input":{"command":$cmd}}' 2>/dev/null
    ;;
  *)
    jq -n --arg cmd "$filtered" \
      '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":$cmd}}}' \
      2>/dev/null
    ;;
esac

# If jq somehow failed to encode the response (should not happen; it only interpolates one
# string arg), fail open rather than emit nothing or partial output.
[[ $? -ne 0 ]] && echo '{}'

exit 0
