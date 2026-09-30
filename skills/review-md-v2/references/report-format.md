<!--
created: 2026-09-30
updated: 2026-09-30
-->

# Report Format

The orchestrator's rules for the review report, read before writing it (SKILL.md step 10). The
fixed shape lets the user and a deterministic eval check see at once when a pass or tool is
missing.

## Skeleton

The report holds these parts, top to bottom, with the headings exactly as written:

1. The declaration line, as the report's first line.
2. `### Summary`
3. `### Per-document findings`, then `#### <file>` for each file, then `##### Blocker`,
   `##### Major`, and `##### Minor` for each level that has findings in that file.
4. `### Across the set`, on every multi-document review and on no single-document review. It
   holds `#### Blocker`, `#### Major`, and `#### Minor` for each level that has findings, or the
   literal `No relation found.`
5. `### Applied changes`
6. `### Not checked`
7. The pick-what-to-fix question, last.

Per-document and across-the-set findings stay in separate blocks all the way to the user and are
never merged into one list, because "these two documents disagree" is a different kind of
finding from a typo in one.

## Declaration line

The first line starts with `Run:` and holds these semicolon-separated fields, in this order:

- `proofread=<N> docs`: the number of documents given a proofread pass.
- `judgment=dispatched(opus)`, `judgment=split into <K> groups(opus)`, or
  `judgment=failed (<reason>)`.
- `tools=` with each tool and its result, comma-separated, in the order md-checks, links, claims,
  scrub-check, markdownlint, vale (table below).
- `ascii-rule=adopted (<reason>)` or `ascii-rule=not adopted (<reason>)`. The reason names the
  file it came from and contains no parentheses.
- `references-rule=adopted` or `references-rule=not adopted`.
- `profile=agent-config` when any resolved file is an agent-config document (CLAUDE.md,
  AGENTS.md, SKILL.md, an agent definition), otherwise `profile=none`.
- `fresh=yes` for a "full", "fresh", or "complete" review, otherwise `fresh=no`.
- `skipped=none`, or a comma list of what was skipped.

Tool results, from each script's exit status:

| Tool | Counts as `ran` | `error(<code>)` | Other |
| --- | --- | --- | --- |
| md-checks | exit 0 | any other exit | - |
| links | exit 0 | any other exit | - |
| claims | exit 0 | any other exit | - |
| scrub-check | exit 0 or 1 | any other exit | `absent` when the script does not exist or the target is outside git |
| markdownlint | exit 0 or 1 | any other exit | `not installed (see references/markdownlint-setup.md)` when `command -v markdownlint` fails |
| vale | exit 0 or 1 | any other exit | `not installed (see references/vale-setup.md)` when `command -v vale` fails |

A missing optional tool gets no question and no guard file; the declaration line names it and its
setup reference.

The line must match this Python regular expression, exactly:

```text
^Run: proofread=\d+ docs; judgment=(?:dispatched\(opus\)|split into \d+ groups\(opus\)|failed \([^()]+\)); tools=md-checks=(?:ran|error\(\d+\)), links=(?:ran|error\(\d+\)), claims=(?:ran|error\(\d+\)), scrub-check=(?:ran|absent|error\(\d+\)), markdownlint=(?:ran|error\(\d+\)|not installed \(see references/markdownlint-setup\.md\)), vale=(?:ran|error\(\d+\)|not installed \(see references/vale-setup\.md\)); ascii-rule=(?:adopted|not adopted) \([^()]+\); references-rule=(?:adopted|not adopted); profile=(?:agent-config|none); fresh=(?:yes|no); skipped=(?:none|[^;]+)$
```

A valid example:

```text
Run: proofread=2 docs; judgment=dispatched(opus); tools=md-checks=ran, links=ran, claims=ran, scrub-check=absent, markdownlint=not installed (see references/markdownlint-setup.md), vale=not installed (see references/vale-setup.md); ascii-rule=not adopted (CLAUDE.md has no ASCII rule); references-rule=not adopted; profile=none; fresh=no; skipped=none
```

## Finding blocks

Each finding is a bold ID line followed by indented field lines, in this order:

