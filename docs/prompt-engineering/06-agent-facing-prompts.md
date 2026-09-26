---
audience: human
created: 2026-09-26
updated: 2026-09-26
---

# Agent-Facing Prompts

## Where agent-facing prompts differ

Chapter 3 covers prompts a person carries into a chat product. This chapter covers prompts one
agent writes for another: a subagent dispatch, a handoff to a fresh session, a system prompt for
an agent definition, or the loop instructions for a background agent. The anatomy from
[chapter 01](01-foundations-and-standards.md) still applies (task, context, constraints, output
format), but three properties of the receiving end change what the prompt must do.

First, there is no chance to ask a clarifying question. A person reading a vague prompt can reply
"what do you mean by that"; a dispatched subagent cannot. Cursor's pstack orchestration playbook
states this as the reason the brief has to be complete on arrival: "a vague brief fails quietly,
because a worker cannot ask you a question" (see [the dispatch brief](#the-dispatch-brief) below).
Claude Code's own subagents documentation confirms this is a hard constraint, not a style
preference: `AskUserQuestion` is on the list of tools withheld from every non-fork subagent
regardless of its configured tool access; a fork keeps the main conversation's tool pool, so it
keeps `AskUserQuestion` too (Claude Code subagents documentation, checked 2026-09-25).

