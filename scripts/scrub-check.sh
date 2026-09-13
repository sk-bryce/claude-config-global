#!/usr/bin/env bash
#
# scrub-check.sh - detect content unsuited to a public remote in this repository's tracked files:
# client, employer, or personal identifiers; machine-specific paths; and credential-shaped tokens.
# Read-only - it reports and exits non-zero, and never edits, stages, or rewrites anything.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit. It registers itself nowhere; scripts/pre-commit-check.sh calls it
# with --staged, and run by hand with no arguments it audits the whole tracked tree.
#
# WHY THIS EXISTS: the working tree was scrubbed once by hand (commit d29690c) and nothing stopped
# the same content from coming straight back. reference/context-file-authoring.md's routing table is
# explicit that a rule which must fire with zero exceptions belongs in a check rather than a context
# file, because context-file content is advice an agent can read and still deviate from. The
# CLAUDE.md rule states the policy; this script is what actually holds the line.
#
# WHY IT CARRIES NO SENSITIVE VALUES: a committed list of client and employer names would itself be
# the leak this script exists to prevent. So the patterns come from three places, and only the first
# is committed:
#   1. Structural patterns (below) - shapes, not values: absolute home paths, projects-path
#      spellings, UUIDs, credential prefixes, email addresses.
#   2. Machine-derived values, computed at run time and never written down: the current username,
#      short hostname, and the git-configured email address and its domain.
#   3. scrub-patterns.local (at the root of THIS script's main checkout, whichever repository or
#      worktree is being scanned) - one extended regex per line, gitignored. Project- and
#      client-specific tokens live here. Its ABSENCE IS A HARD ERROR (exit 2), not a silent
#      skip: structural patterns alone give a false sense of coverage, and a check that quietly
#      passes on an unconfigured machine is worse than one that refuses to run. An empty or
#      comments-only file is fine and means "no project-specific tokens" - that is a deliberate
#      statement, where a missing file is an unanswered question. Create it with scripts/setup.sh.
#
# This script never creates that file, and never writes anything at all. It runs inside a
# pre-commit hook, where a tool that silently materializes files is a bad surprise; scripts/setup.sh
# owns creation, interactively and only when asked.
#
# Unlike md-checks.sh, this does NOT skip fenced code blocks. A real home directory inside an
# example command is exactly as much of a leak as one in prose. There is no path exemption for the
# files that document these categories, this one included: a placeholder and a regex source do not
# match the patterns below, so none of them ever needed one.
#
# Usage: scrub-check.sh [--repo <dir>] [--staged | --all | --test | <path> ...]
#   (no arguments)  Checks every tracked file as it exists in the working tree (git ls-files) -
#                   the full-tree audit. This is the default because it is what a human wants when
#                   they type the bare command ad hoc: "is this repository clean?"
#   --all           Explicit synonym for the default, for a caller that would rather state it.
#   --staged        Checks the STAGED content - the bytes git is about to commit. What
#                   scripts/pre-commit-check.sh passes.
#   --test          Self-test: verifies every fixture line in scrub-test.local triggers at least
#                   one warning below. Proves the patterns are actually firing, not just parsing.
#                   Requires scrub-test.local at this script's own main checkout (create it with
#                   scripts/setup.sh --scrub).
#   <path> ...      Checks those paths as they exist in the working tree.
#   --repo <dir>    Scans the repository containing <dir> instead of the one this script lives in,
#                   so another checkout can reuse this detector rather than copying it.
#                   --repo=<dir> is accepted too; any path inside the target works, and findings
#                   are reported relative to its root. Combines with the default, --all, --staged
#                   and path modes. The pattern and test files still come from this script's own
#                   main checkout, so --test changes nothing under it.
#   Prints findings as "<path>:<line> - <description>", grouped under a "== category ==" header per
#   non-empty category, per file. Silent when clean; --test instead reports per fixture line.
#
# MAINTAINING THAT BLOCK: --help prints it by sed range, ending at the first "#"-only line after the
# Usage: header. Keep the block unbroken - a blank comment line inside it silently truncates the
# help output - and keep anything not meant for a reader of --help below this line.
# WHY --staged EXISTS, AND WHY THE HOOK MUST PASS IT: scanning the working tree while git commits
# the index is a hole, not a shortcut. Stage a file containing a secret, tidy the file afterwards,
# and a working-tree scan passes while the secret commits - verified, not theorised. The mirror
# case is a false positive: a clean staged version blocked by an unrelated dirty edit. Partial
# staging (git add -p) hits both routinely. In staged mode each blob is extracted with
# `git cat-file` and scanned in a temp mirror, but every finding is reported under its real
# repository path, so path:line still points at something actionable - and the line numbers refer
# to the version being committed, which is the one that matters.
#
# WHY THAT IS THE FLAG RATHER THAN THE DEFAULT: the commit gate is written once, by
# scripts/setup.sh, and never typed again, so a flag costs it nothing; a human types the bare
# command repeatedly. Defaulting to the audit also fails in the safe direction - a full-tree scan
# can only over-report relative to a staged one, and over-reporting is the correct failure mode for
# a leak detector.
#
# WHY --test EXISTS: every pattern here is only as good as its regex syntax, and a typo that
# breaks a character class fails silently - grep just stops matching, and every other check keeps
# exiting 0 because there is nothing left to trip over. scrub-test.local holds lines already known
# to match something; --test asserts they still do, so a broken pattern is caught the moment it
# breaks rather than the moment it lets something real through. Its absence is a hard error
# (exit 2), the same as PATTERN_FILE's, and for the same reason: a self-test that quietly no-ops
# when its fixtures go missing is worse than one that refuses to run.
#
# Exit: 0 clean (under --test: every fixture line matched something), 1 findings (under --test: a
#       fixture line matched nothing), 2 usage or environment error (including a missing pattern
#       or test file).

