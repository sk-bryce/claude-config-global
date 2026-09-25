---
name: planner
description: |
  This skill should be used when the user asks to plan, design, or scope a multi-step piece of
  work before implementing it - e.g. "plan this", "make a plan for...",
  "design an approach for...", "plan out migrating...", or
  "finalize this into something executable". Produces a meaningful-slug Markdown plan file that
  runs itself: a one-line Goal, a testable Definition of Done, a minimum orchestrator tier, a
  worktree procedure, self-contained units grouped into dependency waves, a model-role map,
  per-unit acceptance gates, a Progress checklist and Run log, and an embedded, filled-in
  orchestration protocol, so telling any agent to execute the file is enough. Composes with native
  Plan Mode by upgrading an existing draft instead of re-planning. Does not execute plans and does
  not apply to single-question or single-edit requests. Scope: personal (~/.claude/skills/).
model: opus
effort: high
---

<!--
created: 2026-07-27
updated: 2026-09-25
spec: specs/behaviors.md (Plan and Execute section)
generated-by: Opus subagent, spec-driven migration plan execution (Phase 3 Workstream A); the
  shared-contract consistency check (Units section, check 5 of the refinement round checklist,
  verification gate) is a hand-edited addition tracked in specs/behaviors.md's Plan and Execute
  section. The refinement loop runs 2-5 rounds, with each round running the numbered checks below
  it. Renamed to planner on 2026-09-25, with the run procedure moved into the embedded protocol so
  plans run without a separate execution skill (see
  decisions/0010-single-planner-skill-with-self-running-plans.md); both are hand edits.
model: claude-opus-5-thinking-high
harness: Claude Code
-->

# Executable Plan Authoring

Produce a self-contained, agent-executable Markdown plan file that also carries its whole run
procedure. `references/subagent-orchestration.md` (synced from this repository's
`reference/subagent-orchestration.md`) is the source of truth for the orchestration protocol every
plan embeds; load it before writing the artifact. `examples/example-plan.md` is a complete,
filled-in plan of the shape this skill produces - read it before drafting your first plan.

This skill writes plans and never executes them. A finished plan runs when the user tells any agent
to execute it: the embedded protocol carries the tier check, pre-flight, dispatch, progress
tracking, and final report, so there is no separate execution skill
(`decisions/0010-single-planner-skill-with-self-running-plans.md`).

## Run planning judgment at the Opus tier

This skill is pinned `model: opus` because planning is judgment-heavy, so the guidance survives a
harness that drops the pin. The rule-guided steps below (directory resolution, artifact structure,
refinement loop, verification gate) hold at any session model. If the planning judgment itself
needs deeper reasoning on a harness that ignores the pin, ask the user to select a stronger model;
never silently substitute a weaker one and never report Opus-tier reasoning you did not actually
get.

Non-interactive research (reading the target code, mapping call sites, checking existing conventions)
may be fanned out to read-only subagents (`Task`/`Agent` with `subagent_type: Explore`). Dispatch
independent research subagents in one message; give each a self-contained prompt and require that
it writes no files.

## Compose with native Plan Mode; do not double-plan

1. Check first whether plan content already exists in this conversation - native Claude Code Plan
   Mode output, or a draft the user pasted or wrote with you. If it does, treat it as the draft to
   upgrade: keep its decisions, scope, and step order, and add only what the artifact structure below
   requires and it lacks. Do not re-interview the user from zero, do not discard its content, and do
   not produce a second competing plan artifact for the same request.
2. Never write the plan file while still inside Plan Mode. Claude routes writes through the permission
   callback and can degrade to advisory after an `ExitPlanMode` rejection. Exit Plan Mode first (or
   ask the user to approve exiting), then write the file.
3. Native Plan Mode owns enforced read-only exploration and the human approval gate. This skill owns
   executable content: self-contained units, dependency waves, the model-role map, the minimum
   orchestrator tier, per-unit acceptance gates, the Progress checklist and Run log, the refinement
   loop, and the plan-level verification gate.

## Read-only enforcement backstop

