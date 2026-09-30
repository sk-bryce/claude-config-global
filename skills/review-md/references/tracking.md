<!--
created: 2026-09-30
updated: 2026-09-30
-->

# Decision Tracking

The orchestrator's rules for the tracking file, read before merging findings (SKILL.md step 8)
and before recording decisions (step 11). Tracking exists so an item the user already settled is
not raised again in a later session.

## Location

- Tracking works inside a git repository only. The tracking file is `.claude/review-tracking.md`
  at the target's git root, or `review-tracking.md` at the root when the git root is itself a
  `.claude` directory. Create it, and any section it needs, when the first entry is recorded.
- Outside any git repository, read and write no tracking file, because a root outside git could
  be the home directory, which would write into the config directory or create a stray `.claude/`
  directory. The Summary then carries this line in place of the tracking lines:
  `Decisions were not recorded: the target is not inside a git repository.`
- The file is local state. It may be gitignored, and it is committed only if the user wants.

## Format

- A document section is headed `## <path relative to the git root>` and holds the entries for
  findings in that one document.
- A set-level section holds entries for cross-document findings. It is headed
  `## set: <path>, <path>`, with the involved paths sorted and comma-joined. The key names the
  files the finding involves (for example the two files that disagree), not the scope of the
  review that found it, so the same pair matches whichever review raises it again.
- Each entry is one list item:
  `- [<intentional|deferred>] "<quote>" - <description> (<category>, <YYYY-MM-DD>)`
  The quote is a short span of the text the entry covers, the description is short, and the
  category is the finding's Category. A set-level entry holds one quote per file, in the
  section's path order, joined by ` / `.

An example file:

```markdown
## docs/deploy.md

- [intentional] "run rotate.sh --keep 7" - keep count stays at 7 on purpose (accuracy, 2026-09-30)

## set: docs/deploy.md, docs/runbook.md

- [deferred] "rollback window" / "rollback period" - wording differs; align later (consistency, 2026-09-30)
```

## Filter

- The passes report every finding, and never see tracking entries, because an entry shown to a
  pass would bias what it looks for. Filtering happens only in the orchestrator, after the merge.
- Drop a finding when an entry in the section for the same file, or for the same file set, meets
  all of these:
  - its quote still appears in that file (for a set-level entry, each quote in its own file);
  - after whitespace is collapsed, the entry's quote and the finding's quoted evidence match, one
    being a substring of the other;
  - the entry's category equals the finding's Category.
- List what tracking dropped under Not checked, and say in the Summary what tracking skipped.

## Stale entries

An entry whose quoted text no longer appears in its file suppresses nothing, because the text it
settled has changed. The finding resurfaces, and the Summary lists the entry on the
`Stale tracking entries: <comma list or none>` line.

## Statuses

- `intentional`: settled. Never raise it again while the quoted text is unchanged.
- `deferred`: not now. Every Summary gives `Deferred entries in scope: <N>`. List the deferred
  entries when the user asks, and automatically once any in-scope entry is older than 30 days, so
  a deferral does not become a silent permanent dismissal.

## Full or fresh review

When the request says "full", "fresh", or "complete", ignore the in-scope entries for this pass
and delete nothing, because the user asked to see everything once without losing earlier
decisions. The declaration line then says `fresh=yes`.

## Recording

- After the user replies, record each item the user marks intentional or deferred. Append it with
  today's date, its quote, and its category to the section that owns it: the document's section
  for a per-document finding, the set-level section for a cross-document finding.
- Re-dismissing an item that already has an entry updates that entry's date and quote instead of
  adding a second entry.
- Outside any git repository, record nothing; the report already says so with the Summary line
  above.
