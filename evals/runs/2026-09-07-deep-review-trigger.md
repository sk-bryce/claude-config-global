---
created: 2026-09-07
updated: 2026-09-07
---

# `deep-review` 2026-09-07: trigger runs at n=9, and the behavioral suite re-run

Runs A to C cover the two positive cases added 2026-09-07 for `"rigorous review"` and
`"strong review"`. **Run D, added after those, re-measures the eight original positives at n=9.**
**Runs E and F, added later the same day, measure two revised descriptions across the full set -
all 17 cases, positives and negatives, at n=9 - after `"strong review"` was deleted.** The
behavioral suite was re-run separately through the skill-creator harness; see the section at the
end of this file.

**Result: both new cases fail, and four of the eight originals fail as well once measured at n=9.**
**Positives stand at 4 of 10, not the 8 of 10 that runs A to C implied. Two separable causes: n=3**
**systematically overstates a rate near 0.85, and `deep review this` - the canonical invocation -**
**is reproducibly the weakest phrase in the set at 0.67.**

## Procedure

Per `evals/README.md`. Preconditions asserted in the run script rather than remembered:

- `command -v claude` checked before each run. **It failed on the first attempt** - `claude` lives
  at `~/.local/bin/claude` and the invoking shell did not source the profile. That is false-green
  mode 1, caught by the assertion rather than by the number.
- `~/.claude/skills/deep-review` confirmed absent before each run.
- Scratch project root `/tmp/scratch-proj`, `cwd` set to it.
- `--num-workers 1 --timeout 120`, model `claude-sonnet-5`, `--holdout 0`, `--max-iterations 1`,
  `--report none`. The optimizer was never pointed at these scores.
- **`--trigger-threshold 1.0`**, so pass and fail mean the 3-of-3 rate rule this repository
  mandates rather than `run_eval.py`'s 0.5 default. Leaving that default in place is what produced
  the invalid 8/8 corrected on 2026-09-07.
- `stderr` carried no `query failed` line on any run.

## Runs

| Run | Runs per query | Wall clock | `"rigorous review"` | `"strong review"` |
| --- | --- | --- | --- | --- |
| A | 3 | ~50s / 6 calls | 3/3 (1.00) | 1/3 (0.33) |
| B | 3 | 42s / 6 calls | 1/3 (0.33) | 2/3 (0.67) |
| C | 9 | 119s / 18 calls | 4/9 (0.44) | 6/9 (0.67) |
| **Aggregate** | **15** | | **8/15 (0.53)** | **9/15 (0.60)** |

Neither phrase reaches the 100 percent threshold at any run size. Both cases **fail**.

## The instrument finding

**Run A and run B disagree on which query failed.** `"rigorous review"` went 3/3 then 1/3;
`"strong review"` went 1/3 then 2/3. `evals/README.md` names exactly this as the tell for
instrument noise rather than an artifact defect: "under this mode the *set* of failing queries
moves between runs. An artifact defect does not relocate."

The documented cause of that tell is `--num-workers 10` against a short timeout. **That was not the
cause here** - both runs were serial at `--timeout 120`. So the moving-failure-set signature is not
specific to the concurrency mode, and the repository's guidance is wrong to treat it as diagnostic
of that mode alone.

**What this costs: a 3-run rate cannot discriminate at this effect size.** Run A on its own would
have been recorded as `"rigorous review"` passing at 1.00 and `"strong review"` failing at 0.33 -
a clean, specific, publishable-looking result that the n=9 run inverts on the first phrase. Every
positive rate in the 2026-09-05 set was measured at n=3. Those figures are not thereby wrong, but
their error bars are wider than one significant figure, and **the 0.96 mean recorded there should
not be read as separating 1.00 from 0.67 for any individual query.**

Raising runs per query is the cheap fix: run C's 18 subprocess calls took under two minutes.

## Quoting is necessary but not sufficient

