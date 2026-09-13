---
audience: human
created: 2026-07-31
updated: 2026-09-02
---

# Appendix A: Claude Code Specifics

This appendix assumes `skills/cursor-projection/references/harness-matrix.md` as authoritative
for Claude Code mechanical facts and does not restate its tables. It only adds behavioral notes,
gotchas, and "why this matters for staying inside your account limits" framing on top of what
that file already establishes, organized by the core chapter each note supports.

## 1. Session and turn commands (Chapter 2)

Claude Code separates three actions that are easy to conflate: clearing a session outright,
compacting one with a focus instruction, and inspecting what is currently loaded. `/compact`
(optionally `/compact focus on <text>`) is the manual compaction trigger; see
`skills/cursor-projection/references/harness-matrix.md`'s Context compaction / summarization
section for the mechanics, including that compaction also fires automatically near the context
limit, and that only project-root `CLAUDE.md` and unscoped rules are documented to survive it -
user-scope `~/.claude/CLAUDE.md` survival is not confirmed either way and stays marked `(verify)`
there.

That gap is exactly why a `## Compact Instructions` section and a verification canary earn their
keep: `/compact` is cheaper than starting a new session, but only if what actually matters
(current goal, definition of done, decisions made, in-flight background task IDs) survives the
squeeze. Treat a compaction you cannot verify as a soft reset of anything not explicitly
preserved, not a guaranteed carry-forward.

For inspecting rather than changing state,
`skills/cursor-projection/references/harness-matrix.md`'s Verifying an artifact loaded section
lists `/context` and `/doctor` for confirming what is currently loaded and how much room it is
taking up. Reach for `/context` before deciding whether a compaction or a fresh session is the
right move, rather than guessing from turn count alone.

