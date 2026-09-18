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
#   - git tag --no-sign (overrides tag.gpgsign for one tag, producing an unsigned - and with no
#     -a/-m, lightweight - tag)
#   - git config writing commit.gpgsign or tag.gpgsign to a false value, or core.hooksPath to
#     anything, and --unset/--unset-all/`unset` of any of those keys (a read such as
#     `git config --get commit.gpgsign` is left alone, including when a scope flag trails the key)
#   - a pre-subcommand config override that reproduces one of those flags: commit.gpgsign set to
#     a false value (the documented equivalent of --no-gpg-sign), tag.gpgsign set to a false value
#     (the documented equivalent of git tag --no-sign), or core.hooksPath set at all
#     (the documented equivalent of --no-verify), supplied via `-c k=v`, `-ck=v`,
#     `--config-env=k=VAR`, or GIT_CONFIG_KEY_n/GIT_CONFIG_VALUE_n environment assignments
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
# assignments (`GIT_DIR=... git ...`), command wrappers that take a command as their argument
# (`env`, `time`, `sudo`, `nohup`, `command`, `exec`, `xargs`, `nice`, `ionice`, `stdbuf`, with
# their own dash-options), and git's own pre-subcommand global options (`-C <path>`,
# `-c <k>=<v>`, `--git-dir=`, `--work-tree=`, `--no-pager`, ...) are skipped to find the real
# subcommand, so `git -C /repo push --force` is caught too. Each segment is normalized to a
# canonical `git <subcommand> <args>` string and run through one shared rule set, so the rules
# above are written once and apply to every form.
#
# Quoted substrings (commit messages, etc.) are stripped before matching, so flag text inside a
# quoted message does not false-positive and a real flag placed after a quoted argument is not
# missed either way - both are the same position-independence problem this hook exists to solve.
# Stripping quotes first also means a separator inside a commit message cannot manufacture a bogus
# segment. The two config rules are the exception and run a second time over a copy with the quote
# characters removed but their contents kept: they read a value positionally, so stripping it
# outright made `git config commit.gpgsign "false"` look like a valueless read. That second pass is
# confined to those two rules, which match three fixed key names a commit message cannot reach; see
# scan_segments' mode comment. Every other command falls through silently (exit 0, no output). Fails open (no output,
# exit 0) on missing jq or unparsable input - a broken hook must never block a legitimate tool
# call; see filter-verbose-output.sh's header comment for the same accepted tradeoff.
#
# Known limitation: matching is regex-based on the command string, not a real shell parser, so an
# adversarial rewrite (command substitution, an alias, a wrapper script, a git invocation built
# from variables, or one hidden inside `bash -c "..."` whose quoted body this script strips) is
# not guaranteed to be caught. This raises the bar over prefix-only matching; it is not a sandbox.
# A wrapper whose own arguments are not dash-flags hides the git call from the wrapper skip above
# (`xargs -n 1 git push --force`: the bare `1` is not recognized as an option's value), so that form
# falls through as well.
# GIT_CONFIG_PARAMETERS is not matched: the config collector keys on the *name* of an environment
# assignment, and that variable carries its settings as a payload inside its value rather than as a
# `<key>=<value>` assignment of its own. (Before the dequoted pass above existed, the payload did
# not survive quote-stripping either; that is no longer the reason.) `git config commit.gpgsign
# false` (or the tag.gpgsign equivalent) run as its own command, before a later `git commit` or
# `git tag`, is likewise not matched - the guard sees one command at a time and holds no state
# between calls. Server-side branch protection is the only non-bypassable enforcement for signing;
# this rule closes the ordinary one-liner, not the determined case.
# `git push` has no documented `-d` short form for `--delete` (unlike `git branch -d/-D`), so only
# `--delete` and the `:<branch>` delete-refspec form are matched for remote-branch deletion. A
# bare `git gc --prune=now` (without a preceding `git reflog expire --all --expire=now`) is not
# guarded - gc respects reflog-referenced objects by default, so its risk is secondary to and
# smaller than the reflog-expire case that is guarded. On the tag side only the signing bypass is
# guarded: `git tag -d`/`--delete` and `git tag -f`/`--force` are deliberately left alone, because
# a local tag is cheap to recreate and neither one is the setting this guard backs.

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

