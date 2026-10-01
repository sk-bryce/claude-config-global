#!/usr/bin/env bash
#
# review-fill.sh - builds review-md's proofread units and judgment groups, and fills the prompt
# templates that go to each worker pass, so no model ever has to type a prompt itself.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit.
#
# Usage: review-fill.sh units <run-dir>
#   Reads <run-dir>/files.tsv and <run-dir>/request.md. Writes units.tsv and groups.tsv. Prints
#   exactly: "units=<N>", "groups=<G>", then one "P<k><TAB><D ids><TAB><scopes>" line per unit.
# Usage: review-fill.sh fill <run-dir> <proofread|area|rerun|verify>
#   Reads <run-dir> and the skill directory named in <run-dir>/skill.txt. Writes
#   <run-dir>/prompts/<ID>.md for every unit of that kind (and, for verify,
#   <run-dir>/prompts/V<g>-findings.md). Prints one "<ID><TAB><prompt path><TAB><output path>"
#   line per prompt written, or nothing when that kind has no units (rerun with an empty
#   rerun.tsv).
#
#   Exit codes: 0 success; 2 usage error; 1 internal failure. On exit 1 or 2 this prints one
#   stderr line starting "review-fill.sh: ".
#
# Implements contract A's "units" and "fill" subcommands, contract C (units and groups), and
# contract F (templates and slot filling). See the review-md section of specs/skills.md for the
# contracts themselves.
#
# This script and the embedded perl run unchanged under bash 3.2.57 and perl's core modules only.

set -uo pipefail

prog="review-fill.sh"

usage() {
  echo "usage: $prog units <run-dir>" >&2
  echo "       $prog fill <run-dir> <proofread|area|rerun|verify>" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
cmd="$1"
shift

kind=""
case "$cmd" in
  units)
    [[ $# -eq 1 ]] || usage
    run="$1"
    ;;
  fill)
    [[ $# -eq 2 ]] || usage
    run="$1"
    kind="$2"
    case "$kind" in
      proofread|area|rerun|verify) ;;
      *) usage ;;
    esac
    ;;
  *)
    usage
    ;;
esac

[[ -n "$run" && -d "$run" ]] || {
  echo "$prog: run directory not found: $run" >&2
  exit 2
}
run="$(cd "$run" && pwd)"

command -v perl >/dev/null 2>&1 || {
  echo "$prog: required command 'perl' not found" >&2
  exit 1
}

[[ -f "$run/files.tsv" ]] || {
  echo "$prog: missing $run/files.tsv" >&2
  exit 1
}

# --- units ------------------------------------------------------------------------------------
read -r -d '' UNITS_PERL <<'PERL'
use strict;
use warnings;
use utf8;
use POSIX qw(ceil);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my ($run) = @ARGV;

sub die_internal {
  print STDERR "review-fill.sh: $_[0]\n";
  exit 1;
}

sub read_all_lines {
  my ($p) = @_;
  open(my $fh, '<:encoding(UTF-8)', $p) or die_internal("cannot read $p");
  my @l = <$fh>;
  close $fh;
  return @l;
}

