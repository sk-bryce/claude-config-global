#!/usr/bin/env bash
#
# md-checks.sh - the deterministic, offline half of a Markdown review: the checks that are
# mechanical rather than judgment-driven, run as a script instead of by a model.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit. It registers itself nowhere; scripts/md-deferred-checks.sh calls
# it, and skills/review-md/SKILL.md invokes it directly. This script never edits anything.
#
# WHY THIS EXISTS: scanning for TODO markers, em-dashes, skipped heading levels, and relative paths
# that do not resolve is grep work - dispatching a model to do it costs tokens, a round trip, and a
# per-turn slice of the always-loaded agent-description budget, and returns a less reliable answer
# than a regex does. What genuinely needs judgment (is this still true, does this section earn its
# place, what should change) stays with review-md.
#
# Usage: md-checks.sh <file.md> [<file.md> ...]
#   Prints findings as "<abspath>:<line> - <description>", grouped under a "== category ==" header
#   per non-empty category, with a blank line between files that have findings. Silent for a clean
#   file, so it is safe on a hook path where stdout lands in the model's context. Always exits 0:
#   this reports, it never blocks a turn or fails a caller.
#
# Checks (all offline - no network call, ever; link liveness is link-recheck-hook.sh's job):
#   placeholders  - TODO, FIXME, TBD, XXX, [placeholder], Lorem ipsum
#   typography    - en/em dashes, curly quotes, ellipsis character, per CLAUDE.md's Output
#                   Formatting rules
#   headings      - a heading level that skips (H2 straight to H4)
#   links         - a relative link target that does not exist on disk
#   anchors       - a same-file #anchor with no matching heading
#
# Fenced code blocks are excluded from the placeholder and typography scans: CLAUDE.md's ASCII rule
# targets prose and explicitly permits box-drawing glyphs inside a fence that renders a diagram, and
# a TODO inside a fence is example text rather than an unfinished document. Link and anchor checks
# deliberately still run inside fences, since a fenced example of a link is rare and a real broken
# cross-reference hiding in one is worth more than the occasional false positive.

set -uo pipefail  # deliberately not -e: one file's failing check must not skip the remaining
                  # files, and this always exits 0 per the header - no single step here may abort.

