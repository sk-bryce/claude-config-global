---
created: 2026-09-25
updated: 2026-09-25
---

# 10. One planner skill whose plans run themselves

- Status: Accepted
- Date: 2026-09-25
- Deciders: repository owner
- Supersedes: `decisions/0002-plan-and-execute-framework.md`
- Related: `specs/behaviors.md` (Plan and Execute section), `reference/subagent-orchestration.md`,
  `agents/executor.md`

## Context

Decision 0002 split plan-and-execute into two skills over one shared protocol: an auto-invocable
planner and a manual-only executor. By 2026-09-25 most of the executor's body restated the
orchestration block every plan already embeds. Pre-flight, the escalation ladder, halt vs escalate,
the circuit breaker, disjoint-file waves, final verification, and the commit policy all appeared in
both. The copies had begun to drift. The block's pre-flight said to summarize the blast radius but
never to wait for approval; its first retry omitted the failure context the executor added; and its
breaker tripped on "exceeds" where the executor tripped on "reached". The executor therefore carried
a rule for when the plan contradicted it. The planner also hardcoded `origin/<base>` in its worktree
command, and only the executor corrected that.

Three things the executor did could not live in a plan file: finding a plan by slug before reading
it, pinning the orchestrator to Sonnet in a forked context, and giving a clear handle for "run
this". In the 2026-08-03 eval (`evals/runs/2026-08-03-execute-plan.md`, case 2), a no-skill agent
refused a plan's self-triggering block as untrusted file content. That agent had been sent an
unrecognized slash command rather than "execute this plan", so it is one weak data point.

The fork also produced one empirical finding worth keeping: a backgrounded fork cannot pause for a
blocking confirmation. The executor's `background: true` attempt was reverted because its
blast-radius confirmation had no way to reach the user and receive a reply mid-run.

## Decision

- Remove the executor skill. Every plan carries its whole run procedure in the embedded protocol,
  so telling any agent to execute the plan file is how a plan runs.
- Rename the planner to `planner` (not `plan`, which would shadow the built-in `/plan`).
- Move the executor's unique procedure into the protocol: a blocking confirmation pause at the end
  of pre-flight (a halt where no reply can arrive), worktree setup and reuse, resume by re-running
  the gate of every `[x]` unit, failure context on the first retry, a breaker that trips on
  reaching its threshold, a halt-report format, an item-by-item Definition-of-Done walk, and a
  fixed final-report format.
- Make progress durable inside the plan: a Progress checklist with one line per unit and its gate,
  marked `[x]` only after the gate passes, and a Run log that carries retries, escalations, halts,
  and the breaker count across interrupted sessions.
- Replace the Sonnet pin with a per-plan minimum orchestrator tier. The planner asks the user for
  it with `AskUserQuestion`, and the protocol's first step halts when the session model is below it.
- Dispatch file-editing units to the `executor` subagent with a per-unit `model:` override, falling
  back to `general-purpose` where that agent does not exist or the plan assigns another worker.
- Put lookup by slug in `CLAUDE.md` (Subagents & Models), in the planner's plans-directory order,
  because the planner skill is not loaded when a plan runs.
- Have the planner write concrete worktree commands after checking `git remote`, never assuming
  `origin`.
- Carry forward from 0002 unchanged: halt-vs-escalate routing, the one-tier escalation ladder,
  per-run counts with a circuit breaker and no escalation-rate tracking, orchestrator-owned
  verification, no silent re-planning, plain subagents rather than agent teams, and the Plan Mode
  split between native mode and the planner.

## Consequences

- One description slot instead of two, and one synced copy of the protocol instead of two.
- Orchestration runs in whichever session is told to execute the plan, so its dispatch traffic
  lands in that session's context rather than in a fork. That is the cost of dropping the fork.
- There is no manual-only guard: any request to execute a plan starts a run. The blocking
  confirmation at the end of pre-flight is now the only gate before the first dispatch.
- Plans are longer, since each carries the full protocol and the two tracking sections.
- The executor skill's eval cases were ported into `skills/planner/evals/evals.json` as checks on
  the generated plan. Whether an agent actually follows the protocol stays untested until a
  plan-execution eval run exists. The case that tested the manual-only trigger was dropped along
  with the skill it tested.

## Alternatives considered

- Keep a thin launcher skill that finds the plan, keeps the Sonnet fork, and defers to the embedded
  protocol. Rejected: it keeps a second artifact and a second description slot only to hold a fork
  and a lookup, which a tier check and a global rule cover.
- Have the executing session hand orchestration to one foreground Sonnet subagent. Rejected for
  now: it depends on subagents being able to dispatch their own subagents, which was not verified.
- Keep both skills and fix the drift. Rejected: the duplication is what caused the drift.

## References

- `decisions/0002-plan-and-execute-framework.md` - the superseded two-skill decision.
- `reference/subagent-orchestration.md` - the protocol every plan embeds.
- `evals/runs/2026-08-03-execute-plan.md` - the executor skill's only eval run.
