---
name: review-md
description: |
  Reviews Markdown (.md and .markdown files) for accuracy, consistency, fit, and coherence
  across a set. Use when the user asks to "review ...", "review and refine ...", "refine ...",
  "revise ...", or "proofread ..." a Markdown file, a list of them, or a directory holding them.
  Reviewing code, a function, a PR, a diff, or any non-Markdown file is code-review, even when
  the verb is "review"; depth or worth phrasing such as "deep review", "is this a good idea", or
  "be critical" is deep-review, even on a Markdown file. Skill audits go to skill-author, prompt
  improvement to prompt-author, and plan writing to planner.
model: sonnet
---

<!--
created: 2026-09-30
updated: 2026-10-01
spec: specs/skills.md (review-md section)
generated-by: planner plan-2026-10-01-review-md-v2-efficiency (Unit 4.1.5)
harness: Claude Code
-->

# Markdown Review

You run the user-facing steps and never review. A coordinator subagent runs the scripts and the
review passes in its own context, so their output never enters this session. `$CFG` below is
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`. Steps, in order:

1. **Resolve target and mode.** Expand a list or glob; recurse a directory, skipping hidden
   directories below it (not one the user names), `node_modules`, `vendor`, and git-ignored
   paths. Review `.md` and `.markdown` only (`.mdx` JSX gets misread); other files go under Not
   checked, and a named one also gets only this line, with no review or tracking:
   `review-md reviews Markdown only (.md and .markdown files); <file> was not reviewed.`
   Ask if the target is unclear: a wrong one wastes a whole run. No Markdown left: stop.
2. **Start the run.** Run this, with the Markdown files from step 1:
   `"$CFG/scripts/review-checks.sh" init --skill <this skill's directory> <files>`.
   It prints `run-dir=`, `files=`, `chars=`, and `over-cap=` lines. On a non-zero exit, show its
   error and stop.
3. **Guards.** If your session reports a tier below Sonnet, warn and ask the user to confirm
   before going on. When `over-cap=yes`, ask with exactly `Narrow the target`,
   `Split the judgment pass into groups`, and `Run one judgment pass`, since the user must accept
   the cost. Narrowing starts again at step 1.
4. **Write the request** to `<run-dir>/request.md`, exactly:

   ```text
   fresh=<yes for a "full", "fresh", or "complete" review, else no>
   size-cap=<none, or one or groups from the step 3 answer>
   skipped=<none, or a comma list of the non-Markdown paths not reviewed>
   --- request ---
   <the user's request, verbatim>
   ```

   When deep-review called you, also write its verdict and findings, verbatim, to
   `<run-dir>/deep-review.md`.
5. **Dispatch the coordinator** (below) and wait for it. Its reply is
   `review-md coordinator: done` followed by `run-dir:` and `decl:` lines, or
   `review-md coordinator: failed <reason>`. On a failure, or when
   `<run-dir>/report-draft.md` is missing, tell the user the review failed and why, and stop;
   never review the files yourself.
6. **Apply fixes** the fix policy allows, per finding, from `<run-dir>/report-draft.md`; a
   multi-file fix says which files and why. Set `updated:` to today where a
   `created:`/`updated:` header exists and re-run `"$CFG/scripts/md-checks.sh" --review` on
   changed files; a fix is done only if it added no finding, else show the new one beside it.
7. **Report.** Send the draft as it is, with its `### Applied changes` body replaced as below,
   then the pick-what-to-fix question, last.
8. **After the reply**, apply the chosen fixes as in step 6. For each finding the user marks
   intentional or deferred, run
   `"$CFG/scripts/review-merge.sh" record <run-dir> <F-id> <intentional|deferred> "<short description>"`.

Only you ask, because `AskUserQuestion` is unavailable in a subagent. Every question (ambiguous
target, tier guard, size cap, pick what to fix) uses it, plain text as fallback, and ends the
turn. Never narrate a question and carry on, or ask and answer in one reply: both were observed.

## Coordinator dispatch

One Agent call:

| `subagent_type` | `model` | `run_in_background` | `description` |
| --- | --- | --- | --- |
| `"review-md-coordinator"` | `"sonnet"` | `false` | `"review-md coordinator"` |

Its prompt is exactly:

```text
review-md coordinator

Run directory: <run-dir>
Skill directory: <this skill's directory>
Read <this skill's directory>/references/coordinator.md in full and follow it exactly.
```

Never use a fork or a background dispatch: a fork inherits your model and context, and a
background dispatch returns at once, which fakes a clean report.

## Fix policy

First match wins, since a specific instruction beats any general mode: (1) the prompt names
specific fixes: apply exactly those, report every finding, list only those in Applied changes,
and ask no pick-what-to-fix question; (2) it contains "refine", "revise", or "fix": apply
high-confidence fixes and report the rest; (3) anything else: report only.

High-confidence is all of: `Status: confirmed`; one unambiguous correct replacement; no choice
between conflicting sources; not a link removal or a fact change; raised by a script and
confirmed by you reading the cited line, or raised by the proofread pass and confirmed by the
verify pass (`both passes` plays no part). Case 2 never auto-applies, since each needs the user:
a judgment-only finding, polish, a `fit` finding with an `inferred` Purpose basis, or a fix to a
file with a `spec:` header, whose Change is the Question "update <spec path> (<section>) first,
then regenerate".

## Applied changes

List each applied change with its finding ID; for a fix that touched more than one file, the
files it changed and why; every `updated:` header bump; and the post-fix md-checks result. A fix
that added a new md-checks finding shows that finding next to it. Leave `None.` when nothing was
applied.

## Pick-what-to-fix question

Ask it after a report-only review and for case 2's leftovers; never after case 1, where the user
already named the fixes.

- One multi-select question per severity level that has reported, unapplied findings, so at most
  three questions in one call.
- A level with 4 or fewer findings lists each finding as an option; a larger level offers "all"
  for that level plus its first three findings, and the user names others by ID in the free-text
  answer; a level with a single finding offers that finding and "none".
- Without a question tool (a headless or subagent run), ask the same questions in plain text with
  the finding IDs.

## Orchestrator limits

The scripts already filtered, deduplicated, and numbered the findings. Never rewrite a finding's
text, evidence, or replacement, never lower its severity, and never drop, add, or reorder one,
since you run at session tier and the passes ran cold.
