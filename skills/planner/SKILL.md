---
name: planner
description: |
  This skill should be used when the user asks to plan, design, or scope a multi-step piece of
  work before implementing it - e.g. "plan this", "make a plan for...",
  "design an approach for...", "plan out migrating...", or
  "finalize this into something executable". Asks the plan-shaping and run-policy questions, then
  writes a plan-YYYY-MM-DD-<slug>.md file that runs itself: Phases of Clusters of self-contained
  Units in waves, a model-role map, per-Unit gates, usage gating, Progress, Run log, and Decisions
  log appendices, and an embedded, filled-in protocol that reviews its decisions with the user and
  archives the plan. Composes with native Plan Mode by upgrading an existing draft instead of
  re-planning. Does not execute plans and does not apply to single-question or single-edit
  requests. Scope: personal (~/.claude/skills/).
model: opus
effort: high
---

<!--
created: 2026-07-27
updated: 2026-09-29
spec: specs/behaviors.md (Plan and Execute section)
generated-by: Opus subagent, spec-driven migration plan execution (Phase 3 Workstream A); the
  shared-contract consistency check (Units section, check 5 of the refinement round checklist,
  verification gate) is a hand-edited addition tracked in specs/behaviors.md's Plan and Execute
  section. The refinement loop runs 2-5 rounds, with each round running the numbered checks below
  it. Renamed to planner on 2026-09-25, with the run procedure moved into the embedded protocol so
  plans run without a separate execution skill (see
  decisions/0010-single-planner-skill-with-self-running-plans.md); both are hand edits. Rewritten
  by an Opus executor from the Plan and Execute spec on 2026-09-25 for decision
  decisions/0011-planner-work-hierarchy-run-policies-and-usage-gating.md. Appendix C `answer`
  entries for the user's run-time replies are a hand edit tracked in the same spec section, and so
  is the review-md pass after refinement.
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
to execute it: the embedded protocol carries the model guard, pre-flight and resume, the run
policies, usage gating, dispatch, Cluster review, in-file tracking, the final report, the decisions
review, and archiving, so there is no separate execution skill
(`decisions/0010-single-planner-skill-with-self-running-plans.md`, extended by
`decisions/0011-planner-work-hierarchy-run-policies-and-usage-gating.md`).

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
   not produce a second competing plan artifact for the same request. Still ask any run-policy
   question the draft or the user has not already answered.
2. Never write the plan file while still inside Plan Mode. Claude routes writes through the permission
   callback and can degrade to advisory after an `ExitPlanMode` rejection. Exit Plan Mode first (or
   ask the user to approve exiting), then write the file.
3. Native Plan Mode owns enforced read-only exploration and the human approval gate. This skill owns
   executable content: the run policies, the Phase > Cluster > Unit hierarchy with its waves, the
   model-role map, per-Unit acceptance gates, per-Cluster orchestrators and review criteria, the
   three appendices, the refinement loop, and the plan-level verification gate.

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
  one-line Definition of Done, and a single Unit explicitly marked `Direct execution - do not dispatch
  to a subagent`.
- Never manufacture multiple Phases, Clusters, or waves, or a multi-row model-role map, for work
  that has one step.

Everything else gets the full artifact below.

## Intake: ask before planning, not after

### Surface every plan-shaping ambiguity first

Before drafting, identify as many ambiguities and open questions as you can. Ask a clarifying
question when any of these is true: the Goal cannot be stated in one line; the request is as vague
as "just make it better"; the scope boundary (which files, services, or endpoints are in play) is
unknown; or the success condition cannot be made checkable. Ask every question that affects the
shape of the plan with `AskUserQuestion`, at most four questions per call, your recommendation first
and labelled "(Recommended)". Skip anything the user already answered.

Anything that would change the Goal, the Definition of Done, the Phase structure, or the run
policies is asked now, never deferred. Questions that remain unanswerable at planning time and could
only add, remove, or change Clusters or Units become Phase 0 (see "Phase 0" below).

If the user declines to narrow it, still convert the vagueness into checkable conditions yourself and
record what you assumed in the plan's Assumptions section. Never write a Definition of Done that
echoes the prompt's vagueness ("the code is cleaner", "it is better structured").

