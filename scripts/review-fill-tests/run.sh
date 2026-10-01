#!/usr/bin/env bash
#
# review-fill-tests/run.sh - regression suite for scripts/review-fill.sh's "units" and "fill"
# subcommands (contracts A, C, and F in specs/skills.md).
#
# Each run directory is built by hand per contract A (files.tsv, skill.txt, request.md,
# docs/D<k>/ files, exclusions.txt, context.txt), and the skill directory's
# references/proofread-pass.md, area-pass.md, and verify-pass.md are small test templates (not
# the real skill's templates) using every slot that kind defines. Expected output is exact, after
# replacing the temp directory with the literal string $T.
#
# Usage: bash scripts/review-fill-tests/run.sh    (exits 0 only when every case passes)
#   REVIEW_FILL overrides the script under test.

set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_CONFIG_DIR="$ROOT"
FILL="${REVIEW_FILL:-$ROOT/scripts/review-fill.sh}"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0
total=0

# run_case NAME EXPECTED COMMAND...
#   Runs COMMAND, compares its stdout exactly with EXPECTED after replacing the temp directory
#   with the literal string $T.
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

# check NAME CONDITION_DESCRIPTION
#   Records a pass/fail for an assertion already evaluated by the caller into $cond (0 = pass).
check() {
  local name="$1" cond="$2" detail="$3"
  total=$((total + 1))
  if [[ "$cond" -eq 0 ]]; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n%s\n' "$name" "$detail"
  fi
}

# repeat_chars N CHAR  -> prints N copies of CHAR with no trailing newline
repeat_chars() {
  local n="$1" ch="$2"
  perl -e 'print "'"$ch"'" x '"$n"';'
}

# --- Shared skill directory, used by every case below ------------------------------------------
SKILL="$T/skill"
mkdir -p "$SKILL/references"

cat > "$SKILL/references/proofread-pass.md" <<'EOF'
some intro text for the model, outside the prompt markers
<!-- prompt start -->
## Documents
{{DOCUMENTS}}

{{CONTEXT_BLOCK}}

## Exclusions
{{EXCLUSIONS}}

## Claims
{{CLAIMS_FILES}}

## Signals
{{SIGNALS_FILES}}

## Spec
{{SPEC_FILES}}

## Links
{{LINK_TABLE}}

## Output
{{OUTPUT}}
<!-- prompt end -->
trailing text, also outside the markers
EOF

cat > "$SKILL/references/area-pass.md" <<'EOF'
<!-- prompt start -->
## Targets
{{TARGET_FILES}}

Group: {{GROUP}}
Multi-doc: {{MULTI_DOC}}

## Profile files
{{PROFILE_FILES}}

{{CONTEXT_BLOCK}}

## Exclusions
{{EXCLUSIONS}}

## Spec
{{SPEC_FILES}}

## Output
{{OUTPUT}}
<!-- prompt end -->
EOF

cat > "$SKILL/references/verify-pass.md" <<'EOF'
<!-- prompt start -->
## Findings
{{FINDINGS_FILE}}

## Targets
{{TARGET_FILES}}

{{CONTEXT_BLOCK}}

## Exclusions
{{EXCLUSIONS}}

## Spec
{{SPEC_FILES}}

## Output
{{OUTPUT}}
<!-- prompt end -->
EOF

# ================================================================================================
# Case 1: three documents of 10,000, 10,000, and 15,000 characters: units=2, P1 holds D1 and D2,
# P2 holds D3.
# ================================================================================================
R1="$T/run1"
mkdir -p "$R1"
repeat_chars 10000 x > "$R1/d1.md"
repeat_chars 10000 x > "$R1/d2.md"
repeat_chars 15000 x > "$R1/d3.md"
cat > "$R1/files.tsv" <<EOF
D1	$R1/d1.md	10000
D2	$R1/d2.md	10000
D3	$R1/d3.md	15000
EOF
cat > "$R1/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
review these
EOF

run_case "units-small-docs-first-fit" \
  $'units=2\ngroups=1\nP1\tD1,D2\twhole document | whole document\nP2\tD3\twhole document' \
  "$FILL" units "$R1"

# ================================================================================================
# Case 2: a 45,000-character document: its own unit, scope "whole document".
# ================================================================================================
R2="$T/run2"
mkdir -p "$R2"
repeat_chars 45000 x > "$R2/d1.md"
cat > "$R2/files.tsv" <<EOF
D1	$R2/d1.md	45000
EOF
cat > "$R2/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
review this
EOF

