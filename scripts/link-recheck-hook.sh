#!/usr/bin/env bash
#
# link-recheck-hook.sh - shared logic for the non-blocking "recheck References-section links
# after a Markdown edit" hook (decisions/0004-document-generation-as-always-on-rule.md,
# reference/document-generation.md).
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it (the
# settings.json PostToolUse entry) is a separate, human step. This script only reports; it never
# blocks, edits the file, or exits non-zero, so a caller can safely ignore its exit code (kept 0 in
# every path as a second guard).
#
# Usage: link-recheck-hook.sh <file-path>
#        link-recheck-hook.sh --probe <url>     (internal, used by the parallel fan-out below)
#   No-ops for anything that isn't a *.md file, a missing file, or a file with no
#   "# References"-style heading.
#
#        link-recheck-hook.sh --review [--references-rule] <file> [<file> ...]
#   Reviews every link in each file (not just References-section ones), printing one tab-separated
#   row per link: <abspath> <line> <url> <result>. Unlike hook mode, this reads and writes no
#   freshness state and reports every result, "ok" included. --references-rule additionally flags a
#   file that has a probed http(s) link but no "References" heading, with one extra
#   "no-references" row. LINK_REVIEW_MAX_TIME overrides the per-probe --max-time (seconds);
#   default 10.
#
# Three cost properties, all deliberate, all of them things this script did NOT do before
# (see docs/efficient-agentic-use/04-configuration-hygiene.md's hook-cost section, which names
# exactly this check as its worked example of a hook running more often than its answer changes):
#
#   1. SILENT ON SUCCESS. Only BROKEN and inconclusive results are printed. A run where every link
#      resolves prints nothing at all. The old behavior printed one line per link including every
#      "ok", and on a hook path that output lands in the model's context on every single turn -
#      paying context for the answer "nothing changed", which is the answer almost every time.
#   2. DEDUPED BY CONTENT, NOT BY EDIT. A state file records the hash of the URL set last checked
#      for a given document. If the set has not changed and it was checked within the freshness
#      window below, the run exits silently without a single network call. Link rot does not appear
#      between two edits seconds apart, so rechecking on every edit is pure cost for no added
#      safety. Keying on the URL set rather than the session means this also holds across sessions,
#      and that adding one new link rechecks the whole set rather than being missed.
#   3. PARALLEL. Probes run concurrently instead of serially. Serial probing at up to 10s each meant
#      a document with 18 reference links could exceed the 120s hook timeout in settings.json and be
#      killed partway through, silently reporting nothing.
#
# Verification rules mirrored from reference/document-generation.md (do not duplicate the
# rationale here - that file is the source of truth if the two ever disagree):
#   200 / other 2xx, or a 3xx that resolves after following redirects -> ok      (not printed)
#   404, DNS failure, connection refused                              -> BROKEN  (printed)
#   403, 429 (bot-protection/rate-limit)                              -> inconclusive (printed)
#   timeout or other network error                                    -> inconclusive (printed)

set -uo pipefail  # deliberately not -e: this hook only ever reports or silently exits 0 (see the
                  # header), so no single step - mkdir, cat on a state file, one probe subprocess,
                  # the pruning find - may abort the run; each is written to fall through safely.

# How long a clean result stays trusted before the same URL set is probed again. Long enough that
# an editing session never re-probes, short enough that genuine rot surfaces within a day.
FRESH_MINUTES=1440
PARALLELISM=8

# --- Review mode: internal probe (separate from hook mode's --probe below) -----------------------
# Prints "<curl exit>\t<http code>\t<url>" and nothing else.
if [[ "${1:-}" == "--review-probe" ]]; then
  url="${2:-}"
  [[ -n "$url" ]] || exit 0
  max_time="${LINK_REVIEW_MAX_TIME:-10}"
  code="$(curl -s -o /dev/null -w '%{http_code}' -L --max-time "$max_time" \
    -A 'Mozilla/5.0 (link-recheck-hook)' "$url" 2>/dev/null)"
  exit_code=$?
  [[ -z "$code" ]] && code="000"
  printf '%s\t%s\t%s\n' "$exit_code" "$code" "$url"
  exit 0
fi

# --- Review mode ------------------------------------------------------------------------------------
# Reads and writes no freshness state, never prints the hook's "link-recheck:" lines, and reports
# every link (ok included). See the header's Usage block and the review-md/document-generation
# contract for the exact row format.
if [[ "${1:-}" == "--review" ]]; then
  shift
  review_refs_rule=0
  if [[ "${1:-}" == "--references-rule" ]]; then
    review_refs_rule=1
    shift
  fi
  if [[ $# -eq 0 ]]; then
    echo "usage: link-recheck-hook.sh --review [--references-rule] <file> [<file> ...]" >&2
    exit 2
  fi

  review_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  review_self="$review_script_dir/$(basename "${BASH_SOURCE[0]}")"

  review_have_curl=1
  command -v curl >/dev/null 2>&1 || review_have_curl=0

  review_classify() {
    local ex="$1" co="$2"
    case "$ex" in
      6|7) printf 'broken\n'; return ;;
      0) ;;
      *) printf 'inconclusive\n'; return ;;
    esac
    case "$co" in
      2??|3??) printf 'ok\n' ;;
      404|410) printf 'broken\n' ;;
      *) printf 'inconclusive\n' ;;
    esac
  }

  # Per-file scan: fence and inline-code-span rules mirror md-checks.sh (an opener of 0-3 leading
  # spaces then 3+ backticks/tildes, closed by 0-3 leading spaces then the same character repeated
  # at least as many times then only whitespace; a code span is the text between a run of N
  # backticks and the next run of exactly N backticks on the same line). Prints one "HASREF\t0|1"
  # line, then one "<KIND>\t<line>\t<url>" line per link occurrence in line order. KIND is FENCED,
  # INLINECODE, UNSUPPORTED, or PROBE; mailto links are not printed at all.
  read -r -d '' REVIEW_PERL <<'PERL'
