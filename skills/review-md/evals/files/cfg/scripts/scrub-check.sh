#!/usr/bin/env bash
# Report lines that contain a home-directory path or match a pattern in scrub-patterns.local.
# Usage: scripts/scrub-check.sh <path>...
# Prints <path>:<line>: <match> for each hit. Exits 1 on any hit and 0 otherwise.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
patterns="$here/scrub-patterns.local"
status=0

report() {
  local path="$1" regex="$2" n match
  while IFS=: read -r n match; do
    printf '%s:%s: %s\n' "$path" "$n" "$match"
    status=1
  done < <(grep -noE -- "$regex" "$path")
}

for path in "$@"; do
  [ -f "$path" ] || continue
  report "$path" '/(home|Users)/[a-z]+/'
  if [ -f "$patterns" ]; then
    while IFS= read -r pattern || [ -n "$pattern" ]; do
      [ -n "$pattern" ] || continue
      report "$path" "$pattern"
    done < "$patterns"
  fi
done

exit "$status"
