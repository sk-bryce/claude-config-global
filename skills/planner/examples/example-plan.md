<!--
created: 2026-07-27
updated: 2026-09-26
spec: specs/behaviors.md (Plan and Execute section)
generated-by: Opus subagent, spec-driven migration plan execution (Phase 3 Workstream A); updated
  by hand on 2026-09-25 to the self-running plan shape; regenerated on 2026-09-25 for
  decisions/0011-planner-work-hierarchy-run-policies-and-usage-gating.md (Phases, Clusters, Units,
  run policies, and the three appendices) by a Sonnet subagent
model: claude-opus-5-thinking-high
harness: Claude Code
note: illustrative sample artifact for a fictional orders-api service; the paths are not real
-->

# plan-2026-07-27-health-endpoint-database-check.md

## Goal

Add a `GET /health` endpoint to the orders-api service that returns 200 when the database answers and
503 when it does not.

## Definition of Done

Verified at final verification, not by the per-Unit gates alone:

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

- `supertest` and `@types/supertest` are already in `devDependencies`; no Unit installs dependencies.
- The service exports a shared `pg` `Pool` from `src/db/pool.ts` as the named export `pool`.

## Run policies

- Model guard: Sonnet.
- Halt policy: Sparse.
- Confirmation policy: Startup.
- Worktree policy: yes, use a worktree and clean it up after.
- Commit and push policy: commit to `health-endpoint` locally only, no push.
- Usage thresholds: warn 85, stop 95.
- Authorized destructive or irreversible actions: none.

## Execution requirements

- Model guard: Sonnet. The embedded orchestration protocol halts before doing anything if the
  session running it is below Sonnet (Haiku < Sonnet < Opus < Fable), unless the user explicitly
  authorizes continuing on a lower tier at run time.
- To run this plan, tell any agent:
  `execute the plan at /path/to/orders-api/.claude/plans/plan-2026-07-27-health-endpoint-database-check.md`.
  The filled-in orchestration protocol at the end makes the plan self-running: telling any agent to
  execute it is enough, and no separate skill is required.

## Working directory

`/path/to/orders-api/.worktrees/health-endpoint`, a dedicated git worktree so a failed run is
rolled back by deleting it. It sits under the project directory so it inherits the project's tool
permissions. Every path below is absolute under this root.

While planning, `git remote` in `/path/to/orders-api` printed `origin`, and the current branch
tracks `origin/main`. Pre-flight runs, in order:

1. `git -C /path/to/orders-api status --porcelain` - must print nothing.
2. `git -C /path/to/orders-api worktree add .worktrees/health-endpoint -b health-endpoint origin/main`
   - skipped when `/path/to/orders-api/.worktrees/health-endpoint` already exists from an earlier
   run of this plan.

Rollback: `git -C /path/to/orders-api worktree remove .worktrees/health-endpoint`.

## Model-role map

| Role | Tier | Alias |
| --- | --- | --- |
| Top orchestrator | the session model running the plan; minimum Sonnet | `sonnet` or above |
| Cluster 1.1 and Cluster 1.2 orchestrator | the top orchestrator itself; no Cluster orchestrator subagent is dispatched in this plan | n/a |
| Units 1.1.1 and 1.1.2 (new files, exact content given) | Haiku, via the `executor` agent | `haiku` |
| Unit 1.2.1 (edits an existing file whose current content must be matched, plus new tests) | Sonnet, via the `executor` agent | `sonnet` |
| Cluster reviewer (after each Cluster) | Sonnet, via a read-only `general-purpose` reviewer subagent | `sonnet` |
| Holistic reviewer (after the last Cluster) | Opus, via a read-only `general-purpose` reviewer subagent | `opus` |
| Escalation | one tier above the Unit's default (Haiku -> Sonnet -> Opus), then step back down | per the row above |

The Haiku-first default holds here: Units 1.1.1 and 1.1.2 create new files whose full content is
given verbatim in each Unit, which is mechanical application rather than design.

## Phases

### Phase 1: Add the health endpoint

#### Cluster 1.1: Database check and health router

