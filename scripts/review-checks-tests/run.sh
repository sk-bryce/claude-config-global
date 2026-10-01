#!/usr/bin/env bash
#
# review-checks-tests/run.sh - regression suite for scripts/review-checks.sh (the "init" and "run"
# subcommands of Contract A, and Contract D, from specs/skills.md's review-md section).
#
# Every fixture is local: no network call is ever made (link-recheck-hook.sh is given no http(s)
# links), and every git repository used is a throwaway created with `git init -q` inside this
# suite's own mktemp -d directory, with no commit ever made in it.
#
# Usage: bash scripts/review-checks-tests/run.sh    (exits 0 only when every case passes)

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_CONFIG_DIR="$ROOT"
SCRIPT="$ROOT/scripts/review-checks.sh"

# A PATH that carries perl, git, awk, and the other core tools this script and its callees need,
# but deliberately excludes markdownlint and vale: each case that needs one of those two installed
# prepends its own stub bin directory instead.
BASEPATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

SKILL="$T/skill"
mkdir -p "$SKILL/assets/vale"
: > "$SKILL/assets/markdownlint.jsonc"
: > "$SKILL/assets/vale/.vale.ini"

pass=0
total=0

ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() {
  local name="$1"
  shift
  printf 'FAIL %s\n' "$name"
  [[ $# -gt 0 ]] && printf '%s\n' "$@"
}

# getval KEY TEXT - the value of the first "KEY=..." line in TEXT (plain prefix match, no regex).
getval() {
  local key="$1" text="$2"
  printf '%s\n' "$text" | awk -v k="$key=" 'index($0, k) == 1 { print substr($0, length(k) + 1); exit }'
}

# init SKILL_DIR FILE... - runs "init", prints the run directory.
do_init() {
  local skill="$1"
  shift
  local out rd
  out="$(PATH="$BASEPATH" "$SCRIPT" init --skill "$skill" "$@" 2>"$T/init.err")"
  rd="$(getval run-dir "$out")"
  printf '%s\n' "$rd"
}

# run_case NAME EXPECTED COMMAND... - compares stdout exactly, after replacing $T with the
# literal string $T. Used only for cases whose expected stdout never embeds a random path.
run_case() {
  local name="$1" expected="$2" actual
  shift 2
  total=$((total + 1))
  actual="$("$@" 2>/dev/null | sed "s|$T|\$T|g")"
  if [[ "$actual" == "$expected" ]]; then
    ok "$name"
  else
    bad "$name" "--- expected" "$expected" "--- actual" "$actual"
  fi
}

# ===================================================================================================
# Case 1: init prints the four lines; files.tsv counts a UTF-8 file correctly (café + newline = 5).
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c1"
printf 'café\n' > "$T/c1/a.md"
init_out="$(PATH="$BASEPATH" "$SCRIPT" init --skill "$SKILL" "$T/c1/a.md" 2>"$T/c1.err")"
init_status=$?
rd1="$(getval run-dir "$init_out")"
n1="$(getval files "$init_out")"
c1="$(getval chars "$init_out")"
oc1="$(getval over-cap "$init_out")"
fchars1=""
[[ -n "$rd1" && -f "$rd1/files.tsv" ]] && fchars1="$(awk -F'\t' '{print $3}' "$rd1/files.tsv")"
if [[ $init_status -eq 0 && -n "$rd1" && "$n1" == "1" && "$c1" == "5" && "$oc1" == "no" && "$fchars1" == "5" ]]; then
  ok "init-four-lines-and-utf8-char-count"
else
  bad "init-four-lines-and-utf8-char-count" \
    "status=$init_status files=$n1 chars=$c1 over-cap=$oc1 files.tsv-chars=$fchars1"
fi
[[ -n "$rd1" ]] && rm -rf "$rd1"

# ===================================================================================================
# Case 2: over-cap=yes above either threshold.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c2a"
for i in $(seq 1 26); do printf 'line\n' > "$T/c2a/f$i.md"; done
init_out="$(PATH="$BASEPATH" "$SCRIPT" init --skill "$SKILL" "$T"/c2a/*.md 2>"$T/c2a.err")"
rd2a="$(getval run-dir "$init_out")"
oc2a="$(getval over-cap "$init_out")"
[[ -n "$rd2a" ]] && rm -rf "$rd2a"

total=$((total + 1))
mkdir -p "$T/c2b"
perl -e 'print "a" x 130000' > "$T/c2b/big1.md"
perl -e 'print "a" x 130000' > "$T/c2b/big2.md"
init_out="$(PATH="$BASEPATH" "$SCRIPT" init --skill "$SKILL" "$T/c2b/big1.md" "$T/c2b/big2.md" 2>"$T/c2b.err")"
rd2b="$(getval run-dir "$init_out")"
oc2b="$(getval over-cap "$init_out")"
[[ -n "$rd2b" ]] && rm -rf "$rd2b"

if [[ "$oc2a" == "yes" ]]; then ok "init-over-cap-file-count"; else bad "init-over-cap-file-count" "over-cap=$oc2a"; fi
if [[ "$oc2b" == "yes" ]]; then ok "init-over-cap-char-count"; else bad "init-over-cap-char-count" "over-cap=$oc2b"; fi

# ===================================================================================================
# Case 3: init with no --skill and no files exits 2 with a "review-checks.sh: " stderr line.
# ===================================================================================================
total=$((total + 1))
err3="$(PATH="$BASEPATH" "$SCRIPT" init 2>&1 >/dev/null)"
status3=$?
if [[ $status3 -eq 2 && "$err3" == "review-checks.sh: "* ]]; then
  ok "init-no-skill-no-files-exits-2"
else
  bad "init-no-skill-no-files-exits-2" "status=$status3 stderr=$err3"
fi

# ===================================================================================================
# Case 4: run with markdownlint and vale absent: the tools field ends with both "not installed"
# messages.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c4"
printf '# Doc\n\nHello world.\n' > "$T/c4/a.md"
rd4="$(do_init "$SKILL" "$T/c4/a.md")"
run_out4="$(PATH="$BASEPATH" "$SCRIPT" run "$rd4" --ascii not-adopted --ascii-reason test --references not-adopted 2>"$T/c4.err")"
tools4="$(getval tools "$run_out4")"
case "$tools4" in
  *"markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md)")
    ok "run-markdownlint-and-vale-absent" ;;
  *)
    bad "run-markdownlint-and-vale-absent" "tools=$tools4" ;;