Two environment variables move *when* automatic compaction fires, as opposed to what survives it:
`skills/cursor-projection/references/harness-matrix.md`'s Context compaction / summarization
section's Threshold tuning row documents `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (the token capacity
the auto-compact percentage is calculated against) and `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (the
percentage of that window which triggers it, lower-only). `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` only
moves anything if Claude Code was already going to compact proactively, before the hard context
limit, in the first place; that row spells out exactly which sessions and models qualify, and
setting it in a plain local session that doesn't is a silent no-op. Where it does apply, a lower
override compacts smaller contexts more often, which only pays for itself when enough turns
remain afterward to amortize the resummarize cost, per this guide's [Appendix C, Section
3.1](../../generative-ai/appendices/appendix-c-costs-and-getting-value.md#31-prompt-and-context-caching)
and its break-even formula. Tune the override with that formula in hand, and only after confirming
it applies to your session, rather than picking a percentage by feel.

The full cross-harness command table (every command above, side by side with its Cursor
equivalent) lives in this guide's own Appendix D (`appendix-d-cheat-sheet.md`); it is not
duplicated here.

## 2. Delegation: subagents and forks (Chapter 3)

`skills/cursor-projection/references/harness-matrix.md`'s "Subagents: content portability"
section is the authoritative list of frontmatter fields a Claude Code subagent definition
accepts, including `model` and `effort`; do not assume it from memory, check that section
directly before authoring one.

The one behavioral note worth internalizing before pinning an `effort` level, rather than just
looking up the field, lives in that same section: which specific levels are available is gated
per model, and the higher levels are gated further still. A pinned level a model does not support
is a silent no-op at best, not a guaranteed downgrade to something close, so verify a level is
actually listed for the target model rather than assuming the full range is universal.

As a concrete worked example of Chapter 3's "build a small reusable set of workers once" habit,
this repository's own `~/.claude/agents/` directory already holds a small, purpose-tiered set:
a read-only researcher for locating things across a tree without touching them, a mechanical
step-executor for carrying out a fully-specified change with no design judgment involved, and a
test/log runner that absorbs verbose command output into its own context instead of the
dispatching agent's. Each is scoped to one job and reused across tasks rather than redesigned per
call - that reuse, not any one worker's specific prompt, is the habit worth copying.

A reusable worker earns its standing description budget only while its job needs a model at all;
once a job reduces to regex work, a script answers it for no per-turn cost and more reliably. So
reach for the smallest mechanism that can answer the question, and revisit that judgment as the
surrounding tooling changes - the three workers above map exactly onto the three distinct shapes
Chapter 3 names, which is the set shape worth keeping.

## 3. Configuration hygiene (Chapter 4)

`skills/cursor-projection/references/harness-matrix.md`'s Settings and permissions section names
where Claude Code's defaults live (`settings.json`, holding `model`, `effortLevel`, `env`,
`hooks`, `theme`) and its Discovery locations tables give the project-vs-user precedence: project
`.claude/settings.json` and `.claude/settings.local.json` sit alongside the user-scope
`~/.claude/settings.json`, with no shared schema against Cursor's equivalent file.

The Hooks section is the concrete mechanism behind Chapter 4's "move expensive per-edit checks to
an end-of-loop event" habit: `PostToolUse` with a matcher like `"Write|Edit"` fires once per
matching tool call, so a check registered there runs on every single edit in a session, while
`Stop` fires once per agent loop with no matcher, regardless of how many edits happened inside
it. A markdown lint or link-check that costs real time is cheap at `Stop` cadence and expensive at
`PostToolUse` cadence for the exact same amount of work done - the event choice, not the check
itself, is what determines how many times it runs.

For visibility into context and cost without spending a turn to ask,
`skills/cursor-projection/references/harness-matrix.md`'s Status line section documents the
config shape (`{"type": "command", "command": "<path>"}` in `settings.json`) and notes that the
payload piped to the script's stdin is Claude Code-specific and documented separately from
Cursor's. A status line is a standing, per-render cost of basically zero against the account
limits this guide is about, which makes it one of the few configuration changes here with no
quality-risk tradeoff to weigh.

## 4. Model and effort tuning (Chapter 5)

The effort-gating fact from Section 2 above applies just as much to a bare turn as to a subagent
definition: whatever effort level a session or plan defaults to when nothing is pinned varies by
model version and subscription tier, so an unpinned turn does not have a fixed, predictable
reasoning depth across users or sessions
(`skills/cursor-projection/references/harness-matrix.md`'s Subagents: content portability
section). Treat "what effort level am I actually running at" as something to check per model,
not something to assume carries over from a different model you tested it on.

For picking the model itself, `skills/cursor-projection/references/harness-matrix.md`'s Model
tiers section gives the concrete guidance: refer to tiers as Opus, Sonnet, Haiku, and on Claude
Code map each to its `opus`/`sonnet`/`haiku` alias rather than a frozen version slug, unless a
plan or the user explicitly names one. An alias tracks whichever model currently backs that tier as Anthropic
updates it; a frozen slug pins you to a specific snapshot that a plan can retire out from under a
skill or subagent definition without anyone noticing until it fails to launch.

There is no interactive way to bump effort for a single task without it persisting. Per
Anthropic's live "Model configuration" docs (see References), the persistence rule for effort is
stated once, with no `s`/Enter carve-out: "`low`, `medium`, `high`, and `xhigh` persist across
sessions when you set them in an interactive session." That sentence covers every interactive
path to those four levels - `/effort <level>`, the bare `/effort` slider, and the effort slider
exposed inside `/model` via left/right arrow keys - since the docs list all three under the same
"Set the effort level" heading with no per-path exception. The `s`-vs-Enter distinction that does
exist in `/model` ("`s`: switch model for this session only") is documented only for the model
field on that row, not for the effort slider next to it.

`/model`'s own stdout echoes "for this session only" wording on the effort change, but the level
does not in fact revert - confirmed 2026-08-04 by running the picker, which matches the plain
reading of the docs above.

Two levels are genuinely session-only regardless of how they're set: `max` ("applies to the
current session only, except when set through the `CLAUDE_CODE_EFFORT_LEVEL` environment
variable") and `ultracode` ("It applies to the current session only"). Neither is a substitute for
a temporary bump on an ordinary `low`/`medium`/`high`/`xhigh` task.

The one path Anthropic documents as both session-only and not requiring a special level is the
`--effort <level>` CLI flag, passed at launch: "Set the effort level for the current session...
Overrides the `effortLevel` setting for this session and does not persist" (`cli-reference` docs,
see References). This only helps when starting a fresh session for the task; there is no
confirmed way to get the same effect mid-session. For a genuinely one-task bump - the case
`reference/model-selection.md`'s Effort section describes - either relaunch with
`claude --effort <level>`, or accept that an interactive bump persists and manually revert it once
the task is done; do not rely on `/model` plus `s` to do the reverting for you.

A single deep-reasoning turn doesn't need any of the above. Including `ultrathink` anywhere in the
prompt text requests more reasoning for that one turn only, with no effect on the session's effort
setting: "Include `ultrathink` anywhere in your prompt to request deeper reasoning on that turn
without changing your session effort setting... The effort level sent to the API is unchanged"
(Model configuration docs, see References). That last clause is the important part - `ultrathink`
doesn't raise the effort level, it adds an in-context instruction asking the model to reason more
within whatever level is already active. It's a prompt-level nudge, not a substitute for actually
running at `high`/`xhigh`/`max` when a task's ceiling genuinely needs raising.

## References

### Official Documentation

- [Model configuration](https://code.claude.com/docs/en/model-config) - Anthropic; "Adjust effort
  level" section confirms `low`/`medium`/`high`/`xhigh` "persist across sessions when you set them
  in an interactive session" with no `s`/Enter exception, lists `/model`'s effort slider (left/right
  arrow keys) under the same "Set the effort level" heading as `/effort`, and confirms `max` and
  `ultracode` are the only levels scoped to the current session by default. "Setting your model"
  section confirms the `s`/Enter distinction ("`s`: switch model for this session only") is
  documented for the model field specifically, not the effort slider next to it. Its "Use
  ultrathink for one-off deep reasoning" section documents the `ultrathink` prompt keyword as a
  per-turn nudge that leaves the session effort setting unchanged. Fetched and confirmed
  2026-08-04.
- [CLI reference](https://code.claude.com/docs/en/cli-reference) - Anthropic; confirms `--effort
  <level>` "Set[s] the effort level for the current session... Overrides the `effortLevel` setting
  for this session and does not persist" - the one documented path to a non-persistent effort
  change, available only at launch. Fetched and confirmed 2026-08-04.

### Reference Material

- `skills/cursor-projection/references/harness-matrix.md` - the authoritative Claude Code vs.
  Cursor mechanical facts this appendix cites throughout: discovery locations, compaction
  mechanics, subagent frontmatter and effort gating, hooks and settings, model tiers, and status
  line configuration.

### Local Examples

- `~/.claude/agents/` - this repository's own subagent definitions (`Explore.md`, `executor.md`,
  `runner.md`), used above as a concrete instance of Chapter 3's "build a small reusable set of
  workers once" habit.