Rule 2 above is normally enough, but Claude Code's own Plan Mode enforcement can degrade to advisory
after an `ExitPlanMode` rejection. `${CLAUDE_CONFIG_DIR:-~/.claude}/scripts/read-only-plan-guard.sh`
is a `PreToolUse` hook's logic that denies `Write`/`Edit`/`MultiEdit` while `permission_mode` is
`"plan"`, as a hard backstop that cannot be bypassed by a mode change. Per
`${CLAUDE_CONFIG_DIR:-~/.claude}/decisions/0003-hooks-and-scripts-authoring-policy.md`, the script
exists but is NOT registered - registration is a deliberate human step. To register it, add this
block to this file's frontmatter above (do not have an agent add it for you):

```yaml
hooks:
  PreToolUse:
    - matcher: "Write|Edit|MultiEdit"
      hooks:
        - type: command
          command: "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/read-only-plan-guard.sh"
```

That command deliberately spells the fallback `$HOME/.claude` rather than the `~/.claude` used in
the prose above: this string is executed by a shell, and a tilde inside double quotes is left
literal, so `~` would resolve to a nonexistent path while `$HOME` expands correctly. It matches the
form every hook in `settings.json` already uses. Claude Code substitutes only `${CLAUDE_PROJECT_DIR}`,
`${CLAUDE_PLUGIN_ROOT}`, and `${CLAUDE_PLUGIN_DATA}` itself - ordinary variables expand because a
hook with no `args` key is handed to a shell. `${CLAUDE_PROJECT_DIR}` is not a substitute here; it
resolves to the project root, not the config directory.

Where this hook is not registered, native Plan Mode's write-block covers the human planning phase
and the read-only research-subagent dispatch above covers this skill's own fan-out, so the
constraint holds where a coarser permission model is all that is available.

## Right-size before building the machinery

Judge the task before doing any of the below.

- A single question (a name, an API detail, a one-line explanation) is not a planning request. Answer
  it directly; do not create a plan file.
- A genuinely trivial, low-risk change - a single-line rename, a typo, a comment, one file, no
  cross-file coupling and no schema, API, migration, or security surface - uses the escape hatch. Do
  one of: perform the change directly and say so, or write a minimal plan carrying only a Goal, a
  one-line Definition of Done, and a single unit explicitly marked `Direct execution - do not dispatch
  to a subagent`.
- Never manufacture multiple dependency waves or a multi-row model-role map for work that has one
  step.

Everything else gets the full artifact below.

## Intake: ask before planning, not after

Ask a clarifying question first when any of these is true: the Goal cannot be stated in one line; the
request is as vague as "just make it better"; the scope boundary (which files, services, or endpoints
are in play) is unknown; or the success condition cannot be made checkable. Ask one focused question
covering all blocking gaps (`AskUserQuestion`) rather than a series of them.

If the user declines to narrow it, still convert the vagueness into checkable conditions yourself and
record what you assumed in an `Assumptions` line in the plan. Never write a Definition of Done that
echoes the prompt's vagueness ("the code is cleaner", "it is better structured").

### Ask for the minimum orchestrator tier

Every full plan states the lowest model tier allowed to orchestrate it, and the embedded protocol
halts when the session running it is below that tier. Ask the user for it with `AskUserQuestion`
during intake, in the same call as any other intake question, unless they already named one. Offer
Sonnet and Opus, plus Haiku only for a plan whose gates are all commands and whose Definition of
Done needs no judgment. Put your recommendation first, labelled "(Recommended)": Sonnet when units
are prescriptive and every gate is a command, Opus when final verification or halt-vs-escalate calls
need judgment (reviewing prose, subjective Definition-of-Done items, a high-stakes migration). Never
pick the tier yourself when the user can be asked. If no answer can arrive (a non-interactive run),
use your recommendation and record it under Assumptions.

## Resolve the plans directory

Take the first rule that matches; state the resolved absolute path and which rule matched.

1. An explicitly-set native setting: a `plansDirectory` the user actually set in `settings.json`.
   The built-in `${CLAUDE_CONFIG_DIR:-~/.claude}/plans` default does NOT count as set.
2. Else a project agent-config directory under the working directory: `<cwd>/.claude/plans/`. Use
   this only when the `.claude/` directory already exists; create the `plans/` subdirectory if
   needed. If the working directory is itself a `.claude` directory (for example this repository,
   `~/.claude`), use `<cwd>/plans/` directly - there is no nested `.claude/` to create in that case.
