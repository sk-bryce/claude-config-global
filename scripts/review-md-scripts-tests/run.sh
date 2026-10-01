#!/usr/bin/env bash
#
# review-md-scripts-tests/run.sh - end-to-end regression suite driving review-checks.sh,
# review-fill.sh, and review-merge.sh through one full review-md run directory, proving the three
# scripts and the three prompt templates (proofread-pass.md, area-pass.md, verify-pass.md) agree
# with each other and with CONTRACT A/B/R in specs/skills.md before any model ever runs them.
#
# Every fixture is local: the two source documents are copied from the review-md evals and every
# http(s) URL in the copies is stripped with perl before anything touches them, so no tool call
# here ever reaches the network. The only git repository used is a throwaway created with
# `git init -q` inside this suite's own mktemp -d directory, with no commit ever made in it.
#
# Usage: bash scripts/review-md-scripts-tests/run.sh    (exits 0 only when every case passes)

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_CONFIG_DIR="$ROOT"
CHECKS="$ROOT/scripts/review-checks.sh"
FILL="$ROOT/scripts/review-fill.sh"
MERGE="$ROOT/scripts/review-merge.sh"
SKILL_DIR="$ROOT/skills/review-md"

# A PATH that carries perl, git, awk, and the other core tools these scripts need, but
# deliberately excludes markdownlint and vale.
BASEPATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# Every run directory review-checks.sh creates lands under here, so the trap above cleans it up
# too.
export TMPDIR="$T"

