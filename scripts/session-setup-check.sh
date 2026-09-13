#!/usr/bin/env bash
#
# session-setup-check.sh - SessionStart hook logic: warn once per session about two things this
# repository cannot otherwise keep honest -
#   1. machine-local setup is incomplete, so a missing pre-commit registration is noticed at the
#      start of a session rather than discovered after a push;
#   2. the periodic health check is overdue, or its last run left findings nobody acted on.
# The two are independent: either can fire alone, and when both fire the messages compose.
#
# WHY THE HEALTH-CHECK NUDGE LIVES HERE: scripts/health-check.sh is deliberately manual and
# deliberately slow (16 s full, 5.6 s --quick against this hook's own 0.02 s), and its findings are
# the wrong thing to inject into an unrelated session's context every time one starts. But a manual
# check on a weekly-to-monthly cadence is only as good as someone's memory of it. A date comparison
# against the marker health-check.sh leaves behind costs one stat and reaches both the user and
# Claude, which is the smallest thing that makes the cadence real without putting the check itself
# on a hook path. The nudge says a run is due; it never runs one.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md this file may be model-generated and is
# reviewed in full before commit; its registration in settings.json was made at the repository
# owner's explicit, in-the-moment direction.
#
# WHY THIS EXISTS: hook registrations are untracked local state that no tracked artifact can vouch
# for, so a registration going missing - a hook file deleted, a fresh clone that has not run
# setup.sh - is invisible to everything except a check that actually runs. Better install
# instructions cannot catch that; only a runtime check can. See specs/behaviors.md's Machine Setup
# section.
#
# WHY SessionStart RATHER THAN THE STATUS LINE: setup state changes perhaps twice a year, where the
# status line re-renders continuously - checking there would need a caching layer to stay off a hot
# path, and would have a fraction of one shared line to explain itself in. SessionStart runs once,
# can carry a full actionable sentence, and is the only one of the two whose output can reach Claude
# as well as the user (see the output contract below).
#
# OUTPUT CONTRACT (code.claude.com/docs/en/hooks, confirmed 2026-08-21): for SessionStart, plain
# stdout is added to CLAUDE's CONTEXT and is NOT shown to the user - so a bare echo here would be
# invisible to the person who needs to act on it. Reaching the user requires a TOP-LEVEL
# systemMessage field, which renders in the transcript; additionalContext is the field Claude sees
# and it lives inside hookSpecificOutput. The two sit at different levels, and nesting systemMessage
# inside hookSpecificOutput is silently ignored rather than rejected, not flagged as an error - so a
# session can easily end up with Claude warned and the user not, or the reverse, with nothing to
# say so. This emits both: the user learns the gate is off, and Claude learns not to imply a
# commit was checked when it was not. SessionStart cannot block, and its exit code is ignored for
# control purposes, so this always exits 0 - it is advisory, and the pre-commit hook remains the
# actual gate.
#
# Silent unless something is wrong, matching md-checks.sh's convention: a hook that prints on every
# healthy session start trains its reader to ignore it. That applies to the staleness nudge too: a
# check run within the window says nothing, and an unparseable or unwritable marker degrades to
# silence rather than to a nag nobody can clear.
#
# TWO REGISTRATIONS, ONE SCRIPT: settings.json registers this twice, with different matchers.
#   matcher "startup|resume"  -> no argument. The full warning: systemMessage for the user plus
#                                additionalContext for Claude. A resume can be days later on a
#                                machine whose clone was replaced or whose .git/hooks were wiped,
#                                so it is a real session start from the reader's point of view.
#   matcher "clear|compact"   -> --context-only. Re-injects additionalContext WITHOUT systemMessage.
#                                /clear and compaction both destroy Claude's copy of the warning,
#                                which is how a session ends up cheerfully reporting a commit as
#                                checked when the gate never ran - the same survive-compaction
#                                concern behind decisions/0006 and CLAUDE.md's canary. The user,
#                                though, saw the message minutes ago in the same terminal;
#                                re-showing it is the nagging that teaches people to ignore hooks.
#   matcher "fork"            -> deliberately unregistered. A fork inherits context, so the note is
#                                already present and there is nothing to restore.
#
# The mode is a command-line argument rather than something sniffed from the payload on purpose:
# Anthropic's documented SessionStart input fields (session_id, transcript_path, cwd,
# permission_mode, hook_event_name, model) do not include one carrying which of the five start
# types occurred, so branching on a guessed field name would be a silent single point of failure.
# The matcher already knows; let the registration say so out loud.
#
# Usage: session-setup-check.sh [--context-only]
#   Reads the SessionStart JSON payload on stdin; needs no fields beyond cwd, and degrades to
#   running anyway if that is absent.
#   --context-only  Emit additionalContext but no systemMessage: tell Claude, do not re-notify the
#                   user. Emits nothing at all when there is nothing to report, exactly as the
#                   default does.

