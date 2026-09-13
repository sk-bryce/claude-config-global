---
audience: human
created: 2026-07-31
updated: 2026-07-31
---

# Chapter 5: Model, Effort, and Batch Tuning

## In short

- This chapter is about spending less per request, by picking a cheaper model, a lower reasoning
  effort, or an asynchronous tier for a given step. That is a different lever from Chapters 2 and
  3, which are about sending fewer and smaller requests in the first place.
- It comes fifth on purpose: a model tier and a reasoning-effort tier both multiply the cost of
  whatever context they're applied to. Shrinking that context first, with the habits already
  covered, is the larger and safer win; tuning the multiplier on top of an already-bloated context
  is a smaller and riskier one.
- Every habit here trades some amount of capability for savings, which is the one place in this
  guide where output quality can genuinely regress if a habit is applied blindly instead of
  measured. Almost everything below is tagged **Quality risk: gated** accordingly.

## Why this comes after context discipline and delegation

Picture cost as roughly `(size of what you send) x (price per token of the tier you send it at)`.
[Chapter 2](02-turn-session-and-context-discipline.md) and [Chapter 3](03-delegation-subagents-and-verbose-output.md)
attack the first factor: fewer turns, smaller context, verbose output isolated in a subagent
instead of riding along in the parent thread. This chapter attacks the second factor: the price
per token of the model and effort tier that context runs through.

The reason order matters is that the second factor is a multiplier on the first. Running a
bloated, poorly-scoped context through a cheaper model or a lower effort setting still pays the
bloat's cost, just at a smaller multiplier; it does not fix the bloat, and it adds a capability
cut on top of a request that was already larger than it needed to be. Fix the size of what you
send first, the way Chapters 2 and 3 describe, and only then decide what tier to run it at. Doing
it in the other order, reaching for a cheaper model before trimming what you send it, is how
people end up disappointed in a cheaper tier's output quality for reasons that were never really
about the model.