### Ask the run-policy questions

Ask these five questions with `AskUserQuestion`, using this option text, batched with the
plan-shaping questions at most four questions per call. Put the recommendation first, labelled
"(Recommended)"; the recommendation is the default shown unless the task gives a reason to
recommend another. Skip any question the user already answered.

1. "Which model guard should the plan include?" - Opus (default), Sonnet, Fable, None. The plan's
   first protocol step checks the session model and refuses to run when it is below the guard, in
   the order Haiku < Sonnet < Opus < Fable. None skips the check. This replaces the older minimum
   orchestrator tier. Recommend Sonnet instead of the Opus default when Units are prescriptive and
   every gate is a command; keep Opus when final verification or halt-vs-escalate calls need
   judgment (reviewing prose, subjective Definition-of-Done items, a high-stakes migration).
2. "What should the halt policy of this plan be?" - Sparse: only stop on genuine ambiguity or
   issues, otherwise the agent makes decisions to the best of its ability (default); Unattended: do
   not stop, the agent makes all decisions to the best of its ability; Attended: the agent can stop
   and ask the user for any decision or ambiguity.
3. "How much confirmation should the plan aim to have?" - Startup: confirm to proceed only after
   pre-flight and Phase 0 (default); Attended: also confirm between each Phase; Unattended: skip all
   confirmation, including pre-flight and Phase 0.
4. "Should changes be made using a worktree?" - Yes, use a worktree and clean it up after (default);
   Yes, use a worktree and leave it when finished; No, work directly in the main checkout of the
   repo.
5. "What should the commit and push policy of this plan be?" - Commit and push to the indicated
   branch; Commit to the indicated branch locally only, no push; Do not commit or push any changes.
   There is no fixed default: recommend from the repository's own convention and name the branch.

Ask questions 4 and 5 only when the plan changes a git repository. When it does not, record the
worktree and commit and push policies as "not applicable" in Run policies.

### Identify and authorize destructive actions

List every destructive or irreversible action the plan will need: deleting or overwriting files the
run did not create, history rewrites, force pushes, branch or tag deletion, dropping or migrating
data, publishing or pushing outward, sending messages, and changing shared or external systems. Ask
the user to authorize each one explicitly. Actions implied by the chosen commit and push policy count
as authorized, as does the plan's final move into `archive/`. Any action the user does not authorize
stays out of the authorized list; the protocol then stops for confirmation if the run meets it, under
every policy.

### Flag conflicting answers

Before writing, check the answers against each other. "Yes, use a worktree and clean it up after"
with "Do not commit or push any changes" would delete the work, so ask which one to change rather
than picking.

### Decide whether Phase 0 is needed

Phase 0 exists only when questions for the user are known at planning time but could not be answered
then, and their answers could only add, remove, or change Clusters and Units. If every plan-shaping
question was answered, the plan has no Phase 0.

### When no answer can arrive

