---
audience: human
created: 2026-07-31
updated: 2026-08-31
---

# Appendix C: Claude Model Family Specifics

This appendix grounds [Chapter 5](../05-model-effort-and-batch-tuning.md)'s model- and
effort-tuning advice in behavior specific to the Claude model family: how reasoning depth is
actually controlled on current models, why an old habit around thinking-token budgets silently
stops working, and the tokenizer and billing quirks that make cross-generation comparisons
unreliable. It is reference material, not a linear read: jump to the section you need.

## 1. Stale advice: fixed thinking-token budgets no longer do anything

A habit that was completely reasonable on older Claude models is to set a fixed token budget for
extended thinking (a `MAX_THINKING_TOKENS`-style setting, or the equivalent harness control) and
expect the model to reason up to roughly that ceiling. On current Claude models this habit is
silently dead.

Per Anthropic's environment-variable documentation, `MAX_THINKING_TOKENS` has no effect on
adaptive-reasoning models: from Claude Code v2.1.111 onward, it has no effect on Fable 5, Sonnet
5, or Opus 4.7 and later, all of which always use adaptive reasoning rather than a fixed budget
(Anthropic, "Environment variables," see References). There is an escape hatch,
`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`, which can fall back to the old fixed-budget behavior,
but only on the older Opus 4.6 and Sonnet 4.6. On the newer adaptive-reasoning models it also has
no effect (Anthropic, "Environment variables," see References).

**Why this matters practically:** setting a thinking-token budget is exactly the kind of habit
that carries forward unnoticed from an older model generation, because it fails silently rather
than erroring. You set the variable, nothing complains, and you simply stop getting the effect you
expected: the model reasons as much as it judges the task needs, regardless of what you set. If
you are tuning cost or latency and a thinking-budget variable seems to do nothing, that is very
likely why. The dial that replaced it is `/effort` (Section 2 below).

## 2. The real dial: `/effort`

Claude Code exposes reasoning-depth and effort control through the `/effort` command, with levels
including low, medium, high, xhigh, max, and auto; model aliases let you select a model without
remembering an exact version string (Anthropic, "Model configuration," see References).

Two things to check before assuming a level is available on a given model:

- **Effort support itself is gated per model.** Per `skills/cursor-projection/references/harness-matrix.md`'s "Subagents:
  content portability" section, confirmed 2026-07-30 against the Claude Code 2.1.220 subagent
  frontmatter schema: effort support and the specific levels available are gated per model
  (`supportsEffort`, `supportedEffortLevels` in the model catalog); `xhigh` and `max` are further
  gated behind additional model-specific checks beyond plain support (`skills/cursor-projection/references/harness-matrix.md`).
- **Do not assume low through high are universal either.** The same note applies to the whole
  ladder, not just the top two levels: verify a level is listed for your target model before
  pinning it in a skill or subagent definition, rather than assuming it inherited support from a
  sibling model in the same family.

In practice: `/effort` (or the harness-native equivalent) is the dial Chapter 5 means when it
talks about tuning reasoning effort. A fixed thinking-token budget is not a substitute for it on
any current-generation model.

## 3. Tokenizer generations are not comparable

