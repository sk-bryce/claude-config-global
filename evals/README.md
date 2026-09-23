---
created: 2026-07-27
updated: 2026-09-23
---

# Evals: Repo-Wide Run Procedure

This directory holds the repo-wide eval layer only - the run procedure, thresholds, and a
results log. Per-artifact test cases stay co-located with their artifact in the native
skill-creator format (`skills/<name>/evals/evals.json`), not here. See
`reference/spec-driven-architecture.md` (Evals section) for why the eval gate exists and
`decisions/0001-adopt-spec-driven-config-architecture.md` for the decision to gate LLM-class
regeneration with evals.

## Scope and tooling

Native-first, and the plugin provides **two separate mechanisms** which this procedure keeps
separate:

- **Behavioral evals** - `skills/<name>/evals/evals.json`, run through the plugin's
  spawn-subagents-and-grade harness (`scripts.aggregate_benchmark`, the grader agent, the eval
  viewer).
- **Trigger evals** - `skills/<name>/evals/trigger-evals.json`, a flat array of
  `{"query": ..., "should_trigger": true|false}`, run through
  `python -m scripts.run_loop --eval-set <file> --skill-path <skill> --model <model-id>`.

No new dependency or tool is introduced by this repository.

## Two eval layers per artifact

Every skill should carry both layers, in **two different files** (see
`decisions/0001-adopt-spec-driven-config-architecture.md` for why non-deterministic
regeneration needs this gate at all):

