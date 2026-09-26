---
audience: human
created: 2026-09-25
updated: 2026-09-26
---

# Testing and Evaluating Prompts

## Success criteria first

Decide what "works" means before writing the prompt, not after. Anthropic's own test-and-evaluate
guidance frames this as a cycle: define success criteria, build evaluations against them, then
write and iterate on the prompt, in that order
([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).
Skipping straight to writing means you find out what "good" meant only after you have already
committed to a draft, which makes every later revision a guess rather than a measurement.

Good criteria follow a few checks:

- **Specific.** "Good performance" is not a criterion. "Correctly classifies sentiment" is closer;
  a target number attached to a defined test set is closer still.
- **Measurable.** Turn even fuzzy goals into a number or a defined scale where possible. A safety
  goal like "not toxic" can become "fewer than 0.1% of outputs across 10,000 trials flagged for
  toxicity" ([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).
- **Achievable and relevant.** Base a target on a prior baseline or a comparable published result,
  and make sure the criterion matters for how the prompt will actually be used; citation accuracy
  is critical for a medical summarizer and beside the point for a casual chatbot
  ([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).

A single prompt usually needs criteria across more than one dimension, not just "does it get the
task right." Anthropic's guidance names task fidelity, consistency across similar inputs,
relevance and coherence, tone and style, privacy preservation, how well the prompt uses supplied
context, latency, and cost as the recurring dimensions worth setting a target for
([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).
Most of these do not need a console or a script to check; they need a decision, made before
drafting, about which of them actually apply to this prompt and what "acceptable" looks like for
each one. A prompt with no cost or latency constraint does not need a criterion for either; a
prompt handling any personal or sensitive information almost always needs one for privacy.

Write the criteria down somewhere they will survive the editing process: a line above the prompt
draft, a comment in the file, or the top of the test log described below. A criterion that exists
only in your head at draft time is not available to check the fifth revision against.

## Test-first prompt writing

Writing the prompt before checking what happens without it skips the one piece of evidence that
tells you whether the prompt is even solving the right problem. Two independently published
skills for testing agent-facing prompts converge on the same three-phase cycle, borrowed directly
from test-driven development's red-green-refactor loop:

1. **Baseline (red).** Run the task or scenario with no prompt, or with the old prompt if you are
   revising one, and record exactly what the model does: the actions taken, the reasoning given,
   and where it goes wrong. The `writing-skills` skill states the rule plainly: "If you didn't
   watch an agent fail without the skill, you don't know if the skill teaches the right thing"
   ([writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md),
   obra/superpowers). The `test-prompt` skill states the same principle for prompts generally:
   "If you didn't watch an agent fail without the prompt, you don't know what the prompt needs to
   fix" ([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md),
   NeoLabHQ/context-engineering-kit). Skipping this step means any later improvement is unverified:
   you cannot tell whether the prompt fixed a real failure or just changed behavior that was
   already fine.
2. **Write the prompt (green).** Address the specific failures the baseline surfaced. Both skills
   warn against padding the prompt with guidance for failures you did not actually observe: write
   the minimal prompt that addresses the documented gap, then check that the same scenario now
   succeeds. `writing-skills` frames this as addressing "those specific rationalizations" and not
   adding "extra content for hypothetical cases"
   ([writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md)).
   `test-prompt` says the same in its own words: "Write prompt addressing the specific baseline failures you documented."
   ([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)).
3. **Close loopholes (refactor).** Re-run the scenario, and try adjacent scenarios and pressure
   variants: time pressure, a shortcut that looks reasonable, an instruction that conflicts with
   the prompt's rule. If the model finds a new way around the prompt's intent, that is a new
   failure to fix, not a sign the prompt is done. `writing-skills` puts it as: "Agent found new
   rationalization? Add explicit counter. Re-test until bulletproof."
   ([writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md)).

`test-prompt` also recommends running the baseline and the with-prompt test in a fresh subagent
each time, with no access to the prompt being tested and no memory of earlier attempts, because a
model that already saw the correct answer in conversation history is not testing the prompt
anymore; it is testing whether the model remembers the earlier turn
([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)).
The same isolation matters even without a subagent tool available: a fresh chat, a new session, or
at minimum a re-read of the prompt as if seeing it for the first time, keeps the test honest.

This maps directly onto the success criteria from the section above: the baseline tells you which
criteria the unaided model already meets (skip those, or note them as a regression risk to watch
for) and which it fails (those are what the prompt has to earn). Without a baseline, a prompt that
"works" on the first try is indistinguishable from a prompt that never mattered.

## Lightweight checks before handoff

A full test-first pass with a fresh subagent is not always available or worth the time for a
one-off prompt. The checks below cost only a re-read of the prompt you already wrote, no run
required, and catch the mistakes that a quick review reliably finds.

- **Every success criterion from the first section is answered by something in the prompt.** If a
  criterion needs a defined output format, the prompt states one; if it needs a tone, the prompt
  says so explicitly rather than assuming the model will infer it. A criterion with nothing in the
  prompt addressing it is a gap, not a criterion the prompt happens to satisfy anyway.
- **No unfilled or unexplained placeholder remains.** Every `{{PLACEHOLDER}}` or bracketed blank
  either has a real value or is documented for the recipient, per the placeholder discipline
  covered in the companion chapter on writing prompts for other people.
- **No contradictory instructions.** Read the prompt looking specifically for one instruction that
  quietly undercuts another (an early "always cite sources" next to a later "keep responses under
  two sentences" with no guidance on which wins). Contradictions are also the top cause of a
  prompt failing under pressure once real ambiguity forces a choice between two rules.
- **Every paragraph earns its place.** The `test-prompt` skill's refactor step for closing out a
  testing pass applies just as well as a solo review: "Challenge each paragraph: Does this justify
  its token cost?" ([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)).
  A paragraph that restates something already covered, or hedges an instruction that should be
  direct, is worth cutting even without a test run to prove it is safe to cut.
- **The prompt was not written only for the case that happens to work.** `test-prompt`'s list of
  common mistakes calls out "weak test cases" - "academic scenarios where agent has no reason to
  fail" - as a way testing can look successful while proving nothing
  ([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)).
  The same question works as a static check: does this prompt only make sense for the one example
  in your head, or would it hold up against a slightly different, slightly harder version of the
  same task?
- **If you ran even one baseline-versus-prompt comparison, the specific failure it caught is
  actually addressed**, not just plausibly addressed. `test-prompt`'s green-phase success
  criteria - "Agent follows prompt instructions," "Baseline failures no longer occur"
  ([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)) -
  double as a checklist for re-reading a single transcript, not just for running a new one.
- **The failure modes in the next section have each been considered**, even if not every one
  applies. A quick mental pass through the list below costs nothing and catches the omissions a
  single successful run would not surface.

None of this replaces running the prompt. It is the floor: the minimum a prompt should clear
before it is handed to someone else or reused, on the assumption that a real test pass may not
happen before that first use.

## Eval tooling

A prompt that will run once does not need tooling; the checks above and a manual baseline
comparison cover it. A prompt that will be reused across many inputs, shipped to other people, or
revised repeatedly benefits from a tool that runs a fixed test set automatically every time the
prompt changes, so a revision that fixes one case cannot silently break another without anyone
noticing.

**Anthropic's developer console** has a built-in Evaluation tool for exactly this. It builds a
test suite from cases you add by hand, generate with a "Generate Test Case" feature, or import
from a CSV; runs the full suite against the prompt in one click; and lets you compare two or more
prompt versions side by side. Quality grading is a manual 5-point scale filled in by a subject
matter expert, not an automated grader, which keeps the judgment human while automating the
running and comparison ([Evaluate prompts in the developer console](https://claude.com/blog/evaluate-prompts),
Claude by Anthropic). This suits prompts still being iterated on inside the console, where you
want a fast side-by-side after every edit.

For programmatic, code-based evaluation, Anthropic's own test-and-evaluate guidance walks through
building graders directly against the API: exact-match and other deterministic checks for
categorical tasks, embedding-based similarity scores for consistency, ROUGE-L for summary quality,
and model-graded checks (a separate call to a model, asked to output a Likert score, a binary
yes/no, or an ordinal rating against a defined rubric) for qualities like tone or privacy
preservation that resist a hard-coded check. It recommends using a different model to grade than
the one being evaluated, and keeping the grading prompt's output format narrow ("output only the
number") so it parses reliably
([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).
The same guidance favors volume over hand-curated quality: "more questions with slightly lower
signal automated grading is better than fewer questions with high-quality human hand-graded
evals" ([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).

**promptfoo** is an open-source CLI and library built around the same idea, vendor-neutral: a
config file lists one or more prompts, one or more providers (OpenAI, Anthropic, Google, and
others), and a set of test cases with variables to substitute in. Each test case can carry
assertions, which are optional; promptfoo supports both deterministic assertion types (`equals`,
`contains`, `contains-json`, a custom JavaScript check) and model-graded types (`llm-rubric` for a
free-text rubric judged by an LLM, `similar` for embedding-based semantic closeness)
([Promptfoo configuration guide](https://www.promptfoo.dev/docs/configuration/guide/)). Running the
suite produces a side-by-side comparison matrix across every prompt-and-provider combination,
which makes it a reasonable choice when a prompt needs to be tested against more than one model or
compared against a previous version as a regression check, and when the prompt is reused outside
any single vendor's own console
([Promptfoo introduction](https://www.promptfoo.dev/docs/intro/)).

**OpenAI's evals framework** takes a comparable shape inside its own platform: a data source
(a JSON Schema describing the test inputs and, usually, a human-labeled expected output) paired
with a grader (a `string_check` for exact or substring matching, or a model-graded criterion) run
across a JSONL file of test cases, with results reviewed through a dashboard or API. OpenAI frames
the same three-step loop as the others: describe the task as an eval, test it against
representative data with ground-truth labels, then analyze results and iterate on the prompt
([OpenAI evals guide](https://developers.openai.com/api/docs/guides/evals)).

The common shape across all three - Anthropic's console tool, Anthropic's code-based grading
guidance, promptfoo, and OpenAI's evals - is the same regardless of vendor: a fixed set of test
cases, a way to grade each output (deterministic where possible, model-graded where the criterion
is subjective), and a way to compare a prompt's current version against its previous version or
against another candidate. Pick console tooling for fast iteration inside one vendor's product,
and promptfoo or a hand-rolled script for a prompt that needs to run the same suite across
providers or live in version control alongside its test cases.

None of this is worth setting up for a prompt used once. It earns its cost when the prompt will be
revised more than a couple of times, when more than one person depends on it staying correct, or
when the cost of a silent regression (a customer-facing prompt, a prompt gating a decision) is
higher than the setup cost of a test suite.

## Failure modes to test for

A test set that only covers the case the prompt was written for will pass on the first try and
prove almost nothing. Anthropic's guidance on developing test cases is explicit that the goal is
to "mirror your real-world task distribution and include edge cases," and names several categories
worth deliberately including rather than leaving to chance:

- **Irrelevant or nonexistent input data.** What does the prompt do when the thing it expects
  (a document, a value, a prior answer) is missing or does not apply?
- **Overly long input.** A wall of text, or far more input than the prompt's examples showed, can
  cause the model to lose track of an instruction stated once at the top.
- **Poor, harmful, or off-topic user input**, for a prompt that will sit in front of a real user
  rather than a controlled pipeline.
- **Ambiguous cases where even a human reader would disagree on the right answer.** These do not
  have a single correct output to grade against, but they reveal whether the prompt at least
  produces a defensible, consistent choice rather than an arbitrary one.
- **Surface variation that should not change the answer**: sarcasm in a sentiment task, typos and
  misspellings, multiple topics mixed into one input, or a long, rambling version of an otherwise
  simple question
  ([Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)).

Beyond input variety, the test-first methodology in the earlier section points at a second
category: failures that only appear under pressure, not under a neutral request. The `test-prompt`
skill designs scenarios specifically to surface these for prompts meant to enforce a rule or a
process, combining "multiple pressures (time, cost, authority, exhaustion)" in one scenario and
capturing the model's rationalization for cutting a corner verbatim
([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)).
A prompt that holds up when politely asked to follow a rule and folds the moment a deadline or an
authority figure enters the scenario has a real gap that a plain functional test would never find.
Worth testing directly:

- **Time or urgency pressure** ("this is due in five minutes") pushing the model to skip a step
  the prompt requires.
- **A plausible-sounding exception** the model talks itself into ("the spirit of the rule is
  satisfied even if I skip this part").
- **Conflicting instructions**, either two lines within the prompt that pull in different
  directions, or a user request that directly contradicts something the prompt says to always or
  never do.
- **An instruction the model already knows how to do well without help**, to check the prompt is
  not solving a problem that did not exist; if the unaided baseline already succeeds, the prompt
  should not be credited for that case.

A third category sits underneath both of the above: the criteria set out at the start of this
chapter, checked one at a time rather than only as a pass/fail on the main task. A prompt can get
the core answer right and still fail on consistency (two near-identical inputs producing
noticeably different outputs), on privacy (repeating back sensitive input it should have redacted
or ignored), on tone (technically correct but wrong register for the audience), or on cost and
latency if those were ever a stated constraint. None of these show up in a test built only around
"did it get the right answer," which is exactly why they need their own line in the test set
rather than an assumption that the main-task tests cover them.

Finally, watch for a failure in the testing process itself. `test-prompt` lists weak test design as
its own common mistake: "academic scenarios where agent has no reason to fail," and testing with
conversation history still present so "accumulated context affects behavior" and the prompt's
effect cannot be isolated
([test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md)).
A test suite that never fails anything is worth treating with suspicion, not confidence.

## References

- [Define success criteria and build evaluations](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests) - Anthropic; the SMART framework for prompt success criteria, the eight recurring evaluation dimensions, edge-case categories to test for, and grading methods (deterministic and model-graded).
- [Evaluate prompts in the developer console](https://claude.com/blog/evaluate-prompts) - Claude by Anthropic; how the console's Evaluation tool builds and runs test suites and grades quality.
- [writing-skills SKILL.md](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md) - obra/superpowers; source of the red-green-refactor cycle applied to writing agent instructions and the baseline-first principle.
- [test-prompt SKILL.md](https://github.com/NeoLabHQ/context-engineering-kit/blob/master/plugins/customaize-agent/skills/test-prompt/SKILL.md) - NeoLabHQ/context-engineering-kit; the same red-green-refactor cycle applied specifically to prompts, its testing checklist, pressure-scenario design, and common testing mistakes.
- [Promptfoo introduction](https://www.promptfoo.dev/docs/intro/) - Promptfoo; what the tool does and its core build-test-compare-iterate workflow.
- [Promptfoo configuration guide](https://www.promptfoo.dev/docs/configuration/guide/) - Promptfoo; config file structure (prompts, providers, tests) and deterministic versus model-graded assertion types.
- [OpenAI evals guide](https://developers.openai.com/api/docs/guides/evals) - OpenAI; data source and grader structure for an eval, and the describe-test-iterate loop.
