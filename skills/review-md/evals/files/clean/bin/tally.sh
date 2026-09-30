#!/usr/bin/env bash
# tally.sh - count the lines in each file that contain a word, then print a total.
set -euo pipefail

usage() {
  echo "usage: tally.sh [-i] WORD FILE..." >&2
  exit 2
}

ignore_case=0
if [ "${1-}" = "-i" ]; then
  ignore_case=1
  shift
fi
[ $# -ge 2 ] || usage
word="$1"
shift

total=0
for file in "$@"; do
  if [ ! -r "$file" ]; then
    echo "tally.sh: cannot read $file" >&2
    exit 1
  fi
  if [ "$ignore_case" -eq 1 ]; then
    n=$(grep -ciF -- "$word" "$file" || true)
  else
    n=$(grep -cF -- "$word" "$file" || true)
  fi
  printf '%s\t%s\n' "$n" "$file"
  total=$((total + n))
done
printf '%s\ttotal\n' "$total"
