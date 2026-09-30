#!/bin/sh
# backup.sh - archive the notes directory and prune old archives.
set -eu

SRC="${1:-notes}"
DEST="${BACKUP_DIR:-backups}"
KEEP_DAYS=14

mkdir -p "$DEST"
tar -czf "$DEST/notes-$(date +%Y%m%d).tar.gz" "$SRC"
find "$DEST" -name 'notes-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
