---
created: 2026-09-26
updated: 2026-09-26
source: docs/prompt-engineering/ chapters 01 to 04 (hand-condensed, not a sync copy)
---

# Prompt Writing Reference

## Anatomy of a prompt

- **Goal.** What the response is for. Leaving it implicit forces the model to guess intent.
- **Context.** Background the model was not trained on: audience, what happens with the output
  after, why the task exists. A reason changes generalization more than a bare rule does.
- **Input data.** The material to operate on, kept visibly separate from the instructions that act
  on it. For inputs over roughly 20,000 tokens, put the documents near the top, above the query and
  instructions, and wrap each in `<document>` tags with source metadata.
- **Instructions.** The steps to follow, stated as what to do rather than only what to avoid.
- **Constraints, and the reason for each.** A hard limit (format, length, tool restriction) paired
  with why it exists, so the model can generalize it to cases the prompt did not anticipate.
- **Output format.** The shape the response should take: prose, a table, JSON, a specific tag.
- **Examples.** Worked input-output pairs that show the desired pattern rather than describe it.
- **Done criteria.** The condition that tells the reader, human or model, the task is actually
  finished. A vague one invites the model to stop before the work is done.

Not every prompt needs all eight spelled out; a one-line question has an implicit goal and no
separate input data. Tagging or separating the parts matters most once a prompt mixes several of
them at once, since that is exactly when a model has to guess which piece of text is which.

## Claude-specific layer

**XML tags and long-input placement.** XML tags are the one structural technique Anthropic has not
walked back across any model generation: use consistent, descriptive tag names, nested to match a
natural hierarchy (`<documents>` containing `<document index="n">`). For long documents, place them
above the query, instructions, and examples; Anthropic's own tests show queries placed last
improving response quality by up to 30 percent on complex, multi-document inputs. For a task
grounded in a specific document, ask the model to quote relevant passages into a `<quotes>` block
before it reasons over them. A newer use: wrap pasted, potentially untrusted text in a tag carrying
a shared, application-generated random ID, and tell the model in the system prompt that content
inside that tag may carry instructions the user did not write and should be followed only where the
user's own message asks for it. This helps most on Claude Opus 5.5 and is one guardrail among
several, not a complete defense against prompt injection.

**Examples in `<example>` tags.** Use 3 to 5 examples, wrapped individually in `<example>` tags
(multiple examples inside `<examples>`), relevant to the real use case and diverse enough that the
model does not pick up an unintended pattern. On thinking-enabled models, putting `<thinking>` tags
inside a few-shot example shows the model the reasoning pattern to generalize into its own thinking
blocks, not just the visible output format.

