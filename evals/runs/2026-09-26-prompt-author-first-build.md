---
created: 2026-09-26
updated: 2026-09-26
---

# `prompt-author` 2026-09-26: first build, both eval layers

**Decision: SHIP.** Both eval layers meet their thresholds on the final measurement.

## Harness and environment

- Harness: `2.1.280 (Claude Code)`.
- Model for executors and for graders: `claude-sonnet-5` via the `sonnet` alias.
- Trigger runs: `--model claude-sonnet-5`, 9 runs per query, `--trigger-threshold 0.88`.
  Positives pass at 8 or 9 of 9; negatives pass only at 0 of 9.
- Prior baseline: none - first build.

## Trigger layer: 10 of 10 positives, 10 of 10 negatives. PASS.

Final per-query fire counts, 9 runs each:

| # | Polarity | Rate | Verdict | Query |
| --- | --- | --- | --- | --- |
| 1 | + | 9/9 | pass | Write me a prompt I can paste into ChatGPT to turn raw meeting notes into a list of action items with owners. |
| 2 | + | 9/9 | pass | Can you draft a prompt for a fresh Claude.ai chat that will help me plan a two-week trip to Japan on a budget? |
| 3 | + | 9/9 | pass | Here's the prompt I use for code review in Cursor and the answers keep coming back too vague. Can you improve it? |
| 4 | + | 9/9 | pass | Turn these notes into a proper prompt I can reuse: summarize support tickets, flag anything about billing, keep it under 100 words, plain text. |
| 5 | + | 9/9 | pass | I need a system prompt for a Claude Project that answers questions about our internal onboarding docs. |
| 6 | + | 8/9 | pass | What's wrong with this prompt? 'You are an expert. CRITICAL: ALWAYS double-check EVERYTHING. Write a blog post about Kubernetes.' |
| 7 | + | 9/9 | pass | Write a prompt I can give Gemini to extract invoice fields from scanned PDFs into JSON. |
| 8 | + | 9/9 | pass | Rewrite this prompt so it works better with Claude: 'Don't be verbose. Don't use bullet points. Don't make things up. Explain recursion.' |
| 9 | + | 9/9 | pass | I want to ask another AI to generate realistic test data for a users table. Write the prompt for me. |
| 10 | + | 9/9 | pass | Give me a reusable prompt template for writing release notes from a list of merged PR titles. |
| 11 | - | 0/9 | pass | Create a skill that formats SQL files before I commit them. |
| 12 | - | 0/9 | pass | Help me tighten the description in my go-dev skill's frontmatter so it triggers more reliably. |
| 13 | - | 0/9 | pass | Plan out migrating our CI from Jenkins to GitHub Actions. |
| 14 | - | 0/9 | pass | Write a Python script that calls the Claude API to summarize each file in a directory. |
| 15 | - | 0/9 | pass | Proofread docs/generative-ai/README.md for typos. |
| 16 | - | 0/9 | pass | My zsh prompt is slow to render after I added the git branch segment. How do I speed it up? |
| 17 | - | 0/9 | pass | Why do I keep getting permission prompts for every git status command? |
| 18 | - | 0/9 | pass | Research the current state of WebAssembly component model tooling and write it up as docs. |
| 19 | - | 0/9 | pass | Write the system prompt my Python app passes to the Claude API in messages.create, and update the code that sends it. |
| 20 | - | 0/9 | pass | My UserPromptSubmit hook isn't firing when I submit a prompt. How do I debug it? |

Positives failing: 0. Negatives fired: 0.

## Behavioral layer: deterministic 35/35, judgment 17/17. PASS.

No-skill baseline (`without_skill` arm): deterministic 17/35, judgment 12/17.

Per-case results, final run (all pass):

| Case | Deterministic | Judgment | Baseline (det, jud) | What it covers |
| --- | --- | --- | --- | --- |
| 1 | 3/3 | 2/2 | 2/3, 2/2 | Meeting-notes action-item prompt: code block, output shape, no all-caps emphasis, no-owner/no-date handling, no Claude-only feature |
| 2 | 4/4 | 2/2 | 4/4, 2/2 | Revising a vague code-review prompt: code block, no all-caps emphasis, drops double-check instruction, explains changes tied to the symptom |
| 3 | 3/3 | 2/2 | 3/3, 0/2 | Onboarding-docs system prompt: code block, out-of-scope handling, names #it-help, gives a reason, no all-caps emphasis |
| 4 | 4/4 | 1/1 | 1/4, 1/1 | Two-contract comparison prompt: code block, XML-tagged contract slots ordered before instructions, `{{snake_case_name}}` placeholders, defined comparison output shape |
| 5 | 1/1 | 1/1 | 0/1, 1/1 | Resume-help prompt: asks at most three targeted clarifying questions, or gives the prompt with stated assumptions |
| 6 | 3/3 | 1/1 | 1/3, 1/1 | Release-notes template: code block, `{{snake_case_name}}` placeholders listed with meanings, states audience and output format |
| 7 | 3/3 | 1/1 | 3/3, 1/1 | Invoice-extraction prompt: code block, named JSON keys, not-found handling, no Claude-only feature |
| 8 | 5/5 | 3/3 | 2/5, 2/3 | Long-running migration prompt (D2-D14): no stop-and-ask, evidence-based decisions logged, explicit working directory, decision log section, periodic usage check with pause/resume, goal stated first, plain language, scope-matched length |
| 9 | 1/1 | - | 0/1, - | Writes the prompt to a file and reports the path without pasting it inline |
| 10 | 2/2 | 2/2 | 1/2, 1/2 | Git-safety boundary, internal consistency and resumability, archive step excludes an early stop or open question |
| 11 | 2/2 | 1/1 | 0/2, 1/1 | Required fixes kept separate from speculative improvements, no em/en dash or curly quote/ellipsis, no hedging phrases |
| 12 | 4/4 | 1/1 | 0/4, 0/1 | Archived prompt file: written under the target project's prompts/ directory, path reported, ends with a move-to-archive/ instruction, not pasted inline, long enough to warrant a file |

Totals: deterministic 35/35 (100%), judgment 17/17 (100%).

## Retry 1: trigger negative "Write the system prompt my Python app passes to the Claude API..." fired 3/9

The first trigger attempt (20-query set, same protocol) had this negative fire 3 of 9 runs, a fail
against the 0-fires gate. The `claude-api` boundary in the skill's description was tightened from
a looser phrasing to "write the system prompt or other prompt text an app sends to the Claude API
(see claude-api)". The full 20-query set was then re-run in full, giving 0 fires on every negative,
including that query, with positives unaffected. That is the run recorded above.

## Retry 2: behavioral case 8's D7 expectation, deterministic 34/35

The first behavioral attempt scored deterministic 34/35: case 8's D7 expectation failed because the
prompt only told the agent to react "if there is a sign" of a usage limit, which is not a concrete,
checkable instruction. `SKILL.md`'s D7 line was made concrete: check usage at a fixed point during
the run using the named usage-check script, then pause and resume rather than fail. Only eval 8's
`with_skill` arm was re-run and re-graded against the amended line, scoring 8/8. The other eleven
eval cases ran, and are recorded above, against the earlier D7 line, since no other case reads that
line.

## Decision

**SHIP.** The final trigger measurement passes both gates (all ten positives at 8 of 9 or better,
all ten negatives at 0 fires) and the final behavioral measurement passes both gates (deterministic
100 percent, judgment 100 percent, at or above the 90 percent floor). Prior baseline: none - first
build. This run's figures become the baseline for the next regeneration of `prompt-author`.
