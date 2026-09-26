---
name: prompt-author
description: |
  This skill should be used when the user asks for a prompt to be written, rewritten, improved,
  or critiqued - for them to use elsewhere, e.g. "write me a prompt for ...",
  "draft a prompt I can paste into ChatGPT", "what's wrong with this prompt?",
  "write a system prompt for my Claude Project", or for an agent to receive, e.g.
  "write the brief for a subagent", "draft a handoff prompt for a fresh session",
  "write the system prompt for a new agent definition". Loads this user's prompt defaults, a
  pre-handoff checklist, and brief and handoff rules. It does not author skills (see
  skill-author), plan work or write plan Units (see planner), write the system prompt or other
  prompt text an app sends to the Claude API (see claude-api), or proofread Markdown (see
  review-md). Not for shell or permission prompts, or for just delegating a task.
---

<!--
created: 2026-09-26
updated: 2026-09-26
spec: specs/skills.md (prompt-author section)
generated-by: prompt-author build plan, Opus executor subagent dispatched from Claude Code main thread
model: claude-opus
harness: Claude Code

No `context`/`agent`/`model`/`effort` frontmatter, matching skills/go-dev/SKILL.md and for the
same reason: this skill carries knowledge into whichever context invoked it and must share that
context's already-warm prompt cache.
-->

# Prompt Authoring

## What this covers

Use this when the user wants a prompt written, drafted, rewritten, improved, or critiqued. It
covers two kinds:

- User-facing: a prompt the user takes somewhere else, such as another chat, another vendor's
  model, a Claude Project or custom GPT system prompt they paste in by hand, or a reusable
  template.
- Agent-facing: a prompt an agent receives, such as a subagent dispatch brief, a handoff or
  continuation prompt for a fresh session, the body of an `agents/*.md` definition, or a prompt
  for a background or looped agent.

It does not cover a request to simply do a task through a subagent, skills or skill descriptions
(skill-author), plan Units (planner), the system prompt or other prompt text an app sends to the
Claude API (claude-api), Markdown proofreading (review-md), shell prompts, permission prompts, or
the `UserPromptSubmit` hook.

## Before writing

Pin down three things first: the target (which tool or model the prompt goes into, and which
field, such as project instructions versus a knowledge file), the audience for the output, and
what a successful result looks like.

Infer what you can from the request and the conversation. When something the prompt depends on
is still missing, pick one path:

- Ask at most three targeted questions with `AskUserQuestion`, then write.
- Or write the prompt now and list your assumptions right after it.

Never ask more than three questions. Choose the second path when a wrong guess is cheap to fix.

## Your defaults

The user confirmed these. Apply each one to every prompt it bears on.

- [D1] Check that the prompt states an explicit git-safety boundary: work in a worktree or branch
  only, no force-push or history rewrite, and no merge or push to main unless asked.
- [D2] For an unattended, multi-step prompt, tell the agent to keep going instead of stopping to
  ask: decide on evidence, favor correct over easy, record the decision, then continue past
  blockers.
- [D3] State the target working directory or repo path explicitly near the top of the prompt.
- [D4] Give the prompt a dedicated section, inside the prompt file itself rather than a separate
  doc, where the agent logs each deferred decision and the evidence behind it.
- [D5] Before handing over, re-read the prompt for factual accuracy against the current repo
  state, consistency between its steps, and a resume path for an interrupted run.
- [D6] After writing a prompt file, end the turn by stating the file's path rather than pasting
  its contents back.
- [D7] For a prompt likely to run long enough to hit account limits, tell the agent to check usage
  at a fixed point in its loop, such as before each batch or phase, not only when it notices a
  sign, and to pause, then resume, rather than fail. Name the check: on this setup it is
  `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/planner/scripts/usage-check.sh`, whose `status=` line
  says whether to go on, slow down, or pause.
- [D8] For a prompt file that archives itself on completion, make the archive step fire only on a
  genuine finish, not on an early stop, a blocker, or an open question.
- [D9] Keep a "decide instead of asking" instruction from widening scope: put speculative
  improvements in a separate suggestions list, apart from required changes.