- **Orchestrator:** top orchestrator.
- **Review criteria:** a fresh read-only Sonnet reviewer confirms `checkDatabase` and
  `createHealthRouter` match the exact content given in Units 1.1.1 and 1.1.2 verbatim, that
  `npx tsc --noEmit` exits 0, and that neither file was modified outside what its Unit specifies.

##### Wave 1

**Unit 1.1.1 (Wave 1): Add the database connectivity check**

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

##### Wave 2 (depends on Unit 1.1.1's `checkDatabase` export)

**Unit 1.1.2 (Wave 2): Add the health router**

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

#### Cluster 1.2: Mount the router and add tests

- **Orchestrator:** top orchestrator.
- **Review criteria:** a fresh read-only Sonnet reviewer confirms `src/app.ts` mounts
  `createHealthRouter(pool)` before `requireAuth`, that `test/health.test.ts` matches the exact
  content given in Unit 1.2.1 verbatim, and that `npm test -- test/health.test.ts`,
  `npx tsc --noEmit`, and `npm run lint` all exit 0.

##### Wave 1 (depends on Cluster 1.1's `createHealthRouter` export)

**Unit 1.2.1 (Wave 1): Mount the router before auth and add tests**

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

## Orchestration protocol (read before executing this plan)

The executing (top orchestrator) agent MUST dispatch the work below to subagents automatically,
without being told again, and MUST NOT perform a Unit's initial implementation itself. The
orchestrators only sequence Clusters and Units, launch subagents, run usage checks and verification
gates, make bounded corrective edits (see below), and enforce the escalation, halt, and usage rules
below. Use plain subagents only: even if an agent-team feature is enabled in this environment, do
NOT propose or spawn an agent team for this work. A Sonnet Cluster orchestrator is a plain subagent
that dispatches plain subagents, not an agent team. If this plan contradicts itself, or a line below
still holds only one of the 12 unfilled placeholders, STOP and ask rather than picking an
interpretation. Other `<...>` tokens below (such as `<status>`) are format templates, not
placeholders.

- **Model guard (check first):** before any other step, identify the model running this turn from
  your own system context and map it to its tier, ordered Haiku < Sonnet < Opus < Fable. If the
  guard is None, skip this check. Otherwise, if that tier is below the guard, or you cannot
  determine it, HALT before touching anything: name the model you are running as and the required
  tier, and ask the user to switch models (for example with `/model`) and ask again. Continue on a
  lower tier only if the user then explicitly tells you to, and record that override in Appendix B.
  Model guard for this plan:
  Sonnet.
