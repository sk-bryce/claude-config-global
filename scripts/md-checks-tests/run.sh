#!/usr/bin/env bash
#
# md-checks-tests/run.sh - regression suite for scripts/md-checks.sh. Each case writes a small
# Markdown file into a temp directory, runs md-checks.sh on it, and compares stdout exactly with
# the expected text, after replacing the temp directory path with the literal string $T.
# Usage: bash scripts/md-checks-tests/run.sh    (exits 0 only when every case passes)

set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
MDC="${MD_CHECKS:-$ROOT/scripts/md-checks.sh}"   # MD_CHECKS overrides the script under test
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0
total=0

# run_case NAME OPTS FILE EXPECTED
#   OPTS is a string of options, word-split on purpose (may be empty). FILE is relative to $T.
#   EXPECTED is the exact expected stdout, with $T standing for the temp directory.
run_case() {
  local name="$1" opts="$2" file="$3" expected="$4" actual
  total=$((total + 1))
  # shellcheck disable=SC2086
  actual="$(bash "$MDC" $opts "$T/$file" 2>/dev/null | sed "s|$T|\$T|g")"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1)); printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n--- expected\n%s\n--- actual\n%s\n' "$name" "$expected" "$actual"
  fi
}

# 1. underscore anchor: matches an underscore-containing slug unchanged.
cat > "$T/underscore-anchor.md" <<'MD'
## retry_policy

