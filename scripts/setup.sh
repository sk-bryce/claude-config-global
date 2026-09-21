#!/usr/bin/env bash
#
# setup.sh - bring a fresh clone or a new machine up to the state this repository expects but
# cloning cannot produce: the git hook registrations, and the machine-local scrub pattern and
# scrub self-test fixture files. Everything else in this repo travels with the clone.
#
# FOR A HUMAN TO RUN, NOT AN AGENT. This script performs hook registration, which
# decisions/0003-hooks-and-scripts-authoring-policy.md requires be the repository owner's explicit,
# in-the-moment act - never an agent's, never proactively, never on the strength of a prior
# registration. A human typing `scripts/setup.sh` IS that explicit direction; an agent deciding to
# run it is precisely what that policy forbids. Use --check (read-only) to inspect state instead.
#
# Idempotent: every action is skipped when already satisfied, and re-running a completed setup
# changes nothing and exits 0. It never overwrites a hook it did not write - an unrecognized hook
# is reported and left alone, because a hand-tuned registration (extra arguments, a second command)
# is more valuable than this script's default.
#
# Usage:
#   scripts/setup.sh              install anything missing; prompt for scrub patterns and scrub
#                                 test fixtures only if their files do not exist yet
#   scripts/setup.sh --check      report what is missing and change NOTHING; exit 1 if incomplete
#   scripts/setup.sh --scrub      also (re)collect scrub patterns and scrub test fixture lines even
#                                 if their files already exist; appends to them, never truncates
#   scripts/setup.sh --repo <dir> [--with-scrub]
#                                 register ONLY the commit-msg gate in the repository containing
#                                 <dir>, pointing back at this checkout's commit-msg-check.sh. For
#                                 another repository you work in - the trailer rule is universal,
#                                 not something this repository needs for itself. --with-scrub adds
#                                 the public-remote scan of the message, which is off by default
#                                 because that ruleset is written for THIS repository's remote.
#                                 Combines with --check to report without writing.
#   scripts/setup.sh --help
#
# WHY --repo REGISTERS INTO SOMEONE ELSE'S REPOSITORY AT ALL: reference/public-repo-hygiene.md has
# a borrower install the pre-commit line by hand, on the reasoning that registering a hook in a
# repository is its owner's act. That reasoning is unchanged and this does not weaken it - the
# owner typing `setup.sh --repo ~/src/thing` IS that act, the same way typing `setup.sh` is. What
# stays forbidden is an agent running either one; decisions/0003's guard is about who decides, not
# whose fingers move. A command beats a hand-copied line only because a copy drifts silently.
#
# Exit: 0 setup complete (or completed by this run), 1 incomplete (--check only, or a step the
#       script cannot finish non-interactively), 2 usage or environment error.

set -uo pipefail  # not -e: a failed step must still let the remaining steps run and report.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 2
cd "$REPO_ROOT" || exit 2

PATTERN_FILE="scrub-patterns.local"
TEST_FILE="scrub-test.local"
HOOK_DIR=".git/hooks"

mode="install"
want_scrub=0
BORROW_TARGET=""
saw_borrow=0
borrow_scrub=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) mode="check" ;;
    --scrub) want_scrub=1 ;;
    # Both spellings, matching every other script here. Validated after the loop: a missing value,
    # an empty one, and a trailing --repo are the same mistake and deserve one message.
    --repo) saw_borrow=1; BORROW_TARGET="${2-}"; [[ $# -gt 1 ]] && shift ;;
    --repo=*) saw_borrow=1; BORROW_TARGET="${1#--repo=}" ;;
    --with-scrub) borrow_scrub=1 ;;
    # 2,43 is the header comment block exactly - one line further and --help prints the
    # `set -uo pipefail` line as if it were documentation.
    -h|--help) sed -n '2,43p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "setup.sh: unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$saw_borrow" -eq 1 && -z "$BORROW_TARGET" ]]; then
  echo "setup.sh: --repo needs a directory argument" >&2
  exit 2
fi

if [[ "$borrow_scrub" -eq 1 && "$saw_borrow" -eq 0 ]]; then
  echo "setup.sh: --with-scrub only means something alongside --repo (try --help)" >&2
  exit 2
fi

