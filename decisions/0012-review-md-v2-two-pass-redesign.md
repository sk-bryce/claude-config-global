---
created: 2026-09-30
updated: 2026-09-30
---

# 12. review-md v2: two review passes backed by script checks

- Status: Accepted
- Date: 2026-09-30
- Deciders: repository owner
- Supersedes: item 3 of `decisions/0004-document-generation-as-always-on-rule.md` (the synced
  review-md copy)
- Related: `specs/skills.md` (review-md section), `evals/runs/2026-09-29-review-md-v1-baseline.md`,
  `evals/runs/2026-09-30-review-md-v1-new-fixtures.md`, `skills/review-md/SKILL.md`

## Context

v1 review-md checks Markdown for mechanical errors and local, within-document inconsistencies, but
misses the bigger picture and the errors in how parts of a document, or several documents, relate,
and it often has to be run more than once (`specs/skills.md`, review-md section, Purpose).

The 2026-09-29 baseline recorded v1 at commit `d404556`, 12 cases at 3 runs each, majority scoring:
deterministic 50/55 (91%) against a 100 percent floor (fail), judgment 8/9 (89%) against a 90
percent floor (fail). No trigger layer existed yet for review-md.

The 2026-09-30 new-fixtures run recorded v1 at commit `c1d06ef244db7480393c80ea612f6eef2016226a`, 24
cases (1-11, 14-26; cases 12, 13, 27 not run) at 3 runs each: deterministic 56/57 (98%) against the
100 percent floor (fail), judgment 44/51 (86.27%) against the 90 percent floor (fail). Of 49 planted
defects, v1 missed 8 by majority: five Major on the fit-judgment and large-document-split fixtures
(`FIT-1`, `FIT-2`, `LRG-1` to `LRG-3`) and three Minor on the service fixture (`SVC-8` and `SVC-10`
in case 9, `SVC-14` in case 2). The same run's trigger set found 7 of 9 positives at 8 or more fires
of 9 and all 10 negatives at 0 fires. Both baselines record BASELINE, not PASS or FAIL, and gate
nothing by themselves.

## Decision

Adopt the review-md v2 redesign specified in the review-md section of `specs/skills.md`.

- Two review passes, in tiers: a Sonnet proofread pass, one dispatch per document (split by
  top-level section above 60,000 characters), dispatched in waves of at most 5 per message; and an
  Opus judgment pass, one per invocation (or split into groups above the size cap), which covers
  its own check areas over the whole target and verifies every proofread finding as confirmed,
  plausible, or rejected against quoted evidence.
- Three scripts back the passes: `scripts/md-checks.sh` (extended with new categories and a
  typography toggle), `scripts/link-recheck-hook.sh` in a new `--review` mode that checks every
  external link and classifies it broken, inconclusive, or resolving, and a new
  `scripts/md-claims.sh` that extracts and mechanically verifies candidate claims (paths, commands,
  flags, cross-file anchors, dated or versioned statements), passing what it cannot settle to the
  proofread pass as a candidate rather than a verdict.
- Fix policy: the first matching case wins. Named specific fixes apply exactly those and nothing
  else. A prompt containing "refine", "revise", or "fix" applies only high-confidence fixes
  (confirmed status, one unambiguous replacement, no source conflict, not a link removal or a fact
  change, confirmed by the orchestrator or by the judgment pass) and reports the rest. Any other
  prompt reports only, and applies nothing until the user picks.
- Decision tracking moves from review-scope keys to quote-anchored entries in
  `.claude/review-tracking.md`: each entry carries a status (`intentional` or `deferred`), a quote
  of the covered text, and a category, and a finding is suppressed only while its quote still
  matches the file. A stale entry resurfaces its finding and is flagged stale in the summary.
- Calibrated numbers, from the Plan B calibration run on 2026-09-30 over nine runs (cases 26 and 27
  at three runs each, cases 1, 9, and 17 at one run each): the per-finding prose bound is set to 130
  words (measured 95th percentile 127); the proofread wave size is set to 5, because not every
  proofread wave completed in calibration; the size cap is kept at 25 files or 250,000 characters,
  because the across-set defect was not found in all 3 case-27 runs (the incomplete run e27 r1
  missed SCL-3); the per-document split threshold is set to 60,000 characters, confirmed by every
  case-26 defect being found in at least 2 of 3 runs. Two usage limits cut into this calibration:
  the five-hour limit interrupted the case-27 runs, and one run (e27 r1) was left incomplete to save
  weekly usage. The cap and wave values are therefore the conservative defaults, not measured
  optima.
- The v1-against-v2 behavioral comparison has not run. It is pending: it runs after the weekly
  usage reset, and any fixes it finds ship as patch versions. This record makes no claim of a v2
  PASS or FAIL, and no claim that v2 found a defect v1 missed.
- Override, 2026-09-30: the user swapped v2 in before the v2 behavioral run, so no pass criterion
  had been evaluated. Reason, as the promoted spec's `- Override, ` line states it: "the user wanted
  v2 in use now, with the full evaluation to finish after the weekly usage reset and any fixes to
  ship as patch versions."
- The discovery record that the spec's item IDs (P-, E-, D-, G-, R- prefixed) point back to is last
  held by commit `b3af044`, and can be read with
  `git show b3af044:specs/drafts/review-md-v2-discovery.md`.

## Consequences

- v2 is live with no v2 behavioral result. Until the comparison runs, its pass criteria are
  unevaluated, and any fix the comparison finds ships as a patch version.
- The comparison resumes from the local branch `review-md-v2-eval-frozen`, which holds the frozen
  v2 build and both spec drafts as they stood before the swap.
- v1's copy of `reference/document-generation.md` under `skills/review-md/references/` is gone.
  v2 carries the link classification table in `scripts/link-recheck-hook.sh --review` and in its
  proofread template instead.

## Alternatives considered

- Keep v1 with targeted fixes. Rejected: the spec states v2 exists because v1 "catches mechanical
  errors and local inconsistencies but misses the bigger picture and the errors in how parts of a
  document, or several documents, relate, and because it often has to be run more than once"
  (`specs/skills.md`, review-md section, Purpose).
- A single Opus pass over the whole target, with no separate per-document proofread pass. Rejected:
  the spec's Fan-out section keeps one cold Sonnet dispatch per document specifically "because each
  pass must stay independent and bounded to one document (long context degrades review accuracy,
  see Passes and tiers)" (`specs/skills.md`, review-md section, Architecture). A lone whole-target
  pass would drop that bound.
- A whole-skill fork (`context: fork`). Rejected: the spec keeps the orchestrator running inline
  with no `context: fork` because "only the orchestrator asks the user anything, because
  `AskUserQuestion` is unavailable inside a subagent" (`specs/skills.md`, review-md section,
  Architecture). Forking the orchestrator itself would put every user-facing question out of
  reach.

## References

- `specs/skills.md` - the review-md section, source of the design decided here.
- `evals/runs/2026-09-29-review-md-v1-baseline.md` - the 2026-09-29 v1 baseline run record.
- `evals/runs/2026-09-30-review-md-v1-new-fixtures.md` - the 2026-09-30 v1 new-fixtures run record.
- `evals/README.md` - the review-md rows, including the pending v2 row.
- `skills/review-md/SKILL.md` - the skill this decision governs.