set -uo pipefail  # deliberately not -e: one file's failing check must not skip the remaining files,
                  # and the exit code has to mean "findings", not "some grep returned no match".

# Resolved before the cd below, because --help and the unknown-option message are both answered
# after it and a relative "${BASH_SOURCE[0]}" would no longer point at this file by then.
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SELF_REPO="$(cd "$(dirname "$SELF")/.." && pwd)"

# Machine-local files come from this script's own checkout whichever repository is scanned: they
# describe a person, not a repository, and a borrowed repo keeping its own copy would be the same
# list twice with only one kept current. The MAIN checkout, because both are gitignored and so are
# absent from a linked worktree - anchoring them to the running checkout made every commit from a
# branch fail on their absence. Every checkout of a repository shares one git directory, whose
# parent is that main checkout. The fallback is for a replicated CLAUDE_CONFIG_DIR profile, which
# carries a copy of scripts/ and no repository at all.
CONFIG_ROOT="$SELF_REPO"
common_dir="$(git -C "$SELF_REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
  && CONFIG_ROOT="$(dirname "$common_dir")"

PATTERN_FILE="$CONFIG_ROOT/scrub-patterns.local"
TEST_FILE="$CONFIG_ROOT/scrub-test.local"

usage() {
  sed -n '/^# Usage: scrub-check.sh/,/^#$/p' "$SELF" | sed 's/^# \{0,1\}//'
}

# --help is answered here, before anything else can fail. It has to work on a machine that has not
# been set up yet, because that is the machine someone runs it on to find out how to set it up - and
# the missing-pattern-file check below exits 2 long before argument parsing would reach it.
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done

# Consumed here rather than in the mode parsing further down, which rejects any --* it does not
# recognize and would read the directory that follows as a path to scan.
#
# WHY IT EXISTS: a repository wanting this gate can borrow the detector rather than copy it, and a
# copy drifts silently - a scrub check that has stopped matching still exits 0. Everything that
# reads the tree is already relative to REPO_ROOT, so redirecting that one variable is the whole of
# it.
REPO_ROOT_OVERRIDE=""
saw_repo=0
parsed_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Both spellings, validated once after the loop: a missing value, an empty one, and a trailing
    # --repo are the same mistake and deserve one message.
    --repo)   saw_repo=1; REPO_ROOT_OVERRIDE="${2-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --repo=*) saw_repo=1; REPO_ROOT_OVERRIDE="${1#--repo=}"; shift ;;
    *) parsed_args+=("$1"); shift ;;
  esac
