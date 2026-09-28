---
created: 2026-07-24
updated: 2026-09-28
---

# Subagent Orchestration Protocol

> Synced copy of `reference/subagent-orchestration.md` (source of truth) as of 2026-09-28. If that file
> changes, re-sync this copy - do not edit the two independently.

This is the reusable protocol for one agent (the orchestrator) driving work through stateless
subagent workers. It is the source of truth for the orchestration layer; the `planner` skill keeps
a synced copy under its own `references/`, mirroring how `skill-author/references/skills.md` is
synced from `docs/features/skills.md`.

The body below describes capabilities (dispatch a worker, run the shell, track progress, pause for
the user, sleep); the "Tool mapping" section maps each capability to its concrete Claude Code tool.

Scope is the orchestrator-and-workers layer plus the run procedure every plan carries: the model
guard, pre-flight and resume, the run policies (halt, confirmation, destructive actions), usage
gating, the durable in-plan tracking (Appendices A, B, and C), automatic delegation, model roles,
Cluster orchestration, the failure escalation ladder and circuit breaker, halt-vs-escalate,
self-contained prompts, completion discipline, the verification-gate concept, Cluster review,
sequencing and isolation, recovery, commit policy, final verification, the final report, the
decisions review, and archiving. The protocol is embedded whole into each plan, so a plan runs
correctly when any agent is told to execute it, with no separate execution skill (see
`decisions/0010-single-planner-skill-with-self-running-plans.md` and
`decisions/0011-planner-work-hierarchy-run-policies-and-usage-gating.md`). Domain-specific
mechanics (for example a plan's baseline build command, build-broken windows, language-specific
formatters and gates, or a replace-the-file bias for low-reasoning executors) belong in the plan
the consuming skill produces, NOT here, so later plans do not inherit concerns that are not theirs.

## What this is, and what it is not

This is a hierarchical orchestrator plus stateless workers: one orchestrator sequences the work,
dispatches each unit to a fresh subagent that shares no memory, verifies the result itself, and
enforces the rules below. It is the opposite of a peer mesh. The work is organized as Phase >
Cluster > Unit: a Phase is sized for the top-level orchestrator, a Cluster for a Sonnet
orchestrator, and a Unit for a Haiku (sometimes Sonnet) executor. Waves are parallel groupings of
Units inside one Cluster, not a fourth level.

Team guard: use plain subagents only. Do NOT use any peer-to-peer agent-team coordination feature
for this work (for example Claude Code's agent teams, enabled by
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `settings.json`). Such features fix each teammate's model
at spawn, which breaks the escalation ladder's re-dispatch of the same unit to a stronger model;
rely on peer messaging, which breaks the self-contained-prompt isolation this protocol requires; and
are a poor fit for sequential, same-file, or dependency-heavy work. A Sonnet Cluster orchestrator is
a plain subagent that dispatches plain subagents, not an agent team.

## Roles and models

Refer to model tiers as Opus, Sonnet, and Haiku (premium, workhorse, fast) per the environment's
Subagents & Models policy (see `CLAUDE.md`), with Fable above Opus where a plan's model guard names
it. Name each tier by its Claude Code alias (`opus` / `sonnet` / `haiku`) at dispatch time; prefer
an alias over a frozen version slug unless the consuming plan or the user names one. A typical role
mapping:

- Top orchestrator: whichever model runs the driving turn in the top-level session. Each plan
  states a model guard (Opus, Sonnet, Fable, or None, ordered Haiku < Sonnet < Opus < Fable) and
  halts before doing anything when the session model is below it; None skips the check. The top
  orchestrator never hands orchestration of the whole plan to a cheaper model. It alone talks to
  the user, sleeps for usage, runs Cluster reviews, commits, and archives.
- Cluster orchestrator: a Sonnet subagent (`general-purpose`, `model: sonnet`, dispatched in the
  foreground) that runs one Cluster's Units and returns one status. The plan names, per Cluster,
  whether the top orchestrator runs it itself or dispatches a Cluster orchestrator; the planner
  defaults to a Cluster orchestrator for a Cluster of 3 or more Units or with verbose gates.
- Default executor (prescriptive, well-specified units): Haiku when steps are fully prescriptive
  (exact paths and before/after content) so a low-reasoning model applies them mechanically; Sonnet
  for units the consumer marks as design- or test-authoring-heavy. Validate the Haiku-first default
  against real results: if mechanical edits fail often enough that the wasted attempt plus escalation
  costs more than starting on Sonnet, default those units to Sonnet instead.