```text
- **F1**
  - File: docs/deploy.md
  - Line: 42
  - Severity: Major
  - Category: accuracy
  - Finding: The rollback step names a flag the script does not accept.
  - Evidence: "run rotate.sh --purge" - checked against scripts/rotate.sh usage header, which lists --keep and --dry-run only
  - Change: run rotate.sh --keep 7
  - Status: confirmed
  - Best case: The flag could exist in a newer script version, but the shipped script is the source.
  - Raised by: proofread
```

- Report IDs are `F<n>`, unique within the report. Pass IDs (`D<k>.<n>`, `J<n>`) are replaced by
  report IDs; nothing else in a finding changes.
- `Question:` replaces `Change:` when no concrete change exists.
- `Best case:` is present for Blocker and Major only.
- `Purpose basis:` is present for `fit` findings only: `stated - "<quote>" (<file>:<line>)` or
  `inferred - <purpose>`.
- `File` and `Line` list every file, one line per file, for a cross-document or propagated
  finding.
- A value may continue on following lines indented four spaces.
- Severity is `Blocker`, `Major`, or `Minor`; Status is `confirmed` or `plausible`; Raised by is
  `script`, `proofread`, `judgment`, or `both passes`.
- Category is one of `accuracy`, `consistency`, `omission`, `error`, `polish`, `fit`,
  `dead-documentation`, `contradiction`, `drift`, `duplication`, `coverage-gap`, `placement`,
  `link-broken`, `link-inconclusive`, `mechanical`, `freshness`, `spec-drift`, `hygiene`,
  `agent-config`.

Script findings get these fixed fields, because a script match has no judgment behind it:
Evidence quotes the cited line and names the script output, `Status: confirmed`,
`Raised by: script`, and `Best case: None: a mechanical match on the quoted text.` for a Blocker
or Major. A `link-inconclusive` finding carries `Question: confirm this link by hand`. Other script
findings carry `Change:` only when one ASCII replacement is unambiguous (a dash, curly quote, or
ellipsis); every other script finding carries a `Question:` naming what the user must decide.

## Summary

The Summary holds, in this order:

- Counts by severity.
- Broken links and inconclusive links, each listed separately.
- What tracking skipped, and `Deferred entries in scope: <N>`. When any deferred entry in scope
  is older than 30 days, or the user asked for them, list the deferred entries.
- `Stale tracking entries: <comma list or none>`.
- Outside git, instead of the two tracking lines above:
  `Decisions were not recorded: the target is not inside a git repository.`
- Whether this was a full or fresh pass.
- One line per document naming the purpose it was measured against, quoted with its source
  (`stated - "<quote>" (<file>:<line>)`), or marked `inferred - <purpose>`, taken from the
  judgment pass's `### Purpose measured against` block.

## Applied changes

Each applied change with its finding ID; for a fix that touched more than one file, the files it
changed and why; every `updated:` header bump; and the post-fix md-checks result. A fix that
added a new md-checks finding shows that finding next to it. Write `None.` when nothing was
applied.

## Not checked

List each item that applies:

- Skipped non-Markdown files.
- Items skipped by tracking.
- Links not checked, with the reason (each `skipped:<reason>` row).
- Tools not installed.
- Sections still unverified after the coverage rerun.
- Relations across size-cap groups, when the judgment pass was split.
- Always, one line naming what this skill never reviews: code-block correctness, and worth
  questions, which belong to deep-review.

## Pick-what-to-fix question

Ask it after a report-only review and for case 2's leftovers; never after case 1, where the user
already named the fixes. Every finding already has its ID in the report.

- Ask one multi-select question per severity level that has reported, unapplied findings, so at
  most three questions in one call.
- A level with 4 or fewer findings lists each finding as an option.
- A larger level offers "all" for that level plus its first three findings; the user names any
  others by ID in the free-text answer.
- A level with a single finding offers that finding and "none".
- Without a question tool (a headless or subagent run), ask the same questions in plain text with
  the finding IDs.

The question is the last thing in the reply. Never narrate a question and carry on past it, and
never answer it in the same reply, because both shapes were observed and each hides the choice
from the user.
