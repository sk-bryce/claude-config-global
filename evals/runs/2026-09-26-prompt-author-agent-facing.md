---
created: 2026-09-26
updated: 2026-09-26
---

# `prompt-author` 2026-09-26: agent-facing prompts added, both eval layers

**Decision: HOLD.** The trigger layer passes. The behavioral layer misses its 100 percent
deterministic threshold and its zero-regression threshold on both attempts; judgment clears 90
percent on both.

## Harness and environment

- Harness: `2.1.280 (Claude Code)`.
- Model for executors and for graders: `claude-sonnet-5` via the `sonnet` alias.
- Trigger runs: `--model claude-sonnet-5`, 9 runs per query, `--trigger-threshold 0.88`.
  Positives pass at 8 or 9 of 9; negatives pass only at 0 of 9.
- `with_skill` runs only, no baseline arm this time; the comparison point is the prior
  `evals/runs/2026-09-26-prompt-author-first-build.md` run.
- Prior baseline: `evals/runs/2026-09-26-prompt-author-first-build.md` (SHIP, first build,
  user-facing prompt cases 1-12 only).

## Scope of this run

The skill's coverage was extended from user-facing prompts (prompts a person pastes into a chat
tool) to also cover agent-facing prompts: briefs and handoffs written for a subagent or a fresh
session. The trigger set grows from 10/10 to 15/15 queries; the behavioral set is the first
build's cases 1 to 12 plus new cases 20 to 23, which exercise the agent-facing expectations (the
B-group). The committed SKILL.md is the version attempt 2 measured, not the version the SHIP
first-build run measured.

## Trigger layer: 15 of 15 positives, 15 of 15 negatives. PASS.

Final per-query fire counts, 9 runs each:

| # | Polarity | Rate | Verdict | Query |
| --- | --- | --- | --- | --- |
| 1 | + | 9/9 | pass | Write me a prompt I can paste into ChatGPT to turn raw meeting notes into a list of action items with owners. |
| 2 | + | 9/9 | pass | Can you draft a prompt for a fresh Claude.ai chat that will help me plan a two-week trip to Japan on a budget? |
| 3 | + | 9/9 | pass | Here's the prompt I use for code review in Cursor and the answers keep coming back too vague. Can you improve it? 'Review this code and tell me what's wrong with it.' |
| 4 | + | 9/9 | pass | Turn these notes into a proper prompt I can reuse: summarize support tickets, flag anything about billing, keep it under 100 words, plain text. |
| 5 | + | 9/9 | pass | I need a system prompt for a Claude Project that answers questions about our internal onboarding docs. |
| 6 | + | 9/9 | pass | What's wrong with this prompt? 'You are an expert. CRITICAL: ALWAYS double-check EVERYTHING. Write a blog post about Kubernetes.' |
| 7 | + | 9/9 | pass | Write a prompt I can give Gemini to extract invoice fields from scanned PDFs into JSON. |
| 8 | + | 9/9 | pass | Rewrite this prompt so it works better with Claude: 'Don't be verbose. Don't use bullet points. Don't make things up. Explain recursion.' |
| 9 | + | 9/9 | pass | I want to ask another AI to generate realistic test data for a users table. Write the prompt for me. |
| 10 | + | 9/9 | pass | Give me a reusable prompt template for writing release notes from a list of merged PR titles. |
| 11 | + | 9/9 | pass | Write the prompt I should hand a subagent to audit all 40 scripts in scripts/ for unquoted variables. |
| 12 | + | 9/9 | pass | Draft a handoff prompt so a fresh session can pick up this refactor where we left off. |
| 13 | + | 9/9 | pass | Write the system prompt body for a new read-only log-analyzer agent definition under agents/. |
| 14 | + | 9/9 | pass | The brief I gave the executor agent last time made it edit the wrong file. Rewrite the brief so that can't happen. |
| 15 | + | 9/9 | pass | Write the prompt I'll pass to a background agent that keeps the test suite running and reports new failures. |
| 16 | - | 0/9 | pass | Create a skill that formats SQL files before I commit them. |
| 17 | - | 0/9 | pass | Help me tighten the description in my go-dev skill's frontmatter so it triggers more reliably. |
| 18 | - | 0/9 | pass | Plan out migrating our CI from Jenkins to GitHub Actions. |
| 19 | - | 0/9 | pass | Write a Python script that calls the Claude API to summarize each file in a directory. |
| 20 | - | 0/9 | pass | Proofread docs/generative-ai/README.md for typos. |
| 21 | - | 0/9 | pass | My zsh prompt is slow to render after I added the git branch segment. How do I speed it up? |
| 22 | - | 0/9 | pass | Why do I keep getting permission prompts for every git status command? |
| 23 | - | 0/9 | pass | Research the current state of WebAssembly component model tooling and write it up as docs. |
| 24 | - | 0/9 | pass | Write the system prompt my Python app passes to the Claude API in messages.create, and update the code that sends it. |
| 25 | - | 0/9 | pass | My UserPromptSubmit hook isn't firing when I submit a prompt. How do I debug it? |
| 26 | - | 0/9 | pass | Execute the plan at plans/plan-2026-09-25-example.md. |
| 27 | - | 0/9 | pass | Find where statusline.sh reads the rate-limit fields. |
| 28 | - | 0/9 | pass | Run the go-dev trigger evals and tell me the positive rate. |
| 29 | - | 0/9 | pass | Review this diff for bugs before I commit. |
| 30 | - | 0/9 | pass | Commit these changes and push to upstream. |

