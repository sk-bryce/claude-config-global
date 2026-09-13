---
created: 2026-07-27
updated: 2026-08-31
---

# 5. The Cursor projection is a skill, not a tracked artifact

## Context

This config is authored for Claude Code. Cursor discovers `~/.claude/skills/` and
`~/.claude/agents/` natively at that literal path, but it reads no file under `~/.claude` as
global instructions, and its hooks, status line, and MCP configuration live under `~/.cursor/`
in shapes whose field names differ from `settings.json`. Supporting it therefore takes two
distinct things: a body of per-harness facts, and machinery that writes Cursor's config files.

Threading both through the core config taxes every artifact. A portability caveat lands after
each frontmatter field, a second column appears in each comparison table, and the global
instruction file carries a parenthetical for every mechanism that differs - all for knowledge
that is needed a few times a year, on a machine that may not have Cursor installed at all.

Carrying the projected global-rules blob as a tracked artifact adds a second, separate cost. A
tracked projection has to be regenerated whenever its source changes, and something has to
notice when it was not. That is a standing obligation whose only product is a file that must
never be stale, enforced by a check that can only ever emit an advisory notice, because a
prose paraphrase has no mechanical definition of correct.

## Decision

All Cursor knowledge and machinery live in one skill, `skills/cursor-projection/`, and nowhere
else in the config. It carries:

- `references/harness-matrix.md` - the per-harness fact base, the source of truth for every
  claim about what Cursor does and does not honor.
- `references/user-rules-projection.md` - the procedure for projecting `CLAUDE.md`'s global
  sections into a paste-able Cursor User Rules blob, with its exclusions, neutralization rules,
  and acceptance checklist.
- `scripts/statusline-cursor.sh` - Cursor's status line implementation.
- `scripts/project-to-cursor.sh` - writes `~/.cursor/hooks.json`, the `statusLine` key in
  `~/.cursor/cli-config.json`, and `~/.cursor/mcp.json`.

Three rules follow from this:

- The core config targets Claude Code alone. Where a design exists because some harness drops a
  pin or offers only a coarser permission model, the artifact states the design and a
  harness-neutral reason, and the specifics stay in the skill's fact base.
- The User Rules blob is generated on demand and is not tracked. There is no stored copy, so
  there is no staleness marker and no drift check for it.
- `scripts/filter-verbose-output.sh`, `scripts/md-ledger-append.sh`, and
  `scripts/md-deferred-checks.sh` keep their optional `claude|cursor` positional argument. That
  argument is the one place the two harnesses' hook payload and response shapes are encoded in
  running code, and the generated `hooks.json` depends on it.

`project-to-cursor.sh --apply` registers hooks, so it remains the user's own explicit,
in-the-moment act under `decisions/0003-hooks-and-scripts-authoring-policy.md`. Relocating the
machinery moves that hazard; it does not remove it.

## Consequences

- Cursor facts load only when a Cursor task is actually at hand, rather than sitting in every
  context that reads the global instruction file.
- Nothing can drift out of sync, because nothing is stored to drift. The maintenance obligation
  becomes a capability that is invoked when wanted.
- `scripts/sync.sh` writes only inside this repo. Its apply mode therefore carries no
  hook-registration hazard and needs no human-only warning; it keeps the skills' `references/`
  copies honest and nothing more.
- A machine without Cursor installed sees a clean no-op rather than reported drift.
- The real cost: the projected blob is no longer diffable or version-controlled. Reviewing it
  means checking fresh output against the acceptance checklist in
  `references/user-rules-projection.md`, rather than reading a diff against a previous version.
- The artifact-class taxonomy in `decisions/0001-adopt-spec-driven-config-architecture.md` still
  governs how an artifact is regenerated and gated, but with this projection untracked, its
  LLM-generated class has no tracked member. The mechanical class holds `sync.sh`'s reference
  copies.

## Alternatives considered

- **Keep the projection tracked, with a spec and a drift check.** Rejected. The check can only
  compare a commit marker against the source's last commit, so it reports that a review is due,
  never that the content is correct. That buys a notice in exchange for a permanent obligation.
- **Drop Cursor support entirely.** Rejected. The compatibility work is hard to reproduce and
  cheap to keep once it is out of the way.
- **Keep the fact matrix in `reference/` and move only the procedure into a skill.** Rejected. A
  two-harness matrix sitting as a top-level reference document keeps the config describing
  itself as dual-harness, which is the thing being consolidated.
- **Describe the machinery in prose and let an agent reconstruct it.** Rejected. The
  `hooks.json` shape, the `statusLine` key path, and the payload field-name differences are only
  reliable as working code that can be run with `--check`.

## References

- `skills/cursor-projection/SKILL.md`
- `decisions/0001-adopt-spec-driven-config-architecture.md`
- `decisions/0003-hooks-and-scripts-authoring-policy.md`
