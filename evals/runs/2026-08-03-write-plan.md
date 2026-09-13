# write-plan eval run - 2026-08-03 (real dynamic run)

## Harness and model

- Harness: Claude Code 2.1.220.
- Model running this orchestrating session: Sonnet 5 (`claude-sonnet-5`).
- Model used for the 16 dispatched subagents (8 with-skill + 8 baseline, `subagent_type:
  general-purpose`, no model override given): inherited the orchestrator's model, Sonnet 5. The
  `write-plan` skill's own frontmatter pins `model: opus`, but that pin takes effect only when
  Claude Code itself resolves and launches the skill's model; since these dispatches were ordinary
  `general-purpose` subagents that then invoked the skill via the `Skill` tool, they ran the
  skill's judgment on Sonnet, not Opus. This is a real, worth-flagging fact about this run's
  fidelity, not a fabricated result.

## Methodology

This is a real dynamic run, not a static review. Two isolated sandbox projects were built under
this session's scratchpad (never under `~/.claude` or the machine's real workspace root):

- `<scratch>/write-plan-eval-sandbox/` - used for cases 1-4 (with-skill and baseline both dispatched
  into this single shared sandbox).
- `<scratch>/write-plan-eval-sandbox-withskill/` and `<scratch>/write-plan-eval-sandbox-baseline/` -
  two fully separate sandbox copies, used for cases 5-8 (one variant per sandbox).

