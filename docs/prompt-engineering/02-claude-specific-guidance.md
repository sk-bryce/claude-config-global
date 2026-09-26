---
audience: human
created: 2026-09-25
updated: 2026-09-26
---

# Prompting Claude: Model-Specific Guidance

## Model generations and what changed

Anthropic's own prompting guidance is organized by model, not just by vendor: the current
best-practices page names Claude Fable 5.1, Claude Mythos 5.1, Claude Fable 5, Claude Mythos 5,
Claude Opus 5.5, Claude Opus 5, Claude Opus 4.8, Claude Opus 4.7, Claude Opus 4.6, Claude Sonnet 5,
Claude Sonnet 4.6, and Claude Haiku 4.5 as the models a reader might currently be prompting, and
links a dedicated page for each family's most recent members (Anthropic, Prompting best
practices). A prompt tuned for one generation routinely needs retuning for the next, not because
the old prompt was wrong, but because the specific weakness it was written to correct has moved
or disappeared.

The table below tracks the generational changes that alter what a prompt should say, each drawn
from that model's own guide.

| Change | First shows up in | What to change in the prompt |
| --- | --- | --- |
| More responsive to the system prompt; aggressive phrasing that fixed under-triggering now over-triggers | Opus 4.5, Opus 4.6 | Replace "CRITICAL: You MUST use this tool when..." with "Use this tool when...". Drop "if in doubt, use [tool]" |
| More upfront exploration and thinking at high effort, sometimes past what the task needs | Opus 4.6 | Replace blanket thoroughness defaults with targeted conditions; use a lower effort setting as a fallback throttle |
| Manual extended thinking (`budget_tokens`) deprecated, then removed | Deprecated on Opus 4.6 and Sonnet 4.6; a 400 error on Opus 4.7 and later, and on Sonnet 5 | Move thinking-depth control to the `effort` parameter and adaptive thinking |
| Thinking on by default when the `thinking` field is omitted | Opus 5, Sonnet 5 | Stop assuming a thinking-off baseline; budget `max_tokens` for thinking plus reply |
| Verifies and self-corrects its own work without being told | Opus 5 | Delete carried-over verification and re-check instructions rather than rewrite them |
| Longer default responses and more narration, independent of effort | Opus 5 | Prompt explicitly for conciseness and for a specific update cadence; effort no longer shortens replies |
| Thinking always on, cannot be disabled at any effort level; default effort drops one level | Opus 5.5 | Recalibrate effort from a clean sweep rather than reusing Opus 5 settings; remove thinking-disabled workarounds |
| Progress updates arrive as thinking blocks, not text blocks | Opus 5.5 | Set `thinking.display` to receive them; a client that renders only text blocks looks silent during long turns |
| Adaptive thinking on by default, where the same omitted-field request ran without thinking before | Sonnet 5 versus Sonnet 4.6 | Re-budget `max_tokens`; a new tokenizer alone produces about 30 percent more tokens for the same text |
| Sampling parameters (`temperature`, `top_p`, `top_k`) rejected outright | Sonnet 5 | Replace temperature-driven variety with explicit prompted alternatives, such as asking for several options before building one |
| More literal instruction following, especially at low effort | Sonnet 5 | State scope explicitly ("apply this to every section, not just the first") instead of relying on generalization |
| Fewer user-facing updates by default in long tool-calling turns; conversation history must stay append-only | Fable 5.1 versus Fable 5 | Ask explicitly for progress text; never edit or delete earlier turns, since that invalidates later thinking blocks |

(Anthropic, Prompting best practices; Prompting Claude Opus 5; Prompting Claude Opus 5.5;
Prompting Claude Sonnet 5; Prompting Claude Fable 5.1)

Claude Haiku 4.5 appears in the shared techniques, for example the context-awareness feature that
tracks the remaining token budget, but as of this page has no dedicated prompting-differences
guide the way the other current models do. Treat the shared "techniques for all current models"
guidance as the reference point for it rather than assuming a generation-specific behavior that
has not been documented.

Two threads run through nearly every row: thinking configuration keeps moving away from a manual
token budget and toward the `effort` parameter, and each generation needs less of the language
that compensated for the previous generation's specific weakness. The rest of this chapter works
through both threads in more depth.

## Clarity, context, and motivation