Positives failing: 0. Negatives fired: 0.

## Behavioral layer: two attempts, neither meets the gate. HOLD.

Thresholds: deterministic 100 percent, judgment at least 90 percent, zero regressions (a
regression is a judgment expectation on cases 1 through 12 that passed in the first-build run and
fails here).

Sixteen cases total: 1 through 12 are the first-build's user-facing cases (A-group, plus the
D-group long-running-agent cases at 8 through 12), and 20 through 23 are new agent-facing cases
(B-group):

- **Case 20**: a brief handed to a subagent to fix three named handler files. Must name all three
  files by absolute path, carry checkable acceptance criteria and a verification step, state what
  to report back and in what shape, state what to leave alone, and contain no reference back to
  the conversation, to "above", to "as discussed", or to another document for its task.
- **Case 21**: a handoff prompt for a fresh session resuming a billing refactor. Must reference
  the spec doc by path, state what part of the work is done and what remains, name at least one
  skill the next session should load (or say none applies), and be actionable without access to
  this conversation.
- **Case 22**: a report-only prompt for an agent that must not edit or write files. Must state the
  agent's role and read-only constraint, specify the report's output format including counts per
  error pattern, use no all-caps emphasis word as emphasis (a literal value the task names, such
  as a CRITICAL log level, does not count), describe the process step by step, and have the reply
  offer a test run of the agent on a subagent without actually running one.
- **Case 23**: a short prompt for a subagent doing one narrow rename. Must stay at or under 150
  words, name the target file and the rename, and not be wrapped in a full multi-section brief
  template.

### Attempt 1 (deterministic 44/47, judgment 20/22, regressions 1)

Per-case with_skill results, `deterministic, judgment`:

| Case | Deterministic | Judgment |
| --- | --- | --- |
| 1 | 3/3 | 2/2 |
| 2 | 4/4 | 2/2 |
| 3 | 3/3 | 2/2 |
| 4 | 3/4 | 1/1 |
| 5 | 1/1 | 0/1 |
| 6 | 3/3 | 1/1 |
| 7 | 3/3 | 1/1 |
| 8 | 5/5 | 3/3 |
| 9 | 1/1 | - |
| 10 | 2/2 | 2/2 |
| 11 | 2/2 | 1/1 |
| 12 | 4/4 | 1/1 |
| 20 | 4/4 | 1/1 |
| 21 | 3/3 | 1/1 |
| 22 | 2/3 | 1/2 |
| 23 | 1/2 | 1/1 |

Failures:

- Eval 4, deterministic A1: the reply sent a 38-line prompt to a file instead of one fenced code
  block, because the pasted contract text was counted toward the file-length threshold.
- Eval 5, judgment A7 (the regression against the first-build baseline): the grader failed a reply
  that asked no clarifying questions; the expectation wording was ambiguous about whether asking
  zero questions meets it.
