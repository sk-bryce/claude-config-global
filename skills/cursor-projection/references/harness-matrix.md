---
created: 2026-07-24
updated: 2026-08-31
---

# Harness Compatibility Matrix

The single source of truth for mapping each artifact type and capability to concrete
harness behavior. This configuration is used with two harnesses today, Claude Code and Cursor,
and they share this `~/.claude` tree because Cursor natively reads several `~/.claude`
locations for compatibility. Every other spec, skill, and reference in this repository should
point here instead of carrying its own harness facts, so the facts live in exactly one place.

Treat exact field names, event names, and paths below as intent to verify against current docs,
not a frozen API. Both harnesses change quickly. Items known to need re-checking are marked
`(verify)`. Add a column for any third harness this config is later used with, rather than
forking this table.

## The short version

- **Free dual-read:** skills in `~/.claude/skills/` and subagents in `~/.claude/agents/` are
  read by both harnesses with no symlink or copy. Keep authoring them there.
- **The one real gap:** global always-on instructions. Claude reads `~/.claude/CLAUDE.md`;
  Cursor does not read anything under `~/.claude` as global rules. See Instructions delivery.
- **Also unconfirmed:** whether global instructions survive compaction/summarization once
  delivered. Claude Code confirms project-root CLAUDE.md reload, not user-scope; Cursor confirms
  neither. See Context compaction / summarization.
- **Generate separately (no shared schema):** hooks and settings/permissions.
- **Copy-portable:** MCP server definitions (same `mcpServers` shape, different file paths).
- **Content, not just location, must be neutral:** a file both harnesses can find can still
  carry frontmatter, model names, tokens, or tool names only one of them understands. See the
  per-artifact portability sections.

## Discovery locations

### User / global scope

| Artifact | Claude Code | Cursor | Dual-read at `~/.claude`? |
| --- | --- | --- | --- |
| Skills | `~/.claude/skills/` | `~/.agents/skills/`, `~/.cursor/skills/`, plus compat `~/.claude/skills/`, `~/.codex/skills/` | Yes |
| Subagents | `~/.claude/agents/` | `~/.cursor/agents/`, plus compat `~/.claude/agents/`, `~/.codex/agents/` | Yes |
| Global instructions | `~/.claude/CLAUDE.md` | User Rules (Settings UI, cloud-synced); no file under `~/.claude` is read | No |
| Hooks | `~/.claude/settings.json` (`hooks`) | `~/.cursor/hooks.json` | No |
| Settings / permissions | `~/.claude/settings.json` | `~/.cursor/cli-config.json` | No |
| MCP servers | `~/.claude.json` | `~/.cursor/mcp.json` (verify path) | No |
| Plans | `plansDirectory` (default `${CLAUDE_CONFIG_DIR:-~/.claude}/plans`) | `~/.cursor/plans` (not configurable) | No |
| Commands | `~/.claude/commands/` | superseded by skills in Cursor; `~/.cursor/commands/` (verify) | Prefer skills |

### Project scope

| Artifact | Claude Code | Cursor |
| --- | --- | --- |
| Skills | `.claude/skills/` | `.agents/skills/`, `.cursor/skills/`, plus compat `.claude/skills/`, `.codex/skills/` |
| Subagents | `.claude/agents/` | `.cursor/agents/`, plus compat `.claude/agents/`, `.codex/agents/` |
| Instructions | `./CLAUDE.md`, `./.claude/CLAUDE.md`, nested, `CLAUDE.local.md` | `AGENTS.md` (root and nested), `CLAUDE.md` (root, applied to every conversation), `.cursor/rules/*.mdc`, legacy `.cursorrules` |
| Hooks | `.claude/settings.json` | `.cursor/hooks.json` |
| Settings | `.claude/settings.json`, `.claude/settings.local.json` | `.cursor/cli.json` (permissions only) |
| MCP | `.mcp.json` or `.claude/mcp.json` | `.cursor/mcp.json` |

## Instructions delivery (the one real gap)

Claude reads global rules directly from `~/.claude/CLAUDE.md`.

