---
audience: human
created: 2026-09-25
updated: 2026-09-26
---

# Writing Prompts for People to Use Elsewhere

## What a delivered prompt needs

Writing a prompt for someone else to run is a different job from writing one you will run
yourself. You will not be in the room when it runs, so the prompt has to carry everything it
needs on its own:

- **The task and the target tool.** State what the prompt should produce and, if it matters,
  where it is meant to run: a specific chat product, an API call, a coding agent. A prompt that
  assumes tool use, file upload, or a particular model's extended-thinking behavior will fail
  silently in a tool that lacks it.
- **Every input it depends on**, either filled in or marked as a placeholder the person must
  replace before running it (see "Placeholders and reusable templates" below).
- **Instructions for the person, separate from instructions for the model.** A short note above
  or below the prompt block telling the recipient where to paste it and what to fill in is not
  part of the prompt; keep it visibly outside the block they will copy.
- **No context that only you have.** If the prompt only makes sense because of something said
  earlier in your conversation, that context has to be written into the prompt itself, or the
  recipient loses it the moment they paste the prompt somewhere else.

## Gathering missing information

Ask only for what the prompt cannot work without. A long intake questionnaire before writing a
single line is the wrong default: most of what a prompt needs can be inferred, given a sensible
default, or turned into a placeholder for the recipient to fill in themselves at run time rather
than a question for you to ask now.

A practical order:

1. Draft the prompt first, using placeholders for anything you do not know.
2. Look at what you had to placeholder. If a placeholder's value would materially change the
   prompt's structure or instructions, not just fill in a blank, that is worth asking about
   before you finish. If it is a value the recipient will supply differently each time they run
   the prompt (a document, a name, a date), leave it as a placeholder rather than asking.
3. Batch any real questions into one round, rather than a back and forth. If you have discrete
   choices (tone, output format, audience), a small set of options is easier for someone to
   answer than an open-ended question.

The distinction that matters is "information I need to write this prompt correctly" versus
"information the end user will provide when they run it." Only the first is worth interrupting
for; the second belongs in the template as a placeholder.

## Placeholders and reusable templates

A placeholder marks a spot in the prompt where the recipient (or the tool they paste it into)
must substitute a real value before the prompt runs. Anthropic's own documentation uses
double curly braces around an uppercase name, for example `{{ANNUAL_REPORT}}` or
`{{PATIENT_RECORDS}}`, to mark spots meant to be filled in with document content or user
input ([Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)).
That convention is worth following when you do not know which tool the prompt will end up in,
because `{{LIKE_THIS}}` reads unambiguously as "replace me" and will not be mistaken for
literal text or for a different tool's own template syntax (Python's `{variable}`, shell's
`$VARIABLE`, or a square-bracket `[VARIABLE]` style some prompt libraries use). The case of the
name does not matter to the model; the `prompt-author` skill uses lowercase `{{snake_case_name}}`.

For a reusable template, document each placeholder once, separate from the prompt block itself:

- **Name**, matching exactly what appears in the prompt.
- **What it is** in one short phrase.
- **Whether it is required or optional**, and what happens if it is left blank.
- **An example value**, so the recipient can see the expected shape (a sentence, a file name, a
  short list) without guessing.

Two failure modes are worth calling out to the recipient directly: running the prompt with a
placeholder still unfilled (the model will either ask for the missing value or, worse, treat the
placeholder text itself as the input), and a placeholder name that collides with something the
target tool already treats specially. Naming placeholders descriptively and consistently, and
listing them all in one place, is what keeps a template reusable instead of turning into a
one-off that only the original author can safely edit.

## System prompts for chat products

Chat products that support a persistent assistant (Claude Projects, custom GPTs, Gemini Gems)
all split configuration into at least two fields, and a prompt handed over for one of these
products needs to say which field it goes into.

