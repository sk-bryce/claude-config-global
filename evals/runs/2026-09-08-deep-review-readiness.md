---
created: 2026-09-08
updated: 2026-09-08
---

# deep-review readiness run, 2026-09-08

A behavioral re-run after two `SKILL.md` edits, a subagent-inheritance probe, and a rescoring of
the trigger layer. Read the two sections marked "not a fresh measurement" before quoting any
trigger number from this file.

## Verdict: HOLD

Deterministic behavioral checks came in at 21 of 25, and `evals/README.md` sets that threshold at
100 percent, so the gate does not close. No negative trigger case fired even once, and the judgment
layer improved to 14 of 14, but the deterministic shortfall alone decides this.

## Behavioral layer (measured this run)

Re-run after both `SKILL.md` edits. Ten evals, one run each, `with_skill` arm only.

| Layer | This run | Prior baseline |
| --- | --- | --- |
| Deterministic | 21/25 | 23/25 |
| Judgment | 14/14 | 13/14 |
| Total | 35/39 | 36/39 |

Judgment improved by one; deterministic regressed by two.

### The four failing assertions, verbatim

- eval 1: [deterministic] Dispatches no Agent subagent with model opus for a premise pass
- eval 1: [deterministic] Does not emit a Proceed / Proceed with changes / Reconsider scope / Do not
  proceed verdict
- eval 2: [deterministic] Asks the user once whether to run the full pass, before writing a context
  brief, and stops there rather than supplying its own answer and continuing
- eval 2: [deterministic] Uses AskUserQuestion for that question, or asks in plain text if no
  interactive question tool is available

### What happened in each failing case

**Eval 1 ("Review this doc: <path>") is a should-NOT-fire routing test.** Its `expected_output`
says `review-md` should handle it and that `deep-review` must not displace the proofread. The run
dispatched an opus subagent and returned a "Proceed with changes" verdict. The harness forces the
skill to load by passing `Skill path: ${CLAUDE_CONFIG_DIR:-~/.claude}/skills/deep-review` in every executor
prompt, so **this eval cannot test routing under this harness** - once loaded, the skill correctly
follows its own three-phase procedure. Both failures are reported as measured and are not rescored
away; the instrument limitation travels alongside them, it does not cancel them.

**Eval 2.** The run narrated what it would normally do, did not actually stop on a plain-text
full-pass question, proceeded on its own, and then stopped later for a different reason (an
unfillable Purpose field). Assertion 1 is the assertion this plan rewrote precisely so it could fail
in this mode; it did. Assertion 2 failed because no question was ever asked.

## Trigger layer (NOT measured in this run - this is a rescoring)

**No trigger run happened in this plan at all.** The figures below are the recorded per-query rates
from the 2026-09-07 run, rescored against the `>= 8 of 9` rule with the two U3b removals applied.
This is arithmetic on a prior run, not a fresh measurement.

The rescoring is valid because triggering depends only on the frontmatter `description`, and no unit
in this plan changed that line. The live description is the existing frontmatter `description:` in
`skills/deep-review/SKILL.md`, unchanged by this plan - the same text the
2026-09-07 run measured, referred to as the v2 description in
`evals/runs/2026-09-07-deep-review-trigger.md`.

- **Positives: 7 of 7 pass.** Six queries at 9/9, plus "be critical about this" at exactly 8/9.
- **Negatives: 8 cases, 0 fires across 72 runs** (8 cases x 9 runs).

The seven remaining positive queries (abbreviated):

- "deep review this before I commit it - it's the retry wrapper in src/net/bac..."
- "ok honest question, is this a good idea? we're thinking about splitting the..."
- "poke holes in the migration plan in docs/rfc/0012-multi-region.md please..."
- "should we even do this? spent all morning convincing myself we need a featu..."
- "play devil's advocate on my plan to move all the team's runbooks into notio..."
- "be critical about this, don't be nice: proposal is to require two approvals..." <- the 8/9 one
- "i need a rigorous review of the capacity model in planning/2027-forecast.md..."

Two limits must travel with this figure every time it is reported:

1. **"be critical about this" sits exactly on the 8/9 boundary.** It passes, with no margin.
2. **The two removed cases are unmeasured, not fixed.** See below.

### U3b removals

Two positive trigger cases were deleted from `trigger-evals.json`, taking it from 17 cases to 15 and
from 9 positives to 7:

