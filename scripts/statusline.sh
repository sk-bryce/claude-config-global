#!/usr/bin/env bash
#
# statusline.sh - Claude Code statusLine command. One line per contextual group (environment,
# harness identity, session, context window, cache, account limits, git working state), rendered in
# that order: each row's title is set off from its items by a dim ">" (ROW_SEP), and items within a
# row are separated by a dim "|" (SEP) - two different dividers so "this is the row label" and
# "these are sibling items" stay visually distinct at a glance. Labels are dim, values are bold and
# color-coded so the numbers that matter jump out. The context row's window% is colored by raw token
# count (not the percentage itself), since the same percentage means very different absolute token
# counts on a 200k vs. a 1m window; its total turns red with a trailing "!" when exceeds_200k_tokens
# is true.
#
# Each row's at-rest value color comes from a single ROW_*_BASE variable (see the block below the
# palette): change one assignment there and that whole row re-colors, with no need to find every
# item on it. Alert colors are deliberately NOT part of a base - that block documents the boundary,
# and each row's own comment says why it sits where it does. The scaffolding around the data - row
# titles, the label half of every item, and the ">" / "|" dividers themselves - gets the same
# single-place treatment one block earlier, via ROW_TITLE_COLOR / ITEM_LABEL_COLOR /
# ITEM_MUTED_COLOR / ROW_SEP_COLOR / ITEM_SEP_COLOR.
#
# Row titles are padded to a fixed width (pad_label/ROW_LABEL_WIDTH) so the ">" lines up in the
# same column on every row, and each row's items are padded to match the widest item at that same
# column position across all rows on this render (align_columns) so the "|" dividers line up too -
# within an item, the label stays left-justified and the value is right-justified against that
# column width, so labels and values each line up on their own edge. See align_columns' own
# comment for why this is recomputed fresh every render rather than assumed fixed, and for the
# bash-3.2 constraints (no namerefs/associative arrays on macOS's system bash) that shaped how row
# arrays are threaded through it.
#
# CCSTATUS_VSYNC=0 turns off that item-column alignment (align_columns) while leaving the row-label
# alignment above untouched - i.e. the ">" still lines up down the left edge, but items within a
# row are just joined with SEP as-is, unpadded. Unset (the default) or any value other than "0"
# keeps the fully-aligned behavior described above.
#
# CCSTATUS_COLUMNS=<n> overrides the terminal width the error row at the bottom wraps to (see
# term_width for why that width has to be discovered rather than read off the payload). Unset (the
# default) asks the controlling terminal and falls back to 80 when there is none; every other row
# ignores it, since only the error row carries free text long enough to need wrapping.
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file's logic may be
# model-generated and is reviewed in full before commit; wiring it up via the "statusLine" key in
# settings.json is a separate, human step (not done by this script).
#
# See skills/cursor-projection/scripts/statusline-cursor.sh for the Cursor projection of this data
# - a separate script, not a shared one, because the two harnesses' statusLine payloads use
# different field names for the same data (see
# skills/cursor-projection/references/harness-matrix.md's Status line section).
#
# Field usage verified 2026-07-31 against https://code.claude.com/docs/en/statusline (the
# "Available data" table, "Full JSON schema" accordion, and "Context window fields" section):
#   .version                                   - always present; Claude Code version string
#   .cwd                                       - always present; workspace.current_dir carries an
#                                                 identical value, cwd is used since it's the
#                                                 shorter path (same choice made in
#                                                 skills/cursor-projection/scripts/statusline-cursor.sh,
#                                                 see that script's header)
#   .model.display_name                        - always present
#   .effort.level                              - present only when the current model supports
#                                                 the effort parameter; absent otherwise
#   .thinking.enabled                          - whether extended thinking is on for the session
#   .fast_mode                                 - whether fast mode is on for the session. Top-level
#                                                 boolean (not an object like .thinking), and not
#                                                 listed among the docs' "fields that may be
#                                                 absent" - but it is still read null-tolerantly
#                                                 like every other field here, since fast mode is
#                                                 model-gated and older CLI versions predate the
#                                                 field entirely
#   .transcript_path                           - always present; path to this session's JSONL
#                                                 transcript, read once per render to derive the
#                                                 session row's "turns" item (see that item's own
#                                                 comment below for what counts as a turn and why)
#   .context_window.total_input_tokens         - input + cache_creation + cache_read, current
#                                                 context (this is also the denominator docs use
#                                                 for used_percentage, so it doubles as the cache
#                                                 hit-rate denominator below)
#   .context_window.total_output_tokens        - output tokens, current context
#   .context_window.used_percentage            - pre-calculated; docs say prefer this over
#                                                 recomputing it
#   .context_window.context_window_size        - max context window size in tokens (200000
#                                                 default, or 1000000 for extended-context models)
#   .context_window.current_usage.cache_read_input_tokens,
#   .context_window.current_usage.cache_creation_input_tokens
#                                               - cache read/write tokens for the current context
#   .cost.total_cost_usd                       - estimated session cost, resets to $0 on /clear
#   .cost.total_duration_ms                    - wall-clock time since the session started
#   .exceeds_200k_tokens                       - whether combined input+cache+output tokens from
#                                                 the most recent API response exceed 200k, a
#                                                 fixed threshold independent of context_window_size.
#                                                 Drives the context row's total item turning red
#                                                 with a trailing "!" - not shown anywhere else.
#   .rate_limits.five_hour.used_percentage,
#   .rate_limits.seven_day.used_percentage     - 0-100, percentage of that rate-limit window
#                                                 consumed. This is the account's real API window,
#                                                 not this CLI session - it survives /clear.
#   .rate_limits.five_hour.resets_at,
#   .rate_limits.seven_day.resets_at           - Unix epoch seconds; Claude.ai (Pro/Max) only,
#                                                 absent otherwise and independently per window.
#                                                 Cost-capped seats (e.g. enterprise
#                                                 usage-based billing) never send this object at
#                                                 all, verified by capturing this account's real
#                                                 statusLine payload.
# All of the above except model.display_name may be null/absent (early in a session, right after
# /compact, on non-effort models, or on non-subscription accounts) - every extraction below
# tolerates that and simply omits the affected item or line.
#
# organization: not in the statusLine JSON payload at all (confirmed against the docs' full field
# list above) - read once per render from .claude.json's .oauthAccount object instead, the same
# config file Claude Code itself uses for OAuth session state (per the "Settings files" docs:
# "Other configuration is stored in ~/.claude.json ... your OAuth session ..."). This is NOT the
# credentials file (no tokens live here). .claude.json DOES move when CLAUDE_CONFIG_DIR is set -
# confirmed by comparing a stock ~/.claude.json against a CLAUDE_CONFIG_DIR-scoped one side by
# side, which turned out to hold two distinct real oauthAccount identities rather than the same
# file twice - so the path is built from config_dir below, same principle as get_usage_token's
# paths but a different fallback base: unset CLAUDE_CONFIG_DIR defaults .claude.json to $HOME
# directly (a sibling of the ~/.claude directory), not to $HOME/.claude the way settings.json,
# scripts/, and .credentials.json do.
# .oauthAccount.organizationName - absent for an individual (non-org) account, or if there's no
#                                   oauthAccount at all (API-key auth, no Claude.ai login), which
#                                   omits the "org" item exactly like every other extraction here.
#
# git row: also not in the statusLine payload - derived from .cwd, and present only when that
# directory is inside a git work tree (the row is omitted entirely otherwise, the same way any
# other row with zero items is dropped). Two git invocations per render, and no more:
#   git -C <cwd> rev-parse --is-inside-work-tree --git-dir
#       Cheap, and definitive about whether the rest of the row should run at all - so a non-repo
#       cwd (or a cwd inside a bare repo / inside .git itself, where --is-inside-work-tree is
#       false) pays only this one call and stops. The git dir it returns backs the worktree,
#       operation-state, and stash items below without any further git invocation. Note that
#       --git-common-dir is deliberately NOT asked for here; see the comment at that code for the
#       path-resolution trap it walks into.
#   git -C <cwd> status --porcelain=v2 --branch
#       The workhorse: one scan yields branch name, upstream, ahead/behind, and every changed path,
#       from which branch/sync/staged/dirty/new/conflict are all counted in a single awk pass. The
#       "# branch.*" headers are documented under "Porcelain Format Version 2" in git-status(1);
#       branch.upstream and branch.ab are BOTH absent when the branch has no upstream configured,
#       which is what the "sync none" rendering reports. branch.oid is "(initial)" before the first
#       commit and branch.head is "(detached)" on a detached HEAD, in which case the branch item
#       falls back to the short oid.
# Everything else on this row is read straight off the git directory rather than shelling out
# again: in-progress operation from rebase-merge/ + rebase-apply/ + MERGE_HEAD / CHERRY_PICK_HEAD /
# REVERT_HEAD / BISECT_LOG (all per-worktree, so they're looked for in the git dir), the branch a
# rebase is replaying from rebase-*/head-name, linked-worktree identity from the "commondir" file
# that only a linked worktree's git dir has, and the stash count from the refs/stash reflog under
# the common dir (stashes are shared across worktrees, not per-worktree). The stash count is gated
# on refs/stash itself existing, so a reflog left behind after the last stash was dropped can't
# report phantom entries.
#
# The one real cost here is `git status`, which scans the work tree: it is ~15ms on a small repo
# but can reach hundreds of ms on a large one without fsmonitor, and that lands on every render.
# There is deliberately no opt-out env var for it yet - add one (in the CCSTATUS_VSYNC style) if
# that actually turns out to be a problem in practice rather than in theory.
#
# limits row: which items it shows depends on account type, determined at render time rather than
# hardcoded. Pro/Max accounts have rate_limits populated (zero network calls needed), so the row
# shows that data's native shape: a "usage" item for the 5h window's percentage and a separate
# "weekly" item for the 7d window's percentage (split into two labeled items rather than two
# unlabeled numbers sharing one item, so which number is which is unambiguous at a glance), plus the
# reset countdown. Only once rate_limits comes back entirely absent - i.e. this is determined NOT to
# be a Pro/Max account - does the script fall back to fetching cost-capped-seat data from
# Anthropic's own (undocumented) usage API, the same approach the sirmalloc/ccstatusline project
# uses, rather than the statusLine stdin payload:
#   GET https://api.anthropic.com/api/oauth/usage
#   Authorization: Bearer <oauth access token>
#   anthropic-beta: oauth-2025-04-20
# The token is the same credential Claude Code itself already uses to authenticate, resolved by
# get_usage_token (see that function's own comment for the full precedence, which differs by OS
# and by whether CLAUDE_CONFIG_DIR is set). The
# response's top-level `.spend` object (`.used`/`.limit` as {amount_minor, currency, exponent},
# `.percent`, `.severity`) backs that fallback path's usage% / total / max items instead - there is
# no reset timestamp in this response, so accounts on this path show total/max in its place rather
# than a countdown. Only `.spend` is read here: this endpoint's own `five_hour`/`seven_day` objects
# are NOT what selects the path and must not be read as a proxy for it, having been observed both
# null (on the enterprise-usage-based response that motivated this fallback) and populated under
# this same config. What selects the path is solely whether the statusLine stdin payload carries
# `rate_limits`, because the harness knows which account is rendering and this script does not -
# and several accounts on different payment models share this config, so every render must be
# driven by that render's own payload rather than by an assumption about which account is in
# front of it.
# Falls back to "usage n/a" when neither source produces anything for a session that clearly has
# data, so a genuinely unsupported account type still reads as "not available" rather than
# looking broken. That "n/a" degradation is for the "no credential was ever expected here" case
# (e.g. pure API-key auth, no oauthAccount) - it is NOT what happens when a credential WAS expected
# and is missing; that case renders a red "usage withheld" instead, paired with the deliberately
# loud USAGE_TOKEN_ERROR row near the bottom of the script (see get_usage_token's own comment).
#
# Credential handling on that fallback path, stated explicitly because this file is public and the
# path reads a live OAuth token:
#   - The token is never rendered, echoed, or logged. It exists only as a local variable and as the
#     Authorization header of the single request above. The USAGE_TOKEN_ERROR row names the
#     Keychain service that was looked for, never the secret itself.
#   - Nothing token-derived is written to disk. The on-disk cache (CAP_CACHE_FILE) holds only the
#     response's spend JSON, and its directory is keyed by config directory so one profile's
#     response is never served to another.
#   - One caveat, not a leak but worth knowing: the header is passed as a curl argument, so the
#     token is briefly visible in that process's argv to anything on this machine that can already
#     read this user's process list.
#   - The endpoint is undocumented and can change or disappear without notice. Every failure path
#     here degrades to "usage n/a" or a withheld marker rather than guessing, and none of them
#     retries or falls back to another account's credential.
#
# Performance: this script runs on every statusLine render. It does one jq call against the small
# stdin payload, at most one more over the transcript and one over .claude.json (each skipped when
# that file is absent), and a handful of awk/date/git calls - no network call on any row, including
# the Pro/Max path of the limits row. The cost-capped-seat fallback is the sole exception: it disk-
# caches the spend response for CAP_CACHE_TTL seconds (see fetch_spend_json below) so the real
# network call - curl with a 3s timeout - happens at most once per cache window on accounts that
# need it at all, and a failed attempt is locked out for CAP_LOCK_TTL seconds so an offline machine
# doesn't retry every render either. Any failure (no token, no curl, timeout, bad response) fails
# open to stale cache or "".
#
set -uo pipefail  # deliberately not -e: a single missing/null field must never abort the script
                  # and blank the status line - every extraction below already tolerates absence