**Claude Projects** separate project instructions from the project's knowledge base. Instructions
tailor how Claude behaves for the project (tone, role, perspective); the knowledge base is a
separate place to upload documents, text, or code that Claude references for context. The two do
different jobs: instructions say how to respond, the knowledge base supplies what to respond with
([What are projects?](https://support.claude.com/en/articles/9517075-what-are-projects), Claude
Help Center).

**Custom GPTs** use an instructions field the same way, plus a separate knowledge upload and a
set of capability toggles (web browsing, code execution, image generation). The instructions
field in the ChatGPT builder UI has a hard limit of 8,000 characters; OpenAI has not published
this limit in its help center, but its own developer community forum confirms it and notes the
API's Assistants instructions field allows far more (256,000 characters), so a prompt written for
the API is not guaranteed to fit the builder UI unchanged
([GPT Instructions Character Limit thread](https://community.openai.com/t/why-is-the-my-gpt-instructions-limited-by-8000-characters/1006936),
OpenAI Developer Community).

**Gemini Gems** use a single instructions field, and Google's own guidance frames good Gem
instructions around four elements: persona (what role the Gem plays), task (what it should do),
context (background the Gem needs), and format (how responses should be structured). Google
explicitly says you do not need all four, but using several improves results, and recommends
including example output in the format section
([Tips for creating custom Gems](https://support.google.com/gemini/answer/15235603?hl=en), Gemini
Apps Help).

The practical takeaway for handoff: know which field the prompt is meant for, and say so
explicitly when you deliver it ("this goes in the project instructions, not a knowledge file").
A well-written system prompt pasted into a knowledge-upload field, or vice versa, will not do
what the recipient expects, and the failure is often silent rather than an error message.

## Improving an existing prompt

When you are handed a prompt to fix rather than starting from a blank page, the same handoff
problem repeats in reverse: someone else has to read your changes and decide whether the result
still matches what they wanted.

Anthropic's own automated prompt improver, part of the Claude developer console, illustrates what
a systematic revision pass actually touches: it adds a dedicated section for the model to reason
through the problem before answering, converts examples into a consistent structured format,
enriches those examples with the same reasoning it added to the main instructions, rewrites for
clarity and fixes grammar, and can add a short prefill to steady the response's opening
([Improve your prompts in the developer console](https://claude.com/blog/prompt-improver), Claude
by Anthropic). That list is a reasonable checklist for a manual revision too: structure, examples,
reasoning steps, wording, and output formatting are the places a prompt usually has room to
improve. Leave out the prefill step for current Claude models: prefilled responses on the final
assistant turn are no longer supported from Claude 4.6 on, so use a direct instruction or a
structured output instead ([chapter 02](02-claude-specific-guidance.md)).

Two habits make a hand-edited revision usable by someone else:

- **Preserve structure and placeholders where you can.** If the original used `{{DOCUMENT}}` or
  had a clear three-part shape, keep that shape unless there is a real reason to change it. A
  revision that is hard to diff against the original is hard for the recipient to trust.
- **Explain the changes, briefly, next to the prompt, not inside it.** A short list of what
  changed and why (added an explicit output format, moved constraints earlier, removed a
  contradiction between two instructions) lets the recipient judge whether each change still
  fits their intent, rather than accepting a full rewrite on faith.

Do not silently drop content you disagree with. If part of the original prompt seems wrong or
counterproductive, say so and explain the tradeoff, and let the recipient decide whether to keep
it.

## Portability across vendors

Some structural choices carry across Claude, ChatGPT, and Gemini prompts. Others do not, and
assuming otherwise is a common way a prompt written for one product quietly breaks in another.

**What carries:**

- **A separate top-level instructions channel**, distinct from the conversation itself, exists in
  some form in all three: Claude's system prompt, OpenAI's `instructions` parameter (which "gives
  the model high-level instructions on how it should behave... and take priority over the input
  parameter"), and Gemini's system instructions field
  ([OpenAI prompt engineering guide](https://developers.openai.com/api/docs/guides/prompt-engineering);
  [Gemini prompting strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies)).
  A prompt that separates "how to behave" from "what to do this turn" transfers cleanly; one that
  blends the two into a single undifferentiated block does not.
- **XML tags and markdown headers as structuring devices.** All three vendors' own guidance
  recommends wrapping distinct parts of a prompt (context, task, examples, constraints) in tags
  or headers so the boundaries are unambiguous, and Google's guidance adds the specific caution
  to "choose one format and use it consistently within a single prompt" rather than mixing tag
  and header styles in the same prompt
  ([Gemini prompting strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies)).
- **Putting critical instructions early**, and giving concrete examples of desired input and
  output, both show up as advice across all three vendors' documentation.

**What does not carry:**

- **Placeholder syntax.** `{{VARIABLE}}` is Claude's documented convention; it is not a
  cross-vendor standard, and a template built for one tool's variable-substitution feature may
  not substitute at all in another.
- **Field-specific limits.** A custom GPT's instructions field caps at 8,000 characters in the
  ChatGPT builder UI; Claude Projects and Gemini Gems do not publish an equivalent hard number in
  the same way. A prompt that fits comfortably in one product's field can overflow another's.
- **Default behavior the prompt relies on implicitly.** Gemini's own guidance notes that models
  differ in default output verbosity and recommends "explicitly controlling output verbosity"
  rather than assuming a shared default
  ([Gemini prompting strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies)).
  The OpenAI guide separately notes that different model families in the same vendor's lineup
  already need different instruction styles, describing its reasoning models as needing only
  high-level guidance where its other models "benefit from very explicit, detailed instructions"
  ([OpenAI prompt engineering guide](https://developers.openai.com/api/docs/guides/prompt-engineering)).
  Model-specific tuning (a particular model generation's preferred phrasing, or a feature like an
  effort or thinking-budget parameter) is even less portable than that, and should not be
  assumed to transfer at all.

When you hand a prompt to someone whose target tool you do not know, state what the prompt
assumes (a specific product, a specific field, tool access, a particular model's behavior) so
they can adjust it rather than discover the mismatch by trial and error.

## Delivery format

However good the prompt is, it still has to survive being copied out of your response and pasted
somewhere else. A few habits make that reliable:

- **One prompt, one fenced code block.** Put the exact text the recipient should paste inside a
  single code block, with nothing else inside it. Commentary, instructions to the recipient, or
  an explanation of a placeholder does not belong inside the block; it goes in plain text before
  or after it, so a copy-paste of the block picks up only the prompt.
- **List placeholders separately, below the block.** Do not make the recipient hunt through prose
  to find out what `{{AUDIENCE}}` means; give a short list right after the block, in the format
  described under "Placeholders and reusable templates" above.
- **Say which field it goes into**, if the target is a chat product with more than one input
  (project instructions versus knowledge base, GPT instructions versus knowledge files, a Gem's
  single instructions box). One sentence is enough.
- **Keep punctuation plain.** Curly quotes, em dashes, or an ellipsis character introduced by a
  word processor or a rendering step can end up inside the pasted prompt and change how a
  literal-match instruction or a code-like placeholder reads. Plain ASCII punctuation pastes the
  same everywhere.
- **Do not assume the recipient will read your explanation before the prompt.** People skim
  straight to the code block. If a placeholder absolutely must be filled in before the prompt is
  safe to run, say so directly above the block, not three paragraphs into a surrounding
  explanation.

## References

- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) - Anthropic; source of the `{{VARIABLE}}` placeholder convention used in Claude's own prompt examples.
- [What are projects?](https://support.claude.com/en/articles/9517075-what-are-projects) - Claude Help Center; how project instructions and the knowledge base divide labor.
- [GPT Instructions Character Limit thread](https://community.openai.com/t/why-is-the-my-gpt-instructions-limited-by-8000-characters/1006936) - OpenAI Developer Community; confirms the 8,000-character cap on the custom GPT builder's instructions field, unpublished in OpenAI's own help center.
- [Tips for creating custom Gems](https://support.google.com/gemini/answer/15235603?hl=en) - Gemini Apps Help; the persona/task/context/format structure Google recommends for Gem instructions.
- [Improve your prompts in the developer console](https://claude.com/blog/prompt-improver) - Claude by Anthropic; what an automated prompt-improvement pass changes in an existing prompt.
- [OpenAI prompt engineering guide](https://developers.openai.com/api/docs/guides/prompt-engineering) - OpenAI; the `instructions` parameter, recommended prompt structure, and per-model-family instruction style differences.
- [Gemini prompting strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies) - Google; system instructions, structuring with tags versus headers, and default-verbosity differences to control for explicitly.