- Escalation tier: one model tier above the unit's default (Haiku -> Sonnet -> Opus), used only on
  trouble (see the ladder), then step back down for later units.
- Reviewers: a fresh read-only Cluster reviewer after each Cluster (Sonnet by default, Opus where the
  Cluster's output needs judgment), and a holistic reviewer after the last Cluster (Opus by
  default).
- If a plan produces documents via reasoning-heavy roles (reviewers, builders, collators), map those
  roles to tiers explicitly.
- If a required model cannot be launched (for example a tier a harness does not expose), STOP and
  ask the user; never silently substitute. If the user names a different executor model at run time,
  honor that.

## Delegation shape: fork vs. fresh subagent

Prefer a fork over a fresh subagent for a task that continues or extends work already established
in the current conversation (reviewing or refining what was just done, extending an audit already
run) - it inherits that context and shares the prompt cache, where a fresh subagent starts cold and
needs everything rebuilt through a lengthy briefing.

Prefer a fresh subagent instead when independence from the orchestrator's own reasoning is the
actual point - an adversarial check or a second opinion meant to catch a blind spot in its own
conclusions, which a fork would only inherit and repeat - or when the task needs a tool or
permission scope the orchestrator does not hold.

A backgrounded fork cannot pause mid-run for a blocking confirmation: its only output is a single
final report delivered once it exits. This was empirically confirmed via the retired `execute-plan`
skill's reverted `background: true` attempt (see
`decisions/0010-single-planner-skill-with-self-running-plans.md`, Context) - a backgrounded-fork
orchestrator that hit a required blocking confirmation had no tool that could pause and receive a
real reply mid-run. Keep a fork foreground whenever the task needs to ask something before it
finishes.

Nested orchestration is supported: a subagent can spawn subagents of its own, up to three layers
below the main conversation by default, and `AskUserQuestion` is removed from every subagent (both
per the Claude Code subagent documentation, verified 2026-09-25). The protocol therefore runs at
most two subagent layers - top session, then a Sonnet Cluster orchestrator, then its executors and
verifiers - which stays within the default. Because no subagent can ask the user anything, a
Cluster orchestrator never asks: it returns a `halted` status with the question verbatim, and the
top orchestrator resolves it with the user, records the reply in the plan's Appendix C, and
re-dispatches with the answer inlined. Dispatch a Cluster orchestrator in the foreground so the
top orchestrator receives its status before doing anything else.

Parallel fan-out of several fresh subagents deserves its own caution beyond the fork-vs-fresh
choice above: each fresh subagent starts cold, so fanning N of them out multiplies the
system-prompt/tool-definition cache-miss tax by N with no cache sharing between them or with the
orchestrator - prefer parallel forks (`subagent_type: "fork"`) for independent sub-topics instead,
and reach for a dedicated single-purpose subagent only when forking itself is a poor fit, as a
scope decision rather than a cost one. This is domain-specific guidance the research case made
concrete; see `reference/research-discipline.md` for the measured cost model and full decision
framework, and `decisions/0008-avoid-parallel-research-fanout.md` for the record it was measured
against.

## Tool mapping

Map each capability below to Claude Code's concrete tool; exact parameters vary by version, so
treat this as the intent, not a frozen API.

- Read/write worker subagent: Task/Agent tool, `subagent_type: executor` with `model:` set to the
  unit's tier alias; `subagent_type: general-purpose` where no `executor` agent exists or the plan's
  model-role map assigns it
- Read-only investigation/verifier subagent: Task/Agent tool, `subagent_type: Explore`
- Read-only reviewer subagent (Cluster review, holistic review): Task/Agent tool,
  `subagent_type: general-purpose`, told to write nothing and run no git command other than
  `git diff`, `git status`, and `git show`
- Nested Cluster dispatch: Task/Agent tool, `subagent_type: general-purpose` with `model: sonnet`,
  run in the foreground (never backgrounded)
- Progress tracking: the plan file's own Appendix A: Progress, Appendix B: Run log, and Appendix C:
  Decisions log, edited in place
- Pause for the user (confirmation, a halt, a Phase 0 question, the decisions review):
  `AskUserQuestion`, in the top-level session only, since subagents do not have it; where it is
  unavailable, end the turn with the question and wait for a reply
- Usage check: `Bash` running
  `"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/planner/scripts/usage-check.sh" --warn N --stop N`
- Hourly usage sleep: a background shell, `Bash` with `run_in_background: true` running
  `sleep 3600`, then re-check when it exits; never a foreground sleep
