#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-/var/log/app}"
KEEP=7

cd "$DIR"
for f in *.log; do
  [ -e "$f" ] || continue
  mv "$f" "$f.$(date +%Y%m%d)"
  : > "$f"
done

ls -1t *.log.* 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm --
