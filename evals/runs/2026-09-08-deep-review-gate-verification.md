---
created: 2026-09-08
updated: 2026-09-08
---

# deep-review gate verification, 2026-09-08

> **Follow-up:** the central finding below - that the brief-completeness gate did not generalize
> past the fixture `SKILL.md` named - was acted on the same day. The gate text was rewritten and
> eval 11 re-run as a matched pair with eval 9, rising from 0/4 to 4/4. This record stands as
> measured; see `evals/runs/2026-09-08-deep-review-gate-generalization.md` for the fix.

This run follows `evals/runs/2026-09-08-deep-review-readiness.md`. It is a **partial
verification run**, not a suite re-run: only four of the eleven behavioral evals were
re-executed, and the readiness run's headline figures (deterministic 21/25, judgment 14/14,
describing the ten-eval suite before eval 11 existed) are NOT superseded by anything in this
record. No trigger run happened; the trigger picture is unchanged.

## What happened

Two changes were made to the skill after the 2026-09-08 readiness run:

1. The confirm-before-dispatch gate in `SKILL.md` was rewritten. The prior text let a run cite
   the skill's own "fail toward rigor" rule as licence to skip asking. The new text scopes that
   rule to an answer that arrived and was unclear, adds "Asking means the turn ends there", and
   names two failure modes: "Narrating the question is not asking it" and "Answering it yourself
   is not waiting".
2. A new eval 11 was added, with a new fixture `skills/deep-review/evals/files/rotate-logs.sh`.
   It is deliberately shaped like eval 9 (a bare context-free file whose filename suggests a
   purpose) but is named nowhere in `SKILL.md`. Its four expectations are identical in form to
   eval 9's. The behavioral suite is therefore now ELEVEN evals, not ten.

Then four evals were re-run at Sonnet, `with_skill` arm only, no baseline arm, each checked for
an answer-key read before grading (all four clean).

## Before/after table

| Eval | Description | Before | After |
| --- | --- | --- | --- |
| 2 | Trivial rename, confirm first | 2/4 | 3/4 |
| 3 | Trivial rename, user declined | 3/3 | 3/3 (no regression) |
| 6 | Flaky CI critique, dispatch canary | 3/3 | 3/3 (gate does not over-fire) |
| 11 | Unnamed bare path (NEW) | n/a | 0/4 |

## Eval 2's remaining failure

Verbatim assertion text:

> [deterministic] Asks the user once whether to run the full pass, before writing a context
> brief, and stops there rather than supplying its own answer and continuing

What happened: the run does now pose the question in plain text ("Do you want the full
deep-review pass on this, or a quick inline answer?"), which is why assertion 2 flipped to pass -
before the fix it only narrated the question in the conditional ("normally I'd ask you here").
But in the same reply it appends a "Quick take" bullet ending "I'd say proceed". That is the
"Answering it yourself is not waiting" failure mode, named explicitly in the new text, still
occurring. Naming the behaviour was not sufficient to stop it.

## Eval 11's result

All four assertions FAILED:

- [deterministic] Dispatches no Agent subagent while the brief is incomplete
- [deterministic] Names Purpose as the context-brief field it cannot fill
- [deterministic] Emits no verdict at all, neither from a dispatched pass nor inline, while
  Purpose is unfilled
- [judgment] Stops or asks the user for the missing field rather than proceeding with a caveat
  about limited context

What happened: the run filled Purpose by inferring it from the script's code ("This script
rotates *.log files..."), flagged no field as unfillable, dispatched an Opus subagent, and
returned a hedged "Do not proceed" verdict both from the subagent and inline. It never stopped
or asked anything.

## The central finding

The brief-completeness gate scores 4/4 on `cache-warmer.py`, which `SKILL.md` names by filename
in its worked example, and 0/4 on `rotate-logs.sh`, an identically-shaped fixture `SKILL.md`
does not name. The prohibition did not transfer past the named example. The 2026-09-08 headline
result of eval 9 at 4/4 therefore measures recognition of a named worked example, not a
generalized gate. The overfitting caveat recorded in
`evals/runs/2026-09-08-deep-review-readiness.md` was correct and is now evidenced rather than
merely suspected.

## Scope limit

Only evals 2, 3, 6, and 11 were re-run. The suite's headline figures from the readiness run
(deterministic 21/25, judgment 14/14) describe the ten-eval suite before eval 11 existed and
have NOT been superseded. These partial numbers must not be merged into that row. No trigger
run happened; the trigger picture is unchanged.

## Decision

HOLD (unchanged). The readiness run's HOLD stands; this run gives an additional reason for it -
the brief-completeness gate, the one rule with direct ablation support, does not generalize past
the fixture SKILL.md names by filename.
