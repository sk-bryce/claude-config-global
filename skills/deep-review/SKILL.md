---
name: deep-review
description: |
  This skill should be used when the user explicitly asks for a rigorous, critical, or
  adversarial review of code, a document, a plan, or an idea - e.g. "deep review",
  "rigorous review", "be critical", "is this a good idea", "does this belong here",
  "does this provide value", "is there a better way", "does this serve its purpose",
  "is this the best way to do this". Those phrases win even on a source file, a diff, or a
  change about to be committed: the depth wording decides, not the file type. Reviews whether
  something is worth doing at all: the problem it really solves, whether it is over-scoped or
  under-scoped, the alternatives (including doing nothing) it should be measured against, and
  the assumptions it rests on - closing with an explicit verdict. Bare "review the diff" is
  code-review; bare "review this" on a .md is review-md. Scope: any target.
model: opus
effort: high
---

<!--
created: 2026-09-04
updated: 2026-09-12
spec: specs/skills.md (deep-review section)
generated-by: skill-author
model: claude-opus-5
harness: Claude Code
-->

# Deep Review

Other reviews measure correctness, accuracy, and consistency; this asks premise-level questions
to assess whether something should exist at all, and if so, whether the current form is optimal,
and ends in a verdict. It applies to any target: code, a document, a plan, or a claim made in
conversation with nothing built yet.

## The questions

Five questions decide worth. Answer each by name. The sub-prompts under each are prompts, not
fields to fill: they turn a heading into an answer, and the answer stays a judgment.

1. **Value - is this actually useful?** What real problem does it solve, who has that problem,
   and is it observed or hypothetical? What happens today without it? Does the cost of the
   solution (complexity, maintenance, attention) exceed the cost of the problem?
2. **Fit - does this belong here?** Right layer, right owner, right time, right artifact - or does
   it belong in a sibling, upstream, or nowhere? Does something already do this? A good thing in
   the wrong place is still a problem, independent of how well it is executed.
3. **Alternatives - is there a better way?** Name them concretely, and name both kinds: a
   different thing (do nothing, the smaller version, fix the upstream cause, the existing tool)
   and the same thing done differently - is this the best way to do it? Say why the proposal beats
   the best of them. An alternative you cannot name is one you have not considered, and "none
   considered" is a finding, not a blank.
4. **Purpose-fit - does it serve its stated purpose?** Hold the artifact against the brief's
   Purpose field: does it deliver that need, part of it, or something adjacent? Then turn on the
   purpose itself: is the stated need still real and current, and is it the need behind the need
   or a proxy for it?
5. **Assumptions - what does it rest on?** List them and say whether each holds. Mark the
   load-bearing one: the assumption that, if wrong, sinks the whole thing rather than a detail.
   Say how one would know it had stopped holding.

Granularity serves the questions rather than replacing them:

- Consider all of the files/components of the review target both individually and holistically;
  deterministic prose logic that works holistically might still be better as a separate script.
- Cite specific lines, sections, or claims as evidence for a premise finding. "Looks fine
  overall" is not a finding.
- Trace second-order effects: what this breaks, complicates, or forecloses later.
- Precision over politeness. "This breaks when the input is empty" is a finding; "this could be
  more robust" is not.

## What to return

- **Every question answered by name, in the order above, before the verdict.** "No concern" is a
  legitimate answer and is stated as such. A question silently skipped is the failure this skill
  exists to prevent; a pass that returns only line-level findings has not run.
- **Premise findings first.** Execution-level findings (correctness, prose, style) appear only
  when they bear on the verdict. Otherwise leave them to the sibling reviews, or say in one line
  that they went unreviewed.
- **The verdict**, on one ladder for every target:
  **Proceed** / **Proceed with changes** / **Reconsider scope** / **Do not proceed**
  with a one-sentence reason. The verdict addresses worth, not only execution: flawless execution
  of a low-value thing gets "Reconsider scope". For a standing artifact that proposes nothing,
  "Proceed" means "keep as is" - say so explicitly. Lead with the call when the findings are long.
- **The strongest argument against the verdict**, one sentence, immediately after the call. This
  is the check on the ladder itself: any of the four calls can be produced without reasoning, and
  "Proceed with changes" is defensible about almost anything, but a genuine counter-argument
  cannot be written for a verdict that was never reasoned through.
- **Bounded.** Aim for 400-800 words per question and treat 1200 words per question as the
  ceiling; longer only where cited evidence needs the room. Present findings as a list, one or
  two sentences each, with further prose and supporting evidence following. The verdict
  paragraph should aim for roughly 3 sentences; do not exceed 5 unless necessary to convey the
  information. Use clear and concise language. A run that must cut drops the weakest finding
  before a question's answer, and never the counter-argument.

