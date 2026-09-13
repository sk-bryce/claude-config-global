---
audience: human
created: 2026-07-31
updated: 2026-07-31
---

# Chapter 6: Measuring Whether It Worked

## In short

- You don't need a full evaluation harness to know if Chapters 2 through 5 are paying off. A
  handful of cheap, recurring signals, checked on a light cadence, is enough for one person's
  daily use.
- Pick the signal that matches the limit type from [Chapter 1](01-know-your-limit-type.md) that's
  actually pressing on you. Watching everything is its own kind of waste.
- A weekly glance beats a one-off deep report: the report is expensive to produce and, in
  practice, rarely revisited once it's done.
- Habits and configuration buy back real runway, but they cannot fix a policy problem. A hard cap
  blocking genuinely high-value usage is a conversation about the cap, not another habit to adopt.

## Pick signals that match your limit type

This is not a dashboard to build. It's a short list to skim and take one or two items from,
matched to the account-limit shape from [Chapter 1](01-know-your-limit-type.md) that's actually
the one you're closest to hitting. A hard-cap account and a metered account are watching for
different failure modes, so there's no single number that serves everyone equally.

**Universal, worth a glance regardless of limit type:**

- **Cache-read token volume or share, trending over time.** Most harnesses surface this per
  session or per period. A rising trend at flat output usually means growing, unscoped context,
  the exact failure mode [Chapter 2](02-turn-session-and-context-discipline.md) is about. This
  number moving the wrong way is often the earliest warning that a habit has slipped, well before
  a hard cap or a spend alert fires.
- **Share of requests run at a high reasoning-effort tier.** If most of your work is routine and
  a large share is still running at the top effort tier, that's a sign the routing habits in
  [Chapter 5](05-model-effort-and-batch-tuning.md) aren't actually being applied day to day, not
  that the work genuinely needs it.
- **Distinct top-level sessions opened per day for comparable work.** A rising count for what is
  functionally the same underlying task usually means fan-out that should have been subagent
  delegation instead, the distinction [Chapter 3](03-delegation-subagents-and-verbose-output.md)
  covers. Several parallel top-level sessions doing overlapping exploration cost more in aggregate
  than one session dispatching that same exploration to subagents.

**If you're on a hard-cap account:** track days of tooling available before the reset. The goal
is that number trending flat or improving month over month at the same output, not a one-time
high value. This is the same "it's working" criterion Chapter 1 defines for this limit shape.

**If you're on a session or time-window account:** track how often a window is exhausted mid-task
versus comfortably lasting the task end to end. A window that keeps running out partway through
routine work is the clearest sign that turn budgeting or session hygiene from Chapter 2 needs
attention, regardless of what your monthly total looks like.

**If you're on a metered or soft-cap account:** track dollars per week, trending flat or down at
the same output. Because spend is visible in near real time on this limit shape, this is the
fastest-feedback signal of the four: you can watch a week's number move and adjust before it
becomes a real bill.

**If you're on a seat or pool account:** track whether the shared pool's burn rate matches actual
headcount and workload, rather than being dominated by a handful of outlying sessions. A pool that
looks fine in aggregate can still be masking one or two sessions burning through it while everyone
else is well under budget; the aggregate number alone won't show you that; a rough per-person or
per-session breakdown will.

## Cadence

A lightweight periodic check beats a one-off deep report. A weekly cadence is reasonable for most
people: frequent enough to catch a habit slipping before it costs real runway, infrequent enough
not to become its own tax on your time. A report that's expensive to produce and never looked at
again has close to zero ongoing value: the point of this chapter is a check cheap enough that you
actually keep doing it, not a more thorough one you do once.

This kind of check is also a reasonable candidate for automation. Most harnesses have some form of
scheduling or recurring-job feature; it's worth checking whether yours does and pointing it at a
short prompt that pulls the one or two signals above, rather than re-running the check by hand
every week. The exact mechanism is harness-specific, so it isn't spelled out here.

## What this chapter is not

This is a short list of signals, not an evaluation methodology. A defensible answer to "did
switching models or effort tiers actually hold quality" needs a representative task set, a
calibrated judge, and tracking of defects that escaped review: a team-scale undertaking with its
own tooling and upkeep cost, not something to compress into a weekly personal check. If that's what
you actually need, start with [`docs/generative-ai/` Appendix C, Section 5: How to compare cost
across providers and
models](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#5-how-to-compare-cost-across-providers-and-models)
rather than trying to build it out of the signals above.

## The honest ceiling

Everything in this guide is a habit or a piece of configuration, and both have a real, bounded
effect: applied consistently, they reliably buy back a meaningful share of runway under any of the
four limit shapes in Chapter 1. Neither can fix a policy problem.

If a hard cap is blocking someone whose usage is genuinely high-value, no amount of turn
budgeting, subagent delegation, or effort tuning changes the fact that the cap itself is set too
low for that person's actual work. At that point the right move is to raise the question with
whoever owns the account: whether the cap should be higher for that person specifically, or
whether a hard stop should become a soft cap paired with an approval step instead. That's a
conversation about the policy, not something a habit or a config file resolves, and it's worth
having once the signals above show the habits are already being applied and the wall is still
there.

## References

- `docs/generative-ai/appendices/appendix-c-costs-and-getting-value.md` - Section 5 covers the
  full methodology (representative task sets, calibrated judging, escaped-defect tracking) for
  anyone who needs a rigorous answer beyond the lightweight signals in this chapter.