esac
rm -rf "$rd4"

# ===================================================================================================
# Case 5: --ascii not-adopted: md-checks runs with --no-typography, a curly quote yields no
# finding, and exclusions.txt's md-checks line has no "typography, ".
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c5"
printf '# Doc\n\nThis has a \xe2\x80\x98curly\xe2\x80\x99 quote.\n' > "$T/c5/a.md"
rd5="$(do_init "$SKILL" "$T/c5/a.md")"
run_out5="$(PATH="$BASEPATH" "$SCRIPT" run "$rd5" --ascii not-adopted --ascii-reason test --references not-adopted 2>"$T/c5.err")"
findings5="$(getval script-findings "$run_out5")"
excl_mc5="$(grep '^md-checks:' "$rd5/exclusions.txt" || true)"
if [[ "$findings5" == "0" && "$excl_mc5" != *"typography, "* && -n "$excl_mc5" ]]; then
  ok "run-ascii-not-adopted-no-typography-finding"
else
  bad "run-ascii-not-adopted-no-typography-finding" "findings=$findings5 exclusions-md-checks-line=$excl_mc5"
fi
rm -rf "$rd5"

# ===================================================================================================
# Case 6: --ascii adopted: an em dash line yields a Minor mechanical finding whose Change: is the
# line with "-" in place of the em dash.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c6"
printf '# Doc\n\nA sentence\xe2\x80\x94with an em dash.\n' > "$T/c6/a.md"
rd6="$(do_init "$SKILL" "$T/c6/a.md")"
run_out6="$(PATH="$BASEPATH" "$SCRIPT" run "$rd6" --ascii adopted --ascii-reason test --references not-adopted 2>"$T/c6.err")"
sf6="$(cat "$rd6/script-findings.md" 2>/dev/null)"
if printf '%s\n' "$sf6" | grep -qF -- '- **S1**' \
  && printf '%s\n' "$sf6" | grep -qF '  - Severity: Minor' \
  && printf '%s\n' "$sf6" | grep -qF '  - Category: mechanical' \
  && printf '%s\n' "$sf6" | grep -qF '  - Change: A sentence-with an em dash.'; then
  ok "run-ascii-adopted-em-dash-change-line"