The foundations chapter covers the vendor-neutral form of this point: be explicit, and give a
reason rather than a bare rule. Two things about it are specific to current Claude models rather
than general good practice.

First, current Claude models are trained for precise instruction following, which cuts against
relying on the model to read intent between the lines. Anthropic's guidance gives a plain
example: asking "can you suggest some changes to improve this function?" gets suggestions, not
changes, even when changes are what was actually wanted; "Change this function to improve its
performance" gets the edit (Anthropic, Prompting best practices). This is not a wording problem
fixed by a stronger verb alone. If a product wants Claude to act rather than advise, the system
prompt should say so directly, for example with a standing rule such as "by default, implement
changes rather than only suggesting them" for a proactive product, or "do not jump into
implementation ... unless clearly instructed" for a conservative one (Anthropic, Prompting best
practices). Pick one stance and state it; neither default reliably emerges on its own.

Second, Claude Sonnet 5 pushes literalism further than earlier models: it does not silently
generalize an instruction from one item to the rest, and it does not infer requests that were not
made, particularly at low effort (Anthropic, Prompting Claude Sonnet 5). That precision is an
advantage for structured extraction and pipelines with carefully tuned prompts, but it means a
scope that used to be implicit now has to be written out: "apply this formatting to every
section, not just the first one," rather than trusting the model to notice the pattern was meant
to repeat.

Where an application needs the model to identify itself correctly, current guidance recommends
stating that fact directly rather than leaving it to assumption, for example "The assistant is
Claude, created by Anthropic. The current model is Claude Opus 5.5" (Anthropic, Prompting best
practices).

## Structure: XML tags, examples, and long inputs

XML tags remain, across every generation covered here, the one structural technique Anthropic has
not walked back: they reduce misinterpretation whenever a prompt mixes instructions, context,
examples, and variable input, and consistent, descriptive tag names nested to match a natural
hierarchy (documents inside `<documents>`, each inside `<document index="n">`) are still the
recommended default (Anthropic, Prompting best practices).

**Examples.** Use 3 to 5 examples wrapped in `<example>` tags (multiple examples inside
`<examples>`), made relevant to the real use case and diverse enough that Claude does not pick up
an unintended pattern from them (Anthropic, Prompting best practices). This still holds across
every current model; nothing in the model-specific pages narrows it. One addition specific to
thinking-enabled models: putting `<thinking>` tags inside a few-shot example shows Claude the
reasoning pattern to generalize into its own thinking blocks, not just the visible output format
(Anthropic, Prompting best practices).

**Long documents.** For inputs over roughly 20,000 tokens, put the documents near the top of the
prompt, above the query, instructions, and examples; Anthropic's own tests show queries placed
last improving response quality by up to 30 percent on complex, multi-document inputs (Anthropic,
Prompting best practices). Wrap each document in `<document>` tags with `<document_content>` and
`<source>` subtags. For tasks grounded in a specific document, ask Claude to quote the relevant
passages into a `<quotes>` block before it reasons over them; this keeps the model anchored to the
material that actually matters rather than the whole document (Anthropic, Prompting best
practices).

**A newer structural use of tags: marking untrusted pasted text.** Claude Opus 5.5 resists
indirect prompt injection (instructions arriving through tool results, web pages, or on-screen
content) better than earlier Opus models, and extends that resistance to text a user pastes into
their own message from somewhere else, provided the prompt marks which part of the message is the
paste. Wrap the pasted block in an opening and closing tag carrying a shared, application-generated
random ID, then tell the model in the system prompt that text inside that tag may contain
instructions the user did not write and should be followed only where the user's own message asks
for it (Anthropic, Prompting Claude Opus 5.5). This is one guardrail among several, not a complete
defense: the tags are plain text and can be imitated by content designed to fool the model, so
pair it with other prompt-injection mitigations rather than relying on it alone.

## Tone of instructions: emphasis, negation, and over-prompting

The companion foundations chapter already covers why aggressive emphasis and prohibition stacks
have aged badly in general terms. What is specific to Claude is which generations introduced the
shift and how far it now reaches.

