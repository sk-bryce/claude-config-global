#!/usr/bin/env bash
#
# md-claims-tests/run.sh - regression suite for scripts/md-claims.sh. Each case builds a small
# fixture (plain files, or a throwaway git repo under $T) and runs md-claims.sh on it, comparing
# stdout exactly with the expected text after replacing the temp directory path with the literal
# string $T.
#
# Row-order convention (the contract leaves this open; pin it here so the implementer follows it):
# rows are emitted in the order their claims appear left to right on the line, with a command's
# extra --flag rows immediately after the command row, and a drift row immediately after the path
# row it is derived from. A freshness row is emitted at the position of its header line (sorted by
# line number like every other row). When two claims on the same line start at the same character
# position - the prose-heading-ref case, where the path claim and the heading-ref claim both begin
# at the same inline code span - the path row comes first and the heading-ref row second.
#
# Usage: bash scripts/md-claims-tests/run.sh    (exits 0 only when every case passes)

set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MCL="${MD_CLAIMS:-$ROOT/scripts/md-claims.sh}"   # MD_CLAIMS overrides the script under test
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
total=0

# run_case NAME EXPECTED COMMAND...
#   EXPECTED is the exact expected stdout, with $T standing for the temp directory. COMMAND is run
#   and its stdout compared after replacing $T with the literal string $T.
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

# ---------------------------------------------------------------------------
# Build a throwaway git repo at $T/repo1 holding every fixture that needs path
# resolution, heading-ref resolution, freshness, or drift.
# ---------------------------------------------------------------------------

mkdir -p "$T/repo1"/{sub-a,sub-b,sub-c,sub-d,sub-e,sub-f,sub-g,sub-h,sub-i,sub-j}

git -C "$T/repo1" init -q
git -C "$T/repo1" config user.name "Test"
git -C "$T/repo1" config user.email "test@example.com"
git -C "$T/repo1" config commit.gpgsign false

# --- fixtures used only as resolution targets ---

cat > "$T/repo1/other.md" <<'MD'
# Other

## Section One

Some content.
MD

echo "root only target" > "$T/repo1/root-only.md"
echo "root dup" > "$T/repo1/dup.md"
echo "docdir local target" > "$T/repo1/sub-a/local.md"
echo "docdir dup" > "$T/repo1/sub-d/dup.md"
echo "target v1" > "$T/repo1/sub-j/target-drift.md"

# --- path resolution: found via the doc's own directory ---

cat > "$T/repo1/sub-a/path-found-docdir.md" <<'MD'
See `local.md` here.
MD

# --- path resolution: found only via the git root ---

cat > "$T/repo1/sub-b/path-found-root.md" <<'MD'
See `root-only.md` here.
MD

# --- path resolution: not found anywhere ---

cat > "$T/repo1/sub-c/path-not-found.md" <<'MD'
See `nope.md` here.
MD

# --- path resolution: ambiguous (distinct matches in doc dir and git root) ---

cat > "$T/repo1/sub-d/path-ambiguous.md" <<'MD'
See `dup.md` here.
MD

# --- command claims: args whose first word exists / does not exist, with an extra flag row ---

cat > "$T/repo1/sub-e/command-args.md" <<'MD'
First: `ls -la` here.
Second: `not-found-by-script --flag` here.
MD

# --- a lone flag, an identifier, and a single-word command, kept separate ---

cat > "$T/repo1/sub-e/lone-flag.md" <<'MD'
Here is `--dry-run` alone.
MD

cat > "$T/repo1/sub-e/identifier.md" <<'MD'
Then `parse_config()` too.
MD

cat > "$T/repo1/sub-e/single-command.md" <<'MD'
Also `bash` runs.
MD

# --- heading-ref links: found, and to a renamed heading (not found) ---

cat > "$T/repo1/sub-f/heading-ref.md" <<'MD'
# Doc