run_case "units-medium-doc-own-unit" \
  $'units=1\ngroups=1\nP1\tD1\twhole document' \
  "$FILL" units "$R2"

# ================================================================================================
# Case 3: a 130,000-character document of six H2 sections of about 21,600 characters each, with
# 200 characters of preamble: k = 3, three units, P1's scope starts
# "sections: (text above the first H2), " and each unit names two H2 sections.
# ================================================================================================
R3="$T/run3"
mkdir -p "$R3"
{
  repeat_chars 200 p
  printf '\n'
  for i in 1 2 3 4 5 6; do
    printf '## Section %s\n' "$i"
    repeat_chars 21593 x
    printf '\n'
  done
} > "$R3/d1.md"
chars3="$(perl -e 'binmode(STDOUT,":encoding(UTF-8)"); open(F,"<:encoding(UTF-8)",$ARGV[0]); local $/; print length(<F>);' "$R3/d1.md")"
cat > "$R3/files.tsv" <<EOF
D1	$R3/d1.md	$chars3
EOF
cat > "$R3/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
review this
EOF

run_case "units-large-doc-six-h2-sections" \
  $'units=3\ngroups=1\nP1\tD1\tsections: (text above the first H2), Section 1, Section 2\nP2\tD1\tsections: Section 3, Section 4\nP3\tD1\tsections: Section 5, Section 6' \
  "$FILL" units "$R3"

# ================================================================================================
# Case 4: a document whose one H2 section is over 60,000 characters with three H3 subsections:
# the scopes use "<H2 text> > <H3 text>" names.
# ================================================================================================
R4="$T/run4"
mkdir -p "$R4"
{
  repeat_chars 100 p
  printf '\n## Big\nintro text\n'
  for i in 1 2 3; do
    printf '### Sub %s\n' "$i"
    repeat_chars 21980 x
    printf '\n'
  done
} > "$R4/d1.md"
chars4="$(perl -e 'binmode(STDOUT,":encoding(UTF-8)"); open(F,"<:encoding(UTF-8)",$ARGV[0]); local $/; print length(<F>);' "$R4/d1.md")"
cat > "$R4/files.tsv" <<EOF
D1	$R4/d1.md	$chars4
EOF
cat > "$R4/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
review this
EOF

run_case "units-oversized-h2-splits-into-h3" \
  $'units=3\ngroups=1\nP1\tD1\tsections: (text above the first H2), Big > Sub 1\nP2\tD1\tsections: Big > Sub 2\nP3\tD1\tsections: Big > Sub 3' \
  "$FILL" units "$R4"

# ================================================================================================
# Case 5: a "## Looks like a heading" line inside a fenced code block does not start a section.
# ================================================================================================
R5="$T/run5"
mkdir -p "$R5"
{
  repeat_chars 100 p
  printf '\n## Real\n'
  repeat_chars 61000 x
  printf '\n```\n## Looks like a heading\n```\n'
} > "$R5/d1.md"
chars5="$(perl -e 'binmode(STDOUT,":encoding(UTF-8)"); open(F,"<:encoding(UTF-8)",$ARGV[0]); local $/; print length(<F>);' "$R5/d1.md")"
cat > "$R5/files.tsv" <<EOF
D1	$R5/d1.md	$chars5
EOF
cat > "$R5/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
review this
EOF

run_case "units-fenced-fake-heading-ignored" \
  $'units=2\ngroups=1\nP1\tD1\tsections: (text above the first H2)\nP2\tD1\tsections: Real' \
  "$FILL" units "$R5"

# ================================================================================================
# Case 6: size-cap=groups with 30 small files in two directories: groups=2, no group over 25
# files.
# ================================================================================================
R6="$T/run6"
mkdir -p "$R6/dirA" "$R6/dirB"
: > "$R6/files.tsv"
for i in $(seq 1 20); do
  f="$R6/dirA/f$i.md"
  printf 'x\n' > "$f"
  printf 'D%s\t%s\t2\n' "$i" "$f" >> "$R6/files.tsv"
done
for i in $(seq 1 10); do
  j=$((20 + i))
  f="$R6/dirB/f$i.md"
  printf 'x\n' > "$f"
  printf 'D%s\t%s\t2\n' "$j" "$f" >> "$R6/files.tsv"