else
  bad "run-ascii-adopted-em-dash-change-line" "$sf6"
fi
rm -rf "$rd6"

# ===================================================================================================
# Case 7: a stub markdownlint reporting MD040/fenced-code-language on the same line md-checks
# reports fence-language: only the md-checks finding remains, and the tools field says
# markdownlint=ran.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c7" "$T/c7bin"
printf '# Doc\n\n```\nplain\n```\n' > "$T/c7/a.md"
cat > "$T/c7bin/markdownlint" <<'SH'
#!/usr/bin/env bash
shift 2
for f in "$@"; do
  printf '%s:3 MD040/fenced-code-language Fenced code blocks should have a language specified\n' "$f"
done
SH
chmod +x "$T/c7bin/markdownlint"
rd7="$(do_init "$SKILL" "$T/c7/a.md")"
run_out7="$(PATH="$T/c7bin:$BASEPATH" "$SCRIPT" run "$rd7" --ascii not-adopted --ascii-reason test --references not-adopted 2>"$T/c7.err")"
tools7="$(getval tools "$run_out7")"
sf7="$(cat "$rd7/script-findings.md" 2>/dev/null)"
fence_lang_count="$(printf '%s\n' "$sf7" | grep -cF 'add a language tag to the fence')"
polish_count="$(printf '%s\n' "$sf7" | grep -cF 'Category: polish')"
if [[ "$tools7" == *"markdownlint=ran"* && "$fence_lang_count" == "1" && "$polish_count" == "0" ]]; then
  ok "run-markdownlint-equivalent-dedup"
else
  bad "run-markdownlint-equivalent-dedup" "tools=$tools7 fence-lang=$fence_lang_count polish=$polish_count"
fi
rm -rf "$rd7"

# ===================================================================================================
# Case 8: a stub md-checks.sh that exits 3: the tools field says md-checks=error(3).
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c8" "$T/cfg8/scripts"
printf '# Doc\n\nHello.\n' > "$T/c8/a.md"
cp "$ROOT/scripts/link-recheck-hook.sh" "$ROOT/scripts/md-claims.sh" "$T/cfg8/scripts/"
cat > "$T/cfg8/scripts/md-checks.sh" <<'SH'
#!/usr/bin/env bash
exit 3
SH
chmod +x "$T/cfg8/scripts/md-checks.sh" "$T/cfg8/scripts/link-recheck-hook.sh" "$T/cfg8/scripts/md-claims.sh"
rd8="$(do_init "$SKILL" "$T/c8/a.md")"
run_out8="$(CLAUDE_CONFIG_DIR="$T/cfg8" PATH="$BASEPATH" "$SCRIPT" run "$rd8" --ascii not-adopted --ascii-reason test --references not-adopted 2>"$T/c8.err")"
tools8="$(getval tools "$run_out8")"
case "$tools8" in
  "md-checks=error(3), "*) ok "run-md-checks-error-exit" ;;
  *) bad "run-md-checks-error-exit" "tools=$tools8" ;;
esac
rm -rf "$rd8"

# ===================================================================================================
# Case 9: spec header extraction, with and without a matching heading.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c9/specs"
git -C "$T/c9" init -q
cat > "$T/c9/specs/x.md" <<'MD'
## Alpha

Alpha text line.

## Beta

Beta text.
MD
cat > "$T/c9/doc1.md" <<'MD'
spec: specs/x.md (alpha section)

# Doc1

Text here.
MD
cat > "$T/c9/doc2.md" <<'MD'
spec: specs/x.md (gamma section)

# Doc2

