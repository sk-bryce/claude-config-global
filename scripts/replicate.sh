#!/usr/bin/env bash
#
# replicate.sh - mirror the shared Claude Code config (skills, agents, scripts, settings.json,
# and a managed copy of this repo's CLAUDE.md) into one or more other CLAUDE_CONFIG_DIR
# directories, e.g. a second account's config dir. Never touches auth, session, project, or other
# account-specific state - only the subpaths listed in SYNCED_DIRS/SYNCED_FILES below.
#
# Each target's CLAUDE.md is written as a copy of this repo's CLAUDE.md rather than a symlink to
# it (Claude Code has several open/closed issues around symlinked config paths - discovery,
# write-through, and CLAUDE_CONFIG_DIR path validation all mishandling symlinks). See the block
# that writes it for why it is a full copy rather than an `@`-import.
#
# Usage:
#   scripts/replicate.sh <target-dir> [target-dir ...]
# One or more CLAUDE_CONFIG_DIR directories to mirror into, e.g.:
#   scripts/replicate.sh ~/.claude-work
#   scripts/replicate.sh ~/.claude-work ~/.claude-otheraccount
# Deliberately takes targets as arguments rather than a tracked list file: which accounts exist is
# per-machine state, not something to commit to a shared repo.
#
# Install (per machine, run once - and again after any fresh clone, since .git/hooks is never
# tracked by git): run scripts/setup.sh, which asks for your target dir(s) and writes them to
# .git/hooks/replicate-targets.sh, then registers three hooks that exec it:
#   post-commit   every commit made on this machine (stands down mid-rebase, see post-rewrite)
#   post-merge    every merge, which is how `git pull` integrates by default (fast-forwards too)
#   post-rewrite  `git rebase`, which is how `git pull --rebase` integrates (its `amend`
#                 invocation is ignored - post-commit already covers that)
# post-commit alone would replicate only off the machine that authored a commit; the other two are
# what carry a commit authored elsewhere into this machine's profiles when it arrives by pull.
# You can also run this script by hand at any time with the target dir(s) as arguments to sync
# without committing or pulling.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic invoked by a git
# hook) may be model-generated and is reviewed in full before commit; the registration that makes it
# fire automatically (the hooks above and the target dirs in replicate-targets.sh) is a separate,
# explicit human step.
#
# Only ever mirrors from the main working tree on the main branch (see the guard below) - never
# from a linked worktree or a feature branch, even when invoked by hand.
#
# Locked (see below) so two overlapping runs - e.g. a fast sequence of commits - can't rsync into
# the same target at once, which could otherwise interleave two --delete passes and corrupt it.
# Not internally atomic beyond that: a run killed partway through a target leaves it with a mix of
# old and new config. Rather than staging into a temp dir and renaming into place to fully prevent
# that, this only makes sure such a failure is loud (see the ERR trap below) - the next successful
# run always finishes the job, and mid-run kills are rare enough that atomicity isn't worth the
# added complexity here.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf 'replicate: %s\n' "$*" >&2; }

# `git rev-parse --show-toplevel`, which replicate-targets.sh uses to locate this script,
# resolves per-worktree - inside a linked worktree it returns the worktree's own path, not the main
# checkout. Mirroring from a worktree would push an unmerged feature branch's config - the global
# instructions included, since CLAUDE.md carries them outright - into every target profile.
# `--git-dir` and `--git-common-dir` are equal only in the main working tree; they diverge in any
# linked worktree. Also gate on branch: per this repo's own CLAUDE.md, all feature-branch work
# happens in a worktree already, but this is a second, independent check so a main-branch worktree
# (or a future workflow change) is still covered.
# Neither check is an error - both are the routine case while a branch is in progress - so both
# skip quietly rather than exiting non-zero.
if command -v git >/dev/null 2>&1 && git -C "$SOURCE_DIR" rev-parse >/dev/null 2>&1; then
  git_dir="$(git -C "$SOURCE_DIR" rev-parse --git-dir 2>/dev/null || true)"
  git_common_dir="$(git -C "$SOURCE_DIR" rev-parse --git-common-dir 2>/dev/null || true)"
  branch="$(git -C "$SOURCE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ "$git_dir" != "$git_common_dir" ]]; then
    log "skipping: $SOURCE_DIR is a linked worktree, not the main working tree - rerun from there"
    exit 0
  fi
  if [[ -n "$branch" && "$branch" != "main" ]]; then
    log "skipping: current branch is '$branch', not main"
    exit 0
  fi
