---
audience: human
created: 2026-07-31
updated: 2026-08-31
---

# Appendix B: Cursor Specifics

This appendix assumes `skills/cursor-projection/references/harness-matrix.md` as authoritative for every Claude Code vs.
Cursor mechanical fact and only adds behavioral notes on top of it. Where a fact lives in that
file, this appendix cites it by section rather than restating its tables; go there first if a
detail below seems incomplete.

## Session and turn commands

Cursor's context-clearing and context-inspection commands are distinct from Claude Code's, not
aliases of the same names. See `skills/cursor-projection/references/harness-matrix.md`'s "Context compaction /
summarization" section for the manual-trigger command (`/summarize`, alias `/compress`, no
documented arguments) and how it compares to Claude Code's `/compact`, including the open
question of whether either harness's global instruction file survives the operation. The same
file's "Verifying an artifact loaded" section covers how to check what's currently loaded in
Cursor (Customize > Rules / Customize > Skills panels) since Cursor has no `/context`-equivalent
slash command documented there.

The full cross-harness table of every session and turn command from Chapters 2 through 6, mapped
side by side for both harnesses, lives in this guide's own
[Appendix D](appendix-d-cheat-sheet.md); it is not duplicated here.

## Delegation: subagents and forks

Chapter 3's subagent-vs-fork distinction (`../03-delegation-subagents-and-verbose-output.md`)
maps onto Cursor's own subagent frontmatter, which is dual-read from `~/.claude/agents/` but not
field-for-field identical to Claude Code's. See `skills/cursor-projection/references/harness-matrix.md`'s "Subagents:
content portability" section for the full field table; the fields that matter most for isolating
work on Cursor are `readonly` (a Cursor-only flag with no Claude Code equivalent) and
`is_background` (same), alongside `model`, which Cursor accepts as its own model ID or `inherit`
rather than Claude Code's `opus`/`sonnet`/`haiku` aliases.

The one behavioral note worth internalizing before relying on a Cursor subagent's `model:` field
for a tier-sensitive dispatch, rather than just looking up the field, lives in that file's "Model
tiers" section: the requested model is best-effort there, not a guarantee, in circumstances that
section spells out. A dispatch that assumes a specific tier landed can be silently wrong on
Cursor in a way it would not be on Claude Code; use `inherit` when the parent session already
runs at the right tier instead of naming one explicitly, and if a required tier cannot be
confirmed, stop and ask rather than assume it was honored.

Whole-skill fork isolation (`context: fork` plus `agent:`) has no Cursor equivalent at all: per
the same file's "Skills: content portability" section, Cursor always runs a skill inline
regardless of those fields. Any skill that depends on the fork for isolation needs an explicit
subagent dispatch written into its body for the Cursor path, not just a frontmatter field, or
that isolation quietly disappears under Cursor.

## Rule scoping

Cursor's project-rule mechanism is `.cursor/rules/*.mdc` files, and each one supports a
`description`, `globs`, and `alwaysApply` field that together control when it loads. A rule with
`alwaysApply: true` is injected into every conversation's context on every turn, exactly like a
project-root instruction file; a rule scoped by `globs` (file-pattern matching) or left with only
a `description` loads conditionally, only when the current file or task actually matches it.

This is the Cursor-specific version of Chapter 4's keep-the-always-loaded-file-small habit
(`../04-configuration-hygiene.md`): preferring `globs`/`description` scoping over a blanket
`alwaysApply: true` keeps a rule's cost conditional on relevance instead of billing it against
every turn regardless of whether it applies. The same tradeoff Chapter 4 describes for a bloated
CLAUDE.md applies rule-by-rule here, just with an explicit per-file switch instead of one
all-or-nothing file.

For the mechanics of how Cursor discovers and reads these rules at the project versus global
level, including that Cursor also reads a root `AGENTS.md` and root `CLAUDE.md` natively at the
project scope, and that global rules have no file-based delivery path on Cursor at all, see
`skills/cursor-projection/references/harness-matrix.md`'s "Instructions delivery" section.

## Cursor's own account/pool structure

Grounding Chapter 1's limit-shape taxonomy (`../01-know-your-limit-type.md`) in Cursor
specifically: Cursor is understood to route requests between a cheaper first-party model pool and
a separately billed pool for third-party API models, with individual plans drawing against credit
pools that allow overage rather than stopping outright once a threshold is crossed. This guide has
not independently verified that pooling/overage mechanism against a live Cursor source this
session, so treat it as directionally useful rather than confirmed.

That shape, a threshold that triggers billing consequences or a warning rather than a hard block,
is a concrete instance of Chapter 1's "metered-with-alerts" limit shape, not its "hard-cap" shape:
the defining trait of hard-cap is that crossing it costs you access, not dollars, and Cursor's
overage-permitting pool structure is the opposite of that by design. Treat any specific credit
amount, plan name, or price point as something to check on Cursor's own pricing page at the time
you need it rather than something this guide tracks, since those figures move independently of
the mechanism they attach to and this guide has not independently verified a current pricing URL
this session.

## Hooks and status line

Cursor's hook configuration lives in a separate file with different event names, payload shape,
and control-signal convention from Claude Code's; see `skills/cursor-projection/references/harness-matrix.md`'s "Hooks"
section for the concrete mapping, including the file-edit event (`afterFileEdit`, preferred over
the more generic `postToolUse`), the end-of-loop event (`stop`, firing per agent loop rather than
once per session, so Chapter 4's hook-cost-awareness habit still applies), and the pre-command
event (`preToolUse` matched on `Shell`, not `beforeShellExecution`, since only the former carries
a field to rewrite the command). Cursor hooks signal control decisions via JSON on stdout rather
than an exit code, and fail open by default unless a hook entry explicitly sets `failClosed: true`.

Cursor's status line uses the same `statusLine` config-key shape as Claude Code (a `type:
"command"` entry pointing at a script) but a different config file (`~/.cursor/cli-config.json`,
global only) and an undocumented payload schema with different field names, derived empirically
rather than from published docs. See the same file's "Status line" section before assuming a
Claude Code status-line script can be copied over as-is: field names differ, there is no
confirmed cost or rate-limit equivalent in the Cursor payload, and a custom Cursor status line
replaces the entire native footer rather than adding alongside it, so anything from that footer
still wanted has to be recreated in the script.

## References

- `skills/cursor-projection/references/harness-matrix.md` - single source of truth for the Claude Code vs. Cursor
  mechanical facts cited throughout this appendix (session/context commands, subagent and skill
  frontmatter portability, model-tier overrides, instructions delivery, hooks, and status line).
