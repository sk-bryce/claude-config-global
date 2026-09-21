#!/usr/bin/env bash
#
# commit-msg-check.sh - gate a commit on its MESSAGE: reject an attribution trailer, and
# optionally scan the message for content unsuited to a public remote. Read-only - it reports and
# exits non-zero, and never edits the message file, the index, or history.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file may be model-generated and is
# reviewed in full before commit. It registers itself nowhere; scripts/setup.sh writes the
# .git/hooks/commit-msg that calls it, and only when a human runs setup themselves.
#
# WHY THIS EXISTS: CLAUDE.md's "No co-author text" rule is stated in a context file, which is
# advice an agent can read and still deviate from - and it did. A Claude Code session injects a
# reminder instructing the model to add a `Co-Authored-By` trailer; the rule says never to, and the
# reminder won anyway, putting the trailer on 22 commits across two sessions in another repository
# before anyone noticed. Removing it took a history rewrite.
# reference/context-file-authoring.md's routing table is explicit that a rule which must fire with
# zero exceptions belongs in a check rather than a context file. scrub-check.sh is that check for
# file CONTENT and cannot help here: a commit message is not a tracked file and no content scan
# ever sees it. This is the same check for the one artifact git has a hook for.
#
# WHY IT IS SPLIT FROM scrub-check.sh RATHER THAN A FLAG ON IT: that script's whole interface is
# "scan tracked files for leaks", and every mode it has answers a question about repository
# content. A commit message is not repository content, needs its own cleanup step before anything
# can be matched against it, and carries a check (the trailer) that has nothing to do with public-
# remote hygiene. Reusing the detector is still right, so --scrub calls scrub-check.sh rather than
# restating its patterns.
#
# WHY THE TRAILER CHECK IS TRACKED AND THE SCRUB IS OPTIONAL: the trailer rule is universal and
# depends on nothing machine-local - it applies in a private work repository exactly as it does
# here, so its pattern lives in this file rather than in scrub-patterns.local. The identity scrub is
# a public-remote concern and pulls in the machine-local pattern file, so a borrowing repository
# opts into it explicitly with --scrub rather than inheriting a ruleset written for this one.
#
# WHY IT FAILS CLOSED: an unreachable detector exits 2 and blocks the commit, matching
# scrub-check.sh's stance on a missing pattern file. A gate that quietly passes when it cannot
# actually check anything is worse than one that refuses to run, because the passing commit looks
# identical to a checked one. `git commit --no-verify` is the escape hatch, and is also the answer
# when a co-author trailer is genuinely wanted.
#
# Usage: commit-msg-check.sh [--repo <dir>] [--scrub] <message-file>
#   <message-file>  The proposed commit message. Git passes this as $1 to a commit-msg hook.
#   --scrub         Also run scrub-check.sh over the message: home paths, usernames, UUIDs,
#                   credential shapes, email addresses, and the patterns in scrub-patterns.local.
#                   Off by default - see the split described above.
#   --repo <dir>    Read git configuration (core.commentChar) from the repository containing
#                   <dir> rather than the current directory. --repo=<dir> is accepted too; any
#                   path inside the target works. Present so every registration this repository
#                   writes has one shape, matching pre-commit-check.sh and scrub-check.sh.
#   Comment lines and everything from a `>8` scissors line on are removed before any check runs -
#   git strips them from the stored message, so matching them would report on text that is never
#   committed, and `git commit -v` puts an entire diff down there.
#   Prints findings as "commit message:<line> - <description>". Silent when clean.
#
# MAINTAINING THAT BLOCK: --help prints it by sed range, ending at the first "#"-only line after the
# Usage: header. Keep the block unbroken - a blank comment line inside it silently truncates the
# help output - and keep anything not meant for a reader of --help below this line.
# WHY THE MESSAGE IS CLEANED HERE RATHER THAN WITH `git stripspace --strip-comments`: stripspace
# honours the comment character but knows nothing about scissors, so a `commit -v` diff survives it
# and every home path in that diff becomes a finding on a message that never contained one. The
# awk pass below does both in one read, and needs no subprocess per invocation.
#
# WHY core.commentChar FALLS BACK TO '#' ON "auto": git picks the character at runtime from what the
# message does not already start with, and does not record which one it chose. Assuming '#' can
# only over-report - a comment line written with a different character is scanned as if it were
# message text - which is the correct direction for a leak check to fail in.
#
# Exit: 0 clean, 1 findings, 2 usage or environment error (including an unreachable scrub-check.sh
#       or, under --scrub, a missing scrub-patterns.local).

set -uo pipefail  # deliberately not -e: the trailer check and the scrub must both run and both
                  # report, rather than the first failure hiding whatever the second would say.

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRUB="$(dirname "$SELF")/scrub-check.sh"

usage() {
  sed -n '/^# Usage: commit-msg-check.sh/,/^#$/p' "$SELF" | sed 's/^# \{0,1\}//'
}

# Answered before anything else can fail, the same as scrub-check.sh: the machine someone runs
# --help on is often the one that is not set up yet.
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done