3. Else the global `${CLAUDE_CONFIG_DIR:-~/.claude}/plans`.

Keep the resolved directory gitignored by default (`.claude/plans/`, for example via
`core.excludesfile`) so plans stay ephemeral; only version it when the user says they want to
track or share plans. Native plan modes do not follow rule 2, so this resolution is authoritative: if
a native mode already saved a draft elsewhere, still write the artifact to the resolved directory and
say where it went. `CLAUDE.md`'s rule for executing a plan by name searches in this same order; keep
the two in step.

## Write the plan artifact

Write the plan to a file - a chat-only plan does not survive compaction and cannot be executed
later. Filename: a meaningful kebab-case slug naming the work
(`express-to-fastify-migration.md`, `users-nullable-column-migration.md`), in the resolved plans
directory. Never `plan.md`.

Required sections, in this order.

1. **Goal** - one line stating the objective.
2. **Definition of Done** - the concrete, checkable conditions that mean the whole plan succeeded,
   verified once at the end rather than by the per-unit checks. Prefer conditions that are commands
   returning pass/fail or observable states ("`npm test` passes", "`GET /health` returns 503 when the
   DB is down"). Per-unit gates passing does not prove the Goal was met; that is what this section is
   for.
3. **Assumptions** (only when intake left something assumed) - one bullet per assumption.
4. **Execution requirements** - per the rules below.
5. **Working directory** - per the rules below.
6. **Model-role map** - a table of role to tier, per the rules below.
7. **Units and waves** - the work, per the rules below.
8. **Progress** - per the rules below.
9. **Run log** - per the rules below.
10. **Orchestration protocol** - the embedded block, per the rules below.

### Execution requirements

State two things:

- The minimum orchestrator tier the user chose at intake, and that the embedded protocol halts
  before doing anything when the session running it is on a lower tier.
- How to run the plan: a line of the form
  `execute the plan at /absolute/path/to/<slug>.md`, with the real absolute path, followed by the
  statement that the filled-in orchestration protocol makes the plan self-running, so telling any
  agent to execute it is enough and no separate skill is required.

### Working directory

Name the absolute root that every unit's paths sit under, and write the exact commands the
orchestrator runs, resolved while planning rather than left as a template.

- Default to a dedicated git worktree so a failed run is rolled back by deleting it. Run
  `git remote` in the project root while planning; never assume `origin`. Prefer the current
  branch's configured upstream (`git rev-parse --abbrev-ref '@{upstream}'`) when one is set, and
  name the base branch explicitly.
- Write, in order: the clean check (`git -C <project root> status --porcelain` must print
  nothing), the creation command
  (`git -C <project root> worktree add .worktrees/<slug> -b <slug> <remote>/<base>`), the resulting
  absolute root (`<project root>/.worktrees/<slug>`), and the rollback command
  (`git -C <project root> worktree remove .worktrees/<slug>`). Say that pre-flight reuses the
  worktree if it already exists from an earlier run.
- If the repository has no remote, branch from the current HEAD
  (`git worktree add .worktrees/<slug> -b <slug> HEAD`) and say so.
- Keep the worktree under the project directory so it inherits the project's tool permissions.
- Use the live checkout only with a stated reason (a trivial in-place change, the user asked, or a
  repository convention such as committing straight to the main branch). Name it, give the reason,
  and still write the clean check.
- If the plan defines a known-good baseline check, write it here too.

### Model-role map

Name tiers as Opus, Sonnet, and Haiku per this environment's Subagents & Models policy (`CLAUDE.md`),
and name each by its `opus` / `sonnet` / `haiku` alias at dispatch time. Prefer an alias over a
frozen version slug unless the user names one. Defaults:

| Role | Tier |
| --- | --- |
| Orchestrator | the session model running the plan, at or above the minimum orchestrator tier; never handed to a cheaper model |
| Default executor (prescriptive units: exact paths plus before/after content) | Haiku |
| Design-heavy or test-authoring units | Sonnet |
| Reasoning-heavy roles a plan defines (reviewer, collator, verifier) | map each explicitly, usually Sonnet or Opus |
| Escalation | one tier above the unit's default (Haiku -> Sonnet -> Opus), then step back down |

File-editing units go to the `executor` subagent with a per-unit `model:` override. When a unit
needs a different worker (for example a path the `executor` agent is barred from), name that worker
in its row.

Validate the Haiku-first default empirically rather than assuming it: if mechanical edits of this kind
have been failing often enough that the wasted attempt plus escalation costs more than starting on
Sonnet, default those units to Sonnet instead and say so in the plan's model-role map. If a required
tier cannot be launched on the target harness, STOP and ask the user; never silently substitute.

Every unit in the plan must map to a row here.

### Units

Each unit must inline everything its executor needs, because subagents share no memory of the plan or
the conversation. A unit states:

- The absolute file path(s) it touches, under the named working directory.
- A one-sentence "why".
- The exact content or diff to apply, complete enough that an agent holding only this unit's text can
  apply it without opening anything else.
- An acceptance gate: preferably a single shell command that returns pass/fail (`npx tsc --noEmit`,
  `pytest tests/test_health.py`, `rg -q "createRateLimiter" src/gateway/index.ts`), otherwise a
  concrete observable condition.

NEVER write a unit that tells a subagent to open, locate, or consult the plan, "the section above",
"the design doc", or any other document to find or interpret its own task. Repeating the same snippet
across two units is correct and expected; a cross-reference is a defect. Phrases like "as described
above", "see the plan", and "refer to Unit 1" inside unit content are disallowed - paste the content
instead.

### Shared contracts

When two or more units touch the same interface - one unit implements it while another tests or
consumes it (a response shape, a function signature, an event payload, a config schema) - author the
exact literal contract once, then paste that identical literal into every unit that implements, tests,
or consumes it. Never let two units each independently describe the same shape in their own prose or
their own literal values, even when both look reasonable in isolation: independently invented literals
drift (a status string, a key name, a field type) in ways that self-containment alone cannot catch, and
the mismatch only surfaces when the units run against each other. This is still self-contained per the
rule above - the literal is pasted whole into each unit, not cross-referenced - it is just not
independently re-derived.

### Waves

Group units into numbered waves and state what each wave depends on.

- Units in the same wave must touch disjoint file sets and must not depend on types, signatures,
  tests, or config an earlier unit in that same wave creates.
- Any two units that share a file go in different waves, regardless of how independent they look.
- Work that shares an ordering constraint or a single shared tool (one migration runner, one release
  train) is sequenced explicitly rather than fanned out.
- A wave boundary is a verification gate: the orchestrator runs the gates before the next wave starts.

### Progress and Run log

These two sections are the plan's durable progress record, so a run interrupted mid-way resumes
where it stopped. The embedded protocol tells the orchestrator how to update them.

- **Progress:** one line per unit, in wave order, every one starting unchecked:
  `- [ ] Unit 3 (Wave 2): Add the health router - gate: npx tsc --noEmit exits 0`. The gate text
  must match that unit's own acceptance gate exactly. Direct-execution units get a line too.
- **Run log:** starts as the single line `- No entries yet.` The orchestrator appends retries,
  escalations, halts, stale marks found on resume, tier overrides, and the running breaker count.

### Embedded orchestration protocol

Copy the fenced block under `## The protocol (embed this in an executable plan)` in
`references/subagent-orchestration.md` into the plan verbatim. Do not paraphrase, shorten, summarize,
or re-order it. Then fill every `<...>` placeholder with this plan's specifics:

| Placeholder | Fill with |
| --- | --- |
| `<Set the minimum orchestrator tier for this plan here.>` | the tier the user chose at intake: `Haiku.`, `Sonnet.`, or `Opus.` |
| `<Confirm the executor and escalation tiers, plus any reasoning-heavy roles, here.>` | this plan's model-role map, restated in one or two sentences, including any unit that uses a worker other than `executor` |
| `<Set the retry/escalation threshold for this plan here.>` | a concrete number of combined retries plus escalations for the whole run (default 3 for a plan under ~6 units, 5 for larger) |
| `<Name the authoritative build/test/lint gates for this plan here.>` | the exact build, test, and lint commands that count as a real pass or fail - never "run the tests" |
| `<List the waves and their dependency order here.>` | the numbered waves and what each depends on |
| `<Name the harnesses whose failure is environmental, not a regression, here.>` | the specific harnesses (Docker, a local DB, a port-bound service), or "none" |
| `<State the commit or cleanup step here, or "stop at ready for review".>` | the exact commit or cleanup step, or `stop at ready for review` |

A finished plan containing literal `<...>` placeholder text is a defect. Fix it before reporting done.

Keep the block's team guard sentence intact and unsoftened: the produced plan must instruct the
executing agent to use plain subagents only and to NOT propose or spawn an agent team (for example
Claude Code's agent teams via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) even if one is enabled in the
environment.

## Refine the plan: 2 to 5 rounds

Run at least 2 full rounds over the drafted file before presenting it as finished, and keep going up
to 5 rounds while the previous round still found something to fix. Each round runs every check below,
in order, and fixes what it finds:

1. Self-containment: read each unit as if you were a subagent holding only that unit's text. If
   anything needed is missing, inline it.
2. Dependency order: confirm each wave's units are truly independent of each other and that every
   dependency runs in an earlier wave. Check the file sets for overlap.
3. Definition of Done testability: every condition is a command or an observable state, not an
   adjective.
4. Cross-reference violations: scan unit content for "the plan", "above", "below", "see ", "refer to",
   and "this document", and inline whatever each one was pointing at.
5. Shared-contract consistency: for every pair of units where one implements an interface and another
   tests or consumes it, extract the literal values each one asserts (keys, status strings, shapes,
   signatures) and diff them side by side. A mismatch is a defect even if each unit is internally
   consistent and even if no runtime is available to execute the code and prove it - fix by making
   both units paste the same literal, not by picking whichever looks more plausible.
6. Model-role map completeness: every unit maps to a row; the escalation tier and any reasoning-heavy
   roles are named.
7. Progress fidelity: exactly one Progress line per unit, numbered the same, each gate identical to
   the unit's own acceptance gate.
8. Working directory: the commands are concrete, use the remote you verified rather than an assumed
   `origin`, and include the clean check and the rollback.
9. Tier: the minimum orchestrator tier in Execution requirements matches the one filled into the
   block.
10. Placeholders: no literal `<...>` text remains anywhere in the file.

## Plan-level verification gate

Before reporting done, re-read the written file and confirm each item, reporting the result of each:

- Every unit is self-contained: absolute file path(s), a one-sentence why, and the exact content or
  diff inline.
- Dependency order is explicit: numbered waves, and no two units sharing a file in one wave.
- The Definition of Done is testable, and is verified at the end rather than being just the per-unit
  checks.
- The Execution requirements section states the minimum orchestrator tier the user chose and the
  exact line to run the plan.
- The Working directory section names an absolute root and gives concrete clean-check, creation (or
  a stated live-checkout reason), and rollback commands, with no assumed `origin`.
- The authoritative build/test/lint gates are named, and every unit has its own acceptance gate.
- The Progress section has one unchecked line per unit whose gate matches the unit's, and the Run
  log section is present.
- Every pair of units sharing an interface (implementation and its test or consumer) pastes the same
  literal contract - no two units independently assert different literal values for the same shape.
- No unit says to consult the plan or any other document.
- The embedded orchestration block is present, every placeholder is filled, and the team guard is
  intact. **Verify this by diffing the embedded block against the source block in
  `references/subagent-orchestration.md`, not by reading it.** Every line of the source must appear
  in the plan except the placeholder lines you filled. A block transcribed by hand rather than
  copied can silently drop an entire bullet: the result still reads as complete prose and passes
  every other item in this gate, so nothing but a diff catches it. Observed 2026-09-08, where the
  `**Final report:**` bullet went missing and survived four refinement rounds.

If any item fails, fix the plan and re-run this gate rather than reporting it with caveats.

## Finish with a summary

Report: the absolute plan path and which plans-directory rule resolved it; the one-line Goal; the unit
and wave counts; the minimum orchestrator tier; the model-role map in one line; how many refinement
rounds ran; the pass result of each verification-gate item above; and the exact line to run the plan.
Do not paste the plan body back. Name any clarifying question still open. Do not begin implementing
the units - executing the plan is a separate, user-initiated step.