done
cat > "$R6/request.md" <<'EOF'
fresh=yes
size-cap=groups
skipped=none
--- request ---
review these
EOF

"$FILL" units "$R6" > "$T/case6.out" 2> "$T/case6.err"
case6_status=$?
case6_groups_line="$(sed -n '2p' "$T/case6.out")"
case6_max_group_files="$(cut -f1 "$R6/groups.tsv" | sort | uniq -c | awk '{print $1}' | sort -n | tail -1)"
case6_cond=1
[[ "$case6_status" -eq 0 && "$case6_groups_line" == "groups=2" ]] && case6_cond=0
check "units-groups-size-cap" "$case6_cond" \
  "status=$case6_status groups-line=[$case6_groups_line]"
case6_cond2=1
[[ "$case6_max_group_files" -le 25 ]] && case6_cond2=0
check "units-groups-no-group-over-25-files" "$case6_cond2" \
  "max group file count was $case6_max_group_files"

# ================================================================================================
# Case 7: fill proofread: every slot is replaced; {{CLAIMS_FILES}} says "- D1: none" for an empty
# claims file; {{LINK_TABLE}} is the table only when the unit has a non-empty links.tsv; the
# context block holds the request lines verbatim and "none" for deep-review.
# ================================================================================================
R7="$T/run7"
mkdir -p "$R7/docs/D1" "$R7/prompts"
printf 'doc one content\n' > "$R7/d1.md"
cat > "$R7/files.tsv" <<EOF
D1	$R7/d1.md	16
EOF
cat > "$R7/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
Please proofread this document.
Check the claims too.
EOF
echo "$SKILL" > "$R7/skill.txt"
echo "none" > "$R7/docs/D1/spec.md"
: > "$R7/docs/D1/claims.tsv"
: > "$R7/docs/D1/signals.txt"
: > "$R7/docs/D1/links.tsv"
echo "none" > "$R7/exclusions.txt"
cat > "$R7/units.tsv" <<EOF
P1	D1	whole document
EOF

"$FILL" fill "$R7" proofread > "$T/case7.out" 2>&1
actual7="$(cat "$R7/prompts/P1.md")"

cond=1
grep -qF -- "- D1: $R7/d1.md (scope: whole document)" "$R7/prompts/P1.md" && cond=0
check "fill-proofread-documents-slot" "$cond" "$actual7"

cond=1
grep -qF -- "Please proofread this document." "$R7/prompts/P1.md" \
  && grep -qF -- "Check the claims too." "$R7/prompts/P1.md" \
  && grep -qF -- "deep-review verdict and findings (source: deep-review): none" "$R7/prompts/P1.md" \
  && cond=0
check "fill-proofread-context-block-request-and-deep-review" "$cond" "$actual7"

cond=1
grep -qF -- "- D1: none" "$R7/prompts/P1.md" && cond=0
check "fill-proofread-claims-empty-is-none" "$cond" "$actual7"

cond=1
grep -qF -- "No link rows for these documents." "$R7/prompts/P1.md" && cond=0
check "fill-proofread-link-table-empty" "$cond" "$actual7"

cond=1
grep -qF -- "$R7/out/P1.md" "$R7/prompts/P1.md" && cond=0
check "fill-proofread-output-slot" "$cond" "$actual7"

# Now add a non-empty links.tsv for D1 and re-fill: LINK_TABLE should become the table.
printf '%s\t1\thttp://example.com\tok\n' "$R7/d1.md" > "$R7/docs/D1/links.tsv"
"$FILL" fill "$R7" proofread > /dev/null 2>&1
cond=1
grep -q '| `ok` | curl exit 0' "$R7/prompts/P1.md" && cond=0
check "fill-proofread-link-table-present" "$cond" \
  "LINK_TABLE did not contain the link-label table"

# claims.tsv with rows: "- D1: <path> (N rows)"
printf '%s\t1\theading\tpath\tclaim text\tcandidate\n' "$R7/d1.md" > "$R7/docs/D1/claims.tsv"
"$FILL" fill "$R7" proofread > /dev/null 2>&1
cond=1
grep -qF -- "- D1: $R7/docs/D1/claims.tsv (1 rows)" "$R7/prompts/P1.md" && cond=0
check "fill-proofread-claims-nonempty" "$cond" \
  "CLAIMS_FILES row count did not match"

