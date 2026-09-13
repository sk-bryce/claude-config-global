---
audience: human
created: 2026-07-31
updated: 2026-08-31
---

# Appendix D: Cross-Harness Cheat Sheet

This is a fast-lookup companion, not a new source of truth. Every fact below either restates
`skills/cursor-projection/references/harness-matrix.md` (the authoritative mapping of Claude Code vs. Cursor mechanics,
organized by concern) or was independently confirmed by fetching the linked official docs this
session (see References). Where a fact carries a `(verify)` caveat in `harness-matrix.md`, that
caveat is carried forward here rather than presented as settled. Each row also names the chapter
of this guide (Chapters 2 through 6) the habit belongs to; read that chapter for the "why," not
this table.

| Goal | Claude Code | Cursor |
| --- | --- | --- |
| **Start clean for unrelated work** (Chapter 2) | `/clear` (aliases `/reset`, `/new`) starts a new conversation with empty context; the previous conversation is saved and resumable with `/resume`. | `/clear` (aliases `/new`, `/new-chat`, `/newchat`) starts a new chat session. |
| **Label a session, then return to it later** (Chapter 2) | Name at startup with `claude -n <name>`, or mid-session with `/rename <name>`. Return with `claude --resume <name>` or `/resume <name>`, or run `/resume` with no argument to open the session picker. | `/rename <name>` renames the current chat session. `/resume` opens recent chats so you can resume one. |
| **Shrink a long conversation with focus instructions** (Chapter 2) | `/compact [instructions]` replaces history with a summary, optionally focused on what you specify (`skills/cursor-projection/references/harness-matrix.md`'s Context compaction / summarization section). | `/summarize` (alias `/compress`) reduces context by summarizing the conversation; no documented argument for focusing it the way `/compact` takes one (`skills/cursor-projection/references/harness-matrix.md`, same section). |
| **See what is filling context / inspect usage and cost** (Chapters 2, 6) | `/context [all]` visualizes current context usage as a colored grid. `/cost` (alias `/usage`) reports spend. The status line can also surface both live (`skills/cursor-projection/references/harness-matrix.md`'s Status line section documents the payload fields, e.g. `context_window.used_percentage`, `cost.total_cost_usd`). | No `/context`- or `/cost`/`/usage`-equivalent slash command was found in Cursor's CLI reference this session. Check the status line's `context_window.used_percentage` field, or the Cursor dashboard, for the closest equivalents; `skills/cursor-projection/references/harness-matrix.md`'s Status line section notes no cost or rate-limit equivalent has been observed in Cursor's payload (verify). |
| **Change model** (Chapter 5) | `/model [model]` switches the active model and saves it as your default; no argument opens a picker. Map tiers via the `opus`/`sonnet`/`haiku` aliases (`skills/cursor-projection/references/harness-matrix.md`'s Model tiers section). | `/model [filter]` selects a model, filtered by the text you pass; press Tab to edit. Map tiers to a `*-opus-*`/`*-sonnet-*`/`*-haiku-*` model ID, or `inherit`, per the same Model tiers section - and note a subagent's requested model is best-effort there, not a guarantee (`skills/cursor-projection/references/harness-matrix.md`). |
| **Change reasoning effort** (Chapter 5) | `/effort [level\|auto]` sets the model effort level (`low`, `medium`, `high`, `xhigh`, `max`, or the Claude Code-specific `ultracode` workflow-orchestration setting); the `/model` picker also exposes an effort slider via the left/right arrow keys. Levels are gated per model - verify a level is actually listed for the target model before pinning it (`skills/cursor-projection/references/harness-matrix.md`'s Subagents: content portability section). | No dedicated slash command for reasoning effort was found in Cursor's CLI reference this session. `/max-mode` toggles Max Mode (more reasoning/context) but only on legacy request-based plans, and `skills/cursor-projection/references/harness-matrix.md`'s Subagents: content portability table marks a subagent's `effort` field as "Ignored (verify)" on Cursor - treat effort tuning as currently Claude-only (verify). |
| **Dispatch a subagent for a self-contained side task** (Chapter 3) | `Task`/`Agent` tool with `subagent_type: general-purpose` for a read/write worker, or `subagent_type: Explore` for a read-only one (`skills/cursor-projection/references/harness-matrix.md`'s Substitution tokens and tool names section). | `Task` tool with `subagent_type: generalPurpose`, or the built-in `Explore` subagent, or a custom subagent with `readonly: true` for read-only work (`skills/cursor-projection/references/harness-matrix.md`, same section). |
| **Continue in a fork or side-thread that needs the current conversation's context** (Chapter 3) | `/fork [prompt]` copies the conversation into a new background session while you keep working in the original. `/branch [name]` copies the conversation and switches you into the copy, leaving the original intact in the session picker. | `/fork` forks the current chat into a new session. |
| **Undo or roll back a wrong direction** (Chapter 2) | `/rewind` rolls code and conversation back to a checkpoint (or can instead summarize part of the conversation). | `/rewind` jumps back to a previous message. |
| **Enter a read-only or plan-only mode for an exploratory question** (Chapter 2) | Press `Shift+Tab` to cycle the permission mode to `plan` (research and explore; no edits until you approve a plan), or prefix a single prompt with `/plan`. Press `Shift+Tab` again to leave without approving. | `/plan [prompt]` switches to Plan mode (also reachable via `Shift+Tab` in the chat UI), which researches and drafts a plan before writing any code. `/ask` toggles a dedicated read-only Ask mode for questions that shouldn't touch files at all. |
| **Run a cheap, lower-tier review pass over a diff** (Chapter 3) | `/code-review [low\|medium\|high\|xhigh\|max\|ultra] [--fix] [--comment] [target]` reviews the current diff at an explicitly chosen effort tier. | No dedicated review slash command was found in Cursor's CLI reference this session (verify). The documented pattern instead is a subagent dispatch (`Task`, `subagent_type: generalPurpose` or a `readonly` custom subagent) with `model:` pinned to a cheap tier, per the Model tiers section of `skills/cursor-projection/references/harness-matrix.md`. |

For anything not in this table, treat `skills/cursor-projection/references/harness-matrix.md` as authoritative: it covers
discovery locations, compaction survival, full subagent and skill frontmatter, hooks, settings,
MCP, plans, and the status line in depth, organized by concern rather than by goal.

## References

### Official Documentation

- [Manage sessions](https://code.claude.com/docs/en/sessions.md) - Anthropic; `/rename`, `/resume`, `/branch`, `--fork-session`, `/clear`, `/compact`, and `/context`, confirmed live this session.
- [Slash commands](https://code.claude.com/docs/en/commands.md) - Anthropic; the full Claude Code slash command list, confirmed live this session for `/clear`, `/model`, `/effort`, `/cost` (alias of `/usage`), `/context`, `/fork`, `/branch`, `/rewind`, and `/code-review`.
- [Model configuration](https://code.claude.com/docs/en/model-config.md) - Anthropic; effort levels, the `/effort` command syntax, and the `ultracode` setting, confirmed live this session.
- [Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md) - Anthropic; Plan mode entry (`Shift+Tab`, `/plan`) and exit, confirmed live this session.
- [Cursor CLI Slash Commands](https://cursor.com/docs/cli/reference/slash-commands) - Cursor; the full Cursor CLI slash command list, confirmed live this session for `/clear`, `/rename`, `/resume`, `/model`, `/plan`, `/ask`, `/fork`, `/rewind`, `/summarize`, and `/max-mode`.
- [Agent modes](https://cursor.com/docs/agent/modes) - Cursor; Plan Mode's behavior and entry points, confirmed live this session.

### Further Local Reading

- `skills/cursor-projection/references/harness-matrix.md` - the authoritative cross-harness mechanical facts this table is a lookup companion to; consult it directly for anything beyond the goals listed above.