# --scrub collects THIS repository's pattern and fixture lines; --repo touches nothing but another
# repository's hook. Honouring both in one run would report on two repositories at once and make
# the [ok]/[MISSING] lines ambiguous about which one they describe.
if [[ "$saw_borrow" -eq 1 && "$want_scrub" -eq 1 ]]; then
  echo "setup.sh: --scrub and --repo are separate jobs - run them one at a time (try --help)" >&2
  exit 2
fi

# --- 0. borrowed-repository registration ---------------------------------------------------------
# Handled here, before every check below, because those all ask about THIS checkout: its .git
# directory, its hooks, its scrub files. This mode is about somebody else's repository and shares
# none of that state, so it answers, reports, and exits rather than threading a second target
# through the rest of the script.
if [[ "$saw_borrow" -eq 1 ]]; then
  checker="$REPO_ROOT/scripts/commit-msg-check.sh"
  if [[ ! -x "$checker" ]]; then
    echo "setup.sh: $checker is missing or not executable - nothing to register" >&2
    exit 2
  fi

  # git resolves the argument, so any path inside the target works, and both failure shapes - a
  # path that does not exist, and one in no checkout at all - become exit 2 rather than a hook
  # written somewhere surprising.
  target_root="$(git -C "$BORROW_TARGET" rev-parse --show-toplevel 2>/dev/null)" || target_root=""
  if [[ -z "$target_root" ]]; then
    echo "setup.sh: --repo is not a readable path inside a git checkout: $BORROW_TARGET" >&2
    exit 2
  fi

  if [[ "$target_root" == "$REPO_ROOT" ]]; then
    echo "setup.sh: that is this repository - run scripts/setup.sh with no --repo to set it up" >&2
    exit 2
  fi

  target_hooks_path="$(git -C "$target_root" config --get core.hooksPath 2>/dev/null || true)"
  if [[ -n "$target_hooks_path" ]]; then
    echo "setup.sh: $target_root sets core.hooksPath to '$target_hooks_path', so .git/hooks is NOT used." >&2
    echo "setup.sh: unset it there, or install the hook into that directory by hand." >&2
    exit 2
  fi

  # --git-common-dir, not --show-toplevel/.git: a linked worktree's hooks live in the main .git,
  # and writing into the worktree's own .git file would install a hook that never runs.
  target_common="$(git -C "$target_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || target_common=""
  if [[ -z "$target_common" ]]; then
    echo "setup.sh: could not locate the git directory for $target_root" >&2
    exit 2
  fi
  target_hook="$target_common/hooks/commit-msg"

  echo "Commit-message gate for $target_root"
  echo

  if [[ -f "$target_hook" ]]; then
    if grep -q 'commit-msg-check\.sh' "$target_hook" 2>/dev/null; then
      printf '  [ok]      commit-msg -> %s\n' "$checker"
      if [[ "$borrow_scrub" -eq 1 ]] && ! grep -q -- '--scrub' "$target_hook" 2>/dev/null; then
        printf '  %s\n' "registered without --scrub; edit $target_hook by hand to add it"
      fi
      [[ -x "$target_hook" ]] || { chmod +x "$target_hook" && printf '  [done]    made commit-msg executable\n'; }
      exit 0
    fi
    # Never overwritten: a hook somebody else wrote is more valuable than this one's default, and
    # a commit-msg hook that already exists is usually enforcing a message convention.
    printf '  [warn]    commit-msg exists and does not call commit-msg-check.sh - left untouched\n'
    printf '  %s\n' "review $target_hook by hand; the line to add is:"
    printf '  %s\n' "exec \"$checker\" --repo \"\$(git rev-parse --show-toplevel)\" \"\$@\""
    exit 1
  fi

  if [[ "$mode" == "check" ]]; then
    printf '  [MISSING] commit-msg hook (a Co-Authored-By trailer would not be caught here)\n'
    exit 1
  fi

  scrub_arg=""
  [[ "$borrow_scrub" -eq 1 ]] && scrub_arg=" --scrub"

  # Unquoted heredoc: $REPO_ROOT and the --scrub choice are resolved now, at registration time,
  # while the escaped forms stay in the hook for git to expand on each commit.
  cat > "$target_hook" <<HOOK