- Read a file: `Read`
- Run git/build/test/lint in the shell: `Bash`
- Read linter/type diagnostics: run the linter via `Bash` and read its output

## The protocol (embed this in an executable plan)

Copy the block below into a plan and fill every `<...>` placeholder. A plan that carries a
filled-in block is self-running: telling any agent to execute it is enough, and no separate skill
is required to run it correctly. The block refers to six plan sections by name - Run policies,
Working directory, Phases, Appendix A: Progress, Appendix B: Run log, and Appendix C: Decisions
log - which the `planner` skill writes into every plan.

```markdown
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
  This check runs again in every session, even when Appendix C records an earlier override, because
  the model can differ between sessions.
  Model guard for this plan:
  <Set the model guard for this plan here.>
- **Pre-flight (top orchestrator, before any dispatch):** do these in order. If any step fails,
  STOP and report rather than dispatching.
  1. Read this plan in full, including Appendix A: Progress, Appendix B: Run log, and Appendix C:
     Decisions log. Treat every `answer` entry in Appendix C as the user's binding reply: follow it,
     and never ask again a question it already settles. If every Appendix A line except "Decisions
     review" and "Archive" is already `[x]`, only the review and archive remain: skip the rest of
     pre-flight and go straight to the **Decisions review** bullet.
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
     Unattended, answer each by best judgment). Log each answer in Appendix C (the user's reply as
     an `answer` entry, a best-judgment answer as a `decision` entry), then apply the answers by
     editing the Clusters and Units they change and the matching Appendix A lines, log each change
     in Appendix C, then mark Phase 0 `[x]`.
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
  <Set the halt policy for this plan here.>
  Confirmation policy for this plan:
  <Set the confirmation policy for this plan here.>
- **Destructive and irreversible actions:** deleting or overwriting files the run did not create,
  history rewrites, force pushes, branch or tag deletion, dropping or migrating data, publishing or
  pushing outward, sending messages, and changing shared or external systems are destructive or
  irreversible. Any such action not listed below as authorized stops for the user's explicit
  confirmation under every policy, Unattended included, and halts the run when no reply can arrive.
  Actions implied by this plan's commit and push policy and worktree policy, and the final move of
  this plan into `archive/`, count as authorized. A Cluster orchestrator that meets an unauthorized
  one returns `halted`; an executor performs only the actions its prompt names. Authorized actions
  for this plan:
  <List the authorized destructive or irreversible actions for this plan here, or "none".>
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
  <Set the usage thresholds for this plan here.>
- **Progress record (durable):** this plan file is the progress record, so an interrupted run
  resumes where it stopped.
  - Appendix A: Progress holds one `- [ ]` line per Phase, Cluster, and Unit, in order, then the
    closing lines Holistic review, Final verification, Commit and push (per policy), Decisions
    review, and Archive. Mark a Unit `[x]` only after its gate passes; a Cluster only after all its
    Units are `[x]` and its Cluster review passes; a Phase only after all its Clusters are `[x]`; a
    closing line only after its step completes. Never mark ahead of the work.
  - Appendix B: Run log gets one line per retry, escalation, halt, stale mark found on resume,
    guard override, usage status change or sleep, breaker count, and bare go-ahead at a
    confirmation pause, in the form
    `- 2026-09-25 Unit 1.2.1: retried at haiku with failure context; breaker 1/5`. Replace its
    `- No entries yet.` line with the first entry.
  - Appendix C: Decisions log gets one line per decision made in place of the user, deviation from
    the plan, or anomaly, in the form
    `- D3 | 2026-09-25 | Unit 1.2.1 | decision | <what> | why: <reason> | review: pending`, where
    the fourth field is `decision`, `deviation`, `anomaly`, or `answer` (next bullet) and D-numbers
    continue from the last entry. Replace its `- No entries yet.` line with the first entry.
  - Appendix C also gets one line per answer the user gives during the run that decides or changes
    something: a halt, a Phase 0 question, a confirmation-pause reply that changes the plan, a
    circuit-breaker or escalation stop, a destructive-action confirmation, or a model guard
    override, in the form
    `- D4 | 2026-09-25 | Unit 1.2.1 | answer | <question> -> <reply> | why: <cause> | review: n/a`,
    where `<cause>` names what raised the question and the third field is the Unit, Cluster,
    `Phase 0`, or `pre-flight` it arose in. The decisions review skips these entries,
    since the user already decided them. Write the entry before acting on the reply, so an
    interruption or compaction right after it cannot lose the answer. A bare go-ahead at a
    confirmation pause is not an `answer` entry; it goes in Appendix B. Keep answers in this plan,
    never in a memory file or any other document: they bind this run, and this plan is what a
    resumed run reads.
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
  <Confirm the executor and escalation tiers, plus any reasoning-heavy roles, here.>
- **Cluster orchestration:** run Clusters one at a time, in order. Each Cluster is run either by
  the top orchestrator itself or by a Sonnet Cluster orchestrator subagent, as named below.
  - For a Cluster orchestrator, dispatch `general-purpose` with `model: sonnet` in the foreground.
    Its prompt MUST inline: the absolute path of this plan file (for editing Appendices A, B, and C
    only), the working-directory root, the Cluster's Units in full with their waves and gates, each
    Unit's tier alias and escalation tier from the model-role map, the run policies with the halt
    policy's definition, the usage thresholds, the usage script path, the last usage status, the
    current breaker count and threshold, the authorized destructive actions, every Appendix C
    `answer` entry so far, the environmental harnesses, and the protocol rules it must follow
    (Usage gating per Unit, Progress record, Automatic delegation, Worker type, Self-contained
    prompts with the six standing constraints, Completion message discipline, Failure escalation
    ladder, Run circuit breaker, Halt vs escalate, Verification gates, Sequencing and isolation,
    Corrective units, Environmental vs real failures, Recovery and re-planning, Destructive and
    irreversible actions, the return-status contract in the next sub-bullet, and "run no git
    command"), each rule's text copied from this block.
  - A Cluster orchestrator never asks the user anything (subagents do not have `AskUserQuestion`)
    and never sleeps; it returns exactly one status, with its breaker count and last usage status:
    `done` (every Unit gated and marked); `halted` (the question or blocker verbatim);
    `usage-pause` (a `stop` usage check); or `breaker` (the breaker threshold reached). A
    plan-invalidating failure returns `halted`. It treats the inlined `answer` entries as binding
    and never returns `halted` for a question one of them settles. If it has no `Agent` tool
    (nesting turned off), it returns `halted` without doing any Unit itself, and the top
    orchestrator runs the Cluster.
  - On `done`, the top orchestrator runs the Cluster review. On `halted`, it resolves the question
    with the user per the halt policy, records the user's reply as an Appendix C `answer` entry,
    and re-dispatches with the answer inlined. On `usage-pause`, it sleeps per **Usage gating** and
    re-dispatches the Cluster's unmarked Units. On `breaker`, it acts per **Run circuit breaker**.
    Only the top-level session uses `AskUserQuestion`.
  <Name the orchestrator of each Cluster here.>
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
  <Set the retry/escalation threshold for this plan here.>
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
  <Name the authoritative build/test/lint gates for this plan here.>
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
  <List the Phases, Clusters, and waves and their dependency order here.>
- **Corrective units (verification):** if a build, test, or lint command fails, do not retry
  blindly. Read the exact failure output, trace it to the single file or Unit responsible, dispatch
  one narrowly-scoped corrective Unit with the failing message included verbatim, then re-run the
  check. Repeat until it passes cleanly.
- **Environmental vs real failures:** distinguish failures caused by unavailable infrastructure
  (Docker, ports, local databases or services) from genuine regressions. If a check fails only
  because its harness could not start, capture the output, note it as environmental in Appendix C
  as an `anomaly`, and do not block; if it fails to compile or a non-harness assertion fails, treat
  it as a real regression to fix.
  <Name the harnesses whose failure is environmental, not a regression, here.>
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
  <State the commit, push, and worktree cleanup steps here, or "stop at ready for review".>
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
  number of Appendix C entries, split into user answers and entries pending review; the final gate
  results and the per-item Definition-of-Done verification, naming any unmet item; and the
  artifacts produced plus commit, push, and worktree status (or `stop at ready for review`).
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
```

