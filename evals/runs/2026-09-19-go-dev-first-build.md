---
created: 2026-09-19
updated: 2026-09-23
---

# `go-dev` 2026-09-19: first build, both eval layers

**Decision: SHIP on the second pass** (first pass HOLD; see Decision). On the first pass both
layers ran to completion and neither met its threshold.

## Harness and environment

- Trigger layer: `run_eval.py` from the `skill-creator` plugin, install `c447c3207a42`.
  **Deliberately `run_eval.py`, not `run_loop.py`.** `evals/README.md` names `run_loop.py`, but
  that script runs a description-improvement loop (`--max-iterations`, default 5) and rewrites the
  `description:` in `SKILL.md` as a side effect. That would invalidate the recorded digests and the
  spec-anchored provenance chain, and would mean the figure was measured over a description that no
  spec or human ever approved. `run_eval.py` is single-pass measurement with the same flag set, and
  it reports raw `triggers`/`runs` per case, which is what allows negatives to be scored on raw fire
  count instead of the harness's `rate < threshold` pass flag.
- Trigger model: `claude-sonnet-5`. Flags: `--num-workers 1 --timeout 120 --runs-per-query 9
  --trigger-threshold 0.88`, run from a scratch project root with the skill NOT installed under the
  personal-skill glob.
- Behavioral model: executors at Sonnet, one subagent per eval case, expectations withheld from
  every executor. Grading done by the dispatching agent against the grader agent definition that
  ships with the `skill-creator` plugin.
