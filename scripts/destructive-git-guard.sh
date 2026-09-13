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
#   - git push --force/-f (including --force-with-lease), a leading `+` on any refspec (the
#     documented equivalent of --force for that ref), or --delete/a :<branch> delete refspec
#     (removes a remote branch)
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
#
# Where the git call may sit in the command string: anywhere, not just at the start. The command
# is split on shell separators (`;` `&&` `||` `|` `&` and subshell parens) and every resulting
# segment is inspected independently, so `cd /repo && git push --force` and `true; git reset
# --hard` are caught exactly as the bare forms are. Within a segment, leading environment
# assignments (`GIT_DIR=... git ...`) and git's own pre-subcommand global options (`-C <path>`,
# `-c <k>=<v>`, `--git-dir=`, `--work-tree=`, `--no-pager`, ...) are skipped to find the real
# subcommand, so `git -C /repo push --force` is caught too. Each segment is normalized to a
# canonical `git <subcommand> <args>` string and run through one shared rule set, so the rules
# above are written once and apply to every form.
#
# Quoted substrings (commit messages, etc.) are stripped before matching, so flag text inside a
# quoted message does not false-positive and a real flag placed after a quoted argument is not
# missed either way - both are the same position-independence problem this hook exists to solve.
# Stripping quotes first also means a separator inside a commit message cannot manufacture a bogus
# segment. Every other command falls through silently (exit 0, no output). Fails open (no output,
# exit 0) on missing jq or unparsable input - a broken hook must never block a legitimate tool
# call; see filter-verbose-output.sh's header comment for the same accepted tradeoff.
#
# Known limitation: matching is regex-based on the command string, not a real shell parser, so an
# adversarial rewrite (command substitution, an alias, a wrapper script, a git invocation built
# from variables, or one hidden inside `bash -c "..."` whose quoted body this script strips) is
# not guaranteed to be caught. This raises the bar over prefix-only matching; it is not a sandbox.
# `git push` has no documented `-d` short form for `--delete` (unlike `git branch -d/-D`), so only
# `--delete` and the `:<branch>` delete-refspec form are matched for remote-branch deletion. A
# bare `git gc --prune=now` (without a preceding `git reflog expire --all --expire=now`) is not
# guarded - gc respects reflog-referenced objects by default, so its risk is secondary to and
# smaller than the reflog-expire case that is guarded.

set -euo pipefail

payload="$(cat)"

tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
[[ "$tool" != "Bash" ]] && exit 0

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"
[[ -z "$cmd" ]] && exit 0

# Strip quoted substrings (commit messages, etc.) before any matching or splitting, so a
# flag-shaped or separator-shaped token inside quoted text can't false-positive, and a real flag
# after a quoted argument isn't missed.
stripped="$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g" | sed -E 's/"[^"]*"//g')"

# Cheap bail-out for the overwhelmingly common non-git command. Deliberately a plain substring
# test rather than a word-boundary regex: this is only a fast path, and the precise decision is
# made per segment below. A stricter test here can only ever cause a false negative - an earlier
# revision anchored on whitespace and so missed `(git stash drop)`, where `git` follows a paren.
[[ "$stripped" == *git* ]] || exit 0

# Rule set. Takes one canonical "git <subcommand> <args>" string, echoes a deny reason or nothing.
classify() {
  local scan="$1"
  local deny_reason=""

  if [[ "$scan" =~ ^git[[:space:]]+push([[:space:]]|$) ]]; then
    if [[ "$scan" =~ (^|[[:space:]])(--force([[:space:]]|-|$)|-f([[:space:]]|$)) ]]; then
      deny_reason="destructive-git-guard: git push --force/-f is denied regardless of flag position."
    elif [[ "$scan" =~ (^|[[:space:]])\+[^[:space:]]+ ]]; then
      deny_reason="destructive-git-guard: git push with a leading + on a refspec (e.g. +refs/tags/x:refs/tags/x) force-updates the remote ref and is denied, the same as --force."
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

  printf '%s' "$deny_reason"
}

deny_reason=""

# Split on shell separators and inspect each segment independently, so a git call that is not the
# first command in the string is still seen. Runs of separators collapse; empty segments are
# skipped. Over-splitting is safe: it can only produce segments that fail the `git` test below.
# File-descriptor redirections (`2>&1`, `>&2`, `&>log`) are removed before the split, because
# their `&` would otherwise cut a command in half and strand any flag that followed it.
# `|| [[ -n "$segment" ]]` is required, not stylistic: the input has no trailing newline, so a
# command with no separators at all arrives as one unterminated line and a bare `read` would
# return non-zero and skip it entirely - silently disabling every rule for the common case.
while IFS= read -r segment || [[ -n "$segment" ]]; do
  [[ -n "${segment//[[:space:]]/}" ]] || continue

  # Trim leading whitespace.
  seg="${segment#"${segment%%[![:space:]]*}"}"

  # Drop leading environment assignments: `GIT_DIR=/tmp/x git branch -D main`.
  while [[ "$seg" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
    seg="${BASH_REMATCH[1]}"
  done

  [[ "$seg" =~ ^git([[:space:]]|$) ]] || continue

  # Skip git's pre-subcommand global options to find the real subcommand. Options that take a
  # separate value consume two tokens; any other leading `-` token consumes one.
  read -r -a toks <<< "${seg#git}" || true
  idx=0
  sub=""
  while (( idx < ${#toks[@]} )); do
    case "${toks[$idx]}" in
      -C|-c|--exec-path|--git-dir|--work-tree|--namespace|--super-prefix|--config-env)
        idx=$((idx + 2)) ;;
      -*)
        idx=$((idx + 1)) ;;
      *)
        sub="${toks[$idx]}"; break ;;
    esac
  done
  [[ -n "$sub" ]] || continue

  reason="$(classify "git ${toks[*]:$idx}")"
  if [[ -n "$reason" ]]; then
    deny_reason="$reason"
    break
  fi
done < <(printf '%s' "$stripped" \
  | sed -E 's/[0-9]*>&[0-9]+//g; s/&>>?/ /g' \
  | sed -E 's/[;&|()]+/\n/g')

[[ -z "$deny_reason" ]] && exit 0

jq -n --arg reason "$deny_reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}' 2>/dev/null || exit 0

exit 0
