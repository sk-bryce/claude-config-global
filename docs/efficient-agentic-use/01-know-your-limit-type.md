---
audience: human
created: 2026-07-31
updated: 2026-07-31
---

# Chapter 1: Know Your Limit Type

## In short

- The habits in this guide don't all pay off the same way for everyone, because "account limit"
  covers several structurally different things: a hard cap that blocks you outright, a rolling
  time window, a metered account with alerts but no block, and a shared team pool.
- Knowing which one applies to you changes what "it's working" looks like, and occasionally
  changes which habit to prioritize first.
- Every habit and config item in the chapters that follow carries three short tags: **Impact**
  (how much it typically moves the needle), **Helps** (which limit type(s) it most directly
  relieves, most say Universal), and **Quality risk** (whether it's safe to apply without
  measuring first, or needs verifying against your own work).

## Why this comes before anything else

Two people can read the exact same tip, "isolate verbose output in a subagent," and get very
different value from it. For someone on a hard monthly dollar cap, that habit is what keeps them
from losing tool access on the 23rd of the month. For someone on a per-session time window, the
same habit mostly saves cache-read spend that was never going to hit a wall in the first place:
still worth doing, just not the thing standing between them and being blocked. The habit doesn't
change; what changes is how much it's worth prioritizing.

The mechanics behind each limit type, windowed rolling limits, hard stops versus overflow to
metered billing, seat-and-credit-pool structures, are covered in full in
[`docs/generative-ai/` Appendix C, Sections 1.6-1.7](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#16-service-tiers-standard-priority-flex-and-batch).
This chapter only needs the shape of each one, not the pricing detail.

## The four limit shapes

**Hard-cap.** A fixed dollar or token ceiling, usually monthly, that stops working entirely once
crossed: no more requests until the period resets. The defining trait is that going over costs
you nothing in dollars and everything in access: the true cost is lost work, not spend. Every
habit that reduces total volume (Chapters 2 and 3 especially) extends how many days of tooling
you get before that wall, so those chapters matter most here.

**Session or time-window reset.** Usage measured against a rolling window (for example a
five-hour session window with a weekly cap layered on top) rather than a monthly total. The
defining trait is that a burst within one window can exhaust it even if your weekly or monthly
usage is nowhere near a problem: the constraint is local in time, not cumulative. Turn-count
discipline and session hygiene (Chapter 2) matter most here because they control how fast a
single window fills, not because they change a monthly total.

**Metered-with-alerts (soft cap).** Pay-as-you-go or credit-pool billing where crossing a
threshold triggers a warning, not a block; spend keeps flowing, at your cost, past the alert. The
defining trait is that dollars are the direct, continuously visible metric, so the measurement
habits in Chapter 6 pay off fastest here: you can watch the number move in near real time and
adjust before it becomes a real bill.

**Seat or pool.** A shared credit pool across a team or workspace, where one person's heavy usage
affects everyone else's remaining runway. The defining trait is that an individual's habits are
no longer only their own business: the coordination cost of one person's inefficient session
lands on the whole group. Everything in this guide still applies, but Chapter 3's point about
parallel fan-out (many people, or one person, opening several expensive threads over the same
context at once) has the largest blast radius under this shape.

Most real accounts are a blend, most obviously a subscription that behaves like a session-window
account most of the time and quietly becomes a metered account once you opt into overflow
billing past the included allowance. Where that's true, both sets of habits apply; read whichever
section addresses the constraint you're actually closest to hitting.

| Limit shape | What "it's working" looks like |
| --- | --- |
| Hard-cap | More days of tooling available before the monthly reset than last month, at the same output |
| Session/time-window | Fewer bursts that exhaust a window mid-task; less need to wait out a reset |
| Metered-with-alerts | Weekly spend flat or falling while output holds steady |
| Seat/pool | The shared pool's burn rate matches actual team headcount and workload, not a few expensive sessions |

## How the tags work

Every habit and config item in Chapters 2 through 5 is tagged like this:

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

- **Impact** is a rough, relative ranking (high / medium / low) of how much a habit typically
  moves total usage for someone using these tools daily. A hyphenated intermediate value
  (medium-high, low-medium) appears sparingly, only where a habit's impact genuinely sits between
  two tiers rather than cleanly in one. It's the reason the chapters themselves are ordered the
  way they are: Chapter 2 is almost entirely high-impact, Chapter 5 has real wins but a smaller
  share of them.
- **Helps** names the limit shape(s) above where the habit's leverage is sharpest. Most habits
  say **Universal**, meaning they help everyone, just by different amounts depending on which wall
  you're closest to. A few name one shape specifically, per the reasoning in the previous section,
  and a few say **Universal (leans X)** where a habit helps everyone but has noticeably more
  leverage for one shape without being exclusive to it.
- **Quality risk** is either **none** (safe to apply without measuring anything first: it
  either only removes waste or is neutral-to-positive for output quality) or **gated** (it
  trades model tier, reasoning effort, or review depth for savings, and can genuinely make
  output worse if applied blindly). Gated items cluster in [Chapter 5](05-model-effort-and-batch-tuning.md);
  the decision framework behind that distinction, and how to actually measure whether a gated
  change held quality, is [`docs/generative-ai/` Appendix C, Sections 4 and
  5](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#4-a-decision-framework-by-target-output-quality).

Read a gated item's tag as a requirement, not a suggestion: verify it holds on your own work
before adopting it as a standing habit, the same way [Chapter 6](06-measuring-whether-it-worked.md)
describes.

## References

- `docs/generative-ai/appendices/appendix-c-costs-and-getting-value.md`: service-tier and
  subscription-tier mechanics behind the four limit shapes above, and the cost/quality decision
  framework the Quality-risk tag is built on.
