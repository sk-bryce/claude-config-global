#!/usr/bin/env bash
#
# review-merge-tests/run.sh - regression suite for scripts/review-merge.sh's coverage, prefilter,
# merge, and record subcommands. Every case builds a run directory by hand per CONTRACT A and
# CONTRACT B in specs/skills.md, then compares stdout or specific file contents exactly.
# Usage: bash scripts/review-merge-tests/run.sh    (exits 0 only when every case passes)
#   REVIEW_MERGE overrides the script under test (used to run this suite against a baseline copy).

set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_CONFIG_DIR="$ROOT"
RM="${REVIEW_MERGE:-$ROOT/scripts/review-merge.sh}"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0
total=0

# run_case NAME EXPECTED COMMAND...
#   Compares COMMAND's stdout exactly with EXPECTED after replacing the temp directory with the
#   literal string $T.
run_case() {
  local name="$1" expected="$2" actual
  shift 2
  total=$((total + 1))
  actual="$("$@" 2>/dev/null | sed "s|$T|\$T|g")"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$name" "$expected" "$actual"
  fi
}

# assert NAME CONDITION_DESCRIPTION -- used after a manual [[ ]] test already computed in "$ok".
record_result() {
  local name="$1" ok="$2"
  total=$((total + 1))
  if [[ "$ok" -eq 1 ]]; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name"
    shift 2
    [[ $# -gt 0 ]] && printf '%s\n' "$@"
  fi
}

assert_contains() {
  local name="$1" file="$2" pattern="$3"
  if [[ -f "$file" ]] && grep -qF -- "$pattern" "$file"; then
    record_result "$name" 1
  else
    record_result "$name" 0 "--- pattern not found: $pattern" "--- in: $file"
  fi
}

assert_not_contains() {
  local name="$1" file="$2" pattern="$3"
  if [[ -f "$file" ]] && grep -qF -- "$pattern" "$file"; then
    record_result "$name" 0 "--- pattern unexpectedly found: $pattern" "--- in: $file"
  else
    record_result "$name" 1
  fi
}

linenum() {
  grep -nF -- "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1
}

# check_report NAME REPORT_PATH -- CONTRACT R's declaration regex, and heading order.
DECL_RE='^Run: proofread=[0-9]+ docs; judgment=(dispatched\((sonnet|opus)\)|split into [0-9]+ groups\((sonnet|opus)\)|failed \([^()]+\)); tools=md-checks=(ran|error\([0-9]+\)), links=(ran|error\([0-9]+\)), claims=(ran|error\([0-9]+\)), scrub-check=(ran|absent|error\([0-9]+\)), markdownlint=(ran|error\([0-9]+\)|not installed \(see references/markdownlint-setup\.md\)), vale=(ran|error\([0-9]+\)|not installed \(see references/vale-setup\.md\)); ascii-rule=(adopted|not adopted) \([^()]+\); references-rule=(adopted|not adopted); profile=(agent-config|none); fresh=(yes|no); skipped=(none|[^;]+)$'
check_report() {
  local name="$1" report="$2" first
  first="$(head -1 "$report" 2>/dev/null)"
  local decl_ok=0
  [[ "$first" =~ $DECL_RE ]] && decl_ok=1
  record_result "$name-decl-regex" "$decl_ok" "--- declaration line: $first"

  local l1 l2 l3 l4 order_ok=0
  l1="$(linenum "$report" '### Summary')"
  l2="$(linenum "$report" '### Per-document findings')"
  l3="$(linenum "$report" '### Applied changes')"
  l4="$(linenum "$report" '### Not checked')"
  if [[ -n "$l1" && -n "$l2" && -n "$l3" && -n "$l4" && "$l1" -lt "$l2" && "$l2" -lt "$l3" && "$l3" -lt "$l4" ]]; then
    order_ok=1
  fi
  record_result "$name-headings-order" "$order_ok"
}

TOOLS='md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md)'

# write_context DIR GITROOT
write_context() {
  cat > "$1/context.txt" <<EOF
git-root=$2
ascii-rule=not adopted (CLAUDE.md has no ASCII rule)
references-rule=not adopted
profile=none
agent-config=none
tools=$TOOLS
EOF
}

# write_request DIR FRESH SKIPPED
write_request() {
  cat > "$1/request.md" <<EOF
fresh=$2
size-cap=none
skipped=$3
--- request ---
test request
EOF
}

###################################################################################################
# 1. coverage
###################################################################################################

RUN1="$T/run1"
mkdir -p "$RUN1/docs/D1" "$RUN1/out"
printf 'D1\t%s/doc1.md\t100\n' "$RUN1" > "$RUN1/files.tsv"
cat > "$RUN1/docs/D1/claims.tsv" <<EOF
$RUN1/doc1.md	1	H1	path	foo	candidate
$RUN1/doc1.md	2	H1	path	bar	candidate
$RUN1/doc1.md	3	H2	path	baz	candidate
$RUN1/doc1.md	4	H3	path	qux	candidate
EOF
cat > "$RUN1/out/P1.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
| D1 | H1 | 1 | 1 |
| D1 | H2 | 2 | 1 |
| D1 | H3 | 1 | 1 |
EOF

run_case "coverage-initial-reruns" $'reruns=2' "$RM" coverage "$RUN1"
assert_contains "coverage-rerun-tsv-h1" "$RUN1/rerun.tsv" "$(printf 'R1\tD1\tH1')"
assert_contains "coverage-rerun-tsv-h2" "$RUN1/rerun.tsv" "$(printf 'R2\tD1\tH2')"
assert_not_contains "coverage-rerun-tsv-h3-absent" "$RUN1/rerun.tsv" "H3"

cat > "$RUN1/out/R1.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
| D1 | H1 | 2 | 2 |
| D1 | H2 | 2 | 2 |
EOF

run_case "coverage-final-unverified-zero" $'unverified=0' "$RM" coverage "$RUN1" --final

###################################################################################################
# 2. prefilter ordering
###################################################################################################

RUN2="$T/run2"
mkdir -p "$RUN2/out"
: > "$RUN2/files.tsv"
write_context "$RUN2" "none"
write_request "$RUN2" "no" "none"

block() {
  # block ID FILE LINE SEV CAT FINDING QUOTE
  cat <<EOF
- **$1**
  - File: $2
  - Line: $3
  - Severity: $4
  - Category: $5
  - Finding: $6
  - Evidence: "$7" - checked.
  - Change: fix it.
  - Status: plausible
  - Raised by: proofread
EOF
}

{
  echo "### Findings"
  echo
  block D1.1 doc1.md 2 Minor polish "p1 finding one" "span one"
  echo
  block D1.2 doc1.md 3 Minor polish "p1 finding two" "span two"
  echo
  echo "### Coverage"
  echo
  echo "| Document | Heading | Claims found | Claims verified |"
  echo "| --- | --- | --- | --- |"
} > "$RUN2/out/P1.md"

{
  echo "### Findings"
  echo
  block D1.1 doc1.md 4 Minor polish "p2 finding one" "span three"
  echo
  block D1.2 doc1.md 5 Minor polish "p2 finding two" "span four"
  echo
  echo "### Coverage"
  echo
  echo "| Document | Heading | Claims found | Claims verified |"
  echo "| --- | --- | --- | --- |"
} > "$RUN2/out/P2.md"

{
  echo "### Findings"
  echo
  block D1.1 doc1.md 6 Minor polish "r1 finding one" "span five"
  echo
  echo "### Coverage"
  echo
  echo "| Document | Heading | Claims found | Claims verified |"
  echo "| --- | --- | --- | --- |"
} > "$RUN2/out/R1.md"

run_case "prefilter-counts" $'proofread-findings=5\ntracked=0' "$RM" prefilter "$RUN2"
for id in D1.1 D1.2 D1.3 D1.4 D1.5; do
  assert_contains "prefilter-has-$id" "$RUN2/proofread-findings.md" "- **$id**"
done
order_ok=1
prev=0
for id in D1.1 D1.2 D1.3 D1.4 D1.5; do
  ln="$(linenum "$RUN2/proofread-findings.md" "- **$id**")"
  [[ -n "$ln" && "$ln" -gt "$prev" ]] || order_ok=0
  prev="$ln"
done
record_result "prefilter-order-d1.1-to-d1.5" "$order_ok"

###################################################################################################
# 3. tracking
###################################################################################################

mk_tracking_run() {
  # mk_tracking_run NAME FRESH GITROOT_OR_NONE
  local name="$1" fresh="$2" gitrootflag="$3"
  local dir="$T/$name"
  mkdir -p "$dir/repo/.claude" "$dir/out"
  (cd "$dir/repo" && git init -q)
  printf 'Hello brown fox world.\n' > "$dir/repo/doc.md"
  cat > "$dir/repo/.claude/review-tracking.md" <<'EOF'
## doc.md
- [intentional] "brown fox" - already seen (accuracy, 2024-01-01)
EOF
  local gr="$dir/repo"
  [[ "$gitrootflag" == "none" ]] && gr="none"
  : > "$dir/files.tsv"
  printf 'D1\t%s/doc.md\t30\n' "$dir/repo" > "$dir/files.tsv"
  write_context "$dir" "$gr"
  write_request "$dir" "$fresh" "none"
  {
    echo "### Findings"
    echo
    block D1.1 doc.md 1 Minor accuracy "tracked finding" "brown fox"
    echo
    echo "### Coverage"
    echo
    echo "| Document | Heading | Claims found | Claims verified |"
    echo "| --- | --- | --- | --- |"
  } > "$dir/out/P1.md"
  echo "$dir"
}

RUN3A="$(mk_tracking_run run3a no repo)"
run_case "tracking-drop-match" $'proofread-findings=0\ntracked=1' "$RM" prefilter "$RUN3A"
assert_contains "tracking-drop-tracked-tsv" "$RUN3A/tracked.tsv" "$(printf 'D1.1\tdoc.md\tbrown fox')"

RUN3B="$T/run3b"
mkdir -p "$RUN3B/repo/.claude" "$RUN3B/out"
(cd "$RUN3B/repo" && git init -q)
printf 'Hello brown fox world.\n' > "$RUN3B/repo/doc.md"
cat > "$RUN3B/repo/.claude/review-tracking.md" <<'EOF'
## doc.md
- [intentional] "brown fox" - already seen (mechanical, 2024-01-01)
EOF
printf 'D1\t%s/doc.md\t30\n' "$RUN3B/repo" > "$RUN3B/files.tsv"
write_context "$RUN3B" "$RUN3B/repo"
write_request "$RUN3B" "no" "none"
{
  echo "### Findings"
  echo
  block D1.1 doc.md 1 Minor accuracy "tracked finding" "brown fox"
  echo
  echo "### Coverage"
  echo
  echo "| Document | Heading | Claims found | Claims verified |"
  echo "| --- | --- | --- | --- |"
} > "$RUN3B/out/P1.md"
run_case "tracking-category-mismatch-kept" $'proofread-findings=1\ntracked=0' "$RM" prefilter "$RUN3B"

RUN3C="$T/run3c"
mkdir -p "$RUN3C/repo/.claude" "$RUN3C/out"
(cd "$RUN3C/repo" && git init -q)
printf 'Hello world, nothing matches now.\n' > "$RUN3C/repo/doc.md"
cat > "$RUN3C/repo/.claude/review-tracking.md" <<'EOF'
## doc.md
- [intentional] "brown fox" - stale now (accuracy, 2024-01-01)
EOF
printf 'D1\t%s/doc.md\t30\n' "$RUN3C/repo" > "$RUN3C/files.tsv"
write_context "$RUN3C" "$RUN3C/repo"
write_request "$RUN3C" "no" "none"
{
  echo "### Findings"
  echo
  block D1.1 doc.md 1 Minor accuracy "unrelated finding" "Hello world"
  echo
  echo "### Coverage"
  echo
  echo "| Document | Heading | Claims found | Claims verified |"
  echo "| --- | --- | --- | --- |"
} > "$RUN3C/out/P1.md"
run_case "tracking-stale-entry-not-dropped" $'proofread-findings=1\ntracked=0' "$RM" prefilter "$RUN3C"

RUN3D="$(mk_tracking_run run3d yes repo)"
run_case "tracking-fresh-skips" $'proofread-findings=1\ntracked=0' "$RM" prefilter "$RUN3D"

RUN3E="$(mk_tracking_run run3e no none)"
run_case "tracking-gitroot-none-skips" $'proofread-findings=1\ntracked=0' "$RM" prefilter "$RUN3E"

# a two-file (set) finding whose File lines are b.md then a.md must still pair each file with its
# own quote, regardless of block order, since the heading and quote-join order are both sorted.
RUN3F="$T/run3f"
mkdir -p "$RUN3F/repo/.claude" "$RUN3F/out"
(cd "$RUN3F/repo" && git init -q)
printf 'Content with alpha text here.\n' > "$RUN3F/repo/a.md"
printf 'Content with beta text here.\n' > "$RUN3F/repo/b.md"
cat > "$RUN3F/repo/.claude/review-tracking.md" <<'EOF'
## set: a.md, b.md
- [intentional] "alpha text / beta text" - already seen (accuracy, 2024-01-01)
EOF
printf 'D1\t%s/a.md\t30\nD2\t%s/b.md\t30\n' "$RUN3F/repo" "$RUN3F/repo" > "$RUN3F/files.tsv"
write_context "$RUN3F" "$RUN3F/repo"
write_request "$RUN3F" "no" "none"
{
  echo "### Findings"
  echo
  cat <<'FIND'
- **D1.1**
  - File: b.md
  - Line: 1
  - File: a.md
  - Line: 1
  - Severity: Minor
  - Category: accuracy
  - Finding: cross file finding.
  - Evidence: "alpha text" - checked across both.
  - Change: fix it.
  - Status: plausible
  - Raised by: proofread
FIND
  echo
  echo "### Coverage"
  echo
  echo "| Document | Heading | Claims found | Claims verified |"
  echo "| --- | --- | --- | --- |"
} > "$RUN3F/out/P1.md"
run_case "tracking-set-order-independent-pairing" $'proofread-findings=0\ntracked=1' "$RM" prefilter "$RUN3F"

###################################################################################################
# helper to scaffold a minimal merge run
###################################################################################################

# mk_merge_base DIR GITROOT
mk_merge_base() {
  local dir="$1" gr="$2"
  mkdir -p "$dir/out"
  write_context "$dir" "$gr"
  write_request "$dir" "yes" "none"
  : > "$dir/script-findings.md"
  : > "$dir/proofread-findings.md"
  : > "$dir/units.tsv"
  : > "$dir/groups.tsv"
  : > "$dir/files.tsv"
}

###################################################################################################
# 4. merge: verification rows
###################################################################################################

RUN4="$T/run4/repo"
mkdir -p "$RUN4"
mk_merge_base "$T/run4" "$RUN4"
printf 'D1\t%s/doc.md\t100\n' "$RUN4" > "$T/run4/files.tsv"
printf 'doc.md line %s\n' $(seq 1 10) > "$RUN4/doc.md"
printf 'P1\tD1\twhole document\n' > "$T/run4/units.tsv"
printf 'A1\tD1\n' > "$T/run4/groups.tsv"
cat > "$T/run4/out/P1.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
EOF
cat > "$T/run4/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose" (doc.md:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
cat > "$T/run4/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |
| D1.1 | rejected | - | not needed |
| D1.2 | confirmed | Use X instead. | checked ok |

### Propagation

No concern.
EOF
{
  block D1.1 doc.md 5 Minor polish "Alpha issue." "alpha span"
  echo
  block D1.2 doc.md 6 Major accuracy "Beta issue." "beta span"
  echo
  block D1.3 doc.md 7 Minor omission "Gamma issue." "gamma span"
} > "$T/run4/proofread-findings.md"
mkdir -p "$T/run4/docs/D1"
printf '%s/doc.md\t3\thttp://example.com\tskipped:no network\n' "$RUN4" > "$T/run4/docs/D1/links.tsv"

run_case "merge-verification-counts" $'findings=2\ndecl=Run: proofread=1 docs; judgment=dispatched(sonnet); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run4" --tier sonnet
assert_not_contains "merge-rejected-dropped" "$T/run4/report-draft.md" "Alpha issue."
assert_contains "merge-confirmed-kept" "$T/run4/report-draft.md" "Beta issue."
assert_contains "merge-confirmed-bestcase-replaced" "$T/run4/report-draft.md" "Best case: Use X instead."
assert_contains "merge-no-row-plausible" "$T/run4/report-draft.md" "Gamma issue."
assert_contains "merge-no-row-status-plausible" "$T/run4/report-draft.md" "Status: plausible"
assert_contains "merge-skipped-link-bullet" "$T/run4/report-draft.md" "- doc.md:3 http://example.com: link not checked (no network)."
check_report "merge-verification" "$T/run4/report-draft.md"

###################################################################################################
# 5. merge: stale script finding dropped
###################################################################################################

RUN5="$T/run5/repo"
mkdir -p "$RUN5"
mk_merge_base "$T/run5" "$RUN5"
printf 'D1\t%s/doc.md\t100\n' "$RUN5" > "$T/run5/files.tsv"
printf 'line one\nline two\nline three changed\n' > "$RUN5/doc.md"
cat > "$T/run5/script-findings.md" <<EOF
- **S1**
  - File: doc.md
  - Line: 3
  - Severity: Minor
  - Category: mechanical
  - Finding: Script finding whose quote is gone.
  - Evidence: "line three original" - mechanical check.
  - Change: fix it.
  - Status: plausible
  - Raised by: script
EOF

run_case "merge-stale-script-finding-dropped" $'findings=0\ndecl=Run: proofread=0 docs; judgment=dispatched(sonnet); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run5" --tier sonnet
check_report "merge-stale-script" "$T/run5/report-draft.md"

###################################################################################################
# 6. merge: duplicates
###################################################################################################

RUN6="$T/run6/repo"
mkdir -p "$RUN6"
mk_merge_base "$T/run6" "$RUN6"
printf 'D1\t%s/doc.md\t100\n' "$RUN6" > "$T/run6/files.tsv"
printf 'P1\tD1\twhole document\n' > "$T/run6/units.tsv"
printf 'A1\tD1\n' > "$T/run6/groups.tsv"
{
  for i in $(seq 1 9); do echo "filler line $i"; done
  echo "consistency check line text"
  for i in $(seq 1 9); do echo "filler line $i"; done
  echo "polish check script line quoted text here"
} > "$RUN6/doc.md"
cat > "$T/run6/out/P1.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
EOF
cat > "$T/run6/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose" (doc.md:1)
### Accuracy
No concern.
### Consistency
- **J1**
  - File: doc.md
  - Line: 10
  - Severity: Major
  - Category: consistency
  - Finding: Judgment consistency finding text.
  - Evidence: "ev-judge-1" - area pass check.
  - Change: fix differently.
  - Status: plausible
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
cat > "$T/run6/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |

### Propagation

No concern.
EOF
cat > "$T/run6/script-findings.md" <<'EOF'
- **S1**
  - File: doc.md
  - Line: 20
  - Severity: Minor
  - Category: polish
  - Finding: Script flavor finding text.
  - Evidence: "script line quoted" - mechanical check.
  - Change: tidy it.
  - Status: plausible
  - Raised by: script
EOF
{
  block D2.1 doc.md 10 Minor consistency "Proofread consistency finding text." "ev-proof-1"
  echo
  block D2.2 doc.md 20 Minor polish "Proofread polish finding text." "ev-proof-2"
} > "$T/run6/proofread-findings.md"

run_case "merge-duplicate-count" $'findings=2\ndecl=Run: proofread=1 docs; judgment=dispatched(sonnet); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run6" --tier sonnet
assert_contains "merge-dup-major-wins" "$T/run6/report-draft.md" "Judgment consistency finding text."
assert_not_contains "merge-dup-minor-proofread-dropped" "$T/run6/report-draft.md" "Proofread consistency finding text."
assert_contains "merge-dup-both-passes" "$T/run6/report-draft.md" "Raised by: both passes"
assert_contains "merge-dup-tie-script-kept" "$T/run6/report-draft.md" "Script flavor finding text."
assert_not_contains "merge-dup-tie-proofread-dropped" "$T/run6/report-draft.md" "Proofread polish finding text."
check_report "merge-duplicates" "$T/run6/report-draft.md"

###################################################################################################
# 7. placement and order
###################################################################################################

RUN7="$T/run7/repo"
mkdir -p "$RUN7"
mk_merge_base "$T/run7" "$RUN7"
printf 'D1\t%s/doc1.md\t100\nD2\t%s/doc2.md\t100\n' "$RUN7" "$RUN7" > "$T/run7/files.tsv"
printf 'P1\tD1\twhole document\nP2\tD2\twhole document\n' > "$T/run7/units.tsv"
printf 'A1\tD1\nA1\tD2\n' > "$T/run7/groups.tsv"
printf 'line %s\n' $(seq 1 20) > "$RUN7/doc1.md"
printf 'line %s\n' $(seq 1 20) > "$RUN7/doc2.md"
cat > "$T/run7/out/P1.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
EOF
cat > "$T/run7/out/P2.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
EOF
cat > "$T/run7/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose 1" (doc1.md:1)
D2: stated - "purpose 2" (doc2.md:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
### Across the set
- **J1**
  - File: doc1.md
  - Line: 1
  - Severity: Minor
  - Category: omission
  - Finding: Across-heading finding.
  - Evidence: "across heading span" - area pass check.
  - Change: none.
  - Status: plausible
EOF
cat > "$T/run7/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |

### Propagation

No concern.
EOF
{
  block D1.1 doc1.md 5 Major accuracy "D1 major at line five." "span a"
  echo
  block D1.2 doc1.md 2 Major accuracy "D1 major at line two." "span b"
  echo
  block D1.3 doc1.md 8 Blocker accuracy "D1 blocker at line eight." "span c"
  echo
  block D2.1 doc2.md 1 Minor accuracy "D2 minor at line one." "span d"
  echo
  cat <<FIND
- **X1**
  - File: doc1.md
  - Line: 3
  - File: doc2.md
  - Line: 4
  - Severity: Minor
  - Category: drift
  - Finding: Cross-file finding.
  - Evidence: "cross file span" - checked across both.
  - Change: none.
  - Status: plausible
  - Raised by: proofread
FIND
} > "$T/run7/proofread-findings.md"

run_case "merge-placement-count" $'findings=6\ndecl=Run: proofread=2 docs; judgment=dispatched(sonnet); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run7" --tier sonnet

REPORT7="$T/run7/report-draft.md"
order_ok=1
prev=0
for pat in "D1 blocker at line eight." "D1 major at line two." "D1 major at line five." "D2 minor at line one." "Across-heading finding." "Cross-file finding."; do
  ln="$(linenum "$REPORT7" "$pat")"
  if [[ -z "$ln" || "$ln" -le "$prev" ]]; then order_ok=0; fi
  prev="$ln"
done
record_result "merge-placement-order" "$order_ok"
check_report "merge-placement" "$REPORT7"

# single-document review has no "### Across the set" heading.
RUN7B="$T/run7b/repo"
mkdir -p "$RUN7B"
mk_merge_base "$T/run7b" "$RUN7B"
printf 'D1\t%s/doc1.md\t100\n' "$RUN7B" > "$T/run7b/files.tsv"
printf 'P1\tD1\twhole document\n' > "$T/run7b/units.tsv"
printf 'A1\tD1\n' > "$T/run7b/groups.tsv"
printf 'line %s\n' $(seq 1 5) > "$RUN7B/doc1.md"
cat > "$T/run7b/out/P1.md" <<'EOF'
### Findings

No concern.

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
EOF
cat > "$T/run7b/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose 1" (doc1.md:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
cat > "$T/run7b/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |

### Propagation

No concern.
EOF
block D1.1 doc1.md 1 Minor accuracy "single doc finding." "span e" > "$T/run7b/proofread-findings.md"

"$RM" merge "$T/run7b" --tier sonnet >/dev/null 2>&1
assert_not_contains "merge-single-doc-no-across-heading" "$T/run7b/report-draft.md" "### Across the set"

###################################################################################################
# 8. judgment field
###################################################################################################

# 8a. missing out/V1.md -> failed (V1 missing)
RUN8A="$T/run8a/repo"
mkdir -p "$RUN8A"
mk_merge_base "$T/run8a" "$RUN8A"
printf 'D1\t%s/doc.md\t100\n' "$RUN8A" > "$T/run8a/files.tsv"
printf 'line\n' > "$RUN8A/doc.md"
printf 'A1\tD1\n' > "$T/run8a/groups.tsv"
cat > "$T/run8a/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose" (doc.md:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
run_case "judgment-failed-v1-missing" 'findings=0
decl=Run: proofread=0 docs; judgment=failed (V1 missing); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run8a" --tier sonnet
check_report "judgment-failed" "$T/run8a/report-draft.md"

# 8b. two groups -> split into 2 groups(sonnet)
RUN8B="$T/run8b/repo"
mkdir -p "$RUN8B"
mk_merge_base "$T/run8b" "$RUN8B"
printf 'D1\t%s/doc1.md\t100\nD2\t%s/doc2.md\t100\n' "$RUN8B" "$RUN8B" > "$T/run8b/files.tsv"
printf 'line\n' > "$RUN8B/doc1.md"
printf 'line\n' > "$RUN8B/doc2.md"
printf 'A1\tD1\nA2\tD2\n' > "$T/run8b/groups.tsv"
for g in A1 A2; do
  v="${g/A/V}"
  did="D1"
  [[ "$g" == "A2" ]] && did="D2"
  docf="doc1.md"
  [[ "$g" == "A2" ]] && docf="doc2.md"
  cat > "$T/run8b/out/$g.md" <<EOF
### Purpose measured against
$did: stated - "purpose" ($docf:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
  cat > "$T/run8b/out/$v.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |

### Propagation

No concern.
EOF
done
run_case "judgment-two-groups" 'findings=0
decl=Run: proofread=0 docs; judgment=split into 2 groups(sonnet); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run8b" --tier sonnet
check_report "judgment-two-groups" "$T/run8b/report-draft.md"

# 8c. --tier opus, single group -> dispatched(opus)
RUN8C="$T/run8c/repo"
mkdir -p "$RUN8C"
mk_merge_base "$T/run8c" "$RUN8C"
printf 'D1\t%s/doc.md\t100\n' "$RUN8C" > "$T/run8c/files.tsv"
printf 'line\n' > "$RUN8C/doc.md"
printf 'A1\tD1\n' > "$T/run8c/groups.tsv"
cat > "$T/run8c/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose" (doc.md:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
cat > "$T/run8c/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |

### Propagation

No concern.
EOF
run_case "judgment-tier-opus" 'findings=0
decl=Run: proofread=0 docs; judgment=dispatched(opus); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run8c" --tier opus
check_report "judgment-tier-opus" "$T/run8c/report-draft.md"

###################################################################################################
# 9. deferred entries in scope: a set: section counts only when one of its files is relevant.
###################################################################################################

RUN9="$T/run9/repo"
mkdir -p "$RUN9/.claude"
mk_merge_base "$T/run9" "$RUN9"
printf 'D1\t%s/doc.md\t100\n' "$RUN9" > "$T/run9/files.tsv"
printf 'line\n' > "$RUN9/doc.md"
printf 'A1\tD1\n' > "$T/run9/groups.tsv"
cat > "$T/run9/out/A1.md" <<'EOF'
### Purpose measured against
D1: stated - "purpose" (doc.md:1)
### Accuracy
No concern.
### Consistency
No concern.
### Purpose and fit
No concern.
### Omissions
No concern.
EOF
cat > "$T/run9/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |

### Propagation

No concern.
EOF
cat > "$RUN9/.claude/review-tracking.md" <<'EOF'
## set: doc.md, other.md
- [deferred] "in scope entry" - note (accuracy, 2024-01-01)

## set: other.md, zzz.md
- [deferred] "out of scope entry" - note2 (accuracy, 2024-01-01)
EOF

"$RM" merge "$T/run9" --tier sonnet >/dev/null 2>&1
assert_contains "merge-deferred-set-in-scope-counted" "$T/run9/report-draft.md" "Deferred entries in scope: 1"

###################################################################################################
# 10. record
###################################################################################################

RUN10="$T/run10/repo"
mkdir -p "$RUN10"
mkdir -p "$T/run10"
printf 'alpha file content.\n' > "$RUN10/doc.md"
printf 'alpha file content.\n' > "$RUN10/doc1.md"
printf 'alpha file content.\n' > "$RUN10/doc2.md"
write_context "$T/run10" "$RUN10"
cat > "$T/run10/findings.json" <<EOF
{"findings":[
  {"id":"F1","files":["doc.md"],"lines":[1],"severity":"Minor","category":"accuracy","quote":"alpha","raised_by":"proofread","status":"plausible","across":false},
  {"id":"F2","files":["doc2.md","doc1.md"],"lines":[1,1],"severity":"Major","category":"polish","quote":"beta","raised_by":"judgment","status":"plausible","across":true}
]}
EOF

TODAY="$(date +%Y-%m-%d)"

# shellcheck disable=SC2016 # single-quoted on purpose: $T must stay literal, not expand here.
run_case "record-first" 'recorded $T/run10/repo/.claude/review-tracking.md' "$RM" record "$T/run10" F1 deferred "desc1"
assert_contains "record-first-entry" "$RUN10/.claude/review-tracking.md" "## doc.md"
assert_contains "record-first-entry-line" "$RUN10/.claude/review-tracking.md" "- [deferred] \"alpha\" - desc1 (accuracy, $TODAY)"

"$RM" record "$T/run10" F1 intentional "desc2" >/dev/null 2>&1
assert_contains "record-replace-entry" "$RUN10/.claude/review-tracking.md" "- [intentional] \"alpha\" - desc2 (accuracy, $TODAY)"
assert_not_contains "record-replace-no-duplicate" "$RUN10/.claude/review-tracking.md" "desc1"
cnt="$(grep -c '"alpha"' "$RUN10/.claude/review-tracking.md" 2>/dev/null || true)"
record_result "record-replace-single-entry" "$([[ "$cnt" -eq 1 ]] && echo 1 || echo 0)"

"$RM" record "$T/run10" F2 deferred "desc3" >/dev/null 2>&1
assert_contains "record-set-heading-sorted" "$RUN10/.claude/review-tracking.md" "## set: doc1.md, doc2.md"
assert_contains "record-set-entry" "$RUN10/.claude/review-tracking.md" "- [deferred] \"beta\" - desc3 (polish, $TODAY)"

RUN10B="$T/run10b"
mkdir -p "$RUN10B"
write_context "$RUN10B" "none"
cat > "$RUN10B/findings.json" <<'EOF'
{"findings":[{"id":"F1","files":["doc.md"],"lines":[1],"severity":"Minor","category":"accuracy","quote":"alpha","raised_by":"proofread","status":"plausible","across":false}]}
EOF
run_case "record-outside-git" $'not recorded: outside git' "$RM" record "$RUN10B" F1 deferred "desc"
record_result "record-outside-git-no-file-written" "$([[ ! -e "$T/run10b/.claude/review-tracking.md" && ! -e "$T/.claude/review-tracking.md" ]] && echo 1 || echo 0)"

# record with a corrupt findings.json exits 1 with a prefixed stderr line.
RUN10C="$T/run10c"
mkdir -p "$RUN10C"
write_context "$RUN10C" "none"
printf '{not valid json' > "$RUN10C/findings.json"
record_stderr="$("$RM" record "$RUN10C" F1 deferred "desc" 2>&1 1>/dev/null)"
record_rc=$?
record_result "record-corrupt-json-exit-1" "$([[ "$record_rc" -eq 1 ]] && echo 1 || echo 0)" "--- exit: $record_rc"
case "$record_stderr" in
  "review-merge.sh: "*) record_result "record-corrupt-json-stderr-prefix" 1 ;;
  *) record_result "record-corrupt-json-stderr-prefix" 0 "--- stderr: $record_stderr" ;;
esac

# record preserves a tracking file's title, prose, HTML comment, and a malformed entry line; it
# inserts a new entry after the last entry of an existing section, and appends a new section for
# a new file, without deleting anything else.
RUN12="$T/run12/repo"
mkdir -p "$RUN12/.claude"
cat > "$RUN12/.claude/review-tracking.md" <<'EOF'
# Review tracking

Intro paragraph text.

<!-- an html comment -->

## doc.md
- [intentional] "existing quote" - note (accuracy, 2024-01-01)
malformed line without brackets
EOF
printf 'alpha file content existing quote.\n' > "$RUN12/doc.md"
printf 'alpha file content other.\n' > "$RUN12/other.md"
mkdir -p "$T/run12"
write_context "$T/run12" "$RUN12"
cat > "$T/run12/findings.json" <<'EOF'
{"findings":[
  {"id":"F1","files":["doc.md"],"lines":[1],"severity":"Minor","category":"polish","quote":"new quote","raised_by":"proofread","status":"plausible","across":false},
  {"id":"F2","files":["other.md"],"lines":[1],"severity":"Minor","category":"accuracy","quote":"other quote","raised_by":"proofread","status":"plausible","across":false}
]}
EOF

"$RM" record "$T/run12" F1 deferred "desc-new" >/dev/null 2>&1
"$RM" record "$T/run12" F2 deferred "desc-other" >/dev/null 2>&1

TRACK12="$RUN12/.claude/review-tracking.md"
assert_contains "record-preserve-title" "$TRACK12" "# Review tracking"
assert_contains "record-preserve-intro" "$TRACK12" "Intro paragraph text."
assert_contains "record-preserve-comment" "$TRACK12" "<!-- an html comment -->"
assert_contains "record-preserve-malformed" "$TRACK12" "malformed line without brackets"
assert_contains "record-preserve-existing-entry" "$TRACK12" '- [intentional] "existing quote" - note (accuracy, 2024-01-01)'
assert_contains "record-new-entry-in-existing-section" "$TRACK12" "desc-new"
assert_contains "record-new-file-section" "$TRACK12" "## other.md"
assert_contains "record-new-file-entry" "$TRACK12" "desc-other"

order_ok=1
prev=0
for pat in "# Review tracking" "Intro paragraph text." "<!-- an html comment -->" "## doc.md" "existing quote" "malformed line without brackets"; do
  ln="$(linenum "$TRACK12" "$pat")"
  if [[ -z "$ln" || "$ln" -le "$prev" ]]; then order_ok=0; fi
  prev="$ln"
done
record_result "record-preserve-order" "$order_ok"

###################################################################################################
# 11. missing out/P1.md -> Not checked
###################################################################################################

RUN11="$T/run11/repo"
mkdir -p "$RUN11"
mk_merge_base "$T/run11" "$RUN11"
printf 'D1\t%s/doc.md\t100\n' "$RUN11" > "$T/run11/files.tsv"
printf 'line\n' > "$RUN11/doc.md"
printf 'P1\tD1\twhole document\n' > "$T/run11/units.tsv"

"$RM" merge "$T/run11" --tier sonnet >/dev/null 2>&1
assert_contains "merge-missing-p1-not-checked" "$T/run11/report-draft.md" "D1: not checked (proofread pass failed)."
check_report "merge-missing-p1" "$T/run11/report-draft.md"

###################################################################################################
# 12. merge: a finding's first File matches no reviewed document -> printed under its own heading
###################################################################################################

RUN13="$T/run13/repo"
mkdir -p "$RUN13"
mk_merge_base "$T/run13" "$RUN13"
printf 'D1\t%s/docs/a.md\t100\n' "$RUN13" > "$T/run13/files.tsv"
mkdir -p "$RUN13/docs"
printf 'line one\nline two\n' > "$RUN13/docs/a.md"
{
  block D1.1 a.md 1 Minor polish "Orphan finding." "span orphan"
} > "$T/run13/proofread-findings.md"

run_case "merge-orphan-file-findings-count" $'findings=1\ndecl=Run: proofread=0 docs; judgment=dispatched(sonnet); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=yes; skipped=none' \
  "$RM" merge "$T/run13" --tier sonnet
assert_contains "merge-orphan-file-heading" "$T/run13/report-draft.md" "#### a.md"
assert_contains "merge-orphan-file-fid" "$T/run13/report-draft.md" "- **F1**"
check_report "merge-orphan-file" "$T/run13/report-draft.md"

###################################################################################################

printf '%s/%s passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
