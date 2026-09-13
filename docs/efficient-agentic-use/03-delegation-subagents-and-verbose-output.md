---
audience: human
created: 2026-07-31
updated: 2026-07-31
---

# Chapter 3: Delegation: Subagents, Forks, and Verbose Output

## In short

- A subagent and a fork are not the same operation wearing two names. A subagent starts from
  nothing: a fresh, isolated context window that never saw your prior conversation, working
  only from whatever self-contained task description you hand it, and returning only a result.
  A fork copies or continues the conversation you already have, inheriting the context (and, on
  at least one harness, the prompt cache) that built up before it branched.
- Confusing the two is the single most common mistake in this area: assuming that "running
  things in parallel" always means subagents that share context, or that opening several
  independent top-level sessions is a form of delegation. Neither is true; each of those has a
  different cost shape.
- Subagents are not an automatic discount. Running several in parallel multiplies total spend
  roughly with their count, since each pays its own setup independently. What delegation actually
  buys is verbose output staying out of the thread you keep re-paying for, cheaper tiers for
  narrow work, and wall-clock parallelism, not a lower floor on the total tokens the underlying
  work requires.
- The habits below cover isolating high-volume output, pinning a cheap tier deliberately, building
  a small reusable set of worker subagents instead of re-deriving delegation every session, and
  tiering review passes (both automated and human) by who actually consumes the result.

This chapter assumes the base vocabulary, agent, subagent, harness, tool use, from
[`docs/generative-ai/` Chapter 4](../generative-ai/04-agents-subagents-harnesses-and-tools.md);
it does not redefine those terms. What follows is specifically about the *cost* consequences of
each delegation choice, which that chapter does not cover.

## The distinction that trips up most people

[`docs/generative-ai/` Chapter 4, Section 2.3](../generative-ai/04-agents-subagents-harnesses-and-tools.md#23-how-results-come-back-reports-not-shared-memory)
already establishes that a subagent reports back a summary rather than handing over its full
working context. The cost-relevant half of that fact, the half this guide adds, is what a
subagent *starts* with, not just what it returns:

- **A subagent begins from a blank slate.** It does not see the orchestrator's prior turns, its
  files already read, or any decisions made so far in the conversation. Everything it needs has
  to be written into the task description the orchestrator hands it at dispatch time. It works
  from that description alone, does its work in its own context, and returns a result. Nothing
  it read or tried along the way rides back with it.
- **A fork begins from the conversation you already have.** It copies or continues the existing
  thread, so it inherits whatever context, files, and decisions already accumulated there. On at
  least one harness a fork also shares the parent's prompt cache, which lowers its effective
  setup cost further still, since the shared portion doesn't need to be reprocessed as new input.
  Appendices A and B cover which harness does this and the exact command that invokes it.

The practical difference shows up the moment you try to skip writing a real task description.
A subagent handed a vague pointer ("look into the thing we were just discussing") has nothing to
resolve that pointer against; a fork handed the same instruction can, because the conversation
it needs is already there. Treating a subagent like a fork produces a worker that either fails
outright or has to re-derive context it was never given, at extra cost, before it can even start
the task you actually wanted done.

The error this most often produces: assuming that dispatching several pieces of work "in
parallel" automatically means several subagents sharing one context, when in fact it can mean
three structurally different things with three different cost profiles, only one of which
shares anything at all:

| What you actually did | What it shares with the original thread | Typical use |
| --- | --- | --- |
| A fork (or equivalent side-chat/branch) | Full inherited context, possibly a shared prompt cache | Continuing work that genuinely needs everything said so far |
| A subagent dispatch | Nothing except what the orchestrator wrote into the task description | Self-contained work, isolating verbose output, cheap-tier routing |
| Several independent top-level sessions | Nothing at all between the sessions themselves | Unrelated work that should not be tangled together in the first place |

That third row is worth sitting with, because it is the one people reach for by accident. Opening
a second, third, and fourth top-level session to "parallelize" unrelated investigations shares
nothing between them: each pays its own full setup cost, with no context-isolation benefit and no
tier-routing benefit either, since nothing was actually delegated, only duplicated.

## A decision rule

- **Needs the current conversation's context** → fork it (or your harness's equivalent
  side-chat/branch mechanism). Nothing else can pick up where the thread left off without
  re-supplying everything already established.
- **Self-contained, and produces a lot of output** (a full test run, a log pull, a broad
  codebase search, a large diff) → dispatch to a subagent on a cheap tier, and ask for a summary
  only. This is the isolation move covered in Habit 1 below.
- **Many independent, self-contained units of work** → one orchestrator dispatching multiple
  subagents, sharing only a minimal common preamble across them rather than each one re-deriving
  the same setup from scratch.
- **Unrelated to the current thread entirely** → clear or start fresh, rather than opening a
  second thread alongside the first. An unrelated question does not need, and should not carry,
  any of the current thread's accumulated context.

Appendices A (`appendices/appendix-a-claude-code.md`) and B (`appendices/appendix-b-cursor.md`)
give the exact command each harness uses to invoke a subagent versus a fork; this chapter only
covers which one to reach for and why.

## The correction worth stating plainly

It is tempting to read "delegate to a subagent" as "delegate to save money." That is only half
right, and the half that's wrong matters. Running several subagents in parallel multiplies total
token spend roughly in proportion to how many you run, because each one pays for its own context
setup independently; three subagents each re-establishing their own working context do not cost
less in aggregate than one agent doing the same three things in sequence, and can cost more once
each one's setup overhead is counted.