# `git config` write rules. Takes the canonical "git config <args>" string and echoes a deny reason
# or nothing. Separate from classify()'s regex rules because `git config` puts the key and its value
# in two adjacent tokens, so the value has to be read positionally rather than matched in place.
# Reads (`git config --get commit.gpgsign`, `git config --list`) are left alone: only a write, or an
# unset that removes the setting, changes what the next commit does. Both git's classic flag forms
# and its newer `get`/`set`/`unset`/`list` subcommand forms are handled.
classify_config_write() {
  local scan="$1" i key val
  local -a t=()
  read -r -a t <<< "$scan" || true

  # Read selectors, tested before anything else. Without this, `git config --get core.hooksPath
  # --global` reads `--global` as the key's value and denies a pure read: the scope flag happens to
  # sit in the slot the value is read from. An --unset never coexists with a read selector, so
  # returning here cannot swallow a write.
  if [[ "$scan" =~ (^|[[:space:]])--(get|get-all|get-regexp|get-urlmatch|list)([[:space:]]|$) ]] ||
    [[ "${t[2]:-}" == "get" || "${t[2]:-}" == "list" ]]; then
    return 0
  fi

  for ((i = 2; i < ${#t[@]}; i++)); do
    key="${t[$i],,}"
    [[ "$key" == "commit.gpgsign" || "$key" == "tag.gpgsign" || "$key" == "core.hookspath" ]] || continue

    # An --unset removes the setting outright. With signing enabled only at the scope being
    # unset, that leaves later commits (or tags) unsigned, so it counts as a write, not a read.
    # `git config unset <key>` is git's newer subcommand spelling of the same operation and is
    # matched too.
    if [[ "$scan" =~ (^|[[:space:]])--unset(-all)?([[:space:]]|$) ]] || [[ "${t[2]:-}" == "unset" ]]; then
      case "$key" in
        commit.gpgsign)
          printf '%s' "destructive-git-guard: unsetting commit.gpgsign via git config removes the signing setting and can leave later commits unsigned; it is denied, the same as --no-gpg-sign." ;;
        tag.gpgsign)
          printf '%s' "destructive-git-guard: unsetting tag.gpgsign via git config removes the tag-signing setting and can leave later tags unsigned - and, for a bare \`git tag <name>\`, lightweight rather than annotated; it is denied, the same as git tag --no-sign." ;;
        *)
          printf '%s' "destructive-git-guard: unsetting core.hooksPath via git config changes which hooks run and is denied, the same as --no-verify." ;;
      esac
      return 0
    fi

    # No token after the key, or a dash-flag rather than a value: a read, not a write.
    val="${t[$((i + 1))]:-}"
    [[ -n "$val" && "$val" != -* ]] || return 0

    if [[ "$key" == "commit.gpgsign" ]]; then
      case "${val,,}" in
        false|0|no|off)
          printf '%s' "destructive-git-guard: git config commit.gpgsign false disables commit signing for every later commit and is denied, the same as --no-gpg-sign."
          return 0 ;;
      esac
      return 0
    fi

    if [[ "$key" == "tag.gpgsign" ]]; then
      case "${val,,}" in
        false|0|no|off)
          printf '%s' "destructive-git-guard: git config tag.gpgsign false disables tag signing for every later tag - and makes a bare \`git tag <name>\` lightweight rather than annotated - and is denied, the same as git tag --no-sign."
          return 0 ;;
      esac
      return 0
    fi

    printf '%s' "destructive-git-guard: git config core.hooksPath redirects the repository's hooks away from the checked-in ones and is denied, the same as --no-verify."
    return 0
  done

  return 0
}

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
  elif [[ "$scan" =~ ^git[[:space:]]+tag([[:space:]]|$) ]]; then
    if [[ "$scan" =~ (^|[[:space:]])--no-sign([[:space:]]|$) ]]; then
      deny_reason="destructive-git-guard: git tag --no-sign overrides tag.gpgsign for this one tag, producing an unsigned - and, with no -a/-m, lightweight - tag; it is denied, the same as git commit --no-gpg-sign."
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
  elif [[ "$scan" =~ ^git[[:space:]]+config([[:space:]]|$) ]]; then
    deny_reason="$(classify_config_write "$scan")"
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

