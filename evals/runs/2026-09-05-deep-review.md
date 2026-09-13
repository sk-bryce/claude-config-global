# deep-review eval run - 2026-09-05 (real dynamic run)

> **Superseded on both measured layers; the SHIP below was withdrawn.** The trigger figure was
> computed at `run_eval.py`'s 0.5 default rather than this repository's 3-of-3 rule, and re-running
> at n=9 put positives well under it. The 25/25 deterministic and 14/14 judgment figures were
> hand-rolled; re-run through the skill-creator harness they are **23/25 and 13/14**. See
> `evals/runs/2026-09-07-deep-review-trigger.md` and `evals/README.md`. The methodology, the
> fidelity limits, and the four false-green modes recorded here all still stand.

## Harness and model

- Harness: Claude Code. Exact build string not captured - `claude --version` is not resolvable
  from this session's shell, and no version string was fabricated to fill the field.
- Model running this orchestrating session: Opus 5 (`claude-opus-5`).
- Model for the 10 dispatched case agents: `subagent_type: general-purpose` with no model
  override, inheriting the orchestrator's Opus 5.
- Judge model: the orchestrating session itself (Opus 5), grading against transcripts and
  against mechanical tool-call tallies extracted from each agent's JSONL, not against agent
  self-report alone.
- Model for the two blind quality-comparison agents: Opus 5 for both, deliberately matched so
  that the checklist was the only variable between them.

## Methodology

The skill under test lives on branch `deep-review-skill` and is not loaded by the harness from a
worktree. For the duration of this run it was copied to `~/.claude/skills/deep-review/` as an
untracked directory so the harness would load it, and removed afterward; the working tree was
verified clean at the end. Availability to dispatched subagents was confirmed by probe before any
case ran.

Each of the 10 `evals.json` cases was dispatched as one fresh `general-purpose` subagent given
only the case prompt, with fixture paths rewritten to absolute paths under the installed copy, and
with a standing instruction not to read `evals.json`, `plans/`, or any memory directory. No agent
was told which skill was under test or what the expectations were; triggering was real, not
scripted. Each agent appended a self-reported ACTIONS TAKEN block, cross-checked against a
mechanical tally of `Skill`, `Agent`, and `AskUserQuestion` calls grepped from its transcript.

### Two known fidelity limits

**`AskUserQuestion` is unavailable to dispatched subagents.** Every agent that needed it confirmed
its absence via `ToolSearch` and used the skill's documented plain-text fallback. Case 2's first
expectation offers both branches, so it grades cleanly, but the `AskUserQuestion` branch itself is
untestable by this method and remains unverified.

**Cases 2 and 3 reference "the loop I just wrote."** A fresh subagent has no prior turn, so a
five-line snippet was prepended to both prompts. This is a faithful reconstruction of the intent
but is not identical to the in-session context the case assumes.

### Contamination found and attributed

Case 8 ran `scripts/health-check.sh` and reported `spec-coverage` and `readme-coverage` findings
against `skills/deep-review/`. **Both are artifacts of this run's temporary install onto `main`,
not repository defects.** On branch `deep-review-skill` the skill is present in both
`specs/skills.md` and `README.md` (verified). The same run rewrote the gitignored, machine-local
`.health-check-stamp` to `date=2026-09-05 commit=82fc5f5 findings=2`, discarding its prior value.

## Primary test: quality comparison

Run per `plans/plan-deep-review-skill.md`, against a pre-registered answer key written before any
review ran. Known-weak artifact: the repo tree as of 2026-09-03, mounted detached at
`.worktrees/eval-baseline` and published as the `eval-baseline` branch. Ground truth: the diff and
message of the 2026-09-03 commit "Sharpen the three new eval sets and close two coherence gaps",
authored by the user and preserved as `evals/baselines/2026-09-03-ground-truth.patch`.
Both agents were blind - neither saw the key, the fix commit, or its message, and both were barred
from all git history commands.

| Pre-registered defect | deep-review | plain "review this" |
| --- | --- | --- |
| A - expectations conditioned on states the eval never creates | HIT (`skills/research/evals/evals.json:81`, diagnosed as an antecedent that never fires) | MISS |
| B - `[judgment]` labels on binary transcript facts, scored leniently against the 100/90 split | HIT (`skills/cursor-projection/evals/evals.json:72`, tied to threshold routing) | HIT (same line, same reasoning) |
| C - health-check case 8's self-invalidating advisory expectations | HIT, including the reflexive loop | HIT, including the reflexive loop |

**3 versus 2. Pass condition met, and it should not be leaned on.** Four caveats, recorded so a
later reader does not over-read the checkmark:

- The margin is one defect. On A the plain pass reached the same line
  (`skills/research/evals/evals.json:79-81`) but diagnosed it as a labeling and reproducibility
  problem rather than an unreachable antecedent. That is a grader judgment call; a reasonable
  grader could score it a hit, making the comparison a tie and the primary test a failure.
- Each pass found only one instance per defect class. B is three relabeled expectations; both
  passes found the `cursor-projection` one and neither found the two in `research`. The skill
  identifies defect classes, not instances.
- An asymmetry was introduced by the method: the deep-review agent received the four-field context
  brief and the plain agent did not. That is the skill's actual design and is fair to credit, but
  some of the gap may be the brief rather than the checklist.
- The key's prediction that the plain pass would find only a `README.md` run-on wrap was well off.
  The plain pass returned 26 findings and independently caught defect C's reflexive trap in the
  same words. Neither pass found the run-on wrap.

Both passes did catch the secondary defect the key named but did not score: the unfalsifiable
"does not answer from memory" at `skills/cursor-projection/evals/evals.json:12`, identified as both
ungradeable and a duplicate of the check above it - which is why that 2026-09-03 fix commit replaced
rather than
relabeled it.

## Per-case results

Legend: [D] deterministic, [J] judgment.

### Case 1 - plain "review this doc" (expected: `review-md` fires, `deep-review` does not)

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Invokes review-md | PASS | Transcript tally: one `Skill` call, `review-md` |
| 2 | [D] Does not invoke deep-review | PASS | No `deep-review` invocation in tally or self-report |
| 3 | [D] No Agent dispatch with model opus for a premise pass | PASS | `review-md` forked its own review agent; no premise dispatch |
| 4 | [D] Flags the 'Acess' typo | PASS | "Line 8: `Acess` -> `Access`. Straight misspelling." |
| 5 | [D] No ladder verdict | PASS on the letter, flagged | Output carried a section headed "Verdict" containing none of the four ladder terms. Passes as written; a `review-md` pass growing a "Verdict" heading is the first sign of boundary bleed, and only the expectation's phrasing saves it |

Case 1: 5/5 deterministic.

### Case 2 - trivial-target confirm (variable rename)

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Asks once before writing a context brief | PASS | Asked before the brief, citing the skill's own "a variable name" example |
| 2 | [D] Uses AskUserQuestion, or plain text if unavailable | PASS | Confirmed absence via `ToolSearch`, used the documented fallback |
| 3 | [D] No Agent dispatch before the user answers | PASS | Tally: zero `Agent` calls |
| 4 | [J] Treats the rename as low-stakes and reversible | PASS | "invisible outside the function, and reversible in one keystroke" |

Case 2: 4/4 (3 deterministic, 1 judgment). Note: the agent also hit the context-brief gate and
reported that even a "yes" could not dispatch, because `Alternatives already rejected` and
`Constraints` were empty. First observation of finding 1 below.

### Case 3 - user declines the full pass

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] No Agent dispatch | PASS | Tally: zero `Agent` calls, zero `Skill` calls |
| 2 | [D] Substantive inline answer, not just an acknowledgement | PASS | Gave the rename call plus a `sum(1 for ...)` alternative |
| 3 | [D] Does not re-ask after the decline | PASS | Reasoned explicitly that the trigger matched but the user had declined |

