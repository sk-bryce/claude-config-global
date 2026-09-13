#!/usr/bin/env bash
#
# run.sh - replays every fixture in this directory through ../statusline.sh and prints each
# result labeled by filename, so a manual review pass has real rendered output to eyeball
# instead of re-synthesizing payloads from scratch. The rendered fixtures are not an assertion
# suite: several of them (p02_fallback.json and anything with rate_limits null/absent) exercise the
# cost-capped-seat network fallback in statusline.sh, whose usage%/total/max reflect this account's
# live spend - those values are expected to differ run to run and are not something to assert
# equality on. The one exception is the structural-check section at the top, which does assert, and
# is the only thing this script's exit status reflects: 0 = checks passed, 1 = a check failed.
#
# What each fixture covers (see also the header comment in statusline.sh for the fields these
# exercise):
#   p01_full_promax         - Pro/Max rate_limits path, mid-range values, every row except git
#                             present (its .cwd is not a repository - see git-fixtures below). Its
#                             resets_at values are the far-future sentinel 9999999999, which renders
#                             as an absurd "95055d 21h": any epoch hardcoded in a checked-in fixture
#                             either sits in the past or is decades out, so the plausible-countdown
#                             case is covered by the runtime-relative reset case further down
#                             instead
#   p02_fallback            - rate_limits null -> cost-capped-seat spend API fallback path
#   p03_minimal_model_only  - only .model.display_name present; every other row/item omitted
#   p04_empty               - {} entirely; model falls back to "?"
#   p05_exceeds200k         - exceeds_200k_tokens true -> total item turns red with trailing "!"
#   p06_ctx_magenta         - context total_tokens = 59999, just below the 60k boundary -> window%
#                             at its healthy floor, no escalation (the filename names the tier, not
#                             the current color, which is ESCALATION_BASE green)
#   p07_ctx_yellow          - context total_tokens = 119999, just below the 120k boundary -> window%
#                             yellow
#   p08_ctx_orange          - context total_tokens = 199999, just below the 200k boundary -> window%
#                             orange
#   p09_hit_red             - cache hit rate = 84%, just below the 85% boundary -> red
#   p10_hit_yellow          - cache hit rate = 94%, just below the 95% boundary -> yellow
#   p11_hit_base            - cache hit rate = 98%, well past the 95% boundary -> no escalation, so
#                             the value sits at the cache row's base color
#   p12_cost_base           - session cost = $0.99, just below the $1 boundary -> no escalation, so
#                             the value sits at the session row's base color
#   p13_cost_yellow         - session cost = $1.99, just below the $2 boundary -> yellow
#   p14_cost_orange         - session cost = $3.49, just below the $3.5 boundary -> orange
#   p15_cost_red            - session cost = $5.00, well past the $3.5 boundary -> red
#   p16_duration_secs       - elapsed < 60s -> seconds-only formatting
#   p17_duration_days       - elapsed > 24h -> "Xd Yh" formatting
#   p18_ratelimit_boundary_65 - 5h = 64% (green, just below 65) / 7d = 65% (yellow, exactly at the
#                             65% boundary); 5h reset already past -> "now"
#   p19_thinking_off        - thinking.enabled false -> dim "off"
#   p20_malformed_cost      - non-numeric cost/duration -> both items omitted, no crash
#   p21_1m_window           - 1M-token window; window% colored by raw token count, not percentage
#   p22_ctx_yellow_at60k    - context total_tokens = 60000, exactly at the boundary -> window%
#                             yellow (companion to p06's 59999)
#   p23_ctx_orange_at120k   - context total_tokens = 120000, exactly at the boundary -> window%
#                             orange (companion to p07's 119999)
#   p24_ctx_red_at200k      - context total_tokens = 200000, exactly at the boundary -> window% red
#                             (companion to p08's 199999; distinct from p05, which tests the
#                             separate exceeds_200k_tokens flag rather than this boundary)
#   p25_hit_yellow_at85     - cache hit rate = 85%, exactly at the boundary -> yellow (companion to
#                             p09's 84%)
#   p26_hit_base_at95       - cache hit rate = 95%, exactly at the boundary -> the row's base color,
#                             as with p11 (companion to p10's 94%)
#   p27_cost_yellow_at1     - session cost = $1.00, exactly at the boundary -> yellow (companion to
#                             p12's $0.99)
#   p28_cost_orange_at2     - session cost = $2.00, exactly at the boundary -> orange (companion to
#                             p13's $1.99)
#   p29_cost_red_at3_5      - session cost = $3.50, exactly at the boundary -> red (companion to
#                             p14's $3.49)
#   p30_ratelimit_boundary_85 - 5h = 84% (yellow, just below 85) / 7d = 85% (red, exactly at the
#                             85% boundary); companion to p18's 65% boundary pair
#   p31_no_used_pct         - p01 with used_percentage deleted -> the context row renders without a
#                             window% item at all. Reused by the compact-fixtures no_window_pct case
#                             below, which is what it was originally added for
#   p32_fast_on             - fast_mode true -> "fast on" as the claude row's last item
#   p33_fast_off            - fast_mode false -> dim "fast off" (companion to p32, and the same
#                             on/off pair p19 covers for thinking). The third state, fast_mode
#                             absent entirely, needs no fixture of its own: every other fixture
#                             here omits the field, so the item's absence is already visible on all
#                             of them
#   array.json              - top-level JSON array -> jq indexing fails -> "[claude]" fallback
#   null.json               - top-level JSON null -> every field defaults, model shows "?"
#   invalid.txt             - not JSON at all -> "[claude]" fallback
#   empty.txt               - empty stdin -> "[claude]" fallback
#
# org-fixtures/*.claude.json - a second, separate set of cases for the env row's "org" item.
# Unlike every fixture above, item_org doesn't come from the stdin JSON payload at all - it's from
# $HOME/.claude.json's .oauthAccount.organizationName (see statusline.sh's header comment on why).
# So these cases hold stdin fixed at p01_full_promax.json (chosen because its rate_limits are
# populated, so no live network fallback/cache/credentials lookup under $HOME is triggered - see
# fetch_spend_json's guard in statusline.sh) and instead vary a stubbed $HOME/.claude.json, one per
# case, via a temp HOME override - so this account's real org name never enters the comparison and
# the 20-char truncation boundary can be checked exactly:
#   org_short       - "Acme Corp" (9 chars), well under 20 -> unchanged
#   org_boundary20  - exactly 20 chars -> unchanged (<=20 is the untruncated boundary)
#   org_over21      - exactly 21 chars, one past the boundary -> truncated to 17 chars + "..." (20
#                     chars total)
#   org_absent      - no .oauthAccount key at all -> org item omitted entirely, same as an account
#                     that isn't logged in to Claude.ai
#
# transcript-fixtures/*.jsonl - a third set, for the session row's turns/msgs/batch items, which
# are derived from the JSONL transcript at .transcript_path rather than from the stdin payload
# directly (see statusline.sh's "Turn count" comment for what each of the four counts backing them
# means). Same hold-stdin-fixed-and-vary-one-thing approach as org-fixtures above: stdin stays at
# p01_full_promax.json (same reason - populated rate_limits keep the cost-capped-seat fallback out
# of the picture) with only .transcript_path swapped in via a temp `jq` edit, one per case:
#   mixed_batching  - two typed prompts; the first's assistant turn makes 3 batched tool calls, the
#                     second's makes 1, and each is followed by a plain-text-only reply -> turns 2 |
#                     msgs 4 | batch 2.0x. This is the case the "batch" item exists to get right:
#                     dividing by toolmsgs (2 tool-calling turns), not every assistant turn (4),
#                     is what keeps the two plain-text replies from dragging a real 2.0x average
#                     down to 1.0x.
#   single_calls    - every tool-calling turn makes exactly one call, no plain-text-only replies in
#                     between -> batch 1.0x, the un-escalated baseline.
#   no_tool_calls   - every assistant turn is plain text, no tool_use blocks at all -> toolmsgs is 0,
#                     so batch is omitted entirely (never shown as "0.0x"); msgs still renders.
#   malformed       - one line of invalid JSON mixed into an otherwise-valid transcript -> the
#                     single jq pass that derives all four counts fails outright, so turns/msgs/
#                     batch are all omitted together rather than partially populated; no crash.
#   missing         - .transcript_path set to a path that doesn't exist -> same omit-everything
#                     outcome as malformed, but exercises the `-f "$TRANSCRIPT_PATH"` guard instead
#                     of the jq-failure path; distinct from every fixture above this one, which
#                     omits the field entirely rather than pointing it at a nonexistent file.
#
# credential/cache CLAUDE_CONFIG_DIR-scoping - a structural, assertion-based check (like the
# ROW_*_BASE section above, not a render-for-eyeballing fixture) covering the two spots in the
# cost-capped-seat fallback path that must key off CLAUDE_CONFIG_DIR rather than one fixed
# machine-wide location: get_usage_token (which account's OAuth token backs the
# /api/oauth/usage call) and CAP_CACHE_DIR (where that call's response gets disk-cached). Both
# only run when rate_limits is entirely absent from stdin, so this reuses p02_fallback.json - and
# both talk to a real macOS Keychain / a real network endpoint in production, which is exactly why
# p02_fallback itself (above) is rendered for eyeballing rather than asserted on. Here `curl`,
# `security` and `uname` are replaced with fake scripts placed first on PATH, which makes every
# outcome fully deterministic - including which OS branch runs, so both the macOS and non-macOS
# paths are exercised on whatever machine runs this suite:
#   scoped_keychain  - macOS + CLAUDE_CONFIG_DIR set -> ONLY the CLAUDE_CONFIG_DIR-scoped Keychain
#                       service is consulted. This profile's own .credentials.json and the bare
#                       machine-wide Keychain entry both hold different tokens and must both lose;
#                       either one winning is the cross-account bug this path exists to close
#   missing_scoped   - macOS + scoped entry absent + this profile HAS logged in (its .claude.json
#                       carries an oauthAccount) -> hard error: no usage call is attempted at all,
#                       the error row names the exact service looked for, and the limits row reads
#                       "usage withheld" rather than the "n/a" that means "unsupported account"
#   missing_no_org   - macOS + scoped entry absent + no oauthAccount (never logged in under this
#                       profile) -> expected-absent, not an error: still no usage call, but no
#                       error row either
#   configdir_unset  - CLAUDE_CONFIG_DIR unset (the default account) -> the bare Keychain entry,
#                       since there is no profile to scope by
#   non_macos        - uname reports Linux + CLAUDE_CONFIG_DIR set -> that profile's
#                       .credentials.json wins and Keychain never enters into it, even though the
#                       fake `security` would happily answer
#   no_credential    - Linux + CLAUDE_CONFIG_DIR unset + an empty $HOME, so no lookup can resolve
#                       anything -> "usage n/a" and NO error row, the opposite reading from
#                       missing_scoped's "usage withheld". Both halves of that distinction are
#                       asserted, since a regression collapsing the two would still look fine
#   cache dir count  - two different CLAUDE_CONFIG_DIR values plus the unset case must land in
#                       three distinct subdirectories under one shared cache root, so switching
#                       accounts can't serve a stale cached spend response from a different account
#
# compact-fixtures - a fourth set, for the context row's compact percentage, which renders as a
# parenthetical on window% ("window 51% (170%)") rather than as its own labeled item. Like the org
# fixtures, these vary something absent from the stdin payload - CLAUDE_CODE_AUTO_COMPACT_WINDOW,
# read straight from the environment - so stdin is held fixed (p01_full_promax.json, again for its
# populated rate_limits) and only the variable changes. The two cases needing a different payload
# borrow p21 and p31, since window size and used_percentage are payload fields rather than
# environment ones. Note that the variable is unset for the whole script near the top, so the
# fixtures above are unaffected by whether the caller's own environment has it set:
#   unset          - variable absent -> parenthetical omitted (window% already carries the number)
#   equals_window  - capacity == real window -> compact% agrees with window%, no "!"
#   below_window   - capacity < real window -> compact% reads higher than window%, threshold
#                    reachable, no "!"
#   above_window   - capacity > real window -> threshold past the hard limit, unreachable, so the
#                    value carries a trailing red "!" (what 300000 does on a 200k session)
#   1m_session     - 300000 against a 1m window: the intended setup, reachable, no "!". Shows the
#                    divergence the item exists for - 51% of the real window is 170% of the
#                    compaction capacity. Over-100% values are expected, not clamped
#   no_window_pct  - payload has no used_percentage, so there is no window% item to attach the
#                    parenthetical to -> falls back to a standalone labeled "compact" item rather
#                    than dropping the reading entirely
#   invalid        - non-numeric -> parenthetical omitted, no crash
#   zero           - 0 -> parenthetical omitted rather than dividing by zero
#
# git-fixtures - a fifth set, for the git row, and the only one needing real on-disk state: the row
# is derived from real `git` calls against .cwd, so each case has to be an actual repository built
# from scratch at run time (see the section below for how, and why the global git config is
# neutralized while doing it). Stdin is again held fixed at p01_full_promax.json with only .cwd
# swapped, for the same reason the org fixtures hold it fixed. Note that of the plain fixtures,
# only p01, p02, and p31 set .cwd at all (the rest omit it); the replay loop at the bottom of this
# file redirects those three at a temp directory built for the run, so the git row is correctly
# absent from all of their output on any machine - see that loop's comment for why the checked-in
# path could not carry that guarantee on its own.
#   clean           - committed and pushed, nothing outstanding -> "sync ok | branch main", green
#   subdir          - the same repo rendered from a subdirectory; must match "clean" exactly.
#                     Guards --git-dir/--git-common-dir path resolution: a wrong resolution reports
#                     a phantom linked worktree ("wt .git") for every repo subdirectory
#   dirty           - staged 2 (one of them also re-modified after staging) | dirty 2 | new 1
#   ahead_behind    - two unpushed commits plus one fetched-but-unmerged commit -> "sync +2 -1"
#   no_upstream     - committed, no remote -> "sync none" in orange (git omits both branch.upstream
#                     and branch.ab here, so checking only branch.ab would call this in sync)
#   initial         - no commits yet -> branch.oid is "(initial)", counting still works
#   detached        - branch.head is "(detached)" -> branch falls back to the short oid, "@abc1234"
#   long_branch     - branch name past the 24-char cap -> ellipsized, and (being the row's last
#                     item) its width leaves the other rows' column padding untouched
#   conflict        - conflicted merge -> "state merge | conflict 1", branch red; the unmerged path
#                     must NOT also inflate staged/dirty (it's a "u" entry, not a "1"/"2" entry)
#   rebase          - conflicted rebase -> "state rebase 1/2", and the branch shows the branch being
#                     rebased (from rebase-merge/head-name), not the detached oid
#   cherry_pick     - conflicted cherry-pick -> "state cherry-pick", checking state precedence
#   worktree        - rendered from a linked worktree -> "wt <name>" appears
#   stash           - two stashed entries, work tree otherwise clean -> "stash 2", no dirty/new
#   not_a_repo      - an ordinary directory -> git row omitted, every other row unchanged
#   missing_cwd     - a path that doesn't exist -> git row omitted, no error output, no crash
#   inside_git_dir  - cwd is .git itself, where --is-inside-work-tree is false and `git status`
#                     would fail -> the probe stops before the status call and the row is omitted
#
# Usage: ./run.sh [CCSTATUS_VSYNC=0]
#   Pass CCSTATUS_VSYNC=0 as an env var to also see the unaligned-columns rendering, e.g.:
#     CCSTATUS_VSYNC=0 ./run.sh
#   Exit status: 0 if the structural checks passed, 1 if any failed (the rendered fixtures below
#   them never affect it).
#
set -uo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
statusline="$dir/../statusline.sh"

