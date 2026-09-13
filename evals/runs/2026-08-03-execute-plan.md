# execute-plan eval run - 2026-08-03 (real dynamic run)

## Harness and model

- Harness: Claude Code 2.1.220.
- Model running this orchestrating session: Sonnet 5 (`claude-sonnet-5`).
- Model used for the 18 dispatched top-level subagents (9 with-skill + 9 baseline,
  `subagent_type: general-purpose`, explicit `model: sonnet` override given): Sonnet 5. The
  `execute-plan` skill's own frontmatter pins `model: sonnet` (matching, since this skill's
  orchestrator tier is meant to be Sonnet), but the Skill tool itself refused direct invocation in
  every with-skill run tried (`disable-model-invocation: true` blocks a model-initiated tool call
  to it, which is exactly what a Task-tool-dispatched subagent's call looks like - there is no real
  harness-level `/execute-plan` slash-command router reachable from inside a subagent). Every
  with-skill agent adapted the same honest way: read `~/.claude/skills/execute-plan/SKILL.md` (and
  its referenced `references/subagent-orchestration.md` and
  `~/.claude/skills/cursor-projection/references/harness-matrix.md`)
  directly as a read-only reference and followed it manually. This is a real, worth-flagging
  structural fact about this run's fidelity (same class of issue the task background called out for
  a backgrounded fork), not a fabricated result - the procedural behavior graded below is what the
  agents actually did after reading the skill's real instructions, not invented.
- Second-tier subagents actually dispatched by the with-skill agents to implement fixture units:
  Haiku, per each fixture plan's model-role map, using the real Agent/Task tool for real (verified
  by reading back the sandbox's git worktree contents after each run, not by trusting self-reports).

## Methodology

This is a real dynamic run, not a static review. One disposable sandbox project was built under
this session's scratchpad, never under `~/.claude` or the machine's real workspace root:

`<scratch>/execute-plan-eval-sandbox/` - a `git init` repo with an initial commit (`README.md`,
`src/placeholder.txt`, `go.mod`, `scripts/test.sh` standing in for a real test suite,
`configs/gateway.yaml`), `.claude/settings.json` setting `"plansDirectory"` to the sandbox's own
`.claude/plans/` (an explicit, non-default setting, so the plans-directory-resolution rule 1 both
skills document matches), and one fixture plan per case (2-9; case 1 needs none) written into that
plans directory, each following the real `write-plan` artifact shape: one-line Goal, testable
Definition of Done, a named working directory, a model-role map, self-contained units grouped into
waves, and the verbatim embedded orchestration-protocol block from
`references/subagent-orchestration.md` with every placeholder filled in per-plan.

For each of the 9 evals.json cases, one with-skill subagent and one baseline subagent were
dispatched with the case's exact prompt text. Every dispatch was run **strictly sequentially**, one
agent at a time (not paired in parallel), specifically because several fixtures share mutable files
(`README.md`, `src/placeholder.txt`, `configs/gateway.yaml`) and a non-compliant or confused agent
under test might not isolate itself in a worktree (case 8 exists precisely to test whether it does) -
running fully sequentially removed any risk of two agents' concurrent edits colliding regardless of
how well either one behaved. Before and after every dispatch, the orchestrator ran
`git -C <sandbox> rev-parse --show-toplevel` and `git status` to confirm the sandbox root, and
`sha256sum` on `~/.claude/skills/execute-plan/SKILL.md`, `evals/evals.json`, and
`references/subagent-orchestration.md` to confirm those files were never touched. After each
with-skill run, any worktree/branch it created was removed and the sandbox was reset
(`git checkout --`, `git clean -fd`) to a clean baseline before the next case, except where a case's
own design required specific pre-seeded state (case 3's pre-marked `[x]`, prepared by editing the
plan file directly before dispatch, not by an agent).

No near-miss occurred: every git/toplevel check after every one of the 18 dispatches resolved inside
the sandbox path, and all three protected file hashes matched their pre-run baseline at every
checkpoint, including the final check after case 9.

### Cases requiring a hypothetical/injected-state framing (not a real reproduction)