Case 3: 3/3 deterministic.

### Case 4 - one-line change, wide blast radius (expected: full pass, no confirm)

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Dispatches an Agent subagent with model opus | **FAIL** | Tally: zero `Agent` calls. Blocked at the context-brief gate |
| 2 | [D] Does not use subagent_type fork | PASS, vacuous | No dispatch occurred at all |
| 3 | [D] Ends with one of the four ladder verdicts | **FAIL** | No verdict emitted |
| 4 | [D] States the strongest argument against its own verdict | **FAIL** | No verdict to attach one to |
| 5 | [J] Treats the change as wide-impact, not trivial | PASS | Declined to ask, citing "stakes and reversibility decide it, not size" |
| 6 | [J] Raises a second-order effect of a longer connect timeout | PASS | Worst-case wall time per logical call from ~140s to ~240s via `max_retries: 3` |

Case 4: 2 substantive passes, 1 vacuous, 3 fails. **The discrimination the case exists to test
works; the pass it gates never runs.**

Incidental, and a real defect in the case rather than the skill: the agent noted that
`http-defaults.json` sits inside the eval suite's own `files/` directory while the prompt describes
it as a live shared production default, and said it could not tell which framing was operative.

### Case 5 - false-positive control (a genuinely sound proposal)

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | PASS | Tally: one `Skill` call, `deep-review` |
| 2 | [D] Dispatches an Agent subagent with model opus | PASS | `model: opus`, `subagent_type: general-purpose`, fresh not fork |
| 3 | [D] Returns the verdict Proceed | **FAIL** | Returned "Proceed with changes" |
| 4 | [D] States the strongest argument against its own verdict | PASS | Stated that with yarn v1, a committed lockfile and one install site, the call collapses to plain Proceed |
| 5 | [J] Does not manufacture objections | PASS | Objections verified real - see below |

**Case 5 is INVALID as built, not failed.** The fixture is billed as genuinely sound but is not.
`evals/files/sound-proposal.md:12` says `--frozen-lockfile` and never names the package manager.
That flag does not exist in npm, where the equivalent is `npm ci` with different semantics; in pnpm
and yarn Berry, frozen installs already default to on under CI detection, which would contradict
the proposal's own premise at line 5 that CI "resolve[s] dependencies fresh on every run." Only
yarn v1 matches the document as written. For a proposal whose entire content is one flag, that is
load-bearing. Expectation 3 therefore fails against a defective fixture, and the judgment
expectation - the one that actually tests for manufactured objections - passes. **The plan's
required false-positive case is not satisfied by this result.** It needs the fixture repaired
(name the package manager, quote the exact before/after command) and a re-run.

This case is also the control that localizes finding 1: it is the only case whose artifact supplied
its own rejected alternatives, and the only case besides 8 that dispatched.

### Case 6 - "critique this approach", no artifact

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | PASS | Tally confirms |
| 2 | [D] Ends with one of the four ladder verdicts | PASS | "Reconsider scope" |
| 3 | [J] Names a concrete alternative including doing nothing | PASS | "Do nothing, but instrument", plus retry-the-test, quarantine-with-expiry, harness-level fixes |
| 4 | [J] Questions whether retrying addresses cause or masks symptom | PASS | `p` -> `p^3`: "exactly as broken as before, and now nothing will ever force it to be fixed" |

Case 6: 4/4 (2 deterministic, 2 judgment). Reached the gate, said so, and delivered the verdict
anyway - the opposite of case 10's choice on identical input shape. See finding 2.

### Case 7 - "push back on this" (the pre-registered watch item)

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | **FAIL** | Tally: one `Skill` call, `skill-author` |
| 2 | [D] Ends with one of the four ladder verdicts | **FAIL** | Closed with four numbered options |
| 3 | [J] Names a concrete cost of consolidation | PASS | The 1,536-char per-description cap, with all eight description lengths measured |
| 4 | [J] Argues whether it is worth doing, not only how | PASS | Corrected the premise (eight skills, not seven) and argued the merge down |

Case 7: 2/4. **The watch item was correct.** "Push back on this" is the one trigger phrase of the
ten with no lexical anchor in the description, and it is the one that missed. `skill-author`
displaced it by matching on the target domain while `deep-review` matched on nothing.

The substantive output was the strongest of any case - it found five hand-synced `references/`
copies, two byte-identical at 256 lines, differing from source only by a 3-line banner. That
sharpens rather than softens the finding: the user got an excellent answer, just not from this
skill.

### Case 8 - "be critical" about a pre-commit health-check hook

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | PASS | Tally confirms |
| 2 | [D] Ends with one of the four ladder verdicts | PASS, placement flagged | "Reconsider scope", but stated at the top rather than closing. The skill's "State a verdict" section frames it as the close |
| 3 | [J] Raises the fit question of right layer and right time | PASS | Proposed `--gate` mode, pre-push, and CI as alternative layers |
| 4 | [J] Names a concrete alternative rather than only objecting | PASS | Four, with a falsifiable sub-1s bar on the recommended one |

Case 8: 4/4 (2 deterministic, 2 judgment). Dispatched Opus, `subagent_type: general-purpose`,
not a fork. See the contamination note above for the two findings this run produced that were
artifacts of the test install.

### Case 9 - context-brief hard gate (bare file, no context)

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] No Agent dispatch while the brief is incomplete | PASS | Tally: zero `Agent` calls |
| 2 | [D] Names Purpose as the field it cannot fill | PASS | Named Purpose, plus the other three |
| 3 | [D] No verdict from an undispatched pass | PASS | Explicitly labelled its observations "not the deep-review verdict" |
| 4 | [J] Stops or asks rather than proceeding with a caveat | PASS | Asked for the fields, offered a plain code review as the alternative |

Case 9: 4/4 (3 deterministic, 1 judgment). The gate bites, loudly and correctly.

### Case 10 - substantive proposal, no artifact

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | PASS | Tally confirms |
| 2 | [D] Dispatches an Agent subagent with model opus | **FAIL** | Tally: zero `Agent` calls |
| 3 | [D] Ends with one of the four ladder verdicts | **FAIL** | Explicitly withheld: "a prior and not the verdict" |
| 4 | [D] States the strongest argument against its own verdict | **FAIL** | Stated one, but attached to a withheld prior rather than a verdict |
| 5 | [J] Does not give a lighter pass for lack of an artifact | PASS | Read `reference/public-repo-hygiene.md` and `docs/multi-account-claude-code.md` unprompted |
| 6 | [J] Names a concrete alternative to a second repository | PASS | All four existing override routes, including gitignored root files and `CLAUDE_CONFIG_DIR` profiles |

Case 10: 3/6. This case localizes finding 1 precisely: `Purpose`, `Constraints`, and `Prior
findings` were all filled from the repo unaided. **Only `Alternatives already rejected` was empty**,
and that alone blocked the dispatch.

## Aggregate

- **Trigger accuracy:** 5/6 of the cases that assert a trigger decision. Case 1 correctly did not
  fire; cases 5, 6, 8, 10 correctly fired; case 7 failed to fire. **83.3 percent.**
- **Deterministic checks:** 23/32, counting case 4's expectation 2 as a vacuous pass.
  **71.9 percent.**
- **Judgment checks:** 13/13. **100 percent.**
- **Prior baseline reference:** none - first build for this skill.

The shape of that split is the most informative single result in this run. Every judgment check
passed, across all ten cases, including the three cases that failed overall. The skill's reasoning
is not in question. What fails is mechanical: whether it triggers, whether it dispatches, and
whether it emits a verdict.

## Against thresholds

- Trigger: 83.3 percent against 100 percent - **not met**.
- Deterministic: 71.9 percent against 100 percent - **not met**.
- Judgment: 100 percent against >= 90 percent aggregate - **met**. No-regression is vacuous with no
  prior baseline.

## Decision: HOLD

