#!/usr/bin/env bash
#
# pre-commit-check.sh - gate a commit on the mechanical checks nothing else runs automatically:
# settings.json must parse as JSON, the mechanical (deterministic) projections must not have
# drifted from their sources, no staged file may carry content unsuited to a public remote, and
# scrub-check's own patterns must still be firing (scrub-check.sh --test). None of these touches
# history or rewrites anything; all are read-only.
#
# WHY IT TAKES --repo: a repository wanting this gate can borrow this script rather than copy it,
# and a copy drifts silently - a scrub check that has stopped matching still exits 0. The borrower
# needs nothing but a hook registration. Opting in and keeping it current is theirs to do; nothing
# here holds a list of who has, so the flag is a stable interface: a borrower has no way to notice
# if it changes shape.
#
# WHAT TRAVELS: this gate may INSPECT a borrowed repository, never EXECUTE anything out of one.
# The leak checks travel, and so does validating settings.json - jq only reads it. The projection
# check does not, because running it means executing whatever sits at the target's scripts/sync.sh,
# a common enough filename that a borrower could not anticipate it. It is also skipped in a linked
# worktree; see the comment on that check.
#
# This is a git hook's logic, not its registration. Per
# decisions/0003-hooks-and-scripts-authoring-policy.md this file may be model-generated and
# reviewed before commit like any other script; installing it into .git/hooks/pre-commit (the
# step that makes it fire automatically) is the registration step and requires the user's
# explicit, in-the-moment direction the same as any other hook - see that decision's Decision section.
#
# Usage: scripts/pre-commit-check.sh [--repo <dir>]
#   (no arguments)  Checks this script's own repository.
#   --repo <dir>    Checks the repository containing <dir> instead; --repo=<dir> works too, and any
#                   path inside the target does.
#   Intended for .git/hooks/pre-commit. Every registration uses one shape,
#   `--repo "$(git rev-parse --show-toplevel)"`, so there is a single hook line to keep right:
#   scripts/setup.sh writes it here, a borrower writes it by hand.

set -euo pipefail

SELF_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

status=0

log() { printf '%s\n' "$*" >&2; }

# Both spellings, matching scrub-check.sh: a hook written once by hand should not have to remember
# which one this script accepts. Validated once after the loop - a missing value, an empty one, and
# a trailing --repo are the same mistake and deserve one message.
REPO_TARGET=""
saw_repo=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)   saw_repo=1; REPO_TARGET="${2-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --repo=*) saw_repo=1; REPO_TARGET="${1#--repo=}"; shift ;;
    *) log "pre-commit: unknown argument: $1"; exit 2 ;;
  esac
done

if [[ "$saw_repo" -eq 1 && -z "$REPO_TARGET" ]]; then
  log "pre-commit: --repo needs a directory argument"
  exit 2
fi

REPO_ROOT="$SELF_REPO"
if [[ -n "$REPO_TARGET" ]]; then
  # git resolves the root, so any path inside the target repository works. It also covers both ways
  # this can fail - a path that does not exist, and one in no checkout at all - which have to stay
  # errors rather than becoming passes.
  REPO_ROOT="$(git -C "$REPO_TARGET" rev-parse --show-toplevel 2>/dev/null)" || REPO_ROOT=""
  if [[ -z "$REPO_ROOT" ]]; then
    log "pre-commit: --repo is not a readable path inside a git checkout: $REPO_TARGET"
    exit 2
  fi
fi

cd "$REPO_ROOT"
REPO_ROOT="$(git rev-parse --show-toplevel)"  # git's spelling, so the comparison below is textual

# The one checkout the projection check may run in: this script's own MAIN checkout. Everything
# else - a borrowed repository, and a linked worktree of this one - is excluded by the same test.
# Every checkout of a repository shares a git directory, whose parent is the main checkout.
SELF_MAIN="$SELF_REPO"
self_common="$(git -C "$SELF_REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
  && SELF_MAIN="$(dirname "$self_common")"

# Guarded on the file existing, not just on jq: a repository with no settings.json has nothing to
# validate, where the unguarded form reported that absence as invalid JSON. Runs for a borrowed
# repository too - jq only reads it, per the header's inspect/execute rule.
if [[ -f settings.json ]]; then
  if command -v jq >/dev/null 2>&1; then
    if ! jq empty settings.json 2>/dev/null; then
      log "pre-commit: settings.json is not valid JSON"
      status=1
    fi
  else
    log "pre-commit: jq not found, skipping settings.json validation"
  fi
fi

# Two exclusions, one test. Not a borrowed repository, per the header's inspect/execute rule. And
# not a linked worktree either: sync.sh --check compares this checkout's in-repo documentation
# projections against their sources, which are meant to reflect the main checkout's committed
# state, not an in-progress feature branch's - checking a worktree here would fail the gate on
# drift that has not landed on the branch this gate protects yet. A gate that always fails is one
# whose author starts passing --no-verify, losing the leak checks too. Drift introduced on a branch
# is still caught by the commit that lands it here.
if [[ "$REPO_ROOT" == "$SELF_MAIN" ]]; then
  if [[ -x scripts/sync.sh ]]; then
    if ! scripts/sync.sh --check; then
      log "pre-commit: scripts/sync.sh --check reported drift (see above) - run 'scripts/sync.sh' to resync, then re-stage"
      status=1
    fi
  else
    log "pre-commit: scripts/sync.sh not found or not executable, skipping"
  fi
fi

# --staged, not the default: this hook needs the bytes about to be committed, not whatever the
# working tree happens to hold - a secret staged and then tidied out of the working tree passes a
# working-tree scan and commits. scrub-check enumerates them itself, so this hook does not
# duplicate that logic. Staged content only, not the whole tree: a pre-existing finding elsewhere is
# a separate cleanup and deliberately does not block every commit. Running `scripts/scrub-check.sh`
# by hand, with no arguments, is the full-tree audit.
SCRUB="$SELF_REPO/scripts/scrub-check.sh"
if [[ -x "$SCRUB" ]]; then
  if ! "$SCRUB" --repo "$REPO_ROOT" --staged; then
    log "pre-commit: scrub-check reported content unsuited to a public remote (see above)"
    log "pre-commit: see $SELF_REPO/reference/public-repo-hygiene.md"
    status=1
  fi

  # Self-test on every commit, not only when a pattern changes: cheap, and the one thing that would
  # notice a pattern silently stopping firing before that shows up as a leak the check above should
  # have caught. No --repo: the fixtures belong to this script's own checkout, not to whichever
  # repository is being gated.
  if ! "$SCRUB" --test; then
    log "pre-commit: scrub-check --test failed - a pattern may have stopped matching"
    log "pre-commit: see $SELF_REPO/reference/public-repo-hygiene.md"
    status=1
  fi
else
  # Fails the commit rather than skipping: a missing detector is not "nothing to check", it is a
  # commit heading for a public remote with no gate in front of it.
  log "pre-commit: no scrub detector at $SCRUB - the gate cannot run"
  status=1
fi

exit "$status"