Cursor reads no file under `~/.claude` as global rules. Its only reliable global mechanism is
User Rules in the Settings UI, which is cloud-synced and cannot be installed from a committed
file. Deliver global rules to Cursor by generating a paste-able blob and pasting it by hand into
Settings > Rules > User Rules; nothing stores a copy of it. An undocumented
`~/.cursor/rules/` path has been reported to work in some Cursor surfaces but is not official;
do not rely on it.

At the project level Cursor reads both `AGENTS.md` (root and nested) and a root `CLAUDE.md`
natively, so per-project rules need no bridge.

Because Cursor silently drops rules it cannot deliver globally, keep `CLAUDE.md` content split
into a harness-neutral core and any harness-specific notes clearly marked (for example the
model-alias guidance in the Subagents and Models section is Claude-only; see Model tiers below).

## Context compaction / summarization

| Concern | Claude Code | Cursor |
| --- | --- | --- |
| Name | Compaction | Summarization |
| Automatic trigger | Yes, near the context limit (`docs/en/context-window`) | Yes, near the context limit (Cursor Changelog 1.6) |
| Manual trigger | `/compact`, optionally `/compact focus on <text>` | `/summarize` (alias `/compress`), no documented arguments |
| Instruction file survival | Documented: project-root `CLAUDE.md` and unscoped rules are re-injected from disk (`docs/en/context-window#what-survives-compaction`); user-scope `~/.claude/CLAUDE.md` is not named either way (verify) | Undocumented either way. Cursor's Rules docs say User Rules are "included at the start of the model context" but say nothing about surviving summarization - do not assume immunity (verify) |
| Shaping what's preserved | Documented: a `## Compact Instructions` section in CLAUDE.md, per `docs/en/how-claude-code-works#when-context-fills-up` | Not documented. A "customize summarization" request is an open, unresolved community-forum thread as of 2026-07-30 (verify) |
| Verification pattern | No official pattern; this repo's own canary convention (`CLAUDE.md`'s Canary section) fills the gap | No official pattern found either |
| Threshold tuning | `CLAUDE_CODE_AUTO_COMPACT_WINDOW` sets the token capacity auto-compaction math is based on, defaulting to the model's context window (200K standard, 1M extended) except on Sonnet 5, which has its own default; setting it also decouples the compaction threshold from the status line's used-percentage, which always reflects the full window regardless of this variable. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` sets what percentage (1-100) of that window triggers compaction and can only lower the threshold, never raise it above default - but it only causes *earlier* compaction when Claude Code was already going to compact proactively (before the hard context limit) in the first place: when `CLAUDE_CODE_AUTO_COMPACT_WINDOW` is set, in cloud sessions, on Sonnet 4.6/Opus 4.6 without extended context (which proactively compact at the 200K boundary by default), or at Sonnet 5's own default threshold. A local session on a model outside those cases (for example Opus 4.8) instead compacts only once the conversation reaches the model's hard context limit, where the override has no effect. Both variables apply to subagents as well as the main conversation (`docs/en/env-vars`) | No known equivalent (verify) |

Consequence for this repo's shared config: `CLAUDE.md`'s `## Compact Instructions` heading name is
a Claude Code-recognized convention (see the row above) with no confirmed Cursor equivalent, so
`cursor-user-rules.md`'s projection retitled that section to `## Context Preservation` rather than
projecting the heading verbatim, since Cursor has no documented hook tied to that name - but the
canary-reconfirm behavior and the Preserve/Discard priorities are harness-neutral in intent and
still project, arguably with more justification on the Cursor side: Cursor's docs don't even
partially confirm User Rules survive summarization, unlike Claude Code's confirmed (if
scope-ambiguous) project-root guarantee. See
`decisions/0006-global-config-compaction-verification.md`.

## Skills: content portability

Location is dual-read, but frontmatter and body content are not fully portable.

### Frontmatter