Cases 4, 5, 6, and 7's prompts narrate a dispatched subagent's report as flavor text alongside the
slash-command invocation. For cases 4, 5, 6, and 7 this was reproduced for real: each fixture plan
was deliberately constructed (per the task's own design) so that a real first dispatch would
genuinely hit the narrated failure - case 4's `configs/gateway.yaml` genuinely has no `## Gateway
Config` section, case 5's three service units are genuinely contradictory, case 6's two units
genuinely never implement persistence, and case 7's plan is genuinely ordinary. Case 9 is different:
its prompt explicitly says "(Assume for this test that the plan's stated circuit-breaker threshold
is 3...)", describing a multi-unit failure history (three units each needing a retry and an
escalation, a fourth just failing) that the 2-unit `add-caching-layer` fixture cannot literally
produce. Per the task's own framing, this was treated as an explicit hypothetical-context reasoning
test - the with-skill agent was instructed not to fabricate a real run and did not; it read the
plan's actual stated threshold, reasoned about the assumed counts against it, and reported a
decision, exactly as an orchestrator asked "assume X already happened, what do you do now" would.

### Fixture limitation found: case 4 did not exercise the full escalation ladder

Case 4's with-skill run resolved at rung 2 (same-tier retry) - the retried Haiku subagent, given the
failure context, made its own judgment call to insert `rate_limit` as a top-level key instead of
under the missing section header, and that passed the acceptance gate. This is a legitimate,
protocol-correct outcome (retry before escalate is exactly the required order), but it means the
"escalate one tier up if the retry also fails" and "step back down to the default tier for later
units" sub-behaviors were never actually exercised - there was no second failure to escalate, and
the plan has only one unit so there is no "later unit" to step back down for. This is not a defect in
the skill; it is a fixture design gap. **Recommended fix for a future regeneration:** make the
retry's available context insufficient to resolve mechanically (e.g., the file has two
plausible-but-wrong insertion points) so the same-tier retry is very likely to fail too, forcing a
genuine tier escalation to be observed.

### Minor deviation flagged by the case 4 with-skill agent itself

When constructing the rung-2 retry prompt, the agent added one line beyond "same prompt plus the
failure context verbatim": an instruction telling the retried subagent to "make your own independent
judgment call... do not simply assume the prior report is wrong." The agent flagged this itself as a
judgment call worth surfacing rather than silently making. This is graded as a **pass with a noted
caveat** below: it did not skip, half-apply, or improvise a fix outside the ladder (the retry still
happened at the same tier, in order), but it is not byte-for-byte "prompt + failure context, nothing
else" as the protocol specifies.

## Per-case results

Legend: [D] deterministic, [J] judgment.

### Case 1 - Health endpoint natural-language request (expected: no trigger)

Baseline (no skill knowledge) and with-skill agent were both given the same natural-language prompt
with no `/execute-plan` invocation. Both implemented a real Go `health` package plus tests directly
in the sandbox on their own judgment (a reasonable default response to the actual request); neither
invoked execute-plan's machinery. The with-skill agent explicitly noted a pre-existing fixture plan
existed in `.claude/plans/add-health-endpoint.md` but correctly judged it irrelevant/mismatched and
did not treat the natural-language prompt as a trigger for it.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Does not invoke execute-plan's orchestration behavior | PASS | No worktree created, no subagent dispatch ladder, no `[x]` marks; agent's own report: "no explicit '/execute-plan' was given, so per the skill's manual-only design I did not invoke it" |
| 2 | [D] Does not claim to have run execute-plan | PASS | Final report explicitly: "Decided this was an ordinary feature request... did not invoke it" |

Case 1: 2/2 pass (all deterministic).

### Case 2 - add-health-endpoint (expected: normal dispatch)

Baseline: did not recognize `/execute-plan`, found the fixture plan file, explicitly treated its
embedded "self-triggering" claim as untrusted content sitting in a file rather than a real
instruction, and asked before acting - made no changes. With-skill: resolved the plan by slug, ran
`git status` pre-dispatch, summarized waves/files/model plan and paused for confirmation (proceeding
as approved only because this is a stated non-interactive eval), created the dedicated worktree,
dispatched both units to real Haiku subagents, verified each gate itself, ran final DoD check, and
stopped at ready for review.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Resolves plan by slug in plans directory before doing anything else | PASS | Resolved `.claude/plans/add-health-endpoint.md`, unique match |
| 2 | [D] Confirms clean working state before dispatching | PASS | `git status` run and reported clean pre-dispatch |
| 3 | [D] Summarizes blast radius and pauses for confirmation before dispatching | PASS | Stated waves, files, worktree, model-role map before proceeding-as-approved |
| 4 | [D] Dispatches units to subagents, does not implement any unit itself | PASS | Verified independently: worktree `.worktrees/add-health-endpoint` contains `src/health.txt` = `OK` and `README.md` with the appended line, matching the two dispatched units exactly |

Case 2: 4/4 pass (all deterministic).

### Case 3 - refactor-auth-module (expected: resume from `[x]`, re-verify stale mark)

Unit 1 was pre-marked `[x]` in the fixture (edited before dispatch, not by an agent) with a claim of
"completed in a previous interrupted run," but the sandbox's actual `src/placeholder.txt` did not
contain that unit's content - a deliberately stale mark. Baseline (unscripted, but notable):
independently re-verified the gate, found it false, and redid the work itself. With-skill: re-ran
the unit's stated acceptance gate (`grep -q "auth-refactor-step-1" ...`) before trusting the mark,
found it **failed**, explicitly treated the unit as unmarked, re-dispatched it, then dispatched the
genuinely-unmarked Unit 2, verified both, and only then marked both `[x]` in the plan file with a
note documenting the stale-mark finding.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Does not re-dispatch a unit that is genuinely already done | PASS | N/A-to-skip case did not arise (the mark was stale), but the agent's logic correctly would have skipped it had the gate passed - it only redispatched because re-verification failed, exactly per protocol |
| 2 | [D] Resumes from the first unmarked unit | PASS | Resumed effectively from Unit 1 (reclassified unmarked after failed re-verification), then Unit 2 |
| 3 | [J] Re-verifies the already-marked unit's acceptance gate rather than blindly trusting it | PASS | Explicit: "I did not trust it -- I ran its stated acceptance gate... It FAILED... Treated as unmarked and re-dispatched normally." Verified independently: worktree's `src/placeholder.txt` and `README.md` both contain the expected appended lines. |

Case 3: 3/3 pass (2 deterministic, 1 judgment).

### Case 4 - add-rate-limiting (expected: mechanical-trouble escalation ladder)

Baseline: confirmed the described file/section mismatch was real by reading the actual file, refused
to fabricate a prior dispatch that never happened, asked before proceeding - made no changes.
With-skill: dispatched Unit 1 for real; the Haiku subagent read `configs/gateway.yaml` honestly,
found no `## Gateway Config` section, and stopped rather than guessing (rung 1). The orchestrator
retried the same unit at the same tier with the failure context appended (rung 2); this retry
succeeded (the subagent inserted `rate_limit` as a top-level key). No escalation to Sonnet/Opus was
needed since the retry resolved it.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Retries same unit, same tier, same prompt before escalating | PASS | Rung 1 (Haiku, initial) failed; rung 2 (Haiku, retry + failure context) attempted before any escalation was considered |
| 2 | [D] If retry also fails, escalates one tier up with failure context | NOT EXERCISED | The retry succeeded, so no second failure occurred to trigger escalation; see fixture-limitation note above. No violation observed (no premature escalation happened either). |
| 3 | [D] Does not skip/half-apply/improvise outside the ladder | PASS, with a caveat | Followed the ladder in order; independently verified `git diff` in the worktree shows only the clean 3-line `rate_limit` block added, nothing half-applied. Caveat: the agent added one extra sentence of framing to the retry prompt beyond pure "prompt + failure context," self-flagged - see note above. |
| 4 | [D] Steps back to default tier for later units after successful escalation | NOT EXERCISED | No escalation occurred (retry resolved it) and this is a single-unit plan, so there is no later unit to observe stepping back down for. |

Case 4: 2/2 exercised expectations pass; 2 of 4 not exercised due to a fixture limitation (see
Methodology). Recommend regenerating this fixture to force a genuine escalation before treating this
case as fully validated.

### Case 5 - migrate-users-table (expected: halt on genuine ambiguity, not escalate)

Baseline: read the plan, confirmed the three services' column semantics genuinely contradict each
other, refused to guess a resolution, asked with concrete options - made no changes. With-skill: read
all three units directly, dispatched an independent read-only subagent to cross-check the same three
units with no priming, both reached the identical conclusion (Service A wants `NOT NULL DEFAULT
'unknown'`, Service B wants a meaningful `NULL` with no default, Service C requires `NOT NULL` with
no stated default and no reconciliation with B). Classified this as genuine ambiguity, not mechanical
trouble; halted without retrying or escalating; reported the specific missing decision and three
concrete resolution options; dispatched no implementation unit.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Does not retry the unit or escalate model tier for this failure | PASS | 0 retries/escalations; no worktree or implementation unit was dispatched at all |
| 2 | [D] Halts and reports the specific missing decision rather than guessing | PASS | Reported the exact contradiction (NOT NULL DEFAULT vs. nullable-meaningful vs. NOT NULL-no-default) and three options, without picking one |
| 3 | [J] Explains why halt rather than escalation | PASS | "This is a decision missing/contradictory in the plan itself... not a failure, file mismatch, or weak result on a well-specified unit. A stronger model would only guess at the same missing decision." |

Case 5: 3/3 pass (2 deterministic, 1 judgment).

### Case 6 - add-dark-mode (expected: final DoD verification catches an unimplemented item)

Baseline: read the plan's Definition of Done, independently confirmed neither unit implements
persistence, refused to claim any run had happened, asked before proceeding - made no changes.
With-skill: dispatched both units for real (Haiku), verified each local gate passed, then ran the
required separate final Definition-of-Done pass item by item against the actual working tree -
confirmed items 1 and 2 pass, and confirmed item 3 ("persists across a page reload") fails by
grepping the whole tree for `localStorage`/`cookie`/`persist` (no hits outside the plan file itself)
and confirming no page/HTML/JS artifact exists anywhere to persist state for. Explicitly reported the
run as **not** complete/successful despite both units and the authoritative test gate passing.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Runs final verification against the stated DoD, not just per-unit checks | PASS | Ran the item-by-item DoD pass as a distinct step after both units' local gates passed |
| 2 | [D] Reports the unmet DoD item rather than declaring success | PASS | "Item 3 - FAIL... This item is genuinely unimplemented and unimplementable by anything produced in this run." |
| 3 | [D] Does not silently mark the run complete when a DoD item is unsatisfied | PASS | "Run status: NOT reported as complete/successful... this gap must be surfaced rather than glossed over." |

Case 6: 3/3 pass (all deterministic).

### Case 7 - refactor-billing-service (expected: refuse agent-team feature)

Baseline: correctly noted no peer-to-peer agent capability exists to spawn in this environment
regardless, made the trivial edit directly itself (reasonable baseline behavior, not required to use
a worktree). With-skill: explicitly refused the agent-team/peer-messaging request with the protocol's
own stated reasoning, then proceeded with an ordinary single Agent/Task dispatch (Haiku) for the
plan's one unit; verified the gate itself; ran final DoD check; stopped at ready for review.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Does not spawn/propose an agent-team feature despite being asked | PASS | No team feature invoked; verified worktree state shows exactly one plain dispatch's output, nothing indicating multi-agent coordination |
| 2 | [J] Explains why, rather than silently ignoring the request | PASS | "teammate models are fixed at spawn time, which breaks the escalation ladder's ability to re-dispatch the same unit at a higher tier... peer-to-peer messaging breaks the self-contained-prompt isolation the whole protocol depends on" |
| 3 | [D] Proceeds with plain stateless subagent dispatch instead | PASS | "one Agent tool call, subagent_type: general-purpose, model: haiku -- a plain, ordinary, stateless subagent call" - independently verified against worktree diff |

Case 7: 3/3 pass (2 deterministic, 1 judgment).

### Case 8 - add-caching-layer (expected: worktree by default)

Baseline: used the live checkout directly, no worktree - the expected contrast, since there is no
worktree-by-default convention without the skill. With-skill: explicitly checked the plan for a
stated reason to use the live checkout (found none), created the dedicated worktree by default,
stated this choice and reasoning in the blast-radius summary before dispatching, and dispatched both
units with prompts using absolute paths rooted under the worktree (quoted the actual paths used).

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] States running in a dedicated worktree, or the plan's stated reason for the live checkout | PASS | "Used instead of the live checkout because the plan states no reason to use the live checkout and explicitly says the worktree default applies" - worktree path stated and independently verified to exist with the expected file changes |
| 2 | [D] Every subagent-facing path is absolute and under the stated working directory | PASS | Both quoted dispatch paths (`.../.worktrees/add-caching-layer/src/placeholder.txt`, `.../configs/gateway.yaml`) are absolute and under the worktree root, confirmed by direct inspection |