# Neutralized for every fixture below, then set explicitly per case in the compact-fixtures section.
# settings.json's `env` block puts this variable into the environment of everything Claude Code
# spawns, this script included, so without the unset the context row's "compact" item would appear
# in every rendering above purely because of who happened to invoke run.sh - the same
# machine-dependence the git fixtures neutralize GIT_CONFIG_GLOBAL to avoid.
unset CLAUDE_CODE_AUTO_COMPACT_WINDOW

# Neutralized for the same reason, and it matters more: statusline.sh reads .claude.json from
# "${CLAUDE_CONFIG_DIR:-$HOME}", so a caller whose shell exports CLAUDE_CONFIG_DIR (a per-profile
# alias, say) makes every org-fixture case below read THAT profile's real .claude.json and ignore
# the stubbed $HOME entirely - the fixtures still render, they just quietly stop testing anything,
# all four printing the same live org name. Verified by hand before this unset was added. Unsetting
# it also pins the plain fixtures' cost-capped-seat fallback to the default account rather than
# whichever profile happened to invoke this script. The credential/cache section below exports it
# per case inside a subshell, so it is unaffected by this.
unset CLAUDE_CONFIG_DIR

# --- Structural checks ---------------------------------------------------------------------------
# The only part of this file that asserts instead of printing for review, and it earns that because
# the invariant it guards is invisible in rendered output: an item that hardcodes a palette color
# looks correct today and silently stops following its row the next time that row's ROW_*_BASE is
# reassigned. No amount of eyeballing this run's output catches that - the colors only diverge on
# the edit after the mistake. Two checks, both read statusline.sh as text:
#   1. Every ROW_*_BASE is defined exactly once and expanded by at least one item.
#   2. No color a ROW_*_BASE points at is expanded anywhere else in the script. The set is derived
#      from the ROW_*_BASE right-hand sides rather than hardcoded, so it follows a base that gets
#      reassigned to a different palette entry. Alert colors (BYELLOW/ORANGE/BRED) and the git
#      row's neutral GIT_NEUTRAL_COLOR are exempt by construction - neither is a base - which
#      matches the boundary statusline.sh's own definition-block comment draws. The four
#      structural-color variables (ROW_TITLE_COLOR/ITEM_LABEL_COLOR/ROW_SEP_COLOR/ITEM_SEP_COLOR)
#      are exempt too, for a different reason: they're independent of every row and may
#      legitimately be reassigned to the same palette entry some row's base also uses (e.g. item
#      labels in cyan alongside a cyan row base) without that being a stale hardcode - so their
#      own definition lines are excluded from the stray scan rather than counted as a collision.
# Comment lines are excluded from both, so naming a variable in prose never counts as using it.
# "code" keeps each surviving line's real file line number as a "N:" prefix (grep -n '' numbers
# every line, then the second grep drops comments), so a FAIL below cites a line number that
# matches the actual file - stripping first and numbering after would report the wrong ones.
structural_fail=0
echo "=== structural: ROW_*_BASE indirection ==="
code="$(grep -n '' "$statusline" | grep -vE '^[0-9]+:[[:space:]]*#')"