#!/usr/bin/env bash
#
# Local-only registration for $checker, written by
# \`$REPO_ROOT/scripts/setup.sh --repo\`. Not tracked by git, so it needs reinstalling on a fresh
# clone of this repository.
#
# The config repository is named by absolute path because this repository holds no copy of the
# checker - borrowing the detector rather than copying it is what keeps the two from drifting. If
# that path moves, exec fails, the hook exits non-zero, and the commit stops: a message gate that
# cannot run must not pass a message it never read.
exec "$checker" --repo "\$(git rev-parse --show-toplevel)"$scrub_arg "\$@"
HOOK
  chmod +x "$target_hook"
  printf '  [done]    installed commit-msg -> %s%s\n' "$checker" "${scrub_arg:+ (with --scrub)}"
  echo
  echo "Commits in $target_root are now checked for a Co-Authored-By trailer."
  echo "This registration is local to that clone; git commit --no-verify bypasses it."
  exit 0
fi

if [[ ! -d .git ]]; then
  # A linked worktree has a .git FILE, and its hooks live in the main checkout - installing here
  # would silently do nothing useful.
  if [[ -f .git ]]; then
    echo "setup.sh: this is a linked worktree; run setup in the main checkout instead" >&2
  else
    echo "setup.sh: no .git here - run this from a clone of the config repository" >&2
  fi
  exit 2
fi

hooks_path="$(git config --get core.hooksPath 2>/dev/null || true)"
if [[ -n "$hooks_path" ]]; then
  echo "setup.sh: core.hooksPath is set to '$hooks_path', so $HOOK_DIR is NOT used." >&2
  echo "setup.sh: unset it (git config --unset core.hooksPath) or install hooks there by hand." >&2
  exit 2
fi

missing=0
note()   { printf '  %s\n' "$*"; }
ok()     { printf '  [ok]      %s\n' "$*"; }
todo()   { printf '  [MISSING] %s\n' "$*"; missing=1; }
warn()   { printf '  [warn]    %s\n' "$*"; }
action() { printf '  [done]    %s\n' "$*"; }

echo "Setup state for $REPO_ROOT"
echo

# --- 1. pre-commit -----------------------------------------------------------------------------
# The gate that keeps unsuitable content out of a public push. Everything else here is convenience.
echo "git hooks"
pre_commit="$HOOK_DIR/pre-commit"
if [[ -f "$pre_commit" ]]; then
  if grep -q 'pre-commit-check\.sh' "$pre_commit" 2>/dev/null; then
    ok "pre-commit -> scripts/pre-commit-check.sh"
    # Not a failure - an older hook still gates this repository correctly, it just predates the
    # shape every registration now uses. Re-registering is the owner's hand edit to make.
    if ! grep -q -- '--repo' "$pre_commit" 2>/dev/null; then
      note "pre-commit predates the --repo shape (harmless; see pre-commit-check.sh's Usage)"
    fi
    if [[ ! -x "$pre_commit" ]]; then
      if [[ "$mode" == "check" ]]; then
        todo "pre-commit exists but is not executable"
      else
        chmod +x "$pre_commit" && action "made pre-commit executable"
      fi
    fi
  else
    # Preserve it, but do not call the setup complete: whatever this hook does, it is not the gate.
    warn "pre-commit exists but does not call pre-commit-check.sh - left untouched, review by hand"
    missing=1
  fi
elif [[ "$mode" == "check" ]]; then
  todo "pre-commit hook (settings.json validity, projection drift, scrub check would not run)"
else
  cat > "$pre_commit" <<'HOOK'
#!/usr/bin/env bash
#
# Local-only registration for scripts/pre-commit-check.sh, written by scripts/setup.sh.
# Not tracked by git, so it needs reinstalling on a fresh clone.
#
# --repo names the checkout being committed to - the same shape a repository borrowing this gate
# installs by hand, so there is one hook line to keep right rather than two.
root="$(git rev-parse --show-toplevel)"
exec "$root/scripts/pre-commit-check.sh" --repo "$root"
HOOK
  chmod +x "$pre_commit"
  action "installed pre-commit -> scripts/pre-commit-check.sh"
fi

