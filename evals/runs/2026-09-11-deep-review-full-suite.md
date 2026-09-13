---
created: 2026-09-11
updated: 2026-09-13
---

# `deep-review` 2026-09-11: full eval-suite run (trigger + behavioral), current description

A full run of both eval layers against the `SKILL.md` committed by the 2026-09-11 commit "Bound
deep-review's output and move its dispatch rationale to a reference". This
is not a regeneration diff-check - it is the first full-suite measurement of the description as it
now stands.

**Revision note (same day): the trigger-eval section below was rewritten in place.** The first pass
of this run tested `trigger-evals.json` cases built for description **variant E**
(`runs/2026-09-09-deep-review-trigger-regen.md`), including phrases like "should we even do this",
"play devil's advocate", and "poke holes in this". Between that decision and this run, the
description was refined again by the commit "Refine and improve the description for deep-review"
(2026-09-11), which dropped exactly those three phrases and added "does this provide value". The
first pass's write-up compared today's numbers against the 2026-09-09 variant-E figures as if it
were the same description and called the result a "sharp regression" - that comparison was invalid
(three of the compared queries test phrases the description no longer contains at all), and the
error was mine: I never actually read the live `SKILL.md` description before drawing that
conclusion, only recalled variant E from the earlier run file. The user caught this and asked for
`trigger-evals.json` to be rewritten to match the current description and the run redone. That is
what the section below now reports; the invalid regression narrative has been removed rather than
kept alongside it.

**Result: HOLD on both layers.** Trigger (rewritten case set, aligned to the current description's
9 enumerated phrases): 4 of 9 positives pass (>= 8/9), 9 of 9 negatives pass (0 fires). Behavioral:
deterministic 27/31 (87.1%, gate requires 100%), judgment 15/16 (93.75%, clears the 90% floor). Two
real behavioral misses, both the same root cause: the Purpose-gate rule that correctly refuses to
dispatch on bare fixture files also refuses to dispatch on legitimate in-conversation "should we do
this?" proposals that lack an explicit "so that / to fix / because" clause.

## Harness and environment

- Claude Code: `2.1.268`.
- `skill-creator` plugin: `3deb821cb71c`, installed 2026-08-04, **last updated 2026-09-11T17:22:48Z
  - hours before this run**, per `~/.claude/plugins/installed_plugins.json`. Diffed the cached
  orphaned prior version (`09555c965d32`) against the current one for the one file that mattered
  (`scripts/run_eval.py`): the `str | None` type-hint syntax was already present in the orphaned
  version too, so this is not a same-day regression introduced by the plugin update - whatever
  environment ran this successfully on 2026-09-09 had a Python 3.10+ interpreter that is no longer
  the machine's default.
- **New environment blocker, not previously documented**: this machine's `python3` resolves to
  `3.9.6` (Xcode Command Line Tools), and `run_eval.py` uses `str | None` union-type syntax
  (PEP 604), which raises `TypeError: unsupported operand type(s) for |: 'type' and 'NoneType'` on
  import under 3.9. No pyenv, conda, or Homebrew Python existed on this machine before this run.
  Fixed by installing `python@3.12` via Homebrew (already present, `6.0.20`) and invoking
  `/opt/homebrew/bin/python3.12` explicitly. Added to `evals/README.md`'s trigger-precondition
  list: **wrong Python version is a silent import-time crash, not a "did not trigger"
  false-green** - it fails loudly (non-zero exit, traceback in stderr) rather than producing a
  plausible-looking result, which makes it the easy case among these failure modes as long as the
  exit code and stderr are actually checked rather than only the results JSON.
- **Second new failure mode, found and root-caused this run**: isolating the trigger-eval scratch
  run by pointing `CLAUDE_CONFIG_DIR` at a fresh empty directory (to avoid touching the live
  `~/.claude/skills/deep-review`) also strips login state, since credentials resolve relative to
  that same config root. Every `claude -p` subprocess then fails immediately with "Not logged in -
  Please run /login". `run_eval.py` redirects the child's stderr to `DEVNULL` (only stdout is
  captured), so this failure is invisible to the harness and to `evals/README.md`'s existing
  "`query failed` in stderr" tripwire - it just scores as zero triggers on every query, both
  positive and negative, which is indistinguishable from the already-documented void-run signature
  (uniform 0.0 positives, no `query failed` line, exit code 0) without directly testing
  `claude -p` under the same env override. **A uniform-zero result must be treated as suspect even
  when accompanied by a clean exit and empty stderr grep, and verified by manually invoking `claude
  -p` under the exact same environment the harness used, before being trusted at all.** This
  attempt's results were discarded, not recorded.
- Given that, the actual isolation method used for the recorded run below is the one the
  2026-09-09 run also used: temporarily relocate the live `~/.claude/skills/deep-review` directory
  to `/tmp`, restore it via a shell trap on exit/interrupt/error, and verify `SKILL.md` is present
  at the live path afterward. The Claude Code sandbox's auto-mode safety classifier initially
  refused this as "Irreversible Local Destruction" even guarded by the trap; the user was asked
  and explicitly approved it before the run. Restoration was verified successful both times this
  was run (see below).