Second, most receiving agents start cold. A non-fork subagent gets a fresh, isolated context: it
does not see the dispatching conversation's history, its previously invoked skills, or files it
already read. Its startup context is limited to its own system prompt, the delegation message,
the project's `CLAUDE.md` hierarchy (unless suppressed), preloaded skills named in its own
frontmatter, and a git status snapshot (Claude Code subagents documentation, checked 2026-09-25).
Everything else the task needs has to arrive in the dispatch prompt itself, explicitly. A fork is
the one exception: it inherits the parent conversation's full context, system prompt, and tool
pool, which changes what a fork's dispatch prompt needs to restate (see
[the dispatch brief](#the-dispatch-brief)).

Third, the output is not read by a person; it is consumed by another agent's context window, and
often feeds a decision that agent makes next. A report that is padded, hedged, or missing the one
number the caller needs costs that caller a full extra round trip to extract it. Superpowers'
subagent-dispatch skill names the common failure modes on the input side directly: prompts that
are "too broad," carry "no context," specify "no constraints," and ask for "vague output"
(`skills/dispatching-parallel-agents/SKILL.md`, obra/superpowers repository, checked 2026-09-25).
The rest of this chapter works through what closes each of those gaps: a template for the dispatch
itself, what a handoff or continuation prompt needs that a first dispatch does not, how a system
prompt differs from a one-shot brief, and how to size and test all of the above.

## The dispatch brief

A dispatch brief is the prompt that hands a bounded unit of work to a subagent or a parallel
fork. Cursor's pstack orchestration playbook puts the stakes plainly: "Your prompts to agents are
your only product" - the dispatching agent's entire influence over the outcome is what it writes
in that one message (`pstack/skills/poteto-mode/playbooks/orchestrate.md`, cursor/plugins
repository, checked 2026-09-25). The same source gives a template of nine fields:

- **GOAL**: one sentence, written so a stranger with no access to the chat that produced it could
  execute it.
- **SCOPE**: the paths the agent may and may not write to.
- **CONTEXT**: pointers to what it needs (file paths, prior findings), with any upstream report
  pasted in full rather than referenced, since a subagent cannot fetch back through a
  conversation it never saw.
- **ACCEPTANCE**: checkable conditions, one per line.
- **VERIFY**: the exact commands that check those conditions.
- **TIMEBOX**: how much work is reasonable before it should stop and report back.
- **FORBIDDEN**: actions explicitly off-limits (a broader version of SCOPE, for things like
  running git commands or installing dependencies).
- **REPORT**: the shape of what should come back.
- **STANDING**: constraints that apply across the whole dispatch, not just this one unit.

The same source frames the diagnostic use of the template, not just its fields: "A field you
cannot fill is a unit you have not scoped yet." If GOAL cannot be written as one executable
sentence, or VERIFY cannot name a command, the task is still too vague to dispatch - narrow it
before sending it, rather than sending it vague and hoping the subagent narrows it for you.

This matches superpowers' independently-stated framing of what a good agent prompt looks like:
"focused, self-contained, and specific about output," against the common failure modes named in
[Where agent-facing prompts differ](#where-agent-facing-prompts-differ) above
(`skills/dispatching-parallel-agents/SKILL.md`, obra/superpowers repository, checked 2026-09-25).
Focused maps to GOAL and SCOPE; self-contained maps to CONTEXT; specific about output maps to
ACCEPTANCE, VERIFY, and REPORT.

Not every unit needs all nine fields spelled out with headers. See
[Sizing the prompt to the task](#sizing-the-prompt-to-the-task) for how the same template
compresses for small units without dropping the substance behind each field.

A fork's dispatch prompt can skip more of the template than a non-fork subagent's can: a fork
already holds the parent conversation's full context, so its brief can leave out CONTEXT the
parent already has. It still needs GOAL, SCOPE, VERIFY, and REPORT, the same as any other dispatch.

## Handoff and continuation prompts

A dispatch brief starts a unit of work; a handoff or continuation prompt restarts one, either
because the receiving side is a genuinely fresh session (no shared memory at all) or because a
running one is being resumed after it stopped. The two cases need different things.

**Handoff to a fresh session.** Nothing survives except what is written down. Matt Pocock's
`claude-handoff` skill states the two rules that follow from that: reference existing artifacts
by path instead of duplicating their content in the handoff prompt itself, and redact secrets,
because "the summary becomes a prompt" that something else will read and potentially act on
(`skills/in-progress/claude-handoff/SKILL.md`, mattpocock/skills repository, checked 2026-09-25).
The same skill recommends a suggested-skills section, naming which of the receiving agent's
available skills are likely relevant to the handed-off work, since the fresh session has no way to
infer that from history it never had. This is the same self-contained requirement from
[the dispatch brief](#the-dispatch-brief) applied to a whole session's accumulated state rather
than to one unit of work - the state just happens to be larger, so pointers matter more and
verbatim pasting matters less.

**Resuming a finished subagent.** This is a different mechanism from a fresh handoff. Claude
Code's `SendMessage` tool resumes a subagent that has finished or, once its stopped run has exited,
one that was stopped - not the built-in Explore or Plan agents, which are one-shot and cannot be
resumed. The resumed subagent receives its full prior conversation history and tool results and
picks up exactly where it stopped, with no restart (Claude Code subagents documentation, checked
2026-09-25). A continuation message here can be short, because the missing piece is not context -
the subagent still has it - but instruction: what changed, and what to do next. Padding it with a
restatement of context the subagent already holds wastes the same tokens a redundant CLAUDE.md
restatement would waste in a person-facing prompt.

**Continuation across a session that will restart cold.** Between those two cases sits a task that
spans more context windows than one session can hold, where the next window will not inherit
anything automatically. Anthropic's prompting guidance for long-horizon work gives concrete
mechanics for this: track structured state (test status, task lists) in a machine-readable file
such as `tests.json`, keep freeform progress notes in a plain file such as `progress.txt`, and use
git commits as checkpoints the next window can inspect. It recommends being prescriptive about how
the fresh window should start - "Call pwd; you can only read and write files in this directory,"
"Review progress.txt, tests.json, and the git logs" - rather than assuming it will discover the
right starting point on its own (Claude prompting best practices, "Workflows across multiple
context windows," checked 2026-09-25). The same source flags a real choice, not a default: for
long tasks it may work better to start the new window fresh from these files than to rely on the
harness's own compaction: Claude's latest models are extremely effective at discovering state from
the local filesystem, and the guidance suggests taking advantage of that over compaction in some
cases.

Across all three variants, the load-bearing test is the same one from
[Where agent-facing prompts differ](#where-agent-facing-prompts-differ): could the receiving
agent execute this with zero ability to ask a follow-up. If the handoff prompt depends on the
receiving agent inferring something the departing one knew but did not write down, it will fail
quietly, on some later turn, in a way that is hard to trace back to the handoff.

## System prompts for agent definitions

A dispatch brief and a handoff prompt are each written once, for one unit of work. A system
prompt for an agent definition is written once and read many times, by every future invocation of
that agent, on tasks its author cannot fully predict. That reuse changes what belongs in it: a
dispatch brief's CONTEXT field names specific paths and specific findings; a system prompt instead
names the class of task the agent handles and the process it should follow on any instance of that
class.

In Claude Code, a subagent's system prompt is the markdown body of its definition file, after the
YAML frontmatter. That prompt is what the subagent receives at startup, together with environment
details the harness appends - it does not also receive Claude Code's own default system prompt,
so nothing from that default (persona, general tool conventions) can be assumed present unless
the agent's own prompt restates it (Claude Code subagents documentation, checked 2026-09-25).

Anthropic's `plugin-dev` plugin documents four recurring patterns for what that body should say,
by agent role (`references/system-prompt-design.md`,
anthropics/claude-plugins-official repository, checked 2026-09-25):

- **Analysis agents** examine code, documentation, or output for specific issues, and should
  report findings by severity with concrete locators (file and line), not a general impression.
- **Generation agents** produce code, tests, or documentation, and benefit from an explicit
  process: understand requirements, gather context, design structure, generate content, validate,
  document.
- **Validation agents** check output against stated criteria and return a clear pass or fail,
  organized by violation type and severity.
- **Orchestration agents** coordinate a multi-step workflow across tools and dependencies,
  managing phases in sequence and handling failures gracefully rather than assuming every step
  succeeds.

The same source names the pitfalls that erase these patterns' value. A vague responsibility
statement such as "help the user with their code" gives the model nothing to act on; state what to
check instead, such as "identify missing type annotations and improper use of `any`." Missing
process steps have the same effect: "analyze the code" is not a process, but "read files, scan for
the named patterns, verify requirements, list findings with file references" is. Undefined output
formats create a matching failure on the way out. The source's own pitfall is narrower: the agent
does not know what format to use. Worth adding as this chapter's own inference, not the source's:
without a template for section headers and result categories, the same agent tends to format its
findings differently run to run, which can break a caller that parses the result programmatically.
The plugin's own quality bar for a system prompt is that it be specific, structured, complete for
both normal and edge cases, actionable, and testable.

This is also where the orchestrator-workers pattern from Anthropic's "Building effective agents"
post applies most directly: an orchestrating agent's own system prompt should be written so the
model can dynamically decide how to break down a task and delegate it, rather than encoding one
fixed decomposition as if every future task will fit it (Anthropic engineering blog, "Building
effective agents," checked 2026-09-25). The same post's cross-cutting advice for any agent that
calls tools applies here too: invest in the tool descriptions at least as much as the surrounding
prompt, since the guide's authors "actually spent more time optimizing our tools than the overall
prompt" - a tool description with poor examples and unclear boundaries undermines a well-written
system prompt around it.

Claude's own current model generations increasingly decide on their own when a task would
benefit from delegating to a subagent, without being told to. Anthropic's prompting guidance notes
this can overshoot: Claude Opus 4.6 "has a strong predilection for subagents and may spawn them in
situations where a simpler, direct approach would suffice," and Claude Opus 5 delegates to
subagents more readily than prior models too. The guidance gives a damping instruction for a system
prompt that is seeing this: tell the model to delegate "when tasks can run in parallel, require
isolated context, or involve independent workstreams," and to work directly for "simple tasks,
sequential operations, single-file edits" (Claude prompting best practices, "Subagent
orchestration," checked 2026-09-25). This belongs in the orchestrating agent's own system prompt,
not in the dispatch briefs it writes for its subagents, since it governs whether a dispatch happens
at all.

## Context engineering: what to include and what to leave out

Anthropic's context-engineering guidance frames the core decision the same way for any agent
prompt, dispatch brief or system prompt alike: "find the smallest set of high-signal tokens that
maximize the likelihood of your desired outcome" (Anthropic engineering blog, "Effective context
engineering for AI agents," checked 2026-09-25). That is a bias, not a formula - it argues against
two specific habits, one on each side.

**Do not stuff.** The same source warns against dumping "a laundry list of edge cases into a
prompt" on the theory that more coverage is always safer. A long list of edge cases a model has to
read on every invocation costs tokens on every invocation, whether or not that run ever hits one of
them, and it buries the cases that actually matter for this task under ones that do not. The
alternative it recommends is a small set of diverse, canonical examples that illustrate the
intended behavior, which chapter 01 covers under examples (few-shot)
([chapter 01](01-foundations-and-standards.md)).

**Do not omit what only you know.** The dispatching agent typically holds information a cold-start
subagent cannot get any other way: which of several similarly-named files is the right one, what
was already tried and failed, which report from an earlier subagent is load-bearing for this one.
None of that is recoverable by the receiving agent re-deriving it from the repository, because it
is not in the repository - it lived only in the dispatching conversation's own history, which the
subagent does not inherit (see
[Where agent-facing prompts differ](#where-agent-facing-prompts-differ)). Leaving it out does not
make the prompt leaner; it makes the subagent redo work that was already done, or worse, silently
disagree with a decision it never saw.

Between those two failure modes sits the "right altitude" question: a system prompt that hardcodes
brittle, over-specific logic breaks the first time a task varies slightly from what the author
anticipated, while one that is only general guidance gives the model nothing concrete to act on
and assumes shared context the model does not have. The target is "specific enough to guide
behavior effectively, yet flexible enough to provide the model with strong heuristics" (Anthropic
engineering blog, "Effective context engineering for AI agents," checked 2026-09-25) - the same
target the plugin-dev pitfalls in [System prompts for agent
definitions](#system-prompts-for-agent-definitions) describe from the failure side (vague
responsibilities, missing process steps).

For large amounts of reference material - a whole codebase, a long research corpus - the same
source recommends just-in-time retrieval over pre-loading: give the agent lightweight identifiers
(file paths, stored queries, links) and let it pull in the specific content it needs through tools,
the way a person uses a filing system rather than memorizing its contents. This is also the
principle behind the pointer-not-paste convention from `claude-handoff` in [Handoff and
continuation prompts](#handoff-and-continuation-prompts): reference an artifact by path so the
receiving agent fetches it on demand, rather than inflating the handoff prompt with its full text
on the chance it turns out to be needed.

For work that spans more context than one window holds, the same "smallest high-signal set"
principle governs what belongs in the persistent state file versus what gets discarded at a
compaction or a fresh-window restart: architectural decisions and unresolved issues are worth the
tokens to keep, redundant intermediate tool output is not (Anthropic engineering blog, "Effective
context engineering for AI agents," checked 2026-09-25).

## Sizing the prompt to the task

The nine-field brief in [The dispatch brief](#the-dispatch-brief) is a checklist, not a mandatory
template length. Pstack's own guidance is explicit that the template should be sized to the unit
of work: "Size the brief to the unit" - a one-command task collapses the whole template to a short
paragraph that still names the goal, the scope, the exact verify command, and the shape of the
report, without needing nine labeled headers to say so
(`pstack/skills/poteto-mode/playbooks/orchestrate.md`, cursor/plugins repository, checked
2026-09-25). A three-line dispatch that reads "delete the `dist/` directory, verify with
`ls dist`, report whether it existed" has covered GOAL, VERIFY, and REPORT without a single label.

The same principle runs the other direction for larger or more open-ended units: an orchestration
agent's own system prompt, from
[System prompts for agent definitions](#system-prompts-for-agent-definitions), earns the full
weight of the plugin-dev template - explicit phases, failure
handling, output structure - precisely because it will be read on many future invocations across
tasks its author cannot enumerate in advance. Spending that structure on a prompt read once, for
one small unit, is the stuffing failure from
[Context engineering](#context-engineering-what-to-include-and-what-to-leave-out) in a different
guise: template weight the receiving agent has to read but gets no benefit from.

A useful test while drafting either shape: can every field in the template you chose be filled
using only information you already have. Pstack states the underlying test bluntly: "A field you
cannot fill is a unit you have not scoped yet." A field you cannot fill without further
investigation is a sign that the task itself is not yet scoped tightly enough to dispatch as one
unit - narrow the unit, or split it, before writing the prompt
(`pstack/skills/poteto-mode/playbooks/orchestrate.md`, cursor/plugins repository, checked
2026-09-25). This is the same
signal OpenAI's orchestration guidance gives from the multi-agent-architecture side: "start with
one agent whenever you can," and only split into specialists when doing so "materially improve[s]
capability isolation, policy isolation, prompt clarity, or trace legibility," because splitting
too early produces "more prompts, more traces, and more approval surfaces without necessarily
making the workflow better" (developers.openai.com, "Orchestration and handoffs," checked
2026-09-25). Sizing a prompt and sizing an agent boundary are the same decision looked at from two
directions: both ask whether the unit in front of you is small and well-defined enough to write a
complete, checkable brief for.

## Testing agent-facing prompts

[Chapter 04](04-testing-and-evaluating-prompts.md) covers the general test-first workflow,
including running a prompt in a fresh subagent to catch context leakage from the authoring
session. Two checks on top of that are specific to a prompt someone else's agent will read cold.

**The stranger test.** Before dispatching, read the brief as if you were the receiving agent with
no access to the conversation that produced it. Pstack's own phrasing of GOAL - executable by "a
stranger with no chat access" - doubles as the test for the brief as a whole: if executing it
correctly depends on knowing something only the dispatching conversation knows, that dependency
will surface as a wrong guess or a stalled task, not as a question, because the tool that would ask
the question is unavailable to every non-fork subagent - a fork keeps the parent conversation's
tool pool, `AskUserQuestion` included (`pstack/skills/poteto-mode/playbooks/orchestrate.md`,
cursor/plugins repository, checked 2026-09-25; on the missing `AskUserQuestion` tool, see [Where
agent-facing prompts differ](#where-agent-facing-prompts-differ)).

**Run the VERIFY command yourself first.** A dispatch brief's ACCEPTANCE and VERIFY fields are
only as good as the commands actually working. If the verify command in the brief has a typo, a
wrong path, or checks the wrong condition, the subagent inherits that error and either reports a
false pass or gets stuck reporting a failure that is not really one. Confirming the exact command
runs and produces the expected signal before sending the brief costs one extra terminal call and
catches a whole class of dispatch failures that would otherwise only surface after the subagent has
already spent its budget on the wrong verification.

**Test a system prompt against more than one instance of its task class.** Because a system prompt
from [System prompts for agent definitions](#system-prompts-for-agent-definitions) is read on many
future invocations rather than once, testing it against a single example under-covers it the same
way a one-example eval under-covers a person-facing prompt (see chapter 04's success-criteria
guidance). Run it against at least a normal case and one edge case from the task class it claims to
handle, and check the plugin-dev quality bar directly: is the output specific, structured,
complete, actionable, and testable on both runs, or did it only look that way on the case the
author had in mind while writing it (`references/system-prompt-design.md`, anthropics/claude-
plugins-official repository, checked 2026-09-25).

**Watch for the report itself becoming the failure.** A subagent's report is consumed by another
agent's context, not read by a person who can skim past padding. If a test run's report is vague,
hedged, or missing the one fact the dispatching agent needed, that is a prompt defect even when the
underlying work was done correctly - the REPORT field exists in the template precisely so this is
checkable rather than left to whatever the receiving agent decides to volunteer.

## References

- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents) - context inheritance,
  denied tools including AskUserQuestion, nesting depth, background tool restrictions,
  SendMessage resumption behavior, and system-prompt structure for agent definitions.
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) -
  the "smallest high-signal token set" principle, right-altitude system prompts, just-in-time
  retrieval, and long-horizon compaction and note-taking strategies.
- [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) -
  prompt chaining, the orchestrator-workers pattern, and tool documentation as agent-computer
  interface.
- [Claude prompting best practices, Agentic systems](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) -
  multiwindow workflow guidance (tests.json, progress.txt, git checkpoints) and the subagent
  orchestration damping prompt.
- [system-prompt-design.md, plugin-dev](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/agent-development/references/system-prompt-design.md) -
  the four agent-role patterns (analysis, generation, validation, orchestration) and their
  pitfalls and quality standards.
- [Orchestration and handoffs, OpenAI API docs](https://developers.openai.com/api/docs/guides/agents/orchestration) -
  the manager and handoff patterns and the "start with one agent" sizing guidance.
- [orchestrate.md, pstack](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/orchestrate.md) -
  the nine-field dispatch brief template and the size-to-the-unit guidance.
- [dispatching-parallel-agents SKILL.md, superpowers](https://github.com/obra/superpowers/blob/main/skills/dispatching-parallel-agents/SKILL.md) -
  the focused, self-contained, specific-about-output framing and common dispatch-prompt mistakes.
- [claude-handoff SKILL.md, Matt Pocock](https://github.com/mattpocock/skills/blob/main/skills/in-progress/claude-handoff/SKILL.md) -
  referencing artifacts by path, redacting secrets before a handoff, and the suggested-skills
  section.