# --- 2. commit-msg -----------------------------------------------------------------------------
# The message half of the gate. scrub-check.sh reads tracked file content and never sees a commit
# message, so the Co-Authored-By trailer CLAUDE.md forbids was invisible to every check here until
# this hook existed. --scrub is passed for this repository because it targets a public remote; a
# borrowing repository decides that for itself (see --repo below).
commit_msg="$HOOK_DIR/commit-msg"
if [[ -f "$commit_msg" ]]; then
  if grep -q 'commit-msg-check\.sh' "$commit_msg" 2>/dev/null; then
    ok "commit-msg -> scripts/commit-msg-check.sh"
    if ! grep -q -- '--scrub' "$commit_msg" 2>/dev/null; then
      note "commit-msg does not pass --scrub, so messages are checked for the trailer only"
    fi
    if [[ ! -x "$commit_msg" ]]; then
      if [[ "$mode" == "check" ]]; then
        todo "commit-msg exists but is not executable"
      else
        chmod +x "$commit_msg" && action "made commit-msg executable"
      fi
    fi
  else
    warn "commit-msg exists but does not call commit-msg-check.sh - left untouched, review by hand"
    missing=1
  fi
elif [[ "$mode" == "check" ]]; then
  todo "commit-msg hook (a Co-Authored-By trailer or a leak in a commit message would not be caught)"
else
  cat > "$commit_msg" <<'HOOK'
#!/usr/bin/env bash
#
# Local-only registration for scripts/commit-msg-check.sh, written by scripts/setup.sh.
# Not tracked by git, so it needs reinstalling on a fresh clone.
#
# "$@" rather than "$1": git passes exactly one argument today, and forwarding whatever it passes
# keeps this line correct if that ever stops being true.
root="$(git rev-parse --show-toplevel)"
exec "$root/scripts/commit-msg-check.sh" --repo "$root" --scrub "$@"
HOOK
  chmod +x "$commit_msg"
  action "installed commit-msg -> scripts/commit-msg-check.sh (with --scrub)"
fi

# --- 3. replication hooks ----------------------------------------------------------------------
# Replicates this config into other CLAUDE_CONFIG_DIR profiles after each commit, and after each
# pull, so a commit authored on another machine reaches this machine's other profiles without
# waiting for the next local commit here. Git has no post-pull hook: `git pull` fires post-merge for
# the merge it performs (fast-forwards included) and post-rewrite for `git pull --rebase`, so both
# are installed alongside post-commit.
#
# The target directories are per-machine state, so this script asks rather than inventing them - but
# the hooks are installed either way, so that "no hook" always means "setup was never run" rather
# than "no targets configured", which is a real answer worth recording. All three hooks delegate to
# one generated replicate-targets.sh holding the list, so targets are edited in one place, not three.
MANAGED_MARKER="# managed by scripts/setup.sh"
targets_file="$HOOK_DIR/replicate-targets.sh"
REPLICATION_HOOKS=(post-commit post-merge post-rewrite)

ensure_executable() {
  # A hook that is not executable is a hook that does not run, and git says nothing about it.
  local path="$1" label="$2"
  [[ -x "$path" ]] && return 0
  if [[ "$mode" == "check" ]]; then
    todo "$label exists but is not executable"
  else
    chmod +x "$path" && action "made $label executable"
  fi
}