Each sandbox was its own git repo (`git init`, initial commit), with `.claude/settings.json` setting
`"plansDirectory"` to that sandbox's own `.claude/plans/` (an explicit, non-default setting, so
plans-directory-resolution rule 1 in `SKILL.md` matches), plus placeholder source files (`README.md`,
`src/api/`, `src/gateway/`, `src/service-{a,b,c}/`, `src/auth/`, `src/settings/`) so prompts
referencing "our REST API" etc. had something concrete to point at. For each of the 8 evals.json
cases, one with-skill subagent (given only the raw prompt plus a sandbox-boundary safety
instruction) and one baseline subagent (same, plus "do not use any planning skill") were dispatched,
both `subagent_type: general-purpose`, with no hint toward `write-plan` given to the with-skill
agent - auto-trigger was real, not scripted. All 16 subagent runs completed; every plan file was
read back directly by the orchestrator (not taken on the subagent's self-report) before grading.

### Methodology deviation found and corrected mid-run: cross-contamination in the shared sandbox

Cases 1-4 initially ran in one shared sandbox for both variants. For case 2, the with-skill agent
discovered the baseline agent's freshly-written `health-endpoint-plan.md` sitting in the sandbox
root (a side effect of the two variants sharing a directory and running concurrently) and explicitly
treated it as "the existing draft" the prompt referred to, pulling response-shape and timeout details
from it that were not present in the one-line prompt itself. This is not a security violation -
nothing left the sandbox - but it is a real test-validity confound: that specific with-skill run was
not a clean test of "does the agent correctly identify user-language referring to an existing draft,"
because a plan-shaped file happened to exist for reasons unrelated to the prompt. Caught, and fixed
before dispatching cases 5-8 by building two fully separate sandbox copies (one per variant) so no
such cross-talk could recur. Cases 1, 3, and 4 were checked and show no evidence of the same
contamination (case 1's with-skill plan cites no external draft; cases 3/4 produced no files in
either variant).

### Real correctness defect found in case 2's with-skill output (not one of evals.json's listed
### expectations, but a genuine quality finding worth recording)

`health-endpoint-db-check.md` Unit 3 (`src/api/health.js`) returns
`{"status":"ok","checks":{"db":"ok"}}` / `{"status":"unavailable","checks":{"db":"error"}}`, but
Unit 4's test file (`src/api/health.test.js`) asserts `{status:'ok',checks:{database:'ok'}}` and
`{status:'degraded',checks:{database:'unreachable'}}` - different key name (`db` vs `database`) and
different status string (`unavailable` vs `degraded`). Unit 4's own acceptance gate
(`npm test -- src/api/health.test.js`) would fail if actually run against Unit 3's implementation.
The plan's refinement passes and verification gate did not catch this because no Node.js runtime was
available in the sandbox to actually execute the test - the agent could only run static `grep`
checks, and its "all pass" self-report covered only what it could mechanically verify, not runtime
correctness. This is a real, narrow gap: the skill's plan-level verification gate should include an
explicit manual cross-check that any unit producing an implementation and a unit producing that
implementation's test agree on exact literal values, not just presence of required tokens, when the
plan cannot actually execute the code during drafting.

## Per-case results

Legend: [D] deterministic, [J] judgment.

### Case 1 - Express to Fastify migration (expected: auto-trigger, full artifact)

With-skill wrote `<sandbox>/.claude/plans/express-to-fastify-migration.md` (resolved via rule 1,
stated explicitly). Baseline wrote a plain `express-to-fastify-migration-plan.md` at the sandbox
root with no skill machinery, as expected for a no-skill baseline.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Meaningful-slug .md file in resolved plans directory | PASS | `express-to-fastify-migration.md` in `.claude/plans/`, not `plan.md` |
| 2 | [D] One-line Goal near top | PASS | "Replace the Express-based REST API in `src/api/` with an equivalent Fastify implementation, covering routing, middleware, and the centralized error handler." |
| 3 | [D] Testable Definition of Done | PASS | 6 checkable `npm`/`node`/`grep` commands, e.g. `grep -R "require('express')" src` must find nothing |
| 4 | [D] Every unit inlines what it needs, no "consult the plan" | PASS | Read all 6 units in full; each carries complete file content or diff inline, zero cross-reference phrases found |
| 5 | [D] Units grouped into dependency waves | PASS | 3 explicit waves (Wave 1: Units 1-4 parallel; Wave 2: Unit 5; Wave 3: Unit 6) with stated rationale |
| 6 | [D] Model-role map included | PASS | Table: Units 1-4 Haiku, Units 5-6 Sonnet, orchestrator Sonnet, escalation ladder stated |
| 7 | [D] Each unit has an acceptance gate | PASS | Every unit ends with a command-shaped gate (`grep -q ...`, `node --check ...`) |
| 8 | [D] Embedded orchestration block present, placeholders filled | PASS | All 6 named placeholders filled (models, threshold=3, gates, waves, environmental harness=npm registry only, commit policy=stop at ready for review); team-guard sentence intact |
| 9 | [J] Runs a refinement pass before presenting as finished | PASS | Agent reported 3 refinement passes; found and fixed 5 cross-reference violations before finishing |

Case 1: 9/9 pass (8 deterministic, 1 judgment).

### Case 2 - Finalize existing Plan-Mode draft (expected: upgrade, not re-plan)

With-skill wrote `<sandbox>/.claude/plans/health-endpoint-db-check.md`.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [J] Treats existing draft as upgrade base, not re-interview from zero | PASS, but confounded (see Methodology) | Agent's Assumptions section explicitly says the plan is "built on top of that draft rather than re-deriving the endpoint design from zero"; however the draft it found was the baseline agent's file, an artifact of shared-sandbox contamination, not purely the prompt's inline description |
| 2 | [D] Resulting plan has all required parts despite starting from a draft | PASS (structural), with a real defect noted separately | Goal, DoD, Assumptions, Working directory, Model-role map, Waves, Units, orchestration block all present in order; see the Unit 3/Unit 4 response-shape mismatch defect above |
| 3 | [D] No second competing plan artifact for the same request | PASS | Only one file in `.claude/plans/`; agent explicitly reported self-correcting an initial draft-of-its-own into alignment with the discovered file rather than leaving two versions |

Case 2: 3/3 pass (1 judgment, 2 deterministic), all with caveats recorded above - grade the case a
pass on the letter of the expectations, but treat it as a weaker signal than the other 7 cases due
to the sandbox-sharing confound and the internal defect.

### Case 3 - Celsius/Fahrenheit naming question (expected: no trigger)

Both with-skill and baseline: no file created, no skill invoked, direct naming answer given.

| # | Expectation | Result |
| --- | --- | --- |
| 1 | [D] No plan file created/referenced | PASS |
| 2 | [D] No orchestration/model-role-map machinery invoked | PASS |
| 3 | [D] Direct, brief answer to the naming question | PASS |

Case 3: 3/3 pass (all deterministic).

### Case 4 - Trivial `tmp` -> `elapsedMs` rename (expected: right-size escape hatch)

**Sandbox limitation affecting this case's validity:** the placeholder source files created for
this eval contain no actual function with a `tmp` local variable anywhere in the sandbox (verified
by both agents via grep). Neither variant could exercise "rename `tmp` directly" because there was
nothing real to rename.

With-skill: no file created, no skill invoked - correctly reasoned the request is a single-edit
task explicitly out of `write-plan`'s own stated scope, then stopped because the named target
doesn't exist rather than fabricating one. Baseline: same conclusion via first-principles reasoning,
also no file created.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [J] Recognizes task as trivial/low-risk rather than forcing heavyweight structure | PASS | Agent: "renaming one local variable inside one function is exactly that - a mechanical, single-line edit, not a multi-step piece of work" |
| 2 | [D] Does not fabricate multiple waves or a model-role map | PASS | No plan file was written at all, so trivially nothing was fabricated |
| 3 | [J] Either performs the rename directly, or writes a plan explicitly marked direct-execution | **FAIL (confounded)** | Agent did neither - it performed no rename (no real target existed) and wrote no plan of any kind (marked or otherwise); it asked for the actual file/function instead. This is a defensible response to a sandbox that doesn't contain the referenced code, but it does not satisfy the letter of this expectation, and the test as built cannot cleanly distinguish "skill behaved correctly" from "skill had nothing to act on." |

Case 4: 2/3 pass (1 deterministic pass, 1 judgment pass, 1 judgment fail attributable to a sandbox
gap rather than a skill defect). **Recommend a targeted re-run** with a real target file containing
an actual `tmp` local variable before trusting this expectation's signal.

### Case 5 - Rate limiting design (expected: auto-trigger, explicit waves, resolution, threshold,
commit policy)