base_vars="$(printf '%s\n' "$code" | sed -nE 's/^[0-9]+:(ROW_[A-Z]+_BASE)=.*/\1/p' | sort)"
if [[ -z "$base_vars" ]]; then
  echo "FAIL: no ROW_*_BASE definitions found in statusline.sh"
  structural_fail=1
fi

while IFS= read -r var; do
  [[ -n "$var" ]] || continue
  defs="$(printf '%s\n' "$code" | grep -cE "^[0-9]+:${var}=")"
  uses="$(printf '%s\n' "$code" | grep -vE "^[0-9]+:${var}=" \
    | grep -cE "\\\$\{${var}\}|\"\\\$${var}\"")"
  if [[ "$defs" -ne 1 ]]; then
    echo "FAIL: $var has $defs definitions, expected exactly 1"
    structural_fail=1
  elif [[ "$uses" -lt 1 ]]; then
    echo "FAIL: $var is defined but never expanded by any item"
    structural_fail=1
  else
    echo "PASS: $var - 1 definition, $uses use(s)"
  fi
done <<< "$base_vars"

# Every palette entry a base points at, deduped: two rows sharing one color is fine (git and limits
# both sit on BGREEN today), it just means neither may reference that color directly.
base_colors="$(printf '%s\n' "$code" | sed -nE 's/^[0-9]+:ROW_[A-Z]+_BASE="\$([A-Z]+)".*/\1/p' \
  | sort -u)"
while IFS= read -r color; do
  [[ -n "$color" ]] || continue
  stray="$(printf '%s\n' "$code" | grep -vE "^[0-9]+:ROW_[A-Z]*_BASE=" \
    | grep -vE "^[0-9]+:${color}='" \
    | grep -vE "^[0-9]+:(ROW_TITLE_COLOR|ITEM_LABEL_COLOR|ITEM_MUTED_COLOR|ROW_SEP_COLOR|ITEM_SEP_COLOR)=" \
    | grep -E "\\\$\{${color}\}|\"\\\$${color}\"" || true)"
  if [[ -n "$stray" ]]; then
    echo "FAIL: \$$color is a row base but is also expanded directly - route it through the base:"
    printf '%s\n' "$stray" | sed 's/^/        /'
    structural_fail=1
  else
    echo "PASS: \$$color - expanded only via a ROW_*_BASE"
  fi
