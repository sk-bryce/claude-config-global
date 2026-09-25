---
created: 2026-07-24
updated: 2026-09-25
---

# Subagent Orchestration Protocol

This is the reusable protocol for one agent (the orchestrator) driving work through stateless
subagent workers. It is the source of truth for the orchestration layer; the `planner` skill keeps
a synced copy under its own `references/`, mirroring how `skill-author/references/skills.md` is
synced from `docs/features/skills.md`.

The body below describes capabilities (dispatch a worker, run the shell, track progress); the
"Tool mapping" section maps each capability to its concrete Claude Code tool.

Scope is the orchestrator-and-workers layer plus the run procedure every plan carries: the minimum
orchestrator tier check, pre-flight, the durable progress record, automatic delegation, model roles
and the failure escalation ladder, halt-vs-escalate, self-contained prompts, completion discipline,
the verification-gate concept, sequencing and isolation, recovery, commit policy, final
verification, and the final report. The protocol is embedded whole into each plan, so a plan runs
correctly when any agent is told to execute it, with no separate execution skill (see
`decisions/0010-single-planner-skill-with-self-running-plans.md`). Domain-specific mechanics (for
example a plan's baseline build command, build-broken windows, language-specific formatters and
gates, or a replace-the-file bias for low-reasoning executors) belong in the plan the consuming
skill produces, NOT here, so later plans do not inherit concerns that are not theirs.

## What this is, and what it is not

This is a hierarchical orchestrator plus stateless workers: one orchestrator sequences the work,
dispatches each unit to a fresh subagent that shares no memory, verifies the result itself, and
enforces the rules below. It is the opposite of a peer mesh.

Team guard: use plain subagents only. Do NOT use any peer-to-peer agent-team coordination feature
for this work (for example Claude Code's agent teams, enabled by
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `settings.json`). Such features fix each teammate's model
at spawn, which breaks the escalation ladder's re-dispatch of the same unit to a stronger model;
rely on peer messaging, which breaks the self-contained-prompt isolation this protocol requires; and
are a poor fit for sequential, same-file, or dependency-heavy work.

## Roles and models

Refer to model tiers as Opus, Sonnet, and Haiku (premium, workhorse, fast) per the environment's
Subagents & Models policy (see `CLAUDE.md`). Name each tier by its Claude Code alias (`opus` /
`sonnet` / `haiku`) at dispatch time; prefer an alias over a frozen version slug unless the
consuming plan or the user names one. A typical role mapping:

- Orchestrator: whichever model runs the driving turn. Each plan states a minimum orchestrator tier
  and halts before doing anything when the session model is below it. The orchestrator never hands
  orchestration itself to a cheaper model.
- Default executor (prescriptive, well-specified units): Haiku when steps are fully prescriptive
  (exact paths and before/after content) so a low-reasoning model applies them mechanically; Sonnet
  for units the consumer marks as design- or test-authoring-heavy. Validate the Haiku-first default
  against real results: if mechanical edits fail often enough that the wasted attempt plus escalation
  costs more than starting on Sonnet, default those units to Sonnet instead.
- Escalation tier: one model tier above the unit's default (Haiku -> Sonnet -> Opus), used only on
  trouble (see the ladder), then step back down for later units.
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
- Progress tracking: the plan file's own Progress checklist and Run log, edited in place
- Pause for the user's confirmation: end the turn with the blast-radius summary and wait for a
  reply, or use `AskUserQuestion` where it is available
- Read a file: `Read`
- Run git/build/test/lint in the shell: `Bash`
- Read linter/type diagnostics: run the linter via `Bash` and read its output

## The protocol (embed this in an executable plan)

Copy the block below into a plan and fill every `<...>` placeholder. A plan that carries a
filled-in block is self-running: telling any agent to execute it is enough, and no separate skill
is required to run it correctly. The block refers to three plan sections by name - Working
directory, Progress, and Run log - which the `planner` skill writes into every plan.

