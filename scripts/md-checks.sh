#!/usr/bin/env bash
#
# md-checks.sh - the deterministic, offline half of a Markdown review: the checks that are
# mechanical rather than judgment-driven, run as a script instead of by a model.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit. It registers itself nowhere; scripts/md-deferred-checks.sh calls
# it (with no options, one file at a time), and skills/review-md/SKILL.md invokes it directly (with
# --review for the four review-only categories). This script never edits anything.
#
# WHY THIS EXISTS: scanning for TODO markers, em-dashes, skipped heading levels, and relative paths
# that do not resolve is grep work - dispatching a model to do it costs tokens, a round trip, and a
# per-turn slice of the always-loaded agent-description budget, and returns a less reliable answer
# than a regex does. What genuinely needs judgment (is this still true, does this section earn its
# place, what should change) stays with review-md.
#
# Usage: md-checks.sh [--no-typography] [--review] <file> [<file> ...]
#   Options must come before the files. --no-typography turns off the typography category (on by
#   default). --review additionally reports four categories that are noisy for a routine hook pass
#   but useful for a deliberate review: fence-language, alt-text, h1, and sibling-headings. An
#   unrecognized --option prints a warning to stderr and is otherwise ignored; the file(s) are still
#   checked. With no file argument, prints the usage line to stderr.
#
#   Prints findings as "<abspath>:<line> - <description>", grouped under a "== category ==" header
#   per non-empty category, with a blank line after each file that has findings. Silent for a clean
#   file, so it is safe on a hook path where stdout lands in the model's context. Always exits 0:
#   this reports, it never blocks a turn or fails a caller.
#
# Checks (all offline - no network call, ever; link liveness is link-recheck-hook.sh's job):
#   placeholders    - TODO, FIXME, TBD, XXX, HACK, [placeholder], Lorem ipsum
#   typography      - any non-ASCII punctuation/symbol character (Unicode general category, not a
#                     fixed byte-sequence list), per CLAUDE.md's Output Formatting rules
#   headings        - a heading level that skips (H2 straight to H4)
#   fences          - a fenced code block left open at end of file
#   links           - a relative link target that does not exist on disk
#   anchors         - a same-file #anchor with no matching heading, using GitHub's slug algorithm
#   fence-language  - (--review only) a fenced code block with no language tag
#   alt-text        - (--review only) an image with empty alt text
#   h1              - (--review only) the first heading is not H1, or more than one H1 is present
#   sibling-headings - (--review only) two headings with the same text and level under the same
#                     parent
#
# Fenced code blocks and inline code spans are excluded from the placeholder, typography, heading,
# link, and anchor scans: CLAUDE.md's ASCII rule targets prose and explicitly permits box-drawing
# glyphs inside a fence that renders a diagram, and a TODO inside a fence or `code span` is example
# text rather than an unfinished document. YAML frontmatter (a leading "---" line through the next
# bare "---" line) is never treated as a heading or a fence opener, but its lines are still scanned
# by the other checks like any other prose.
#
# Unicode classification (typography) and GitHub-style heading-slug generation (anchors) are done
# in perl, which ships by default on Linux and macOS and can classify Unicode reliably; awk cannot.

set -uo pipefail  # deliberately not -e: one file's failing check must not skip the remaining
                  # files, and this always exits 0 per the header - no single step here may abort.

typography=1
review=0
files=()
in_files=0

for arg in "$@"; do
  if [[ $in_files -eq 0 && "$arg" == --* ]]; then
    case "$arg" in
      --no-typography) typography=0 ;;
      --review) review=1 ;;
      *) echo "md-checks.sh: unknown option: $arg" >&2 ;;
    esac
  else
    in_files=1
    files+=("$arg")
  fi
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "usage: md-checks.sh [--no-typography] [--review] <file> [<file> ...]" >&2
  exit 0
fi

TAB="$(printf '\t')"

# The whole per-file analysis (frontmatter, fence tracking, inline-code masking, heading
# collection and slugging, and every category) lives in this perl program. It is invoked once per
# file with the file's absolute path, its directory, and the two flags as @ARGV, and it prints raw
# "category<TAB>line<TAB>description" lines with no grouping or sorting - the bash loop below does
# that part, exactly as before, so the output shape stays identical to the pre-perl version.
read -r -d '' PERL_PROGRAM <<'PERL'
use strict;
use warnings;
use utf8;

binmode(STDOUT, ':encoding(UTF-8)');

my ($file, $dir, $review, $typography) = @ARGV;

open(my $fh, '<:encoding(UTF-8)', $file) or exit 0;
my @lines = <$fh>;
close $fh;
chomp @lines;
my $n = scalar @lines;

# --- YAML frontmatter: first line "---" through the next line that is exactly "---". -------------
my @is_frontmatter = (0) x ($n + 1);
if ($n >= 1 && $lines[0] eq '---') {
  my $end = 0;
  for (my $i = 2; $i <= $n; $i++) {
    if ($lines[$i - 1] eq '---') { $end = $i; last; }
  }
  if ($end) {
    for (my $i = 1; $i <= $end; $i++) { $is_frontmatter[$i] = 1; }
  }
}

