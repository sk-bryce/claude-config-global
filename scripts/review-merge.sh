#!/usr/bin/env bash
#
# review-merge.sh - the coverage, prefilter, merge, and record subcommands of review-md's run
# directory (CONTRACT A in the review-md section of specs/skills.md): decides which claims still
# need a rerun, drops findings a tracking entry has already settled, merges
# script/proofread/judgment findings into
# one numbered report, and records a human's intentional/deferred decision back to the tracking
# file. All parsing, tracking-match, duplicate-detection, and JSON assembly below is embedded
# perl (JSON::PP for findings.json), so review-md's own context never has to parse any of it.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and
# is reviewed in full before commit.
#
# Usage:
#   review-merge.sh coverage <run-dir> [--final]
#   review-merge.sh prefilter <run-dir>
#   review-merge.sh merge <run-dir> --tier <sonnet|opus>
#   review-merge.sh record <run-dir> <F-id> <intentional|deferred> <description>
#
#   Exit codes: 0 success; 2 usage error; 1 internal failure. On exit 1 or 2 this prints one
#   stderr line starting "review-merge.sh: ". Stdout carries only the lines named by CONTRACT A's
#   coverage, prefilter, merge, and record subcommands (see the review-md section of
#   specs/skills.md).
#
# Implements CONTRACT A's "coverage", "prefilter", "merge", and "record" subcommands, CONTRACT B
# (the output formats this reads), CONTRACT E (the algorithms), and CONTRACT R (the declaration
# line regex). See the review-md section of specs/skills.md for the contracts themselves.
#
# This script and the embedded perl run unchanged under bash 3.2.57 and perl's core modules only
# (JSON::PP is allowed): no associative arrays, no case-folding parameter expansion, no
# bulk-array-read builtins, no bash namerefs, no |&, no ;;&, no negative array indices.

set -uo pipefail

prog="review-merge.sh"

usage() {
  echo "usage: $prog coverage <run-dir> [--final]" >&2
  echo "       $prog prefilter <run-dir>" >&2
  echo "       $prog merge <run-dir> --tier <sonnet|opus>" >&2
  echo "       $prog record <run-dir> <F-id> <intentional|deferred> <description>" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
cmd="$1"
shift

case "$cmd" in
  coverage|prefilter|merge|record) ;;
  *) usage ;;
esac

