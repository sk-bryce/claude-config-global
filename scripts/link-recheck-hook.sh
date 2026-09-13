#!/usr/bin/env bash
#
# link-recheck-hook.sh - shared logic for the non-blocking "recheck References-section links
# after a Markdown edit" hook (decisions/0004-document-generation-as-always-on-rule.md,
# reference/document-generation.md).
#
# Per decisions/0003-hooks-and-scripts-authoring-policy.md, this file (hook logic) may be
# model-generated and is reviewed in full before commit; the registration that activates it (the
# settings.json PostToolUse entry) is a separate, human step. This script only reports; it never
# blocks, edits the file, or exits non-zero, so a caller can safely ignore its exit code (kept 0 in
# every path as a second guard).
#
# Usage: link-recheck-hook.sh <file-path>
#        link-recheck-hook.sh --probe <url>     (internal, used by the parallel fan-out below)
#   No-ops for anything that isn't a *.md file, a missing file, or a file with no
#   "# References"-style heading.
#
# Three cost properties, all deliberate, all of them things this script did NOT do before
# (see docs/efficient-agentic-use/04-configuration-hygiene.md's hook-cost section, which names
# exactly this check as its worked example of a hook running more often than its answer changes):
#
#   1. SILENT ON SUCCESS. Only BROKEN and inconclusive results are printed. A run where every link
#      resolves prints nothing at all. The old behavior printed one line per link including every
#      "ok", and on a hook path that output lands in the model's context on every single turn -
#      paying context for the answer "nothing changed", which is the answer almost every time.
#   2. DEDUPED BY CONTENT, NOT BY EDIT. A state file records the hash of the URL set last checked
#      for a given document. If the set has not changed and it was checked within the freshness
#      window below, the run exits silently without a single network call. Link rot does not appear
#      between two edits seconds apart, so rechecking on every edit is pure cost for no added
#      safety. Keying on the URL set rather than the session means this also holds across sessions,
#      and that adding one new link rechecks the whole set rather than being missed.
#   3. PARALLEL. Probes run concurrently instead of serially. Serial probing at up to 10s each meant
#      a document with 18 reference links could exceed the 120s hook timeout in settings.json and be
#      killed partway through, silently reporting nothing.
#
# Verification rules mirrored from reference/document-generation.md (do not duplicate the
# rationale here - that file is the source of truth if the two ever disagree):
#   200 / other 2xx, or a 3xx that resolves after following redirects -> ok      (not printed)
#   404, DNS failure, connection refused                              -> BROKEN  (printed)
#   403, 429 (bot-protection/rate-limit)                              -> inconclusive (printed)
#   timeout or other network error                                    -> inconclusive (printed)

set -uo pipefail  # deliberately not -e: this hook only ever reports or silently exits 0 (see the
                  # header), so no single step - mkdir, cat on a state file, one probe subprocess,
                  # the pruning find - may abort the run; each is written to fall through safely.

# How long a clean result stays trusted before the same URL set is probed again. Long enough that
# an editing session never re-probes, short enough that genuine rot surfaces within a day.
FRESH_MINUTES=1440
PARALLELISM=8

# --- Internal probe mode -------------------------------------------------------------------------
# Split out so xargs can fan the probes out across processes. Prints "code<TAB>url" and nothing else.
if [[ "${1:-}" == "--probe" ]]; then
  url="${2:-}"
  [[ -n "$url" ]] || exit 0
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -L \
    -A 'Mozilla/5.0 (link-recheck-hook)' "$url" 2>/dev/null)"
  [[ -z "$code" ]] && code="000"
  printf '%s\t%s\n' "$code" "$url"
  exit 0
fi

f="${1:-}"
[[ -z "$f" || ! -f "$f" ]] && exit 0
case "$f" in
  *.md) ;;
  *) exit 0 ;;
esac

# Scope to the References section onward, matching reference/document-generation.md's own scope
# (a link cited as supporting material, not the file being edited itself), and drop fenced code
# blocks so illustrative example URLs (like the ones in this repo's own document-generation.md
# format examples) are never mistaken for real citations.
refs="$(awk '
  /^```/ { in_fence = !in_fence; next }
  in_fence { next }
  /^#+[[:space:]]+References[[:space:]]*$/ { found = 1 }
  found
' "$f")"
[[ -z "$refs" ]] && exit 0

urls="$(printf '%s\n' "$refs" \
  | grep -oE '\]\(https?://[^)[:space:]]+\)' \
  | sed -E 's/^\]\(//; s/\)$//' \
  | sort -u)"
[[ -z "$urls" ]] && exit 0

# --- Freshness gate ------------------------------------------------------------------------------
# Keyed on this script's own on-disk location rather than $HOME or $CLAUDE_CONFIG_DIR, matching how
# md-ledger-append.sh and md-deferred-checks.sh resolve their ledger directory: the state directory
# must not depend on CLAUDE_CONFIG_DIR being set, since this script can run under a profile where
# it is not.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
state_dir="$(dirname "$script_dir")/cache/link-recheck"
mkdir -p "$state_dir" 2>/dev/null || true

abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
# cksum rather than md5sum/sha1sum: POSIX, present everywhere, and a collision here costs at most a
# skipped recheck of one document, not a correctness bug.
key="$(printf '%s' "$abs" | cksum | tr -d ' ' | tr '/' '_')"
url_hash="$(printf '%s' "$urls" | cksum | tr -d ' ')"
state="$state_dir/$key.state"

if [[ -f "$state" ]] \
   && [[ "$(cat "$state" 2>/dev/null)" == "$url_hash" ]] \
   && [[ -n "$(find "$state" -mmin "-$FRESH_MINUTES" 2>/dev/null)" ]]; then
  exit 0
fi

# --- Probe in parallel, report only what is not ok -------------------------------------------------
results="$(printf '%s\n' "$urls" \
  | xargs -r -P "$PARALLELISM" -I{} "$script_dir/$(basename "${BASH_SOURCE[0]}")" --probe {} \
  2>/dev/null)"

had_finding=0
while IFS=$'\t' read -r code url; do
  [[ -n "$url" ]] || continue
  case "$code" in
    2??|3??) continue ;;
    403|429) status="inconclusive (bot-protection/rate-limit - not confirmed broken)" ;;
    404)     status="BROKEN (404)" ;;
    000)     status="inconclusive (no response or timeout)" ;;
    *)       status="inconclusive (HTTP $code)" ;;
  esac
  printf 'link-recheck: %s [%s] %s\n' "$url" "$code" "$status"
  had_finding=1
done <<< "$results"

# Only record a clean bill of health, and only when every URL actually came back. A run that found
# something stays unrecorded on purpose, so the next run reports it again rather than going quiet on
# an unresolved problem after one mention.
#
# The count comparison is the important half: if the fan-out itself fails (xargs missing, the script
# path unresolvable, the process killed by the hook timeout), `results` comes back empty, no line is
# ever classified, and had_finding stays 0 - which without this guard would write a "clean" state and
# suppress the next 24 hours of checking on the strength of a run that never probed anything.
url_count="$(printf '%s\n' "$urls" | grep -c .)"
result_count="$(printf '%s\n' "$results" | grep -c .)"
if [[ "$had_finding" -eq 0 && "$result_count" -eq "$url_count" ]]; then
  printf '%s' "$url_hash" > "$state" 2>/dev/null
fi

# Prune state for documents that have not been rechecked in a long time, so cache/ does not
# accumulate an entry per document forever.
find "$state_dir" -maxdepth 1 -type f -name '*.state' -mtime +30 -delete 2>/dev/null || true

exit 0
