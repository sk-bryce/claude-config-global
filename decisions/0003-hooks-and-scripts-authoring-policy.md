---
created: 2026-07-26
updated: 2026-08-31
---

# 3. Hooks and scripts authoring policy

- Status: Accepted
- Date: 2026-07-26
- Deciders: repository owner
- Related: `decisions/0001-adopt-spec-driven-config-architecture.md`, `scripts/sync.sh`,
  `decisions/0002-plan-and-execute-framework.md`

## Context

Hooks run shell on lifecycle events, often with full user permissions, on every future session,
and a hook activates on the next session or tool call - before any commit review. Install and
sync scripts also run with the user's permissions, but only when invoked, so they do not execute
merely by being written to disk. Models produce subtly wrong shell (quoting, missing
`set -euo pipefail`, unguarded destructive paths) even absent an attacker, so unreviewed shell is
the real hazard.

Two properties actually contain that hazard: nothing runs before a human has reviewed it, and no
lifecycle hook is activated without a human deciding, in that moment, that this specific
registration should happen. Everything else - the bulk of the writing - can be model-generated,
because this repository is reviewed in full before commit.

The safety property is the contemporaneous human decision to activate, not the mechanical act of
typing. A model that writes a registration the user just, explicitly told it to write is the same
guarded action as a human typing it themselves: a human decided, in the moment, that this
registration should exist. What the guard rules out is the model registering a hook on its own
initiative - proactively, inferred from a broader request, or because a similar one was registered
before - since that is the case where a hook could activate before anyone reviewed it.

## Decision

Scripts and hook logic may be model-generated; hook registration requires the user's explicit,
in-the-moment direction each time; everything is reviewed before commit or use.

- Scripts (`scripts/*.sh` including `scripts/sync.sh`, and script data such as
  `scripts/mcp-servers.json`) may be model-generated directly into the working tree. They do not
  execute on write, and the full diff is reviewed before commit.
- Hook logic (the shell a hook runs) may likewise be model-generated as a `scripts/` file,
  reviewed before commit.
- Hook registration - the entry that activates a hook (`settings.json` hooks or a skill's `hooks`
  frontmatter) - may be written by the model into the live location, but only when the user has
  just explicitly directed that specific registration. It is
  never done proactively, as an inferred step of a broader request, or on the strength of a prior
  registration having gone the same way - each one needs its own explicit go-ahead in the moment.
  Absent that explicit instruction, the model may only draft the registration as a reviewed diff,
  since an unrequested registration would activate before any commit review.

The read-only enforcement `PreToolUse` hook referenced by the plan-and-execute framework (ADR 2)
follows this rule: its shell logic may be model-generated, its registration requires the same
explicit, in-the-moment user direction.

## Consequences

- The bulk of the mechanical authoring (`sync.sh`, hook logic) is model-generated and then
  reviewed before commit, which is faster than hand-writing while preserving review.
- The activating step for any hook stays a deliberate, explicit human decision made in the moment
  - whether the human's own hands type it or the model does, under that direction - so no hook
  activates from a standing permission, an inference, or precedent, and no unreviewed shell runs
  on a lifecycle event without that decision having just been made.
- Shared hook logic lives in `scripts/` and is registered via thin wrappers; the wrappers are
  model-generated, the registrations require the user's explicit in-the-moment direction.
- A model-performed registration made under that explicit direction is the compliant path, not
  an exception to it, and is not logged as a deviation.

## Alternatives considered

- Hand-author everything (a model may only propose a diff, never write into place). Rejected as
  unnecessarily strict for a personal repository whose full diff is reviewed before commit: it
  slows the common case (scripts and hook logic) without adding safety beyond the
  review-before-commit and explicit-direction guards.
- Fully autonomous authoring, including hook registration without being asked. Rejected: a
  registered hook activates before any commit review, so a model registering one on its own
  initiative - proactively or by inference - could run unreviewed shell on the next tool call.
- Requiring the human's own hands to type every registration, with no model-performed path even
  under explicit direction. Rejected: it conflates two different things, who operates the
  keyboard and who decides. The safety property this decision protects is the latter; requiring
  the former adds friction to an already-reviewed, already-directed action without containing
  any additional hazard.

## References

- `reference/spec-driven-architecture.md` - Anti-patterns section.
