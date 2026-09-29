---
created: 2026-09-29
updated: 2026-09-29
---

# `review-md` 2026-09-29: v1 behavioral baseline

**Decision: BASELINE.** Deterministic 91% (50/55) against the 100 percent floor;
judgment 89% (8/9) against the 90 percent floor. This run records the current skill
before the v2 rebuild and gates nothing by itself.

## Harness and environment

- Harness: `2.1.283 (Claude Code)`.
- Model for executors and graders: Sonnet via the `sonnet` alias, dispatched as `general-purpose`
  subagents.
- Skill under test: `skills/review-md/` at commit `d404556`, copied without its `evals/`
  directory so executors could not read the expectations.
- Runs: 12 cases, 3 runs each, each expectation scored by majority (passes in at least 2 of 3).
- Trigger layer: not run; review-md has no `trigger-evals.json`.
- Prior baseline: none - first recorded run.
- Workspace: a gitignored scratch directory, not committed.

## Results

| Kind | Passed | Total | Rate | Threshold | Verdict |
| --- | --- | --- | --- | --- | --- |
| Deterministic | 50 | 55 | 91% | 100% | fail |
| Judgment | 8 | 9 | 89% | >= 90% | fail |

## Per-case results

| Eval | Task | Deterministic | Judgment | Failing expectations (majority) |
| --- | --- | --- | --- | --- |
| 1 | Review this doc (report-only) | 6/6 | 1/1 | none |
| 2 | Review and fix this doc | 2/3 | 0/1 | #2 (judgment): reports link findings as lower-confidence rather than silently resolving them; #3 (deterministic): presents unresolved findings as a multi-select question |
| 3 | Fix one named typo only | 4/4 | - | none |
| 4 | Review a non-.md config file | 3/4 | - | #4 (deterministic): stops without acting rather than a best-effort prose review |
| 5 | Proofread, asking about broken links | 2/3 | 1/1 | #4 (deterministic): ends with a summary separating confirmed-broken from inconclusive links |
| 6 | Re-review with existing tracking (intentional/deferred) | 4/4 | 1/1 | none |
| 7 | Full fresh review, clearing tracking | 5/5 | - | none |
| 8 | Review a PR/code change (should not trigger) | 2/2 | 1/1 | none |
| 9 | Review a directory of docs (multi-document) | 8/9 | 2/2 | #11 (deterministic): ends with a summary separating per-document from across-the-set findings |
| 10 | Review two named docs (ask which mode) | 3/3 | 1/1 | none |
| 11 | Review two docs together and fix (holistic signal) | 5/5 | 1/1 | none |
| 12 | Re-review a doc set with existing tracking | 6/7 | - | #6 (deterministic): records a newly settled cross-document decision under the set-level key |

## Flaky expectations (passed 2 of 3)

- eval-1 #7: "Ends with a summary of what was checked and found"
- eval-2 #4: "Ends with a summary distinguishing what was changed from what was queued for the
  user to choose from"
- eval-7 #5: "Ends with a summary noting this was a full/fresh pass"
- eval-9 #3: "Dispatches one Sonnet subagent per document concurrently, then one further Sonnet
  subagent for the cross-document pass"
- eval-11 #5: "Presents the remaining unresolved findings as a multi-select question"
- eval-12 #7: "Ends with a summary reflecting what was skipped due to prior tracking, split into
  per-document and across-the-set findings"

## Grader notes on the eval set

- eval-1: Expectation 4 names "httpstat.us/403" but the fixture uses httpbin.org/status/403;
  harmless drift since only one 403 link exists, but the expectation text should be corrected so
  it doesn't look like a missed link on a future read.
- eval-1: Expectation 1 is nearly trivial, since the task input already names the target file, so
  confirming it is a .md file has little chance of failing.
- eval-1: Expectations 3 and 4 both hinge on a single bundled sentence in response.md that lumps
  the dead-link and 403-link findings together rather than addressing each individually; the
  link-recheck-hook.sh run reported no output, so the dead/inconclusive determination rests on the
  agent's reading of the doc's own inline claims rather than a verified live check.
- eval-1: Expectation 7's "ends with a summary" wording is in tension with the skill's own
  no-live-user protocol, which requires ending with the Question-for-the-user block instead; this
  run put the summary earlier in the body, a genuine ordering deviation from the skill's own
  "finish with a summary" instruction, so a stricter grader could fail this on the literal "ends
  with" wording.
- eval-2: The judgment expectation assumes the correct behavior is to flag the two link findings
  as lower-confidence items; this run instead confidently classified them as intentional-by-design
  and closed them out, arguably the more accurate read of the fixture's own prose but not a match
  for the expectation's literal wording, so it fails as written.
- eval-2: Expectations 3 and 4 are not independently informative: because expectation 2 failed
  (the agent resolved both link findings itself instead of queuing them), there were no unresolved
  findings left to present as a multi-select question, so expectation 3 fails for the same
  underlying reason, and expectation 4's summary passes on format only since the "queued" side is
  trivially empty.
- eval-2: Expectation 1 is nearly impossible to fail given the prompt says "fix" and the typo is
  unambiguous; it mainly checks that the diff exists.
- eval-3: Expectation 3 (no multi-select question) is only weakly tested here: the run never
  found any unrelated findings to surface, so it cannot distinguish correct suppression from
  having nothing to ask about.
- eval-3: Expectation 4 ("ends with a summary confirming the one requested change") is loosely
  worded: the summary of the fix is actually response.md's opening line, not its closing line,
  though the response does close by reconfirming no other issues were found; worth tightening the
  expectation to specify where the confirmation must appear if position matters.