| Field | Claude Code | Cursor |
| --- | --- | --- |
| `name`, `description` | Yes | Yes |
| `disable-model-invocation` | Yes | Yes |
| `model` | Yes (`opus`/`sonnet`/`haiku`) | Ignored - Cursor skills cannot pin a turn model |
| `context: fork` + `agent:` | Yes | Ignored - isolate via a Cursor subagent instead |
| `user-invocable` | Yes | Ignored |
| `allowed-tools` / `disallowed-tools` | Yes | Ignored |
| `hooks`, `arguments` | Yes | Ignored |
| `paths` | Ignored | Yes (file scoping; legacy `globs` accepted) |
| `metadata` | Ignored | Yes |

### Body assumptions to neutralize

- **Model pin is Claude-only.** A guarantee like "run this on Sonnet" cannot come from `model:`
  under Cursor. Move it into the body as a dispatch to a tier-named subagent (see Model tiers),
  or accept that Cursor runs the skill turn on the session model.
- **Whole-skill fork isolation differs.** `context: fork` (with `agent:` and `background:`) is
  Claude-only; Cursor always runs the skill inline regardless of these fields, so a skill that
  relies on the fork for isolation needs an equivalent manual dispatch in the body for Cursor to
  keep any isolation at all - do not remove that manual dispatch just because Claude Code also
  forks the whole skill (see `skills/review-md/SKILL.md`'s "Do the review with a subagent" note
  for the pattern). `agent:` names a read-only agent (for example `Explore`) for pure research
  isolation, or a read/write one (`general-purpose`) when the forked run itself needs to edit
  files, as `review-md` and `execute-plan` (EXPERIMENTAL, see `specs/behaviors.md`) both do.
  `context: fork` dispatches cold: the forked agent's starting prompt is synthesized from the
  invocation line, not the full prior conversation, so only pin it on skills whose work is
  fully specified by their trigger and arguments.
- **Read-only or tool guards differ.** `allowed-tools`/`disallowed-tools` do not apply under
  Cursor; enforce equivalent constraints in the body or via a Cursor `readonly` subagent.
- **Create-path tooling differs.** Claude hands off to the `skill-creator` plugin; Cursor uses
  the built-in `/create-skill`. Any authoring skill must branch on the target.
- **Substitution tokens and tool names differ.** See the two sections below.
- **Claude platform specifics** (description budget: 1% of context or 8,000-char fallback,
  1,536-char per description; `/doctor`, `/context`, `/reload-skills`; bundled-skill list) come
  from `docs/features/skills.md` and apply to Claude only. Cursor surfaces skills in
  Customize > Skills and has its own limits (verify); do not assert Claude's numbers for Cursor.

## Subagents: content portability

`~/.claude/agents/` is dual-read, which makes subagents the cheapest cross-harness primitive.
Frontmatter still differs.

| Field | Claude Code | Cursor |
| --- | --- | --- |
| `name`, `description` | Yes | Yes |
| `model` | Yes (`opus`/`sonnet`/`haiku`) | Yes (Cursor model ID or `inherit`) - different value space |
| `tools` (allow-list) | Yes | Ignored |
| `disallowedTools` (deny-list) | Yes (ignored if `tools` is set) | Ignored (verify) |
| `effort` | Yes (`low`/`medium`/`high`/`xhigh`/`max`, or an integer) | Ignored (verify) |
| `readonly` | Ignored | Yes |
| `is_background` | Ignored | Yes - confirmed broken in CLI/ACP as of 2026-08, see note below |

Author the shared `name`/`description` core, then add harness-specific fields knowingly. Values
for `model` are not interchangeable; see Model tiers.

Claude Code also accepts `color`, `permissionMode`, `mcpServers`, `hooks`, `maxTurns`, and
`skills` on a subagent; treat all of them as Claude-only until verified on Cursor. Fields each
harness ignores are inert rather than invalid, so one file can carry both sides: pairing
`tools:` with `readonly: true` is the portable way to express a read-only subagent, since Claude
enforces the allow-list and Cursor enforces the flag.