# --- Fence state machine --------------------------------------------------------------------------
my @is_fenced = (0) x ($n + 1);
my @fence_openers;          # [line, lang] for every opener seen
my @unclosed_fence_lines;   # opener line(s) still open at EOF
my $in_fence = 0;
my $fence_char = '';
my $fence_len = 0;
my $fence_open_at = 0;

for (my $i = 1; $i <= $n; $i++) {
  next if $is_frontmatter[$i];   # frontmatter lines are never fence openers or closers
  my $line = $lines[$i - 1];

  if ($in_fence) {
    $is_fenced[$i] = 1;
    if ($line =~ /^ {0,3}\Q$fence_char\E{$fence_len,}[ \t]*$/) {
      $in_fence = 0;
    }
    next;
  }

  if ($line =~ /^ {0,3}(`{3,}|~{3,})(.*)$/) {
    my $chars = $1;
    my $rest = $2;
    $is_fenced[$i] = 1;
    $in_fence = 1;
    $fence_char = substr($chars, 0, 1);
    $fence_len = length($chars);
    $fence_open_at = $i;
    $rest =~ s/^\s+|\s+$//g;
    push @fence_openers, [$i, $rest];
  }
}
if ($in_fence) {
  push @unclosed_fence_lines, $fence_open_at;
}

# --- Headings: collected from unfenced, non-frontmatter lines. ------------------------------------
my @headings;   # { line, level, text }
for (my $i = 1; $i <= $n; $i++) {
  next if $is_frontmatter[$i];
  next if $is_fenced[$i];
  my $line = $lines[$i - 1];
  if ($line =~ /^(#{1,6})(?:[ \t](.*)|)$/) {
    my $level = length($1);
    my $text = defined($2) ? $2 : '';
    $text =~ s/^\s+|\s+$//g;
    $text =~ s/\s*#+$//;
    $text =~ s/\s+$//;
    push @headings, { line => $i, level => $level, text => $text };
  }
}

# --- GitHub-style heading slugs, with -1/-2/... suffixes for repeats. ----------------------------
sub make_slug {
  my ($text) = @_;
  my $t = $text;
  $t =~ s/`//g;                                  # remove inline code backticks, keep contents
  $t =~ s/\[([^\]]*)\]\([^)]*\)/$1/g;             # [text](url) -> text
  $t = lc($t);
  $t =~ s/[^\p{L}\p{M}\p{N}\p{Pc} -]//g;
  $t =~ s/ /-/g;
  return $t;
}

my %slug_seen;
my %slug_set;
foreach my $h (@headings) {
  my $base = make_slug($h->{text});
  my $count = $slug_seen{$base}++;
  my $slug = $count == 0 ? $base : "$base-$count";
  $slug_set{$slug} = 1;
}