- eval-4: Expectations 1-3 are effectively guaranteed once the .json extension is detected via the
  skill's own stated gate, since that same gate text explicitly licenses the best-effort fallback
  review that expectation 4 forbids; the skill's instructions and expectation 4 pull in opposite
  directions, so future runs will likely split on this tension rather than on genuinely different
  behavior.
- eval-4: Expectation 4 may be testing a stricter behavior (decline entirely) than the skill text
  mandates, since the skill's own instruction is to fall through to whatever other skill or normal
  conduct applies for non-.md targets, and normal code-review conduct plausibly includes giving
  findings; worth confirming whether "stops without acting" covers the review-md-specific action
  only or all action on the file.
- eval-4: In practice the executor did stop the skill's own review workflow but still gave a full
  prose consistency finding as a direct answer to the user's question, explicitly outside the
  skill; defensible, but graders should note it declined only the skill-driven review path, not
  all action.
- eval-5: Expectation 2 names "httpstat.us/403" but the fixture's actual link is
  "httpbin.org/status/403"; a labeling issue in the eval, not in the run, since the run correctly
  handled the actual fixture link.
- eval-5: Expectation 4's "ends with" wording is ambiguous: this run produces a clear
  broken-vs-inconclusive summary paragraph, just not as the literal final content, since a
  Question-for-the-user section follows it; if the intent is only that such a summary exists
  somewhere in the report, the expectation should drop "ends with" so it does not fail runs that
  otherwise satisfy the substantive requirement.
- eval-6: Expectation 4 is close to trivially satisfied in this fixture, since the Old runbook
  link is an obvious, easy-to-spot untracked finding that any competent reviewer would surface; a
  more discriminating test would use a subtler undocumented issue.
- eval-6: Expectation 5 ("ends with a summary") is satisfied loosely: the skip summary sits
  mid-document, followed by a "No other findings" line and a Question-for-the-user section, rather
  than being the literal final paragraph, so a stricter reading of "ends with" could fail it.
- eval-7: Expectation 2 (no effect on other sections) is trivially satisfied here across all three
  runs: the seeded review-tracking.md for this eval contains only the sample-doc.md section, so
  there is no other section for the run to disturb, and no run could fail this check under this
  fixture setup.
- eval-8: The project directory for this eval was placed empty (no PR/diff fixture at all,
  confirmed identical across all three runs), so expectations 1 and 2 are only weakly diagnostic:
  even a run that ignored the skill entirely would produce no checklist output and no
  review-tracking.md simply because there was nothing to review. Expectation 3 is the only one
  that actually exercises the intended judgment call and is well supported by the transcript's
  explicit reasoning.
- eval-9: Expectations 9 and 11 are nearly redundant, both graded by the same two headed sections
  in response.md; a single expectation about separation would suffice.
- eval-9: Expectation 10 (no edits applied) is close to trivially satisfied, since the task prompt
  never used "fix"/"refine" language, so any implementation defaulting to report-only would pass
  it regardless of whether its fix-policy logic is sound. Expectation 3's "concurrently" clause is
  meaningful and caught a real gap: the run dispatched all three subagents sequentially rather
  than batching the two per-document reviews into one concurrent dispatch.
- eval-9: Expectation 11 ("ends with a summary") is graded strictly on the literal "ends with,"
  which the response does not satisfy because it closes with Tracking and the
  Question-for-the-user block instead of a recap summary; worth clarifying whether the intended
  check is section-separation (already covered by expectation 9) or a literal closing summary
  block.
- eval-10: The four expectations overlap heavily, since all point to the same single observable
  fact (the run stopped at the clarification question with zero dispatch or file changes), so a
  run that fails one would almost certainly fail all four together rather than differentiating
  failure modes. Expectation 2 is nearly guaranteed to pass whenever expectation 1 passes, since
  the skill's only two defined modes are independent vs. holistic. Expectations 1 and 4 overlap
  similarly (both hinge on "no dispatch before the question"); consider merging them or making
  expectation 4 test a distinct failure mode, such as synthesis dispatched despite a pending
  question.
- eval-11: The last expectation ("ends with a summary") is satisfied by response.md's structure,
  but the response does not literally end with that summary since it is followed by the
  interactive question section; graded charitably as the intended final substantive content
  block.
- eval-11: The multi-select expectation and the executor's actual behavior (three separate
  single-select questions) diverge sharply; worth checking whether the skill's guidance on
  presenting a batch of unresolved findings is ambiguous about single- vs multi-select framing,
  since a reasonable design (one question per independent decision) was chosen instead.
- eval-11: Expectation 4 ("states which files were changed and why" for any cross-document fix) is
  trivially satisfied here because the run applied zero cross-document fixes (only a
  single-document typo fix), so it never exercised the behavior the expectation is meant to check.
- eval-12: Expectation 6 (recording newly settled cross-document decisions under the set-level
  key) cannot be positively verified in a run that stops at the question-and-findings stage with
  no reply received, across all three runs; nothing was ever settled, so there is no behavior to
  observe either way, and the expectation is effectively untestable unless the eval scenario
  supplies a reply that settles something.
- eval-12: Expectation 7 is worded as "ends with a summary" but the run's tracked/skipped-items
  recap is correct in content and grouping, just placed near the top or split across sections
  rather than at the end; a stricter or looser reading of "ends with" would flip this result.

## Caveats

- No live user: where the skill would ask a question, the executor wrote the question into its
  response and stopped; question-presentation expectations were graded from that written question.
- Several fixtures describe their own purpose in prose (for example that two documents
  "deliberately disagree"), which can cue the executor. New fixtures should not.
- Evals 4 and 8 test the skill's exit path with the skill path pre-supplied; they cannot test
  whether the description would fire.