`"rigorous review"` **is** quoted verbatim in the description and still aggregates to 0.53. That
qualifies the standing finding recorded from the 2026-09-05 sets, which held that quoted example
phrases do the triggering and prose-only capabilities do not. Quoting remains necessary on the
evidence available; it is plainly not sufficient.

`specs/skills.md` had predicted `"strong review"` would be the weak one, as the only phrase of the
ten resting on semantic proximity rather than a quote. **That prediction is confirmed in direction**
- it does fail - **but it does not explain the result**, since the quoted phrase failed too, and by
a wider margin in aggregate.

Two hypotheses, neither tested here, recorded so a later run can discriminate them:

1. **Phrase position.** All eight of the 2026-09-05 positives open with the trigger phrase ("deep
   review this...", "poke holes in...", "push back on this:"). Both new queries bury it after a
   lead-in ("i need a rigorous review of...", "give this a strong review:").
2. **Scope override.** The description ends `Scope: personal (~/.claude/skills/)`, and both new
   queries name targets outside that scope. This is the mechanism already observed overriding a
   verbatim quoted phrase in `health-check`. It is a weaker fit here, because the 2026-09-05
   positives also name out-of-scope targets and scored far higher.

## Effect on the gate, as of runs A to C

The gate stays at **HOLD**. It was already there for the threshold-default error corrected earlier
on 2026-09-07; these runs add a second, independent reason and give it a concrete target.

Positives stood at 8 of 10 on the evidence available at this point. **Run D below supersedes that:
the figure is 4 of 10.**

---

## Run D: the eight original positives at n=9

Run after the above, same preconditions, same flags, `--runs-per-query 9`. 72 serial calls,
07:06:31 to 07:15:15 UTC (524s, ~7.3s per call). No `query failed` line. Commissioned to settle
whether the run-to-run movement in runs A and B was specific to the two new queries or general to
the instrument.

| Query opens with | Rate | Pass at 3-of-3 | 2026-09-05 at n=3 |
| --- | --- | --- | --- |
| `deep review this` | 6/9 (0.67) | **no** | 2/3 (0.67), the one recorded miss |
| `critique this approach` | 7/9 (0.78) | **no** | 3/3 |
| `push back on this` | 8/9 (0.89) | **no** | 3/3 |
| `should we even do this` | 8/9 (0.89) | **no** | 3/3 |
| `is this a good idea` | 9/9 (1.00) | yes | 3/3 |
| `poke holes in` | 9/9 (1.00) | yes | 3/3 |
| `play devil's advocate` | 9/9 (1.00) | yes | 3/3 |
| `be critical about this` | 9/9 (1.00) | yes | 3/3 |

**Four of eight pass. Mean 65/72 = 0.90**, against the 0.96 recorded at n=3.

### Both explanations were true, and they are separable

**The instrument overstated, and the arithmetic is elementary.** For a phrase whose true rate is
about 0.85, the chance of scoring 3 for 3 is roughly 0.61 - so at n=3 it looks perfect more often
than not. At n=9 the chance of 9 for 9 falls to about 0.23. That is the whole of why four queries
"passed" on 2026-09-05 and fail here with nothing about them changed. **n=3 does not test a 100
percent threshold; it tests whether a coin lands heads three times.**

**The two new phrases are also genuinely weaker**, independently of that. `"rigorous review"` at
0.53 and `"strong review"` at 0.60 sit below every one of the eight originals. Runs A and B moved
because n=3 is noise at that effect size, not because the phrases are fine.

**The one result consistent across both sessions is the worst one.** `deep review this` was the
single query recorded as falling short on 2026-09-05 (2/3) and is the weakest of the eight here
(6/9). It is the canonical invocation and it carries the skill's own name.

Do not read the matching 0.667 as a reproduced measurement - n=3 is far too coarse for that, and 2/3
is consistent with any true rate from roughly 0.5 to 0.85. The evidence is weaker than a repeated
figure and still sufficient: this query failed in both sessions, and in the session with real
resolution it was the worst of eight. Treat it as a probable description defect and confirm it in
the next run rather than treating it as settled.

### What this does to the recorded numbers

Positives are **4 of 10** at n=9 under the 3-of-3 rule, not 8 of 10. Negatives were **not** re-run
here and keep their 2026-09-05 figure of 8 of 8, measured at n=3 - and by the argument above that
figure is soft in the opposite direction, since a negative passes by *not* firing and n=3 makes a
low-but-nonzero rate look like a clean zero.

**Every trigger figure in `evals/README.md` measured at n=3 should be read as an upper bound on
positives and a lower bound on negatives.** That includes `cursor-projection`, `research`, and
`health-check`.

---

## Runs E and F: two revised descriptions, full set at n=9

`"strong review"` was deleted first - from the phrase list in `specs/skills.md` and from
`trigger-evals.json`, leaving 17 cases (9 positive, 8 negative). It was never in the description,
so the deletion freed no budget. The behavioral eval that used it as its prompt was reworded to
`"rigorous review"`, which was the same test of the same thing.

Three description variants are in play:

| variant | chars | content |
| --- | --- | --- |
| v1 | 751 | the 2026-09-05 description, unchanged |
| v2 | 875 | v1 plus a file-type sentence and a sibling-guard sentence, minus the Opus-subagent sentence |
| v3 | 794 | v2 with the guard sentence removed |

The two added sentences were meant to answer a specific diagnosis: `deep review this` was the worst
positive at 6/9, and its query is the only one whose target is a source file about to be committed.
It matches `code-review` on three hooks, and `review-md`'s description carries an explicit redirect
sending non-Markdown targets to code-review conventions.

### Results, n=9, `--trigger-threshold 1.0`, 153 serial calls per run

| query | v1 | v2 | v3 | p (v2 vs v3) |
| --- | --- | --- | --- | --- |
| `deep review this` (code target) | 6/9 | **9/9** | **9/9** | 1.000 |
| `rigorous review` | ~4.8/9 | **9/9** | **9/9** | 1.000 |
| `is this a good idea` | 9/9 | 9/9 | 9/9 | 1.000 |
| `poke holes in` | 9/9 | 9/9 | 9/9 | 1.000 |
| `should we even do this` | 8/9 | 9/9 | 9/9 | 1.000 |
| `be critical about this` | 9/9 | 8/9 | 8/9 | 1.000 |
| `play devil's advocate` | 9/9 | 9/9 | **7/9** | 0.471 |
| `critique this approach` | 7/9 | 5/9 | **3/9** | 0.637 |
| `push back on this` | 8/9 | 4/9 | **3/9** | 1.000 |
| **total** | ~69.8/81 | **71/81** | 66/81 | |
| **pass count** | 4/9 | **6/9** | 5/9 | |
| **negative fires** | n=3 only | **0 / 72** | **0 / 72** | |

v1's `rigorous review` figure is interpolated from its 8/15 aggregate at n=3; every other cell is
a direct n=9 measurement.

### What replicated

- **`deep review this` is repaired.** 2/3, then 6/9, then 9/9 twice. Four measurements across three
  sessions.
- **`rigorous review` is repaired.** 8/15, then 9/9 twice.
- **`should we even do this` is repaired**, 8/9 to 9/9 twice. A third repair, easy to miss because
  it was never one of the diagnosed cases.
- **`be critical about this` regressed**, 9/9 to 8/9, and stayed there across both post-change runs.
  It is the one casualty that is not an artifact-less query, so the dilution story does not cover
  it.
- **No sibling bleed.** Zero fires in 72 negative runs, on each of two runs. The `code-review`
  collision that the overlap analysis rated its highest risk did not appear once. Negative case 2
  (`review the changes on this branch vs main ... before i open the PR`) carries both the "diff" and
  the "about to be committed" cues and never fired.

### What was falsified

The guard sentence was argued to be dead weight: the negatives were already perfect without it, so
it looked like insurance against a risk that never materialized, and the likeliest candidate for
diluting the idea-review signal that the artifact-less queries depend on. **Removing it made things
worse.** v3 is the worst of the three variants. It did not merely fail to recover the two
conversational queries, it drove both lower - `critique this approach` 5/9 to 3/9 and `push back on
this` 4/9 to 3/9 - and it cost `play devil's advocate` 9/9 to 7/9 with no mechanism anyone can
point to. v2 was restored.

Do not re-run this experiment expecting a different answer without changing something else first.

### What is not established

Nothing separates v2 from v3 statistically. Every per-query comparison sits at p >= 0.47, and the
largest single-query swing in the whole exercise, `push back on this` at 8/9 to 4/9, is p = 0.131
against v1. The ordering of the variants rests on total rate and pass count, not on any single
query. The trade against the two artifact-less positives is consistent in direction across both
post-change runs, which is why it is reported as probably real rather than as measured.

`play devil's advocate` falling to 7/9 in v3 alone, with no mechanism, is the clearest reminder in
this file that n=9 still has room for a two-run swing that means nothing.

---

## Behavioral suite: re-run through the harness

The 2026-09-05 figures of 25/25 deterministic and 14/14 judgment came from hand-rolled dispatch and
carried an explicit caveat saying so. They were re-run through the skill-creator harness: one
executor subagent per eval saving `response.md` and a tool-call log `actions.md`, then a grader
subagent following the grader agent definition that ships with the skill-creator plugin, writing
`grading.json` per run with the `text`/`passed`/`evidence` schema the viewer requires.

Executors ran at Sonnet on purpose. At Opus the skill folds its second phase inline by design, and
every dispatch assertion would correctly fail to fire. No baseline arm was run: it answers whether
the skill beats no skill, which is not what the caveat was about, and it would have scored near zero
on most of the 25 deterministic assertions.

**Result: 23/25 deterministic, 13/14 judgment. The hand-rolled figures were too generous.**

All three failures are eval 9, `Deep review evals/files/cache-warmer.py.` - a bare path with no
stated purpose, which is the exact case the four-field brief gate exists for. They are one failure
seen three ways:

1. `[deterministic] Dispatches no Agent subagent while the brief is incomplete` - it dispatched, with
   Purpose guessed as "presumably to pre-populate a cache" and the other three fields recorded
   "None stated."
2. `[deterministic] Names Purpose as the context-brief field it cannot fill` - never named. Evidence
   absent rather than contradicted.
3. `[judgment] Stops or asks the user for the missing field rather than proceeding with a caveat` -
   it proceeded to a full verdict with an inline hedge, the explicitly excluded behavior.

The brief-completeness gate is the one rule in this skill with direct experimental support behind
it: the 2026-09-05 ablation showed that only the arms given a brief caught a constraint violation
that was not inferable from the artifact. The harness now shows that gate not holding on the single
eval built to test it, and the hand-rolled pass had scored that eval 4/4.

### Defects in the eval set itself

- **Eval 9's fourth assertion is non-discriminating.** "Does not emit a verdict based on an
  undispatched pass" passed *because* the run wrongly dispatched. It cannot fail in the failure mode
  the eval exists to catch. It wants rewording to something like "emits no verdict at all when the
  brief cannot be completed."
- **Eval 2's first assertion passes on the letter.** The run asked one question without writing a
  brief, as required, but also supplied its own default answer in the same breath instead of
  waiting. If "asks and stops" is the intent, the assertion does not currently say so.
- **`AskUserQuestion` is unavailable inside a subagent.** Any assertion touching it can only ever be
  graded against its plain-text fallback branch. The eval set was written to tolerate this, so it is
  a limit on what the suite can prove rather than a false failure.

### What this does to the recorded numbers, again

Both halves of the gate are now HOLD on measured evidence rather than on assumption: trigger 6 of 9
positives against a rule that demands 9 of 9, and behavioral 36 of 39 rather than the recorded 39
of 39. The trigger half improved and the behavioral half got worse, and both moved because they
were measured properly rather than because the skill changed underneath them.
