---
created: 2026-09-26
updated: 2026-09-26
source: docs/prompt-engineering/06-agent-facing-prompts.md (hand-condensed, not a sync copy)
---

# Agent-Facing Prompt Reference

## The dispatch brief

A dispatch brief hands a bounded unit of work to a subagent or a parallel fork. It has to be
complete on arrival: the receiving agent cannot ask a clarifying question back (non-fork subagents
are denied `AskUserQuestion`), and most receiving agents start cold, with no view of the
dispatching conversation's history. Fields:

- **Goal**: one sentence, written so a stranger with no access to the chat that produced it could
  execute it.
- **Scope**: the paths the agent may and may not write to.
- **Context**: pointers to what it needs (file paths, prior findings), with any upstream report
  pasted in full rather than referenced, since a subagent cannot fetch back through a conversation
  it never saw.
- **Acceptance**: checkable conditions, one per line.
- **Verify**: the exact commands that check those conditions.
- **Report**: the shape of what should come back.
- **Timebox** and **Forbidden** (broader than Scope: things like running git commands or
  installing dependencies), when they matter for the unit.

A field you cannot fill is a unit you have not scoped yet. If Goal cannot be written as one
executable sentence, or Verify cannot name a command, narrow the task before dispatching it,
rather than sending it vague and hoping the subagent narrows it for you.

Never point the brief at "the conversation," "above," "as discussed," or another document to find
its own task. Paste what the agent needs, or name input material by its exact path.

A fork already holds the parent conversation's full context, so its brief can leave out Context
the parent already has. It still needs Goal, Scope, Verify, and Report, the same as any dispatch.

## Sizing

The field list is a checklist, not a mandatory template length. A one-step task collapses the
whole brief to a short paragraph, at most 150 words, that still names the goal, the scope, the
exact verify command, and the shape of the report, without needing labeled headers to say so. For
example: "delete the `dist/` directory, verify with `ls dist`, report whether it existed" covers
goal, verify, and report in one line. Save the full multi-field template for units large or
open-ended enough that skipping a field would leave real ambiguity; spending that structure on a
prompt read once, for one small unit, is template weight the receiving agent has to read but gets
no benefit from.

## Handoff prompts

A handoff restarts a unit of work in a fresh session that inherits nothing automatically. State
what is already done and what remains. Reference existing artifacts by their path instead of
duplicating their content in the handoff prompt itself; the receiving agent fetches them on
demand. Redact secrets, because the handoff becomes a prompt something else will read and
potentially act on. Name which of the receiving agent's available skills are likely relevant to
the handed-off work, since a fresh session cannot infer that from history it never had.

Resuming an already-finished subagent through a resume mechanism is different: the subagent
receives its full prior history and tool results, so the continuation message can be short, naming
only what changed and what to do next. Padding it with a restatement of context the subagent
already holds wastes tokens for no benefit.

## Agent definition system prompts

A system prompt is written once and read many times, across tasks its author cannot fully
predict, so it names a class of task and a process, not one instance's specific paths and
findings. Four recurring shapes by agent role:

- **Analysis agents**: state exactly what to check, and report findings by severity with concrete
  locators (file and line), not a general impression.
- **Generation agents**: give an explicit process, for example understand requirements, gather
  context, design structure, generate content, validate, document.
- **Validation agents**: check output against stated criteria and return a clear pass or fail,
  organized by violation type and severity.
- **Orchestration agents**: manage phases in sequence and handle failures gracefully rather than
  assuming every step succeeds.

A vague responsibility statement ("help with the code") gives the model nothing to act on; state
the target instead ("identify missing type annotations and improper use of `any`"). A missing
process step has the same effect: "analyze the code" is not a process, but "read files, scan for
the named patterns, verify requirements, list findings with file references" is. An undefined
output format lets the same agent format its findings differently run to run, which can break a
caller that parses the result programmatically. The bar: specific, structured, complete for normal
and edge cases, actionable, and testable. Use no all-caps emphasis in an agent system prompt.

## Background, scheduled, and looped agents

These prompts run with nobody watching the turn they run in, so the prompt must carry what a
watching person would otherwise supply.

- **Background subagent.** It cannot ask questions, its permission prompts wait on a person in the
  main session, and its result arrives as a notification in a later turn. Make the report stand on
  its own (done, found, still open), and keep the brief to tools the session already allows if it
  must finish unattended.
