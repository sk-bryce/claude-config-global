#!/usr/bin/env bash
# ferryctl.sh - control the Ferry scheduler.
#
# Usage:
#   ferryctl.sh start [--config PATH]
#   ferryctl.sh stop
#   ferryctl.sh status
#   ferryctl.sh submit [--queue NAME] [--dry-run] JOB
#   ferryctl.sh drain [--timeout SECONDS]
#
# --config defaults to config/ferry.toml. --queue defaults to "default".
# --timeout defaults to 300.
set -euo pipefail

api="http://127.0.0.1:${FERRY_PORT:-9170}"

usage() {
  sed -n '4,12p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

cmd="${1:-}"
[[ -n "$cmd" ]] || usage
shift

case "$cmd" in
  start)
    config="config/ferry.toml"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --config) config="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    exec ferryd --config "$config"
    ;;
  stop)
    [[ $# -eq 0 ]] || usage
    pkill -TERM -x ferryd
    ;;
  status)
    [[ $# -eq 0 ]] || usage
    curl -fsS "$api/status"
    ;;
  submit)
    queue="default"
    dry_run=0
    while [[ $# -gt 1 ]]; do
      case "$1" in
        --queue) queue="$2"; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        *) usage ;;
      esac
    done
    [[ $# -eq 1 ]] || usage
    curl -fsS -X POST "$api/jobs/$1/runs?queue=$queue&dry_run=$dry_run"
    ;;
  drain)
    timeout=300
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --timeout) timeout="$2"; shift 2 ;;
        *) usage ;;
      esac
    done
    curl -fsS -X POST "$api/drain?timeout=$timeout"
    ;;
  *)
    usage
    ;;
esac
