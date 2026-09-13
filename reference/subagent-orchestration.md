---
created: 2026-07-24
updated: 2026-08-31
---

# Subagent Orchestration Protocol

This is the reusable, domain-agnostic protocol for one agent (the orchestrator) driving work
through stateless subagent workers. It is the source of truth for the orchestration layer; skills
that orchestrate subagents keep a synced copy under their own `references/`, mirroring how
`skill-author/references/skills.md` is synced from `docs/features/skills.md`.

The body below describes capabilities (dispatch a worker, run the shell, track progress); the
"Tool mapping" section maps each capability to its concrete Claude Code tool.

Scope is the generic orchestrator-and-workers layer only: automatic delegation, model roles and the
failure escalation ladder, halt-vs-escalate, self-contained prompts, completion discipline, the
verification-gate concept, sequencing and isolation, recovery, and commit policy. Domain-specific
mechanics (for example a plan's baseline build command, build-broken windows, language-specific
formatters and gates, or a replace-the-file bias for low-reasoning executors) belong in the
consuming skill's own references or in the plan it produces, NOT here, so later consumers do not
inherit concerns that are not theirs.

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

- Orchestrator: whichever model runs the driving turn (typically Sonnet). It stays the orchestrator
  and never hands orchestration itself to a cheaper model.
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
final report delivered once it exits. This was empirically confirmed via `execute-plan`'s reverted
`background: true` attempt (see `specs/behaviors.md`'s Plan and Execute entry, Context subsection) -
a backgrounded-fork orchestrator that hit a required blocking confirmation had no tool that could
pause and receive a real reply mid-run. Keep a fork foreground whenever the task needs to ask
something before it finishes.

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

- Read/write worker subagent: Task/Agent tool, `subagent_type: general-purpose`
- Read-only investigation/verifier subagent: Task/Agent tool, `subagent_type: Explore`
- Progress tracking: `TodoWrite`
- Read a file: `Read`
- Run git/build/test/lint in the shell: `Bash`
- Read linter/type diagnostics: run the linter via `Bash` and read its output

## The protocol (embed this in an executable plan)

Copy the block below into a plan and fill every `<...>` placeholder. A plan that carries a
filled-in block is self-triggering: telling the agent to execute it is enough, and no separate skill
is required to run it correctly.

```markdown
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
  If a required model cannot be launched, STOP and ask; never silently substitute. `<Confirm the
  executor and escalation tiers, plus any reasoning-heavy roles, here.>`
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
  escalation runs up cost. `<Set the retry/escalation threshold for this plan here.>`
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
  one narrowly-scoped corrective unit before proceeding. `<Name the authoritative build/test/lint
  gates for this plan here.>`
- **Sequencing and isolation:** dispatch independent units in one message (multiple subagent calls)
  so they run concurrently, then gate before the next wave. Before dispatching any parallel wave,
  verify the units' declared file sets are disjoint; if they overlap, serialize them regardless of
  how the plan labeled their independence. Units that share a file, or that depend on
  types/signatures/tests an earlier unit establishes, MUST run strictly sequentially, one at a time,
  because each subagent reads the file fresh and concurrent edits would clobber each other. Parallel
  document-producing subagents must each write ONLY their own output file, must NOT read another
  parallel agent's file, and must NOT communicate; merging or reconciling their outputs is a
  separate, later dispatch. `<List the waves and their dependency order here.>`
- **Corrective units (verification):** if a build, test, or lint command fails, do not retry blindly.
  Read the exact failure output, trace it to the single file or unit responsible, dispatch one
  narrowly-scoped corrective unit with the failing message included verbatim, then re-run the check.
  Repeat until it passes cleanly.
- **Environmental vs real failures:** distinguish failures caused by unavailable infrastructure
  (Docker, ports, local databases or services) from genuine regressions. If a check fails only
  because its harness could not start, capture the output, note it as environmental, and do not
  block; if it fails to compile or a non-harness assertion fails, treat it as a real regression to
  fix. `<Name the harnesses whose failure is environmental, not a regression, here.>`
- **Recovery and re-planning:** the ladder above is for unit-level trouble. If a failure instead
  reveals the plan itself is wrong (an assumption does not hold, a phase's premise is invalid), do
  NOT push through or silently re-plan. Halt execution, surface the failure context, and offer to
  re-enter planning with that context folded in.
- **Commit policy:** subagents never run any git command. Do not add, commit, push, or open a PR at
  any point unless the user explicitly requested it; if requested, the orchestrator does it as a
  final, separate step. `<State the commit or cleanup step here, or "stop at ready for review".>`
- **Final verification (orchestrator-owned):** after the last unit, run the full authoritative gates
  named above yourself (not via a subagent) to confirm the whole target is green, and confirm the
  plan's stated goal and definition of done are actually met - all units passing their local checks
  does not by itself prove the overall objective was achieved. Resolve any stragglers with a bounded
  corrective edit or one narrowly-scoped corrective unit before reporting.
- **Final report:** report which units completed vs were stopped and not resumed; the count of units
  that required a retry or an escalation; any acceptance checks or goal/definition-of-done items that
  could not be satisfied and why; and the paths of any artifacts produced.
```

## Placeholders to fill per consumer

- Working directory: the absolute root the subagents operate in. Prefer a dedicated git worktree over
  the live checkout so a failed run is trivially rolled back (delete the worktree) and its blast
  radius is isolated; use the live checkout only for trivial in-place changes. State which. Every
  path handed to a subagent must be an absolute path under it. If that root, its caches, or its
  `.git` sit outside the directory the orchestrator was started in, ensure the orchestrator has
  permission (per your harness's permission system) to run git/build/test/tidy there.
- Goal and definition of done: the one-line objective and the concrete, checkable conditions that
  mean the whole plan succeeded (verified at final verification, not just per-unit).
- Role-to-tier mapping: confirm the orchestrator, default executor, and escalation tier, plus any
  reasoning-heavy roles (reviewers, builders, collators). Optionally pre-flag the one unit most
  likely to escalate (usually design- or test-authoring-heavy).
- Retry/escalation threshold: the run circuit-breaker limit past which the orchestrator pauses.
- Authoritative gates: the build/test/lint commands that count as a real pass or fail, and any
  harness whose failure is environmental rather than a regression.
- Sequencing: the waves and their dependency order.
- Commit policy: the exact commit or cleanup step, or "stop at ready for review".

## Notes for consumers

- Domain-specific execution mechanics (baseline build command, build-broken windows,
  language-specific formatters and gates, a replace-the-file bias for low-reasoning executors) are
  supplied by the consuming skill or written into the plan it produces, not added to this shared
  file.
- Two sequencing patterns are both supported. Sequential-with-gates (the default above) suits
  dependency-heavy work with verification between phases. Parallel fan-out-and-collate suits
  independent producers: dispatch them under the isolation rule above, then reconcile their outputs
  in a separate collate unit.
