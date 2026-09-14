#!/usr/bin/env bash
#
# health-check.sh - the mechanical half of this repository's periodic self-evaluation: every
# check on "is this config still internally consistent" that a file test or a regex can answer,
# run in one pass over the whole tracked tree.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit.
#
# REGISTRATION STATE: deliberately UNREGISTERED, and meant to stay that way. It is not a git hook,
# not a settings.json hook, and not part of the commit gate. scripts/pre-commit-check.sh remains
# the fast staged-only gate and this script must never be wired into it. Run this by hand, on
# demand or on a long cadence (weekly or monthly, or before a publication pass).
#
# WHY THIS EXISTS: the commit gate only ever sees the bytes of one commit, so drift that no single
# commit introduces accumulates invisibly - a skill with no spec section, a spec section naming a
# retired artifact, a script the README forgot, a description that has grown past its budget, an
# "updated:" date that was not bumped. Because this never runs on a hot path it can afford to be
# slow and thorough: it walks every tracked file rather than the staged set.
#
# WHAT IT DOES NOT DO: it never edits, stages, or rewrites anything, and it never registers
# anything. Judgment - is this document still true, does this artifact still earn its place, do
# these two files now contradict each other - is deliberately out of scope; that is the
# health-check skill's half, which reads this script's output rather than re-deriving it.
#
# CHECKS, self-implemented (the delegated ones are listed under REUSE below):
#   json-validity         every tracked *.json parses, plus settings.local.json and mcp-servers.json
#   settings-refs         every command settings.json points at exists, is executable, and is tracked
#   frontmatter           created:/updated: present, well-formed, ordered, and not in the future
#   description-budget    skill descriptions against the per-description cap and the shared pool
#   spec-coverage         skills/ and agents/ against their spec sections, in both directions
#   readme-coverage       top-level scripts, skills, and subagents named in README.md
#   script-modes          tracked mode 100755 and on-disk executability for every *.sh
#   shell-syntax          bash -n and a shebang on every tracked *.sh (shellcheck advisory if present)
#   artifact-frontmatter  a skill's or subagent's name: matches its path, and description: exists
#   decision-numbering    decisions/ is a gapless series with no duplicate number
#   path-refs             backticked repo-internal paths in prose resolve (see COMPLEMENTARY below)
#   eval-coverage         a skill with no evals/evals.json                         (advisory)
#   context-budget        always-loaded files against the documented line convention (advisory)
#   updated-bump          a Markdown file changed in the working tree without its date bumped
#   orphans               a reference, example, or decision nothing else cites      (advisory, slow)
#   updated-history       updated: trailing the last commit by more than a day      (advisory, slow)
#                         (files untouched since the repository's root commit are exempt)
#
# REUSE: checks that already exist are invoked, never reimplemented -
#   scripts/md-checks.sh      placeholders, typography, heading levels, broken links and anchors
#   scripts/scrub-check.sh    public-repo hygiene, full-tree audit (invoked with no arguments)
#   scripts/sync.sh --check   projection drift (--check only; apply mode writes outside this repo)
#   scripts/setup.sh --check  machine-local setup completeness (--check only; it is read-only)
#
# COMPLEMENTARY, not duplicated: md-checks.sh resolves Markdown *link* targets - `[text](path)`.
# The prose in this repository overwhelmingly cites paths as bare backticked spans instead, which
# no link parser sees, so check_path_refs covers that form. It is scoped to the files that describe
# this repository and skipped for docs/ and evals/runs/, which cite paths belonging to other
# projects and to fixture transcripts.
#
# Usage:
#   scripts/health-check.sh            run every check
#   scripts/health-check.sh --quick    skip the slow checks: the four delegated scripts
#                                      (md-checks, scrub-check, sync --check, setup --check), the
#                                      per-file git-history scan, and the inbound-reference scan
#   scripts/health-check.sh --help     print this usage block
#
# Output: findings as "<path>:<line> - <description>", grouped under a "== <category> ==" header.
#   A line number of 0 means the finding is about the file as a whole. Advisory findings are
#   grouped under "== <category> (advisory) ==" and never affect the exit code; they cover
#   machine-local state, historical drift, and measurements against a "roughly N" convention -
#   none of which is a defect in the tree itself, and each of which is a judgment call the
#   health-check skill makes rather than one this script can settle.
#   Output from a delegated script is capped at DELEGATED_MAX_LINES lines per category, with the
#   true total named on a trailing line, so one noisy delegated check cannot bury the rest.
#
# Exit: 0 no failures (advisories may be present), 1 one or more checks failed, 2 usage or
#       environment error.
#
# STALENESS MARKER: a full run records three key=value lines in .health-check-stamp -
#   date=YYYY-MM-DD    when this machine last ran the full check
#   commit=<sha>       the HEAD it ran against, or "unknown" outside a resolvable HEAD
#   findings=<n>       non-advisory finding lines that run produced
# scripts/session-setup-check.sh reads them to say, at session start, both "last run N days ago"
# and "left N findings unaddressed", and to stretch its overdue threshold when the tree has not
# moved since a clean run. That nudge is the only thing keeping a manual, long-cadence check honest
# without putting it on a hook path - see specs/behaviors.md's Config Health Check section.