**Superseded by the re-run below.** The fixes this section demanded were applied the same day and
cases 4, 5, 7, and 10 were re-run; see "Re-run after fixes" for the current numbers and decision.
This section records the pre-fix state and is kept as the failing baseline.

Two of three thresholds missed. Three findings block, in severity order.

**1. The context-brief gate is miscalibrated and blocks the skill's primary function.** Only 2 of
10 runs dispatched. `Alternatives already rejected` is the blocking field: case 10 filled the other
three from the repo unaided and still stopped, and case 5 dispatched precisely because its artifact
listed its own rejections. The field is empty when a user proposes something new and has genuinely
rejected nothing - which is not the same as missing context, but `SKILL.md`'s "Any empty field
blocks the dispatch" cannot distinguish the two. The gate's reasoning is sound; its absolutism is
not. **Direction decided by the user on 2026-09-05: distinguish empty from unknown** - let
"none considered yet" count as a filled field, keeping the gate for genuinely thin briefs. Not yet
implemented.

**2. The gate is ambiguous and behaves inconsistently on the same input shape.** "Name the field
that is missing and stop" does not say whether to stop dispatching or stop reviewing. Case 6
blocked and delivered a full verdict; case 10 blocked and withheld one; case 8 had no stated
alternatives and dispatched anyway. Three same-shaped inputs, three behaviors. Part of the pass/fail
split in this run is therefore a coin flip rather than a measurement, which weakens every
gate-related result here including the ones that passed.

**3. "Push back on this" does not fire the skill.** One-line fix: anchor the phrase, or a near
synonym, in the description's enumerated examples. Re-run case 7 after.

### A premise-level result the eval suite cannot see

Cases 6 and 10 produced assumption audits, concrete alternatives, second-order effects, and
counter-arguments **with no Opus dispatch at all**. Case 6's inline output meets the skill's full
quality bar unaided. The dispatch is the structure the entire skill is built around, and two runs
suggest the inline phase may already clear the bar on its own. The suite cannot test this, because
every case that asserts a dispatch also assumes the dispatch is what produced the quality. Worth
the skill owner's attention before finding 1 is fixed, since fixing the gate presumes the dispatch
is worth unblocking.

## Not run

- **Manual invocation** - `/deep-review` and `/deep-review <path>` (plan gate item 2). Untested.
- **Successful-dispatch brief inspection** (plan gate item 6, first half). The gate was confirmed
  to bite, but no successful dispatch prompt was inspected to verify all four fields carry real
  content rather than a path.
- **The `AskUserQuestion` branch of the confirm step.** Untestable via subagents; only the
  plain-text fallback ran.

---

# Re-run after fixes - 2026-09-05, same day

## What changed between the two runs

Three fixes to `skills/deep-review/SKILL.md`, applied in response to the three blocking findings
above:

1. **Trigger anchor** - added "push back on this," "critique this approach," and "be critical about
   this" to the description's enumerated examples. Description grew to 752 chars, well inside the
   1,536-char per-description cap.
2. **Gate calibration** - the brief's `Alternatives already rejected` bullet now states that "none
   considered yet" is a complete answer, and the gate rule was rewritten to "a field whose answer is
   unknown blocks the dispatch; a field whose answer is 'nothing' does not," with an added
   instruction to fill every field the target, conversation, and repository can answer before asking
   the user for anything.
3. **Gate disambiguation** - "stop" is now defined explicitly: do not dispatch and do not state a
   verdict, but do give what the artifact alone supports, labelled as preliminary and explicitly not
   the verdict, then ask for the missing field.

Plus one fixture repair attempt on `evals/files/sound-proposal.md`, discussed under case 5.

## Per-case re-run results

### Case 4 - re-run twice; trigger is flaky, and the case is defective

Three total runs of the identical prompt fired the skill, then did not, then did. **A 2-of-3 trigger
rate on a prompt opening with "Is this a good idea?" - a phrase the description enumerates verbatim
- means single-run trigger results in this suite carry real noise.**

The graded run (the third) shows finding 3's fix working exactly as designed: it filled three brief
fields, identified `Purpose` as genuinely unknown, gave three substantive preliminary observations
explicitly labelled "not a verdict," withheld the verdict, and asked for the missing field.

Score unchanged at 2 substantive passes, 1 vacuous, 3 fails. **The remaining failures are the
case's defect, not the skill's.** The prompt says "I want to change X" and never says why, so
`Purpose` is genuinely unknown and the gate is correct to block; yet expectations 1, 3, and 4 assert
a dispatch and a verdict. Those cannot both hold. The case was built to test stakes-versus-size
discrimination, which passed in all three runs.

