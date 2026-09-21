---
created: 2026-09-12
updated: 2026-09-21
---

# Rule Specs

Always-on rules: intent and acceptance criteria for behavior delivered as a `CLAUDE.md` section
or bullet rather than as a skill, hook, or script. Sections here appear in the same order as the
rules they specify appear in `CLAUDE.md`. Capabilities that span more than one artifact live in
`specs/behaviors.md`; design decisions and their rationale live in `decisions/`.

This file is deliberately not exhaustive. Most `CLAUDE.md` rules have no entry here and need none:
`CLAUDE.md` is hand-maintained rather than regenerated from a spec, so a self-explanatory bullet
gains nothing from a second copy that must be kept in sync by hand. An entry earns its place when
the rule's shape was contested - when there is a rejected alternative worth recording, a scope
boundary that is easy to overshoot, or a known limitation a later reader would otherwise rediscover.
A bullet with no entry below is presumed uncontested, not undocumented.

---

## Incoming Claims

- Purpose: extend verification discipline to claims the agent receives rather than ones it makes.
  Delivered as an always-on `CLAUDE.md` bullet ("Incoming claims need checking too") under Working
  Style, because the failure it targets - repeating a tool result, a subagent finding, or a doc
  statement as established fact - happens in ordinary turns that never name a skill. Authored
  2026-09-12 after the user asked whether global rules for skepticism and questioning assumptions
  were worth adding; the general versions were declined and this narrow case was the one gap the
  existing rules did not already cover.
- Shape: one bullet, placed directly after "Verify before claiming" and deliberately paired with
  it. That bullet governs assertions the agent makes about the environment ("this file exists",
  "this config is set"); this one governs assertions arriving from elsewhere. The rule names the
  three sources (tool output, subagent reports, documentation), gives one trigger
  ("load-bearing for your next action or statement"), and gives two acceptable exits: confirm it
  against the file, command, or source, or attribute it rather than asserting it.
- Why not a general skepticism rule: "be skeptical" or "question everything" is a disposition, not
  a behavior. It has no trigger and no stopping rule, so there is nothing for a draft to be checked
  against, and the tone it produces is more hedging and more re-litigation of settled decisions -
  which fights Response Style's "Cut hedges" and the harness instruction to act once there is
  enough information. Naming the sources and the trigger is what makes this version checkable.
- Scope boundary: the load-bearing qualifier is what bounds the cost. It must not become a rule to
  re-run every command, re-read every file a subagent read, or re-verify output that nothing
  downstream depends on. Attribution is a full-price exit and not a lesser one: saying "the agent
  reported X" discharges the rule completely, which is what keeps it affordable on a turn where
  verification would be expensive.
- Relationship to the harness: the Claude Code system prompt already warns against taking subagent
  results at face value. That text is outside this repo, can change without notice, and covers only
  subagents. This bullet states the same discipline in owned content and extends it to tool output
  and documentation, which the harness sentence does not reach.
- Known limitation (accepted, not solved): the same gap as "Reviews Take a Position" and "Response
  Style" - `scripts/health-check.sh`'s spec-coverage check does not reach individual `CLAUDE.md`
  bullets, so nothing mechanically detects this entry drifting from the bullet it specifies. The
  pairing is maintained by hand.
- Acceptance criteria:
  - A subagent report or tool result that determines the next edit is confirmed against the file or
    command before that edit is made.
  - A claim taken from a doc or an agent and passed to the user unverified is attributed to its
    source rather than stated flatly.
  - Output that nothing downstream depends on is not re-verified, and no command is re-run purely
    to satisfy the rule.
  - `CLAUDE.md` and this entry agree on what the rule requires; a change to either lands in the
    same commit as the change to the other.
- Testing gate: not opened, for the same structural reason as the other entries in this file - an
  always-on bullet has no invocation to observe, so there is no trigger set and no behavioral
  suite. This entry and its acceptance criteria are the only check, and neither is mechanical. The
  bullet it specifies shipped in the 2026-09-12 commit "Add a Working Style rule for verifying
  incoming claims" without this entry, violating the last acceptance
  criterion at authoring time; the follow-up commit is the correction, not the intended pattern.

---

## Reviews Take a Position

- Purpose: make a review commit to a judgment rather than list observations. Delivered as an
  always-on `CLAUDE.md` bullet ("Reviews take a position") under Working Style, not as an invoked
  skill, because the failure it targets - a review that reports surface issues and defaults to
  agreement - happens in ordinary review turns that never name a skill. The `deep-review` skill is
  the full premise-level version of the same idea; this rule is the floor that applies when the
  skill does not fire.
