---
created: 2026-09-09
updated: 2026-09-11
---

# `deep-review` 2026-09-09: trigger gate after the regeneration, five description variants at n=9

The skill was regenerated from a restructured spec on 2026-09-09, and the description was
changed for the first time since 2026-09-07: it gained four phrasings the user supplied in their
own words ("does this belong here", "is there a better way to do this", "is this the best way to
do this", "does this serve its purpose") and a premise-led opener replacing "explicitly asks for
a rigorous, critical, or adversarial review". The spec's description rule says any change reopens
the trigger gate, so the gate was run: the regenerated description (A), then controlled variants
to locate the cause of what A showed.

**Result: A fails the gate at 2 of 11 positives. The four added phrases are the diluter, not
the opener, and the effect is a phrase budget: swapping out two unmeasured phrases (D, E)
recovers the originals and lets "does this belong here" fire, while the three generic phrasings
stay at chance under every variant. The previously measured description, run as a control, does
not fire on any of the four user phrasings at all.**

## Procedure

Per `evals/README.md`, with every precondition asserted in the run script:

- `command -v claude` asserted; `claude` resolves via `~/.local/bin` after exporting `PATH`.
- The live `~/.claude/skills/deep-review` was parked under a fresh `/tmp` name for each run
  with `mv`, and restored by a `trap` on exit. A stale `/tmp/dr-under-test` left by the
  2026-09-07 run tripped the refuse-if-exists guard once; the live directory was untouched by
  that failure. Restoration was confirmed after every run.
- Scratch project root `/tmp/scratch-proj`, `cwd` set to it, `PYTHONPATH` at the plugin's
  skill-creator directory, `python3 -m scripts.run_eval`.
- `--model claude-sonnet-5 --num-workers 1 --timeout 120 --runs-per-query 9`; variants B to E
  passed via `--description` so no file was edited between runs.
- `--trigger-threshold 0.88` for the harness flag, but positives are scored here by the
  repository rule (>= 8 of 9) and negatives by raw fire count, not by the flag.
- No `query failed` line on any run. Wall clock 799s to 947s per 180-call run, about 5s per
  call, consistent with the valid 2026-09-07 runs.
- Eval set: `skills/deep-review/evals/trigger-evals.json`, 20 cases after this session's
  additions - 11 positives (the seven measured 2026-09-07 plus one per new phrasing) and 9
  negatives (the eight from 2026-09-07 plus a near-miss for "is there a better way" on a trivial
  code snippet).

## Variants

| Variant | Chars | What it is |
| --- | --- | --- |
| A | 1062 | The regenerated description: premise-led opener, 13 quoted phrases |
| B | 1002 | The 2026-09-07 description with only the four new phrases appended (13 phrases) |
| C | 875 | The 2026-09-07 description verbatim - the control (9 phrases) |
| D | see below | C with "push back on this" and "critique this approach" swapped for "does this belong here" and "does this serve its purpose" (9 phrases) |
| E | see below | D plus "is there a better way to do this" and "is this the best way to do this" (11 phrases) |

## Per-query fires out of 9, variants A to C

| Expect | Query | A | B | C |
| --- | --- | --- | --- | --- |
| pos | deep review this before I commit it - it's the retry wrapper... | 8/9 | 7/9 | 7/9 |
| pos | ok honest question, is this a good idea? we're thinking abou... | 3/9 | 4/9 | 8/9 |
| pos | poke holes in the migration plan in docs/rfc/0012-multi-regi... | 7/9 | 9/9 | 9/9 |
| pos | should we even do this? spent all morning convincing myself ... | 5/9 | 5/9 | 9/9 |
| pos | play devil's advocate on my plan to move all the team's runb... | 9/9 | 6/9 | 9/9 |
| pos | be critical about this, don't be nice: proposal is to requir... | 6/9 | 8/9 | 8/9 |
| pos | i need a rigorous review of the capacity model in planning/2... | 5/9 | 6/9 | 7/9 |
| pos | does this belong here? i put the retry/backoff logic straigh... | 5/9 | 8/9 | 0/9 |
| pos | is there a better way to do this? current plan is a nightly ... | 1/9 | 2/9 | 0/9 |
| pos | is this the best way to do this - we're thinking of enforcin... | 1/9 | 5/9 | 0/9 |
| pos | does this actually serve its purpose? scripts/health-check.s... | 3/9 | 3/9 | 0/9 |
| neg | can you review this doc for me? docs/onboarding/day-one.md -... | 0/9 | 0/9 | 0/9 |
| neg | review the changes on this branch vs main and tell me if any... | 0/9 | 0/9 | 0/9 |
| neg | proofread the README, i rewrote the install section and want... | 0/9 | 0/9 | 0/9 |
| neg | run a health check on this config repo and tell me what's st... | 0/9 | 0/9 | 0/9 |
| neg | my skill's description isn't triggering reliably - can you l... | 0/9 | 0/9 | 0/9 |
| neg | quick sanity check, does `chmod 755` on a directory mean wha... | 0/9 | 0/9 | 0/9 |
| neg | summarize what this python module does, i inherited it and t... | 0/9 | 0/9 | 0/9 |
| neg | i need to write up the 'alternatives considered and rejected... | 0/9 | 0/9 | 0/9 |
| neg | is there a better way to write this? `for i in range(len(ite... | 0/9 | 0/9 | 0/9 |

Totals:

| | A | B | C |
| --- | --- | --- | --- |
| Positives passing (>= 8/9) | 2 of 11 | 3 of 11 | 5 of 11 |
| Fires on the original seven | 43/63 | 45/63 | 57/63 |
| Original seven passing | 2 of 7 | 2 of 7 | 5 of 7 |
| Fires on the four new phrasings | 10/36 | 18/36 | 0/36 |
| Negative fires | 0/81 | 0/81 | 0/81 |

## What the three runs establish

1. **The control is lower than its 2026-09-07 figure.** C scores the original seven at 5 of 7
   today against 7 of 7 then; `deep review this` and `rigorous review` sit at 7/9 where they were
   9/9. About one fire per query of day-to-day drift, same model, same binary, same procedure.
   Any comparison across days carries that; comparisons within today do not.
2. **The four added phrases dilute the originals.** C to B changes nothing but the phrase list
   and drops the originals from 57 to 45 fires. `is this a good idea` goes 8/9 to 4/9,
   `should we even do this` 9/9 to 5/9, `play devil's advocate` 9/9 to 6/9.
3. **The premise-led opener costs little beyond that.** B to A is 45 to 43 on the originals,
   inside noise. The user's choice to lead with premise framing is not what failed the gate.
4. **The old description never fires on the user's phrasings.** 0 of 36 under C. The trigger
   gap the user named is real and measured, and it cannot be closed by leaving the description
   alone.
5. **Negatives are unaffected by every variant**, including the new near-miss. Bleed toward
   `code-review` and `review-md`, the risk rated likeliest on 2026-09-07, did not appear.

## Variants D and E

D (884 chars) and E (955 chars) test the phrase-budget hypothesis: that dilution scales with the
number of quoted phrases, so the cheapest way to add the user's phrasings is to remove the two
that have no eval cases and were already firing about half the time. D ran 2026-09-09 (1227s,
clean). **E's first run the same evening was void**: 0 of 99 positives and 0 of 81 negatives at
761s, faster per call than every other run, with no `query failed` line and nothing else in
stderr - the all-zero signature `evals/README.md` names, on a run that had been preceded by about
900 serial calls that day. It was discarded (raw copy kept at `/tmp/dr-trigger-n9-variantE-void.out`)
and re-run 2026-09-11 (709s, clean), which is the E column below. A void run with no logged
cause is a fifth false-green mode: the harness scores a silently rejected call as "did not
trigger" and writes a normal results file.

| Expect | Query | C | D | E |
| --- | --- | --- | --- | --- |
| pos | deep review this before I commit it - it's the retry wrapper... | 7/9 | 9/9 | 7/9 |
| pos | ok honest question, is this a good idea? we're thinking abou... | 8/9 | 9/9 | 8/9 |
| pos | poke holes in the migration plan in docs/rfc/0012-multi-regi... | 9/9 | 9/9 | 9/9 |
| pos | should we even do this? spent all morning convincing myself ... | 9/9 | 8/9 | 8/9 |
| pos | play devil's advocate on my plan to move all the team's runb... | 9/9 | 9/9 | 9/9 |
| pos | be critical about this, don't be nice: proposal is to requir... | 8/9 | 9/9 | 9/9 |
| pos | i need a rigorous review of the capacity model in planning/2... | 7/9 | 8/9 | 9/9 |
| pos | does this belong here? i put the retry/backoff logic straigh... | 0/9 | 7/9 | 8/9 |
| pos | is there a better way to do this? current plan is a nightly ... | 0/9 | 0/9 | 3/9 |
| pos | is this the best way to do this - we're thinking of enforcin... | 0/9 | 0/9 | 2/9 |
| pos | does this actually serve its purpose? scripts/health-check.s... | 0/9 | 2/9 | 4/9 |
| neg | can you review this doc for me? docs/onboarding/day-one.md -... | 0/9 | 0/9 | 0/9 |
| neg | review the changes on this branch vs main and tell me if any... | 0/9 | 0/9 | 0/9 |
| neg | proofread the README, i rewrote the install section and want... | 0/9 | 0/9 | 0/9 |
| neg | run a health check on this config repo and tell me what's st... | 0/9 | 0/9 | 0/9 |
| neg | my skill's description isn't triggering reliably - can you l... | 0/9 | 0/9 | 0/9 |
| neg | quick sanity check, does `chmod 755` on a directory mean wha... | 0/9 | 0/9 | 0/9 |
| neg | summarize what this python module does, i inherited it and t... | 0/9 | 0/9 | 0/9 |
| neg | i need to write up the 'alternatives considered and rejected... | 0/9 | 0/9 | 0/9 |
| neg | is there a better way to write this? `for i in range(len(ite... | 0/9 | 0/9 | 0/9 |

Totals:

| | C (control) | D | E |
| --- | --- | --- | --- |
| Positives passing (>= 8/9) | 5 of 11 | 7 of 11 | 7 of 11 |
| Fires on the original seven | 57/63 | 61/63 | 59/63 |
| Original seven passing | 5 of 7 | 7 of 7 | 6 of 7 |
| Fires on the four new phrasings | 0/36 | 9/36 | 17/36 |
| Negative fires | 0/81 | 0/81 | 0/81 |

## What D and E add

6. **Removing "push back on this" and "critique this approach" helps the originals.** D differs
   from C only by that swap and scores the originals higher than the control, 61 against 57,
   with all seven passing. Those two phrases were diluting the description they sat in; they had
   no eval cases since 2026-09-08 and were kept on the theory that keeping them cost nothing.
7. **"does this belong here" is learnable.** 7/9 under D and 8/9 under E, from 0/9 under C.
8. **The two "better way" phrases and "does this serve its purpose" are not, at this
   description shape.** 2/9 to 4/9 under E, the variant that carries all of them. These are
   generic conversational phrasings, and the harness's own caveat applies: the model consults a
   skill only when it judges the task to need one, and "is there a better way to do this" reads
   as a task it can answer directly. Rewording the description is unlikely to move these much;
   they may need a different phrase, or acceptance that they fire at chance.
9. **E's one original miss is day drift, not E.** `deep review this` sits at 7/9 under E and
   7/9 under the control on the same day, and it has been the weakest phrase in every session.
10. **Phrase count is a budget.** Across the five valid variants, fires on the original seven
    track quoted-phrase count: 9 phrases 57 and 61, 11 phrases 59, 13 phrases 43 and 45. The
    opener wording moved the total by about two fires, inside noise.

## Gate status and the open decision

No variant passes the gate as written, because the gate requires every positive at >= 8 of 9
and the three generic phrasings do not reach it under any variant. D and E each pass 7 of 11,
and both are strictly better than the description that was live on 2026-09-08 measured on the
same day (C, 5 of 11), because C scores 0 on every user phrasing.

**Decision, 2026-09-11: variant E**, chosen by the user from D, E, an unmeasured premise-led
variant on E's phrase list, and keeping A. E is now the description in `SKILL.md` verbatim. The
options were: D (all originals pass, one user phrasing near the
line, the other three absent), E (one user phrasing passes, the other two present at chance,
one original at the day's drift level), or a further variant. The regenerated description (A)
was replaced in the working tree by E before anything was committed.

Raw results: `/tmp/dr-trigger-n9-variant{A,B,C,D,E}.out`, description texts at
`/tmp/dr-variant{B,C,D,E}-description.txt`.
