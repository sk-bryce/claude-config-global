<!--
created: 2026-09-11
updated: 2026-09-11
-->

# Deep Review: Dispatch Rationale

Why each parameter in `SKILL.md`'s Dispatch section is set the way it is, and what fails
quietly when one is dropped. The body carries the parameters; this file carries the reasons.
Read it before changing any of them.

## Why dispatch at all, and why not at equal tier

The dispatch buys a tier the caller lacks. Under a `settings.json` `"model": "sonnet"` session
the caller writes the brief at Sonnet and the questions run at Opus. When the caller is already
at Opus the dispatch buys nothing and measurably costs some rigor: in the all-Opus arm table of
`${CLAUDE_CONFIG_DIR:-~/.claude}/evals/runs/2026-09-05-deep-review.md` the dispatching arm scored lowest of the three and
returned fewer findings than a plain inline review. That is why phase 2 folds into phase 1 at
equal tier. Everything else in the body still applies inline: the brief, the questions verbatim,
the output instruction, and the bound.

## Why `subagent_type: "general-purpose"`

The pass must read, search, and judge. A read-only search agent returns locations rather than
judgments, and the narrow implementer types cannot review.

## Why never `subagent_type: "fork"`, and why the frontmatter pin does not cover it

A fork always inherits the parent's model, which silently drops the tier this structure exists
to provide. The `model: opus` frontmatter pin does not cover it either: an unforked pin is not
enforced and is carried for forward compatibility only. The `Agent` call's `model: opus` is what
delivers the tier. Do not remove the dispatch on the theory that the pin does its job.

`context: fork` frontmatter would set the tier correctly but is deliberately not used: a forked
skill's whole body becomes the subagent prompt with no conversation history, and phase 1 and
phase 3 need that history.

## Why foreground (`run_in_background: false`)

A backgrounded dispatch returns control at once. Phase 3 then arrives with nothing to present,
and the pass ends with no findings and no verdict. That is a legal reading of the instructions,
and it fails quietly, because reporting nothing is correct given that state.

## Why exactly one dispatch

`decisions/0008-avoid-parallel-research-fanout.md` argues against cold fresh-subagent
dispatches. The divergence here is deliberate: 0008 measured parallel fan-out of five, where the
cold-start tax multiplies by N, and one dispatch does not multiply. If this skill ever fans out
to several subagents, 0008 applies directly and the design needs revisiting, not a second call.

## Why the prompt assumes nothing is inherited

The subagent cannot see the conversation or the skill body. The global working-style rules were
observed arriving in fresh general-purpose subagents, but nothing in the harness guarantees it,
so anything not in the prompt does not exist for the subagent. Three consequences:

- "Run the deep-review checklist" points into a file the subagent has no reason to open, so the
  questions and granularity rules are inlined verbatim.
- A path suffices only for a file the subagent can read. A claim made in conversation, the
  highest-value case, has no file to fall back on and must be quoted into the prompt, or the
  verdict is about nothing.
- The brief is everything the pass can see beyond the artifact, and the brief ablation found
  that which defects get found is decided by the brief. That is why the body shows the brief
  before dispatching: a verdict reasoned soundly from a mis-stated premise reads exactly like a
  sound one, and phase 3 reproduces it verbatim.

## Why the reviewer validates the brief first

The brief gate is prose judged by the model that wrote the brief, and it has failed quietly in
several shapes. The dispatched reviewer is the only party in the design that sees the brief at
the higher tier before a verdict exists, so it is the one place a second judge can sit. The
check costs a partial dispatch only in the case where the pass should have stopped anyway, and
it does not fan out, so `decisions/0008` does not apply. The failure to watch for is the reverse
one: a reviewer bouncing a brief whose quote does state the need. That is unmeasured.

## Why `ultrathink` and the batching instruction

The `Agent` tool takes no effort parameter, so the `effort: high` frontmatter reaches the
dispatch no more than the `model:` pin does. `ultrathink` in the prompt text is what raises
reasoning depth for the turn. The batching instruction is there because a subagent that
serialises lookups re-bills the accumulating prefix once per turn.