`is_background` is confirmed broken as of 2026-08 for the Cursor CLI this repo targets (and for
ACP integration too): a Cursor team member confirmed on the community forum that
`is_background: true` "currently works properly in the IDE, but in CLI/ACP mode background
subagents still behave like blocking." The dispatching agent waits for it to finish either way,
despite the flag, so there is no concurrent-progress benefit to it in this harness right now, and
correspondingly no confirmed way for a Cursor subagent to pause mid-run and ask a question before
completing regardless of this field. Treat any Cursor subagent dispatch as blocking until this is
fixed upstream; re-check the forum thread or current docs before relying on `is_background` for
anything other than a documentation-level intent.

Confirmed 2026-07-30 against the Claude Code 2.1.220 subagent frontmatter schema. `effort` here
answers the standing question of whether thinking effort can be pinned alongside `model`: on
Claude Code it can, on a subagent definition as well as a skill. Effort support and the specific
levels available are gated per model (`supportsEffort`, `supportedEffortLevels` in the model
catalog); `xhigh` and `max` are further gated behind additional model-specific checks beyond
plain support. Verify a level is listed for the target model before pinning it rather than
assuming `low`-`high` are universal. The session/plan default effort also varies by model version
and subscription tier, so a skill or subagent without an explicit `effort` pin does not have a
fixed, predictable reasoning depth across users or sessions.

A custom subagent whose `name` matches a harness built-in (for example `Explore`, which both
harnesses ship) may shadow or be shadowed by that built-in, and precedence is unverified on both
(verify). Check the Task tool listing per Verifying an artifact loaded before relying on a
same-named override.

## Model tiers

Refer to models by tier: Opus (premium), Sonnet (workhorse), Haiku (fast). Map each tier at
dispatch time.

| Tier | Claude Code | Cursor |
| --- | --- | --- |
| Opus | `opus` alias | a `*-opus-*` model ID from Cursor's model list, else `inherit` |
| Sonnet | `sonnet` alias | a `*-sonnet-*` model ID, else `inherit` |
| Haiku | `haiku` alias | a `*-haiku-*` model ID, else `inherit` |

- Prefer an alias over a frozen version slug unless a plan or the user names one.
- Cursor skills cannot pin a turn model at all; only subagents accept `model:`.
- On Cursor a dispatched subagent's `model:` is best-effort, not a guarantee: it is overridden to
  Composer on legacy request-based plans without Max Mode, and whenever a team admin or the current
  plan blocks the requested model. Use `inherit` when the parent already runs at the right tier.
- If a required tier cannot be launched on a harness, STOP and ask rather than silently
  substituting (matches `subagent-orchestration.md`).

## Substitution tokens and tool names

| Capability | Claude Code | Cursor |
| --- | --- | --- |
| Positional / all args | `$ARGUMENTS`, `$0`, `$1`, `$name` | `$ARGUMENTS` (verify positional/named support) |
| Project root token | `${CLAUDE_PROJECT_DIR}` | `${CURSOR_PROJECT_DIR}` (verify) |
| Skill directory token | `${CLAUDE_SKILL_DIR}` | no confirmed equivalent (verify) |
| Session / effort tokens | `${CLAUDE_SESSION_ID}`, `${CLAUDE_EFFORT}` | Claude-only |
| Dynamic shell injection | `` !`cmd` `` at line start | Claude-only (verify) |
| Read / find files | `Read`, `Glob`, `Grep` | `Read`, `Glob`, `Grep` |
| Run shell | `Bash` | `Shell` |
| Read diagnostics | run linter via `Bash` | `ReadLints` where available, else run linter via `Shell` |
| Read/write worker subagent | `Task`/`Agent`, `subagent_type: general-purpose` | `Task`, `subagent_type: generalPurpose` |
| Read-only worker subagent | `Task`/`Agent`, `subagent_type: Explore` | built-in `Explore` subagent, or a custom subagent with `readonly: true`; else `generalPurpose` constrained read-only in the prompt |
| Ask the user | `AskUserQuestion` | `AskQuestion` |
| Progress tracking | `TodoWrite` | `TodoWrite` |

## Hooks

Both run subprocess hooks configured in JSON, but event names, payload shape, and control
signal differ, so registrations are generated separately from a shared script.