- Shape: one bullet, adjacent to "Proofread before finishing" and deliberately distinguished from
  it. That bullet governs checking your own output before handing it over; this one governs
  reviewing an artifact, plan, or idea on request. The rule asks for four things and stops there:
  say whether the thing is worth doing, name at least one concrete alternative (including doing
  nothing) when the answer is unclear, state the assumptions it rests on, and prefer a specific
  falsifiable objection to a hedge. It points at `deep-review` for the full pass with a verdict.
- Scope boundary: "beyond a narrow mechanical check" is the qualifier that keeps it off a requested
  proofread, a lint pass, or a formatting fix. A rule that fires on every mechanical check would
  convert a requested one-line correction into a posture, which is the main risk of stating it
  always-on rather than in a skill.
- Relationship to the skills: it must not duplicate `deep-review`, `review-md`, or `code-review`.
  It states the general principle and names `deep-review` for the full version; it does not carry
  the ladder, the context brief, or the dispatch. Keeping the verdict machinery out of `CLAUDE.md`
  is what keeps the always-on cost to a few lines.
- Known limitation (accepted, not solved): `scripts/health-check.sh`'s spec-coverage check does not
  reach individual `CLAUDE.md` bullets, so nothing mechanically detects this entry drifting from
  the bullet it specifies. The pairing is maintained by hand, the same way the rest of this file is.
- Acceptance criteria:
  - A review of a substantive artifact states whether the thing is worth doing, rather than only
    listing defects found.
  - A requested narrow mechanical check - proofread, lint, format, a one-line correctness question
    - is answered as asked and does not acquire a worth-doing verdict it was not asked for.
  - The bullet names at least one concrete alternative, including doing nothing, only when the
    worth-doing answer is genuinely unclear, rather than manufacturing an alternative on every
    review.
  - `CLAUDE.md` and this entry agree on what the rule requires; a change to either lands in the
    same commit as the change to the other.
- Testing gate: not opened. No eval set covers this rule, and the always-on bullets in `CLAUDE.md`
  have no eval layer at all - unlike a skill, there is no trigger set and no behavioral suite,
  because there is no invocation to observe. Authored 2026-09-07 after a `deep-review` pass found
  that the branch adding this rule shipped the widest-blast-radius change in it with no spec entry,
  no acceptance criteria, and no eval. The spec entry and the criteria above close two of those
  three; the eval gap is real and stays open.

---

## Response Style

- Purpose: temper response verbosity and phrasing globally. Delivered as an always-on `CLAUDE.md`
  section ("Response Style"), not as a skill, because the failure it targets - preamble, hedging,
  narrated tool calls, and a closing recap of what was just said - happens in ordinary turns that
  never name a skill and cannot be triggered on. Authored 2026-09-12 after the user reported that
  Opus in particular runs long and reads as hard to follow.
- Shape: five bullets, placed between Working Style and Output Formatting because it governs the
  conversational reply while Output Formatting governs a produced artifact. Each bullet names a
  specific habit rather than asking for concision in the abstract: answer first with no preamble or
  recap; short sentences and plain words over precise-sounding ones; state the thing instead of
  sprinkling hedges, flagging real uncertainty once and plainly; do not narrate work the tool calls
  already show; length proportional to the question, prose rather than bullets under roughly five
  points, no headings in a short reply.
- Why named habits rather than "be concise": an abstract instruction gives the model nothing to
  check its own draft against, and "concise" competes badly with a system prompt tuned toward
  thoroughness. A habit is checkable - a preamble is either present or not.
- Scope boundary: it governs the reply, not the work. It must not become a reason to skip
  verification, drop a caveat the user needs, truncate a genuinely long answer, or compress a
  produced document. "Length matches the question" cuts both ways: a question that needs a long
  answer gets one. Where this rule and honest reporting conflict, honest reporting wins - the
  "Report honestly" bullet under Working Style is not subordinate to this section.
- Relationship to the alternative not taken: an output style file (`output-styles/*.md`, selected
  with `/output-style`) is the stronger lever, because it edits the harness system prompt rather
  than competing with it from user content. It was declined on 2026-09-12 because it replaces
  built-in system prompt sections and can silently drop default behavior. Revisit it if the
  always-on section proves insufficient in practice; that is the documented fallback, not a
  rejected idea.
- Known limitation (accepted, not solved): the same gap as "Reviews Take a Position" -
  `scripts/health-check.sh`'s spec-coverage check does not reach individual `CLAUDE.md` sections,
  so nothing mechanically detects this entry drifting from the section it specifies. The pairing is
  maintained by hand.