- [D10] Use only ASCII punctuation in the delivered prompt: plain hyphens and straight quotes, no
  em or en dashes, curly quotes, ellipsis character, or other typographic substitutions.
- [D11] Lead the prompt with the goal, stated plainly, before background or setup detail.
- [D12] Write instructions in short sentences and common words rather than precise-sounding
  jargon.
- [D13] State each instruction directly, with no hedging phrases.
- [D14] Size the prompt's length and detail to the size of the task it describes.

## Writing the prompt

Include the parts the target model cannot supply itself:

- The goal, so the model does not have to guess intent.
- The context it lacks: audience, what happens to the output next, why the task exists.
- What a finished answer looks like: format, length, or done-criteria, since a vague finish line
  invites stopping early.
- The reason behind any constraint that is not self-evident, so the model can apply it to cases
  the prompt did not foresee.

Mark every spot the user must fill in with one form, `{{snake_case_name}}`, because it reads
clearly as "replace me" and does not collide with other template syntax.

Say what to do rather than only what to avoid, because a list of prohibitions pulls the forbidden
behavior into view. Keep an explicit prohibition for a hard guardrail you cannot phrase
positively.

Write emphasis in normal case. Recent Claude models tend to over-apply a rule written in capitals
(Anthropic documents this for Opus 4.5 and 4.6), so use a plain conditional ("Use this when...")
instead, unless the user asked for capitals.

For a Claude target:

- Put long pasted input or documents in XML tags, apart from the instructions and placed before
  them, because Claude answers better when the query comes last.
- For a Claude Opus 5 and Opus 5.5 target, add no blanket instruction to double-check or
  re-verify the work. Those models already self-check, so the extra instruction adds cost with no
  gain. Keep this rule to those two models.

For a non-Claude target, use only techniques that work across vendors: a clear goal, structure by
tags or headers, key instructions early, concrete examples. Leave out Claude-only features such as
prefilled responses and extended-thinking settings, and do not name Claude in the prompt.

## Improving an existing prompt

Give the revised prompt, then a short list of what changed and why, with each change tied to the
problem the user reported. Keep the original's structure, and keep its placeholder names and form
unless a change needs them to move; the `{{snake_case_name}}` form applies to new prompts. If part
of the original looks wrong, say so and explain the tradeoff rather than dropping it silently.

## Agent-facing prompts

The receiving agent cannot ask you a question back, and most start with no view of this
conversation. Write every agent-facing prompt so it is complete on arrival.

For a subagent dispatch brief, give:

- The goal, in one sentence an agent with no chat access can act on.
- The scope: the paths it may touch, and what it must leave alone.
- The context it needs, pasted in. Paste an upstream report in full.
- Acceptance criteria it can check, one per line.
- The exact command that verifies them.
- What to report back, and in what shape.

If you cannot fill the goal or the verify command, narrow the task before you write the brief. A
fork already holds this conversation, so its brief can drop the context part; it still needs the
goal, scope, verify command, and report shape.

Paste what the agent needs into the prompt, or name input material by its exact path. Never send
it to "the conversation", "above", "as discussed", or another document to find its task.

Size the prompt to the task. A one-step task gets a short paragraph of at most 150 words that
still names the goal, scope, verify command, and report shape. Count the words before you hand it
over. In a one-step brief, leave out the git-safety boundary unless the task itself touches git,
and leave out edge cases the task does not raise. Keep the full brief for work large or
open-ended enough that a missing part would leave real doubt.

For a handoff to a fresh session, state what is done and what remains. Point to existing
artifacts, such as specs, plans, and commits, by path instead of restating them. Leave out secret
values. Name the skills the next session should load. A message resuming a finished subagent
that keeps its history needs only what changed and what to do next.

For the system prompt of an agent definition, state the agent's role, its scope boundaries, the
process it follows step by step, and its output format. Name a class of task, not one run's paths
and findings, since it will be read on many future tasks.

For the brief template, background and looped agents, work that spans several context windows,
and testing, read `references/agent-prompts.md`.