- `--skill-path` pointed at a throwaway git worktree (`.worktrees/deep-review-eval-20260911`,
  branch `deep-review-eval-20260911` off `origin/main`, at the 2026-09-11 "Bound deep-review's
  output" commit) rather than the live path,
  so the description under test is decoupled from whatever is temporarily parked at the live path.
  The worktree's `SKILL.md` already matched the live description throughout this run (both are
  the same 2026-09-11 commit); only `trigger-evals.json` needed rewriting, and its eval-set file was
  copied out to
  `/tmp` before parking, since it lives inside the directory the park step moves.
- Model for trigger evals: `claude-sonnet-5`, `--num-workers 1 --timeout 120 --runs-per-query 9
  --trigger-threshold 0.88`. No `query failed` lines in stderr on either recorded trigger run. Wall
  clock not precisely timed but consistent with prior ~5s/call serial runs.
- Model for behavioral eval executors: **Sonnet**, deliberately (per 2026-09-07's finding: at Opus
  the skill folds its second phase inline and dispatch-related assertions cannot be observed).
  Grading was done by the dispatching agent itself following `agents/grader.md`, not a separate
  grader subagent per case; judge model was that same agent's tier (Sonnet).
- No baseline (`without_skill`) arm was run for the behavioral layer, consistent with this
  repository's convention since 2026-09-08 for an actively-developed skill with prior baseline
  history already on record.

## Trigger evals: 4 of 9 positives pass, 9 of 9 negatives pass

