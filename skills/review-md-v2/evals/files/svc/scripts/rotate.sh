#!/usr/bin/env bash
#
# rotate.sh - rotate and prune ledgerd logs. Run it nightly from cron.
#
# Usage: scripts/rotate.sh [--keep-days N] [--log-dir DIR] [--dry-run]
#
#   --keep-days N   delete rotated logs older than N days (default: 14)
#   --log-dir DIR   the log directory (default: /var/log/ledgerd)
#   --dry-run       print what would be rotated and deleted; change nothing
#
set -euo pipefail

keep_days=14
log_dir=/var/log/ledgerd
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-days) keep_days="$2"; shift 2 ;;
    --log-dir) log_dir="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "rotate.sh: unknown option: $1" >&2; exit 2 ;;
  esac
done

stamp="$(date +%Y%m%d)"
for f in "$log_dir"/*.log; do
  [[ -e "$f" ]] || continue
  if [[ "$dry_run" -eq 1 ]]; then
    echo "would rotate $f"
  else
    mv "$f" "$f.$stamp"
    gzip -q "$f.$stamp"
  fi
done

if [[ "$dry_run" -eq 1 ]]; then
  find "$log_dir" -name '*.log.*.gz' -mtime +"$keep_days" -print
else
  find "$log_dir" -name '*.log.*.gz' -mtime +"$keep_days" -delete
fi
