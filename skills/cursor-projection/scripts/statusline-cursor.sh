#!/usr/bin/env bash
#
# statusline-cursor.sh - Cursor CLI statusLine command: model, working directory, git branch,
# approval mode, and token/context usage. Cursor's counterpart to scripts/statusline.sh (Claude
# Code); the two are separate scripts, not a shared one, because a custom Cursor statusLine
# replaces Cursor's entire native footer rather than adding to it (model/context, working
# directory, branch, and approval-mode indicators all disappear otherwise - see
# references/harness-matrix.md's Status line section), so this script recreates what it can of
# that footer from the payload plus a git lookup, in addition to the Claude-Code-style context
# usage line the original script already had.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file's logic may be
# model-generated and is reviewed in full before commit; wiring it up via the "statusLine" key in
# ~/.cursor/cli-config.json is a separate, human step performed via `scripts/sync.sh` (apply mode,
# run by a human who has read this file) - not done by this script.
#
# Layout:
#   Opus 5 300K Medium  wd workspace  branch main  ctx [####------] 38% 114.2k/300k  out 45.6k
#   turn 1.2M cached / 200k written
#
# Field usage: Cursor's statusLine payload schema has no official documentation (confirmed
# 2026-07-31: cursor.com/docs/cli/reference/configuration only documents the
# display.showStatusLineRunningTime setting, not the payload shape). The fields below were
# confirmed by capturing two real payloads 2026-07-31 (one idle, one after a real turn), not from
# docs - treat anything not listed here as unconfirmed rather than assuming it doesn't exist:
#   .model.display_name, .model.param_summary        - confirmed; param_summary is sometimes
#                                                       already folded into display_name (deduped
#                                                       below)
#   .model.max_mode                                  - NOT observed in either capture (both were
#                                                       non-Max-Mode sessions) - (verify) whether
#                                                       this key exists at all when Max Mode is on,
#                                                       or whether Max Mode surfaces some other way
#   .cwd                                             - confirmed; workspace.current_dir carries an
#                                                       identical value, cwd is used since it's the
#                                                       shorter path
#   .autorun                                         - confirmed boolean; per a 2026-07 forum
#                                                       report this cannot distinguish Cursor's
#                                                       "Allowlist" and "Auto-review" approval
#                                                       modes, only whether autorun is on at all -
#                                                       treat the label below as coarser than the
#                                                       native footer's badge, not equivalent to it
#   .context_window.total_input_tokens,
#   .context_window.total_output_tokens,
#   .context_window.context_window_size,
#   .context_window.used_percentage                 - confirmed, same names Claude Code uses
#   .context_window.current_usage.input_tokens,
#   .context_window.current_usage.output_tokens,
#   .context_window.current_usage.cache_creation_input_tokens,
#   .context_window.current_usage.cache_read_input_tokens
#                                                     - confirmed; cache_* names are identical to
#                                                       Claude Code's - Cursor does not use
#                                                       camelCase variants for these fields
# No cost or rate-limit field of any kind was present in either capture - Cursor's statusLine
# payload appears to have no equivalent of Claude Code's `.cost`/`.rate_limits`, and there is no
# effort/thinking-level field either. No PR indicator is present or derivable without an extra
# network call (a `gh` lookup), which this script deliberately does not make on every render.
#
# Not carried over from statusline.sh (Claude Code): an env row (version/org/cwd), session
# length + cost-escalation coloring, and a limits/usage row. Each is absent because the underlying
# data doesn't exist in this payload, not because of a stylistic choice:
#   - .version           - never seen in either capture; adding it would be a guess, not a fact
#   - org/account         - no Cursor equivalent of Claude Code's ~/.claude.json oauthAccount has
#                           been verified to exist
#   - session length      - no field of any kind for elapsed/duration time (part of the missing
#                           .cost object noted above)
#   - session cost + its $1/$3/$5 color escalation - same reason, no .cost.total_cost_usd
#   - limits/usage row    - no .rate_limits object at all (see above)
#
# The cache-write/read color convention DOES carry over: cache_creation_input_tokens is confirmed
# present above, and the turn-cache line surfaces it next to the read figure, under the same DIM
# baseline / yellow-at-2M convention already used for read, rather than introducing a new color
# for it.
#
# Git branch is not in the payload at all, so it is derived here with one `git` call per render
# against `.cwd` - cheap (same cost any git-aware shell prompt already pays) and silently empty
# outside a git repo or in detached HEAD, which just omits that item.
#
# The context percentage is colored green under 50%, yellow at 50-79%, red at 80%+. The per-turn
# cache read/write figures turn yellow when either exceeds 2M tokens, the point where a single
# turn starts costing dollars rather than cents. The autorun indicator only renders when true,
# matching this script's existing convention of showing a flag item only in its "on" state.
#
# Performance: this script runs on every statusLine render (Cursor's updateIntervalMs governs how
# often, set separately in cli-config.json). One jq call against the small stdin payload, one git
# call, no network calls, no loop over the transcript or any other large file.
#
set -uo pipefail  # deliberately not -e: a single missing/null field must never abort the script
                  # and blank the status line - every extraction below already tolerates absence