done <<< "$base_colors"
echo

# --- structural: CLAUDE_CONFIG_DIR-scoped credentials/cache --------------------------------------
# See the header comment above ("credential/cache CLAUDE_CONFIG_DIR-scoping") for what this covers
# and why fake `curl`/`security`/`uname` scripts make it assertable rather than eyeballed. Skipped,
# like transcript-fixtures, if jq is missing - the fake scripts and the real fetch_spend_json/
# get_usage_token both need it - or if shasum is missing, since the scoped Keychain service name
# these cases assert on is derived with it.
echo "=== structural: CLAUDE_CONFIG_DIR-scoped credentials/cache ==="
if ! command -v jq >/dev/null 2>&1 || ! command -v shasum >/dev/null 2>&1; then
  echo "SKIPPED (jq and shasum required)"
else
  cred_root="$(mktemp -d)"
  fakebin="$cred_root/bin"
  keychain="$cred_root/keychain"
  mkdir -p "$fakebin" "$keychain"

  # Fake `security`: a file-backed stand-in for the macOS Keychain. `find-generic-password -s
  # <service> -w` prints $FAKE_KEYCHAIN_DIR/<service> when that file exists and exits 1 otherwise,
  # so each case decides per-service which entries exist. That per-service resolution is the whole
  # point: get_usage_token looks up a CLAUDE_CONFIG_DIR-scoped service name rather than one fixed
  # machine-wide one, so a fake that answered every service identically could not tell the two
  # apart.
  cat > "$fakebin/security" <<'FAKESECURITY'
#!/usr/bin/env bash
service=""
prev=""
for arg in "$@"; do
  [[ "$prev" == "-s" ]] && service="$arg"
  prev="$arg"
done
[[ -n "$service" && -f "${FAKE_KEYCHAIN_DIR:-}/$service" ]] || exit 1
cat "${FAKE_KEYCHAIN_DIR}/$service"
FAKESECURITY
  chmod +x "$fakebin/security"

  # Fake `uname`: reports whatever FAKE_UNAME_S says (default Darwin), so the macOS-only branch of
  # get_usage_token and the non-macOS branch are BOTH exercised on whatever machine runs this
  # suite, rather than only whichever one this machine happens to be. statusline.sh calls `uname
  # -s` and nothing else, so answering every invocation with the same string is sufficient.
  cat > "$fakebin/uname" <<'FAKEUNAME'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_UNAME_S:-Darwin}"
FAKEUNAME
  chmod +x "$fakebin/uname"

  # Fake `curl`: records whichever token it was actually called with (parsed off the Authorization
  # header, the same way the real call in fetch_spend_json shapes it) into $CURL_CAPTURE_FILE, and
  # returns a fixed, valid cost-capped-seat spend response so fetch_spend_json's own `.spend` check
  # passes and CAP_CACHE_FILE gets written. A case where the capture file is never created is a
  # case where the network call was never attempted at all, which several cases below assert on.
  cat > "$fakebin/curl" <<'FAKECURL'
#!/usr/bin/env bash
token=""
prev=""
for arg in "$@"; do
  if [[ "$prev" == "-H" && "$arg" == "Authorization: Bearer "* ]]; then
    token="${arg#Authorization: Bearer }"
  fi
  prev="$arg"