## Placeholders to fill per consumer

The block has 12 placeholders. Each sits alone on its own line, indented two spaces, under the
bullet it configures, and each takes the value of the matching entry in the plan's Run policies
section or model-role map:

- Model guard (`<Set the model guard for this plan here.>`): "Opus.", "Sonnet.", "Fable.", or
  "None.", chosen at intake. It replaces the older minimum orchestrator tier.
- Halt policy (`<Set the halt policy for this plan here.>`): "Sparse.", "Unattended.", or
  "Attended."
- Confirmation policy (`<Set the confirmation policy for this plan here.>`): "Startup.",
  "Attended.", or "Unattended."
- Usage thresholds (`<Set the usage thresholds for this plan here.>`): the warn and stop
  percentages, by default "warn 85, stop 95."
- Authorized destructive actions
  (`<List the authorized destructive or irreversible actions for this plan here, or "none".>`):
  each destructive or irreversible action the user authorized during planning, or "none".
- Role-to-tier mapping
  (`<Confirm the executor and escalation tiers, plus any reasoning-heavy roles, here.>`): the
  model-role map in one or two sentences. Optionally pre-flag the Unit most likely to escalate
  (usually design- or test-authoring-heavy).
- Cluster orchestrators (`<Name the orchestrator of each Cluster here.>`): per Cluster ID, "top
  orchestrator" or "Sonnet Cluster orchestrator subagent".