- **Pre-flight (top orchestrator, before any dispatch):** do these in order. If any step fails,
  STOP and report rather than dispatching.
  1. Read this plan in full, including Appendix A: Progress, Appendix B: Run log, and Appendix C:
     Decisions log. If every Appendix A line except "Decisions review" and "Archive" is already
     `[x]`, only the review and archive remain: skip the rest of pre-flight and go straight to the
     **Decisions review** bullet.
  2. Set up the working directory exactly as this plan's Run policies and Working directory sections
     state (a worktree, created or reused, or the main checkout). Before creating a worktree or
     touching the live checkout, confirm the repository is clean (`git status --porcelain` prints
     nothing; when the root is not a git repository, run the Working directory section's own clean
     check instead); uncommitted changes corrupt diffs and test results, so if it is dirty, STOP and
     report - never stash, commit, or revert anything on your own. On a resumed run, where
     Appendix A already has `[x]` marks, changes limited to the files this plan's Units name are
     expected; only changes outside them count as dirty. If the worktree already exists from an
     earlier run of this plan, reuse it rather than recreating it. Every path handed to a subagent
     must be absolute and under the working-directory root.
  3. Confirm every tool, build, and test command this plan needs is available, including the usage
     script named under **Usage gating**, and run any known-good baseline check the plan defines.
  4. Resume check: for every Unit already marked `[x]` in Appendix A, re-run that Unit's gate before
     trusting the mark. If it passes, skip the Unit. If it fails, change the mark back to `[ ]`, log
     the stale mark in Appendix B, and dispatch the Unit normally. Trust a Cluster's `[x]` only when
     every one of its Units re-verifies, and a Phase's `[x]` only when every one of its Clusters is
     trusted; un-mark and log any that are not. Restore the run's circuit-breaker count from
     Appendix B rather than starting again from zero.
  5. Run the first usage check (see **Usage gating**) and act on its status before continuing.
  6. Summarize the blast radius: the model running this turn against the model guard; the run
     policies (halt, confirmation, worktree, commit and push with the branch, usage thresholds,
     authorized destructive actions); the working directory; the Phases, Clusters, and waves, the
     files each touches, and who orchestrates each Cluster; the model plan; the circuit-breaker
     threshold and the count carried over; the last usage status; and which Phases, Clusters, and
     Units are already done.
  7. Phase 0: if this plan has a Phase 0 not yet marked `[x]`, resolve its questions per the halt
     policy (ask them at the top level with `AskUserQuestion`, at most four per call, or, under
     Unattended, answer each by best judgment). Apply the answers by editing the Clusters and Units
     they change and the matching Appendix A lines, log each answer and each change in Appendix C,
     then mark Phase 0 `[x]`.
  8. Confirmation pause, per the confirmation policy: under Startup or Attended, PAUSE for the
     user's explicit confirmation of the summary and the Phase 0 outcome, and dispatch nothing until
     they confirm; never treat silence as approval. Under Unattended, do not pause. If a pause or a
     Phase 0 question is required and this run cannot receive a reply (a backgrounded subagent, a
     non-interactive session), STOP and report instead of proceeding.
- **Run policies:** this plan's Run policies section sets these; the values below govern.
  - Halt policy. Sparse: stop and ask only on genuine ambiguity, a contradiction, or an issue that
    blocks the work; any other decision the plan leaves open is made to the best of your ability
    and logged in Appendix C. Unattended: never stop to ask for a decision; make every decision to
    the best of your ability, log each one in Appendix C, and answer Phase 0 questions by best
    judgment. Attended: stop and ask the user on any decision or ambiguity. Under every policy, a
    blocker that no decision can clear (the escalation ladder exhausted, the circuit breaker
    reached, a plan-invalidating failure, a spend cap) halts and reports. Where a stop is required
    but no reply can arrive, halt and report rather than decide.
  - Confirmation policy. Startup: pause once, after pre-flight and Phase 0. Attended: pause there,
    and also before each Phase after the first. Unattended: never pause for confirmation. Silence
    is never approval, and a required pause that cannot receive a reply halts the run.
  - The two policies are independent: the confirmation policy governs the planned pauses, the halt
    policy governs stops for decisions and ambiguity. The destructive-action rule below overrides
    both.
  Halt policy for this plan:
  Sparse.
  Confirmation policy for this plan:
  Startup.
- **Destructive and irreversible actions:** deleting or overwriting files the run did not create,
  history rewrites, force pushes, branch or tag deletion, dropping or migrating data, publishing or
  pushing outward, sending messages, and changing shared or external systems are destructive or
  irreversible. Any such action not listed below as authorized stops for the user's explicit
  confirmation under every policy, Unattended included, and halts the run when no reply can arrive.
  Actions implied by this plan's commit and push policy and worktree policy, and the final move of
  this plan into `archive/`, count as authorized. A Cluster orchestrator that meets an unauthorized
  one returns `halted`; an executor performs only the actions its prompt names. Authorized actions
  for this plan:
  None.
