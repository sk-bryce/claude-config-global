#!/usr/bin/env bash
#
# run.sh - assertion suite for ../destructive-git-guard.sh.
#
# Why this exists as a tracked harness rather than an ad-hoc one retyped per change: the guard
# fails open by design (see specs/behaviors.md's Destructive Git Guard section), which means a
# completely broken guard and a working one are indistinguishable on every allowed command - both
# emit nothing and exit 0. Nothing surfaces the difference at runtime. On 2026-09-13 the guard was
# found to have been inspecting only commands whose string began literally with `git <subcommand>`,
# so every rule in it was bypassable by moving the git call off the front (`cd repo && git push
# --force`, `git -C repo push --force`, ...). The rewrite that fixed that then introduced two
# further defects, each of which silently disabled the whole script again, and each of which was
# caught only by running cases like these. Reading the regexes is not sufficient evidence about
# this script; running it is.
#
# Unlike scripts/statusline-tests/, there are no fixture files: a case here is a single command
# string plus an expected verdict, so checking them in as separate files would add indirection
# without adding coverage. The cases are inline below, grouped and labeled by the acceptance
# criterion in specs/behaviors.md that each one pins. Those criteria and this file are meant to
# stay in step - if you add a rule to the guard, add the criterion there and the case here.
#
# Usage:
#   scripts/git-guard-tests/run.sh              # test ../destructive-git-guard.sh
#   scripts/git-guard-tests/run.sh <path>       # test a specific copy (e.g. one in a worktree)
#
# Exit status: 0 = every case passed, 1 = at least one failed, 2 = the harness could not run
# (missing jq, or the guard script is not where it was expected). A harness that cannot run must
# not report success - that is the one place this suite deliberately does NOT fail open.

set -uo pipefail

GUARD="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../destructive-git-guard.sh}"

if ! command -v jq >/dev/null 2>&1; then
  echo "git-guard-tests: jq is required to build hook payloads; cannot run." >&2
  exit 2
fi
if [[ ! -f "$GUARD" ]]; then
  echo "git-guard-tests: guard script not found at $GUARD" >&2
  exit 2
fi

pass=0
fail=0

# Emits the guard's decision for one command string: "deny" or "allow".
decide() {
  local out
  out="$(jq -n --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}' \
    | bash "$GUARD" 2>/dev/null)"
  if [[ -z "$out" ]]; then
    printf 'allow'
    return
  fi
  printf '%s' "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || printf 'allow')"
}

label() { printf '\n  %s\n' "$1"; }