RESET='\033[0m'
BOLD='\033[1m'
GRAY='\033[90m'
LGRAY='\033[38;5;250m'
MGRAY='\033[38;5;244m'
BCYAN='\033[96m'
BBLUE='\033[94m'
BMAGENTA='\033[95m'
BGREEN='\033[92m'
BYELLOW='\033[93m'
ORANGE='\033[38;5;208m'
BRED='\033[91m'
WHITE='\033[97m'
# Deliberately its own literal rather than "$WHITE" (even though it's the same escape code today):
# the structural checks below scan for the literal $WHITE token to make sure a color a
# ROW_*_BASE points at is never ALSO hardcoded elsewhere, and the git row's neutral wt/stash items
# are hardcoded on purpose - they're independent of any base by design (see the git row base
# comment) and must stay that way even on a render where some row's base is reassigned to white
# too. A same-valued alias would still read as "$WHITE" to that textual scan and defeat the check
# it exists to run; a plain literal doesn't.
GIT_NEUTRAL_COLOR='\033[97m'

# Deliberately its own literal rather than "$BGREEN" (even though it's the same escape code
# today), for the same reason GIT_NEUTRAL_COLOR above is: the structural stray-color check scans
# for the literal $BGREEN token to confirm nothing besides a ROW_*_BASE expands it, and an alias
# would still read as "$BGREEN" to that textual scan. ESCALATION_BASE is the shared "healthy"
# floor for the one headline item per row that runs an escalation ladder - window% (context),
# hit% (cache), usage%/weekly% (limits), cost (session) - so all four read as unambiguously good
# together regardless of what color their row's own ROW_*_BASE happens to be set to.
ESCALATION_BASE='\033[92m'

# Structural colors - the single place to change how the scaffolding around the data reads, as
# opposed to the data itself (that's what the ROW_*_BASE block right below is for). Every row
# title, the label half of every "label value" item, each divider glyph, and every "there is
# nothing here" value draws from one of these five rather than a literal color scattered at each of
# their 45+ call sites - reassign one here and it re-colors everywhere that element appears. The
# two divider glyphs get their own variables rather than sharing one, since ">" (row title vs.
# items) and "|" (item vs. item) are deliberately different dividers (see the file header) and may
# want different colors.
#
# ITEM_MUTED_COLOR is the odd one out: it colors a VALUE rather than scaffolding - the claude row's
# "off" thinking and fast states, and the limits row's "n/a" fallback. It belongs here anyway,
# because what those three values are doing is receding, which is a scaffolding job even though the
# text sits in a value position. It points at the same palette entry as ITEM_SEP_COLOR (the
# dimmest thing on the line, so "off"/"n/a" sink below every real value without disappearing)
# rather than aliasing that variable, so the two can be re-aimed independently.
ROW_TITLE_COLOR="$BCYAN"    # env/claude/git/session/context/cache/limits
ITEM_LABEL_COLOR="$BBLUE"   # the label half of every item, e.g. "version" in "version 2.1.3"
ROW_SEP_COLOR="$LGRAY"      # the ">" between a row title and its items
ITEM_SEP_COLOR="$MGRAY"     # the "|" between sibling items
ITEM_MUTED_COLOR="$MGRAY"   # a value that means "nothing/neutral": thinking/fast "off", "n/a"
SEP=" ${ITEM_SEP_COLOR}|${RESET} "
ROW_SEP=" ${ROW_SEP_COLOR}>${RESET} "

# Per-row base value color - the single place to change a row's palette. Every item on a row draws
# its "nothing to flag here" color from its row's base below, so reassigning one of these to another
# palette entry above re-colors that whole row.
#
# What a base does NOT cover, deliberately:
#   - Escalations. BYELLOW/ORANGE/BRED are shared alert colors that mean the same thing on every
#     row, so they're written literally at each threshold rather than derived from a base. Most of
#     a row's other, non-escalating items still follow the base - e.g. the cache row's read/write
#     or the context row's in/out/max.
#   - The one headline item per row that runs a full escalation ladder - the context row's
#     window%, the cache row's hit%, the limits row's usage%/weekly%, and the session row's cost -
#     floors on ESCALATION_BASE instead of that row's own base, so all four read as unambiguously
#     good together regardless of what color the row itself is set to.
#   - The git row's GIT_NEUTRAL_COLOR items (wt, stash), which are neutral context rather than
#     state: they mark "you should know this" without claiming anything is good or bad, so they
#     sit outside the ladder that ROW_GIT_BASE floors.
#   - Row titles, which use ROW_TITLE_COLOR on every row regardless (see the structural-colors
#     block above).
ROW_ENV_BASE="$WHITE"
ROW_CLAUDE_BASE="$WHITE"
ROW_GIT_BASE="$BGREEN"        # the clean/at-rest floor of the git row's escalation ladder
ROW_SESSION_BASE="$WHITE"
ROW_CONTEXT_BASE="$WHITE"
ROW_CACHE_BASE="$WHITE"
ROW_LIMITS_BASE="$WHITE"

# Row-title width: pad env/claude/git/session/context/cache/limits to the same width so the ">"
# divider (and every item after it) starts in the same column on every row. 7 = length of the
# longest label ("session"/"context").
ROW_LABEL_WIDTH=7
pad_label() {
  printf '%-*s' "$ROW_LABEL_WIDTH" "$1"
}

# Terminal width, used only by the wrapped error row at the bottom of this script. It has to be
# discovered rather than read: the statusLine JSON payload carries no width field (checked against
# the CLI's payload builder), and this script's stdout is a pipe, so `tput cols` answers terminfo's
# 80 rather than the real terminal. Asking the controlling terminal directly is the one reading
# that is actually right; 80 is the fallback when there is no tty to ask (a non-interactive render,
# or the test harness). CCSTATUS_COLUMNS outranks both - statusline-tests/run.sh pins it so its
# wrap assertions don't depend on the terminal the suite happens to run in.
term_width() {
  local cols="${CCSTATUS_COLUMNS-}"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS-}"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  printf '%s' "$cols"
}

input="$(cat)"

# Fail open: no jq, or stdin that isn't the JSON we expect - print a minimal line rather than
# nothing (a blank status line reads as broken; a script exiting non-zero also blanks it per the
# docs' troubleshooting section).
if ! command -v jq >/dev/null 2>&1; then
  echo "[claude]"
  exit 0
fi

