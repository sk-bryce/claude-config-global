---
name: execute-plan
description: |
  Executes an already-written plan file produced by write-plan - resolves the plan by slug or
  path, confirms the blast radius, then dispatches every unit to a stateless subagent with
  per-unit verification, the failure escalation ladder, a run circuit breaker, and a final
  Definition-of-Done gate. Manual invocation only - run it by explicit reference, for example
  "/execute-plan add-health-endpoint" or "/execute-plan ~/.claude/plans/add-health-endpoint.md";
  it never fires on its own, no matter how plan-shaped a request sounds. Does not write, revise,
  or re-plan plans (that is write-plan). Scope: personal (~/.claude/skills/), any project working
  directory.
disable-model-invocation: true
model: sonnet
context: fork
agent: general-purpose
background: false
---

<!--
created: 2026-07-27
updated: 2026-09-11
spec: specs/behaviors.md (Plan and Execute section)
generated-by: Opus subagent, spec-driven migration plan execution (Phase 3 Workstream A) - see
  specs/behaviors.md
model: claude-opus-5-thinking-high
harness: Claude Code
-->

# Plan Execution

Execute an already-written plan by dispatching its units to stateless subagents.
`references/subagent-orchestration.md` (synced from this repository's
`reference/subagent-orchestration.md`) is the authoritative protocol: read it before the first
dispatch and follow it wherever this file is silent. For subagent tool names, model-tier IDs, and
plan storage locations,
`${CLAUDE_CONFIG_DIR:-~/.claude}/skills/cursor-projection/references/harness-matrix.md` is the
source of truth - map tiers and tools there rather than guessing names.

A plan written by `write-plan` carries a filled-in copy of that reference's orchestration block.
Its run-specific values (waves, working directory, model-role map, circuit-breaker threshold,
authoritative gates, commit policy) are authoritative for this run; the procedure below governs how
to act on them. If the plan contradicts this file on procedure, or leaves a placeholder unfilled,
stop and ask rather than picking one.

This skill executes plans. It does not author or revise them; that is `write-plan`.

## Run only on explicit invocation

Run this workflow only when it is invoked by name - `/execute-plan <slug-or-path>`, or an
equivalent explicit reference to this skill by the user.

- Never start it from a natural-language request, however plan-shaped ("figure out the best
  approach and implement X", "work through this end to end"). Route those to `write-plan` when the
  user wants a plan, or handle them as an ordinary implementation request.
- Never claim to have run `execute-plan` for work that was not explicitly invoked this way, and do
  not apply this file's orchestration machinery (worktree-by-default execution, dispatch ladder,
  per-unit `[x]` marks) to an uninvoked request.

`disable-model-invocation: true` enforces this; the rule above still stands if the field is ever
ignored.

## Locate the plan

Treat `$ARGUMENTS` as a plan slug or a plan path, and resolve it before doing anything else.

- If it is a path that exists, use it as-is.
- Otherwise look for `<slug>.md` (then a case-insensitive or unique substring match on the slug) in
  the plans directory, resolved in this priority order - the same order `write-plan/SKILL.md`'s
  "Resolve the plans directory" section states:
  1. An explicitly-set native plans setting: a `plansDirectory` the user actually set. The
     built-in `${CLAUDE_CONFIG_DIR:-~/.claude}/plans` default does not count as set.
  2. Else a project agent-config plans directory under the working directory:
     `<cwd>/.claude/plans/`, or `<cwd>/plans/` when the working directory is itself a `.claude`
     directory (for example this repository, `~/.claude`).
  3. Else the global `${CLAUDE_CONFIG_DIR:-~/.claude}/plans`.
- If nothing matches, or the same slug exists in more than one of those directories, stop and ask
  which plan is meant. Do not write a plan to fill the gap - hand that to `write-plan`.

State the resolved absolute plan path, then read the plan in full.

## Pre-flight before any dispatch

Complete all of this before launching the first subagent:

1. Read the plan in full and extract: the Goal, the Definition of Done, the waves and their
   dependency order, each unit with its acceptance gate, the model-role map, the retry/escalation
   circuit-breaker threshold, the authoritative build/test/lint gates, the named working directory,
   and the commit policy. If any of those is missing, ask before proceeding.
2. Confirm the working state is clean: run `git status` in the repository the plan targets, before
   creating any worktree from it. Uncommitted changes corrupt diffs and test results. If it is
   dirty, stop and report; do not stash, commit, or revert anything on your own.
3. Confirm every tool, build, and test command the plan needs is available, and run the plan's
   baseline check if it defines one.
4. Summarize the blast radius: the waves, the files each wave touches, the model-role/tier plan, the
   working directory, and the circuit-breaker threshold.
5. Pause for explicit user confirmation of that summary. Do not dispatch any unit until they
   confirm. This skill runs forked but not backgrounded on Claude Code (`context: fork`,
   `background: false`), specifically so this pause can still reach and block on the user - a
   backgrounded fork has no channel to receive a real reply mid-run (confirmed empirically; see
   specs/behaviors.md). If a future change to this pin ever makes confirmation not visibly reach
   the user, treat that as a failed precondition and report it rather than proceeding or treating
   silence as approval.