# Config-override rule set. Takes the space-separated pre-subcommand config assignments collected
# for one segment (`k=v` tokens from -c/--config-env, plus leading environment assignments) and
# echoes a deny reason or nothing. Applied regardless of subcommand: `git -c commit.gpgsign=false
# status` has no legitimate use either, and enumerating every subcommand the setting bites would be
# a list to keep in step with git rather than a rule.
classify_config() {
  local cfg="$1" tok key val n k v t2 noun equiv
  local -a pairs=() raw=()

  # Nothing collected: return before touching an empty array, which is an unbound-variable error
  # under `set -u` on bash < 4.4 and would abort the whole script under `set -e`.
  # `return 0`, not a bare `return`: the caller assigns this function's output in a command
  # substitution, so a nonzero status would propagate to the assignment and `set -e` would abort
  # the script mid-scan - failing closed and silently, the one thing this guard must never do.
  [[ -n "${cfg//[[:space:]]/}" ]] || return 0

  # Split with `read -r -a` rather than an unquoted `for tok in $cfg`: word splitting is wanted
  # here, pathname expansion is not, and a config value may legitimately contain a glob character.
  read -r -a raw <<< "$cfg" || true

  for tok in "${raw[@]}"; do
    if [[ "$tok" =~ ^GIT_CONFIG_KEY_([0-9]+)=(.*)$ ]]; then
      # GIT_CONFIG_KEY_n names the key; its value lives in the separately-assigned
      # GIT_CONFIG_VALUE_n, so pair them by index rather than reading either alone.
      n="${BASH_REMATCH[1]}"
      k="${BASH_REMATCH[2]}"
      v=""
      for t2 in "${raw[@]}"; do
        [[ "$t2" == "GIT_CONFIG_VALUE_${n}="* ]] && v="${t2#GIT_CONFIG_VALUE_"${n}"=}"
      done
      pairs+=("$k=$v")
    else
      pairs+=("$tok")
    fi
  done

  for tok in "${pairs[@]}"; do
    [[ "$tok" == *=* ]] || continue
    key="${tok%%=*}"
    val="${tok#*=}"
    case "${key,,}" in
      commit.gpgsign | tag.gpgsign)
        # Both signing keys take the same shape, so they share one branch; only the noun and the
        # flag each one is equivalent to differ.
        if [[ "${key,,}" == "tag.gpgsign" ]]; then
          noun="tag"
          equiv="git tag --no-sign"
        else
          noun="commit"
          equiv="--no-gpg-sign"
        fi
        # @env marks a --config-env key whose value sits in an environment variable this script
        # cannot read. Deny rather than guess: a one-shot indirection of exactly this key is not
        # something a legitimate commit or tag needs.
        if [[ "$val" == "@env" ]]; then
          printf '%s' "destructive-git-guard: git --config-env=${key}=VAR hides the signing setting in an environment variable and is denied, the same as ${equiv}."
          return 0
        fi
        case "${val,,}" in
          false|0|no|off|"")
            printf '%s' "destructive-git-guard: setting ${key} to a false value via a config override produces an unsigned ${noun} and is denied, the same as ${equiv}."
            return 0 ;;
        esac ;;
      core.hookspath)
        printf '%s' "destructive-git-guard: overriding core.hooksPath redirects the repository's hooks away from the checked-in ones and is denied, the same as --no-verify."
        return 0 ;;
    esac
  done

  return 0
}

deny_reason=""

# Quote characters removed but the quoted contents kept, unlike $stripped above. Used only for the
# config-only pass below; see scan_segments' mode comment for why the distinction matters.
dequoted="$(printf '%s' "$cmd" | tr -d "\"'")"