Say the uncomfortable thing plainly. A verdict hedged into meaninglessness is no verdict. The
reverse failure is as real: "no concern" on every question and a clean "Proceed" is a valid
outcome for a sound target, and manufacturing objections to justify the pass is the likelier
failure for a skill built to find fault.

## Resolve the target

`$ARGUMENTS`, when given, names the target. With no argument, take the most recent artifact or
claim in the conversation. A named file, a diff, an artifact just produced, an unbuilt idea, or a
claim someone made all qualify; there is no file-type gate. If it is genuinely ambiguous which is
meant, ask rather than guess - a premise review aimed at the wrong target wastes the whole pass,
and the confirm branch and the brief below both depend on the target being the right one.

## Confirm before spending the pass

If the resolved target looks trivial or low-stakes - a one-line value, a variable name, a passing
remark - ask once whether to spend the full pass. Ask before writing the brief, so the cheap path
stays cheap. Stakes and reversibility decide this, not size and not whether an artifact exists: a
one-line config change with a wide blast radius earns the full pass, and an in-conversation idea
with nothing built is among the highest-value targets there is, because changing course is still
cheap.

Use `AskUserQuestion`; where no interactive question tool is available, ask in plain text. Never
silently pick a mode on the user's behalf. **Asking means the turn ends there:** put the question,
then stop. Do not dispatch and do not review while it is unanswered. Two shapes are excluded by
name:

- **Narrating the question is not asking it.** "Normally I would ask whether you want the full
  pass" followed by continuing is the silent mode-pick this gate exists to prevent. Address the
  question to the user, in the present tense, as the last thing in the turn.
- **Answering it yourself is not waiting.** Asking and then supplying your own answer in the same
  reply ("assuming you want the quick take") is the excluded behaviour, not a compromise.

A belief that no reply can reach you does not resolve the gate. From inside, a run that cannot be
answered looks the same as one whose answer has not arrived yet; ask anyway and stop anyway. An
answer that arrives ambiguous means run the full pass: fail toward rigor. If the user declines,
answer briefly inline - declining gets a short real answer, not silence.

## Write the context brief

The dispatched pass can see nothing but the artifact and this brief, so the brief decides which
defects get found. Four required fields:

- **Purpose** - why this thing exists and what goal it serves
- **Alternatives already rejected** - and why. "None considered yet" is a complete answer, and
  often the reason the review is worth running.
- **Constraints** - what the target has to live within
- **Prior findings** - what is already known, so the pass does not re-derive it

**Each field is evidence, not a summary.** Fill it with verbatim quotes, each tagged with its
source: the user's message, a line from earlier in the conversation, a README sentence, a
ticket, a commit body. Quote the words as written and name where they came from. A one-line
gloss may follow a quote; it never replaces one. The reviewer does the synthesis: it runs at the
higher tier and can see what you quoted, and it cannot recover what you left out of a
paraphrase. A field with no quotable source and no "nothing" answer is unfilled, however much
you have read. Quoting is also what makes the shown brief checkable: a quoted line that
describes behaviour is visible for what it is, where a synthesized sentence with "(from
README.md)" attached is not.

Fill every field you can from the target, the conversation, and the repository before asking the
user for anything. A field you can answer yourself is not a field the user owes you.

**With no conversation behind the target, Purpose comes from the user or from a quoted source
that states the need, never from the artifact.** When the invocation is the first message of
the session, or the target arrived as a bare path with no prior discussion, one pass over the
surrounding files may fill Alternatives, Constraints, and Prior findings and may turn up a
sentence that states the need; quote it and proceed. If it does not, put one `AskUserQuestion`
call carrying all four fields (plain text where the tool is unavailable), give the preliminary
read described below, and end the turn. The confirm gate's rules on asking apply here
unchanged: the question is the last thing in the turn, and you do not answer it yourself. The
user's answers are quoted in verbatim, including "I don't know", which fills the field.

**A field whose answer is unknown blocks the dispatch. A field whose answer is "nothing" does
not.** Telling those two states apart is the whole of this gate. "No alternatives have been
considered yet" is information the pass needs; "I cannot tell what was considered" is the absence
of it. Only the second stops you.

**Purpose is what someone needed the thing to do, not what it does.** You can always read the
artifact and say what it does, and that is never Purpose, however accurate. Purpose is why the
thing exists, what depends on it, and what would break without it - facts about the world around
the artifact, which the artifact cannot supply. When its contents are the only evidence you have,
Purpose is unfilled, whatever the target is.

