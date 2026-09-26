---
audience: human
created: 2026-09-25
updated: 2026-09-26
---

# Survey of Existing Prompt-Writing Skills

A survey, taken on 2026-09-25, of whether any reputable, published agent skill already does what
the `prompt-author` skill sets out to do: write prompts for a user to take elsewhere, carrying that
user's own defaults and a check pass before handing the prompt over.

## Verdict

None does. The three most-followed skill collections each hold a fragment of the idea, and the
dedicated community prompt skills are generic technique catalogs that carry no personal defaults.
Several of those catalogs also teach habits that current Claude guidance now advises against. The
fragments below are worth borrowing; the content itself is best sourced from vendor guidance (see
chapters 01 and 02).

## obra/superpowers

About 291,000 stars when checked. It has no prompt-writing skill. Two skills come close:

- `dispatching-parallel-agents` has an "Agent Prompt Structure" section: a good agent prompt is
  focused on one problem, self-contained, and specific about what to return. It pairs a worked
  example with four before-and-after mistakes: too broad, no context, no constraints, vague output.
- `writing-skills` treats writing a skill as test-driven development: run a pressure scenario on a
  subagent without the skill and watch it fail, write the skill, watch the agent comply, then close
  loopholes. This is the most transferable idea in the survey, and it applies to any reusable
  prompt.

## mattpocock/skills

About 270,000 stars when checked. No prompt-writing skill. The closest is `writing-for-agents`,
the best-written material in the survey. It covers any document an agent reads and gives concrete
tests: every step ends on a completion criterion that is clear and demanding; steering by
prohibition makes the banned behavior more available, so state the positive target; a sentence
the model already obeys by default is a no-op to delete; and a compact "leading word" the model
already knows can replace a sentence. `claude-handoff` writes one specific prompt: a handoff
summary that seeds a fresh background agent, referencing existing artifacts by path, redacting
secrets, and naming skills the next agent should load.

## Lauren Tan's pstack

Upstream lives in `cursor/plugins` under `pstack/`, with many community ports. No standalone prompt
skill. The `poteto-mode` skill's `orchestrate` playbook has a section titled "The brief" that treats
the prompt as the product: "a vague brief fails quietly, because a worker cannot ask you a
question." It gives a fixed template (GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX,
FORBIDDEN, REPORT, STANDING), says a field you cannot fill means the unit is not scoped yet, sizes
the brief to the unit, and keeps a standing-orders file that gains a line whenever an instruction
is repeated. Its `technical-writing` and `unslop` skills are prose-quality standards rather than
prompt skills.

## Anthropic

`anthropics/skills` and `anthropics/claude-plugins-official` hold no prompt-writing skill. The
nearest is the `plugin-dev` plugin's `system-prompt-design.md` reference, which gives patterns for
agent system prompts (analysis, generation, validation, and orchestration agents). The
authoritative content source is the Claude prompting best-practices page, which also names
practices that now backfire on recent models: aggressive "CRITICAL: You MUST" language causes
over-triggering, and on Claude Opus 5 explicit self-verification instructions cause
over-verification and should be removed rather than reworded.

## Community prompt skills

- `Jeffallan/claude-skills` `prompt-engineer` (about 11,600 stars for the collection) and
  `alirezarezvani/claude-skills` `senior-prompt-engineer` (about 26,000 stars for the collection)
  are textbook overviews: zero-shot, few-shot, chain of thought, evaluation frameworks.
- `ckelsoe/prompt-architect` (about 300 stars) is a catalog of 31 named frameworks such as CO-STAR
  and CRISPE.
- `NeoLabHQ/context-engineering-kit` `test-prompt` applies the superpowers test-first loop to any
  prompt, including commands, hooks, and subagent instructions. It is the only one with a distinct
  idea.

Only the headers and file trees of these community skills were read, so the "generic" verdict
rests on their descriptions and structure.

## What this meant for the design

1. The skill body holds the user's own defaults and a pre-handoff checklist, since nobody else can
   write those.
2. Agent-facing prompts borrow pstack's brief fields and its sizing rule.
3. No technique catalog: technique questions point to vendor guidance.
4. A test run on a subagent is offered, not forced, for prompts that will be reused.

## References

- [obra/superpowers](https://github.com/obra/superpowers) - `dispatching-parallel-agents` and `writing-skills`.
- [mattpocock/skills](https://github.com/mattpocock/skills) - `writing-for-agents` and `claude-handoff`.
- [cursor/plugins, pstack](https://github.com/cursor/plugins/tree/main/pstack) - the `orchestrate` playbook's brief template and `technical-writing`.
- [anthropics/skills](https://github.com/anthropics/skills) - checked for a prompt-writing skill; none found.
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) - `plugin-dev` system prompt design patterns.
- [Prompting best practices, Claude Platform Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) - current Claude guidance and the practices that now backfire.
- [Jeffallan/claude-skills prompt-engineer](https://github.com/Jeffallan/claude-skills/blob/main/skills/prompt-engineer/SKILL.md) - generic technique catalog.
- [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) - `senior-prompt-engineer`.
- [ckelsoe/prompt-architect](https://github.com/ckelsoe/prompt-architect) - framework catalog.
- [NeoLabHQ/context-engineering-kit](https://github.com/NeoLabHQ/context-engineering-kit) - `test-prompt` and `prompt-engineering`.
