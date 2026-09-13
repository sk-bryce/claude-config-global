---
audience: human
created: 2026-07-31
updated: 2026-08-31
---

# Chapter 4: Configuration Hygiene

## In short

- Chapters 2 and 3 were about what you do inside a session. This chapter is about what you set up
  once so that good behavior is the default, not something you have to remember every time.
- Everything here is low-effort relative to its payback, and none of it trades away output
  quality: it's waste elimination and visibility, not a tuning knob.
- The two biggest items are shrinking the always-loaded instruction file and ordering it so the
  stable parts sit first; the rest, status-line visibility, hook cost-awareness, and
  project-versus-personal defaults, are smaller but still worth doing once and forgetting.

## Keep the always-loaded instruction file small

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

Your CLAUDE.md/AGENTS.md-equivalent instruction file is not read once at the start of a
conversation and then set aside. It is loaded and billed on every single turn, regardless of
whether anything in it is relevant to the task in front of you. A hundred extra lines of
instructions that apply to one task in twenty still get resent, and re-billed against your
context, on the other nineteen.

The practical filter: is this entry a standing *fact or rule* ("commits need a linked ticket
number", "this repo uses tabs"), or is it a multi-step *procedure* ("here's how to cut a release",
"here's the five-step process for rotating a credential")? Facts and rules belong in the
always-loaded file because they're short and apply broadly. Procedures belong in an on-demand
skill or rule instead, something that only loads into context when a task actually invokes it.
The content isn't lost by moving it; it's just made conditional on being needed, instead of paid
for on every turn whether needed or not.

This is the single highest-leverage item in this chapter because it compounds silently. A
procedure sitting in the always-loaded file doesn't fail loudly, it just adds a small, invisible
tax to every request for as long as the file exists, which for a personal instruction file is
typically the lifetime of your account.

## Order the instruction file stable-content-first

> **Impact:** high · **Helps:** Universal · **Quality risk:** none

Once the file is small, order still matters. Put facts and rules that never change, naming
conventions, standing policies, tone preferences, at the top. Keep anything volatile, a
timestamp, today's date, a per-run detail, out of the always-loaded file entirely, or if it must
appear somewhere in context, push it as late as possible rather than at the top.

This is the same prefix-cache mechanism [Chapter 2](02-turn-session-and-context-discipline.md)
covers for ordering a single turn's prompt, applied here to the instruction file instead: a stored
prefix is matched against what you send next, and the match breaks at the first byte that differs.
A single volatile line sitting near the top of an otherwise-static file invalidates the cache for
everything that follows it, every single turn, turning what should be a one-time cost into a
recurring one. The full mechanism, and what it's worth in practice, is covered in
[`docs/generative-ai/` Appendix C, Section
3.1](../generative-ai/appendices/appendix-c-costs-and-getting-value.md#31-prompt-and-context-caching);
this chapter isn't re-deriving that math, just telling you where in your own file it applies.

In practice this means: rules and facts first, anything environment- or session-specific last,
and nothing that changes between turns anywhere the cache would have to re-match against it.

## Make context growth visible while you're deciding whether to keep going

> **Impact:** medium-high · **Helps:** Universal · **Quality risk:** none

The habits in Chapters 2 and 3, budgeting turns, scoping questions, forking off verbose output,
all depend on you noticing context is growing before it's already a problem. Left to its own
devices, that growth is invisible: nothing in a normal session tells you how full the context
window is or what the session has cost so far unless you stop and ask.

A status line that surfaces context-used percentage and running session cost turns that into an
ambient signal instead of a question you have to remember to ask. It's one of the cheapest
behavior-change levers available precisely because it doesn't ask you to do anything differently;
it just makes the number you'd otherwise have to hunt for sit in view the whole time, so the
decision to fork a subagent, close a thread, or start fresh happens at the moment it's cheap
instead of several turns after it would have been.

Concrete configuration for wiring this up lives in the harness appendices, not here: [Appendix A](appendices/appendix-a-claude-code.md)
for Claude Code, [Appendix B](appendices/appendix-b-cursor.md) for Cursor.

## Be deliberate about hook cost

> **Impact:** medium · **Helps:** Universal (leans hard-cap) · **Quality risk:** none

A hook wired to fire on every file edit re-runs its full cost, a network call, a serial check, any
verbose output that gets injected back into context, on every single edit of that session, not
once per session or once per file. If a check produces output only meaningful at the very end of
a task, running it on every intermediate edit buys nothing but repeated cost.

The fix is to match the hook's trigger to when its answer actually needs to be seen, not to when
it's technically possible to run it. A check whose result only matters once work is done belongs
on an end-of-loop or stop-style event instead of a per-edit event. A check that's about a specific
file rather than the edit itself can be gated to fire once per file per session instead of every
time that file changes. Neither of these changes what the check catches, only how often it's paid
for; a case worth naming concretely is link-rot in a document, which does not appear or disappear
between two edits made seconds apart, so re-checking it on every edit is pure waste with no
corresponding safety gained. This is why the tag above leans toward hard-cap: a hard-cap account
pays for every one of those repeated fires out of the same finite pool, where a session-window
account mostly just refills sooner.

The exact hook-event names and how to scope a hook to first-touch-per-file differ by harness; see
[Appendix A](appendices/appendix-a-claude-code.md) and [Appendix B](appendices/appendix-b-cursor.md)
for the concrete mechanics, and `skills/cursor-projection/references/harness-matrix.md` as the mechanical source of truth
those appendices draw from.

## Set the default where the work happens, not where the person is

> **Impact:** medium · **Helps:** seat/pool · **Quality risk:** none

On a shared codebase, a project-level default for model and reasoning-effort tier matters more
than any individual's personal default, because the project default is what applies to everyone
touching that repo regardless of what they'd otherwise pick for themselves. Relying on each
person's personal default to happen to match what the routine work in that repo actually needs is
relying on coincidence; a handful of people defaulting one tier higher than the work calls for is
exactly the kind of diffuse overspend that a shared pool absorbs quietly until someone notices the
burn rate.

Set the default at the project level to match the tier the routine work in that repo actually
needs, and let any individual opt up for a specific task that warrants it. That keeps the common
case cheap by default while leaving the escalation path open for whoever actually needs it, rather
than making everyone carry a personal habit of remembering to opt down.

## Keep a budget-mode override handy, but don't make it a default

> **Impact:** low-medium · **Helps:** hard-cap · **Quality risk:** none

For bulk mechanical work, batches of near-identical, low-judgment edits, a session-scoped override
that forces every delegated worker onto the cheapest available tier for that session is worth
having on hand. It's the kind of thing you reach for deliberately when you already know the task
ahead of you is repetitive and low-risk, not something that should quietly become how every session
runs.

The distinction that matters is persisted default versus explicit, occasional choice. A permanent
downgrade risks degrading quality on the work that actually needed a higher tier, silently, since
nothing tells you a task needed more until the output is already wrong. An override you flip on for
one batch and back off afterward gets the savings on the work that genuinely doesn't need
judgment, without carrying that tradeoff into the next session by accident. This matters most
under a hard-cap, where the whole point is stretching a fixed pool across more days, and matters
least under a metered account, where Chapter 6's ongoing spend visibility will catch a bad default
quickly regardless.

## References

- `docs/generative-ai/appendices/appendix-c-costs-and-getting-value.md` - prompt-caching mechanics
  (Section 3.1) behind the stable-content-first ordering rule above.
- `skills/cursor-projection/references/harness-matrix.md` - mechanical source of truth for harness-specific settings keys,
  hook event names, and status-line configuration referenced throughout this chapter.