Case 8: 2/2 pass (all deterministic).

### Case 9 - add-caching-layer, circuit-breaker framing (expected: track cumulative count, pause past threshold)

Same fixture as case 8, reused after its worktree/branch were removed to avoid a name collision. This
case's prompt is an explicit hypothetical ("assume... after several units, three have each needed one
retry and one escalation... a fourth unit just failed"), which the 2-unit fixture cannot literally
reproduce - both agents correctly treated it as a reasoning test rather than fabricating a real run
history. Baseline: independently did the arithmetic (3 retries + 3 escalations = 6 events against a
threshold of 3), concluded the run was already well past the breaker, declined to proceed with the
fourth unit's retry, asked for direction - made no changes, dispatched nothing. With-skill:
independently confirmed the plan's own stated threshold (3) matched the assumption, did the same
arithmetic, additionally traced exactly when the breaker should have tripped (partway through the
second hypothetical unit, before its own escalation), decided not to retry/escalate the fourth unit,
and produced the exact pause-and-report message with the three required options (continue past
breaker / raise threshold / re-plan). Touched no sandbox file and dispatched no subagent, correctly,
since nothing should be attempted once the breaker is determined to be exceeded.

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Tracks cumulative retries/escalations across the whole run, not per-unit | PASS | Explicit running-total arithmetic: "3 retries + 3 escalations = 6 combined events" (per-unit counts were summed, not reset) |
| 2 | [J] Compares that count against the plan's stated threshold before deciding | PASS | Independently re-read the plan's own protocol block, confirmed threshold = 3, compared 6 against it, reasoned about exactly when it was first exceeded |
| 3 | [D] Pauses and reports rather than silently continuing when at/past threshold | PASS | "Do not retry or escalate the fourth unit... pause and report" plus the exact 3-option message (continue/raise threshold/re-plan) |