What delegation to a subagent actually buys is three specific things:

1. **Verbose output stays out of the thread you keep re-paying to resend.** This is the largest
   effect in practice and the subject of Habit 1 below.
2. **Workers can run at a cheaper model or effort tier than the orchestrator**, because a narrow,
   well-specified task doesn't need the orchestrator's full reasoning budget. This is Habit 2.
3. **Wall-clock parallelism.** Independent subagents can run at the same time instead of in
   sequence, which saves time, not tokens.

None of those three lower the total token cost of the underlying work itself. Generating N
independent units of output costs N units of output no matter how the work is dispatched;
delegation controls which tier does the generating and how much duplicated preamble each unit
pays for, not the floor under the total. Go into delegation decisions expecting a shift in *where*
the cost lands and *how visible* it stays in later turns, not a reduction in the total amount of
work actually being paid for.

## Habits

### 1. Isolate high-volume output in a subagent, return only a summary

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

A full test run, a log pull, a broad codebase search, or a large diff is exactly the case a
subagent is built for: the verbose content gets billed once, inside the subagent's own context,
instead of being resent on every later turn of the main thread for the rest of the session. The
orchestrator only pays for the summary it asked for, not the raw output that produced it. This is
a pure win with no quality tradeoff, because the underlying work still happens in full; only where
its bulk gets billed changes. [Chapter 2](02-turn-session-and-context-discipline.md) covers why a
growing context is costly on every subsequent turn in the first place; this habit is the
delegation-side answer to that same mechanism.

### 2. Pin an explicit, cheap tier on delegated work

> **Impact:** high · **Helps:** Universal (leans hard-cap and seat/pool) · **Quality risk:** none

Left unspecified, delegated work commonly inherits whatever model and effort level the
orchestrator itself is running at, which is rarely necessary for a narrow, well-defined subtask.
Set the tier explicitly at dispatch time instead of letting it default upward. This matters most
under a hard-cap, where every avoided token extends the runway before the reset, and under a
seat or pool, where one person's habit of dispatching expensive workers by default raises the
whole group's burn rate. Appendix C (`appendices/appendix-c-claude-model-family.md`) covers
effort-level gating per model, and Appendices A and B give the exact frontmatter fields each
harness exposes for pinning a subagent's model and effort independently of the orchestrator's.

### 3. Build a small, reusable set of purpose-tiered worker subagents once

> **Impact:** medium-high · **Helps:** Universal · **Quality risk:** none

Re-deriving a delegation decision from scratch every session, what to hand off, at what tier,
with what scope, costs attention even when the tokens involved are small. Building a handful of
narrow, reusable subagents once and reaching for the right one by name is cheaper than working it
out fresh each time. A useful starting set covers three distinct shapes of work:

- A **read-only researcher**: searches, reads, and reports; never edits anything, so it is safe
  to point at a broad or vague question.
- A **mechanical step-executor**: implements a single, fully specified change and refuses to
  guess when a step turns out to be ambiguous, rather than producing a plausible-looking wrong
  answer.
- A **verbose-command runner**: executes a noisy command, a test suite, a log pull, a diff, and
  returns only the failures or a summary, not the raw stream.

Each of these maps directly to the "cheap and mechanical" end of the model-tier spectrum from
Habit 2, which is exactly why building them once pays for itself: the tier decision is made a
single time, at authoring time, instead of re-litigated on every dispatch. Appendices A and B give
concrete frontmatter examples of this pattern for each harness.

### 4. Tier review passes by who consumes the result, not uniformly

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

Not every artifact deserves the same number of review passes. Two passes are enough for anything
you are the sole consumer of: a first pass to produce it, a second to catch what the first missed.
Reserve three or more passes for an artifact someone else will act on unsupervised, a shared
document, a pull request, a config change other people depend on, where an escaped defect costs
more than the extra review did. Within that, scope any pass beyond the first to the delta since
the prior pass, not a full re-read of the whole artifact plus its sibling files; a second pass
that re-reads everything from scratch mostly repeats ground the first pass already covered.

This is quality-preserving, not quality-reducing, precisely because it retargets review effort
toward where it has actual escaped-defect value instead of spreading the same fixed number of
passes evenly regardless of stakes. A solo scratch file and a shared production config do not
carry the same cost if something is wrong in them; reviewing them identically spends the same
budget on both and gets less total defect-catching for it than concentrating the deeper review
where the stakes actually are.

### 5. Use a cheap automated verification pass before a human review

> **Impact:** medium · **Helps:** Universal · **Quality risk:** none

A lower-tier or lower-effort automated pass over a diff, run before a human looks at it, catches
a meaningful share of defects at a fraction of the cost of a second full human-equivalent review
pass. It does not replace human review on anything that matters; it front-loads the cheap,
mechanical catches (an obvious omission, an inconsistency, a broken reference) so the human
review that follows spends its attention on judgment calls instead of on defects a cheaper pass
could have already flagged. Combined with Habit 4's delta-scoping, this keeps the total review
cost proportional to how much actually changed and who is actually depending on the result.

## References

- `docs/generative-ai/04-agents-subagents-harnesses-and-tools.md` - base definitions of agent,
  subagent, harness, and the report-back (not shared-memory) model a subagent's results come
  back through, assumed rather than re-explained in this chapter.
