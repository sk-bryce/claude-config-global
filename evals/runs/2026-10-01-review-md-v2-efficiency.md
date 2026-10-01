---
created: 2026-10-01
updated: 2026-10-01
---

# `review-md` 2026-10-01: v2 efficiency rework, targeted eval

## Harness and environment

- Harness: Claude Code 2.1.283 (from the session log; `claude --version` is not on PATH in this
  environment). The v1 baseline this run compares against ran on 2.1.280.
- Models by alias: executor sonnet; coordinator sonnet, effort high; proofread workers sonnet;
  area and verify workers sonnet in the main v2eff iteration, opus in the Opus arm (and, after the
  decision below, opus is what ships).
- Date: 2026-10-01.
- Skill commit: working tree on top of `b62622b`, the uncommitted v2 efficiency changes applied
  on top of that commit.

## What changed

- Added a coordinator layer (`agents/review-md-coordinator.md`) dispatching separate worker
  agents (`review-md-proofread`, `review-md-judgment` for the area and verify roles) in place of
  the earlier v2's inline orchestrator and single judgment pass.
- Added `scripts/review-checks.sh`, `scripts/review-fill.sh`, and `scripts/review-merge.sh` to
  run deterministic checks, fill templates, and merge findings outside the model loop.
- Packing: large and scale documents are split and packed into units sized from the generated
  workspace content rather than from static stubs.
- Split the review into separate Proofread, Area, and Verify passes, each with its own template
  and batching rule.
- Effort and tier pins: the coordinator runs at Sonnet, effort high; the Area and Verify passes
  were pinned to Sonnet for the main v2eff iteration and moved to Opus after D12 (see Decision).

## Pre-registration

From `specs/skills.md`'s `#### Efficiency rework targeted eval (2026-10)`, fixed before any
v2eff result existed:

- Scope: cases 1, 2, 9, 10, 24, 25, and 26, 3 runs each, iteration `v2eff`, compared with the v1
  runs on the same cases.
- Quality bar: no defect v1 found by majority is lost; at least 4 of the 8 defects v1 missed by
  majority are found by majority (SVC-14, SVC-8, SVC-10, FIT-1, FIT-2, LRG-1, LRG-2, LRG-3);
  false-positive clusters with `fp_runs >= 2` no more than v1's on the same cases; every
  deterministic expectation passes in every run; no judgment expectation that v1 passed by
  majority fails by majority.
- Cost bar: the input-side ratio and the total ratio of v2eff to v1 mean per-run cost both at or
  below 2.0, with the relative prices Sonnet input 3, cache write 3.75, cache read 0.30, output 15
  and Opus input 6, cache write 7.5, cache read 0.30, output 30 per million tokens; usage
  deduplicated by message id.
- The Opus arm is run only on cases with a defect missed by majority.
- Items 8a (verify Blocker and Major findings only) and 8b (skip a verify group with nothing to
  verify) are applied and re-measured only when the cost bar fails.

## Results

`v2eff` (main iteration eff-summary.txt), cases 1, 2, 9, 10, 24, 25, 26 vs v1:

```text
quality=FAIL
regressions=none
v1_missed_found=6/8
missed=SVC-10,FIT-2
fp_clusters=1/10
deterministic=231/243
judgment_regressions=1 (9)
cost_ratio_input=1.52
cost_ratio_total=1.39
cost=OK
duration_ratio=1.85
```

`v2eff-opus` (Opus-arm iteration eff-summary.txt), cases 9 and 25 only, Opus area and verify, vs
v1:

```text
quality=FAIL
regressions=none
v1_missed_found=2/8
missed=SVC-10
fp_clusters=0/2
deterministic=57/66
judgment_regressions=0
cost_ratio_input=0.93
cost_ratio_total=0.85
cost=OK
duration_ratio=2.19
```

## Planted defects

Per-defect `found_runs`, v2eff (Sonnet area/verify) vs v1, for the seven scoped cases (case 10 has
no planted defects):

| Id | Case | v2eff found_runs | v1 found_runs |
| --- | --- | --- | --- |
| SVC-1 | 1 | 3 | 3 |
| SVC-2 | 1 | 3 | 3 |
| SVC-3 | 1 | 3 | 3 |
| SVC-4 | 1 | 3 | 3 |
| SVC-11 | 2 | 3 | 3 |
| SVC-12 | 2 | 3 | 3 |
| SVC-13 | 2 | 3 | 3 |
| SVC-14 | 2 | 3 | 0 |
| SVC-15 | 2 | 2 | 2 |
| SVC-5 | 9 | 2 | 3 |
| SVC-6 | 9 | 3 | 3 |
| SVC-7 | 9 | 3 | 3 |
| SVC-8 | 9 | 2 | 1 |
| SVC-9 | 9 | 3 | 3 |
| SVC-10 | 9 | 0 | 0 |
| SVC-23 | 9 | 3 | 3 |
| SVC-30 | 9 | 3 | 3 |
| FIT-1 | 24 | 2 | 1 |
| FIT-2 | 25 | 0 | 0 |
| LRG-1 | 26 | 3 | 1 |
| LRG-2 | 26 | 3 | 1 |
| LRG-3 | 26 | 3 | 1 |
| LRG-4 | 26 | 3 | 3 |
| LRG-5 | 26 | 3 | 3 |
| LRG-6 | 26 | 3 | 3 |

