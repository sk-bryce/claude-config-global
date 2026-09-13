# deep-review brief ablation and self-review - 2026-09-05

Closes the two items the 2026-09-05 gate run left open: the brief-versus-tier confound in the
dispatch experiment, and the fact that the skill had never been run against its own definition.

## Part 1: brief ablation

### Why it was needed

The dispatch experiment recorded in `runs/2026-09-05-deep-review.md` found every arm reviewing at
Opus scoring 3/3 on a pre-registered key and every arm at Sonnet scoring 0/3. That result is what
justifies the `Agent` dispatch. But the winning arm's prompt also supplied a richer brief seed than
the others, so its margin mixed tier with brief quality and the design's central claim rested on a
confounded measurement.

A prior partial observation held that all four brief fields were answerable from the repository
itself, which if true means the gate does not bind on a repo-local target. This ablation therefore
uses a target outside any repository.

### Design

Target: `/tmp/dr-target/proposal.md`, a 36-line self-contained design proposal ("a documentation
staleness daemon") written for this run, in a directory that is not a git checkout and contains
nothing else. The answer key and the rich brief were held in a separate directory the arms were
never given and were instructed not to search.

2x2, four fresh `general-purpose` subagents, foreground, identical checklist text inlined verbatim
in every prompt. Reviewer tier {opus, sonnet} x brief {rich, thin}. "Thin" arms received the
artifact path and the sentence "Context brief: none supplied beyond the artifact path" - the
shallow-brief condition the context-brief gate exists to prevent.

### Pre-registered answer key

Written before any arm ran. An arm scores a defect only for naming the substance.

- **A. Hypothetical problem, no evidence.** Staleness asserted, never counted or exemplified.
  Artifact-derivable.
- **B. The mechanism cannot detect the failure it targets.** Staleness is measured by file
  modification time; the stated failure is docs that are *wrong*. Uncorrelated in both directions,
  and "editing the file is the fix" means a whitespace change clears a wrong page.
  Artifact-derivable.
- **C. A strictly cheaper alternative is unconsidered.** A pre-commit hook and a nightly docs build
  both already exist and already run. Partly artifact-derivable; the brief names both triggers.
- **D. It violates a standing constraint outright.** "No new always-running background processes on
  engineer workstations" is a platform rule; the proposal is exactly that, defaulted on via the
  workstation setup script. **Only derivable from the brief.** This is the discriminator.

Registered prediction: tier drives A/B/C, brief drives D.

### Results

| Arm | A | B | C | D | Verdict returned |
| --- | --- | --- | --- | --- | --- |
| Opus + rich | yes | yes | yes | yes | Do not proceed |
| Opus + thin | yes | yes | yes | n/a | Do not proceed |
| Sonnet + rich | yes | yes | yes | yes | Do not proceed |
| Sonnet + thin | yes | yes | yes | n/a | Reconsider scope |

### What this establishes

**The brief's contribution is real, separable, and exactly where it was predicted to be.** Both
rich arms named the constraint violation and called it disqualifying; neither thin arm mentioned it,
because it is not inferable from the artifact. D behaved as a clean discriminator. This is the
first direct evidence that the four-field brief buys findings no amount of reasoning reaches
without it, which is the premise the hard gate rests on.

**The tier's contribution did not reproduce at the magnitude the earlier experiment reported.**
Both Sonnet arms scored full marks on every artifact-derivable defect. The earlier 3/3-versus-0/3
split, where Sonnet arms "did not just miss, they asserted the opposites", did not recur here.

Tier still separated the arms, but weakly and in two softer places:

1. **Verdict strength.** Three arms returned "Do not proceed"; Sonnet + thin returned "Reconsider
   scope" - one rung softer on the same evidence, which is the direction of drift the skill exists
   to resist.
2. **Depth beyond the key.** Both Opus arms independently found a defect that outranks two of the
   three registered ones and was not in the key: git does not preserve modification times, so a
   fresh clone resets the entire corpus and the build host - the deployment that produces the
   committed report - would report zero stale files forever. Sonnet + rich did not raise it;
   Sonnet + thin gestured at the checkout problem without following it to the build host.

### Correction: the tier reading above is invalid, and the reason was pre-registered

**Written 2026-09-06, after checking this run against the earlier one rather than against memory
of it.** The first draft of this record offered an alternative explanation for the divergence -
that the original tier gap measured prompt completeness rather than reasoning capacity, since the
earlier arms did not all get the checklist inlined. **That explanation is refuted by the earlier
run's own arm table.** `runs/2026-09-05-deep-review.md` Arm B was *checklist inline, Sonnet caller,
Sonnet reviewing context, thin brief* and scored **~0.5/3**. That is the same cell as this run's
Sonnet + thin arm, which scored full marks. Prompt completeness was already held constant there.

The remaining difference between the two cells is the **target and its key**, and the earlier run
named this exact failure mode in advance. Its pre-registered prediction 2 read: "If a Sonnet Arm C
still scores 3/3, the key is too easy to discriminate anything and needs harder defects before any
further arm comparison is worth running. That is the outcome that would invalidate the whole
instrument rather than any one arm." In that run the risk did not materialise. **In this one it
did.** Both Sonnet arms scoring full marks on A/B/C is the registered signature of a key that does
not discriminate, not evidence about tier.

**So: the A/B/C columns of this ablation say nothing about tier, and the earlier 3/3-versus-0/3
result stands unqualified.** The planted defects here are too legible - a proposal that measures
mtime while claiming to measure correctness is a defect a competent reader finds without reaching
for extra reasoning, where the earlier target's defects were structural claims about a scoring
model.

**What survives, and it is the part the ablation existed to test.** D was a genuine discriminator:
both rich arms caught the constraint violation, neither thin arm mentioned it, and no amount of
reasoning recovers a fact that is not in the artifact. That result does not depend on key
difficulty the way the A/B/C columns do. **The brief is load-bearing, on direct evidence, and the
hard four-field gate is justified.**

The two softer tier signals - one rung of verdict softening at Sonnet + thin, and both Opus arms
independently finding the unregistered git-clone defect - are consistent with the earlier result
and are worth noting, but a ceilinged key cannot support weight on them either.

**Consequence for the design: none.** The dispatch stays, on its original justification. The
outstanding follow-up is not "re-run with the checklist held constant" - that was already Arm B -
but **re-run this ablation with a key hard enough to discriminate**, if a tier reading from it is
wanted at all. The brief question, which is what this run was commissioned to answer, is answered.

## Part 2: the skill reviewed by itself

One fresh `general-purpose` subagent at Opus, foreground, given `SKILL.md`, its `specs/skills.md`
section, sibling skills, and a full four-field brief including every prior finding, so it could not
score by rediscovery.

Verdict returned: **Proceed with changes**, with the counter-argument that findings 1 and 6 might
be gaps only on paper, since the review itself arrived with a well-composed prompt.

Eight findings. All four that were independently verifiable were verified before any edit:

1. **The body never says what the dispatch prompt must carry.** The word "prompt" did not appear in
   `SKILL.md` at all. It specified the subagent's type, model, and foreground-ness in detail and
   left the prompt contents unstated, so "run the checklist below" pointed into a file the
   context-isolated subagent cannot see. Worst on the conversation-only target - the skill's
   self-declared highest-value case and the one with no file to fall back on. **Fixed** in body and
   spec: five required prompt contents, with the conversation-target case called out.
2. **The gate's "fails loudly" rationale overstates itself.** Both the gate and the rejected prose
   warning are prose in the same body, judged by the same model; and `run_in_background: false` is
   an equally emphatic prose instruction observed failing silently twice. **Fixed** in the spec by
   correcting the rationale rather than the gate - what earns the gate is naming a specific state
   and stop action, not a categorically harder mechanism.
3. **The spec's trigger accounting was stale.** It said six of ten phrases are enumerated in the
   description and named "push back on this" as the unanchored one to watch. Verified: nine of ten
   are enumerated; only "strong review" is unanchored. A regeneration would have shrunk the
   description back. **Fixed**, with a note not to regenerate on the old accounting.
4. **`effort: high` is inert.** The spec reasons carefully about the unenforced `model:` pin, then
   leaves `effort:` pinned beside it with no delivery mechanism - the `Agent` tool takes no effort
   parameter. **Fixed**: the dispatch prompt now carries `ultrathink`, which is the remedy
   `CLAUDE.md` already names.
5. **Load-bearing guidance living in only one of the two files.** Phase 3's verbatim-verdict rule
   was body-only; "exactly one dispatch per invocation" was spec-only. **Both fixed** into both.
6. **No batching instruction in the dispatch prompt**, which `review-md` states as a rule for every
   dispatch prompt and backs with a measured multi-million-token incident. **Fixed** as part of
   finding 1's prompt-contents list.
7. **Roughly 15 of 169 lines are restatement.** The motivating failure is restated four times and
   the tier argument twice. **Not fixed** - a trim pass is a separate change and the finding is
   recorded rather than acted on here.
8. **An acceptance criterion contradicted two legitimate exits.** "Ends with one of the four
   verdicts" is unconditional, while a user declining the pass and a stop on an unknown brief field
   both correctly end without one - so a harness reading it literally would score a correct gate
   stop as a failure. **Fixed** by scoping the criterion and naming both exits.

## Standing caveat, unchanged

The pre-registered answer key remains a weak instrument. It rewards rediscovering what was already
believed, and this run reproduced the problem exactly: the strongest defect any arm found (the
git-clone mtime reset) was not in the key, and the self-review's most serious finding - an
unspecified dispatch prompt - was not on any prior list either.

## Status

`deep-review` remains at **SHIP**. Both open items from the gate run are now closed: the ablation
ran, and the skill has reviewed itself. Open after this run: the trim pass (finding 7), and the
re-run of the original dispatch experiment with the checklist held constant across arms.