set -uo pipefail  # deliberately not -e: one failing check must not skip the remaining checks.
                  # Every check reports; the exit code is computed once, at the end.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 2
cd "$REPO_ROOT" || exit 2

readonly SKILL_DESC_MAX=1536   # skillListingMaxDescChars, per skills/skill-author/references/skills.md
readonly SKILL_POOL_MAX=8000   # the shared skill-description pool fallback, same source

# Untracked by design. .gitignore's leading /* ignores every root entry that is not explicitly
# whitelisted, so this cannot be committed by accident, and "when did THIS machine last audit the
# tree, against what, and with what result" is per-machine state rather than a property of the tree
# - a tracked stamp would claim every clone had been audited because one of them had.
readonly STAMP_FILE=".health-check-stamp"

usage() {
  sed -n '/^# Usage:/,/^#       environment error\./p' "${BASH_SOURCE[0]}" | sed 's/^#\{1\} \{0,1\}//'
}

run_slow=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) run_slow=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'health-check: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'health-check: not a git repository: %s\n' "$REPO_ROOT" >&2
  exit 2
fi

WORK="$(mktemp -d)" || exit 2
trap 'rm -rf "$WORK"' EXIT
FAILS="$WORK/fails"
WARNS="$WORK/warns"
: >"$FAILS"
: >"$WARNS"

# Findings are collected as "<category>\t<rendered line>" and grouped at the end, so each check
# function can report freely without caring about output order or header placement.
fail() { printf '%s\t%s:%s - %s\n' "$1" "$2" "$3" "$4" >>"$FAILS"; }
warn() { printf '%s\t%s:%s - %s\n' "$1" "$2" "$3" "$4" >>"$WARNS"; }

# A delegated script already prints "<path>:<line> - <description>"; re-wrapping that through
# fail() would double-prefix it, so its lines are tagged with a category and passed through as-is.
#
# Capped, because one misconfigured delegated check can bury every other finding: a single
# over-broad pattern in scrub-patterns.local produced 868 lines here, against which every
# self-implemented finding was invisible. The cap keeps this report readable and names the true
# total so nothing is silently hidden; the delegated script itself remains the place to get the
# full list.
readonly DELEGATED_MAX_LINES=25
emit_raw() {
  local category="$1" sink="$2" line shown=0 total=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    total=$(( total + 1 ))
    if (( shown < DELEGATED_MAX_LINES )); then
      printf '%s\t%s\n' "$category" "$line" >>"$sink"
      shown=$(( shown + 1 ))
    fi
  done
  if (( total > shown )); then
    printf '%s\t%s\n' "$category" \
      "... $(( total - shown )) more lines from this check are suppressed ($total in total) - run it directly for the full list" >>"$sink"
  fi
}

TRACKED_MD=()
while IFS= read -r f; do TRACKED_MD+=("$f"); done < <(git ls-files '*.md')