Of the 8 defects v1 missed by majority, v2eff finds 6 by majority (SVC-14, SVC-8, FIT-1, LRG-1,
LRG-2, LRG-3); SVC-10 and FIT-2 stay missed (`missed=SVC-10,FIT-2`), matching
`v1_missed_found=6/8`.

## False-positive clusters

`fp_clusters=1/10`: on the seven scoped cases, v1 had 10 clusters with `fp_runs >= 2` (case 1: 1;
case 9: 2; case 10: 3; case 24: 3; case 26: 1; cases 2 and 25: none). v2eff carries 1 such
cluster forward, at or below v1's count, which is what the quality bar requires on this
criterion.

## Cost and duration

Per-case mean cost and duration, v2eff vs v1 (cost in input-equivalent token units):

| Case | v2eff cost_input | v2eff cost_total | v2eff duration (s) | v1 cost_input | v1 cost_total | v1 duration (s) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 1097007.60 | 1116287.60 | 355.34 | 560472.90 | 637172.90 | 203.61 |
| 2 | 1419405.50 | 1440285.50 | 437.36 | 619653.70 | 754418.70 | 202.32 |
| 9 | 1911929.45 | 1973294.45 | 691.84 | 2883436.20 | 3267186.20 | 418.79 |
| 10 | 1612110.60 | 1656975.60 | 574.59 | 797001.90 | 977811.90 | 249.54 |
| 24 | 944770.85 | 957300.85 | 330.15 | 769878.05 | 775128.05 | 177.27 |
| 25 | 974407.30 | 990272.30 | 327.57 | 832022.80 | 865652.80 | 257.06 |
| 26 | 2937809.65 | 2956689.65 | 441.39 | 709753.55 | 711583.55 | 197.73 |

Ratios: `cost_ratio_input=1.52`, `cost_ratio_total=1.39`, `duration_ratio=1.85`. Caveat: v1 ran on
harness 2.1.280, and later versions undercount subagent output tokens, so the input-side ratio
(1.52) is the reliable figure; the total-cost ratio (1.39) is read with that undercount in mind, so 1.39 is a lower bound.

## Opus arm

Run on cases 9 and 25 only, the two cases carrying a defect missed by majority by v2eff
(SVC-10 and FIT-2).

| Defect | Case | v2eff (Sonnet area/verify) found_runs | v2eff-opus (Opus area/verify) found_runs |
| --- | --- | --- | --- |
| SVC-10 | 9 | 0 | 0 |
| FIT-2 | 25 | 0 | 3 |

Opus found FIT-2 in 3 of 3 runs where Sonnet found it in 0 of 3; SVC-10 stayed unfound at either
tier. On the same two cases, mean `cost_total` per run: v1 2066419.50; v2eff 1481783.38 (0.72x
v1); v2eff-opus 1757837.38 (0.85x v1, about 1.19x v2eff's Sonnet cost on these cases). Mean
duration: v1 337.93s; v2eff 509.71s; v2eff-opus 739.94s. Opus arm deterministic: 57/66; the
failures are the same kinds the Sonnet runs showed (finding_fields with Status missing in all 6
runs, one word_bound at 135 words, ends_after_question in two case 9 runs). `judgment_regressions`
is 0 and `fp_clusters` is 0/2.

## Background dispatch

The plan's background-dispatch check (12a): `background-dispatch: not observed`. The coordinator's worker Agent calls in the
sampled smoke run all used `run_in_background=false`, and each call's tool result returned inline
rather than through a backgrounded task notification.

## Decision

**SHIP** - this is a user-accepted ship, not a measured pass. By this run's own rule, the final
`eff-summary.txt` (v2eff, the shipped iteration's Sonnet-area/verify measurement) reads
`quality=FAIL`, with the failing lines:

```text
quality=FAIL
deterministic=231/243
judgment_regressions=1 (9)
```

The plan's Appendix C (D10) records the user's answer accepting this result and continuing rather
than stopping or re-planning. Supporting points:

(a) After the Opus arm, the user switched the Area and Verify passes to Opus (D12). Opus found
FIT-2 in 3 of 3 runs where Sonnet found it in 0 of 3, at about 1.19x the Sonnet cost on cases 9
and 25.

(b) The shipped Opus configuration's cost was measured only on cases 9 and 25, not on all seven
scoped cases.

(c) Cost is above v1: `cost_ratio_total=1.39` and `cost_ratio_input=1.52` for the Sonnet v2eff
iteration. `cost=OK` means only "under the 2.0 cap," not "cheaper than v1." The 2.0x cap was met,
but cost did not fall below v1.

(d) Duration is above v1 too: `duration_ratio=1.85` for v2eff and 2.19 for v2eff-opus on cases
9 and 25. The goal of finishing sooner was not met.

(e) Known defects go to a follow-up plan rather than blocking this ship:
`scripts/review-merge.sh` merge step 5 dedupes by File, Line, and Category, which folded a
distinct defect in case 9 run 1 (a 30-day vs. 14-day retention finding merged into another and
lost); and `finding_fields` failures (Status missing in 7 of 21 Sonnet runs and in all 6 Opus
runs).
