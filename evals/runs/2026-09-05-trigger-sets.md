---
created: 2026-09-05
updated: 2026-09-07
---

# Trigger-set run: `health-check`, `research`, `cursor-projection`

First measurement of the three trigger sets written on 2026-09-05 alongside the `deep-review` gate.
These sets have never been run before. This record covers the trigger layer only - none of these
three skills had its behavioral suite re-run here, so nothing in this file is a gate decision.

## Procedure

`run_loop.py` from the installed `skill-creator` plugin, one skill at a time, each skill temporarily
moved out of `~/.claude/skills/` for the duration of its own run and restored by a shell trap:

```
--model claude-sonnet-5 --max-iterations 1 --holdout 0
--runs-per-query 3 --num-workers 1 --timeout 120 --report none
```

`claude-sonnet-5` because that is the tier `settings.json` configures. Serial with a raised timeout
because the defaults produce a plausible wrong answer - see the correction section of
`2026-09-05-deep-review.md`.

**The first attempt at this run was void and is not reported below.** It scored all three skills at
0 of 8 positives and 8 of 8 negatives, and it did so in roughly 130 milliseconds per skill, because
`claude` was not on the invoking shell's `PATH`. That failure mode was already documented in
`../README.md` at the time and it was hit anyway, which is why the README now asks for a
`command -v claude` assertion inside the run script rather than a warning a human is expected to
remember. The reported runs took 3 to 4 minutes each, consistent with 48 real subprocess calls.

## Results

| Skill | Positives | Negatives | Mean positive rate |
| --- | --- | --- | --- |
| `cursor-projection` | 7/8 | 8/8 | 0.92 |
| `research` | 6/8 | 8/8 | 0.83 |
| `health-check` | see below | 8/8 | see below |

**Negatives are 8 of 8 for all three skills, at 0 of 3 on every case but one.** No description in
this set is over-broad, and the near-miss negatives are doing real work: `cursor-projection`
correctly declined "run the health check and tell me if anything's stale" and "should we even keep
supporting cursor?" (the second belongs to `deep-review`), and `research` correctly declined a
single-fact lookup, a `review-md` proofread, and a `write-plan` request. The one non-zero negative
was `cursor-projection` at 1 of 3 on "write a new skill for projecting config into vscode, model it
on how the cursor one works" - which names the cursor skill as a model, so a partial fire is
defensible rather than a defect.

### `cursor-projection`: 7/8, mean 0.92

Seven of eight positives fired 3 of 3. The single miss, at 1 of 3:

> i'm getting different behavior in cursor vs claude code for the same skill and i can't work out
> which side is wrong

The description covers "what Cursor does and does not support relative to Claude Code" and lists
capability questions, but every enumerated example is phrased as a question *about the harness*
("does Cursor honor `model:`?"). This query is phrased as a *symptom*. That is a small, specific
gap, and it is the highest-value shape in the set - a user who already knows to ask "does Cursor
support X" needs the skill less than one who is confused about why two harnesses disagree.

### `research`: 6/8, mean 0.83

Six positives at 3 of 3. Two misses, both at 1 of 3, and they share a shape:

> put together a written comparison of wasm runtimes for edge functions

> we're evaluating whether to move off stripe. research the realistic migration paths

Both ask for research output without using a documentation noun. The description's enumerated
phrases all pair a research verb with a *docs* object ("research X and write docs about it",
"create a docs/<topic>/ documentation set", "build documentation on X"). "Written comparison" and
"research the realistic migration paths" match the intent but not the shape, and the second is
additionally a decision-support request, which sits close to the `write-plan` and `deep-review`
boundaries the description explicitly disclaims. These two are worth one description change
between them; neither is urgent.

### `health-check`: 4/8 measured twice, and the number is not valid

Measured twice, and the two runs agree on all eight positives - the same four fail, at means 0.50
and 0.46. That agreement is the only direct evidence in this repository that the serial protocol is
reproducible rather than merely less wrong, and it is worth more than the number it produced.

The number itself does not survive scrutiny. One failure was strange enough to isolate: `audit this
repo and go ahead and fix whatever you find` scored 0 of 6 across both runs, even though `"audit this
repo"` is enumerated **verbatim** in the description. The first hypothesis was that the description's
"it applies no edits unless the user asks" clause repels a request to make edits. **That hypothesis
is refuted:**

| Probe query (3 runs each) | Fires |
| --- | --- |
| `audit this repo` | 1/3 |
| `audit this repo and tell me what you find` | 0/3 |
| `audit this repo and go ahead and fix whatever you find, i trust you` | 0/3 |
| `audit this repo and fix the stale dates while you're in there` | 0/3 |

The fix-it clause changes nothing; the bare enumerated phrase fires 1 time in 12. A second probe
isolates the real variable:

| Probe query (3 runs each) | Fires |
| --- | --- |
| `audit this repo` | 1/3 |
| `audit this config repo` | 3/3 |
| `audit my ~/.claude config repo` | 3/3 |
| `audit the config in ~/.claude and tell me what's stale` | 3/3 |

**One word moves it from 1 of 3 to 3 of 3.** The description is scoped hard - "this ~/.claude config
repository", "Scope: personal (~/.claude/), this repository only" - and the harness runs every query
from an empty scratch project that is not that repository. An unscoped "this repo" therefore refers
to something the skill explicitly does not cover, and declining is **correct behaviour**, not a
trigger defect.

#### This is a structural conflict between two of the run preconditions

The scratch project root is mandatory: without it the real skill fires instead of the synthetic
command file and every correct trigger is scored as a miss. But it also means the harness can only
ever ask about a directory that is not the target of a repository-scoped skill. **For any skill
scoped to a specific repository, deictic queries - "this repo", "the docs", "these scripts" - are
unmeasurable by construction**, because the referent is wrong in the only environment the harness can
run in.

This is not a defect in `run_loop.py` so much as a limit on what it can answer, and it applies to
`health-check` far more than to the other three skills, which are scoped by topic rather than by
location.

#### What this leaves

`health-check`'s trigger rate is **unknown**. Three of its four failures use unscoped deixis and are
invalid as written: "audit this repo...", "can you check whether the docs still match what the
scripts actually do", and "something feels off with the reference/ docs" (which is additionally a
genuine `review-md` near-miss and may belong in the negative set). The set needs those queries
rewritten with an explicit scope marker before any number from it means anything.

One candidate defect survives the confound and is worth keeping:

> give the config a once-over before i push this branch to the public remote

1 of 3, then 0 of 3. This query **does** carry the scope marker "config", so the confound does not
explain it. The description covers this case in prose - "and before a publication pass" - but that is
the reviewer's jargon, not a phrasing any user would type. The gap is real, small, and the same shape
as the two `research` misses: a capability stated only in prose, with no quoted example matching how
a user would actually phrase it.

## Conclusions

1. **Negatives are healthy across all three skills** (24 of 24). Nothing here is over-broad.
2. **`cursor-projection` at 0.92 and `research` at 0.83 are real figures** with small, specific,
   diagnosable gaps. Neither is urgent.
3. **`health-check`'s 0.50 is not a real figure.** The eval set needs repair before it is remeasured.
4. **The recurring shape, across all three:** capabilities the description states in prose do not
   trigger; only the quoted example phrases do. Every genuine miss in this run is a capability that
   exists in the description body with no quoted phrase matching real user wording.
5. **A verbatim-quoted phrase is not sufficient either.** "audit this repo" is quoted and still fires
   1 in 12, because a hard scope statement elsewhere in the description overrides it. Quoting a
   phrase does not guarantee it fires.

None of this is actioned here - see the deferred to-do.