# ================================================================================================
# Case 8: a slot value containing {{X}} and $HOME is copied literally.
# ================================================================================================
R8="$T/run8"
mkdir -p "$R8/docs/D1"
printf 'doc\n' > "$R8/d1.md"
cat > "$R8/files.tsv" <<EOF
D1	$R8/d1.md	4
EOF
cat > "$R8/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
req
EOF
echo "$SKILL" > "$R8/skill.txt"
echo "none" > "$R8/docs/D1/spec.md"
: > "$R8/docs/D1/claims.tsv"
: > "$R8/docs/D1/signals.txt"
: > "$R8/docs/D1/links.tsv"
printf 'exclude anything matching {{X}} or $HOME literally\n' > "$R8/exclusions.txt"
cat > "$R8/units.tsv" <<EOF
P1	D1	whole document
EOF

"$FILL" fill "$R8" proofread > /dev/null 2>&1
check "fill-slot-value-copied-literally" \
  "$(grep -qF 'exclude anything matching {{X}} or $HOME literally' "$R8/prompts/P1.md" && echo 0 || echo 1)" \
  "literal {{X}} / \$HOME text was altered"

# ================================================================================================
# Case 9: a template holding {{UNKNOWN}} makes fill exit 1; a template without the prompt markers
# makes it exit 1.
# ================================================================================================
R9="$T/run9"
mkdir -p "$R9/docs/D1"
printf 'doc\n' > "$R9/d1.md"
cat > "$R9/files.tsv" <<EOF
D1	$R9/d1.md	4
EOF
cat > "$R9/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
req
EOF
SKILL9="$T/skill9"
mkdir -p "$SKILL9/references"
echo "$SKILL9" > "$R9/skill.txt"
echo "none" > "$R9/docs/D1/spec.md"
: > "$R9/docs/D1/claims.tsv"
: > "$R9/docs/D1/signals.txt"
: > "$R9/docs/D1/links.tsv"
echo "none" > "$R9/exclusions.txt"
cat > "$R9/units.tsv" <<EOF
P1	D1	whole document
EOF

cat > "$SKILL9/references/proofread-pass.md" <<'EOF'
<!-- prompt start -->
{{UNKNOWN}}
<!-- prompt end -->
EOF
"$FILL" fill "$R9" proofread >/dev/null 2>"$T/case9a.err"
status9a=$?
check "fill-unknown-slot-exits-1" \
  "$([[ $status9a -eq 1 && "$(cat "$T/case9a.err")" == "review-fill.sh: "* ]] && echo 0 || echo 1)" \
  "status=$status9a stderr=$(cat "$T/case9a.err")"

cat > "$SKILL9/references/proofread-pass.md" <<'EOF'
no prompt markers in this file at all
EOF
"$FILL" fill "$R9" proofread >/dev/null 2>"$T/case9b.err"
status9b=$?
check "fill-missing-markers-exits-1" \
  "$([[ $status9b -eq 1 && "$(cat "$T/case9b.err")" == "review-fill.sh: "* ]] && echo 0 || echo 1)" \
  "status=$status9b stderr=$(cat "$T/case9b.err")"

# ================================================================================================
# Case 10: fill verify writes prompts/V<g>-findings.md with only the blocks whose first File is
# in the group, and {{FINDINGS_FILE}} is "none" when no block is.
# ================================================================================================
R10="$T/run10"
mkdir -p "$R10/docs/D1" "$R10/docs/D2" "$R10/docs/D3"
printf 'one\n' > "$R10/d1.md"
printf 'two\n' > "$R10/d2.md"
printf 'three\n' > "$R10/d3.md"
cat > "$R10/files.tsv" <<EOF
D1	$R10/d1.md	4
D2	$R10/d2.md	4
D3	$R10/d3.md	6
EOF
cat > "$R10/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
req
EOF
echo "$SKILL" > "$R10/skill.txt"
for d in D1 D2 D3; do
  echo "none" > "$R10/docs/$d/spec.md"
  : > "$R10/docs/$d/claims.tsv"
  : > "$R10/docs/$d/signals.txt"
  : > "$R10/docs/$d/links.tsv"