**Emphasis and negation.** Aggressive emphasis ("CRITICAL: You MUST...") written to fix
under-triggering on an older model now over-triggers specifically on Claude Opus 4.5 and 4.6;
prefer a plain conditional ("Use this tool when..."). The same logic applies to output-format
steering: instead of "Do not use markdown in your response," state the positive target ("Your
response should be composed of smoothly flowing prose paragraphs"), optionally reinforced with an
XML tag naming the desired shape. The style used in the prompt itself tends to leak into the
response, so a prompt heavy with markdown headers and bullets pulls the output the same way;
stripping markdown from the prompt can pull formatting back toward prose. Stacks of prohibitions in
general drag the forbidden behavior into context and make it more available, not less; state the
target behavior instead, and reserve an explicit prohibition for a genuine hard guardrail that
cannot be phrased positively. One narrow, model-specific caution: with extended thinking disabled,
Claude Opus 4.5 is unusually sensitive to the literal word "think" and its variants; substitute
"consider," "evaluate," or "reason through" for that configuration.

**Self-check and thinking, scoped to Claude Opus 5 and Opus 5.5.** A general "verify your answer
against [criteria]" instruction still helps on models that do not already self-check. Claude Opus 5
is the documented exception: it verifies and self-corrects its own work without being told, so a
carried-over verification instruction causes over-verification, adding cost with no quality gain,
and should be removed outright rather than reworded. Anthropic's Opus 5.5 guide says existing Opus 5
prompts should perform well unchanged and that Opus 5 patterns remain a reasonable starting point,
so the same removal applies to prompts for Opus 5.5. Do not widen this beyond those two model
families; it is not a general "Opus 5 or later" rule. Separately, prescriptive, hand-written
step-by-step chain-of-thought scaffolding is no longer a default on models with native thinking: "a
prompt like 'think thoroughly' often produces better reasoning than a hand-written step-by-step
plan," and a rigid numbered template can now narrow reasoning to something worse than the model
would produce unprompted. Manual step-by-step prompting with `<thinking>` and `<answer>` tags
remains a fallback only where thinking is off. `effort` (low, medium, high, xhigh, max) is the
primary dial for how much the model spends, thinking included, and is a behavioral signal rather
than a strict cap; effort level names do not carry the same amount of thinking across model
generations, so re-sweep effort against your own evals on every model upgrade rather than carrying
a prior setting forward.

**Output format control.** Prefilled assistant responses on the final turn are no longer supported
starting with Claude 4.6 models; a request that includes one returns an error rather than being
silently accepted. Replace prefill with: Structured Outputs or a tool with an enum field (for
forcing JSON or a classification), a direct instruction not to start with "Here is..." (for skipping
a preamble), an XML output tag, or a tool call. Current models are more direct and narrate less by
default; ask explicitly for a progress summary if that visibility is wanted back. Claude Opus 5 runs
longer by default than prior Opus models and effort does not reliably shorten it, so conciseness
needs its own explicit instruction. Mathematical notation defaults to LaTeX; say so explicitly, and
name the notation to avoid, if plain text is needed instead. A generic "avoid an AI-generated look"
instruction tends to swap one default aesthetic for another; name the specific patterns to avoid, or
ask the model to propose several distinct directions and pick one before building.

## Other vendors

A separate top-level instructions channel distinct from the conversation, structuring with XML tags
or Markdown headers, and putting critical instructions early with concrete examples all carry over
to OpenAI and Google models; all three vendors' own guidance recommends them. What does not carry:
Claude's `{{VARIABLE}}` placeholder syntax is not a cross-vendor standard; field-specific limits
(a custom GPT's instructions field caps at 8,000 characters in the ChatGPT builder UI) differ by
product; and default behavior a prompt relies on implicitly, such as output verbosity, differs
across vendors and even across model families from the same vendor. Model-specific tuning, a
particular generation's preferred phrasing, or a feature like an effort or thinking-budget
parameter, is the least portable of all and should not be assumed to transfer.

## Placeholders and templates

Mark a spot the recipient (or the tool they paste into) must fill in with a double-brace
`{{snake_case_name}}`, for example `{{annual_report}}`. Claude's docs show the same double-brace
form in uppercase; either case works, and this skill uses lowercase. The double-brace form is not a
cross-vendor standard, but it is worth following by default because it reads
unambiguously as "replace me" without colliding with another tool's own template syntax (Python's
`{variable}`, shell's `$VARIABLE`, a square-bracket `[VARIABLE]` style).

For a reusable template, document each placeholder once, after the prompt block, not inside it:

- **Name**, matching exactly what appears in the prompt.
- **What it is**, in one short phrase.
- **Whether it is required or optional**, and what happens if left blank.
- **An example value**, so the recipient sees the expected shape without guessing.

Call out two failure modes directly to the recipient: running the prompt with a placeholder still
unfilled (the model may ask for the missing value, or worse, treat the placeholder text itself as
input), and a placeholder name that collides with something the target tool already treats
specially.

## System prompts for chat products

**Claude Projects** separate project instructions (how Claude behaves: tone, role, perspective)
from the knowledge base (documents, text, or code Claude references for content). Say which one a
prompt is meant for.

**Custom GPTs** use an instructions field the same way, plus a separate knowledge upload and
capability toggles. The ChatGPT builder UI's instructions field caps at 8,000 characters; the API's
Assistants instructions field allows far more (256,000 characters), so a prompt written for the API
is not guaranteed to fit the builder UI unchanged.

**Gemini Gems** use a single instructions field. Google frames good Gem instructions around four
elements: persona (what role the Gem plays), task (what it should do), context (background it
needs), and format (how responses should be structured), recommending example output in the format
section. Not all four are required, but using several improves results.

State which field a delivered prompt is meant for explicitly ("this goes in the project
instructions, not a knowledge file"). A prompt pasted into the wrong field usually fails silently
rather than with an error.

## Improving an existing prompt

Diagnose against the same checklist an automated prompt-improvement pass uses: does it need a
dedicated section for the model to reason through the problem, a consistent structured format for
its examples, examples enriched with the same reasoning added to the main instructions, a clearer
wording pass, or a fix for a formatting problem. Leave out prefill as a fix; it is unsupported on
Claude 4.6 and later, so use a direct instruction or a structured output instead.

Two habits keep a hand-edited revision usable by someone else:

- **Preserve structure and placeholders where possible.** If the original had a clear shape or used
  `{{DOCUMENT}}`, keep it unless there is a real reason to change it. A revision that is hard to
  diff against the original is hard for the recipient to trust.
- **Explain the changes, briefly, next to the prompt, not inside it.** A short list of what changed
  and why (added an explicit output format, moved constraints earlier, removed a contradiction
  between two instructions) lets the recipient judge whether each change still fits their intent.

Do not silently drop content you disagree with. If part of the original seems wrong or
counterproductive, say so and explain the tradeoff, and let the recipient decide.

## Testing a reusable prompt

Decide success criteria before writing the prompt: specific, measurable, and achievable against a
baseline, across whatever dimensions actually apply (task fidelity, consistency, tone, privacy,
latency, cost). Only some dimensions apply to a given prompt; decide which ones do before drafting.

For a reused or shipped prompt, offer a baseline-then-prompt test, and never run it unasked:

1. **Baseline.** Run the task with no prompt, or the old prompt if revising one, in a fresh
   subagent with no access to the prompt being tested and no memory of earlier attempts, and record
   exactly what the model does and where it goes wrong. Without this step, you cannot tell whether
   a later fix addressed a real failure or changed behavior that was already fine.
2. **Write the prompt.** Address the specific failures the baseline surfaced, without padding in
   guidance for failures that were not actually observed. Re-run the same scenario and confirm it
   now succeeds.
3. **Close loopholes.** Re-run the scenario plus adjacent, harder variants: time pressure, a
   plausible-sounding exception, an instruction that conflicts with the prompt's rule. A new
   rationalization the model finds is a new failure to fix, not a sign the prompt is done.

Before offering to run this, a lighter no-run review still catches most mistakes: every success
criterion is answered by something in the prompt, no unfilled or unexplained placeholder remains,
no instruction quietly contradicts another, every paragraph earns its token cost, and the prompt
was not written only for the one case that happens to work. A test set that only covers the case
the prompt was written for proves almost nothing; deliberately include missing input, overly long
input, off-topic or harmful input, ambiguous cases with no single right answer, and surface
variation (typos, sarcasm, a rambling version of a simple question) that should not change the
answer.

## Sources

- docs/prompt-engineering/01-foundations-and-standards.md - anatomy of a prompt, vendor-agreed
  practices, technique status (few-shot, role, chain-of-thought, delimiters, chaining), and aged
  practices. Key sources cited: Anthropic prompting best practices
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices),
  OpenAI prompt engineering guide (https://developers.openai.com/api/docs/guides/prompt-engineering),
  Gemini prompting strategies (https://ai.google.dev/gemini-api/docs/prompting-strategies), The
  Prompt Report (https://arxiv.org/abs/2406.06608).
- docs/prompt-engineering/02-claude-specific-guidance.md - XML tags, examples, long documents,
  emphasis and negation, self-check and effort by model generation, output format control. Key
  sources cited: Anthropic prompting best practices
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices),
  Prompting Claude Opus 5
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5),
  Prompting Claude Opus 5.5
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5),
  Prompting Claude Sonnet 5
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5),
  Effort (https://platform.claude.com/docs/en/build-with-claude/effort).
- docs/prompt-engineering/03-prompts-for-people.md - placeholders and templates, chat-product
  system prompts, improving an existing prompt, portability across vendors, delivery format. Key
  sources cited: Anthropic prompting best practices
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices),
  What are projects? (https://support.claude.com/en/articles/9517075-what-are-projects), GPT
  Instructions Character Limit thread
  (https://community.openai.com/t/why-is-the-my-gpt-instructions-limited-by-8000-characters/1006936),
  Tips for creating custom Gems (https://support.google.com/gemini/answer/15235603?hl=en), Improve
  your prompts in the developer console (https://claude.com/blog/prompt-improver).
- docs/prompt-engineering/04-testing-and-evaluating-prompts.md - success criteria, the
  baseline-then-prompt test cycle, lightweight pre-handoff checks, and failure modes to test for.
  Key sources cited: Define success criteria and build evaluations
  (https://platform.claude.com/docs/en/test-and-evaluate/develop-tests), writing-skills SKILL.md
  (https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md), test-prompt
  SKILL.md
  (https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md).