set -uo pipefail

context_only=0
for arg in "$@"; do
  case "$arg" in
    --context-only) context_only=1 ;;
    # A SessionStart hook must never be the reason a session fails to start, so an unrecognized
    # argument is reported and ignored rather than treated as fatal.
    *) printf 'session-setup-check: ignoring unknown argument: %s\n' "$arg" >&2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 2>/dev/null || exit 0

# A replicated CLAUDE_CONFIG_DIR profile receives a copy of scripts/ but has no repository to check
# (see CLAUDE.md's Repository Maintenance heading). Staying silent there is the whole point.
[[ -d "$REPO_ROOT/.git" ]] || exit 0
[[ -x "$REPO_ROOT/scripts/setup.sh" ]] || exit 0

payload=""
if [[ ! -t 0 ]]; then
  payload="$(cat 2>/dev/null || true)"
fi

# Only speak up when the session is actually working in this repository. The hook is registered at
# user scope, so it fires in every project on this machine; a warning about ~/.claude's git hooks
# is noise in an unrelated codebase, and this repo cannot be committed to from outside it anyway.
session_cwd=""
if [[ -n "$payload" ]]; then
  if command -v jq >/dev/null 2>&1; then
    session_cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
  else
    session_cwd="$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  fi
fi
[[ -n "$session_cwd" ]] || session_cwd="$PWD"

# Resolve both sides before comparing: a symlinked or /private-prefixed path would otherwise fail a
# plain prefix test and silence the hook exactly where it is wanted.
resolve() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s' "$1"; }
real_cwd="$(resolve "$session_cwd")"
real_root="$(resolve "$REPO_ROOT")"
case "$real_cwd" in
  "$real_root"|"$real_root"/*) ;;
  *) exit 0 ;;
esac

sys_msg=""
ctx=""
# Both conditions append to one message rather than each emitting their own: SessionStart gets one
# systemMessage and one additionalContext, so a second condition has to compose, not overwrite.
add() { sys_msg="${sys_msg:+$sys_msg }$1"; ctx="${ctx:+$ctx }$2"; }

# --- Condition 1: machine-local setup -----------------------------------------------------------
report="$("$REPO_ROOT/scripts/setup.sh" --check 2>&1)"
if [[ $? -ne 0 ]]; then
  # Reduce the report to the actionable lines. These are this repo's own strings - no double quotes
  # or backslashes - but escape anyway rather than trusting that to stay true.
  items="$(printf '%s\n' "$report" \
    | grep -E '^\s*\[(MISSING|warn)\]' \
    | sed -E 's/^[[:space:]]*\[(MISSING|warn)\][[:space:]]*//' \
    | sed -E 's/[[:space:]]+\(.*\)$//' \
    | awk 'NF' | awk '!seen[$0]++' \
    | awk '{ out = (NR == 1 ? $0 : out "; " $0) } END { print out }' 2>/dev/null || true)"
  [[ -n "$items" ]] || items="see scripts/setup.sh --check"

  add "Config repo setup incomplete: ${items}. Run scripts/setup.sh (or --check for detail)." \
      "The user's ~/.claude config repository has incomplete machine-local setup: ${items}. \
The pre-commit gate (settings.json validity, projection drift, and scrub-check for content \
unsuited to a public remote) may therefore not run on commit. Do not state or imply that a commit \
to this repository was checked by those hooks unless you have verified the registration exists. \
Registering hooks is the owner's explicit act - suggest they run scripts/setup.sh themselves \
rather than running it for them."
fi

# --- Condition 2: health-check staleness or unaddressed findings --------------------------------
# scripts/health-check.sh writes date=, commit=, and findings= here on a full run; --quick
# deliberately does not write at all.
readonly HEALTH_STALE_DAYS=7
# An idle tree earns a longer leash, never silence. HEAD alone does not determine what the check
# finds - scrub-patterns.local, .git/hooks/, settings.local.json, on-disk permission
# bits, and the working-tree diff all feed checks there and none is in any commit - so "nothing has
# changed since a clean run" is a reason to nag less often, not a reason to stop. Thirty days bounds
# the worst case at a month rather than at never.
readonly HEALTH_IDLE_DAYS=30
# Findings are not reported the day after the run that found them: a standing nag with no grace
# period is the thing that teaches a reader to skim past this hook. Three days is enough to act.
readonly HEALTH_FINDINGS_GRACE_DAYS=3
readonly STAMP_FILE="$REPO_ROOT/.health-check-stamp"

