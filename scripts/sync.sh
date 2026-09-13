#!/usr/bin/env bash
#
# sync.sh - keeps the skills' references/ copies in sync with their in-repo sources, and
# drift-checks them.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this script's logic may be
# model-generated but is reviewed in full before commit.
#
# Scope: the "mechanical" artifact class (deterministic projections). It must NOT generate or
# edit LLM-authored artifacts (skills, subagents) - those are regenerated via their own authoring
# skill and gated by evals or diff review. See reference/spec-driven-architecture.md.
#
# Cursor projection lives in a separate skill, not here: see
# skills/cursor-projection/scripts/project-to-cursor.sh.
#
# Sources of truth:
#   docs/features/skills.md                 -> skills/skill-author/references/skills.md
#   reference/document-generation.md        -> skills/review-md/references/document-generation.md
#   reference/research-discipline.md        -> skills/research/references/research-discipline.md
#   reference/subagent-orchestration.md     -> skills/write-plan/references/subagent-orchestration.md
#                                            -> skills/execute-plan/references/subagent-orchestration.md
#
# Usage:
#   scripts/sync.sh            apply (idempotent)
#   scripts/sync.sh --check    warn-only: report divergence, make no changes, exit 1 if any
#                              drift is found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_ONLY=0
DRIFT_FOUND=0

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '%s\n' "$*"; }

# note_drift <message>: record that a live output diverges from its source. Fails --check.
note_drift() {
  DRIFT_FOUND=1
  log "DRIFT: $*"
}

# --- Synced reference copies (deterministic file copy plus a dated sync-note line) ----------
# Pattern: copy the source verbatim, but insert a "> Synced copy of ..." note right after the
# first H1 heading (matching skill-author/references/skills.md's existing convention), with
# today's date. Drift comparison strips that note (both lines) from each side first, so a date
# bump alone never counts as drift - only a real content change does. The note is always exactly
# two lines, so strip exactly two lines starting at the match rather than a range to the next
# line ending in "independently." (a range would over-delete if that closing wording ever changes).
_strip_sync_note() {
  sed '/^> Synced copy of /,+1d'
}

sync_one_reference() {
  local src_rel="$1" dest_rel="$2"
  local src_path="$REPO_ROOT/$src_rel"
  local dest_path="$REPO_ROOT/$dest_rel"

  if [[ ! -f "$src_path" ]]; then
    log "sync_one_reference: source not found, skipping: $src_rel"
    return
  fi

  local today generated
  today="$(date +%Y-%m-%d)"
  generated="$(awk -v note1="> Synced copy of \`$src_rel\` (source of truth) as of $today. If that file" \
                    -v note2="> changes, re-sync this copy - do not edit the two independently." '
    BEGIN { in_fm = 0; fm_done = 0; title_done = 0 }
    {
      if (NR == 1 && $0 == "---") { in_fm = 1; print; next }
      if (in_fm) {
        print
        if ($0 == "---") { in_fm = 0; fm_done = 1 }
        next
      }
      if (fm_done && !title_done && $0 ~ /^# /) {
        print
        print ""
        print note1
        print note2
        title_done = 1
        next
      }
      print
    }
  ' "$src_path")"

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    if [[ ! -f "$dest_path" ]]; then
      note_drift "missing synced copy: $dest_rel (source: $src_rel)"
      return
    fi
    local existing_norm generated_norm
    existing_norm="$(_strip_sync_note < "$dest_path")"
    generated_norm="$(printf '%s\n' "$generated" | _strip_sync_note)"
    if [[ "$existing_norm" != "$generated_norm" ]]; then
      note_drift "synced copy out of date: $dest_rel (source: $src_rel)"
    fi
  else
    # Skip the write when only the note's date would change (compare with the same
    # note-stripping normalization --check uses), so re-running on a later day with no real
    # source change is a true no-op instead of a date-only diff on every copy.
    if [[ -f "$dest_path" ]]; then
      local existing_norm generated_norm
      existing_norm="$(_strip_sync_note < "$dest_path")"
      generated_norm="$(printf '%s\n' "$generated" | _strip_sync_note)"
      if [[ "$existing_norm" == "$generated_norm" ]]; then
        log "unchanged: $dest_rel (source: $src_rel)"
        return
      fi
    fi
    mkdir -p "$(dirname "$dest_path")"
    printf '%s\n' "$generated" > "$dest_path"
    log "synced: $dest_rel <- $src_rel"
  fi
}

sync_reference_copies() {
  sync_one_reference "docs/features/skills.md" "skills/skill-author/references/skills.md"
  sync_one_reference "reference/document-generation.md" "skills/review-md/references/document-generation.md"
  sync_one_reference "reference/research-discipline.md" "skills/research/references/research-discipline.md"
  sync_one_reference "reference/subagent-orchestration.md" "skills/write-plan/references/subagent-orchestration.md"
  sync_one_reference "reference/subagent-orchestration.md" "skills/execute-plan/references/subagent-orchestration.md"
}

main() {
  log "repo: $REPO_ROOT"
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    log "mode: check (warn-only, no changes)"
  else
    log "mode: apply"
  fi

  sync_reference_copies

  if [[ "$CHECK_ONLY" -eq 1 && "$DRIFT_FOUND" -eq 1 ]]; then
    log "drift detected"
    exit 1
  fi
  log "done"
}

main "$@"