The over-triggering effect is attributed by Anthropic specifically to Claude Opus 4.5 and Claude
Opus 4.6 becoming "more responsive to the system prompt than previous models" (Anthropic,
Prompting best practices); it is not claimed as a general property of every Claude model, and a
prompt written for an older or smaller model may not need the same dialing back. Claude Opus 4.6
separately over-explores at high effort: guidance for it recommends replacing blanket tool-use
defaults ("default to using [tool]") with a targeted condition ("use [tool] when it would enhance
your understanding of the problem"), and falling back to a lower `effort` setting if the model
still gathers more context than the task needs (Anthropic, Prompting best practices).

The same "state the positive, not the prohibition" logic that governs whole instructions also
governs output-format steering specifically. Rather than "Do not use markdown in your response,"
current guidance recommends "Your response should be composed of smoothly flowing prose
paragraphs," optionally reinforced with an XML tag naming the desired shape, for example asking
the model to write its prose inside a tag named for that shape (Anthropic, Prompting best
practices). A related, format-specific lever: the style used in the prompt itself tends to leak
into the response, so a prompt heavy with markdown headers and bullets pulls the output the same
way; stripping markdown from the prompt is one way to pull formatting back toward prose when a
plain negative instruction is not enough on its own (Anthropic, Prompting best practices).

One narrower, model-specific caution: with extended thinking disabled, Claude Opus 4.5 is
unusually sensitive to the literal word "think" and its variants; Anthropic recommends
substituting "consider," "evaluate," or "reason through" in prompts aimed at that configuration
(Anthropic, Prompting best practices).

## Self-checking, thinking, and effort

**Adaptive thinking has replaced the manual token budget.** Claude 4.6 models and later use
adaptive thinking (`thinking: {type: "adaptive"}`), where Claude decides when and how much to
think based on the `effort` parameter and the query's complexity, rather than a fixed
`budget_tokens` value the caller sets by hand. Anthropic's internal evaluations found adaptive
thinking reliably outperforms the older manual-budget extended thinking, and its guidance
recommends moving to it (Anthropic, Prompting best practices). Manual `budget_tokens` still works,
deprecated, on Opus 4.6 and Sonnet 4.6; on Opus 4.7 and later, and on Sonnet 5, setting it returns
a 400 error (Anthropic, Prompting best practices).

**`effort` is the primary dial, separate from the thinking toggle.** `effort` controls how many
tokens Claude spends across the whole response, thinking included, ranging from `low` (short,
scoped tasks) through `medium`, `high` (the default on most current models), `xhigh` (long-horizon
agentic and coding work), to `max` (no constraint on spending) (Anthropic, Effort). It is a
behavioral signal, not a strict cap: at low effort Claude still thinks when a problem genuinely
needs it, just less than it would at a higher setting for the same problem (Anthropic, Effort).
Effort level names do not carry the same amount of thinking across models or generations.
Anthropic's own cross-model note: Claude Sonnet 5 at `medium` is roughly comparable to Claude
Sonnet 4.6 at `high`, and Claude Opus 5.5 at `medium` (its default) matches or exceeds Claude Opus
5 at `high` (its default) on coding and knowledge-work evaluations (Anthropic, Prompting Claude
Sonnet 5; Prompting Claude Opus 5.5). Carrying an old effort setting forward onto a new model
version needs a fresh sweep against your own evals, not an assumption that the label still means
what it meant before.

**Self-verification and self-correction have their own per-model exception.** The general rule,
ask Claude to self-check by appending something like "verify your answer against [test
criteria]," still holds for models that do not already do this on their own. Claude Opus 5 is the
documented exception: it verifies and self-corrects its own work without being told, so a
verification instruction carried over from an older prompt causes over-verification, adding
tokens and latency for no quality gain, and the fix is to remove the instruction outright rather
than reword it (Anthropic, Prompting Claude Opus 5). The same model also narrates its own
corrections more than earlier models did, which can read as excessive hedging in a user-facing
product; if that matters, constrain when a correction is worth mentioning at all, for example only
when the earlier error would actually change the user's code or conclusions (Anthropic, Prompting
Claude Opus 5). Anthropic's Opus 5.5 guide does not restate the point, but it says existing
Claude Opus 5 prompts should perform well without changes and that the Opus 5 patterns remain a
reasonable starting point, so the same removal applies to prompts for Opus 5.5 (Anthropic,
Prompting Claude Opus 5.5).