- **Repeating prompt (`/loop`, a scheduled task, `loop.md`).** Say what to do in each state the run
  may find, including the quiet one ("If everything is green and quiet, say so in one line"). Name
  the done condition, so a self-paced loop can end itself. State a boundary on irreversible actions
  such as pushing or deleting, because a custom prompt replaces the built-in one that carries that
  rule. Check actual state each run: missed fires are not caught up, so do not count iterations.
- **Done condition for any long or looped run.** Follow the `/goal` guidance: one measurable end
  state, a stated check (such as "`npm test` exits 0"), the constraints that must not change on the
  way, and a bound such as "or stop after 20 turns". Under `/goal` the judge reads only the
  conversation, so the check must show up in Claude's own output.
- **Headless or cloud run (`claude -p` in CI, a routine).** Nobody is there to answer: an
  unattended `claude -p` run denies anything that would prompt and drops `AskUserQuestion`, and a
  routine runs its actions without asking. Make the prompt self-contained and explicit about what
  success looks like. A routine starts from a fresh clone of the default branch. Text sent with its
  trigger arrives in a `<routine-fire-payload>` block marked untrusted, and stays inert context
  unless the prompt refers to that block by name. A green run status does not mean the task
  succeeded, so have the run state its outcome plainly.

## Work that spans several context windows

A prompt for a session that will restart cold across a task spanning more context than one window
holds needs mechanics a one-shot dispatch does not: track structured state (test status, task
lists) in a machine-readable file such as `tests.json`, keep freeform progress notes in a plain
file such as `progress.txt`, and use git commits as checkpoints the next window can inspect. Be
prescriptive about how the fresh window should start, for example "call pwd; you can only read and
write files in this directory" and "review progress.txt, tests.json, and the git logs," rather
than assuming it will discover the right starting point on its own. For long tasks, starting the
next window fresh from these files can work better than relying on the harness's own compaction.
Anthropic's long-running harness also uses a separate first-session prompt that sets up the
environment, has each later session pick the highest-priority unfinished feature from a JSON
feature list and change only its `passes` field, works one feature at a time, and leaves a clean
state at the end of each session. The feature list guards against a failure the harness hit often:
a later session sees progress and declares the job done.

## Testing

Before dispatching, read the brief as if you were the receiving agent with no access to the
conversation that produced it: if executing it correctly depends on knowing something only that
conversation knows, the dependency surfaces as a wrong guess or a stalled task, not a question,
because the tool that would ask is unavailable to a non-fork subagent. Run the exact Verify command
yourself first; a typo, a wrong path, or a check of the wrong condition in that command becomes the
subagent's failure, not just the brief's. Test a system prompt, which is read on many future
invocations, against at least a normal case and one edge case from its task class, not a single
example. Watch the report itself: if a test run's report is vague, hedged, or missing the one fact
the dispatching agent needed, that is a prompt defect even when the underlying work was done
correctly.

Offer a subagent test run for a prompt that will be reused. Never run one unasked.

## Sources

- docs/prompt-engineering/06-agent-facing-prompts.md - the dispatch brief template, sizing, handoff
  and continuation prompts, background, scheduled, and looped agents, agent-definition system
  prompts, and testing agent-facing prompts. Key
  external sources it cites: Claude Code subagents
  (https://code.claude.com/docs/en/sub-agents), Effective context engineering for AI agents
  (https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents), Building
  effective agents (https://www.anthropic.com/engineering/building-effective-agents), Claude
  prompting best practices, Agentic systems
  (https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices),
  system-prompt-design.md, plugin-dev
  (https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/agent-development/references/system-prompt-design.md),
  Orchestration and handoffs, OpenAI API docs
  (https://developers.openai.com/api/docs/guides/agents/orchestration), orchestrate.md, pstack
  (https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/orchestrate.md),
  dispatching-parallel-agents SKILL.md, superpowers
  (https://github.com/obra/superpowers/blob/main/skills/dispatching-parallel-agents/SKILL.md),
  claude-handoff SKILL.md, Matt Pocock
  (https://github.com/mattpocock/skills/blob/main/skills/in-progress/claude-handoff/SKILL.md),
  the Claude Code scheduled tasks, `/goal`, headless, and routines pages
  (https://code.claude.com/docs/en/scheduled-tasks, https://code.claude.com/docs/en/goal,
  https://code.claude.com/docs/en/headless, https://code.claude.com/docs/en/routines), and
  Effective harnesses for long-running agents
  (https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).