**The Purpose quote must state the need.** It must say, in some wording, why the thing exists,
what depends on it, or what would break without it. The test is what the quoted sentence says,
not which source it came from: a prompt, a README, a ticket, a design doc, or a commit message
can each state a need, and none fills Purpose by existing. A quote that describes what the
artifact does leaves Purpose unfilled, however accurately it is sourced.

Three shapes are excluded by name:

- **Restating behaviour is not filling Purpose.** "This script rotates the log files and deletes
  the old ones" describes the code correctly and answers nothing. A flat, accurate summary fails
  exactly as a hedge does, and is harder to catch because it does not sound like a guess. A
  README that explains what the artifact does, how to invoke it, and when it runs is still
  behaviour. A trailing goal clause does not rescue it: "syncs the table so the data stays
  current" restates the operation rather than naming who needed it current or what goes wrong
  when it is not.
- **Guessing from the artifact's shape is not filling Purpose.** "Presumably to send the nightly
  digest" restates the filename. Hedge words are a symptom; their absence proves nothing.
- **Proceeding with a caveat is not stopping.** A verdict with a note about limited context is
  the excluded behaviour, not a compromise. There is no version of this pass that emits a
  verdict on an incomplete brief.

If you find yourself reasoning that some specific target is the one these rules were written
about, that is the failure, not an exemption. This gate is prose, judged by you, and it has
failed quietly in several shapes; assume the next failure is a shape not listed here.

**When a field is genuinely unknown, name that field and stop.** Stop means: do not dispatch and
do not state a verdict. It does not mean go silent - give what the artifact alone supports,
labelled preliminary and explicitly not the verdict, then ask for the missing field. **When the
user, asked, cannot state the need either, that answer fills the field.** Purpose becomes "no one
can state why this exists", the pass proceeds, and that is its lead finding and usually its
verdict. The unknown state is "I have not been told", not "there is nothing to tell"; the second
is the question this skill was built to ask.

**Show the brief before dispatching.** Print the four fields, labelled, then dispatch in the same
turn. This is a display step, not a second confirmation gate; do not wait unless the user objects.
A verdict reasoned soundly from a mis-stated premise reads exactly like a sound one, and phase 3
reproduces it verbatim, so the shown brief is the only place that error is catchable.

## Dispatch

Three phases: (1) inline, resolve the target and write the brief; (2) run the questions against
artifact plus brief and return findings and a verdict; (3) inline, present the findings and field
the follow-ups a subagent could not be asked mid-run.

Phase 2 runs inline when the session is already at Opus. Otherwise dispatch **exactly one fresh**
subagent with the `Agent` tool: `subagent_type: "general-purpose"`, `model: opus`,
`run_in_background: false`, never `subagent_type: "fork"`. The subagent sees nothing but the
prompt, so the prompt carries all six: the four-field brief, quotes and sources intact; the
target's identity **and** its content (a claim made in conversation is quoted in); the questions
and granularity rules inlined verbatim; a validation step that runs first, with the need test
from the brief section inlined: check each Purpose quote against it, and if none states a need,
return `Brief invalid: Purpose` with one sentence saying why, answer none of the questions, and
give no verdict; the output instruction (every question by name, premise findings first, the
four-term ladder, the reason, the counter-argument, and the output bound); and `ultrathink` plus
an instruction to batch independent tool calls. `references/dispatch.md` gives the reason behind
each parameter and what fails quietly when one is dropped; read it before changing any of them.

## Present

**Phase 3 reproduces the dispatched verdict verbatim.** Carry the ladder term, its one-sentence
reason, and the counter-argument through exactly as returned. Do not paraphrase, soften, or
restructure it into a menu of options: a list of choices is not a verdict, and replacing the call
with one silently removes the single output this skill exists to force. Frame it if that helps
the reader; do not substitute framing for the call.

A returned `Brief invalid` is not a verdict. Present it as a stop, name the field, and go back to
the brief. Inline at Opus there is no second judge; apply the need test yourself before
proceeding.

## Neighbouring passes

If another review pass is already running, do not re-litigate the mechanics it owns: prose nits,
link checks, lint, formatting. Premise, scope, alternatives, purpose-fit, and assumptions are this
one's. That sentence does not create a companion pass: **when the target is document-heavy, run
`review-md` as well**, or tell the user plainly that the mechanical layer went unchecked. A deep
pass told that mechanics belong to someone else, while no one else is running, misses what a
`review-md` pass over the same target catches.
