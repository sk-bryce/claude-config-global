---
audience: human
created: 2026-07-31
updated: 2026-09-01
---

# Chapter 2: Turn, Session, and Context Discipline

## In short

- A model is stateless: every request resends everything accumulated so far, and a single
  user-visible turn in an agentic tool can expand into many underlying model calls, one per
  tool-call/result round trip, each resending the growing context. Turn and request count over a
  growing context is the single largest lever on account-limit runway, larger than model choice or
  reasoning effort.
- Most of the habits below cost nothing to adopt: they either remove waste outright or are neutral
  to positive for output quality. None of them trade away correctness the way model or effort
  choices in [Chapter 5](05-model-effort-and-batch-tuning.md) can.
- The common thread is scope: scope the session before you start, scope each question to the files
  that matter, scope re-reviews to what changed, and scope fan-out to subagents under one
  orchestrator rather than several independent top-level sessions.
- A second thread runs through the chapter: protect whatever makes a request cheap to repeat,
  namely a stable, cache-friendly prompt prefix and a session that isn't left compacting or
  re-processing context it didn't need to.

The underlying mechanism, why a request resends everything, what a "turn" actually costs, how
prompt caching makes a repeated prefix cheaper, is not re-explained here; see
[`docs/generative-ai/` Chapter 3: Prompts, Context, Memory, and Caching](../generative-ai/03-prompts-context-memory-and-caching.md)
and the "Turn" glossary entry in
[`docs/generative-ai/` Chapter 1](../generative-ai/01-fundamentals.md#building-and-interacting).
This chapter is entirely about the habits that control it.

## Before you start: budget the turn count

**Decide the turn budget before you start.** Before opening a session, ask explicitly whether the
task in front of you is a five-turn task or a fifty-turn task. A quick config tweak, a one-file
bug fix, and a multi-service refactor are not the same shape of session, and treating all three as
"just start typing and see" is how a five-turn task quietly becomes a fifty-turn one. Scope the
*session* to that estimate, not just the topic: if the task turns out to be much bigger than
expected, that is itself a signal to stop, split the work, and open a new, deliberately scoped
session for the remainder rather than letting one session run long against no plan at all.

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

## Scope what you ask

**Never point an open-ended question at a large or whole context.** Name the specific files,
packages, or services in scope rather than asking a vague question over an entire repository. An
unscoped question doesn't cost one request, it costs one request per file or area the agent
decides to check, and each of those checks carries everything read so far along with it. A
generic illustration: an unscoped question such as "is there anything worth cleaning up on this
branch?", with no repository or files named, can turn one instruction into dozens of tool-call
round trips as the agent opens file after file to answer it, each one resending everything already
read. That pattern, not a long prompt, is how a single exchange can balloon into resending tens of
millions of tokens over its life without anyone ever typing more than a short question.

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

**Use read-only or plan modes for exploratory questions**, before an open-ended "look into this"
turns into an accidental edit-and-verify loop, where the agent makes a change, then reads files
back to check it, then adjusts, each pass adding another full-context round trip. A mode that
can only read and report cannot fall into that loop. The exact command differs by harness; see
[Appendix D](appendices/appendix-d-cheat-sheet.md) for the cross-harness cheat sheet, and
[Appendix A](appendices/appendix-a-claude-code.md) or
[Appendix B](appendices/appendix-b-cursor.md) for the harness you actually use.

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

## Structure work across threads and sessions

**One thread per artifact. Fan out only through subagents from a single orchestrator, never open
several independent parallel top-level sessions on the same work.** Each top-level session cold-
starts independently: its own system prompt, its own tool schemas, its own instruction file, its
own skill catalog, all loaded fresh before the first useful token is produced. If several separate
sessions all work from the same shared context or the same spec, each one pays that entire setup
cost on its own, and none of them share anything they learn with each other, so redundant
exploration happens in every one of them independently. A single orchestrating session that
delegates pieces of the same artifact to subagents pays that setup cost once and can hand each
subagent only the slice of context it actually needs. The correct delegation mechanics, including
the distinction between a subagent and a fork and how to isolate high-volume output, are covered in
[Chapter 3: Delegation, Subagents, and Verbose Output](03-delegation-subagents-and-verbose-output.md);
this habit is the reason that chapter exists.

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

**Start fresh sessions for unrelated work.** When a new task shares no real continuity with what a
session was just doing, clearing the session beats compacting it: compaction is itself a
substantial request that has to read and summarize everything accumulated so far, while starting
clear is close to free. The exact command or setting for clearing versus compacting differs by
harness, and so does what triggers automatic compaction; see
[Appendix A](appendices/appendix-a-claude-code.md),
[Appendix B](appendices/appendix-b-cursor.md), and
[Appendix D](appendices/appendix-d-cheat-sheet.md) for specifics rather than assuming one command
here.

> **Impact:** medium-high · **Helps:** Universal (leans session/time-window) · **Quality risk:** none

**Don't compact reflexively just because you're near the threshold.** When work does have enough
continuity that clearing isn't an option, compacting is still not free: it rereads everything
accumulated so far and pays a resummarize-and-recache cost regardless of what happens afterward.
That cost only earns itself back if enough turns remain in the session to actually run on the
smaller, cheaper context it produces; compacting a session that is about to finish anyway is close
to pure waste, since nothing is left to spend the savings on. Treat an approaching context limit as
a prompt to check how much of the task is genuinely left, not as an automatic trigger to compact
the moment the option appears. `docs/generative-ai/` [Appendix C, Section
3.1](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#31-prompt-and-context-caching)
gives the break-even formula and a worked example for how many remaining turns make it worth it.

> **Impact:** medium · **Helps:** Universal · **Quality risk:** none

## Keep reviews and follow-ups cheap

**Scope re-reviews to the delta since the last pass**, not a re-read of the whole artifact plus its
sibling files. A second look at a document or a diff only needs to reconsider what actually
changed since the first look; re-reading everything around it on every pass resends content that
was already reviewed and found fine, for no additional signal.

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

**Batch follow-ups instead of trickling them across long gaps.** A cached prompt prefix has a
finite lifetime; the first message sent after it lapses has to reprocess the whole context at full
rate, the same cost as if nothing had been cached at all. Grouping several follow-up questions or
edits into one exchange, rather than sending them one at a time with long pauses between, keeps
more of them inside the cache's active window instead of each one paying that reprocessing cost
individually. The mechanism, and the fact that the exact cache lifetime is harness- and
plan-specific, is covered in
[`docs/generative-ai/` Appendix C, Section 3.1](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#31-prompt-and-context-caching);
see [Appendix A](appendices/appendix-a-claude-code.md) and
[Appendix B](appendices/appendix-b-cursor.md) for the specific numbers on your plan.

> **Impact:** medium · **Helps:** Universal · **Quality risk:** none

**Order prompts and instruction content stable-first, volatile-last**, to protect the cache-prefix
hit rate. Anything that changes shape between turns, the specific question being asked, a
timestamp, an identifier, should sit at the end of what gets sent, not the start. A cache only pays
off on the portion of a prompt that stays byte-for-byte identical across requests; putting volatile
content first breaks that match for everything after it, even when the bulk of the prompt didn't
actually change. See the same
[Appendix C, Section 3.1](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#31-prompt-and-context-caching)
for the underlying cache-prefix mechanics.

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

## Correct course immediately

**Cut a wrong direction off immediately** rather than letting it run for several more turns before
course-correcting. The moment it's clear an agent has misunderstood the task or is heading down an
approach you don't want, stop mid-turn and roll back to before that point, rather than arguing with
it across several additional turns trying to talk it back onto the right path. Each of those
argument turns resends the same growing, now partly-wrong context, so the cost of correcting late
compounds with every turn spent trying first. See
[Appendix D](appendices/appendix-d-cheat-sheet.md) for the exact undo or rewind command in your
harness.

> **Impact:** medium · **Helps:** Universal · **Quality risk:** none

## References

- `../generative-ai/03-prompts-context-memory-and-caching.md` - the mechanism behind why every
  request resends accumulated context, and how prompt caching changes what gets billed for it.
- `../generative-ai/01-fundamentals.md` - Chapter 1's glossary, including the "Turn" entry
  describing how one user-visible turn can expand into many underlying model calls.
- `../generative-ai/appendices/appendix-c-costs-and-getting-value.md` - Section 3.1 covers
  prompt and context caching mechanics referenced above for batching follow-ups and cache-friendly
  prompt ordering, plus a break-even formula for when compacting pays for itself versus carrying
  context forward uncompacted.
