#!/usr/bin/env bash
#
# md-claims.sh - extracts checkable claims from a Markdown document (paths, commands, flags,
# identifiers, heading references, and dated/versioned statements) and settles the ones a script
# can settle, so review-md's proofread pass only has to judge what remains ambiguous.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit.
#
# Usage: md-claims.sh [--extract] <file> [<file> ...]
#   With no file argument, or an unrecognized --option, prints a usage line to stderr and exits 2.
#   --extract prints every extracted claim with result "extracted" and runs no checks (no
#   freshness or drift rows either). Files that do not exist, or whose name does not end in .md or
#   .markdown, are skipped silently. Otherwise this always exits 0.
#
#   This script is read-only: it never runs a command taken from a document. The only external
#   commands it runs on document-derived text are `command -v` (existence of a word found in a
#   `command` code span, invoked as a single argument via a fixed bash -c wrapper, never
#   interpolated into a shell string) and `git` (log/rev-parse, for path resolution against a git
#   root and for freshness/drift, always invoked with the path as a separate argv element);
#   everything else is a plain file existence test.
#
# Output: one tab-separated row per claim, with no header row:
#   <abspath><TAB><line><TAB><heading><TAB><kind><TAB><claim><TAB><result>
#
# Claim kinds: path, command, flag, identifier, heading-ref, dated, freshness, drift.
# Result values: found, not-found-by-script, candidate, newer-than-doc, stale-header (with
#   --extract, every result is "extracted" and no freshness/drift row is printed).
#
# The freshness check (an "updated: YYYY-MM-DD" header more than a day older than the file's last
# commit) mirrors scripts/health-check.sh's fm_date rule: the header must match
# ^updated: *[0-9]{4}-[0-9]{2}-[0-9]{2} within the file's first 60 lines.
#
# Fence and frontmatter exclusion, and heading-anchor slugging, follow scripts/md-checks.sh's
# rules exactly (perl fence state machine, GitHub-style slugs with -1/-2 suffixes).

set -uo pipefail

extract=0
files=()
in_files=0

for arg in "$@"; do
  if [[ $in_files -eq 0 && "$arg" == --* ]]; then
    case "$arg" in
      --extract) extract=1 ;;
      *)
        echo "usage: md-claims.sh [--extract] <file> [<file> ...]" >&2
        exit 2
        ;;
    esac
  else
    in_files=1
    files+=("$arg")
  fi
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "usage: md-claims.sh [--extract] <file> [<file> ...]" >&2
  exit 2
fi

# The whole per-file analysis (frontmatter, fence tracking, heading collection and slugging,
# inline-code span extraction and classification, link/heading-ref and dated-claim scanning, path
# resolution, and git-backed freshness/drift) lives in this perl program. It is invoked once per
# file with the file's absolute path, its directory, and the extract flag as @ARGV, and prints raw
# "line<TAB>heading<TAB>kind<TAB>claim<TAB>result" lines - the bash loop below prepends the
# absolute path and prints them as-is.
read -r -d '' PERL_PROGRAM <<'PERL'
use strict;
use warnings;
use utf8;
use Cwd ();
use Time::Local ();

binmode(STDOUT, ':encoding(UTF-8)');

my ($file, $dir, $extract) = @ARGV;

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

# --- Fence state machine (same rules as md-checks.sh). ----------------------------------------------
my @is_fenced = (0) x ($n + 1);
my $in_fence = 0;
my $fence_char = '';
my $fence_len = 0;

