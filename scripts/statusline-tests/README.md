# statusline.sh test fixtures

Manual test payloads for `../statusline.sh`, saved here so a future review pass can replay them
instead of re-synthesizing test JSON from scratch. Not a hook, not a graded eval set (see
`evals/README.md` for why that directory is scoped to skill trigger/behavioral evals instead) -
just fixture files plus a thin runner, which prints rendered output for review rather than grading
it. The one exception is the structural-check section `run.sh` prints first, described under
[Structural checks](#structural-checks) below: those do assert, and are the only thing the script's
exit status reflects.

There are five kinds of fixture here, because the status line draws on five different sources:

- `*.json` / `*.txt` in this directory are stdin payloads (the statusLine JSON, or edge-case
  non-JSON input). One case is generated rather than checked in: the reset countdown, whose
  `resets_at` epochs `run.sh` computes from the current clock, because any hardcoded epoch renders
  either as "now" or as decades away.
- `org-fixtures/*.claude.json` are stand-ins for `$HOME/.claude.json`, used to test the env row's
  "org" item, which is read from that file instead of stdin. `run.sh` replays those against a temp
  `$HOME` rather than feeding them to statusline.sh as stdin.
- `transcript-fixtures/*.jsonl` are stand-ins for the JSONL transcript at `.transcript_path`, used
  to test the session row's turns/msgs/batch items. `run.sh` points `.transcript_path` at each one
  in turn via a `jq`-edited copy of `p01_full_promax.json`.
- The compact-percentage cases have no files either: they vary `CLAUDE_CODE_AUTO_COMPACT_WINDOW`,
  which `statusline.sh` reads straight from the environment, so `run.sh` just re-runs a fixed
  payload once per value of it. `run.sh` unsets that variable (and `CLAUDE_CONFIG_DIR`) for every
  other case, so the caller's own environment can't change what the rest of the suite renders.
- The git-row cases have no files at all: that row is derived from real `git` calls against `.cwd`,
  so `run.sh` builds a temp repository per case at run time (clean, dirty, ahead/behind, detached,
  mid-rebase, linked worktree, and so on), renders each, and deletes them.

The last four hold stdin's other fields fixed at `p01_full_promax.json` and vary only the one thing
each is testing - see `run.sh`'s header comment for why (two compact cases borrow `p21`/`p31`
instead, since window size and `used_percentage` are payload fields rather than environment ones).

## Usage

```
./run.sh                        # default (VSYNC-aligned) rendering
CCSTATUS_VSYNC=0 ./run.sh       # unaligned-columns rendering
```

Each fixture's purpose is documented in `run.sh`'s header comment. Read the printed output by
eye - color tiers, item presence/omission, formatting - against the expectations listed there.
Exit status is 0 when the structural checks pass and 1 when any fails; the rendered fixtures never
affect it, since nothing here knows what they should look like.

`p02_fallback.json` and any fixture with `rate_limits` null/absent will make a live (cached,
read-only) call to `https://api.anthropic.com/api/oauth/usage` via `statusline.sh`'s own
cost-capped-seat fallback path, so their `usage`/`total`/`max` values reflect this account's real
spend and will legitimately differ between runs - don't treat those as fixed expected values.

## Structural checks

Each row's at-rest value color comes from one `ROW_*_BASE` variable in `statusline.sh`, so a row can
be recolored in a single place. That indirection has a failure mode no rendered output can show: an
item that hardcodes a palette color renders identically today and silently stops following its row
the next time that base is reassigned - the divergence appears an edit later, in a diff nobody is
looking at. So `run.sh` checks the invariant as text instead:

- every `ROW_*_BASE` is defined exactly once and expanded by at least one item, catching a base
  that was defined and then never wired up (or wired up and later orphaned);
- no color a `ROW_*_BASE` points at is expanded anywhere else in the script, catching the hardcoded
  item above. Failures cite real file line numbers.

The color set is derived from the `ROW_*_BASE` right-hand sides rather than hardcoded here, so it
follows a base that gets pointed at a different palette entry. Alert colors
(`BYELLOW`/`ORANGE`/`BRED`), the git row's neutral `GIT_NEUTRAL_COLOR`, the shared healthy floor
`ESCALATION_BASE`, and the structural `ITEM_LABEL_COLOR`/`ROW_TITLE_COLOR`/`ITEM_MUTED_COLOR`/
separator colors are exempt by construction: none of them is a base, which is the same boundary
`statusline.sh`'s own definition-block comment draws. `GIT_NEUTRAL_COLOR` and `ESCALATION_BASE`
hold their own escape-code literals rather than aliasing the palette entry they currently match,
precisely so this textual scan can't read them as a stray expansion of a base's color.

The second structural section covers credential and cache scoping on the cost-capped-seat fallback
path - which account's OAuth token backs the `/api/oauth/usage` call, and where that call's
response is cached. Both are `CLAUDE_CONFIG_DIR`-scoped, and getting either wrong shows one
account's spend under another account's org label, which is a bug rendered output looks entirely
healthy for. Fake `curl`, `security` and `uname` executables placed first on `PATH` make the
outcomes deterministic and let both the macOS and non-macOS branches run on any machine; the fake
`curl` records the token it was called with, so the assertions are on the credential actually used
rather than on what got printed. The cases are listed in `run.sh`'s header comment, and cover the
macOS `CLAUDE_CONFIG_DIR`-scoped Keychain lookup, its two missing-entry outcomes (a loud error row
when this profile has logged in, silence when it hasn't), the unset-`CLAUDE_CONFIG_DIR` default,
the file-based non-macOS path, the no-credential-anywhere case that must read `usage n/a` rather
than `usage withheld`, and cache-directory separation across accounts.

## Regression-checking a future edit

To confirm a change to `statusline.sh` doesn't alter behavior, diff `run.sh`'s output between the
pre-edit and post-edit versions of the script (copy the script, apply the candidate edit to one
copy, run both through these fixtures, `diff` the two outputs). A byte-for-byte match across every
fixture here, in both VSYNC states, confirms the edit is behavior-preserving.

Two things in that output are expected to differ run to run and are not regressions:

- `p02_fallback.json` and any fixture with `rate_limits` null/absent, as described above.
- Every git fixture, because each run builds its repositories under a fresh `mktemp -d` and that
  path is printed in the env row's `cwd` item (and shifts column alignment with it). Diff the
  `git` rows specifically, or normalize the temp path first.
