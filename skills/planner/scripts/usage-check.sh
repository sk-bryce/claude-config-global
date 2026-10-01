#!/usr/bin/env bash
#
# usage-check.sh - reports this account's usage against warn/stop thresholds so an orchestrator
# can pause a plan before hitting a limit.
#
# Usage:  usage-check.sh [--warn N] [--stop N]
#         N is an integer from 1 to 100. Defaults: --warn 85, --stop 95. warn must be less than
#         stop. On an invalid argument: usage text on stderr, nothing on stdout, exit 2.
#
# Output: exactly one line on stdout:
#   status=<status> pct=<pct> source=<source> five_hour=<v> seven_day=<v> spend=<v>
#   pct    = the largest present value (five_hour/seven_day/spend), or "-" when none is present
#   source = the value pct came from; ties prefer spend, then seven_day, then five_hour;
#            "none" when no value is present
#
# Status and exit code, first match wins:
#   unknown   30  no value present; or no token, a token error, a network failure, or a response
#                 that is not JSON
#   stop-cap  21  spend >= stop   (spend cap: does not reset within hours; halt, never sleep)
#   stop      20  pct >= stop     (5-hour or 7-day window: pause, re-check every 15 min)
#   warn      10  pct >= warn     (check before every Unit)
#   ok         0  otherwise       (check before every Cluster)
#
# Source: GET https://api.anthropic.com/api/oauth/usage (undocumented) with the OAuth access
# token, resolved by get_usage_token below (copied from scripts/statusline.sh, see that function's
# own comment for the full lookup order). The token is never printed, logged, or written to disk.
#
# Test hook: when PLANNER_USAGE_JSON names a file, its contents are read as the response in place
# of the token lookup and the network call.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file's logic may be
# model-generated and is reviewed in full before commit.
#
set -uo pipefail  # deliberately not -e: every failure path must reach the "unknown" output

WARN=85
STOP=95

