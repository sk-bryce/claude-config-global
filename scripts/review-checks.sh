#!/usr/bin/env bash
#
# review-checks.sh - runs review-md's six mechanical checks (md-checks, link-recheck-hook,
# md-claims, scrub-check, markdownlint, vale) in one batched step and turns their raw output into
# the run directory's fixed files, so the (potentially large) tool output never has to enter a
# model's context directly. Implements the "init" and "run" subcommands of Contract A, and all of
# Contract D, from specs/skills.md's review-md section.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit.
#
# Usage:
#   review-checks.sh init --skill <skill-dir> <file> [<file> ...]
#     Creates a new run directory (mktemp -d "${TMPDIR:-/tmp}/review-md.XXXXXX"), writes
#     files.tsv and skill.txt, and prints exactly four lines:
#       run-dir=<absolute run directory>
#       files=<number of files>
#       chars=<total characters>
#       over-cap=<yes|no>
#
#   review-checks.sh run <run-dir> --ascii <adopted|not-adopted> --ascii-reason <text> \
#       --references <adopted|not-adopted>
#     Runs the six tools concurrently against the files named in <run-dir>/files.tsv, writes
#     tools/, docs/, context.txt, exclusions.txt, and script-findings.md under <run-dir>, and
#     prints exactly three lines:
#       tools=<the tools field value>
#       profile=<agent-config|none>
#       script-findings=<count>
#
# Exit codes: 0 success; 2 usage error; 1 internal failure. On exit 1 or 2 this prints one stderr
# line starting "review-checks.sh: ". Stdout carries only the lines documented above.
#
# This script never edits a reviewed file, and never runs anything taken from a document: every
# command line above is built only from this script's own arguments and the paths in files.tsv.
#
# Bash 3.2 compatible: only plain indexed arrays and standard parameter expansion are used, no
# namerefs. All non-trivial text processing (parsing tool output, extracting spec sections,
# detecting agent-config documents, and building script-findings.md) is embedded perl using core
# modules only.

set -uo pipefail

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

usage_line="usage: review-checks.sh init --skill <skill-dir> <file> [<file> ...] | review-checks.sh run <run-dir> --ascii <adopted|not-adopted> --ascii-reason <text> --references <adopted|not-adopted>"

# --- Shared: count the Unicode characters of a file, decoded as UTF-8. Prints 0 on any error. ----
count_chars() {
  perl -Mutf8 -e '
    open(my $fh, "<:encoding(UTF-8)", $ARGV[0]) or do { print 0; exit };
    local $/;
    my $c = <$fh>;
    $c = "" unless defined $c;
    print length($c);
  ' "$1" 2>/dev/null
}