Claude 4.7 and later use a newer tokenizer that produces roughly 30 percent more tokens for the
same text than earlier model generations, per Anthropic's own pricing page (see
[`docs/generative-ai/` Appendix C, Section
5.1](../../generative-ai/appendices/appendix-c-costs-and-getting-value.md#51-why-headline-per-token-prices-are-not-comparable)).

Practical consequence for this guide's audience: do not compare token counts, context budgets, or
cost estimates across Claude model generations linearly. A context-window ceiling, a `max_tokens`
setting, or a rough cost-per-request figure that held on an older model does not transfer to a
newer one at face value: the same text now costs measurably more tokens before a single pricing
tier is even considered. If a number matters (an approaching context limit, a per-request cost
estimate), re-measure it with an actual token count against the model you're currently using
rather than assuming a prior generation's figure still applies.

## 4. Reasoning tokens are billed as output, which is what makes effort a cost lever

Across every vendor, reasoning tokens are billed at the output rate, the most expensive token
category by a wide margin (see [`docs/generative-ai/` Appendix C, Section
1.4](../../generative-ai/appendices/appendix-c-costs-and-getting-value.md#14-reasoning-tokens-are-billed-as-output)).
That general mechanism is what makes effort tuning ([Chapter
5](../05-model-effort-and-batch-tuning.md)) a direct, controllable cost lever specifically on
Claude models: effort level (Section 2 above) is the exposed dial for exactly this billing
category. Turning effort down on a step that doesn't need deep reasoning isn't just a quality
trade, it's the mechanism that keeps the most expensive token category from being spent on steps
that didn't call for it.

## 5. Mapping task type to model tier on the current Claude lineup

[`docs/generative-ai/` Appendix C, Section
2.2](../../generative-ai/appendices/appendix-c-costs-and-getting-value.md#22-what-the-price-ladder-actually-buys)
and [Section
4](../../generative-ai/appendices/appendix-c-costs-and-getting-value.md#4-a-decision-framework-by-target-output-quality)
already lay out the general framework: larger, newer models win on long dependency chains and
ambiguous specifications; smaller models are the better engineering choice, not merely the
tolerable one, on narrow and well-specified work. This section is how that general framework maps
onto the current Claude lineup specifically, not a repeat of it.

Describe the mapping by role rather than by a fixed set of model names, since the actual lineup
changes over time and this guide is explicitly not trying to be a live model catalog:

- **Mechanical, narrow, well-specified tasks:** classification into a fixed label set,
  schema-driven extraction, format conversion, simple routing. These suit the smallest model in
  the current-generation lineup. The quality difference against a larger model is usually
  unmeasurable on this class of task, and latency and cost both favor the small tier.
- **Standard, well-scoped work:** most day-to-day coding steps, drafting, routine review. These
  suit a mid-tier model. This is where the bulk of an agentic session's steps land, and it's the
  tier worth defaulting to unless a step gives you a specific reason to move off it.
- **Ambiguous refactors, architecture decisions, and hard debugging:** long dependency chains,
  subtle reasoning, adversarial edge cases. These suit the largest readily-available model, run
  at a higher effort level.
- **Exceptionally hard, long-horizon work:** the rare step where correctness matters more than
  cost and the task genuinely exceeds what the largest readily-available model handles well.
  This suits the most capable model a vendor offers, when access to it is available.

As always in this guide, moving down this ladder is a capability trade, not a free lunch.
Chapter 5's **Quality risk: gated** framing and [Chapter
6](../06-measuring-whether-it-worked.md)'s measurement habits apply here exactly as they do to any
other effort- or model-tuning decision.

## References

### Official Documentation

- [Environment variables](https://code.claude.com/docs/en/env-vars) - Anthropic; `MAX_THINKING_TOKENS` and `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` behavior on adaptive-reasoning models, fetched and confirmed 2026-07-31.
- [Model configuration](https://code.claude.com/docs/en/model-config) - Anthropic; `/effort` levels and model aliases, fetched and confirmed 2026-07-31.

### Further Local Reading

- `skills/cursor-projection/references/harness-matrix.md` - "Subagents: content portability" section; per-model effort-level gating (`supportsEffort`, `supportedEffortLevels`), confirmed 2026-07-30 against the Claude Code 2.1.220 subagent frontmatter schema.
- `docs/generative-ai/appendices/appendix-c-costs-and-getting-value.md` - Section 1.4 (reasoning tokens billed as output), Section 2.2 (what the price ladder actually buys), Section 4 (decision framework by target output quality), and Section 5.1 (why headline per-token prices, including tokenizer generation, are not comparable): the general framework this appendix maps onto the current Claude lineup.
- `docs/efficient-agentic-use/05-model-effort-and-batch-tuning.md` - the chapter this appendix grounds.