usage() {
  cat >&2 <<'EOF'
Usage: usage-check.sh [--warn N] [--stop N]
  N is an integer from 1 to 100. Defaults: --warn 85, --stop 95. warn must be less than stop.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --warn)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      WARN="$2"
      shift 2
      ;;
    --stop)
      if [[ $# -lt 2 ]]; then
        usage
        exit 2
      fi
      STOP="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if ! [[ "$WARN" =~ ^[1-9][0-9]*$ ]] || (( WARN < 1 || WARN > 100 )); then
  usage
  exit 2
fi
if ! [[ "$STOP" =~ ^[1-9][0-9]*$ ]] || (( STOP < 1 || STOP > 100 )); then
  usage
  exit 2
fi
if (( WARN >= STOP )); then
  usage
  exit 2
fi

# Copied from scripts/statusline.sh's get_usage_token (and the ORG_NAME read it depends on); the
# two copies must be kept in step manually. Lookup order: the macOS profile-scoped Keychain entry
# ("Claude Code-credentials-<first 8 hex of sha256 of CLAUDE_CONFIG_DIR>") when CLAUDE_CONFIG_DIR
# is set on macOS, else the bare "Claude Code-credentials" Keychain entry on macOS, else
# .credentials.json in the config directory. A missing scoped entry for a profile that has logged
# in is a hard error rather than a fallback, so one account's usage is never read under another's
# profile.
ORG_NAME=""
CLAUDE_JSON_PATH="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
if [[ -f "$CLAUDE_JSON_PATH" ]]; then
  ORG_NAME="$(jq -r '.oauthAccount.organizationName // "" | gsub("[\n\r]"; " ")' \
    "$CLAUDE_JSON_PATH" 2>/dev/null)"
fi

get_usage_token() {
  local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local token=""
  local is_darwin=0
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] && is_darwin=1

  if [[ "$is_darwin" == "1" && -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
    if command -v security >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1; then
      local suffix scoped_service
      suffix="$(printf '%s' "$CLAUDE_CONFIG_DIR" | shasum -a 256 | cut -c1-8)"
      scoped_service="Claude Code-credentials-$suffix"
      token="$(security find-generic-password -s "$scoped_service" -w 2>/dev/null | \
        jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)"
      if [[ -z "$token" && -n "$ORG_NAME" ]]; then
        USAGE_TOKEN_ERROR="expected macOS Keychain entry \"$scoped_service\" for CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR (org \"$ORG_NAME\") but it was not found - withholding limits rather than risk showing another account's data"
      fi
    else
      USAGE_TOKEN_ERROR="cannot verify this profile's Keychain entry: 'security' or 'shasum' not found on PATH"
    fi
    RESOLVED_TOKEN="$token"
    return
  fi

  # Everything below is the non-(macOS + CLAUDE_CONFIG_DIR) path, so only two lookups remain:
  # the bare Keychain entry (macOS with no profile to scope by) and the file at config_dir, which
  # is $CLAUDE_CONFIG_DIR when that is set and $HOME/.claude otherwise. The file check below
  # already covers CLAUDE_CONFIG_DIR on its own; the only case where checking it ahead of the
  # Keychain lookup would matter is macOS with CLAUDE_CONFIG_DIR set, and that case returns above
  # already.
  if [[ -z "$token" && "$is_darwin" == "1" ]] && command -v security >/dev/null 2>&1; then
    token="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | \
      jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)"
  fi

  if [[ -z "$token" && -f "$config_dir/.credentials.json" ]]; then
    token="$(jq -r '.claudeAiOauth.accessToken // empty' "$config_dir/.credentials.json" 2>/dev/null)"
  fi

  RESOLVED_TOKEN="$token"
}

JSON=""
FETCH_ERROR=""

if [[ -n "${PLANNER_USAGE_JSON:-}" ]]; then
  if [[ -f "$PLANNER_USAGE_JSON" ]]; then
    JSON="$(cat "$PLANNER_USAGE_JSON" 2>/dev/null)"
  else
    FETCH_ERROR="PLANNER_USAGE_JSON file not found: $PLANNER_USAGE_JSON"
  fi
else
  RESOLVED_TOKEN=""
  USAGE_TOKEN_ERROR=""
  get_usage_token
  if [[ -n "$USAGE_TOKEN_ERROR" ]]; then
    FETCH_ERROR="$USAGE_TOKEN_ERROR"
  elif [[ -z "$RESOLVED_TOKEN" ]]; then
    FETCH_ERROR="no usage token available"
  else
    JSON="$(curl -s --max-time 5 --connect-timeout 3 \
      -H "Authorization: Bearer $RESOLVED_TOKEN" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)"
    if [[ -z "$JSON" ]]; then
      FETCH_ERROR="network request failed or returned empty response"
    fi
  fi
fi

FIVE_HOUR="-"
SEVEN_DAY="-"
SPEND="-"

if [[ -z "$FETCH_ERROR" ]]; then
  parsed="$(printf '%s' "$JSON" | jq -r '
    def val(v): if (v|type) == "number" then (v|floor|tostring) else "-" end;
    (.five_hour.utilization) as $fh
    | (.seven_day.utilization) as $sd
    | (if (.spend.limit != null) then .spend.percent else null end) as $sp
    | [val($fh), val($sd), val($sp)] | join("\t")
  ' 2>/dev/null)"
  if [[ -z "$parsed" ]]; then
    FETCH_ERROR="response was not valid JSON"
  else
    IFS=$'\t' read -r FIVE_HOUR SEVEN_DAY SPEND <<< "$parsed"
  fi
fi

PCT="-"
SOURCE="none"

pick() {
  local v="$1" name="$2"
  [[ "$v" == "-" ]] && return
  if [[ "$PCT" == "-" ]]; then
    PCT="$v"
    SOURCE="$name"
  elif (( v >= PCT )); then
    PCT="$v"
    SOURCE="$name"
  fi
}

if [[ -z "$FETCH_ERROR" ]]; then
  pick "$FIVE_HOUR" "five_hour"
  pick "$SEVEN_DAY" "seven_day"
  pick "$SPEND" "spend"
fi

if [[ -n "$FETCH_ERROR" ]]; then
  STATUS="unknown"
  EXIT=30
  printf '%s\n' "$FETCH_ERROR" >&2
elif [[ "$PCT" == "-" ]]; then
  STATUS="unknown"
  EXIT=30
elif [[ "$SPEND" != "-" ]] && (( SPEND >= STOP )); then
  STATUS="stop-cap"
  EXIT=21
elif (( PCT >= STOP )); then
  STATUS="stop"
  EXIT=20
elif (( PCT >= WARN )); then
  STATUS="warn"
  EXIT=10
else
  STATUS="ok"
  EXIT=0
fi

echo "status=$STATUS pct=$PCT source=$SOURCE five_hour=$FIVE_HOUR seven_day=$SEVEN_DAY spend=$SPEND"
exit "$EXIT"
