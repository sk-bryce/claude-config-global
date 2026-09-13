<!--
created: 2026-07-27
updated: 2026-08-31
spec: specs/behaviors.md (Plan and Execute section)
generated-by: Opus subagent, spec-driven migration plan execution (Phase 3 Workstream A)
model: claude-opus-5-thinking-high
harness: Claude Code
note: illustrative sample artifact for a fictional orders-api service; the paths are not real
-->

# Plan: Health Endpoint with Database Connectivity Check

## Goal

Add a `GET /health` endpoint to the orders-api service that returns 200 when the database answers and
503 when it does not.

## Definition of Done

Verified at final verification, not by the per-unit gates alone:

1. `npx tsc --noEmit` exits 0 in the working directory.
2. `npm run lint` exits 0 in the working directory.
3. `npm test` exits 0 in the working directory, with the two new `GET /health` cases passing.
4. `GET /health` responds 200 with body `{"status":"ok","checks":{"database":"ok"}}` when the pool
   query resolves.
5. `GET /health` responds 503 with body `{"status":"degraded","checks":{"database":"unreachable"}}`
   when the pool query rejects, and the response body contains no driver error text.
6. `GET /health` is reachable without an `Authorization` header: in `src/app.ts`,
   `rg -n "app.use" src/app.ts` shows `app.use(createHealthRouter(pool));` on a lower line number than
   `app.use(requireAuth);`.

## Assumptions

- `supertest` and `@types/supertest` are already in `devDependencies`; no unit installs dependencies.
- The service exports a shared `pg` `Pool` from `src/db/pool.ts` as the named export `pool`.

## Working directory

`/path/to/orders-api/.worktrees/health-endpoint`

A dedicated git worktree, created from the project root with
`git worktree add .worktrees/health-endpoint -b health-endpoint origin/main`, so a failed run is rolled
back by `git worktree remove .worktrees/health-endpoint`. It sits under the project directory so it
inherits the project's tool permissions. Every path below is absolute under this root.

## Model-role map

| Role | Tier | Alias |
| --- | --- | --- |
| Orchestrator | the model running the executing turn (Sonnet) | `sonnet` |
| Units 1 and 2 (new files, exact content given) | Haiku | `haiku` |
| Unit 3 (edits an existing file whose current content must be matched, plus new tests) | Sonnet | `sonnet` |
| Escalation | one tier above the unit's default (Haiku -> Sonnet -> Opus), then step back down | per the row above |

The Haiku-first default holds here: Units 1 and 2 create new files whose full content is given
verbatim in each unit, which is mechanical application rather than design.

## Waves

| Wave | Units | Depends on |
| --- | --- | --- |
| 1 | Unit 1 | nothing |
| 2 | Unit 2 | Unit 1's `checkDatabase` export |
| 3 | Unit 3 | Unit 2's `createHealthRouter` export |

Strictly sequential: each wave consumes a symbol the previous wave creates. No two units share a file.

---

## Unit 1 (Wave 1): Add the database connectivity check

**File:** `/path/to/orders-api/.worktrees/health-endpoint/src/health/checkDatabase.ts` (new
file; create the `src/health/` directory)

**Why:** The health route needs a bounded, non-throwing database probe so a hung connection cannot
hang the endpoint.

**Exact content (write this file exactly as shown):**

```ts
import type { Pool } from 'pg';

export type DatabaseCheck = { ok: true } | { ok: false; reason: string };

const CHECK_TIMEOUT_MS = 2000;

export async function checkDatabase(pool: Pool): Promise<DatabaseCheck> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const timeout = new Promise<never>((_resolve, reject) => {
      timer = setTimeout(() => reject(new Error('database check timed out')), CHECK_TIMEOUT_MS);
    });
    await Promise.race([pool.query('SELECT 1'), timeout]);
    return { ok: true };
  } catch (error) {
    return { ok: false, reason: error instanceof Error ? error.message : 'unknown error' };
  } finally {
    if (timer !== undefined) {
      clearTimeout(timer);
    }
  }
}
```

**Acceptance gate:** `npx tsc --noEmit` exits 0, and
`rg -q "export async function checkDatabase" src/health/checkDatabase.ts` exits 0.

---

## Unit 2 (Wave 2): Add the health router

**File:** `/path/to/orders-api/.worktrees/health-endpoint/src/health/router.ts` (new file)

