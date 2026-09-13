---
created: 2026-09-01
updated: 2026-09-02
---

# Model Selection, Effort, and Delegation Shape

The mechanics behind `CLAUDE.md`'s Subagents & Models section. That section states the decisions
that have to be made without a lookup - default to Sonnet, escalate one tier once, keep research
inline, prefer forks, never parallel-dispatch `researcher`; this file carries the detail behind
each one, including the parts (the tier fit criteria, the effort mechanics, the skill-body tier
statement) that are lookup rather than decision. Read it when choosing a model for an Agent-tool
subagent, pinning `model:` or `effort:` on a skill, or deciding delegation shape.

Scope is the choosing layer only. The generic orchestrator-and-workers protocol - dispatch,
verification gates, halt-vs-escalate, commit policy - is `reference/subagent-orchestration.md`,
which is the file a plan embeds. This one is never synced into a skill's `references/`.

## Naming tiers

Refer to tiers as Opus, Sonnet, and Haiku, and name each by its `opus` / `sonnet` / `haiku` alias
at dispatch time. Prefer an alias over a frozen version slug unless a plan or the user names one:
a slug pins a model that will eventually be retired, where an alias follows the tier.

State the intended tier in a skill's body as well as its frontmatter. A harness that drops the
`model:` pin (Cursor does - see `skills/cursor-projection/references/harness-matrix.md`) still
reads the body, so guidance stated only in frontmatter is silently lost there.

## The tiers

**Default: Sonnet.** Use it unless the work clearly fits Opus or Haiku.

- **Sonnet** (workhorse): implementation, code generation, tests, routine PR or checklist review,
  multi-hop exploration/search that needs synthesis, executing an already-written plan (dispatch,
  verify, light orchestration).
- **Opus** (premium; wrong-first-time is expensive): architecture, ambiguous or high-stakes
  planning, designing multi-agent plans, security or other judgment-heavy reviews, hard debugging
  after Sonnet failed or the bug is clearly cross-cutting.
- **Haiku** (fast/cheap volume): formatting, narrow grep-and-summarize, fully prescriptive edits
  with exact paths and diffs spelled out.

## Escalation

On mechanical failure or a weak result, bump one tier once and retry the same task. On genuine
ambiguity, stop and ask the user - do not reach for a bigger model to guess, because a stronger
model guesses more convincingly rather than more correctly. After an escalation succeeds, return
to the prior tier for later tasks unless they also need it.

## Effort

Effort is a separate axis from the tier ladder above, and the default is deliberately moderate -
see `decisions/0007-default-effort-level.md`.

There is no reliable interactive way to bump effort for one task without it persisting. `/effort
<level>` and the effort slider inside `/model` both save `low`/`medium`/`high`/`xhigh` as the new
default once set in an interactive session, regardless of pressing `s` instead of Enter - that
distinction governs only the model field, not the effort value alongside it. So:

- **One task, session-only:** launch a fresh session with `claude --effort <level>`. This is the
  one path Anthropic documents as session-only and not saved.
- **Interactive bump:** accept that it persists, and set it back by hand once the task is done.
- **`max` and `ultracode`:** already scoped to the current session by design, so escalating to
  either needs no revert step. (`max` is an effort level; `ultracode` is the multi-agent
  workflow-orchestration toggle - different things.)
- **One deep-reasoning turn:** add `ultrathink` to the prompt. It asks for more reasoning within
  whatever level is already active rather than changing the level, so there is nothing to revert.

Full mechanics and the vendor citations behind them:
`docs/efficient-agentic-use/appendices/appendix-a-claude-code.md` Section 4.

## Dispatch

Subagent calls batch the same as any other tool call (see `CLAUDE.md`'s Working Style, "Batch
independent tool calls"): send independent ones in a single message, run dependent tasks
sequentially.

## Delegation shape: fork vs. fresh subagent

Fork for work that continues or extends the current conversation (reviewing what was just done,
extending an audit already run) - it inherits that context and shares the prompt cache, where a
fresh subagent starts cold and needs everything rebuilt through a briefing.

Dispatch a fresh subagent when independence is the actual point - an adversarial check or second
opinion meant to catch a blind spot a fork would inherit and repeat - or when the task needs a
tool or permission scope the current context does not hold.

A backgrounded fork cannot pause mid-run for a blocking confirmation; its only output is a single
final report delivered once it exits. Keep a fork in the foreground whenever it may need to ask
something before finishing. Full guidance:
`reference/subagent-orchestration.md`'s Delegation shape section.

## Research fan-out

For research-heavy documentation work, default to direct WebSearch/WebFetch in the current
context rather than delegating; the `research` skill loads the full workflow automatically.

When a topic genuinely needs isolation and splits into independent sub-questions, prefer parallel
`Agent` forks (`subagent_type: "fork"`) over fresh subagents, which each re-pay their system
prompt and tool definitions as a cache miss with no sharing between them.

Reserve the `researcher` subagent (`agents/researcher.md`) for when forking is a poor fit - a need
to keep the work off this context's full history and tools - and dispatch it one at a time, never
in parallel. That is a scope decision, not a cost one: within any reachable session size a fork
does not lose to a fresh subagent on cost, so session size alone is never the reason to prefer
`researcher`. The measurement is in `decisions/0008-avoid-parallel-research-fanout.md`; the full
protocol is `reference/research-discipline.md`.