**Effort is respected strictly at the low end on Sonnet 5.** At `low` and `medium` effort, Claude
Sonnet 5 scopes its work tightly to what was asked rather than going further, which is good for
cost and latency but carries some risk of under-thinking a moderately complex task. If shallow
reasoning shows up, Anthropic's recommendation is to raise effort rather than prompt around it,
reserving an explicit "think carefully through this multistep problem" instruction for cases where
effort must stay low for latency reasons (Anthropic, Prompting Claude Sonnet 5).

**Thinking-disabled configurations carry their own artifacts on Opus 5.** Opus 5 can disable
thinking, but only at effort `high` or below (combining disabled thinking with `xhigh` or `max`
effort returns a 400 error), and with thinking off it can occasionally leak a tool call into
visible text instead of a structured tool-use block, or emit internal thinking-like XML tags into
the visible response. The documented mitigations: remove any system-prompt rule telling the model
not to think or not to reason, since that increases leakage; if thinking must stay off, use the
page's general instruction rather than one that names the tags, which works less well. Better
still, keep thinking enabled and control cost through a lower effort level, which for most tasks
outperforms thinking-disabled at similar cost (Anthropic, Prompting Claude Opus 5). Claude Opus 5.5
removes the setting altogether: thinking is always on and cannot be disabled at any effort level,
so an integration built around thinking-disabled Opus 5 needs to migrate to a low-effort,
thinking-on configuration instead (Anthropic, Prompting Claude Opus 5.5).

**Changing effort mid-conversation has a caching cost.** Setting a new top-level `effort` value on
a later request restarts prompt caching for that conversation, because it reshapes the whole
rendered prompt. Models that support a per-message effort change, an empty `role: "system"`
message carrying only the new `output_config.effort`, can vary effort turn to turn without paying
that cost; where that is not available, pick one effort level for a cached conversation and hold
it (Anthropic, Effort).

## Output format control

**Prefilled responses are gone, not just discouraged.** Starting with Claude 4.6 models, a
request that includes a prefilled assistant message on the final turn returns a 400 error rather
than being silently accepted (Anthropic, Prompting best practices). Anthropic's migration
guidance maps each old use of prefill to a specific replacement:

| Old prefill use | Replacement |
| --- | --- |
| Forcing JSON, YAML, or a classification format | Structured Outputs, or a tool with an enum field for classification; ask directly for the schema first, since current models follow it reliably |
| Skipping a preamble ("Here is the requested summary:") | A direct system-prompt instruction not to start with "Here is..." or "Based on...", output inside an XML tag, or a tool call |
| Steering around an unwanted refusal | Usually unnecessary now; current models refuse less aggressively, so clear prompting in the user message is normally enough |
| Resuming an interrupted response | Move the continuation into the user message, quoting the last text the model produced and asking it to continue from there |
| Periodic context or role reinforcement | Move the reminder into a user turn, or hydrate context through a tool call or context compaction instead |

(Anthropic, Prompting best practices)

**Communication style defaults have shifted toward less, not more.** Current Claude models are
more direct and less self-congratulatory in their progress narration by default, and may skip a
verbal summary after a tool call and move straight to the next action. A prompt that wants that
visibility back has to ask for it explicitly, for example "after completing a task that involves
tool use, provide a quick summary of the work you've done" (Anthropic, Prompting best practices).
Claude Opus 5 is the documented exception in the other direction: its default responses run longer
than prior Opus models', and effort does not reliably shorten them, so conciseness needs its own
explicit instruction rather than a lower effort setting (Anthropic, Prompting Claude Opus 5).

**Mathematical notation defaults to LaTeX.** If a product needs plain text instead, say so
explicitly and name the notation to avoid (parenthesis-delimited LaTeX, dollar signs, fraction
macros), since the model will otherwise reach for LaTeX by default on anything mathematical
(Anthropic, Prompting best practices).

**Frontend and design defaults need naming, not just "avoid generic."** A generic instruction like
"avoid an AI-generated look" tends to swap one default aesthetic for another rather than
producing real variety, on both Claude Sonnet 5 and Claude Opus 5.5. What works instead is naming
the specific patterns to avoid, such as a list of overused fonts, a specific color scheme, or
pill-shaped buttons, or asking the model to propose several distinct visual directions and pick
one before building. The second approach matters more on Claude Sonnet 5, which no longer accepts
`temperature` as a lever for output variety at all (Anthropic, Prompting Claude Sonnet 5;
Prompting Claude Opus 5.5).