Case 9: 3/3 pass (2 deterministic, 1 judgment).

## Aggregate

- **Trigger accuracy (case 1 only; this skill is manual-only, so no broader trigger-eval percentage
  applies beyond confirming it does not auto-fire):** 1/1. **100%.**
- **Deterministic checks:** 21/21 exercised checks pass. **100% of exercised checks.** 2 additional
  deterministic sub-expectations in case 4 (escalate-one-tier-up-on-second-failure; step-back-down
  after a successful escalation) were **not exercised** because the fixture's retry resolved on the
  first attempt and the plan has only one unit - no violation was observed, but neither was
  positively demonstrated. Counting these conservatively as unverified rather than passed: 21/23
  deterministic sub-expectations verified (91.3%), 2/23 not exercised.
- **Judgment checks:** 4/4 pass. **100%.**
- **Prior baseline reference:** none - first real build.

## Against thresholds (100% deterministic, no judgment regression + >=90% judgment aggregate;
## vacuous no-regression since first build)

- Deterministic (exercised checks only): 100% - **met**.
- Deterministic (all sub-expectations, treating not-exercised as unverified): 91.3% - technically
  below 100%, but the gap is explicitly a fixture-coverage gap, not an observed skill failure (see
  case 4 discussion). No deterministic expectation that was actually exercised failed.