done
[[ -n "${CURL_CAPTURE_FILE:-}" ]] && printf '%s' "$token" > "$CURL_CAPTURE_FILE"
printf '%s' '{"spend":{"enabled":true,"percent":10,"severity":"normal","used":{"amount_minor":500,"exponent":2,"currency":"USD"},"limit":{"amount_minor":10000,"exponent":2,"currency":"USD"}}}'
FAKECURL
  chmod +x "$fakebin/curl"

  cred_stdin="$dir/p02_fallback.json"
  cache_root="$cred_root/cache"

  # The same derivation get_usage_token performs, so these cases assert against the service name it
  # actually looks up rather than against a hardcoded copy that could silently drift from it.
  scoped_service_for() {
    printf 'Claude Code-credentials-%s' "$(printf '%s' "$1" | shasum -a 256 | cut -c1-8)"
  }

  # Four profile dirs, each standing in for one account on one machine:
  #   config_a - scoped Keychain entry present; its .credentials.json holds a DIFFERENT token, as a
  #              decoy that must lose on macOS and win once uname says otherwise
  #   config_b - same shape, second account, used only for the cache-separation check
  #   config_c - no scoped entry, but a real .claude.json oauthAccount -> the hard-error case
  #   config_d - no scoped entry and no oauthAccount -> expected-absent, not an error
  config_a="$cred_root/config_a"
  config_b="$cred_root/config_b"
  config_c="$cred_root/config_c"
  config_d="$cred_root/config_d"
  mkdir -p "$config_a" "$config_b" "$config_c" "$config_d"
  printf '{"claudeAiOauth":{"accessToken":"CONFIGDIR_TOKEN_A"}}' > "$config_a/.credentials.json"
  printf '{"claudeAiOauth":{"accessToken":"CONFIGDIR_TOKEN_B"}}' > "$config_b/.credentials.json"
  printf '{"claudeAiOauth":{"accessToken":"CONFIGDIR_TOKEN_C"}}' > "$config_c/.credentials.json"
  printf '{"oauthAccount":{"organizationName":"Acme Corp"}}' > "$config_a/.claude.json"
  printf '{"oauthAccount":{"organizationName":"Acme Corp"}}' > "$config_b/.claude.json"
  printf '{"oauthAccount":{"organizationName":"Acme Corp"}}' > "$config_c/.claude.json"
  printf '{}' > "$config_d/.claude.json"

  # Keychain contents: the bare machine-wide entry (the pre-fix fallback, and still the right
  # answer when CLAUDE_CONFIG_DIR is unset) plus scoped entries for config_a/config_b only.
  printf '{"claudeAiOauth":{"accessToken":"KEYCHAIN_TOKEN"}}' > "$keychain/Claude Code-credentials"
  printf '{"claudeAiOauth":{"accessToken":"SCOPED_TOKEN_A"}}' \
    > "$keychain/$(scoped_service_for "$config_a")"
  printf '{"claudeAiOauth":{"accessToken":"SCOPED_TOKEN_B"}}' \
    > "$keychain/$(scoped_service_for "$config_b")"

  # Runs statusline.sh in a subshell so the CLAUDE_CONFIG_DIR/PATH/cache overrides never leak into
  # the rest of this script - the org-fixtures and git-fixtures sections further down read the
  # real $HOME and must not see any of this. Stdout goes to $4 so the error-row assertions below
  # have something to grep; $3 is the cache root, kept separate per case so the cache-separation
  # check at the end counts only the runs it means to.
  run_cred_case() {
    local configdir="$1" capture_file="$2" case_cache_root="$3" out_file="$4" uname_s="${5:-Darwin}"
    local home_override="${6:-}"
    (
      if [[ -n "$configdir" ]]; then
        export CLAUDE_CONFIG_DIR="$configdir"
      else
        unset CLAUDE_CONFIG_DIR
      fi
      # Only the no-credential-anywhere case passes this, to move $HOME/.claude/.credentials.json
      # (get_usage_token's last resort) somewhere guaranteed empty. Every other case leaves $HOME
      # alone, since their earlier lookups win before that fallback is reached.
      [[ -n "$home_override" ]] && export HOME="$home_override"
      export PATH="$fakebin:$PATH"
      export FAKE_KEYCHAIN_DIR="$keychain"
      export FAKE_UNAME_S="$uname_s"
      export XDG_CACHE_HOME="$case_cache_root"
      export CURL_CAPTURE_FILE="$capture_file"
      bash "$statusline" < "$cred_stdin" > "$out_file" 2>&1
    )
  }

  # Asserts on the token the fake curl was actually called with; "<none>" means no call happened.
  cred_token_used() {
    cat "$1" 2>/dev/null || printf '<none>'
  }

  check_cred() {
    local desc="$1" expected="$2" got="$3"
    if [[ "$got" == "$expected" ]]; then
      echo "PASS: $desc"
    else
      echo "FAIL: $desc - got '$got', expected '$expected'"
      structural_fail=1
    fi
  }

  # macOS + CLAUDE_CONFIG_DIR set: ONLY the scoped Keychain service is consulted. The bare Keychain
  # entry and this profile's own .credentials.json both hold different tokens and must both lose -
  # either one winning is the cross-account bug this path exists to close.
  run_cred_case "$config_a" "$cred_root/cap_a" "$cache_root" "$cred_root/out_a"
  check_cred "macOS + CLAUDE_CONFIG_DIR set uses the scoped Keychain entry, not .credentials.json \
or the bare entry" "SCOPED_TOKEN_A" "$(cred_token_used "$cred_root/cap_a")"

  # macOS + CLAUDE_CONFIG_DIR set + scoped entry MISSING + this profile has logged in (its
  # .claude.json has an oauthAccount): hard error. No network call may be attempted, and the error
  # row must name the exact service that was looked for.
  run_cred_case "$config_c" "$cred_root/cap_c" "$cred_root/cache_c" "$cred_root/out_c"
  check_cred "macOS + missing scoped entry + oauthAccount present attempts no usage call" \
    "<none>" "$(cred_token_used "$cred_root/cap_c")"
  if grep -q "$(scoped_service_for "$config_c")" "$cred_root/out_c"; then
    echo "PASS: missing scoped entry renders the error row naming the expected service"
  else
    echo "FAIL: missing scoped entry did not render an error row naming the expected service"
    structural_fail=1
  fi
  if grep -q "withheld" "$cred_root/out_c"; then
    echo "PASS: withheld credential renders 'usage withheld' rather than 'usage n/a'"
  else
    echo "FAIL: withheld credential did not render 'usage withheld' on the limits row"
    structural_fail=1
  fi

  # Same case, but with a cache already on disk for that profile - the situation this account was
  # actually in when the bug was found, since the pre-fix bare-Keychain fallback had populated the
  # cache with ANOTHER account's spend response. A credential hard error must skip the cache
  # entirely, fresh or stale, or the fix silently keeps serving exactly what it exists to stop.
  # The cache path is rebuilt here the same way statusline.sh builds it (cksum of
  # CLAUDE_CONFIG_DIR), so this asserts against the real location rather than a guessed one.
  cache_c_key="$(printf '%s' "$config_c" | cksum | tr -d ' ' | tr '/' '_')"
  mkdir -p "$cred_root/cache_c_stale/claude-statusline/$cache_c_key"
  printf '%s' '{"spend":{"enabled":true,"percent":77,"severity":"normal","used":{"amount_minor":7777,"exponent":2,"currency":"USD"},"limit":{"amount_minor":10000,"exponent":2,"currency":"USD"}}}' \
    > "$cred_root/cache_c_stale/claude-statusline/$cache_c_key/spend.json"
  run_cred_case "$config_c" "$cred_root/cap_c_stale" "$cred_root/cache_c_stale" \
    "$cred_root/out_c_stale"
  if grep -q "77.77\|77%" "$cred_root/out_c_stale"; then
    echo "FAIL: credential hard error served the on-disk cache instead of withholding it"
    structural_fail=1
  else
    echo "PASS: credential hard error skips the on-disk cache, stale or fresh"
  fi

  # Same, but this profile never logged in (no oauthAccount): a missing scoped entry is expected
  # here, not an error - it degrades silently like any other genuinely-absent field.
  run_cred_case "$config_d" "$cred_root/cap_d" "$cred_root/cache_d" "$cred_root/out_d"
  check_cred "macOS + missing scoped entry + no oauthAccount attempts no usage call" \
    "<none>" "$(cred_token_used "$cred_root/cap_d")"
  if grep -q "not found - withholding" "$cred_root/out_d"; then
    echo "FAIL: missing scoped entry with no oauthAccount rendered an error row, expected silence"
    structural_fail=1
  else
    echo "PASS: missing scoped entry with no oauthAccount renders no error row"
  fi

  # macOS + CLAUDE_CONFIG_DIR unset (the default account): the bare machine-wide Keychain entry,
  # since there is no profile to scope by.
  run_cred_case "" "$cred_root/cap_unset" "$cache_root" "$cred_root/out_unset"
  check_cred "macOS + CLAUDE_CONFIG_DIR unset still uses the bare Keychain entry" \
    "KEYCHAIN_TOKEN" "$(cred_token_used "$cred_root/cap_unset")"

  # Non-macOS: CLAUDE_CONFIG_DIR scopes .credentials.json at the OS level there, so the file wins
  # and Keychain never enters into it - even though the fake `security` would happily answer.
  run_cred_case "$config_a" "$cred_root/cap_linux" "$cred_root/cache_linux" \
    "$cred_root/out_linux" "Linux"
  check_cred "non-macOS + CLAUDE_CONFIG_DIR set uses that profile's .credentials.json" \
    "CONFIGDIR_TOKEN_A" "$(cred_token_used "$cred_root/cap_linux")"

  # No credential resolvable anywhere, and no hard error either: non-macOS (so Keychain is out of
  # play), CLAUDE_CONFIG_DIR unset (so there is no scoped lookup to fail loudly), and $HOME pointed
  # at an empty directory so get_usage_token's last resort - $HOME/.claude/.credentials.json - is
  # genuinely absent. p02's payload still carries cost/duration, so the session clearly HAS data,
  # which is the condition that makes the limits row read "usage n/a". This is the counterpart to
  # the withheld case above, and the distinction statusline.sh's three-way empty-limits comment
  # turns on: "n/a" means this account type is unsupported, "withheld" means a credential was
  # expected and missing. Asserting only one of the two would let the other quietly become the
  # rendering for both.
  empty_home="$cred_root/empty_home"
  mkdir -p "$empty_home"
  run_cred_case "" "$cred_root/cap_na" "$cred_root/cache_na" "$cred_root/out_na" "Linux" \
    "$empty_home"
  check_cred "no credential anywhere attempts no usage call" \
    "<none>" "$(cred_token_used "$cred_root/cap_na")"
  if grep -q "usage.*n/a" "$cred_root/out_na"; then
    echo "PASS: no credential anywhere renders 'usage n/a'"
  else
    echo "FAIL: no credential anywhere did not render 'usage n/a' on the limits row"
    structural_fail=1
  fi
  if grep -q "withholding" "$cred_root/out_na"; then
    echo "FAIL: no credential anywhere rendered the withheld error row, expected silence"
    structural_fail=1
  else
    echo "PASS: no credential anywhere renders no error row"
  fi

  # Cache separation: config_a, config_b and unset each ran against the SAME cache root above (the
  # error/non-macOS cases deliberately used their own, so they can't pad this count), and must
  # still land in three distinct subdirectories.
  run_cred_case "$config_b" "$cred_root/cap_b" "$cache_root" "$cred_root/out_b"
  cache_subdirs="$(find "$cache_root/claude-statusline" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  check_cred "CAP_CACHE_DIR uses 3 distinct subdirectories for config_a/config_b/unset" \
    "3" "$cache_subdirs"

  rm -rf "$cred_root"