If any precondition fails, stop and report rather than dispatching.

Dispatch every substantive unit to a subagent; never perform a unit's initial implementation
yourself. The orchestrator does only this: dispatch subagents, read files back, run the git, build,
test, and lint commands, make bounded corrective edits during verification (a few lines at most;
anything larger becomes a narrowly-scoped corrective dispatch), and commit only if explicitly
asked. A unit the plan itself marks as trivial and direct-execution is the only exception.

## Working directory

Run in a dedicated git worktree by default, so a failed run is rolled back by deleting it.

- If the plan names a worktree, use it. If it does not, create one before dispatching:
  `git worktree add .worktrees/<plan-slug> -b <plan-slug> <remote>/<base>`. Do not assume
  `<remote>` is `origin`: run `git remote`, and prefer the branch's configured upstream when one is
  set (see `CLAUDE.md`, Git & GitHub). Keep the worktree under the project directory so it inherits
  that directory's tool permissions. Use the base branch the plan names; if it names none, or the
  repository has no remote, branch from the current HEAD and say so.
- Use the live checkout only when the plan explicitly states a reason to. Repeat that stated reason
  in the pre-flight summary.
- State the absolute working-directory root in the pre-flight summary, whichever it is.
- Every path in every dispatched prompt must be an absolute path under that root - no relative
  paths, no `~`, no paths from the session's original directory.
- If that root, its caches, or its `.git` sit outside the directory the session started in, confirm
  you have permission to run git/build/test there before dispatching.

## Resume an interrupted run

On start, scan the plan for units already marked `[x]`.

- Do not re-dispatch a unit that is already marked complete.
- Before trusting the mark, re-verify that unit's stated acceptance gate still passes - an
  interrupted run can leave a mark ahead of the actual state, or a later change can have undone it.
  Run the gate command where the acceptance criterion is command-shaped; otherwise read the named
  files back and confirm the criterion directly.
- If the re-verification fails, treat the unit as unmarked and re-dispatch it normally.
- Resume dispatching from the first unmarked unit, in wave order.
- Report which units were skipped as already done and that their gates were re-verified.

## Dispatch each unit

Work through the plan's waves in order.

- Units in the same wave may be dispatched concurrently (multiple subagent calls in one message)
  unless the plan says otherwise. First verify their declared file sets are actually disjoint; if
  they overlap, serialize them regardless of how the plan labeled their independence.
- Units that share a file, or that depend on types, signatures, or tests an earlier unit
  establishes, run strictly sequentially, one at a time.
- Use the tier the plan's model-role map assigns to that unit type (the `opus` / `sonnet` / `haiku`
  alias). If a required tier cannot be launched, stop and ask; never silently substitute. Honor a
  different executor model if the user names one at run time.
- Use a read/write worker subagent for any unit that edits files; a read-only subagent only for pure
  investigation or independent verification that writes nothing. Run git, build, test, and lint
  yourself in the shell rather than delegating them.
- Make each prompt fully self-contained: copy the unit's own content verbatim from the plan (the
  absolute file path(s), a one-sentence why, the exact content or diff, and its acceptance
  criteria), plus the standing constraints in `references/subagent-orchestration.md`
  ("Self-contained prompts"). Never tell a subagent to open, locate, or consult the plan or any
  other document to find or interpret its task. Once dispatch has begun, re-open the plan only to
  read the next unit's content or to mark progress, not to let a subagent re-derive its own task.
- Require a terse completion message from each subagent: one status line, the changed path(s), and
  at most a few bullets on decisions or flagged mismatches. No pasted file contents.
- Verify after each unit or wave, before any dependent work: read the modified file(s) back, run the
  linter, and independently confirm each acceptance criterion, preferring a command that returns
  pass/fail over a subjective judgment. For a high-risk or reasoning-heavy unit, dispatch a separate
  read-only verifier subagent instead of self-verifying.
- Mark the unit `[x]` in the plan file only after its checks actually pass.

## Escalate mechanical trouble one tier

Classify every failure before reacting to it. Mechanical trouble is: a failure or error return, a
report that the instructions did not match the file (a snippet is not found, a section is missing or
drifted), no progress, or a weak or incorrect result on a unit whose requirements were clear. In
other words, the unit is hard but well specified, and more context at the same or a higher tier
could plausibly fix it. For mechanical trouble, follow this ladder exactly:

1. Retry the SAME unit once, at the SAME tier, with the same self-contained prompt plus the failure
   context appended (what the subagent reported, verbatim).
2. If it fails again, re-dispatch the SAME unit one tier up (Haiku to Sonnet, or Sonnet to Opus)
   with the same prompt plus the failure context.
3. If the escalated tier also fails, or cannot be launched, STOP and ask the user.