# Files that legitimately carry no created:/updated: header. The repository README and CLAUDE.md
# are the entry points rather than dated records; eval runs are dated by their own filename and are
# append-only; a skill's eval fixtures are deliberately plain sample documents, since a fixture
# carrying repository conventions would test the wrong thing; statusline-tests/README.md documents
# a fixture directory.
#
# Deliberately NOT a blanket */README.md exemption: every other nested README in this tree
# (docs/*/README.md, evals/README.md) does carry both dates, so exempting the pattern would quietly
# drop five compliant files out of enforcement to accommodate one that is not.
fm_exempt() {
  case "$1" in
    CLAUDE.md|README.md) return 0 ;;
    scripts/*-tests/README.md) return 0 ;;   # a test dir's own README, not a tracked document
    evals/runs/*.md) return 0 ;;
    skills/*/evals/files/*) return 0 ;;
    *) return 1 ;;
  esac
}

# created:/updated: live in YAML frontmatter for plain documents and in a leading HTML comment for
# files whose frontmatter is reserved for harness keys (skills, subagents). Both sit
# well inside the first 60 lines; scanning a bounded prefix rather than the whole file keeps a
# body line that happens to start with "updated:" from being mistaken for the header.
fm_date() {
  head -60 "$2" 2>/dev/null \
    | grep -m1 -oE "^$1: *[0-9]{4}-[0-9]{2}-[0-9]{2}" \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}'
}

# Length of a frontmatter description:, handling both the plain form and the "|" block scalar.
desc_len() {
  awk '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { next }
    $0 == "---" { exit }
    /^description:[[:space:]]*\|/ { block = 1; next }
    # A blank line inside a block scalar is a paragraph break, not the end of the value. Treating
    # it as the end truncated every multi-paragraph description to its first paragraph, which is
    # exactly the case this check exists to measure.
    block && /^[[:space:]]*$/ { next }
    block && /^[[:space:]]/ { line = $0; sub(/^[[:space:]]+/, "", line); buf = buf line " "; next }
    block { exit }
    /^description:/ { line = $0; sub(/^description:[[:space:]]*/, "", line); buf = line; exit }
    END { sub(/[[:space:]]+$/, "", buf); print length(buf) }
  ' "$1"
}

# Every tracked *.json, not just settings.json: a skill's evals.json and the statusline fixtures
# are parsed by tooling that fails opaquely on malformed input, and none of them is covered by the
# commit gate (which validates settings.json alone). settings.local.json and scripts/mcp-servers.json
# are named explicitly because both are untracked-or-absent by design and would otherwise be missed.
check_json_validity() {
  if ! command -v jq >/dev/null 2>&1; then
    warn json-validity settings.json 0 "jq not installed - JSON validity and settings references not checked"
    return
  fi
  local f
  for f in $(git ls-files '*.json') settings.local.json scripts/mcp-servers.json; do
    [[ -f "$f" ]] || continue
    jq empty "$f" >/dev/null 2>&1 || fail json-validity "$f" 0 "not valid JSON (jq empty failed)"
  done
}

