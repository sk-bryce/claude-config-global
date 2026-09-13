---
name: health-check
description: |
  Evaluates the health of this ~/.claude config repository as a whole - runs
  scripts/health-check.sh for the mechanical findings, then reviews what no regex can judge:
  whether each artifact still earns its place, what has gone stale, and where two documents now
  contradict each other. Use when the user asks to "run a health check",
  "check the health of this config", "audit this repo", "is anything stale",
  "does this config still hang together", or asks for a self-evaluation of ~/.claude, and before
  a publication pass. Reports findings with path references and proposes changes; it applies no
  edits unless the user asks. Does not proofread an arbitrary Markdown file (see review-md) and
  never runs on a hot path - it is manual, on demand or on a weekly-to-monthly cadence. Scope:
  personal (~/.claude/), this repository only.
model: opus
effort: high
---

<!--
created: 2026-08-24
updated: 2026-09-12
spec: specs/skills.md (health-check section); specs/behaviors.md (Config Health Check section)
generated-by: Opus main-thread session, executed from plans/config-health-check-mechanism.md
model: claude-opus-5
harness: Claude Code
-->

# Config Health Check

The judgment half of this repository's periodic self-evaluation. `scripts/health-check.sh` is the
mechanical half; this skill runs it, then answers what it deliberately cannot.

Run this manually, on demand or on a long cadence (weekly to monthly, or before a publication
pass). It is not a hook and must never become one.

## Step 1: run the mechanical half

Run `scripts/health-check.sh` from the repository root and read its output in full. Do not
reimplement or second-guess its checks, and do not re-derive its findings by hand - it is the
source of the mechanical picture.

Its output is `<path>:<line> - <description>` lines grouped under `== <category> ==` headers, with
advisory categories marked `(advisory)`. A line number of 0 means the finding is about the file as
a whole. Exit 0 means no failures; exit 1 means at least one check failed; exit 2 means a usage or
environment error.

`scripts/health-check.sh --quick` skips three things: the four delegated scripts
(`scripts/md-checks.sh`, `scripts/scrub-check.sh`, `scripts/sync.sh --check`, and
`scripts/setup.sh --check`), the per-file git-history scan behind the `updated-history` advisory,
and the inbound-reference scan behind the `orphans` advisory. Use it only when you have already run
those in this session. The full run is the default and is what a real health check needs.

## Step 2: triage the mechanical findings

For each non-advisory finding, decide whether it is a defect to fix or a rule that no longer fits
the repository. Both outcomes are legitimate; say which one you concluded and why. Never propose
loosening a check purely to make a run come out clean.

Advisory findings are context, not work items, and nothing records a previous run, so there is no
baseline to diff against - judge each on its own terms. Report the ones close to a threshold or
that the judgment pass should follow up, and leave the rest alone. Three advisory categories are
direct inputs to Step 3 rather than things to dismiss:

- `orphans` - a reference document, example, or decision record that no other tracked Markdown
  file cites. Zero inbound references is a measurement, not a verdict; deciding whether the file
  has been superseded, was never wired in, or is simply a standalone record is the judgment half.
- `eval-coverage` - a skill with no `evals/evals.json`. Cross-check it against what
  `specs/skills.md` claims about that skill's testing gate; a spec entry asserting validation for
  a skill with no eval set is a contradiction to report under Coherence.
- `context-budget` - `CLAUDE.md` measured against the roughly 200-line target in
  `reference/context-file-authoring.md`, which permits overrunning it as far as a hard ceiling of
  300, and each on-demand `reference/*.md` against that file's 400-line convention. A root-file
  overrun is a standing per-turn cost, so it is worth naming with a concrete trimming proposal
  rather than noted and forgotten; a ceiling breach is worth treating as a defect. An oversized
  reference file costs only the tasks that load it, so weigh a split against leaving it whole.

The remaining advisories (`description-budget` totals, `setup-check`, `scrub-check` exit 2,
`updated-history`, `shellcheck`) are measurements or machine-local state; report only what has
moved close to a limit.

## Step 3: the judgment pass

This is the half a regex cannot do. Working from the tracked tree, assess:

- **Coherence.** Do `CLAUDE.md`, `specs/`, `decisions/`, `reference/`, and the skills still agree?
  Name any place where two documents now say different things, with both paths and line numbers.
- **Earning its place.** Does each skill, subagent, script, and reference document still do
  something the others do not? Name anything that has been superseded, duplicated, or outgrown.
- **Staleness.** Which documents describe behavior that has since changed - a renamed flag, a
  retired artifact, a count or threshold that has moved, a decision that a later decision
  superseded without the earlier text being updated?
- **Specs against artifacts.** Does each spec still describe what its artifact actually does, or
  has the artifact moved on? The mechanical check only proves a section exists.
- **Gaps.** What is in the tree with no spec, no decision record, and no README entry?

Read the files you are judging. Do not infer a document's current content from its name, its spec,
or a previous run's notes.

Two blind spots the script leaves deliberately, which this pass has to cover by reading:

- **`decisions/` path references.** `path-refs` skips `decisions/` entirely, because those records
  are immutable and describe the tree as it stood when they were accepted. A decision that now
  cites something gone is not a defect to fix in place - it is a signal that a superseding record
  may be due, which is a judgment call.
- **`docs/`.** `path-refs` skips it as well, since it is a research library citing other projects'
  paths. Its internal cross-references are still covered by `md-checks.sh`'s link check, but a
  claim in `docs/` that has gone stale about *this* repository is only visible by reading.

## Step 4: report

Produce a report with these sections, in this order:

1. **Mechanical summary** - counts by category, and the exit code.
2. **Findings to fix** - one bullet each, `path:line - what is wrong - proposed change`.
3. **Judgment findings** - contradictions, stale content, artifacts that no longer earn their
   place, and gaps, each with path references.
4. **No action needed** - checks that fired but are correct as they stand, with the reason.
5. **Suggested next pass** - the two or three highest-value changes, in order.

## Constraints

- Read-only by default. Propose changes; apply none unless the user asks for them.
- Never register a hook, and never wire `scripts/health-check.sh` into
  `scripts/pre-commit-check.sh`, `settings.json`, `.git/hooks/`, or any skill's `hooks:`
  frontmatter. Per `decisions/0003-hooks-and-scripts-authoring-policy.md`, no hook activates
  without the owner's explicit, in-the-moment decision to activate it - the rule is about who
  decides, not whose fingers type the write. No such direction exists in this flow, and this
  mechanism is manual by design regardless.
- Never run `scripts/setup.sh` in any mode other than `--check`, and never run `scripts/sync.sh`
  without `--check`; both write outside this repository in their default modes.
- `decisions/` records are immutable. Propose a superseding record, never an edit to an existing
  one.
- Editing a tracked Markdown file means bumping its `updated:` date the same day.
