---
created: 2026-09-08
updated: 2026-09-08
---

# deep-review Purpose quote-test fix, 2026-09-08

This run fixes the 0/4 partial-context failure recorded in
`evals/runs/2026-09-08-deep-review-partial-context.md` and re-runs the three gate evals together.

It is a **three-eval run**, not a suite re-run. No trigger run happened. The readiness run's
headline figures (deterministic 21/25, judgment 14/14, ten-eval suite) are unaffected.

## The diagnosis

The self-check tested **provenance**, asking which of three sources an answer came from - "the
prompt, the conversation, or the artifact itself" - and counting only the first two for Purpose.
The repository was absent from that list, although `SKILL.md:110` names it as a source for the
four fields. A Purpose sourced to a README therefore matched no category and fell through the
check entirely. The failing run's own attribution line read "(from README.md + CHANGELOG.md +
crontab.fragment)".

The deeper problem was that provenance is the wrong axis. A README can legitimately state a need,
and a prompt can contain nothing but a behaviour summary. Which file a sentence came from does
not determine whether it answers the question.

## The fix

The self-check now tests **content**:

> **Before you dispatch, apply this test to Purpose, out loud: quote the sentence that states the
> need.** Not the file it came from - the sentence.

It must say why the thing exists, what depends on it, or what would break without it. Quote it and
proceed; fail to quote one and Purpose is unfilled "however much material you have read". Any
source can fill Purpose when it states a need, and none fills it by existing. A new named rule,
**"A citation is not a source"**, covers the specific way this failed: attaching "(from
README.md)" to a behaviour sentence makes an unfilled field look sourced, which is harder to catch
than a blank one.

Failure mode 1 was extended to close the two escapes the failing run used: documentation does not
change the test, and a trailing goal clause does not rescue a behaviour sentence - "syncs the
table so the data stays current" is the same sentence twice, because the clause after "so"
restates the operation rather than naming who needed it or what breaks without it.

Verified before the re-run: `SKILL.md` names none of the three fixtures (0 references), and the
frontmatter `description:` was not touched, so trigger figures are unaffected.

## Result: 12 of 12

All three at Sonnet, `with_skill` arm only, neutral `/tmp/dr-fixtures/` paths, each verified
clean of the answer key before grading (no run opened anything under `skills/deep-review/evals/`).

| Eval | Case | Before | After |
| --- | --- | --- | --- |
| 9 | bare file, once named in `SKILL.md` | 4/4 | **4/4** |
| 11 | bare file, never named | 4/4 | **4/4** |
| 12 | partial context (README, cron, CHANGELOG, git history) | 0/4 | **4/4** |

Eval 12's run read the README, CHANGELOG, crontab fragment, and git log, explicitly rejected both
the module docstring and the README's behaviour description as insufficient, and wrote:

> I can't quote a Purpose sentence, so that field is unfilled, not just thin.

It then gave preliminary artifact-only observations, asked for Purpose, dispatched nothing, and
stated no verdict.

Expectation 4 - the anti-over-refusal check - also passed, which was the risk of a stricter test.
The run filled Alternatives as an explicit "none stated" and drew Constraints and Prior findings
from the CHANGELOG, crontab fragment, and git log rather than refusing across the board.

## Caveats

- **n=1 per eval.** The deterministic threshold is 100 percent of runs, and this is one run each.
  Three consecutive gate results have now each turned on a single run; a repeat at higher n is the
  cheapest available increase in confidence and has not been done.
- The eval 12 grader flagged that the run never assembled a formally labelled four-field brief:
  Constraints and Prior findings are present as prose rather than as named fields. Expectation 4
  passes on substance, but no assertion currently requires the labelled brief that `SKILL.md`
  asks to be shown before dispatch. That is an eval gap, not a skill regression.
- The gate is now tested across three shapes: no context, no context unnamed, and behaviour-rich
  context with no stated need. It is still untested against a source that genuinely DOES state a
  need, where the correct behaviour is to quote it and proceed. The new rule makes that path
  explicit for the first time, and nothing measures it.

## Decision

HOLD (unchanged). The partial-context defect is fixed and the fix cost nothing on the cases that
already passed. The remaining HOLD grounds are unchanged: eval 2 answers its own question
alongside asking it, eval 1 is non-discriminating under this harness, and the trigger figure is a
rescoring rather than a measurement.