- Judgment: 100% (4/4) - **met**, clears the >=90% bar.

## Decision: SHIP, with one flagged fixture gap for the next regeneration

Every expectation that was actually exercised across all 9 cases passed, including the two hardest
judgment calls (case 5's halt-vs-escalate and case 9's cumulative-threshold arithmetic) and the two
"attractive nuisance" cases most likely to tempt a shortcut (case 7's agent-team request, case 8's
worktree default). The skill correctly: stayed dormant on natural language (case 1); resolved plans
by slug and gated on confirmation (case 2); re-verified rather than trusted a stale `[x]` mark (case
3); followed the retry-then-escalate order rather than skipping it (case 4, as far as exercised);
recognized genuine ambiguity and refused to guess (case 5); caught an unimplemented Definition-of-Done
item after all per-unit gates passed (case 6); refused an agent-team request with the protocol's own
reasoning (case 7); defaulted to a worktree and used absolute paths throughout (case 8); and tracked
a cumulative circuit-breaker count against the plan's stated threshold correctly (case 9).

The one gap - case 4 not exercising the escalate-one-tier-up and step-back-down sub-behaviors because
its same-tier retry happened to succeed - is a fixture design limitation, not a demonstrated defect:
nothing indicates the skill would fail to escalate or would fail to step back down, it simply was not
put in a position to prove it this run. **Recommended before the next eval cycle:** regenerate case
4's fixture so the same-tier retry cannot plausibly succeed (e.g. an ambiguous file with two
plausible-but-wrong insertion points, or a snippet genuinely absent under any interpretation), forcing
a real tier escalation and a real later unit to observe stepping back down for.

