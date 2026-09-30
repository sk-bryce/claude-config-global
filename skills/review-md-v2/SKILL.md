---
name: review-md-v2
description: |
  Reviews Markdown (.md and .markdown files) for accuracy, consistency, fit, and coherence
  across a set. Use when the user asks to "review ...", "review and refine ...", "refine ...",
  "revise ...", or "proofread ..." a Markdown file, a list of them, or a directory holding them.
  Reviewing code, a function, a PR, a diff, or any non-Markdown file is code-review, even when
  the verb is "review"; depth or worth phrasing such as "deep review", "is this a good idea", or
  "be critical" is deep-review, even on a Markdown file. Skill audits go to skill-author, prompt
  improvement to prompt-author, and plan writing to planner.
model: opus
disable-model-invocation: true
---

<!--
created: 2026-09-30
updated: 2026-09-30
spec: specs/drafts/review-md-v2.md
generated-by: planner Plan B (review-md v2 build)
harness: Claude Code
-->

# Markdown Review

You orchestrate and never review, since the dispatched passes give the isolation. Steps, in order:

1. **Resolve target and mode.** Expand a list or glob; recurse a directory, skipping hidden
   directories below it (not one the user names), `node_modules`, `vendor`, and git-ignored
   paths. Review `.md` and `.markdown` only (`.mdx` JSX gets misread); other files go under Not
   checked, and a named one also gets only this line, with no review or tracking:
   `review-md reviews Markdown only (.md and .markdown files); <file> was not reviewed.`
   Ask if the target is unclear: a wrong one wastes an Opus pass. No Markdown left: stop. One file
   is a single-document review with no Across the set; more is a multi-document review.
2. **Guards.** If your session reports a tier below Sonnet, warn and ask the user to confirm
   before any script or dispatch. Above 25 Markdown files or 250,000 characters, ask with exactly
   `Narrow the target`, `Split the judgment pass into groups`, and `Run one judgment pass`, since
   the user must accept the cost; groups follow the directory tree.
3. **Read context.** From the target repository's CLAUDE.md and AGENTS.md, decide whether it
   adopts the ASCII rule and the References rule (the reason names the file). Note agent-config
   documents (CLAUDE.md, AGENTS.md, SKILL.md, agent definitions) and each `spec:` header.
4. **Run the scripts** in one batched step before any dispatch:

   ```text
   "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/md-checks.sh" --review [--no-typography] <files>
   "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/link-recheck-hook.sh" --review [--references-rule] <files>
   "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/md-claims.sh" <files>
   "<git root>/scripts/scrub-check.sh" <files>
   markdownlint --config <config> <files>
   vale --config <config> <files>
   ```

   `--no-typography` unless the ASCII rule is adopted; `--references-rule` if that rule is;
   scrub-check only if it exists. Configs: the git root's first `.markdownlint.json`, `.jsonc`,
   `.yaml`, or `.yml`, else `assets/markdownlint.jsonc` (never `--fix`: the review decides
   edits); the root's `.vale.ini`, else `assets/vale/.vale.ini`. md-claims `found` rows are
   settled; `not-found-by-script` and `candidate` rows of kind `path`, `command`, `flag`,
   `identifier`, `heading-ref`, or `dated` go to `{{CLAIMS}}`; `drift` rows to `{{SCRIPT_SIGNALS}}`.
5. **Proofread passes** (`references/proofread-pass.md`), one per document, in waves of at most
   5 per message, never one at a time. Split a document over 60,000 characters by top-level
   section into dispatches in the same wave, `{{SECTION_SCOPE}}` then being
   `sections: <heading>, <heading>`, since long context degrades accuracy.
6. **Coverage check.** A heading is unverified when `Claims verified` is below `Claims found`,
   or `Claims found` is below md-claims's handed-over rows for it. Rerun each such section once,
   alone; what stays unverified goes under Not checked, so a partial pass never looks complete.
7. **Judgment pass** (`references/judgment-pass.md`) after every proofread pass returns: one, or
   one per size-cap group. Always dispatch it; a session misjudging its tier would skip it.
8. **Merge and filter.** Read `references/tracking.md` first. A proofread finding takes Status
   and Best case from its Verification row; drop `rejected`. Keep a script finding only if its
   line still holds the matched text. Drop duplicates, filter by tracking, number `F1`, `F2`.