fi
echo

# The three fixtures that set .cwd (p01, p02, p31) need it to be a real directory that is NOT a
# repository, so the git row stays absent from their output. A checked-in absolute literal risks
# happening to be a repository on some machine, which would silently start rendering a git row in
# all three and nobody would know why. So the directory is built here instead: guaranteed to exist,
# guaranteed not to be a repo, on any machine. Named "workspace" so the cwd item keeps ending in
# "workspace" as
# the checked-in fixtures intend. Deliberately a fixed path rather than `mktemp -d`: the cwd item
# renders the directory in full, and these fixtures are rendered for eyeballing rather than
# asserted on, so a fresh random name every run would put gratuitous churn on the one line a
# reviewer is diffing against the previous run. Needs jq to rewrite .cwd; without it, fall back to
# replaying the fixtures untouched, which is what this loop did before. The .cwd the fixtures carry
# on disk is only ever used on that no-jq path, and all it has to be is a path that is not a
# repository - hence the obviously-unreal /nonexistent/workspace. It is deliberately NOT the path
# built below: making the two match would put the same literal in four files, where setting TMPDIR
# silently desynchronizes them and nothing would catch it.
fixture_cwd_root=""
if command -v jq >/dev/null 2>&1; then
  fixture_cwd_root="${TMPDIR:-/tmp}/statusline-fixture-cwd"
  rm -rf "$fixture_cwd_root"
  mkdir -p "$fixture_cwd_root/workspace"
fi