# Every command settings.json points at must exist, be executable, and be tracked. A hook whose
# script has been renamed or deleted fails silently at runtime - the harness reports a non-zero
# hook, not a missing file - and an untracked one works on this machine and nowhere else, which is
# precisely the drift a fresh clone discovers the hard way. The commit gate cannot catch either,
# because both sides of the mismatch can be introduced by separate commits.
check_settings_references() {
  command -v jq >/dev/null 2>&1 || return   # already reported by check_json_validity
  [[ -f settings.json ]] || return
  local cmd path tracked
  tracked="$(git ls-files)"
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    path="${cmd%% *}"                                   # drop any arguments
    path="${path#\$\{CLAUDE_CONFIG_DIR:-\$HOME/.claude\}/}"
    path="${path#\$\{CLAUDE_CONFIG_DIR\}/}"
    path="${path#\$HOME/.claude/}"
    path="${path#~/.claude/}"
    case "$path" in
      /*|\$*) continue ;;   # an absolute or still-unexpanded path is not ours to resolve
    esac
    if [[ ! -f "$path" ]]; then
      fail settings-refs settings.json 0 "references '$path', which does not exist"
      continue
    fi
    [[ -x "$path" ]] || fail settings-refs "$path" 0 "referenced by settings.json but not executable"
    grep -qxF -- "$path" <<<"$tracked" \
      || fail settings-refs "$path" 0 "referenced by settings.json but not tracked by git (works here, absent in a fresh clone)"
  done < <(jq -r '.. | objects | .command? // empty | select(type == "string")' settings.json)
}

# bash -n on every tracked shell script. A syntax error in a hook script is invisible until the
# hook fires, and a hook that fires on every Bash call is a bad place to discover one. Cheap enough
# to stay in the fast set. shellcheck, when installed, is advisory: its style findings are opinions
# this repository has not adopted as rules, and it is not installed everywhere this clone lands.
check_shell_syntax() {
  local f out
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    head -1 "$f" | grep -q '^#!' || fail shell-syntax "$f" 1 "no shebang line"
    out="$(bash -n "$f" 2>&1)" || fail shell-syntax "$f" 0 "bash -n failed: ${out//$'\n'/ }"
  done < <(git ls-files '*.sh')
  command -v shellcheck >/dev/null 2>&1 || return
  while IFS= read -r f; do
    shellcheck -f gcc -S warning "$f" 2>/dev/null | while IFS= read -r out; do
      printf '%s\t%s\n' shellcheck "$out" >>"$WARNS"
    done
  done < <(git ls-files '*.sh')
}

# A skill or subagent whose frontmatter name: does not match its own path is discovered under one
# name and invoked under another, which fails at the point of use rather than here. Both harnesses
# key on the frontmatter, so the mismatch is silent in the listing.
check_artifact_frontmatter() {
  local f expect got desc
  for f in skills/*/SKILL.md agents/*.md; do
    [[ -f "$f" ]] || continue
    case "$f" in
      skills/*) expect="$(basename "$(dirname "$f")")" ;;
      *)        expect="$(basename "$f" .md)" ;;
    esac
    if [[ "$(head -1 "$f")" != "---" ]]; then
      fail artifact-frontmatter "$f" 1 "does not open with a '---' frontmatter block"
      continue
    fi
    got="$(awk 'NR>1 && $0=="---"{exit} /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$f")"
    got="${got%\"}"; got="${got#\"}"
    if [[ -z "$got" ]]; then
      fail artifact-frontmatter "$f" 0 "no 'name:' key in frontmatter"
    elif [[ "$got" != "$expect" ]]; then
      fail artifact-frontmatter "$f" 0 "frontmatter name '$got' does not match its path (expected '$expect')"
    fi
    desc="$(desc_len "$f")"
    (( desc > 0 )) || fail artifact-frontmatter "$f" 0 "no 'description:' key in frontmatter, or it is empty"
  done
}

# decisions/ is an append-only numbered series. A duplicate number makes two records cite-collide
# ("see decision 0007") and a gap usually means a record was deleted rather than superseded, which
# the immutability rule forbids.
check_decision_numbering() {
  local f n expect=1 seen=""
  for f in decisions/[0-9][0-9][0-9][0-9]-*.md; do
    [[ -f "$f" ]] || continue
    n="$(basename "$f")"; n="${n%%-*}"
    if grep -qxF -- "$n" <<<"$seen"; then
      fail decision-numbering "$f" 0 "duplicate decision number $n"
    else
      seen="$seen$n"$'\n'
      if (( 10#$n != expect )); then
        fail decision-numbering "$f" 0 "decision number $n breaks the sequence (expected $(printf '%04d' "$expect"))"
      fi
      expect=$(( 10#$n + 1 ))
    fi
  done
}

check_frontmatter() {
  local f c u today
  today="$(date +%F)"
  (( ${#TRACKED_MD[@]} )) || return   # set -u makes "${empty[@]}" an error on bash 3.2 (macOS)
  for f in "${TRACKED_MD[@]}"; do
    fm_exempt "$f" && continue
    [[ -f "$f" ]] || continue
    c="$(fm_date created "$f")"
    u="$(fm_date updated "$f")"
    [[ -n "$c" ]] || fail frontmatter "$f" 0 "no well-formed 'created: YYYY-MM-DD' in the first 60 lines"
    [[ -n "$u" ]] || fail frontmatter "$f" 0 "no well-formed 'updated: YYYY-MM-DD' in the first 60 lines"
    if [[ -n "$c" && -n "$u" && "$u" < "$c" ]]; then
      fail frontmatter "$f" 0 "updated ($u) is earlier than created ($c)"
    fi
    # A future date is always a typo or a copied header, and it silently defeats the bump check
    # below: a file dated tomorrow never compares equal to today and never will.
    [[ -n "$c" && "$c" > "$today" ]] && fail frontmatter "$f" 0 "created ($c) is in the future (today is $today)"
    [[ -n "$u" && "$u" > "$today" ]] && fail frontmatter "$f" 0 "updated ($u) is in the future (today is $today)"
  done
}

check_description_budgets() {
  local f len total=0 atotal=0
  for f in skills/*/SKILL.md; do
    [[ -f "$f" ]] || continue
    len="$(desc_len "$f")"
    total=$(( total + len ))
    if (( len > SKILL_DESC_MAX )); then
      fail description-budget "$f" 0 "skill description is $len chars, over the ${SKILL_DESC_MAX}-char per-description cap"
    fi
  done
  if (( total > SKILL_POOL_MAX )); then
    fail description-budget skills 0 "skill descriptions total $total chars, over the ${SKILL_POOL_MAX}-char pool fallback"
  else
    warn description-budget skills 0 "skill descriptions total $total of the ${SKILL_POOL_MAX}-char pool fallback"
  fi
  # Subagent descriptions are always loaded too, but no per-description cap is documented for them
  # the way skillListingMaxDescChars is for skills. Reporting the figures without inventing a
  # threshold keeps this a measurement rather than a fabricated rule.
  for f in agents/*.md; do
    [[ -f "$f" ]] || continue
    len="$(desc_len "$f")"
    atotal=$(( atotal + len ))
    warn description-budget "$f" 0 "subagent description is $len chars"
  done
  warn description-budget agents 0 "subagent descriptions total $atotal chars (no documented cap; always loaded)"
}

check_spec_coverage() {
  local d f name ln heading
  for d in skills/*/; do
    name="$(basename "$d")"
    [[ -f "$d/SKILL.md" ]] || continue
    # A loose substring match, not a heading match: write-plan and execute-plan are specified
    # together under specs/behaviors.md's "Plan and Execute" heading rather than under their own
    # names, so requiring "## <name>" would flag two correctly-specified skills.
    if ! grep -qF -- "$name" specs/skills.md specs/behaviors.md 2>/dev/null; then
      fail spec-coverage "skills/$name/SKILL.md" 0 "not mentioned in specs/skills.md or specs/behaviors.md"
    fi
  done
  for f in agents/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .md)"
    grep -qE "^## ${name}( |$)" specs/agents.md 2>/dev/null \
      || fail spec-coverage "$f" 0 "no '## $name' section in specs/agents.md"
  done
  while IFS=: read -r ln heading; do
    heading="${heading##\#\# }"
    [[ "$heading" == *"(retired"* ]] && continue
    [[ -d "skills/$heading" ]] \
      || fail spec-coverage specs/skills.md "$ln" "section '## $heading' names a skill with no skills/$heading/ directory"
  done < <(grep -nE '^## ' specs/skills.md 2>/dev/null)
  while IFS=: read -r ln heading; do
    heading="${heading##\#\# }"
    [[ "$heading" == *"(retired"* ]] && continue
    [[ -f "agents/$heading.md" ]] \
      || fail spec-coverage specs/agents.md "$ln" "section '## $heading' names a subagent with no agents/$heading.md"
  done < <(grep -nE '^## ' specs/agents.md 2>/dev/null)
}

