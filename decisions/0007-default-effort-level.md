---
created: 2026-08-02
updated: 2026-08-31
---

# 7. Default reasoning-effort level

- Status: Accepted
- Date: 2026-08-02
- Deciders: repository owner
- Related: `docs/efficient-agentic-use/05-model-effort-and-batch-tuning.md`,
  `docs/efficient-agentic-use/06-measuring-whether-it-worked.md`,
  `docs/efficient-agentic-use/appendices/appendix-c-claude-model-family.md`,
  `CLAUDE.md` (Subagents & Models), `specs/behaviors.md` (Plan and Execute),
  `specs/skills.md` (skill-author, review-md)

## Context

`settings.json` set `"effortLevel": "high"` globally, for every turn in every project, with no
decision record or spec behind that specific value - `specs/` only ever references
`settings.json` as a hook/statusline registration site, never as the home for the `model` or
`effortLevel` scalars, so this was a hand-set default that had never been written down.

`docs/efficient-agentic-use/05-model-effort-and-batch-tuning.md` states reasoning-effort tokens
are the most expensive lever available and that effort should track task ambiguity rather than
be pinned high as a blanket default. An audit of this repo against that guide surfaced the
undocumented blanket-high default as the one concrete configuration gap the guide's Ch5 speaks
to directly.

Two framings were considered for why this matters, and the first one turned out to be wrong:

- **Cost framing (rejected):** one argument holds that the blanket-high default inflates spend
  and undermines a Cursor-side "share of requests at high-effort tier" measurement. It does not
  hold: that measurement is derived from Cursor's own usage export, and `effortLevel` is
  a Claude Code-only setting Cursor ignores entirely
  (`skills/cursor-projection/references/harness-matrix.md`'s per-harness table). The two are different harnesses with unrelated data sources; a Claude Code setting
  cannot be inflating a Cursor-side metric. Separately, this account carries no Claude Code
  Pro/Max spend cap ("cap n/a" on the statusline), so there is no Claude Code-side dollar
  pressure either.
- **Reasoning-discipline framing (adopted):** the real argument is that effort should track task
  ambiguity per turn, not sit pinned at the ceiling for every trivial turn regardless of
  difficulty. The paths in this repo that genuinely need deep reasoning already pin their own
  effort explicitly and do not depend on the session baseline at all: `write-plan` pins
  `effort: high` ("a wrong plan is expensive to unwind"), `skill-author` pins high so the
  baseline "cannot understate reasoning depth," `Explore` runs Haiku at high, and `review-md`
  already runs at `medium` deliberately, capping reasoning depth for what its own spec calls
  "a bounded checklist, not open-ended judgment" on "a well-specified, repetitive pass."
  Lowering the global default touches none of these; it only changes the floor for everything
  else.

## Decision

Set the global `effortLevel` default in `settings.json` to `"medium"`. Escalate per task via
`/effort` when a specific piece of work is genuinely ambiguous or high-stakes (architecture,
hardware-safety-adjacent debugging, an unusually hard plan), and let it revert once that task is
done rather than becoming a new standing session default - captured in `CLAUDE.md`'s "Subagents
& Models" section as a short **Effort** clause alongside the model-tier escalation ladder. The
two are separate levers (model tier vs. reasoning effort), and both are documented there so
neither is mistaken for the other.

## Consequences

- Every new Claude Code session/turn in every project defaults to `medium` effort unless a
  skill or agent pins its own value (several already do, see Context) or the user runs `/effort`
  for a specific task.
- The setting is Claude Code-only; Cursor has no equivalent persisted setting and runs at
  whatever its own session model implies
  (`skills/cursor-projection/references/harness-matrix.md`).
- Chapter 6's "share of requests at high-effort tier trending up" signal is meaningful on this
  account, because the baseline sits below the ceiling and has somewhere to trend from. It has
  no automated collection path on the Claude Code side; this decision does not add one.
- `CLAUDE.md`'s Subagents & Models section carries one short paragraph for this. Kept to a few
  sentences appended to existing prose rather than a new subsection, consistent with the guide's own
  Ch4 config-hygiene advice to keep the always-loaded instruction file lean.

## Alternatives considered

- **Remove the `effortLevel` key entirely**, falling back to Claude Code's own harness default.
  Rejected: Anthropic's docs (see References) state an unpinned turn's effort varies by model
  version and subscription tier rather than being fixed or predictable - this would trade a
  documented-but-wrong default for an undocumented, unpredictable one, against this repo's general
  preference for explicit values over implicit harness behavior (e.g. tier aliases over frozen
  model slugs).
- **Keep `"high"`, just document the rationale.** Rejected: the cost framing above does not hold,
  and no reasoning-discipline rationale for keeping the ceiling as the default survives
  scrutiny - the paths that need depth already pin it, so the only effect of keeping the
  default high is spending the most expensive reasoning tier on every trivial turn as well.
- **`"auto"` as the default value.** Considered as possibly the most literal reading of Ch5, since
  the `/effort` command's help text lists `auto` as a level. Rejected: Anthropic's own settings
  documentation (see References) confirms `effortLevel` accepts only `low`, `medium`, `high`, or
  `xhigh` - `auto` is not a valid persisted value, only relevant to the interactive `/effort`
  command's own resolution behavior.

## References

- [Settings](https://code.claude.com/docs/en/settings) - Anthropic; confirms `effortLevel`
  accepts only `"low"`, `"medium"`, `"high"`, or `"xhigh"`, verified 2026-08-02 (no `"auto"` or
  `"max"` value documented for the persisted setting).
- `docs/efficient-agentic-use/05-model-effort-and-batch-tuning.md` - source of the
  "effort should track ambiguity, not be pinned high" guidance this decision acts on.
- `docs/efficient-agentic-use/appendices/appendix-c-claude-model-family.md` - documents that fixed
  thinking-token budgets are a no-op on adaptive-reasoning models and that `/effort` is the actual
  dial, and that effort levels are gated per model.
- `skills/cursor-projection/references/harness-matrix.md` - confirms `effortLevel` is a Claude
  Code-only setting that Cursor ignores.
- `specs/behaviors.md` - "Plan and Execute" entry, source of the `write-plan` effort-pin rationale
  quoted in Context.
- `specs/skills.md` - `skill-author` and `review-md` entries, source of the effort-pin rationale
  quotes for those two skills.
