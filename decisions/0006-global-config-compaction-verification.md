---
created: 2026-07-30
updated: 2026-08-31
---

# 6. Global config compaction verification (canary)

- Status: Accepted
- Date: 2026-07-30
- Deciders: repository owner
- Related: `reference/context-file-authoring.md` (Loading Mechanics > CLAUDE.md),
  `skills/cursor-projection/references/harness-matrix.md` (Context compaction /
  summarization),
  `decisions/0001-adopt-spec-driven-config-architecture.md`

## Context

Anthropic's own compaction table (`docs/en/context-window#what-survives-compaction`) confirms
only "Project-root CLAUDE.md and unscoped rules" are re-injected from disk after `/compact`;
nothing in Anthropic's documentation states whether that guarantee extends to user-scope
`~/.claude/CLAUDE.md`, which is this repository's actual root file. Confirmed by reading `docs/en/memory` and `docs/en/context-window` directly: neither page
names the user/global scope in the survival table or prose. `reference/context-file-authoring.md`
already scoped its own prior claim to "project-root" only, for the same reason.

Two further findings shaped the design:

- Anthropic documents a `## Compact Instructions` section in CLAUDE.md as the way to control what
  automatic compaction preserves; a human manually running `/compact focus on <text>` at the
  terminal is a separate, alternative lever - both facts appear on `docs/en/how-claude-code-works`
  ("When context fills up"), and the focus-argument fact is repeated on `docs/en/context-window`
  ("Compact with a focus"). This was missed on an initial pass that only checked `docs/en/memory`
  and `docs/en/context-window`, neither of which mentions the `Compact Instructions` section;
  confirmed only once `docs/en/how-claude-code-works` was checked directly. The Preserve/Discard
  checklist below should live under a section literally named `## Compact Instructions`, not an
  arbitrary heading, for the documented mechanism to apply.
- Undocumented, and distinct from the heading-matching ambiguity above: whether the mechanism is
  honored for a user-scope `CLAUDE.md` at all. Anthropic's docs describe it against the
  project-root file and say nothing about the global scope, so a `## Compact Instructions`
  heading in `~/.claude/CLAUDE.md` may or may not be read by compaction's preservation logic.
  Treat as unconfirmed alongside the user-scope gap above.
- The assistant has no tool to read its own live context-window percentage, and no tool-call
  surface equivalent to `/compact`. Compaction only happens via the harness's own automatic pass or
  a human typing `/compact`.

Given the confirmed gap and the absence of any assistant-side lever to observe or trigger
compaction, a passive verification signal (a canary phrase, re-read and reconfirm) is the only
thing available to check whether "this file always reloads" actually holds for the global scope,
as opposed to trying to control compaction's timing or its content directly - neither of which is
possible from inside a conversation turn.

## Decision

Add a `## Canary` and `## Compact Instructions` section to `CLAUDE.md` (the latter named to match
Anthropic's documented mechanism, not an arbitrary heading):

- After any compaction event (automatic or manual - not a self-triggered schedule), re-read
  `CLAUDE.md` and the user rules and reconfirm via canary before continuing.
- Keep the Preserve/Discard checklist under that heading, so it is the documented lever for what
  automatic compaction preserves, not just prose the assistant happens to reread afterward.

Explicitly rejected: instructing the assistant to "perform compaction when context reaches X%."
The assistant cannot observe a live percentage and cannot invoke compaction itself, so a numeric
self-trigger is not actionable regardless of the number chosen. An earlier draft additionally
tried a fixed "every 5 turns" cadence; dropped for the same inactionability, plus the added cost of
forcing extra compaction events (cache invalidation, summarization overhead) with no proportional
benefit.

## Consequences

- The canary can only prove the success case. If the global file genuinely failed to reload after
  some compaction, the instruction telling the assistant to check and say the phrase would also be
  gone, so nothing prompts the assistant to flag the gap - silent success and silent failure look
  identical unless a human is actively watching for the phrase's absence on every turn following a
  compaction. This is a known, accepted limitation, not something the current design closes.
- The Preserve/Discard list has a documented mechanism to matter (the `## Compact Instructions`
  heading), but the docs don't specify exact matching rules (heading level, case sensitivity), nor
  whether the mechanism reaches a user-scope `CLAUDE.md` the way it reaches a project-root one, so
  treat the literal name as the safest bet rather than a guaranteed API.
- No added cost from forced extra compactions, since there is no self-triggered schedule.
- Cursor scope (researched 2026-07-30, see
  `skills/cursor-projection/references/harness-matrix.md` > Context compaction / summarization):
  Cursor has an equivalent trigger, "summarization" (`/summarize`, alias `/compress`, plus an
  automatic pass near the context limit), but no documented way to shape what it preserves and no
  documentation confirming whether User Rules survive it at all - a wider, still-unconfirmed gap
  than Claude Code's. The `## Compact Instructions` heading name is Claude Code-specific, so the
  projection procedure in `skills/cursor-projection/references/user-rules-projection.md` retitles
  the section to `## Context Preservation` rather than projecting it verbatim, while still
  carrying the canary-reconfirm behavior and the Preserve/Discard priorities, which are
  harness-neutral in intent.

## Alternatives considered

- Fixed-cadence forced compaction ("every 5 turns" or "at 65% utilization", self-triggered by the
  assistant). Rejected: the assistant cannot observe context percentage or invoke compaction, so
  neither variant is actionable; the turn-based version additionally wastes tokens forcing
  compaction events unrelated to actual context pressure.
- No verification at all. Rejected: the compaction survival guarantee is confirmed only for
  project-root CLAUDE.md; this repository's actual file is user-scope, so assuming the same
  guarantee applies with no way to notice if it doesn't would let global-config drift go unnoticed.
- A hook-based verification (for example an `InstructionsLoaded` hook logging which files loaded,
  independent of assistant compliance). Not adopted here because it would positively detect the
  failure case the canary can't, but is out of scope for this change; worth revisiting if the
  canary's blind spot proves costly in practice.

## References

- [How Claude remembers your project](https://code.claude.com/docs/en/memory) - Anthropic;
  "Instructions seem lost after /compact" section, confirms only project-root CLAUDE.md is
  documented to survive.
- [Explore the context window](https://code.claude.com/docs/en/context-window) - Anthropic; "What
  survives compaction" table, same project-root-only scoping; "Compact with a focus" section
  documents the `/compact focus on X` human-invoked lever.
- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up) -
  Anthropic; "When context fills up" section, source for the `## Compact Instructions` mechanism.
- [Cursor Changelog 1.6](https://cursor.com/changelog/1-6) - Cursor; confirms automatic
  summarization near the context limit.
- [Cursor CLI Slash Commands](https://cursor.com/docs/cli/reference/slash-commands) - Cursor;
  documents `/summarize` and its `/compress` alias.
- `reference/context-file-authoring.md` - Loading Mechanics > CLAUDE.md, states the same
  project-root-only claim this decision is built on, plus the `Compact Instructions` fact.
- `skills/cursor-projection/references/harness-matrix.md` - Context compaction / summarization,
  the cross-harness comparison this decision's Cursor scope note is built on.