use strict;
use warnings;
use utf8;

binmode(STDOUT, ':encoding(UTF-8)');

my ($file) = @ARGV;

open(my $fh, '<:encoding(UTF-8)', $file) or exit 0;
my @lines = <$fh>;
close $fh;
chomp @lines;
my $n = scalar @lines;

my @is_fenced = (0) x ($n + 1);
my $in_fence = 0;
my $fence_char = '';
my $fence_len = 0;

for (my $i = 1; $i <= $n; $i++) {
  my $line = $lines[$i - 1];
  if ($in_fence) {
    $is_fenced[$i] = 1;
    if ($line =~ /^ {0,3}\Q$fence_char\E{$fence_len,}[ \t]*$/) {
      $in_fence = 0;
    }
    next;
  }
  if ($line =~ /^ {0,3}(`{3,}|~{3,})(.*)$/) {
    $is_fenced[$i] = 1;
    $in_fence = 1;
    $fence_char = substr($1, 0, 1);
    $fence_len = length($1);
  }
}

my $has_references = 0;
for (my $i = 1; $i <= $n; $i++) {
  next if $is_fenced[$i];
  my $line = $lines[$i - 1];
  if ($line =~ /^#{1,6}[ \t]+(.*)$/) {
    my $text = $1;
    $text =~ s/^\s+|\s+$//g;
    $text =~ s/\s*#+$//;
    $text =~ s/\s+$//;
    $has_references = 1 if $text eq 'References';
  }
}
print "HASREF\t" . ($has_references ? 1 : 0) . "\n";

sub parse_target {
  my ($raw) = @_;
  $raw =~ s/^\s+|\s+$//g;
  return $1 if $raw =~ /^<([^>]*)>/;
  return $1 if $raw =~ /^(\S*)/;
  return '';
}

sub code_span_ranges {
  my ($line) = @_;
  my @ranges;
  while ($line =~ /(`+)(.*?)\1/g) {
    push @ranges, [$-[0], $+[0]];
  }
  return @ranges;
}