[x](#retry_policy)
MD
run_case "underscore-anchor" "" "underscore-anchor.md" ""

# 2. duplicate-heading anchor: second "## Examples" gets slug "examples-1".
cat > "$T/duplicate-heading-anchor.md" <<'MD'
## Examples

## Examples

[x](#examples-1)
MD
run_case "duplicate-heading-anchor" "" "duplicate-heading-anchor.md" ""

# 3. link with a quoted title, target exists.
touch "$T/other.md"
cat > "$T/quoted-title-link.md" <<'MD'
# Title

[a](other.md "Title")
MD
run_case "quoted-title-link" "" "quoted-title-link.md" ""

# 4. Go generics call inside a fence is not a placeholder/heading/anything else.
cat > "$T/go-generics-fence.md" <<'MD'
# Title

```go
errors.AsType[T](err)
```
MD
run_case "go-generics-fence" "" "go-generics-fence.md" ""

# 5. TODO marker inside an inline code span is skipped.
cat > "$T/todo-inline-code.md" <<'MD'
# Title

Some text `TODO: x` here.
MD
run_case "todo-inline-code" "" "todo-inline-code.md" ""

# 6. tilde fence holding a backtick fence line: the backtick line does not close the tilde
# fence, the fenced "# Not a heading" is neither a heading nor a second H1, and #after resolves.
# The opener carries a language tag so --review adds no fence-language finding.
cat > "$T/tilde-fence-backtick-line.md" <<'MD'
# Title
~~~text
```
# Not a heading
~~~
## After
[x](#after)
MD
run_case "tilde-fence-backtick-line" "--review" "tilde-fence-backtick-line.md" ""

# 7. unclosed fence: reported on the opener's line.
cat > "$T/unclosed-fence.md" <<'MD'
# Title

```
code here
MD
run_case "unclosed-fence" "" "unclosed-fence.md" '$T/unclosed-fence.md
  == fences ==
  $T/unclosed-fence.md:3 - unclosed code fence'

# 8. arrow (U+2192) and multiplication sign (U+00D7) outside a fence, one per line.
cat > "$T/non-ascii-arrow-multiplication.md" <<'MD'
# Title

Line with arrow → here.

Line with multiplication × sign.
MD
run_case "non-ascii-arrow-multiplication" "" "non-ascii-arrow-multiplication.md" '$T/non-ascii-arrow-multiplication.md
  == typography ==
  $T/non-ascii-arrow-multiplication.md:3 - non-ASCII character U+2192
  $T/non-ascii-arrow-multiplication.md:5 - non-ASCII character U+00D7'

# 9. same file with --no-typography: no output.
run_case "non-ascii-no-typography" "--no-typography" "non-ascii-arrow-multiplication.md" ""

# 10. em dash.
cat > "$T/em-dash.md" <<'MD'
# Title

An em dash — here.
MD
run_case "em-dash" "" "em-dash.md" '$T/em-dash.md
  == typography ==
  $T/em-dash.md:3 - em dash (use "-" or restructure)'

# 11. Japanese Kanji and an ideographic full stop (U+3002): exempt, no output.
printf '# Title\n\n\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e\xe3\x80\x82\n' > "$T/kanji-ideographic-stop.md"
run_case "kanji-ideographic-stop" "" "kanji-ideographic-stop.md" ""

# 12. "#1 priority" is not a heading, so the H1 -> H3 skip is still reported for "### C".
cat > "$T/hash-not-heading.md" <<'MD'
# A

#1 priority

### C
MD
run_case "hash-not-heading" "" "hash-not-heading.md" '$T/hash-not-heading.md
  == headings ==
  $T/hash-not-heading.md:5 - heading level skips H1 -> H3'

# 13. fence-language: only reported with --review.
cat > "$T/fence-language.md" <<'MD'
# Title

```
code
```
MD
run_case "fence-language-review" "--review" "fence-language.md" '$T/fence-language.md
  == fence-language ==
  $T/fence-language.md:3 - code fence has no language tag'
run_case "fence-language-no-review" "" "fence-language.md" ""

# 14. alt-text: only reported with --review.
touch "$T/img.png"
cat > "$T/alt-text.md" <<'MD'
# Title

![](img.png)
MD
run_case "alt-text" "--review" "alt-text.md" '$T/alt-text.md
  == alt-text ==
  $T/alt-text.md:3 - image has empty alt text'

# 15. h1: first heading not H1, and a second H1.
cat > "$T/h1-not-first.md" <<'MD'
## A

Text
MD
run_case "h1-not-first" "--review" "h1-not-first.md" '$T/h1-not-first.md
  == h1 ==
  $T/h1-not-first.md:1 - first heading is not H1'

cat > "$T/h1-second.md" <<'MD'
# One

# Two
MD
run_case "h1-second" "--review" "h1-second.md" '$T/h1-second.md
  == h1 ==
  $T/h1-second.md:3 - more than one H1 heading'

# 16. sibling-headings: repeated sibling under the same parent; different parents give nothing.
cat > "$T/sibling-heading-repeat.md" <<'MD'
# Root

## Setup

## Setup
MD
run_case "sibling-heading-repeat" "--review" "sibling-heading-repeat.md" '$T/sibling-heading-repeat.md
  == sibling-headings ==
  $T/sibling-heading-repeat.md:5 - repeated sibling heading: Setup'

cat > "$T/sibling-heading-different-parent.md" <<'MD'
# Root

## A

### Setup

## B

### Setup
MD
run_case "sibling-heading-different-parent" "--review" "sibling-heading-different-parent.md" ""

# 17. frontmatter is never headings, so a "# Real" heading after it is the only, first H1.
cat > "$T/frontmatter-h1.md" <<'MD'
---
title: x
# comment
---
# Real
MD
run_case "frontmatter-h1" "--review" "frontmatter-h1.md" ""

# 18. missing relative link target.
cat > "$T/link-missing.md" <<'MD'
# Title

[a](missing.md)
MD
run_case "link-missing" "" "link-missing.md" '$T/link-missing.md
  == links ==
  $T/link-missing.md:3 - relative link target does not exist: missing.md'

# 19. angle-bracket target with a space, target exists.
touch "$T/my file.md"
cat > "$T/angle-bracket-link.md" <<'MD'
# Title

[a](<my file.md>)
MD
run_case "angle-bracket-link" "" "angle-bracket-link.md" ""

# 20. non-ASCII letter anchor: heading and link share the same last letter (e with acute, U+00E9).
printf '## Caf\xc3\xa9\n\n[x](#caf\xc3\xa9)\n' > "$T/anchor-nonascii.md"
run_case "anchor-nonascii" "" "anchor-nonascii.md" ""

# 21. unknown option: warns on stderr, exits 0, and still checks the file.
cat > "$T/unknown-opt.md" <<'MD'
# Title

An em dash — here.
MD
total=$((total + 1))
raw_out="$(bash "$MDC" --bogus "$T/unknown-opt.md" 2>"$T/unknown-opt.stderr")"
unknown_opt_exit=$?
unknown_opt_out="${raw_out//$T/\$T}"
unknown_opt_err="$(cat "$T/unknown-opt.stderr")"
unknown_opt_expected_out='$T/unknown-opt.md
  == typography ==
  $T/unknown-opt.md:3 - em dash (use "-" or restructure)'
unknown_opt_expected_err='md-checks.sh: unknown option: --bogus'
if [[ "$unknown_opt_out" == "$unknown_opt_expected_out" \
  && "$unknown_opt_err" == "$unknown_opt_expected_err" \
  && "$unknown_opt_exit" -eq 0 ]]; then
  pass=$((pass + 1)); printf 'ok   %s\n' "unknown-option"
else
  printf 'FAIL %s\n--- expected stdout\n%s\n--- expected stderr\n%s\n--- expected exit\n0\n' \
    "unknown-option" "$unknown_opt_expected_out" "$unknown_opt_expected_err"
  printf -- '--- actual stdout\n%s\n--- actual stderr\n%s\n--- actual exit\n%s\n' \
    "$unknown_opt_out" "$unknown_opt_err" "$unknown_opt_exit"
fi

# 22. a .markdown file is checked like a .md file.
cat > "$T/extension-test.markdown" <<'MD'
# Title

[a](missing2.md)
MD
run_case "markdown-extension" "" "extension-test.markdown" '$T/extension-test.markdown
  == links ==
  $T/extension-test.markdown:3 - relative link target does not exist: missing2.md'

# 23. placeholders: bare TBD, [placeholder], and Lorem ipsum are each reported.
cat > "$T/placeholders.md" <<'MD'
# Title

TBD

[placeholder]

Lorem ipsum dolor.
MD
run_case "placeholders" "" "placeholders.md" '$T/placeholders.md
  == placeholders ==
  $T/placeholders.md:3 - unfinished marker: TBD
  $T/placeholders.md:5 - unfinished marker: [placeholder]
  $T/placeholders.md:7 - unfinished marker: Lorem ipsum'

# 24. no-break space (U+00A0).
printf '# Title\n\nHello\xc2\xa0World\n' > "$T/nbsp.md"
run_case "nbsp" "" "nbsp.md" '$T/nbsp.md
  == typography ==
  $T/nbsp.md:3 - non-ASCII character U+00A0'

# 25. a heading-like line inside a fence creates no anchor slug.
cat > "$T/anchor-fenced-heading.md" <<'MD'
# Title

```
## Fenced Heading
```

[x](#fenced-heading)
MD
run_case "anchor-fenced-heading" "" "anchor-fenced-heading.md" '$T/anchor-fenced-heading.md
  == anchors ==
  $T/anchor-fenced-heading.md:7 - anchor has no matching heading: #fenced-heading'

# 26. output shape: absolute path line, one == category == header per non-empty category in
# order, finding lines sorted by line number, then one blank line at the end of the file's output.
cat > "$T/two-categories.md" <<'MD'
# Title

TBD

[a](missing3.md)
MD
run_case "two-categories" "" "two-categories.md" '$T/two-categories.md
  == placeholders ==
  $T/two-categories.md:3 - unfinished marker: TBD
  == links ==
  $T/two-categories.md:5 - relative link target does not exist: missing3.md'

total=$((total + 1))
bash "$MDC" "$T/two-categories.md" > "$T/two-categories.out" 2>/dev/null
trailing_bytes="$(tail -c 2 "$T/two-categories.out" | od -An -tx1 | tr -d ' \n')"
if [[ "$trailing_bytes" == "0a0a" ]]; then
  pass=$((pass + 1)); printf 'ok   %s\n' "trailing-blank-line"
else
  printf 'FAIL %s\n--- expected last two bytes\n0a0a\n--- actual\n%s\n' \
    "trailing-blank-line" "$trailing_bytes"
fi

printf '%d/%d passed\n' "$pass" "$total"
[[ "$pass" -eq "$total" ]]