for fixture in "$dir"/*.json "$dir"/*.txt; do
  [[ -f "$fixture" ]] || continue
  echo "=== $(basename "$fixture") ==="
  if [[ -n "$fixture_cwd_root" ]] && jq -e 'type == "object" and has("cwd")' "$fixture" >/dev/null 2>&1; then
    jq --arg cwd "$fixture_cwd_root/workspace" '.cwd = $cwd' "$fixture" | bash "$statusline"
  else
    bash "$statusline" < "$fixture"
  fi
  echo
done

[[ -n "$fixture_cwd_root" ]] && rm -rf "$fixture_cwd_root"

# --- reset countdown -----------------------------------------------------------------------------
# The one stdin-payload case that cannot be checked in: resets_at is an absolute Unix epoch, so a
# hardcoded one is either already past (p18's 5h window, which renders "now") or decades out (the
# 9999999999 sentinel every other fixture uses, which renders "95055d 21h"). Neither shows what a
# real reset looks like, and fmt_duration's "Xh Ym" branch - the shape a live 5h window spends
# almost all its time in - is otherwise never exercised at all. So this case computes the epochs at
# run time from `date +%s` and prints the expected shape next to the label, since the exact minute
# value moves with the clock.
if command -v jq >/dev/null 2>&1; then
  reset_now="$(date +%s)"
  # The offsets are deliberately not clean multiples of an hour or a day: a whole-unit offset lands
  # exactly on a rollover boundary, so the second or two that passes before statusline.sh calls
  # `date +%s` itself can flip "3d 0h" to "2d 23h" and make a correct render look wrong.
  echo "=== reset-countdown (expect: 5h 2h 5m | 7d 3d 1h) ==="
  jq --argjson f "$((reset_now + 7500))" --argjson s "$((reset_now + 3 * 86400 + 5400))" \
    '.rate_limits.five_hour.resets_at = $f | .rate_limits.seven_day.resets_at = $s' \
    "$dir/p01_full_promax.json" | bash "$statusline"
  echo
fi

org_stdin="$dir/p01_full_promax.json"
for org_fixture in "$dir"/org-fixtures/*.claude.json; do
  [[ -f "$org_fixture" ]] || continue
  echo "=== org-fixtures/$(basename "$org_fixture") ==="
  org_tmphome="$(mktemp -d)"
  cp "$org_fixture" "$org_tmphome/.claude.json"
  HOME="$org_tmphome" bash "$statusline" < "$org_stdin"
  rm -rf "$org_tmphome"
  echo
done

# --- transcript fixtures --------------------------------------------------------------------------
# turns/msgs/batch are derived from a real JSONL transcript, so - like org-fixtures above - stdin
# stays fixed at p01_full_promax.json with only .transcript_path swapped in via a temp `jq` edit.
# Requires jq, which every fixture above already assumes is present to do anything meaningful; the
# explicit guard here is only because this section (unlike the plain-fixture loop above) invokes jq
# itself rather than leaving all jq use inside statusline.sh.
if ! command -v jq >/dev/null 2>&1; then
  echo "=== transcript-fixtures: SKIPPED (jq required) ==="
else
  transcript_stdin="$dir/p01_full_promax.json"
  render_transcript_case() {
    echo "=== transcript-fixtures/$1 ==="
    jq --arg tp "$2" '.transcript_path = $tp' "$transcript_stdin" | bash "$statusline"
    echo
  }
  render_transcript_case mixed_batching "$dir/transcript-fixtures/mixed_batching.jsonl"
  render_transcript_case single_calls "$dir/transcript-fixtures/single_calls.jsonl"
  render_transcript_case no_tool_calls "$dir/transcript-fixtures/no_tool_calls.jsonl"
  render_transcript_case malformed "$dir/transcript-fixtures/malformed.jsonl"
  render_transcript_case missing "$dir/transcript-fixtures/does-not-exist.jsonl"
fi

# --- compact fixtures ----------------------------------------------------------------------------
# The fourth set (see the header comment's list). Like the org fixtures, these vary something that
# is not in the stdin payload at all - here CLAUDE_CODE_AUTO_COMPACT_WINDOW, which the context row's
# compact percentage reads straight from the environment - so stdin is held fixed and only the
# variable changes.
# p01_full_promax.json is the 200k-window base for the same reason the org fixtures use it: its
# populated rate_limits keep the cost-capped-seat network fallback out of the picture. Two cases
# need a different payload and borrow p21 and p31, since window size and used_percentage are
# payload fields rather than environment ones.
#
# These run before the git section deliberately: that section exits early when git or jq is
# missing, and these cases need neither.
compact_stdin="$dir/p01_full_promax.json"
render_compact_case() {
  echo "=== compact-fixtures/$1 ==="
  if [[ "$2" == "<unset>" ]]; then
    env -u CLAUDE_CODE_AUTO_COMPACT_WINDOW bash "$statusline" < "$3"
  else
    CLAUDE_CODE_AUTO_COMPACT_WINDOW="$2" bash "$statusline" < "$3"
  fi
  echo
}

# unset: the default for anyone who has not set the variable -> parenthetical omitted entirely,
# because window% already carries the same number and a duplicate would be noise.
render_compact_case unset "<unset>" "$compact_stdin"

# equals_window: capacity set to exactly the real window -> compact% and window% agree, no "!".
# This is the case that shows the item earning its keep only when the two numbers diverge.
render_compact_case equals_window 200000 "$compact_stdin"

# below_window: capacity below the real window -> compact% reads higher than window%, no "!",
# because a threshold inside the window is reachable and compaction will actually fire there.
render_compact_case below_window 150000 "$compact_stdin"

# above_window: capacity above the real window -> the proactive threshold sits past the hard limit
# and can never be reached, so the value carries the trailing red "!". This is exactly what a
# 300000 setting does on a 200k session.
render_compact_case above_window 300000 "$compact_stdin"

# 1m_session: the intended configuration - a 300000 capacity on a 1m window. Reachable, so no "!".
# This is the divergence the item exists to surface: p21's 510k tokens read as a comfortable 51% of
# the real window while sitting at 170% of the compaction capacity, i.e. well past where compaction
# would already have fired. Values over 100% are expected here rather than clamped - a live session
# would have compacted before reaching one, so seeing it means the capacity is set below where the
# session actually operates.
render_compact_case 1m_session 300000 "$dir/p21_1m_window.json"

# no_window_pct: p31 is p01 with used_percentage deleted, so there is no window% item for the
# parenthetical to attach to. Expect a standalone labeled "compact" item instead - the reading is
# still the only context percentage available, so dropping it would lose the signal rather than
# just shorten the row.
render_compact_case no_window_pct 150000 "$dir/p31_no_used_pct.json"

# invalid: a non-numeric value -> parenthetical omitted, no crash, same fail-quiet posture as every
# other malformed input in this script.
render_compact_case invalid notanumber "$compact_stdin"

# zero: would be a division by zero if the guard were only a numeric check -> parenthetical omitted.
render_compact_case zero 0 "$compact_stdin"

# --- git fixtures --------------------------------------------------------------------------------
# The fifth set, and the only one needing real on-disk state per case: the git row is derived from
# real `git` calls against .cwd, so its cases have to be actual repositories, and a repository can't
# be nested inside this one. They're built from scratch into a temp directory on every run,
# then each is rendered with stdin held fixed at p01_full_promax.json and only .cwd swapped - the
# same hold-stdin-fixed approach the org fixtures above use, and for the same reason: p01's
# populated rate_limits keep the cost-capped-seat network fallback out of the picture.
#
# GIT_CONFIG_GLOBAL/GIT_CONFIG_SYSTEM are neutralized for this whole section so the fixtures don't
# inherit this machine's real git config (core.excludesFile, commit.gpgsign, hooks, default branch),
# any of which would otherwise make the rendered output differ from one machine to the next.
if ! command -v git >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "=== git-fixtures: SKIPPED (git and jq are both required) ==="
  exit "$structural_fail"
fi

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null

git_root="$(mktemp -d)"
git_stdin="$dir/p01_full_promax.json"

# Renders one case: label, then statusline.sh with .cwd swapped to this case's directory.
render_git_case() {
  echo "=== git-fixtures/$1 ==="
  jq --arg cwd "$2" '.cwd = $cwd' "$git_stdin" | bash "$statusline"
  echo
}

# Fresh repo with a deterministic identity. Committer identity is set per-repo rather than via env
# vars so `git commit` works with the global config neutralized above.
gf_init() {
  mkdir -p "$1"
  git -C "$1" init -q -b main >/dev/null 2>&1
  git -C "$1" config user.email fixture@example.invalid
  git -C "$1" config user.name Fixture
  git -C "$1" config commit.gpgsign false
}

# gf_commit <repo> <path> <content> <message>
gf_commit() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" > "$1/$2"
  git -C "$1" add "$2" >/dev/null 2>&1
  git -C "$1" commit -q -m "$4" >/dev/null 2>&1
}

# A bare repo to act as "origin" for the cases that need a real upstream.
gf_origin="$git_root/origin.git"
git init -q --bare -b main "$gf_origin" >/dev/null 2>&1

# clean: committed, pushed, nothing outstanding -> "sync ok | branch main", branch green. Also
# carries a committed subdirectory, used by the "subdir" case below.
gf_init "$git_root/clean"
gf_commit "$git_root/clean" README.md base "init"
gf_commit "$git_root/clean" sub/nested.txt nested "nested"
git -C "$git_root/clean" remote add origin "$gf_origin" >/dev/null 2>&1
git -C "$git_root/clean" push -q -u origin main >/dev/null 2>&1
render_git_case clean "$git_root/clean"

# subdir: same repo, rendered from a subdirectory rather than its top level. Exercises the path
# resolution in statusline.sh, since rev-parse reports --git-dir differently depending on where it
# is invoked from; the row must come out identical to "clean" above.
render_git_case subdir "$git_root/clean/sub"

# dirty: one file staged, one modified in the work tree, one both staged and re-modified (so it
# counts toward staged AND dirty), plus an untracked file -> staged 2 | dirty 2 | new 1.
gf_init "$git_root/dirty"
gf_commit "$git_root/dirty" a.txt a "init"
gf_commit "$git_root/dirty" b.txt b "b"
gf_commit "$git_root/dirty" c.txt c "c"
printf 'staged\n' > "$git_root/dirty/a.txt"
git -C "$git_root/dirty" add a.txt >/dev/null 2>&1
printf 'modified\n' > "$git_root/dirty/b.txt"
printf 'staged\n' > "$git_root/dirty/c.txt"
git -C "$git_root/dirty" add c.txt >/dev/null 2>&1
printf 'then modified again\n' > "$git_root/dirty/c.txt"
printf 'untracked\n' > "$git_root/dirty/d.txt"
render_git_case dirty "$git_root/dirty"

# ahead_behind: two unpushed local commits, and one commit pushed to origin by a second clone and
# then fetched -> "sync +2 -1". Requires the fetch: without it the local ref has nothing to be
# behind, which is exactly the trap this case exists to catch.
gf_init "$git_root/ahead_behind"
gf_commit "$git_root/ahead_behind" f.txt base "init"
git -C "$git_root/ahead_behind" remote add origin "$gf_origin" >/dev/null 2>&1
git -C "$git_root/ahead_behind" push -q -u origin main:ab >/dev/null 2>&1
git -C "$git_root/ahead_behind" branch --set-upstream-to=origin/ab main >/dev/null 2>&1
git clone -q --branch ab "$gf_origin" "$git_root/pusher" >/dev/null 2>&1
git -C "$git_root/pusher" config user.email fixture@example.invalid
git -C "$git_root/pusher" config user.name Fixture
gf_commit "$git_root/pusher" f.txt remote "remote side"
git -C "$git_root/pusher" push -q origin ab >/dev/null 2>&1
gf_commit "$git_root/ahead_behind" g.txt one "local one"
gf_commit "$git_root/ahead_behind" h.txt two "local two"
git -C "$git_root/ahead_behind" fetch -q origin >/dev/null 2>&1
render_git_case ahead_behind "$git_root/ahead_behind"

# no_upstream: committed, but no remote at all -> "sync none" in orange, branch yellow. Distinct
# from ahead/behind: git omits BOTH branch.upstream and branch.ab here, so an implementation that
# only checked branch.ab would wrongly report this as in sync.
gf_init "$git_root/no_upstream"
gf_commit "$git_root/no_upstream" f.txt base "init"
render_git_case no_upstream "$git_root/no_upstream"

# initial: repo with no commits yet -> branch.oid is "(initial)", branch.head is still "main", so
# the branch item shows the name and sync shows none. The untracked file confirms counting still
# works before the first commit.
gf_init "$git_root/initial"
printf 'untracked\n' > "$git_root/initial/f.txt"
render_git_case initial "$git_root/initial"

# detached: branch.head is the literal "(detached)" -> the branch item falls back to the short oid,
# rendered as "@abc1234".
gf_init "$git_root/detached"
gf_commit "$git_root/detached" f.txt one "one"
gf_commit "$git_root/detached" f.txt two "two"
git -C "$git_root/detached" checkout -q HEAD~1 >/dev/null 2>&1
render_git_case detached "$git_root/detached"

# long_branch: a branch name past the 24-char truncation cap -> the branch value is ellipsized, and
# because branch is the row's LAST item, its width must not pad any other row's columns. Compare
# this case's non-git rows against no_upstream's: they should be identical, since the only
# difference between the two repos is the branch name. That comparison needs the two directory
# names to be the same length ("long_branch"/"no_upstream", 11 each), because the env row prints
# cwd and every row shares column widths - keep them equal-length if either is ever renamed.
gf_init "$git_root/long_branch"
git -C "$git_root/long_branch" checkout -q -b \
  feature/extremely-long-branch-name-for-column-alignment >/dev/null 2>&1
gf_commit "$git_root/long_branch" f.txt base "init"
render_git_case long_branch "$git_root/long_branch"

# conflict: a merge stopped on a conflict -> "state merge | conflict 1", branch red. The conflicted
# file must NOT also inflate the staged/dirty counts - unmerged paths are "u" entries in porcelain
# v2, counted separately from the "1"/"2" entries.
gf_init "$git_root/conflict"
gf_commit "$git_root/conflict" f.txt base "base"
git -C "$git_root/conflict" checkout -q -b other >/dev/null 2>&1
gf_commit "$git_root/conflict" f.txt other "other side"
git -C "$git_root/conflict" checkout -q main >/dev/null 2>&1
gf_commit "$git_root/conflict" f.txt mine "my side"
git -C "$git_root/conflict" merge -q other >/dev/null 2>&1 || true
render_git_case conflict "$git_root/conflict"

# rebase: a rebase stopped on a conflict -> "state rebase 1/2" from rebase-merge/msgnum + end.
gf_init "$git_root/rebase"
gf_commit "$git_root/rebase" f.txt base "base"
git -C "$git_root/rebase" checkout -q -b topic >/dev/null 2>&1
gf_commit "$git_root/rebase" f.txt topic1 "topic one"
gf_commit "$git_root/rebase" g.txt topic2 "topic two"
git -C "$git_root/rebase" checkout -q main >/dev/null 2>&1
gf_commit "$git_root/rebase" f.txt mainside "main side"
git -C "$git_root/rebase" checkout -q topic >/dev/null 2>&1
git -C "$git_root/rebase" rebase main >/dev/null 2>&1 || true
render_git_case rebase "$git_root/rebase"

# cherry_pick: CHERRY_PICK_HEAD present -> "state cherry-pick". Checks the state precedence order
# too, since a conflicted cherry-pick is otherwise easy to misreport as a plain merge.
gf_init "$git_root/cherry_pick"
gf_commit "$git_root/cherry_pick" f.txt base "base"
git -C "$git_root/cherry_pick" checkout -q -b side >/dev/null 2>&1
gf_commit "$git_root/cherry_pick" f.txt side "side"
git -C "$git_root/cherry_pick" checkout -q main >/dev/null 2>&1
gf_commit "$git_root/cherry_pick" f.txt mine "mine"
git -C "$git_root/cherry_pick" cherry-pick side >/dev/null 2>&1 || true
render_git_case cherry_pick "$git_root/cherry_pick"

# worktree: rendered from a linked worktree, where --git-dir is <common>/worktrees/<name> and
# --git-common-dir is the original .git -> the "wt" item appears with the worktree's name.
gf_init "$git_root/wt_main"
gf_commit "$git_root/wt_main" f.txt base "init"
git -C "$git_root/wt_main" worktree add -q "$git_root/wt_linked" -b feature >/dev/null 2>&1
render_git_case worktree "$git_root/wt_linked"

# stash: two stashed entries, work tree otherwise clean -> "stash 2" with no dirty/new items.
gf_init "$git_root/stash"
gf_commit "$git_root/stash" f.txt base "init"
printf 'one\n' > "$git_root/stash/f.txt"
git -C "$git_root/stash" stash push -q -m one >/dev/null 2>&1
printf 'two\n' > "$git_root/stash/f.txt"
git -C "$git_root/stash" stash push -q -m two >/dev/null 2>&1
render_git_case stash "$git_root/stash"

# not_a_repo: an ordinary directory -> the git row is omitted entirely, and every other row renders
# exactly as it does for p01_full_promax.json.
mkdir -p "$git_root/plain"
printf 'hello\n' > "$git_root/plain/file.txt"
render_git_case not_a_repo "$git_root/plain"

# missing_cwd: a path that doesn't exist at all -> git row omitted, no error output, no crash.
render_git_case missing_cwd "$git_root/does-not-exist"

# inside_git_dir: cwd is the .git directory itself, where --is-inside-work-tree is false and
# `git status` would fail -> the probe stops before the status call and the row is omitted.
render_git_case inside_git_dir "$git_root/clean/.git"

rm -rf "$git_root"

# Exit status reflects the structural checks only - the rendered fixtures above are for review by
# eye, so there is nothing here to pass or fail them on.
exit "$structural_fail"