sub in_ranges {
  my ($pos, $ranges) = @_;
  foreach my $r (@$ranges) {
    return 1 if $pos >= $r->[0] && $pos < $r->[1];
  }
  return 0;
}

sub emit {
  my ($line, $pos, $target, $fenced, $ranges) = @_;
  return if $target eq '';
  if ($fenced) {
    print "FENCED\t$line\t$target\n";
    return;
  }
  if (in_ranges($pos, $ranges)) {
    print "INLINECODE\t$line\t$target\n";
    return;
  }
  if ($target =~ /^mailto:/i) {
    return;
  }
  if ($target =~ /^https?:\/\//i) {
    print "PROBE\t$line\t$target\n";
    return;
  }
  print "UNSUPPORTED\t$line\t$target\n";
}

for (my $i = 1; $i <= $n; $i++) {
  my $line = $lines[$i - 1];
  my @ranges = code_span_ranges($line);

  if ($line =~ /^\[[^\]]+\]:\s*(\S.*)$/) {
    my $target = parse_target($1);
    emit($i, 0, $target, $is_fenced[$i], \@ranges);
  }

  while ($line =~ /(!?\[[^\]]*\]\(([^)]*)\))|<(https?:\/\/[^>\s]+)>/g) {
    my $pos = $-[0];
    my $target;
    if (defined $2) {
      $target = parse_target($2);
    } elsif (defined $3) {
      $target = $3;
    } else {
      next;
    }
    emit($i, $pos, $target, $is_fenced[$i], \@ranges);
  }
}
PERL

  declare -a review_file_kind=() review_file_path=() review_file_scan=()
  declare -A review_seen_url=()
  declare -a review_probe_urls=()

  for f in "$@"; do
    if [[ ! -e "$f" ]]; then
      review_file_kind+=("MISSING")
      review_file_path+=("$f")
      review_file_scan+=("")
      continue
    fi
    case "$f" in
      *.md|*.markdown)
        review_abs="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/$(basename "$f")"
        review_out="$(perl -e "$REVIEW_PERL" -- "$review_abs" 2>/dev/null)"
        review_file_kind+=("SCAN")
        review_file_path+=("$review_abs")
        review_file_scan+=("$review_out")
        while IFS=$'\t' read -r review_kind review_line review_url; do
          [[ "$review_kind" == "PROBE" ]] || continue
          [[ -n "${review_seen_url[$review_url]:-}" ]] && continue
          review_seen_url["$review_url"]=1
          review_probe_urls+=("$review_url")
        done <<< "$review_out"
        ;;
      *)
        review_abs="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/$(basename "$f")"
        review_file_kind+=("NOTMD")
        review_file_path+=("$review_abs")
        review_file_scan+=("")
        ;;
    esac
  done

  declare -A review_url_result=()
  if [[ ${#review_probe_urls[@]} -gt 0 && $review_have_curl -eq 1 ]]; then
    review_round1="$(printf '%s\n' "${review_probe_urls[@]}" \
      | xargs -r -P "$PARALLELISM" -I{} "$review_self" --review-probe {} 2>/dev/null)"
    declare -A review_r1_exit=() review_r1_code=()
    while IFS=$'\t' read -r review_ex review_co review_u; do
      [[ -n "$review_u" ]] || continue
      review_r1_exit["$review_u"]="$review_ex"
      review_r1_code["$review_u"]="$review_co"
    done <<< "$review_round1"

    review_retry_urls=()
    for review_u in "${review_probe_urls[@]}"; do
      [[ "${review_r1_exit[$review_u]:-}" == "28" ]] && review_retry_urls+=("$review_u")
    done

    declare -A review_r2_exit=() review_r2_code=()
    if [[ ${#review_retry_urls[@]} -gt 0 ]]; then
      review_round2="$(printf '%s\n' "${review_retry_urls[@]}" \
        | xargs -r -P "$PARALLELISM" -I{} "$review_self" --review-probe {} 2>/dev/null)"
      while IFS=$'\t' read -r review_ex review_co review_u; do
        [[ -n "$review_u" ]] || continue
        review_r2_exit["$review_u"]="$review_ex"
        review_r2_code["$review_u"]="$review_co"
      done <<< "$review_round2"
    fi

    for review_u in "${review_probe_urls[@]}"; do
      review_ex="${review_r1_exit[$review_u]:-}"
      review_co="${review_r1_code[$review_u]:-}"
      if [[ "$review_ex" == "28" ]]; then
        review_ex2="${review_r2_exit[$review_u]:-}"
        review_co2="${review_r2_code[$review_u]:-}"
        if [[ "$review_ex2" == "28" ]]; then
          review_url_result["$review_u"]="inconclusive"
        else
          review_url_result["$review_u"]="$(review_classify "$review_ex2" "$review_co2")"
        fi
      else
        review_url_result["$review_u"]="$(review_classify "$review_ex" "$review_co")"
      fi
    done
  fi

  for review_i in "${!review_file_kind[@]}"; do
    case "${review_file_kind[$review_i]}" in
      MISSING)
        printf '%s\t0\t-\tskipped:missing-file\n' "${review_file_path[$review_i]}"
        ;;
      NOTMD)
        printf '%s\t0\t-\tskipped:not-markdown\n' "${review_file_path[$review_i]}"
        ;;
      SCAN)
        review_abs="${review_file_path[$review_i]}"
        review_hasref=0
        review_first_seen=0
        review_first_line=""
        review_first_url=""
        while IFS=$'\t' read -r review_kind review_line review_url; do
          [[ -n "$review_kind" ]] || continue
          case "$review_kind" in
            HASREF)
              review_hasref="$review_line"
              ;;
            FENCED)
              printf '%s\t%s\t%s\tskipped:fenced-code\n' "$review_abs" "$review_line" "$review_url"
              ;;
            INLINECODE)
              printf '%s\t%s\t%s\tskipped:inline-code\n' "$review_abs" "$review_line" "$review_url"
              ;;
            UNSUPPORTED)
              printf '%s\t%s\t%s\tskipped:unsupported-scheme\n' "$review_abs" "$review_line" "$review_url"
              ;;
            PROBE)
              if [[ $review_have_curl -eq 0 ]]; then
                review_result="skipped:no-curl"
              else
                review_result="${review_url_result[$review_url]:-inconclusive}"
              fi
              printf '%s\t%s\t%s\t%s\n' "$review_abs" "$review_line" "$review_url" "$review_result"
              if [[ $review_first_seen -eq 0 ]]; then
                review_first_line="$review_line"
                review_first_url="$review_url"
                review_first_seen=1
              fi
              ;;
          esac
        done <<< "${review_file_scan[$review_i]}"
        if [[ $review_refs_rule -eq 1 && "$review_hasref" -eq 0 && $review_first_seen -eq 1 ]]; then
          printf '%s\t%s\t%s\tno-references\n' "$review_abs" "$review_first_line" "$review_first_url"
        fi
        ;;
    esac
  done

  exit 0