**Why:** Keeps the route in its own module so it can be mounted before the auth middleware and tested
without the full app.

**Exact content (write this file exactly as shown):**

```ts
import { Router } from 'express';
import type { Pool } from 'pg';
import { checkDatabase } from './checkDatabase';

export function createHealthRouter(pool: Pool): Router {
  const router = Router();

  router.get('/health', async (_req, res) => {
    const database = await checkDatabase(pool);

    if (database.ok) {
      res.status(200).json({ status: 'ok', checks: { database: 'ok' } });
      return;
    }

    // database.reason stays server-side: the probe surfaces driver text that must not reach callers.
    res.status(503).json({ status: 'degraded', checks: { database: 'unreachable' } });
  });

  return router;
}
```

The file `/path/to/orders-api/.worktrees/health-endpoint/src/health/checkDatabase.ts`
already exists and exports an async `checkDatabase(pool: Pool)` returning
`Promise<{ ok: true } | { ok: false; reason: string }>`. Do not modify it.

**Acceptance gate:** `npx tsc --noEmit` exits 0, and
`rg -q "createHealthRouter" src/health/router.ts` exits 0.

---

## Unit 3 (Wave 3): Mount the router before auth and add tests

**Files:**

- `/path/to/orders-api/.worktrees/health-endpoint/src/app.ts` (edit)
- `/path/to/orders-api/.worktrees/health-endpoint/test/health.test.ts` (new file)

**Why:** The endpoint must answer without authentication, and both status paths need regression
coverage.

**Edit 1 - `src/app.ts`.** Its current content is:

```ts
import express from 'express';
import { pool } from './db/pool';
import { requireAuth } from './middleware/requireAuth';
import { ordersRouter } from './orders/router';

export const app = express();

app.use(express.json());
app.use(requireAuth);
app.use('/orders', ordersRouter);
```

Replace the whole file with:

```ts
import express from 'express';
import { pool } from './db/pool';
import { createHealthRouter } from './health/router';
import { requireAuth } from './middleware/requireAuth';
import { ordersRouter } from './orders/router';

export const app = express();

app.use(express.json());
app.use(createHealthRouter(pool));
app.use(requireAuth);
app.use('/orders', ordersRouter);
```

If what you find in the file differs from the current content given here, STOP and report the
difference instead of guessing. The only required changes are the added `createHealthRouter` import
and the `app.use(createHealthRouter(pool));` line, placed after `app.use(express.json());` and before
`app.use(requireAuth);`.

**Edit 2 - `test/health.test.ts`.** Write this new file exactly as shown:

```ts
import express from 'express';
import request from 'supertest';
import type { Pool } from 'pg';
import { createHealthRouter } from '../src/health/router';

function appWithQuery(query: () => Promise<unknown>) {
  const app = express();
  app.use(createHealthRouter({ query } as unknown as Pool));
  return app;
}

describe('GET /health', () => {
  it('returns 200 when the database answers', async () => {
    const response = await request(appWithQuery(async () => ({ rows: [{ ok: 1 }] }))).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok', checks: { database: 'ok' } });
  });

  it('returns 503 and leaks no driver text when the database rejects', async () => {
    const response = await request(
      appWithQuery(async () => {
        throw new Error('ECONNREFUSED 127.0.0.1:5432');
      }),
    ).get('/health');

    expect(response.status).toBe(503);
    expect(response.body).toEqual({ status: 'degraded', checks: { database: 'unreachable' } });
    expect(JSON.stringify(response.body)).not.toContain('ECONNREFUSED');
  });
});
```

`supertest` and `@types/supertest` are already devDependencies. Do not install or update any
dependency.

**Acceptance gate:** `npm test -- test/health.test.ts` exits 0 with both cases passing,
`npx tsc --noEmit` exits 0, `npm run lint` exits 0, and `rg -n "app.use" src/app.ts` shows
`app.use(createHealthRouter(pool));` on a lower line number than `app.use(requireAuth);`.

---

This plan carries a filled-in orchestration protocol, which makes it self-triggering: telling any
agent to execute this plan is enough, and no separate skill is required to run it correctly.

## Orchestration protocol (read before executing this plan)

The executing (orchestrator) agent MUST dispatch the work below to subagents automatically, without
being told again, and MUST NOT perform a unit's initial implementation itself. The orchestrator only
sequences units, launches subagents, runs verification gates, makes bounded corrective edits (see
below), and enforces the escalation and halt rules below. Use plain subagents only: even if an
agent-team feature is enabled in this environment, do NOT propose or spawn an agent team for this
work.