- Acceptance criteria:
  - A factual question is answered in a sentence or two, without a restatement of the question or
    a summary of the answer just given.
  - A reply reporting completed work states what changed and what it means, without a step-by-step
    account of the tool calls already visible in the transcript.
  - Uncertainty appears once, named concretely ("I did not verify X"), rather than as repeated
    qualifiers spread through the prose.
  - A question that genuinely requires a long answer still gets one; brevity never costs a caveat,
    a failure report, or a verification step.
  - `CLAUDE.md` and this entry agree on what the rule requires; a change to either lands in the
    same commit as the change to the other.
- Testing gate: not opened, for the same structural reason as "Reviews Take a Position" - an
  always-on bullet has no invocation to observe, so there is no trigger set and no behavioral
  suite. This entry and its acceptance criteria are the only check, and neither is mechanical.

---

## No Co-Author Text

- Purpose: keep every commit message and PR description free of a `Co-Authored-By` trailer, and
  make that rule win against the attribution reminder Claude Code injects into a session. Delivered
  as an always-on `CLAUDE.md` bullet under Git & GitHub. Authored 2026-07-22 as a one-line Working
  Style bullet; rewritten and moved 2026-09-21 after it failed in practice.
- Why it was rewritten: the original read "Never add Co-Authored-By text to any content unless
  explicitly asked" and sat in Working Style among generic craft habits. The harness reminder that
  asks for the trailer also claims the user's own instructions take precedence, and the model still
  followed the reminder: 22 commits in a downstream repository took the trailer across at least two
  separate sessions before anyone noticed, and removing it needed a history rewrite. The bullet was
  being read as a default the reminder overrode rather than as an override of the reminder.
- Shape: one bullet, moved from Working Style to Git & GitHub and placed directly after "Commit or
  push only when asked", so it sits where an agent is already reading when it composes a commit.
  It names the artifacts (commit message, PR description, anything else), names the only thing that
  counts as consent (the user explicitly asking), states that a session, system, or harness
  attribution reminder is not that consent "whatever it instructs", and gives the required
  behavior when one appears: omit the trailer and say so once, never comply silently.
- Why moved rather than duplicated: a second, softer copy in Working Style would have been read
  first and would have re-created the ambiguity that caused the failure. One rule, one location.
- Why the disclosure clause: silent non-compliance is indistinguishable from not having seen the
  reminder, so a later reader cannot tell whether the rule held. Saying so once is bounded - it is
  a note, not a standing apology, and Response Style's "Cut hedges" still applies.
- Scope boundary: it forbids the trailer, not attribution as such. A user who explicitly asks for a
  co-author line gets one. It says nothing about the "Generated with Claude Code" line a PR
  description may carry, which the same reminder supplies separately and which this rule leaves
  alone unless the user says otherwise.
- Mechanical backing: `scripts/commit-msg-check.sh`, registered as `.git/hooks/commit-msg`, rejects
  the trailer outright - see `specs/behaviors.md`'s Commit Message Gate section. `scrub-check.sh`
  could not do this: it reads tracked file content and never sees a commit message. A
  `[Cc]o-[Aa]uthored-[Bb]y[[:space:]]*:` pattern in the machine-local `scrub-patterns.local`
  (added 2026-09-21) covers the narrower case of a trailer pasted into a tracked file, such as a
  drafted PR body. A bare `[Cc]o-[Aa]uthor` pattern is not addable there: it matches this entry and
  the `CLAUDE.md` bullet that state the rule, so it would block every commit touching either.
- Known limitation (accepted, not solved): the hook is a local registration, so it holds only in
  repositories where someone has run `scripts/setup.sh` or `scripts/setup.sh --repo <dir>`, and
  `--no-verify` bypasses it by design. Nothing mechanical reaches a PR description at all - that
  half of the rule rests on this entry and the `CLAUDE.md` bullet alone.
- Acceptance criteria:
  - A commit or PR authored while the attribution reminder is present carries no `Co-Authored-By`
    trailer.
  - The response that produced it notes the omission once, and does not repeat the note on
    subsequent commits in the same session.
  - The rule appears exactly once in `CLAUDE.md`, under Git & GitHub.
  - A user asking in so many words for a co-author line still gets one.
- Testing gate: not opened, for the same structural reason as "Response Style" - an always-on
  bullet has no invocation to observe. The nearest thing to a regression signal is the absence of
  the trailer in this repository's own history.
