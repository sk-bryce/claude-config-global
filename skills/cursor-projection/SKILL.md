---
name: cursor-projection
description: |
  This skill should be used when the user asks to project, port, sync, or set up this `~/.claude`
  config for Cursor - e.g. "get Cursor using these skills", "update my Cursor user rules",
  "sync the hooks to Cursor", "set up Cursor on this machine" - or asks what Cursor does and does
  not support relative to Claude Code ("does Cursor honor `model:`?",
  "why is the tier stated in the skill body?", "what happens to `effort:` under Cursor?").
  Carries the harness fact matrix, the CLAUDE.md-to-User-Rules projection procedure, and the
  script that writes Cursor's hooks, status line, and MCP config. Does not author or audit skills
  (see skill-author) and does not proofread Markdown (see review-md). Scope: personal
  (~/.claude/skills/).
---

<!--
created: 2026-08-24
updated: 2026-09-11
spec: specs/skills.md (cursor-projection section)
generated-by: Claude Code main thread (Opus 5)
model: claude-opus-5
harness: Claude Code

This skill is the single home for Cursor knowledge in this config. The core repo targets
Claude Code alone; everything harness-specific about Cursor - the fact matrix, the User Rules
projection procedure, the status line implementation, and the config writer - lives here and
is loaded only when a Cursor task is actually at hand. See
`${CLAUDE_CONFIG_DIR:-~/.claude}/decisions/0005-cursor-projection-as-a-skill.md`.
-->

# Project this config for Cursor

Cursor reads some of this config natively and none of the rest. This skill covers the gap.

Load the reference you need before acting - `references/harness-matrix.md` is the source of
truth for every per-harness claim below, and nothing here restates it in full.

## What Cursor already reads, with no projection at all

- `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/` and `.../agents/` are discovered natively at the
  literal `~/.claude/...` path. Authoring a skill or subagent here is all that is required.
- Project-scope `AGENTS.md` and `CLAUDE.md` are read directly.

Two consequences worth knowing before you touch anything:

- Cursor ignores a skill's or subagent's `model:` and `effort:` frontmatter, and honors
  `readonly: true` in place of a `tools:` allow-list. This is why tier and scope guidance in
  this repo is stated in an artifact's body as well as pinned in its frontmatter: the body
  survives a harness that drops the pin. See `references/harness-matrix.md`.
- There is no global-instructions file. Nothing under `~/.claude` is read as global rules.

## The three projections

### 1. Global rules into Cursor User Rules

Cursor's only global-instruction mechanism is User Rules in the Settings UI, which is
cloud-synced and cannot be installed from a file. Generate the paste-able blob by following
`references/user-rules-projection.md`, which holds the source sections, the exclusions, every
neutralization rule, and the acceptance checklist. Read it in full before generating - the
neutralization rules are the substance of this projection, not a style pass over it.

The output is a generated artifact, not a tracked one. Regenerate it whenever `CLAUDE.md`'s
global sections change rather than trying to keep a stored copy current.

### 2. Hooks, status line, and MCP config

`scripts/project-to-cursor.sh` writes `~/.cursor/hooks.json`, the `statusLine` key in
`~/.cursor/cli-config.json`, and `~/.cursor/mcp.json`.

```sh
scripts/project-to-cursor.sh --check    # report divergence, write nothing
scripts/project-to-cursor.sh --apply    # perform the writes
```

**`--apply` is the user's own step, not an agent's.** Writing `~/.cursor/hooks.json` registers
hooks, and a hook activates before any later review can catch it, so
`${CLAUDE_CONFIG_DIR:-~/.claude}/decisions/0003-hooks-and-scripts-authoring-policy.md`
requires that registration be the user's explicit, in-the-moment act. Run `--check`, show the
user what would change, and ask them to run `--apply` themselves.

On a machine with no `~/.cursor`, every target is a clean no-op rather than drift.

### 3. The status line itself

This skill's `scripts/statusline-cursor.sh` is Cursor's status line implementation, separate from
Claude Code's `${CLAUDE_CONFIG_DIR:-~/.claude}/scripts/statusline.sh` because the two harnesses'
status line payloads use different field names for the same data, and a custom Cursor status line
replaces the native footer wholesale rather than adding to it.
`scripts/project-to-cursor.sh` points Cursor's `statusLine` key at it.

## The hook wrappers speak both dialects

`filter-verbose-output.sh`, `md-ledger-append.sh`, and `md-deferred-checks.sh` under
`${CLAUDE_CONFIG_DIR:-~/.claude}/scripts/` each take an optional `claude|cursor` positional
argument that selects the hook payload and response JSON shape. With no argument they behave as
Claude Code hooks, which is how `settings.json` invokes them. The `hooks.json` that
`scripts/project-to-cursor.sh` generates passes `cursor`.

Keep that argument intact when editing those scripts. It is the only place the payload-shape
differences between the two harnesses are encoded in running code.

## Verifying a projection landed

Per `references/harness-matrix.md`'s verification section: confirm a skill or subagent was
discovered from within Cursor rather than assuming the file's presence is enough, and re-read
`~/.cursor/hooks.json` after an `--apply` rather than trusting the script's own report.