done
set -- ${parsed_args[@]+"${parsed_args[@]}"}

if [[ "$saw_repo" -eq 1 && -z "$REPO_ROOT_OVERRIDE" ]]; then
  echo "scrub-check: --repo needs a directory argument" >&2
  exit 2
fi

if [[ -n "$REPO_ROOT_OVERRIDE" ]]; then
  # git resolves the root, so any path inside the target repository works and a symlinked path
  # normalizes itself. It also covers both ways this can fail - a path that does not exist, and one
  # in no checkout at all - which have to stay errors rather than becoming passes: `git ls-files`
  # outside a repository returns nothing, and an empty file list reads as a perfectly clean tree.
  REPO_ROOT="$(git -C "$REPO_ROOT_OVERRIDE" rev-parse --show-toplevel 2>/dev/null)" || REPO_ROOT=""
  if [[ -z "$REPO_ROOT" ]]; then
    echo "scrub-check: --repo is not a readable path inside a git checkout: $REPO_ROOT_OVERRIDE" >&2
    exit 2
  fi
else
  REPO_ROOT="$SELF_REPO"
fi
cd "$REPO_ROOT" || exit 2

# --- Structural patterns ---------------------------------------------------------------------------
# Each is a (regex, exemption, description) triple. The exemption is matched against the matched
# TEXT, not the whole line, so a placeholder is exempt wherever it appears. Angle-bracket
# placeholders (/Users/<name>) need no exemption: they cannot match the character classes below.

PATHS_RE='/(Users|home)/[A-Za-z0-9._-]+'
PATHS_EXEMPT='/(Users|home)/(example|examples|user|username|you|your-name|your-username|me|name|admin|root|ubuntu|debian|runner|test|guest|placeholder|somebody|someone)$'

PROJECTS_RE='-(Users|home)-[A-Za-z0-9-]+'
PROJECTS_EXEMPT='-(Users|home)-(example|user|username|you|placeholder)(-|$)'

UUID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
UUID_EXEMPT='^0{8}-0{4}-0{4}-0{4}-0{12}$'

EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
# Exempts the reserved example domains, GitHub's noreply form, and the commonest false positive:
# a filename or extension sitting after an @ (a version spec, an npm scope, a doc cross-reference).
EMAIL_EXEMPT='@(example\.(com|org|net|invalid)|.+\.example|users\.noreply\.github\.com)$|\.(md|sh|bash|zsh|json|jsonl|js|ts|tsx|py|go|rs|yml|yaml|toml|html|css|txt|png|svg|lock)$'

SECRET_RE='(sk-ant-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[A-Za-z0-9_-]{35})'
SECRET_EXEMPT='^$'  # never exempt a credential-shaped token

# --- Machine-derived literals ----------------------------------------------------------------------
# Computed here, never committed. A value that is generic enough to appear as ordinary prose is
# dropped rather than searched for, since grepping the whole repo for "user" or "test" would bury a
# real finding under noise.
GENERIC='^(user|users|admin|root|ubuntu|debian|ec2-user|runner|dev|devel|test|tests|example|me|you|guest|host|localhost|mac|macbook|home|build|ci)$'
COMMON_MAIL_DOMAIN='^(gmail\.com|googlemail\.com|icloud\.com|me\.com|outlook\.com|hotmail\.com|live\.com|yahoo\.com|proton\.me|protonmail\.com|fastmail\.com|users\.noreply\.github\.com)$'

derived_literals=()   # parallel arrays: literal + what to call it in a finding
derived_labels=()