1. **Trigger evals (deterministic), in `skills/<name>/evals/trigger-evals.json`.** Positive queries
   that must invoke the skill and negative queries that must not, derived from the trigger phrases
   and non-goals in the skill's spec section (`specs/skills.md`, or `specs/behaviors.md`'s Plan and
   Execute section for `write-plan` and `execute-plan`). The assertion is binary (did it fire?) and
   needs no model judge.

   **These cannot live in `evals.json`, and putting them there produces a silent false pass.** The
   behavioral harness hands the executor the skill by path - its prompt template is literally
   `Skill path: <path-to-skill>` - so the skill is pre-selected and there is no triggering decision
   left to observe. A negative-trigger assertion graded from that transcript is not measuring
   whether the description would have fired; in the with-skill arm it is guaranteed to fail and in
   the without-skill arm it is guaranteed to pass vacuously. A regenerated skill with a badly
   over-eager description would pass every such case while mis-triggering in production. Only
   `run_loop.py` presents the model with a real `available_skills` choice.

   **Before trusting any `run_loop.py` output, confirm `claude` resolves on the invoking shell's
   `PATH` and that `stderr` contains no `query failed` lines.** `run_eval.py` shells out to
   the `claude` binary and **counts a failed invocation as "did not trigger."** A run in which the
   binary is missing therefore scores 100 percent on every negative query, exits 0, and writes a
   normal `results.json` with no error field on any record - a perfect negative sweep from a run that
   executed nothing. This happened on 2026-09-05. Treat uniformly 0.0 positives as an environment
   failure until proven otherwise, and never record a trigger figure from a run whose stderr carries
   a `query failed` line.

   **Run trigger evals from a scratch project root, with the skill under test NOT installed.**
   `run_eval.py` does not install the skill; it writes a synthetic command file to
   `<project_root>/.claude/commands/<name>-skill-<uuid>.md` and counts a trigger only when that
   generated name appears in the tool input. If the real skill is installed under `~/.claude/skills/`
   it fires instead, the generated name never appears, and every correct trigger is scored as a miss.
   The detector also returns False on the first tool call if it is anything other than `Skill` or
   `Read`, so a run inside a real repository - where the model reasonably opens with `Bash` or `Grep`
   to orient itself - scores misses for that reason alone. Note too that `find_project_root` walks up
   from the **working directory**, not from `--skill-path`: run from the wrong place it will write its
   command file into your live `~/.claude/.claude/commands/`.

   Set up as: `mkdir -p /tmp/scratch-proj/.claude`, uninstall the skill under test, then run with
   `cwd=/tmp/scratch-proj` and `PYTHONPATH` pointed at the plugin's skill directory. Raise `--timeout`
   above the 30-second default; a substantive query can take longer than that to reach its first tool
   call.

   **All three failure modes look identical and all three exit 0**: binary missing from `PATH`, skill
   installed, and a non-`Skill` first tool call each produce 100 percent on negatives and near-zero on
   positives, because "did not trigger" is exactly what a negative query asserts. A trigger set
   weighted toward negatives will report a high pass rate under every one of them. Never accept a
   trigger figure without checking the positive rate first.

   **A wrong Python version fails loudly, which makes it the easy case; an empty `CLAUDE_CONFIG_DIR`
   fails silently, which makes it a sixth false-green mode.** `run_eval.py` uses `str | None`
   (PEP 604) syntax and needs Python 3.10+; under an older interpreter it crashes at import with a
   `TypeError` and a non-zero exit - unmissable, unlike the five modes above. But isolating the
   scratch run by pointing `CLAUDE_CONFIG_DIR` at a fresh empty directory instead of parking the
   live skill directory strips login state along with it, since credentials resolve relative to
   that same config root; every `claude -p` subprocess then fails with "Not logged in", invisibly,
   because `run_eval.py` redirects the child's stderr to `DEVNULL`. The result is indistinguishable
   from the void-run signature above - uniform 0.0 on every query, exit code 0, nothing in stderr.
   Verify by invoking `claude -p` once by hand under the exact env override the harness will use,
   before trusting a uniform-zero result. Details: `runs/2026-09-11-deep-review-full-suite.md`.

   **Run serially: `--num-workers 1 --timeout 120`.** The `--num-workers 10` default starves the
   concurrent `claude -p` subprocesses and they time out before their first tool call, which the
   harness cannot distinguish from a description that did not fire. This is a fourth failure mode and
   it is worse than the other three, because it does not produce an obviously broken all-zero sweep -
   it produces a plausible, specific, wrong number. On 2026-09-05 the parallel default scored
   `deep-review` at 0 of 8 positives and that figure was written up as a skill defect and committed;
   the same description, same queries, same model, run serially, scores 8 of 8 at a mean rate of 0.96.
   A tell, if you have runs to compare: under this mode the *set* of failing queries moves between
   runs. An artifact defect does not relocate.

   **Assert the preconditions in the run script rather than trusting yourself to remember them.**
   Every one of these modes was already documented here on 2026-09-05 and the very next run hit the
   `PATH` one anyway, scoring three skills at 0 of 8 positives and 8 of 8 negatives. Start the script
   with `command -v claude >/dev/null || exit 1`, and check the wall clock: a valid serial run of a
   16-query set at 3 runs each makes 48 subprocess calls and takes tens of minutes. The void run
   finished in 130 milliseconds per skill. Anything that returns in seconds did not measure anything.

   **A void run can also be partial, and then it looks like data.** During the `go-dev` first
   build, one serial run left three positives that scored 9 of 9 on the runs either side at 0 of 9,
   including the most obviously-triggering query in the set, while two other positives still fired
   9 of 9 and every negative stayed clean. Exit code 0, no `query failed` line. It read as a
   catastrophic regression caused by the preceding description edit; re-running two of the collapsed
   queries in isolation scored 3 of 3 each. The uniform-zero signature above does not catch this,
   and because `run_eval.py` sends the child's stderr to `DEVNULL` the failing calls leave no trace.
   **The tripwire is mean wall time per call** - total run time divided by queries times
   runs-per-query. Healthy serial runs of that set measured 4.4 to 6.5 seconds per call; the void
   run measured 2.3. A run well below the band its predecessors set measured fewer real completions,
   whatever the results JSON says, so record the per-call figure in every run file to give the next
   run a band to compare against. Details: `runs/2026-09-19-go-dev-first-build.md`.

   **Never run `--optimize` against parallel-mode scores.** The optimizer grades its own proposed
   descriptions with this same harness, so it will rewrite a working description to fit timing noise
   and report the result as an improvement. Establish a trustworthy serial baseline first.

   Write these the way the plugin's own guidance asks: 16 to 20 realistic, specific queries, 8 to 10
   each way, with the negatives being genuine near-misses that share vocabulary with the skill rather
   than obviously-irrelevant filler. Note the plugin's own caveat that simple one-step queries may
   not trigger any skill regardless of description quality, so they make poor test cases.

   **Run each trigger case at least nine times and record the rate, not a single outcome.**
   `run_loop.py` already does this via `--runs-per-query`. Three runs is not enough: for a query
   whose true rate is near 0.85, the chance of scoring 3 of 3 is about 0.61, so n=3 tests whether a
   coin lands heads three times rather than testing a threshold. Triggering is
   not deterministic in practice: during the 2026-09-05 `deep-review` run, one case fired, then did
   not, then did, across three runs of an identical prompt that opened with a phrase the skill's
   description enumerates verbatim. A single run therefore cannot distinguish a real trigger defect
   from noise, and both error directions are expensive - a false pass ships a skill that misfires,
   a false fail sends someone editing a description that was fine. The threshold below applies to
   the rate: **a positive case must pass on at least 8 of 9 runs**, and **a negative case passes only
   by firing zero times**. Report any positive below 8 of 9 with its exact count as a finding to
   investigate. Mechanically, score positives with `--trigger-threshold 0.88` at
   `--runs-per-query 9`, which passes 9/9 and 8/9 and fails 7/9; judge negatives on their raw fire
   count rather than on a threshold, because a negative that fires even once is a real overlap and
   not sampling noise. **Do not read the harness's own PASS/FAIL flag for a negative case.**
   `run_eval.py` scores a negative as `rate < threshold`, so at a 0.88 threshold a negative that
   fires 7 times out of 9 is reported as PASS. Reading the script's flag instead of this
   document's rule is the exact error that invalidated the 2026-09-05 figure.

   **Run trigger cases at the tier `settings.json` configures, not only at the tier the session
   happens to be on.** Triggering is tier-dependent, and measuring it only from an escalated session
   reports a number that no default session will reproduce. On 2026-09-05 a `deep-review` trigger
   case that fired reliably at Opus did not fire at Sonnet - with the skill confirmed visible in that
   agent's skill list and `CLAUDE.md` loaded - given a prompt opening with the first phrase the
   skill's own description enumerates. Every trigger figure recorded for that skill had been measured
   at Opus. Record the tier next to the rate; a rate without a tier is not a result.
2. **Behavioral evals (mixed).** The skill's acceptance criteria from that same spec section,
   split per expectation into:
   - **Deterministic checks** (contains / regex / JSON-shape) - for example "the proposed
     description starts with the exact phrase 'This skill should be used when the user asks
     to'", or "sets `disable-model-invocation: true`".
   - **Judgment checks** (model-graded) - for genuinely qualitative expectations (for example
     "explains why the action is destructive"). Pin the judge model and the rubric text, and
     record both in the run file below.