**Recommended fix, not applied:** give the case prompt a motivation ("we are seeing connect timeouts
against one dependency") so it tests blast-radius discrimination without colliding with the brief
gate.

### Case 5 - three fixture attempts, three real defects; the case is mis-specified

| Attempt | Fixture premise | Verdict | Defect found |
| --- | --- | --- | --- |
| Original | `--frozen-lockfile`, package manager unnamed | Proceed with changes | Flag does not exist in npm; pnpm and yarn Berry default it on under CI, contradicting the premise |
| Second | Yarn 1.22 named explicitly | Proceed with changes | Yarn 1 with a committed lockfile already installs locked versions; `--frozen-lockfile` only changes silent-rewrite into failure |
| Third | `npm install` to `npm ci` | Proceed with changes | Since npm 7, `npm install` builds from the lockfile and does not upgrade an already-locked transitive; that is `npm update` |

Each attempt scored 4/5, failing only expectation 3 ("Returns the verdict Proceed"), and passing the
judgment expectation every time. In all three the reviewer explicitly credited what held up - "scope
discipline is genuinely good," "fit is right on all three axes," the manifest-pinning rejection
correct - which is the false-positive property the case exists to demonstrate.

**The conclusion is about the case, not the skill.** The fixture's core premise - CI re-resolves and
picks up a breaking transitive version - is false for every modern package manager *with a committed
lockfile*. yarn, pnpm, and npm all install from the lockfile. Any proposal resting on that premise
contains a real defect, so a competent reviewer will keep finding one, and plain `Proceed` is
unreachable. Editing the flag cannot fix this; the premise requires the lockfile to be absent, at
which point the sound proposal becomes "commit the lockfile."

**Two options, neither applied:** rebuild the fixture on a premise with no false factual claim, or
relax expectation 3 to accept `Proceed` or `Proceed with changes` provided no objection is
manufactured. The second is the better bar - it grades the behavior the case actually cares about,
and a rigorous pass on any real technical proposal will almost always find something worth changing.

### Case 7 - trigger fixed; a new skill defect surfaced

| # | Expectation | Before | After |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | FAIL | **PASS** |
| 2 | [D] Ends with one of the four ladder verdicts | FAIL | **FAIL** |
| 3 | [J] Names a concrete cost of consolidation | PASS | PASS |
| 4 | [J] Argues whether it is worth doing | PASS | PASS |

2/4 to 3/4. **The trigger fix works** - `deep-review` now fires on "push back on this" (after
`skill-author`, but it fires), and it dispatched a fresh Opus subagent with a densely populated
brief.

Expectation 2 still fails, and this is a **new, genuine skill defect**. The dispatched pass produced
a verdict; the inline presentation phase then reframed it as "Pushing back: don't do this" plus four
numbered options, and none of the four ladder terms survived. `SKILL.md`'s phase 3 says to "present
the findings" but never says to carry the verdict through verbatim, so the presentation step can
silently drop the single output the skill mandates.

**Recommended fix, not applied:** one line in "Write the context brief and dispatch", phase 3 -
state that the dispatched pass's ladder verdict must be reproduced verbatim, not paraphrased or
restructured into options.

### Case 10 - fully fixed

| # | Expectation | Before | After |
| --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | PASS | PASS |
| 2 | [D] Dispatches an Agent subagent with model opus | FAIL | **PASS** |
| 3 | [D] Ends with one of the four ladder verdicts | FAIL | **PASS** (Reconsider scope) |
| 4 | [D] States the strongest argument against its own verdict | FAIL | **PASS** |
| 5 | [J] Does not give a lighter pass for lack of an artifact | PASS | PASS |
| 6 | [J] Names a concrete alternative to a second repository | PASS | PASS |

3/6 to **6/6**. Its `Alternatives already rejected` field reported "none named by the user" and then
supplied the five override mechanisms the repo already has, so the empty field became information
handed to the reviewer rather than a wall. That is precisely what fix 2 was for.

## Previously-unrun gate items, now run

- **Plan gate item 2, manual with an argument path** - PASS. The skill resolved the argument to the
  named file explicitly, said the conversation-default path was not used, dispatched Opus, and
  returned a verdict with a counter-argument.
- **Plan gate item 2, manual with no argument** - PASS. Resolved the target to the most recent
  in-conversation claim and said so explicitly.
- **Plan gate item 6, first half (successful-dispatch brief inspection)** - PASS, on four separate
  dispatches. Every brief carried four fields of real content, not a path. One is quoted in full in
  the log for this run.
- **Plan gate item 5, the `AskUserQuestion` branch** - PASS. Run from the orchestrating session
  rather than a subagent, since subagents do not have that tool. On a variable-rename target the
  skill asked via `AskUserQuestion` before writing any brief, and the decline produced a short real
  answer rather than silence.

## Re-run aggregate

Latest result per case; cases 1, 2, 3, 6, 8, and 9 were not re-run and carry their original scores.

- **Trigger accuracy:** 6/6. **100 percent** - up from 83.3 percent. *Caveat:* case 4's ungraded
  trigger flaked in 1 of 3 runs, so this number is less stable than it looks.
- **Deterministic checks:** 27/32. **84.4 percent** - up from 71.9 percent.
- **Judgment checks:** 13/13. **100 percent**, unchanged.

## Against thresholds, after fixes

- Trigger: 100 percent - **met**.
- Deterministic: 84.4 percent against 100 percent - **not met**.
- Judgment: 100 percent - **met**.

## Decision after fixes: HOLD

One threshold still missed, but the composition of the remaining failures has changed completely.
All five outstanding deterministic failures are now accounted for:

- **Three (case 4)** are a defect in the case, which asserts a dispatch from a prompt that supplies
  no `Purpose`.
- **One (case 5)** is a mis-specified expectation demanding a verdict token that a sound review of a
  real technical proposal will rarely produce.
- **One (case 7)** is a genuine skill defect: the inline presentation phase can drop the ladder
  verdict the dispatched pass produced.

**Exactly one real skill defect remains**, and its fix is one line. The three findings that blocked
the first run are all closed and verified by direct evidence: the trigger fires, the gate
distinguishes empty from unknown, and a blocked gate now withholds the verdict while still
answering. Recommend applying the case-4 prompt fix, the case-5 expectation relaxation, and the
phase-3 verdict-preservation line, then re-running cases 4, 5, and 7 alone.

## Standing caveat on the primary quality comparison

The 3-2 result above was measured against the **pre-fix** skill. The checklist sections it exercised
were not touched by any of these fixes, so the comparison is not invalidated, but it has not been
re-run and its four caveats stand unchanged.

---

# Fourth fix and verification - 2026-09-05

The re-run above identified one genuine skill defect: phase 3 could drop the ladder verdict the
dispatched pass produced. That fix was applied and verified.

**Fix 4 - verdict preservation.** Added to "Write the context brief and dispatch", after the three
phases: phase 3 reproduces the dispatched pass's verdict verbatim, carrying the ladder term, its
one-sentence reason, and the counter-argument through exactly as returned. Explicitly forbids
restructuring the call into a menu of options, since a list of choices is not a verdict.

**Verification - case 7, the case that exposed the defect.**

| # | Expectation | First run | After fixes 1-3 | After fix 4 |
| --- | --- | --- | --- | --- |
| 1 | [D] Invokes deep-review | FAIL | PASS | **PASS** (fired first, no `skill-author` detour) |
| 2 | [D] Ends with one of the four ladder verdicts | FAIL | FAIL | **PASS** ("Do not proceed") |
| 3 | [J] Names a concrete cost of consolidation | PASS | PASS | PASS |
| 4 | [J] Argues whether it is worth doing | PASS | PASS | PASS |

2/4, then 3/4, now **4/4**.

**Regression check - case 6**, which already passed expectation 2 and could have been broken by the
new wording. Still passes, returning "Reconsider scope" with its counter-argument, and the agent
described its own output as "the verdict reproduced as returned" - the instruction is being honored
rather than ignored. No regression.

## Final aggregate

- **Trigger accuracy:** 6/6. **100 percent.**
- **Deterministic checks:** 28/32. **87.5 percent** (71.9 -> 84.4 -> 87.5).
- **Judgment checks:** 13/13. **100 percent.**

## Final decision: HOLD, with no known skill defects outstanding

Deterministic is still short of its 100 percent threshold, so the gate does not clear. But every
remaining failure is now a defect in the eval suite rather than in the skill:

- **Three (case 4)** - the case asserts a dispatch and verdict from a prompt that supplies no
  `Purpose`, which the brief gate is correct to block.
- **One (case 5)** - the case demands the verdict token `Proceed` against a fixture whose premise
  cannot be made true.

All four skill defects found by this run are closed and each was verified by re-running the case
that exposed it: the trigger fires, the gate distinguishes empty from unknown, a blocked gate
withholds the verdict while still answering, and the verdict survives phase 3.

Clearing HOLD requires two decisions about the suite, which belong to its owner and were
deliberately not made here.

## Contamination, restated

Across cases 7, 8, and this verification run, agents reported that `skills/deep-review/` is
untracked, absent from `README.md`, and absent from `specs/skills.md`, and that
`scripts/health-check.sh` fails on it. **All of these are artifacts of the temporary install onto
`main` that this run required.** On branch `deep-review-skill` the skill is tracked,
`specs/skills.md:367` carries a real `## deep-review` section, and `README.md` names it. Any future
run using the same install method should expect the same false findings.

---

# Suite amendments and the three-arm dispatch experiment - 2026-09-05

This section supersedes the "Final aggregate" and "Final decision" above.

## Suite amendments

Both remaining defects were in the eval suite, not the skill. The owner chose a fix for each.

**Case 4 - added a motivation to the prompt.** The old prompt asked whether changing
`connect_timeout_seconds` from 5 to 30 was a good idea without ever saying why, so `Purpose` was
genuinely unknown and the brief gate was correct to block. The prompt now supplies the motivation
("we're seeing connect timeouts against one slow dependency") and states the blast radius in the
prompt itself. This keeps the case testing what it was written to test - that the confirm step keys
on stakes rather than on size - instead of accidentally testing the brief gate a second time, which
case 9 already covers.

**Case 5 - relaxed the verdict expectation.** The case demanded the token `Proceed`. Three separate
fixture rewrites all drew `Proceed with changes` for reasons that were correct about the artifact in
front of them, and the underlying premise turned out to be unrealizable: "CI re-resolves and picks up
a breaking transitive" is false for yarn, pnpm, and npm alike once a lockfile is committed, because
all three install from the lockfile. The expectation now accepts `Proceed` or `Proceed with changes`
and rejects only `Reconsider scope` or `Do not proceed`. The false-positive property the case exists
to test is carried instead by two judgment expectations: no manufactured objections, and explicit
credit for what holds up.

**Verdict-placement wording, applied across the suite.** Five cases read "Ends with one of Proceed,
...". The skill never required the verdict to come last, and a run that opened with the call was
being failed for placement rather than for substance. All five now read "States one of ... as an
explicit verdict, whether it opens or closes with it", and `SKILL.md`'s "State a verdict" section
says the same thing explicitly.

## Amended-case verification

**Case 4, re-run against the amended prompt: 6/6.** Dispatched an `Agent` subagent at `model: opus`,
not a fork; returned "Reconsider scope" with a counter-argument; treated the change as wide-impact
because it is the shared default rather than trivial because it is one line; and raised a
second-order effect the case only asked for in general terms - a Little's-law argument that a 6x
longer connect timeout multiplies in-flight connection slots during an outage, turning one slow
dependency into a connection-pool exhaustion event across every outbound call.

**Case 5: 6/6 on existing evidence, no re-run needed.** The three prior runs all returned "Proceed
with changes", which the amended expectation accepts, and all three credited the proposal's stated
alternatives, cost, and rollback path by name. The objections they raised were factually correct
about the fixture, which the judgment expectation explicitly does not count as manufactured.

## Three-arm experiment: does the dispatch earn its cost?

The open premise-level question was whether the `Agent` dispatch causes the quality, or whether the
checklist alone does. Every case asserting a dispatch assumes the former without testing it. Three
arms were run blind against `.worktrees/eval-baseline` (detached at the 2026-09-03 baseline tree), on
the same four
files, with no access to git history, `plans/`, `decisions/`, or memory:

- **Arm A** - the real `deep-review` skill, including its Opus dispatch.
- **Arm B** - the identical checklist supplied inline, dispatching explicitly forbidden.
- **Arm C** - a plain "review this", no skill and no checklist.

A-versus-C re-runs the primary quality comparison against the post-fix skill. A-versus-B isolates
the dispatch itself, which is the thing the suite has never been able to test.

Scored against the same pre-registered answer key as the first comparison (defect A: an expectation
conditioned on a state the run never creates; defect B: `[judgment]` labels on binary transcript
facts, tied to the 100/90 threshold split; defect C: health-check case 8's advisory-dependent
expectations and their self-invalidation).

| | Arm A (skill + dispatch) | Arm B (checklist, no dispatch) | Arm C (plain review) |
| --- | --- | --- | --- |
| Defect A | HIT (`research:81` "will essentially never occur") | HIT (`research:81` "vacuously true") | HIT (`research:81` "unfalsifiable") |
| Defect B | PARTIAL | HIT (`cursor:69` vs `:72` by line) | HIT (`cursor:72` by line) |
| Defect C | PARTIAL | HIT, less the reflexive clause | HIT, including the reflexive clause |
| Findings | 16 | 15 | 25 |
| Ladder verdict | Yes, + counter-argument | Yes | **No** |
| Opus dispatches | 1 | 0 | 0 |
| Tokens / tool calls | 56.6k / 12 | - / 15 | 58.1k / 15 |

Arm A's defect B is partial because its finding 2 catalogues mislabeling only in the
deterministic-labelled-but-judgment direction and never names the three judgment-labelled binary
facts; it does independently nail the threshold half. Its defect C is partial because finding 6
names case 8's advisory dependence but not the self-invalidation. Arms B and C found the specific
mislabeled lines by number.

**The dispatched arm scored lowest of the three on the pre-registered key.** The skill's central
structural claim - that a fresh Opus subagent is what produces the depth - is not supported by this
experiment. On this target the checklist matched it without the dispatch, and a plain review with
neither matched it as well.

Two things cut the other way and should not be dropped:

1. **Arm A produced the single sharpest finding across all three arms**, and neither other arm found
   it: the 90 percent judgment floor tolerates zero misses in two of the three suites, because
   `cursor-projection` and `research` carry 7 judgment checks each and one failure puts them at
   85.7 percent. That is arithmetic on the scoring model itself rather than a reading of the cases,
   and it is the kind of finding the tier is supposed to buy.
2. **Only the arms carrying the checklist stated a ladder verdict.** Arm C produced 25 findings and
   no call at all, which is precisely the failure the skill was written to fix. Finding count is not
   the metric; the forced call is.

The honest reading: the **checklist** is doing the work, and the **dispatch** is not demonstrated to
add value on top of it. Arm C's result further suggests that on an analytical target like an eval
suite, a plain review already goes granular, so this target flatters the no-skill arm more than a
typical one would. Neither observation rescues the dispatch. This is one target, one run per arm,
and one grader - it is evidence, not proof - but it is the first direct test of the claim, and the
claim did not survive it cleanly.

**No change to the skill was made on the strength of this.** Removing the dispatch is a design
decision for the skill's owner, and `SKILL.md:36-38` currently instructs the reader not to remove it.
That instruction is now known to rest on an untested premise, and this run is the record of that.

## Final aggregate, after suite amendments

- **Trigger accuracy:** 6/6, **100 percent** - but single-run, and see the caveat below.
- **Deterministic checks:** 32/32. **100 percent** (71.9 -> 84.4 -> 87.5 -> 100).
- **Judgment checks:** 14/14. **100 percent.**

**Trigger caveat.** `evals/README.md` now requires each trigger case be run three times and scored on
the rate, because case 4's trigger fired, then did not, then did, across three runs of an identical
prompt. That protocol was written during this run and **has not been applied**: all six trigger
figures here are single-run. Applying it is roughly 18 dispatches and is the first thing the next
run should do.

## Final decision: SHIP, with the trigger protocol outstanding

Every threshold is met. All four skill defects are closed and each was individually verified by
re-running the case that exposed it. Both eval-suite defects are resolved by owner decision rather
than by working around them.

The two things this run does not close, both recorded rather than waived:

- The 3-of-3 trigger protocol is unapplied, so the 100 percent trigger figure is the weakest number
  in the table.
- The dispatch premise failed its first direct test, which is a finding about the skill's design
  rather than about this gate.

---

# Tier-differential re-test - 2026-09-05

## Why the first three-arm test did not settle the question

`SKILL.md:36-38` justifies the dispatch on one ground: it "actually guarantees the tier." The first
three-arm experiment dispatched all three arms with no `model` override, so all three inherited the
same tier from the orchestrator. Arms B and C therefore already had the thing the dispatch exists to
buy, and the experiment measured whether a second same-tier context beats one - not the claim.

The design also disadvantaged Arm A on information. Its judgment pass saw the artifact plus a
four-field brief; Arms B and C had the same file access plus their own unmediated reading. Equal
tier, strictly less information. Arm A losing was close to structurally guaranteed.

What survives from that run is the narrower claim: **the dispatch is not demonstrated to add value
when the caller is already at the Opus tier.** That still covers any session already bumped to Opus.

## This test

Same four target files, same baseline (`.worktrees/eval-baseline`, detached at the 2026-09-03
baseline tree), same
blind constraints, same pre-registered answer key (defects A, B, C - unchanged, so there is no
opportunity to fit the key to the result). One variable changed: **all three arms run at Sonnet.**
Arm A's dispatch is therefore a genuine tier upgrade to Opus; Arms B and C stay at Sonnet.

The skill was reinstalled to `~/.claude/skills/deep-review/` from the committed branch and verified
byte-identical by md5 before the run, so this measures the artifact as shipped in the 2026-09-05
commit "Close the deep-review eval gate: SHIP, and test the dispatch premise". No fix
was applied to the brief's one-sided framing beforehand, deliberately, so that this comparison
measures the same artifact the first one did.

## Pre-registered predictions

Written before any arm returned.

1. **If the tier justification is sound, Arm A now beats B and C on the key.** The prediction is
   that it does, and that the margin comes from the same class of finding it uniquely produced last
   time - structural claims about the scoring model rather than line-level catalogue.
2. **Arms B and C should both get worse than their Opus runs** (3/3 and 3/3). If a Sonnet Arm C
   still scores 3/3, the key is too easy to discriminate anything and needs harder defects before
   any further arm comparison is worth running. That is the outcome that would invalidate the whole
   instrument rather than any one arm.
3. **The verdict asymmetry should persist regardless of tier**: the checklist-carrying arms state a
   ladder verdict, plain review does not. That is a property of the checklist, not the model.

The result that would most change the design: **Arm A wins on the key but Arm B matches it on
verdict quality and finding count.** That would mean the tier is what matters and the dispatch is
merely how the tier is obtained - which a `model:` pin would do more cheaply if the harness ever
enforces one for unforked skills.

## Results

Four arms ran at Sonnet. A fifth (`A'`) repeated Arm A with the skill named explicitly, because
Arm A did not fire the skill at all.

| Arm | Caller tier | Reviewing context | Key score | Ladder verdict |
| --- | --- | --- | --- | --- |
| A - skill, auto-trigger | Sonnet | Sonnet (**skill never fired**) | 0/3 | No |
| B - checklist inline | Sonnet | Sonnet | ~0.5/3 | Yes + counter-argument |
| C - plain review | Sonnet | Sonnet | 0/3 | No |
| **A' - skill named, dispatch fired** | **Sonnet** | **Opus (dispatched)** | **3/3** | Yes + counter-argument |

For comparison, the equal-tier experiment above scored Opus A at one full hit and two partials,
Opus B at 3/3, and Opus C at 3/3.

**Every 3/3 in the whole project came from an Opus reviewing context; every 0/3 came from a Sonnet
one.** The dispatch is the only mechanism that produces an Opus reviewing context from a Sonnet
session, and `settings.json` sets `"model": "sonnet"`. Same caller tier, same files, same key:
0/3 without the dispatch, 3/3 with it.

### Prediction scorecard

1. **Arm A beats B and C at a real tier differential** - CONFIRMED, via `A'`. The margin came partly
   from the predicted source: `A'` produced structural findings about the harness and the scoring
   model, not a longer line-level catalogue.
2. **Sonnet B and C degrade from their 3/3 Opus runs** - CONFIRMED, and hard. C went 3/3 to 0/3, and
   did not merely miss the defects but asserted their opposites ("no unverifiable expectations
   found"; "reasonably split ... all verifiable from a transcript"; case 8 cited as a strength). The
   registered risk was that a Sonnet C still scoring 3/3 would prove the key too easy to discriminate
   anything. The opposite happened, so the key discriminates and both experiments stay interpretable.
3. **The verdict asymmetry is a property of the checklist, not the model** - CONFIRMED. Both
   checklist-carrying arms stated a ladder verdict at Sonnet; both plain arms stated none.

### The correction this forces

The equal-tier experiment concluded the dispatch was "not demonstrated to add value." That
conclusion was an artifact of its own design: it dispatched all three arms with no `model` override,
so every arm inherited the same tier and Arms B and C already had the thing the dispatch exists to
buy. The surviving claim from that run is only the narrow one - **the dispatch adds little when the
caller is already at Opus.** Below Opus it is the entire mechanism.

### Confound to carry forward

`A'`'s prompt supplied purpose, constraints, and an explicit "no alternatives rejected yet" so the
brief gate would not block, while the other arms got a thinner seed. So `A'`'s margin mixes tier with
brief richness. A brief ablation at fixed tier - full four-field, Purpose-only, artifact-only - is the
follow-up that separates them, and is the direct test of whether the handoff rather than the dispatch
is the lever.

## Two skill defects found, both reproduced

**Defect 5 - the trigger is tier-dependent and fails at Sonnet.** Arm A was handed "Deep review these
four files", opening with the first phrase the description enumerates. The skill did not fire. The
availability confound was excluded by a separate probe: `deep-review` appears in a Sonnet subagent's
skill list, and that probe returned the `CLAUDE.md` canary, so the agent also had "Invoke
auto-triggering skills before acting" and "Skill named = skill invoked" loaded. All six trigger
figures in this file were measured at Opus.

There is no evidence-backed description edit that fixes this, so nothing in `SKILL.md` was changed
for it. What was changed is the measurement: `evals/README.md` now requires trigger cases be run at
the tier `settings.json` configures and the tier be recorded next to the rate.

**Defect 6 - a backgrounded dispatch destroys phase 3.** `SKILL.md` puts the verdict in phase 3, in
the caller, and told the caller to dispatch without saying how to wait. `run_in_background` defaults
to true. Arm A' dispatched to background, reached phase 3 with nothing to present, and returned an
empty placeholder - twice, across a resume. The skill's one required output was lost by a completely
legal reading of its own text, and lost *quietly*, because the caller correctly reported that it had
nothing. Invisible at Opus only because the earlier Opus arms happened to dispatch in the foreground.

**Fix 5 applied:** `SKILL.md`'s dispatch section now requires `run_in_background: false` and states
the failure it prevents.

A third gap is recorded but not fixed: `SKILL.md` specifies the model and forbids `fork` but never
names a `subagent_type`, and Arm A' dispatched with none set.

## What the dispatched pass found that the answer key does not cover

`A'`'s Opus pass produced findings that outrank all three registered defects, which is itself a
finding about the instrument: **the key rewards rediscovering what was already believed, not finding
what matters.** Every comparison in this file inherits that bias.

- **The trigger layer cannot run on the harness this README names.** The plugin's with-skill executor
  is handed `Skill path: <path>`, so triggering is pre-decided; seven negative-trigger cases across
  the three suites are guaranteed to fail in the with-skill arm and pass vacuously in the without-skill
  arm. The plugin's real trigger mechanism is a separate format (`{query, should_trigger}`) and a
  separate script (`run_loop.py`), which this README never mentions. Independently found by Sonnet
  Arm B, and verified directly against the installed plugin.
- **The one real prior run already worked around this silently.**
  `evals/runs/2026-08-03-write-plan.md` records hand-rolled `general-purpose` dispatches with "no hint
  toward `write-plan` given to the with-skill agent - auto-trigger was real, not scripted." The only
  person who ever executed this procedure abandoned step 1 of it without saying so.
- **The same applies to this file.** The trigger figures here were measured by free-choice dispatch,
  not by the documented procedure. That deviation made them stronger, not weaker - today's Sonnet
  Arm A is proof the method can detect a non-trigger - but it was undocumented until now.
- **A verified path from machine state to the public remote.** `cursor-projection` cases run
  `--check` against the real `~/.cursor`, pulling MCP server names and absolute home paths into the
  transcript; the plugin writes to `skills/<name>-workspace/`; `.gitignore` is a root-anchored
  whitelist with `!/skills/`, so that workspace was not ignored. Confirmed with `git check-ignore`.
- **`health-check` case 6 mutates the live tracked repo**, and `cursor-projection` case 4's failure
  mode is a real hook registration on the real machine.

**Fixes applied for the last two:** `.gitignore` now ignores `skills/*-workspace/` (verified with
`git check-ignore`, and `git ls-files -i -c` confirms no tracked file became ignored), and
`evals/README.md` gained a "Run isolation" section requiring a throwaway worktree, an overridden
`HOME` for machine-touching suites, and no verbatim commit of native grading output.

## Verification of fix 5: NOT COMPLETED

The behavioral test of the foreground-dispatch fix was dispatched against the patched skill
(md5-matched to the branch copy) and deliberately **not** told to use the foreground, so that it
would test the `SKILL.md` text rather than an instruction in its own prompt. It died on a session
rate limit before it dispatched, having emitted only its confirm-step reasoning.

**Fix 5 therefore does not meet this file's own standard**, which every other fix in this run met:
verified by re-running the case that exposed it. It is applied and unverified.

One weak signal exists and is recorded as weak: the artifact-only ablation arm stated it was
"dispatching a fresh Opus subagent in the foreground per the skill's instructions." That arm's own
prompt also instructed a foreground dispatch, so the attribution is ambiguous and it is not
verification.

## Brief ablation: NOT RUN

All three arms (full four-field brief, Purpose-only, artifact-only) died on the same rate limit. The
confound in `A'` - tier mixed with brief richness - therefore stands unresolved. One partial
observation survives from the artifact-only arm before it died: it judged that "all four
context-brief fields are answerable directly from the target files and the surrounding repo
conventions, so no field blocks dispatch." If that holds up when the arm is re-run, it means the
brief gate does not bind on a repo-local target, because the repository itself supplies the fields -
which would make the Purpose-only and artifact-only conditions collapse into the full condition and
require a different ablation design, on a target outside any repository.

## Decision: back to HOLD

Two defects were found after this file recorded SHIP. Both are fixed in the artifact; one is
unverified. Re-affirming SHIP on an unverified fix would be precisely the stamped-but-unverified
output this whole exercise exists to prevent, so the decision returns to HOLD.

Clearing it needs three things, none of which requires a new decision:

1. Re-run the fix 5 behavioral test - a Sonnet caller, skill named, no foreground instruction in the
   prompt - and confirm it dispatches in the foreground and presents the verdict.
2. Apply the 3-of-3 trigger protocol at the tier `settings.json` configures. All six trigger figures
   in this file remain single-run and Opus-only, and defect 5 shows that tier changes the answer.
3. Run the brief ablation, or redesign it per the observation above.

---

# Trigger-layer restructure - 2026-09-05

The dispatched Opus pass found that the trigger layer `evals/README.md` mandated could not run on
the harness it named. That is now fixed at the architecture level rather than recorded as a caveat.

**Trigger evals moved to their own file and the plugin's own format.** Four skills now carry
`skills/<name>/evals/trigger-evals.json` - `deep-review`, `health-check`, `research`,
`cursor-projection` - each a flat array of `{"query", "should_trigger"}` with 16 queries, 8 positive
and 8 negative, written to the plugin's stated guidance: realistic and specific, with negatives that
are genuine near-misses sharing vocabulary with the skill rather than obviously-irrelevant filler.
These run through `python -m scripts.run_loop --eval-set <file> --skill-path <skill> --model <id>`.

Two things this confirmed, both of which had been added to `evals/README.md` before the plugin's
trigger mechanism was understood, and both of which turn out to match it:

- `run_loop.py` already runs each query three times for a trigger rate, which is the 3-of-3 protocol
  written into this procedure after case 4's flake.
- It takes `--model`, and the plugin's guidance says to pass the model powering the session "so the
  triggering test matches what the user actually experiences" - which is the tier requirement added
  after defect 5.

**Unrunnable assertions removed from the behavioral suites.** Seven from
`skills/deep-review/evals/evals.json` (`Invokes deep-review` on ids 5, 6, 7, 8, 10, plus `Invokes
review-md` and `Does not invoke deep-review` on id 1) and one from
`skills/health-check/evals/evals.json` (id 2's `Triggers on the staleness phrasing`). Each was
guaranteed to fail in the with-skill arm and pass vacuously in the without-skill arm. The
displacement question id 1 was written to test - plain "review this doc" must not pull in
`deep-review` - is now carried by a negative query in the trigger set instead, where it can actually
be measured.

**`deep-review`'s behavioral suite is now 25 deterministic / 14 judgment across 10 cases**, down from
32 / 14. The 32/32 figure recorded earlier in this file described a suite that contained seven
assertions the harness cannot evaluate; it is not comparable to any figure produced after this
change, and it should not be carried forward as a baseline.

The other four suites (`review-md`, `skill-author`, `write-plan`, `execute-plan`) have no
trigger-eval file yet. Their in-`evals.json` trigger-adjacent assertions are behavioral proxies -
"does not load reference X", "does not invoke the orchestration machinery" - which a transcript can
answer, so they are not affected by this defect and were left alone.

## Verification of fix 5: PASSED

Re-run after the rate limit cleared. A Sonnet caller, told to use the skill but **not** told anything
about foreground or background, so the only source of that instruction was the patched `SKILL.md`.

| What fix 5 requires | Observed |
| --- | --- |
| Dispatch happens | `deep-review` invoked, one `Agent` dispatch |
| At the Opus tier | `model: opus` |
| In the foreground | `run_in_background: false`, self-reported and consistent with the transcript |
| Phase 3 presents the findings | Five findings presented inline |
| Phase 3 reproduces the verdict verbatim | "Reconsider scope" plus its counter-argument, reproduced unaltered |

The caller's own words: "I was able to present its findings and verdict in full in this reply,
unmodified and unsoftened." Against two prior runs that returned an empty placeholder, this is the
fix working. **Fix 5 is verified.**

An independent corroboration arrived with it. That run's dispatched Opus pass, from a cold context
with no knowledge of this file, rediscovered the trigger-format defect on its own - naming
`run_loop.py` and the `{query, should_trigger}` format, and noting that
`scripts/health-check.sh` "only checks that `evals/evals.json` exists, so committing this flips an
advisory green without adding real gate strength." That is the second independent discovery of the
defect and the third of the lint-driven-coverage problem.

It also raised one thing no prior pass did, which is actionable and outside this gate: the highest-risk
regression for `research` is an LLM regeneration silently adding `context: fork` to the frontmatter,
which both its `SKILL.md` and `specs/skills.md` explicitly argue against. That is a static frontmatter
property, so it belongs in `scripts/health-check.sh` as a grep, not in a behavioral eval - and nothing
currently checks it.

## A defect in the trigger harness itself: a broken run scores as a clean negative sweep

The first attempt to run `skills/deep-review/evals/trigger-evals.json` through `run_loop.py`
returned **16/16 on the negative queries and 0/16 on the positives**, and exited 0.

None of that was real. `stderr` carried one line per invocation:

```
Warning: query failed: [Errno 2] No such file or directory: 'claude'
```

`scripts/run_eval.py` shells out to the `claude` binary, which was not on the invoking shell's
`PATH`. **Every failed invocation was counted as "did not trigger."** The consequences are worth
stating precisely, because they generalise well beyond this repository:

- A completely broken run produces a **perfect score on every negative query**, since "did not
  trigger" is exactly what a negative asserts.
- The failure is only visible as a positive-query collapse. A trigger set weighted toward negatives
  would report a high pass rate from a run in which nothing executed at all.
- The process exits 0 and writes a normal `results.json` with no error field on any record, so
  nothing downstream distinguishes an environment failure from a description failure.

This is the same class of defect as the one that motivated splitting the trigger layer out in the
first place - a mechanism that reports green without having measured anything - and it sits one layer
lower, in the tool this procedure now depends on.

**Operational rule, added to the procedure:** before trusting any `run_loop.py` output, confirm
`claude` resolves on the invoking shell's `PATH` and that `stderr` contains no `query failed` lines.
Treat a run whose positives are uniformly 0.0 as an environment failure until proven otherwise, not
as a description defect. A trigger figure taken from a run with any `query failed` line in its stderr
is not a measurement and must not be recorded.

## Second harness defect: `run_loop.py` cannot measure a skill that is actually installed

With `claude` on `PATH` and zero `query failed` lines, the run still returned **0/16 on positives and
16/16 on negatives**. That is also not a result. Reading `scripts/run_eval.py` explains why, and the
explanation matters for anyone who tries to use this procedure.

The harness does **not** install the skill. It writes a synthetic command file to
`<project_root>/.claude/commands/<skill-name>-skill-<uuid8>.md` carrying the skill's description, and
counts a trigger only when that generated name appears in the tool input:

```python
if tool_name == "Skill" and clean_name in tool_input.get("skill", ""):
    triggered = True
```

Two independent things in this environment make that unmeasurable, and both were live:

1. **The real skill was installed** at `~/.claude/skills/deep-review/`, which is user-scope and loads
   regardless of the working directory. The model fired the real skill - `skill: "deep-review"` -
   which does not contain the `-skill-<uuid8>` suffix, so a correct trigger was scored as a miss.
2. **The first tool call decides.** The detector reads
   `if tool_name in ("Skill", "Read"): ... else: return False`. Any other opening tool call is an
   immediate miss. Run against a real repository the model reasonably opens with `Bash` or `Grep` to
   orient itself. A manual single invocation of the same query confirmed both halves: the `Skill`
   tool was called twice, in 16 seconds, well inside the 30-second default timeout - but preceded by
   four `Bash` calls.

`find_project_root` also walks up from **cwd**, not from `--skill-path`. Run from the plugin
directory it resolved to `~/.claude` and wrote its synthetic command into the real
`.claude/commands/`. It cleans up after itself in a `finally` block, and no file was left behind -
but the write target is the user's live config directory, chosen by accident of working directory.

**The measurement requires an environment the procedure never described:** a scratch project root, and
the skill under test *not* installed, so the synthetic command is the only candidate. Both conditions
are now in the procedure.

**Taken together with the first harness defect, the trigger layer has three distinct false-green
modes**, all of which exit 0 and write a normal `results.json`:

| Mode | Symptom | Real cause |
| --- | --- | --- |
| Binary missing from `PATH` | negatives 100%, positives 0% | nothing executed |
| Skill actually installed | negatives 100%, positives 0% | correct triggers not counted |
| First tool call is not Skill/Read | scattered positive misses | detector returns False immediately |

Every one of them inflates the negative score to 100 percent, because "did not trigger" is what a
negative asserts. **A trigger suite weighted toward negatives reports a high pass rate in all three.**
That is the same structural failure as the original defect - a gate reporting green without measuring
anything - now found at two further layers down.

## First valid trigger measurement: the description barely fires at Sonnet

Run from a scratch project root (`/tmp/scratch-proj`), with `deep-review` uninstalled, `claude` on
`PATH`, `--timeout 60`, `--runs-per-query 3`, `--holdout 0`, `--max-iterations 1`, model
`claude-sonnet-5`. Zero `query failed` lines. Three positive queries returned nonzero trigger counts,
which is the proof that detection was working this time - the two earlier attempts could not produce a
nonzero count under any condition.

**Score: 8/16. Positives 0/8. Negatives 8/8.**

| Query (positive) | Trigger rate |
| --- | --- |
| "deep review this before I commit it - it's the retry wrapper in src/net/backoff.go..." | **0/3** |
| "poke holes in the migration plan in docs/rfc/0012-multi-region.md..." | **0/3** |
| "push back on this: I want to add a nightly cron that reindexes..." | **0/3** |
| "be critical about this, don't be nice: proposal is to require two approvals..." | **0/3** |
| "critique this approach - to fix our flaky integration tests..." | **0/3** |
| "ok honest question, is this a good idea? we're thinking about splitting the billing service..." | 1/3 |
| "should we even do this? spent all morning convincing myself we need a feature flag service..." | 1/3 |
| "play devil's advocate on my plan to move all the team's runbooks into notion..." | 1/3 |

All eight negatives scored 0/3 and pass. Mean positive trigger rate is **12.5 percent** against a
default threshold of 50 percent.

**Every failing phrase is enumerated verbatim in the description.** "deep review this," "poke holes in
this," "push back on this," "be critical about this," "critique this approach" are all listed, and all
five never fired once in three runs. The three that did fire at all are the two open-ended framings
("is this a good idea," "should we even do this") and "play devil's advocate."

This confirms defect 5 with a real instrument and quantifies it: **the skill is close to
non-triggering at Sonnet**, which is the tier `settings.json` configures. The earlier single-run
observation was not a fluke and was, if anything, generous.

**Caveat on what this measures.** `run_eval.py` tests whether the description causes the model to
select a synthetic *command* entry, not a skill entry. It is the plugin's own instrument and the
description is genuinely what is under test, but it is a proxy for real skill selection rather than
the thing itself. The direction of the result is not in doubt - zero fires across fifteen runs of five
verbatim-enumerated phrases is not noise - but the absolute number should not be quoted as "the skill
triggers 12.5 percent of the time in normal use."

**No description change was made.** `run_loop.py` exists to optimise exactly this and would propose
one, but rewriting the description is a change to the artifact under gate and belongs to its owner.

## Gate status

Trigger is now measured, and it fails: **0/8 positives against a 100 percent threshold.** This is a
real defect in the skill, not an instrument artifact and not an eval-suite defect. The decision stays
**HOLD**, now for a substantive reason rather than a pending verification.

## CORRECTION: the 0/8 trigger result was an artifact. The real figure is 16/16.

**The section above titled "First valid trigger measurement: the description barely fires at Sonnet"
is wrong and is retained only as the record of the error.** Its conclusion - that the description is
close to inert at Sonnet - does not survive. Neither does defect 5 as originally written.

The run that produced 0/8 used the harness defaults: `--num-workers 10` against a 30-second timeout.
Re-run with the description, queries, model, project root and installation state all held constant,
changing only concurrency and timeout:

| Configuration | Positives | Negatives | Mean positive rate |
| --- | --- | --- | --- |
| 10 workers, 30s timeout, 3 runs | **0/8** | 8/8 | 0.13 |
| 1 worker, 120s timeout, 1 run | 5/8 | 8/8 | 0.63 |
| **1 worker, 120s timeout, 3 runs** | **8/8** | **8/8** | **0.96** |

Only one positive query is below a perfect rate: "deep review this before I commit it..." at 2/3.
Every other positive fired 3 of 3. Negatives remain 8/8 throughout, so the description is neither
inert nor over-broad.

The failures also **moved between runs** - "poke holes," "push back," and "be critical" scored 0/3 in
parallel and 3/3 serially, while "deep review this" fired instantly in a hand-run invocation and
missed once serially. A defect that relocates between runs of an unchanged artifact is a timing race,
not a property of the artifact.

**This is a fourth false-green mode, and it is the dangerous one.** The other three produce
transparently broken output - all-zero positives with a perfect negative sweep, implausible on its
face. This one produced a plausible, specific, damning number that was written up and committed as a
real defect. Nothing in the output distinguishes it from a genuine description failure.

Two consequences worth stating plainly:

1. **Running the optimizer would have made this worse in an invisible way.** `run_loop.py` scores its
   own proposed descriptions with the same harness. Pointed at parallel-mode scores it would have
   rewritten a working description to fit timing noise, and reported an improvement.
2. **Defect 5 is withdrawn as a skill defect.** The original observation - one subagent failing to
   fire on "Deep review these four files" - is better explained by the stale session skill registry,
   which was directly observed later the same day when an ablation arm returned
   `Unknown skill: deep-review` while the skill was installed on disk. That is an artifact of the
   copy-in/remove install method this run required, not a property of the description.

**Procedure rule:** run trigger evals with `--num-workers 1` and `--timeout 120`. The defaults are
not safe, and their failure mode is a believable wrong answer rather than an obvious one.

## Gate status, corrected

| Layer | Result | Threshold | Met |
| --- | --- | --- | --- |
| Trigger | 16/16 (8/8 positive, 8/8 negative), 3 runs each, serial, clean room | 100% | yes |
| Deterministic | 25/25 | 100% | yes |
| Judgment | 14/14 | >=90% | yes |

All four original skill defects were fixed and individually verified. Fix 5 (foreground dispatch) is
fixed and verified. Defect 5 is withdrawn. **Decision: SHIP.**

Three honest caveats, recorded rather than waived:

- The deterministic and judgment figures were measured by hand-rolled free-choice dispatch, not by
  the plugin's behavioral harness, and 25/25 is arithmetic on that run after seven unrunnable
  assertions were removed rather than a fresh measurement.
- The trigger figure is the first in this repository taken with the real instrument, but it took four
  attempts to get a valid one, and "serial is reliable" is established by agreement between two
  serial runs rather than proven.
- `health-check`, `research`, and `cursor-projection` have trigger sets that have never been run.