pass=0
total=0

ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() {
  local name="$1"
  shift
  printf 'FAIL %s\n' "$name"
  [[ $# -gt 0 ]] && printf '%s\n' "$@"
}

# check NAME CONDITION -- CONDITION is 0 (true) or non-zero (false); extra args print on failure.
check() {
  local name="$1" cond="$2"
  shift 2
  total=$((total + 1))
  if [[ "$cond" -eq 0 ]]; then
    ok "$name"
  else
    bad "$name" "$@"
  fi
}

# getval KEY TEXT - the value of the first "KEY=..." line in TEXT (plain prefix match, no regex).
getval() {
  local key="$1" text="$2"
  printf '%s\n' "$text" | awk -v k="$key=" 'index($0, k) == 1 { print substr($0, length(k) + 1); exit }'
}

###################################################################################################
# Fixtures: two real review-md eval documents, copied into a throwaway git repo with every
# http(s) URL stripped.
###################################################################################################

REPO="$T/repo"
mkdir -p "$REPO/docs"
cp "$SKILL_DIR/evals/files/svc/docs/deploy.md" "$REPO/docs/deploy.md"
cp "$SKILL_DIR/evals/files/svc/docs/config.md" "$REPO/docs/config.md"
perl -pi -e 's{https?://\S+}{}g' "$REPO/docs/deploy.md" "$REPO/docs/config.md"
(cd "$REPO" && PATH="$BASEPATH" git init -q)

###################################################################################################
# 1. init
###################################################################################################

init_out="$(PATH="$BASEPATH" "$CHECKS" init --skill "$SKILL_DIR" "$REPO/docs/deploy.md" "$REPO/docs/config.md" 2>"$T/init.err")"
init_rc=$?
check "init-exit-zero" "$init_rc" "--- stderr" "$(cat "$T/init.err")"

RUN="$(getval run-dir "$init_out")"
files_val="$(getval files "$init_out")"
check "init-files-count" "$([[ "$files_val" == "2" ]]; echo $?)" "--- files=$files_val" "--- full output" "$init_out"

###################################################################################################
# 2. request.md
###################################################################################################

printf 'fresh=no\nsize-cap=none\nskipped=none\n--- request ---\nreview docs/\n' > "$RUN/request.md"

###################################################################################################
# 3. run
###################################################################################################

run_out="$(PATH="$BASEPATH" "$CHECKS" run "$RUN" --ascii not-adopted --ascii-reason "no CLAUDE.md or AGENTS.md" --references not-adopted 2>"$T/run.err")"
run_rc=$?
check "run-exit-zero" "$run_rc" "--- stderr" "$(cat "$T/run.err")" "--- stdout" "$run_out"

###################################################################################################
# 4. units
###################################################################################################

units_out="$(PATH="$BASEPATH" "$FILL" units "$RUN" 2>"$T/units.err")"
units_rc=$?
check "units-exit-zero" "$units_rc" "--- stderr" "$(cat "$T/units.err")"

units_val="$(getval units "$units_out")"
groups_val="$(getval groups "$units_out")"
check "units-count" "$([[ "$units_val" == "1" && "$groups_val" == "1" ]]; echo $?)" \
  "--- units=$units_val groups=$groups_val" "--- full output" "$units_out"

###################################################################################################
# 5. fill proofread, fill area
###################################################################################################

PATH="$BASEPATH" "$FILL" fill "$RUN" proofread >"$T/fill-proofread.out" 2>"$T/fill-proofread.err"
check "fill-proofread-exit-zero" "$?" "--- stderr" "$(cat "$T/fill-proofread.err")"

PATH="$BASEPATH" "$FILL" fill "$RUN" area >"$T/fill-area.out" 2>"$T/fill-area.err"
check "fill-area-exit-zero" "$?" "--- stderr" "$(cat "$T/fill-area.err")"

placeholder_hits="$(grep -rlF '{{' "$RUN/prompts/" 2>/dev/null || true)"
check "fill-no-placeholders-left" "$([[ -z "$placeholder_hits" ]]; echo $?)" "--- files with {{: $placeholder_hits"

mkdir -p "$RUN/out"

###################################################################################################
# 6. out/P1.md and out/A1.md, written by hand
###################################################################################################
#
# The Coverage table's headings and counts match docs/D1/claims.tsv and docs/D2/claims.tsv exactly
# (confirmed by running review-checks.sh on these fixtures), so step 7's coverage pass needs no
# reruns. D1.1's quoted span is a real sentence in the stripped deploy.md copy.

cat > "$RUN/out/P1.md" <<'EOF'
### Findings

- **D1.1**
  - File: docs/deploy.md
  - Line: 5
  - Severity: Minor
  - Category: polish
  - Finding: The deploy window sentence could be tightened.
  - Evidence: "We deploy on Tuesdays and Thursdays" - checked against the deploy window text.
  - Change: Deploys happen Tuesdays and Thursdays.
  - Status: plausible
  - Raised by: proofread

### Coverage

| Document | Heading | Claims found | Claims verified |
| --- | --- | --- | --- |
| D1 | Before you start | 1 | 1 |
| D1 | Install the release | 5 | 5 |
| D1 | Log rotation | 1 | 1 |
| D1 | Rolling back | 2 | 2 |
| D2 | Configuration reference | 3 | 3 |
| D2 | server | 5 | 5 |
| D2 | storage | 5 | 5 |
| D2 | queue | 2 | 2 |
| D2 | logging | 6 | 6 |
| D2 | metrics | 1 | 1 |
EOF

cat > "$RUN/out/A1.md" <<'EOF'
### Purpose measured against
D1: inferred - operational runbook for deploying ledgerd
D2: inferred - reference for ledgerd configuration keys
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
  - File: docs/deploy.md
  - Line: 18
  - Severity: Minor
  - Category: consistency
  - Finding: deploy.md and config.md should cross-reference the same config path consistently.
  - Evidence: "config/ledgerd.yaml" - compared the deploy and config pages for the same path.
  - Change: none.
  - Status: plausible
EOF

###################################################################################################
# 7. coverage, coverage --final
###################################################################################################

PATH="$BASEPATH" "$MERGE" coverage "$RUN" >"$T/coverage.out" 2>"$T/coverage.err"
check "coverage-exit-zero" "$?" "--- stderr" "$(cat "$T/coverage.err")" "--- stdout" "$(cat "$T/coverage.out")"

PATH="$BASEPATH" "$MERGE" coverage "$RUN" --final >"$T/coverage-final.out" 2>"$T/coverage-final.err"
check "coverage-final-exit-zero" "$?" "--- stderr" "$(cat "$T/coverage-final.err")" "--- stdout" "$(cat "$T/coverage-final.out")"

###################################################################################################
# 8. prefilter, fill verify
###################################################################################################

prefilter_out="$(PATH="$BASEPATH" "$MERGE" prefilter "$RUN" 2>"$T/prefilter.err")"
prefilter_rc=$?
check "prefilter-exit-zero" "$prefilter_rc" "--- stderr" "$(cat "$T/prefilter.err")"

proofread_findings_val="$(getval proofread-findings "$prefilter_out")"
check "prefilter-proofread-findings-count" "$([[ "$proofread_findings_val" == "1" ]]; echo $?)" \
  "--- proofread-findings=$proofread_findings_val" "--- full output" "$prefilter_out"

PATH="$BASEPATH" "$FILL" fill "$RUN" verify >"$T/fill-verify.out" 2>"$T/fill-verify.err"
check "fill-verify-exit-zero" "$?" "--- stderr" "$(cat "$T/fill-verify.err")"

check "fill-verify-v1-written" "$([[ -f "$RUN/prompts/V1.md" ]]; echo $?)"
verify_placeholder_hits="$(grep -lF '{{' "$RUN/prompts/V1.md" 2>/dev/null || true)"
check "fill-verify-no-placeholders-left" "$([[ -z "$verify_placeholder_hits" ]]; echo $?)"

###################################################################################################
# 9. out/V1.md, written by hand
###################################################################################################

cat > "$RUN/out/V1.md" <<'EOF'
### Verification

| Finding | Status | Best case | Note |
| --- | --- | --- | --- |
| D1.1 | confirmed | - | quote matches the deploy window sentence. |

### Propagation

No concern.
EOF

###################################################################################################
# 10. merge
###################################################################################################

merge_out="$(PATH="$BASEPATH" "$MERGE" merge "$RUN" --tier sonnet 2>"$T/merge.err")"
merge_rc=$?
check "merge-exit-zero" "$merge_rc" "--- stderr" "$(cat "$T/merge.err")"

decl_line="$(printf '%s\n' "$merge_out" | sed -n 's/^decl=//p')"
decl_match="$(perl -e '
  my $re = qr/^Run: proofread=\d+ docs; judgment=(?:dispatched\((?:sonnet|opus)\)|split into \d+ groups\((?:sonnet|opus)\)|failed \([^()]+\)); tools=md-checks=(?:ran|error\(\d+\)), links=(?:ran|error\(\d+\)), claims=(?:ran|error\(\d+\)), scrub-check=(?:ran|absent|error\(\d+\)), markdownlint=(?:ran|error\(\d+\)|not installed \(see references\/markdownlint-setup\.md\)), vale=(?:ran|error\(\d+\)|not installed \(see references\/vale-setup\.md\)); ascii-rule=(?:adopted|not adopted) \([^()]+\); references-rule=(?:adopted|not adopted); profile=(?:agent-config|none); fresh=(?:yes|no); skipped=(?:none|[^;]+)$/;
  print(($ARGV[0] =~ $re) ? "0" : "1");
' "$decl_line")"
check "merge-decl-matches-contract-r" "$decl_match" "--- decl: $decl_line"

REPORT="$RUN/report-draft.md"
l1="$(grep -n '^### Summary$' "$REPORT" | head -1 | cut -d: -f1)"
l2="$(grep -n '^### Per-document findings$' "$REPORT" | head -1 | cut -d: -f1)"
l3="$(grep -n '^### Across the set$' "$REPORT" | head -1 | cut -d: -f1)"
l4="$(grep -n '^### Applied changes$' "$REPORT" | head -1 | cut -d: -f1)"
l5="$(grep -n '^### Not checked$' "$REPORT" | head -1 | cut -d: -f1)"
headings_ok=1
if [[ -n "$l1" && -n "$l2" && -n "$l3" && -n "$l4" && -n "$l5" \
      && "$l1" -lt "$l2" && "$l2" -lt "$l3" && "$l3" -lt "$l4" && "$l4" -lt "$l5" ]]; then
  headings_ok=0
fi
check "merge-report-headings-in-order" "$headings_ok" "--- lines: $l1 $l2 $l3 $l4 $l5"

d11_confirmed=1
if grep -A 8 'Finding: The deploy window sentence could be tightened\.' "$REPORT" | grep -q '^\s*- Status: confirmed$'; then
  d11_confirmed=0
fi
check "merge-d1.1-status-confirmed" "$d11_confirmed" "--- report: $REPORT"

###################################################################################################
# 11. record
###################################################################################################

record_out="$(PATH="$BASEPATH" "$MERGE" record "$RUN" F1 deferred "test" 2>"$T/record.err")"
record_rc=$?
check "record-exit-zero" "$record_rc" "--- stderr" "$(cat "$T/record.err")" "--- stdout" "$record_out"

TRACKING="$REPO/.claude/review-tracking.md"
deferred_count=0
[[ -f "$TRACKING" ]] && deferred_count="$(grep -c '^- \[deferred\]' "$TRACKING" 2>/dev/null || true)"
[[ -n "$deferred_count" ]] || deferred_count=0
check "record-one-deferred-line" "$([[ "$deferred_count" -eq 1 ]]; echo $?)" \
  "--- deferred count: $deferred_count" "--- tracking file: $TRACKING"

###################################################################################################

printf '%s/%s passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