add_derived() {
  local value="$1" label="$2"
  [[ -n "$value" ]] || return 0
  [[ ${#value} -ge 4 ]] || return 0                                # too short to grep usefully
  shopt -s nocasematch
  if [[ "$value" =~ $GENERIC ]]; then shopt -u nocasematch; return 0; fi
  shopt -u nocasematch
  derived_literals+=("$value")
  derived_labels+=("$label")
}

add_derived "${USER:-$(id -un 2>/dev/null)}" "this machine's username"
add_derived "$(hostname -s 2>/dev/null)" "this machine's hostname"

git_email="$(git config --get user.email 2>/dev/null)"
if [[ -n "$git_email" ]]; then
  add_derived "$git_email" "the git-configured email address"
  git_domain="${git_email##*@}"
  shopt -s nocasematch
  if [[ -n "$git_domain" && ! "$git_domain" =~ $COMMON_MAIL_DOMAIN ]]; then
    shopt -u nocasematch
    add_derived "$git_domain" "the git-configured email domain"
  else
    shopt -u nocasematch
  fi
fi

# --- Project patterns from the untracked pattern file ----------------------------------------------
project_patterns=()
if [[ ! -f "$PATTERN_FILE" ]]; then
  cat >&2 <<MSG
scrub-check: $PATTERN_FILE does not exist - refusing to run.

This file holds the client, engagement, and internal-hostname patterns that only you know.
Without it this check covers structural shapes (home paths, UUIDs, credential prefixes, email
addresses) and literals derived from this machine, and nothing else - which is exactly the
coverage that looks adequate right up until a client name ships to a public remote.

  Create it:  $CONFIG_ROOT/scripts/setup.sh --scrub
  Or by hand: an empty file is a valid answer if you genuinely have no such tokens.

See $CONFIG_ROOT/reference/public-repo-hygiene.md.
MSG
  exit 2
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%$'\r'}"
  [[ -n "${line// /}" ]] || continue
  [[ "${line#\#}" == "$line" ]] || continue
  # scripts/setup.sh --scrub rejects an uncompilable pattern at collection time, but this file is
  # meant to be hand-edited too (see reference/public-repo-hygiene.md), which bypasses that check.
  # Silently dropping a bad line here would be exactly the quietly-reduced coverage this script
  # otherwise refuses to give - so warn and skip it rather than folding it in unnoticed.
  printf '' | grep -qE -- "$line" 2>/dev/null
  if [[ $? -ge 2 ]]; then
    echo "scrub-check: skipping invalid pattern in $PATTERN_FILE: $line" >&2
    continue
  fi
  project_patterns+=("$line")
done < "$PATTERN_FILE"

# --- File list -------------------------------------------------------------------------------------
# SCAN_PREFIX is stripped from a path before reporting, so a blob extracted to a temp mirror is
# still displayed as its real repository path.
SCAN_PREFIX=""
STAGED_TMP=""

cleanup() {
  [[ -n "$STAGED_TMP" && -d "$STAGED_TMP" ]] && rm -rf "$STAGED_TMP"
}
trap cleanup EXIT INT TERM

files=()
mode="all"
saw_staged=0
saw_paths=0
saw_test=0
for arg in "$@"; do
  case "$arg" in
    --all) mode="all" ;;
    --staged) mode="staged"; saw_staged=1 ;;
    --test) mode="test"; saw_test=1 ;;
    -h|--help) usage; exit 0 ;;  # unreachable in practice: handled above, kept so the case is total
    --*) echo "scrub-check: unknown option: $arg (try --help)" >&2; exit 2 ;;
    *) mode="paths"; saw_paths=1 ;;
  esac
done

# Explicit paths, --staged, and --test each answer a different question; silently honouring more
# than one would misreport which bytes were actually checked.
if [[ $((saw_staged + saw_paths + saw_test)) -gt 1 ]]; then
  echo "scrub-check: --staged, --test, and path arguments are mutually exclusive" >&2
  exit 2
fi