See [link](other.md#section-one) for details.

See [link](other.md#section-two) for details.
MD

# --- a prose heading reference: path span + later quoted heading text ---

cat > "$T/repo1/sub-f/prose-heading-ref.md" <<'MD'
# Doc

The `other.md` covers this in "Section One".
MD

# --- dated claims: "as of" + version, and a bare YYYY-MM-DD ---

cat > "$T/repo1/sub-g/dated.md" <<'MD'
# Doc

Written as of v2.3, effective 2026-03-01.
MD

# --- fenced lines and frontmatter lines are never scanned ---

cat > "$T/repo1/sub-h/fences-frontmatter.md" <<'MD'
---
title: x
`ignored-fm.md`
---
# Doc

```text
`ignored-fence.md`
```

Real claim: `real-target.md` here.
MD

# --- freshness: header more than one day before the last commit, and one within a day ---

printf 'updated: 2025-12-01\n' > "$T/repo1/sub-i/freshness-stale.md"
printf 'updated: 2026-01-01\n' > "$T/repo1/sub-i/freshness-ok.md"

# --- drift: a path claim resolving to a tracked file committed later than the doc ---

cat > "$T/repo1/sub-j/drift-doc.md" <<'MD'
# Doc

See `target-drift.md` for details.
MD

# --- --extract: every result is "extracted", no freshness/drift rows ---

cat > "$T/repo1/extract-test.md" <<'MD'
# Extract Test

Here is `some/thing.py` and `bash` and `--dry-run` and `parse_config()`.
MD

# --- a non-Markdown file is skipped silently ---

echo "not markdown" > "$T/repo1/notes.txt"

# Commit everything above at a single, controlled date.
GIT_AUTHOR_DATE="2026-01-01T09:00:00" GIT_COMMITTER_DATE="2026-01-01T09:00:00" \
  git -C "$T/repo1" add -A
GIT_AUTHOR_DATE="2026-01-01T09:00:00" GIT_COMMITTER_DATE="2026-01-01T09:00:00" \
  git -C "$T/repo1" commit -q -m "initial"

# Modify and re-commit only the drift target, at a later date, so its last commit is newer than
# drift-doc.md's (which is untouched after the initial commit).
echo "target v2" >> "$T/repo1/sub-j/target-drift.md"
GIT_AUTHOR_DATE="2026-01-05T09:00:00" GIT_COMMITTER_DATE="2026-01-05T09:00:00" \
  git -C "$T/repo1" add sub-j/target-drift.md
GIT_AUTHOR_DATE="2026-01-05T09:00:00" GIT_COMMITTER_DATE="2026-01-05T09:00:00" \
  git -C "$T/repo1" commit -q -m "update target"

# --- a fixture outside any git repo: no freshness/drift rows even with a stale header ---

mkdir -p "$T/nogit"
cat > "$T/nogit/outside.md" <<'MD'
updated: 2020-01-01

# Doc

See `whatever.md` here.
MD

# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

run_case "path-found-docdir" $'$T/repo1/sub-a/path-found-docdir.md\t1\t-\tpath\tlocal.md\tfound' \
  bash "$MCL" "$T/repo1/sub-a/path-found-docdir.md"

run_case "path-found-root" $'$T/repo1/sub-b/path-found-root.md\t1\t-\tpath\troot-only.md\tfound' \
  bash "$MCL" "$T/repo1/sub-b/path-found-root.md"

run_case "path-not-found" $'$T/repo1/sub-c/path-not-found.md\t1\t-\tpath\tnope.md\tnot-found-by-script' \
  bash "$MCL" "$T/repo1/sub-c/path-not-found.md"

run_case "path-ambiguous" $'$T/repo1/sub-d/path-ambiguous.md\t1\t-\tpath\tdup.md\tcandidate' \
  bash "$MCL" "$T/repo1/sub-d/path-ambiguous.md"

run_case "command-args" $'$T/repo1/sub-e/command-args.md\t1\t-\tcommand\tls -la\tfound\n$T/repo1/sub-e/command-args.md\t2\t-\tcommand\tnot-found-by-script --flag\tnot-found-by-script\n$T/repo1/sub-e/command-args.md\t2\t-\tflag\t--flag\tcandidate' \
  bash "$MCL" "$T/repo1/sub-e/command-args.md"

run_case "lone-flag" $'$T/repo1/sub-e/lone-flag.md\t1\t-\tflag\t--dry-run\tcandidate' \
  bash "$MCL" "$T/repo1/sub-e/lone-flag.md"

run_case "identifier" $'$T/repo1/sub-e/identifier.md\t1\t-\tidentifier\tparse_config()\tcandidate' \
  bash "$MCL" "$T/repo1/sub-e/identifier.md"

run_case "single-command" $'$T/repo1/sub-e/single-command.md\t1\t-\tcommand\tbash\tfound' \
  bash "$MCL" "$T/repo1/sub-e/single-command.md"

run_case "heading-ref" $'$T/repo1/sub-f/heading-ref.md\t3\tDoc\theading-ref\tother.md#section-one\tfound\n$T/repo1/sub-f/heading-ref.md\t5\tDoc\theading-ref\tother.md#section-two\tnot-found-by-script' \
  bash "$MCL" "$T/repo1/sub-f/heading-ref.md"

run_case "prose-heading-ref" $'$T/repo1/sub-f/prose-heading-ref.md\t3\tDoc\tpath\tother.md\tfound\n$T/repo1/sub-f/prose-heading-ref.md\t3\tDoc\theading-ref\tother.md > Section One\tfound' \
  bash "$MCL" "$T/repo1/sub-f/prose-heading-ref.md"

run_case "dated" $'$T/repo1/sub-g/dated.md\t3\tDoc\tdated\tas of v2.3\tcandidate\n$T/repo1/sub-g/dated.md\t3\tDoc\tdated\t2026-03-01\tcandidate' \
  bash "$MCL" "$T/repo1/sub-g/dated.md"

run_case "fences-frontmatter" $'$T/repo1/sub-h/fences-frontmatter.md\t11\tDoc\tpath\treal-target.md\tnot-found-by-script' \
  bash "$MCL" "$T/repo1/sub-h/fences-frontmatter.md"

run_case "freshness-stale" $'$T/repo1/sub-i/freshness-stale.md\t1\t-\tfreshness\tupdated: 2025-12-01; last commit 2026-01-01\tstale-header' \
  bash "$MCL" "$T/repo1/sub-i/freshness-stale.md"

run_case "freshness-ok" '' \
  bash "$MCL" "$T/repo1/sub-i/freshness-ok.md"

run_case "drift" $'$T/repo1/sub-j/drift-doc.md\t3\tDoc\tpath\ttarget-drift.md\tfound\n$T/repo1/sub-j/drift-doc.md\t3\tDoc\tdrift\ttarget-drift.md\tnewer-than-doc' \
  bash "$MCL" "$T/repo1/sub-j/drift-doc.md"

run_case "extract" $'$T/repo1/extract-test.md\t3\tExtract Test\tpath\tsome/thing.py\textracted\n$T/repo1/extract-test.md\t3\tExtract Test\tcommand\tbash\textracted\n$T/repo1/extract-test.md\t3\tExtract Test\tflag\t--dry-run\textracted\n$T/repo1/extract-test.md\t3\tExtract Test\tidentifier\tparse_config()\textracted' \
  bash "$MCL" --extract "$T/repo1/extract-test.md"

run_case "non-markdown-skipped" '' \
  bash "$MCL" "$T/repo1/notes.txt"

run_case "outside-git-no-freshness-or-drift" $'$T/nogit/outside.md\t5\tDoc\tpath\twhatever.md\tnot-found-by-script' \
  bash "$MCL" "$T/nogit/outside.md"

# --- exit status 2: no file given ---

total=$((total + 1))
noargs_out="$(bash "$MCL" 2>"$T/noargs.stderr")"
noargs_rc=$?
noargs_err="$(cat "$T/noargs.stderr")"
if [[ -z "$noargs_out" && "$noargs_rc" -eq 2 && -n "$noargs_err" ]]; then
  pass=$((pass + 1)); printf 'ok   %s\n' "exit-2-no-file"
else
  printf 'FAIL %s\n--- expected\nexit 2, empty stdout, non-empty stderr\n--- actual\nexit %s, stdout=%q, stderr=%q\n' \
    "exit-2-no-file" "$noargs_rc" "$noargs_out" "$noargs_err"
fi

# --- exit status 2: unknown option ---

total=$((total + 1))
badopt_out="$(bash "$MCL" --bogus "$T/repo1/sub-a/path-found-docdir.md" 2>"$T/badopt.stderr")"
badopt_rc=$?
badopt_err="$(cat "$T/badopt.stderr")"
if [[ -z "$badopt_out" && "$badopt_rc" -eq 2 && -n "$badopt_err" ]]; then
  pass=$((pass + 1)); printf 'ok   %s\n' "exit-2-unknown-option"
else
  printf 'FAIL %s\n--- expected\nexit 2, empty stdout, non-empty stderr\n--- actual\nexit %s, stdout=%q, stderr=%q\n' \
    "exit-2-unknown-option" "$badopt_rc" "$badopt_out" "$badopt_err"
fi

printf '%d/%d passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