fi

# --- Internal probe mode -------------------------------------------------------------------------
# Split out so xargs can fan the probes out across processes. Prints "code<TAB>url" and nothing else.
if [[ "${1:-}" == "--probe" ]]; then
  url="${2:-}"
  [[ -n "$url" ]] || exit 0
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -L \
    -A 'Mozilla/5.0 (link-recheck-hook)' "$url" 2>/dev/null)"
  [[ -z "$code" ]] && code="000"
  printf '%s\t%s\n' "$code" "$url"
  exit 0
fi

f="${1:-}"
[[ -z "$f" || ! -f "$f" ]] && exit 0
case "$f" in
  *.md) ;;
  *) exit 0 ;;
esac

# Scope to the References section onward, matching reference/document-generation.md's own scope
# (a link cited as supporting material, not the file being edited itself), and drop fenced code
# blocks so illustrative example URLs (like the ones in this repo's own document-generation.md
# format examples) are never mistaken for real citations.
refs="$(awk '
  /^```/ { in_fence = !in_fence; next }
  in_fence { next }
  /^#+[[:space:]]+References[[:space:]]*$/ { found = 1 }
  found
' "$f")"
[[ -z "$refs" ]] && exit 0

urls="$(printf '%s\n' "$refs" \
  | grep -oE '\]\(https?://[^)[:space:]]+\)' \
  | sed -E 's/^\]\(//; s/\)$//' \
  | sort -u)"
[[ -z "$urls" ]] && exit 0

# --- Freshness gate ------------------------------------------------------------------------------
# Keyed on this script's own on-disk location rather than $HOME or $CLAUDE_CONFIG_DIR, matching how
# md-ledger-append.sh and md-deferred-checks.sh resolve their ledger directory: the state directory
# must not depend on CLAUDE_CONFIG_DIR being set, since this script can run under a profile where
# it is not.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
state_dir="$(dirname "$script_dir")/cache/link-recheck"
mkdir -p "$state_dir" 2>/dev/null || true

abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
# cksum rather than md5sum/sha1sum: POSIX, present everywhere, and a collision here costs at most a
# skipped recheck of one document, not a correctness bug.
key="$(printf '%s' "$abs" | cksum | tr -d ' ' | tr '/' '_')"
url_hash="$(printf '%s' "$urls" | cksum | tr -d ' ')"
state="$state_dir/$key.state"

if [[ -f "$state" ]] \
   && [[ "$(cat "$state" 2>/dev/null)" == "$url_hash" ]] \
   && [[ -n "$(find "$state" -mmin "-$FRESH_MINUTES" 2>/dev/null)" ]]; then
  exit 0
fi

# --- Probe in parallel, report only what is not ok -------------------------------------------------
results="$(printf '%s\n' "$urls" \
  | xargs -r -P "$PARALLELISM" -I{} "$script_dir/$(basename "${BASH_SOURCE[0]}")" --probe {} \
  2>/dev/null)"

had_finding=0
while IFS=$'\t' read -r code url; do
  [[ -n "$url" ]] || continue
  case "$code" in
    2??|3??) continue ;;
    403|429) status="inconclusive (bot-protection/rate-limit - not confirmed broken)" ;;
    404)     status="BROKEN (404)" ;;
    000)     status="inconclusive (no response or timeout)" ;;
    *)       status="inconclusive (HTTP $code)" ;;
  esac
  printf 'link-recheck: %s [%s] %s\n' "$url" "$code" "$status"
  had_finding=1
done <<< "$results"

# Only record a clean bill of health, and only when every URL actually came back. A run that found
# something stays unrecorded on purpose, so the next run reports it again rather than going quiet on
# an unresolved problem after one mention.
#
# The count comparison is the important half: if the fan-out itself fails (xargs missing, the script
# path unresolvable, the process killed by the hook timeout), `results` comes back empty, no line is
# ever classified, and had_finding stays 0 - which without this guard would write a "clean" state and
# suppress the next 24 hours of checking on the strength of a run that never probed anything.
url_count="$(printf '%s\n' "$urls" | grep -c .)"
result_count="$(printf '%s\n' "$results" | grep -c .)"
if [[ "$had_finding" -eq 0 && "$result_count" -eq "$url_count" ]]; then
  printf '%s' "$url_hash" > "$state" 2>/dev/null
fi

# Prune state for documents that have not been rechecked in a long time, so cache/ does not
# accumulate an entry per document forever.
find "$state_dir" -maxdepth 1 -type f -name '*.state' -mtime +30 -delete 2>/dev/null || true

exit 0