for (my $i = 1; $i <= $n; $i++) {
  next if $is_frontmatter[$i];
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

# --- Nearest unfenced heading at-or-above each line; "-" when there is none yet. ------------------
my @heading_for_line = ('-') x ($n + 1);
{
  my $cur = '-';
  my $hi = 0;
  for (my $i = 1; $i <= $n; $i++) {
    if ($hi < scalar(@headings) && $headings[$hi]{line} == $i) {
      $cur = $headings[$hi]{text} eq '' ? '-' : $headings[$hi]{text};
      $hi++;
    }
    $heading_for_line[$i] = $cur;
  }
}

# --- GitHub-style heading slugs, with -1/-2/... suffixes for repeats (same as md-checks.sh). ------
sub make_slug {
  my ($text) = @_;
  my $t = $text;
  $t =~ s/`//g;
  $t =~ s/\[([^\]]*)\]\([^)]*\)/$1/g;
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

# --- Headings/slugs of an arbitrary (target) file, for heading-ref resolution. --------------------
sub headings_and_slugs_of_file {
  my ($path) = @_;
  open(my $tfh, '<:encoding(UTF-8)', $path) or return ([], {});
  my @l = <$tfh>;
  close $tfh;
  chomp @l;
  my $nn = scalar @l;
  my @isfm = (0) x ($nn + 1);
  if ($nn >= 1 && $l[0] eq '---') {
    my $end = 0;
    for (my $i = 2; $i <= $nn; $i++) { if ($l[$i - 1] eq '---') { $end = $i; last; } }
    if ($end) { for (my $i = 1; $i <= $end; $i++) { $isfm[$i] = 1; } }
  }
  my @isfenced = (0) x ($nn + 1);
  my $inf = 0; my $fc = ''; my $flen = 0;
  for (my $i = 1; $i <= $nn; $i++) {
    next if $isfm[$i];
    my $line = $l[$i - 1];
    if ($inf) {
      $isfenced[$i] = 1;
      if ($line =~ /^ {0,3}\Q$fc\E{$flen,}[ \t]*$/) { $inf = 0; }
      next;
    }
    if ($line =~ /^ {0,3}(`{3,}|~{3,})(.*)$/) {
      $isfenced[$i] = 1; $inf = 1; $fc = substr($1, 0, 1); $flen = length($1);
    }
  }
  my @hs;
  for (my $i = 1; $i <= $nn; $i++) {
    next if $isfm[$i];
    next if $isfenced[$i];
    my $line = $l[$i - 1];
    if ($line =~ /^(#{1,6})(?:[ \t](.*)|)$/) {
      my $level = length($1);
      my $text = defined($2) ? $2 : '';
      $text =~ s/^\s+|\s+$//g;
      $text =~ s/\s*#+$//;
      $text =~ s/\s+$//;
      push @hs, { text => $text };
    }
  }
  my %sseen; my %sset;
  foreach my $h (@hs) {
    my $base = make_slug($h->{text});
    my $count = $sseen{$base}++;
    my $slug = $count == 0 ? $base : "$base-$count";
    $sset{$slug} = 1;
  }
  return (\@hs, \%sset);
}

# --- command -v, run only via a fixed bash -c wrapper with the word as a separate argv element, so
# --- document-derived text is never parsed as shell syntax. ---------------------------------------
sub command_exists {
  my ($word) = @_;
  my $rc = system('bash', '-c', 'command -v "$1" >/dev/null 2>&1', 'bash', $word);
  return $rc == 0;
}