- the case beginning "push back on this: I want to add a nightly cron that reindexes" - was 4/9
- the case beginning "critique this approach - to fix our flaky integration tests" - was 5/9

Ground: they are the least likely invocations in practice and had resisted three description
variants. The user settled this on 2026-09-08.

**Removing a failing case does not make the skill trigger on it.** The live description still fires
on those phrasings roughly half the time, and that behaviour is now UNMEASURED rather than fixed.

**deep-review's idea-review scope is NOT narrowed by these removals.** "is this a good idea" and
"should we even do this" are the same family (a described plan with no file target) and both sit at
9/9.

## Subagent inheritance probe (U6)

Ten fresh general-purpose subagents at Sonnet, dispatched one at a time.

- Part 1, canary emitted: **10 of 10**
- Part 2, working-style rules inherited: **10 of 10** <- this is the count that drove the change

All ten named the git worktree mechanism, cited the `.worktrees/` path, AND stated that
`git checkout`/`git switch` is forbidden for branch work. None gave a generic answer.

**Change made in `SKILL.md`:** the passage claiming "The subagent inherits nothing" was replaced
with wording that tells the reader to ASSUME nothing is inherited, while recording that inheritance
was measured as reliable on 2026-09-08 and is not guaranteed by the harness. The five mandatory
prompt contents that follow that passage were NOT softened.

**Caveat:** this conflicts with a 2026-09-07 observation of 6 of 10 canary emission on `review-md`
subagents. That earlier run measured canary emission, a weaker signal than rule presence.

## Instrument deviations and caveats

1. **No baseline (`without_skill`) arm was run**, deliberately. It answers whether the skill beats
   no skill, which is a different question, and would score near zero on most deterministic
   assertions.
2. **`AskUserQuestion` is unavailable inside a subagent**, so any assertion touching it can only be
   graded against its plain-text fallback branch.
3. **The four file-based evals (1, 4, 5, 9) were run against copies of their fixtures at neutral
   paths** under `/tmp/dr-fixtures/`, not at their in-repo paths, and their prompts named those
   neutral paths. Reason: on two earlier attempts the eval 9 executor grepped
   `skills/deep-review/evals/evals.json` - the answer key - and read the expectations before writing
   its response, because the skill's own gate tells it to search the repository for Purpose and the
   only in-repo text mentioning the fixture IS the eval spec. Both contaminated attempts were
   discarded ungraded rather than scored. The source fixtures and the whole `skills/deep-review/`
   tree were left untouched.
4. **Overfitting caveat, and this one is important.** The new gate text added to `SKILL.md` names
   the eval 9 fixture by filename ("Reading a script named `cache-warmer.py` and writing 'presumably
   to pre-populate a cache' restates the filename"). The eval 9 executor cited that worked example.
   So eval 9 passing 4/4 shows the gate holds on the one case the skill names by name; it is NOT
   evidence the gate generalizes to an unnamed bare-path target.
5. **Eval 10's executor found and cited `evals/runs/2026-09-05-deep-review.md` Case 10**, which
   records a prior verdict on the same proposal. Its assertions do not turn on which verdict is
   reached, so this is a weaker leak than the eval 9 one, but it is recorded.
6. **Fidelity caveat, recorded verbatim, because it applies to every trigger figure in this
   repository and has never been written down:** `run_eval.py` does not measure a real skill
   registration. It writes a synthetic command file whose body is `This skill handles:
   <description>` and counts a trigger when that generated name appears in the tool input. The
   figures therefore measure a description inside a synthetic wrapper. This applies equally to every
   prior run, so comparisons between runs hold, but a claim that a number measures "the skill"
   overstates it.

## Thresholds applied

From `evals/README.md`:

| Check kind | Threshold | This run | Result |
| --- | --- | --- | --- |
| Trigger positives | every case at >= 8 of 9 | 7 of 7 (lowest 8/9) | meets, on a rescoring |
| Trigger negatives | every case at 0 fires | 0 fires in 72 runs | meets |
| Deterministic | 100 percent | 21/25 (84 percent) | **fails** |
| Judgment | no per-case regression, aggregate >= 90 percent | 14/14, up from 13/14 | meets |

**HOLD.** The deterministic layer is below its 100 percent threshold at 21 of 25. No negative case
fired, so nothing here is a SHIP-blocking overlap; the block is the deterministic shortfall, two of
whose four failures come from an eval the harness structurally cannot run as written (eval 1) and
two from a real behavioral miss (eval 2, the full-pass question never asked).
