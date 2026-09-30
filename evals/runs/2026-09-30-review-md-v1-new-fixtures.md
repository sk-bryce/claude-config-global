---
created: 2026-09-30
updated: 2026-09-30
---

# `review-md` 2026-09-30: v1 on the new fixtures

**Decision: BASELINE.** Deterministic 98% (56/57) against the 100 percent floor; judgment 86%
(44/51) against the 90 percent floor. This run gates nothing by itself.

## Harness and environment

- Harness: Claude Code was upgraded partway through the batch. 56 of the 72 runs recorded
  `2.1.280`. The other 16 recorded `2.1.283`: every run of cases 23-26, plus the rebuilt runs e1
  r3, e6 r2, e8 r3, and e17 r3. The trigger run used `2.1.283`.
- Executors: Sonnet via `general-purpose` subagents. Haiku for none - v1 does not run case 12
  (`tier-guard`), the only case that dispatches at Haiku.
- Graders: Opus. Collators: Sonnet.
- Skill under test: `skills/review-md/` at commit `c1d06ef244db7480393c80ea612f6eef2016226a` (the
  manifest's `repo_head`), SKILL.md sha256
  `4f411ae6df152ae761d540a8482acacc1072e50fd7f294ebbdc31893e78c9bc1`.
- Scripts:
  - `md-checks.sh`: `29c8dc1642ca8cce8b530ced186f85bcfd1f7c52a569b34862abf8eccc804551`
  - `link-recheck-hook.sh`: `11b271b428b7ca67337ceb8713f414fe043a9e773346e1462be406664c52164a`
  - `md-claims.sh`: `1d00fdc39205bd884ba842efb1225a8f57c4e709f49fdeb17fcfe46c113da347`
- Fixture set: `skills/review-md-v2/evals/` at the same commit
  (`c1d06ef244db7480393c80ea612f6eef2016226a`).
- Runs: 24 cases (1-11, 14-26; cases 12, 13, 27 not run), 3 runs each, each expectation scored by
  majority (passes in at least 2 of 3).
- Case 19 (`tools`) ran.
- Workspace: `<scratch>`.

## Pre-registration

A fixture on which v1 scores full marks cannot show that v2 is better (D38). Such a fixture stays
for regression and is left out of criterion 4. The fixture set, the grading rubric, and the pass
criteria in specs/drafts/review-md-v2.md are frozen from the first v2 run.

Cases on which v1 scores full marks (every expectation passes by majority): 3 (`named-fix`), 4
(`non-markdown`), 5 (`mixed-dir`), 6 (`links`), 7 (`tracking`), 8 (`fresh`), 9 (`directory`), 11
(`set-rereview`), 14 (`verification`), 15 (`spec-drift`), 16 (`post-fix`), 17 (`ascii-cfg`), 18
(`pick-question`), 19 (`tools`), 20 (`agent-config`), 21 (`nongit`), 22 (`deep-review-caller`), 23
(`clean`).

## Results

| Kind | Passed | Total | Rate | Threshold | Verdict |
| --- | --- | --- | --- | --- | --- |
| Deterministic | 56 | 57 | 98% | 100% | fail |
| Judgment | 44 | 51 | 86.27% | >= 90% | fail |

## Per-case results

| Eval | Task | Deterministic | Judgment | Failing expectations (majority) |
| --- | --- | --- | --- | --- |
| 1 | review-report | 3/3 | 5/6 | em dash on docs/deploy.md line 6 flagged despite no house typography rule |
| 2 | review-fix | 2/2 | 3/4 | no finding on docs/config.md line 9 (ledgerd 2.2 vs. Version 2.4.1) |
| 3 | named-fix | 3/3 | 1/1 | none |
| 4 | non-markdown | 3/3 | 1/1 | none |
| 5 | mixed-dir | 2/2 | 2/2 | none |
| 6 | links | 3/3 | 4/4 | none |
| 7 | tracking | 4/4 | 2/2 | none |
| 8 | fresh | 1/1 | 1/1 | none |
| 9 | directory | 3/3 | 4/4 | none |
| 10 | cross-fix | 2/3 | 2/2 | response.md has no Question for the user heading |
| 11 | set-rereview | 1/1 | 3/3 | none |
| 14 | verification | 3/3 | 1/1 | none |
| 15 | spec-drift | 3/3 | 2/2 | none |
| 16 | post-fix | 3/3 | 1/1 | none |
| 17 | ascii-cfg | 2/2 | 3/3 | none |
| 18 | pick-question | 3/3 | 1/1 | none |
| 19 | tools | 3/3 | 1/1 | none |
| 20 | agent-config | 2/2 | 1/1 | none |
| 21 | nongit | 2/2 | 1/1 | none |
| 22 | deep-review-caller | 3/3 | 1/1 | none |
| 23 | clean | 1/1 | 1/1 | none |
| 24 | fit-stated | 2/2 | 0/1 | no finding that docs/install.md mostly covers cloning/building/running/testing rather than fresh-host install |
| 25 | fit-none | 0/0 | 0/1 | no finding that docs/install.md mostly covers cloning/building/running/testing, with only its last section installing from the release archive |
| 26 | split | 2/2 | 3/6 | no finding on handbook.md line 20 (port 8080 vs. 9170); no finding on line 59 (5 retries vs. `DEFAULT_MAX_RETRIES = 3`); no finding on line 73 (undocumented `--wait` flag) |

## Planted defects

Missed by majority: 8 of 49 (`FIT-1`, `FIT-2`, `LRG-1`, `LRG-2`, `LRG-3`, `SVC-10`, `SVC-14`,
`SVC-8`).

Found by majority (41):

| Id | Case | File(s) | Severity |
| --- | --- | --- | --- |
| SVC-1 | 1 | docs/deploy.md | Major |
| SVC-2 | 1 | docs/deploy.md | Major |
| SVC-3 | 1 | docs/deploy.md | Major |
| SVC-4 | 1 | docs/deploy.md | Minor |
| SVC-5 | 9 | docs/ (deploy.md, operations.md, config.md, architecture.md, api.md, runbook.md, glossary.md) | Major |
| SVC-6 | 9 | docs/ (as above) | Minor |
| SVC-7 | 9 | docs/ (as above) | Minor |
| SVC-9 | 9 | docs/ (as above) | Minor |
| SVC-11 | 2 | docs/config.md | Major |
| SVC-12 | 2 | docs/config.md | Major |
| SVC-13 | 2 | docs/config.md | Minor |
| SVC-15 | 2 | docs/config.md | Major |
| SVC-16 | 6 | docs/architecture.md | Major |
| SVC-17 | 6 | docs/architecture.md | Minor |
| SVC-18 | 6 | docs/architecture.md | Minor |
| SVC-19 | 6 | docs/architecture.md | Minor |
| SVC-20 | 15 | docs/api.md | Major |
| SVC-21 | 15 | docs/api.md | Major |
| SVC-22 | 14 | docs/runbook.md | Major |
| SVC-23 | 9 | docs/ (as above) | Major |
| SVC-24 | 18 | docs/glossary.md | Minor |
| SVC-25 | 18 | docs/glossary.md | Minor |
| SVC-26 | 18 | docs/glossary.md | Minor |
| SVC-27 | 18 | docs/glossary.md | Minor |
| SVC-28 | 18 | docs/glossary.md | Minor |
| SVC-29 | 18 | docs/glossary.md | Major |
| SVC-30 | 9 | docs/ (as above) | Minor |
| CFG-1 | 17 | docs/guide.md, docs/notes.md | Minor |
| CFG-2 | 17 | docs/guide.md, docs/notes.md | Minor |
| CFG-3 | 17 | docs/guide.md, docs/notes.md | Minor |
| CFG-4 | 17 | docs/guide.md, docs/notes.md | Minor |
| CFG-5 | 17 | docs/guide.md, docs/notes.md | Major |
| CFG-6 | 20 | AGENTS.md | Major |
| CFG-7 | 20 | AGENTS.md | Minor |
| NG-1 | 21 | notes.md | Major |
| MIX-1 | 5 | notes/standup.md, notes/retro.md | Major |
| MIX-2 | 5 | notes/standup.md, notes/retro.md | Minor |
| MIX-3 | 5 | notes/standup.md, notes/retro.md | Major |
| LRG-4 | 26 | docs/handbook.md | Major |
| LRG-5 | 26 | docs/handbook.md | Major |
| LRG-6 | 26 | docs/handbook.md | Minor |

Missed (8):

| Id | Case | File(s) | Severity |
| --- | --- | --- | --- |
| SVC-8 | 9 | docs/ (deploy.md, operations.md, config.md, architecture.md, api.md, runbook.md, glossary.md) | Minor |
| SVC-10 | 9 | docs/ (as above) | Minor |
| SVC-14 | 2 | docs/config.md | Minor |
| FIT-1 | 24 | docs/install.md | Major |
| FIT-2 | 25 | docs/install.md | Major |
| LRG-1 | 26 | docs/handbook.md | Major |
| LRG-2 | 26 | docs/handbook.md | Major |
| LRG-3 | 26 | docs/handbook.md | Major |

Case 9 (`directory`) reviews seven documents at once; the source data ties each defect to that
case as a whole rather than to one file within it, so the file column above lists all seven for
those rows.

## False-positive clusters

| Case | Cluster | FP runs (of 3) |
| --- | --- | --- |
| 1 (review-report) | C1 | 3 |
| 3 (named-fix) | C1 | 3 |
| 5 (mixed-dir) | C7 | 2 |
| 5 (mixed-dir) | C8 | 2 |
| 9 (directory) | C5 | 3 |
| 9 (directory) | C39 | 2 |
| 10 (cross-fix) | C1 | 3 |
| 10 (cross-fix) | C13 | 3 |
| 10 (cross-fix) | C14 | 2 |
| 11 (set-rereview) | C1 | 3 |
| 17 (ascii-cfg) | C5 | 2 |
| 17 (ascii-cfg) | C6 | 2 |
| 17 (ascii-cfg) | C12 | 2 |
| 17 (ascii-cfg) | C13 | 2 |
| 19 (tools) | C5 | 3 |
| 20 (agent-config) | C6 | 2 |
| 23 (clean) | C3 | 3 |
| 23 (clean) | C5 | 2 |
| 23 (clean) | C6 | 3 |
| 23 (clean) | C7 | 2 |
| 24 (fit-stated) | C1 | 3 |
| 24 (fit-stated) | C3 | 2 |
| 24 (fit-stated) | C4 | 2 |
| 26 (split) | C3 | 2 |

## Flaky expectations (passed 2 of 3)

- case 1 (review-report): [judgment] The httpbin.org link on docs/deploy.md line 24 is listed as
  inconclusive, not broken.
- case 5 (mixed-dir): [deterministic:ends_after_question] response.md has a Question for the user
  heading as its last heading, and the executor makes no Agent, Edit, or Write call to a project
  file after its first write of response.md.
- case 6 (links): [judgment] The grafana.ledgerd.invalid body link (line 43) and the
  wiki.ledgerd.invalid link under References (line 57) are both reported as broken.
- case 7 (tracking): [judgment] No finding is raised for 'recieve' on line 17 or 'commit buffer' on
  line 23 of docs/operations.md, which the tracking file marks deferred.
- case 9 (directory): [judgment] Each pass transcript batches independent Read, Grep, and Bash
  lookups into shared tool-call rounds rather than issuing them one at a time.
- case 9 (directory): [judgment] A cross-document finding reports that docs/deploy.md line 30 keeps
  rotated logs 30 days, contradicting docs/operations.md and scripts/rotate.sh (14 days).
- case 11 (set-rereview): [judgment] The first report raises no finding for the pre-change checklist
  repeated in docs/deploy.md and docs/operations.md, which the set-level tracking entry marks
  deferred.
- case 16 (post-fix): [deterministic:no_question] response.md has no Question for the user heading.
- case 18 (pick-question): [judgment] A finding reports that docs/glossary.md line 23 names the
  X-Request-ID header, while src/client.go and specs/api.md use Idempotency-Key.
- case 23 (clean): [judgment] No finding claims that README.md or docs/usage.md contradicts
  bin/tally.sh, and the example path /var/log/app/ in docs/usage.md is not reported as a missing
  file.
- case 24 (fit-stated): [deterministic:no_edits] Every file under project/, outside .git/, is
  identical to the original copy, and no file was added or removed.
- case 24 (fit-stated): [deterministic:ends_after_question] response.md has a Question for the user
  heading as its last heading, and the executor makes no Agent, Edit, or Write call to a project
  file after its first write of response.md.
- case 26 (split): [judgment] The health port 9171 on docs/handbook.md line 21 is not reported as
  wrong.

## Trigger results

Valid: `<scratch>/trigger/v1.log` reports `query failed count: 0` and `VALID`.

- Tier: Sonnet, `claude-sonnet-5`.
- Wall time: 574.71 seconds. Mean per call: 3.36 seconds.
- `claude --version`: `2.1.283 (Claude Code)`.
- Harness: `run_eval.py`, 9 runs per query, threshold 0.88, one worker, 120-second timeout.
- Positives: 7 of 9 at >= 8 of 9. Negatives: 10 of 10 at 0 fires.

| Query | Should trigger | Fires (of 9) | Pass |
| --- | --- | --- | --- |
| review docs/deployment.md, I rewrote the rollback section yesterday and want to know if anything is off | yes | 9 | pass |
| proofread README.md before I push it | yes | 9 | pass |
| review and refine specs/auth-flow.md, it has gotten messy after three rounds of edits | yes | 9 | pass |
| refine docs/onboarding.md so it reads cleanly for a new hire | yes | 9 | pass |
| revise CONTRIBUTING.md so it matches how we actually cut releases now | yes | 0 | fail |
| review everything in docs/runbooks/ and tell me whether those pages still agree with each other | yes | 9 | pass |
| can you review AGENTS.md? I think some of the instructions contradict each other | yes | 8 | pass |
| proofread notes/q3-retro.md and docs/roadmap.md | yes | 9 | pass |
| revise design/overview.md, the storage section is out of date | yes | 0 | fail |
| review this PR before I merge it, mostly the changes in src/billing/ | no | 0 | pass |
| review parse_config in config/loader.py for edge cases | no | 0 | pass |
| review the diff on this branch and flag anything risky | no | 0 | pass |
| review docker-compose.yml for consistency issues | no | 0 | pass |
| deep review specs/auth-flow.md, is this design even a good idea? | no | 0 | pass |
| be critical: is plans/migration.md the right approach at all? | no | 0 | pass |
| audit my skills and tell me which descriptions are too vague | no | 0 | pass |
| improve this prompt for the triage agent in prompts/triage.md | no | 0 | pass |
| plan this: move our docs site from MkDocs to Docusaurus | no | 0 | pass |
| finalize this plan in plans/cache-rewrite.md so it is ready to execute | no | 0 | pass |

## Park and restore

```
v1 parked 2026-09-30T09:24:06Z
v1 restored 2026-09-30T09:35:16Z status clean
```

## Grader notes on the eval set

- Cross-case theme: no expectation anywhere in this set checks that a finding states a severity
  (Blocker/Major/Minor). Every run's report gave no severity labels, so `severity_match` reads
  false throughout the run set, and graders flagged this as an ungraded gap in nearly every case
  rather than as a v1 defect.
- Cross-case theme: no expectation checks trap avoidance directly. TRAP-1 (an em dash on
  docs/deploy.md line 6, flagged under a nonexistent house typography rule) recurred across cases
  1, 3, 9, 10, 11, 19 without failing any expectation designed to catch it; TRAP-3 (`#checks-1`)
  and TRAP-101 (a Kanji character) were left alone correctly but also go unchecked.
- eval-1 (review-report): severity labeling and the em-dash trap (TRAP-1) are the two ungraded
  gaps; one run also found a real, unkeyed defect (30-day vs. 14-day log retention) the answer key
  omits.
- eval-2 (review-fix): no expectation checks that SVC-11/SVC-12 should have been held for the user
  rather than auto-applied; all three runs auto-applied them silently and still passed. SVC-14 (a
  stale `updated:` header) has no expectation and was missed in every run.
- eval-3 (named-fix): the single expectation covers only the requested edit and cannot catch the
  TRAP-1 em-dash false positive, which appeared in all three runs.
- eval-4 (non-markdown): the case has no planted defects, and its one expectation (no script ran)
  is close to automatic once the skill's own YAML/JSON exclusion applies; it does not test whether
  the fallback review avoided TRAP-8 (which it did, correctly, in every run).
- eval-5 (mixed-dir): no expectation covers MIX-2 ("the the") or the false-positive load (roughly
  half the findings in two of three runs were low-value); severity labeling is unchecked.
- eval-6 (links): the httpbin-vs-`.invalid` classification expectation is ambiguous enough that a
  run lumping them together as "inconclusive" can still pass; no expectation covers severity or the
  Map[T] generic trap.
- eval-7 (tracking): both expectations pass for any report that stays quiet about tracked items,
  so they cannot tell a careful re-review from an empty one; a drifted tracking-entry quote
  ("wait for the the drain to finish" vs. the file's actual "wait for the the queue to empty") is
  never graded.
- eval-8 (fresh): the single expectation checks only that the two deferred items resurface; all
  three runs wiped the user's prior `[intentional]` ruling from the tracking file while doing so,
  and no expectation catches that.
- eval-9 (directory): no expectation covers trap handling (TRAP-1 and TRAP-3 both surfaced without
  penalty) or the false-positive rate; one run's "cross-document" expectation failed on citation
  framing rather than on detection, and a real unkeyed defect (config.md's flush_interval mismatch)
  was found but not credited.
- eval-10 (cross-fix): both expectations check only the requested edit; none penalizes reported
  trap findings (TRAP-1, TRAP-3) or a false claim about a missing rollback drain step, and a real,
  unkeyed port mismatch (deploy.md 8080 vs. ledgerd.yaml 8420) was missed by the executor without
  being graded.
- eval-11 (set-rereview): the report-only fix-policy expectation is close to trivially satisfied
  given the task wording; no expectation checks trap handling, and TRAP-1 surfaced in every run
  without effect.
- eval-14 (verification): the single expectation checks recall only; it does not check that
  TRAP-8 (the 0.0.0.0 bind line) stayed unflagged (it did, in every run) or that findings carry
  severities (none did).
- eval-15 (spec-drift): both expectations check detection only, not severity (absent in every run)
  or that no project file was edited on a findings-only request (confirmed empty diffs across all
  three runs).
- eval-16 (post-fix): the single expectation checks only the heading text, not whether the same-file
  link at line 6 was updated to the new anchor (it was, correctly, in every run) or whether
  out-of-scope files were touched (they were not).
- eval-17 (ascii-cfg): the batching expectation is close to trivial since dispatch prompts told
  executors to batch explicitly; no expectation covers CFG-4 (a missing References section, missed
  in one run) or severity labeling.
- eval-18 (pick-question): the single expectation covers only the one Major defect; the five Minor
  defects and severity labeling go ungraded, though all five Minors were found in every run.
- eval-19 (tools): the answer key lists no planted defects even though deploy.md carries several
  real ones (script name, retention, typo); the em-dash trap (TRAP-1) recurred and, in one run, the
  executor passed a false "CLAUDE.md forbids em dashes" premise down to its subagent.
- eval-20 (agent-config): the single expectation covers only CFG-6; CFG-7 recall, false-positive
  count (three in one run, including a factually wrong scrub-check claim), and severity labeling
  are all ungraded.
- eval-21 (nongit): the single expectation checks detection only; three low-value findings (a stale
  example date, a `set -eu` note, a same-day overwrite) and the absence of a stated severity go
  unpenalized.
- eval-22 (deep-review-caller): the key has no planted defects, so trap avoidance in
  architecture.md and how the run handled deep-review's passed-in verdict (DR1, "no finding on
  purpose or fit") are not scored by the one expectation that exists.
- eval-23 (clean): the single expectation checks only two specific false-positive kinds; it cannot
  catch other invented findings on this clean fixture, and one run's compound wording let a soft
  finding fail the whole case while the real trap (`/var/log/app/`) was cleanly avoided.
- eval-24 (fit-stated): one run's response.md was drafted before its review subagent returned,
  built from facts the executor's own subagent brief had already stated, which weakens what the
  expectation measures for that run; severity and false-positive load (four of seven findings weak)
  are otherwise ungraded.
- eval-25 (fit-none): the expectation's wording leaves open whether a Prerequisites-scope finding
  counts as a fit finding, and does not check whether an auto-applied fix made the planted misfit
  worse, which one run's fix did.
- eval-26 (split): the trap expectation (line 21, port 9171) passes even for a run that reports no
  port finding at all, or that hedges rather than flags it outright. Expectations 4 and 5 can be
  satisfied from the doc's own text alone, so only LRG-1 through LRG-3 test whether the review
  actually checked the repository, and every run failed all three because none opened config/,
  src/, or scripts/.
