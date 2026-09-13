#!/usr/bin/env bash
#
# markdownlint-hook.sh - shared logic for the "lint a Markdown file after it's edited" hook.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it
# (settings.json's PostToolUse entry) is a separate, human step. This script does nothing on
# write; it only runs when a registered hook invokes it with a changed file path.
#
# Usage: markdownlint-hook.sh <file-path>
#   Silently no-ops for anything that isn't a *.md file, and for a missing/empty argument.
#
# Claude Code's settings.json PostToolUse hook calls this script directly, so there is exactly one
# copy of this logic - see decisions/0003.

set -euo pipefail

f="${1:-}"
[[ -z "$f" ]] && exit 0

case "$f" in
  *.md) markdownlint --fix "$f" 2>/dev/null || true ;;
esac

exit 0