9. **Apply fixes** the fix policy allows, per finding; a multi-file fix says which files and why.
   Set `updated:` to today where a `created:`/`updated:` header exists and re-run md-checks on
   changed files; a fix is done only if it added no finding, else show the new one beside it.
10. **Report.** Read `references/report-format.md` first; the pick-what-to-fix question is last.
11. **After the reply**, read `references/tracking.md`, apply the chosen fixes as in step 9, and
    record newly settled tracking decisions.

Only you ask, because `AskUserQuestion` is unavailable in a subagent. Every question (ambiguous
target, tier guard, size cap, pick what to fix) uses it, plain text as fallback, and ends the
turn. Never narrate a question and carry on, or ask and answer in one reply: both were observed.

## Dispatch

| Pass | `model` | `subagent_type` | `run_in_background` | Effort lever |
| --- | --- | --- | --- | --- |
| Proofread | `sonnet` | `"general-purpose"` | `false` | none (session default) |
| Judgment | `opus` | `"general-purpose"` | `false` | `ultrathink` in the prompt |

Every dispatch sets `run_in_background: false`. Forks inherit your model and background passes
return at once, faking a clean report. Send the text between the prompt markers, every
`{{NAME}}` slot filled (`{{DOC_ID}}` is `D<k>`, k the list position), never tracking entries.
`{{EXCLUSIONS}}` names only tools that ran: md-checks (unfinished markers, typography if run,
heading-level skips, unclosed fences, relative link targets, same-file anchors, fence language
tags, empty alt text, H1 rules, repeated sibling headings), links (link liveness), scrub-check
(home paths and identifiers), markdownlint (its rules' topics), vale (repeated words). Findings
cap at 130 words, bar evidence quotes and Change. Fill the context block verbatim (no paraphrase):

```text
Context block
- Request (source: user message): <the user's request, verbatim>
- Resolved files: <one path per line>
- deep-review verdict and findings (source: deep-review): <verbatim, or none>
```

## Script findings

Exit codes: md-checks, links, claims are `ran` on 0; scrub-check, markdownlint, vale on 0 or 1;
any other is `error(<code>)`. Other values and fixed fields: `references/report-format.md`.

- Blocker: scrub-check (`hygiene`). Major: placeholder and unclosed fence (`mechanical`); broken
  relative link and missing anchor (`error`); `broken` link (`link-broken`).
- Minor: `inconclusive` link (`link-inconclusive`, Question "confirm this link by hand");
  typography, heading skip, fence without language, empty alt text, H1 rules, repeated sibling
  heading (`mechanical`); `stale-header` (`freshness`); `no-references` (`omission`);
  markdownlint and Vale (`polish`).

When md-checks and markdownlint report the same file and line under an equivalent rule, keep
md-checks: `headings` MD001, `anchors` MD051, `fence-language` MD040, `alt-text` MD045, `h1`
MD025 and MD041, `sibling-headings` MD024.

## Fix policy

First match wins, since a specific instruction beats any general mode: (1) the prompt names
specific fixes: apply exactly those, report every finding, list only those in Applied changes,
and ask no pick-what-to-fix question; (2) it contains "refine", "revise", or "fix": apply
high-confidence fixes and report the rest; (3) anything else: report only.

High-confidence is all of: `Status: confirmed`; one unambiguous correct replacement; no choice
between conflicting sources; not a link removal or a fact change; raised by a script and
confirmed by you, or by the proofread pass and confirmed by the judgment pass (`both passes`
plays no part). Case 2 never auto-applies, since each needs the user: a judgment-only finding,
polish, a `fit` finding with an `inferred` Purpose basis, or a fix to a file with a `spec:`
header, whose Change is the Question "update <spec path> (<section>) first, then regenerate".

## Orchestrator limits

Drop (rejected, tracked, duplicate) and group findings; never rewrite a finding's text, evidence,
or replacement or lower its severity, since you run at session tier. Of two findings for one
defect keep one whole: the higher severity, else the proofread one; a kept judgment finding is
judgment-only. `Raised by: both passes` only when the judgment pass raised it in its own area
blocks with different evidence; else name the kept finding's pass.
