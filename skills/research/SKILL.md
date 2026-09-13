---
name: research
description: |
  This skill should be used when the user asks to research an external topic and write it up as
  documentation - e.g. "research X and write docs about it",
  "create a docs/<topic>/ documentation set on X", "research and document Y",
  "look into X and write it up", or "build documentation on X". Loads the incremental
  skeleton-first workflow, progress-file convention, usage-utilization check, and
  delegation-shape decision (inline by default; parallel Agent-tool forks for independent
  sub-topics; the dedicated researcher subagent only for the narrow-tool-contract case) from
  reference/research-discipline.md. Does not apply to a quick single-fact lookup, reviewing or
  editing already-written content (see review-md), or planning non-documentation work (see
  write-plan). Scope: personal (~/.claude/skills/).
---

<!--
created: 2026-08-10
updated: 2026-09-11
spec: specs/skills.md (research section)
generated-by: skill-author + skill-creator, dispatched from Claude Code main thread (Sonnet 5)
model: claude-sonnet-5
harness: Claude Code 2.1.222

No `context`/`agent`/`model`/`effort` frontmatter, by deliberate deviation from skill-author's
default "research-heavy work -> context: fork" guidance. `context: fork` dispatches to a
cold-started agent context (docs/features/skills.md; specs/skills.md's review-md section calls
its own use of that field a "cold-start fork" explicitly) - it does not share the invoking
conversation's prompt cache. This skill's entire purpose is to carry a workflow into whichever
context invoked it, usually inline, so it can share that context's already-warm cache; setting
`context: fork` here would silently reintroduce the cold-start cost problem
decisions/0008-avoid-parallel-research-fanout.md diagnoses. See that decision for the full
rationale.
-->

# Research and Write Documentation

Research one topic and write it up as documentation, following the protocol in
`references/research-discipline.md` (synced from this repository's
`reference/research-discipline.md`). Load that file now, before doing anything else - it is the
source of truth for the workflow below, not duplicated here.

## Default: work inline

Do the research and writing directly in the current context. Follow
`references/research-discipline.md` exactly for:

- The skeleton-first incremental workflow (outline before content, one section at a time).
- The progress-file convention (what to record, where, and why it matters for resuming).
- The usage-utilization check (the exact command, the default 90% halt threshold, and what to
  do if the check itself fails).

## Delegation decision

Stay inline unless a topic's raw research output would flood the current context. When it
would:

- **One self-contained topic, even a large one:** stay inline. Size alone is not a reason to
  delegate.
- **Genuinely independent sub-topics, and raw output would flood the current context:**
  dispatch each sub-topic as a parallel `Agent`-tool fork (`subagent_type: "fork"`) - not a
  fresh subagent. A fork shares the current context's already-warm prompt cache, so each
  parallel branch costs a cheap cache read instead of a fresh cache write for its own copy of
  the system prompt and tool definitions. Give each fork a self-contained sub-prompt naming its
  specific sub-topic and target file - it does not inherit your intent beyond what you inherit
  yourself into it (a fork sees the conversation so far, not your unstated plan for the other
  forks).
- **Forking is a poor fit:** the isolated work should not carry the full calling context/tool
  access. This is a scope reason, not a cost one - a fork does not lose to a fresh subagent on
  cost within any reachable session size (see `decisions/0008-avoid-parallel-research-
  fanout.md`), so session size alone is never the reason to skip forking. In
  the scope case, dispatch the `researcher` subagent (`agents/researcher.md`) instead, one
  topic at a time - never several `researcher` dispatches in parallel, since that reproduces
  the cold-start cost problem with a different tool.

Full rationale for this ordering:
`${CLAUDE_CONFIG_DIR:-~/.claude}/decisions/0008-avoid-parallel-research-fanout.md`.