```markdown
## Orchestration protocol (read before executing this plan)

The executing (orchestrator) agent MUST dispatch the work below to subagents automatically, without
being told again, and MUST NOT perform a unit's initial implementation itself. The orchestrator only
sequences units, launches subagents, runs verification gates, makes bounded corrective edits (see
below), and enforces the escalation and halt rules below. Use plain subagents only: even if an
agent-team feature is enabled in this environment, do NOT propose or spawn an agent team for this
work. If this plan contradicts itself, or still contains unfilled placeholder text, STOP and ask
rather than picking an interpretation.

- **Minimum orchestrator tier (check first):** before any other step, identify the model running
  this turn from your own system context and map it to its tier, ordered Haiku < Sonnet < Opus. If
  that tier is below this plan's minimum, or you cannot determine it, HALT before touching anything:
  name the model you are running as and the required tier, and ask the user to switch models (for
  example with `/model`) and ask again. Continue on a lower tier only if the user then explicitly
  tells you to, and record that override in the Run log. Minimum tier for this plan:
  <Set the minimum orchestrator tier for this plan here.>
- **Pre-flight (orchestrator, before any dispatch):** do these in order. If any step fails, STOP and
  report rather than dispatching.
  1. Read this plan in full, including its Progress and Run log sections.
  2. Set up the working directory exactly as this plan's Working directory section states. Before
     creating a worktree or touching the live checkout, confirm the repository is clean
     (`git status --porcelain` prints nothing); uncommitted changes corrupt diffs and test results,
     so if it is dirty, STOP and report - never stash, commit, or revert anything on your own. On a
     resumed run, where Progress already has `[x]` marks, changes limited to the files this plan's
     units name are expected; only changes outside them count as dirty. If the worktree already
     exists from an earlier run of this plan, reuse it rather than recreating it. Every path handed
     to a subagent must be absolute and under the working-directory root.
  3. Confirm every tool, build, and test command this plan needs is available, and run any
     known-good baseline check the plan defines.
  4. Resume check: for every unit already marked `[x]` in the Progress section, re-run that unit's
     gate before trusting the mark. If it passes, skip the unit. If it fails, change the mark back
     to `[ ]`, log the stale mark in the Run log, and dispatch the unit normally. Restore the run's
     retry/escalation count from the Run log rather than starting again from zero.
  5. Summarize the blast radius: the model running this turn against the minimum tier, the working
     directory, the waves and the files each touches, the model plan, the circuit-breaker threshold
     and the count carried over, and which units are already done.
  6. PAUSE for the user's explicit confirmation of that summary. Do not dispatch any unit until they
     confirm, and never treat silence as approval. If this run cannot receive a reply (a
     backgrounded subagent, a non-interactive session), STOP and report instead of proceeding.
- **Progress record (durable):** this plan file is the progress record, so an interrupted run
  resumes where it stopped. Change a unit's Progress line from `- [ ]` to `- [x]` only after that
  unit's gate has passed; never mark ahead of the work. Append one line to the Run log for every
  retry, escalation, halt, stale mark found on resume, and tier override, in the form
  `- 2026-09-25 Unit 3: retried at haiku with failure context; breaker 1/5`. The Progress and Run
  log sections are the only parts of this plan the orchestrator edits.
- **Automatic delegation (default on):** every substantive unit of work defined below is dispatched
  to a subagent; the orchestrator does not implement a unit itself. It does only this: launching
  subagents, reading files back, running verification/build/test/lint commands in the shell, making
  bounded corrective edits during verification (a few lines at most - anything larger becomes a
  corrective subagent), and (only if explicitly requested) committing. A plan may mark a genuinely
  trivial, low-risk unit for direct execution instead of fan-out; delegation is the default, not a
  mandate for work that does not warrant it.
- **Models (role -> tier; fill per plan):** a default executor tier for prescriptive units, an
  escalation one tier up (Haiku -> Sonnet -> Opus), and an orchestrator that is the model running
  this plan, at or above the minimum tier. Name each tier by its harness equivalent; prefer an alias
  over a frozen slug. If a required model cannot be launched, STOP and ask; never silently
  substitute.
  <Confirm the executor and escalation tiers, plus any reasoning-heavy roles, here.>
- **Worker type:** dispatch every unit that edits files to the `executor` subagent
  (`subagent_type: executor`) with `model:` set to that unit's tier alias, unless this plan's
  model-role map assigns the unit a different worker. If this harness has no `executor` agent, use
  a general read/write worker subagent (`general-purpose`) instead and say so in the blast-radius
  summary. Use a read-only subagent (`Explore`) only for pure investigation or independent
  verification that writes nothing. The orchestrator runs git, build, test, and lint commands itself
  in the shell rather than delegating them, so it keeps authority over the gates.
- **Self-contained prompts:** subagents share no memory of this plan or this conversation. Each
  dispatched prompt MUST inline, verbatim: the absolute file path(s) to touch, a one-sentence "why",
  the exact content or diff to apply (copied from the relevant section below), and the standing
  constraints below. NEVER tell a subagent to open, locate, or consult this plan or any other
  document to find or interpret its task; paste any context it needs directly into the prompt.
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
  back; this keeps the orchestrator's context lean across a long, multi-dispatch run.
- **Failure escalation ladder (mechanical trouble):** when a subagent (a) returns a failure or
  error, (b) reports the instructions did not match the file (a snippet is not found, a line
  drifted), (c) makes no progress, or (d) produces a weak or incorrect result on a unit whose
  requirements were clear:
  1. Retry the SAME unit once, same model, same self-contained prompt plus the failure context
     (what the subagent reported, verbatim).
  2. If it still fails, re-dispatch the SAME unit one model tier up, with the same prompt plus the
     failure context. Do not skip, half-apply, or improvise. Step back to the default tier for later
     units: an escalation applies only to the unit that needed it.
  3. If the escalated tier also cannot resolve it, or cannot be launched, STOP and ask the user.
     Never leave work partially applied or guess past a blocker.

  Log every retry and escalation in the Run log as it happens.
- **Run circuit breaker:** keep one cumulative count of retries and escalations across the whole
  run - every unit's attempts added together, carried in the Run log so it survives an interrupted
  session. Before starting each new retry or escalation, compare the count to the threshold below;
  if it has reached the threshold, pause and report instead of continuing: give the count, which
  units consumed it, and the current failure, then ask whether to continue, raise the threshold, or
  re-plan. A run that keeps escalating usually signals a bad plan or a systemic issue a stronger
  model will not fix, and unbounded escalation runs up cost.
  <Set the retry/escalation threshold for this plan here.>
- **Halt vs escalate (route by cause):** escalating the model is only for the mechanical trouble
  above - a unit that is hard but well specified. If a subagent instead stops because a decision is
  missing or contradictory, or information the task needs is not present in the prompt (genuine
  ambiguity), do NOT retry or escalate the model: a stronger model would only guess at the same
  missing decision. Halt and report: which unit stopped, the exact missing or contradictory decision
  (quote the subagent's question), the options as you understand them and what is needed to choose,
  and that this is a halt rather than an escalation because it is a gap in the plan. Log the halt in
  the Run log.
- **Verification gates (orchestrator, after each unit or wave):** do not trust self-reports. Before
  starting dependent work, read the modified file(s) back to confirm intent, run the applicable
  checks for the changed scope (the linter, and the unit's acceptance check), and independently
  confirm each acceptance criterion. Prefer acceptance criteria expressed as a command that returns
  pass/fail, and run it, rather than judging subjectively. For a high-risk or reasoning-heavy unit,
  optionally dispatch a separate read-only verifier subagent to check the output against the criteria
  independently instead of self-verifying. Mark the unit `[x]` in the Progress section only after
  the checks pass. If an edit is wrong or drifted, make a bounded corrective edit yourself or
  dispatch one narrowly-scoped corrective unit before proceeding.
  <Name the authoritative build/test/lint gates for this plan here.>
- **Sequencing and isolation:** dispatch independent units in one message (multiple subagent calls)
  so they run concurrently, then gate before the next wave. Before dispatching any parallel wave,
  verify the units' declared file sets are disjoint; if they overlap, serialize them regardless of
  how the plan labeled their independence. Units that share a file, or that depend on
  types/signatures/tests an earlier unit establishes, MUST run strictly sequentially, one at a time,
  because each subagent reads the file fresh and concurrent edits would clobber each other. Parallel
  document-producing subagents must each write ONLY their own output file, must NOT read another
  parallel agent's file, and must NOT communicate; merging or reconciling their outputs is a
  separate, later dispatch.
  <List the waves and their dependency order here.>
- **Corrective units (verification):** if a build, test, or lint command fails, do not retry blindly.
  Read the exact failure output, trace it to the single file or unit responsible, dispatch one
  narrowly-scoped corrective unit with the failing message included verbatim, then re-run the check.
  Repeat until it passes cleanly.
- **Environmental vs real failures:** distinguish failures caused by unavailable infrastructure
  (Docker, ports, local databases or services) from genuine regressions. If a check fails only
  because its harness could not start, capture the output, note it as environmental, and do not
  block; if it fails to compile or a non-harness assertion fails, treat it as a real regression to
  fix.
  <Name the harnesses whose failure is environmental, not a regression, here.>
- **Recovery and re-planning:** the ladder above is for unit-level trouble. If a failure instead
  reveals the plan itself is wrong (an assumption does not hold, a phase's premise is invalid), do
  NOT push through or silently re-plan. Halt execution, surface the failure context, and offer to
  re-enter planning with that context folded in.
- **Commit policy:** subagents never run any git command, and every dispatched prompt says so. Do not
  add, commit, push, or open a PR at any point unless the user explicitly requested it; if
  requested, the orchestrator does it as a final, separate step after final verification passes.
  Leave any worktree in place unless the user asks to remove it.
  <State the commit or cleanup step here, or "stop at ready for review".>
- **Final verification (orchestrator-owned):** after the last unit:
  1. Run the full authoritative gates named above yourself, not via a subagent.
  2. Walk the Definition of Done item by item and check each one against the actual working tree or
     running behavior. A unit's passing gate is not evidence for a Definition-of-Done item: a
     requirement no unit implemented passes every unit gate and still fails the plan.
  3. Classify any failure as environmental or real, per the rule above.
  4. If any Definition-of-Done item is unmet, name it and what is missing, do not report the run
     complete, and offer either one narrowly-scoped corrective unit or re-planning when the gap is
     a planning miss rather than an implementation miss.

  Report the run complete only when every Definition-of-Done item is verified satisfied.
- **Final report:** end every run with: this plan's absolute path and the working directory used (a
  worktree, or the live checkout with this plan's stated reason); the model that orchestrated,
  against the minimum tier; units completed, units skipped as already `[x]` and re-verified, and
  units not run; every retry and escalation (which unit, from which tier to which, and the outcome)
  and the final breaker count against the threshold; any halt and the exact missing or
  contradictory decision behind it; the final gate results and the per-item Definition-of-Done
  verification, naming any unmet item; and the artifacts produced plus commit status (or
  `stop at ready for review`).
```