## Migration checklist for older prompts

Work through an existing prompt against each item. Most items name the model or generation where
Anthropic documents the behavior; skip an item if the target model predates it.

- [ ] Remove aggressive emphasis ("CRITICAL", "MUST", all-caps) written to fix under-triggering on
  Opus 4.5 or 4.6; replace with a plain conditional ("Use [tool] when...").
- [ ] Remove blanket thoroughness or tool-use defaults ("if in doubt, use [tool]", "default to
  using [tool]") on any current model; replace with a targeted condition.
- [ ] If the prompt sets manual extended thinking with a `budget_tokens` value, migrate to adaptive
  thinking and the `effort` parameter; on Opus 4.7 and later, and on Sonnet 5, the old field
  returns a 400 error rather than being ignored.
- [ ] Re-run an effort sweep against your own evals on every model upgrade rather than carrying the
  old effort level forward; the same level name does not mean the same amount of thinking across
  models.
- [ ] If the prompt targets Claude Opus 5 or Opus 5.5, remove any "verify your answer" or "double-check before
  responding" instruction rather than rewording it; the model does this unprompted, and the
  instruction now adds cost without adding quality.
- [ ] If the prompt includes a prefilled assistant message on the final turn, remove it and migrate
  to Structured Outputs, a direct no-preamble instruction, an XML output tag, or a tool call,
  depending on what the prefill was doing.
- [ ] If the prompt relies on `temperature`, `top_p`, or `top_k` for output variety and targets
  Sonnet 5, remove them (they return a 400 error there) and replace variety with an explicit
  "propose several options, then implement one" instruction.
- [ ] If the prompt was tuned for thinking disabled on Opus 5, re-test on Opus 5.5, which cannot
  disable thinking at all; move to a low-effort, thinking-on configuration instead.
- [ ] If the prompt suppresses narration ("hold all findings for the final response") because an
  older model over-narrated, check whether the target model already under-narrates by default
  (for example Fable 5.1) before keeping that suppression.
- [ ] If the prompt edits or rewrites earlier turns in a stored conversation, for compaction,
  redaction, or context hydration, confirm the target model does not require an append-only
  history; on Fable 5.1 and Opus 5.5 this can invalidate cached thinking blocks or raise an error.
- [ ] If the prompt bans markdown or a specific format with a bare negative ("do not use
  markdown"), replace it with a positive description of the desired shape, optionally reinforced
  with an XML output tag.
- [ ] If the prompt names "think" or "reasoning" directly in an instruction aimed at Opus 4.5 with
  thinking disabled, substitute "consider," "evaluate," or "reason through" instead.
- [ ] If the prompt handles untrusted pasted user content and targets Opus 5.5, consider wrapping
  pasted blocks in a tagged, ID-marked span and telling the model that instructions inside it need
  the user's own message to invoke them.

## References

- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) - Anthropic; the model-specific guidance table, general instruction-following and formatting examples, prefill migration table, adaptive thinking guidance, and the Opus 4.5/4.6 over-triggering and overthinking notes used throughout this chapter.
- [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) - Anthropic; source of the self-verification and self-correction exception, response-length and narration guidance, and the thinking-disabled artifacts and mitigation for Claude Opus 5.
- [Prompting Claude Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5) - Anthropic; source of the effort recalibration guidance, the always-on thinking change, progress updates arriving as thinking blocks, and the pasted-content tagging technique for prompt-injection resistance.
- [Prompting Claude Sonnet 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5) - Anthropic; source of the literal-instruction-following, strict-effort-at-low-end, sampling-parameter removal, and frontend-design-variety guidance for Claude Sonnet 5.
- [Effort](https://platform.claude.com/docs/en/build-with-claude/effort) - Anthropic; source of the effort-level definitions, the cross-model effort comparison notes, and the prompt-caching behavior of top-level versus per-message effort changes.
- [Prompting Claude Fable 5.1](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1) - Anthropic; source of the Fable 5.1 versus Fable 5 differences in default progress-update frequency and the append-only conversation-history requirement.
