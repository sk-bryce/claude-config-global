---
audience: human
created: 2026-09-25
updated: 2026-09-26
---

# Prompt Engineering: Writing Prompts That Work

A researched guide to writing prompts: for a person to paste into another tool, and for one agent
to hand to another. It backs the `prompt-author` skill in this repository, but it stands on its
own. Every chapter ends with a References section listing only sources that were checked.

## How to use this guide

1. Read [chapter 1](01-foundations-and-standards.md) for the vendor-neutral basics.
2. Read [chapter 2](02-claude-specific-guidance.md) before writing for a Claude model.
3. Use chapters 3 and 4 as working references when writing and checking a prompt.
4. Read [chapter 6](06-agent-facing-prompts.md) before writing a prompt for a subagent, a fresh session, or a background or looped agent.
5. Chapter 5 records what other published skills already do, and why this guide exists.

## Chapters

| Chapter | Covers |
| --- | --- |
| [1. Foundations and standards](01-foundations-and-standards.md) | What the major vendors agree on, the parts of a prompt, which techniques still help, and practices that have aged badly. |
| [2. Claude-specific guidance](02-claude-specific-guidance.md) | How current Claude models respond to prompts, and a migration checklist for older prompts. |
| [3. Prompts for people](03-prompts-for-people.md) | Writing a prompt someone else will run: missing information, placeholders, chat-product system prompts, portability, and delivery. |
| [4. Testing and evaluating prompts](04-testing-and-evaluating-prompts.md) | Success criteria, test-first prompt writing, checks before handoff, and eval tooling. |
| [5. Existing skills survey](05-existing-skills-survey.md) | A 2026-09-25 survey of published prompt-writing skills and what this guide borrowed from them. |
| [6. Agent-facing prompts](06-agent-facing-prompts.md) | Prompts one agent hands to another: dispatch briefs, handoffs, background and looped agents, agent system prompts, context, sizing, and testing. |
