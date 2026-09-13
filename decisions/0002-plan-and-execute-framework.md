---
created: 2026-07-26
updated: 2026-08-31
---

# 2. Plan-and-execute framework as two skills over one orchestration reference

- Status: Accepted (implemented 2026-07-27; see `specs/behaviors.md`'s Plan and Execute section
  for current build/eval status - this record stays the fixed historical rationale)
- Date: 2026-07-24
- Deciders: repository owner
- Related: `specs/behaviors.md` (buildable intent), `reference/subagent-orchestration.md`
  (shared protocol), `skills/cursor-projection/references/harness-matrix.md` (per-harness
  facts)

## Context

A plan-then-execute capability is wanted: produce a self-contained, agent-executable plan,
then dispatch it to subagents with verification. This ADR records the design decisions
behind that capability. The buildable specification lives in `specs/behaviors.md`; this
record captures the decisions and their rationale so they survive regeneration.

## Decision

Build the capability as two skills over one shared, harness-neutral orchestration
reference (`reference/subagent-orchestration.md`), with the following resolved choices.

- Two skills, not one with two modes. The planner must be auto-invocable while the
  executor must be manual-only with a destructive-action guard
  (`disable-model-invocation: true`); one skill cannot be both. A secondary reason is the
  model pin (planner at Opus, executor orchestrator at Sonnet); the same tier guarantee is
  restated as harness-mapped subagent dispatch in each skill's body, so the guidance
  survives a harness that drops the pin.
- Names: `write-plan` (not `plan`, to avoid shadowing the built-in `/plan` and native
  Plan Mode, since personal skills override bundled ones) and `execute-plan`.
- Plan artifact and handoff: `write-plan` writes a meaningful-slug Markdown plan that
  survives compaction; `execute-plan` inlines each unit verbatim into subagent prompts
  and never tells a subagent to open the plan.
- Plans-directory resolution (harness-aware, in priority order): an explicitly-set native
  setting; else a project agent-config directory (`.claude/`) when present; else the
  global `~/.claude/plans`.
- Halt vs escalate, routed by cause: a hard-but-well-specified unit is mechanical trouble
  (escalate the model one tier); a missing or contradictory decision is genuine ambiguity
  (halt and ask, because a stronger model would only guess).
- Escalation ladder: retry the same unit once at its default tier; if it still fails,
  re-dispatch one tier up (haiku to sonnet to opus) with failure context; if that also
  fails or cannot launch, stop and ask the user.
- Escalation-rate tracking dropped as YAGNI; keep only per-run retry/escalation counts and
  a per-run circuit breaker.
- Recovery / re-planning: unit-level mechanical failures use the ladder; if a failure
  reveals the plan itself is wrong, `execute-plan` halts and offers to re-enter
  `write-plan` with context folded in. No silent auto-replan.
- Automatic subagent use: `execute-plan` dispatches every substantive unit to a subagent
  and never does a unit's initial implementation itself (bounded corrective edits during
  verification are allowed); `write-plan` may fan out research subagents under the same
  isolation rules.
- Adopted refinements: orchestrator-edit boundary (no initial implementation by the
  orchestrator); explicit Goal and testable Definition of Done in every plan; right-sizing
  escape hatch for trivial tasks; worktree-by-default execution; resumable execution via
  per-unit `[x]` marks; pre-execution blast-radius confirm; run circuit breaker.
- Native Plan Mode interaction: native mode owns enforced read-only exploration plus the
  human approval gate; `write-plan` owns executable content (self-contained units,
  dependency waves, model-role map, per-unit acceptance gates, refinement loop, plan-level
  verification gate). Do not write the artifact during Plan Mode: writes are routed through
  the permission callback and can degrade to advisory after an ExitPlanMode rejection, so
  the constraint holds where a coarser permission model is all that is available. For
  skill-first read-only enforcement, use a `PreToolUse` hook (declared via the skill's
  `hooks` frontmatter) rather than relying on `allowed-tools`/`disallowed-tools`.

## Consequences

- Cost is two description-budget slots instead of one, negligible against the ~20-30
  personal-skill ceiling.
- The tier guarantees are stated twice - as a `model:` pin and as harness-mapped subagent
  dispatch in the body - so the guidance survives a harness that drops the pin.
- The read-only enforcement hook's logic may be model-generated and reviewed before commit;
  its registration requires the user's explicit, in-the-moment direction (see ADR 3).

## Alternatives considered

- One skill with a planning mode and an execution mode. Rejected: cannot be both
  auto-invocable and manual-only-with-guard.
- Native subagents plus Plan Mode alone. Rejected as insufficient: they provide the
  substrate but not the discipline layer (escalation ladder, halt-vs-escalate,
  self-contained-prompt hygiene, orchestrator-owned verification gates).
- Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). Rejected: teammate models are
  fixed at spawn (breaks the escalation ladder), peer messaging conflicts with
  self-contained-prompt isolation, and its docs call it a poor fit for sequential,
  same-file, or dependency-heavy work.

## References

- `reference/subagent-orchestration.md` - the shared orchestration protocol.
- `skills/cursor-projection/references/harness-matrix.md` - frontmatter portability and
  model-tier mapping.