Text here.
MD
rd9="$(do_init "$SKILL" "$T/c9/doc1.md" "$T/c9/doc2.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd9" --ascii not-adopted --ascii-reason test --references not-adopted >/dev/null 2>"$T/c9.err"
spec_d1="$(cat "$rd9/docs/D1/spec.md" 2>/dev/null)"
spec_d2="$(cat "$rd9/docs/D2/spec.md" 2>/dev/null)"
expected_d1=$'Spec: specs/x.md (alpha)\nAlpha text line.'
expected_d2=$'Spec: specs/x.md (gamma)\nSection text not extracted; read the named section yourself.'
if [[ "$spec_d1" == "$expected_d1" && "$spec_d2" == "$expected_d2" ]]; then
  ok "run-spec-header-extraction"
else
  bad "run-spec-header-extraction" "--- D1 ---" "$spec_d1" "--- D2 ---" "$spec_d2"
fi
rm -rf "$rd9"

# ===================================================================================================
# Case 10: a file named SKILL.md is detected as agent-config.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c10"
printf '# A skill\n\nBody.\n' > "$T/c10/SKILL.md"
rd10="$(do_init "$SKILL" "$T/c10/SKILL.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd10" --ascii not-adopted --ascii-reason test --references not-adopted >/dev/null 2>"$T/c10.err"
ctx10="$(cat "$rd10/context.txt" 2>/dev/null)"
profile10="$(getval profile "$ctx10")"
ac10="$(getval agent-config "$ctx10")"
if [[ "$profile10" == "agent-config" && "$ac10" == "D1" ]]; then
  ok "run-skill-md-is-agent-config"
else
  bad "run-skill-md-is-agent-config" "profile=$profile10 agent-config=$ac10"
fi
rm -rf "$rd10"

# ===================================================================================================
# Case 11: a path claim to a missing file appears in claims.tsv; a found claim does not.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c11"
printf 'ok\n' > "$T/c11/README.md"
printf '# Doc\n\nSee `missing-file.txt` for details.\n\nSee `README.md` for more.\n' > "$T/c11/a.md"
rd11="$(do_init "$SKILL" "$T/c11/a.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd11" --ascii not-adopted --ascii-reason test --references not-adopted >/dev/null 2>"$T/c11.err"
claims11="$(cat "$rd11/docs/D1/claims.tsv" 2>/dev/null)"
if printf '%s\n' "$claims11" | grep -qF 'missing-file.txt' && ! printf '%s\n' "$claims11" | grep -qF 'README.md'; then
  ok "run-claims-tsv-missing-vs-found"
else
  bad "run-claims-tsv-missing-vs-found" "$claims11"
fi
rm -rf "$rd11"

# ===================================================================================================
# Case 12: outside a git repository, git-root=none and scrub-check=absent; inside one with a stub
# scripts/scrub-check.sh printing one finding, one Blocker hygiene finding results.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c12a"
printf '# Doc\n\nHello.\n' > "$T/c12a/a.md"
rd12a="$(do_init "$SKILL" "$T/c12a/a.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd12a" --ascii not-adopted --ascii-reason test --references not-adopted >/dev/null 2>"$T/c12a.err"
ctx12a="$(cat "$rd12a/context.txt" 2>/dev/null)"
gitroot12a="$(getval git-root "$ctx12a")"
tools12a="$(getval tools "$ctx12a")"
if [[ "$gitroot12a" == "none" && "$tools12a" == *"scrub-check=absent"* ]]; then
  ok "run-outside-git-root-none-scrub-absent"
else
  bad "run-outside-git-root-none-scrub-absent" "git-root=$gitroot12a tools=$tools12a"
fi
rm -rf "$rd12a"

total=$((total + 1))
mkdir -p "$T/c12b/scripts"
git -C "$T/c12b" init -q
printf '# Doc\n' > "$T/c12b/doc.md"
cat > "$T/c12b/scripts/scrub-check.sh" <<'SH'
#!/usr/bin/env bash
printf 'doc.md\n'
printf '  == identity ==\n'
printf '  doc.md:1 - fake identifier found\n'
SH
chmod +x "$T/c12b/scripts/scrub-check.sh"
rd12b="$(do_init "$SKILL" "$T/c12b/doc.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd12b" --ascii not-adopted --ascii-reason test --references not-adopted >/dev/null 2>"$T/c12b.err"
sf12b="$(cat "$rd12b/script-findings.md" 2>/dev/null)"
block_header_count="$(printf '%s\n' "$sf12b" | grep -cF -- '- **S1**')"
blocker_count="$(printf '%s\n' "$sf12b" | grep -cF '  - Severity: Blocker')"
hygiene_count="$(printf '%s\n' "$sf12b" | grep -cF '  - Category: hygiene')"
if [[ "$block_header_count" == "1" && "$blocker_count" == "1" && "$hygiene_count" == "1" ]]; then
  ok "run-inside-git-scrub-check-blocker-finding"