done
echo "none" > "$R10/exclusions.txt"
cat > "$R10/groups.tsv" <<EOF
A1	D1
A2	D2
A3	D3
EOF
cat > "$R10/context.txt" <<EOF
git-root=$T
ascii-rule=not adopted (no reason)
references-rule=not adopted
profile=none
agent-config=none
tools=none
EOF
cat > "$R10/proofread-findings.md" <<EOF
- **F1**
  - File: run10/d1.md
  - Line: 1
  - Severity: Minor
  - Category: polish
  - Finding: finding one
  - Evidence: "one" - checked wording
  - Change: tweak wording
  - Status: plausible
  - Raised by: proofread

- **F2**
  - File: run10/d2.md
  - Line: 1
  - Severity: Minor
  - Category: polish
  - Finding: finding two
  - Evidence: "two" - checked wording
  - Change: tweak wording
  - Status: plausible
  - Raised by: proofread
EOF

cat > "$T/expected_v1_findings.md" <<'EOF'
- **F1**
  - File: run10/d1.md
  - Line: 1
  - Severity: Minor
  - Category: polish
  - Finding: finding one
  - Evidence: "one" - checked wording
  - Change: tweak wording
  - Status: plausible
  - Raised by: proofread
EOF
cat > "$T/expected_v2_findings.md" <<'EOF'
- **F2**
  - File: run10/d2.md
  - Line: 1
  - Severity: Minor
  - Category: polish
  - Finding: finding two
  - Evidence: "two" - checked wording
  - Change: tweak wording
  - Status: plausible
  - Raised by: proofread
EOF

"$FILL" fill "$R10" verify > "$T/case10.out" 2>&1
check "fill-verify-findings-v1-has-f1" \
  "$(diff -q "$T/expected_v1_findings.md" "$R10/prompts/V1-findings.md" >/dev/null 2>&1 && echo 0 || echo 1)" \
  "V1-findings.md: $(cat "$R10/prompts/V1-findings.md" 2>/dev/null || echo MISSING)"
check "fill-verify-findings-v2-has-f2" \
  "$(diff -q "$T/expected_v2_findings.md" "$R10/prompts/V2-findings.md" >/dev/null 2>&1 && echo 0 || echo 1)" \
  "V2-findings.md: $(cat "$R10/prompts/V2-findings.md" 2>/dev/null || echo MISSING)"
check "fill-verify-findings-v3-none" \
  "$([[ ! -e "$R10/prompts/V3-findings.md" ]] && grep -q '^## Findings$' "$R10/prompts/V3.md" && grep -qx 'none' "$R10/prompts/V3.md" && echo 0 || echo 1)" \
  "V3.md: $(cat "$R10/prompts/V3.md" 2>/dev/null || echo MISSING)"

# ================================================================================================
# Case 11: fill rerun with an empty rerun.tsv prints nothing and exits 0.
# ================================================================================================
R11="$T/run11"
mkdir -p "$R11/docs/D1"
printf 'doc\n' > "$R11/d1.md"
cat > "$R11/files.tsv" <<EOF
D1	$R11/d1.md	4
EOF
cat > "$R11/request.md" <<'EOF'
fresh=yes
size-cap=none
skipped=none
--- request ---
req
EOF
echo "$SKILL" > "$R11/skill.txt"
echo "none" > "$R11/docs/D1/spec.md"
: > "$R11/docs/D1/claims.tsv"
: > "$R11/docs/D1/signals.txt"
: > "$R11/docs/D1/links.tsv"
echo "none" > "$R11/exclusions.txt"
: > "$R11/rerun.tsv"

run_case "fill-rerun-empty-prints-nothing" "" "$FILL" fill "$R11" rerun
rerun_status=$("$FILL" fill "$R11" rerun >/dev/null 2>&1; echo $?)
check "fill-rerun-empty-exits-0" "$([[ "$rerun_status" -eq 0 ]] && echo 0 || echo 1)" "exit status was $rerun_status"

# ================================================================================================
# Case 12: printed fill lines are <ID> TAB <prompt path> TAB <output path>.
# ================================================================================================
printf 'R1\tD1\tsome heading\n' > "$R11/rerun.tsv"

run_case "fill-rerun-prints-id-prompt-output" \
  $'R1\t$T/run11/prompts/R1.md\t$T/run11/out/R1.md' \
  "$FILL" fill "$R11" rerun

printf '%s/%s passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