`trigger-evals.json` was rewritten for this run to drop the three cases keyed to phrases the
current description no longer enumerates ("poke holes in the migration plan", "should we even do
this? feature flag service", "play devil's advocate... runbooks") and keep exactly one positive
case per each of the description's 9 current phrases. The 9 negatives are unchanged from every
prior run of this eval set.

| Expect | Query (short) | Rate | Pass (>=8/9)? |
| --- | --- | --- | --- |
| pos | deep review this before I commit it... (phrase: "deep review") | 9/9 | yes |
| pos | is this a good idea? billing service split (phrase: "is this a good idea") | 4/9 | no |
| pos | be critical about this... two approvals PR (phrase: "be critical") | 0/9 | no |
| pos | rigorous review of the capacity model (phrase: "rigorous review") | 8/9 | yes |
| pos | does this belong here? retry/backoff logic (phrase: "does this belong here") | 7/9 | no |
| pos | is there a better way to do this? S3 dump (phrase: "is there a better way") | 0/9 | no |
| pos | is this the best way to do this - pre-commit hook (phrase: "is this the best way to do this") | 9/9 | yes |
| pos | does this serve its purpose? health-check.sh (phrase: "does this serve its purpose") | 3/9 | no |
| pos | does this provide value? metrics digest email (phrase: "does this provide value") | 9/9 | yes |
| neg | all 9 negative cases | 0/9 each | yes (all) |

Against the repository's threshold ("every positive at >= 8 of 9 runs, and every negative case at
0 fires"): **FAIL** on positives (4 of 9), **PASS** on negatives (9 of 9).

No before/after comparison table is included this time: the prior run's comparison was against a
different phrase set (variant E), which is exactly the invalid comparison this revision removes,
and there is no other prior measurement of this exact 9-phrase description to compare against.
This run is now the baseline figure for the current description, for whenever it is next measured.

Five of the nine current phrases land below the gate even with cases now correctly aligned to
them: "is this a good idea" (4/9), "be critical" (0/9), "does this belong here" (7/9), "is there a
better way" (0/9), and "does this serve its purpose" (3/9). "be critical" and "is there a better
way" firing zero times out of nine is notable given both are quoted verbatim in the description's
example list - quoting a phrase is necessary but, as this repository's history has shown before,
not sufficient for it to reliably fire.

## Behavioral evals: deterministic 27/31 (87.1%), judgment 15/16 (93.75%)

| Eval | Prompt (one-line) | Pass/Total | Deterministic | Judgment | Defect |
| --- | --- | --- | --- | --- | --- |
| 1 | Plain "review this doc" on onboarding-note.md (should-NOT-fire case) | 3/3 | 3/3 | 0/0 | not fairly testable (see below) |
| 2 | Rename `n` to `count`, no code shown | 4/4 | 3/3 | 1/1 | none |
| 3 | Same rename, user declines full pass | 3/3 | 3/3 | 0/0 | none |
| 4 | Raise `connect_timeout_seconds` 5 to 30, shared default | 6/6 | 4/4 | 2/2 | none |
| 5 | Rigorous review of a sound CI-lockfile proposal | 5/5 | 3/3 | 2/2 | none |
| 6 | Critique CI auto-retry-twice plan | 3/3 | 1/1 | 2/2 | none |
| 7 | Push back on merging 7 skills into 1 file | 3/3 | 1/1 | 2/2 | none |
| 8 | Be critical: full health-check as pre-commit hook | 1/3 | 0/1 | 1/2 | gate-stopped on Purpose instead of dispatching; no verdict, no counter-argument to the hook produced |
| 9 | Deep review bare cache-warmer.py | 4/4 | 3/3 | 1/1 | none |
| 10 | "Should we even do this?" - second config repo idea | 2/5 | 0/3 | 2/2 | gate-stopped on Purpose instead of dispatching; no verdict/counter-argument (alternatives were still named well) |
| 11 | Deep review bare rotate-logs.sh | 4/4 | 3/3 | 1/1 | none |
| 12 | Deep review sync_inventory.py (README/CHANGELOG/crontab present) | 4/4 | 3/3 | 1/1 | none |

Against the repository's thresholds: deterministic checks **FAIL** (87.1%, requires 100%);
judgment checks **PASS** the 90% aggregate floor (93.75%), and there is no directly comparable
full-12-eval prior baseline to check for a per-case regression against (2026-09-08's runs covered
only subsets: evals 2, 3, 6, 9, 11, 12).

**Eval 1 cannot fairly test what it is built to test**, and this is not a new finding - it is the
same structural limitation `evals/README.md` already records in footnote 10 for this identical
case. The behavioral harness hands the executor `Skill path: <path>` directly, which pre-empts
Claude's own routing decision; there is no trigger choice left to observe. In this run the three
expectations passed only because the fixture's Purpose field happened to be unfillable, which
blocked dispatch as a side effect of an unrelated gate - not because the skill declined to engage
with a shallow request. Recorded as measured, not rescored away, per that precedent, and not
counted as validating trigger behavior.

**The one real defect pattern**: the Purpose-gate rule (built for and verified working on bare
fixture files - evals 9, 11, 12 all pass 4/4) also fires on in-conversation "I want to do X"
proposals that lack an explicit "so that / to fix / because" clause. Evals 8 ("I want every commit
to run health check as a pre-commit hook") and 10 ("I'm thinking of adding a second config
repo...") both lack that clause and were gate-stopped before dispatch; evals 6 ("to fix flaky CI")
and 7 ("so there's only one thing to maintain") contain one and reached a full dispatched verdict.
This is a real tension: the same rigor that correctly blocks a caveated verdict on an unexplained
script also blocks the premise-critique of an ordinary "should we do this?" idea - which the
skill's own material calls one of the highest-value targets there is.

Other notes from the executing agent, kept for context:

- Where the skill ran end-to-end (4, 5, 6, 7), execution was clean: exactly one
  `general-purpose`/opus dispatch, never `fork`, a verdict immediately followed by its own
  strongest counter-argument, findings tied to specific quotes or line numbers.
- The two `AskUserQuestion`-touching expectations (evals 2, 3) were graded against the plain-text
  fallback only, since that tool is unavailable inside a subagent - both executors used the
  fallback correctly and passed, consistent with the prior documented workaround.
- The three bare-file Purpose-gate cases (9, 11, 12) were the most reliable part of the suite: all
  three did real context search (git log, sibling files, repo-wide grep) before concluding Purpose
  was unfillable, and correctly separated "nothing considered" (fillable) from "unknown"
  (blocking) for the other brief fields.

## Decision

**HOLD.** Both layers fail their respective gates: trigger positives at 4 of 9 (need every positive
at >= 8/9), behavioral deterministic at 87.1% (need 100%). Unlike the first pass of this run, the
trigger figure now reflects the description actually in `SKILL.md` and needs no reproducibility
check to be trusted - it is a real, if unflattering, measurement: five of the nine currently
enumerated phrases do not reliably trigger the skill, including two ("be critical", "is there a
better way") that fire zero times out of nine despite being quoted verbatim. The behavioral defect
has a specific, actionable shape: the Purpose-gate needs either a narrower trigger condition
(bare-artifact targets only, not in-conversation proposals) or an explicit carve-out for the
"should we do this?" case class, which the skill's own material already treats as high-value.

No prior committed ref is being pinned as a new baseline by this run, consistent with the standing
note in `evals/README.md` that no artifact in this table has ever had a valid pinned baseline ref.

Raw trigger-eval JSON: `/tmp/dr-trigger-run-20260911-park-v2.out` (the corrected run; the first
pass's now-superseded output is still at `/tmp/dr-trigger-run-20260911-park.out` for reference).
Behavioral raw outputs and
transcripts: `/tmp/dr-behavioral-eval-20260911/eval-<1-12>/{output.md,transcript.md}`. The eval
worktree (`.worktrees/deep-review-eval-20260911`) was left in place after this run rather than
removed, at the user's implicit denial of a bundled cleanup command that combined a force branch
delete with other git-state changes in one call; it holds no unique content (a clean checkout of
the 2026-09-11 "Bound deep-review's output" commit) and can be removed with
`git worktree remove .worktrees/deep-review-eval-20260911`
followed by a separate, individually-confirmed `git branch -d deep-review-eval-20260911` whenever
convenient.