# --- Inline code span masking: blank out the text between a run of N backticks and the next run --
# --- of exactly N backticks on the same line, so later checks never see inside a code span. -------
sub mask_inline_code {
  my ($line) = @_;
  my $masked = $line;
  while ($line =~ /(`+)(.*?)\1/g) {
    my $start = $-[0];
    my $len = $+[0] - $-[0];
    substr($masked, $start, $len) = (' ' x $len);
  }
  return $masked;
}

sub parse_target {
  my ($raw) = @_;
  $raw =~ s/^\s+|\s+$//g;
  if ($raw =~ /^<([^>]*)>/) {
    return $1;
  }
  if ($raw =~ /^(\S*)/) {
    return $1;
  }
  return '';
}

my @findings;   # [category, line, description]

# --- placeholders, typography, links, images, anchors: unfenced lines, inline code masked. --------
for (my $i = 1; $i <= $n; $i++) {
  next if $is_fenced[$i];
  my $line = $lines[$i - 1];
  my $masked = mask_inline_code($line);

  if ($masked =~ /(TODO|FIXME|XXX|HACK)[:(]/) {
    push @findings, ['placeholders', $i, "unfinished marker: $&"];
  }
  if ($masked =~ /(^|[^A-Za-z])TBD([^A-Za-z]|$)/) {
    push @findings, ['placeholders', $i, "unfinished marker: TBD"];
  }
  if ($masked =~ /\[placeholder\]|Lorem ipsum/) {
    push @findings, ['placeholders', $i, "unfinished marker: $&"];
  }

  if ($typography) {
    my %seen_char;
    foreach my $ch (split //, $masked) {
      my $cp = ord($ch);
      next if $cp < 128;
      next if ($cp >= 0x3000 && $cp <= 0x303F);
      next if ($cp >= 0xFF00 && $cp <= 0xFFEF);
      next unless ($ch =~ /\p{P}/ || $ch =~ /\p{S}/ || $cp == 0x00A0 || $cp == 0x200B);
      next if $seen_char{$cp}++;
      my $desc;
      if ($cp == 0x2014) { $desc = 'em dash (use "-" or restructure)'; }
      elsif ($cp == 0x2013) { $desc = 'en dash (use "-" or restructure)'; }
      elsif ($cp == 0x2018 || $cp == 0x2019) { $desc = 'curly single quote'; }
      elsif ($cp == 0x201C || $cp == 0x201D) { $desc = 'curly double quote'; }
      elsif ($cp == 0x2026) { $desc = 'ellipsis character (use "...")'; }
      else { $desc = sprintf('non-ASCII character U+%04X', $cp); }
      push @findings, ['typography', $i, $desc];
    }
  }

  while ($masked =~ /(!?)\[([^\]]*)\]\(([^)]*)\)/g) {
    my $is_img = ($1 eq '!');
    my $alt = $2;
    my $target = parse_target($3);

    if ($is_img && $review && $alt eq '') {
      push @findings, ['alt-text', $i, 'image has empty alt text'];
    }

    next if $target eq '';
    next if $target =~ /^https?:/ || $target =~ /^mailto:/;

    if ($target =~ /^#(.*)$/) {
      my $anchor = $1;
      if ($anchor ne '' && !$slug_set{$anchor}) {
        push @findings, ['anchors', $i, "anchor has no matching heading: #$anchor"];
      }
      next;
    }

    my $path = $target;
    $path =~ s/#.*$//;
    next if $path eq '';
    my $resolved = ($path =~ m{^/}) ? $path : "$dir/$path";
    if (!-e $resolved) {
      push @findings, ['links', $i, "relative link target does not exist: $path"];
    }
  }
}

# --- headings: a level that skips (H2 straight to H4). ---------------------------------------------
{
  my $prev_level = 0;
  foreach my $h (@headings) {
    if ($prev_level > 0 && $h->{level} > $prev_level + 1) {
      push @findings, ['headings', $h->{line}, "heading level skips H$prev_level -> H$h->{level}"];
    }
    $prev_level = $h->{level};
  }
}

# --- fences: still open at end of file. -------------------------------------------------------------
foreach my $line_no (@unclosed_fence_lines) {
  push @findings, ['fences', $line_no, 'unclosed code fence'];
}

# --- fence-language (--review only): opener with nothing after the fence characters. ---------------
if ($review) {
  foreach my $pair (@fence_openers) {
    my ($line_no, $lang) = @$pair;
    if ($lang eq '') {
      push @findings, ['fence-language', $line_no, 'code fence has no language tag'];
    }
  }
}

# --- h1 (--review only): first heading not H1, or more than one H1. --------------------------------
if ($review) {
  my $seen_h1 = 0;
  for (my $idx = 0; $idx < scalar(@headings); $idx++) {
    my $h = $headings[$idx];
    if ($idx == 0 && $h->{level} != 1) {
      push @findings, ['h1', $h->{line}, 'first heading is not H1'];
    }
    if ($h->{level} == 1) {
      if ($seen_h1) {
        push @findings, ['h1', $h->{line}, 'more than one H1 heading'];
      }
      $seen_h1 = 1;
    }
  }
}

# --- sibling-headings (--review only): same text and level under the same parent. ------------------
if ($review) {
  my @stack;
  my $next_id = 1;
  my %seen;
  foreach my $h (@headings) {
    while (@stack && $stack[-1]{level} >= $h->{level}) { pop @stack; }
    my $parent_id = @stack ? $stack[-1]{id} : 0;
    my $key = "$parent_id\x1f$h->{level}\x1f$h->{text}";
    if ($seen{$key}++) {
      push @findings, ['sibling-headings', $h->{line}, "repeated sibling heading: $h->{text}"];
    }
    push @stack, { level => $h->{level}, id => $next_id++ };
  }
}

foreach my $f (@findings) {
  print "$f->[0]\t$f->[1]\t$f->[2]\n";
}
PERL

for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.md|*.markdown) ;;
    *) continue ;;
  esac

  abs="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/$(basename "$f")"
  [[ -f "$abs" ]] || continue
  dir="$(dirname "$abs")"

  findings="$(perl -e "$PERL_PROGRAM" -- "$abs" "$dir" "$review" "$typography" 2>/dev/null)"
  [[ -n "$findings" ]] || continue

  printf '%s\n' "$abs"
  for category in placeholders typography headings fences links anchors fence-language alt-text h1 sibling-headings; do
    group="$(printf '%s\n' "$findings" | awk -F"$TAB" -v c="$category" '$1 == c' | sort -t"$TAB" -k2,2n)"
    [[ -n "$group" ]] || continue
    printf '  == %s ==\n' "$category"
    printf '%s\n' "$group" \
      | awk -F"$TAB" -v a="$abs" '{ printf "  %s:%s - %s\n", a, $2, $3 }'
  done
  printf '\n'
done

exit 0