sub expand_prefix {
  my ($p) = @_;
  my $cfg = $ENV{CLAUDE_CONFIG_DIR};
  my $cfg_dir = (defined $cfg && length $cfg) ? $cfg : (($ENV{HOME} // '') . '/.claude');
  if ($p =~ /^\$\{CLAUDE_CONFIG_DIR:-~\/\.claude\}(.*)$/) {
    return $cfg_dir . $1;
  }
  if ($p =~ /^\$CLAUDE_CONFIG_DIR(.*)$/) {
    return $cfg_dir . $1;
  }
  if ($p =~ /^~(.*)$/) {
    return ($ENV{HOME} // '') . $1;
  }
  return $p;
}

# --- Path resolution: doc directory, then git root, deduped by canonical path. ---------------------
sub resolve_path {
  my ($raw, $doc_dir, $root) = @_;
  my $p = expand_prefix($raw);
  my @candidates;
  if ($p =~ m{^/}) {
    push @candidates, $p;
  } else {
    push @candidates, "$doc_dir/$p";
    push @candidates, "$root/$p" if defined $root && length $root;
  }
  my %seen;
  my @found;
  foreach my $c (@candidates) {
    if (-e $c) {
      my $canon = Cwd::abs_path($c);
      $canon = $c unless defined $canon;
      push @found, $canon unless $seen{$canon}++;
    }
  }
  if (@found == 0) { return ('not-found-by-script', undef); }
  elsif (@found == 1) { return ('found', $found[0]); }
  else { return ('candidate', undef); }
}

sub check_heading_ref {
  my ($path_raw, $doc_dir, $root, $anchor, $quoted) = @_;
  my ($status, $canon) = resolve_path($path_raw, $doc_dir, $root);
  return 'candidate' if $status eq 'candidate';
  return 'not-found-by-script' if $status ne 'found';
  my ($hs, $slugs) = headings_and_slugs_of_file($canon);
  if (defined $anchor) {
    return $slugs->{$anchor} ? 'found' : 'not-found-by-script';
  }
  foreach my $h (@$hs) {
    return 'found' if lc($h->{text}) eq lc($quoted);
  }
  return 'not-found-by-script';
}

# --- Inline code span classification (contract rules 1-5, checked in order). ----------------------
sub classify_span {
  my ($content) = @_;
  if ($content =~ /^-[A-Za-z-]/) {
    return ({ kind => 'flag', claim => $content });
  }
  if ($content =~ /\s/) {
    my @items = ({ kind => 'command', claim => $content });
    my @words = split(' ', $content);
    for (my $idx = 1; $idx <= $#words; $idx++) {
      push @items, { kind => 'flag', claim => $words[$idx] } if $words[$idx] =~ /^--/;
    }
    return @items;
  }
  if ($content =~ m{/} || $content =~ /\.[A-Za-z0-9]{1,6}$/) {
    return ({ kind => 'path', claim => $content });
  }
  if ($content =~ /^[A-Za-z0-9_.-]+$/) {
    if (command_exists($content)) {
      return ({ kind => 'command', claim => $content });
    }
    if ($content =~ /^[A-Za-z_][A-Za-z0-9_.:]*(\(\))?$/) {
      return ({ kind => 'identifier', claim => $content });
    }
    return ();
  }
  if ($content =~ /^[A-Za-z_][A-Za-z0-9_.:]*(\(\))?$/) {
    return ({ kind => 'identifier', claim => $content });
  }
  return ();
}

sub compute_result_for_item {
  my ($item, $doc_dir, $root) = @_;
  my $kind = $item->{kind};
  if ($kind eq 'flag' || $kind eq 'identifier') {
    return ('candidate', undef);
  }
  if ($kind eq 'path') {
    return resolve_path($item->{claim}, $doc_dir, $root);
  }
  if ($kind eq 'command') {
    my $claim = $item->{claim};
    if ($claim =~ /\s/) {
      my @w = split(' ', $claim);
      my $first = $w[0];
      if ($first =~ m{/}) {
        my ($status, undef) = resolve_path($first, $doc_dir, $root);
        return ($status, undef);
      }
      return (command_exists($first) ? 'found' : 'not-found-by-script', undef);
    }
    return ('found', undef);   # single-word command already validated in classify_span
  }
  return ('candidate', undef);
}

# --- Dated/versioned phrases. ----------------------------------------------------------------------
my $MONTHS = qr/January|February|March|April|May|June|July|August|September|October|November|December/;

sub extract_dated {
  my ($masked) = @_;
  my @items;
  my @consumed;
  my $overlaps = sub {
    my ($s, $e) = @_;
    foreach my $c (@consumed) { return 1 if $s < $c->[1] && $e > $c->[0]; }
    return 0;
  };
  while ($masked =~ /\bas of\s+(?:(?:v[0-9]+(?:\.[0-9]+)*)|(?:version\s+[0-9]+(?:\.[0-9]+)*)|(?:[0-9]{4}-[0-9]{2}-[0-9]{2})|(?:(?:$MONTHS)\s+[0-9]{4}))/gi) {
    my $s = $-[0]; my $e = $+[0];
    push @items, { pos => $s, claim => substr($masked, $s, $e - $s) };
    push @consumed, [$s, $e];
  }
  while ($masked =~ /\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b/g) {
    my $s = $-[0]; my $e = $+[0];
    next if $overlaps->($s, $e);
    push @items, { pos => $s, claim => substr($masked, $s, $e - $s) };
    push @consumed, [$s, $e];
  }
  while ($masked =~ /\b(?:$MONTHS)\s+[0-9]{4}\b/g) {
    my $s = $-[0]; my $e = $+[0];
    next if $overlaps->($s, $e);
    push @items, { pos => $s, claim => substr($masked, $s, $e - $s) };
    push @consumed, [$s, $e];
  }
  while ($masked =~ /\bv[0-9]+(?:\.[0-9]+)*\b/g) {
    my $s = $-[0]; my $e = $+[0];
    next if $overlaps->($s, $e);
    push @items, { pos => $s, claim => substr($masked, $s, $e - $s) };
    push @consumed, [$s, $e];
  }
  while ($masked =~ /\bversion\s+[0-9]+(?:\.[0-9]+)*\b/gi) {
    my $s = $-[0]; my $e = $+[0];
    next if $overlaps->($s, $e);
    push @items, { pos => $s, claim => substr($masked, $s, $e - $s) };
    push @consumed, [$s, $e];
  }
  return @items;
}

# --- Git context: is this file inside a repo, and what is its own last-commit info. ----------------
my $git_root;
{
  # Outside a repository, git's "not a git repository" error is expected; keep it off stderr.
  open(my $saved_err, '>&', \*STDERR);
  open(STDERR, '>', '/dev/null');
  my $pid = open(my $gfh, '-|', 'git', '-C', $dir, 'rev-parse', '--show-toplevel');
  open(STDERR, '>&', $saved_err);
  if ($pid) {
    local $/;
    my $out = <$gfh>;
    close $gfh;
    if (defined $out && $? == 0) {
      $out =~ s/\s+$//;
      $git_root = $out if length $out;
    }
  }
}

my ($doc_commit_date, $doc_commit_epoch);
if (defined $git_root) {
  my $rel = $file;
  if (index($file, "$git_root/") == 0) { $rel = substr($file, length($git_root) + 1); }
  my $pid = open(my $gfh, '-|', 'git', '-C', $git_root, 'log', '-1', '--format=%cs%x09%ct', '--', $rel);
  if ($pid) {
    local $/;
    my $out = <$gfh>;
    close $gfh;
    if (defined $out && $? == 0 && length($out)) {
      chomp $out;
      ($doc_commit_date, $doc_commit_epoch) = split /\t/, $out, 2;
    }
  }
}

sub target_commit_epoch {
  my ($canon_path, $root) = @_;
  return undef unless defined $root && length $root;
  return undef unless index($canon_path, "$root/") == 0;
  my $rel = substr($canon_path, length($root) + 1);
  my $pid = open(my $gfh, '-|', 'git', '-C', $root, 'log', '-1', '--format=%ct', '--', $rel);
  return undef unless $pid;
  local $/;
  my $out = <$gfh>;
  close $gfh;
  return undef unless defined $out && $? == 0 && length($out);
  chomp $out;
  return $out;
}

# --- Freshness header: first of the file's first 60 raw lines matching the fm_date rule. ----------
my ($fresh_line, $fresh_date);
{
  my $limit = $n < 60 ? $n : 60;
  for (my $i = 1; $i <= $limit; $i++) {
    if ($lines[$i - 1] =~ /^updated: *([0-9]{4}-[0-9]{2}-[0-9]{2})/) {
      $fresh_line = $i;
      $fresh_date = $1;
      last;
    }
  }
}

my @all_rows;   # [line, heading, kind, claim, result]

for (my $i = 1; $i <= $n; $i++) {
  next if $is_frontmatter[$i];
  next if $is_fenced[$i];
  # The line that supplies the freshness header is metadata, already settled by the freshness row
  # below; it is not re-scanned for ordinary claims (its date would otherwise duplicate as "dated").
  next if defined $fresh_line && $i == $fresh_line;

  my $line = $lines[$i - 1];
  my $masked = mask_inline_code($line);
  my $heading = $heading_for_line[$i];

  my @events;

  {
    my $s = $line;
    while ($s =~ /(`+)(.*?)\1/g) {
      push @events, { pos => $-[0], type => 'span', content => $2, endpos => $+[0] };
    }
  }

  while ($masked =~ /(!?)\[([^\]]*)\]\(([^)]*)\)/g) {
    my $pos = $-[0];
    next if $1 eq '!';
    my $target = parse_target($3);
    next if $target eq '' || $target =~ /^https?:/ || $target =~ /^mailto:/ || $target !~ /#/;
    my ($p_part, $a_part) = $target =~ m{^([^#]*)#(.+)$};
    next unless defined $p_part && length($p_part) && defined $a_part && length($a_part);
    push @events, { pos => $pos, type => 'link', path => $p_part, anchor => $a_part };
  }

  foreach my $d (extract_dated($masked)) {
    push @events, { pos => $d->{pos}, type => 'dated', claim => $d->{claim} };
  }

  @events = sort { $a->{pos} <=> $b->{pos} } @events;

  foreach my $ev (@events) {
    if ($ev->{type} eq 'span') {
      my @items = classify_span($ev->{content});
      foreach my $item (@items) {
        my $result;
        if ($extract) { $result = 'extracted'; }
        else { ($result) = compute_result_for_item($item, $dir, $git_root); }
        push @all_rows, [$i, $heading, $item->{kind}, $item->{claim}, $result];

        if (!$extract && $item->{kind} eq 'path' && $result eq 'found' && defined $doc_commit_epoch) {
          my (undef, $canon) = resolve_path($item->{claim}, $dir, $git_root);
          if (defined $canon) {
            my $tgt_epoch = target_commit_epoch($canon, $git_root);
            if (defined $tgt_epoch && $tgt_epoch > $doc_commit_epoch) {
              push @all_rows, [$i, $heading, 'drift', $item->{claim}, 'newer-than-doc'];
            }
          }
        }

        if ($item->{kind} eq 'path') {
          my $rest = substr($line, $ev->{endpos});
          my $sentence = $rest;
          my $cut = index($rest, '. ');
          if ($cut >= 0) { $sentence = substr($rest, 0, $cut + 1); }
          if ($sentence =~ /"([^"]*)"/) {
            my $quoted = $1;
            my $hresult;
            if ($extract) { $hresult = 'extracted'; }
            else { $hresult = check_heading_ref($item->{claim}, $dir, $git_root, undef, $quoted); }
            push @all_rows, [$i, $heading, 'heading-ref', "$item->{claim} > $quoted", $hresult];
          }
        }
      }
    } elsif ($ev->{type} eq 'link') {
      my $claim = "$ev->{path}#$ev->{anchor}";
      my $result;
      if ($extract) { $result = 'extracted'; }
      else { $result = check_heading_ref($ev->{path}, $dir, $git_root, $ev->{anchor}, undef); }
      push @all_rows, [$i, $heading, 'heading-ref', $claim, $result];
    } elsif ($ev->{type} eq 'dated') {
      my $result = $extract ? 'extracted' : 'candidate';
      push @all_rows, [$i, $heading, 'dated', $ev->{claim}, $result];
    }
  }
}

if (!$extract && defined $fresh_line && defined $doc_commit_date) {
  my ($hy, $hm, $hd) = split /-/, $fresh_date;
  my ($cy, $cm, $cd) = split /-/, $doc_commit_date;
  my $h_epoch = Time::Local::timegm(0, 0, 0, $hd, $hm - 1, $hy);
  my $c_epoch = Time::Local::timegm(0, 0, 0, $cd, $cm - 1, $cy);
  if ($c_epoch - $h_epoch > 86400) {
    push @all_rows, [$fresh_line, $heading_for_line[$fresh_line], 'freshness',
                      "updated: $fresh_date; last commit $doc_commit_date", 'stale-header'];
  }
}

@all_rows = sort { $a->[0] <=> $b->[0] } @all_rows;

foreach my $r (@all_rows) {
  my $claim = $r->[3];
  $claim =~ s/[\t\n]/ /g;
  print "$file\t$r->[0]\t$r->[1]\t$r->[2]\t$claim\t$r->[4]\n";
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

  perl -e "$PERL_PROGRAM" -- "$abs" "$dir" "$extract"
done

exit 0