## Placeholders to fill per consumer

- Minimum orchestrator tier: the lowest tier (Haiku, Sonnet, or Opus) allowed to orchestrate the
  plan, chosen by the user when the plan is written.
- Working directory: the absolute root the subagents operate in. Prefer a dedicated git worktree over
  the live checkout so a failed run is trivially rolled back (delete the worktree) and its blast
  radius is isolated; use the live checkout only with a stated reason. Resolve the remote with
  `git remote` (never assume `origin`) and write the exact clean-check, creation, and rollback
  commands into the plan's Working directory section. Every path handed to a subagent must be an
  absolute path under the root. If that root, its caches, or its `.git` sit outside the directory
  the orchestrator was started in, ensure the orchestrator has permission (per your harness's
  permission system) to run git/build/test/tidy there.
- Goal and definition of done: the one-line objective and the concrete, checkable conditions that
  mean the whole plan succeeded (verified at final verification, not just per-unit).
- Role-to-tier mapping: confirm the orchestrator minimum, default executor, and escalation tier,
  plus any reasoning-heavy roles (reviewers, builders, collators). Optionally pre-flag the one unit
  most likely to escalate (usually design- or test-authoring-heavy).
- Retry/escalation threshold: the run circuit-breaker limit at which the orchestrator pauses.
- Authoritative gates: the build/test/lint commands that count as a real pass or fail, and any
  harness whose failure is environmental rather than a regression.
- Sequencing: the waves and their dependency order.
- Commit policy: the exact commit or cleanup step, or "stop at ready for review".
- Progress and Run log: plan sections rather than placeholders. Progress holds one `- [ ]` line per
  unit carrying that unit's gate; the Run log starts empty.

## Notes for consumers

- Domain-specific execution mechanics (baseline build command, build-broken windows,
  language-specific formatters and gates, a replace-the-file bias for low-reasoning executors) are
  supplied by the consuming skill or written into the plan it produces, not added to this shared
  file.
- Two sequencing patterns are both supported. Sequential-with-gates (the default above) suits
  dependency-heavy work with verification between phases. Parallel fan-out-and-collate suits
  independent producers: dispatch them under the isolation rule above, then reconcile their outputs
  in a separate collate unit.