- **Pre-flight (orchestrator, before any dispatch):** read this plan in full; confirm the working
  state is clean (no uncommitted changes that would corrupt diffs or tests) and that every tool,
  build, and test command this plan needs is available; run any known-good baseline check the plan
  defines; create a durable, per-unit progress record that survives an interrupted session (so a
  re-run resumes where it stopped rather than restarting); and summarize the blast radius (the waves,
  the files each will touch, and the model plan) before dispatching. If any precondition fails, STOP
  and report rather than dispatching.
- **Automatic delegation (default on):** every substantive unit of work defined below is dispatched
  to a subagent; the orchestrator does not implement a unit itself. It does only this: launching
  subagents, reading files back, running verification/build/test/lint commands in the shell, making
  bounded corrective edits during verification (a few lines at most - anything larger becomes a
  corrective subagent), and (only if explicitly requested) committing. A plan may mark a genuinely
  trivial, low-risk unit for direct execution instead of fan-out; delegation is the default, not a
  mandate for work that does not warrant it.
- **Models (role -> tier; fill per plan):** a default executor tier for prescriptive units, an
  escalation one tier up (Haiku -> Sonnet -> Opus), and an orchestrator that stays on the model
  running this plan. Name each tier by its harness equivalent; prefer an alias over a frozen slug.
  If a required model cannot be launched, STOP and ask; never silently substitute. Units 1 and 2 run
  on Haiku (new files with exact content given); Unit 3 runs on Sonnet (it must match an existing
  file's content and add tests); escalation is one tier up from each unit's default; the orchestrator
  stays on Sonnet. There are no reviewer, builder, or collator roles in this plan.
- **Worker type:** dispatch a read/write worker subagent for any unit that edits files; use a
  read-only subagent only for pure investigation or independent verification that writes nothing. The
  orchestrator runs git, build, test, and lint commands itself in the shell rather than delegating
  them, so it keeps authority over the gates.
- **Self-contained prompts:** subagents share no memory of this plan or this conversation. Each
  dispatched prompt MUST inline, verbatim: the absolute file path(s) to touch, a one-sentence "why",
  the exact content or diff to apply (copied from the relevant section below), and the standing
  constraints below. NEVER tell a subagent to open, locate, or consult this plan or any other
  document to find or interpret its task; paste any context it needs directly into the prompt.
  1. "Read the target file(s) in full first; do not trust line numbers - locate code by content,
     not position."
  2. "Edit only the file(s) named in this prompt. Do not modify any other file. Do not run
     git add/commit/push. Do not run dependency or tidy commands unless this prompt explicitly says
     to."
  3. "After editing, run the project's configured formatter/linter on each changed file and fix
     anything it flags."
  4. "Report a terse summary of what changed, and explicitly flag anything in these instructions
     that did not match what you found in the file."
  5. "If anything here is ambiguous or needs information not present in this prompt, STOP and report
     the ambiguity rather than guessing."
  6. "Before reporting done, confirm each acceptance criterion in this prompt; if any cannot be met,
     STOP and report which one(s) and why."
- **Completion-message discipline:** require each subagent's completion message to be terse - one
  line of status, the path(s) of any file(s) changed or artifact(s) produced, and at most a few
  bullets on key decisions or anything flagged. Subagents must NOT paste file or document contents
  back; this keeps the orchestrator's context lean across a long, multi-dispatch run.
- **Failure escalation ladder (mechanical trouble):** when a subagent (a) returns a failure or
  error, (b) reports the instructions did not match the file (a snippet is not found, a line
  drifted), (c) makes no progress, or (d) produces a weak or incorrect result on a unit whose
  requirements were clear:
  1. Retry the SAME unit once, same model, same self-contained prompt.
  2. If it still fails, re-dispatch the SAME unit one model tier up, with the same prompt plus the
     failure context (what went wrong). Do not skip, half-apply, or improvise. Step back to the
     default tier for later units.
  3. If the escalated tier also cannot resolve it, or cannot be launched, STOP and ask the user.
     Never leave work partially applied or guess past a blocker.
- **Run circuit breaker:** track the count of retries and escalations across the whole run. If it
  exceeds the threshold below, pause and report instead of continuing - a run that keeps escalating
  usually signals a bad plan or a systemic issue a stronger model will not fix, and unbounded
  escalation runs up cost. Threshold for this plan: 3 combined retries plus escalations across the
  whole run.
- **Halt vs escalate (route by cause):** escalating the model is only for the mechanical trouble
  above - a unit that is hard but well specified. If a subagent instead stops because a decision is
  missing or contradictory, or information the task needs is not present in the prompt (genuine
  ambiguity), do NOT retry or escalate the model: a stronger model would only guess at the same
  missing decision. Halt and report the specifics to the user.
- **Verification gates (orchestrator, after each unit or wave):** do not trust self-reports. Before
  starting dependent work, read the modified file(s) back to confirm intent, run the applicable
  checks for the changed scope (the linter, and the unit's acceptance check), and independently
  confirm each acceptance criterion. Prefer acceptance criteria expressed as a command that returns
  pass/fail, and run it, rather than judging subjectively. For a high-risk or reasoning-heavy unit,
  optionally dispatch a separate read-only verifier subagent to check the output against the criteria
  independently instead of self-verifying. Mark the unit's progress record complete only after the
  checks pass. If an edit is wrong or drifted, make a bounded corrective edit yourself or dispatch
  one narrowly-scoped corrective unit before proceeding. The authoritative gates for this plan, all
  run from `/path/to/orders-api/.worktrees/health-endpoint`, are: `npx tsc --noEmit`,
  `npm run lint`, and `npm test` (per-unit, the narrower `npm test -- test/health.test.ts`).
- **Sequencing and isolation:** dispatch independent units in one message (multiple subagent calls)
  so they run concurrently, then gate before the next wave. Before dispatching any parallel wave,
  verify the units' declared file sets are disjoint; if they overlap, serialize them regardless of
  how the plan labeled their independence. Units that share a file, or that depend on
  types/signatures/tests an earlier unit establishes, MUST run strictly sequentially, one at a time,
  because each subagent reads the file fresh and concurrent edits would clobber each other. Parallel
  document-producing subagents must each write ONLY their own output file, must NOT read another
  parallel agent's file, and must NOT communicate; merging or reconciling their outputs is a
  separate, later dispatch. Waves for this plan: Wave 1 is Unit 1 (no dependencies); Wave 2 is Unit 2
  and depends on Unit 1's `checkDatabase` export; Wave 3 is Unit 3 and depends on Unit 2's
  `createHealthRouter` export. All three waves are strictly sequential, one unit at a time; there is
  no parallel wave in this plan.
- **Corrective units (verification):** if a build, test, or lint command fails, do not retry blindly.
  Read the exact failure output, trace it to the single file or unit responsible, dispatch one
  narrowly-scoped corrective unit with the failing message included verbatim, then re-run the check.
  Repeat until it passes cleanly.
- **Environmental vs real failures:** distinguish failures caused by unavailable infrastructure
  (Docker, ports, local databases or services) from genuine regressions. If a check fails only
  because its harness could not start, capture the output, note it as environmental, and do not
  block; if it fails to compile or a non-harness assertion fails, treat it as a real regression to
  fix. There are no environmental harnesses in this plan: every gate runs without Docker, a live
  database, or a bound port, because the tests inject a fake pool. Any failure here is a real
  regression.
- **Recovery and re-planning:** the ladder above is for unit-level trouble. If a failure instead
  reveals the plan itself is wrong (an assumption does not hold, a phase's premise is invalid), do
  NOT push through or silently re-plan. Halt execution, surface the failure context, and offer to
  re-enter planning with that context folded in.
- **Commit policy:** subagents never run any git command. Do not add, commit, push, or open a PR at
  any point unless the user explicitly requested it; if requested, the orchestrator does it as a
  final, separate step. Stop at ready for review: leave the `health-endpoint` worktree and branch in
  place, uncommitted, and report the diff for the user to inspect.
- **Final verification (orchestrator-owned):** after the last unit, run the full authoritative gates
  named above yourself (not via a subagent) to confirm the whole target is green, and confirm the
  plan's stated goal and definition of done are actually met - all units passing their local checks
  does not by itself prove the overall objective was achieved. Resolve any stragglers with a bounded
  corrective edit or one narrowly-scoped corrective unit before reporting.
- **Final report:** report which units completed vs were stopped and not resumed; the count of units
  that required a retry or an escalation; any acceptance checks or goal/definition-of-done items that
  could not be satisfied and why; and the paths of any artifacts produced.