case "$mode" in
  paths)
    for arg in "$@"; do
      [[ "$arg" == --* ]] || files+=("$arg")
    done
    ;;

  all)
    while IFS= read -r f; do files+=("$f"); done < <(git ls-files 2>/dev/null)
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "scrub-check: no tracked files found (not a git checkout?)" >&2
      exit 2
    fi
    ;;

  staged)
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      echo "scrub-check: not a git checkout, so there is no index to read" >&2
      exit 2
    fi

    staged_paths=()
    while IFS= read -r -d '' f; do
      staged_paths+=("$f")
    done < <(git diff --cached --name-only --diff-filter=ACMR -z 2>/dev/null)

    if [[ ${#staged_paths[@]} -eq 0 ]]; then
      # Nothing staged is not a pass to celebrate, but it is not a failure either: there is simply
      # nothing about to be committed. Say so rather than printing a misleading clean bill.
      echo "scrub-check: nothing staged - no content to check" >&2
      exit 0
    fi

    STAGED_TMP="$(mktemp -d "${TMPDIR:-/tmp}/scrub-staged.XXXXXX")" || {
      echo "scrub-check: could not create a temp directory" >&2
      exit 2
    }
    SCAN_PREFIX="$STAGED_TMP/"

    for f in ${staged_paths[@]+"${staged_paths[@]}"}; do
      dest="$STAGED_TMP/$f"
      mkdir -p "$(dirname "$dest")" 2>/dev/null || continue
      # The index version, not the working-tree version - the whole point of this mode.
      if git cat-file blob ":$f" > "$dest" 2>/dev/null; then
        files+=("$dest")
      else
        echo "scrub-check: could not read staged content for $f - skipping" >&2
      fi
    done

    if [[ ${#files[@]} -eq 0 ]]; then
      echo "scrub-check: no staged content could be read" >&2
      exit 2
    fi
    ;;

  test)
    if [[ ! -f "$TEST_FILE" ]]; then
      cat >&2 <<MSG
scrub-check: $TEST_FILE does not exist - refusing to run --test.

This file holds lines that are known to match one of the patterns above, used to verify the
patterns are actually firing rather than just parsing. Without it there is nothing to self-test.

  Create it:  $CONFIG_ROOT/scripts/setup.sh --scrub
  Or by hand: add a line for each pattern you want proof is still matching.

See $CONFIG_ROOT/reference/public-repo-hygiene.md.
MSG
      exit 2
    fi
    files=("$TEST_FILE")
    ;;
esac

TAB="$(printf '\t')"
found_any=0

# Collect "category<TAB>line<TAB>description" for one regex, dropping matches the exemption covers.
scan_regex() {
  local file="$1" category="$2" regex="$3" exempt="$4" desc="$5"
  local hit lineno match
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    lineno="${hit%%:*}"
    match="${hit#*:}"
    if [[ -n "$exempt" ]] && printf '%s' "$match" | grep -qE -- "$exempt"; then
      continue
    fi
    printf '%s\t%s\t%s: %s\n' "$category" "$lineno" "$desc" "$match"
  done < <(grep -InoE -- "$regex" "$file" 2>/dev/null || true)
}

scan_literal() {
  local file="$1" category="$2" literal="$3" desc="$4"
  local hit lineno
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    lineno="${hit%%:*}"
    printf '%s\t%s\t%s (%s)\n' "$category" "$lineno" "$desc" "$literal"
  done < <(grep -InoFi -- "$literal" "$file" 2>/dev/null | cut -d: -f1 | sort -un || true)
}

# Every pattern category applied to one file, as "category<TAB>line<TAB>description" lines. Used
# by both --test and the main loop below, so a new pattern category only has to be added once.
compute_findings() {
  local file="$1" out=""
  out+="$(scan_regex "$file" paths     "$PATHS_RE"    "$PATHS_EXEMPT"    'absolute home-directory path')"$'\n'
  out+="$(scan_regex "$file" paths     "$PROJECTS_RE" "$PROJECTS_EXEMPT" 'projects-path spelling of a home directory')"$'\n'
  out+="$(scan_regex "$file" sessions  "$UUID_RE"     "$UUID_EXEMPT"     'session or project UUID')"$'\n'
  out+="$(scan_regex "$file" identity  "$EMAIL_RE"    "$EMAIL_EXEMPT"    'email address')"$'\n'
  out+="$(scan_regex "$file" secrets   "$SECRET_RE"   "$SECRET_EXEMPT"   'credential-shaped token')"$'\n'
  local i pat
  for i in ${derived_literals[@]+"${!derived_literals[@]}"}; do
    out+="$(scan_literal "$file" identity "${derived_literals[$i]}" "${derived_labels[$i]}")"$'\n'
  done
  for pat in ${project_patterns[@]+"${project_patterns[@]}"}; do
    out+="$(scan_regex "$file" project "$pat" "" "project-specific pattern from $PATTERN_FILE")"$'\n'
  done
  printf '%s' "$out"
}

# --test is a different question from every other mode: not "does this content have a finding"
# but "does every fixture line have one". Handled here, once, rather than folded into the loop
# below, because its pass/fail unit is a fixture line, not a file.
if [[ "$mode" == "test" ]]; then
  test_file="${files[0]}"

  active_linenos=()
  active_contents=()
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    line="${line%%$'\r'}"
    [[ -n "${line// /}" ]] || continue
    [[ "${line#\#}" == "$line" ]] || continue
    active_linenos+=("$lineno")
    active_contents+=("$line")
  done < "$test_file"

  if [[ ${#active_linenos[@]} -eq 0 ]]; then
    echo "scrub-check --test: $TEST_FILE has no fixture lines - nothing to verify" >&2
    exit 0
  fi

  findings="$(compute_findings "$test_file")"
  matched_linenos="$(printf '%s\n' "$findings" | awk -F"$TAB" 'NF>=2 {print $2}' | sort -un)"

  fail=0
  for i in "${!active_linenos[@]}"; do
    ln="${active_linenos[$i]}"
    if ! printf '%s\n' "$matched_linenos" | grep -qx "$ln"; then
      fail=$((fail + 1))
      printf '%s:%s - no pattern matched: %s\n' "$TEST_FILE" "$ln" "${active_contents[$i]}"
    fi
  done

  total=${#active_linenos[@]}
  if [[ "$fail" -gt 0 ]]; then
    echo "scrub-check --test: $fail of $total fixture line(s) matched nothing (see above) - a pattern may be broken" >&2
    exit 1
  fi
  echo "scrub-check --test: all $total fixture line(s) in $TEST_FILE triggered a warning as expected"
  exit 0
fi

for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  rel="${f#./}"
  if [[ -n "$SCAN_PREFIX" ]]; then
    rel="${rel#"$SCAN_PREFIX"}"
  fi
  case "$rel" in
    "$REPO_ROOT"/*) rel="${rel#"$REPO_ROOT"/}" ;;
  esac
  [[ "$rel" == ".git/"* ]] && continue

  findings="$(compute_findings "$f")"
  findings="$(printf '%s' "$findings" | grep -v '^[[:space:]]*$' || true)"
  [[ -n "$findings" ]] || continue

  found_any=1
  printf '%s\n' "$rel"
  for category in paths identity sessions secrets project; do
    # -k3,3 alongside -k2,2n: BSD sort's -u treats lines as duplicate whenever the given keys
    # match, so line-number alone would collapse two distinct findings that share a line (e.g.
    # two different email addresses on one line) down to just one, silently dropping the other.
    group="$(printf '%s\n' "$findings" | awk -F"$TAB" -v c="$category" '$1 == c' | sort -t"$TAB" -k2,2n -k3,3 -u)"
    [[ -n "$group" ]] || continue
    printf '  == %s ==\n' "$category"
    printf '%s\n' "$group" | awk -F"$TAB" -v p="$rel" '{ printf "  %s:%s - %s\n", p, $2, $3 }'
  done
  printf '\n'
done

if [[ "$found_any" -eq 1 ]]; then
  cat >&2 <<MSG
scrub-check: found content unsuited to a public remote (see above).
Fix it. See $CONFIG_ROOT/reference/public-repo-hygiene.md for the neutral
substitutes to use instead. There is no path exemption to add.
MSG
  exit 1
fi

exit 0