## Check before handing over

Walk this list silently before you reply. Fix anything that fails, then deliver.

1. An inline prompt sits in one fenced code block, and nothing the user should not paste is inside
   it.
2. Every new placeholder uses `{{snake_case_name}}`, and every placeholder has a one-line meaning
   after the block.
3. The prompt states the goal, the context the target lacks, what a finished answer looks like,
   and the reason behind any constraint that is not self-evident.
4. Instructions say what to do, and no word is in all capitals for emphasis unless the user asked.
5. For a Claude target, long input sits in XML tags before the instructions. For Claude Opus 5 and
   Opus 5.5, no blanket self-check instruction is present.
6. For a non-Claude target, no Claude-only feature appears and Claude is not named.
7. A prompt over about 40 lines went to a file under the rule in Delivering, and the reply gives
   its path. If a Claude Code agent will run it, it ends with the archive instruction. A dispatch
   brief and an agent-definition body are the exceptions Delivering names.
8. A prompt that touches git states the git-safety boundary.
9. The prompt matches the repo as it is now, its steps agree with each other, and an interrupted
   run has a way to resume.
10. A self-archiving prompt archives only on a genuine finish, not on an early stop, a blocker, or
    an open question.
11. A "decide instead of asking" instruction does not widen scope, and speculative ideas sit in a
    separate suggestions list.
12. The prompt text uses only ASCII punctuation.
13. No instruction hedges.

For an agent-facing prompt, also check:

14. A dispatch brief has a one-sentence goal, the scope, the needed context pasted in, checkable
    acceptance criteria, a verify command, and the report shape.
15. Nothing points the agent at "the conversation", "above", "as discussed", or another document
    to find its task; input material is pasted in or named by exact path.
16. A one-step task got a short paragraph of at most 150 words by count, not the full brief.
17. A handoff states what is done and what remains, points to artifacts by path, carries no
    secret values, and names the skills to load.
18. An agent-definition body states the role, the scope boundaries, a step-by-step process, and
    the output format.
19. For a prompt that will be reused, including an agent definition or a background or looped
    prompt, the reply offers a test run on a subagent.

## Delivering

For a prompt of about 40 lines or fewer, reply in this order:

1. One fenced code block holding only the prompt, so the user can copy it whole.
2. Each placeholder with its one-line meaning.
3. Your assumptions, or for a revision, what changed and why.

For a prompt that will be reused, including an agent definition or a background or looped prompt,
offer to test it on a subagent. Never run the test unasked. For a non-Claude target, say that such
a run checks only clarity, not how the target model behaves.

Count the prompt's own lines as you wrote them, with each placeholder as one line; text the user
will paste into a placeholder does not count. A prompt longer than about 40 lines goes to a file
instead, named `prompt-YYYY-MM-DD-<slug>.md`, in a `prompts/` directory beside the plans directory
the `planner` skill resolves. Pick the directory in this order:

1. Next to a `plansDirectory` the user set.
2. Else `<cwd>/.claude/prompts/` when `<cwd>/.claude/` exists, or `<cwd>/prompts/` when the
   working directory is itself a `.claude` directory.
3. Else `${CLAUDE_CONFIG_DIR:-~/.claude}/prompts/`.

The reply gives the file's path instead of pasting the prompt. When a Claude Code agent will
execute the prompt, end it with an instruction to move its own file into the `archive/`
subdirectory of that `prompts/` directory, creating it if needed, once every step has finished,
and not on an early stop, a blocker, or an open question. A prompt meant for another tool
carries no such instruction.

Two agent-facing prompts skip the file rule and the archive instruction. A dispatch brief goes
straight into the Agent tool call, or inline when the user asked for the text. An agent-definition
body goes into its `agents/<name>.md` file. A handoff prompt for a fresh session follows the file
rule like any other prompt.

## Going deeper

For technique detail, model-specific guidance, and system prompts for chat products, read
`references/prompt-writing.md`. For briefs, handoffs, agent definitions, background and looped
agents, and work that spans several context windows, read `references/agent-prompts.md`.