- `python3` 3.12.3 (above the 3.10 floor `run_eval.py`'s PEP 604 syntax requires).
  `CLAUDE_CONFIG_DIR` deliberately NOT overridden: pointing it at an empty directory strips login
  state and yields a uniform-zero result indistinguishable from a void run.
- Eval-set digests this run was measured over:
  - `trigger-evals.json` `a3ae1d697a5e3a2de72753c868f4543d62652a1d268bee55d153b7d04255427e`
  - `evals.json` `c9859188d6ee3cb17fa45c4e5a493cc3e43b034e173e73accb525a9a980938e6`

## New failure mode found: the PARTIAL void run

`evals/README.md` documents a void run as a uniform sweep of near-zero positives. One run here was
void in a way the existing tripwires do not catch: it was **partial**. Three queries that had scored
9 of 9 read 0 of 9, including the most obviously-triggering query in the set, while two other
positives still fired 9 of 9 and all nine negatives stayed clean. Exit code 0, no `query failed`
line in stderr. Read at face value it looked like a catastrophic regression caused by the preceding
description edit.

Confirmed void by re-running two of the collapsed queries in isolation against the unchanged
description: both scored 3 of 3.

**Usable tripwire: mean per-call wall time.** Healthy runs here measured 4.6, 4.9, 5.7 and 6.5
seconds per call. The void run measured 2.3. A serial run that finishes substantially faster than
its predecessors measured fewer real completions, whatever the results JSON says. Recommend adding
this to the README's failure-mode list.

## Trigger layer: 7 of 9 positives, 7 of 9 negatives. FAIL.

Positive total 75 of 81. Gate: every positive at 8 of 9 or better, every negative at no more than
1 fire of 9.

| Case | Polarity | Rate | Verdict |
| --- | --- | --- | --- |
| worker pool leaking goroutines | + | 9/9 | pass |
| wire context cancellation through a handler | + | 8/9 | pass |
| Go HTTP handler returns 200, should be 502 | + | 7/9 | **fail** |
| table-driven test flakes in CI | + | 9/9 | pass |
| go.mod wants two versions of one dependency | + | 6/9 | **fail** |
| profiled service, allocation hot spot | + | 9/9 | pass |
| add error wrapping so callers can use errors.Is | + | 9/9 | pass |
| new Go project, what goes in go.mod | + | 9/9 | pass |
| Go HTTP client posting JSON with a timeout | + | 9/9 | pass |
| review my Go diff before I open the PR | - | 2/9 | **fail** |
| Go program hanging in production, attach to it | - | 0/9 | pass |
| generate a full test suite with full coverage | - | 2/9 | **fail** |
| proofread this README | - | 0/9 | pass |
| Python threading data races | - | 0/9 | pass |
| Rust channel deadlock | - | 0/9 | pass |
| migrate Go services to Kubernetes | - | 0/9 | pass |
| Node.js handler wrong status code | - | 0/9 | pass |
| fix the Helm chart YAML | - | 0/9 | pass |

### One eval case was re-derived mid-run, and why that is not eval-softening

The positive case originally read `This HTTP handler is returning a 200 even when the downstream
call fails - it should be a 502.` It scored 0 of 9 under two different descriptions and was
**unsatisfiable by construction**: it carried no Go signal at all, while the set separately carries
the negative `This Node.js HTTP handler is returning the wrong status code - can you fix it?`. The
only token distinguishing the pair was the language the negative named. Any description firing on
the positive must also fire on a language-less handler query, while the set correctly asserts
elsewhere that this skill must not fire for other languages.

**No spec change was needed.** The spec's trigger-conditions bullet already requires Go signal
("prompts naming Go or golang; Go-specific tasks"), so the case was mis-derived from a spec that
was already correct. One word was added: `This Go HTTP handler ...`. The case then moved 0/9 to
7/9. The digest was re-recorded (old `36831a42...`, new `a3ae1d69...`).

All nine positives were audited for the same defect first. Four carry no literal Go token, but
three of those carry Go-specific idiom instead (context cancellation, table-driven test, allocation
profiling) and all three score 9 of 9. Only the one case had neither, so only it was changed.

### The remaining positive failure is a content gap, not a description defect

`go.mod wants two different versions of the same dependency` sits at 6 of 9 across two runs.
Consistent, not noise. **The skill has no content on module or dependency resolution**: no version
conflicts, no MVS, no `go mod tidy`, no indirect dependencies. The only `go.mod` mentions across
all nine reference files are a directory-tree line and two incidental hits.

The description could be edited to lift this number. That was deliberately not done, because it
would make the skill fire on questions it cannot answer, which is the precise false-green this
layer exists to catch. `specs/skills.md` lists "work on a `go.mod`" as a trigger condition with
nothing written behind it. Close it by narrowing the spec bullet or by adding the content; do not
close it in the description.

### Contamination caveat

The description was iterated against the same trigger set that scores it, so 75 of 81 is an upper
bound, not an independent estimate. Mitigated by fixing at the level of the defect (over-broad
negation clauses) rather than pattern-matching individual failing queries, but not eliminated. An
honest re-measurement needs a held-out query set that never informed the description.

## Behavioral layer: deterministic 26/30 (86.7%), judgment 6/8 (75%). FAIL.

Gate: deterministic 100 percent, judgment at or above 90 percent. No `without_skill` baseline arm
was run, consistent with this repository's convention since 2026-09-08.

| Case | Deterministic | Judgment |
| --- | --- | --- |
| 1 CSV reader | 4/5 | 1/1 |
| 2 table-driven test | 2/4 | 0/1 |
| 3 HTTP client with timeout | 4/4 | 1/1 |
| 4 worker pool | 2/3 | 1/1 |
| 5 structured logging | 5/5 | - |
| 6 key=value config parser | 4/4 | - |
| 7 largest-sum key | 2/2 | 1/1 |
| 8 errgroup explanation plus new helper | 1/1 | 1/2 |
| 9 existing slog project | 2/2 | 1/1 |

### The most important finding: the reference examples teach against the house rule

Case 2 failed three of its five expectations, and all three trace to one cause. The executor read
both `go-testing.md` and `go-style-preferences.md`, then reproduced the reference example's style
rather than the house rule:

- `go-testing.md:42` writes `tests := []struct {`. The executor wrote `tests := []struct {`. That
  is `:=` outside an initializer expression, which the house declaration rule forbids.
- `go-testing.md:74` writes `for _, tt := range tests`. The executor wrote `tt`. That is a
  two-letter name outside the `ok`/`err` exceptions, which the house naming rule forbids.

This is direct evidence against the settled decision recorded in `specs/skills.md`, that the domain
files' examples stay in upstream idiom and are exempt. The exemption is coherent as policy, but in
the single most-copied shape in Go it causes the model to emit the anti-pattern the skill exists to
prevent. Case 8 probes the same boundary from the other side and got it half right: it correctly
declined to criticise the reference's `g, ctx := errgroup.WithContext(ctx)` and correctly used
`var` in its own new helper, but never articulated that the exemption covers the reference files.

Options, in preference order: add a house-style counterpart beside the upstream example in
`go-testing.md`; or state the exemption inline in each example rather than only in the file-top
framing note; or revisit the exemption itself.

### The other deterministic failures

- **Case 1**: wrote a bare `defer dataFile.Close()`, silently discarding the close error. No
  reference file covers deferred-close error handling. Content gap.
- **Case 4**: bounded its workers and collected errors under a mutex correctly, but did not
  propagate cancellation on failure, so every job runs to completion regardless. The executor said
  it deviated from the errgroup example deliberately because the prompt asked to collect all errors
  rather than stop at the first. `go-concurrency.md`'s only errgroup example stops at the first
  error, so the skill never demonstrates collect-all-plus-cancel. Content gap.
- **Case 2's third failure** asserts a named test-case struct type. No reference file shows one
  anywhere. That expectation asserts a shape the skill never teaches, so it is an eval over-claim
  rather than a skill defect, and should be re-derived or dropped.

## Eval-set critique

Two assertions test shapes absent from the skill (case 2's named struct type; the trigger set's
`go.mod` dependency-resolution query). Case 7's `ok`/`err` assertion passes vacuously: the task
introduces neither a comma-ok access nor an error value, so nothing can violate it. Case 4's
expectation demands both collect-all-errors and stop-on-first-failure cancellation, which are in
tension in the prompt as written and should be split or reworded.

## Second pass: what changed between the runs

Four content changes, all approved before they were made, then both layers re-measured.

1. `go-testing.md` gained a `### The same test in house style` subsection beside the upstream
   example, which is left byte-identical. This is the fix for the headline finding above.
2. `go-error-handling.md` gained `## Errors From Deferred Close`, teaching the named-return capture
   pattern for handles that were written to, and saying plainly that a bare `defer f.Close()` is the
   right call on a read-only handle.
3. `go-concurrency.md` gained `## Collecting Every Error While Still Cancelling`, which demonstrates
   the collect-all-plus-cancel shape the existing errgroup example does not cover.
4. `specs/skills.md` narrowed the `go.mod` trigger condition and extended the Non-goals bullet to
   exclude module and dependency version resolution explicitly.

The Go parse baseline held at exactly 3 unparseable blocks across all three content additions, and
the idiom-framing note stayed present and byte-identical in all seven domain files.

## Trigger layer, run 6: 9 of 9 positives, 9 of 9 negatives. PASS.

Run 5 measured description v2 and came in at 9/9 positives (80/81 fires) but 8/9 negatives, the
single failure being `Generate a full test suite with complete coverage for this Go package` at 5/9.
The description had not changed between runs 4 and 5, so that query is unstable near the decision
boundary rather than newly broken: it read 0, 2, 2, then 5 across four runs. The negation was then
rewritten to carry a scope discriminator (one existing test versus bulk suite generation) instead of
a keyword, which pushed the description to 1585 chars, over the 1536 cap, so redundant prose was
trimmed elsewhere to land at 1533. Only 3 characters of headroom remain, which constrains any future
description edit.

Because the description changed after run 5, run 5's numbers did not describe the shipped artifact
and a sixth run was mandatory.

Run 6, description v3: 12m49s, 4.75s per call. That sits inside the healthy 4.4 to 6.5s band and
well clear of the 2.3s partial-void signature described above, so the run is trustworthy.

- Positives: 9 of 9 meet the 8-of-9 gate. 78 of 81 total fires. Six cases at 9/9, three at 8/9.
- Negatives: 9 of 9 within the 1-fire gate. 2 total fires across 81 runs.
- The sharpened negation moved `Generate a full test suite` from 5/9 to 1/9.
- The `go.mod` dependency-resolution positive that stalled the first pass at 6/9 is gone: the spec
  boundary moved to exclude dependency resolution, and the query was replaced by a slice-aliasing
  positive. The remaining `go.mod` positive (`setting up a new Go project`) was already 9/9 and
  held there. The gap closed because the spec boundary moved, not because the description was
  tuned to advertise coverage the skill lacks.

Scored on raw `triggers`/`runs`, not the harness's own pass flag. The harness reported `18/18
passed`, which grades negatives on `rate < threshold` and would have concealed a negative firing up
to 7 times in 9.

## Behavioral layer, run 2: deterministic 29/30 (96.7%), judgment 7/8 (87.5%)

Same protocol as run 1: nine executors at Sonnet, one per case, expectations withheld from every
executor, graded by the dispatching agent.

- **Case 2 fully fixed**, 4/4 deterministic and 1/1 judgment, up from 2/4 and 0/1. The output now
  declares a named `validateEmailCase` struct type, writes `var testCases = []validateEmailCase{`,
  and ranges with `for _, testCase := range testCases` rather than `tt`. One added example converted
  all three prior failures, which is direct confirmation of the headline finding's diagnosis.
- **Case 4 fully fixed**, 3/3 and 1/1. The new collect-all-plus-cancel section supplied the
  cancellation-on-failure shape the executor previously had nowhere to read.
- Cases 3, 5, 6, 7 and 9 all clean on every expectation.
- Two failures remained, one in each layer, and each turned out to be a conflict rather than a
  simple miss. They are treated separately below.

## The two conflicts run 2 exposed

**Case 1: the new content and the expectation genuinely disagreed.** The deferred-close section
added in this pass teaches that a bare `defer f.Close()` is correct on a read-only handle. The
executor opened the file read-only and wrote exactly that, with a comment giving the reason. The
expectation forbade a bare deferred Close unconditionally. Correct Go here is conditional on read
versus write, so the expectation was mis-derived rather than the output being wrong, and that is
arguable from Go semantics without reference to the failing output. That is the line separating this
from answer-key softening: the earlier `go.mod` trigger case was NOT re-derived, because there the
measurement was right and the skill was missing content. Expectation 3 of case 1 now scopes the
capture requirement to handles that were written to and accepts a justified bare Close on a
read-only handle. The case re-grades to 5/5 against the corrected expectation on the same unchanged
output; it was not re-run, because neither the skill content nor the prompt changed.

**Case 8: the skill stated a rule but never told the model to say it.** The expectation wants the
model to articulate that the upstream-idiom exemption covers the reference files' own examples. The
run-2 output did the right thing - it left the reference's `g, ctx := errgroup.WithContext(ctx)`
alone and wrote its own helper in house style, calling the difference a deliberate departure - but
justified the reference line on shadowing-safety grounds instead of the exemption. The intended fix
was to add the exemption to `SKILL.md`; on opening the file, `SKILL.md` already carried it in the
house-rules section, so adding it again would have been cargo-culting a fix already in place. The
actual gap was narrower: the skill said the exemption exists but never said to state it when asked.
One sentence was added to that existing paragraph directing the model to say plainly that such an
example is upstream idiom carried deliberately. That is a body-only edit and leaves `description:`
untouched, so trigger run 6 remains valid for the shipped artifact.

**That fix did not work, and the third run is why the expectation was re-derived rather than the
skill patched again.** Case 8 was re-run at Sonnet against the amended `SKILL.md`. It failed the
same expectation a third time. The output explained the line via Go's `:=` redeclaration rule (a
short variable declaration may redeclare a name already present in the same block provided at least
one name on the left is new) and never reached for the exemption, even though the skill now
explicitly directs it to. Run 2 had failed the same expectation by a different route, justifying the
line on shadowing-safety grounds.

Three runs, one of them with an explicit directive in the skill to say the thing, is a different
evidence base from a single bad result. The pattern is not that the skill forgot to state the
exemption; it is that the case asks *why this line works*, and the correct answer to that question
is the language mechanics. The expectation was asking the model to answer a mechanics question with
style-policy recitation, and to give a worse answer in order to pass.

The expectation was therefore re-derived to test the distinction rather than the recitation: it now
asks that the response draw an explicit distinction between the reference file's example and the new
code it writes, rather than applying one style uniformly to both or passing over the difference in
silence. All three runs satisfy that. Recorded here in full, including the two failed attempts to
fix it skill-side, so the softening is auditable rather than invisible.

An earlier draft of this grading passed run 3 on the strength of its phrase `the same shape as the
reference file's examples, but written under this project's house declaration style`. That was
rejected: run 2 carried an equally direct contrast (`a deliberate departure from the reference
file's own example`) and had been failed, so passing run 3 on that basis would have been the grading
line moving to produce a green rather than the evidence changing.

### An unexpected content finding from the same case

The run-3 executor tried the direct house-style translation `var group, ctx =
errgroup.WithContext(ctx)` and found it does not compile: `ctx redeclared in this block`. Plain
`var` has no redeclaration rule, so it cannot reuse a parameter name the way `:=` can. It verified
this with `go build` against `golang.org/x/sync` v0.23.0 on go1.26.4 and fell back to declare-then-
assign (`var group *errgroup.Group`, then `group, ctx = errgroup.WithContext(ctx)`, a plain
assignment rather than a declaration).

This is a hard language limit on the house declaration rule at a shape the skill actively routes
users toward, and `go-style-preferences.md` does not document it. It is NOT fixed in this run:
adding it would be a fourth content change and would invalidate the behavioral measurement that was
just completed against these files. Carried as the highest-value content follow-up.

## Eval-set digest change, recorded under Definition of Done condition 11

`evals.json` moved from `c9859188d6ee3cb17fa45c4e5a493cc3e43b034e173e73accb525a9a980938e6` to
`a68d3831e12d45ddd0d5421fe1fb6669767d0466ab25ca61ab8f24aa1ac3f2eb` across two deliberate spec
changes, both described above and both approved before they were made: the re-derived case-1
deferred-close expectation, and the re-derived case-8 judgment expectation. Case and expectation
counts are unchanged at 9 and 38, still 30 deterministic and 8 judgment with none untagged.

`trigger-evals.json` moved to `ca087912a4fc8f9ec9f6d93bb1767c0d3cef06c346cc8b25bb4ef74d561bc0ea`
across two deliberate changes, both recorded in the first pass above: the re-derived HTTP-handler
case, and the replacement of the `go.mod` dependency-resolution case with a slice-aliasing case
after the content gap was confirmed rather than papered over.

## Decision

**HOLD** on the first pass, superseded. **SHIP** on the second.

The first pass was held for two reasons and both are now closed. The `go.mod` spec-versus-content
gap was resolved by narrowing the spec rather than by tuning the description to advertise coverage
the skill does not have, and the dependency-resolution positive was replaced by a slice-aliasing
one. The reference-example
style leak, which defeated the skill's primary purpose in the single most-copied shape in Go, was
closed by adding a house-style counterpart beside the untouched upstream example in
`go-testing.md`; case 2 went from 2/4 to 4/4 on that one change.

Final measurement against the shipped artifact:

- Trigger: positives 9/9 meeting the 8-of-9 gate (78/81 fires), negatives 9/9 within the 1-fire gate
  (2 fires across 81). Measured at `claude-sonnet-5`.
- Behavioral: deterministic 30/30 (100%), judgment 8/8 (100%).

Two of the 38 expectations were re-derived mid-run and both are documented above with their full
history, including the two failed attempts to fix case 8 from the skill side before its expectation
was touched. A reader who distrusts those two re-derivations can read the unsoftened figures as
deterministic 29/30 and judgment 7/8 and decide for themselves; the raw outputs are unchanged and
the reasoning is recorded rather than folded into the numbers.

Known follow-ups at the time, none of them gates, all closed on 2026-09-23 (see below): `go-style-preferences.md` does not document that plain `var`
cannot redeclare a parameter name, which makes the house rule unfollowable at the
`errgroup.WithContext` shape; `reference/layout.md` has no `go-dev` entry; `errors.Join` is taught
nowhere; case 7's `ok`/`err` expectation still passes vacuously; and the partial-void-run failure
mode found here should be written into `evals/README.md`, which currently documents only the
uniform-zero variant.

## Post-run changes, 2026-09-23

Made after the skill merged, to close follow-ups this run raised. None of them touches the
`description:`, so the trigger figures above still describe the shipped artifact.

- **Case 7 rewritten.** Its `ok`/`err` expectation passed vacuously, since the task introduced
  neither a comma-ok access nor an error value. It also over-claimed: the house rule permits `ok`
  and does not require it. The prompt now takes a slice of candidate keys, skips absent ones, and
  counts a present candidate with an empty slice, so a comma-ok lookup is required for
  correctness. The expectation now checks for that lookup over a nil or length check, and accepts
  `ok` or a descriptive name. Case and expectation counts are unchanged at 9 and 38.
- **Content added.** `go-style-preferences.md` gained a subsection on reassigning a parameter from
  a multi-value call. It covers the `var group, ctx = errgroup.WithContext(ctx)` compile error the
  case-8 executor found, and the declare-then-assign fix. `go-error-handling.md` gained
  `errors.Join`. It covers joining a close error with a body error, a collect-then-join loop, and
  three caveats (multi-line messages, single-error wrapping, and joining is not a substitute for
  `%w` context). Every claim in both was compiled on go1.26.4 before it was written.
- **Targeted re-run.** Cases 1, 7, and 8 were re-run at Sonnet with expectations withheld, the only
  cases whose prompt changed or whose likely-read files gained content bearing on them. All three
  passed every expectation: case 1 at 5/5 and 1/1, case 7 at 2/2 and 1/1, and case 8 at 1/1 and
  2/2. Case 8's executor used the new declare-then-assign shape directly. The other six cases were
  not re-run.
- **Docs.** `reference/layout.md` gained its `go-dev` entry, and `evals/README.md` now documents
  the partial-void run alongside the uniform-zero variant. With the two content additions above,
  that closes all five known follow-ups from the Decision section.
- **Digests after these changes.** `evals.json` was then
  `7f20f3efdd0e4b777e5fe1c175d6f4e5c978000a271e8ef1556da7042627dcba`, a deliberate change to
  case 7 only. `trigger-evals.json` is unchanged at
  `ca087912a4fc8f9ec9f6d93bb1767c0d3cef06c346cc8b25bb4ef74d561bc0ea`.

## Review changes, 2026-09-23

A skill-author audit of the merged skill found claims that were wrong or went against the skill's
own rules. Each fix below was checked against go1.26.4 or golangci-lint v2 before it was written.
None touches the `description:`.

- **Linter claims.** The house config runs `errcheck` with `check-blank: true`, which flags both
  `defer f.Close()` and `defer func() { _ = f.Close() }()`. `go-error-handling.md` now teaches
  `//nolint:errcheck // reason` for a read-only deferred Close. A Close called directly, not
  deferred, also trips `gosec` G104, so the in-loop close in `go-style-preferences.md` names both
  linters. That file's shadow snippet was v1 syntax, which a `version: "2"` config rejects. It is
  now v2 and passes `golangci-lint config verify`. The stale claim that the house config lacks
  `shadow` is gone.
- **Examples that taught against the house rule.** The loop example in `go-style-preferences.md`
  is where the `var row, errRead` shape of case 1's first output came from. It now hoists `row`
  and reuses `err`. `go-http.md` gained a per-call `context.WithTimeout` example layered over
  `Client.Timeout`. In `go-performance.md`, the retry loop no longer defers `resp.Body.Close()`
  inside the loop, and the redundant hand-set `GetBody` is gone (`NewRequestWithContext` sets it
  for a `*bytes.Reader`). The multipart writer is no longer closed twice, and a stray
  `</content>` line is removed.
- **Framing.** The top-of-file note in all eight files that carry it now allows sections marked as
  written in house style. Three sections now carry that mark, and the house-style subsection in
  `go-testing.md` already said so in its heading. `SKILL.md`, `specs/skills.md`, and
  `reference/layout.md` say the same. `SKILL.md`'s error-handling routing line now names deferred
  Close errors and `errors.Join`.
- **Other corrections.** The untyped-constant gotcha described a silent lossy conversion. That is
  actually a compile error; the real trap is integer arithmetic before conversion
  (`var ratio float64 = 1 / 2` is 0). `go-style-conventions.md` now says a package holding an
  `slog.LogValuer` redaction type needs its own scoped depguard rule. This file's own claims were
  corrected: the opening decision line, the `go.mod` positive (it was replaced, not re-scoped to
  9/9), case 2's starting score (2/4, not 1/4), and one "below" that should read "above".
- **Eval text.** Case 1's `expected_output` still said the close error must not be dropped, which
  contradicted its re-derived expectation 3. It now matches. Expectations are unchanged. `evals.json`
  is now `ff3141f9dec54798aa2c7b311173443540dc1ed4c89d8b38f67cd9d629a8f9a5`.
  `trigger-evals.json` is unchanged.
- **Targeted re-run.** Cases 1, 3, and 6 were re-run at Sonnet with expectations withheld. These
  are the cases whose likely-read examples changed. All passed every expectation: case 1 at 5/5
  and 1/1, case 3 at 4/4 and 1/1, and case 6 at 4/4. Case 1's loop now hoists `row` and reuses
  `err`, where its last output declared `var row, errRead` inside the loop. Case 3 layered a
  per-call `context.WithTimeout` over `Client.Timeout`. Case 3's receiver is the one-letter `c`,
  graded the same way as in earlier runs; whether receivers, `t`/`b`, and loop indices are formal
  naming exceptions is an open policy question. The Go parse baseline held at 3 unparseable
  blocks.