else
  bad "run-inside-git-scrub-check-blocker-finding" "$sf12b"
fi
rm -rf "$rd12b"

# ===================================================================================================
# Case 13: run with an unknown option exits 2.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c13"
printf '# Doc\n' > "$T/c13/a.md"
rd13="$(do_init "$SKILL" "$T/c13/a.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd13" --bogus >/dev/null 2>"$T/c13.err"
status13=$?
if [[ $status13 -eq 2 ]]; then
  ok "run-unknown-option-exits-2"
else
  bad "run-unknown-option-exits-2" "status=$status13"
fi
rm -rf "$rd13"

# ===================================================================================================
# Case 14: every block in a produced script-findings.md matches "- **S<n>**" followed by
# "  - File: ".
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c14"
printf '# Doc\n\nTODO: finish this.\n\n```\nunclosed\n' > "$T/c14/a.md"
rd14="$(do_init "$SKILL" "$T/c14/a.md")"
PATH="$BASEPATH" "$SCRIPT" run "$rd14" --ascii not-adopted --ascii-reason test --references not-adopted >/dev/null 2>"$T/c14.err"
sf14="$(cat "$rd14/script-findings.md" 2>/dev/null)"
block_count="$(printf '%s\n' "$sf14" | grep -c '^- \*\*S[0-9]\+\*\*$')"
bad_blocks="$(printf '%s\n' "$sf14" | awk '
  /^- \*\*S[0-9]+\*\*$/ { expect_file=1; next }
  expect_file { if ($0 !~ /^  - File: /) print "bad: " $0; expect_file=0 }
')"
if [[ "$block_count" -ge 2 && -z "$bad_blocks" ]]; then
  ok "script-findings-block-format"
else
  bad "script-findings-block-format" "blocks=$block_count bad=$bad_blocks" "$sf14"
fi
rm -rf "$rd14"

# ===================================================================================================
# Case 15: --ascii not-adopted with a reason containing parentheses exits 2.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c15"
printf '# Doc\n' > "$T/c15/a.md"
rd15="$(do_init "$SKILL" "$T/c15/a.md")"
err15="$(PATH="$BASEPATH" "$SCRIPT" run "$rd15" --ascii not-adopted --ascii-reason 'a (b)' --references not-adopted 2>&1 >/dev/null)"
status15=$?
if [[ $status15 -eq 2 && "$err15" == "review-checks.sh: "* ]]; then
  ok "run-ascii-reason-with-parens-exits-2"
else
  bad "run-ascii-reason-with-parens-exits-2" "status=$status15 stderr=$err15"
fi
rm -rf "$rd15"

# ===================================================================================================
# Case 16: a stub markdownlint emitting a row for a path containing a space yields a finding.
# ===================================================================================================
total=$((total + 1))
mkdir -p "$T/c16/my dir" "$T/c16bin"
printf '# Doc\n\nHello.\n' > "$T/c16/my dir/a b.md"
cat > "$T/c16bin/markdownlint" <<'SH'
#!/usr/bin/env bash
shift 2
for f in "$@"; do
  printf '%s:1 MD013/line-length Line too long\n' "$f"
done
SH
chmod +x "$T/c16bin/markdownlint"
rd16="$(do_init "$SKILL" "$T/c16/my dir/a b.md")"
run_out16="$(PATH="$T/c16bin:$BASEPATH" "$SCRIPT" run "$rd16" --ascii not-adopted --ascii-reason test --references not-adopted 2>"$T/c16.err")"
findings16="$(getval script-findings "$run_out16")"
if [[ "$findings16" == "1" ]]; then
  ok "run-markdownlint-path-with-space"
else
  bad "run-markdownlint-path-with-space" "findings=$findings16" "$(cat "$T/c16.err" 2>/dev/null)"
fi
rm -rf "$rd16"

printf '%s/%s passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