- **Usage gating:** check account usage with
  `"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/planner/scripts/usage-check.sh" --warn N --stop N`,
  with each N taken from the thresholds below. It prints one line,
  `status=<status> pct=<pct> source=<source> five_hour=<v> seven_day=<v> spend=<v>`, and exits
  0 `ok`, 10 `warn`, 20 `stop`, 21 `stop-cap`, 30 `unknown`, or 2 on an invalid argument (a plan
  error: halt and report).
  - The top orchestrator checks before dispatching each Cluster. After any check returns `warn` or
    `unknown`, the orchestrator running the Cluster (top or Cluster orchestrator) also checks
    before each Unit, until a check returns `ok`.
  - On `stop`: finish the gate of the Unit in flight, start nothing new, and log it. A Cluster
    orchestrator returns `usage-pause`. The top orchestrator sleeps one hour with a background
    shell `sleep 3600` (never a foreground sleep), re-checks, and repeats until the check returns
    `ok` or `warn` (below the stop threshold), then resumes from Appendix A.
  - On `stop-cap`: halt and report; a spend cap does not reset within hours, so never sleep on it.
    A Cluster orchestrator returns `halted` with the check's output line verbatim.
  - `unknown` is never treated as headroom: log it and keep checking before every Unit.
  - Log in Appendix B every check whose status differs from the previous check, and every sleep.
  Usage thresholds for this plan:
  warn 85, stop 95.
- **Progress record (durable):** this plan file is the progress record, so an interrupted run
  resumes where it stopped.
  - Appendix A: Progress holds one `- [ ]` line per Phase, Cluster, and Unit, in order, then the
    closing lines Holistic review, Final verification, Commit and push (per policy), Decisions
    review, and Archive. Mark a Unit `[x]` only after its gate passes; a Cluster only after all its
    Units are `[x]` and its Cluster review passes; a Phase only after all its Clusters are `[x]`; a
    closing line only after its step completes. Never mark ahead of the work.
  - Appendix B: Run log gets one line per retry, escalation, halt, stale mark found on resume,
    guard override, usage status change or sleep, and breaker count, in the form
    `- 2026-09-25 Unit 1.2.1: retried at haiku with failure context; breaker 1/5`. Replace its
    `- No entries yet.` line with the first entry.
  - Appendix C: Decisions log gets one line per decision made in place of the user, deviation from
    the plan, or anomaly, in the form
    `- D3 | 2026-09-25 | Unit 1.2.1 | decision | <what> | why: <reason> | review: pending`, where
    the fourth field is `decision`, `deviation`, or `anomaly` and D-numbers continue from the last
    entry. Replace its `- No entries yet.` line with the first entry.
  - Single writer: Clusters run one at a time, so one agent at a time edits this plan. While a
    Cluster orchestrator subagent runs, it alone marks its own Units and appends to Appendices B
    and C; the top orchestrator edits the plan at all other times. Appendices A, B, and C, and the
    Clusters and Units that Phase 0 answers change, are the only parts of this plan any
    orchestrator edits.
- **Automatic delegation (default on):** every substantive Unit defined below is dispatched to a
  subagent; no orchestrator implements a Unit itself. An orchestrator does only this: launching
  subagents, reading files back, running usage checks and verification/build/test/lint commands in
  the shell, making bounded corrective edits during verification (a few lines at most - anything
  larger becomes a corrective subagent), and (top orchestrator only, per the commit policy)
  committing. A plan may mark a genuinely trivial, low-risk Unit for direct execution instead of
  fan-out; delegation is the default, not a mandate for work that does not warrant it.
