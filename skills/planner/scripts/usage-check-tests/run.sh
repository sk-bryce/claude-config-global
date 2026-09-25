#!/usr/bin/env bash
#
# run.sh - runs each fixture case in this directory through ../usage-check.sh with
# PLANNER_USAGE_JSON pointed at that fixture, compares stdout and the exit code exactly, and
# prints "PASS <case>" or "FAIL <case>: expected ... got ..." per case. Exits 0 only if every
# case passes.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file's logic may be
# model-generated and is reviewed in full before commit.
#
set -uo pipefail

DIR="$(dirname "${BASH_SOURCE[0]}")"
SCRIPT="$DIR/../usage-check.sh"

FAILURES=0

run_case() {
  local name="$1" fixture="$2" expected_stdout="$3" expected_exit="$4"
  shift 4
  local actual_stdout actual_exit
  actual_stdout="$(PLANNER_USAGE_JSON="$DIR/$fixture" "$SCRIPT" "$@" 2>/dev/null)"
  actual_exit=$?
  if [[ "$actual_stdout" == "$expected_stdout" && "$actual_exit" == "$expected_exit" ]]; then
    echo "PASS $name"
  else
    echo "FAIL $name: expected stdout=[$expected_stdout] exit=$expected_exit got stdout=[$actual_stdout] exit=$actual_exit"
    FAILURES=$((FAILURES + 1))
  fi
}

run_case "ok" "f01_ok.json" \
  "status=ok pct=40 source=five_hour five_hour=40 seven_day=20 spend=-" 0

run_case "warn boundary" "f02_warn_boundary.json" \
  "status=warn pct=85 source=five_hour five_hour=85 seven_day=10 spend=-" 10

run_case "floor below warn" "f03_below_warn.json" \
  "status=ok pct=84 source=five_hour five_hour=84 seven_day=- spend=-" 0

run_case "stop on 7-day" "f04_stop_seven_day.json" \
  "status=stop pct=95 source=seven_day five_hour=30 seven_day=95 spend=-" 20

run_case "spend cap stop" "f05_stop_cap.json" \
  "status=stop-cap pct=97 source=spend five_hour=- seven_day=- spend=97" 21

run_case "cap and window" "f06_cap_and_window.json" \
  "status=stop-cap pct=99 source=five_hour five_hour=99 seven_day=- spend=96" 21

run_case "all null" "f07_all_null.json" \
  "status=unknown pct=- source=none five_hour=- seven_day=- spend=-" 30

run_case "malformed" "f08_malformed.txt" \
  "status=unknown pct=- source=none five_hour=- seven_day=- spend=-" 30

run_case "tie order" "f09_tie.json" \
  "status=warn pct=90 source=spend five_hour=90 seven_day=90 spend=90" 10

run_case "spend without cap ignored" "f10_spend_no_limit.json" \
  "status=ok pct=40 source=five_hour five_hour=40 seven_day=- spend=-" 0

run_case "custom thresholds" "f01_ok.json" \
  "status=warn pct=40 source=five_hour five_hour=40 seven_day=20 spend=-" 10 \
  --warn 30 --stop 60

run_case "bad number" "f01_ok.json" \
  "" 2 \
  --warn abc

run_case "warn above stop" "f01_ok.json" \
  "" 2 \
  --warn 90 --stop 80

if [[ "$FAILURES" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