Do not skip the unit, half-apply it, improvise a fix outside this ladder, or jump straight to the
top tier. Never leave work partially applied.

After a successful escalation, step back down to the plan-stated default tier for subsequent units.
An escalation applies to the one unit that needed it; it does not raise the floor for the rest of
the run.

If a build, test, or lint command fails during verification, do not retry blindly: read the exact
failure output, trace it to the one file or unit responsible, dispatch a single narrowly-scoped
corrective unit with the failing message included verbatim, then re-run the check.

## Halt on genuine ambiguity instead of escalating

If a unit instead stops because a decision is missing or contradictory, or because information the
task needs is not in the prompt and not in the plan, do NOT retry it and do NOT escalate the tier: a
stronger model would only guess at the same missing decision. Halt immediately and report:

- which unit stopped, and the exact missing or contradictory decision (quote the subagent's
  question),
- the options as you understand them, and what is needed to choose,
- that this is a halt rather than an escalation because it is a gap in the plan, not mechanical
  trouble a stronger model could grind through.

If the failure reveals the plan itself is wrong (an assumption does not hold, a wave's premise is
invalid), halt the same way, surface the failure context, and offer to re-enter `write-plan` with it
folded in. Never silently re-plan or push through.

## Run circuit breaker

Keep a cumulative count of retries and escalations across the whole run - every unit's attempts
added together, not a per-unit count that resets. Compare that running total to the plan's stated
retry/escalation threshold before starting each new retry or escalation.

- If the total has reached or passed the threshold, pause and report instead of continuing: give the
  count, which units consumed it, and the current failure, then ask whether to continue, raise the
  threshold, or re-plan. A run that keeps escalating usually means a bad plan or a systemic issue a
  stronger model will not fix.
- If the plan states no threshold, ask for one during pre-flight; if the user does not set one, use
  5 and say so in the blast-radius summary.

## Use plain subagents, never an agent team

Do not spawn or propose a peer-to-peer agent-team feature (for example Claude Code's agent teams via
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) for this work, even if the user asks for one and even if it
is enabled in the environment. Say why rather than ignoring the request: teammate models are fixed
at spawn, which breaks the escalation ladder's re-dispatch of the same unit at a higher tier, and
peer messaging breaks the self-contained-prompt isolation this protocol depends on; it is also a
poor fit for sequential, same-file, or dependency-heavy work. Then continue with plain stateless
subagent dispatch as described above.

## Final verification against the Definition of Done

Every unit passing its local gate does not prove the plan's goal was met. After the last unit:

1. Run the plan's authoritative build/test/lint gates yourself, not via a subagent.
2. Walk the Definition of Done item by item and check each one against the actual working tree or
   running behavior. A unit's local acceptance check is not evidence for a Definition-of-Done item:
   a requirement no unit implemented (for example "the theme toggle persists across a page reload")
   passes every unit gate and still fails the plan.
3. Distinguish environmental failures (a harness that could not start - Docker, ports, local
   databases or services) from real regressions. Capture environmental output, note it as
   environmental, and do not treat it as a pass or a blocker; treat compile failures and
   non-harness assertion failures as real.
4. If any Definition-of-Done item is not satisfied, report exactly which item and what is missing.
   Do not mark the run complete. Offer either one narrowly-scoped corrective unit, or re-entry to
   `write-plan` when the gap is a planning miss rather than an implementation miss.

Report the run as complete only when every Definition-of-Done item has been verified satisfied.

## Commit policy

Follow the plan's stated commit policy. If the plan states none, stop at ready for review. Do not
add, commit, push, or open a PR at any point unless the plan or the user explicitly asked for it; if
asked, do it yourself as a final, separate step after final verification passes (see `CLAUDE.md`,
Git & GitHub). Every dispatched prompt must tell the subagent to run no git commands. Leave the
worktree in place unless the user asks to clean it up.

## Tier delivery

The orchestrator tier is Sonnet; the executor tier is whatever the plan's model-role map assigns
per unit (typically Haiku for fully prescriptive units with exact paths and content, Sonnet for
design- or test-authoring-heavy ones), with escalation one tier above that unit's default. These are
separate settings - do not let the orchestrator pin decide a unit's tier.

`model: sonnet` in this file's frontmatter pins the orchestrator turn. Dispatch units with the
Task/Agent tool, `subagent_type: general-purpose`, and `model:` set to the tier alias (`opus`,
`sonnet`, `haiku`); use `subagent_type: Explore` for read-only verifiers.

## Finish with a summary

End every run with:

- the resolved plan path and the working directory used (worktree, or live checkout with the plan's
  stated reason),
- units completed, units skipped as already marked `[x]` and re-verified, and units not run,
- every retry and escalation: which unit, from which tier to which, and the outcome, plus the
  cumulative count against the circuit-breaker threshold,
- any halt and the specific missing or contradictory decision that caused it,
- the final gate results and the per-item Definition-of-Done verification, naming any item that is
  not satisfied,
- artifacts produced and commit status (or "stop at ready for review").
