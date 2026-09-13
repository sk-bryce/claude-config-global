---
created: 2026-09-08
updated: 2026-09-08
---

# deep-review gate generalization fix, 2026-09-08

This run follows `evals/runs/2026-09-08-deep-review-gate-verification.md`, which established that
the brief-completeness gate held on eval 9 (4/4) and failed entirely on eval 11 (0/4) - an
identically-shaped fixture `SKILL.md` did not name. This record covers the fix for that finding
and the matched-pair re-run that verifies it.

It is a **two-eval matched pair**, not a suite re-run. The readiness run's headline figures
(deterministic 21/25, judgment 14/14, describing the ten-eval suite before eval 11 existed) are
NOT superseded by anything here. No trigger run happened; the trigger picture is unchanged.

## The diagnosis

Two defects in the gate text, both introduced by the wording the readiness plan prescribed:

1. **The self-check blessed the wrong source.** It asked which of the four fields were filled
   "from the target or the conversation" versus from a guess - naming the target as a legitimate
   source for all four. For Purpose specifically, the target is the forbidden source: an
   artifact cannot state what someone needed it to do.
2. **The failure test keyed on hedge words.** A guess was defined as anything you would introduce
   with "presumably", "probably", "it looks like". A confident code paraphrase ("this script
   rotates the log files and deletes the old ones") carries no hedge and so evaded the test
   entirely - which is exactly what eval 11 produced.

The named worked example (`cache-warmer.py`) then did the remaining work: the eval 9 run
recognized its own fixture in the skill body and complied, while eval 11 had nothing to match.

## The fix

The passage was rewritten to remove both defects and the filename:

- The self-check now asks, per field, whether the answer came from **the prompt, the
  conversation, or the artifact itself**, and states that for Purpose only the first two count.
- It states the general rule the worked example was meant to illustrate: **"Purpose is not what
  the artifact does. It is what someone needed it to do."**
- Three failure modes are named, all observed: restating behaviour, guessing from the artifact's
  shape, and proceeding with a caveat. None names a file.
- It closes with an anti-exemption clause: reasoning that some specific target is the one the
  rule was written about is itself the failure.

Verified before the re-run: `grep -c "cache-warmer\|rotate-logs" skills/deep-review/SKILL.md`
returns **0**. Neither fixture is named in the skill, so the pair is a fair test. The
frontmatter `description:` was not touched, so the trigger figures are unaffected.

## Matched-pair result

Both evals re-run at Sonnet, `with_skill` arm only, against neutral `/tmp/dr-fixtures/` paths,
each contamination-checked for an answer-key read before grading (both clean, 0 references).

| Eval | Fixture | Named in SKILL.md | Before | After |
| --- | --- | --- | --- | --- |
| 9 | `cache-warmer.py` | no longer (was) | 4/4 | 4/4 |
| 11 | `rotate-logs.sh` | never | 0/4 | 4/4 |

Eval 11's run read the script, checked the directory, git, and adjacent docs for context, found
none, named Purpose as the unfillable field, dispatched no subagent, labelled its findings
"preliminary, code-only read" and explicitly disclaimed a verdict, and ended by asking what it
needed. Eval 9 held on all four with the named example gone.

## What this does and does not establish

It establishes that the gate now fires on a fixture the skill has never seen named, and that
removing the worked example did not cost the case the example was written for. That is the
generalization claim the previous run showed to be false, now shown to hold on the one
additional shape tested.

It does not establish a suite score, and two fixtures is a narrow base: both are bare
context-free files in an empty directory. The gate is untested against a target that has *some*
surrounding context which is nonetheless insufficient for Purpose - the more common real case.

## Decision

HOLD (unchanged). The generalization defect that motivated the previous run's additional HOLD
reason is fixed and verified. The readiness run's HOLD stands on its other grounds: eval 2 still
answers its own question alongside asking it, eval 1 remains non-discriminating under this
harness, and the trigger figure is still a rescoring rather than a measurement.
