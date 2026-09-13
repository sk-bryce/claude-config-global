#!/usr/bin/env bash
#
# md-deferred-checks.sh - end-of-agent-loop driver for the deferred Markdown checks. Drains the
# ledger that scripts/md-ledger-append.sh built during the turn and runs markdownlint-hook.sh,
# md-checks.sh, and link-recheck-hook.sh once per distinct file instead of once per edit.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it
# (settings.json's Stop entry) is a separate human step.
#
# Usage: md-deferred-checks.sh [claude|cursor]
#   Reads the stop-event hook JSON on stdin. Selects the session-key field name with the first
#   positional argument, falling back to the MD_HOOK_HARNESS env var, and defaulting to "claude"
#   when neither is set or the value is unrecognized - the same convention as
#   scripts/filter-verbose-output.sh. See
#   ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/cursor-projection/SKILL.md for what generates and
#   consumes the "cursor" form. Per skills/cursor-projection/references/harness-matrix.md's Hooks
#   section:
#     claude  Stop  session .session_id
#     cursor  stop  session .conversation_id
#   No-ops when jq is absent or the ledger for this session is empty or missing.
#
# Scope note: both harnesses' stop events fire at the end of every agent loop, not once per
# session, so a file edited across three turns is still checked three times - once per turn, rather
# than once per file-edit call. That is the intended tradeoff: it bounds the cost by turn instead of
# by edit, and keeps a file's checks current after each turn that changed it.
#
# This script only reports and reformats; it never blocks the turn and never exits non-zero, so a
# caller can safely ignore its exit code (kept 0 in every path as a second guard). Deliberately
# not `set -e`: one file's failing check must not skip the remaining files.

set -uo pipefail

harness="${1:-${MD_HOOK_HARNESS:-claude}}"
case "$harness" in
  claude|cursor) ;;
  *) harness="claude" ;;
esac

case "$harness" in
  claude) session_filter='.session_id // empty' ;;
  cursor) session_filter='.conversation_id // empty' ;;
esac

command -v jq >/dev/null 2>&1 || exit 0

session="$(jq -r "$session_filter" 2>/dev/null || true)"
session="${session//[^A-Za-z0-9._-]/_}"
[[ -z "$session" ]] && session="no-session"

# Keyed on this script's own on-disk location (not $HOME or $CLAUDE_CONFIG_DIR) so both harnesses
# resolve to the same directory even if the config root moves: Cursor invokes this same script
# file but never sets CLAUDE_CONFIG_DIR (a Claude Code-only variable), so keying on that env var
# would silently split the two harnesses onto different ledger directories after a move. Must
# match md-ledger-append.sh's resolution exactly or a recorded batch would never be drained.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ledger_dir="$(dirname "$script_dir")/cache/md-ledger"
ledger="$ledger_dir/$session.paths"
[[ -f "$ledger" ]] || exit 0

# Claim the batch with a single mv before reading it, so entries appended while the checks run
# (a slow curl can outlast the turn) survive for the next stop event instead of being dropped, and
# a concurrent stop cannot process the same batch twice.
batch="$ledger.batch.$$"
mv "$ledger" "$batch" 2>/dev/null || exit 0

# Resolve siblings by this script's own location rather than a hardcoded path, since the Cursor
# registration invokes the same shared logic through $REPO_ROOT.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Order matters: markdownlint may reformat the file, so md-checks.sh reads it afterwards and reports
# line numbers that match what is now on disk. link-recheck-hook.sh goes last because it is the only
# one that touches the network, and it self-gates on a freshness window, so on most turns it returns
# without making a single call.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ -f "$f" ]] || continue
  "$script_dir/markdownlint-hook.sh" "$f" || true
  "$script_dir/md-checks.sh" "$f" || true
  "$script_dir/link-recheck-hook.sh" "$f" || true
done < <(sort -u "$batch")

rm -f "$batch"

# Prune ledgers left behind by sessions that ended without a stop event (crash, kill), so cache/
# does not accumulate one small file per session forever.
find "$ledger_dir" -maxdepth 1 -type f -name '*.paths*' -mtime +7 -delete 2>/dev/null || true

exit 0
