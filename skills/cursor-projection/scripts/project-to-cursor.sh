#!/usr/bin/env bash
#
# project-to-cursor.sh - projects this repo's Cursor-facing configuration into ~/.cursor/:
# settings.json's hooks -> ~/.cursor/hooks.json, this skill's own statusline-cursor.sh ->
# ~/.cursor/cli-config.json's statusLine key, and the repo's canonical MCP server list ->
# ~/.cursor/mcp.json.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this script's logic may be
# model-generated but is reviewed in full before commit; running --apply performs a hook
# registration (writing ~/.cursor/hooks.json), which is itself a hook-registration act and must
# only be done by a human who has read this file, since a hook activates before any later commit
# review. Run --check first; only run --apply yourself once you've read this file.
#
# This script writes OUTSIDE the repo (~/.cursor/), so unlike a typical in-repo sync script it
# never defaults to writing: with no arguments, or any argument it doesn't recognize, it prints
# usage and exits without touching anything. --apply is the deliberate, documented step that
# performs the human hook-registration act described above.
#
# Self-contained: this script does not source or call anything under the repo's scripts/. It
# lives inside this skill and must work when the skill is the only thing a reader has. It does
# reference a few repo-root paths by name (settings.json's hook wrapper scripts, and
# scripts/mcp-servers.json as the MCP source) because those are the actual sources of truth for
# what gets projected - referencing a path is not the same as depending on it.
#
# Sources of truth:
#   settings.json hooks (this repo's root)         -> ~/.cursor/hooks.json twin
#   statusline-cursor.sh (this script's directory)  -> ~/.cursor/cli-config.json's statusLine key
#   scripts/mcp-servers.json (this repo's root, canonical mcpServers block) -> ~/.cursor/mcp.json
# Per-harness facts: references/harness-matrix.md (this skill's references/ directory)
#
# Usage:
#   project-to-cursor.sh --check    warn-only: report divergence, make no changes, exit 1 if any
#                                    drift is found
#   project-to-cursor.sh --apply    perform the writes (idempotent)
#
# All three projections are a guarded no-op on a machine that doesn't have Cursor installed (see
# is_cursor_installed) - reporting the absence of ~/.cursor/* as "drift" on a machine that runs
# only Claude Code would be a permanent false positive, not a real staleness signal. The MCP
# projection is additionally a guarded no-op until scripts/mcp-servers.json exists at the repo
# root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CHECK_ONLY=0
DRIFT_FOUND=0

usage() {
  cat <<'EOF'
Usage: project-to-cursor.sh --check|--apply

Projects this repo's Cursor-facing configuration into ~/.cursor/ (hooks.json, cli-config.json's
statusLine key, mcp.json).

  --check   report what would change, write nothing, exit 1 if anything diverges
  --apply   perform the writes - a hook-registration act; read this script first (see header)

Guarded no-op on a machine without Cursor installed, and for the MCP projection until
scripts/mcp-servers.json exists at the repo root.
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

case "$1" in
  --check) CHECK_ONLY=1 ;;
  --apply) CHECK_ONLY=0 ;;
  *) usage; exit 2 ;;
esac

log()  { printf '%s\n' "$*"; }

# note_drift <message>: record that a live output diverges from its source. Fails --check.
note_drift() {
  DRIFT_FOUND=1
  log "DRIFT: $*"
}

# is_cursor_installed: whether THIS machine has Cursor's CLI, gating the three functions below
# that write into ~/.cursor/ (a machine-local, harness-specific directory).
#
# Cursor's CLI binary is literally named "agent" (cursor.com/docs/cli/installation), too generic
# a name to `command -v` safely - an unrelated "agent" on some machine's PATH would false-positive.
# Check the documented default install location first; failing that, treat ~/.cursor itself
# existing as a secondary positive signal (Cursor has been configured/run here even if the binary
# lives somewhere else). Neither signal existing means Cursor isn't on this machine.
is_cursor_installed() {
  [[ -x "$HOME/.local/bin/agent" ]] && return 0
  [[ -d "$HOME/.cursor" ]] && return 0
  return 1
}