fields="$(printf '%s' "$input" | jq -r '
  [
    (.version // ""),
    (.cwd // ""),
    (.model.display_name // "?"),
    (.effort.level // ""),
    (.thinking.enabled | if . == null then "" elif . then "1" else "0" end),
    (.fast_mode | if . == null then "" elif . then "1" else "0" end),
    (.transcript_path // ""),
    (.context_window.total_input_tokens // ""),
    (.context_window.total_output_tokens // ""),
    (.context_window.used_percentage // ""),
    (.context_window.current_usage.cache_read_input_tokens // ""),
    (.context_window.current_usage.cache_creation_input_tokens // ""),
    (.context_window.context_window_size // ""),
    (.cost.total_cost_usd // ""),
    (.cost.total_duration_ms // ""),
    (.exceeds_200k_tokens | if . == null then "" elif . then "1" else "0" end),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
  ] | join("\u001f")
' 2>/dev/null)"

if [[ -z "$fields" ]]; then
  echo "[claude]"
  exit 0
fi

# Split on \x1f (ASCII unit separator), not a tab: bash's `read` treats tab as IFS whitespace
# regardless of what IFS is set to, so consecutive tabs from an empty field would collapse and
# silently shift every field after it.
IFS=$'\x1f' read -r VERSION CWD MODEL EFFORT THINKING FAST TRANSCRIPT_PATH IN OUT PCT CACHE_READ \
  CACHE_WRITE CTXSIZE COST DURATION_MS EXCEEDS200K FIVEH_PCT FIVEH_RESET SEVEND_PCT SEVEND_RESET \
  <<< "$fields"

# Organization: not in the statusLine payload - read once per render from .claude.json's
# .oauthAccount, scoped by CLAUDE_CONFIG_DIR like every other config path here (see header comment
# for why this file lives inside config_dir rather than at a fixed $HOME location). Absent file,
# absent jq, or absent .oauthAccount all degrade to an empty field the same way every other
# missing field in this script does.
ORG_NAME=""
CLAUDE_JSON_PATH="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
if [[ -f "$CLAUDE_JSON_PATH" ]]; then
  # Newlines are stripped rather than kept: this is the one externally-supplied value that reaches
  # an item intact (CWD and friends are already cut short by the \x1f field read above, which stops
  # at the first newline), and a newline inside an item splits that row in two on the way through
  # align_columns, which desynchronizes every row label from its body.
  ORG_NAME="$(jq -r '.oauthAccount.organizationName // "" | gsub("[\n\r]"; " ")' \
    "$CLAUDE_JSON_PATH" 2>/dev/null)"
fi

# Set by get_usage_token() when running under a CLAUDE_CONFIG_DIR profile on macOS whose expected
# scoped Keychain entry is missing (see that function for why this is a hard error rather than a
# silent fallback). Rendered as a standalone red row after everything else - see the bottom of the
# script. Empty means "no error", same convention as every other optional field here.
#
# RESOLVED_TOKEN/USAGE_TOKEN_ERROR are both set by get_usage_token() via direct assignment rather
# than printed to stdout and captured with "$(get_usage_token)" - a command substitution runs in a
# subshell, and a subshell's variable assignments never propagate back to the caller, so anything
# get_usage_token() needs the rest of the script to see (the error in particular) has to be a real
# assignment made while get_usage_token is called as a plain statement, not wrapped in $(...). See
# get_usage_token's own comment and its call site for how that constraint is honored.
RESOLVED_TOKEN=""
USAGE_TOKEN_ERROR=""

# Auto-compaction capacity: not in the statusLine payload either, and not derivable from it - it
# comes from the environment, where settings.json's `env` block sets it. Empty when unset, which
# omits the context row's compact parenthetical entirely (see that row for why that is the default).
# Read unconditionally rather than guarded on jq or the payload, since it is independent of both.
AUTO_COMPACT_WINDOW="${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}"

# Git state: derived from CWD rather than the payload (see the "git row" note in the header comment
# for the two commands this runs, why the rev-parse probe comes first, and what the cost is).
# GIT_PRESENT stays 0 for a missing/non-repo cwd, a cwd inside .git or a bare repo, or a machine
# with no git at all, and every item below is then empty so the row drops out entirely.
GIT_PRESENT=0
GIT_BRANCH=""
GIT_OID=""
GIT_UPSTREAM=""
GIT_AHEAD=0
GIT_BEHIND=0
GIT_STAGED=0
GIT_DIRTY=0
GIT_NEW=0
GIT_CONFLICT=0
GIT_STASH=0
GIT_STATE=""
GIT_WORKTREE=""
GIT_REBASE_BRANCH=""

if [[ -n "$CWD" && -d "$CWD" ]] && command -v git >/dev/null 2>&1; then
  git_probe="$(git -C "$CWD" rev-parse --is-inside-work-tree --git-dir 2>/dev/null)"
  git_inside=""
  git_dir=""
  { read -r git_inside; read -r git_dir; } <<< "$git_probe"

  if [[ "$git_inside" == "true" && -n "$git_dir" ]]; then
    GIT_PRESENT=1
    # rev-parse reports --git-dir relative to its own working directory when it can (a plain ".git"
    # at a repo's top level, an absolute path from a subdirectory), so resolve it against CWD -
    # every filesystem probe below indexes off it, and this script's process cwd is wherever Claude
    # Code happened to launch it, not the repo.
    [[ "$git_dir" != /* ]] && git_dir="$CWD/$git_dir"

    # The common dir comes from the git dir's own "commondir" file rather than from rev-parse's
    # --git-common-dir: that option's relative output is relative to the repository top level, not
    # to rev-parse's working directory the way --git-dir's is, so resolving both the same way
    # mis-resolves the common dir whenever cwd is a subdirectory - which then reads as "these two
    # paths differ", i.e. a phantom linked worktree on every ordinary subdirectory of every repo.
    # "commondir" exists only inside a linked worktree's git dir, so its presence IS the test.
    git_common="$git_dir"
    if [[ -f "$git_dir/commondir" ]]; then
      git_common="$(<"$git_dir/commondir")"
      [[ "$git_common" != /* ]] && git_common="$git_dir/$git_common"
      GIT_WORKTREE="${git_dir##*/}"
    fi

    # One scan, one awk pass. XY in the "1"/"2" entry lines is <staged><worktree>, where "." means
    # unmodified in that half - so a file staged AND then edited again counts toward both staged
    # and dirty, which is the distinction worth seeing. "u" is unmerged, "?" untracked.
    git_fields="$(git -C "$CWD" status --porcelain=v2 --branch 2>/dev/null | awk '
      $1 == "#" {
        if ($2 == "branch.oid") oid = $3
        else if ($2 == "branch.head") head = $3
        else if ($2 == "branch.upstream") upstream = $3
        else if ($2 == "branch.ab") { ahead = $3 + 0; behind = -($4 + 0) }
        next
      }
      $1 == "1" || $1 == "2" {
        if (substr($2, 1, 1) != ".") staged++
        if (substr($2, 2, 1) != ".") dirty++
        next
      }
      $1 == "u" { conflict++; next }
      $1 == "?" { untracked++; next }
      END {
        printf "%s\x1f%s\x1f%s\x1f%d\x1f%d\x1f%d\x1f%d\x1f%d\x1f%d",
          oid, head, upstream, ahead, behind, staged, dirty, untracked, conflict
      }
    ')"
    if [[ -n "$git_fields" ]]; then
      IFS=$'\x1f' read -r GIT_OID GIT_BRANCH GIT_UPSTREAM GIT_AHEAD GIT_BEHIND GIT_STAGED \
        GIT_DIRTY GIT_NEW GIT_CONFLICT <<< "$git_fields"
    fi

    # `git status` can still fail after rev-parse succeeded - an unreadable index, a repo being
    # written to concurrently - and awk emits its zeroed default line either way. An empty branch
    # AND an empty oid is the signal that nothing was really parsed, so drop the row entirely
    # rather than render a "branch ?" that looks like a bug in the repo instead of a missed read.
    if [[ -z "$GIT_BRANCH" && -z "$GIT_OID" ]]; then
      GIT_PRESENT=0
    fi

    # In-progress operation, checked enclosing-operation-first. Verified on git 2.50.1 that these
    # don't actually collide today: a conflicted rebase leaves rebase-merge/ and REBASE_HEAD, a
    # conflicted cherry-pick leaves only CHERRY_PICK_HEAD, and a conflicted merge only MERGE_HEAD.
    # The ordering is kept regardless, because the sequencer backs several of these and an
    # interactive rebase running a "pick" is a cherry-pick internally - if a combination ever does
    # surface, the enclosing operation is the one whose abort command you need. Step counters are
    # read with $(<file) rather than cat to keep this section subprocess-free, and are used only
    # once they're actually numeric.
    if [[ -d "$git_dir/rebase-merge" ]]; then
      GIT_STATE="rebase"
      if [[ -f "$git_dir/rebase-merge/msgnum" && -f "$git_dir/rebase-merge/end" ]]; then
        git_step="$(<"$git_dir/rebase-merge/msgnum")"
        git_total="$(<"$git_dir/rebase-merge/end")"
        [[ "$git_step" =~ ^[0-9]+$ && "$git_total" =~ ^[0-9]+$ ]] && \
          GIT_STATE="rebase ${git_step}/${git_total}"
      fi
    elif [[ -d "$git_dir/rebase-apply" ]]; then
      # rebase-apply backs both `git am` and the old apply-based rebase; "applying" tells them
      # apart, and the two need different abort commands.
      if [[ -f "$git_dir/rebase-apply/applying" ]]; then
        GIT_STATE="am"
      else
        GIT_STATE="rebase"
      fi
      if [[ -f "$git_dir/rebase-apply/next" && -f "$git_dir/rebase-apply/last" ]]; then
        git_step="$(<"$git_dir/rebase-apply/next")"
        git_total="$(<"$git_dir/rebase-apply/last")"
        [[ "$git_step" =~ ^[0-9]+$ && "$git_total" =~ ^[0-9]+$ ]] && \
          GIT_STATE="${GIT_STATE} ${git_step}/${git_total}"
      fi
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
      GIT_STATE="merge"
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
      GIT_STATE="cherry-pick"
    elif [[ -f "$git_dir/REVERT_HEAD" ]]; then
      GIT_STATE="revert"
    elif [[ -f "$git_dir/BISECT_LOG" ]]; then
      GIT_STATE="bisect"
    fi

    # A rebase detaches HEAD, so git reports the branch as "(detached)" for its whole duration -
    # but the branch being rebased is recorded in head-name, and mid-rebase that name is the answer
    # to "where am I" worth showing, not the oid of whichever commit is currently being replayed.
    for git_head_file in "$git_dir/rebase-merge/head-name" "$git_dir/rebase-apply/head-name"; do
      [[ -f "$git_head_file" ]] || continue
      git_head_name="$(<"$git_head_file")"
      [[ -n "$git_head_name" ]] && GIT_REBASE_BRANCH="${git_head_name##*/}"
      break
    done

    # Stash count: the refs/stash reflog IS `git stash list`, one line per entry. Gated on the ref
    # existing so a reflog file left behind after the last stash was dropped reports 0, not stale
    # entries. Both live in the common dir - the stash is shared across linked worktrees.
    if [[ -f "$git_common/refs/stash" && -f "$git_common/logs/refs/stash" ]]; then
      GIT_STASH="$(wc -l < "$git_common/logs/refs/stash" 2>/dev/null | tr -d '[:space:]')"
      [[ "$GIT_STASH" =~ ^[0-9]+$ ]] || GIT_STASH=0
    fi

  fi
fi

# Turn count: not in the statusLine payload directly - derived from the JSONL transcript at
# TRANSCRIPT_PATH (one JSON object per line), read once per render via a single streaming jq pass
# (reduce over `inputs`, not -s/slurp, so the whole transcript never sits in memory at once - it
# can run to tens of thousands of lines by the end of a long session). That one pass produces all
# four numbers the "turns"/"msgs"/"batch" items need:
#   typed    - entries where type == "user" AND promptSource == "typed": that combination is
#              unique to a message actually submitted. Every tool-result Claude Code appends back
#              to the transcript is also type == "user", but carries no promptSource at all (its
#              content is the tool_result array, not something typed); an automated message
#              landing mid-session (e.g. a background task notification) reports promptSource ==
#              "system" instead. Filtering on "typed" excludes both, leaving exactly the count of
#              prompts sent this session. Local commands (/clear and friends) are excluded the
#              same way - they carry no promptSource either, since they never reach the model.
#              Backs the "turns" item.
#   asst     - every type == "assistant" entry, i.e. every model turn regardless of whether it
#              ended in a tool call or a final text reply. Backs the "msgs" item, shown as context
#              for how much of the session was the model working versus you typing.
#   calls    - every tool_use content block across all assistant entries (a single assistant turn
#              can contain more than one, e.g. parallel reads).
#   toolmsgs - assistant entries that contain at least one tool_use block, i.e. the subset of asst
#              that actually had a chance to batch. The "batch" item is calls / toolmsgs, not
#              calls / asst: dividing by every assistant turn, including plain-text-only replies
#              that never call a tool at all, would drag the average toward 1 regardless of how
#              well the tool-calling turns themselves batch. toolmsgs isolates exactly the
#              population capable of batching, so the ratio reflects batching discipline rather
#              than how chatty the session happened to be.
TURN_COUNT=""
TURN_ASST_COUNT=""
TURN_CALL_COUNT=""
TURN_TOOLMSGS_COUNT=""
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]] && command -v jq >/dev/null 2>&1; then
  turn_fields="$(jq -nr '
    reduce inputs as $line (
      {typed: 0, asst: 0, calls: 0, toolmsgs: 0};
      if ($line.type == "user" and $line.promptSource == "typed") then .typed += 1
      elif ($line.type == "assistant") then
        ([$line.message.content[]? | select(.type == "tool_use")] | length) as $n
        | .asst += 1
        | .calls += $n
        | .toolmsgs += (if $n > 0 then 1 else 0 end)
      else . end
    ) | "\(.typed)\(.asst)\(.calls)\(.toolmsgs)"
  ' "$TRANSCRIPT_PATH" 2>/dev/null)"
  if [[ -n "$turn_fields" ]]; then
    IFS=$'\x1f' read -r TURN_COUNT TURN_ASST_COUNT TURN_CALL_COUNT TURN_TOOLMSGS_COUNT <<< "$turn_fields"
  fi
  [[ "$TURN_COUNT" =~ ^[0-9]+$ ]] || TURN_COUNT=""
  [[ "$TURN_ASST_COUNT" =~ ^[0-9]+$ ]] || TURN_ASST_COUNT=""
  [[ "$TURN_CALL_COUNT" =~ ^[0-9]+$ ]] || TURN_CALL_COUNT=""
  [[ "$TURN_TOOLMSGS_COUNT" =~ ^[0-9]+$ ]] || TURN_TOOLMSGS_COUNT=""
fi

# Formats a raw token count as e.g. "15.5k" / "1.2m"; "-" for missing/non-numeric input.
#
# The fractional digit is TRUNCATED, not rounded, and computed in integer arithmetic (tenths of the
# unit) rather than as a float. Rounding was actively misleading here: %.1f turned 59999 into
# "60.0k", i.e. a number claiming a threshold the color tiers - which read the raw count, not this
# string - had deliberately not crossed, and 999999 into the nonsensical "1000.0k". Truncating also
# keeps the trailing ".0" from contradicting the integral case in the line below it, and doing the
# arithmetic on integers sidesteps the binary-float trap in the obvious int(v * 10) / 10 spelling
# (10700 / 1000 is 10.699999... in a double, so that form prints "10.6k").
fmt_tokens() {
  local n="$1"
  if [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]]; then
    echo "-"
    return
  fi
  awk -v n="$n" 'BEGIN {
    if (n >= 1000000) { tenths = int(n / 100000); unit = "m" }
    else if (n >= 1000) { tenths = int(n / 100); unit = "k" }
    else { printf "%d", n; exit }
    if (tenths % 10 == 0) printf "%d%s", tenths / 10, unit;
    else printf "%d.%d%s", int(tenths / 10), tenths % 10, unit;
  }'
}

# Formats a countdown in seconds as "Xd Yh" / "Xh Ym" / "Xm"; "now" once the deadline has passed.
fmt_duration() {
  local secs="$1"
  if [[ -z "$secs" || ! "$secs" =~ ^[0-9]+$ ]]; then
    echo ""
    return
  fi
  local now
  now="$(date +%s)"
  local delta=$((secs - now))
  if [[ "$delta" -le 0 ]]; then
    echo "now"
    return
  fi
  local days=$((delta / 86400))
  local hours=$(((delta % 86400) / 3600))
  local mins=$(((delta % 3600) / 60))
  if [[ "$days" -gt 0 ]]; then
    echo "${days}d ${hours}h"
  elif [[ "$hours" -gt 0 ]]; then
    echo "${hours}h ${mins}m"
  else
    echo "${mins}m"
  fi
}

# Formats elapsed milliseconds as "Xd Yh" / "Xh Ym" / "Xm" / "Xs"; "" for missing/non-numeric
# input. Seconds-only granularity is kept for sessions under a minute old.
fmt_elapsed() {
  local ms="$1"
  if [[ -z "$ms" || ! "$ms" =~ ^[0-9]+$ ]]; then
    echo ""
    return
  fi
  local secs=$((ms / 1000))
  if [[ "$secs" -lt 60 ]]; then
    echo "${secs}s"
    return
  fi
  local mins=$((secs / 60))
  local hours=$((mins / 60))
  mins=$((mins % 60))
  if [[ "$hours" -ge 24 ]]; then
    local days=$((hours / 24))
    hours=$((hours % 24))
    echo "${days}d ${hours}h"
  elif [[ "$hours" -gt 0 ]]; then
    echo "${hours}h ${mins}m"
  else
    echo "${mins}m"
  fi
}

# Truncates a string to at most $2 characters, replacing the tail with "..." (ASCII, per this
# repo's no-Unicode-typography convention) when it's longer; returned unchanged otherwise.
truncate_ellipsis() {
  local s="$1"
  local max="$2"
  if [[ "${#s}" -le "$max" ]]; then
    printf '%s' "$s"
    return
  fi
  printf '%s...' "${s:0:$((max - 3))}"
}

# Joins non-empty arguments with the given separator, skipping empty ones.
join_with() {
  local sep="$1"
  shift
  local out="" item
  for item in "$@"; do
    [[ -z "$item" ]] && continue
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="${out}${sep}${item}"
    fi
  done
  printf '%s' "$out"
}

# Joins non-empty arguments with a single space, for sub-parts within one item.
join_words() {
  join_with " " "$@"
}

# Formats one rate-limit percentage with its color tier (green below 65%, yellow at 65%+,
# red at 85%+); "" for missing/non-numeric input. Shared by both the 5h and 7d values in
# build_usage_item. The healthy tier is ESCALATION_BASE rather than ROW_LIMITS_BASE, same as this
# row's other escalation ladder (usage_item below) - usage and weekly are the same kind of
# percentage on the same ladder, just different windows, so they read consistently together.
fmt_rate_pct() {
  local pct="$1"
  [[ -z "$pct" ]] && return
  local p="${pct%%.*}"
  [[ "$p" =~ ^[0-9]+$ ]] || return
  local c="$ESCALATION_BASE"
  [[ "$p" -ge 65 ]] && c="$BYELLOW"
  [[ "$p" -ge 85 ]] && c="$BRED"
  printf '%s' "${BOLD}${c}${p}%${RESET}"
}

# Builds the "usage" item: the 5h rate-limit percentage (color-coded via fmt_rate_pct). "" when
# absent.
build_usage_item() {
  local pct
  pct="$(fmt_rate_pct "$1")"
  [[ -z "$pct" ]] && return
  printf '%s' "${ITEM_LABEL_COLOR}usage${RESET} ${pct}"
}

# Builds the "weekly" item: the 7d rate-limit percentage, split out from "usage" into its own
# labeled item (rather than a second unlabeled number tacked onto "usage") so the 5h and 7d
# figures are unambiguous at a glance. Same color escalation as usage, via the shared
# fmt_rate_pct. "" when absent.
build_weekly_item() {
  local pct
  pct="$(fmt_rate_pct "$1")"
  [[ -z "$pct" ]] && return
  printf '%s' "${ITEM_LABEL_COLOR}weekly${RESET} ${pct}"
}

# Builds the "reset" item: 5h/7d rate-limit reset countdowns. Degrades to whichever window is
# present; "" when neither is.
build_reset_item() {
  local fiveh_resets="$1" sevend_resets="$2"
  local sub_5h="" sub_7d="" countdown
  countdown="$(fmt_duration "$fiveh_resets")"
  [[ -n "$countdown" ]] && sub_5h="${ITEM_LABEL_COLOR}5h${RESET} ${BOLD}${ROW_LIMITS_BASE}${countdown}${RESET}"
  countdown="$(fmt_duration "$sevend_resets")"
  [[ -n "$countdown" ]] && sub_7d="${ITEM_LABEL_COLOR}7d${RESET} ${BOLD}${ROW_LIMITS_BASE}${countdown}${RESET}"
  local body
  body="$(join_words "$sub_5h" "$sub_7d")"
  [[ -z "$body" ]] && return
  printf '%s' "${ITEM_LABEL_COLOR}reset${RESET} ${body}"
}

# --- Cost-capped-seat spend fetch: see the header comment above for why this exists and what it
# calls.
#
# The cache dir is scoped by CLAUDE_CONFIG_DIR (via a cksum key, same convention as
# link-recheck-hook.sh's state_dir keying - POSIX, no extra deps, and a collision here costs at
# most one account's spend response overwriting another's for one TTL window, not a correctness
# bug worth a stronger hash) rather than living at one fixed path: unlike .claude.json, this
# directory is the SCRIPT's own cache, not something Claude Code itself reads or writes, so
# nothing forces a fixed location the way .claude.json's is forced. A fixed shared path would let
# one account's cached spend response answer for another account's render whenever CLAUDE_CONFIG_DIR
# switches between them within CAP_CACHE_TTL, which defeats the whole point of the cache being
# per-account. Empty CLAUDE_CONFIG_DIR (the default account) still gets its own stable key, same as
# any other value.
CAP_CACHE_KEY="$(printf '%s' "${CLAUDE_CONFIG_DIR:-default}" | cksum | tr -d ' ' | tr '/' '_')"
CAP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline/$CAP_CACHE_KEY"
CAP_CACHE_FILE="$CAP_CACHE_DIR/spend.json"
CAP_LOCK_FILE="$CAP_CACHE_DIR/spend.lock"
CAP_CACHE_TTL=180
CAP_LOCK_TTL=30

# Portable mtime-in-seconds: macOS/BSD stat and GNU stat take different flags for the same thing.
file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

# Resolves the same OAuth access token Claude Code itself uses, without ever printing it to
# stdout. Must be called as a plain statement ("get_usage_token", never "$(get_usage_token)") -
# see the RESOLVED_TOKEN/USAGE_TOKEN_ERROR declaration above for why. Sets RESOLVED_TOKEN to the
# token (or "") and, on the specific hard-error condition below, USAGE_TOKEN_ERROR too.
#
# On macOS with CLAUDE_CONFIG_DIR set, Claude Code namespaces Keychain storage per profile, as
# service "Claude Code-credentials-<suffix>", where <suffix> is the first 8 hex characters of
# `printf '%s' "$CLAUDE_CONFIG_DIR" | shasum -a 256`. This is not documented anywhere
# (code.claude.com/docs/en/authentication.md's "Storage location" section just says "macOS:
# Keychain", full stop) and could change or stop matching in a future release without notice.
# A config-dir-scoped .credentials.json is never written on macOS at all (Claude Code ignores a
# valid, present .credentials.json there and re-prompts /login instead; see
# github.com/anthropics/claude-code/issues/29816), so the bare "Claude Code-credentials" entry is
# shared across every profile on that OS and cannot distinguish which profile is asking - reading
# it under a scoped profile would silently show one account's org label paired with another
# account's usage/limits data.
#
# Because the scoped-service naming is unverified/undocumented, and because showing the wrong
# account's data under another's label is the failure this scoping exists to prevent, a miss on
# the scoped lookup is a hard error rather than a silent fallback: when CLAUDE_CONFIG_DIR is set
# and running on macOS, only the scoped service name is tried. If it comes back empty AND this
# profile's own .claude.json already has an oauthAccount (ORG_NAME non-empty - i.e. this profile
# has completed a real login, so a scoped entry should exist), USAGE_TOKEN_ERROR is set and the
# function returns "" without falling back to the bare Keychain entry or to .credentials.json (the
# latter is a no-op on macOS per the issue above, and both would risk showing the wrong account's
# data). See the bottom of the script for where USAGE_TOKEN_ERROR is rendered. If ORG_NAME is empty
# (no oauthAccount at all - e.g. API-key-only auth, no login under this profile), a missing scoped
# entry is expected, not an error - it degrades to "" the same as any other genuinely-not-applicable
# field.
#
# When CLAUDE_CONFIG_DIR is unset (the default/no-profile account) on macOS, the bare
# "Claude Code-credentials" entry is tried instead, since there is no profile to scope by and
# nothing for it to disagree with.
#
# Non-macOS needs none of this: CLAUDE_CONFIG_DIR already scopes .credentials.json at the OS level
# there (confirmed in the docs' "Storage location" section for Linux/Windows), so the file-based
# lookup below is correct on its own and Keychain never enters into it.
#
# An alternative approach - pinning each profile to its own CLAUDE_CODE_OAUTH_TOKEN (minted
# per-account via `claude setup-token`, which docs confirm outranks the Keychain-derived /login
# credential in Claude Code's own auth precedence), stored per-profile and exported by each shell
# alias - would need real secret management (a Keychain entry per profile under a service name this
# repository mints, referenced from shell config) for comparatively little gain over the
# per-profile Keychain scoping above, which fixes the display-layer issue directly with no separate
# credential to provision, rotate, or lose track of. Worth reconsidering only if a future finding
# shows the sha256 scoping above is unreliable in some case this comment doesn't anticipate.
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

# Returns the raw spend/extra-usage API response (cached), or "" on any failure - callers treat
# absence exactly like "this account has no cap data available", not as an error to surface.
#
# Reads RESOLVED_TOKEN/USAGE_TOKEN_ERROR rather than calling get_usage_token() itself: this
# function is invoked as "$(fetch_spend_json)" (see call site), a subshell, so get_usage_token
# would need to run inside that same subshell and its USAGE_TOKEN_ERROR assignment would be lost
# the moment the subshell exits - the caller already ran get_usage_token as a plain statement
# beforehand for exactly this reason.
#
# Exception: a USAGE_TOKEN_ERROR (credential-resolution hard error, see get_usage_token's comment)
# skips the cache entirely, fresh or stale, and returns "" unconditionally. The on-disk cache is
# keyed by CLAUDE_CONFIG_DIR, not by account identity, so before this fix it could easily hold a
# DIFFERENT account's spend response - e.g. this exact account's cache was populated earlier via
# the old bare-Keychain fallback and needed to be cleared as part of this fix. Serving it here,
# even briefly past the fix, would silently reproduce the original bug.
fetch_spend_json() {
  # The withhold check comes before everything else, mkdir included: a profile whose credential
  # could not be resolved should leave no trace of a cache it is never allowed to read or write.
  [[ -n "$USAGE_TOKEN_ERROR" ]] && return
  command -v curl >/dev/null 2>&1 || return
  mkdir -p "$CAP_CACHE_DIR" 2>/dev/null

  local token="$RESOLVED_TOKEN"

  if [[ -f "$CAP_CACHE_FILE" ]]; then
    local cache_mtime cache_age
    cache_mtime="$(file_mtime "$CAP_CACHE_FILE")"
    if [[ "$cache_mtime" =~ ^[0-9]+$ ]]; then
      cache_age=$(( $(date +%s) - cache_mtime ))
      if [[ "$cache_age" -lt "$CAP_CACHE_TTL" ]]; then
        cat "$CAP_CACHE_FILE"
        return
      fi
    fi
  fi

  if [[ -f "$CAP_LOCK_FILE" ]]; then
    local lock_mtime lock_age
    lock_mtime="$(file_mtime "$CAP_LOCK_FILE")"
    if [[ "$lock_mtime" =~ ^[0-9]+$ ]]; then
      lock_age=$(( $(date +%s) - lock_mtime ))
      if [[ "$lock_age" -lt "$CAP_LOCK_TTL" ]]; then
        [[ -f "$CAP_CACHE_FILE" ]] && cat "$CAP_CACHE_FILE"
        return
      fi
    fi
  fi

  if [[ -z "$token" ]]; then
    [[ -f "$CAP_CACHE_FILE" ]] && cat "$CAP_CACHE_FILE"
    return
  fi

  # Lock before the network call (not after a failure) so concurrent renders started while a
  # request is in flight also back off, instead of each independently hitting the API.
  touch "$CAP_LOCK_FILE" 2>/dev/null

  local response
  response="$(curl -s --max-time 3 --connect-timeout 2 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)"

  if [[ -n "$response" ]] && printf '%s' "$response" | jq -e '.spend' >/dev/null 2>&1; then
    printf '%s' "$response" > "$CAP_CACHE_FILE" 2>/dev/null
    rm -f "$CAP_LOCK_FILE" 2>/dev/null
    printf '%s' "$response"
    return
  fi

  [[ -f "$CAP_CACHE_FILE" ]] && cat "$CAP_CACHE_FILE"
}

# Formats a {amount_minor, exponent} money pair as e.g. "$5.22" ("USD" gets a "$" symbol, any
# other currency code is printed as-is before the amount).
format_currency_minor() {
  local currency="$1" amount_minor="$2" exponent="$3"
  local symbol="$currency"
  [[ "$currency" == "USD" ]] && symbol='$'
  printf '%s%s' "$symbol" "$(awk -v n="$amount_minor" -v e="$exponent" \
    'BEGIN { printf "%.2f", n / (10 ^ e) }')"
}

# Builds the cost-capped-seat fallback's three items from a spend API response - usage%, total
# (dollars currently used), and max (the dollar limit) - as a \x1f-joined triple the caller splits
# with IFS, same convention as the main field extraction above. Colored by the API's own severity
# classification (normal/warning/critical) rather than reinvented thresholds - whatever Anthropic
# itself considers the risk tier is the one shown. Each of the three is independently "" when its
# own source field is missing; all three come back "" when spend reporting is disabled for this
# account/seat, or the response is empty/malformed.
build_spend_items() {
  local spend_json="$1"
  if [[ -z "$spend_json" ]]; then
    printf '\x1f\x1f'
    return
  fi

  local fields
  fields="$(printf '%s' "$spend_json" | jq -r '
    if (.spend.enabled // false) then
      [
        (.spend.percent // ""),
        (.spend.severity // ""),
        (.spend.used.amount_minor // ""),
        (.spend.used.exponent // 2),
        (.spend.used.currency // "USD"),
        (.spend.limit.amount_minor // ""),
        (.spend.limit.exponent // 2),
        (.spend.limit.currency // "USD")
      ] | join("\u001f")
    else empty end
  ' 2>/dev/null)"
  if [[ -z "$fields" ]]; then
    printf '\x1f\x1f'
    return
  fi

  local percent severity used_minor used_exp used_cur limit_minor limit_exp limit_cur
  IFS=$'\x1f' read -r percent severity used_minor used_exp used_cur limit_minor limit_exp \
    limit_cur <<< "$fields"

  local usage_item=""
  if [[ "$percent" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    local color="$ESCALATION_BASE"
    case "$severity" in
      warning) color="$BYELLOW" ;;
      critical|exceeded) color="$BRED" ;;
    esac
    usage_item="${ITEM_LABEL_COLOR}usage${RESET} ${BOLD}${color}${percent%%.*}%${RESET}"
  fi

  local total_item=""
  [[ -n "$used_minor" ]] && total_item="${ITEM_LABEL_COLOR}total${RESET} ${BOLD}${ROW_LIMITS_BASE}$(format_currency_minor \
    "$used_cur" "$used_minor" "$used_exp")${RESET}"

  local max_item=""
  [[ -n "$limit_minor" ]] && max_item="${ITEM_LABEL_COLOR}max${RESET} ${BOLD}${ROW_LIMITS_BASE}$(format_currency_minor \
    "$limit_cur" "$limit_minor" "$limit_exp")${RESET}"

  printf '%s\x1f%s\x1f%s' "$usage_item" "$total_item" "$max_item"
}

# Joins array elements with \x1f (ASCII unit separator - same convention the jq field split above
# uses), for handing a row's items to align_columns below.
join_us() {
  local sep=$'\x1f'
  local out="" item
  for item in "$@"; do
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="${out}${sep}${item}"
    fi
  done
  printf '%s' "$out"
}

# Builds one row's filtered (non-empty) item array in the caller-named array variable, skipping
# empty items exactly like join_with does. Uses eval-based indirection rather than a nameref
# (`local -n`, bash 4.3+) since macOS's system bash is 3.2.57 - confirmed via `bash --version`, no
# homebrew bash on PATH - which has neither namerefs nor associative arrays. arr_name is always one
# of this script's own hardcoded row-array names below, never external input.
build_row_items() {
  local arr_name="$1"
  shift
  eval "$arr_name=()"
  local item
  for item in "$@"; do
    [[ -z "$item" ]] && continue
    eval "$arr_name+=(\"\$item\")"
  done
}

# Reads rows on stdin (one per line, items \x1f-joined via join_us), pads every item to the
# widest item at that column position across ALL rows on stdin, and re-emits each row's items
# re-joined with SEP - so the "|" dividers line up vertically across rows. Column widths are
# recomputed fresh every call from whatever rows/items are actually present; there's no fixed
# schema, since which items a row has can change render to render (e.g. "effort" appears/
# disappears depending on the model).
#
# Label and value widths are tracked as two SEPARATE maximums per column, not one combined
# "widest item" maximum - so every value in a column starts at the same x position, one space
# past the column's longest label, regardless of how long that particular row's own label is.
# Tracking one combined width (the naive approach) only pins the item's overall length, not where
# the value inside it begins - a short label paired with a long value can reach the same overall
# length as a long label paired with a short value while its value starts in a completely
# different place. Tracking label/value widths independently fixes the start position: the value
# is then left-justified within its own (shared) value-width field, via trailing fill after the
# value rather than leading fill before it - so "Sonnet 5" and "Opus   " both begin at the same x
# position and every following "|" still lands in the same place.
#
# A row's own last item gets that same value-start alignment (it participates in lblw and gets
# the same leading gap) but never the trailing fill: there's no following "|" on that row to keep
# aligned, so the fill would only be invisible whitespace before the newline - harmless, but
# pointless bytes with nothing to show for them. Because of that, valw[i] itself only accumulates
# from items that are NOT their row's last item (lblw has no such restriction, since every row's
# value-start position is worth aligning, ending items included). A row that ends at column i has
# no trailing "|" to align, so its value length must not inflate the fill that OTHER rows' real
# separators at column i get pushed out to - otherwise an unrelated row's ending item forces every
# continuing row's separator wider than the columns actually in use require.
#
# This relies on every item being shaped "label value" with a single literal space as the
# separator: since \033[...m escape sequences never contain a space themselves, the first raw
# space in an item is always that label/value boundary, so a plain index() lookup finds it
# without needing to strip ANSI codes first to locate the split (stripping is still needed
# separately to measure visible width, below). "Visible width" strips the literal \033[...m
# pattern, not real ESC bytes: color codes are still literal backslash-escape text at this point
# in the script - printf '%b' only interprets them once, at the very end.
align_columns() {
  awk -F $'\x1f' -v sep="$SEP" '
    function strip(s) { gsub(/\\033\[[0-9;]*m/, "", s); return s }
    {
      n[NR] = NF
      for (i = 1; i <= NF; i++) {
        item[NR, i] = $i
        space_pos = index($i, " ")
        if (space_pos > 0) {
          lbl_len = length(strip(substr($i, 1, space_pos - 1)))
          val_len = length(strip(substr($i, space_pos + 1)))
        } else {
          lbl_len = length(strip($i))
          val_len = 0
        }
        if (lbl_len > lblw[i]) lblw[i] = lbl_len
        if (i < NF && val_len > valw[i]) valw[i] = val_len
      }
      if (NR > maxrow) maxrow = NR
    }
    END {
      for (r = 1; r <= maxrow; r++) {
        out = ""
        for (i = 1; i <= n[r]; i++) {
          it = item[r, i]
          space_pos = index(it, " ")
          if (space_pos > 0) {
            label_part = substr(it, 1, space_pos - 1)
            value_part = substr(it, space_pos + 1)
            lbl_pad = lblw[i] - length(strip(label_part))
            it = label_part sprintf("%*s", lbl_pad + 1, "") value_part
            if (i < n[r]) {
              val_pad = valw[i] - length(strip(value_part))
              it = it sprintf("%*s", val_pad, "")
            }
          }
          out = (i == 1) ? it : out sep it
        }
        print out
      }
    }
  '
}

# --- Line 0: env - help / org / cwd ---------------------------------------------------------------
# ROW_ENV_BASE throughout: these values are fixed for the whole session and never call for a
# reaction, so the color is doing identification work - which row am I looking at - rather than
# signaling anything, unlike the limits row's tiers. No item here escalates off the base.
#
# item_help restores one of the footer hints Claude Code stops drawing once a custom statusLine is
# configured. That suppression is not a setting - the footer's internal suppressHint flag is set
# from "is a statusLine command configured" - so the only way to get them back is to not have this
# script. Six hints go with it: "esc to interrupt", "? for shortcuts", "hold space to speak",
# "ctrl+t to show tasks", "down to manage", "enter to view memories". The badges beside them (task
# count, memory count, PR, IDE, mode label) sit outside that flag and still render, so what a
# statusLine costs is discoverability, not state - which is why one pointer at the shortcut panel
# covers the loss and the other five aren't reprinted here. "esc to interrupt" in particular must
# not be: it depends on whether Claude is generating right now, and no field in the statusLine
# payload carries that, so it could only ever be printed unconditionally (i.e. wrong most of the
# time). Verified 2026-08-20 against Claude Code 2.1.227's footer component and
# https://code.claude.com/docs/en/statusline.
#
# Shaped "label value" like every other item rather than as bare prose, so align_columns needs no
# special case for it (it splits each item at its first space) and so it sits in the same grid as
# the data around it instead of competing with it: a static pointer to a help panel is the least
# urgent thing on this row and should read that way. The label is kept short deliberately - at 9
# characters "shortcuts" became column 1's widest label and pushed every row's first value two
# columns right, where "help" fits inside "version" and costs the other rows nothing.
item_help="${ITEM_LABEL_COLOR}help${RESET} ${BOLD}${ROW_ENV_BASE}?${RESET}"
item_org=""
[[ -n "$ORG_NAME" ]] && item_org="${ITEM_LABEL_COLOR}org${RESET} ${BOLD}${ROW_ENV_BASE}$(truncate_ellipsis "$ORG_NAME" 20)${RESET}"
item_cwd=""
[[ -n "$CWD" ]] && item_cwd="${ITEM_LABEL_COLOR}cwd${RESET} ${BOLD}${ROW_ENV_BASE}${CWD}${RESET}"

# --- Line 1: claude - version / model / effort / thinking / fast ----------------------------------
# ROW_CLAUDE_BASE throughout: these are harness/model identity facts, fixed for the whole session
# and never call for a reaction, so the color is doing identification work - which row am I looking
# at - rather than signaling anything, unlike the limits row's tiers. No item here escalates off
# the base.
item_version=""
[[ -n "$VERSION" ]] && item_version="${ITEM_LABEL_COLOR}version${RESET} ${BOLD}${ROW_CLAUDE_BASE}${VERSION}${RESET}"
item_model="${ITEM_LABEL_COLOR}model${RESET} ${BOLD}${ROW_CLAUDE_BASE}${MODEL:-?}${RESET}"
item_effort=""
[[ -n "$EFFORT" ]] && item_effort="${ITEM_LABEL_COLOR}effort${RESET} ${BOLD}${ROW_CLAUDE_BASE}${EFFORT}${RESET}"
item_thinking=""
if [[ -n "$THINKING" ]]; then
  if [[ "$THINKING" == "1" ]]; then
    item_thinking="${ITEM_LABEL_COLOR}thinking${RESET} ${BOLD}${ROW_CLAUDE_BASE}on${RESET}"
  else
    item_thinking="${ITEM_LABEL_COLOR}thinking${RESET} ${BOLD}${ITEM_MUTED_COLOR}off${RESET}"
  fi
fi

# fast: same on/off rendering as thinking directly above (an "off" value recedes to
# ITEM_MUTED_COLOR rather than claiming the row base's identity color), since the two are the same
# kind of session-wide toggle read the same way. Omitted entirely when .fast_mode is absent - a CLI
# or model that has no such toggle should say nothing here rather than assert "off".
item_fast=""
if [[ -n "$FAST" ]]; then
  if [[ "$FAST" == "1" ]]; then
    item_fast="${ITEM_LABEL_COLOR}fast${RESET} ${BOLD}${ROW_CLAUDE_BASE}on${RESET}"
  else
    item_fast="${ITEM_LABEL_COLOR}fast${RESET} ${BOLD}${ITEM_MUTED_COLOR}off${RESET}"
  fi
fi

# --- Line 6: git - wt / state / conflict / sync / staged / dirty / new / stash / branch -----------
# Unlike every other row, this one has no flat base color: git's items ARE state, so they're
# colored by what they say, and ROW_GIT_BASE is only the bottom rung of that ladder - the color a
# clean, synced repo renders in. It reads "nothing to do"; yellow means "there is uncommitted or
# unpushed work here", red "this repo is mid-operation or mid-conflict and needs a decision before
# anything else". The branch value carries the whole row's worst state, so the branch name alone answers
# "is this repo OK?" without reading the counts.
#
# Item order front-loads the two items you must not miss (state, conflict) ahead of the routine
# counts. Every count is omitted at 0 rather than shown as "0", so a clean synced repo renders as
# just "sync ok | branch <name>" and anything more than that is a real signal.
#
# Branch comes LAST despite being the item you read first: it's the only git value whose width
# varies with the repo rather than the state, and column alignment pads every row to the widest
# cell in each column, so a long branch name in column 1 would push every other row's first
# column out by that much. Trailing position keeps that variance out of the shared columns.
item_git_branch=""
item_git_wt=""
item_git_state=""
item_git_conflict=""
item_git_sync=""
item_git_staged=""
item_git_dirty=""
item_git_new=""
item_git_stash=""
if [[ "$GIT_PRESENT" == "1" ]]; then
  git_color="$ROW_GIT_BASE"
  if [[ $((GIT_STAGED + GIT_DIRTY + GIT_NEW)) -gt 0 || "$GIT_AHEAD" -gt 0 || "$GIT_BEHIND" -gt 0 \
    || -z "$GIT_UPSTREAM" ]]; then
    git_color="$BYELLOW"
  fi
  if [[ "$GIT_CONFLICT" -gt 0 || -n "$GIT_STATE" ]]; then
    git_color="$BRED"
  fi

  # On a detached HEAD git reports the branch as the literal "(detached)", which says nothing about
  # where you are. A rebase is the common case and knows the real branch name; otherwise the short
  # oid at least locates you.
  git_branch_label="$GIT_BRANCH"
  if [[ "$GIT_BRANCH" == "(detached)" ]]; then
    if [[ -n "$GIT_REBASE_BRANCH" ]]; then
      git_branch_label="$GIT_REBASE_BRANCH"
    elif [[ "$GIT_OID" =~ ^[0-9a-f]{7,}$ ]]; then
      git_branch_label="@${GIT_OID:0:7}"
    else
      git_branch_label="detached"
    fi
  fi
  [[ -z "$git_branch_label" ]] && git_branch_label="?"
  item_git_branch="${ITEM_LABEL_COLOR}branch${RESET} ${BOLD}${git_color}$(truncate_ellipsis \
    "$git_branch_label" 24)${RESET}"

  [[ -n "$GIT_WORKTREE" ]] && \
    item_git_wt="${ITEM_LABEL_COLOR}wt${RESET} ${BOLD}${GIT_NEUTRAL_COLOR}$(truncate_ellipsis "$GIT_WORKTREE" 20)${RESET}"
  [[ -n "$GIT_STATE" ]] && item_git_state="${ITEM_LABEL_COLOR}state${RESET} ${BOLD}${BRED}${GIT_STATE}${RESET}"
  [[ "$GIT_CONFLICT" -gt 0 ]] && \
    item_git_conflict="${ITEM_LABEL_COLOR}conflict${RESET} ${BOLD}${BRED}${GIT_CONFLICT}${RESET}"

  # No upstream is its own state, not "in sync": it means a push needs -u and nothing is backing
  # this branch up yet, so it escalates past the ahead/behind yellow rather than sitting at green.
  if [[ -z "$GIT_UPSTREAM" ]]; then
    item_git_sync="${ITEM_LABEL_COLOR}sync${RESET} ${BOLD}${ORANGE}none${RESET}"
  elif [[ "$GIT_AHEAD" -eq 0 && "$GIT_BEHIND" -eq 0 ]]; then
    item_git_sync="${ITEM_LABEL_COLOR}sync${RESET} ${BOLD}${ROW_GIT_BASE}ok${RESET}"
  else
    git_ab=""
    [[ "$GIT_AHEAD" -gt 0 ]] && git_ab="+${GIT_AHEAD}"
    [[ "$GIT_BEHIND" -gt 0 ]] && git_ab="$(join_words "$git_ab" "-${GIT_BEHIND}")"
    item_git_sync="${ITEM_LABEL_COLOR}sync${RESET} ${BOLD}${BYELLOW}${git_ab}${RESET}"
  fi

  # Staged sits at the base color rather than yellow: those changes are already captured in the
  # index, so they're the one kind of local change that isn't at risk of being lost.
  [[ "$GIT_STAGED" -gt 0 ]] && \
    item_git_staged="${ITEM_LABEL_COLOR}staged${RESET} ${BOLD}${ROW_GIT_BASE}${GIT_STAGED}${RESET}"
  [[ "$GIT_DIRTY" -gt 0 ]] && item_git_dirty="${ITEM_LABEL_COLOR}dirty${RESET} ${BOLD}${BYELLOW}${GIT_DIRTY}${RESET}"
  [[ "$GIT_NEW" -gt 0 ]] && item_git_new="${ITEM_LABEL_COLOR}new${RESET} ${BOLD}${BYELLOW}${GIT_NEW}${RESET}"
  [[ "$GIT_STASH" -gt 0 ]] && item_git_stash="${ITEM_LABEL_COLOR}stash${RESET} ${BOLD}${GIT_NEUTRAL_COLOR}${GIT_STASH}${RESET}"
fi

# --- Line 2: session - cost / turns / msgs / batch / length ---------------------------------------
# ROW_SESSION_BASE for turns/msgs/length: these are elapsed measurements rather than states to
# react to, so the color identifies the row rather than signaling anything. cost is this row's
# headline escalation item, so it floors on ESCALATION_BASE instead and escalates off that on its
# own spend thresholds below.
#
# turns/msgs are independently-aligned columns (not a parenthetical on one item) so each degrades
# on its own if the single-pass jq derivation above didn't come back with that particular count.
item_turns=""
[[ -n "$TURN_COUNT" ]] && \
  item_turns="${ITEM_LABEL_COLOR}turns${RESET} ${BOLD}${ROW_SESSION_BASE}${TURN_COUNT}${RESET}"
item_msgs=""
[[ -n "$TURN_ASST_COUNT" ]] && \
  item_msgs="${ITEM_LABEL_COLOR}msgs${RESET} ${BOLD}${ROW_SESSION_BASE}${TURN_ASST_COUNT}${RESET}"

# batch: calls per tool-calling assistant turn (calls / toolmsgs - see the jq derivation's comment
# above for why toolmsgs, not asst, is the right denominator). Omitted rather than shown as "-"
# when toolmsgs is absent or 0, same as every other item here that has nothing to report yet (early
# in a session, or one with no tool calls at all).
item_batch=""
if [[ "$TURN_CALL_COUNT" =~ ^[0-9]+$ && "$TURN_TOOLMSGS_COUNT" =~ ^[0-9]+$ \
  && "$TURN_TOOLMSGS_COUNT" -gt 0 ]]; then
  batch_ratio="$(awk -v c="$TURN_CALL_COUNT" -v m="$TURN_TOOLMSGS_COUNT" 'BEGIN { printf "%.1f", c / m }')"
  item_batch="${ITEM_LABEL_COLOR}batch${RESET} ${BOLD}${ROW_SESSION_BASE}${batch_ratio}x${RESET}"
fi
duration_fmt="$(fmt_elapsed "$DURATION_MS")"
item_length=""
[[ -n "$duration_fmt" ]] && \
  item_length="${ITEM_LABEL_COLOR}length${RESET} ${BOLD}${ROW_SESSION_BASE}${duration_fmt}${RESET}"
item_cost=""
if [[ "$COST" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  # Starts at ESCALATION_BASE, not the row base, then escalates - yellow/orange/red - as session
  # spend climbs, so a cost worth noticing stands out from routine ones.
  cost_color="$ESCALATION_BASE"
  cost_tier="$(awk -v c="$COST" 'BEGIN {
    if (c >= 3.5) print 3; else if (c >= 2) print 2; else if (c >= 1) print 1; else print 0
  }')"
  [[ "$cost_tier" == "1" ]] && cost_color="$BYELLOW"
  [[ "$cost_tier" == "2" ]] && cost_color="$ORANGE"
  [[ "$cost_tier" == "3" ]] && cost_color="$BRED"
  item_cost="${ITEM_LABEL_COLOR}cost${RESET} ${BOLD}${cost_color}$(printf '$%.2f' "$COST")${RESET}"
fi

# --- Line 3: context window% (compact%) / total / in / out / max ---------------------------------
# ROW_CONTEXT_BASE for in/out/max, which are plain measurements and stay at the base. window% and
# total each escalate on their own thresholds (see the two comments below); window%'s healthy
# floor is ESCALATION_BASE rather than the row base (it's this row's headline escalation item),
# while total's stays ROW_CONTEXT_BASE since it only escalates on the one EXCEEDS200K trip.
item_ctx_usage=""
item_compact=""
item_total=""
item_in=""
item_out=""
item_max=""
if [[ -n "$IN" || -n "$OUT" || -n "$PCT" ]]; then
  in_val=0
  out_val=0
  [[ "$IN" =~ ^[0-9]+$ ]] && in_val="$IN"
  [[ "$OUT" =~ ^[0-9]+$ ]] && out_val="$OUT"
  total_tokens=$((in_val + out_val))

  # compact%: how full the context is against the capacity auto-compaction actually measures
  # itself against, which stops matching window% the moment CLAUDE_CODE_AUTO_COMPACT_WINDOW is set.
  # Setting that variable decouples the compaction threshold from used_percentage, which keeps
  # reflecting the real context window regardless
  # (skills/cursor-projection/references/harness-matrix.md, Context compaction
  # / summarization, Threshold tuning row). On a 1m session with the variable at 300000, compaction
  # fires while window% still reads under 30%, and nothing else on this row would say so.
  #
  # Rendered as a parenthetical on window% rather than as its own labeled item, which keeps the row
  # roughly nine columns shorter (no "compact" label, no extra separator). The parenthetical form is
  # also the more honest one: this is the same measurement as window%, taken against a different
  # denominator, so it reads as a qualifier on that number rather than as an independent statistic.
  # Computed before the window% block below because it has to exist to be appended there.
  #
  # Omitted entirely when the variable is unset, because window% already carries the same number in
  # that case and a second copy of it would be noise rather than a second signal.
  #
  # Unlike window% below, this ladder runs on the percentage rather than the raw token count: the
  # denominator here is a capacity the user chose deliberately, so proximity to it is the whole
  # meaning of the item, where window%'s fixed token thresholds exist precisely because its
  # denominator varies between a 200k and a 1m window.
  #
  # Trailing "!": the configured capacity is larger than the real context window, so the proactive
  # threshold sits past the hard limit and can never be reached - the session falls back to
  # compacting at the hard limit. That is stock behavior rather than a broken state, but it means
  # this setting is doing nothing on this session, which is worth seeing rather than inferring.
  compact_frag=""
  if [[ "$AUTO_COMPACT_WINDOW" =~ ^[0-9]+$ && "$AUTO_COMPACT_WINDOW" -gt 0 ]]; then
    compact_pct=$(( total_tokens * 100 / AUTO_COMPACT_WINDOW ))
    compact_color="$ESCALATION_BASE"
    [[ "$compact_pct" -ge 60 ]] && compact_color="$BYELLOW"
    [[ "$compact_pct" -ge 80 ]] && compact_color="$ORANGE"
    [[ "$compact_pct" -ge 92 ]] && compact_color="$BRED"
    compact_suffix=""
    [[ "$CTXSIZE" =~ ^[0-9]+$ && "$AUTO_COMPACT_WINDOW" -gt "$CTXSIZE" ]] && \
      compact_suffix="${BRED}!"
    compact_frag="${BOLD}${compact_color}${compact_pct}%${compact_suffix}${RESET}"
  fi

  # window% color reflects the raw token count, not the percentage itself: a fixed window-size
  # threshold matters more than the percentage, since the same percentage means very different
  # absolute token counts on a 200k vs. a 1m window.
  #
  # The parens carry ITEM_LABEL_COLOR so they recede like a label, leaving the escalation color
  # inside them to do the signalling - same split as every label/value pair on these rows.
  if [[ -n "$PCT" ]]; then
    pct_int="${PCT%%.*}"
    if [[ "$pct_int" =~ ^[0-9]+$ ]]; then
      usage_color="$ESCALATION_BASE"
      [[ "$total_tokens" -ge 60000 ]] && usage_color="$BYELLOW"
      [[ "$total_tokens" -ge 120000 ]] && usage_color="$ORANGE"
      [[ "$total_tokens" -ge 200000 ]] && usage_color="$BRED"
      item_ctx_usage="${ITEM_LABEL_COLOR}window${RESET} ${BOLD}${usage_color}${pct_int}%${RESET}"
      [[ -n "$compact_frag" ]] && \
        item_ctx_usage+=" ${ITEM_LABEL_COLOR}(${RESET}${compact_frag}${ITEM_LABEL_COLOR})${RESET}"
    fi
  fi

  # Fallback: with no usable used_percentage there is no window% item to hang the parenthetical on,
  # so compact% goes back to being its own labeled item rather than being dropped. Rare enough that
  # the row length this costs doesn't matter, and the number is still worth showing when it's the
  # only context reading available.
  if [[ -z "$item_ctx_usage" && -n "$compact_frag" ]]; then
    item_compact="${ITEM_LABEL_COLOR}compact${RESET} ${compact_frag}"
  fi

  total_color="$ROW_CONTEXT_BASE"
  total_suffix=""
  if [[ "$EXCEEDS200K" == "1" ]]; then
    total_color="$BRED"
    total_suffix="!"
  fi
  item_total="${ITEM_LABEL_COLOR}total${RESET} ${BOLD}${total_color}$(fmt_tokens "$total_tokens")${total_suffix}${RESET}"

  item_in="${ITEM_LABEL_COLOR}in${RESET} ${BOLD}${ROW_CONTEXT_BASE}$(fmt_tokens "$IN")${RESET}"
  item_out="${ITEM_LABEL_COLOR}out${RESET} ${BOLD}${ROW_CONTEXT_BASE}$(fmt_tokens "$OUT")${RESET}"
  [[ "$CTXSIZE" =~ ^[0-9]+$ ]] && \
    item_max="${ITEM_LABEL_COLOR}max${RESET} ${BOLD}${ROW_CONTEXT_BASE}$(fmt_tokens "$CTXSIZE")${RESET}"
fi

# --- Line 4: cache hit rate / read / write -------------------------------------------------------
# ROW_CACHE_BASE for read/write, which are raw volumes with no good or bad value. hit rate is this
# row's headline escalation item: it sits at ESCALATION_BASE once healthy (>=95%) and escalates
# down through yellow to red as it falls, since a cold cache costs real money per turn.
item_hit=""
if [[ "$CACHE_READ" =~ ^[0-9]+$ && "$IN" =~ ^[0-9]+$ && "$IN" -gt 0 ]]; then
  hit_pct=$((CACHE_READ * 100 / IN))
  hit_color="$BRED"
  [[ "$hit_pct" -ge 85 ]] && hit_color="$BYELLOW"
  [[ "$hit_pct" -ge 95 ]] && hit_color="$ESCALATION_BASE"
  item_hit="${ITEM_LABEL_COLOR}hit${RESET} ${BOLD}${hit_color}${hit_pct}%${RESET}"
fi
# read/write are the one place in this script where a missing value renders as fmt_tokens' "-"
# instead of dropping its item: either field present brings out BOTH, so the pair is always shown
# together. They're two halves of one measurement - what the cache gave back versus what it cost to
# fill - and a lone "read 12k" invites reading the missing half as zero rather than as unreported.
# The "-" says which of the two didn't arrive, which a dropped item cannot. Every other item here
# stands on its own, so absence is unambiguous and omission is the right degradation.
item_read=""
item_write=""
if [[ -n "$CACHE_READ" || -n "$CACHE_WRITE" ]]; then
  item_read="${ITEM_LABEL_COLOR}read${RESET} ${BOLD}${ROW_CACHE_BASE}$(fmt_tokens "$CACHE_READ")${RESET}"
  item_write="${ITEM_LABEL_COLOR}write${RESET} ${BOLD}${ROW_CACHE_BASE}$(fmt_tokens "$CACHE_WRITE")${RESET}"
fi

# --- Line 5: limits - usage% + weekly% + reset (Pro/Max) OR usage% + total + max (cost-capped
# fallback) --------------------------------------------------------------------------------------
# Colors are applied up in this row's builder functions (fmt_rate_pct, build_reset_item,
# build_spend_items) rather than here, since both account-type paths render through them - that's
# where to look when changing what this row's colors do. reset uses ROW_LIMITS_BASE; usage/weekly
# (both account-type paths) use ESCALATION_BASE as their headline-escalation-item floor instead.
item_usage="$(build_usage_item "$FIVEH_PCT")"
item_weekly="$(build_weekly_item "$SEVEND_PCT")"
item_reset=""
item_spend_total=""
item_spend_max=""

if [[ -n "$item_usage$item_weekly" ]]; then
  # rate_limits is populated - this is a Pro/Max account - so show its native shape: usage% (5h),
  # weekly% (7d), plus the reset countdown. Pro/Max has no dollar-denominated cap, so total/max
  # stay empty here.
  item_reset="$(build_reset_item "$FIVEH_RESET" "$SEVEND_RESET")"
else
  # rate_limits came back entirely absent - this is determined NOT to be a Pro/Max account - so
  # (and only so) fall back to the cost-capped-seat spend fetch, which has no reset timestamp or
  # separate weekly figure, but does have usage%/total/max.
  #
  # get_usage_token is called here as a plain statement, NOT "$(get_usage_token)" - it must run in
  # this top-level shell, not a subshell, so its USAGE_TOKEN_ERROR assignment (see that function's
  # comment) actually survives to the error-row check at the bottom of the script.
  get_usage_token
  spend_items="$(build_spend_items "$(fetch_spend_json)")"
  IFS=$'\x1f' read -r item_usage item_spend_total item_spend_max <<< "$spend_items"
fi

# Distinguish three empty-limits cases from each other rather than collapsing them into one
# rendering:
#   credential withheld - get_usage_token hit its hard error (see that function's comment), so the
#                         row has nothing NOT because this account lacks limits data but because
#                         showing it would have risked showing another account's. Rendered in red
#                         as "usage withheld", pairing with the error row printed at the bottom of
#                         the script - an "n/a" here would read as "unsupported", which is exactly
#                         the wrong conclusion. Checked first, since it also satisfies the
#                         has-session-data test below.
#   genuinely unsupported - session clearly has data (COST/DURATION_MS present), yet both sources
#                         came back empty: an explicit "n/a" so it reads as expected-absent rather
#                         than looking broken.
#   not populated yet   - early session, COST/DURATION_MS also absent: no item at all, so the row
#                         drops out entirely and fills in on its own once data arrives.
if [[ -z "$item_usage$item_weekly$item_reset$item_spend_total$item_spend_max" ]]; then
  if [[ -n "$USAGE_TOKEN_ERROR" ]]; then
    item_usage="${ITEM_LABEL_COLOR}usage${RESET} ${BOLD}${BRED}withheld${RESET}"
  elif [[ -n "$COST" || -n "$DURATION_MS" ]]; then
    item_usage="${ITEM_LABEL_COLOR}usage${RESET} ${ITEM_MUTED_COLOR}n/a${RESET}"
  fi
fi

# --- Assemble rows: filter each row's empty items, then (unless disabled) align columns across
# all surviving rows -------------------------------------------------------------------------------
VSYNC_ENABLED=1
[[ "${CCSTATUS_VSYNC-}" == "0" ]] && VSYNC_ENABLED=0

# ROWn/labeln are numbered in render order, matching the "Line n:" section headers above: env,
# claude, session, context, cache, limits, git. The git row is defined out of that order up in the
# script (next to the git data it reads) but assembled in it here.
declare -a ROW0 ROW1 ROW2 ROW3 ROW4 ROW5 ROW6
build_row_items ROW0 "$item_help" "$item_org" "$item_cwd"
build_row_items ROW1 "$item_version" "$item_model" "$item_effort" "$item_thinking" "$item_fast"
build_row_items ROW2 "$item_cost" "$item_turns" "$item_msgs" "$item_batch" "$item_length"
build_row_items ROW3 "$item_ctx_usage" "$item_compact" "$item_total" "$item_in" "$item_out" "$item_max"
build_row_items ROW4 "$item_hit" "$item_read" "$item_write"
build_row_items ROW5 "$item_usage" "$item_weekly" "$item_reset" "$item_spend_total" "$item_spend_max"
build_row_items ROW6 "$item_git_wt" "$item_git_state" "$item_git_conflict" \
  "$item_git_sync" "$item_git_staged" "$item_git_dirty" "$item_git_new" "$item_git_stash" \
  "$item_git_branch"

label0="${ROW_TITLE_COLOR}$(pad_label env)${RESET}"
label1="${ROW_TITLE_COLOR}$(pad_label claude)${RESET}"
label2="${ROW_TITLE_COLOR}$(pad_label session)${RESET}"
label3="${ROW_TITLE_COLOR}$(pad_label context)${RESET}"
label4="${ROW_TITLE_COLOR}$(pad_label cache)${RESET}"
label5="${ROW_TITLE_COLOR}$(pad_label limits)${RESET}"
label6="${ROW_TITLE_COLOR}$(pad_label git)${RESET}"

# A row with zero items is omitted entirely. When VSYNC is off, each row's body is built right
# here (unpadded); when it's on, bodies are filled in below instead, from align_columns' output -
# either way bodies ends up in the same row order as active_labels.
#
# Loops over the ROW*/label* array-name pairs via eval-indirection (same bash-3.2-without-namerefs
# constraint as build_row_items above) rather than repeating this block once per row.
row_names=(ROW0 ROW1 ROW2 ROW3 ROW4 ROW5 ROW6)
row_labels=("$label0" "$label1" "$label2" "$label3" "$label4" "$label5" "$label6")
active_labels=()
align_input=""
bodies=()
for row_idx in "${!row_names[@]}"; do
  row_name="${row_names[$row_idx]}"
  eval "row_count=\${#${row_name}[@]}"
  [[ "$row_count" -eq 0 ]] && continue
  active_labels+=("${row_labels[$row_idx]}")
  eval "row_items=(\"\${${row_name}[@]}\")"
  if [[ "$VSYNC_ENABLED" == "1" ]]; then
    align_input="${align_input}$(join_us "${row_items[@]}")"$'\n'
  else
    bodies+=("$(join_with "$SEP" "${row_items[@]}")")
  fi
done

if [[ "$VSYNC_ENABLED" == "1" && -n "$align_input" ]]; then
  while IFS= read -r body; do
    bodies+=("$body")
  done < <(printf '%s' "$align_input" | align_columns)
fi

# "${bodies[$i]-}" rather than "${bodies[$i]}": under set -u a body missing for an active label
# would abort the render and blank the status line entirely. The two arrays are built in lockstep
# and can only desynchronize if an item value contains a newline, which would split one row into two
# on the way through align_columns. The only value that could carry one is stripped where it's read
# (see ORG_NAME above), so this is belt-and-braces: it degrades a case that should be unreachable to
# one short row rather than to no status line at all.
for i in "${!active_labels[@]}"; do
  printf '%b\n' "${active_labels[$i]}${ROW_SEP}${bodies[$i]-}"
done

# Standalone error row: deliberately outside the vsync/column-alignment machinery above (it's a
# message, not column data) and always the last thing printed, so a credential-resolution problem
# this account cares about (see get_usage_token's comment) can never be missed among the normal
# rows or mistaken for a normal-looking limits value. Empty means no error - nothing printed.
if [[ -n "$USAGE_TOKEN_ERROR" ]]; then
  # Wrapped here rather than left to the harness: Claude Code renders one terminal row per line
  # this script prints and clips each at the terminal width, with no wrap setting of its own, so a
  # message this long (the Keychain one runs past 200 characters) loses its tail - including the
  # service name that makes it actionable. Continuation lines are indented to the gutter the label
  # occupies, so the message reads as one hanging block rather than as extra unlabeled rows.
  # `fold -s` breaks on spaces and counts bytes, so a multibyte character in CLAUDE_CONFIG_DIR's
  # path can only leave a line short of the width, never overflow it.
  err_gutter=$((ROW_LABEL_WIDTH + 3))               # label + ROW_SEP's " > "
  err_width=$(($(term_width) - err_gutter - 1))     # -1 for the statusLine left padding
  # Floor: an absurdly narrow terminal would otherwise hand fold a zero or negative width, which
  # it rejects outright - and an error row that prints nothing is the one outcome worse than a
  # clipped one. Lines can then run past the terminal, which is the old behavior and still better.
  ((err_width < 20)) && err_width=20
  err_indent="$(printf '%*s' "$err_gutter" '')"
  err_first=1
  while IFS= read -r err_line; do
    err_line="${err_line% }"                        # fold -s leaves the space it broke on
    if ((err_first)); then
      printf '%b\n' "${BOLD}${BRED}$(pad_label error)${RESET}${ROW_SEP}${BOLD}${BRED}${err_line}${RESET}"
      err_first=0
    else
      printf '%b\n' "${err_indent}${BOLD}${BRED}${err_line}${RESET}"
    fi
  done < <(printf '%s\n' "$USAGE_TOKEN_ERROR" | fold -s -w "$err_width")
fi

exit 0