fi

# Only handles the invoking user's own home (~ or ~/...); ~otheruser/... is passed through
# literally rather than resolved - fine for this repo's single-user use case.
#
# The patterns below escape the tilde rather than quoting it, matching scripts/setup.sh's case
# statement for the same job. Both forms mean the same literal `~` here, but SC2088 ("tilde does
# not expand in quotes") fires on the quoted one - not expanding is the point on the right of a
# [[ == ]] and a bug almost anywhere else, so the escape says which one this is and keeps the file
# lint-clean without a disable directive. (Keep "shellcheck" off the start of a comment line: it
# reads any such line as a directive and gives up parsing the file.)
expand_tilde() {
  local path="$1"
  if [[ "$path" == \~ ]]; then
    printf '%s\n' "$HOME"
  elif [[ "$path" == \~/* ]]; then
    printf '%s\n' "$HOME/${path#\~/}"
  else
    printf '%s\n' "$path"
  fi
}

if [[ "$#" -eq 0 ]]; then
  log "usage: replicate.sh <target-dir> [target-dir ...] (see this file's header for install instructions)"
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  log "rsync not found on PATH - required to mirror skills/agents/scripts/etc, aborting before touching any target"
  exit 1
fi

targets=()
for arg in "$@"; do
  targets+=("$(expand_tilde "$arg")")
done

# --- Lock -----------------------------------------------------------------------------------------
# `flock` isn't available on macOS (this repo's primary platform), so lock with `mkdir`, which is
# atomic on every filesystem this needs to run on: exactly one concurrent caller can create a given
# directory. A run that loses the race skips outright rather than waiting - the next commit's run
# mirrors the same end state, so nothing is lost, and a hook shouldn't add latency to `git commit`
# or `git pull`.
LOCK_DIR="$SOURCE_DIR/cache/replicate.lock"
mkdir -p "$(dirname "$LOCK_DIR")" 2>/dev/null || true
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # A run that was killed before reaching the `rmdir` in the EXIT trap below leaves this behind
  # forever otherwise, permanently blocking every future sync. No real sync approaches 5 minutes,
  # so treat an older lock as abandoned and reclaim it.
  if [[ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +5 2>/dev/null)" ]] \
     && rmdir "$LOCK_DIR" 2>/dev/null && mkdir "$LOCK_DIR" 2>/dev/null; then
    log "reclaimed a stale lock ($LOCK_DIR is over 5 minutes old - a prior run likely crashed)"
  else
    log "skipping: another replicate.sh run holds the lock - the next commit's run will catch up"
    exit 0
  fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# Names which target was being synced if a step below fails, so a `set -e` abort - rsync killed,
# disk full, a permission error - says what's now inconsistent instead of just exiting non-zero.
# Both variables are declared here rather than only inside the trap body: the body is a string the
# shell parses later, so an assignment made only in there reads as an undeclared global to anything
# looking at this file, shellcheck included (SC2154).
current_target=""
trap_status=0
trap '
  trap_status=$?
  if [[ -n "$current_target" ]]; then
    log "FAILED (exit $trap_status) partway through syncing $current_target - it may have a mix of old and new config until the next successful run"
  fi
' ERR

# Directories mirrored verbatim (rsync --delete: each becomes an exact copy of the source
# subdirectory, so don't add account-specific files directly under these paths in a target - the
# next sync deletes anything not present in the source). -L dereferences any symlink found inside
# the source tree so a real file lands in the target, never a symlink.
#
# reference/ and decisions/ are on the list because synced content loads them at runtime: a skill
# or subagent told to read reference/subagent-orchestration.md before dispatching needs the copy
# inside the profile it is running under, not the default account's. docs/ and specs/ are
# deliberately off it
# - docs/ is a 1MB reading library rather than runtime config, and specs/ holds this checkout's
# build-intent for maintainers rather than anything a running skill loads.
SYNCED_DIRS=(skills agents scripts commands rules hooks reference decisions)
# Files copied verbatim (full overwrite, no merge) - don't hand-edit a target's copy of these,
# the next sync replaces it wholesale.
SYNCED_FILES=(settings.json)

for target in "${targets[@]}"; do
  current_target="$target"
  mkdir -p "$target"
  target_real="$(cd "$target" && pwd)"
  if [[ "$target_real" == "$SOURCE_DIR" ]]; then
    log "target $target resolves to this repo itself ($SOURCE_DIR) - refusing to sync onto the source, skipping"
    continue
  fi
  log "syncing into $target"

  # The source is $SOURCE_DIR/CLAUDE.md, which holds the global instructions outright. A missing
  # source is a warning here rather than a failure, so a target's copy simply stays at its last
  # synced state until the source reappears.
  #
  # Written as a full copy rather than an `@`-import: an import by absolute path would leave every
  # target permanently dependent on this repo staying at that exact path - move or rename it and
  # the profile silently loads no global instructions at all, with nothing to notice but the
  # missing canary. An import would also defeat the point of syncing reference/ and decisions/
  # above: the global instructions declare their bare-relative pointers to resolve against the
  # directory holding them, so under an import they would resolve into this repo rather than into
  # the copies sitting in the target. A copy is also the safer side of an open question about
  # `## Compact Instructions` (decisions/0006 and
  # reference/context-file-authoring.md): Anthropic documents the mechanism against CLAUDE.md's own
  # literal text and does not say whether it reaches into an `@`-imported file. Staleness between
  # syncs is not a new exposure - every other path written here is already a snapshot refreshed by
  # the same replication hooks.
  #
  # Written here rather than added to SYNCED_FILES, even though source and target now share a name:
  # the copy is prefixed with the managed-by header below, so a target's CLAUDE.md says outright
  # that editing it is pointless and names the file to edit instead. The self-sync guard above is
  # what keeps that header from being prepended to the source itself.
  #
  # Known cost of the copy: those bare-relative pointers now resolve inside the target, and docs/
  # is not synced (it is a 1MB reading library rather than runtime config), so the two docs/
  # citations - the "Turn" glossary entry and the effort-level appendix - resolve to nothing there.
  # Both rules state themselves fully inline, so a target loses the footnote rather than the rule.
  # Add docs to SYNCED_DIRS if that stops being true.
  claude_md="$target/CLAUDE.md"
  if [[ -f "$SOURCE_DIR/CLAUDE.md" ]]; then
    # An HTML comment, not a `#` line: this file is Markdown, and `#` would render as an H1 above
    # the copied file's own content.
    claude_md_content="$(printf '<!--\nManaged by scripts/replicate.sh - manual edits are overwritten on the next sync.\nEdit %s/CLAUDE.md instead.\n-->\n%s' "$SOURCE_DIR" "$(cat "$SOURCE_DIR/CLAUDE.md")")"
    if [[ ! -f "$claude_md" ]] || [[ "$(cat "$claude_md")" != "$claude_md_content" ]]; then
      printf '%s\n' "$claude_md_content" > "$claude_md"
      log "  wrote $claude_md (copy of $SOURCE_DIR/CLAUDE.md)"
    fi
  else
    log "  WARNING: $SOURCE_DIR/CLAUDE.md is missing - did not write $claude_md"
  fi

  for dir in "${SYNCED_DIRS[@]}"; do
    if [[ -d "$SOURCE_DIR/$dir" ]]; then
      mkdir -p "$target/$dir"
      rsync -aL --delete "$SOURCE_DIR/$dir/" "$target/$dir/"
      log "  synced $dir/"
    fi
  done

  for file in "${SYNCED_FILES[@]}"; do
    if [[ -f "$SOURCE_DIR/$file" ]]; then
      cp -f "$SOURCE_DIR/$file" "$target/$file"
      log "  synced $file"
    fi
  done
done

log "done"