# --- Cursor hooks.json twin (from settings.json hooks, via the repo's scripts/*.sh wrappers) -
# Three managed event categories, each built as its own desired-entries block below then merged in
# independently: afterFileEdit (from settings.json's PostToolUse Write|Edit entries), stop (from
# settings.json's Stop entry), and preToolUse (from settings.json's PreToolUse Bash entry). Each
# shared wrapper script is invoked with its own "cursor" positional argument so it reads Cursor's
# payload field names and emits Cursor's response shape instead of Claude Code's defaults - that
# positional argument is the whole reason these wrappers branch internally, so it is not optional
# here.
#
# afterFileEdit and stop are a pair, not two independent hooks: afterFileEdit records touched
# Markdown paths to a ledger, and stop drains that ledger and runs the expensive checks once per
# distinct file (see scripts/md-ledger-append.sh for why the work is on the stop event rather than
# the per-edit event). Registering one without the other silently disables the checks - the
# recorder would accumulate a ledger nothing ever reads, or the drain would find nothing to read.
#
# preToolUse, not beforeShellExecution: per references/harness-matrix.md's Hooks section,
# beforeShellExecution's response has no field to rewrite the command, only allow/deny/ask -
# preToolUse is the event whose response supports updated_input.command. stop is Cursor's
# end-of-agent-loop event, the analog of Claude Code's Stop (confirmed against Cursor's hooks
# docs). Add a new jq -n block to the matching category (and a matching settings.json entry,
# registered by hand per decisions/0003-hooks-and-scripts-authoring-policy.md) whenever a new
# shared logic script of that kind is added.
sync_cursor_hooks() {
  if ! is_cursor_installed; then
    log "sync_cursor_hooks: Cursor not installed on this machine, skipping"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    log "sync_cursor_hooks: jq not found, skipping"
    return
  fi

  local managed_marker="$REPO_ROOT/scripts/"
  local hooks_path="$HOME/.cursor/hooks.json"

  # Desired afterFileEdit entries: the ledger recorder. It parses Cursor's .file_path itself
  # (given the "cursor" argument), so it needs no jq/xargs wrapper - it reads the raw payload on
  # stdin exactly as the Claude registration does.
  local desired_after_file_edit
  desired_after_file_edit="$(jq -n \
    --arg ledger_cmd "$REPO_ROOT/scripts/md-ledger-append.sh cursor" \
    '[{command: $ledger_cmd}]')"

  # Desired stop entries: the deferred-checks drain, paired with the afterFileEdit recorder above.
  local desired_stop
  desired_stop="$(jq -n \
    --arg checks_cmd "$REPO_ROOT/scripts/md-deferred-checks.sh cursor" \
    '[{command: $checks_cmd}]')"

  # Desired preToolUse entries: one per registered PreToolUse hook this repo manages. matcher is
  # a Cursor tool name (references/harness-matrix.md: Bash on Claude Code is Shell on Cursor), not
  # Claude Code's matcher value.
  local desired_pre_tool_use
  desired_pre_tool_use="$(jq -n \
    --arg filter_cmd "$REPO_ROOT/scripts/filter-verbose-output.sh cursor" \
    '[{command: $filter_cmd, matcher: "Shell"}]')"

  local existing
  if [[ -f "$hooks_path" ]]; then
    existing="$(cat "$hooks_path")"
  else
    existing='{"version":1,"hooks":{}}'
  fi

  # Keep any entry this script doesn't manage (foreign entries: no reference to this repo's
  # scripts/ path); drop our own prior entries in each category so re-running is idempotent,
  # then append the freshly generated desired entries for that category.
  local new_json
  new_json="$(jq --arg marker "$managed_marker" \
                 --argjson desired_afe "$desired_after_file_edit" \
                 --argjson desired_stop "$desired_stop" \
                 --argjson desired_ptu "$desired_pre_tool_use" '
    .version //= 1
    | .hooks //= {}
    | .hooks.afterFileEdit = (
        [(.hooks.afterFileEdit // [])[] | select((.command // "") | contains($marker) | not)]
        + $desired_afe
      )
    | .hooks.stop = (
        [(.hooks.stop // [])[] | select((.command // "") | contains($marker) | not)]
        + $desired_stop
      )
    | .hooks.preToolUse = (
        [(.hooks.preToolUse // [])[] | select((.command // "") | contains($marker) | not)]
        + $desired_ptu
      )
  ' <<< "$existing")"

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ "$new_json" != "$(jq . <<< "$existing")" ]]; then
      note_drift "$hooks_path missing or out of date relative to settings.json hooks"
    fi
  else
    mkdir -p "$(dirname "$hooks_path")"
    jq . <<< "$new_json" > "$hooks_path"
    log "synced: $hooks_path"
  fi
}

# --- Cursor statusLine registration (~/.cursor/cli-config.json's statusLine key) -------------
# Claude Code's equivalent is settings.json's own "statusLine" key - both point a
# "type": "command" entry at a script, so this mirrors that shape rather than inventing a new
# one. Only "type" and "command" are enforced; any other keys already present under .statusLine
# (padding, updateIntervalMs, timeoutMs - none of which are documented defaults, just whatever the
# user or Cursor itself has set) are left untouched, so this can't silently reset tuning that
# lives outside this repo. Merges into the existing file rather than overwriting it outright,
# since cli-config.json also holds permissions, model selection, and account state this script
# must never touch.
sync_cursor_statusline() {
  if ! is_cursor_installed; then
    log "sync_cursor_statusline: Cursor not installed on this machine, skipping"
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    log "sync_cursor_statusline: jq not found, skipping"
    return
  fi

  local config_path="$HOME/.cursor/cli-config.json"
  local desired_command="$SCRIPT_DIR/statusline-cursor.sh"

  local existing
  if [[ -f "$config_path" ]]; then
    existing="$(cat "$config_path")"
  else
    existing='{}'
  fi

  local new_json
  new_json="$(jq --arg cmd "$desired_command" '
    .statusLine = ((.statusLine // {}) + {type: "command", command: $cmd})
  ' <<< "$existing")"

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ "$new_json" != "$(jq . <<< "$existing")" ]]; then
      note_drift "$config_path's statusLine is missing or does not point at $desired_command"
    fi
  else
    mkdir -p "$(dirname "$config_path")"
    jq . <<< "$new_json" > "$config_path"
    log "synced: $config_path (statusLine)"
  fi
}

# --- MCP servers (~/.cursor/mcp.json from the repo's canonical mcpServers block) -------------
# Source: scripts/mcp-servers.json at the repo root. Guarded no-op until that file exists.
sync_mcp() {
  if ! is_cursor_installed; then
    log "sync_mcp: Cursor not installed on this machine, skipping"
    return
  fi
  local src="$REPO_ROOT/scripts/mcp-servers.json"
  if [[ ! -f "$src" ]]; then
    log "sync_mcp: no scripts/mcp-servers.json at the repo root (no MCP servers configured) - guarded no-op"
    return
  fi
  local dest="$HOME/.cursor/mcp.json"
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ ! -f "$dest" ]] || ! diff -q "$src" "$dest" >/dev/null 2>&1; then
      note_drift "$dest missing or out of date relative to scripts/mcp-servers.json"
    fi
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    log "synced: $dest"
  fi
}

main() {
  log "repo: $REPO_ROOT"
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    log "mode: check (warn-only, no changes)"
  else
    log "mode: apply"
  fi

  sync_cursor_hooks
  sync_cursor_statusline
  sync_mcp

  if [[ "$CHECK_ONLY" -eq 1 && "$DRIFT_FOUND" -eq 1 ]]; then
    log "drift detected"
    exit 1
  fi
  log "done"
}

main