# Whole days between a YYYY-MM-DD date and today. GNU and BSD date take incompatible flags and this
# repo is pulled onto both; a machine whose date does neither gets no nudge rather than a wrong one.
days_since() {
  local then now
  then="$(date -d "$1" +%s 2>/dev/null)" \
    || then="$(date -j -f %Y-%m-%d "$1" +%s 2>/dev/null)" \
    || return 1
  now="$(date +%s)" || return 1
  printf '%s\n' $(( (now - then) / 86400 ))
}

stamp_field() { sed -n "s/^$1=//p" "$STAMP_FILE" 2>/dev/null | head -1 | tr -d '[:space:]'; }

health_phrase=""
if [[ ! -f "$STAMP_FILE" ]]; then
  health_phrase="has never been run on this machine"
else
  stamp_date="$(stamp_field date)"
  stamp_commit="$(stamp_field commit)"
  stamp_findings="$(stamp_field findings)"
  # An unreadable or malformed marker is not something the reader can act on, so it degrades to
  # silence. The marker is a convenience; it is never a gate.
  case "$stamp_date" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      if days="$(days_since "$stamp_date")"; then
        # How far has the tree moved? An unknown or unreachable commit (rebased away, or a stamp
        # written outside a resolvable HEAD) means we cannot claim it is idle, so it is not.
        moved=1
        commits=""
        if [[ -n "$stamp_commit" ]] && git -C "$REPO_ROOT" cat-file -e "${stamp_commit}^{commit}" 2>/dev/null; then
          commits="$(git -C "$REPO_ROOT" rev-list --count "${stamp_commit}..HEAD" 2>/dev/null)"
          # Anything git reports as dirty counts as movement, untracked files included - the
          # conservative direction, nudging more often rather than less. Note that .gitignore's
          # leading /* means a stray file at the repository root is ignored and so does not count;
          # that is the same rule that keeps .health-check-stamp itself out of the way.
          if [[ "$commits" == "0" ]] && [[ -z "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
            moved=0
          fi
        fi

        # Unaddressed findings from the last run, past the grace period. Independent of age: five
        # findings left on the floor are still there whether or not anything has been committed.
        findings_due=0
        case "$stamp_findings" in
          ''|0|*[!0-9]*) ;;
          *) (( days >= HEALTH_FINDINGS_GRACE_DAYS )) && findings_due=1 ;;
        esac

        # The idle extension applies only to a clean run: if the last run found something, "nothing
        # has changed since" is an argument that the findings are still there, not that they are not.
        threshold=$HEALTH_STALE_DAYS
        if (( moved == 0 )) && [[ "$stamp_findings" == "0" ]]; then
          threshold=$HEALTH_IDLE_DAYS
        fi
        overdue=0
        (( days > threshold )) && overdue=1

        if (( overdue || findings_due )); then
          health_phrase="was last run ${days} days ago (${stamp_date})"
          if [[ -n "$commits" ]] && [[ "$commits" != "0" ]]; then
            health_phrase="${health_phrase}, ${commits} commit$( (( commits == 1 )) || printf s ) back"
          elif (( moved == 0 )); then
            health_phrase="${health_phrase}, with the tree unchanged since"
          fi
          if (( findings_due )); then
            health_phrase="${health_phrase}, and left ${stamp_findings} finding$( (( stamp_findings == 1 )) || printf s ) unaddressed"
          fi
        fi
      fi
      ;;
  esac
fi

if [[ -n "$health_phrase" ]]; then
  add "Config health check ${health_phrase} - a run is due. Run scripts/health-check.sh, or ask for the health-check skill for the full review." \
      "The user's ~/.claude config repository health check ${health_phrase}. The cadence threshold \
is ${HEALTH_STALE_DAYS} days, stretched to ${HEALTH_IDLE_DAYS} when the tree has not moved since a \
clean run. Mention this if the session touches that repository. Do NOT run scripts/health-check.sh \
or invoke the health-check skill unprompted - it is a slow full-tree pass whose findings would \
flood an unrelated session's context. Wait to be asked."
fi

[[ -n "$sys_msg" ]] || exit 0

json_escape() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' \
    | awk '{ printf "%s\\n", $0 }' \
    | sed 's/\\n$//'
}

if [[ "$context_only" -eq 1 ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$(json_escape "$ctx")"
else
  # systemMessage is a top-level field, NOT a member of hookSpecificOutput - see the output contract
  # above. Nested, it is dropped without a word and only Claude ever hears about the problem.
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$(json_escape "$sys_msg")" "$(json_escape "$ctx")"
fi

exit 0
