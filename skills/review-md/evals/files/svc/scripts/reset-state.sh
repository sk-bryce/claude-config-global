#!/usr/bin/env bash
#
# reset-state.sh - mark this node's local state as reset, so the next start rebuilds its caches.
#
# Usage: scripts/reset-state.sh
#
set -euo pipefail

touch "$(dirname "$0")/../.state-was-reset"