[[ $# -ge 1 ]] || usage
run="$1"
shift

[[ -n "$run" && -d "$run" ]] || {
  echo "$prog: run directory not found: $run" >&2
  exit 2
}
run="$(cd "$run" && pwd)"

final="0"
tier=""
fid=""
status=""
description=""

case "$cmd" in
  coverage)
    if [[ $# -gt 0 ]]; then
      [[ "$1" == "--final" ]] || usage
      final="1"
      shift
    fi
    [[ $# -eq 0 ]] || usage
    ;;
  prefilter)
    [[ $# -eq 0 ]] || usage
    ;;
  merge)
    [[ "${1:-}" == "--tier" ]] || usage
    shift
    tier="${1:-}"
    case "$tier" in
      sonnet|opus) ;;
      *) usage ;;
    esac
    shift
    [[ $# -eq 0 ]] || usage
    ;;
  record)
    [[ $# -eq 3 ]] || usage
    fid="$1"
    status="$2"
    description="$3"
    case "$status" in
      intentional|deferred) ;;
      *) usage ;;
    esac
    shift 3
    ;;
esac

command -v perl >/dev/null 2>&1 || {
  echo "$prog: required command 'perl' not found" >&2
  exit 1
}

read -r -d '' MERGE_PERL <<'PERL'
use strict;
use warnings;
use utf8;
use JSON::PP qw(decode_json encode_json);
use POSIX qw(strftime mktime);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

sub die_internal {
  print STDERR "review-merge.sh: $_[0]\n";
  exit 1;
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

sub write_file_text {
  my ($p, $content) = @_;
  open(my $fh, '>:encoding(UTF-8)', $p) or die_internal("cannot write $p");
  print $fh $content;
  close $fh;
}

sub append_file_text {
  my ($p, $content) = @_;
  open(my $fh, '>>:encoding(UTF-8)', $p) or die_internal("cannot write $p");
  print $fh $content;
  close $fh;
}

sub read_lines_opt {
  my ($p) = @_;
  return () unless -e $p;
  open(my $fh, '<:encoding(UTF-8)', $p) or die_internal("cannot read $p");
  my @l = <$fh>;
  close $fh;
  chomp @l;
  return @l;
}

sub read_tsv_opt {
  my ($p) = @_;
  my @rows;
  for my $l (read_lines_opt($p)) {
    next if $l eq '';
    push @rows, [split /\t/, $l, -1];
  }
  return @rows;
}

sub collapse_ws {
  my ($s) = @_;
  $s = '' unless defined $s;
  $s =~ s/\s+/ /g;
  $s =~ s/^\s+|\s+$//g;
  return $s;
}

sub today_str { return strftime('%Y-%m-%d', localtime); }

sub days_old {
  my ($datestr) = @_;
  return 0 unless defined $datestr && $datestr =~ /^(\d{4})-(\d{2})-(\d{2})$/;
  my $then = mktime(0, 0, 12, $3, $2 - 1, $1 - 1900);
  return 0 unless defined $then;
  return int((time() - $then) / 86400);
}

sub numkey {
  my ($s) = @_;
  return $1 if $s =~ /(\d+)/;
  return 0;
}

sub numsort { return sort { numkey($a) <=> numkey($b) } @_; }

sub list_out_files {
  my ($run, $prefix) = @_;
  opendir(my $dh, "$run/out") or return ();
  my @all = readdir($dh);
  closedir($dh);
  return numsort(grep { /^\Q$prefix\E\d+\.md$/ } @all);
}

sub parse_kv {
  my ($path) = @_;
  my %h;
  for my $line (read_lines_opt($path)) {
    next unless $line =~ /^([^=]+)=(.*)$/;
    $h{$1} = $2;
  }
  return %h;
}

# --- generic Finding-block parsing (CONTRACT B/E) ----------------------------------------------

sub parse_blocks {
  my ($text) = @_;
  return () unless defined $text;
  my @lines = split /\n/, $text, -1;
  pop @lines if @lines && $lines[-1] eq '';
  my @blocks;
  my $cur;
  my $lastfield;
  for my $line (@lines) {
    if ($line =~ /^- \*\*(\S+)\*\*\s*$/) {
      push @blocks, $cur if $cur;
      $cur = { id => $1, fields => [] };
      $lastfield = undef;
      next;
    }
    if ($line =~ /^#/) {
      push @blocks, $cur if $cur;
      $cur = undef;
      $lastfield = undef;
      next;
    }
    next unless $cur;
    if ($line =~ /^  - ([^:]+): (.*)$/) {
      push @{ $cur->{fields} }, { name => $1, lines => [$2] };
      $lastfield = $cur->{fields}[-1];
      next;
    }
    if ($lastfield && $line =~ /^    (.*)$/) {
      push @{ $lastfield->{lines} }, $1;
      next;
    }
  }
  push @blocks, $cur if $cur;
  return @blocks;
}

sub fields_all {
  my ($block, $name) = @_;
  return grep { $_->{name} eq $name } @{ $block->{fields} };
}

sub field_first {
  my ($block, $name) = @_;
  for my $f (@{ $block->{fields} }) {
    return $f->{lines}[0] if $f->{name} eq $name;
  }
  return undef;
}

sub field_full {
  my ($block, $name) = @_;
  for my $f (@{ $block->{fields} }) {
    return join(' ', @{ $f->{lines} }) if $f->{name} eq $name;
  }
  return undef;
}

sub set_field {
  my ($block, $name, $value) = @_;
  for my $f (@{ $block->{fields} }) {
    if ($f->{name} eq $name) { $f->{lines} = [$value]; return; }
  }
  push @{ $block->{fields} }, { name => $name, lines => [$value] };
}

sub serialize_block {
  my ($block) = @_;
  my @out;
  push @out, "- **$block->{id}**";
  for my $f (@{ $block->{fields} }) {
    push @out, "  - $f->{name}: $f->{lines}[0]";
    for (my $i = 1; $i < scalar(@{ $f->{lines} }); $i++) {
      push @out, "    $f->{lines}[$i]";
    }
  }
  return join("\n", @out);
}

sub block_files { my ($b) = @_; return map { $_->{lines}[0] } fields_all($b, 'File'); }
sub block_lines_nums { my ($b) = @_; return map { $_->{lines}[0] } fields_all($b, 'Line'); }

sub block_quote {
  my ($block) = @_;
  my $ev = field_full($block, 'Evidence');
  return '' unless defined $ev;
  return $1 if $ev =~ /"([^"]*)"/;
  return '';
}

sub extract_section {
  my ($text, $heading) = @_;
  return undef unless defined $text;
  my @lines = split /\n/, $text, -1;
  my $n = scalar @lines;
  my $start;
  for (my $i = 0; $i < $n; $i++) {
    if ($lines[$i] =~ /^#{1,6}\s+\Q$heading\E\s*$/) { $start = $i + 1; last; }
  }
  return undef unless defined $start;
  my @out;
  for (my $i = $start; $i < $n; $i++) {
    last if $lines[$i] =~ /^#{1,6}\s+/;
    push @out, $lines[$i];
  }
  return join("\n", @out);
}

sub relativize {
  my ($path, $gitroot) = @_;
  return $path unless defined $gitroot && $gitroot ne 'none';
  if ($path =~ /^\// && index($path, "$gitroot/") == 0) {
    return substr($path, length($gitroot) + 1);
  }
  return $path;
}

sub normalize_files {
  my ($block, $gitroot) = @_;
  return unless defined $gitroot && $gitroot ne 'none';
  for my $f (fields_all($block, 'File')) {
    $f->{lines}[0] = relativize($f->{lines}[0], $gitroot);
  }
}

# --- tracking (CONTRACT E "Tracking") -----------------------------------------------------------

sub tracking_path {
  my ($gitroot) = @_;
  return basename($gitroot) eq '.claude' ? "$gitroot/review-tracking.md" : "$gitroot/.claude/review-tracking.md";
}

sub parse_tracking {
  my ($path) = @_;
  my %sections;
  my @order;
  my $text = read_file_text($path);
  return (\%sections, \@order) unless defined $text;
  my $cur;
  for my $line (split /\n/, $text) {
    if ($line =~ /^##\s+(.*?)\s*$/) {
      $cur = $1;
      unless (exists $sections{$cur}) { $sections{$cur} = []; push @order, $cur; }
      next;
    }
    next unless defined $cur;
    if ($line =~ /^- \[(intentional|deferred)\] "(.*)" - (.*) \(([^,()]+), (\d{4}-\d{2}-\d{2})\)\s*$/) {
      push @{ $sections{$cur} }, { status => $1, quote => $2, description => $3, category => $4, date => $5 };
    }
  }
  return (\%sections, \@order);
}

sub abs_from_relative {
  my ($rel, $gitroot) = @_;
  return $rel if $rel =~ /^\//;
  return "$gitroot/$rel";
}

# Returns (dropped, entry-quote-or-empty).
sub tracking_drop {
  my ($ctx, $block) = @_;
  my $gitroot = $ctx->{'git-root'} // 'none';
  return (0, '') if $gitroot eq 'none';
  my ($sections, undef) = parse_tracking(tracking_path($gitroot));

  my @files = block_files($block);
  return (0, '') unless @files;
  my @relfiles = do { my %s; grep { !$s{$_}++ } sort map { relativize($_, $gitroot) } @files };
  my $heading = (@relfiles == 1) ? $relfiles[0] : ('set: ' . join(', ', @relfiles));
  my $entries = $sections->{$heading} || [];
  my $category = field_first($block, 'Category') // '';
  my $fquote_c = collapse_ws(block_quote($block));

  for my $e (@$entries) {
    next unless $e->{category} eq $category;
    my @equotes = (@relfiles > 1) ? split(/ \/ /, $e->{quote}) : ($e->{quote});
    my $all_present = 1;
    for (my $i = 0; $i < scalar(@relfiles); $i++) {
      my $content = read_file_text(abs_from_relative($relfiles[$i], $gitroot));
      $content = '' unless defined $content;
      my $eq = $equotes[$i];
      $eq = '' unless defined $eq;
      $all_present = 0 unless index($content, $eq) >= 0;
    }
    next unless $all_present;
    my $eq_c = collapse_ws(join(' / ', @equotes));
    if (index($eq_c, $fquote_c) >= 0 || index($fquote_c, $eq_c) >= 0) {
      return (1, $e->{quote});
    }
  }
  return (0, '');
}

sub tracking_skipped {
  my ($ctx, $req) = @_;
  my $gitroot = $ctx->{'git-root'} // 'none';
  return 1 if $gitroot eq 'none';
  return 1 if (($req->{'fresh'} // 'no') eq 'yes');
  return 0;
}

# --- coverage ------------------------------------------------------------------------------------

sub cmd_coverage {
  my ($run, $final) = @_;

  my %docpath;
  my @docorder;
  for my $row (read_tsv_opt("$run/files.tsv")) {
    push @docorder, $row->[0];
    $docpath{$row->[0]} = $row->[1];
  }

  my %claims_count;
  my %heading_order;
  my %heading_seen;
  for my $d (@docorder) {
    for my $row (read_tsv_opt("$run/docs/$d/claims.tsv")) {
      my $heading = $row->[2];
      next unless defined $heading;
      $claims_count{$d}{$heading}++;
      unless ($heading_seen{$d}{$heading}) {
        $heading_seen{$d}{$heading} = 1;
        push @{ $heading_order{$d} ||= [] }, $heading;
      }
    }
  }

  my @outfiles = list_out_files($run, 'P');
  push @outfiles, list_out_files($run, 'R') if $final;

  my %rows;
  for my $of (@outfiles) {
    my $text = read_file_text("$run/out/$of");
    next unless defined $text;
    my $cov = extract_section($text, 'Coverage');
    next unless defined $cov;
    for my $line (split /\n/, $cov) {
      next unless $line =~ /^\|\s*(D\d+)\s*\|\s*(.*?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*$/;
      push @{ $rows{$1}{$2} }, [$3 + 0, $4 + 0];
    }
  }

  my @result;
  for my $d (@docorder) {
    next unless $heading_order{$d};
    for my $heading (@{ $heading_order{$d} }) {
      my $cc = $claims_count{$d}{$heading} // 0;
      my $rr = $rows{$d}{$heading} || [];
      my $pass = 0;
      for my $r (@$rr) {
        my ($found, $verified) = @$r;
        next if $verified < $found;
        next if $found < $cc;
        $pass = 1;
        last;
      }
      push @result, [$d, $heading] unless $pass;
    }
  }

  if ($final) {
    my $out = join('', map { "$_->[0]\t$_->[1]\n" } @result);
    write_file_text("$run/unverified.txt", $out);
    print 'unverified=' . scalar(@result) . "\n";
  } else {
    my $k = 0;
    my $out = join('', map { $k++; "R$k\t$_->[0]\t$_->[1]\n" } @result);
    write_file_text("$run/rerun.tsv", $out);
    print 'reruns=' . scalar(@result) . "\n";
  }
}

# --- prefilter -----------------------------------------------------------------------------------

sub cmd_prefilter {
  my ($run) = @_;
  my %ctx = parse_kv("$run/context.txt");
  my %req = parse_kv("$run/request.md");
  my $skip = tracking_skipped(\%ctx, \%req);

  my @collected;
  for my $f (list_out_files($run, 'P'), list_out_files($run, 'R')) {
    my $text = read_file_text("$run/out/$f");
    next unless defined $text;
    my $sec = extract_section($text, 'Findings');
    next unless defined $sec;
    next if collapse_ws($sec) eq 'No concern.';
    for my $b (parse_blocks($sec)) {
      normalize_files($b, $ctx{'git-root'});
      push @collected, $b;
    }
  }

  my %counter;
  for my $b (@collected) {
    my ($d) = $b->{id} =~ /^(D\d+)\./;
    $d = 'D0' unless defined $d;
    $counter{$d} = ($counter{$d} // 0) + 1;
    $b->{id} = "$d.$counter{$d}";
  }

  my @kept;
  my @tracked_rows;
  if ($skip) {
    @kept = @collected;
  } else {
    for my $b (@collected) {
      my ($dropped, $eq) = tracking_drop(\%ctx, $b);
      if ($dropped) {
        my @files = block_files($b);
        push @tracked_rows, "$b->{id}\t" . ($files[0] // '') . "\t$eq";
      } else {
        push @kept, $b;
      }
    }
  }

  my $out = join("\n\n", map { serialize_block($_) } @kept);
  $out .= "\n" if length($out);
  write_file_text("$run/proofread-findings.md", $out);

  my $trackedtext = join('', map { "$_\n" } @tracked_rows);
  write_file_text("$run/tracked.tsv", $trackedtext);

  print 'proofread-findings=' . scalar(@kept) . "\n";
  print 'tracked=' . scalar(@tracked_rows) . "\n";
}

# --- merge ---------------------------------------------------------------------------------------

sub cmd_merge {
  my ($run, $tier) = @_;
  my %ctx = parse_kv("$run/context.txt");
  my %req = parse_kv("$run/request.md");
  my $gitroot = $ctx{'git-root'} // 'none';
  my $skip = tracking_skipped(\%ctx, \%req);

  my @filerows = read_tsv_opt("$run/files.tsv");
  my @docorder = map { $_->[0] } @filerows;
  my %docpath = map { ($_->[0], $_->[1]) } @filerows;
  my %docrel;
  for my $d (@docorder) { $docrel{$d} = relativize($docpath{$d}, $gitroot); }

  my @findings;

  # 1. proofread findings, matched against every out/V*.md's Verification table.
  my @proofread_blocks = parse_blocks(read_file_text("$run/proofread-findings.md"));
  for my $b (@proofread_blocks) { normalize_files($b, $gitroot); }

  my %verif;
  for my $vf (list_out_files($run, 'V')) {
    my $text = read_file_text("$run/out/$vf");
    next unless defined $text;
    my $sec = extract_section($text, 'Verification');
    next unless defined $sec;
    for my $line (split /\n/, $sec) {
      next unless $line =~ /^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*$/;
      my ($id, $vstatus, $best) = ($1, $2, $3);
      next if $id eq 'Finding' || $id =~ /^-+$/;
      $verif{$id} = { status => $vstatus, best => $best };
    }
  }

  for my $b (@proofread_blocks) {
    my $v = $verif{$b->{id}};
    if ($v) {
      next if $v->{status} eq 'rejected';
      set_field($b, 'Status', $v->{status});
      set_field($b, 'Best case', $v->{best}) if $v->{best} ne '-';
    } else {
      set_field($b, 'Status', 'plausible');
    }
    push @findings, { block => $b, source => 'proofread', across => 0 };
  }

  # 2. script findings: kept only when the cited line still contains the quote.
  for my $b (parse_blocks(read_file_text("$run/script-findings.md"))) {
    normalize_files($b, $gitroot);
    my @bf = block_files($b);
    my @bl = block_lines_nums($b);
    next unless @bf && @bl;
    my $abspath = abs_from_relative($bf[0], $gitroot);
    my $lineno = $bl[0];
    my $text = read_file_text($abspath);
    next unless defined $text;
    my @lines = split /\n/, $text, -1;
    next unless $lineno =~ /^\d+$/ && $lineno >= 1 && $lineno <= scalar(@lines);
    my $quote = block_quote($b);
    next unless index($lines[$lineno - 1], $quote) >= 0;
    push @findings, { block => $b, source => 'script', across => 0 };
  }

  # 3. judgment findings (area outputs and verify-output Propagation blocks), plus the "judgment"
  #    field's own failed(...)/dispatched(...)/split-into-N-groups(...) computation.
  my %gset;
  for my $row (read_tsv_opt("$run/groups.tsv")) { $gset{$row->[0]} = 1 if defined $row->[0] && $row->[0] ne ''; }
  my @gids = numsort(keys %gset);

  my @missing;
  for my $g (@gids) {
    my $atext = read_file_text("$run/out/$g.md");
    if (!defined $atext || index($atext, '### Purpose measured against') < 0) {
      push @missing, $g;
    } else {
      my $across_sec = extract_section($atext, 'Across the set');
      my %across_ids;
      if (defined $across_sec) {
        $across_ids{$_->{id}} = 1 for parse_blocks($across_sec);
      }
      for my $b (parse_blocks($atext)) {
        next unless $b->{id} =~ /^J/;
        normalize_files($b, $gitroot);
        my $rb = field_first($b, 'Raised by');
        set_field($b, 'Raised by', 'judgment') unless defined $rb && $rb eq 'both passes';
        push @findings, { block => $b, source => 'judgment', across => ($across_ids{$b->{id}} ? 1 : 0) };
      }
    }

    my $vid = $g;
    $vid =~ s/^A/V/;
    my $vtext = read_file_text("$run/out/$vid.md");
    if (!defined $vtext || index($vtext, '### Verification') < 0) {
      push @missing, $vid;
    } else {
      my $prop = extract_section($vtext, 'Propagation');
      if (defined $prop) {
        for my $b (parse_blocks($prop)) {
          next unless $b->{id} =~ /^V/;
          normalize_files($b, $gitroot);
          my $rb = field_first($b, 'Raised by');
          set_field($b, 'Raised by', 'judgment') unless defined $rb && $rb eq 'both passes';
          push @findings, { block => $b, source => 'judgment', across => 0 };
        }
      }
    }
  }

  my $judgment;
  if (@missing) {
    $judgment = 'failed (' . join(', ', map { "$_ missing" } @missing) . ')';
  } elsif (scalar(@gids) > 1) {
    $judgment = 'split into ' . scalar(@gids) . " groups($tier)";
  } else {
    $judgment = "dispatched($tier)";
  }

  # 4. tracking filter on every finding, appended to the prefilter-written tracked.tsv.
  if (!$skip) {
    my @kept;
    my @new_rows;
    for my $f (@findings) {
      my ($dropped, $eq) = tracking_drop(\%ctx, $f->{block});
      if ($dropped) {
        my @bf = block_files($f->{block});
        push @new_rows, "$f->{block}{id}\t" . ($bf[0] // '') . "\t$eq";
      } else {
        push @kept, $f;
      }
    }
    @findings = @kept;
    append_file_text("$run/tracked.tsv", join('', map { "$_\n" } @new_rows)) if @new_rows;
  }

  # 5. duplicates: same first File, first Line, Category -> one, keeping the higher severity and,
  #    on a tie, script then proofread then judgment.
  my %sevrank = (Blocker => 3, Major => 2, Minor => 1);
  my %srcrank = (script => 0, proofread => 1, judgment => 2);
  my %groups;
  for (my $i = 0; $i < scalar(@findings); $i++) {
    my $b = $findings[$i]{block};
    my @bf = block_files($b);
    my @bl = block_lines_nums($b);
    my $cat = field_first($b, 'Category') // '';
    my $key = ($bf[0] // '') . "\x1e" . ($bl[0] // '') . "\x1e" . $cat;
    push @{ $groups{$key} }, $i;
  }
  my %drop_idx;
  for my $key (keys %groups) {
    my @idxs = @{ $groups{$key} };
    next if scalar(@idxs) < 2;
    my @sorted = sort {
      my $sb = $sevrank{ field_first($findings[$b]{block}, 'Severity') // '' } // 0;
      my $sa = $sevrank{ field_first($findings[$a]{block}, 'Severity') // '' } // 0;
      $sb <=> $sa || $srcrank{ $findings[$a]{source} } <=> $srcrank{ $findings[$b]{source} }
    } @idxs;
    my $keep = $sorted[0];
    my ($pf_idx) = grep { $findings[$_]{source} eq 'proofread' } @idxs;
    my ($jf_idx) = grep { $findings[$_]{source} eq 'judgment' } @idxs;
    if (defined $pf_idx && defined $jf_idx) {
      my $ev1 = field_full($findings[$pf_idx]{block}, 'Evidence') // '';
      my $ev2 = field_full($findings[$jf_idx]{block}, 'Evidence') // '';
      set_field($findings[$keep]{block}, 'Raised by', 'both passes') if $ev1 ne $ev2;
    }
    for my $i (@idxs) { $drop_idx{$i} = 1 unless $i == $keep; }
  }
  my @deduped;
  for (my $i = 0; $i < scalar(@findings); $i++) {
    push @deduped, $findings[$i] unless $drop_idx{$i};
  }
  @findings = @deduped;

  # 6. placement: across-the-set when more than one document and the finding came from an
  #    "### Across the set" block or its File lists more than one distinct file.
  my $multidoc = (scalar(@docorder) > 1) ? 1 : 0;
  for my $f (@findings) {
    my @bf = block_files($f->{block});
    my %u;
    $u{$_} = 1 for @bf;
    my $multifile = (scalar(keys %u) > 1) ? 1 : 0;
    $f->{is_across} = ($multidoc && ($f->{across} || $multifile)) ? 1 : 0;
  }

  # 7. order and renumber.
  my %docfile_rank;
  for (my $i = 0; $i < scalar(@docorder); $i++) {
    my $rel = $docrel{ $docorder[$i] };
    $docfile_rank{$rel} = $i unless exists $docfile_rank{$rel};
  }
  my $sevof = sub {
    my $s = field_first($_[0]{block}, 'Severity') // '';
    return $sevrank{$s} // 0;
  };
  my $lineof = sub {
    my @bl = block_lines_nums($_[0]{block});
    my $l = $bl[0] // 0;
    $l = $1 if $l =~ /(\d+)/;
    return $l + 0;
  };

  my @per_doc = grep { !$_->{is_across} } @findings;
  my @across = grep { $_->{is_across} } @findings;

  @per_doc = sort {
    my $fa = (block_files($a->{block}))[0] // '';
    my $fb = (block_files($b->{block}))[0] // '';
    my $ra = exists $docfile_rank{$fa} ? $docfile_rank{$fa} : 999999;
    my $rb = exists $docfile_rank{$fb} ? $docfile_rank{$fb} : 999999;
    $ra <=> $rb || $sevof->($b) <=> $sevof->($a) || $lineof->($a) <=> $lineof->($b)
  } @per_doc;

  @across = sort {
    $sevof->($b) <=> $sevof->($a) || $lineof->($a) <=> $lineof->($b)
  } @across;

  @findings = (@per_doc, @across);
  my $fn = 0;
  for my $f (@findings) {
    $fn++;
    $f->{block}{id} = "F$fn";
  }

  # 9. proofread units whose output is missing or lacks "### Findings" leave their documents
  #    unreviewed, named under Not checked.
  my @unitrows = read_tsv_opt("$run/units.tsv");
  my %p2docs;
  my @punits_order;
  my %punits_seen;
  for my $r (@unitrows) {
    my ($pk, $dj) = ($r->[0], $r->[1]);
    push @{ $p2docs{$pk} ||= [] }, $dj;
    unless ($punits_seen{$pk}) { $punits_seen{$pk} = 1; push @punits_order, $pk; }
  }
  my @unreviewed_docs;
  for my $pk (@punits_order) {
    my $ptext = read_file_text("$run/out/$pk.md");
    if (!defined $ptext || index($ptext, '### Findings') < 0) {
      push @unreviewed_docs, @{ $p2docs{$pk} };
    }
  }

  my %distinct_docs_units;
  $distinct_docs_units{ $_->[1] } = 1 for @unitrows;
  my $proofread_n = scalar(keys %distinct_docs_units);

  # findings.json
  my @json_findings;
  for my $f (@findings) {
    my $b = $f->{block};
    my @bf = block_files($b);
    my @bl = map { /(\d+)/ ? ($1 + 0) : 0 } block_lines_nums($b);
    push @json_findings, {
      id        => $b->{id},
      files     => [@bf],
      lines     => [@bl],
      severity  => field_first($b, 'Severity') // '',
      category  => field_first($b, 'Category') // '',
      quote     => block_quote($b),
      raised_by => field_first($b, 'Raised by') // $f->{source},
      status    => field_first($b, 'Status') // 'plausible',
      across    => ($f->{is_across} ? JSON::PP::true : JSON::PP::false),
    };
  }
  write_file_text("$run/findings.json", encode_json({ findings => \@json_findings }) . "\n");

  # declaration line
  my $decl = sprintf(
    'Run: proofread=%d docs; judgment=%s; tools=%s; ascii-rule=%s; references-rule=%s; profile=%s; fresh=%s; skipped=%s',
    $proofread_n, $judgment, ($ctx{'tools'} // ''), ($ctx{'ascii-rule'} // ''),
    ($ctx{'references-rule'} // ''), ($ctx{'profile'} // ''), ($req{'fresh'} // 'no'),
    ($req{'skipped'} // 'none')
  );

  my $decl_re = qr/^Run: proofread=\d+ docs; judgment=(?:dispatched\((?:sonnet|opus)\)|split into \d+ groups\((?:sonnet|opus)\)|failed \([^()]+\)); tools=md-checks=(?:ran|error\(\d+\)), links=(?:ran|error\(\d+\)), claims=(?:ran|error\(\d+\)), scrub-check=(?:ran|absent|error\(\d+\)), markdownlint=(?:ran|error\(\d+\)|not installed \(see references\/markdownlint-setup\.md\)), vale=(?:ran|error\(\d+\)|not installed \(see references\/vale-setup\.md\)); ascii-rule=(?:adopted|not adopted) \([^()]+\); references-rule=(?:adopted|not adopted); profile=(?:agent-config|none); fresh=(?:yes|no); skipped=(?:none|[^;]+)$/;
  unless ($decl =~ $decl_re) {
    die_internal("declaration line does not match CONTRACT R: $decl");
  }

  # report-draft.md
  my $report = "$decl\n\n";
  $report .= "### Summary\n\n";

  my $blockers = scalar(grep { (field_first($_->{block}, 'Severity') // '') eq 'Blocker' } @findings);
  my $majors   = scalar(grep { (field_first($_->{block}, 'Severity') // '') eq 'Major' } @findings);
  my $minors   = scalar(grep { (field_first($_->{block}, 'Severity') // '') eq 'Minor' } @findings);
  $report .= "- Findings: $blockers Blocker, $majors Major, $minors Minor.\n";

  my (@broken, @inconclusive, @skipped_links);
  for my $d (@docorder) {
    for my $row (read_tsv_opt("$run/docs/$d/links.tsv")) {
      my ($fp, $ln, $url, $res) = @$row;
      next unless defined $res;
      my $rel = relativize($fp, $gitroot);
      if ($res eq 'broken') { push @broken, "$rel:$ln $url"; }
      elsif ($res eq 'inconclusive') { push @inconclusive, "$rel:$ln $url"; }
      elsif ($res =~ /^skipped:(.+)$/) { push @skipped_links, "- $rel:$ln $url: link not checked ($1).\n"; }
    }
  }
  $report .= '- Broken links: ' . (@broken ? join(', ', @broken) : 'none') . ".\n";
  $report .= '- Inconclusive links: ' . (@inconclusive ? join(', ', @inconclusive) : 'none') . ".\n";

  my @tr_rows = read_tsv_opt("$run/tracked.tsv");
  if ($gitroot eq 'none') {
    $report .= "- Decisions were not recorded: the target is not inside a git repository.\n";
  } else {
    $report .= '- Tracking skipped: ' . scalar(@tr_rows);
    $report .= ': ' . join(', ', map { "$_->[1]: $_->[2]" } @tr_rows) if @tr_rows;
    $report .= ".\n";

    my ($sections, $order) = parse_tracking(tracking_path($gitroot));
    my %relevant = map { ($_, 1) } values %docrel;
    my @deferred;
    my @stale;
    for my $h (@$order) {
      if ($h =~ /^set: (.*)$/) {
        my @setfiles = split(/, /, $1);
        next unless grep { $relevant{$_} } @setfiles;
      } else {
        next unless $relevant{$h};
      }
      for my $e (@{ $sections->{$h} }) {
        push @deferred, $e if $e->{status} eq 'deferred';
        unless ($h =~ /^set: /) {
          my $content = read_file_text(abs_from_relative($h, $gitroot));
          $content = '' unless defined $content;
          push @stale, $e->{quote} unless index($content, $e->{quote}) >= 0;
        }
      }
    }
    $report .= '- Deferred entries in scope: ' . scalar(@deferred) . "\n";
    for my $e (grep { days_old($_->{date}) > 30 } @deferred) {
      $report .= "  - \"$e->{quote}\" ($e->{date})\n";
    }
    $report .= '- Stale tracking entries: ' . (@stale ? join(', ', @stale) : 'none') . ".\n";
  }

  $report .= '- Pass: ' . ((($req{'fresh'} // 'no') eq 'yes') ? 'full (fresh)' : 'standard') . ".\n";

  $report .= "- Purpose:\n";
  for my $g (@gids) {
    my $psec = extract_section(read_file_text("$run/out/$g.md"), 'Purpose measured against');
    next unless defined $psec;
    for my $line (split /\n/, $psec) {
      next if $line =~ /^\s*$/;
      $report .= "  - $line\n";
    }
  }

  $report .= "\n### Per-document findings\n\n";
  for my $d (@docorder) {
    my $rel = $docrel{$d};
    $report .= "#### $rel\n\n";
    my @dfind = grep { !$_->{is_across} && ((block_files($_->{block}))[0] // '') eq $rel } @findings;
    if (!@dfind) {
      $report .= "No findings.\n\n";
      next;
    }
    for my $sev (qw(Blocker Major Minor)) {
      my @s = grep { (field_first($_->{block}, 'Severity') // '') eq $sev } @dfind;
      next unless @s;
      $report .= "##### $sev\n\n";
      $report .= serialize_block($_->{block}) . "\n\n" for @s;
    }
  }

  my %relset = map { ($_, 1) } values %docrel;
  my @orphan_order;
  my %orphan_seen;
  for my $f (@findings) {
    next if $f->{is_across};
    my $fp = (block_files($f->{block}))[0] // '';
    next if $relset{$fp};
    unless ($orphan_seen{$fp}) { $orphan_seen{$fp} = 1; push @orphan_order, $fp; }
  }
  for my $fp (@orphan_order) {
    $report .= "#### $fp\n\n";
    my @ofind = grep { !$_->{is_across} && ((block_files($_->{block}))[0] // '') eq $fp } @findings;
    for my $sev (qw(Blocker Major Minor)) {
      my @s = grep { (field_first($_->{block}, 'Severity') // '') eq $sev } @ofind;
      next unless @s;
      $report .= "##### $sev\n\n";
      $report .= serialize_block($_->{block}) . "\n\n" for @s;
    }
  }

  if ($multidoc) {
    $report .= "### Across the set\n\n";
    if (!@across) {
      $report .= "No relation found.\n\n";
    } else {
      for my $sev (qw(Blocker Major Minor)) {
        my @s = grep { (field_first($_->{block}, 'Severity') // '') eq $sev } @across;
        next unless @s;
        $report .= "#### $sev\n\n";
        $report .= serialize_block($_->{block}) . "\n\n" for @s;
      }
    }
  }

  $report .= "### Applied changes\n\nNone.\n\n";

  $report .= "### Not checked\n\n";
  my $skipped_docs = $req{'skipped'} // 'none';
  if ($skipped_docs ne 'none' && $skipped_docs ne '') {
    $report .= "- $_: not Markdown, not reviewed.\n" for split(/,\s*/, $skipped_docs);
  }
  $report .= "- $_->[1]: $_->[2]: skipped by tracking.\n" for @tr_rows;
  $report .= $_ for @skipped_links;
  for my $part (split(/,\s*/, $ctx{'tools'} // '')) {
    $report .= "- $part.\n" if $part =~ /not installed/;
  }
  for my $row (read_tsv_opt("$run/unverified.txt")) {
    $report .= "- $row->[0] $row->[1]: claims in this section were not all verified.\n";
  }
  $report .= "- $_: not checked (proofread pass failed).\n" for @unreviewed_docs;
  $report .= "- Relations across judgment groups were not checked.\n" if scalar(@gids) > 1;
  $report .= "- Always: Code-block correctness and worth questions are never reviewed here; worth questions belong to deep-review.\n";

  write_file_text("$run/report-draft.md", $report);

  print 'findings=' . scalar(@findings) . "\n";
  print "decl=$decl\n";
}

# --- record ----------------------------------------------------------------------------------

sub cmd_record {
  my ($run, $fid, $status, $description) = @_;
  my $json = read_file_text("$run/findings.json");
  die_internal("missing $run/findings.json") unless defined $json;
  my $data = eval { decode_json($json) } or die_internal("findings.json is not valid JSON");
  my ($finding) = grep { $_->{id} eq $fid } @{ $data->{findings} };
  die_internal("unknown finding id $fid") unless $finding;

  my %ctx = parse_kv("$run/context.txt");
  my $gitroot = $ctx{'git-root'} // 'none';
  if ($gitroot eq 'none') {
    print "not recorded: outside git\n";
    exit 0;
  }

  my $tpath = tracking_path($gitroot);

  my @files = do { my %s; grep { !$s{$_}++ } sort @{ $finding->{files} } };
  my $heading = (scalar(@files) == 1) ? $files[0] : ('set: ' . join(', ', @files));
  my $quote = $finding->{quote};
  my $category = $finding->{category};
  my $date = today_str();
  my $qc = collapse_ws($quote);
  my $entry_line = "- [$status] \"$quote\" - $description ($category, $date)";

  make_path(dirname($tpath)) unless -d dirname($tpath);

  my $text = read_file_text($tpath);
  unless (defined $text) {
    write_file_text($tpath, "## $heading\n$entry_line\n");
    print "recorded $tpath\n";
    return;
  }

  my @lines = split /\n/, $text, -1;
  pop @lines if @lines && $lines[-1] eq '';

  my $heading_idx;
  for (my $i = 0; $i < scalar(@lines); $i++) {
    if ($lines[$i] =~ /^##\s+(.*?)\s*$/ && $1 eq $heading) { $heading_idx = $i; last; }
  }

  unless (defined $heading_idx) {
    write_file_text($tpath, ($text =~ /\S/ ? $text . "\n" : "") . "## $heading\n$entry_line\n");
    print "recorded $tpath\n";
    return;
  }

  my $section_end = scalar(@lines);
  for (my $i = $heading_idx + 1; $i < scalar(@lines); $i++) {
    if ($lines[$i] =~ /^##\s+/) { $section_end = $i; last; }
  }

  my $replace_idx;
  my $last_entry_idx;
  for (my $i = $heading_idx + 1; $i < $section_end; $i++) {
    next unless $lines[$i] =~ /^- \[(?:intentional|deferred)\] "(.*)" - .* \(([^,()]+), \d{4}-\d{2}-\d{2}\)\s*$/;
    $last_entry_idx = $i;
    if (collapse_ws($1) eq $qc && $2 eq $category) { $replace_idx = $i; last; }
  }

  if (defined $replace_idx) {
    $lines[$replace_idx] = $entry_line;
  } else {
    my $insert_at = defined $last_entry_idx ? $last_entry_idx + 1 : $heading_idx + 1;
    splice(@lines, $insert_at, 0, $entry_line);
  }

  write_file_text($tpath, join("\n", @lines) . "\n");
  print "recorded $tpath\n";
}

# --- dispatch ------------------------------------------------------------------------------------

my $mode = shift @ARGV;
if ($mode eq 'coverage') {
  cmd_coverage($ARGV[0], $ARGV[1] eq '1');
} elsif ($mode eq 'prefilter') {
  cmd_prefilter($ARGV[0]);
} elsif ($mode eq 'merge') {
  cmd_merge($ARGV[0], $ARGV[1]);
} elsif ($mode eq 'record') {
  cmd_record($ARGV[0], $ARGV[1], $ARGV[2], $ARGV[3]);
} else {
  die_internal("unknown mode $mode");
}
exit 0;
PERL

case "$cmd" in
  coverage)  perl -e "$MERGE_PERL" -- coverage "$run" "$final" ;;
  prefilter) perl -e "$MERGE_PERL" -- prefilter "$run" ;;
  merge)     perl -e "$MERGE_PERL" -- merge "$run" "$tier" ;;
  record)    perl -e "$MERGE_PERL" -- record "$run" "$fid" "$status" "$description" ;;
esac
rc=$?
if [[ "$rc" != 0 && "$rc" != 1 && "$rc" != 2 ]]; then
  echo "$prog: internal failure (perl exit $rc)" >&2
  exit 1
fi
exit "$rc"