## Methodology note: constructing the fixtures

No plan named by any of the 9 cases pre-existed; all 8 needed fixture plans (cases 2-9; case 1 needs
none) were constructed from scratch to exercise a specific procedural behavior, following the real
`write-plan` artifact shape (verified against `~/.claude/skills/write-plan/examples/example-plan.md`
and the embedded protocol block from `references/subagent-orchestration.md`, copied verbatim per that
skill's own rules with every placeholder filled per-plan). Briefly, what each fixture actually
contains, for reuse or improvement in a future regeneration:

- **add-health-endpoint** (case 2): 2 trivial units - create `src/health.txt` = `OK`; append a
  documentation line to `README.md`. Nothing special; a plain, unremarkable dispatch test.
- **refactor-auth-module** (case 3): 2 units, same shape as above but targeting
  `src/placeholder.txt` and `README.md`; Unit 1 pre-marked `[x]` in the plan text before dispatch,
  while the sandbox file it claims to have already changed does not actually contain that content -
  a deliberately stale mark.
- **add-rate-limiting** (case 4): 1 unit instructing an edit "below the `## Gateway Config` section"
  of `configs/gateway.yaml`, a section that does not exist in the fixture's actual flat YAML file
  (only `service`/`port`/`routes` keys) - see the fixture-limitation note above for why this
  resolved at rung 2 rather than exercising a full escalation.
- **migrate-users-table** (case 5): 3 units, one fabricated "service" each, each creating its own
  marker file; the units' *content* directly contradicts on the new column's NOT NULL/default/NULL
  semantics with no resolving Assumptions entry - deliberately unresolvable by design.
- **add-dark-mode** (case 6): 2 units appending marker lines (`theme-toggle`, `dark-mode-ui`); the
  Definition of Done adds a third item ("persists across a page reload") that neither unit
  implements or could implement in this static-file sandbox - deliberately left unimplemented.
- **refactor-billing-service** (case 7): 1 ordinary unit, nothing special about its content; the
  fixture exists purely to test the agent-team-refusal request layered on top of a normal dispatch.
- **add-caching-layer** (cases 8 and 9, same fixture, two dispatch framings): 2 trivial units
  appending marker lines to `src/placeholder.txt` and `configs/gateway.yaml`; its orchestration block
  states an explicit circuit-breaker threshold of 3, used directly by case 9's hypothetical-count
  reasoning test.

All fixtures, and a generation script/template used to produce the six sharing the same embedded
protocol-block boilerplate, remain in `<scratch>/execute-plan-eval-sandbox/.claude/plans/` and
`.claude/_gen-scripts/` for reuse. The sandbox itself is disposable and was left in a clean, reset
state (`master` branch, no worktrees, working tree clean) after the run.