check_readme_coverage() {
  local f b d
  # Top-level scripts only. Fixtures and helpers under scripts/<subdir>/ are documented by their
  # own README, not by the repository Layout section.
  while IFS= read -r f; do
    b="$(basename "$f")"
    grep -qF -- "$b" README.md || fail readme-coverage "$f" 0 "not named anywhere in README.md"
  done < <(git ls-files 'scripts/*.sh' | grep -vE '^scripts/[^/]+/')
  for f in agents/*.md; do
    [[ -f "$f" ]] || continue
    b="$(basename "$f" .md)"
    grep -qF -- "$b" README.md || fail readme-coverage "$f" 0 "not named anywhere in README.md"
  done
  for d in skills/*/; do
    b="$(basename "$d")"
    grep -qF -- "$b" README.md || fail readme-coverage "skills/$b" 0 "not named anywhere in README.md"
  done
  # Any .sh basename README.md mentions must resolve somewhere in the tracked tree - not just
  # scripts/, so a script correctly named at its actual path (e.g. under skills/*/scripts/)
  # isn't flagged for living where it belongs. A basename the tree has no file for at all is
  # still a real defect (a rename or deletion the prose was not updated for), unless README.md
  # itself says so by naming it under .git/hooks/, which setup.sh generates and does not track.
  while IFS= read -r b; do
    git ls-files | grep -qE "(^|/)${b}\$" && continue
    grep -qF ".git/hooks/$b" README.md && continue
    fail readme-coverage README.md 0 "names $b, which does not exist anywhere in the tree"
  done < <(grep -oE '\b[a-z0-9][a-z0-9-]*\.sh\b' README.md | sort -u)
}

check_script_modes() {
  local mode sha stage path
  while read -r mode sha stage path; do
    [[ "$mode" == "100755" ]] || fail script-modes "$path" 0 "tracked mode is $mode, expected 100755"
    [[ -x "$path" ]] || fail script-modes "$path" 0 "not executable on disk"
  done < <(git ls-files -s '*.sh')
}

# The convention is that editing a tracked Markdown file means bumping its updated: date. Checked
# against the WORKING TREE, not against history: a file changed today and not yet bumped is the
# mistake this catches, at the moment it is still cheap to fix.
check_updated_bump() {
  local today f u
  today="$(date +%F)"
  while IFS= read -r f; do
    [[ "$f" == *.md ]] || continue
    [[ -f "$f" ]] || continue
    fm_exempt "$f" && continue
    u="$(fm_date updated "$f")"
    if [[ "$u" != "$today" ]]; then
      fail updated-bump "$f" 0 "changed in the working tree but 'updated:' is ${u:-absent}, not today ($today)"
    fi
  done < <({ git diff --name-only; git diff --cached --name-only; } | sort -u)
}

