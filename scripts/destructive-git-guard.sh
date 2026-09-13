#!/usr/bin/env bash
#
# destructive-git-guard.sh - PreToolUse hook logic that blocks destructive git invocations
# regardless of where the triggering flag appears on the command line.
#
# Why this exists on top of settings.json's permissions.deny: those rules match on literal
# command-string prefix only, so `Bash(git push --force:*)` blocks `git push --force` but not
# `git push origin main --force` - the flag has moved out of prefix position, and Claude Code's
# own permission-rule docs confirm there is no glob/regex mechanism to match a flag independent
# of position. This hook tokenizes the command after the git subcommand instead, so flag
# position doesn't matter. The settings.json deny rules stay in place as an independent,
# overlapping check for the fixed-position forms; this hook does not replace them.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it
# (settings.json's PreToolUse entry) is a separate, explicit human step.
#
# Usage: register as a PreToolUse hook matching Bash. Reads the hook's JSON payload from stdin
# (same shape as filter-verbose-output.sh: .tool_input.command).
#
# Behavior: emits a permissionDecision "deny" with a reason, matched anywhere after the git
# subcommand rather than just at the start, for:
#   - git push --force/-f (including --force-with-lease), or --delete/a :<branch> delete
#     refspec (removes a remote branch)
#   - git reset --hard
#   - git clean -f/--force (including combined short-flag clusters like -fd)
#   - git branch -D, or --delete combined with --force/-f
#   - git commit --no-verify/-n/--no-gpg-sign
#   - git rebase -i/--interactive
#   - git checkout targeting a bare `.` (discards uncommitted changes)
#   - git restore targeting a bare `.`, unless --staged is used without --worktree (unstaging
#     alone does not discard working-tree edits)
#   - git stash drop/clear (permanently deletes stashed changes)
#   - git filter-branch (rewrites repository history)
#   - git reflog expire --all combined with --expire=now/--expire-unreachable=now (destroys the
#     recovery safety net other mistakes rely on)
# Quoted substrings (commit messages, etc.) are stripped before matching, so flag text inside a
# quoted message does not false-positive and a real flag placed after a quoted argument is not
# missed either way - both are the same position-independence problem this hook exists to solve.
# Every other command falls through silently (exit 0, no output). Fails open (no output, exit 0)
# on missing jq or unparsable input - a broken hook must never block a legitimate tool call; see
# filter-verbose-output.sh's header comment for the same accepted tradeoff.
#
# Known limitation: matching is regex-based on the command string, not a real shell parser, so an
# adversarial rewrite (command substitution, an alias, a wrapper script) is not guaranteed to be
# caught. This raises the bar over prefix-only matching; it is not a sandbox. `git push` has no
# documented `-d` short form for `--delete` (unlike `git branch -d/-D`), so only `--delete` and
# the `:<branch>` delete-refspec form are matched for remote-branch deletion. A bare
# `git gc --prune=now` (without a preceding `git reflog expire --all --expire=now`) is not
# guarded - gc respects reflog-referenced objects by default, so its risk is secondary to and
# smaller than the reflog-expire case that is guarded.

set -euo pipefail

payload="$(cat)"

tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
[[ "$tool" != "Bash" ]] && exit 0

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"
[[ -z "$cmd" ]] && exit 0

trimmed="${cmd#"${cmd%%[![:space:]]*}"}"
[[ "$trimmed" =~ ^git[[:space:]] ]] || exit 0

# Strip quoted substrings (commit messages, etc.) before flag-matching, so a flag-shaped token
# inside quoted text can't false-positive, and a real flag after a quoted argument isn't missed.
scan="$(printf '%s' "$trimmed" | sed -E "s/'[^']*'//g" | sed -E 's/"[^"]*"//g')"

deny_reason=""

if [[ "$scan" =~ ^git[[:space:]]+push([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])(--force([[:space:]]|-|$)|-f([[:space:]]|$)) ]]; then
    deny_reason="destructive-git-guard: git push --force/-f is denied regardless of flag position."
  elif [[ "$scan" =~ (^|[[:space:]])--delete([[:space:]]|$) ]] \
    || [[ "$scan" =~ (^|[[:space:]]):[A-Za-z0-9._/-]+([[:space:]]|$) ]]; then
    deny_reason="destructive-git-guard: git push --delete (or a :<branch> delete refspec) removes a remote branch and is denied regardless of flag position."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+reset([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])--hard([[:space:]]|$) ]]; then
    deny_reason="destructive-git-guard: git reset --hard is denied regardless of flag position."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+clean([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])(--force([[:space:]]|$)|-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)) ]]; then
    deny_reason="destructive-git-guard: git clean -f/--force is denied regardless of flag position."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+branch([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])-D([[:space:]]|$) ]]; then
    deny_reason="destructive-git-guard: git branch -D is denied regardless of flag position."
  elif [[ "$scan" =~ (^|[[:space:]])(--delete([[:space:]]|$)|-d([[:space:]]|$)) ]] \
    && [[ "$scan" =~ (^|[[:space:]])(--force([[:space:]]|$)|-f([[:space:]]|$)) ]]; then
    deny_reason="destructive-git-guard: git branch --delete --force is denied regardless of flag position."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+commit([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])(--no-verify([[:space:]]|$)|-n([[:space:]]|$)|--no-gpg-sign([[:space:]]|$)) ]]; then
    deny_reason="destructive-git-guard: git commit --no-verify/-n/--no-gpg-sign is denied regardless of flag position."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+rebase([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])(-i([[:space:]]|$)|--interactive([[:space:]]|$)) ]]; then
    deny_reason="destructive-git-guard: git rebase -i/--interactive is denied regardless of flag position."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+checkout([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])\.([[:space:]]|$) ]]; then
    deny_reason="destructive-git-guard: git checkout targeting . (bare dot) is denied regardless of position - it discards uncommitted changes."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+restore([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])\.([[:space:]]|$) ]]; then
    if [[ "$scan" =~ (^|[[:space:]])--staged([[:space:]]|$) ]] && ! [[ "$scan" =~ (^|[[:space:]])--worktree([[:space:]]|$) ]]; then
      : # --staged without --worktree only unstages; it does not discard working-tree edits.
    else
      deny_reason="destructive-git-guard: git restore targeting . (bare dot) is denied regardless of position, unless --staged is used without --worktree - it discards uncommitted working-tree changes."
    fi
  fi
elif [[ "$scan" =~ ^git[[:space:]]+stash([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])(drop|clear)([[:space:]]|$) ]]; then
    deny_reason="destructive-git-guard: git stash drop/clear permanently deletes stashed changes and is denied."
  fi
elif [[ "$scan" =~ ^git[[:space:]]+filter-branch([[:space:]]|$) ]]; then
  deny_reason="destructive-git-guard: git filter-branch rewrites repository history and is denied."
elif [[ "$scan" =~ ^git[[:space:]]+reflog([[:space:]]|$) ]]; then
  if [[ "$scan" =~ (^|[[:space:]])expire([[:space:]]|$) ]] \
    && [[ "$scan" =~ (^|[[:space:]])--all([[:space:]]|$) ]] \
    && [[ "$scan" =~ (^|[[:space:]])(--expire=now([[:space:]]|$)|--expire-unreachable=now([[:space:]]|$)) ]]; then
    deny_reason="destructive-git-guard: git reflog expire --all --expire=now destroys the recovery safety net other mistakes rely on and is denied."
  fi
fi

[[ -z "$deny_reason" ]] && exit 0

jq -n --arg reason "$deny_reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}' 2>/dev/null || exit 0

exit 0
