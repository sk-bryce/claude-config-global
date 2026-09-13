---
created: 2026-09-08
updated: 2026-09-08
---

# deep-review partial-context case, 2026-09-08

This run adds and executes the case named as the open limit at the end of
`evals/runs/2026-09-08-deep-review-gate-generalization.md`: a target that has real surrounding
context which is nonetheless insufficient for Purpose. Evals 9 and 11 are both bare files in
empty directories, so the gate had only ever been tested where a context search returns nothing.

It is a **single-eval run**, not a suite re-run. No trigger run happened. The readiness run's
headline figures (deterministic 21/25, judgment 14/14, ten-eval suite) are unaffected.

## The fixture

`skills/deep-review/evals/files/inventory-sync/`, copied for the run to a neutral path at
`/tmp/dr-fixtures/eval-12/` so the executor could not reach the answer key. It contains:

- `sync_inventory.py` - the target. Pulls a CSV inventory feed and updates `items.on_hand`.
- `README.md` - documents usage, the feed format, batching, two silent-skip behaviours, runtime,
  and the absence of a dry-run mode.
- `crontab.fragment` - shows it running every 15 minutes on the app host.
- `CHANGELOG.md` - three dated entries.
- A real git history, two commits: "Initial version" and "Fix off-by-one in batch slice".

The material is deliberately thorough about **behaviour** and silent about **need**. Nothing in
it says why the script exists, what depends on it, or what breaks without it. A grep of the whole
fixture for need-language ("so that", "because", "in order to", "needed", "requirement") returns
nothing. So a context search succeeds, returns a lot, and still leaves Purpose unfilled.

This is the discriminating property. Evals 9 and 11 can be passed by noticing that the cupboard
is bare. Eval 12 cannot.

## Expectations

Expectations 1-3 mirror evals 9 and 11 (no dispatch, name Purpose, no verdict), with 2 extended
to "does not treat the README's account of what the script does as having filled it".
Expectation 4 is new and tests the **opposite** error: the skill's own instruction is to "fill
every field you can from the target, the conversation, and the repository before asking the user
for anything", so a blanket refusal that leaves the fillable fields empty is also wrong. The case
therefore does not reward simply stopping on everything.

## Result: 0 of 4

The run read the target, listed the directory, printed the README, CHANGELOG, crontab fragment,
and git log, wrote a four-field brief, dispatched one Opus subagent, and reproduced its
"Proceed with changes" verdict verbatim. It never stopped and never named a missing field.

Verified clean of the answer key before grading: no file under `skills/deep-review/evals/` was
opened.

The Purpose field it wrote, attributed by the run to `README.md + CHANGELOG.md +
crontab.fragment`:

> keep `items.on_hand` synced to the feed so the storefront reflects current stock, run
> unattended via cron every 15 minutes

That is what the artifact does and when it runs. It names no consumer, no dependency, and no
consequence of failure. It is failure mode 1 from `SKILL.md` - "Restating behaviour is not
filling Purpose... A flat, accurate summary of what the artifact does fails this gate exactly as
a hedge does, and it is the harder one to catch because it does not sound like a guess" - and it
was not caught.

Notably the other three fields were filled well: Alternatives correctly recorded that the
CHANGELOG shows only incremental fixes with no evidence any alternative design was considered.
The run was not careless. It did the context work competently and then mistook the product of
that work for Purpose.

## What this changes about the 2026-09-08 generalization result

It narrows it rather than overturning it. Evals 9 and 11 at 4/4 remain accurate: with no
surrounding context, the gate holds and no longer depends on the fixture being named. But that
now looks like the easy half of the problem. The gate's real job is to reject a *plausible,
well-sourced* Purpose, and on the first case where one was available it did not.

There is a plausible contributing defect in the text, recorded here as a hypothesis and NOT yet
tested. `SKILL.md:110` says to fill fields from "the target, the conversation, and the
repository". The self-check at `SKILL.md:127-129` asks whether each answer came from "the prompt,
the conversation, or the artifact itself", and says that for Purpose only the first two count.
The repository is absent from the self-check's list of sources, so a Purpose sourced to a README
matches none of the three categories and falls through the check. The run's own attribution line
cites exactly those repository files. Whether closing that gap fixes the behaviour is unmeasured.

## Scope limit

One eval, one run, `with_skill` arm only. No trigger run. Nothing here supersedes a suite figure.

## Decision

HOLD (unchanged, one more reason). The brief-completeness gate is the rule with the strongest
ablation support behind it, and it now has a measured failure on the most realistic case built
for it so far.