sub fence_flags {
  my (@lines) = @_;
  my @is_fenced = (0) x scalar(@lines);
  my $in_fence = 0;
  my $fc = '';
  my $flen = 0;
  for (my $i = 0; $i < @lines; $i++) {
    my $line = $lines[$i];
    if ($in_fence) {
      $is_fenced[$i] = 1;
      if ($line =~ /^ {0,3}\Q$fc\E{$flen,}[ \t]*$/) {
        $in_fence = 0;
      }
      next;
    }
    if ($line =~ /^ {0,3}(`{3,}|~{3,})/) {
      $is_fenced[$i] = 1;
      $in_fence = 1;
      $fc = substr($1, 0, 1);
      $flen = length($1);
    }
  }
  return @is_fenced;
}

sub extract_sections {
  my ($path) = @_;
  my @lines = read_all_lines($path);
  my @fenced = fence_flags(@lines);

  my @h2idx;
  for (my $i = 0; $i < @lines; $i++) {
    next if $fenced[$i];
    push @h2idx, $i if $lines[$i] =~ /^##(?!#)[ \t]+(.*)$/;
  }

  my @sections;
  my $first_h2 = @h2idx ? $h2idx[0] : scalar(@lines);
  my $preamble = join('', @lines[0 .. $first_h2 - 1]);
  if (length($preamble) > 0) {
    push @sections, { name => '(text above the first H2)', chars => length($preamble) };
  }

  for (my $hi = 0; $hi < @h2idx; $hi++) {
    my $start = $h2idx[$hi];
    my $end = ($hi + 1 < @h2idx) ? $h2idx[$hi + 1] - 1 : $#lines;
    $lines[$start] =~ /^##(?!#)[ \t]+(.*)$/;
    my $name = $1;
    $name =~ s/\s+$//;
    my $section_text = join('', @lines[$start .. $end]);
    my $schars = length($section_text);

    if ($schars > 60000) {
      my @h3idx;
      for (my $i = $start; $i <= $end; $i++) {
        next if $fenced[$i];
        push @h3idx, $i if $lines[$i] =~ /^###(?!#)[ \t]+(.*)$/;
      }
      if (@h3idx) {
        my $prefix_end = $h3idx[0] - 1;
        my $prefix_text = join('', @lines[$start .. $prefix_end]);
        for (my $hj = 0; $hj < @h3idx; $hj++) {
          my $hs = $h3idx[$hj];
          my $he = ($hj + 1 < @h3idx) ? $h3idx[$hj + 1] - 1 : $end;
          $lines[$hs] =~ /^###(?!#)[ \t]+(.*)$/;
          my $h3name = $1;
          $h3name =~ s/\s+$//;
          my $body = join('', @lines[$hs .. $he]);
          $body = $prefix_text . $body if $hj == 0;
          push @sections, { name => "$name > $h3name", chars => length($body) };
        }
      } else {
        push @sections, { name => $name, chars => $schars };
      }
    } else {
      push @sections, { name => $name, chars => $schars };
    }
  }

  return @sections;
}

open(my $fh, '<:encoding(UTF-8)', "$run/files.tsv") or die_internal("cannot read files.tsv");
my @docs;
my $idx = 0;
while (my $line = <$fh>) {
  chomp $line;
  next if $line eq '';
  my ($id, $path, $chars) = split /\t/, $line;
  die_internal("malformed files.tsv row: $line") unless defined $chars;
  $idx++;
  push @docs, { id => $id, path => $path, chars => $chars + 0, idx => $idx };
}
close $fh;

my @units;
my @bins;
my $gen = 0;

foreach my $d (@docs) {
  my $chars = $d->{chars};
  if ($chars <= 30000) {
    my $placed = 0;
    foreach my $b (@bins) {
      if ($b->{chars} + $chars <= 30000) {
        push @{ $b->{unit}{docs} }, { id => $d->{id}, scope => 'whole document' };
        $b->{chars} += $chars;
        $placed = 1;
        last;
      }
    }
    if (!$placed) {
      $gen++;
      my $unit = {
        docs => [ { id => $d->{id}, scope => 'whole document' } ],
        minidx => $d->{idx},
        order => $gen,
      };
      push @bins, { chars => $chars, unit => $unit };
      push @units, $unit;
    }
  } elsif ($chars <= 60000) {
    $gen++;
    push @units, {
      docs => [ { id => $d->{id}, scope => 'whole document' } ],
      minidx => $d->{idx},
      order => $gen,
    };
  } else {
    my @sections = extract_sections($d->{path});
    my $k = ceil($chars / 50000);
    $k = 1 if $k < 1;
    my $target = $chars / $k;
    my $limit = $target * 1.2;
    $limit = 60000 if $limit > 60000;

    my @parts;
    my $cur;
    foreach my $s (@sections) {
      if (defined $cur && $cur->{chars} + $s->{chars} > $limit) {
        push @parts, $cur;
        $cur = undef;
      }
      $cur = { names => [], chars => 0 } unless defined $cur;
      push @{ $cur->{names} }, $s->{name};
      $cur->{chars} += $s->{chars};
    }
    push @parts, $cur if defined $cur;

    foreach my $p (@parts) {
      $gen++;
      my $scope = 'sections: ' . join(', ', @{ $p->{names} });
      push @units, {
        docs => [ { id => $d->{id}, scope => $scope } ],
        minidx => $d->{idx},
        order => $gen,
      };
    }
  }
}

@units = sort { $a->{minidx} <=> $b->{minidx} || $a->{order} <=> $b->{order} } @units;

open(my $rf, '<:encoding(UTF-8)', "$run/request.md") or die_internal("cannot read request.md");
my $sizecap = 'none';
while (my $l = <$rf>) {
  chomp $l;
  if ($l =~ /^size-cap=(.*)$/) {
    $sizecap = $1;
    last;
  }
}
close $rf;

my @groups;
if ($sizecap eq 'groups') {
  my @bucket_order;
  my %bucket_map;
  foreach my $d (@docs) {
    my $dir = $d->{path};
    $dir =~ s{/[^/]*$}{};
    $dir = '/' if $dir eq '';
    if (!exists $bucket_map{$dir}) {
      $bucket_map{$dir} = [];
      push @bucket_order, $dir;
    }
    push @{ $bucket_map{$dir} }, $d;
  }

  my @buckets;
  foreach my $dir (@bucket_order) {
    my @ds = @{ $bucket_map{$dir} };
    my $tot_chars = 0;
    $tot_chars += $_->{chars} for @ds;
    if (scalar(@ds) <= 25 && $tot_chars <= 250000) {
      push @buckets, \@ds;
    } else {
      my @cur;
      my $curchars = 0;
      foreach my $d (@ds) {
        if (@cur && (scalar(@cur) + 1 > 25 || $curchars + $d->{chars} > 250000)) {
          push @buckets, [@cur];
          @cur = ();
          $curchars = 0;
        }
        push @cur, $d;
        $curchars += $d->{chars};
      }
      push @buckets, [@cur] if @cur;
    }
  }

  my @gfiles;
  my @gchars;
  my @gdocs;
  foreach my $b (@buckets) {
    my $bfiles = scalar(@$b);
    my $bchars = 0;
    $bchars += $_->{chars} for @$b;
    my $placed = -1;
    for (my $i = 0; $i < @gfiles; $i++) {
      if ($gfiles[$i] + $bfiles <= 25 && $gchars[$i] + $bchars <= 250000) {
        $placed = $i;
        last;
      }
    }
    if ($placed == -1) {
      push @gfiles, $bfiles;
      push @gchars, $bchars;
      push @gdocs, [ map { $_->{id} } @$b ];
    } else {
      $gfiles[$placed] += $bfiles;
      $gchars[$placed] += $bchars;
      push @{ $gdocs[$placed] }, map { $_->{id} } @$b;
    }
  }
  @groups = @gdocs;
} else {
  @groups = ( [ map { $_->{id} } @docs ] ) if @docs;
}

open(my $ut, '>:encoding(UTF-8)', "$run/units.tsv") or die_internal("cannot write units.tsv");
my $k = 0;
foreach my $u (@units) {
  $k++;
  foreach my $doc (@{ $u->{docs} }) {
    print $ut "P$k\t$doc->{id}\t$doc->{scope}\n";
  }
}
close $ut;

open(my $gt, '>:encoding(UTF-8)', "$run/groups.tsv") or die_internal("cannot write groups.tsv");
my $g = 0;
foreach my $grp (@groups) {
  $g++;
  foreach my $did (@$grp) {
    print $gt "A$g\t$did\n";
  }
}
close $gt;

print 'units=' . scalar(@units) . "\n";
print 'groups=' . scalar(@groups) . "\n";
$k = 0;
foreach my $u (@units) {
  $k++;
  my $ids = join(',', map { $_->{id} } @{ $u->{docs} });
  my $scopes = join(' | ', map { $_->{scope} } @{ $u->{docs} });
  print "P$k\t$ids\t$scopes\n";
}
PERL

# --- fill -------------------------------------------------------------------------------------
read -r -d '' FILL_PERL <<'PERL'
use strict;
use warnings;
use utf8;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my ($run, $kind) = @ARGV;

sub die_internal {
  print STDERR "review-fill.sh: $_[0]\n";
  exit 1;
}

sub read_all_lines {
  my ($p) = @_;
  open(my $fh, '<:encoding(UTF-8)', $p) or die_internal("cannot read $p");
  my @l = <$fh>;
  close $fh;
  return @l;
}

sub read_file_text {
  my ($p) = @_;
  return undef unless -e $p;
  open(my $fh, '<:encoding(UTF-8)', $p) or die_internal("cannot read $p");
  local $/;
  my $t = <$fh>;
  close $fh;
  return defined $t ? $t : '';
}

my $LINK_TABLE_TEXT = <<'TBL';
| Label | Meaning |
| --- | --- |
| `ok` | curl exit 0 with a final code of 200-399, after following redirects |
| `broken` | curl exit 6 (DNS failure) or 7 (connection refused), or exit 0 with a final code of 404 or 410 |
| `inconclusive` | a second timeout (exit 28 twice), any other non-zero curl exit such as a TLS error, or exit 0 with any other code (401, 403, 429, 5xx, 000, and the rest) |
| `skipped:fenced-code` | the link is on a fenced line |
| `skipped:inline-code` | the link is inside an inline code span |
| `skipped:unsupported-scheme` | the link is not http or https |
| `skipped:no-curl` | curl is not installed |
| `skipped:missing-file`, `skipped:not-markdown` | the file argument was missing or not Markdown |
| `no-references` | the document cites external pages with no References heading, where the References rule is adopted |
TBL

# --- rerun: exit early with no output when there are no reruns to fill ------------------------
if ($kind eq 'rerun' && !(-e "$run/rerun.tsv" && -s "$run/rerun.tsv")) {
  exit 0;
}

open(my $sf, '<:encoding(UTF-8)', "$run/skill.txt") or die_internal("cannot read skill.txt");
my $skilldir = <$sf>;
close $sf;
die_internal("skill.txt is empty") unless defined $skilldir;
chomp $skilldir;
die_internal("skill directory not found: $skilldir") unless -d $skilldir;

my %template_file = (
  proofread => "$skilldir/references/proofread-pass.md",
  rerun     => "$skilldir/references/proofread-pass.md",
  area      => "$skilldir/references/area-pass.md",
  verify    => "$skilldir/references/verify-pass.md",
);
my $template_path = $template_file{$kind};

sub extract_template {
  my ($path) = @_;
  my $text = read_file_text($path);
  die_internal("template not found: $path") unless defined $text;
  if ($text =~ /<!-- prompt start -->\r?\n(.*?)\n<!-- prompt end -->/s) {
    return $1 . "\n";
  }
  die_internal("template missing prompt markers: $path");
}

my $template = extract_template($template_path);

open(my $ff, '<:encoding(UTF-8)', "$run/files.tsv") or die_internal("cannot read files.tsv");
my @docs_all;
my %pathof;
while (my $line = <$ff>) {
  chomp $line;
  next if $line eq '';
  my ($id, $path, $chars) = split /\t/, $line;
  die_internal("malformed files.tsv row: $line") unless defined $chars;
  push @docs_all, { id => $id, path => $path, chars => $chars + 0 };
  $pathof{$id} = $path;
}
close $ff;

my %is_agent_config;
my $git_root = 'none';
if (-e "$run/context.txt") {
  open(my $cf, '<:encoding(UTF-8)', "$run/context.txt") or die_internal("cannot read context.txt");
  while (my $l = <$cf>) {
    chomp $l;
    if ($l =~ /^agent-config=(.*)$/) {
      my $v = $1;
      if ($v ne 'none' && $v ne '') {
        $is_agent_config{$_} = 1 for split(/,/, $v);
      }
    } elsif ($l =~ /^git-root=(.*)$/) {
      $git_root = $1;
    }
  }
  close $cf;
}

my $exclusions = read_file_text("$run/exclusions.txt");
$exclusions = '' unless defined $exclusions;

sub build_request_text {
  my @lines = read_all_lines("$run/request.md");
  my $i = 0;
  for (; $i < @lines; $i++) {
    last if $lines[$i] =~ /^--- request ---\s*$/;
  }
  die_internal("request.md missing '--- request ---' marker") if $i >= @lines;
  my @req = @lines[$i + 1 .. $#lines];
  my $text = join('', @req);
  $text =~ s/\n+$//;
  return $text;
}

sub build_context_block {
  my $reqtext = build_request_text();
  my @paths = map { $_->{path} } @docs_all;
  my $resolved = join('', map { "      $_\n" } @paths);
  my $dr;
  if (-e "$run/deep-review.md") {
    $dr = read_file_text("$run/deep-review.md");
    $dr =~ s/\n+$//;
  } else {
    $dr = 'none';
  }
  return "Context block\n"
    . "- Request (source: user message): $reqtext\n"
    . "- Resolved files:\n"
    . $resolved
    . "- deep-review verdict and findings (source: deep-review): $dr\n";
}

my $context_block = build_context_block();

mkdir("$run/prompts") unless -d "$run/prompts";

sub docs_lines_with_scope {
  my (@docitems) = @_;
  my @lines;
  foreach my $it (@docitems) {
    push @lines, "- $it->{id}: $pathof{$it->{id}} (scope: $it->{scope})";
  }
  return join("\n", @lines) . "\n";
}

sub target_files_lines {
  my (@ids) = @_;
  return "none\n" unless @ids;
  return join("\n", map { "- $_: $pathof{$_}" } @ids) . "\n";
}

sub claims_files_lines {
  my (@ids) = @_;
  my @lines;
  foreach my $id (@ids) {
    my $p = "$run/docs/$id/claims.tsv";
    my $n = 0;
    if (-e $p) {
      open(my $fh, '<:encoding(UTF-8)', $p) or die_internal("cannot read $p");
      while (my $l = <$fh>) {
        chomp $l;
        $n++ if length($l);
      }
      close $fh;
    }
    if ($n == 0) {
      push @lines, "- $id: none";
    } else {
      push @lines, "- $id: $p ($n rows)";
    }
  }
  return join("\n", @lines) . "\n";
}

sub signals_files_lines {
  my (@ids) = @_;
  return join("\n", map { "- $_: $run/docs/$_/signals.txt" } @ids) . "\n";
}

sub spec_files_lines {
  my (@ids) = @_;
  my @lines;
  foreach my $id (@ids) {
    my $p = "$run/docs/$id/spec.md";
    my $content = read_file_text($p);
    $content = '' unless defined $content;
    $content =~ s/\s+$//;
    if ($content eq 'none') {
      push @lines, "- $id: none";
    } else {
      push @lines, "- $id: $p";
    }
  }
  return join("\n", @lines) . "\n";
}

sub link_table_for {
  my (@ids) = @_;
  foreach my $id (@ids) {
    my $p = "$run/docs/$id/links.tsv";
    if (-e $p && -s $p) {
      return $LINK_TABLE_TEXT;
    }
  }
  return "No link rows for these documents.\n";
}

sub load_units_as_items {
  my ($path) = @_;
  return () unless -e $path;
  my @lines = read_all_lines($path);
  my %by;
  my @order;
  foreach my $l (@lines) {
    chomp $l;
    next if $l eq '';
    my ($pid, $did, $scope) = split /\t/, $l, 3;
    if (!exists $by{$pid}) {
      $by{$pid} = [];
      push @order, $pid;
    }
    push @{ $by{$pid} }, { id => $did, scope => $scope };
  }
  my @items;
  foreach my $pid (@order) {
    push @items, { id => $pid, docs => $by{$pid} };
  }
  return @items;
}

sub load_groups_as_items {
  my ($path, $prefix) = @_;
  return () unless -e $path;
  my @lines = read_all_lines($path);
  my %by;
  my @order;
  foreach my $l (@lines) {
    chomp $l;
    next if $l eq '';
    my ($gid, $did) = split /\t/, $l, 2;
    if (!exists $by{$gid}) {
      $by{$gid} = [];
      push @order, $gid;
    }
    push @{ $by{$gid} }, $did;
  }
  my @items;
  foreach my $gid (@order) {
    my $num = $gid;
    $num =~ s/^A//;
    push @items, { id => "$prefix$num", docs => [ map { { id => $_, scope => undef } } @{ $by{$gid} } ] };
  }
  return @items;
}

sub load_rerun_items {
  my ($path) = @_;
  return () unless -e $path;
  my @lines = read_all_lines($path);
  my @items;
  foreach my $l (@lines) {
    chomp $l;
    next if $l eq '';
    my ($rid, $did, $heading) = split /\t/, $l, 3;
    push @items, { id => $rid, docs => [ { id => $did, scope => "sections: $heading" } ] };
  }
  return @items;
}

sub findings_blocks {
  my ($text) = @_;
  return () unless defined $text;
  my @lines = split /\n/, $text, -1;
  pop @lines if @lines && $lines[-1] eq '';
  my @starts;
  for (my $i = 0; $i < @lines; $i++) {
    push @starts, $i if $lines[$i] =~ /^- \*\*/;
  }
  my @blocks;
  for (my $i = 0; $i < @starts; $i++) {
    my $s = $starts[$i];
    my $e = ($i + 1 < @starts) ? $starts[$i + 1] - 1 : $#lines;
    for (my $j = $s; $j <= $e; $j++) {
      if ($lines[$j] =~ /^### /) {
        $e = $j - 1;
        last;
      }
    }
    $e-- while ($e > $s && $lines[$e] eq '');
    push @blocks, join("\n", @lines[$s .. $e]);
  }
  return @blocks;
}

sub block_first_file {
  my ($block) = @_;
  return $1 if $block =~ /^  - File:\s*(.+?)\s*$/m;
  return undef;
}

my @items;
if ($kind eq 'proofread') {
  @items = load_units_as_items("$run/units.tsv");
} elsif ($kind eq 'rerun') {
  @items = load_rerun_items("$run/rerun.tsv");
} elsif ($kind eq 'area') {
  @items = load_groups_as_items("$run/groups.tsv", 'A');
} elsif ($kind eq 'verify') {
  @items = load_groups_as_items("$run/groups.tsv", 'V');
}

my $G_total = scalar(@items);

my @all_findings_blocks;
if ($kind eq 'verify') {
  @all_findings_blocks = findings_blocks(read_file_text("$run/proofread-findings.md"));
}

foreach my $item (@items) {
  my $id = $item->{id};
  my @ids = map { $_->{id} } @{ $item->{docs} };
  my %slots;
  $slots{OUTPUT} = "$run/out/$id.md";
  $slots{CONTEXT_BLOCK} = $context_block;
  $slots{EXCLUSIONS} = $exclusions;

  if ($kind eq 'proofread' || $kind eq 'rerun') {
    $slots{DOCUMENTS} = docs_lines_with_scope(@{ $item->{docs} });
    $slots{CLAIMS_FILES} = claims_files_lines(@ids);
    $slots{SIGNALS_FILES} = signals_files_lines(@ids);
    $slots{SPEC_FILES} = spec_files_lines(@ids);
    $slots{LINK_TABLE} = link_table_for(@ids);
  } elsif ($kind eq 'area') {
    $slots{TARGET_FILES} = target_files_lines(@ids);
    my ($gnum) = $id =~ /^A(\d+)$/;
    $slots{GROUP} = ($G_total == 1) ? 'all' : "group $gnum of $G_total";
    $slots{MULTI_DOC} = (scalar(@ids) > 1) ? 'yes' : 'no';
    my @pf = grep { $is_agent_config{$_} } @ids;
    $slots{PROFILE_FILES} = target_files_lines(@pf);
    $slots{SPEC_FILES} = spec_files_lines(@ids);
  } elsif ($kind eq 'verify') {
    $slots{TARGET_FILES} = target_files_lines(@ids);
    $slots{SPEC_FILES} = spec_files_lines(@ids);
    my %grouppaths;
    foreach my $did (@ids) {
      my $p = $pathof{$did};
      $grouppaths{$p} = 1;
      if ($git_root ne 'none' && index($p, "$git_root/") == 0) {
        $grouppaths{substr($p, length($git_root) + 1)} = 1;
      }
    }
    my @matched = grep {
      my $f = block_first_file($_);
      defined $f && $grouppaths{$f};
    } @all_findings_blocks;
    if (@matched) {
      my $fpath = "$run/prompts/$id-findings.md";
      open(my $fw, '>:encoding(UTF-8)', $fpath) or die_internal("cannot write $fpath");
      print $fw join("\n\n", @matched) . "\n";
      close $fw;
      $slots{FINDINGS_FILE} = $fpath;
    } else {
      $slots{FINDINGS_FILE} = 'none';
    }
  }

  my $filled = $template;
  my $failed_slot;
  $filled =~ s/\{\{(\w+)\}\}/
    exists $slots{$1} ? $slots{$1} : do { $failed_slot = $1; '' }
  /gxe;
  if (defined $failed_slot) {
    die_internal("unknown slot {{$failed_slot}} in $template_path");
  }

  my $prompt_path = "$run/prompts/$id.md";
  open(my $pw, '>:encoding(UTF-8)', $prompt_path) or die_internal("cannot write $prompt_path");
  print $pw $filled;
  close $pw;

  print "$id\t$prompt_path\t$slots{OUTPUT}\n";
}
PERL

case "$cmd" in
  units)
    perl -e "$UNITS_PERL" -- "$run"
    rc=$?
    if [[ $rc -ne 0 && $rc -ne 1 && $rc -ne 2 ]]; then
      echo "$prog: internal failure (perl exit $rc)" >&2
      exit 1
    fi
    exit $rc
    ;;
  fill)
    perl -e "$FILL_PERL" -- "$run" "$kind"
    rc=$?
    if [[ $rc -ne 0 && $rc -ne 1 && $rc -ne 2 ]]; then
      echo "$prog: internal failure (perl exit $rc)" >&2
      exit 1
    fi
    exit $rc
    ;;
esac