write_targets_file() {
  # Zero targets is a valid outcome, but the generated file must NOT call replicate.sh with no
  # arguments: that prints its usage message after every commit and every pull. The list guards
  # itself instead, so the empty case is quiet without needing a differently-shaped file.
  local -a targets=("$@")
  {
    printf '#!/usr/bin/env bash\n'
    printf '#\n'
    printf '%s - local-only replication target list for scripts/replicate.sh.\n' "$MANAGED_MARKER"
    printf '# Shared by the post-commit, post-merge, and post-rewrite hooks beside it, so the targets are\n'
    printf '# edited in one place. Not tracked by git, so it needs reinstalling on a fresh clone. Which\n'
    printf '# config dirs exist is per-machine state, which is why the targets are here, not in the repo.\n'
    printf '#\n'
    printf '# Add or remove targets by editing the list below.\n'
    printf 'TARGETS=(\n'
    local t
    for t in ${targets[@]+"${targets[@]}"}; do
      printf '  %s\n' "$(printf '%q' "$t")"
    done
    if [[ ${#targets[@]} -eq 0 ]]; then
      printf '  # No targets on this machine, so nothing replicates. Example: "$HOME/.claude-work"\n'
    fi
    printf ')\n'
    printf '\n'
    printf '[[ ${#TARGETS[@]} -gt 0 ]] || exit 0\n'
    printf 'exec "$(git rev-parse --show-toplevel)/scripts/replicate.sh" "${TARGETS[@]}"\n'
  } > "$targets_file"
  chmod +x "$targets_file"
}

write_replication_hook() {
  local name="$1"
  {
    printf '#!/usr/bin/env bash\n'
    printf '#\n'
    printf '%s - local-only registration for scripts/replicate.sh.\n' "$MANAGED_MARKER"
    printf '# Not tracked by git, so it needs reinstalling on a fresh clone. The target directories live in\n'
    printf '# replicate-targets.sh beside this file, shared with the other replication hooks.\n'
    printf '#\n'
    case "$name" in
      post-commit)
        printf '# Fires after every commit made on this machine - including each commit a rebase replays,\n'
        printf '# which is why the rebase case bails out below. Mirroring a half-rebased tree would push\n'
        printf '# transient state into every target, and post-rewrite syncs once when the rebase finishes.\n'
        printf '\n'
        printf 'if [[ -d "$(git rev-parse --git-path rebase-merge)" ]] \\\n'
        printf '   || [[ -d "$(git rev-parse --git-path rebase-apply)" ]]; then\n'
        printf '  exit 0\n'
        printf 'fi\n'
        printf '\n'
        ;;
      post-merge)
        printf '# Fires after a merge succeeds, which includes the merge `git pull` performs (fast-forwards\n'
        printf '# included) - so commits authored on another machine replicate on pull here, rather than\n'
        printf '# waiting for the next local commit. Git runs no hook when a merge stops on conflicts; the\n'
        printf '# commit that resolves one fires post-commit instead.\n'
        printf '\n'
        ;;
      post-rewrite)
        printf '# Fires after `git rebase` (which covers `git pull --rebase`) and after `git commit --amend`.\n'
        printf '# Only the rebase case is handled here: an amend already fires post-commit, and letting both\n'
        printf "# run would only collide on replicate.sh's lock.\\n"
        printf '\n'
        printf '# Git feeds the rewritten-commit list on stdin. Nothing here reads it, but draining it keeps\n'
        printf '# git from writing into a pipe this hook has already closed.\n'
        printf 'cat >/dev/null 2>&1 || true\n'
        printf '[[ "${1:-}" == "rebase" ]] || exit 0\n'
        printf '\n'
        ;;
    esac
    # --git-common-dir, not --show-toplevel: hooks live in the main .git even when git invokes them
    # from a linked worktree, where the two paths diverge.
    printf 'exec "$(git rev-parse --git-common-dir)/hooks/replicate-targets.sh"\n'
  } > "$HOOK_DIR/$name"
  chmod +x "$HOOK_DIR/$name"
}

count_targets() {
  # Entries in the generated list, ignoring its comments and blank lines.
  awk '/^TARGETS=\(/ { inside = 1; next }
       inside && /^\)/ { inside = 0 }
       inside && $0 !~ /^[[:space:]]*(#|$)/ { n++ }
       END { print n + 0 }' "$targets_file" 2>/dev/null
}