With-skill wrote `<sandbox-withskill>/.claude/plans/gateway-rate-limiting.md`.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Resolves and states plans directory + matching rule | PASS | "matched via Rule 1 (explicitly-set `plansDirectory`...)" stated in the plan and the agent's own report |
| 2 | [D] Explicit dependency waves for multi-part work | PASS | 3 waves, strictly sequential, each with a stated dependency (Unit 3 needs Unit 1's and Unit 2's exports) |
| 3 | [D] States the retry/escalation circuit-breaker threshold | PASS | "Threshold for this plan: 3 combined retries plus escalations across the whole run" |
| 4 | [D] States the commit policy | PASS | "Stop at ready for review: leave the `gateway-rate-limiting` worktree and branch in place, uncommitted" |

Case 5: 4/4 pass (all deterministic).

### Case 6 - Three-service DB migration (expected: team-guard intact, named gates, service
sequencing)

With-skill wrote `<sandbox-withskill>/.claude/plans/users-nullable-column-migration.md`.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Orchestration block explicitly bars proposing/spawning an agent team | PASS | Verbatim: "Use plain subagents only: even if an agent-team feature is enabled in this environment, do NOT propose or spawn an agent team for this work." |
| 2 | [D] Names authoritative build/test/lint gates, not just "run the tests" | PASS | Named exact `rg`/`git diff --numstat` content checks per file (no real migration tooling exists in the sandbox to name instead - explicitly verified and stated) |
| 3 | [J] Sequences the three services with explicit dependency order rather than an uncoordinated parallel wave, given shared risk | **PASS, with a caveat worth flagging to the eval owner** | The plan puts all 3 services in **one parallel wave**, not a serial dependency order - but only after explicitly investigating the exact risk factor the expectation names (a shared migration tool) and documenting that none exists in this repo (independent `users` tables, no FK, disjoint files, no shared tooling found). This is a reasoned, investigated decision, not a naive default. Whether this counts as satisfying "explicit dependency order" depends on reading the expectation as "must serialize" (fail) vs. "must explicitly reason about shared risk" (pass) - graded PASS here since the model demonstrably did the latter, but this is a genuine judgment call worth the skill owner's attention, not a clean signal either way. |

Case 6: 3/3 pass (2 deterministic, 1 judgment-with-caveat).

### Case 7 - Vague "just make it better" auth refactor (expected: clarifying question or concrete
DoD)