In a non-interactive run, use the defaults (Opus guard, Sparse halt, Startup confirmation, worktree
with cleanup, and your recommended commit and push policy from the repository's convention),
authorize no destructive action, and record each of these under Assumptions. Never pick an answer
yourself when the user can be asked.

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
say where it went. Completed plans move themselves into that directory's `archive/` subdirectory.
`CLAUDE.md`'s rule for executing a plan by name searches in this same order, matching
`plan-*-<slug>.md` or the legacy `<slug>.md`; keep the two in step.

## Write the plan artifact

Write the plan to a file - a chat-only plan does not survive compaction and cannot be executed
later. Filename: `plan-YYYY-MM-DD-<slug>.md` in the resolved plans directory, where the date is the
day the plan is written (`date +%F`) and the kebab-case slug names the goal and the work it contains
(`plan-2026-09-25-express-to-fastify-migration.md`). Never a generic slug such as `plan` or `work`.

Required sections, in this order, with these exact headings where the embedded block refers to them
(`## Run policies`, `## Working directory`, `## Phases`, `## Appendix A: Progress`,
`## Appendix B: Run log`, `## Appendix C: Decisions log`):

1. **Goal** - one line stating the objective.
2. **Definition of Done** - the concrete, checkable conditions that mean the whole plan succeeded,
   verified once at the end rather than by the per-Unit checks. Prefer conditions that are commands
   returning pass/fail or observable states ("`npm test` passes", "`GET /health` returns 503 when the
   DB is down"). Per-Unit gates passing does not prove the Goal was met; that is what this section is
   for.
3. **Assumptions** (only when something was assumed) - one bullet per assumption.
4. **`## Run policies`** - per the rules below.
5. **Execution requirements** - per the rules below.
6. **`## Working directory`** - per the rules below.
7. **Model-role map** - a table of role to tier, per the rules below.
8. **`## Phases`** - the work: Phase 0 only when needed, then Phase 1 onward, each holding Clusters,
   each holding Units grouped into waves, per the rules below.
9. **Orchestration protocol** - the embedded block with every placeholder filled, per the rules
   below.
10. **`## Appendix A: Progress`** - per the rules below.
11. **`## Appendix B: Run log`** - per the rules below.
12. **`## Appendix C: Decisions log`** - per the rules below.

### Run policies

List, one bullet each, the values chosen at intake:

- Model guard: Opus, Sonnet, Fable, or None.
- Halt policy: Sparse, Unattended, or Attended.
- Confirmation policy: Startup, Attended, or Unattended.
- Worktree policy: the chosen option, or "not applicable" when the plan changes no git repository.
- Commit and push policy, naming the branch, or "not applicable".
- Usage thresholds: warn 85, stop 95 unless the plan says otherwise. You may change them without
  asking when the work warrants it; say why.
- Authorized destructive or irreversible actions: each one the user authorized, or "none".

The same values fill the embedded block's placeholders.

### Execution requirements

State two things:

- The model guard from Run policies, and that the embedded protocol halts before doing anything
  when the session running it is below the guard (Haiku < Sonnet < Opus < Fable), unless the guard
  is None.
- How to run the plan: a line of the form
  `execute the plan at /absolute/path/to/plan-YYYY-MM-DD-<slug>.md`, with the real absolute path,
  followed by the statement that the filled-in orchestration protocol makes the plan self-running,
  so telling any agent to execute it is enough and no separate skill is required.

### Working directory

Name the absolute root that every Unit's paths sit under, and write the exact commands the
orchestrator runs, resolved while planning rather than left as a template. The worktree policy
answer decides the shape.

- For either worktree option, run `git remote` in the project root while planning; never assume
  `origin`. Prefer the current branch's configured upstream
  (`git rev-parse --abbrev-ref '@{upstream}'`) when one is set, and name the base branch
  explicitly. Write, in order: the clean check (`git -C <project root> status --porcelain` must
  print nothing), the creation command
  (`git -C <project root> worktree add .worktrees/<slug> -b <slug> <remote>/<base>`), the resulting
  absolute root (`<project root>/.worktrees/<slug>`), and the rollback command
  (`git -C <project root> worktree remove .worktrees/<slug>`). Say that pre-flight reuses the
  worktree if it already exists from an earlier run.
- For "Yes, use a worktree and clean it up after", say the worktree is removed as the final step
  only after its changes are committed, never with `--force`. For "Yes, use a worktree and leave it
  when finished", say it stays in place and the final report names it.
- If the repository has no remote, branch from the current HEAD
  (`git worktree add .worktrees/<slug> -b <slug> HEAD`) and say so.
- Keep the worktree under the project directory so it inherits the project's tool permissions.
- For "No, work directly in the main checkout of the repo", name the live checkout as the root, give
  the reason (the user chose it, a trivial in-place change, or a repository convention such as
  committing straight to the main branch), and still write the clean check.
- When the plan changes no git repository, name the absolute root, say no worktree or git step
  applies, and write a non-git clean check (for example, list the root's files the plan will touch
  and confirm none has changed since planning), or state that none applies.
- For "Yes, use a worktree and clean it up after", also write the command that re-creates the
  worktree on its existing branch (`git worktree add .worktrees/<slug> <slug>`), used when a
  reopened decision needs a corrective Unit after cleanup.
- If the plan defines a known-good baseline check, write it here too.

### Model-role map

Name tiers as Opus, Sonnet, and Haiku per this environment's Subagents & Models policy (`CLAUDE.md`),
and name each by its `opus` / `sonnet` / `haiku` alias at dispatch time. Prefer an alias over a
frozen version slug unless the user names one. Defaults:

| Role | Tier |
| --- | --- |
| Top orchestrator | the session model running the plan, at or above the model guard; never handed to a cheaper model |
| Cluster orchestrator (where a Cluster names one) | Sonnet (`general-purpose`, foreground) |
| Default executor (prescriptive Units: exact paths plus before/after content) | Haiku |
| Design-heavy or test-authoring Units | Sonnet |
| Cluster reviewer | Sonnet, or Opus where the Cluster's output needs judgment |
| Holistic reviewer | Opus |
| Other reasoning-heavy roles a plan defines (collator, verifier) | map each explicitly, usually Sonnet or Opus |
| Escalation | one tier above the Unit's default (Haiku -> Sonnet -> Opus), then step back down |

File-editing Units go to the `executor` subagent with a per-Unit `model:` override. When a Unit
needs a different worker (for example a path the `executor` agent is barred from), name that worker
in its row.

Validate the Haiku-first default empirically rather than assuming it: if mechanical edits of this kind
have been failing often enough that the wasted attempt plus escalation costs more than starting on
Sonnet, default those Units to Sonnet instead and say so in the plan's model-role map. If a required
tier cannot be launched on the target harness, STOP and ask the user; never silently substitute.

Every Unit in the plan must map to a row here.

### Phases, Clusters, Units, and waves

- **Phase:** the largest unit of work, sized for the top-level orchestrator (an Opus or Sonnet
  session). Numbered from 1. Phase 0 exists only for questions known at planning time but not
  answerable then; list each question with its options and say which Clusters or Units each answer
  could add, remove, or change.
- **Cluster:** a logical grouping of Units inside a Phase, sized for a Sonnet orchestrator. Clusters
  run one at a time, in order. Each Cluster states:
  - Its orchestrator: "top orchestrator" or "Sonnet Cluster orchestrator subagent". Default to a
    Sonnet Cluster orchestrator subagent for a Cluster of 3 or more Units or with verbose gates.
  - Its review criteria: what the read-only Cluster reviewer checks the Cluster's changes against
    before the next Cluster starts, concrete enough to pass or fail.
- **Unit:** the smallest unit of work, clearly and concretely defined and self-contained, sized for
  a Haiku (sometimes Sonnet) executor. "Unit" is used rather than "Task" because "Task" collides
  with the `Task` dispatch tool and `TaskCreate`/`TaskUpdate`.
- **Waves:** parallel groupings of Units inside one Cluster, not a fourth level, and never spanning
  Clusters. Number them within their Cluster and state what each wave depends on.
  - Units in the same wave must touch disjoint file sets and must not depend on types, signatures,
    tests, or config an earlier Unit in that same wave creates.
  - Any two Units that share a file go in different waves, regardless of how independent they look.
  - Work that shares an ordering constraint or a single shared tool (one migration runner, one
    release train) is sequenced explicitly rather than fanned out.
  - A wave boundary is a verification gate: the orchestrator runs the gates before the next wave
    starts.
- **IDs are hierarchical:** Phase 2, Cluster 2.1, Unit 2.1.3. Wave numbers are local to their
  Cluster. Use the same IDs everywhere: in `## Phases`, in the filled placeholders, and in
  Appendix A.

### Units

Each Unit must inline everything its executor needs, because subagents share no memory of the plan or
the conversation. A Unit states:

- Its hierarchical ID, title, and wave.
- The absolute file path(s) it touches, under the named working directory.
- A one-sentence "why".
- The exact content or diff to apply, complete enough that an agent holding only this Unit's text can
  apply it without opening anything else.
- An acceptance gate: preferably a single shell command that returns pass/fail (`npx tsc --noEmit`,
  `pytest tests/test_health.py`, `rg -q "createRateLimiter" src/gateway/index.ts`), otherwise a
  concrete observable condition.

NEVER write a Unit that tells a subagent to open, locate, or consult the plan, "the section above",
"the design doc", or any other document to find or interpret its own task. Repeating the same snippet
across two Units is correct and expected; a cross-reference is a defect. Phrases like "as described
above", "see the plan", and "refer to Unit 1.1.1" inside Unit content are disallowed - paste the
content instead.

### Shared contracts

When two or more Units touch the same interface - one Unit implements it while another tests or
consumes it (a response shape, a function signature, an event payload, a config schema) - author the
exact literal contract once, then paste that identical literal into every Unit that implements, tests,
or consumes it. Never let two Units each independently describe the same shape in their own prose or
their own literal values, even when both look reasonable in isolation: independently invented literals
drift (a status string, a key name, a field type) in ways that self-containment alone cannot catch, and
the mismatch only surfaces when the Units run against each other. This is still self-contained per the
rule above - the literal is pasted whole into each Unit, not cross-referenced - it is just not
independently re-derived.

### Appendices

The three appendices are the plan's durable record, so a run interrupted mid-way resumes where it
stopped. They, plus Phase 0's own Clusters and Units when Phase 0 changes them, are the only parts of
the plan the orchestrators edit. The embedded protocol tells them how.

- **`## Appendix A: Progress`:** a nested checklist, one line per Phase, Cluster, and Unit, in
  order, every one starting `- [ ]`. Include Phase 0 when the plan has one. Cluster lines carry the
  Cluster's review criteria. Unit lines carry the Unit's gate verbatim, in the form
  `- [ ] Unit 1.2.1 (Wave 1): <title> - gate: <gate>`, and the gate text must match that Unit's own
  acceptance gate exactly. Direct-execution Units get a line too. The checklist ends with these
  closing lines, in order: Holistic review, Final verification, Commit and push (per policy),
  Decisions review, Archive.
- **`## Appendix B: Run log`:** starts as the single line `- No entries yet.` The orchestrator
  appends one line per retry, escalation, halt, stale mark found on resume, guard override, usage
  status change or sleep, breaker count, and bare go-ahead at a confirmation pause, in the form
  `- 2026-09-25 Unit 1.2.1: retried at haiku with failure context; breaker 1/5`.
- **`## Appendix C: Decisions log`:** starts as the single line `- No entries yet.` The
  orchestrator appends one line per decision made in place of the user, deviation from the plan, or
  anomaly, in the form
  `- D3 | 2026-09-25 | Unit 1.2.1 | decision | <what> | why: <reason> | review: pending`, where the
  fourth field is `decision`, `deviation`, `anomaly`, or `answer`. It also appends one `answer`
  entry per reply the user gives during the run that decides or changes something, in the form
  `- D4 | 2026-09-25 | Unit 1.2.1 | answer | <question> -> <reply> | why: <cause> | review: n/a`
  (the third field names the Unit, Cluster, `Phase 0`, or `pre-flight` it arose in), so a resumed
  or compacted run finds the answer in the plan instead of re-asking. The embedded
  protocol carries the full rule; run answers belong in the plan, not in a memory file. After the
  final report the orchestrator walks each pending entry with the user, then archives the plan.

The usage gating these records log runs through
`${CLAUDE_CONFIG_DIR:-~/.claude}/skills/planner/scripts/usage-check.sh`, which the embedded block
already names; confirm it exists while planning, and list it among the tools pre-flight checks.

### Embedded orchestration protocol

Copy the fenced block under `## The protocol (embed this in an executable plan)` in
`references/subagent-orchestration.md` into the plan verbatim, starting at its first line
`## Orchestration protocol (read before executing this plan)`. Do not paraphrase, shorten,
summarize, or re-order it, and do not wrap it in a code fence in the plan. Then replace each of its
12 placeholder lines with this plan's value, keeping the two-space indent:

| Placeholder | Fill with |
| --- | --- |
| `<Set the model guard for this plan here.>` | `Opus.`, `Sonnet.`, `Fable.`, or `None.` |
| `<Set the halt policy for this plan here.>` | `Sparse.`, `Unattended.`, or `Attended.` |
| `<Set the confirmation policy for this plan here.>` | `Startup.`, `Attended.`, or `Unattended.` |
| `<Set the usage thresholds for this plan here.>` | the warn and stop percentages, by default `warn 85, stop 95.` |
| `<List the authorized destructive or irreversible actions for this plan here, or "none".>` | each action the user authorized during planning, or `none` |
| `<Confirm the executor and escalation tiers, plus any reasoning-heavy roles, here.>` | the model-role map in one or two sentences, including any Unit that uses a worker other than `executor` |
| `<Name the orchestrator of each Cluster here.>` | per Cluster ID: `top orchestrator` or `Sonnet Cluster orchestrator subagent` |
| `<Set the retry/escalation threshold for this plan here.>` | a number: default 3 for a plan under about 6 Units, 5 for larger plans |
| `<Name the authoritative build/test/lint gates for this plan here.>` | the exact commands that count as a real pass or fail - never "run the tests" |
| `<List the Phases, Clusters, and waves and their dependency order here.>` | the hierarchy with each dependency named |
| `<Name the harnesses whose failure is environmental, not a regression, here.>` | the specific harnesses (Docker, a local database, a network service), or `none` |
| `<State the commit, push, and worktree cleanup steps here, or "stop at ready for review".>` | the exact commands implied by the commit and push policy and the worktree policy |

A finished plan in which any of these 12 placeholder lines is still unfilled is a defect. Fix it
before reporting done. The block's other `<...>` tokens (format templates such as `<status>` and
`<plans-dir>`) are copied as-is.

Keep the block's team guard sentence intact and unsoftened: the produced plan must instruct the
executing agent to use plain subagents only and to NOT propose or spawn an agent team (for example
Claude Code's agent teams via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) even if one is enabled in the
environment.

## Refine the plan: 2 to 5 rounds

Run at least 2 full rounds over the drafted file before presenting it as finished, and keep going up
to 5 rounds while the previous round still found something to fix. Each round runs every check below,
in order, and fixes what it finds:

1. Self-containment: read each Unit as if you were a subagent holding only that Unit's text. If
   anything needed is missing, inline it.
2. Dependency order: confirm each wave's Units are truly independent of each other and that every
   dependency runs in an earlier wave of the same Cluster or an earlier Cluster. Check the file sets
   for overlap.
3. Definition of Done testability: every condition is a command or an observable state, not an
   adjective.
4. Cross-reference violations: scan Unit content for "the plan", "above", "below", "see ", "refer to",
   and "this document", and inline whatever each one was pointing at.
5. Shared-contract consistency: for every pair of Units where one implements an interface and another
   tests or consumes it, extract the literal values each one asserts (keys, status strings, shapes,
   signatures) and diff them side by side. A mismatch is a defect even if each Unit is internally
   consistent and even if no runtime is available to execute the code and prove it - fix by making
   both Units paste the same literal, not by picking whichever looks more plausible.
6. Model-role map completeness: every Unit maps to a row; the escalation tier, Cluster orchestrator,
   reviewers, and any reasoning-heavy roles are named.
7. Clusters: every Cluster names its orchestrator and its review criteria, and the orchestrator
   matches the `<Name the orchestrator of each Cluster here.>` fill.
8. IDs and progress fidelity: hierarchical IDs are consistent between `## Phases` and Appendix A.
   Appendix A has exactly one line per Phase, Cluster, and Unit, in order, plus the five closing
   lines; each Unit line's gate is identical to the Unit's own acceptance gate.
9. Appendices B and C exist, each with its `- No entries yet.` line.
10. Working directory: the commands follow the worktree policy, are concrete, use the remote you
    verified rather than an assumed `origin`, and include the clean check and, for a worktree, the
    rollback.
11. Run policies: every value in `## Run policies` matches its filled placeholder (model guard, halt,
    confirmation, usage thresholds, authorized destructive actions, and the commit, push, and
    worktree cleanup steps), and the model guard in Execution requirements matches too.
12. Destructive actions: every destructive or irreversible action the plan needs is listed as
    authorized, or the list says "none".
13. Phase 0: present only when questions known at planning time were left unanswered, and absent
    otherwise.
14. Filename: the file is named `plan-YYYY-MM-DD-<slug>.md` with the writing date and a slug that
    names the work.
15. Placeholders: none of the 12 placeholder lines remains unfilled; the block's other `<...>`
    format templates stay as copied.

## Run review-md on the written plan

After the refinement rounds, invoke the `review-md` skill on the plan file with the Skill tool, once
per plan. The refinement rounds are the author checking its own work and share its blind spots; a
reader without this conversation's context does not. Pass these args, with the absolute plan path
filled in:

`review <absolute plan path>. Report findings only; do not edit the file. The "## Orchestration
protocol" section is a verbatim copy of a source block: do not report its wording. Text a Unit
quotes from its target file, and every gate command, must stay exactly as written: do not report
them as typos or style issues.`

Resolve every finding before the verification gate:

- If review-md asks the user which findings to address, the chosen ones are accepted and the rest
  are rejected by the user. If it returns findings without asking, accept each one you agree with
  and reject the others.
- Fix the plan for every accepted finding. Never change a Unit's quoted target-file text or the
  embedded block to satisfy one.
- A real defect inside the embedded block belongs to `references/subagent-orchestration.md`'s
  source, not to this plan: leave the plan's copy alone and name it in the summary.
- Record each rejected finding and its reason for the summary.

The verification gate below then re-checks what the fixes could have broken: the block diff, the
IDs, and the gates.

## Plan-level verification gate

Before reporting done, re-read the written file and confirm each item, reporting the result of each:

- The filename matches `plan-YYYY-MM-DD-<slug>.md`.
- Every Unit is self-contained: hierarchical ID, absolute file path(s), a one-sentence why, and the
  exact content or diff inline.
- Phases are numbered from 1, and Phase 0 exists only for questions left unanswered at planning time.
- Every Cluster names its orchestrator and its review criteria.
- Dependency order is explicit: numbered waves inside each Cluster, and no two Units sharing a file
  in one wave.
- The Definition of Done is testable, and is verified at the end rather than being just the per-Unit
  checks.
- The `## Run policies` section lists all seven values, and each matches its filled placeholder in
  the embedded block.
- Destructive or irreversible actions are listed as authorized, or "none".
- The Execution requirements section states the model guard and the exact line to run the plan.
- The Working directory section names an absolute root and gives concrete commands that follow the
  worktree policy (clean check, creation, and rollback, or a stated live-checkout reason), with no
  assumed `origin`.
- The authoritative build/test/lint gates are named, and every Unit has its own acceptance gate.
- Hierarchical IDs are consistent between `## Phases` and Appendix A.
- Appendix A has one unchecked line per Phase, Cluster, and Unit, each Unit line's gate matching the
  Unit's own, plus the closing lines Holistic review, Final verification, Commit and push (per
  policy), Decisions review, and Archive.
- Appendices B and C exist, each starting as `- No entries yet.`
- Every pair of Units sharing an interface (implementation and its test or consumer) pastes the same
  literal contract - no two Units independently assert different literal values for the same shape.
- No Unit says to consult the plan or any other document.
- The embedded orchestration block is present, all 12 placeholders are filled, and the team guard is
  intact. **Verify this by diffing the embedded block against the source block in
  `references/subagent-orchestration.md`, not by reading it.** Every line of the source must appear
  in the plan except the placeholder lines you filled. A block transcribed by hand rather than
  copied can silently drop an entire bullet: the result still reads as complete prose and passes
  every other item in this gate, so nothing but a diff catches it. Observed 2026-09-08, where the
  `**Final report:**` bullet went missing and survived four refinement rounds.
- review-md ran on the written plan, and every finding it returned is fixed, rejected with a
  reason, or named as a protocol-source defect.

If any item fails, fix the plan and re-run this gate rather than reporting it with caveats.

## Finish with a summary

Report: the absolute plan path and which plans-directory rule resolved it; the one-line Goal; the
Phase, Cluster, and Unit counts (and whether there is a Phase 0); the run policies (model guard,
halt, confirmation, worktree, commit and push with the branch, usage thresholds); the authorized
destructive actions, or "none"; the model-role map in one line; how many refinement rounds ran; the
review-md result (findings fixed, findings rejected with each reason, and any protocol-source
defect); the pass result of each verification-gate item above; and the exact line to run the plan.
Do not paste the plan body back. Name any clarifying question still open. Do not begin implementing
the Units - executing the plan is a separate, user-initiated step.