legacy_targets() {
  # Recovers the target list from a post-commit hook that hardcodes its targets inline rather
  # than sourcing replicate-targets.sh. Without this, a machine that already had replication
  # configured would be re-prompted for targets it already answered - or, non-interactively, would
  # silently lose them. Only ever reads a hook carrying this script's own marker.
  local hook="$HOOK_DIR/post-commit" line args
  local -a recovered=()
  [[ -f "$hook" ]] || return 0
  grep -q "$MANAGED_MARKER" "$hook" 2>/dev/null || return 0
  line="$(grep -E '^[[:space:]]*exec .*replicate\.sh' "$hook" 2>/dev/null | head -1)"
  [[ -n "$line" ]] || return 0
  args="${line#*replicate.sh\"}"
  # An unmatched strip returns the line unchanged; eval-ing that would turn `exec` and a command
  # substitution into "targets", and a bogus target is a directory rsync --delete would empty.
  [[ "$args" != "$line" ]] || return 0
  # The arguments were written with printf %q, so eval is the matching inverse.
  eval "recovered=($args)" 2>/dev/null || return 0
  local t
  for t in ${recovered[@]+"${recovered[@]}"}; do
    [[ "$t" == /* || "$t" == "~"* ]] && printf '%s\n' "$t"
  done
}

collect_targets() {
  # Returns targets on stdout, one per line. Empty output is a valid answer.
  if [[ ! -t 0 ]]; then
    return 0
  fi
  echo >&2
  echo "  Replication targets: other CLAUDE_CONFIG_DIR directories this config should be mirrored" >&2
  echo "  into after each commit and each pull - e.g. a second account's config dir. One path per" >&2
  echo "  line. Leave empty if this machine runs a single account. Blank line to finish." >&2
  echo >&2
  local line
  while true; do
    printf '  target> ' >&2
    IFS= read -r line || break
    [[ -n "${line// /}" ]] || break
    # Expand a leading ~ by hand: read does not do it, and an unexpanded ~ silently creates a
    # directory literally named "~" the first time replicate.sh runs.
    case "$line" in
      \~) line="$HOME" ;;
      \~/*) line="$HOME/${line#\~/}" ;;
    esac
    if [[ ! -d "$line" ]]; then
      echo "  note: $line does not exist yet - keeping it, but replication will skip it until it does" >&2
    fi
    printf '%s\n' "$line"
  done
}

# The shared list comes first: the hooks below are inert without it, and recovering targets from a
# legacy post-commit has to happen before that hook is rewritten.
if [[ -f "$targets_file" ]]; then
  if grep -q "$MANAGED_MARKER" "$targets_file" 2>/dev/null; then
    target_count="$(count_targets)"
    if [[ "$target_count" -gt 0 ]]; then
      ok "replicate-targets.sh ($target_count target(s), replication active)"
    else
      ok "replicate-targets.sh present, no replication targets configured (edit it to add some)"
    fi
    ensure_executable "$targets_file" "replicate-targets.sh"
  else
    warn "replicate-targets.sh exists but was not written by setup.sh - left untouched, review by hand"
  fi
elif [[ "$mode" == "check" ]]; then
  todo "replicate-targets.sh (the replication hooks have no targets to mirror into)"
else
  targets=()
  while IFS= read -r t; do
    [[ -n "$t" ]] && targets+=("$t")
  done < <(legacy_targets)
  if [[ ${#targets[@]} -gt 0 ]]; then
    note "recovered ${#targets[@]} target(s) from the existing post-commit hook"
  else
    while IFS= read -r t; do
      [[ -n "$t" ]] && targets+=("$t")
    done < <(collect_targets)
  fi
  write_targets_file ${targets[@]+"${targets[@]}"}
  if [[ ${#targets[@]} -gt 0 ]]; then
    action "installed replicate-targets.sh (${#targets[@]} target(s))"
  else
    action "installed replicate-targets.sh with no targets (nothing will replicate)"
  fi
fi

for hook_name in "${REPLICATION_HOOKS[@]}"; do
  hook_path="$HOOK_DIR/$hook_name"
  case "$hook_name" in
    post-commit) hook_gap="a commit made here would not replicate to other profiles" ;;
    post-merge)  hook_gap="a pull would not replicate commits authored on another machine" ;;
    post-rewrite) hook_gap="a 'git pull --rebase' would not replicate" ;;
  esac
  if [[ -f "$hook_path" ]]; then
    if grep -q 'replicate-targets\.sh' "$hook_path" 2>/dev/null; then
      ok "$hook_name -> replicate-targets.sh"
      ensure_executable "$hook_path" "$hook_name"
    elif grep -q "$MANAGED_MARKER" "$hook_path" 2>/dev/null && grep -q 'replicate\.sh' "$hook_path" 2>/dev/null; then
      # It carries this script's own marker, so rewriting it loses nothing a human put there.
      if [[ "$mode" == "check" ]]; then
        todo "$hook_name still hardcodes its targets - rerun setup.sh to move them into replicate-targets.sh"
      else
        write_replication_hook "$hook_name"
        action "upgraded $hook_name -> replicate-targets.sh"
      fi
    else
      warn "$hook_name exists but does not call replicate.sh - left untouched, review by hand"
    fi
  elif [[ "$mode" == "check" ]]; then
    todo "$hook_name hook ($hook_gap)"
  else
    write_replication_hook "$hook_name"
    action "installed $hook_name -> replicate-targets.sh"
  fi
done
echo

# --- 4. scrub patterns -------------------------------------------------------------------------
echo "scrub patterns"
collect_patterns() {
  # Appends, never truncates: re-running --scrub must not silently drop patterns added by hand.
  if [[ ! -t 0 ]]; then
    todo "$PATTERN_FILE needs input but stdin is not a terminal - run scripts/setup.sh --scrub interactively"
    return 1
  fi

  local created=0
  if [[ ! -f "$PATTERN_FILE" ]]; then
    cat > "$PATTERN_FILE" <<'HEADER'
# scrub-patterns.local - machine-local patterns for scripts/scrub-check.sh.
#
# One POSIX extended regex (ERE) per line; blank lines and # comments are ignored. Matching is
# case-SENSITIVE, so spell out the casings that matter or use a character class. Remember to
# escape a literal dot: acme\.internal, not acme.internal.
#
# This file is never committed - the root .gitignore ignores every unwhitelisted root entry, so a
# tracked list of client names (the exact leak scrub-check exists to prevent) cannot happen by
# accident. Add to it whenever a new client or engagement name enters your vocabulary.
HEADER
    created=1
  fi

  echo
  echo "  Enter the client, engagement, employer, or internal-host patterns this machine should"
  echo "  never publish - one per line, as an extended regex. Examples:"
  echo "      [Aa]cme[- ]?[Cc]orp"
  echo "      \\.claude-acme"
  echo "      jira\\.internal\\.example\\.com"
  echo "  An empty answer is valid and means you have none. Blank line to finish."
  echo

  local n=0 line
  while true; do
    printf '  pattern> '
    IFS= read -r line || break
    [[ -n "${line// /}" ]] || break
    # Reject a pattern grep cannot compile, here rather than at commit time inside a hook.
    # On empty input a valid ERE exits 1 (no match); only a malformed one exits 2 or higher.
    printf '' | grep -qE -- "$line" 2>/dev/null
    if [[ $? -ge 2 ]]; then
      echo "  not a valid extended regex, skipped: $line" >&2
      continue
    fi
    printf '%s\n' "$line" >> "$PATTERN_FILE"
    n=$((n + 1))
  done

  if [[ "$created" -eq 1 ]]; then
    action "created $PATTERN_FILE with $n pattern(s)"
  else
    action "appended $n pattern(s) to $PATTERN_FILE"
  fi
  return 0
}

pattern_count() {
  # grep -c always prints a count, including 0, and exits 1 when that count is 0 - so a
  # `|| echo 0` fallback here emits TWO lines and every later numeric test on it fails.
  local n
  n="$(grep -cvE '^[[:space:]]*(#|$)' "$PATTERN_FILE" 2>/dev/null)" || n="${n:-0}"
  printf '%s\n' "${n:-0}"
}

if [[ -f "$PATTERN_FILE" ]]; then
  count="$(pattern_count)"
  ok "$PATTERN_FILE exists ($count active pattern(s))"
  if [[ "$count" -eq 0 ]]; then
    warn "no active patterns - fine if you genuinely have none, but scrub-check then covers only"
    warn "structural shapes and this machine's own username, hostname, and git email"
  fi
  if [[ "$want_scrub" -eq 1 ]]; then
    if [[ "$mode" == "check" ]]; then
      note "[skip]    --scrub ignored under --check (would modify the file)"
    else
      collect_patterns || true
    fi
  fi
elif [[ "$mode" == "check" ]]; then
  todo "$PATTERN_FILE (scrub-check.sh refuses to run without it, so the pre-commit gate fails closed)"
else
  # The one thing that cannot be defaulted: only the owner knows which names matter.
  collect_patterns || true
fi
echo

# --- 5. scrub test fixtures ---------------------------------------------------------------------
# Fixture lines for `scrub-check.sh --test`, a self-test that the patterns above are actually
# firing rather than just parsing. Ignored by every other mode - untracked, and never picked up
# by a bare or --staged scan - so it cannot pollute an ordinary audit.
echo "scrub test fixtures"

collect_test_lines() {
  # Appends, never truncates - same reason as collect_patterns: re-running --scrub must not
  # silently drop a fixture line added by hand.
  if [[ ! -t 0 ]]; then
    todo "$TEST_FILE needs input but stdin is not a terminal - run scripts/setup.sh --scrub interactively"
    return 1
  fi

  local created=0
  if [[ ! -f "$TEST_FILE" ]]; then
    cat > "$TEST_FILE" <<'HEADER'
# scrub-test.local - fixture lines for `scripts/scrub-check.sh --test`.
#
# Each non-comment line here is expected to trigger at least one warning when scanned - that is
# what proves the patterns above are actually firing, not just that they parse. --test fails if
# any line matches nothing. Every other scrub-check.sh mode ignores this file entirely.
#
# Add a line that SHOULD match: a real client name from scrub-patterns.local, a sample absolute
# path, an email address, or a credential-shaped token - anything the patterns exist to catch.
#
# This file is never committed - same as scrub-patterns.local, the root .gitignore ignores every
# unwhitelisted root entry.
HEADER
    created=1
  fi

  echo
  echo "  Enter lines that SHOULD trigger a scrub-check warning - used by 'scrub-check.sh --test' to"
  echo "  prove the patterns above are still firing. One per line: a real client name, a sample"
  echo "  path, an email address, or an example credential-shaped token. Blank line to finish."
  echo

  local n=0 line
  while true; do
    printf '  test-line> '
    IFS= read -r line || break
    [[ -n "${line// /}" ]] || break
    printf '%s\n' "$line" >> "$TEST_FILE"
    n=$((n + 1))
  done

  if [[ "$created" -eq 1 ]]; then
    action "created $TEST_FILE with $n fixture line(s)"
  else
    action "appended $n fixture line(s) to $TEST_FILE"
  fi
  return 0
}

test_line_count() {
  local n
  n="$(grep -cvE '^[[:space:]]*(#|$)' "$TEST_FILE" 2>/dev/null)" || n="${n:-0}"
  printf '%s\n' "${n:-0}"
}

if [[ -f "$TEST_FILE" ]]; then
  tcount="$(test_line_count)"
  ok "$TEST_FILE exists ($tcount fixture line(s))"
  if [[ "$tcount" -eq 0 ]]; then
    warn "no fixture lines - scrub-check.sh --test has nothing to verify"
  fi
  if [[ "$want_scrub" -eq 1 ]]; then
    if [[ "$mode" == "check" ]]; then
      note "[skip]    --scrub ignored under --check (would modify the file)"
    else
      collect_test_lines || true
    fi
  fi
elif [[ "$mode" == "check" ]]; then
  todo "$TEST_FILE (scrub-check.sh --test has nothing to verify without it, so the pre-commit self-test fails closed)"
else
  collect_test_lines || true
fi
echo

# --- 6. report ---------------------------------------------------------------------------------
if [[ "$mode" == "check" ]]; then
  if [[ "$missing" -eq 1 ]]; then
    echo "Setup is INCOMPLETE. Run scripts/setup.sh to fix, or see the README's Setup After Cloning."
    exit 1
  fi
  echo "Setup is complete."
  exit 0
fi

# Prove the result rather than asserting it: the gate is only real if scrub-check actually runs.
echo "verifying"
if [[ -x scripts/scrub-check.sh ]]; then
  if scripts/scrub-check.sh >/dev/null 2>&1; then
    ok "scrub-check.sh runs clean over the tracked tree"
  else
    rc=$?
    if [[ "$rc" -eq 1 ]]; then
      warn "scrub-check.sh reports findings in the tracked tree - run it directly to see them"
    else
      warn "scrub-check.sh could not run (exit $rc) - run it directly to see why"
    fi
  fi
  if [[ -f "$TEST_FILE" ]]; then
    if scripts/scrub-check.sh --test >/dev/null 2>&1; then
      ok "scrub-check.sh --test passes ($TEST_FILE's fixture lines all trigger a warning)"
    else
      warn "scrub-check.sh --test failed - run it directly to see which fixture line matched nothing"
    fi
  fi
else
  warn "scripts/scrub-check.sh missing or not executable"
fi
echo
if [[ "$missing" -eq 1 ]]; then
  # A step this run could not finish - almost always scrub patterns needed interactively while
  # stdin was a pipe. Exiting 0 here would report success for a setup that is still incomplete.
  echo "Setup is INCOMPLETE - see the [MISSING] and [warn] lines above."
  exit 1
fi
echo "Setup complete. Re-run scripts/setup.sh --check any time to confirm nothing has drifted."
exit 0