Mark each `expectations[]` entry in a run record as deterministic or judgment when grading, so
the thresholds below can be applied separately to each kind.

## Thresholds

Decided 2026-07-27; revisit as case counts grow:

| Check kind | Threshold |
| --- | --- |
| Trigger evals | Every positive case at >= 8 of 9 runs, AND every negative case at 0 fires |
| Deterministic behavioral checks | 100 percent |
| Judgment (model-graded) checks | No per-case regression versus the pinned prior baseline, AND an aggregate pass rate >= 90 percent |

The no-regression rule protects against a rewrite silently breaking a case that used to pass;
the 90 percent aggregate floor tolerates single-case model-judge noise without letting a real
regression through. Pin the judge model per run to reduce that noise, and record it in the run
file.

## Paired comparison: first build vs. regeneration

- **First build** (no prior committed version exists): there is nothing to compare against, so
  the gate is the absolute floor above. The resulting run becomes the baseline for every future
  regeneration of that artifact.
- **Regeneration**: run both the pinned prior committed version (checked out at its git ref)
  and the new candidate against the *same* case set, and compare pass/fail per case - not only
  an absolute floor on the candidate alone. A case that passed on the prior version and fails on
  the candidate is a regression regardless of the candidate's aggregate pass rate.

## Run isolation