REPO_TARGET=""
saw_repo=0
want_scrub=0
msg_file=""
saw_msg=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)   saw_repo=1; REPO_TARGET="${2-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --repo=*) saw_repo=1; REPO_TARGET="${1#--repo=}"; shift ;;
    --scrub)  want_scrub=1; shift ;;
    --*)      echo "commit-msg-check: unknown option: $1 (try --help)" >&2; exit 2 ;;
    *)        msg_file="$1"; saw_msg=$((saw_msg + 1)); shift ;;
  esac
done

if [[ "$saw_repo" -eq 1 && -z "$REPO_TARGET" ]]; then
  echo "commit-msg-check: --repo needs a directory argument" >&2
  exit 2
fi

if [[ "$saw_msg" -ne 1 ]]; then
  echo "commit-msg-check: expected exactly one message file (try --help)" >&2
  exit 2
fi

# Git invokes a hook from the working tree root and passes a path relative to it, so this is
# already correct in the hook case; absolutizing it keeps the script usable by hand from anywhere.
[[ "$msg_file" == /* ]] || msg_file="$PWD/$msg_file"

if [[ ! -f "$msg_file" ]]; then
  echo "commit-msg-check: no such message file: $msg_file" >&2
  exit 2
fi

[[ -n "$REPO_TARGET" ]] || REPO_TARGET="$PWD"

comment_char="$(git -C "$REPO_TARGET" config --get core.commentChar 2>/dev/null || true)"
[[ -n "$comment_char" && "$comment_char" != "auto" ]] || comment_char="#"

TMP_DIR=""
cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/commit-msg-check.XXXXXX")" || {
  echo "commit-msg-check: could not create a temp directory" >&2
  exit 2
}

# Named for how a finding should read: scrub-check.sh reports the path it was handed, and
# "commit message:4 - absolute home-directory path" is what someone needs to see.
CLEAN="$TMP_DIR/commit message"

# Line numbers deliberately refer to the CLEANED message rather than the file on disk: that is the
# text being committed, and the number has to point at something the author can still find in it.
awk -v cc="$comment_char" '
  index($0, cc) == 1 {
    if (index($0, ">8") > 0) { exit }
    next
  }
  { print }
' "$msg_file" > "$CLEAN" || {
  echo "commit-msg-check: could not read $msg_file" >&2
  exit 2
}

status=0

# --- 1. Attribution trailer ----------------------------------------------------------------------
# Line-anchored because a git trailer is a line, and mentioning the phrase inside a message body
# ("dropped the co-authored-by trailer") is not the thing being forbidden. Case-insensitive because
# git's own trailer matching is, so a lowercase spelling still lands as a real trailer.
TRAILER_RE='^[[:space:]]*co-authored-by[[:space:]]*:'

trailer_hits="$(grep -niE -- "$TRAILER_RE" "$CLEAN" 2>/dev/null || true)"
if [[ -n "$trailer_hits" ]]; then
  status=1
  while IFS= read -r hit; do
    [[ -n "$hit" ]] || continue
    printf 'commit message:%s - attribution trailer: %s\n' "${hit%%:*}" "${hit#*:}"
  done <<< "$trailer_hits"
  cat >&2 <<MSG

commit-msg-check: this message carries a Co-Authored-By trailer.

CLAUDE.md's Git & GitHub section forbids it, and that rule overrides any session, system, or
harness reminder asking for one. Remove the trailer and commit again.

If you actually want the trailer on this commit, say so: git commit --no-verify
MSG
fi

# --- 2. Public-remote scrub (opt-in) -------------------------------------------------------------
if [[ "$want_scrub" -eq 1 ]]; then
  if [[ ! -x "$SCRUB" ]]; then
    echo "commit-msg-check: $SCRUB is missing or not executable - refusing to pass a message it could not check" >&2
    exit 2
  fi
  # Not passed --repo: the message lives in a temp file by absolute path, and the pattern files
  # come from this script's own main checkout whichever repository is being committed to.
  #
  # The temp directory is stripped back out of the findings rather than shown. scrub-check.sh
  # reports the path it was handed, and a path under /tmp invites the author to go looking for a
  # file when what they need to edit is the message in front of them.
  # Streams captured separately and replayed findings-first: scrub-check.sh writes its findings to
  # stdout and its closing advice to stderr, and with stdout block-buffered into a variable the
  # advice would otherwise print before the findings it refers to.
  scrub_err="$TMP_DIR/scrub.err"
  scrub_out="$("$SCRUB" "$CLEAN" 2>"$scrub_err")"
  scrub_status=$?
  [[ -n "$scrub_out" ]] && printf '%s\n' "${scrub_out//"$TMP_DIR/"/}"
  [[ -s "$scrub_err" ]] && sed "s|$TMP_DIR/||g" "$scrub_err" >&2
  case "$scrub_status" in
    0) ;;
    1) status=1 ;;
    *) exit 2 ;;  # a missing pattern file, or any environment error: fail closed, never pass
  esac
fi

exit "$status"