# One day after a date, or the date unchanged if neither date(1) dialect is available. GNU and BSD
# date take incompatible flags and this repository is pulled onto both; falling back to the input
# makes the caller's comparison strictly conservative (it reports more, never less).
next_day() {
  date -d "$1 +1 day" +%F 2>/dev/null \
    || date -j -v+1d -f %Y-%m-%d "$1" +%F 2>/dev/null \
    || printf '%s\n' "$1"
}

# The same convention applied to history, as an advisory only. A file committed the day after its
# updated: date is an ordinary overnight commit rather than a missed bump, so a one-day gap is
# tolerated outright: without that tolerance this check emitted 36 lines on a healthy tree, none of
# them actionable, and an advisory nobody reads is worse than no advisory. A gap wider than a day
# is a genuine signal that the file was edited without its date being bumped.
#
# A file whose last commit is the repository's root commit is exempt. This repository is intended
# to be republished by squashing its history into a single commit, which makes that commit every
# file's last commit and its date every file's comparison point - so without this exemption the
# first run after a republish reports every tracked Markdown file at once, which is noise rather
# than signal: nothing has been edited since publication, so there is no missed bump to catch. The
# check resumes for each file the moment it gains a second commit. `git rev-list --max-parents=0`
# can name more than one root (a repository built by merging unrelated histories), so match
# against the full list rather than assuming a single line.
check_updated_history() {
  local f u c h roots
  (( ${#TRACKED_MD[@]} )) || return
  roots="$(git rev-list --max-parents=0 HEAD 2>/dev/null)"
  for f in "${TRACKED_MD[@]}"; do
    fm_exempt "$f" && continue
    [[ -f "$f" ]] || continue
    u="$(fm_date updated "$f")"
    [[ -n "$u" ]] || continue
    read -r h c < <(git log -1 --format='%H %ad' --date=short -- "$f" 2>/dev/null)
    [[ -n "$c" ]] || continue
    [[ -n "$roots" && -n "$h" ]] && grep -qxF "$h" <<<"$roots" && continue
    if [[ "$(next_day "$u")" < "$c" ]]; then
      warn updated-history "$f" 0 "'updated: $u' predates its last commit ($c) by more than a day"
    fi
  done
}

# Backticked repo-internal path references that do not resolve. md-checks.sh already resolves
# Markdown link targets - [text](path) - but this repository almost never cites a path that way;
# it writes `skills/cursor-projection/references/harness-matrix.md` inline, which no link parser
# sees. A backticked path can drift out from under a rename or deletion just as easily as a
# Markdown link, with nothing in the existing checks positioned to catch it.
#
# Scoped deliberately, because an over-broad version of this check is worse than none:
#   - docs/ is a research library about the outside world and evals/runs/ holds fixture
#     transcripts; both legitimately cite paths belonging to other projects.
#   - decisions/ records are immutable and describe the tree as it stood when they were accepted,
#     so a reference there that no longer resolves cannot be fixed without violating that rule.
#   - fenced code blocks are skipped, matching md-checks.sh: a path inside a fence is template or
#     example text (`docs/research/some-file.md` in reference/document-generation.md is a
#     References-section template), not a claim that the file exists.
#   - only first segments that are real top-level directories here are considered, so an upstream
#     repo path or a URL fragment is not mistaken for ours.
#   - a candidate is skipped when it contains a glob, when its last segment carries no extension
#     (the `decisions/0003` shorthand and Anthropic doc-URL fragments such as `docs/en/memory`
#     both take that form), or when the line itself says the file is not there - retired, deleted,
#     absent, "does not exist", "not yet". specs/behaviors.md names
#     scripts/mcp-servers.json as an artifact that does not exist until MCP servers are configured.
#   - a candidate that is a suffix of some tracked path counts as resolved: prose routinely cites
#     a path relative to a context it just named ("each skill's `evals/evals.json`"), and treating
#     that as broken would train the reader to ignore this category.
check_path_refs() {
  local f dir line ln p fenced tracked
  (( ${#TRACKED_MD[@]} )) || return
  tracked="$(git ls-files)"
  for f in "${TRACKED_MD[@]}"; do
    case "$f" in
      docs/*|decisions/*|evals/runs/*|skills/*/evals/files/*) continue ;;
    esac
    [[ -f "$f" ]] || continue
    dir="$(dirname "$f")"
    ln=0
    fenced=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      ln=$(( ln + 1 ))
      case "$line" in
        '```'*|'~~~'*) fenced=$(( 1 - fenced )); continue ;;
      esac
      (( fenced )) && continue
      case "$line" in
        *retired*|*Retired*|*deleted*|*Deleted*|*"git history"*) continue ;;
        *absent*|*"does not exist"*|*"not yet"*) continue ;;
      esac
      case "$line" in *'`'*) ;; *) continue ;; esac
      for p in $(grep -oE '`[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+`' <<<"$line" | tr -d '`' | sort -u); do
        case "$p" in
          agents/*|decisions/*|docs/*|evals/*|reference/*|scripts/*|skills/*|specs/*) ;;
          *) continue ;;
        esac
        case "$p" in *'*'*|*'...'*) continue ;; esac
        [[ "${p##*/}" == *.* ]] || continue      # no extension: a shorthand or a URL fragment
        [[ -e "$p" || -e "$dir/$p" ]] && continue
        grep -qE "(^|/)${p//./\\.}\$" <<<"$tracked" && continue
        fail path-refs "$f" "$ln" "references '$p', which does not exist"
      done
    done <"$f"
  done
}

# Artifacts nothing points at. Not a defect on its own - this reports zero inbound references and
# leaves "does it still earn its place" to the skill - but a reference document, example, or
# decision record that no other file cites is either newly orphaned by a deletion or was never
# wired in. Slow: one git grep per file.
check_orphans() {
  local f b n
  for f in reference/*.md decisions/*.md skills/*/references/*.md skills/*/examples/*.md; do
    [[ -f "$f" ]] || continue
    b="$(basename "$f")"
    n="$(git grep -lF -- "$b" -- '*.md' 2>/dev/null | grep -vxF -- "$f" | wc -l | tr -d ' ')"
    (( n == 0 )) && warn orphans "$f" 0 "no other tracked Markdown file references it"
  done
}

# A skill with no eval set. specs/skills.md gates a skill on trigger/behavioral evals, and more
# than one entry there currently carries a "testing gate deferred" note; this keeps that debt
# visible instead of resting in prose. Advisory, because authoring evals is its own piece of work.
check_eval_coverage() {
  local d name
  for d in skills/*/; do
    name="$(basename "$d")"
    [[ -f "${d}evals/evals.json" ]] \
      || warn eval-coverage "skills/$name" 0 "no evals/evals.json - trigger and behavioral evals have not been authored"
  done
}

# Always-loaded context is paid for on every turn of every session, so its size is a standing cost
# rather than a one-time one. The thresholds are this repository's own documented convention, not
# an invented rule: reference/context-file-authoring.md sets a roughly 200-line target for an
# always-loaded root file, matching Anthropic's own, permits overrunning it as far as a hard
# ceiling of 300, and sets roughly 200 to 400 lines for an on-demand reference. Advisory, since
# the convention says "roughly" and a considered overrun of the target is a judgment call, not a
# defect - but the ceiling is a limit rather than a target, so it is reported in stronger terms.
readonly ROOT_CTX_MAX=200      # reference/context-file-authoring.md, repository-local convention
readonly ROOT_CTX_CEILING=300  # same source, how far an overrun of the target may go
readonly REF_CTX_MAX=400       # same source, on-demand reference files
check_context_budget() {
  local f n
  f="CLAUDE.md"
  if [[ -f "$f" ]]; then
    n="$(wc -l <"$f" | tr -d ' ')"
    if (( n > ROOT_CTX_CEILING )); then
      warn context-budget "$f" 0 "$n lines, past the ${ROOT_CTX_CEILING}-line hard ceiling in reference/context-file-authoring.md - trim before adding anything"
    elif (( n > ROOT_CTX_MAX )); then
      warn context-budget "$f" 0 "$n lines, over the ${ROOT_CTX_MAX}-line always-loaded target in reference/context-file-authoring.md"
    fi
  fi
  for f in reference/*.md; do
    [[ -f "$f" ]] || continue
    n="$(wc -l <"$f" | tr -d ' ')"
    (( n > REF_CTX_MAX )) \
      && warn context-budget "$f" 0 "$n lines, over the ${REF_CTX_MAX}-line on-demand reference convention"
  done
}

check_delegated_md_checks() {
  if [[ ! -x scripts/md-checks.sh ]]; then
    warn md-checks scripts/md-checks.sh 0 "not found or not executable - skipped"
    return
  fi
  (( ${#TRACKED_MD[@]} )) || return
  local out
  out="$(scripts/md-checks.sh "${TRACKED_MD[@]}" 2>&1)"
  # md-checks.sh always exits 0 and is silent for a clean file, so any output at all is a finding.
  [[ -n "$out" ]] && printf '%s\n' "$out" | emit_raw md-checks "$FAILS"
}

check_delegated_scrub() {
  if [[ ! -x scripts/scrub-check.sh ]]; then
    warn scrub-check scripts/scrub-check.sh 0 "not found or not executable - skipped"
    return
  fi
  local out rc
  out="$(scripts/scrub-check.sh 2>&1)"
  rc=$?
  case "$rc" in
    0) ;;
    # Exit 2 means scrub-patterns.local is absent, which is machine-local setup state rather than
    # a defect in the tree. Advisory, so an unconfigured machine can still run this usefully.
    2) warn scrub-check scrub-patterns.local 0 "scrub-check could not run (exit 2): scrub-patterns.local is missing - run scripts/setup.sh yourself to create it" ;;
    *) printf '%s\n' "$out" | emit_raw scrub-check "$FAILS" ;;
  esac
}

check_delegated_sync() {
  if [[ ! -x scripts/sync.sh ]]; then
    warn sync-check scripts/sync.sh 0 "not found or not executable - skipped"
    return
  fi
  local out rc
  out="$(scripts/sync.sh --check 2>&1)"
  rc=$?
  (( rc == 0 )) || printf '%s\n' "$out" | emit_raw sync-check "$FAILS"
}

check_delegated_setup() {
  if [[ ! -x scripts/setup.sh ]]; then
    warn setup-check scripts/setup.sh 0 "not found or not executable - skipped"
    return
  fi
  local out rc
  out="$(scripts/setup.sh --check 2>&1)"
  rc=$?
  # Machine-local completeness, not repository health: a fresh clone is legitimately incomplete
  # until its owner runs setup.sh, and that run is the owner's act, never this script's.
  if (( rc != 0 )); then
    warn setup-check scripts/setup.sh 0 "machine-local setup incomplete (exit $rc) - run scripts/setup.sh yourself"
    printf '%s\n' "$out" | emit_raw setup-check "$WARNS"
  fi
}

render() {
  local file="$1" suffix="$2"
  [[ -s "$file" ]] || return 0
  awk -F'\t' -v suffix="$suffix" '
    $1 != last { if (last != "") print ""; printf "== %s%s ==\n", $1, suffix; last = $1 }
    { print $2 }
  ' "$file"
}

check_json_validity
check_settings_references
check_frontmatter
check_description_budgets
check_spec_coverage
check_readme_coverage
check_script_modes
check_shell_syntax
check_artifact_frontmatter
check_decision_numbering
check_path_refs
check_eval_coverage
check_context_budget
check_updated_bump
if (( run_slow )); then
  check_orphans
  check_updated_history
  check_delegated_md_checks
  check_delegated_scrub
  check_delegated_sync
  check_delegated_setup
fi

fail_n="$(wc -l <"$FAILS" | tr -d ' ')"
warn_n="$(wc -l <"$WARNS" | tr -d ' ')"

render "$WARNS" " (advisory)"
if [[ -s "$WARNS" && -s "$FAILS" ]]; then printf '\n'; fi
render "$FAILS" ""

printf '\nhealth-check: %s finding line(s), %s advisory\n' "$fail_n" "$warn_n"

# Stamped on a full run only. --quick skips the four delegated scripts and both history scans,
# which is most of what makes this a health check rather than a linter; letting a five-second quick
# run silence the nudge for a week would defeat the point of having one.
#
# The finding count is recorded, not just the date, so the nudge can distinguish "you have not
# looked lately" from "you looked, and left five things on the floor" - a run that reports findings
# and is then ignored must not silently reset the clock the way a clean run does. The commit is
# recorded so the nudge can say how far the tree has moved since, and so an idle tree can earn a
# longer leash without earning silence: HEAD alone does not determine the findings, because
# scrub-patterns.local, .git/hooks/, settings.local.json, on-disk permission bits, and the
# working-tree diff all feed checks here and none of them is in any commit.
#
# Never fatal - a read-only checkout must still be able to run this.
if (( run_slow )); then
  stamp_commit="$(git rev-parse HEAD 2>/dev/null)" || stamp_commit="unknown"
  [[ -n "$stamp_commit" ]] || stamp_commit="unknown"
  if printf 'date=%s\ncommit=%s\nfindings=%s\n' \
       "$(date +%F)" "$stamp_commit" "$fail_n" >"$STAMP_FILE" 2>/dev/null; then
    printf 'health-check: recorded this run in %s (%s finding line(s) against %s)\n' \
      "$STAMP_FILE" "$fail_n" "${stamp_commit:0:7}"
  else
    printf 'health-check: could not write %s - the session-start staleness nudge will not update\n' \
      "$STAMP_FILE" >&2
  fi
fi

(( fail_n == 0 )) || exit 1
exit 0
