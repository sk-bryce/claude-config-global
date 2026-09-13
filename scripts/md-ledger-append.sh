#!/usr/bin/env bash
#
# md-ledger-append.sh - records that a Markdown file was touched, for the deferred checks that
# scripts/md-deferred-checks.sh runs later when the agent loop ends.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it
# (settings.json's PostToolUse entry) is a separate human step.
#
# WHY THIS EXISTS: markdownlint-hook.sh and link-recheck-hook.sh are expensive to run on every
# file-edit event. link-recheck makes a network call per References link; markdownlint reformats
# the whole file. Paying either cost per edit is the dominant per-edit overhead in a doc-heavy
# session, so this recorder defers that work: it appends the touched path to a per-session ledger,
# and scripts/md-deferred-checks.sh drains the ledger and runs the real checks once, at the end of
# the agent loop. Neither harness's stop-event payload says which files changed, so this recorder
# is the only thing that stays on the file-edit event. It must remain silent and near-free: one jq
# call, one append, no output on any path (stdout here would land in context, which is what this
# avoids).
#
# Usage: md-ledger-append.sh [claude|cursor]
#   Reads the file-edit hook JSON on stdin. Selects the payload field names with the first
#   positional argument, falling back to the MD_HOOK_HARNESS env var, and defaulting to "claude"
#   when neither is set or the value is unrecognized - the same convention as
#   scripts/filter-verbose-output.sh. See
#   ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/cursor-projection/SKILL.md for what generates and
#   consumes the "cursor" form. Per skills/cursor-projection/references/harness-matrix.md's Hooks
#   section the two harnesses disagree on both field names:
#     claude  PostToolUse Write|Edit  path .tool_response.filePath // .tool_input.file_path
#                                     session .session_id
#     cursor  afterFileEdit           path .file_path
#                                     session .conversation_id
#   Silently no-ops when jq is absent, when no file path is present, and for any non-*.md path.
#
# Ledger location: ~/.claude/cache/md-ledger/<session>.paths, one absolute path per line,
# duplicates allowed (md-deferred-checks.sh dedupes). Keyed on this script's own on-disk location
# (see below) rather than $HOME or $CLAUDE_CONFIG_DIR, so both harnesses share one ledger directory
# even if the config root moves. cache/ is git-ignored by this repo's .gitignore whitelist. The
# "no-session" fallback string and the ledger path must stay in sync with md-deferred-checks.sh, or
# a recorded batch would never be drained.

set -euo pipefail

harness="${1:-${MD_HOOK_HARNESS:-claude}}"
case "$harness" in
  claude|cursor) ;;
  *) harness="claude" ;;
esac

case "$harness" in
  claude)
    path_filter='.tool_response.filePath // .tool_input.file_path // empty'
    session_filter='.session_id // empty'
    ;;
  cursor)
    path_filter='.file_path // empty'
    session_filter='.conversation_id // empty'
    ;;
esac

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"

# `|| true` is required, not decorative: under `set -e` a jq parse failure on a malformed payload
# would otherwise abort the assignment and exit non-zero, which the harness surfaces as a hook
# error. A recorder must never fail a tool call it only observes.
path="$(jq -r "$path_filter" <<< "$payload" 2>/dev/null || true)"
[[ -z "$path" ]] && exit 0
case "$path" in
  *.md) ;;
  *) exit 0 ;;
esac

session="$(jq -r "$session_filter" <<< "$payload" 2>/dev/null || true)"
session="${session//[^A-Za-z0-9._-]/_}"
[[ -z "$session" ]] && session="no-session"

# Keyed on this script's own on-disk location (not $HOME or $CLAUDE_CONFIG_DIR) so both harnesses
# resolve to the same directory even if the config root moves; must match md-deferred-checks.sh's
# resolution exactly or a recorded batch would never be drained.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ledger_dir="$(dirname "$script_dir")/cache/md-ledger"
mkdir -p "$ledger_dir"
printf '%s\n' "$path" >> "$ledger_dir/$session.paths"

exit 0