- **Models (role -> tier; fill per plan):** a default executor tier for prescriptive Units, an
  escalation one tier up (Haiku -> Sonnet -> Opus), Sonnet for Cluster orchestrators, a Cluster
  reviewer (Sonnet, or Opus where a Cluster's output needs judgment), a holistic reviewer (Opus),
  and a top orchestrator that is the model running this plan, at or above the model guard. Name
  each tier by its harness alias; prefer an alias over a frozen slug. If a required model cannot be
  launched, STOP and ask; never silently substitute.
  Units 1.1.1 and 1.1.2 run on Haiku (new files with exact content given) and Unit 1.2.1 on Sonnet (it must match an existing file's content and add tests), all through the `executor` agent; escalation is one tier up from each Unit's default, then steps back down. The top orchestrator is the session model, Sonnet or above. There is no Cluster orchestrator subagent in this plan: the top orchestrator runs both Clusters itself. The Cluster reviewer is Sonnet by default and the holistic reviewer is Opus.
- **Cluster orchestration:** run Clusters one at a time, in order. Each Cluster is run either by
  the top orchestrator itself or by a Sonnet Cluster orchestrator subagent, as named below.
  - For a Cluster orchestrator, dispatch `general-purpose` with `model: sonnet` in the foreground.
    Its prompt MUST inline: the absolute path of this plan file (for editing Appendices A, B, and C
    only), the working-directory root, the Cluster's Units in full with their waves and gates, each
    Unit's tier alias and escalation tier from the model-role map, the run policies with the halt
    policy's definition, the usage thresholds, the usage script path, the last usage status, the current
    breaker count and threshold, the authorized destructive actions, the environmental harnesses,
    and the protocol rules it must follow (Usage gating per Unit, Progress record, Automatic
    delegation, Worker type, Self-contained prompts with the six standing constraints, Completion
    message discipline, Failure escalation ladder, Run circuit breaker, Halt vs escalate,
    Verification gates, Sequencing and isolation, Corrective units, Environmental vs real
    failures, Recovery and re-planning, Destructive and irreversible actions, the return-status
    contract in the next sub-bullet, and "run no git command"), each rule's text copied from this
    block.
  - A Cluster orchestrator never asks the user anything (subagents do not have `AskUserQuestion`)
    and never sleeps; it returns exactly one status, with its breaker count and last usage status:
    `done` (every Unit gated and marked); `halted` (the question or blocker verbatim);
    `usage-pause` (a `stop` usage check); or `breaker` (the breaker threshold reached). A
    plan-invalidating failure returns `halted`. If it has no `Agent` tool (nesting turned off), it
    returns `halted` without doing any Unit itself, and the top orchestrator runs the Cluster.
  - On `done`, the top orchestrator runs the Cluster review. On `halted`, it resolves the question
    with the user per the halt policy and re-dispatches with the answer inlined. On `usage-pause`,
    it sleeps per **Usage gating** and re-dispatches the Cluster's unmarked Units. On `breaker`, it
    acts per **Run circuit breaker**. Only the top-level session uses `AskUserQuestion`.
  Cluster 1.1: top orchestrator. Cluster 1.2: top orchestrator.
- **Worker type:** dispatch every Unit that edits files to the `executor` subagent
  (`subagent_type: executor`) with `model:` set to that Unit's tier alias, unless this plan's
  model-role map assigns the Unit a different worker. If this harness has no `executor` agent, use
  a general read/write worker subagent (`general-purpose`) instead and say so in the blast-radius
  summary. Use a read-only subagent (`Explore`) only for pure investigation or independent
  verification that writes nothing; reviews go to a `general-purpose` reviewer told to write
  nothing. Orchestrators run build, test, and lint commands themselves in
  the shell rather than delegating them, so they keep authority over the gates; only the top
  orchestrator runs git. Dispatch every worker, verifier, and reviewer in the foreground, never
  backgrounded, so its result arrives before the next step; a backgrounded dispatch returns
  control while the orchestrator still waits on it.
- **Self-contained prompts:** subagents share no memory of this plan or this conversation. Each
  dispatched Unit prompt MUST inline, verbatim: the absolute file path(s) to touch, a one-sentence
  "why", the exact content or diff to apply (copied from the relevant section below), and the
  standing constraints below. NEVER tell a subagent to open, locate, or consult this plan or any
  other document to find or interpret its task; paste any context it needs directly into the
  prompt.
  1. "Read the target file(s) in full first; do not trust line numbers - locate code by content,
     not position."
  2. "Edit only the file(s) named in this prompt. Do not modify any other file. Do not run any
     git command. Do not run dependency or tidy commands unless this prompt explicitly says to."
  3. "After editing, run the project's configured formatter/linter on each changed file and fix
     anything it flags. If a fix would change content this prompt gives verbatim, STOP and report
     instead."
  4. "Report a terse summary of what changed, and explicitly flag anything in these instructions
     that did not match what you found in the file."
  5. "If anything here is ambiguous or needs information not present in this prompt, STOP and report
     the ambiguity rather than guessing."
  6. "Before reporting done, confirm each acceptance criterion in this prompt; if any cannot be met,
     STOP and report which one(s) and why."
- **Completion-message discipline:** require each subagent's completion message to be terse - one
  line of status, the path(s) of any file(s) changed or artifact(s) produced, and at most a few
  bullets on key decisions or anything flagged. Subagents must NOT paste file or document contents
  back; this keeps each orchestrator's context lean across a long, multi-dispatch run.
- **Failure escalation ladder (mechanical trouble):** when a subagent (a) returns a failure or
  error, (b) reports the instructions did not match the file (a snippet is not found, a line
  drifted), (c) makes no progress, or (d) produces a weak or incorrect result on a Unit whose
  requirements were clear:
  1. Retry the SAME Unit once, same model, same self-contained prompt plus the failure context
     (what the subagent reported, verbatim).
  2. If it still fails, re-dispatch the SAME Unit one model tier up, with the same prompt plus the
     failure context. Do not skip, half-apply, or improvise. Step back to the default tier for later
     Units: an escalation applies only to the Unit that needed it.
  3. If the escalated tier also cannot resolve it, or cannot be launched, STOP (a Cluster
     orchestrator returns `halted`) and ask the user. Never leave work partially applied or guess
     past a blocker.

  Log every retry and escalation in Appendix B as it happens.
- **Run circuit breaker:** keep one cumulative count of retries and escalations across the whole
  run - every Unit's attempts added together, carried in Appendix B so it survives an interrupted
  session and passed to and back from every Cluster orchestrator. Before starting each new retry or
  escalation, compare the count to the threshold below; if it has reached the threshold, pause (a
  Cluster orchestrator returns `breaker`) and report instead of continuing: give the count, which
  Units consumed it, and the current failure, then ask whether to continue, raise the threshold, or
  re-plan. A run that keeps escalating usually signals a bad plan or a systemic issue a stronger
  model will not fix, and unbounded escalation runs up cost.
  3 combined retries plus escalations across the whole run.
- **Halt vs escalate (route by cause):** escalating the model is only for the mechanical trouble
  above - a Unit that is hard but well specified. If a subagent instead stops because a decision is
  missing or contradictory, or information the task needs is not present in the prompt (genuine
  ambiguity), do NOT retry or escalate the model: a stronger model would only guess at the same
  missing decision. Route it through the halt policy. Under Unattended, and under Sparse for a
  minor call that does not change the outcome materially, make the decision to the best of your
  ability, log it in Appendix C, and re-dispatch with the decision inlined; never do this for a
  destructive or irreversible action. Otherwise halt (a Cluster orchestrator returns `halted`) and
  report: which Unit stopped, the exact missing or contradictory decision (quote the subagent's
  question), the options as you understand them and what is needed to choose, and that this is a
  halt rather than an escalation because it is a gap in the plan. Log the halt in Appendix B.
- **Verification gates (orchestrator, after each Unit or wave):** do not trust self-reports.
  Before starting dependent work, read the modified file(s) back to confirm intent, run the
  applicable checks for the changed scope (the linter, and the Unit's gate), and independently
  confirm each acceptance criterion. Prefer acceptance criteria expressed as a command that returns
  pass/fail, and run it, rather than judging subjectively. For a high-risk or reasoning-heavy Unit,
  optionally dispatch a separate read-only verifier subagent to check the output against the
  criteria independently instead of self-verifying. Mark the Unit `[x]` in Appendix A only after
  the checks pass. If an edit is wrong or drifted, make a bounded corrective edit yourself or
  dispatch one narrowly-scoped corrective Unit before proceeding.
  The authoritative gates for this plan, all run from `/path/to/orders-api/.worktrees/health-endpoint`, are: `npx tsc --noEmit`, `npm run lint`, and `npm test` (per-Unit, the narrower `npm test -- test/health.test.ts` for Unit 1.2.1).
- **Cluster review and refine (top orchestrator, after each Cluster):** dispatch a fresh read-only
  reviewer subagent (`general-purpose`, told to write nothing and run no git command other than
  `git diff`, `git status`, and `git show`; Sonnet by default, Opus where the Cluster's output
  needs judgment) with the Cluster's review criteria, its Units' intent, and the changed file paths
  inlined, to check the Cluster's changes against them. Turn each finding into a corrective Unit, run and gate
  it before the next Cluster starts, and re-review. Mark the Cluster `[x]` only after the review
  passes, and a Phase `[x]` once all its Clusters are. Under the Attended confirmation policy,
  pause before starting each Phase after the first.
- **Sequencing and isolation:** dispatch independent Units of one wave in one message (multiple
  subagent calls) so they run concurrently, then gate before the next wave. Before dispatching any
  parallel wave, verify the Units' declared file sets are disjoint; if they overlap, serialize them
  regardless of how the plan labeled their independence. Units that share a file, or that depend on
  types/signatures/tests an earlier Unit establishes, MUST run strictly sequentially, one at a
  time, because each subagent reads the file fresh and concurrent edits would clobber each other.
  Waves never span Clusters, and Clusters run one at a time. Parallel document-producing subagents
  must each write ONLY their own output file, must NOT read another parallel agent's file, and must
  NOT communicate; merging or reconciling their outputs is a separate, later dispatch.
  Phase 1 has two Clusters, run one at a time, in order: Cluster 1.1 (Wave 1 is Unit 1.1.1, no dependencies; Wave 2 is Unit 1.1.2 and depends on Unit 1.1.1's `checkDatabase` export), then Cluster 1.2 (Wave 1 is Unit 1.2.1 and depends on Cluster 1.1's `createHealthRouter` export). All waves are strictly sequential, one Unit at a time; there is no parallel wave in this plan.
- **Corrective units (verification):** if a build, test, or lint command fails, do not retry
  blindly. Read the exact failure output, trace it to the single file or Unit responsible, dispatch
  one narrowly-scoped corrective Unit with the failing message included verbatim, then re-run the
  check. Repeat until it passes cleanly.
- **Environmental vs real failures:** distinguish failures caused by unavailable infrastructure
  (Docker, ports, local databases or services) from genuine regressions. If a check fails only
  because its harness could not start, capture the output, note it as environmental in Appendix C
  as an `anomaly`, and do not block; if it fails to compile or a non-harness assertion fails, treat
  it as a real regression to fix.
  None: every gate in this plan runs without Docker, a live database, or a bound port, because the tests inject a fake pool. Any failure here is a real regression.
- **Recovery and re-planning:** the ladder above is for Unit-level trouble. If a failure instead
  reveals the plan itself is wrong (an assumption does not hold, a Phase's premise is invalid), do
  NOT push through or silently re-plan. Halt execution, surface the failure context, and offer to
  re-enter planning with that context folded in.
- **Commit policy:** subagents never run any git command, and every dispatched prompt says so.
  Commit, push, and clean up the worktree only as this plan's Run policies state, as a final,
  separate step by the top orchestrator after final verification passes, then mark "Commit and push
  (per policy)" in Appendix A. Remove a worktree only after its changes are committed, and never
  with `--force`; otherwise leave it in place and say so in the final report. Never open a PR
  unless the user explicitly requested it.
  Commit locally to the `health-endpoint` branch only, no push, as a final step after final verification passes. Remove the `.worktrees/health-endpoint` worktree only after that local commit succeeds, and never with `--force`; if the commit does not happen, leave the worktree in place and say so in the final report.
- **Final verification (top orchestrator):** after the last Cluster:
  1. Holistic review: dispatch a fresh read-only reviewer subagent (Opus by default) with the Goal,
     the Definition of Done, and the changed file paths inlined, to check the whole change set
     against them. Turn each finding into a corrective Unit, gate it, then mark "Holistic review".
  2. Run the full authoritative gates named above yourself, not via a subagent.
  3. Walk the Definition of Done item by item and check each one against the actual working tree or
     running behavior. A Unit's passing gate is not evidence for a Definition-of-Done item: a
     requirement no Unit implemented passes every Unit gate and still fails the plan.
  4. Classify any failure as environmental or real, per the rule above.
  5. If any Definition-of-Done item is unmet, name it and what is missing, do not report the run
     complete, and offer either one narrowly-scoped corrective Unit or re-planning when the gap is
     a planning miss rather than an implementation miss.

  Mark "Final verification" and report the run complete only when every Definition-of-Done item is
  verified satisfied.
- **Final report:** end every run with: this plan's absolute path and the working directory used
  (a worktree, or the live checkout with this plan's stated reason); the model that orchestrated,
  against the model guard; the run policies used; Phases, Clusters, and Units completed, skipped as
  already `[x]` and re-verified, and not run; every retry and escalation (which Unit, from which
  tier to which, and the outcome) and the final breaker count against the threshold; every usage
  pause and its length; any halt and the exact missing or contradictory decision behind it; the
  number of Appendix C entries; the final gate results and the per-item Definition-of-Done
  verification, naming any unmet item; and the artifacts produced plus commit, push, and worktree
  status (or `stop at ready for review`).
- **Decisions review (top orchestrator, after the final report):** walk every Appendix C entry
  marked `review: pending`, one at a time or in batches of up to four: give its context (what was
  decided, where, why, and the alternatives), then ask with `AskUserQuestion` whether to keep it or
  reopen it. Keep marks it `review: kept`. Reopen discusses it, records the outcome as
  `review: reopened - <outcome>`, and runs any corrective Unit the outcome needs before archiving:
  it reuses the working directory, or, when it was already removed, re-creates it on its existing
  branch with the Working directory section's re-create command, gates the Unit, re-runs final verification, and commits and cleans up per
  the commit policy.
  When no entry is pending, or once every entry is reviewed, mark "Decisions review" `[x]`. When no
  reply can arrive, leave the plan in place with "Decisions review" unchecked and the final report
  saying it awaits the decisions review; the next "execute this plan" runs only the review and the
  archive.
- **Archive:** once the decisions review is done (or Appendix C has no entries), mark "Archive"
  `[x]`, then move this plan file into the `archive/` subdirectory of the directory that holds it
  (creating it if needed, for example `mkdir -p <plans-dir>/archive`), keeping its filename. This
  plan authorizes that move itself. This is the last step of the run.

## Appendix A: Progress

- [ ] Phase 1: Add the health endpoint
  - [ ] Cluster 1.1: Database check and health router - review: a fresh read-only Sonnet reviewer
    confirms `checkDatabase` and `createHealthRouter` match the exact content given in Units 1.1.1
    and 1.1.2 verbatim, that `npx tsc --noEmit` exits 0, and that neither file was modified outside
    what its Unit specifies.
    - [ ] Unit 1.1.1 (Wave 1): Add the database connectivity check - gate: `npx tsc --noEmit` exits
      0, and `rg -q "export async function checkDatabase" src/health/checkDatabase.ts` exits 0.
    - [ ] Unit 1.1.2 (Wave 2): Add the health router - gate: `npx tsc --noEmit` exits 0, and
      `rg -q "createHealthRouter" src/health/router.ts` exits 0.
  - [ ] Cluster 1.2: Mount the router and add tests - review: a fresh read-only Sonnet reviewer
    confirms `src/app.ts` mounts `createHealthRouter(pool)` before `requireAuth`, that
    `test/health.test.ts` matches the exact content given in Unit 1.2.1 verbatim, and that
    `npm test -- test/health.test.ts`, `npx tsc --noEmit`, and `npm run lint` all exit 0.
    - [ ] Unit 1.2.1 (Wave 1): Mount the router before auth and add tests - gate:
      `npm test -- test/health.test.ts` exits 0 with both cases passing, `npx tsc --noEmit` exits 0,
      `npm run lint` exits 0, and `rg -n "app.use" src/app.ts` shows
      `app.use(createHealthRouter(pool));` on a lower line number than `app.use(requireAuth);`.
- [ ] Holistic review
- [ ] Final verification
- [ ] Commit and push (per policy)
- [ ] Decisions review
- [ ] Archive

## Appendix B: Run log

- No entries yet.

## Appendix C: Decisions log

- No entries yet.