# Walks one command string: splits it into segments and runs the rule sets over each. Sets the
# global deny_reason and stops at the first rule that fires.
#
# mode "all" runs every rule, over the quote-stripped text, where flag-shaped text inside a commit
# message cannot survive to cause a false positive.
#
# mode "config-only" runs just the two config rules, over $dequoted. It exists because those rules
# read a config value *positionally* rather than matching a token in place, so quote-stripping
# deletes the value outright and leaves the slot looking empty - which the read-vs-write test then
# reads as a read. Without this pass, `git config commit.gpgsign "false"` and
# `git -c "commit.gpgsign=false" commit` are both allowed. The pass is restricted to the config
# rules precisely because its input still contains quoted contents: those rules match three fixed
# key names, so a commit message cannot reach them, whereas every other rule could be tripped by
# flag-shaped text inside a quoted argument.
scan_segments() {
  local text="$1" mode="$2"
  local segment seg before reason cfgtoks cfgenv sub idx
  local -a toks=()

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

    # Pre-subcommand config assignments seen while walking to the git subcommand. Collected rather
    # than discarded: `-c commit.gpgsign=false` is the documented equivalent of a flag this guard
    # already denies, so the skip loops below must hand these on instead of dropping them.
    cfgtoks=""

    # Drop whatever stands between the start of the segment and the git call: leading environment
    # assignments (`GIT_DIR=/tmp/x git branch -D main`) and command wrappers that take a command as
    # their argument (`env git ...`, `time git ...`, `xargs git push --force`). The two can interleave
    # (`env FOO=1 git ...`), so this loops until the front of the segment stops changing. Stripping a
    # wrapper can only ever expose a git call that would otherwise have been missed; it cannot cause a
    # false deny, because whatever follows a wrapper still has to pass the `git` test below.
    while :; do
      before="$seg"
      while [[ "$seg" =~ ^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)[[:space:]]+(.*)$ ]]; do
        cfgtoks+=" ${BASH_REMATCH[1]}"
        seg="${BASH_REMATCH[2]}"
      done
      if [[ "$seg" =~ ^(sudo|env|time|nohup|command|exec|xargs|nice|ionice|stdbuf)([[:space:]]+-[^[:space:]]+)*[[:space:]]+(.*)$ ]]; then
        seg="${BASH_REMATCH[3]}"
      fi
      if [[ "$seg" == "$before" ]]; then
        break
      fi
    done

    [[ "$seg" =~ ^git([[:space:]]|$) ]] || continue

    # Skip git's pre-subcommand global options to find the real subcommand. Options that take a
    # separate value consume two tokens; any other leading `-` token consumes one.
    read -r -a toks <<< "${seg#git}" || true
    idx=0
    sub=""
    while (( idx < ${#toks[@]} )); do
      case "${toks[$idx]}" in
        -c)
          cfgtoks+=" ${toks[$((idx + 1))]:-}"
          idx=$((idx + 2)) ;;
        --config-env)
          # The value is an environment variable name, not the setting's value; record the key with
          # an @env marker so the rules can see the key without pretending to know the value.
          cfgenv="${toks[$((idx + 1))]:-}"
          cfgtoks+=" ${cfgenv%%=*}=@env"
          idx=$((idx + 2)) ;;
        -c?*)
          cfgtoks+=" ${toks[$idx]#-c}"
          idx=$((idx + 1)) ;;
        --config-env=*)
          cfgenv="${toks[$idx]#--config-env=}"
          cfgtoks+=" ${cfgenv%%=*}=@env"
          idx=$((idx + 1)) ;;
        -C|--exec-path|--git-dir|--work-tree|--namespace|--super-prefix)
          idx=$((idx + 2)) ;;
        -*)
          idx=$((idx + 1)) ;;
        *)
          sub="${toks[$idx]}"; break ;;
      esac
    done
    reason="$(classify_config "$cfgtoks")"
    if [[ -n "$reason" ]]; then
      deny_reason="$reason"
      break
    fi

    [[ -n "$sub" ]] || continue

    # In config-only mode only the `git config` write rule runs; see the mode comment above.
    if [[ "$mode" == "config-only" ]]; then
      [[ "$sub" == "config" ]] || continue
      reason="$(classify_config_write "git ${toks[*]:$idx}")"
    else
      reason="$(classify "git ${toks[*]:$idx}")"
    fi
    if [[ -n "$reason" ]]; then
      deny_reason="$reason"
      break
    fi
  done < <(printf '%s' "$text" \
    | sed -E 's/[0-9]*>&[0-9]+//g; s/&>>?/ /g' \
    | sed -E 's/[;&|()]+/\n/g')
  # Explicit, not incidental: under `set -e` a function whose last command returned nonzero would
  # abort the script, and the while loop's status is whatever its body last produced.
  return 0
}

scan_segments "$stripped" all
[[ -n "$deny_reason" ]] || scan_segments "$dequoted" config-only


[[ -z "$deny_reason" ]] && exit 0

jq -n --arg reason "$deny_reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}' 2>/dev/null || exit 0

exit 0