# --- init ------------------------------------------------------------------------------------------
cmd_init() {
  local skill_dir="" files=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skill)
        if [[ $# -lt 2 ]]; then
          echo "review-checks.sh: --skill requires a value" >&2
          exit 2
        fi
        skill_dir="$2"; shift 2 ;;
      --*)
        echo "review-checks.sh: unknown option: $1" >&2
        exit 2 ;;
      *)
        files+=("$1"); shift ;;
    esac
  done

  if [[ -z "$skill_dir" || ${#files[@]} -eq 0 ]]; then
    echo "review-checks.sh: $usage_line" >&2
    exit 2
  fi

  local run_dir
  run_dir="$(mktemp -d "${TMPDIR:-/tmp}/review-md.XXXXXX")" || {
    echo "review-checks.sh: could not create run directory" >&2
    exit 1
  }

  local skill_abs
  skill_abs="$(cd "$skill_dir" 2>/dev/null && pwd)"
  [[ -n "$skill_abs" ]] || skill_abs="$skill_dir"
  printf '%s\n' "$skill_abs" > "$run_dir/skill.txt"

  : > "$run_dir/files.tsv"
  local total_chars=0 k=0 f d abs chars
  for f in "${files[@]}"; do
    k=$((k + 1))
    if [[ -e "$f" ]]; then
      d="$(dirname "$f")"
      abs="$(cd "$d" 2>/dev/null && pwd)/$(basename "$f")"
    else
      abs="$f"
    fi
    chars="$(count_chars "$abs")"
    [[ -n "$chars" ]] || chars=0
    total_chars=$((total_chars + chars))
    printf 'D%s\t%s\t%s\n' "$k" "$abs" "$chars" >> "$run_dir/files.tsv"
  done

  local n_files=${#files[@]}
  local over_cap="no"
  if [[ $n_files -gt 25 || $total_chars -gt 250000 ]]; then
    over_cap="yes"
  fi

  printf 'run-dir=%s\n' "$run_dir"
  printf 'files=%s\n' "$n_files"
  printf 'chars=%s\n' "$total_chars"
  printf 'over-cap=%s\n' "$over_cap"
}

# --- run: embedded perl postprocessor (docs/, script-findings.md; prints PROFILE/AGENTCONFIG/
# FINDINGS lines read back by the bash side below). ------------------------------------------------
read -r -d '' POSTPROCESS <<'PERL'
use strict;
use warnings;
use utf8;
use File::Basename qw(basename dirname);

binmode(STDOUT, ':encoding(UTF-8)');

my ($run_dir, $git_root, $mc_ran, $lk_ran, $cl_ran, $sc_ran, $mdl_ran, $vl_ran, $ran_csv) = @ARGV;
$git_root = '' unless defined $git_root;

sub read_lines {
  my ($path) = @_;
  open(my $fh, '<:encoding(UTF-8)', $path) or return ();
  my @lines = <$fh>;
  close $fh;
  chomp @lines;
  return @lines;
}

sub trim { my ($s) = @_; $s = '' unless defined $s; $s =~ s/^\s+|\s+$//g; return $s; }

sub rel_to_git_root {
  my ($abs) = @_;
  if ($git_root ne '' && index($abs, "$git_root/") == 0) {
    return substr($abs, length($git_root) + 1);
  }
  return $abs;
}

# --- files.tsv --------------------------------------------------------------------------------
my @files;        # { id, path, chars }
my %index_of;     # path -> order index
{
  my @rows = read_lines("$run_dir/files.tsv");
  my $i = 0;
  foreach my $row (@rows) {
    my ($id, $path, $chars) = split(/\t/, $row, 3);
    next unless defined $path;
    push @files, { id => $id, path => $path, chars => $chars };
    $index_of{$path} = $i++;
  }
}

mkdir "$run_dir/docs" unless -d "$run_dir/docs";
foreach my $f (@files) {
  mkdir "$run_dir/docs/$f->{id}" unless -d "$run_dir/docs/$f->{id}";
}

# --- agent-config detection -------------------------------------------------------------------
my @agent_ids;
foreach my $f (@files) {
  my $base = basename($f->{path});
  my $is_cfg = 0;
  if ($base eq 'CLAUDE.md' || $base eq 'AGENTS.md' || $base eq 'SKILL.md') {
    $is_cfg = 1;
  } else {
    my $dir = dirname($f->{path});
    if (basename($dir) eq 'agents') {
      my @l = read_lines($f->{path});
      $is_cfg = 1 if (@l && $l[0] eq '---');
    }
  }
  push @agent_ids, $f->{id} if $is_cfg;
}
my $profile = @agent_ids ? 'agent-config' : 'none';
my $agent_config_field = @agent_ids ? join(',', @agent_ids) : 'none';

# --- shared md-checks / scrub-check output parser ---------------------------------------------
# Format: a file header line (no leading spaces, ignored - every finding row already carries its
# own path), then per category "  == <category> ==" followed by "  <path>:<line> - <description>"
# rows.
sub parse_block_style {
  my ($text, $abs_paths) = @_;
  my @out;
  my $cur_cat;
  foreach my $line (split(/\n/, $text)) {
    next if $line eq '';
    if ($line =~ /^  == (.+) ==$/) { $cur_cat = $1; next; }
    if ($line =~ /^  (.+):(\d+) - (.*)$/) {
      my ($path, $ln, $desc) = ($1, $2, $3);
      my $abs = $abs_paths ? $path : ($git_root ne '' ? "$git_root/$path" : $path);
      push @out, { file => $abs, line => $ln, category => $cur_cat, desc => $desc };
    }
  }
  return @out;
}

my @mc_findings;
@mc_findings = parse_block_style(join("\n", read_lines("$run_dir/tools/md-checks.out")), 1)
  if $mc_ran eq '1';

my @sc_findings;
@sc_findings = parse_block_style(join("\n", read_lines("$run_dir/tools/scrub-check.out")), 0)
  if $sc_ran eq '1';

# --- links.out ----------------------------------------------------------------------------------
my @link_rows;
if ($lk_ran eq '1') {
  foreach my $row (read_lines("$run_dir/tools/links.out")) {
    my ($path, $line, $url, $result) = split(/\t/, $row, 4);
    next unless defined $result;
    push @link_rows, { file => $path, line => $line, url => $url, result => $result };
  }
}

foreach my $f (@files) {
  my @rows = grep { $_->{file} eq $f->{path} } @link_rows;
  open(my $fh, '>:encoding(UTF-8)', "$run_dir/docs/$f->{id}/links.tsv") or die "$!";
  foreach my $r (@rows) {
    print $fh "$r->{file}\t$r->{line}\t$r->{url}\t$r->{result}\n";
  }
  close $fh;
}

# --- claims.out ---------------------------------------------------------------------------------
my @claims_rows;
if ($cl_ran eq '1') {
  foreach my $row (read_lines("$run_dir/tools/claims.out")) {
    my ($path, $line, $heading, $kind, $claim, $result) = split(/\t/, $row, 6);
    next unless defined $result;
    push @claims_rows, {
      file => $path, line => $line, heading => $heading, kind => $kind,
      claim => $claim, result => $result, raw => $row,
    };
  }
}

my %claims_tsv_kinds = map { $_ => 1 } qw(path command flag identifier heading-ref dated);
my %claims_tsv_results = map { $_ => 1 } qw(not-found-by-script candidate);

my @ran_tools = $ran_csv ne '' ? split(/,/, $ran_csv) : ();
my $ran_tools_line = 'Tools that ran: ' . (@ran_tools ? join(', ', @ran_tools) : 'none');

foreach my $f (@files) {
  my @rows = grep { $_->{file} eq $f->{path} } @claims_rows;

  open(my $fh1, '>:encoding(UTF-8)', "$run_dir/docs/$f->{id}/claims.tsv") or die "$!";
  foreach my $r (@rows) {
    next unless $claims_tsv_kinds{$r->{kind}} && $claims_tsv_results{$r->{result}};
    print $fh1 "$r->{raw}\n";
  }
  close $fh1;

  open(my $fh2, '>:encoding(UTF-8)', "$run_dir/docs/$f->{id}/signals.txt") or die "$!";
  foreach my $r (@rows) {
    next unless $r->{kind} eq 'drift';
    print $fh2 "$r->{raw}\n";
  }
  print $fh2 "$ran_tools_line\n";
  close $fh2;
}

my @freshness_findings = grep { $_->{kind} eq 'freshness' && $_->{result} eq 'stale-header' } @claims_rows;

# --- spec.md -------------------------------------------------------------------------------------
foreach my $f (@files) {
  my @lines = read_lines($f->{path});
  my $max = @lines < 30 ? scalar(@lines) : 30;
  my ($spec_path_raw, $section_raw);
  for (my $i = 0; $i < $max; $i++) {
    if ($lines[$i] =~ /^\s*spec:\s*(\S+)(?:\s*\(([^)]*)\))?/) {
      $spec_path_raw = $1;
      $section_raw = $2;
      last;
    }
  }

  open(my $fh, '>:encoding(UTF-8)', "$run_dir/docs/$f->{id}/spec.md") or die "$!";
  if (!defined $spec_path_raw) {
    print $fh "none\n";
    close $fh;
    next;
  }

  my $section_name = defined($section_raw) ? $section_raw : '';
  $section_name =~ s/\s*section$//i;
  print $fh "Spec: $spec_path_raw ($section_name)\n";

  my $spec_abs;
  if ($spec_path_raw =~ m{^/}) {
    $spec_abs = $spec_path_raw;
  } elsif ($git_root ne '') {
    $spec_abs = "$git_root/$spec_path_raw";
  }

  my $extracted;
  if (defined $spec_abs && -f $spec_abs) {
    my @slines = read_lines($spec_abs);
    my $n = scalar(@slines);
    my @is_fenced = (0) x ($n + 1);
    my $in_fence = 0; my $fchar = ''; my $flen = 0;
    for (my $i = 1; $i <= $n; $i++) {
      my $line = $slines[$i - 1];
      if ($in_fence) {
        $is_fenced[$i] = 1;
        if ($line =~ /^ {0,3}\Q$fchar\E{$flen,}[ \t]*$/) { $in_fence = 0; }
        next;
      }
      if ($line =~ /^ {0,3}(`{3,}|~{3,})/) {
        $is_fenced[$i] = 1; $in_fence = 1; $fchar = substr($1, 0, 1); $flen = length($1);
      }
    }

    my @headings;
    for (my $i = 1; $i <= $n; $i++) {
      next if $is_fenced[$i];
      my $line = $slines[$i - 1];
      if ($line =~ /^(#{1,6})(?:[ \t](.*)|)$/) {
        my $level = length($1);
        my $text = defined($2) ? $2 : '';
        $text =~ s/^\s+|\s+$//g;
        $text =~ s/\s*#+$//;
        push @headings, { line => $i, level => $level, text => $text };
      }
    }

    my $match_idx = -1;
    for (my $i = 0; $i < scalar(@headings); $i++) {
      if (lc($headings[$i]{text}) eq lc($section_name)) { $match_idx = $i; last; }
    }

    if ($match_idx >= 0) {
      my $start = $headings[$match_idx]{line} + 1;
      my $level = $headings[$match_idx]{level};
      my $end = $n;
      for (my $i = $match_idx + 1; $i < scalar(@headings); $i++) {
        if ($headings[$i]{level} <= $level) { $end = $headings[$i]{line} - 1; last; }
      }
      my @body;
      for (my $i = $start; $i <= $end; $i++) { push @body, $slines[$i - 1]; }
      while (@body && $body[0] eq '') { shift @body; }
      while (@body && $body[-1] eq '') { pop @body; }
      $extracted = join("\n", @body);
    }
  }

  if (defined $extracted) {
    print $fh "$extracted\n";
  } else {
    print $fh "Section text not extracted; read the named section yourself.\n";
  }
  close $fh;
}

# --- markdownlint / vale output parsing -----------------------------------------------------------
my @mdl_findings;
if ($mdl_ran eq '1') {
  my @lines = (read_lines("$run_dir/tools/markdownlint.out"), read_lines("$run_dir/tools/markdownlint.err"));
  foreach my $line (@lines) {
    next if $line eq '';
    if ($line =~ /^(.+?):(\d+)(?::\d+)?\s+(MD\d+)\/(\S+)\s+(.*)$/) {
      push @mdl_findings, { file => $1, line => $2, rule => $3, alias => $4, desc => $5 };
    }
  }
}

my @vale_findings;
if ($vl_ran eq '1') {
  foreach my $line (read_lines("$run_dir/tools/vale.out")) {
    next if $line eq '';
    if ($line =~ /^([^:]+):(\d+):(\d+):([^:]+):(.*)$/) {
      push @vale_findings, { file => $1, line => $2, check => $4, msg => $5 };
    }
  }
}

my %equiv_rule_to_cat = (
  MD001 => 'headings',
  MD051 => 'anchors',
  MD040 => 'fence-language',
  MD045 => 'alt-text',
  MD025 => 'h1',
  MD041 => 'h1',
  MD024 => 'sibling-headings',
);
my %mc_present;
foreach my $m (@mc_findings) {
  $mc_present{"$m->{file}\t$m->{line}\t$m->{category}"} = 1;
}
@mdl_findings = grep {
  my $cat = $equiv_rule_to_cat{$_->{rule}};
  !($cat && $mc_present{"$_->{file}\t$_->{line}\t$cat"});
} @mdl_findings;

# --- script-findings.md ---------------------------------------------------------------------------
my %file_lines_cache;
sub source_line {
  my ($path, $line) = @_;
  $file_lines_cache{$path} = [read_lines($path)] unless exists $file_lines_cache{$path};
  my $arr = $file_lines_cache{$path};
  my $idx = $line - 1;
  return ($idx >= 0 && $idx < scalar(@$arr)) ? $arr->[$idx] : '';
}

sub ascii_fold_line {
  my ($line) = @_;
  my $out = $line;
  $out =~ s/\x{2014}/-/g;
  $out =~ s/\x{2013}/-/g;
  $out =~ s/[\x{2018}\x{2019}]/'/g;
  $out =~ s/[\x{201C}\x{201D}]/"/g;
  $out =~ s/\x{2026}/.../g;
  return $out;
}

my @records;   # { file, line, rank, severity, category, cq, finding, evidence }

my %rank_of_mc = (
  placeholders => 1, fences => 2, links => 3, anchors => 4, typography => 5,
  headings => 6, 'fence-language' => 7, 'alt-text' => 8, h1 => 9, 'sibling-headings' => 10,
);

foreach my $m (@mc_findings) {
  my $cat = $m->{category};
  next unless exists $rank_of_mc{$cat};
  my ($sev, $gcat, $cq, $finding_text);
  if ($cat eq 'placeholders') {
    $sev = 'Major'; $gcat = 'mechanical'; $cq = 'Question: replace the unfinished marker';
    $finding_text = 'md-checks found an unfinished marker';
  } elsif ($cat eq 'fences') {
    $sev = 'Major'; $gcat = 'mechanical'; $cq = 'Question: close the fence';
    $finding_text = 'md-checks found an unclosed code fence';
  } elsif ($cat eq 'links') {
    $sev = 'Major'; $gcat = 'error'; $cq = 'Question: fix or remove the link target';
    $finding_text = 'md-checks found a relative link target that does not exist';
  } elsif ($cat eq 'anchors') {
    $sev = 'Major'; $gcat = 'error'; $cq = 'Question: fix the anchor or the heading it points to';
    $finding_text = 'md-checks found a same-file anchor with no matching heading';
  } elsif ($cat eq 'typography') {
    $sev = 'Minor'; $gcat = 'mechanical';
    $cq = 'Change: ' . ascii_fold_line(source_line($m->{file}, $m->{line}));
    $finding_text = 'md-checks found a character that violates the adopted ASCII rule';
  } elsif ($cat eq 'headings') {
    $sev = 'Minor'; $gcat = 'mechanical'; $cq = 'Question: fix the heading level';
    $finding_text = 'md-checks found a heading level that skips a level';
  } elsif ($cat eq 'fence-language') {
    $sev = 'Minor'; $gcat = 'mechanical'; $cq = 'Question: add a language tag to the fence';
    $finding_text = 'md-checks found a fenced code block with no language tag';
  } elsif ($cat eq 'alt-text') {
    $sev = 'Minor'; $gcat = 'mechanical'; $cq = 'Question: add alt text to the image';
    $finding_text = 'md-checks found an image with empty alt text';
  } elsif ($cat eq 'h1') {
    $sev = 'Minor'; $gcat = 'mechanical'; $cq = 'Question: fix the H1';
    $finding_text = 'md-checks found an H1 problem';
  } elsif ($cat eq 'sibling-headings') {
    $sev = 'Minor'; $gcat = 'mechanical'; $cq = 'Question: rename one of the repeated sibling headings';
    $finding_text = 'md-checks found a repeated sibling heading';
  }

  push @records, {
    file => $m->{file}, line => $m->{line}, rank => $rank_of_mc{$cat}, severity => $sev,
    category => $gcat, cq => $cq, finding => $finding_text,
    evidence => '"' . trim(source_line($m->{file}, $m->{line})) . '" - md-checks output: ' . $m->{desc},
  };
}

foreach my $r (@sc_findings) {
  push @records, {
    file => $r->{file}, line => $r->{line}, rank => 15, severity => 'Blocker', category => 'hygiene',
    cq => 'Question: remove or replace the identifier',
    finding => 'scrub-check found an identifier unsuited to a public remote',
    evidence => '"' . trim(source_line($r->{file}, $r->{line})) . '" - scrub-check output: ' . $r->{desc},
  };
}

foreach my $r (@link_rows) {
  my ($rank, $sev, $gcat, $cq, $finding_text);
  if ($r->{result} eq 'broken') {
    $rank = 11; $sev = 'Major'; $gcat = 'link-broken'; $cq = 'Question: fix or remove this link';
    $finding_text = 'link-recheck-hook.sh found a broken link';
  } elsif ($r->{result} eq 'inconclusive') {
    $rank = 12; $sev = 'Minor'; $gcat = 'link-inconclusive'; $cq = 'Question: confirm this link by hand';
    $finding_text = 'link-recheck-hook.sh could not confirm this link';
  } elsif ($r->{result} eq 'no-references') {
    $rank = 13; $sev = 'Minor'; $gcat = 'omission';
    $cq = 'Question: add a References section for the external pages this document cites';
    $finding_text = 'link-recheck-hook.sh found external links with no References section';
  } else {
    next;
  }
  push @records, {
    file => $r->{file}, line => $r->{line}, rank => $rank, severity => $sev, category => $gcat,
    cq => $cq, finding => $finding_text,
    evidence => '"' . trim(source_line($r->{file}, $r->{line})) . '" - links output: ' . $r->{url} . ' ' . $r->{result},
  };
}

foreach my $r (@freshness_findings) {
  push @records, {
    file => $r->{file}, line => $r->{line}, rank => 14, severity => 'Minor', category => 'freshness',
    cq => 'Question: confirm the content is current, then update the updated: header',
    finding => "md-claims.sh found an updated: header older than the file's last commit",
    evidence => '"' . trim(source_line($r->{file}, $r->{line})) . '" - claims output: ' . $r->{claim},
  };
}

foreach my $r (@mdl_findings) {
  push @records, {
    file => $r->{file}, line => $r->{line}, rank => 16, severity => 'Minor', category => 'polish',
    cq => "Question: $r->{rule}/$r->{alias} $r->{desc}",
    finding => "markdownlint found a $r->{rule} issue",
    evidence => '"' . trim(source_line($r->{file}, $r->{line})) . "\" - markdownlint output: $r->{rule}/$r->{alias} $r->{desc}",
  };
}

foreach my $r (@vale_findings) {
  push @records, {
    file => $r->{file}, line => $r->{line}, rank => 17, severity => 'Minor', category => 'polish',
    cq => "Question: $r->{check} $r->{msg}",
    finding => "vale found a $r->{check} issue",
    evidence => '"' . trim(source_line($r->{file}, $r->{line})) . "\" - vale output: $r->{check}: $r->{msg}",
  };
}

my $unknown_index = scalar(@files) + 1000;
@records = sort {
  my $ia = exists $index_of{$a->{file}} ? $index_of{$a->{file}} : $unknown_index;
  my $ib = exists $index_of{$b->{file}} ? $index_of{$b->{file}} : $unknown_index;
  $ia <=> $ib || $a->{line} <=> $b->{line} || $a->{rank} <=> $b->{rank}
} @records;

open(my $sf, '>:encoding(UTF-8)', "$run_dir/script-findings.md") or die "$!";
my $n = 0;
foreach my $r (@records) {
  $n++;
  my $rel = rel_to_git_root($r->{file});
  print $sf "- **S$n**\n";
  print $sf "  - File: $rel\n";
  print $sf "  - Line: $r->{line}\n";
  print $sf "  - Severity: $r->{severity}\n";
  print $sf "  - Category: $r->{category}\n";
  print $sf "  - Finding: $r->{finding}.\n";
  print $sf "  - Evidence: $r->{evidence}\n";
  print $sf "  - $r->{cq}\n";
  print $sf "  - Status: confirmed\n";
  if ($r->{severity} eq 'Blocker' || $r->{severity} eq 'Major') {
    print $sf "  - Best case: None: a mechanical match on the quoted text.\n";
  }
  print $sf "  - Raised by: script\n";
  print $sf "\n";
}
close $sf;

print "PROFILE\t$profile\n";
print "AGENTCONFIG\t$agent_config_field\n";
print "FINDINGS\t$n\n";
PERL

# --- run -------------------------------------------------------------------------------------------
cmd_run() {
  if [[ $# -lt 1 ]]; then
    echo "review-checks.sh: $usage_line" >&2
    exit 2
  fi

  local run_dir="$1"; shift
  local ascii_mode="" ascii_reason="" references_mode=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ascii)
        [[ $# -ge 2 ]] || { echo "review-checks.sh: --ascii requires a value" >&2; exit 2; }
        ascii_mode="$2"; shift 2 ;;
      --ascii-reason)
        [[ $# -ge 2 ]] || { echo "review-checks.sh: --ascii-reason requires a value" >&2; exit 2; }
        ascii_reason="$2"; shift 2 ;;
      --references)
        [[ $# -ge 2 ]] || { echo "review-checks.sh: --references requires a value" >&2; exit 2; }
        references_mode="$2"; shift 2 ;;
      *)
        echo "review-checks.sh: unknown option: $1" >&2
        exit 2 ;;
    esac
  done

  case "$ascii_mode" in
    adopted|not-adopted) ;;
    *) echo "review-checks.sh: --ascii must be adopted or not-adopted" >&2; exit 2 ;;
  esac
  case "$references_mode" in
    adopted|not-adopted) ;;
    *) echo "review-checks.sh: --references must be adopted or not-adopted" >&2; exit 2 ;;
  esac
  if [[ -z "$ascii_reason" || "$ascii_reason" == *[\(\)]* || "$ascii_reason" == *$'\n'* ]]; then echo "review-checks.sh: --ascii-reason must be non-empty, one line, without parentheses" >&2; exit 2; fi

  if [[ ! -d "$run_dir" ]]; then
    echo "review-checks.sh: run directory not found: $run_dir" >&2
    exit 2
  fi
  if [[ ! -f "$run_dir/files.tsv" ]]; then
    echo "review-checks.sh: $run_dir/files.tsv not found" >&2
    exit 1
  fi

  local files=() d_ids=()
  local did fpath fchars
  while IFS=$'\t' read -r did fpath fchars; do
    [[ -n "$did" ]] || continue
    d_ids+=("$did")
    files+=("$fpath")
  done < "$run_dir/files.tsv"

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "review-checks.sh: $run_dir/files.tsv has no files" >&2
    exit 1
  fi

  local skill_dir=""
  [[ -f "$run_dir/skill.txt" ]] && skill_dir="$(cat "$run_dir/skill.txt")"

  local d1_dir git_root=""
  d1_dir="$(dirname "${files[0]}")"
  git_root="$(git -C "$d1_dir" rev-parse --show-toplevel 2>/dev/null)"

  mkdir -p "$run_dir/tools" "$run_dir/docs"

  # --- launch the six tools concurrently ---------------------------------------------------------
  local mc_args=(--review)
  [[ "$ascii_mode" == "adopted" ]] || mc_args+=(--no-typography)
  (
    "$CFG/scripts/md-checks.sh" "${mc_args[@]}" "${files[@]}" \
      > "$run_dir/tools/md-checks.out" 2> "$run_dir/tools/md-checks.err"
    printf '%s\n' "$?" > "$run_dir/tools/md-checks.exit"
  ) &

  local lk_args=(--review)
  [[ "$references_mode" == "adopted" ]] && lk_args+=(--references-rule)
  (
    "$CFG/scripts/link-recheck-hook.sh" "${lk_args[@]}" "${files[@]}" \
      > "$run_dir/tools/links.out" 2> "$run_dir/tools/links.err"
    printf '%s\n' "$?" > "$run_dir/tools/links.exit"
  ) &

  (
    "$CFG/scripts/md-claims.sh" "${files[@]}" \
      > "$run_dir/tools/claims.out" 2> "$run_dir/tools/claims.err"
    printf '%s\n' "$?" > "$run_dir/tools/claims.exit"
  ) &

  local scrub_launched=0
  if [[ -n "$git_root" && -f "$git_root/scripts/scrub-check.sh" ]]; then
    scrub_launched=1
    (
      "$git_root/scripts/scrub-check.sh" "${files[@]}" \
        > "$run_dir/tools/scrub-check.out" 2> "$run_dir/tools/scrub-check.err"
      printf '%s\n' "$?" > "$run_dir/tools/scrub-check.exit"
    ) &
  fi

  local mdl_present=0 mdl_config=""
  if command -v markdownlint >/dev/null 2>&1; then
    mdl_present=1
    if [[ -n "$git_root" ]]; then
      local c
      for c in .markdownlint.json .markdownlint.jsonc .markdownlint.yaml .markdownlint.yml; do
        if [[ -f "$git_root/$c" ]]; then mdl_config="$git_root/$c"; break; fi
      done
    fi
    [[ -n "$mdl_config" ]] || mdl_config="$skill_dir/assets/markdownlint.jsonc"
    (
      markdownlint --config "$mdl_config" "${files[@]}" \
        > "$run_dir/tools/markdownlint.out" 2> "$run_dir/tools/markdownlint.err"
      printf '%s\n' "$?" > "$run_dir/tools/markdownlint.exit"
    ) &
  fi

  local vale_present=0 vale_config=""
  if command -v vale >/dev/null 2>&1; then
    vale_present=1
    if [[ -n "$git_root" && -f "$git_root/.vale.ini" ]]; then
      vale_config="$git_root/.vale.ini"
    else
      vale_config="$skill_dir/assets/vale/.vale.ini"
    fi
    (
      vale --config "$vale_config" --output=line "${files[@]}" \
        > "$run_dir/tools/vale.out" 2> "$run_dir/tools/vale.err"
      printf '%s\n' "$?" > "$run_dir/tools/vale.exit"
    ) &
  fi

  wait

  # --- classify each tool's result ---------------------------------------------------------------
  local mc_exit mc_result mc_ran=0
  mc_exit="$(cat "$run_dir/tools/md-checks.exit" 2>/dev/null)"
  if [[ "$mc_exit" == "0" ]]; then mc_result="ran"; mc_ran=1; else mc_result="error($mc_exit)"; fi

  local lk_exit lk_result lk_ran=0
  lk_exit="$(cat "$run_dir/tools/links.exit" 2>/dev/null)"
  if [[ "$lk_exit" == "0" ]]; then lk_result="ran"; lk_ran=1; else lk_result="error($lk_exit)"; fi

  local cl_exit cl_result cl_ran=0
  cl_exit="$(cat "$run_dir/tools/claims.exit" 2>/dev/null)"
  if [[ "$cl_exit" == "0" ]]; then cl_result="ran"; cl_ran=1; else cl_result="error($cl_exit)"; fi

  local sc_result sc_ran=0
  if [[ $scrub_launched -eq 1 ]]; then
    local sc_exit
    sc_exit="$(cat "$run_dir/tools/scrub-check.exit" 2>/dev/null)"
    case "$sc_exit" in
      0|1) sc_result="ran"; sc_ran=1 ;;
      *) sc_result="error($sc_exit)" ;;
    esac
  else
    sc_result="absent"
  fi

  local mdl_result mdl_ran=0
  if [[ $mdl_present -eq 1 ]]; then
    local mdl_exit
    mdl_exit="$(cat "$run_dir/tools/markdownlint.exit" 2>/dev/null)"
    case "$mdl_exit" in
      0|1) mdl_result="ran"; mdl_ran=1 ;;
      *) mdl_result="error($mdl_exit)" ;;
    esac
  else
    mdl_result="not installed (see references/markdownlint-setup.md)"
  fi

  local vl_result vl_ran=0
  if [[ $vale_present -eq 1 ]]; then
    local vl_exit
    vl_exit="$(cat "$run_dir/tools/vale.exit" 2>/dev/null)"
    case "$vl_exit" in
      0|1) vl_result="ran"; vl_ran=1 ;;
      *) vl_result="error($vl_exit)" ;;
    esac
  else
    vl_result="not installed (see references/vale-setup.md)"
  fi

  local tools_field="md-checks=$mc_result, links=$lk_result, claims=$cl_result, scrub-check=$sc_result, markdownlint=$mdl_result, vale=$vl_result"

  # --- exclusions.txt ------------------------------------------------------------------------------
  local excl_lines=()
  if [[ $mc_ran -eq 1 ]]; then
    if [[ "$ascii_mode" == "adopted" ]]; then
      excl_lines+=("md-checks: unfinished markers, typography, heading-level skips, unclosed fences, relative link targets, same-file anchors, fence language tags, empty alt text, H1 rules, repeated sibling headings")
    else
      excl_lines+=("md-checks: unfinished markers, heading-level skips, unclosed fences, relative link targets, same-file anchors, fence language tags, empty alt text, H1 rules, repeated sibling headings")
    fi
  fi
  [[ $lk_ran -eq 1 ]] && excl_lines+=("links: link liveness")
  [[ $sc_ran -eq 1 ]] && excl_lines+=("scrub-check: home paths and identifiers")
  [[ $mdl_ran -eq 1 ]] && excl_lines+=("markdownlint: the topics of its rules")
  [[ $vl_ran -eq 1 ]] && excl_lines+=("vale: repeated words")

  if [[ ${#excl_lines[@]} -eq 0 ]]; then
    printf 'none\n' > "$run_dir/exclusions.txt"
  else
    printf '%s\n' "${excl_lines[@]}" > "$run_dir/exclusions.txt"
  fi

  # --- tools that ran, for signals.txt -----------------------------------------------------------
  local ran_list=()
  [[ $mc_ran -eq 1 ]] && ran_list+=("md-checks")
  [[ $lk_ran -eq 1 ]] && ran_list+=("links")
  [[ $cl_ran -eq 1 ]] && ran_list+=("claims")
  [[ $sc_ran -eq 1 ]] && ran_list+=("scrub-check")
  [[ $mdl_ran -eq 1 ]] && ran_list+=("markdownlint")
  [[ $vl_ran -eq 1 ]] && ran_list+=("vale")
  local ran_tools_csv=""
  if [[ ${#ran_list[@]} -gt 0 ]]; then
    ran_tools_csv="$(IFS=,; echo "${ran_list[*]}")"
  fi

  # --- docs/, script-findings.md ------------------------------------------------------------------
  local pp_out pp_status
  pp_out="$(perl -e "$POSTPROCESS" -- "$run_dir" "$git_root" "$mc_ran" "$lk_ran" "$cl_ran" "$sc_ran" "$mdl_ran" "$vl_ran" "$ran_tools_csv")"
  pp_status=$?
  if [[ $pp_status -ne 0 && $pp_status -ne 1 && $pp_status -ne 2 ]]; then
    echo "review-checks.sh: internal failure (perl exit $pp_status)" >&2
    exit 1
  fi
  if [[ $pp_status -ne 0 ]]; then
    echo "review-checks.sh: postprocessing failed (exit $pp_status)" >&2
    exit 1
  fi

  local profile agent_config findings_count
  profile="$(printf '%s\n' "$pp_out" | awk -F'\t' '$1=="PROFILE"{print $2}')"
  agent_config="$(printf '%s\n' "$pp_out" | awk -F'\t' '$1=="AGENTCONFIG"{print $2}')"
  findings_count="$(printf '%s\n' "$pp_out" | awk -F'\t' '$1=="FINDINGS"{print $2}')"

  # --- context.txt ----------------------------------------------------------------------------------
  {
    printf 'git-root=%s\n' "${git_root:-none}"
    if [[ "$ascii_mode" == "adopted" ]]; then
      printf 'ascii-rule=adopted (%s)\n' "$ascii_reason"
    else
      printf 'ascii-rule=not adopted (%s)\n' "$ascii_reason"
    fi
    if [[ "$references_mode" == "adopted" ]]; then
      printf 'references-rule=adopted\n'
    else
      printf 'references-rule=not adopted\n'
    fi
    printf 'profile=%s\n' "$profile"
    printf 'agent-config=%s\n' "$agent_config"
    printf 'tools=%s\n' "$tools_field"
  } > "$run_dir/context.txt"

  printf 'tools=%s\n' "$tools_field"
  printf 'profile=%s\n' "$profile"
  printf 'script-findings=%s\n' "$findings_count"
}

# --- dispatch ----------------------------------------------------------------------------------------
cmd="${1:-}"
case "$cmd" in
  init) shift; cmd_init "$@" ;;
  run) shift; cmd_run "$@" ;;
  *)
    echo "review-checks.sh: $usage_line" >&2
    exit 2 ;;
esac

exit 0
