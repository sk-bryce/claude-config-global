---
audience: human
created: 2026-09-25
updated: 2026-09-26
---

# Prompt Engineering Foundations and Standards

## Scope and sources

This chapter covers what makes a prompt work when the choice of model is not fixed: the points that Anthropic, OpenAI, and Google's own prompting documentation share, the named parts of a prompt, which named techniques still earn their place with current frontier models, which plain-language writing standards carry over into prompt prose, and which once-common practices now hurt more than they help. It does not cover model-specific tuning (for example, effort settings or thinking-budget parameters that apply to one vendor's models only) except where a vendor's own guidance uses that detail to illustrate a general point.

Sources are trusted in this order: vendor documentation first (Anthropic's platform docs, OpenAI's developer docs, Google's Gemini API docs), then peer-reviewed or widely cited surveys (The Prompt Report), then practitioner writing (open-source prompting skills and tutorials with a visible author and reasoning, not listicle blog posts). Every source cited here was fetched and confirmed working on 2026-09-25; a reader returning to this chapter later should expect vendor guidance in particular to keep changing, since all three vendors revise these pages as new models ship.

## What the major vendors agree on

Read side by side, Anthropic, OpenAI, and Google's prompting guides converge on the same handful of points, even though each states them in its own words.

**Be explicit rather than assume the model will infer intent.** Anthropic's best-practices page states this as a "golden rule": show the prompt to a colleague with minimal context on the task and ask them to follow it; if they would be confused, the model will be too. OpenAI's guide makes the same point in reverse, noting that its GPT models "benefit from more explicit instructions around how to accomplish tasks," contrasting this with reasoning models that can work from higher-level guidance alone. Google's Gemini guidance opens with the same idea: clear and specific instructions are "an effective and efficient way to customize model behavior."

**Examples work, and vendors recommend using them by default.** Anthropic recommends 3 to 5 examples wrapped in `<example>` tags, chosen to be relevant to the real use case and diverse enough that the model does not pick up unintended patterns. Google is the most emphatic of the three: its guide states plainly that "we recommend to always include few-shot examples in your prompts. Prompts without few-shot examples are likely to be less effective." OpenAI's guide gives the same advice in its own terms, recommending "input/output examples in the prompt" that "show a diverse range of possible inputs with the desired outputs."

**Structure and delimiters reduce misreading.** All three recommend marking distinct parts of a prompt so the model does not have to guess where an instruction ends and a piece of data begins. Anthropic recommends XML tags such as `<instructions>`, `<context>`, and `<input>`, nested when content has a natural hierarchy. OpenAI's guidance recommends Markdown headers, lists, and XML tags for the same reason, to "mark distinct sections of a prompt" and communicate hierarchy. Google's Gemini 3 guidance likewise recommends XML tags or Markdown headings to separate roles, constraints, context, and tasks.

**Context and reasons improve results more than bare instructions do.** Anthropic's guide shows that explaining why an instruction matters, for example that a response will be read aloud by text-to-speech software and so should avoid ellipses, produces better generalization than a bare prohibition. Google demonstrates the same point with a worked example: adding a router's troubleshooting guide as context produces more targeted, accurate responses than generic instructions alone.

**Complex tasks benefit from decomposition, and testing should happen before deployment, not after.** Google recommends splitting complex work into separate prompts, either chained sequentially or run in parallel over separate portions of data. OpenAI's guidance stresses building "tests and evaluation suites that measure prompt behavior" before a prompt goes into production, treating a prompt as something to be tested like code rather than tuned by feel. Anthropic's overview page states outright that its prompting guidance assumes a reader already has a clear definition of success criteria and a way to test against them; readers who lack that should establish it before prompt engineering, not instead of it.

## Anatomy of a prompt

No vendor publishes a single canonical list of prompt parts, but their guidance and the structures they recommend imply the same set of pieces. Anthropic's tag-based structuring (`<instructions>`, `<context>`, `<input>`, `<example>`) and OpenAI's role-based structuring (developer messages for rules, user messages for the input those rules apply to) both separate the same underlying concerns; a well-built prompt distinguishes each of the following even when it does not label them with tags.

- **Goal.** What the response is actually for. A goal that is only implied forces the model to guess at the reader's real intent behind the literal request.
- **Context.** Background the model needs but was not trained on: who the audience is, what happens with the output afterward, why the task exists at all. Anthropic's text-to-speech example is a context statement doing the work that a bare prohibition ("never use ellipses") could not do on its own.
- **Input data.** The actual material to operate on, kept visibly separate from instructions about what to do with it. Anthropic's guidance on long-context prompting recommends placing input documents ahead of the instructions and query that act on them, and wrapping each in its own `<document>` tag with source metadata, specifically so the model does not have to hold the boundary between data and instruction in its own reasoning.
- **Instructions.** The actual steps or rules to follow, ideally stated as what to do rather than only what to avoid (see Practices that have aged badly below for why the negative form backfires).
- **Constraints, and the reason for each.** A hard limit (a format, a length, a tool restriction) paired with why it exists. Anthropic's guidance is explicit that giving a reason, not just a rule, helps the model generalize the constraint to cases the prompt did not anticipate.
- **Output format.** What shape the response should take: prose, a table, JSON, a specific tag to wrap the answer in. Google's guidance recommends stating this explicitly, and its "completion strategy" of starting the response yourself is one concrete way to pin the format down.
- **Examples.** Worked input-output pairs that show, rather than tell, the desired pattern. Covered in more depth in the techniques section below.
- **Done criteria.** The condition that tells the reader, human or model, that the task is actually finished. This is the part vendor documentation covers least explicitly and practitioner writing covers most directly: the Matt Pocock `writing-for-agents` skill argues every step needs "a completion criterion, the condition that tells the agent the work is done," and that a vague one invites premature completion, ending the step before it is genuinely done.

Not every prompt needs all eight parts spelled out. A one-line chat question has an implicit goal and no separate input data. The parts matter most, and the case for tagging or separating them is strongest, once a prompt mixes several of these at once, since that is exactly the condition under which a model has to guess which piece of text is which.

A prompt combining several of these parts, using Anthropic's tag convention, might look like this:

```xml
<context>
The output goes straight into a customer-facing email, so tone and length both matter.
</context>

<instructions>
Summarize the ticket below in three sentences, then propose one next step.
</instructions>

<constraints>
Keep the summary under 60 words. The reader has never seen the ticket, so do not
assume they know any internal shorthand used in it.
</constraints>

<input>
{{TICKET_TEXT}}
</input>

<example>
Summary: The customer's export tool times out on files over 500 rows...
Next step: Ask for a sample file so we can reproduce the timeout locally.
</example>

Done when: the summary and next step are both present, the summary is under 60 words,
and no internal shorthand from the ticket appears unexplained.
```

The goal here is implicit in the instruction itself (produce a usable summary and next step); everything else, context, constraints and their reasons, input, an example, and a done-criteria statement, is spelled out and kept in its own block.

## Techniques and when they still help

The Prompt Report (Schulhoff et al., arXiv 2406.06608) catalogs 58 distinct prompting techniques for text alone, evidence that naming and testing individual techniques is now established practice rather than folklore. Vendor guidance has, if anything, narrowed which of those techniques it still recommends by default as models improve. Anthropic's own interactive tutorial offers a hands-on, chaptered walkthrough of several of the techniques below, roles, examples, chain of thought, and prompt chaining, for a reader who wants to practice each one directly.

**Few-shot examples.** Still holds up, and arguably the technique with the least disagreement across sources. Anthropic calls examples "one of the most reliable ways" to steer output format, tone, and structure, and recommends 3 to 5 of them. Google goes further, stating that prompts without few-shot examples "are likely to be less effective." OpenAI recommends the same pattern under a different name, "input/output examples." None of the three vendor guides suggest dropping examples for frontier models; the only refinement is that examples should stay diverse enough that the model does not overfit to an accidental surface pattern in them, a caution Anthropic states directly.

**Role prompting.** Still useful for setting tone and domain focus, but the evidence for it being load-bearing has narrowed. Anthropic's current guidance frames a system-prompt role as a light touch: "even a single sentence makes a difference," illustrated with a one-line example ("You are a helpful coding assistant specializing in Python."), not an elaborate persona. OpenAI's role framework is structural rather than a persona at all: developer, user, and assistant messages exist to set an authority hierarchy for whose instructions win, not to have the model imagine itself as a specific character. Role prompting still earns a place, but current guidance treats it as a small, targeted lever rather than a technique that needs paragraphs of backstory to work.

**Chain of thought and thinking modes.** This is the technique that has moved the most. Manual, hand-written step-by-step chain-of-thought prompting was the standard way to get a model to reason before answering; Anthropic's current guidance now treats it as a fallback for when a model's built-in thinking mode is off, not the default. Where a model has adaptive or extended thinking built in, Anthropic states plainly that "a prompt like 'think thoroughly' often produces better reasoning than a hand-written step-by-step plan," because the model's own reasoning frequently exceeds what a human would prescribe. Prescriptive, itemized chain-of-thought scaffolding, once considered best practice, can now actively underperform a simple instruction to reason on models with native thinking. It still has a place as a fallback: on models or configurations where thinking is off, Anthropic recommends manual step-by-step prompting with tags like `<thinking>` and `<answer>` to separate reasoning from the final output.

**Structured delimiters (XML tags, Markdown structure).** Still recommended without qualification by all three vendors, covered in more detail under "What the major vendors agree on" above. This is the one technique in this list with no vendor walking back its value as models improve; if anything, Google's newest Gemini guidance leans on it more, recommending XML tags or Markdown headings specifically to separate roles, constraints, context, and tasks before the model reasons about a task.

**Prompt chaining.** Still useful, but its role has shifted from "the way to get multistep reasoning at all" to "the way to inspect or control a pipeline." Anthropic's current guidance is explicit that adaptive thinking and native subagent orchestration now handle most multistep reasoning internally, and that prompt chaining, breaking a task into sequential API calls, remains useful specifically "when you need to inspect intermediate outputs or enforce a specific pipeline structure," with self-correction (draft, review against criteria, refine) as the most common surviving pattern. Google's guidance frames the same idea from the other direction, recommending decomposition for complex tasks that a single prompt handles poorly, whether split into sequential steps or run in parallel over independent portions of data.

| Technique | Still a default recommendation? | What changed |
| --- | --- | --- |
| Few-shot examples | Yes, unqualified | No vendor walks this back; Google treats it as close to mandatory. |
| Structured delimiters (XML/Markdown) | Yes, unqualified | All three vendors still recommend it; Google's newest guidance leans on it more, not less. |
| Role prompting | Yes, but lighter | A single sentence now does the job vendor guidance once used a paragraph for. |
| Prompt chaining | Yes, narrower | Reserved for inspecting intermediate output or enforcing a pipeline, not general multistep reasoning. |
| Prescriptive chain-of-thought scaffolding | No, as a default | Superseded by native thinking modes on models that have them; kept only as a fallback when thinking is off. |

## Plain-language writing standards that transfer

A model reading a prompt is, in this one respect, like any other reader trying to follow instructions on a first pass: it benefits from the same clarity rules that technical writing standards have converged on for decades. Not every rule in every standard transfers, since some were built for a human audience or medium that a prompt does not share.

**What transfers directly.** The plain-language guidelines at digital.gov (the current home of plainlanguage.gov's guidance) recommend active voice ("you must do it" instead of "it must be done"), present tense as "the simplest and strongest form of a verb," and avoiding hidden verbs such as "conduct an analysis" in favor of the direct form, "analyze." All three carry over to prompt writing without modification: an instruction written as a direct, present-tense command is both shorter and less ambiguous about who is meant to act, and a prompt has exactly the same failure mode a government form does, a reader (here, a model) working through it in one pass with no chance to ask a clarifying question first. The Google developer documentation style guide's core stance, that its rules are "guidelines, not rules" a writer should depart from "when doing so improves your content," transfers as a caution against treating any of these standards, including this chapter's, as inviolable. Its recommendations on active voice, addressing the reader in second person, and minimizing jargon all transfer the same way plain-language's do.

ASD-STE100 (Simplified Technical English, maintained by the Simplified Technical English Maintenance Group under the Aerospace, Security and Defence Industries Association of Europe) contributes its sentence-discipline rules well: one instruction per sentence, a hard cap around 20 to 25 words per sentence, and one-word-one-meaning, using a given word the same way every time it appears. These transfer cleanly to prompt instructions, where an ambiguous word or an overloaded sentence with two instructions folded together is exactly the kind of thing a model can misparse. What does not transfer is ASD-STE100's controlled vocabulary itself, a fixed dictionary of roughly 900 approved words: a prompt author writing about a specific codebase, API, or domain needs the actual technical terms for that domain, not a restricted general-purpose word list built for aircraft maintenance manuals.

Diataxis (the tutorials, how-to guides, reference, and explanation split) transfers as a principle more than as a literal structure: its core claim is that content should be organized around what the reader is trying to do, not mixed indiscriminately, and a prompt genuinely mixing instruction, background, and raw data without marking the boundaries is the same failure Diataxis describes for documentation that mixes a tutorial with a reference in one page. What does not transfer is the four-way split itself: a single prompt usually needs instructions, context, and examples together in one place to work at all, where Diataxis would keep those apart as separate documents for a human reader with time to navigate between them.

The pstack `technical-writing` skill (Lauren Tan's skill in the `cursor/plugins` repository) is a practitioner example of applying exactly this bundle, Diataxis, Google developer style, ASD-STE100, and a fourth layer it calls Global English, directly to agent-read text rather than human-read documentation. It adds two rules specific to that audience: cut every non-functional word, since an agent reading a prompt has no patience for filler a human reader would skim past, and use exact names from the material itself, stating plainly that "the codebase is the word list," meaning real symbol and command names belong in a prompt rather than a paraphrased description of them.

## Practices that have aged badly

**All-caps and aggressive emphasis ("CRITICAL: You MUST...").** Per Anthropic's best-practices page, aggressive emphasis written for an older, under-triggering model now over-triggers specifically on Claude Opus 4.5 and 4.6, and moderate wording such as "Use this tool when..." works better (chapter 02 covers this in detail).

**Stacks of prohibitions.** Telling a model everything it must not do, rather than what it should do, was common practice when models needed heavy negative steering. The Matt Pocock `writing-for-agents` skill states the mechanism directly: "steering by prohibition drags the forbidden behaviour into context and makes it more available, not less," illustrated with the classic instruction-following failure, telling someone not to think of an elephant. Its recommended fix is to "prompt the positive": state the target behavior so the banned one never has to be named at all, reserving an explicit prohibition only for a genuine hard guardrail that cannot be phrased positively.

**Blanket self-check and verification instructions.** Once a reasonable hedge against earlier models that skipped their own checking; Anthropic now says that on Claude Opus 5 and Opus 5.5, which already verify their own work, carried-over verification instructions cause over-verification and should be removed, not rewritten (chapter 02 covers this in detail).

**Prescriptive, itemized chain-of-thought scaffolding as a default.** As covered in the techniques section above, Anthropic's current guidance now prefers a general instruction to reason over a hand-written step-by-step plan for models with native thinking, on the grounds that the model's own reasoning frequently exceeds what a human would prescribe. A rigid, numbered reasoning template that was once considered a reliability technique can now narrow a model's reasoning to something worse than what it would produce unprompted.

**Elaborate persona boilerplate.** Long, novelistic system-prompt personas, complete with backstory and personality traits, were once a common way to steer tone. Anthropic's current guidance shows the opposite pattern working: a one-sentence role statement ("You are a helpful coding assistant specializing in Python.") is presented as sufficient, with the explicit framing that "even a single sentence makes a difference." The elaborate version is not shown to actively hurt output, but current guidance no longer treats it as necessary, and the plain-language and technical-writing standards covered above (cut every non-functional word) argue directly against padding a prompt with backstory the model does not need to do the job.

**Prefilled assistant responses to force a format.** Once a standard workaround for locking in a JSON structure, skipping a preamble, or steering around a refusal. Anthropic now says prefill on the final assistant turn is not supported on its newest models, and that direct instructions and structured outputs replace it (chapter 02 covers this in detail).

**Over-prompting for tool use and thoroughness ("if in doubt, use the tool," "default to being thorough").** Instructions written to fight an older model's tendency to under-use tools or stop too early cause over-triggering specifically on Claude Opus 4.5 and 4.6, and Anthropic recommends targeted conditions over blanket defaults ([chapter 02](02-claude-specific-guidance.md)).

The pattern across all seven is the same: each was a reasonable fix for an older model's specific weakness, and each now overcorrects on a model that no longer has that weakness.

| Aged practice | Older phrasing | Current phrasing |
| --- | --- | --- |
| Aggressive emphasis | "CRITICAL: You MUST use this tool when..." | "Use this tool when..." |
| Prohibition stacks | "Never use ellipses" | State the positive target behavior instead |
| Blanket self-check | "Verify your answer before finishing," applied unconditionally | Removed entirely on models that already self-verify |
| Prescriptive chain of thought | A numbered, hand-written reasoning template | "Think thoroughly," letting native thinking do the rest |
| Tool-use over-prompting | "If in doubt, use [tool]" | "Use [tool] when it would enhance your understanding of the problem" |

## References

- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) - Anthropic; source of the golden rule, example-tag guidance, the "CRITICAL: You MUST" rewrite, verification and over-prompting guidance, prefill migration, and the role and thinking-technique guidance used throughout this chapter.
- [Prompt engineering overview](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview) - Anthropic; source of the "define success criteria before prompt engineering" framing and the pointer to the interactive tutorial.
- [Anthropic's prompt engineering interactive tutorial](https://github.com/anthropics/prompt-eng-interactive-tutorial) - Anthropic; a chaptered, example-driven tutorial covering roles, examples, chain of thought, and prompt chaining.
- [Prompt engineering guide](https://developers.openai.com/api/docs/guides/prompt-engineering) - OpenAI; source of the explicit-instructions guidance, the developer/user role hierarchy, few-shot recommendation, and the recommendation to build test and evaluation suites before deploying a prompt.
- [Gemini prompting strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies) - Google; source of the "always include few-shot examples" recommendation, the context-addition example, task decomposition guidance, and the XML/Markdown structuring recommendation.
- [The Prompt Report: A Systematic Survey of Prompting Techniques](https://arxiv.org/abs/2406.06608) - Schulhoff et al.; source of the count of 58 cataloged text-prompting techniques, used to support that named-technique evaluation is now established practice.
- [Google developer documentation style guide](https://developers.google.com/style) - Google; source of the "guidelines, not rules" framing and its active-voice, second-person, and jargon-avoidance recommendations.
- [Diataxis](https://diataxis.fr/) - Diataxis; source of the tutorials/how-to/reference/explanation split and its principle of organizing content around what the reader is trying to do.
- [Simplified Technical English](https://en.wikipedia.org/wiki/Simplified_Technical_English) - Wikipedia; source of ASD-STE100's governance, sentence-length limits, and one-word-one-meaning rule.
- [Plain language guides](https://digital.gov/guides/plain-language) - digital.gov (the current home of plainlanguage.gov's guidance); source of the pointer to the writing-for-understanding sub-guide.
- [Writing for understanding](https://digital.gov/guides/plain-language/writing) - digital.gov; source of the active-voice, present-tense, and hidden-verb (nominalization) guidance quoted in this chapter.
- [writing-for-agents skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md) - Matt Pocock; source of the prohibition/positive-steering guidance and the completion-criterion concept used in the anatomy-of-a-prompt section.
- [technical-writing skill](https://github.com/cursor/plugins/blob/main/pstack/skills/technical-writing/SKILL.md) - Lauren Tan; practitioner example layering Diataxis, Google developer style, ASD-STE100, and Global English for agent-read text, source of the "codebase is the word list" guidance.