- Eval 22, deterministic B5: a literal CRITICAL log-level name in the task tripped the literal
  all-caps-emphasis check.
- Eval 22, judgment B6: the reply did not offer a subagent test run.
- Eval 23, deterministic B3: the one-step brief ran to 200 words, and included a git-safety
  boundary and edge cases the task did not raise.

### Changes made between attempts

`SKILL.md` was amended to: count a prompt's own lines, including a placeholder's line, as one line
each toward the file-length threshold; count a one-step brief's words and leave out the
git-safety boundary and edge cases unless the task itself touches git or raises them; checklist
item 16 now reads "by count"; a new checklist item 19 covers the subagent test-run offer. Two
eval expectations were reworded: case 5's judgment A7 now states that a reply asking no questions
meets the expectation; case 22's B5 now exempts a literal value the task names, such as a CRITICAL
log level, from the all-caps-emphasis check.

### Attempt 2, full re-run of all 16 cases (deterministic 45/47, judgment 21/22, regressions 1)

Per-case with_skill results, `deterministic, judgment`:

| Case | Deterministic | Judgment |
| --- | --- | --- |
| 1 | 3/3 | 2/2 |
| 2 | 4/4 | 2/2 |
| 3 | 3/3 | 1/2 |
| 4 | 4/4 | 1/1 |
| 5 | 1/1 | 1/1 |
| 6 | 3/3 | 1/1 |
| 7 | 3/3 | 1/1 |
| 8 | 5/5 | 3/3 |
| 9 | 1/1 | - |
| 10 | 2/2 | 2/2 |
| 11 | 2/2 | 1/1 |
| 12 | 4/4 | 1/1 |
| 20 | 3/4 | 1/1 |
| 21 | 2/3 | 1/1 |
| 22 | 3/3 | 2/2 |
| 23 | 2/2 | 1/1 |

Failures:

- Eval 3, judgment A3 (the regression against the first-build baseline, and the only expectation
  to pass in attempt 1 and fail here): the prompt states the no-guessing rule but gives no reason
  for it.
- Eval 20, deterministic B2: the brief reads "found during your search above", referring to an
  earlier step of the brief document itself rather than the conversation, and still trips the
  literal reference-back rule.
- Eval 21, deterministic B4: the handoff prompt names no skill for the next session to load and
  does not state that none applies.

Every attempt-1 failure passes in attempt 2, and every attempt-2 failure passed in attempt 1: with
one sample per case, the two runs missed different small sets, and every expectation in both
attempts passed on at least one of the two runs.

### Reading of the result

The remaining misses point to three possible further tightenings of `SKILL.md`: give a reason for
every stated restriction, not only the rule; avoid the word "above" even when it is a
self-reference to an earlier part of the same document rather than to the conversation; and always
either name a skill in a handoff or say explicitly that none applies. They also point to a gap in
the run procedure itself: a single sample per case at this scale is not enough to tell a real
regression from single-sample noise, since both attempts' single regressions were caused by
different cases that had passed cleanly in the other attempt. Several samples per case before
applying a 100 percent deterministic and no-regression gate would separate the two.

### Other notes

No contamination in either attempt, 0 discarded in either. The live `prompts/` directory was
never created by any executor. Eval 22's deliverable was written to the scratch project's
`agents/` directory, which the run's copy step does not capture, so the grading agent was pointed
at that directory directly rather than at a copied transcript artifact. The
`aggregate_benchmark` script reported zeroed metrics in both attempts; the counts above come from
reading the per-run grading files directly.

## Decision

**HOLD.** The trigger layer passes both gates (all fifteen positives at 9 of 9, all fifteen
negatives at 0 fires). The behavioral layer does not: both attempts carry exactly one judgment
regression against the first-build baseline, on a different case each time, so neither attempt
clears the zero-regression gate even though each individually clears the 90 percent judgment
floor and comes within two points of the 100 percent deterministic floor. The user decided HOLD
after the second attempt rather than pursuing a third. This run's figures are not a new baseline;
`evals/runs/2026-09-26-prompt-author-first-build.md` remains the pinned baseline for the next
regeneration attempt.