**Every run happens in a throwaway `git worktree`, never the checkout you care about.** These suites
are not read-only. `skills/health-check/evals/evals.json` case 6 ("Audit this repo, and go ahead and
fix whatever you find") hands an executor Edit and Write against the tracked tree and then grades it
on having edited tracked Markdown; `skills/research/evals/evals.json` cases 1 and 2 make real
WebSearch/WebFetch calls and write real files into `docs/`. Use the convention `CLAUDE.md` already
sets: `git worktree add .worktrees/<name>`, run there, remove after.

**Override `HOME` for any suite that touches machine state.** `skills/cursor-projection/evals/evals.json`
cases 3, 4 and 6 run `scripts/project-to-cursor.sh --check`, which diffs against the real
`~/.cursor/hooks.json`, `cli-config.json` and `mcp.json`. Case 4's premise is a user pushing the
agent to run `--apply`, so the failure mode the case exists to detect *is* a real hook registration
on the real machine. Point `HOME` at a scratch directory before running it.

**Never commit the grading tool's native output verbatim for a suite that touches machine state.**
Step 4 below offers `.json` "if the grading tool's native output is preferred verbatim" - that
option does not apply here. A `--check` run pulls real MCP server names and absolute home paths into
the executor transcript, and this repository targets a public remote. Hand-write the run file and
neutralise the paths, as `evals/runs/2026-08-03-write-plan.md` does with `<scratch>` and `<sandbox>`.
The plugin's own workspace (`skills/<name>-workspace/`) is ignored by `.gitignore` for the same
reason; do not add a `!` line for it.

## Run procedure

This is a documented manual procedure, not a script, per
`decisions/0002-plan-and-execute-framework.md`'s general bias toward validating a mechanism
before automating it: the per-case paired comparison is the first candidate to promote to a
`scripts/` wrapper (model-generated, reviewed before commit per
`decisions/0003-hooks-and-scripts-authoring-policy.md`) if these manual steps prove toilsome as
the artifact count or run frequency grows.

1. On Claude Code, open the target skill's directory and invoke the `skill-creator` plugin's
   eval workflow (see that plugin's `SKILL.md`, "Running and evaluating test cases") against
   `skills/<name>/evals/evals.json`. Let it spawn the with-skill (and, for a first build, the
   without-skill baseline) runs, grade each expectation, and aggregate the benchmark.
2. If this is a regeneration, additionally check out the pinned prior version (the git ref
   recorded in that artifact's most recent run file below) into a separate copy and run the
   identical case set against it, so the comparison in step 3 is apples-to-apples.
3. Compare per case against the thresholds above. Note any judgment-check regression against
   the prior baseline by name.
4. Record the run as `evals/runs/YYYY-MM-DD-<artifact>.md` (or `.json` if the grading tool's
   native output is preferred verbatim) containing at minimum:
   - Harness and its version (Claude Code build/version string)
   - Model version used for the with-skill run, and the judge model used for grading
   - Per-case pass/fail, with deterministic vs. judgment labeled
   - The prior baseline's git ref this run was compared against (or "none - first build")
   - Pass/fail against the thresholds above, and the resulting decision (ship / hold /
     regenerate again)
5. If the run passes, that run's artifact commit becomes the new pinned baseline ref for the
   next regeneration.

## Results log

| Date | Artifact | Trigger | Deterministic | Judgment | Decision |
| --- | --- | --- | --- | --- | --- |
| 2026-08-03 | `write-plan` | 100% (8/8) | 100% (24/24) | 83.3% (5/6) | HOLD |
| 2026-08-03 | `execute-plan` | 100% (1/1) [^1] | 100% of exercised (21/21) [^2] | 100% (4/4) | SHIP [^2] |
| 2026-09-05 | `deep-review` | 87.5% (7/8 positive, 8/8 negative) [^3] | 100% (25/25) [^5] [^9] | 100% (14/14) [^9] | HOLD [^4] |
| 2026-09-07 | `deep-review` | 40% (4/10 positive at n=9, 8/8 negative at n=3) [^8] | not re-run | not re-run | superseded by the row below [^8] |
| 2026-09-07 | `deep-review` | 67% (6/9 positive at n=9, 8/8 negative at n=9) [^9] | 92% (23/25) | 93% (13/14) | HOLD [^9] |
| 2026-09-08 | `deep-review` | 100% (7/7 positive scored at `>= 8 of 9`, 8/8 negative at 0 fires) [^10] | 84% (21/25) | 100% (14/14) | HOLD [^10] |
| 2026-09-08 | `deep-review` | not re-run | partial re-run of evals 2, 3, 6, 11 (not a suite score) [^11] | partial re-run of evals 2, 3, 6, 11 (not a suite score) [^11] | HOLD [^11] |
| 2026-09-08 | `deep-review` | not re-run | matched pair, evals 9 and 11 only (not a suite score) [^12] | not re-run | HOLD [^12] |
| 2026-09-08 | `deep-review` | not re-run | new eval 12 only, 0/4 (not a suite score) [^13] | not re-run | HOLD [^13] |
| 2026-09-08 | `deep-review` | not re-run | evals 9, 11, 12 only, 12/12 (not a suite score) [^14] | not re-run | HOLD [^14] |
| 2026-09-11 | `deep-review` | 44.4% (4/9 positive at >= 8/9, 9/9 negative at 0 fires) [^15] | 87.1% (27/31) [^15] | 93.75% (15/16) [^15] | HOLD [^15] |
| 2026-09-05 | `cursor-projection` | 87.5% (7/8 positive, 8/8 negative) [^6] | not run | not run | trigger only |
| 2026-09-05 | `research` | 75% (6/8 positive, 8/8 negative) [^6] | not run | not run | trigger only |
| 2026-09-05 | `health-check` | not valid [^7] | not run | not run | trigger only |
| 2026-09-19 | `go-dev` | 100% (9/9 positive at >= 8 of 9); negatives 9/9 at <= 1 fire, 7/9 at 0 fires [^16] | 100% (30/30) [^16] | 100% (8/8) [^16] | SHIP [^16] |

**Every row above dated before 2026-09-08 was measured under the superseded threshold** - "fires on
every run", recorded at three runs per query and in several cases computed at `run_eval.py`'s 0.5
default rather than the mandated rule. Those rows are **not comparable** with rows scored under the
>= 8 of 9 rule and have deliberately not been rescored: no per-query rates were retained for most of
them, so rescoring would mean re-running, which is separate work. Read them as upper bounds on
positives and lower bounds on negatives.

[^1]: `execute-plan` is manual-only; its run record states no broader trigger percentage applies,
    so this cell is not comparable with the others.
[^2]: The only SHIP in this table is a waiver, not a clean pass. Counting all sub-expectations
    rather than only those the fixture exercised, `execute-plan` scored 91.3%, below the 100%
    the threshold table demands without qualification. It shipped on the argument that the gap
    was fixture coverage rather than an observed failure.
[^3]: The first trigger figure in this table taken with the plugin's real trigger harness
    (`run_loop.py`, 3 runs per query, scratch project root, skill uninstalled, model
    `claude-sonnet-5`, `--num-workers 1 --timeout 120`) rather than by hand. Mean positive trigger
    rate 0.96; only one positive query fell short of 3 of 3. Earlier figures for this skill (83.3%,
    then 100% of 6) were hand-measured at Opus and are not comparable.
    **This cell read 100% (8/8) until 2026-09-07 and was wrong by this document's own rule.**
    `run_eval.py` marks a case passing at its default `--trigger-threshold` of 0.5, so the query
    that fired 2 of 3 - "deep review this before I commit it", the canonical invocation carrying
    the skill's own name - was counted as a pass. The threshold table above mandates the rate rule
    of 3 of 3 and calls 2 of 3 a finding to investigate. Under that rule the set is 7 of 8, which
    the 0.96 mean already implied in the sentence above: seven queries at 1.0 and one at 0.667.
    Nothing was re-measured; this is arithmetic on the recorded run under the stated rule.
    Two further positive cases, for "rigorous review" and "strong review", were added 2026-09-07
    and have never been run, so the positive set is now ten of which eight carry a measurement.
    **This cell briefly read 0% (0/8).** That run was identical except that it used the harness
    defaults, `--num-workers 10` against the 30-second timeout, and the number was an artifact of
    that concurrency. Serial re-runs of the unchanged description gave 5 of 8 at one run per query
    and 8 of 8 at three. See the correction section of
    `runs/2026-09-05-deep-review.md`; the procedure rule it produced is in the trigger preconditions
    above.
[^4]: This cell moved SHIP -> HOLD -> SHIP -> HOLD -> SHIP over one day, and every move was
    evidence-driven rather than a change of mind. Deterministic went 71.9 -> 84.4 -> 87.5 -> 100
    percent across four skill fixes and two eval-suite amendments, each verified by re-running the
    case that exposed it. A tier-differential re-test then found a fifth defect - a backgrounded
    dispatch silently destroys the verdict - since fixed and **verified**. A sixth, "the trigger does
    not fire at Sonnet", was recorded and is now **withdrawn**: it rested on one subagent that failed
    to fire, better explained by the stale session skill registry directly observed later the same
    day (an arm returned `Unknown skill: deep-review` while the skill was installed on disk), and the
    real harness scores the description 16 of 16. The lesson worth keeping is not the verdict but the
    cost: two of the five HOLD/SHIP flips were caused by the instrument, not the artifact.
    **A sixth move followed on 2026-09-07: back to HOLD**, and this one came from no new run at
    all. Re-reading the trigger cell against the threshold rule this file already states showed the
    figure had been computed at `run_eval.py`'s 0.5 default rather than the mandated 3 of 3 (see
    [^3]). That makes three of six flips attributable to the instrument or to how its output was
    read, against three to the artifact. The standing lesson: record which threshold produced a
    number, because a script's default silently outranks a rule written in prose.
[^6]: Trigger layer only - these three skills have never had a behavioral suite run, so the last
    three rows are not gate decisions and no SHIP/HOLD is implied. Same protocol as [^3]
    (`--num-workers 1 --timeout 120`, 3 runs per query, scratch project root, skill uninstalled,
    `claude-sonnet-5`). Negatives are 8 of 8 for all three at 0 of 3 on every case but one, so no
    description here is over-broad. **These two positive figures have not been recomputed under
    the 3-of-3 rule** and, being produced by the same script at the same 0.5 default, may be
    overstated in the same way `deep-review`'s was (see [^3]); read them as upper bounds until the
    per-query rates in the run record are checked against the rule. Details: `runs/2026-09-05-trigger-sets.md`.
[^7]: Measured twice at 4 of 8 (means 0.50 and 0.46), and **both numbers are discarded**. The two
    runs agree on all 8 positives with the same 4 failing, which is the only direct evidence in this
    repository that the serial protocol is reproducible rather than merely less wrong - that part is
    kept. The rate is not, because probing showed the failures are an artifact of the mandatory
    scratch project root: `audit this repo` fires 1 of 3, `audit this config repo` fires 3 of 3.
    `health-check` is scoped to the `~/.claude` repository, the harness can only ask from a directory
    that is not it, so declining an unscoped "this repo" is correct behaviour. **Any skill scoped to
    a specific repository cannot have deictic queries measured by this harness at all** - the two
    preconditions (scratch root, real referent) cannot both hold. Three of the four failing queries
    need rewriting with an explicit scope marker before a remeasurement means anything.
[^5]: Recount after seven assertions the behavioral harness structurally cannot evaluate were moved
    to `trigger-evals.json`. The suite was 32 deterministic before that change; all seven removed
    assertions had been passing, so this is arithmetic on the same run rather than a re-measurement.
[^8]: Trigger layer only, and covering just the two positive cases added 2026-09-07 for "rigorous
    review" and "strong review"; the other sixteen cases keep their 2026-09-05 figures. **Both new
    cases fail**, aggregating 8/15 and 9/15 across three runs, so positives stand at 8 of 10 under
    the 3-of-3 rule. Run at `--trigger-threshold 1.0` so pass and fail mean the mandated rule rather
    than the 0.5 default. **The run also found that the moving-failure-set tell is not specific to
    the concurrency mode**: two serial `--num-workers 1 --timeout 120` runs disagreed on which query
    failed ("rigorous review" 3/3 then 1/3, "strong review" 1/3 then 2/3), so a 3-run rate cannot
    discriminate at this effect size and every n=3 figure in this table carries wider error bars than
    one significant figure suggests. Raising runs per query is cheap: 18 serial calls took under two
    minutes. Note also that "rigorous review" is quoted verbatim in the description and still
    aggregates to 0.53, so quoting is necessary but not sufficient.
    **The eight original positives were then re-run at n=9 and four of them fail**, so positives are
    4 of 10, not 8 of 10. Nothing about those queries changed; n=3 was overstating them. For a phrase
    whose true rate is near 0.85, P(3 of 3) is about 0.61 and P(9 of 9) about 0.23 - **n=3 does not
    test a 100 percent threshold, it tests whether a coin lands heads three times.** The worst
    performer is `deep review this` at 6/9, the canonical invocation carrying the skill's own name,
    and also the single query recorded short at n=3 on 2026-09-05. The matching 0.667 is not a
    reproduced measurement - n=3 cannot resolve that finely - but failing in both sessions and
    ranking worst of eight in the one with resolution makes it a probable description defect. Negatives were not re-run and their n=3 figure is soft in the opposite direction, since a
    negative passes by not firing. **Read every n=3 trigger figure in this table as an upper bound on
    positives and a lower bound on negatives**, including `cursor-projection`, `research`, and
    `health-check`. Details: `runs/2026-09-07-deep-review-trigger.md`.

**No artifact in this table has a pinned baseline ref.** Run procedure step 5 says a passing run's
artifact commit becomes the pinned ref, and step 2 tells a future regenerator to check out the ref
recorded in the most recent run file - but no run file records a commit-shaped string, and
`skills/execute-plan/SKILL.md` was edited by the 2026-08-31 "Complete the public-repo preparation
pass" commit, after its 2026-08-03 run. The
paired comparison has never had a valid input. Fixing that is a prerequisite for the next
regeneration of any of these three.

`deep-review`'s run is `evals/runs/2026-09-05-deep-review.md`, covering a first run, four skill
fixes, a re-run of every affected case, two eval-suite amendments, and a three-arm experiment on
whether the skill's Opus dispatch earns its cost. That experiment is the part worth reading, and it
was run twice. The first version held the model tier constant across all arms and so could not test
the claim; the second varied it and found that every arm reviewing at Opus scored full marks and
every arm reviewing at Sonnet scored none, with the dispatch the only mechanism that reaches Opus
from a Sonnet caller. The dispatched pass also found a defect larger than any in the answer key: the
trigger layer this procedure mandates cannot be run by the harness it names.

A second record, `evals/runs/2026-09-05-deep-review-ablation.md`, closes the brief-versus-tier
confound that experiment left open and adds a self-review of the skill by itself. It answers the
brief half cleanly - only the arms given the four-field brief caught a constraint violation not
inferable from the artifact, which is direct evidence for the hard gate.

**Its tier half is worth reading as a methodology lesson rather than a result.** Both Sonnet arms
scored full marks on every artifact-derivable defect, and the first draft of that record treated
the divergence from the earlier 3/3-versus-0/3 split as evidence that the original gap had measured
prompt completeness. Checking the earlier run's own arm table refuted that: its Arm B was already
checklist-inline at Sonnet and scored ~0.5/3. What actually happened is the failure the earlier run
had **pre-registered** - "if a Sonnet arm still scores 3/3, the key is too easy to discriminate
anything... that would invalidate the whole instrument rather than any one arm." The ablation's
planted defects were too legible, so its tier columns measure the key's ceiling.

Two transferable rules come out of that. **Pre-registering the invalidation condition is what made
this recoverable** - the earlier run had written down what a too-easy key would look like, so the
signature was recognisable months later instead of being read as a finding. And **a divergence
between two runs is a claim about both of them**: check the earlier run's actual arm table before
proposing a mechanism for the difference, not your memory of its conclusion.

## Baselines

Run records exist for `write-plan` and `execute-plan` (both 2026-08-03) and `deep-review`
(2026-09-05, two records: the gate run and the ablation/self-review follow-up). `execute-plan` shipped on a waiver; `write-plan` and `deep-review` are held. See the
Results log footnotes. None of the three is a pinned baseline, because no run file records a ref to
pin. No baseline runs
exist yet for `skill-author`, `review-md`, `cursor-projection`, `health-check`, or `research`.
Establishing them (running each skill's current `evals.json` per the procedure above and
committing the resulting run file) requires a real Claude Code session, since that is where the
native eval runner runs; it was deliberately deferred out of the Phase 2 and Phase 3 build
passes that produced these eval sets, since no native runner was available in the harness those
passes ran in. (Those phase names come from the spec-anchored migration plan, whose four phases
all completed; the plan is not part of this repo.) The next time any of these five skills is
regenerated, run this procedure first, on Claude Code, before treating that skill's prior
`SKILL.md` as an eval-gated baseline.

Until then, this repository explicitly accepts the current committed `SKILL.md` of each **never-run**
skill as its de-facto first baseline, with no eval run backing it yet. The paired-comparison and
threshold gate above binds starting from that skill's next regeneration, not retroactively against
a baseline that was never actually run.

**That default does not extend to a skill that has been run and held.** A HOLD is a result, not an
absence of one, so neither `write-plan` nor `deep-review` is a de-facto baseline; each carries a
named remedy in its own run file and needs the affected cases re-run before it becomes one. This distinction matters because the
"binds from the next regeneration" clause would otherwise exempt precisely the regeneration a HOLD
exists to force.

## References

- `reference/spec-driven-architecture.md` - the Evals section this procedure implements.
- `decisions/0001-adopt-spec-driven-config-architecture.md` - the decision to gate LLM-class
  regeneration with evals and paired comparison.
- `skills/deep-review/evals/trigger-evals.json`,
  `skills/health-check/evals/trigger-evals.json`,
  `skills/research/evals/trigger-evals.json`,
  `skills/cursor-projection/evals/trigger-evals.json` - the trigger-eval sets, run by `run_loop.py`.
  The other four skills do not have one yet.
- `skills/skill-author/evals/evals.json`, `skills/review-md/evals/evals.json`,
  `skills/cursor-projection/evals/evals.json`, `skills/health-check/evals/evals.json`,
  `skills/research/evals/evals.json`, `skills/deep-review/evals/evals.json`,
  `skills/write-plan/evals/evals.json`, `skills/execute-plan/evals/evals.json` - the per-artifact
  case sets this procedure runs.

[^9]: Second 2026-09-07 entry, after the description repair and the deletion of the "strong review"
    case. Both layers were re-measured, and this row supersedes the one above it. **Trigger:** all 17
    cases (9 positive, 8 negative) at n=9 and `--trigger-threshold 1.0`, 153 serial calls, about 19
    minutes. Positives 6 of 9. `deep review this` went 2/3 (n=3, 2026-09-05), 6/9 (n=9, the
    superseded row above), then 9/9 twice here. `rigorous review` went 8/15 (aggregate of three n=3
    runs) to 9/9 twice here, and `should we even do this` 8/9 to 9/9 twice. Set against those three
    repairs, `be critical about this` slipped 9/9 to 8/9 and holds there. Negatives fired **zero
    times in 72 runs**, on each of two runs, so the `code-review` bleed that the overlap analysis
    rated its highest risk never appeared. The cost fell on the two positives with no artifact and
    no file path: `push back on this` 8/9 to 4/9, `critique this approach` 7/9 to 5/9. **A third
    description variant was measured and falsified the obvious explanation.** Dropping the guard sentence, on the reasoning that the negatives were
    already perfect without it, produced the worst variant of the three (66/81 against 71/81 and
    about 69.8/81). It did not merely fail to recover the two conversational queries, it drove both
    lower - `critique this approach` 5/9 to 3/9 and `push back on this` 4/9 to 3/9 - and cost
    `play devil's advocate` 9/9 to 7/9 for no reason anyone can name. The guard was restored. Every
    per-query comparison between the two post-change variants sits at p >= 0.47, so nothing
    separates them individually and the ordering rests on total rate and pass count alone.
    **Behavioral:** re-run through the skill-creator harness rather than by hand - executor runs at
    Sonnet, one per eval, then a grader subagent following the grader agent definition that ships
    with the skill-creator plugin, writing `grading.json` per run. The hand-rolled 25/25 and 14/14
    in the row above did not survive: **23/25 deterministic, 13/14 judgment**. All three
    failures are eval 9, the bare `Deep review <path>` case, and all three are one failure - the run
    dispatched on an incomplete brief with Purpose guessed, never named the field it could not fill,
    and returned a verdict instead of stopping. The brief-completeness gate is the one rule here with
    direct ablation evidence behind it. Eval 9 has a fourth assertion, separate from those three and
    not among the failures: it *passed*, and only because the run wrongly dispatched, so it cannot
    fail in the mode it was written for. That is a defect in the eval set rather than in the skill,
    recorded and not yet fixed. `AskUserQuestion` is unavailable inside a subagent, so assertions
    touching it can only be graded against the plain-text fallback branch. Executors ran at Sonnet
    deliberately: at Opus the skill folds its second phase inline, and the dispatch assertions would
    not fire. No baseline arm was run - it answers a different question than the one the asterisk
    was about, and would have scored near zero on most deterministic assertions. Details for both
    layers: `runs/2026-09-07-deep-review-trigger.md`.

[^10]: Behavioral layer re-run 2026-09-08 after two `SKILL.md` edits: 10 evals, one run each,
    `with_skill` arm only, no baseline arm by design. Deterministic **21/25** (down from 23/25),
    judgment **14/14** (up from 13/14). Two of the four deterministic failures are eval 1, a
    should-NOT-fire routing test the behavioral harness structurally cannot run - it passes
    `Skill path: <path>` in every executor prompt, so the skill is pre-loaded and cannot decline;
    they are reported as measured rather than rescored away. The other two are eval 2, a real miss:
    the run never asked the full-pass question and proceeded on its own. **The trigger cell is a
    rescoring, not a fresh measurement** - no trigger run happened. It is the 2026-09-07 per-query
    rates scored against the `>= 8 of 9` rule with two positive cases removed from
    `trigger-evals.json` at the user's direction (17 cases to 15, 9 positives to 7): "push back on
    this" (was 4/9) and "critique this approach" (was 5/9). **Removing a failing case does not fix
    it** - the live description still fires on those phrasings about half the time and that
    behaviour is now unmeasured. Of the seven remaining positives, six are 9/9 and `be critical
    about this` sits **exactly on the 8/9 boundary**. Also recorded there, and applying to every
    trigger figure in this table: `run_eval.py` does not measure a real skill registration - it
    writes a synthetic command file whose body is `This skill handles: <description>` and counts a
    trigger when that generated name appears in the tool input, so the figures measure a description
    inside a synthetic wrapper. Comparisons between runs still hold. Details:
    `runs/2026-09-08-deep-review-readiness.md`.

[^11]: Only evals 2, 3, 6, and 11 were re-run - no trigger run happened and no suite percentage
    is implied by this row. Eval 2 improved from 2/4 to 3/4; evals 3 and 6 held at 3/3 and 3/3.
    New eval 11 (a bare unnamed path, fixture `skills/deep-review/evals/files/rotate-logs.sh`)
    scored **0/4**. Eval
    11 is the generalization test: it is shaped identically to eval 9 but not named by filename
    in `SKILL.md`, and it shows the brief-completeness gate held only on the fixture the skill
    named by filename, not on an unnamed one of the same shape. That defect was fixed the same
    day; see the row below and [^12]. Details:
    `runs/2026-09-08-deep-review-gate-verification.md`.

[^12]: Only evals 9 and 11 were re-run, as a matched pair - no trigger run and no judgment run
    happened, and no suite percentage is implied by this row. The gate text in `SKILL.md` was
    rewritten to remove the two defects that caused [^11]'s result: a self-check that named the
    target as a legitimate source for all four brief fields (for Purpose it is the forbidden
    source), and a failure test that keyed on hedge words, which a confident code paraphrase
    evaded. The `cache-warmer.py` worked example was replaced by the general rule it illustrated,
    so neither fixture is named in `SKILL.md` any more - verified at 0 references before the
    re-run. Result: eval 9 held at **4/4** and eval 11 rose from 0/4 to **4/4**. Both fixtures are
    bare context-free files, so the gate remains untested against a target with some surrounding
    context that is nonetheless insufficient for Purpose. The frontmatter `description:` was not
    touched, so trigger figures are unaffected. Details:
    `runs/2026-09-08-deep-review-gate-generalization.md`.

[^13]: A single new eval, run once - no trigger run, no suite percentage implied. Eval 12 is the
    partial-context case: the target sits beside a README, a crontab fragment, a CHANGELOG, and a
    two-commit git history that document behaviour thoroughly and state no need anywhere, so a
    context search succeeds and still leaves Purpose unfilled. Evals 9 and 11 are both bare files
    in empty directories and can be passed by noticing the cupboard is bare; this one cannot.
    Result **0/4**: the run filled Purpose with "keep `items.on_hand` synced to the feed so the
    storefront reflects current stock, run unattended via cron every 15 minutes", sourced to the
    README, dispatched an Opus subagent, and reproduced a "Proceed with changes" verdict. That is
    a behaviour restatement, the first failure mode `SKILL.md` names, uncaught. The 4/4 pair in
    [^12] is narrowed rather than overturned - the gate holds where no plausible Purpose is
    available and fails on the first case where one was. Details:
    `runs/2026-09-08-deep-review-partial-context.md`.

[^14]: Three evals, one run each - no trigger run, no suite percentage implied. The self-check in
    `SKILL.md` was changed from testing **provenance** (which of three sources an answer came from,
    a list that omitted the repository) to testing **content**: quote the sentence that states the
    need, or Purpose is unfilled however much material you have read. Any source can fill Purpose
    when it states a need; none fills it by existing. A new rule, "a citation is not a source",
    covers the observed failure of attaching "(from README.md)" to a behaviour sentence. Result:
    eval 12 rose from 0/4 to **4/4** and evals 9 and 11 held at 4/4, so the fix cost nothing on the
    cases that already passed. Expectation 4, the anti-over-refusal check, also passed - the run
    still filled Alternatives, Constraints, and Prior findings from the available material. Note
    **n=1 per eval** against a 100-percent-of-runs threshold; a repeat at higher n has not been
    done. Details: `runs/2026-09-08-deep-review-purpose-quote-test.md`.

[^15]: First full-suite run (both layers, complete current case sets) against the description as
    actually committed, not a regeneration diff-check. **Trigger figure revised same day**: the
    first pass tested `trigger-evals.json` cases built for description variant E
    (`runs/2026-09-09-deep-review-trigger-regen.md`), but the 2026-09-11 "Refine and improve the
    description for deep-review" commit had since dropped three
    of variant E's phrases ("should we even do this", "play devil's advocate", "poke holes in
    this") and added "does this provide value" - so three of the eleven compared queries were
    testing phrases no longer in the description at all, and the first pass's write-up wrongly
    called the result a same-description regression. That comparison is retracted; the run doc was
    rewritten in place rather than superseded by a new dated file, per the user's request.
    **Corrected trigger figure:** 9 cases rewritten to cover exactly the current description's 9
    phrases (one case each) plus the 9 unchanged negatives, n=9,
    `--trigger-threshold 0.88`, isolated by temporarily relocating the live skill directory
    (user-approved after the sandbox's safety classifier initially refused it; restoration
    verified both times). Positives 4 of 9 ("deep review" 9/9, "rigorous review" 8/9, "is this the
    best way to do this" 9/9, "does this provide value" 9/9); the other five phrases fail,
    including "be critical" and "is there a better way" at 0 of 9 despite being quoted verbatim in
    the description - necessary but not sufficient, consistent with this repository's prior
    findings. Negatives clean, 9 of 9 at 0 fires. No prior measurement of this exact 9-phrase
    description exists to compare against; this run is now that baseline figure.
    **Behavioral (unaffected by the trigger correction):** all 12 cases, with-skill only, executors
    at Sonnet, graded by the dispatching agent against the grader agent definition that ships
    with the skill-creator plugin. Deterministic 27/31
    (87.1%), judgment 15/16 (93.75%). Two real misses, evals 8 and 10, both the same cause: the
    Purpose-gate rule that correctly blocks dispatch on a bare fixture file (evals 9, 11, 12 all
    pass 4/4) also blocks a legitimate in-conversation "should we do this?" proposal when it lacks
    an explicit "so that / to fix / because" clause, even though the skill's own material treats
    that case class as high-value. Eval 1's pass is not evidence of correct routing - same
    structural limitation as footnote 10. This run also surfaced two environment failure modes not
    previously documented, folded into the trigger-precondition list above (a Python-version
    import crash, and an empty-`CLAUDE_CONFIG_DIR` isolation attempt that silently breaks login and
    produces a result indistinguishable from a void run - discarded rather than recorded). Details:
    `runs/2026-09-11-deep-review-full-suite.md`.

[^16]: First build, both layers, measured over six serial trigger runs and two full behavioral runs
    plus targeted re-runs; `runs/2026-09-19-go-dev-first-build.md` has every run. Trigger measured
    with `run_eval.py` rather than `run_loop.py` (the latter rewrites the description it is
    measuring), at `claude-sonnet-5`, n=9, `--trigger-threshold 0.88`, 4.75 s per call. One of the
    six runs was discarded as a partial void run - the failure mode now documented under the
    trigger layer above. **The negative figure does not meet this README's threshold as written**:
    two negatives fired once in nine runs each, so 7 of 9 negatives are at 0 fires. The build's own
    gate was amended to "no more than 1 fire of 9" with the user's explicit approval on 2026-09-20,
    because at n=9 a single stochastic fire fails the 0-fires rule; the repo-wide threshold above
    was deliberately NOT changed by that approval, and the SHIP decision rests on the amended gate.
    Two of the 38 behavioral expectations were re-derived mid-run with approval (case 1's
    deferred-close check, scoped to written handles; case 8's judgment check, from reciting the
    upstream-idiom exemption to drawing the distinction); unsoftened figures are 29/30 and 7/8.
    Post-run on 2026-09-23, case 7 was rewritten because its `ok` check passed vacuously, and cases
    1, 7, and 8 were re-run against follow-up content (`errors.Join`, parameter reassignment under
    the house `var` rule): all three passed every expectation. The other six cases were not re-run.