if [[ $# -eq 0 ]]; then
  echo "usage: md-checks.sh <file.md> [<file.md> ...]" >&2
  exit 0
fi

# Slugify a heading the way GitHub does, closely enough for an anchor existence check: lowercase,
# drop anything that is not alphanumeric/space/hyphen, then spaces to hyphens. Deliberately an
# approximation - a false "anchor not found" is cheap for a human to dismiss, where the alternative
# (no anchor checking at all) misses real broken cross-references.
# The trailing newline is load-bearing: the caller collects these into a newline-separated list and
# looks an anchor up with `grep -x`, so emitting slugs without one silently concatenates every
# heading into a single line and makes every anchor look missing.
slugify() {
  printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g'
}

TAB="$(printf '\t')"

for f in "$@"; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.md) ;;
    *) continue ;;
  esac

  abs="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/$(basename "$f")"
  [[ -f "$abs" ]] || continue
  dir="$(dirname "$abs")"

  # --- Single awk pass: placeholders, typography, heading skips ------------------------------------
  # One pass rather than several greps, so fence state is tracked once and every check that cares
  # about it sees the same notion of "inside a fence". Emits "category<TAB>line<TAB>description".
  #
  # The typographic characters are matched as their literal UTF-8 byte sequences (em dash U+2014 is
  # E2 80 94, and so on) rather than as a broad non-ASCII class, so each finding can name which
  # substitution it found instead of reporting a generic "non-ASCII character here".
  scan="$(awk '
    /^[[:space:]]*(```|~~~)/ { in_fence = !in_fence; next }
    in_fence { next }
    {
      line = $0

      # Requires the "TODO:" / "TODO(owner)" convention rather than the bare word. A bare match
      # flags prose that merely mentions the concept ("placeholder/TODO scan", "TODOs in a comment")
      # and legitimate "## TODO" backlog headings - all four of which this repo has, and none of
      # which is an unfinished document. TBD is matched bare because it is almost never written with
      # a colon, but is bounded so it cannot fire inside a longer word.
      if (match(line, /(TODO|FIXME|XXX|HACK)[:(]/)) {
        printf "placeholders\t%d\tunfinished marker: %s\n", NR, substr(line, RSTART, RLENGTH)
      }
      if (match(line, /(^|[^A-Za-z])TBD([^A-Za-z]|$)/)) {
        printf "placeholders\t%d\tunfinished marker: TBD\n", NR
      }
      if (match(line, /\[placeholder\]|Lorem ipsum/)) {
        printf "placeholders\t%d\tunfinished marker: %s\n", NR, substr(line, RSTART, RLENGTH)
      }

      if (index(line, "\342\200\224")) printf "typography\t%d\tem dash (use \"-\" or restructure)\n", NR
      if (index(line, "\342\200\223")) printf "typography\t%d\ten dash (use \"-\" or restructure)\n", NR
      if (index(line, "\342\200\230") || index(line, "\342\200\231")) printf "typography\t%d\tcurly single quote\n", NR
      if (index(line, "\342\200\234") || index(line, "\342\200\235")) printf "typography\t%d\tcurly double quote\n", NR
      if (index(line, "\342\200\246")) printf "typography\t%d\tellipsis character (use \"...\")\n", NR

      if (match(line, /^#+/)) {
        level = RLENGTH
        if (prev_level > 0 && level > prev_level + 1) {
          printf "headings\t%d\theading level skips H%d -> H%d\n", NR, prev_level, level
        }
        prev_level = level
      }
    }
  ' "$abs" 2>/dev/null)"

  # --- Relative link targets and same-file anchors --------------------------------------------------
  # Shell rather than awk: both need filesystem and whole-file-heading lookups that awk would have to
  # buffer the entire file to answer.
  heading_slugs="$(grep -E '^#+[[:space:]]' "$abs" 2>/dev/null \
    | sed -E 's/^#+[[:space:]]*//' \
    | while IFS= read -r h; do slugify "$h"; done)"

  link_findings=""
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    lineno="${hit%%:*}"
    rest="${hit#*:}"       # "](target)"
    target="${rest#\](}"   # "target)"
    target="${target%\)}"  # "target"

    case "$target" in
      http://*|https://*|mailto:*|'') continue ;;
      \#*)
        anchor="${target#\#}"
        if [[ -n "$anchor" ]] && ! grep -qxF -- "$anchor" <<< "$heading_slugs"; then
          link_findings+="anchors${TAB}${lineno}${TAB}anchor has no matching heading: #${anchor}"$'\n'
        fi
        ;;
      *)
        path="${target%%#*}"
        [[ -n "$path" ]] || continue
        case "$path" in
          /*) resolved="$path" ;;
          *)  resolved="$dir/$path" ;;
        esac
        if [[ ! -e "$resolved" ]]; then
          link_findings+="links${TAB}${lineno}${TAB}relative link target does not exist: ${path}"$'\n'
        fi
        ;;
    esac
  done < <(grep -noE '\]\([^)]*\)' "$abs" 2>/dev/null || true)

  # --- Report ---------------------------------------------------------------------------------------
  findings="$(printf '%s\n%s' "$scan" "$link_findings" | grep -v '^$' || true)"
  [[ -n "$findings" ]] || continue

  printf '%s\n' "$abs"
  for category in placeholders typography headings links anchors; do
    group="$(printf '%s\n' "$findings" | awk -F"$TAB" -v c="$category" '$1 == c' | sort -t"$TAB" -k2,2n)"
    [[ -n "$group" ]] || continue
    printf '  == %s ==\n' "$category"
    printf '%s\n' "$group" \
      | awk -F"$TAB" -v a="$abs" '{ printf "  %s:%s - %s\n", a, $2, $3 }'
  done
  printf '\n'
done

exit 0
