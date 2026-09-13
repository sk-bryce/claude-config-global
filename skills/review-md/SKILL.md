---
name: review-md
description: |
  Proofreads and reviews Markdown (.md) documents for accuracy, consistency, omissions, errors,
  and whether they still serve their stated purpose - either a single document, or a named set of
  documents reviewed together for how they hold up individually and how they hang together as a
  set. Use this whenever the user asks to "review", "proofread", or "refine" one or more Markdown
  files (docs, READMEs, specs, notes, AGENTS.md/CLAUDE.md-style config, etc.) - trigger even if
  they just say "review this" or "proofread this" while a .md file is the clear subject, and also
  for "review these docs together", "review this doc set",
  "do these docs still agree with each other", or "review everything in docs/" when multiple
  files or a directory of them are the subject. Do not use for non-Markdown files (code, JSON,
  YAML, etc.) - defer to normal code-review conventions for those.
model: sonnet
effort: medium
context: fork
agent: general-purpose
background: false
---

<!--
created: 2026-07-22
updated: 2026-09-11
spec: specs/skills.md (review-md section)
generated-by: skill-author
model: claude-opus-5
harness: Claude Code
-->

# Markdown Review

Proofread Markdown on request in one of two modes - a single document, or a named set of documents
assessed both individually and for how they hold together as a set - tracking decisions so the same
items are never re-flagged in a later session. Before checking any link in a document, load
`references/document-generation.md` (synced from this repository's
`reference/document-generation.md`) - it is the source of truth for link-verification rules,
including the 403/429-is-inconclusive-not-broken judgment used in "What to check" below.

## Before anything else: confirm the target is Markdown

Identify the document or documents being reviewed. If it's ambiguous which is meant, ask before
proceeding rather than guessing.

Resolve the request to a concrete file list first: a named file is that one file, a list of named
files is that list, and a directory target is every file inside it. Then confirm every resolved file
is a `.md` file - for a directory target, check its contents, not just the one path you were handed.

If any resolved target is not a `.md` file, stop here and do not act - let the request fall through
to whatever other skill or normal conduct applies. This skill exists specifically for Markdown
prose; applying a prose-review checklist to code or config produces noise, not value.

## Then decide the mode: single-document or multi-document

With the file list resolved, decide which mode this invocation runs in:

- **Single-document** (default) - exactly one resolved target file, whether named directly or the
  sole `.md` file inside a directory target. Run the rest of this skill as written, with a single
  review dispatch - a directory that happens to resolve to one file is not multi-document, and
  gets no synthesis pass.
