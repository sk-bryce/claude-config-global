---
created: 2026-09-25
updated: 2026-09-25
---

# 11. Planner work hierarchy, run policies, usage gating, and in-plan tracking

- Status: Accepted
- Date: 2026-09-25
- Deciders: repository owner
- Extends: `decisions/0010-single-planner-skill-with-self-running-plans.md` (supersedes nothing)
- Related: `specs/behaviors.md` (Plan and Execute section), `reference/subagent-orchestration.md`,
  `skills/planner/scripts/usage-check.sh`

## Context

Decision 0010 made plans self-running, with flat units grouped into dependency waves, a Progress
checklist, and a Run log. Three gaps showed up in use. Long plans had no level between "the whole
plan" and "one unit", so there was nowhere to hand a coherent slice of work to a cheaper
orchestrator, and nowhere to review a slice before the next one started. Plans ran until they hit
an account limit and then failed mid-unit, because nothing checked usage. And the only
interactivity setting was the minimum orchestrator tier: whether a plan should stop on ambiguity,
confirm between phases, use a worktree, or commit were decided ad hoc during the run.

0010 also rejected handing orchestration to a subagent because nested subagents were unverified.
Claude Code's subagent documentation now states that a subagent can spawn subagents of its own,
up to three layers below the main conversation, and that `AskUserQuestion` is removed from every
subagent.

## Decision

- Work hierarchy: Phase > Cluster > Unit. A Phase is the largest unit of work, sized for the
  top-level Opus or Sonnet orchestrator. A Cluster is a logical grouping inside a Phase, sized for
  a Sonnet orchestrator subagent. A Unit is the smallest, fully specified piece, sized for a Haiku
  (sometimes Sonnet) executor. "Unit" is kept rather than "Task" because "Task" collides with the
  `Task` dispatch tool and `TaskCreate`/`TaskUpdate`, and because Unit is already the term the
  `executor` agent, specs, and evals use. Waves stay, but only as parallel groupings of Units
  inside one Cluster, not as a fourth level. IDs are hierarchical (Unit 2.1.3).
- Phases are numbered from 1. Phase 0 exists only for questions known at planning time that could
  not be answered then; its answers may add or change Units and Clusters, and anything larger is
  asked during planning.
- Five run-policy questions at intake: model guard (Opus default; Sonnet, Fable, None), halt
  policy (Sparse default; Unattended, Attended), confirmation (Startup default; Attended,
  Unattended), worktree (git only; worktree and clean up by default), and commit and push (git
  only). Tier order for the guard is Haiku < Sonnet < Opus < Fable. The model guard replaces the
  minimum orchestrator tier.
- Destructive or irreversible actions the plan needs are identified and authorized during
  planning. Any other such action stops for confirmation under every policy, Unattended included.
- Usage gating: a standalone script, `skills/planner/scripts/usage-check.sh`, reads the OAuth usage
  endpoint the status line already uses. The top orchestrator checks before every Cluster; at or
  above the warn threshold (default 85) checks move to before every Unit; at or above the stop
  threshold (default 95) the run pauses and re-checks hourly. A spend cap at the stop threshold
  halts instead, since a monthly cap does not reset within hours. A run resumes once usage is below
  the stop threshold, not below the warn threshold, so a 7-day window sitting between the two
  after a 5-hour reset does not stall the run for days.
- The script copies the status line's token resolution rather than sharing it, keeping the skill
  self-contained; the two copies must be kept in step by hand.
- Nested orchestration: a Cluster may be dispatched to a foreground Sonnet Cluster orchestrator
  subagent, which dispatches its own Units. Only the top-level session talks to the user, sleeps
  for usage, reviews Clusters, commits, and archives. Clusters run one at a time, so one agent at
  a time writes the plan file.
- Each Cluster is reviewed and refined by a fresh read-only reviewer before the next starts, and
  the whole change set gets a holistic review before final verification.
- Tracking lives in plan appendices: Appendix A Progress (nested checklist), Appendix B Run log,
  and Appendix C Decisions log (agent decisions, deviations, and anomalies). After the run, the
  orchestrator walks each Decisions log entry with the user (keep or reopen), then moves the plan
  to the plans directory's `archive/`. When no reply can arrive, the plan stays in place awaiting
  that review.
- Resume is folded into pre-flight rather than given its own section: every `[x]` Unit's gate is
  re-run, and a Cluster or Phase mark is trusted only when all its children re-verify.
- Plan filenames are `plan-YYYY-MM-DD-<slug>.md`. Lookup by slug matches `plan-*-<slug>.md` and the
  legacy `<slug>.md`.

## Consequences

- Plans get longer again: a Run policies section, three appendices, and a larger protocol block.
- Usage gating depends on an undocumented endpoint. When it fails, the script reports `unknown`
  and the orchestrator checks before every Unit instead of treating the failure as headroom.
- The hourly sleep relies on a background shell sleep in the top-level session; its behavior in a
  headless `claude -p` run is unverified.
- Existing plans keep their embedded old protocol and still run; they are not migrated.
- Whether agents actually follow the new protocol stays untested until a plan-execution eval run
  exists, as with 0010.

## Alternatives considered

- Phase > Cluster > Task. Rejected for the tool-name collision above.
- Keep flat units and waves. Rejected: no place for a cheaper Cluster orchestrator or a
  per-Cluster review.
- Read usage from the status line's stdin payload. Rejected: only `statusline.sh` receives that
  payload; a running agent cannot read it.
- Share the token logic through a sourced helper. Rejected in favor of a self-contained skill
  script, at the cost of two copies.
- A separate Resume section. Rejected: the pre-flight re-verification already covers it.

## References

- `decisions/0010-single-planner-skill-with-self-running-plans.md` - the decision this extends.
- `scripts/statusline.sh` - source of the usage endpoint call and the token resolution copied into
  the usage-check script.
- [Create custom subagents](https://code.claude.com/docs/en/sub-agents) - Claude Code
  documentation, source of the nested-subagent depth limit and the `AskUserQuestion` removal.