With-skill: no file created; asked a clarifying question. Baseline: wrote a plain plan without
asking, explicitly flagging the placeholder-content gap.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [J] Asks a clarifying question about "better"/scope, or states a concrete testable DoD | PASS | Agent asked: "Can you clarify (1) which files/services actually make up the auth module... (2) what specifically is wrong with it today... (3) what 'better' means for this refactor..." rather than guessing |
| 2 | [D] If it proceeds without asking, DoD is checkable not vague | N/A (vacuously satisfied) | Did not proceed without asking, so this conditional does not trigger |

Case 7: 1/1 substantive pass (judgment), 1 vacuous.

### Case 8 - Dark mode settings page (expected: self-contained units, inlined absolute paths, named
working directory)

With-skill wrote `<sandbox-withskill>/.claude/plans/dark-mode-settings-page.md`.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] No unit tells a subagent to open/consult the plan | PASS | Read all 3 units in full; each carries complete file content inline, zero cross-reference phrases |
| 2 | [D] Each unit includes absolute file path(s) | PASS | All 3 units state a full absolute path under the named worktree |
| 3 | [D] Named working directory stated | PASS | Worktree path + exact `git worktree add` command + stated reason for branching from local `master` (no `origin` remote) |

Case 8: 3/3 pass (all deterministic).

## Aggregate

- **Trigger accuracy:** 8/8 cases showed the correct trigger/non-trigger decision. Case 3 correctly
  did not trigger; cases 1, 2, 5, 6, 8 correctly auto-triggered and wrote full artifacts; case 7
  triggered (matched the skill's own intake rule) but correctly stopped for a clarifying question
  instead of writing a file; case 4 correctly did not invoke the skill's heavyweight machinery, per
  the skill's own documented right-sizing escape hatch. **100% (8/8).**
- **Deterministic checks:** 24/24 pass. **100%.**
- **Judgment checks:** 5/6 pass (case 4's item 3 fails, confounded by a sandbox gap - see above).
  **83.3% (5/6).**
- **Prior baseline reference:** none - first real build. (The 2026-08-03 file this replaces was a
  static-review placeholder produced by a prior run that could not dispatch subagents; it explicitly
  stated it carried no real eval-run backing. This run supersedes it with an actual dynamic result.)

## Against thresholds (100% trigger, 100% deterministic, no judgment regression + >=90% judgment
## aggregate; no prior baseline so no-regression is vacuous)

- Trigger: 100% - **met**.
- Deterministic: 100% - **met**.
- Judgment: 83.3% - **not met** (threshold is >=90%).

## Decision: HOLD

Trigger accuracy and every deterministic check passed cleanly across all 8 cases - the skill's
structure, directory resolution, self-containment, and orchestration-block machinery are solid. The
one judgment shortfall (case 4, item 3) is directly attributable to a gap in this eval sandbox, not
a demonstrated skill defect: the sandbox contains no real `tmp` variable in any function, so neither
the with-skill nor the baseline agent had a real rename to perform, and the with-skill agent's
"ask for the actual target" response - while reasonable - could not be graded as a clean pass or
fail against "either rename directly or write a plan marked for direct execution." Recommend: add a
real target file/function containing an actual `tmp` local variable to the eval sandbox and re-run
case 4 alone; if it then passes cleanly, this run's aggregate would clear the 90% judgment bar and
the decision would become SHIP. Separately worth the skill owner's attention (not blocking, not one
of evals.json's listed expectations): the case 6 sequencing judgment call (parallel wave vs. explicit
serialization, see above) and the case 2 cross-unit response-shape defect the plan's own
static-only verification gate could not catch.

## Methodology note

This was a real dynamic run: 16 actual subagent dispatches (8 with-skill, 8 baseline) into
disposable, isolated sandbox projects under this session's scratchpad, never under `~/.claude` or
the machine's real workspace root. Every graded plan file was read back and verified directly by
the orchestrator, not taken on a subagent's self-report. One real methodology issue was found mid-run
(shared-sandbox cross-contamination affecting case 2) and corrected for the remaining cases by
switching to fully separate per-variant sandboxes. Nothing was written to the real
`~/.claude/plans`, and no git operation touched `~/.claude` or the machine's real workspace root
at any point (verified after the run: `~/.claude/plans` is empty, and that workspace root's
contents are all pre-existing and untouched).