payload=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

# \x1f (ASCII unit separator) joins the fields below, not a tab: bash's `read` treats tab as IFS
# whitespace regardless of what IFS is set to, so consecutive empty fields (param_summary and
# max_mode are both routinely empty together) would collapse and silently shift every field after
# them. Passed in via --arg rather than written as a literal control byte in the jq program text,
# which some tooling flags or mangles.
unit_sep=$(printf '\x1f')
fields=$(
  printf '%s' "$payload" | jq -r --arg sep "$unit_sep" '
    def num($v): if ($v | type) == "number" then $v else 0 end;
    def obj($v): if ($v | type) == "object" then $v else {} end;
    obj(.context_window.current_usage) as $cu
    | [ (.model.display_name // "?"),
        (.model.param_summary // ""),
        (if .model.max_mode == true then "MAX" else "" end),
        (num(.context_window.used_percentage) | floor),
        num(.context_window.context_window_size),
        num(.context_window.total_input_tokens),
        num(.context_window.total_output_tokens),
        num($cu.cache_read_input_tokens),
        num($cu.cache_creation_input_tokens),
        num($cu.input_tokens),
        num($cu.output_tokens),
        (.cwd // ""),
        (if .autorun == true then "1" else "0" end)
      ]
    | join($sep)' 2>/dev/null
) || exit 0
[ -n "$fields" ] || exit 0

IFS=$'\x1f' read -r model params max_mode pct ctx_size total_in total_out turn_cache turn_write \
  turn_in turn_out cwd autorun <<<"$fields"

hum() {
  local t=${1:-0}
  if [ "$t" -ge 1000000 ]; then
    printf '%d.%dM' $((t / 1000000)) $(((t % 1000000) / 100000))
  elif [ "$t" -ge 1000 ]; then
    printf '%d.%dk' $((t / 1000)) $(((t % 1000) / 100))
  else
    printf '%d' "$t"
  fi
}

DIM=$'\033[90m'
RESET=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'

# Context bar.
width=10
filled=$((pct * width / 100))
[ "$filled" -gt "$width" ] && filled=$width
[ "$filled" -lt 0 ] && filled=0
bar=""
for ((i = 0; i < filled; i++)); do bar+="#"; done
for ((i = filled; i < width; i++)); do bar+="-"; done

if [ "$pct" -ge 80 ]; then
  pct_color=$RED
elif [ "$pct" -ge 50 ]; then
  pct_color=$YELLOW
else
  pct_color=$GREEN
fi

# Model, skipping a param summary already contained in the display name.
label="$model"
if [ -n "$params" ] && [[ "$model" != *"$params"* ]]; then
  label="$label $params"
fi
[ -n "$max_mode" ] && label="$label $max_mode"

# Working directory, shown as its leaf name (the full path is already visible in the shell prompt
# most of the time, and the native footer this replaces showed a short form too).
wd_name=""
[ -n "$cwd" ] && wd_name="${cwd##*/}"

# Git branch: not in the payload, derived here. Empty and silently omitted outside a git repo or
# in detached HEAD (git prints nothing for --show-current in the latter case).
branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
fi

line="${CYAN}${label}${RESET}"
[ -n "$wd_name" ] && line+="  ${DIM}wd${RESET} ${wd_name}"
[ -n "$branch" ] && line+="  ${DIM}branch${RESET} ${branch}"
[ "$autorun" == "1" ] && line+="  ${GREEN}auto${RESET}"
line+="  ${DIM}ctx${RESET} ${pct_color}[${bar}] ${pct}%${RESET}"
line+=" ${DIM}$(hum "$total_in")/$(hum "$ctx_size")${RESET}"

[ "$total_out" -gt 0 ] && line+="  ${DIM}out $(hum "$total_out")${RESET}"

if [ "$turn_cache" -gt 0 ] || [ "$turn_write" -gt 0 ]; then
  cache_color=$DIM
  { [ "$turn_cache" -ge 2000000 ] || [ "$turn_write" -ge 2000000 ]; } && cache_color=$YELLOW
  cache_label="turn $(hum "$turn_cache") cached"
  [ "$turn_write" -gt 0 ] && cache_label="$cache_label / $(hum "$turn_write") written"
  line+="  ${cache_color}${cache_label}${RESET}"
elif [ "$turn_in" -gt 0 ] || [ "$turn_out" -gt 0 ]; then
  line+="  ${DIM}turn $(hum "$turn_in") in / $(hum "$turn_out") out${RESET}"
fi

printf '%s' "$line"