- **Multi-document** (holistic) - a directory target that resolves to more than one file, or
  explicit holistic-signaling language ("together", "as a whole", "do these still agree with each
  other", "hang together") naming a set of two or more targets. Either signal alone is unambiguous
  and enough on its own - do not require both. Every document still gets the full single-document
  checklist, and the set additionally gets a cross-document pass.
- **Ambiguous - ask once** - multiple named files with neither a directory target nor holistic
  language *in the request*. This is *not* multi-document by file count alone, and *not* several
  independent single-document reviews either - stop and ask which is wanted: independent
  single-document passes, or one holistic pass over the set. Present it as a choice between those
  two options using `AskUserQuestion`; don't silently pick one, because the two produce materially
  different output. If the tool isn't available in this
  execution context, ask in plain text instead of guessing - never fall through to either mode
  unasked.

The signal has to come from the request's own wording (or a bare directory target), decided before
you read any document's content. A document that describes itself as paired with, or designed to
agree/disagree with, another document is not a substitute for that - noticing that while reading is
not the same as the user asking for a holistic pass, and silently treating it as such skips the
ask-once branch by the back door. If content like that makes you suspect a holistic pass is wanted,
say so as part of the question you ask, rather than deciding on the user's behalf.

Multi-document mode reviews exactly the set the user pointed at. Don't go looking beyond it for
other documents you judge related.

## Decide the fix policy from the prompt

Check the prompt in this order and stop at the first match:

1. **It names specific fixes** ("fix the broken link on line 12", "update the changelog date") -
   apply exactly those, nothing more. A specific instruction is more precise than any general mode,
   so it always wins.
2. **It contains "refine" or "fix"** (e.g. "review and fix", "refine this") - apply high-confidence
   fixes automatically as you find them. Report anything lower-confidence rather than guessing.
3. **Otherwise** ("review this", "proofread this") - report findings only. Apply nothing until the
   user has chosen what to act on.

Whenever you have findings to report rather than fixes already applied (case 2's leftovers, and all
of case 3), present them as a multi-select question (`AskUserQuestion` with `multiSelect: true`) so
the user can pick what to address in one round trip instead of a back-and-forth.

In multi-document mode this precedence is unchanged, but it applies per finding rather than per
invocation: a finding scoped to one document and a cross-document finding are each judged against
the same three cases above. A cross-document finding may imply edits across more than one file -
when you apply one, state which files changed and why, the same as for any other applied fix.

## Run the mechanical checks first

Before dispatching any review pass, run `~/.claude/scripts/md-checks.sh` over every in-scope file,
batched into one call:

```bash
~/.claude/scripts/md-checks.sh <file1.md> [<file2.md> ...]
```

It reports placeholders and unfinished markers, CLAUDE.md typography violations, skipped heading
levels, relative link targets that do not resolve, and same-file anchors with no matching heading.
It is silent for a clean file, never edits anything, and always exits 0.

Fold its output into the findings you report, attributed the same as any other finding, and do
**not** ask a dispatched subagent to re-check those five categories - they are settled
deterministically at this point, and a model re-deriving them costs a round trip to produce a less
reliable answer. The dispatches below then spend their whole budget on the judgment calls in "What
to check", which is the part a script cannot do.

For link *liveness* (does an external URL still resolve), use
`~/.claude/scripts/link-recheck-hook.sh <file.md>`, which applies the verification rules in
`references/document-generation.md` and prints only links that are broken or inconclusive. It
self-gates on a freshness window, so a document checked recently returns silently without a network
call - that is correct behavior, not a skipped check.

## What to check

Read the document and assess:

- Accuracy - does it still describe things correctly?
- Consistency - internal contradictions, drifted terminology, mismatched examples.
- Omissions - gaps a reader would trip on.
- Errors - typos, broken formatting, dead links.
- Improvements - anything that would make it clearer or more useful.
- Fit for purpose - does each section still earn its place given what the document is for? A
  section can be well-written and still not belong.

## Track decisions so they stick

The reason this tracking exists: without it, every review re-surfaces the same "yes, that's
intentional" items the user already settled, which wastes their time and erodes trust in the review
itself.

Decisions live in `.claude/review-tracking.md` at the root of whatever project you're working in
(create the file if it doesn't exist yet). If the project root is itself a `.claude` directory
(for example this repository, `~/.claude`), use `<root>/review-tracking.md` directly instead -
there is no nested `.claude/` to create in that case. Treat it as local, machine-specific state by
default - it's fine for a project's `.gitignore` to exclude it; that still gives cross-session
persistence on this machine, which is the mechanism's main value. Track and commit it explicitly
only if the user wants decisions to survive across machines or be shared with a team - that's their
call, not something to assume either way. It's keyed by document, one section per file:

```markdown
## docs/architecture.md

- [intentional] "Fable" model name spelling (2026-06-30)
- [deferred] Broken links in Related Reading section (2026-07-10)
```

Per-document findings always live in that per-document section, keyed by path, in both modes.
Cross-document findings have no single owning file, so multi-document mode records them under a
separate set-level key instead: the directory path or the comma-joined file list that scoped that
review, written so it reads as a set rather than as one document's path.

```markdown
## set: docs/

- [intentional] "runbook" vs "playbook" wording differs between these docs on purpose (2026-08-04)
```

Keep that set-level section distinct from every document's own section, so a cross-document
`intentional`/`deferred` call is never attributed to - or lost inside - any one document's section.

Before reviewing, read the section(s) in scope and skip anything listed there: each in-scope
document's section, plus the matching set-level section in multi-document mode.

- `intentional` means the user has permanently settled this - never re-raise it.
- `deferred` means "not now" - skip it for this pass, but it's still open and may be worth
  resurfacing later, so don't treat it the same as `intentional`.

When the user marks something as intentional or defers it during this pass, append it to the section
that owns it - the document's section for a per-document finding, the set-level section for a
cross-document one - with today's date.

When the user asks for a "full", "fresh", or "complete" review, clear only what's in scope before
starting, since they're explicitly asking to see everything again: in single-document mode that's
the current document's section; in multi-document mode it's the in-scope file sections plus the
matching set-level section. Never clear the whole tracking file in either mode.

## Do the review with a subagent

Never do the read-and-assess pass in the invoking turn. Dispatch every review pass to a Sonnet-tier
subagent (a `Task`/`Agent` subagent with `model: sonnet`). Each is a bounded pass against a clear
checklist - and in multi-document mode, a bounded cross-referencing pass over a known, closed set -
not open-ended architectural judgment, so Sonnet is the right fit rather than reaching for a
heavier model. The invoking turn only dispatches, then applies approved fixes and updates the
tracking file.

### Dispatch shape

**Single-document mode:** one dispatch. It reads the document and returns findings labeled against
the checklist above, cross-referenced with what `review-tracking.md` already lists so settled items
don't get re-reported.

**Multi-document mode:** a fan-out followed by a synthesis pass. This is a genuinely different shape
from single-document mode's one dispatch, not a flag on the same call.

1. **Per-document fan-out.** One dispatch per document in the set: separate tool calls, batched into
   a single response rather than issued one at a time - never merged into one call that covers more
   than one document. Each applies the same "What to
   check" checklist above, unchanged, to its one document, cross-referenced with that document's own
   tracking section - exactly what a single-document pass does. Nothing about the per-document
   checklist changes in this mode.
2. **Cross-document synthesis.** One further dispatch, once the fan-out has returned. Give it the
   full set - every document's content, plus each document's per-document findings - and have it
   report cross-document findings *only*:
   - Contradictions between documents.
   - Terminology or heading drift across the set.
   - Redundant or duplicated coverage.
   - Coverage gaps: something the set collectively should cover but doesn't, or something covered in
     more than one place that should live in exactly one.

   Cross-reference this pass against the set-level tracking section so settled cross-document calls
   don't come back. It must not restate per-document findings; those already came back from step 1.

Keep the two result sets distinct from the fan-out all the way through to what the user sees. Never
merge per-document and cross-document findings into one undifferentiated list - "these two documents
disagree" is a different kind of finding from "this document has a typo", and collapsing them loses
the distinction the holistic pass exists to produce.

### Every dispatch prompt must require batched tool calls

Every dispatch prompt written above - the single-document dispatch, each per-document fan-out
dispatch, and the cross-document synthesis dispatch - must explicitly tell the subagent to batch
its independent verification tool calls (unrelated `Read`/`Grep`/`Bash` lookups with no ordering
dependency between them) into as few tool-call rounds as possible, rather than issuing them one at
a time. State this directly in the prompt text; do not assume the subagent already knows it.

A `Task`/`Agent`-dispatched subagent does not automatically inherit the invoking session's global
CLAUDE.md working-style rules, including the "batch independent tool calls" rule - so
without restating it, a dispatched pass has no reason to combine its lookups. This is a pure
efficiency instruction, not a scope change: it does not shrink the checklist or skip any
verification step, only the number of round trips used to get through it. It matters because
Claude Code's prompt cache re-bills the accumulating conversation prefix on every turn - a pass
that issues its lookups serially pays that cost once per turn instead of once per batch, and in a
multi-document fan-out that cost is paid independently by every parallel dispatch. A measured
10-document multi-document review where per-document dispatches issued verification calls one at a
time (7-26 turns each) multiplied into several million cache-read tokens for what was substantively
a bounded 10-document proofread.

### Why the dispatch stays even when the skill is forked

These subagent dispatches carry the tier guarantee, so the guidance survives a harness that drops
the pin. They stay in place even though the whole skill also runs forked (`context: fork`): the
fork is what keeps this skill's tool-call noise out of the calling conversation - it does not
replace them, and they are not a "now-redundant" step to remove. The same applies to the
multi-document fan-out: collapsing it into one dispatch over the whole set, or into the invoking
turn, gives up both the isolation and the per-document bounding.

Once the review pass or passes return: apply whatever the fix policy above says to apply, then
update `review-tracking.md` with any newly-settled items.

## Finish with a summary

Every invocation ends with a short summary: what was checked, what was found, what was changed (or
queued for the user to choose from), and what's newly tracked as intentional/deferred.

In multi-document mode, split the findings part of that summary in two: what was found
**per-document**, grouped by file, and what was found **across the set**. Report both halves even
when one of them is empty, rather than collapsing them into a single list.