It's also why real quality risk lives in this chapter and mostly doesn't in the ones before it.
Turn discipline and delegation are close to free lunches: done well, they remove waste without
touching what the model is capable of. A lower model tier or reasoning-effort setting is not free
in the same way; it is a deliberate trade of some capability for some savings, and whether that
trade is a good one depends on the task, not just on the account-limit pressure you're under. Read
every **Quality risk: gated** tag below as a requirement to verify against your own work before
it becomes a standing habit, not a suggestion, the same way [Chapter 1](01-know-your-limit-type.md#how-the-tags-work)
frames it. [Chapter 6](06-measuring-whether-it-worked.md) covers how to actually check.

## Right-size the model per step, not per whole session

> **Impact:** high · **Helps:** Universal · **Quality risk:** gated

Most sessions mix step types of very different difficulty: locating a symbol, drafting a
commit message, and redesigning a module all happen in the same conversation, and none of them
need the same model. Assigning one model to an entire session, rather than picking a tier per
step, is the single most common way people either overspend (flagship-for-everything) or
underdeliver (cheap-for-everything) inside an agentic coding tool.

The mechanism behind this, and the arithmetic that tells you when a cheap-first approach actually
pays off, is not repeated here: see [`docs/generative-ai/` Appendix C, Section
3](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#3-concrete-cost-reduction-strategies)
for model routing and right-sizing, including the escalation-rate threshold formula that
determines whether a cheap-first router is actually winning, and [Section
4](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#4-a-decision-framework-by-target-output-quality)
for the decision tree that picks a tier by the cost of being wrong rather than by how impressive
the task looks.

What that appendix doesn't cover, because it's harness-specific, is what "route this step to a
cheaper tier" actually looks like when you're typing at a keyboard rather than calling an API
directly. That mechanism differs by tool: one harness exposes explicit subagent model pinning
plus a direct model or effort switch you can invoke mid-session; another routes through an
Auto- or Composer-style pool alongside its own subagent model fields. Neither is described here
on purpose; see Appendix A (`appendices/appendix-a-claude-code.md`) and Appendix B
(`appendices/appendix-b-cursor.md`) for the concrete commands and fields in the harness you
actually use.

## Tune reasoning effort to task ambiguity, not to a high default

> **Impact:** high · **Helps:** Universal · **Quality risk:** gated

Reasoning or thinking tokens are billed as output, the most expensive token category by a wide
margin, so a reasoning-effort setting is a cost dial as much as a quality dial. The general
mechanism, why this is true and what it implies for cost estimates, is covered in
[`docs/generative-ai/` Appendix C, Section
1.4](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#14-reasoning-tokens-are-billed-as-output)
and isn't repeated here. Leaving effort pinned high by default, on the assumption that more
reasoning can only help, quietly multiplies the bill on every step that didn't need it, including
the short, well-specified ones that make up most of a typical session.

The exact mechanics of how effort is expressed and gated differ by harness and, within a harness,
by model family. What a fixed thinking-token-budget setting does and does not do on a current
model, and how adaptive reasoning changes that picture, is Claude-specific detail that belongs in
this guide's own Appendix C (`appendices/appendix-c-claude-model-family.md`), not here. Check that
appendix, and Appendix A or B for the harness-level control surface, before assuming a given
effort setting behaves the way an older model generation did.

## Route work nobody is waiting on to an asynchronous or batch tier

> **Impact:** medium · **Helps:** metered-with-alerts · **Quality risk:** none

Some work genuinely has nobody waiting on the result right now: a backfill, an overnight
summarization pass, a bulk classification job, a periodic report. For exactly that category of
work, an asynchronous or batch tier is close to a free discount, because you're only giving up
immediacy you weren't using anyway: same model, same weights, only the delivery timing changes,
so this is a latency tradeoff rather than a quality one. It's the largest win for bulk or offline
workloads specifically, though every limit shape can use it where it applies. The discount
mechanism itself, and the boundary between where it applies (nothing time-sensitive, no human
blocked on the result) and where it doesn't
(interactive work, or a tightly coupled multi-step loop where each hop waits on the previous one)
is covered in [`docs/generative-ai/` Appendix C, Section
3.3](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#33-batch-and-asynchronous-tiers-for-bulk-work)
and not repeated here.

One point of confusion is worth flagging explicitly, because it's an easy mix-up: a coding
harness may bundle a feature that is literally named "batch," for example a pattern that
decomposes a task and runs several worktrees or agents in parallel. That is a task-decomposition
convenience, not the vendor's asynchronous Batch API discount described in the appendix above.
The two share a name and get conflated easily, but only one of them is an actual pricing lever;
the other is a way of organizing parallel work at standard rates. Before assuming your harness's
own "batch"-named feature is the discount, check Appendix A or B (`appendices/appendix-a-claude-code.md`,
`appendices/appendix-b-cursor.md`) for what that specific feature actually does.

## Gate all of this on your own measurement

Everything above trades model tier, reasoning effort, or delivery timing for savings, and the
first two of those three can genuinely make output worse if adopted on faith rather than checked.
Treat each **gated** item as a hypothesis about your own workload, not a settled fact: run it,
compare the result against what you were getting before, and only keep it as a standing habit
once it holds up on real tasks you care about. [Chapter 6](06-measuring-whether-it-worked.md)
covers the handful of cheap, ongoing signals worth watching for exactly this purpose, rather than
a one-off deep audit you run once and never revisit.

## References

### Local Reference (docs/generative-ai/)

- `docs/generative-ai/appendices/appendix-c-costs-and-getting-value.md` - Section 3 (concrete
  cost-reduction strategies, including model routing and the escalation-rate threshold formula in
  3.2) and Section 4 (the decision framework by target output quality) behind the "right-size the
  model per step" habit above; Section 1.4 (reasoning tokens billed as output) behind the
  reasoning-effort habit; Section 3.3 (batch and asynchronous tiers) behind the batch-routing
  habit.

### Further Local Reading (this guide)

- `docs/efficient-agentic-use/01-know-your-limit-type.md` - the four account-limit shapes and the
  Impact/Helps/Quality-risk tagging scheme used on every habit above.
- `docs/efficient-agentic-use/02-turn-session-and-context-discipline.md` - the turn- and
  context-shrinking habits this chapter assumes come first.
- `docs/efficient-agentic-use/03-delegation-subagents-and-verbose-output.md` - subagent and
  verbose-output isolation, the other half of shrinking what a model or effort tier gets applied
  to.
- `docs/efficient-agentic-use/06-measuring-whether-it-worked.md` - how to check whether a gated
  change from this chapter actually held quality on your own work.
- `docs/efficient-agentic-use/appendices/appendix-a-claude-code.md` - Claude Code's concrete
  model/effort switching and subagent model-pinning mechanism.
- `docs/efficient-agentic-use/appendices/appendix-b-cursor.md` - Cursor's Auto/Composer-style
  routing pool and subagent model fields.
- `docs/efficient-agentic-use/appendices/appendix-c-claude-model-family.md` - adaptive reasoning
  and what a fixed thinking-token budget does and doesn't do on current Claude models.