| Concern | Claude Code | Cursor |
| --- | --- | --- |
| Config file | `settings.json` `hooks` | `hooks.json` |
| File-edit event | `PostToolUse` with `matcher: "Write\|Edit"` | `afterFileEdit` (confirmed 2026-07-27 against Cursor's hooks docs). Cursor also has a generic `postToolUse` (confirmed 2026-07-31), but `afterFileEdit` stays preferred here: it hands over `file_path` directly instead of requiring a tool-name filter |
| End-of-agent-loop event | `Stop` (no matcher) | `stop` (confirmed 2026-07-31 against Cursor's hooks docs), payload `status` (`completed`/`aborted`/`error`) and `loop_count`. Fires per agent loop on both harnesses, not once per session - work registered here is charged per turn |
| Pre-command/rewrite event | `PreToolUse` with `matcher: "Bash"` | `preToolUse` with `matcher: "Shell"` (confirmed 2026-07-31 against Cursor's hooks docs) - not `beforeShellExecution`: that event's response is allow/deny/ask only (`permission`), with no field to rewrite the command |
| Command-rewrite response field | `hookSpecificOutput.updatedInput.command` | `updated_input.command` (confirmed 2026-07-31 against Cursor's hooks docs) |
| Control signal | exit code (and JSON for some events) | JSON on stdout (for example `permission: deny`); malformed JSON, a crash, or a timeout fails open by default (`failClosed: false`) unless the hook entry sets `failClosed: true` |
| Session id | `session_id` | `conversation_id` |
| Working dir | `cwd`, `CLAUDE_PROJECT_ROOT` | `workspace_roots[]`, `CURSOR_PROJECT_DIR` |
| Changed-file path | `.tool_input.file_path` / `.tool_response.filePath` | `file_path` (confirmed 2026-07-27 against Cursor's hooks docs) |
| Matcher form | string | string, e.g. `"Shell\|Read\|Write"` (confirmed 2026-07-31 against Cursor's hooks docs; corrects a prior "object" claim here) |

Pattern: put the real logic in `scripts/<name>.sh` and register it in both places with thin
wrappers - one normalizing the changed-file path for the file-edit event, one selecting the
response shape via a `claude`/`cursor` positional argument for the pre-command event.
`scripts/filter-verbose-output.sh` plus `scripts/sync.sh`'s `sync_cursor_hooks` are the reference
implementation of the pre-command pairing (`PreToolUse`/`Bash` on Claude Code, `preToolUse`/`Shell`
on Cursor). The markdownlint and link-recheck hooks in `settings.json` already have their
`hooks.json` twin generated the same way for the file-edit event.

## Settings and permissions

No shared schema. Generate each separately.

- Claude: `settings.json` holds `model`, `effortLevel`, `env`, `hooks`, `theme`. Fields like
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` and the `model` alias are Claude-only.
- Cursor: `~/.cursor/cli-config.json` holds `permissions.allow`/`deny`, `approvalMode`,
  `editor.vimMode`, and display options; only permissions are settable per project
  (`.cursor/cli.json`).

## MCP servers

Copy-portable. Both use a top-level `mcpServers` object keyed by server name with
`command`/`args`/`env`. A server block copies verbatim between harnesses in most cases;
exceptions are servers that depend on a specific working directory or host-only env var.

- Claude: `~/.claude.json` (global, mixed with other keys - do not symlink the whole file) and
  `.mcp.json` (project).
- Cursor: `~/.cursor/mcp.json` (global) and `.cursor/mcp.json` (project).
- At the project level, symlinking `.mcp.json` to `.cursor/mcp.json` is safe when the server set
  is identical.

## Plans

Already harness-aware in `subagent-orchestration.md` and the `write-plan`/`execute-plan` skills.
Claude uses `plansDirectory` (default `${CLAUDE_CONFIG_DIR:-~/.claude}/plans`); Cursor uses
`~/.cursor/plans`, which is not configurable. A plan made through a native plan mode and one made
through the skill can therefore land in different places; the skill's own resolution is the
authority.

## Status line

A `statusLine` config key on both harnesses runs a `type: "command"` shell script and renders its
stdout above the prompt. The shape of that config key is the same on both; the JSON payload piped
to the script's stdin is not.

| Concern | Claude Code | Cursor |
| --- | --- | --- |
| Config file | `settings.json` | `~/.cursor/cli-config.json` (global; no project-level override found) |
| Config key shape | `{"type": "command", "command": "<path>"}` | `{"type": "command", "command": "<path>", "padding": <int>, "updateIntervalMs": <int>, "timeoutMs": <int>}` - the three extra fields were already present in a live config (confirmed 2026-07-31) with no documented defaults, so `scripts/sync.sh`'s `sync_cursor_statusline` only enforces `type`/`command` and leaves them alone |
| Registration | hand-edit `settings.json` (human step per `decisions/0003-hooks-and-scripts-authoring-policy.md`) | `/statusline` slash command, or hand-edit `cli-config.json` (same human-step rule applies - see `sync_cursor_statusline`) |
| Payload docs | Documented: `code.claude.com/docs/en/statusline` (see `scripts/statusline.sh`'s header for the exact fields this repo relies on) | Undocumented (confirmed 2026-07-31: `cursor.com/docs/cli/reference/configuration` documents only the unrelated `display.showStatusLineRunningTime` setting, not the payload shape). Confirmed instead against two captured real payloads (one idle, one after a real turn) - see `scripts/statusline-cursor.sh`'s header for the full confirmed field list |
| Payload field names | `model.display_name`, `context_window.total_input_tokens`, `context_window.used_percentage`, `context_window.current_usage.cache_read_input_tokens`, `cost.total_cost_usd`, `rate_limits.*`, `effort.level`, `thinking.enabled`, etc. | Confirmed real fields (2026-07-31 capture): `model.display_name`, `model.param_summary`, `cwd`, `autorun` (boolean), `workspace.{current_dir,project_dir,added_dirs}`, `version`, `session_name`, `output_style.name`, `context_window.{total_input_tokens,total_output_tokens,context_window_size,used_percentage,remaining_percentage}`, and `context_window.current_usage.{input_tokens,output_tokens,cache_creation_input_tokens,cache_read_input_tokens}`. No `cost`, `rate_limits`, `effort`, or `thinking` field of any kind was present in either capture - Cursor's statusLine has no observed equivalent for cost, rate limits, or reasoning-effort level. `model.max_mode` (assumed by a pre-existing, pre-capture version of this script) was not observed in either capture, both of which were non-Max-Mode sessions - `(verify)` whether it exists at all |
| Schema compatible with Claude Code's? | - | Partially, and more than first assumed: `context_window.current_usage.{cache_read_input_tokens,cache_creation_input_tokens}` use the exact same names as Claude Code, confirming the "compatible with Claude's implementation" claim from a 2026-07 community forum report for that sub-schema. It is not compatible overall, though: no cost/rate-limit/effort/thinking equivalent exists, and `model.param_summary`/`cwd`/`autorun`/`workspace.*` have no Claude Code counterpart. This repo still uses two separate scripts rather than one shared one, since enough of the schema differs (and because Claude Code's own fields are also frequently absent early in a session) that a single script would need near-identical conditional-degradation logic for two different payload shapes anyway |
| Replaces or adds to the native footer? | N/A (no separate native footer) | Replaces the entire native footer (model/context, auto-review state, working directory, branch, PR indicators) rather than adding alongside it - there is no append/prepend mode (confirmed via forum report 2026-07; not independently re-verified against current Cursor CLI behavior). `scripts/statusline-cursor.sh` recreates working directory (`.cwd`) and git branch (derived via a `git` call, since no branch field exists in the payload) directly; it approximates approval-mode state from `.autorun` (a boolean, coarser than the native footer's "Allowlist"/"Auto-review" distinction per the same forum report); it cannot recreate a PR indicator at all, since no PR data is in the payload and adding a `gh` network call on every render (Cursor's `updateIntervalMs` can be sub-second) is not worth the latency |

## Verifying an artifact loaded

| Check | Claude Code | Cursor |
| --- | --- | --- |
| Instructions loaded | `/context`, `/memory`, `InstructionsLoaded` hook | Customize > Rules panel |
| Skills discovered | `/context`, `/doctor`, `/reload-skills` | Customize > Skills panel |
| Subagents discovered | subagent appears in the Task tool list | subagent appears in the Task tool list |

## Notes for consumers

- Point at this file for any harness fact; do not restate the tables elsewhere. Duplication is
  what `context-file-authoring.md` warns against, and the copies will drift.
- When a fact is marked `(verify)`, confirm it against the current docs before relying on it in a
  generated artifact, and update this file when you do.
- When adding a third harness, add a column here rather than special-casing it in each consumer.

## References

### Official Documentation

- [Agent Skills](https://cursor.com/docs/skills) - Cursor; skill discovery directories (including compat reads of `~/.claude/skills`), SKILL.md frontmatter fields, and built-in skills.
- [Subagents](https://cursor.com/docs/subagents) - Cursor; subagent directories (including compat reads of `~/.claude/agents`), frontmatter fields, and model configuration.
- [Rules](https://cursor.com/docs/rules) - Cursor; Project Rules, User Rules, and native reading of `AGENTS.md` and `CLAUDE.md` at the project level.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) - Anthropic; CLAUDE.md loading order, `@AGENTS.md` import, and that Claude Code does not read `AGENTS.md` natively.
- [The .claude directory](https://code.claude.com/docs/en/claude-directory) - Anthropic; where Claude Code reads settings, skills, subagents, commands, and hooks at project and user scope.
- [Explore the context window](https://code.claude.com/docs/en/context-window) - Anthropic; the compaction survival table and the `## Compact Instructions` / `/compact focus` mechanisms cited in Context compaction / summarization.
- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up) - Anthropic; documents the `## Compact Instructions` mechanism cited in Context compaction / summarization.
- [Environment variables](https://code.claude.com/docs/en/env-vars) - Anthropic; `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` defaults, valid ranges, the lower-only threshold behavior, and the specific conditions under which proactive (pre-limit) compaction happens at all, cited in the Threshold tuning row of Context compaction / summarization.
- [Statusline](https://code.claude.com/docs/en/statusline) - Anthropic; the payload schema `scripts/statusline.sh` relies on, cited in Status line.
- [Configuration](https://cursor.com/docs/cli/reference/configuration) - Cursor; documents `cli-config.json` fields including `display.showStatusLineRunningTime`, but not the `statusLine` payload shape, cited in Status line.
- [Cursor CLI custom statusLine replaces native footer and cannot preserve Auto-review state](https://forum.cursor.com/t/cursor-cli-custom-statusline-replaces-native-footer-and-cannot-preserve-auto-review-state/166364) - Cursor Community Forum; source for the footer-replacement behavior and the `cli-config.json` `statusLine` shape cited in Status line.
- [Configurable Status Lines in Cursor Agent](https://forum.cursor.com/t/configurable-status-lines-in-cursor-agent/152287) - Cursor Community Forum; source for the "compatible with Claude's implementation" claim that Status line notes as confirmed true only for the `current_usage` cache-token sub-schema, not the payload as a whole.
- [Cursor Changelog 1.6](https://cursor.com/changelog/1-6) - Cursor; confirms automatic conversation summarization near the context limit.
- [Cursor CLI Slash Commands](https://cursor.com/docs/cli/reference/slash-commands) - Cursor; documents `/summarize` and its `/compress` alias.
- [Does cursor acp support subagent run in background?](https://forum.cursor.com/t/does-cursor-acp-support-subagent-run-in-background/156649) - Cursor Community Forum; a Cursor team member confirms `is_background: true` works in the IDE but still blocks in CLI/ACP mode, cited in the Subagents: content portability section.

### Further Local Reading

- `reference/subagent-orchestration.md` - the original per-capability harness mapping this file generalizes.
- `reference/context-file-authoring.md` - CLAUDE.md and AGENTS.md loader mechanics and the do-not-duplicate rule.
- `docs/features/skills.md` - the Claude-specific skill facts (budgets, tokens, bundled skills) that are Claude-only here.