- Retry/escalation threshold (`<Set the retry/escalation threshold for this plan here.>`): the run
  circuit-breaker limit, by default 3 for a plan under about 6 Units and 5 for larger plans.
- Authoritative gates (`<Name the authoritative build/test/lint gates for this plan here.>`): the
  exact commands that count as a real pass or fail.
- Sequencing (`<List the Phases, Clusters, and waves and their dependency order here.>`): the
  hierarchy with each dependency named.
- Environmental harnesses
  (`<Name the harnesses whose failure is environmental, not a regression, here.>`): the specific
  harnesses (Docker, a local database, a network service), or "none".
- Commit and cleanup
  (`<State the commit, push, and worktree cleanup steps here, or "stop at ready for review".>`):
  the exact commands implied by the commit and push policy and the worktree policy.

The block also refers to six plan sections, spelled exactly, which the `planner` skill writes into
every plan:

- `## Run policies`: the model guard, halt policy, confirmation policy, worktree policy, commit and
  push policy with the branch, usage thresholds, and authorized destructive or irreversible actions
  (or "none"); the same values fill the placeholders above.
- `## Working directory`: the absolute root the subagents operate in. Prefer a dedicated git
  worktree over the live checkout so a failed run is trivially rolled back (delete the worktree)
  and its blast radius is isolated; use the live checkout only with a stated reason. Resolve the
  remote with `git remote` (never assume `origin`) and write the exact clean-check, creation, and
  rollback commands here. Every path handed to a subagent must be an absolute path under the root.
  If that root, its caches, or its `.git` sit outside the directory the orchestrator was started
  in, ensure the orchestrator has permission (per your harness's permission system) to run
  git/build/test/tidy there.
- `## Phases`: Phase 0 only when questions known at planning time could not be answered then, then
  Phase 1 onward, each holding Clusters (each naming its orchestrator and review criteria), each
  holding self-contained Units grouped into waves, with hierarchical IDs (Phase 2, Cluster 2.1,
  Unit 2.1.3).
- `## Appendix A: Progress`: one `- [ ]` line per Phase, Cluster, and Unit, in order; Unit lines
  carry the Unit's gate verbatim (`- [ ] Unit 1.2.1 (Wave 1): <title> - gate: <gate>`) and Cluster
  lines carry the review criteria. It ends with Holistic review, Final verification, Commit and push
  (per policy), Decisions review, and Archive.
- `## Appendix B: Run log`: starts as `- No entries yet.`
- `## Appendix C: Decisions log`: starts as `- No entries yet.`

The plan also carries a Goal and a Definition of Done: the one-line objective and the concrete,
checkable conditions that mean the whole plan succeeded (verified at final verification, not just
per Unit).

## Notes for consumers

- Domain-specific execution mechanics (baseline build command, build-broken windows,
  language-specific formatters and gates, a replace-the-file bias for low-reasoning executors) are
  supplied by the consuming skill or written into the plan it produces, not added to this shared
  file.
- Two sequencing patterns are both supported inside a Cluster. Sequential-with-gates (the default
  above) suits dependency-heavy work with verification between waves. Parallel fan-out-and-collate
  suits independent producers: dispatch them under the isolation rule above, then reconcile their
  outputs in a separate collate Unit.
- The usage script's full interface (source, value rules, exit codes, and test hook) is recorded
  in the Plan and Execute section of `specs/behaviors.md`; the script itself lives at
  `${CLAUDE_CONFIG_DIR:-~/.claude}/skills/planner/scripts/usage-check.sh`.

## References

- Claude Code subagents documentation, <https://code.claude.com/docs/en/sub-agents> (nested
  subagent depth and the removal of `AskUserQuestion` from subagents; verified 2026-09-25).