# assert <deny|allow> <command>
assert() {
  local want="$1" cmd="$2" got disp
  got="$(decide "$cmd")"
  if [[ "$got" == "$want" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    # Render embedded newlines as literal \n so a multi-line case stays one grep-able FAIL line.
    disp="${cmd//$'\n'/\\n}"
    printf '    FAIL  want=%-5s got=%-5s  %s\n' "$want" "$got" "$disp"
  fi
}

# assert_silent <description> -- <command to run, fed to the guard>
# For robustness cases: asserts the guard emits nothing and exits 0, whatever the input.
assert_silent() {
  local desc="$1" out rc
  shift
  out="$("$@" 2>/dev/null)"
  rc=$?
  if [[ -z "$out" && $rc -eq 0 ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '    FAIL  %s: expected no output and exit 0, got exit %d and %q\n' "$desc" "$rc" "$out"
  fi
}

printf 'git-guard-tests: %s\n' "$GUARD"

label "force-push, matched regardless of flag position"
assert deny "git push --force upstream main"
assert deny "git push origin main --force"
assert deny "git push origin main -f"
assert deny "git push --force-with-lease origin main"

label "position of the git call in the command string does not matter"
assert deny "cd repo && git push --force upstream main"
assert deny "true; git reset --hard HEAD~1"
assert deny "git status | head && git clean -fd"
assert deny "(git stash drop)"
assert deny "$(printf 'cd repo\ngit push --force upstream main')"
assert deny "$(printf 'git status\ngit reset --hard\necho done')"
assert allow "cd /repo && git status"
assert allow "$(printf 'git status\ngit log --oneline\ngit diff')"

label "git's pre-subcommand global options are skipped, not treated as the subcommand"
assert deny "git -C repo push --force origin main"
assert deny "git -c user.name=x push --force origin main"
assert deny "git --no-pager -C repo push -f origin main"
assert deny "git -C repo -c user.name=x push --force origin main"
assert allow "git -C repo status"
assert allow "git -C repo -c user.name=x status"

label "leading environment assignments are skipped"
assert deny "GIT_DIR=/tmp/x git branch -D main"

label "command wrappers that take a command as their argument are skipped"
assert deny "time git push --force origin main"
assert deny "env git push --force origin main"
assert deny "env FOO=1 git push --force origin main"
assert deny "sudo git push --force origin main"
assert deny "nohup git reset --hard HEAD~1"
assert deny "echo main | xargs git push --force origin"
assert deny "command git branch -D feature"
assert deny "env -i GIT_DIR=/tmp/x git stash drop"
assert allow "time git status"
assert allow "env git status"
assert allow "sudo apt-get install git"
# Not covered: a wrapper option whose value is not a dash-token hides the git call. Asserted as
# `allow` so the limitation is visible here rather than mistaken for coverage; see the guard's
# header comment.
assert allow "xargs -n 1 git push --force origin"

label "a leading + on a refspec is a force-update"
assert deny "git push upstream +main"
assert deny "git push upstream +refs/tags/v0.1.4:refs/tags/v0.1.4"
assert deny "git -C repo push upstream +v0.1.4"
assert allow "git push upstream HEAD:main"

label "redirections do not split a command away from its own flags"
assert deny "git push --force upstream main 2>&1 | tee /tmp/log"

label "combined and split flag clusters"
assert deny "git clean -fd"
assert deny "git clean -df"
assert deny "git branch -D feature"
assert deny "git branch --delete --force feature"
assert allow "git clean -n"
assert allow "git branch -d merged-branch"

label "bare-dot targets"
assert deny "git checkout ."
assert deny "git checkout -- ."
assert deny "git checkout HEAD -- ."
assert deny "git restore ."
assert deny "git restore --staged --worktree ."
assert allow "git restore --staged ."
assert allow "git checkout main"
assert allow "git checkout -b newbranch"

label "remote-branch deletion"
assert deny "git push --delete upstream v0.1.4"
assert deny "git push origin --delete somebranch"
assert deny "git push origin :somebranch"
assert allow "git push origin HEAD:refs/heads/main"

label "history- and recovery-destroying commands"
assert deny "git stash drop"
assert deny "git stash clear"
assert deny "git filter-branch --tree-filter x HEAD"
assert deny "git reflog expire --all --expire=now"
assert deny "git reflog expire --expire=now --all"
assert allow "git stash list"
assert allow "git stash show"
assert allow "git reflog expire --expire=now"
assert allow "git reflog show"
assert allow "git gc --prune=now"

label "commit flags"
assert deny "git commit --no-verify -m hello"
assert deny "git commit --no-gpg-sign -m hello"
assert deny "git rebase -i HEAD~3"
assert allow "git commit -m hello"
assert allow "git rebase main"

label "config overrides that reproduce a denied flag"
assert deny "git -c commit.gpgsign=false commit -m hello"
assert deny "git -c commit.gpgSign=0 commit -m hello"
assert deny "git -c commit.gpgsign=no commit -m hello"
assert deny "git -c commit.gpgsign=off commit -m hello"
assert deny "git -ccommit.gpgsign=false commit -m hello"
assert deny "git --config-env=commit.gpgsign=NOPE commit -m hello"
assert deny "git --config-env commit.gpgsign=NOPE commit -m hello"
assert deny "git -c core.hooksPath=/dev/null commit -m hello"
assert deny "cd repo && git -c commit.gpgsign=off commit -m hello"
assert deny "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false git commit -m hello"
assert deny "GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=x GIT_CONFIG_KEY_1=commit.gpgsign GIT_CONFIG_VALUE_1=false git commit -m hello"
assert allow "git -c commit.gpgsign=true commit -m hello"
assert allow "git -c user.name=x commit -m hello"
assert allow "git -c commit.gpgsignoff=false commit -m hello"
assert allow "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=x git commit -m hello"
assert allow "git commit -m 'stop setting commit.gpgsign=false in CI'"
# Pins the two ways the config collector can break the scan rather than a rule: a glob character
# in a config value (pathname expansion during splitting) and no config tokens at all (an empty
# array under set -u). Both must leave the rest of the rules working, so each pairs with a
# guarded command that still has to be denied.
assert allow "git -c core.pager=* status"
assert deny "git -c core.pager=* push --force origin main"
assert deny "git push --force origin main"

label "git config writes that disable signing or redirect hooks"
assert deny "git config commit.gpgsign false"
assert deny "git config --global commit.gpgsign false"
assert deny "git config --local commit.gpgSign 0"
assert deny "git config --global commit.gpgsign off"
assert deny "git config --global commit.gpgsign no"
assert deny "git config set commit.gpgsign false"
assert deny "git config --global --unset commit.gpgsign"
assert deny "git config --unset-all commit.gpgsign"
assert deny "git config core.hooksPath /dev/null"
assert deny "cd repo && git config commit.gpgsign false"
assert deny "GIT_DIR=/tmp/x git config commit.gpgsign false"
# git's newer subcommand spelling of --unset, which no flag regex catches.
assert deny "git config unset commit.gpgsign"
assert deny "git config unset --global core.hooksPath"
# Reads must stay allowed: a guard that blocks `git config --get` blocks routine inspection.
assert allow "git config --global commit.gpgsign true"
assert allow "git config --get commit.gpgsign"
assert allow "git config get commit.gpgsign"
assert allow "git config --get core.hooksPath"
assert allow "git config --list"
# The value is read positionally, so a read whose key is *not* the last token used to hand the
# rule a scope flag as the value. These pin that a dash-flag in the value slot is not a value.
assert allow "git config --get core.hooksPath --global"
assert allow "git config --get-all core.hooksPath --global"
assert allow "git config --get core.hooksPath --show-origin"
assert allow "git config list --show-origin"
assert allow "git config --global user.name x"
assert allow "git config commit.gpgsignoff false"

label "quoting the value does not hide a config write"
# Quoted substrings are stripped before matching, which is what keeps a commit message from
# tripping the other rules - but the config rules read their value positionally, so stripping it
# left the slot empty and the write read as a harmless read. A second pass over a dequoted copy
# closes that; these pin it, and the quoted-message allow cases below pin that the second pass did
# not cost the protection the stripping exists to provide.
assert deny "git config --global commit.gpgsign \"false\""
assert deny "git config --global commit.gpgsign 'false'"
assert deny "git config commit.gpgsign \"off\""
assert deny "git config core.hooksPath \"/dev/null\""
assert deny "git config \"commit.gpgsign\" false"
assert deny "git -c \"commit.gpgsign=false\" commit -m x"
assert deny "git -c 'core.hooksPath=/dev/null' commit -m x"
assert allow "git config --get-regexp \"core.hooksPath\""
assert allow "git config user.name \"Jane core.hooksPath\""
assert allow "git log --grep=\"commit.gpgsign false\""
assert allow "echo \"git config core.hooksPath /x\" >> notes.txt"
assert allow "git commit -m \"document git config core.hooksPath usage\""

label "flag-shaped text inside quoted messages is not a flag"
assert allow "git commit -m 'fix -n flag handling'"
assert allow "git stash push -m 'clear old test data'"
assert allow "git commit -m \"do not use git push --force here\""

label "non-git commands that merely mention a guarded flag"
assert allow "cat notes.md | grep 'git push --force'"
assert allow "echo 'git push --force' >> notes.txt"
assert allow "ls -la && echo done"

label "everyday git passes through"
assert allow "git status --porcelain"
assert allow "git push origin main"
assert allow "git push -u upstream integrate"
assert allow "git log --oneline -10"
assert allow "git log --format='%h|%s' | head"
assert allow "git worktree add .worktrees/x -b x main"
assert allow "git tag -d v0.1.4"
assert allow "git tag -s v0.1.4 -m msg main"
assert allow "git add -A"
assert allow "git fetch upstream"

label "a command with no shell separator at all is still inspected"
# Standing regression test for the no-trailing-newline defect: a bare `read` discarded the only
# segment of any separator-free command, which silently disabled every rule above. The assertions
# in this file are dense with separator-free commands precisely so this cannot regress quietly,
# but it is named here so the reason is not lost.
assert deny "git push --force upstream main"
assert allow "git status"

label "robustness: the guard fails open, quietly, on anything it cannot parse"
assert_silent "unparsable stdin" bash -c "printf 'not json at all' | bash '$GUARD'"
assert_silent "empty stdin" bash -c "printf '' | bash '$GUARD'"
assert_silent "non-Bash tool_name" bash -c \
  "jq -n '{tool_name:\"Read\",tool_input:{command:\"git push --force origin main\"}}' | bash '$GUARD'"

# jq genuinely absent. Build a stub PATH holding the utilities the guard needs EXCEPT jq. Do not
# simulate this by clearing PATH wholesale: that removes bash itself, so the test would "pass" on a
# command-not-found error while proving nothing about the guard.
stub="$(mktemp -d)"
for b in bash sed cat env printf; do
  p="$(command -v "$b")" && ln -sf "$p" "$stub/$b"
done
if PATH="$stub" command -v jq >/dev/null 2>&1; then
  printf '    FAIL  jq-absent case: stub PATH still resolves jq; case proves nothing\n'
  fail=$((fail + 1))
else
  assert_silent "jq absent from PATH" env PATH="$stub" "$stub/bash" "$GUARD" <<<'{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}'
fi
rm -rf "$stub"

printf '\n  passed: %d   failed: %d   total: %d\n\n' "$pass" "$fail" "$((pass + fail))"
[[ $fail -eq 0 ]] || exit 1
exit 0
