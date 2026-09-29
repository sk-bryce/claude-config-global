---
created: 2026-09-29
updated: 2026-09-29
---

# review-md v2: discovery record

Working record for the review-md v2 redesign: what was settled before discovery, the user
interview, the v1 baseline, and every candidate item with the user's decision on it. The approved
spec is `specs/drafts/review-md-v2.md`.

## 0. Settled before discovery

Decided with the user on 2026-09-29. These are not re-asked.

- Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document,
  and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There
  is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call.
- The ask-once branch is dropped. A multi-file target always gets an "across the set" section,
  which may say "no relation".
- v2 is built beside v1 and compared on the same fixtures before any swap, after a recorded v1
  baseline.
- The work is two plans: this one ends at an approved spec; Plan B (build, evals, swap, cleanup) is
  written from that spec.
- Plan B must include: planted-defect fixtures; updated evals; a v1 run on the new fixtures; pass
  criteria fixed in the spec before any v2 result exists; trigger evals at n of 9 or more with
  threshold 0.88 and negatives against code-review, deep-review, and skill-author; v2 kept from
  triggering (another name, `disable-model-invocation: true`) until the swap; migration of existing
  `review-tracking.md` entries; updates to `specs/skills.md` (the review-md section and deep-review's
  companion-pass rule), `skills/cursor-projection/references/harness-matrix.md`'s fork note, the
  README, and a decision record.
- Target trigger phrases: "review ...", "review and refine ...", "refine ...", "revise ...", and
  "proofread ...", scoped to Markdown.

## 1. Interview

Held with the user on 2026-09-29.

### 1.1 Markdown reviewed and where

- All four kinds: agent config (CLAUDE.md, AGENTS.md, SKILL.md, agent definitions), specs and
  plans, READMEs and docs sets, and notes.
- Run in this config repository, in work code repositories, and in personal projects.

### 1.2 What v1 does well and what it misses

- Does well: catches inconsistencies and mechanical errors.
- Misses: the bigger picture and interconnectedness errors (how parts of a document, or documents,
  relate to each other).
- Often has to be run more than once to surface all significant issues.

### 1.3 Priority among check areas

- Accuracy against the source first, then purpose and fit, then cross-document coherence, then
  polish.

### 1.4 Fix autonomy

- Keep the v1 policy: named fixes are applied; "fix" or "refine" applies high-confidence fixes;
  otherwise report only.
- Define "high-confidence" concretely.

### 1.5 Cost and latency

- Quality over cost: a few minutes and one Opus pass per call is acceptable. Cap only runaway
  cases such as large directories.

### 1.6 Tracking file in practice

- Rarely used so far.
- Checked 2026-09-29: no `review-tracking.md` exists in this repository or anywhere else in the
  user's home directory, so there are currently no entries to migrate.

### 1.7 Output shape

- A short summary, then findings grouped by severity (blocker, major, minor), with per-document and
  across-the-set findings kept separate.
- Keep the multi-select "pick what to fix" question at the end of a report-only review.

### 1.8 Trigger phrases and negatives

- Phrases typed: "review ...", "review and refine ...", "refine ...", "revise ...",
  "proofread ...".
- Must not trigger on: code review (functions, PRs, diffs, non-Markdown files); deep-review
  phrasing ("deep review", "is this a good idea", "be critical"), even on a Markdown file; skill
  and prompt authoring ("audit my skills", "improve this prompt"); plan writing ("plan this",
  "finalize this plan").

### 1.9 Relation to other skills and harnesses

- deep-review: stay separate. review-md checks correctness and fit; deep-review asks whether the
  thing is worth doing, and keeps calling review-md as its companion pass on Markdown targets.
- planner: leave it alone.
- Cursor: not a concern for v2, but keep v2 portable where possible.
- health-check: not discussed.

### 1.10 What success looks like

- No false positives: zero false positives on the eval fixtures, graded by majority; any fixture
  false positive fails v2. Rare ones in real use are tolerated.
- Catches things v1 misses.
- One run finds all significant issues in a document; no need to run it several times.

## 2. Baseline (v1)

Deterministic 91% (50/55), judgment 89% (8/9). Full run record:
`evals/runs/2026-09-29-review-md-v1-baseline.md`.

Expectations that failed by majority:

- eval-2 #2: Treats the broken-link and inconclusive-403-link findings as lower-confidence and
  reports them rather than silently resolving them
- eval-2 #3: Presents the reported (unresolved) findings as a multi-select question
- eval-4 #4: Stops without acting, rather than proceeding with a best-effort prose review
- eval-5 #4: Ends with a summary that separates confirmed-broken from inconclusive link findings
- eval-9 #11: Ends with a summary that separates per-document findings from findings across the
  set
- eval-12 #6: Records any newly settled cross-document decision under the set-level key rather
  than inside either document's section

Flaky expectations:

- eval-1 #7: Ends with a summary of what was checked and found
- eval-2 #4: Ends with a summary distinguishing what was changed from what was queued for the
  user to choose from
- eval-7 #5: Ends with a summary noting this was a full/fresh pass
- eval-9 #3: Dispatches one Sonnet subagent per document concurrently, then one further Sonnet
  subagent for the cross-document pass
- eval-11 #5: Presents the remaining unresolved findings as a multi-select question
- eval-12 #7: Ends with a summary reflecting what was skipped due to prior tracking, split into
  per-document and across-the-set findings

## 3. Candidate items

Each item uses the same block. `Settled: yes` items take their decision from section 0 and are
not re-asked.

### 3.1 Existing skill (E)

#### E1: Markdown-only gate
- What: After resolving targets, every resolved file must be `.md`. If any one is not, the skill stops and lets the request fall through to other skills or normal conduct.
- Recommendation: modify - keep the gate for a named non-Markdown target, and say in one line that review-md does not handle it. For a directory, filter its contents to `.md` and stop only when no `.md` file remains.
- Why: As written, one non-Markdown file anywhere in a directory stops the whole review. That is wrong for "review everything in docs/" when docs/ also holds an image or a JSON example. The "fall through to normal conduct" wording also lets the model do a best-effort prose review anyway. That is the tension behind the one failed eval-4 expectation.
- Evidence: skills/review-md/SKILL.md:39-50 (line 46: "for a directory target, check its contents"); specs/skills.md:143-145; eval-4 #4 failed by majority (evals/runs/2026-09-29-review-md-v1-baseline.md:38, grader notes at 94-107); skills/review-md/evals/evals.json:43-54.
- Overlap: also G1
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E2: Target resolution
- What: Turns the request into a concrete file list. A named file is that file, a list is that list, and a directory is "every file inside it". If the target is unclear, ask.
- Recommendation: modify - say whether directory resolution recurses into subdirectories, whether globs count, and how hidden or vendored folders (node_modules, .git, .worktrees) are handled. Keep the "ask if ambiguous" rule.
- Why: "Every file inside it" does not say whether to recurse. The answer changes both cost and the set the Opus pass sees. The runaway-directory concern in P7 depends on this rule being clear.
- Evidence: skills/review-md/SKILL.md:41-46; specs/drafts/review-md-v2-discovery.md:63-66 (1.5 caps only runaway cases such as large directories) and P7.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E3: Single-document mode (one resolved file, including a one-file directory)
- What: Exactly one resolved file, named directly or found as the only file in a directory, runs single-document mode: one review dispatch and no synthesis pass.
- Recommendation: modify - keep "one resolved file is not a set", so no "across the set" section. Replace "one dispatch" with the settled two-pass shape: a Sonnet pass on the document plus the Opus whole-target pass.
- Why: Section 0 says every invocation runs both passes, so a single document now also gets the Opus judgment pass. The rule that a one-file directory is not a set still holds and is worth keeping as an explicit case.
- Evidence: skills/review-md/SKILL.md:56-59; specs/skills.md:213-214 (acceptance: directory resolving to one file runs single-document); specs/drafts/review-md-v2-discovery.md:16-18.
- Overlap: none
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: modify - as recommended (2026-09-29)

#### E4: Multi-document mode selection signals
- What: Multi-document mode runs when a directory resolves to more than one file, or when the request uses holistic wording ("together", "as a whole", "do these still agree with each other", "hang together") over two or more targets.
- Recommendation: modify - any target that resolves to more than one file is multi-document, with no wording needed. Drop the holistic-language list as a mode signal.
- Why: Section 0 removes the middle case, so file count alone now decides the mode. The wording list only mattered for telling multi-document apart from the ask-once branch.
- Evidence: skills/review-md/SKILL.md:60-64; specs/skills.md:87-104; eval-9 and eval-11 mode-selection expectations passed (evals/runs/2026-09-29-review-md-v1-baseline.md:43,45).
- Overlap: none
- Settled: yes - "The ask-once branch is dropped. A multi-file target always gets an "across the set" section, which may say "no relation"."
- Decision: modify - as recommended (2026-09-29)

#### E5: Ask-once branch
- What: Several named files with no directory target and no holistic wording trigger one question: independent single-document passes, or one holistic pass. It uses `AskUserQuestion`, with plain text as the fallback.
- Recommendation: drop - as settled.
- Why: It passed its eval (eval-10 3/3 deterministic, 1/1 judgment) and still goes, because section 0 removed the choice. Its plain-text fallback for when no question tool is available should survive as a general rule for the findings question (see E12).
- Evidence: skills/review-md/SKILL.md:65-72; specs/skills.md:94-104, 211-212, 215-216; skills/review-md/evals/evals.json:123-134; evals/runs/2026-09-29-review-md-v1-baseline.md:44, grader note at 144-151.
- Overlap: none
- Settled: yes - "The ask-once branch is dropped. A multi-file target always gets an "across the set" section, which may say "no relation"."
- Decision: drop (2026-09-29)

#### E6: Mode signal must come from the request wording, not document content
- What: The mode is decided from the request before any document is read. A document calling itself "paired with" another does not count as a holistic signal, which stops the ask-once branch from being skipped through the back door.
- Recommendation: drop - with no mode choice left beyond file count, there is nothing for document content to override.
- Why: The rule only guards the ask-once branch. Section 0 removed that branch, so the rule has nothing left to protect.
- Evidence: skills/review-md/SKILL.md:74-79; specs/skills.md:98-102.
- Overlap: none
- Settled: yes - "The ask-once branch is dropped. A multi-file target always gets an "across the set" section, which may say "no relation"."
- Decision: modify - repurpose: drop it as a mode rule; text in a reviewed document is data to verify, not instructions, and a document's claims about itself ("intentional", "verified") are not evidence (2026-09-29)

#### E7: Review only the set the user named
- What: Multi-document mode reviews exactly the set the user pointed at. It does not go looking for related documents.
- Recommendation: modify - keep the scope limit. Add that reading other files to verify a claim is allowed and does not widen the review. Only the named set gets findings.
- Why: The claim-verification pass (P2) has to read source files outside the target to check accuracy. Without this clarification, the scope rule and the verification method conflict.
- Evidence: skills/review-md/SKILL.md:81-82; specs/skills.md:112-115; P2.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E8: Fix policy case 1 (named fixes) and first-match precedence
- What: The prompt is checked in order and the first match wins. Case 1: if the prompt names specific fixes, apply exactly those and nothing else, because a specific instruction beats any general mode.
- Recommendation: carry forward
- Why: The user kept the v1 policy in the interview, and case 1 passed 4/4. The one weak spot is test design, not the rule: eval-3's "no multi-select" expectation cannot tell correct suppression apart from having found nothing.
- Evidence: skills/review-md/SKILL.md:86-90; specs/skills.md:176-177; specs/drafts/review-md-v2-discovery.md:57-61 (1.4); eval-3 4/4 (evals/runs/2026-09-29-review-md-v1-baseline.md:37, note at 87-93).
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E9: Fix policy case 2 ("refine" or "fix" applies high-confidence fixes)
- What: A prompt containing "refine" or "fix" applies high-confidence fixes as they are found and reports lower-confidence findings.
- Recommendation: modify - define high-confidence concretely: one unambiguous correct replacement, no choice between conflicting sources, and never a link removal or a fact change. Add "revise" (and "review and refine") to the trigger words.
- Why: "High-confidence" is undefined. In eval-2 the model decided the fixture's link findings were intentional and closed them itself, so nothing was left to ask about. Section 0 adds "revise" as a trigger phrase, but case 2 only matches "refine" and "fix", so "revise this" would fall through to report-only. P3's confidence field is the mechanism that makes this rule checkable.
- Evidence: skills/review-md/SKILL.md:91-92; specs/skills.md:177-178; specs/drafts/review-md-v2-discovery.md:32-33, 61 (1.4 "Define high-confidence concretely"), P3; eval-2 #2 failed by majority, judgment 0/1 (evals/runs/2026-09-29-review-md-v1-baseline.md:36, note at 76-84).
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E10: Fix policy case 3 (report only)
- What: Any other prompt ("review this", "proofread this") reports findings only and applies nothing until the user chooses.
- Recommendation: carry forward
- Why: The user kept this in the interview, and it passed wherever it was tested. The grader flagged eval-9 #10 as close to trivially satisfied, so the new evals need a harder case.
- Evidence: skills/review-md/SKILL.md:93-94; specs/skills.md:178-179; eval-1 #5, eval-5 #3, eval-9 #10 passed (evals/runs/2026-09-29-review-md-v1-baseline.md:35,39,43, note at 134-138).
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E11: Per-finding fix policy and multi-file fix reporting
- What: In multi-document mode the fix policy is applied per finding. An applied cross-document fix must say which files changed and why.
- Recommendation: carry forward - apply it to every multi-file target, per E4.
- Why: The rule is sound, but it has never been exercised. eval-11 #4 passed only because no cross-document fix was applied. That is right, since which document is correct is not high-confidence, but the rule itself went untested.
- Evidence: skills/review-md/SKILL.md:100-103; specs/skills.md:179-182; evals/runs/2026-09-29-review-md-v1-baseline.md:160-162.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E12: Multi-select findings question
- What: Findings that are reported rather than applied (case 2 leftovers and all of case 3) are shown as one `AskUserQuestion` with `multiSelect: true`, so the user can pick what to fix in one round trip.
- Recommendation: modify - keep it as the report's last element. Say how findings map onto the tool's limits, for example one question per severity, up to 4 questions of 4 options each, with any overflow listed in the report and chosen by ID. Add a plain-text fallback when the tool is unavailable.
- Why: The user asked to keep it. A real review with more than 4 findings cannot fit in one multi-select question, and the skill never says what to do then. That gap likely explains why eval-11 produced three single-select questions instead. Only the ask-once branch had a plain-text fallback.
- Evidence: skills/review-md/SKILL.md:96-98; specs/skills.md:179; CLAUDE.md:50 (the tool caps at 4 questions per call and 4 options per question); specs/drafts/review-md-v2-discovery.md:77-78 (1.7); eval-2 #3 failed, eval-11 #5 flaky (evals/runs/2026-09-29-review-md-v1-baseline.md:36,56, note at 156-159).
- Overlap: also G13
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E13: md-checks.sh invocation and the "do not re-check" rule
- What: Before any dispatch, run `scripts/md-checks.sh` (through a hardcoded home-directory path) over all in-scope files in one call. Its output goes into the findings, and subagents are told not to re-derive its five categories.
- Recommendation: modify - keep the script-first split and the no-recheck rule. Call it through the `CLAUDE_CONFIG_DIR`-aware path form that skills use (CLAUDE.md:33), and pass its output through the fixed findings format.
- Why: Settling mechanical checks without a model is cheap and reliable. The hardcoded home-directory path goes against the path convention for skills. The script is shared with the deferred-checks hook, so any change to it also changes the hook.
- Evidence: skills/review-md/SKILL.md:105-122 (paths at 107, 111); scripts/md-checks.sh:1-34 (line 7-8: called by scripts/md-deferred-checks.sh too); CLAUDE.md:33; P3.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E14: md-checks placeholder check
- What: Flags the TODO, FIXME, XXX, and HACK markers when followed by a colon or parenthesis, a bare to-be-determined marker, a bracketed placeholder token, and filler Latin text, outside fenced code.
- Recommendation: carry forward
- Why: It is narrowly matched to avoid prose that only mentions TODOs, and it skips fences. An unfinished marker is a real defect in all four kinds of Markdown the user reviews.
- Evidence: scripts/md-checks.sh:83-96.
- Overlap: also G4
- Settled: no
- Decision: carry forward (2026-09-29)

#### E15: md-checks typography check
- What: Flags em and en dashes, curly quotes, and the ellipsis character outside fences, citing this user's CLAUDE.md Output Formatting rule.
- Recommendation: modify - apply it as a finding only where the project adopts the ASCII rule (this config repo, or a project whose CLAUDE.md or AGENTS.md states it). Elsewhere, report it as informational or skip it. It also still flags quoted characters inside inline code spans.
- Why: The user runs review-md in work repos and personal projects too. The ASCII rule is a personal preference, not a Markdown defect, so flagging a colleague's em dash in a work README is a false positive against the zero-false-positive bar.
- Evidence: scripts/md-checks.sh:24-25, 98-102; specs/drafts/review-md-v2-discovery.md:39-43 (1.1), 99-100 (1.10).
- Overlap: also G2
- Settled: no
- Decision: modify - as recommended; whether a project adopts the ASCII rule is decided by the orchestrator reading its context files (CLAUDE.md, AGENTS.md), and the decision and its reason are stated in the run declaration line; language characters (for example Japanese Kanji) are always allowed (2026-09-29)

#### E16: md-checks heading-skip check
- What: Flags a heading level that jumps by more than one, for example H2 straight to H4.
- Recommendation: modify - require a space after the hashes. `/^#+/` also matches a line like `#1 priority` or a shebang written outside a fence.
- Why: A skipped level is a real structure defect. The loose pattern is a small but concrete false-positive source.
- Evidence: scripts/md-checks.sh:104-110.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E17: md-checks relative-link check
- What: Flags a relative link target that does not exist on disk. It runs inside fences on purpose.
- Recommendation: modify - skip fenced code, or at least fences with a language tag. Strip an optional link title (`(path "title")`) before resolving.
- Why: Checking inside fences is a known source of false positives. The user's notes record `errors.AsType[T]` called on `err` in a Go fence being flagged as a broken link, still open. The script's own comment weighs "the occasional false positive" as acceptable, which conflicts with the v2 zero-false-positive bar.
- Evidence: scripts/md-checks.sh:32-34, 114-149; specs/drafts/review-md-v2-discovery.md:99-100 (1.10).
- Overlap: also G4
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E18: md-checks same-file anchor check
- What: Flags a `#anchor` link with no matching heading slug, using an approximate GitHub-style slugify.
- Recommendation: modify - bring the slugify closer to GitHub's: keep underscores and non-ASCII letters, and add `-1`, `-2` suffixes for duplicate headings. Or downgrade a miss to "check" rather than a finding.
- Why: The script accepts false "anchor not found" results as "cheap for a human to dismiss". Under the zero-false-positive bar each one counts. The slugify drops underscores and cannot see duplicate-heading suffixes. I did not verify GitHub's exact slug rules for this entry.
- Evidence: scripts/md-checks.sh:44-55, 117-136.
- Overlap: also G4
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E19: Link liveness via link-recheck-hook.sh
- What: For external URLs, the skill runs `link-recheck-hook.sh <file>`, which prints only broken or inconclusive links. It says the 24-hour freshness gate going silent is correct behavior, not a skipped check.
- Recommendation: modify - add a review mode (a flag or a sibling script) that checks every external link, not only those under a References heading. It should skip the freshness gate, tell DNS failure and connection refused (broken) apart from timeout (inconclusive) using curl's exit code, and report what it checked so silence cannot be mistaken for a clean result.
- Why: The script only scans from a `References` heading onward. The eval fixture's links sit under "Further reading", so the script prints nothing, and in the baseline the model judged the links from the fixture's own prose. A DNS failure comes back as code 000, which the script labels "inconclusive (no response or timeout)". The reference file classifies DNS failure as broken, so the fixture's dead `.example` link can never be reported as broken by this script. Both scripts are shared with the edit hook, so a separate review mode avoids changing hook behavior.
- Evidence: skills/review-md/SKILL.md:124-128; scripts/link-recheck-hook.sh:47-49, 57-59, 71-81, 105-109, 119-124; skills/review-md/references/document-generation.md:68; skills/review-md/evals/files/sample-doc.md:12-17; evals/runs/2026-09-29-review-md-v1-baseline.md:67-70; eval-5 #4 failed (baseline line 39).
- Overlap: also G7
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E20: 403/429-is-inconclusive rule
- What: A 403, 429, or other bot-protection response is reported as inconclusive, not broken. 404, DNS failure, and connection refused are broken. A resolving 3xx works. A timeout is inconclusive and retried once.
- Recommendation: carry forward - put the classification table into the link script (E19) and the Sonnet prompt template, and require the report to list broken and inconclusive links separately.
- Why: The judgment expectations on it passed (eval-1 #4, eval-5 #2). The failure was in reporting: eval-5 #4 (summary separating broken from inconclusive) failed.
- Evidence: skills/review-md/references/document-generation.md:64-71; skills/review-md/SKILL.md:36-37; scripts/link-recheck-hook.sh:36-41, 119-124; evals/runs/2026-09-29-review-md-v1-baseline.md:35,39.
- Overlap: also R4
- Settled: no
- Decision: carry forward (2026-09-29)

#### E21: Synced document-generation.md reference
- What: The skill loads its own copy of `reference/document-generation.md`, kept in sync by `scripts/sync.sh`, before checking any link.
- Recommendation: modify - load only what the review uses (the verification table and the broken-link handling), either as a trimmed reference or inside the prompt templates. Drop the instruction to load the full file.
- Why: Most of the file covers writing a References section (format tiers, red flags for authors), which a reviewer does not need. The copy is currently in sync; only the synced-copy header differs. Once the link script encodes the classification (E19, E20), loading the whole file is wasted context.
- Evidence: skills/review-md/SKILL.md:33-37; specs/skills.md:183-187; skills/review-md/references/document-generation.md:13-53 (authoring), 55-75 (verification); `diff` of reference/document-generation.md against the synced copy shows only the header note.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E22: What to check - Accuracy
- What: "Does it still describe things correctly?"
- Recommendation: modify - give it a method: script-extracted claims (paths, commands, flags, identifiers) are checked for existence, and the Sonnet pass verifies the rest against the source with a citation. Make it the top-priority check.
- Why: The user ranks accuracy against the source first, and v1 lists it as one bullet with no method. P2 covers the method.
- Evidence: skills/review-md/SKILL.md:134; specs/drafts/review-md-v2-discovery.md:52-55 (1.3), P2.
- Overlap: also P2
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: modify - as recommended (2026-09-29)

#### E23: What to check - Consistency
- What: "Internal contradictions, drifted terminology, mismatched examples."
- Recommendation: modify - keep in-section consistency in the Sonnet pass. Give cross-section consistency within one document (a claim in section 2 contradicting section 5) to the Opus whole-target pass as well.
- Why: The user says v1 catches inconsistencies but misses "interconnectedness errors" between parts of a document. A per-document checklist pass is where that gets lost.
- Evidence: skills/review-md/SKILL.md:135; specs/drafts/review-md-v2-discovery.md:45-50 (1.2).
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E24: What to check - Omissions
- What: "Gaps a reader would trip on."
- Recommendation: modify - move it to the Opus whole-target pass, which section 0 names as covering omissions.
- Why: Spotting a gap takes knowing what the document is for, which is judgment rather than proofreading.
- Evidence: skills/review-md/SKILL.md:136; specs/drafts/review-md-v2-discovery.md:16-18.
- Overlap: none
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: modify - as recommended (2026-09-29)

#### E25: What to check - Errors
- What: "Typos, broken formatting, dead links."
- Recommendation: modify - keep typos and formatting in the Sonnet proofread pass. Take out "dead links", since the link script and md-checks settle those mechanically (E13, E19).
- Why: As written, the checklist asks the model to judge dead links, which conflicts with the SKILL.md rule not to re-check what the scripts settle.
- Evidence: skills/review-md/SKILL.md:118-122, 137.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E26: What to check - Improvements
- What: "Anything that would make it clearer or more useful."
- Recommendation: modify - rename it to polish and rank it last. Allow only minor severity, require exact replacement text, and never auto-apply it under case 2.
- Why: An open-ended "anything clearer" category is the most likely source of false positives, and the bar is zero on fixtures. The user still wants polish, ranked last.
- Evidence: skills/review-md/SKILL.md:138; specs/drafts/review-md-v2-discovery.md:52-55 (1.3), 99-100 (1.10), P3.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E27: What to check - Fit for purpose
- What: Whether each section still earns its place given what the document is for. A well-written section can still not belong.
- Recommendation: carry forward - into the Opus whole-target pass.
- Why: This is the "bigger picture" check the user says v1 misses. It is a judgment call, and section 0 assigns it to the Opus pass.
- Evidence: skills/review-md/SKILL.md:139-140; specs/drafts/review-md-v2-discovery.md:16-18, 48-49.
- Overlap: also D1, also R6
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: carry forward (2026-09-29)

#### E28: Tracking file location and git status
- What: Decisions live in `<project root>/.claude/review-tracking.md`, or `<root>/review-tracking.md` when the root is itself a `.claude` directory. The file is treated as local state that may be gitignored, and committed only if the user wants.
- Recommendation: carry forward - add what "project root" means for a file outside any git repository (for example, the file's own directory, or asking once).
- Why: The location rule is reasonable, and the user reported no problems with it. Tracking is rarely used and no file exists anywhere yet, so there is nothing to migrate and the location can still change freely. "Project root" is undefined when the target is not inside a repository.
- Evidence: skills/review-md/SKILL.md:148-155; specs/skills.md:188-191; specs/drafts/review-md-v2-discovery.md:68-72 (1.6).
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E29: Tracking entry format (keyed by document path, free-text description, date)
- What: One section per document, keyed by path. Each entry is `[intentional]` or `[deferred]`, a free-text description, and a date.
- Recommendation: modify - anchor each entry to a short quote of the text it covers, and resurface it flagged as stale when that text changes.
- Why: A free-text description keeps an item hidden even after its section is rewritten, and matching findings to entries is left to model judgment. P4 covers this.
- Evidence: skills/review-md/SKILL.md:155-162; P4.
- Overlap: also P4
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E30: Tracking status - intentional
- What: `intentional` means permanently settled, never raised again.
- Recommendation: carry forward - with the quote anchor from E29, so "never" means "never while the quoted text is unchanged".
- Why: It removes repeat findings the user already dismissed, which is the stated reason tracking exists. eval-6 and eval-12 honored it.
- Evidence: skills/review-md/SKILL.md:144-146, 181; eval-6 4/4 and 1/1, eval-12 #2-#3 passed (evals/runs/2026-09-29-review-md-v1-baseline.md:40,46).
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E31: Tracking status - deferred
- What: `deferred` means "not now": skipped this pass but still open, and "may be worth resurfacing later".
- Recommendation: modify - say when a deferred item comes back, for example a count of deferred items in every summary, with the items listed on request or after a set age.
- Why: "May be worth resurfacing later" names no trigger, so in practice a deferred item behaves like an intentional one.
- Evidence: skills/review-md/SKILL.md:182-183; specs/skills.md:204-205.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E32: Read tracking before review and skip listed items (who filters)
- What: The in-scope tracking sections are read before reviewing. Each dispatched pass is given them and must not re-report settled items.
- Recommendation: modify - subagents report every finding, and the orchestrator filters them against tracking afterwards.
- Why: Filtering in the subagent adds tracking logic to every prompt and cannot be checked. Filtering in the orchestrator is a mechanical match on quote anchors. P4 covers this.
- Evidence: skills/review-md/SKILL.md:178-179, 205-207, 215-216, 227-228; P4.
- Overlap: also P4
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E33: Recording newly settled decisions
- What: When the user marks an item intentional or deferred during a pass, append it with today's date to the section that owns it: the document's section, or the set-level section for a cross-document finding.
- Recommendation: carry forward - and give the evals a scripted user reply so this can be tested.
- Why: The failed baseline expectation here was untestable, not wrong. With no user reply, nothing is ever settled, so nothing can be recorded.
- Evidence: skills/review-md/SKILL.md:185-187; eval-12 #6 failed (evals/runs/2026-09-29-review-md-v1-baseline.md:46, note at 163-167).
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E34: Set-level tracking sections
- What: Cross-document decisions go under a separate `## set: <dir or comma-joined file list>` key, never inside one document's section.
- Recommendation: modify - key each cross-document entry to the files it involves (for example the pair that disagree) plus a quote anchor, not to the scope of the review that found it.
- Why: A key built from the review scope is fragile. The same two files reviewed as `docs/` and later as a named pair, or in a different order, miss each other's entries. Honoring set-level entries worked in eval-12; only recording them was untested.
- Evidence: skills/review-md/SKILL.md:164-176; specs/skills.md:192-197; eval-12 #3-#4 passed, #6 failed (evals/runs/2026-09-29-review-md-v1-baseline.md:46).
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E35: Full/fresh review clears tracking
- What: "Full", "fresh", or "complete" clears the in-scope tracking sections before review, never the whole file.
- Recommendation: modify - ignore the in-scope entries for this pass instead of deleting them. Re-dismissing an item updates its entry.
- Why: Deleting throws away permanent "intentional" decisions just to see everything once. After a fresh pass the user has to re-settle every item or lose it. Ignoring the entries gives the same view without the loss.
- Evidence: skills/review-md/SKILL.md:189-192; specs/skills.md:196-199; eval-7 5/5 with #5 flaky (evals/runs/2026-09-29-review-md-v1-baseline.md:41,53, note at 122-125).
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E36: Subagent dispatch and tier (the invoking turn never reviews)
- What: Every review pass goes to a Sonnet subagent. The invoking turn only dispatches, applies approved fixes, and updates tracking.
- Recommendation: modify - keep "the orchestrator never reviews". Change the tiers to the settled pair: Sonnet per document plus one Opus whole-target pass.
- Why: Section 0 settles the tier change. v1's reasoning that "Opus is not warranted" is replaced by the user's accepted cost of one Opus pass per call.
- Evidence: skills/review-md/SKILL.md:194-201, 264-265; specs/skills.md:116-121; specs/drafts/review-md-v2-discovery.md:16-18, 63-66 (1.5).
- Overlap: none
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: modify - as recommended, plus a tier guard: the orchestrator warns and asks the user to confirm only when the session reports a tier below Sonnet (2026-09-29)

#### E37: Per-document fan-out
- What: One dispatch per document, issued together in one response and never merged, each running the unchanged checklist against its own tracking section.
- Recommendation: carry forward - as the Sonnet pass for every multi-file target. Say explicitly that the calls must go in a single message.
- Why: It keeps each pass bounded and is required by section 0. The baseline caught a run that dispatched sequentially, so the concurrency instruction is not being followed reliably.
- Evidence: skills/review-md/SKILL.md:212-217; specs/skills.md:147-151, 219-220; eval-9 #3 flaky (evals/runs/2026-09-29-review-md-v1-baseline.md:54-55, note at 134-138).
- Overlap: none
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: carry forward (2026-09-29)

#### E38: Cross-document synthesis pass
- What: After the fan-out, one more dispatch gets the full set plus the per-document findings. It reports only cross-document findings (contradictions, terminology and heading drift, duplicated coverage, coverage gaps) and must not repeat per-document findings.
- Recommendation: modify - make it the Opus whole-target pass, run on every invocation. Keep the four cross-document categories and add purpose, fit, and omissions. A single document gets the same pass without the cross-document categories.
- Why: Section 0 folds synthesis into the Opus pass and makes it unconditional. The four categories were caught reliably in the baseline (eval-9 judgment 2/2), so they carry over as they are. P7 covers the size cap when the whole target is too large.
- Evidence: skills/review-md/SKILL.md:218-228; specs/skills.md:151-157; evals/runs/2026-09-29-review-md-v1-baseline.md:43; P7.
- Overlap: also D4
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: modify - as recommended (2026-09-29)

#### E39: Keep per-document and cross-document findings distinct
- What: The two result sets stay separate all the way to the user and are never merged into one list.
- Recommendation: carry forward - within the severity-grouped output, as two blocks. Show the "across the set" block even when it says "no relation".
- Why: The user asked for this output shape, and section 0 requires the across-the-set section on every multi-file target. eval-9 #9 passed.
- Evidence: skills/review-md/SKILL.md:230-233; specs/skills.md:221-222; specs/drafts/review-md-v2-discovery.md:74-78 (1.7); evals/runs/2026-09-29-review-md-v1-baseline.md:43.
- Overlap: none
- Settled: yes - "The ask-once branch is dropped. A multi-file target always gets an "across the set" section, which may say "no relation"."
- Decision: carry forward (2026-09-29)

#### E40: Batching instruction in every dispatch prompt
- What: Every dispatch prompt must tell the subagent to batch independent Read, Grep, and Bash lookups, because subagents do not inherit CLAUDE.md. This is backed by a measured serial-lookup incident costing several million cache-read tokens.
- Recommendation: carry forward - as a fixed line in each prompt template. Keep the rationale only in the spec.
- Why: The instruction is cheap and fixes a measured cost problem. The rationale takes 19 lines of the skill body and repeats the spec. P5 covers moving it.
- Evidence: skills/review-md/SKILL.md:235-253; specs/skills.md:161-175, 208-209; P5.
- Overlap: also P5
- Settled: no
- Decision: carry forward (2026-09-29)

#### E41: "Why the dispatch stays even when the skill is forked" section
- What: Body text explaining that the subagent dispatches carry the tier guarantee and are not redundant under `context: fork`.
- Recommendation: drop
- Why: It exists only to defend the fork arrangement. With an inline orchestrator (P1), there is nothing left to defend. Design reasoning belongs in the spec (P5).
- Evidence: skills/review-md/SKILL.md:255-262; specs/skills.md:137-142; P1, P5.
- Overlap: none
- Settled: no
- Decision: drop (2026-09-29)

#### E42: Summary format
- What: Every invocation "ends with" a short summary of what was checked, found, changed or queued, and newly tracked. Multi-document mode splits findings into per-document and across-the-set.
- Recommendation: modify - fix the order: a short summary first, then findings by severity (blocker, major, minor) in per-document and across-the-set blocks, then the multi-select question last. Replace "ends with a summary" with that order. Require the summary to list broken and inconclusive links separately, what tracking skipped, and whether this was a full/fresh pass.
- Why: "Ends with a summary" conflicts with the question that must come last. Most failed or flaky baseline expectations are summary-position disputes (eval-1 #7, eval-2 #4, eval-5 #4, eval-7 #5, eval-9 #11, eval-12 #7). The user asked for summary first, then findings by severity.
- Evidence: skills/review-md/SKILL.md:267-274; specs/skills.md:206, 224-225; specs/drafts/review-md-v2-discovery.md:74-78 (1.7); evals/runs/2026-09-29-review-md-v1-baseline.md:39,43,48-58, notes at 71-75, 111-115, 139-143, 168-170.
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E43: Frontmatter - name
- What: `name: review-md`.
- Recommendation: carry forward - use a different name plus `disable-model-invocation: true` while v2 is built beside v1, and take the `review-md` name at the swap.
- Why: Section 0 settles how v2 stays silent until the swap. The final name has no reason to change.
- Evidence: skills/review-md/SKILL.md:2; specs/drafts/review-md-v2-discovery.md:21-31.
- Overlap: none
- Settled: yes - "Plan B must include: planted-defect fixtures; updated evals; a v1 run on the new fixtures; pass criteria fixed in the spec before any v2 result exists; trigger evals at n of 9 or more with threshold 0.88 and negatives against code-review, deep-review, and skill-author; v2 kept from triggering (another name, `disable-model-invocation: true`) until the swap; migration of existing `review-tracking.md` entries; updates to `specs/skills.md` (the review-md section and deep-review's companion-pass rule), `skills/cursor-projection/references/harness-matrix.md`'s fork note, the README, and a decision record."
- Decision: carry forward (2026-09-29)

#### E44: Frontmatter - description
- What: The trigger description: "review", "proofread", "refine" with a `.md` subject, the holistic phrases, and a negative for non-Markdown files.
- Recommendation: modify - add "revise" and "review and refine". Add negatives for deep-review phrasing even on Markdown, skill and prompt authoring, and plan writing. Drop the holistic-phrase list, which no longer selects a mode.
- Why: Section 0 fixes the trigger phrases. The interview adds negatives the current description lacks. There is no trigger eval yet, so the description has never been measured.
- Evidence: skills/review-md/SKILL.md:3-13; specs/skills.md:105-111; specs/drafts/review-md-v2-discovery.md:32-33, 80-87 (1.8); evals/runs/2026-09-29-review-md-v1-baseline.md:20.
- Overlap: none
- Settled: yes - "Target trigger phrases: "review ...", "review and refine ...", "refine ...", "revise ...", and "proofread ...", scoped to Markdown."
- Decision: modify - as recommended (add "revise ..." and "review and refine ...", plus the interview negatives); do not add "fix ..." as a trigger phrase (2026-09-29)

#### E45: Frontmatter - model
- What: `model: sonnet` pins the skill's tier.
- Recommendation: modify - decide together with P1. With an inline orchestrator, the tier guarantee lives in the dispatch calls (Sonnet per document, Opus whole-target). Keep a skill-level pin only if the orchestrator's own work needs one.
- Why: v1's pin sets the tier of the forked orchestrator. It does not set the tier of the passes, which set their own model. I did not verify what an inline skill's `model:` pin does to the calling session's model.
- Evidence: skills/review-md/SKILL.md:14; specs/skills.md:116-121; P1.
- Overlap: none
- Settled: no
- Decision: modify - keep `model: opus` as a forward-compatible pin; the tier guarantee comes from the dispatch calls, and the orchestrator guards at a Sonnet floor with a confirm question below it (2026-09-29)

#### E46: Frontmatter - effort
- What: `effort: medium`, described in the spec as a ceiling, not a floor.
- Recommendation: drop - put `ultrathink` in the Opus pass prompt instead.
- Why: The pin never reaches the dispatched subagents that do the work, and a medium ceiling conflicts with the settled Opus judgment pass. P6 covers this.
- Evidence: skills/review-md/SKILL.md:15; specs/skills.md:122-128; P6, citing evals/runs/2026-09-05-deep-review-ablation.md finding 4.
- Overlap: also D26, also P6
- Settled: no
- Decision: drop (2026-09-29)

#### E47: Frontmatter - context
- What: `context: fork` runs the whole skill in an isolated fork where the harness honors it.
- Recommendation: drop - per P1, run the orchestrator inline.
- Why: The orchestrator must dispatch subagents and ask the findings question, and whether a forked skill can do either is unverified. The isolation that matters already comes from the dispatched passes. Section 0 already lists updating the harness-matrix fork note.
- Evidence: skills/review-md/SKILL.md:16; specs/skills.md:129-142; specs/drafts/review-md-v2-discovery.md:29-30, P1.
- Overlap: also P1
- Settled: no
- Decision: drop (2026-09-29)

#### E48: Frontmatter - agent
- What: `agent: general-purpose`, the agent type for the fork.
- Recommendation: drop - it only matters alongside `context: fork`.
- Why: It follows E47.
- Evidence: skills/review-md/SKILL.md:17; specs/skills.md:129; P1.
- Overlap: also P1
- Settled: no
- Decision: drop (2026-09-29)

#### E49: Frontmatter - background
- What: `background: false`, so the fork runs in the foreground and can show the multi-select question.
- Recommendation: drop - it only matters alongside `context: fork`. An inline orchestrator is foreground by nature.
- Why: It follows E47.
- Evidence: skills/review-md/SKILL.md:18; specs/skills.md:137-138; P1.
- Overlap: also P1
- Settled: no
- Decision: drop (2026-09-29)

#### E50: Provenance comment block
- What: The HTML comment after the frontmatter: created, updated, spec pointer, generated-by, model, harness.
- Recommendation: carry forward - regenerate it for v2, pointing at the v2 spec, and bump `updated:` on every edit.
- Why: The pointer from skill to spec is how the repo's spec-anchored workflow finds the source of intent.
- Evidence: skills/review-md/SKILL.md:21-28.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### E51: Spec non-goals
- What: Non-Markdown files go to code review, skill authoring goes to skill-author, and multi-document mode stays within the named set.
- Recommendation: modify - add the interview's other non-goals: deep-review's "is this worth doing" question (deep-review keeps calling review-md as its companion pass), prompt authoring, and plan writing.
- Why: The current non-goals leave out the neighbors the user named, and the description (E44) needs matching spec text.
- Evidence: specs/skills.md:112-115; specs/drafts/review-md-v2-discovery.md:80-95 (1.8, 1.9).
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### E52: Spec acceptance criteria
- What: Shared and multi-document-only acceptance lists covering the gate, fix policy, link rules, tracking, summary, batching, mode selection, fan-out shape, and separate reporting.
- Recommendation: modify - rewrite them for v2 before any v2 result exists. Drop the ask-once criteria. Add zero false positives on fixtures, one run finding all planted defects, and the Opus pass on every call.
- Why: Section 0 requires pass criteria fixed in the spec first. The interview sets the success bar at zero fixture false positives and one run finding everything significant.
- Evidence: specs/skills.md:200-225; specs/drafts/review-md-v2-discovery.md:25-26, 97-102 (1.10).
- Overlap: none
- Settled: yes - "Plan B must include: planted-defect fixtures; updated evals; a v1 run on the new fixtures; pass criteria fixed in the spec before any v2 result exists; trigger evals at n of 9 or more with threshold 0.88 and negatives against code-review, deep-review, and skill-author; v2 kept from triggering (another name, `disable-model-invocation: true`) until the swap; migration of existing `review-tracking.md` entries; updates to `specs/skills.md` (the review-md section and deep-review's companion-pass rule), `skills/cursor-projection/references/harness-matrix.md`'s fork note, the README, and a decision record."
- Decision: modify - as recommended (2026-09-29)

#### E53: Behavioral eval set (evals.json)
- What: 12 cases with 64 expectations (55 deterministic, 9 judgment) covering the fix policy, the gate, link rules, tracking, multi-document mode, and ask-once.
- Recommendation: modify - fix the label drift (the expectations say `httpstat.us/403`, the fixture uses `httpbin.org/status/403`). Merge the redundant expectations the grader named (eval-9 #9 and #11, eval-10 #1-#4). Add a scripted user reply wherever a later step depends on one (eval-12 #6). Drop eval-10 with ask-once. Add a trigger eval set.
- Why: Section 0 requires updated evals and trigger evals. The baseline grader notes list trivially satisfied, untestable, and mislabeled expectations that would blur a v1-to-v2 comparison.
- Evidence: skills/review-md/evals/evals.json:13, 62 (httpstat.us), 123-134 (eval-10); skills/review-md/evals/files/sample-doc.md:16; evals/runs/2026-09-29-review-md-v1-baseline.md:20, 60-170.
- Overlap: none
- Settled: yes - "Plan B must include: planted-defect fixtures; updated evals; a v1 run on the new fixtures; pass criteria fixed in the spec before any v2 result exists; trigger evals at n of 9 or more with threshold 0.88 and negatives against code-review, deep-review, and skill-author; v2 kept from triggering (another name, `disable-model-invocation: true`) until the swap; migration of existing `review-tracking.md` entries; updates to `specs/skills.md` (the review-md section and deep-review's companion-pass rule), `skills/cursor-projection/references/harness-matrix.md`'s fork note, the README, and a decision record."
- Decision: modify - as recommended (2026-09-29)

#### E54: Eval fixtures
- What: `sample-doc.md`, `sample-config.json`, the two-file `doc-set/`, and two tracking fixtures.
- Recommendation: modify - replace them with planted-defect fixtures that do not describe their own defects. Put at least one dead link under a References heading and one elsewhere, and include false-positive traps (fenced code, example paths, a legitimate em dash in a work-repo document).
- Why: The fixtures announce their own defects ("intentionally dead", "deliberately disagree"). That cued the eval-2 run into closing the link findings on its own, and the baseline caveats say new fixtures should not do this. The fixture's link section is outside what link-recheck-hook.sh scans (E19).
- Evidence: skills/review-md/evals/files/sample-doc.md:3-4, 14-17; evals/runs/2026-09-29-review-md-v1-baseline.md:76-79, 174-177; specs/drafts/review-md-v2-discovery.md:25.
- Overlap: none
- Settled: yes - "Plan B must include: planted-defect fixtures; updated evals; a v1 run on the new fixtures; pass criteria fixed in the spec before any v2 result exists; trigger evals at n of 9 or more with threshold 0.88 and negatives against code-review, deep-review, and skill-author; v2 kept from triggering (another name, `disable-model-invocation: true`) until the swap; migration of existing `review-tracking.md` entries; updates to `specs/skills.md` (the review-md section and deep-review's companion-pass rule), `skills/cursor-projection/references/harness-matrix.md`'s fork note, the README, and a decision record."
- Decision: modify - as recommended (2026-09-29)


### 3.2 deep-review (D)

#### D1: Purpose-fit question, bounded to the document's own purpose
- What: deep-review's purpose-fit question holds the artifact against its stated purpose ("does it deliver that need, part of it, or something adjacent?"), then questions the purpose itself ("is it the need behind the need or a proxy for it?").
- Recommendation: modify - put the first half in the Opus judgment pass prompt as a named check: does each document deliver its own stated purpose, part of it, or something adjacent, and is that stated purpose still current. Leave out the second half, which questions the frame itself.
- Why: interview 1.2 says v1 misses "the bigger picture". The first half targets that directly, and review-md already asks it in weaker form ("does each section still earn its place"). The second half is what the spec says separates deep-review from review-md: review-md measures against the document's own purpose, and deep-review "questions the frame itself". Adopting it would blur the split the user chose to keep (1.9) and weaken the negative trigger cases against deep-review that section 0 requires.
- Evidence: skills/deep-review/SKILL.md:50-53; specs/skills.md:392-396; skills/review-md/SKILL.md:139; specs/drafts/review-md-v2-discovery.md:47-50, 91-93
- Overlap: same as E27
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D2: Assumptions question, recast as a document's load-bearing claims
- What: deep-review lists what the target rests on, says whether each assumption holds, marks the load-bearing one, and says how one would know it had stopped holding.
- Recommendation: modify - add to the Opus pass: name the claims or unstated preconditions the document depends on (an environment, a file layout, another document's content). Mark any whose failure would make the document wrong as a whole, and rate it blocker. Where it is cheap, say what change would make the claim go stale.
- Why: accuracy against the source is the user's top priority (1.3), and cross-document relations are the stated v1 gap (1.2). The "load-bearing" idea gives the severity scale (1.7) a principled blocker criterion. The "how would one know it stopped holding" sub-prompt is a staleness check, which suits docs, specs, and agent config. The worth framing ("sinks the whole thing") stays with deep-review.
- Evidence: skills/deep-review/SKILL.md:54-56; specs/skills.md:622-624; specs/drafts/review-md-v2-discovery.md:47-50, 54-55, 76-78
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D3: Value and Alternatives questions
- What: deep-review asks whether the target solves a real problem, and whether a different thing (do nothing, a smaller version, an existing tool) or the same thing done differently would be better.
- Recommendation: drop - keep both out of review-md's passes. A document whose existence looks unjustified may get one line pointing the user to deep-review.
- Why: these are the worth questions the user assigned to deep-review in 1.9 ("deep-review asks whether the thing is worth doing"). Asking them on every "review this" would also add findings that are opinions, not defects, against the zero-false-positive criterion (1.10). The spec keeps deep-review's list short "on purpose", because extra questions dilute attention. The same holds in reverse for review-md's Opus pass.
- Evidence: skills/deep-review/SKILL.md:39-49; specs/skills.md:629-631; specs/drafts/review-md-v2-discovery.md:91-93, 99-100
- Overlap: none
- Settled: no
- Decision: drop (2026-09-29)

#### D4: Fit question, recast as placement and duplication within the set
- What: deep-review's Fit question asks about right layer, right owner, right artifact, and "Does something already do this?"
- Recommendation: modify - adopt the placement half for the Opus pass's cross-document check: content that belongs in a sibling document, content duplicated across documents, and a section whose owner is another file in the set. Drop the "right time" and "right owner" organisational framing.
- Why: interview 1.2 names interconnectedness errors as the main v1 miss. Duplicated content in two places is the usual source of the drift that D6 traces. This is correctness and fit of the set, which is review-md's job under 1.9, not worth.
- Evidence: skills/deep-review/SKILL.md:42-44; specs/drafts/review-md-v2-discovery.md:47-50, 91-93
- Overlap: same as E38
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D5: Individually and holistically, and prose logic that should be a script
- What: deep-review's first granularity rule: consider every file both individually and holistically, since "deterministic prose logic that works holistically might still be better as a separate script".
- Recommendation: modify - the individual-and-holistic half is already built into v2 by the two-pass design, so nothing to add there. Carry the script half into the Opus pass prompt only for agent-config targets (SKILL.md, CLAUDE.md, agent definitions), as a minor-severity suggestion.
- Why: agent config is one of the four kinds the user reviews (1.1). Prose that encodes a deterministic procedure is a real fit defect in that kind of document. Capping it at minor keeps it from counting as a false positive against 1.10 when the user disagrees.
- Evidence: skills/deep-review/SKILL.md:60-61; plans/deep-review-rearchitecture.md:262-265; specs/drafts/review-md-v2-discovery.md:16-18, 41-42
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D6: Second-order effects, recast as claim propagation across the set
- What: deep-review asks the reviewer to "trace second-order effects: what this breaks, complicates, or forecloses later".
- Recommendation: carry forward - as an Opus-pass instruction: for each wrong or stale claim found, check where else in the set it is repeated or relied on, and report every location in one finding.
- Why: the one recorded case where review-md beat deep-review was exactly this. A stale coverage claim had spread across four artifacts, and a review-md pass caught it. Making it an explicit instruction serves "one run finds all significant issues" (1.10), because otherwise each copy tends to surface on a separate run (1.2).
- Evidence: skills/deep-review/SKILL.md:64; specs/skills.md:500-504; specs/drafts/review-md-v2-discovery.md:47-50, 101-102
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D7: Every check area answered by name, "no concern" stated
- What: deep-review requires every question to be answered by name, in order, with "no concern" as a legitimate stated answer. A silently skipped question is "the failure this skill exists to prevent".
- Recommendation: carry forward - the Opus pass returns one labelled line or block per check area (accuracy, purpose-fit, omissions, cross-document), and says "no concern" where that is the answer. The "across the set" section already follows this pattern ("may say 'no relation'").
- Why: interview 1.2 reports v1 must be run more than once to surface everything. A named, per-area return makes a skipped area visible in the output and assertable in an eval. Caveat: deep-review's acceptance criterion for this had no behavioral case when written, so its effect on thoroughness is unmeasured.
- Evidence: skills/deep-review/SKILL.md:70-73; specs/skills.md:632-636, 739-742; specs/drafts/review-md-v2-discovery.md:19-20, 47-50
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D8: Evidence rule: cite lines, precision over politeness
- What: deep-review says to cite specific lines, sections, or claims as evidence ("'Looks fine overall' is not a finding"), and prefers a falsifiable objection ("this breaks when the input is empty") to a hedge ("could be more robust").
- Recommendation: carry forward - into both passes' prompt templates. Every finding carries a line reference and a quoted span, and a finding with no quotable anchor is not reported.
- Why: this is the substance behind P3's fixed format. A cited finding can be checked by the user and by the grader, and an uncitable one is the likeliest false positive (1.10). The 2026-09-11 run records that where deep-review ran end to end, its findings were "tied to specific quotes or line numbers".
- Evidence: skills/deep-review/SKILL.md:62-66; specs/skills.md:625-628; evals/runs/2026-09-11-deep-review-full-suite.md:173-175; P3
- Overlap: also P3
- Settled: no
- Decision: carry forward (2026-09-29)

#### D9: One plain leading sentence per finding
- What: the unexecuted deep-review plan adds: "Each finding leads with one plain sentence a reader can act on, before any supporting prose", with precision kept in the evidence.
- Recommendation: carry forward - make it part of the fixed findings format: a one-sentence plain statement first, then evidence and replacement text.
- Why: it matches the user's global response style (short sentences, answer first) and the requested "short summary, then findings" shape (1.7). It is cheap. It is unmeasured: the plan that introduces it has not run, and its evidence is one observed pass (2026-09-12) whose analysis was acted on only through an unlabelled closing paragraph.
- Evidence: plans/deep-review-rearchitecture.md:362-366, 671-676; specs/drafts/review-md-v2-discovery.md:76-78
- Overlap: also P3
- Settled: no
- Decision: carry forward (2026-09-29)

#### D10: A clean result is valid; do not manufacture findings
- What: deep-review states that "no concern" on every question and a clean "Proceed" is a valid outcome, and that manufacturing objections is "the likelier failure for a skill built to find fault". It has an acceptance criterion for it.
- Recommendation: carry forward - put the sentence in both pass templates, and add at least one sound, defect-free fixture whose pass criterion is zero findings above minor.
- Why: the user's first success criterion is zero false positives on the fixtures (1.10). v2 adds an Opus pass on every call (section 0), which is a new chance to invent concerns about fit. A reviewer told to look for bigger-picture issues will find some unless told that none is a legitimate answer.
- Evidence: skills/deep-review/SKILL.md:92-95; specs/skills.md:724-725; specs/drafts/review-md-v2-discovery.md:16-18, 99-100
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D11: Four-term verdict ladder
- What: deep-review ends with one of Proceed / Proceed with changes / Reconsider scope / Do not proceed, plus a one-sentence reason.
- Recommendation: drop - review-md's output is the short summary plus severity-grouped findings the user chose in 1.7. The summary may say whether any blocker was found. It gives no worth verdict.
- Why: the ladder judges worth, which is deep-review's job (1.9). A verdict line would also blur the two skills' outputs for a user choosing between them. The spec records that a second, artifact-shaped ladder was tried inside deep-review and dropped because it "forced a target-classification branch that can misfire".
- Evidence: skills/deep-review/SKILL.md:76-80; specs/skills.md:647-660; specs/drafts/review-md-v2-discovery.md:76-78, 91-93
- Overlap: none
- Settled: no
- Decision: drop (2026-09-29)

#### D12: Strongest counter-argument, recast as a per-finding false-positive check
- What: deep-review follows its verdict with "the strongest argument against the verdict" in one sentence, because a genuine counter-argument "cannot be written for a verdict that was never reasoned through".
- Recommendation: modify - with no verdict (D11), apply the idea per finding: for each blocker or major finding, the pass states in one sentence the strongest case that the text is intended or correct as written. It drops the finding if that case wins.
- Why: this points the "hard to fake" check at the user's top criterion, zero false positives (1.10). Keeping it to blocker and major limits the cost. Its effect is unmeasured in both skills: deep-review's rationale is argued, not tested.
- Evidence: skills/deep-review/SKILL.md:81-84; specs/skills.md:651-655; specs/drafts/review-md-v2-discovery.md:99-100
- Overlap: none
- Settled: no
- Decision: modify - fold into G10: no separate filter; G10's per-finding verification of blocker and major findings checks the quoted evidence against the source and names the best case that the text is correct as written (2026-09-29)

#### D13: Premise findings first, and a one-line "went unreviewed" statement
- What: deep-review leads with premise findings and leaves execution findings to sibling reviews "or say in one line that they went unreviewed".
- Recommendation: modify - v2 orders by severity (1.7), not by premise. Adopt the second half: the report ends with one line naming anything not reviewed (code-block correctness, a part skipped by the P7 size cap, worth questions left to deep-review).
- Why: stating scope limits plainly stops a clean report from reading as full coverage. This matters most when P7 splits or trims a large target, where a silent gap looks like a pass.
- Evidence: skills/deep-review/SKILL.md:73-75; specs/skills.md:635-637; specs/drafts/review-md-v2-discovery.md:76-78, P7
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D14: Output bound, and stating what the bound measures
- What: deep-review bounds its output per question (400-800 words, 1200 ceiling in the body). The unexecuted plan tightens this to 200-400/800 and records that the spec and body had "disagreed by 7.5x" because one bounded the whole return and the other each question. Its cut rule drops "the weakest finding before a question's answer".
- Recommendation: modify - bound the prose per finding (the plain sentence plus short evidence), not the number of findings. Wherever v2 states a bound, the spec and the prompt template state the same number and the same scope.
- Why: capping findings conflicts with "one run finds all significant issues" (1.10), because a cut finding is a missed one. Capping prose per finding keeps reports readable without losing coverage. The scope lesson is measured drift in this repository, and P5's templates are where it would recur.
- Evidence: skills/deep-review/SKILL.md:85-90; plans/deep-review-rearchitecture.md:79-84, 224-251; specs/drafts/review-md-v2-discovery.md:101-102, P5
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D15: Actions section: a finding must be a concrete change
- What: the plan adds an Actions section restating every surviving finding as a concrete change, on the principle that "a finding that cannot be written as a concrete change is either not real or not this pass's business".
- Recommendation: modify - no separate section. P3's exact replacement text already plays that role. Adopt the filter: a finding with no concrete change is either dropped or labelled as a question for the user, never reported as a defect.
- Why: the filter serves 1.10 (false positives) and fix policy (1.4), since applying a fix needs a concrete change. A second section repeating the findings would duplicate the list the user already picks fixes from (1.7). The plan is unexecuted, so the filter's effect is unmeasured.
- Evidence: plans/deep-review-rearchitecture.md:348-360, 678-689; specs/drafts/review-md-v2-discovery.md:59-61, 76-78, P3
- Overlap: also P3
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D16: Four-field context brief and the hard gate
- What: deep-review writes a four-field brief (Purpose, Alternatives rejected, Constraints, Prior findings) and refuses to dispatch while any field is unknown.
- Recommendation: modify - keep a context block for the Opus pass, with no gate: the user's request, any statement of the documents' purpose found in or near them, the source files the documents describe, and known constraints. Missing fields are passed as "none found". The pass never stops for them.
- Why: the ablation's one clean result is that the brief is load-bearing. Only arms given it caught a constraint violation "not inferable from the artifact", and review-md's accuracy and fit checks need the same outside facts. The gate itself is what failed. It caused both real deterministic misses on 2026-09-11 (evals 8 and 10) and three earlier 0/4 shapes, and it adds about 80 lines. A stop-and-ask step would also bring back the ask-before-reviewing friction section 0 removed by dropping ask-once.
- Evidence: evals/runs/2026-09-05-deep-review-ablation.md:52-57, 61-65, 106-110; evals/runs/2026-09-11-deep-review-full-suite.md:28-33, 161-169; skills/deep-review/SKILL.md:130-211; specs/skills.md:597-601; specs/drafts/review-md-v2-discovery.md:19-20
- Overlap: none
- Settled: no
- Decision: modify - mechanical context only: the verbatim user request, the resolved file list, and deep-review's findings when it is the caller; no orchestrator-written purpose or constraint fields; the Opus pass finds purpose and sources itself and states the purpose it measured against; fit findings resting on an inferred purpose are labelled and never auto-applied; Plan B tests both with and without a stated purpose (2026-09-29)

#### D17: Context carried as verbatim quotes with a source
- What: deep-review fills each brief field with verbatim quotes tagged with their source, because the brief's author runs at the session tier and "cannot recover what you left out of a paraphrase".
- Recommendation: carry forward - the orchestrator passes the user's request and any found purpose statement to the Opus pass as quotes with a file:line or "user message" source, not as its own summary.
- Why: the v2 orchestrator runs at session tier (Sonnet under this config's settings) and writes the context the Opus pass sees, which is the same asymmetry deep-review found. Quoting is cheap. The spec itself says quoting being less tier-sensitive "is assumed, not measured".
- Evidence: skills/deep-review/SKILL.md:141-149; specs/skills.md:565-570; P1
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D18: Reviewer-held brief validation ("Brief invalid: Purpose")
- What: deep-review's dispatched pass validates the brief before answering, returning `Brief invalid: Purpose` with no verdict. The plan moves the full failure-shape catalogue into a reference pasted into the prompt, because "the caller wrote the brief and cannot be the only judge of it".
- Recommendation: drop - with no gate (D16), there is nothing to validate.
- Why: the mechanism exists only to back the Purpose gate. Its principle is that the author of an input should not be its only judge. That points at the P4 orchestrator filter, not at a validation step, and belongs with P4's decision.
- Evidence: skills/deep-review/SKILL.md:222-227, 240-242; plans/deep-review-rearchitecture.md:513-583; skills/deep-review/references/dispatch.md:67-74
- Overlap: also P4
- Settled: no
- Decision: drop (2026-09-29)

#### D19: Show the brief before dispatching, recast as stating the measured-against purpose
- What: deep-review prints the brief before dispatch, because "a verdict reasoned soundly from a mis-stated premise reads exactly like a sound one" and the shown brief is the only place that error is catchable.
- Recommendation: modify - no pre-dispatch display. The report's summary states in one line the purpose each document was measured against, quoted with its source, so a wrong premise is visible after the fact.
- Why: the risk is the same in v2. A purpose-fit finding against the wrong purpose looks sound. Displaying a block before every review would add noise to a routine "review this". One line in the summary keeps the error catchable at almost no cost.
- Evidence: skills/deep-review/SKILL.md:208-211; specs/skills.md:535-541; specs/drafts/review-md-v2-discovery.md:76-78
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D20: Confirm branch before spending the full pass
- What: deep-review asks once whether to spend the full pass on a trivial or low-stakes target.
- Recommendation: drop - v2 runs both passes on every call.
- Why: already decided in section 0. Its cost reasoning ("Accepted cost: an Opus pass on every call") also covers the case a confirm branch would guard.
- Evidence: skills/deep-review/SKILL.md:105-128; specs/drafts/review-md-v2-discovery.md:16-18, 65-66
- Overlap: none
- Settled: yes - "Every invocation runs both passes: a Sonnet proofread and claim-verification pass per document, and one Opus judgment pass over the whole target (purpose, fit, omissions, cross-document). There is no proofread-versus-review depth split. Accepted cost: an Opus pass on every call."
- Decision: drop (2026-09-29)

#### D21: Asking discipline: the question ends the turn
- What: deep-review's rules for asking: use `AskUserQuestion` with a plain-text fallback, the question is the last thing in the turn, and two shapes are excluded by name (narrating the question and continuing; asking and answering in the same reply).
- Recommendation: carry forward - apply to every question v2 still asks (the P7 size-cap question and the end-of-review "pick what to fix" question), and only from the inline orchestrator.
- Why: both excluded shapes were observed. Eval 2's self-answering persisted even after the body named it, so these rules need an eval, not just prose. `AskUserQuestion` is unavailable inside a subagent, which supports P1's point that only the inline orchestrator can ask.
- Evidence: skills/deep-review/SKILL.md:114-128; specs/skills.md:406-412, 745-747, 762-763; specs/drafts/review-md-v2-discovery.md:76-78, P1, P7
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D22: Tier delivered by the Agent dispatch, never by the frontmatter pin or a fork
- What: deep-review found an unforked `model:` frontmatter pin unenforced (3 of 3 trials served by Sonnet), and gets Opus from the `Agent` call's `model: opus` with `subagent_type: "general-purpose"`, never `subagent_type: "fork"`, which inherits the parent model.
- Recommendation: carry forward - dispatch the Opus judgment pass with `model: opus` and `subagent_type: "general-purpose"`, and the proofread pass with `model: sonnet`. Never use `"fork"`. Treat any frontmatter `model:` as forward-compatibility only.
- Why: v1 relies on `context: fork` plus `model: sonnet` frontmatter. P1 removes the fork, so the only tier mechanism left is the dispatch parameter, which is the one deep-review verified. A tier error here is silent: an Opus pass served by Sonnet returns plausible output.
- Evidence: specs/skills.md:505-514; skills/deep-review/references/dispatch.md:27-36; skills/review-md/SKILL.md:14-18; P1
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D23: Foreground dispatch
- What: deep-review dispatches with `run_in_background: false`, because a backgrounded dispatch returns control at once, and phase 3 then ends with no findings and no verdict. This was observed failing silently twice.
- Recommendation: carry forward - every v2 pass dispatch is foreground, stated in each template's dispatch parameters.
- Why: v2's inline orchestrator merges both passes' findings, so a backgrounded pass produces a clean-looking report with a whole pass missing. That is the worst shape for a skill whose first criterion is completeness in one run (1.10).
- Evidence: specs/skills.md:519-523, 589-596; skills/deep-review/references/dispatch.md:38-42; specs/drafts/review-md-v2-discovery.md:101-102
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D24: Equal-tier inline branch and the silent tier self-report
- What: deep-review runs phase 2 inline when the session "is already at Opus", decided by the session's own reported tier. The plan names this as a load-bearing weakness: "a Sonnet session that believes it is Opus silently skips the dispatch and returns output indistinguishable from a correct pass".
- Recommendation: modify - v2 always dispatches the Opus pass, with no tier branch.
- Why: the branch's only benefit is one all-Opus arm table where the dispatching arm scored lowest. That is a single run, and the spec cites it through the 2026-09-05 record. Its cost is a silent failure the plan could only make visible, not remove. It also blinds evals: the 2026-09-11 run had to use Sonnet executors because "at Opus the skill folds its second phase inline and dispatch-related assertions cannot be observed". v2's orchestrator is inline and already dispatches the Sonnet pass, so always dispatching adds no new mechanism.
- Evidence: plans/deep-review-rearchitecture.md:20-22, 296-303, 598-600; specs/skills.md:528-534; skills/deep-review/references/dispatch.md:12-20; evals/runs/2026-09-11-deep-review-full-suite.md:86-87
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D25: A declaration line that makes the run's shape visible
- What: the plan's fix for D24 is a fixed one-line declaration of which path phase 2 took, because declaring "makes a wrong branch visible instead of silent".
- Recommendation: modify - v2's report opens with one fixed-format line stating what ran: the proofread pass (document count), the Opus pass (dispatched, or split into N groups under P7), and anything skipped.
- Why: v2 has more silent-skip paths than deep-review: per-document fan-out, a size-cap split, a backgrounded or failed dispatch. A fixed line lets the user and a deterministic eval assertion catch a missing pass. The declaration does not make the underlying signal reliable, as the plan concedes; it only makes an error visible.
- Evidence: plans/deep-review-rearchitecture.md:182-185, 296-303, 615-626; P7
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D26: The inert effort pin and `ultrathink`
- What: deep-review's self-review found `effort: high` inert, because the `Agent` tool takes no effort parameter. The remedy is `ultrathink` in the dispatch prompt.
- Recommendation: carry forward - as P6 proposes: drop the `effort:` pin and put `ultrathink` in the Opus pass template. Leave the Sonnet proofread pass at default effort unless an eval shows it misses claims.
- Why: the same mechanism applies to v1's `effort: medium`. `ultrathink` is the documented per-turn lever and changes no setting. Nothing shows the Sonnet pass needs it, and adding it costs tokens on every document.
- Evidence: evals/runs/2026-09-05-deep-review-ablation.md:147-150; skills/deep-review/references/dispatch.md:76-79; specs/skills.md:553-555; skills/review-md/SKILL.md:15; P6
- Overlap: same as E46, also P6
- Settled: no
- Decision: carry forward (2026-09-29)

#### D27: Self-contained dispatch prompt contents
- What: deep-review's prompt must carry everything the subagent needs: the brief with quotes intact, the target's identity and content, the questions inlined verbatim, the output instruction and bound, and `ultrathink` plus a batching instruction. It assumes nothing is inherited.
- Recommendation: carry forward - each P5 template carries its check list verbatim, the target paths, the context block (D16/D17), the fixed findings format, the clean-result sentence (D10), and the batching instruction v1 already requires.
- Why: deep-review's self-review found the body never said what the prompt must carry ("The word 'prompt' did not appear in SKILL.md at all"), so "run the checklist" pointed into a file the subagent could not see. Global rules were observed reaching 10 of 10 fresh subagents, but nothing guarantees it. Fixed templates (P5) are the natural place to make this complete once.
- Evidence: evals/runs/2026-09-05-deep-review-ablation.md:132-137, 153-155; specs/skills.md:542-552; skills/deep-review/references/dispatch.md:51-65; skills/review-md/SKILL.md:235-253
- Overlap: also P5
- Settled: no
- Decision: carry forward (2026-09-29)

#### D28: One dispatch versus fan-out under decisions/0008
- What: deep-review justifies its cold subagent against decisions/0008 only because one dispatch "does not multiply", and says that if it ever fans out, "0008 applies directly and this design must be revisited".
- Recommendation: modify - v2's per-document Sonnet pass is a fan-out, so the v2 spec must address 0008 explicitly: either justify N cold dispatches (independence, bounded N under P7) or batch several documents into one Sonnet dispatch.
- Why: deep-review's own reasoning shows the cold-start tax multiplies with N, and v2 dispatches N+1 passes on every call. Leaving 0008 unaddressed would repeat the kind of silent divergence the deep-review spec took care to record.
- Evidence: specs/skills.md:556-560; skills/deep-review/references/dispatch.md:44-49; skills/review-md/SKILL.md:212; specs/drafts/review-md-v2-discovery.md:16-18
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D29: Carry the pass output through without softening it
- What: deep-review's phase 3 reproduces the dispatched verdict verbatim and forbids paraphrasing, softening, or restructuring it "into a menu of options".
- Recommendation: carry forward - the v2 orchestrator may drop findings (P4 tracking filter, duplicates across passes) and group them, but never rewrites a finding's text, evidence, or replacement, and never lowers its severity.
- Why: the orchestrator runs at session tier and sits between the Opus pass and the user. Softening there would undo the tier the dispatch paid for, with no trace in the output.
- Evidence: skills/deep-review/SKILL.md:234-238; specs/skills.md:523-527; P4
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D30: Resolve the target, and ask only when genuinely ambiguous
- What: deep-review takes `$ARGUMENTS` or the most recent artifact, and asks rather than guesses when the target is genuinely ambiguous, because a pass "aimed at the wrong target wastes the whole pass".
- Recommendation: carry forward - keep v1's Markdown-target confirmation and add the ambiguity rule.
- Why: with an Opus pass on every call (section 0), a wrong target now costs more than it did in v1. The rule is one sentence.
- Evidence: skills/deep-review/SKILL.md:97-103; skills/review-md/SKILL.md:39; specs/drafts/review-md-v2-discovery.md:16-18
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D31: Rules in the body, observations in the spec
- What: deep-review's spec holds that the body states each rule and its reason and may name an excluded shape, but carries no observation dates or scores. Its self-review found load-bearing rules living in only one of the two files.
- Recommendation: carry forward - consistent with P5: SKILL.md and templates carry rules only. The spec carries rationale and observations, and each rule appears in whichever file an executor reads, not only in the spec.
- Why: deep-review's body grew to 272 lines with nine dated observations before this rule. P5's split fails the same way if a rule lives only in the spec, which no executor reads.
- Evidence: specs/skills.md:661-679; evals/runs/2026-09-05-deep-review-ablation.md:151-152; P5
- Overlap: also P5
- Settled: no
- Decision: carry forward (2026-09-29)

#### D32: Naming a failure mode is not a guard; the eval is
- What: deep-review's spec states "The regression guard for a named failure is the eval that caught it, not the paragraph that describes it". Its record shows a named mode (eval 2's self-answer) persisting after being named in the body.
- Recommendation: carry forward - every failure mode the v2 spec or templates name gets a matching fixture or assertion in Plan B.
- Why: this is measured in this repository, not assumed. v2 will name several modes (false positives, skipped areas, silent pass loss), and prose alone was shown not to stop one.
- Evidence: specs/skills.md:677-679, 745-747
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D33: Literal output contracts make assertions deterministic
- What: the plan fixes exact literals (the brief block shape, the declaration lines, the `Brief invalid` token) so that "is the field filled" is "answerable by looking rather than by judging". The spec records an acceptance criterion that no assertion covered because the brief came back as prose.
- Recommendation: carry forward - define v2's output literals (section headings, severity labels, the D25 declaration line, the finding field labels) exactly in the spec, and assert on them deterministically.
- Why: section 0 requires pass criteria fixed before any v2 result exists. Literal contracts are what let those criteria be checked mechanically instead of by a judge whose own error rate the gate cannot see.
- Evidence: plans/deep-review-rearchitecture.md:161-188, 267-275; specs/skills.md:748-750; specs/drafts/review-md-v2-discovery.md:25-31, P3
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D34: Keep deep-review's companion-pass rule working after v2
- What: deep-review runs `review-md` on document-heavy targets. The live rule allows "or say it went unchecked". The unexecuted plan changes it to run `review-md` inline in phase 3 after the verdict, unless one of three named conditions applies.
- Recommendation: modify - v2 keeps the name `review-md` at swap, so the rule's literal reference still resolves. v2 must stay invocable by explicit Skill call from an inline phase 3, which P1's removal of `context: fork` helps. When deep-review invokes it, v2 accepts deep-review's verdict and findings as prior context, so its Opus pass does not re-argue purpose-fit. The Plan B update to deep-review's rule should say this, and should reconcile with the unexecuted plan's text rather than overwrite it.
- Why: the rule's evidence is that review-md caught what deep-review missed. With v2's Opus pass on every call (section 0), a companion invocation now costs a second Opus pass that overlaps D1. Passing context avoids duplicate findings without adding a mode, which section 0 rules out. Deep-review's eval 5 companion assertion depends on `review-md` being reachable from the eval executor, so v2's install path must keep it reachable. The v2 description's negative cases against deep-review phrasing do not affect an explicit Skill call.
- Evidence: skills/deep-review/SKILL.md:244-251; specs/skills.md:494-504; plans/deep-review-rearchitecture.md:20-22, 328-339, 637-653, 908-929; specs/drafts/review-md-v2-discovery.md:25-31, 82-87, 91-93
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### D35: Description lessons from deep-review's trigger history
- What: deep-review measured that quoting a phrase verbatim is "necessary and not sufficient". "be critical" and "is there a better way" fired 0/9 despite being quoted. A sentence conceding bare "review this" on a .md to review-md was load-bearing: dropping it measured worst of three variants (66/81 against 71/81). Generic phrases get answered directly without consulting a skill.
- Recommendation: carry forward - v2's description keeps an explicit concession sentence toward code-review and deep-review. It treats the description as a measured artifact that no regeneration rewrites. It expects generic stems like "refine ..." and "revise ..." to be the weakest positives and measures them individually.
- Why: v2's target phrases (section 0) are generic verbs, the class that failed in deep-review's runs. The 2026-09-11 run also shows the two skills' descriptions interact: deep-review's routing sentence names review-md.
- Evidence: specs/skills.md:462-466, 470-474, 483-488; evals/runs/2026-09-11-deep-review-full-suite.md:94-128; specs/drafts/review-md-v2-discovery.md:32-33
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D36: Trigger-eval instrument lessons
- What: deep-review's history records that a threshold stated in prose does not enforce itself (`run_eval.py` scores at 0.5 by default, and a recorded 8/8 was 7/8). A uniform all-zero run with clean stderr is void. Isolating with a fresh `CLAUDE_CONFIG_DIR` strips login and scores every query zero.
- Recommendation: carry forward - Plan B passes `--trigger-threshold 0.88` explicitly, treats any all-zero positive run as void until `claude -p` is verified under the same environment, and records the harness version with each run.
- Why: section 0 settles n of 9 or more and threshold 0.88. These lessons are what make those figures real rather than false greens. Each was learned from a wrong result believed for a while.
- Evidence: specs/skills.md:753-755, 763-765; evals/runs/2026-09-11-deep-review-full-suite.md:55-67, 83-85; specs/drafts/review-md-v2-discovery.md:25-31
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D37: Answer-key contamination and neutral fixture paths
- What: deep-review learned that "an executor told to search the repo will find the answer key", so fixtures run from neutral paths outside it and contaminated runs are discarded ungraded. The ablation held its key in a directory the arms never saw.
- Recommendation: carry forward - Plan B's planted-defect fixtures and their keys live outside the repository and outside the executor's search reach. Any run whose transcript shows it opened the key is discarded.
- Why: v2's Sonnet pass is told to verify claims against sources (P2), so it will search. A key within reach would produce exactly the false-green the v1-versus-v2 comparison cannot afford.
- Evidence: specs/skills.md:760-762; evals/runs/2026-09-05-deep-review-ablation.md:22-25; specs/drafts/review-md-v2-discovery.md:25-31, P2
- Overlap: none
- Settled: no
- Decision: modify - keys stay in `skills/review-md/evals/` per evals/README.md; runs execute from a scratch workspace outside the repository with a full-transcript contamination check (2026-09-29)

#### D38: Ceilinged keys void comparisons; count unregistered findings
- What: the ablation's tier columns were void because both Sonnet arms scored full marks on a key "too legible" to discriminate. A key "rewards rediscovering what was already believed", and the strongest defect any arm found was not in it.
- Recommendation: carry forward - before any v2 run, pre-register that if v1 scores full marks on a fixture, that fixture cannot show v2 is better. Record findings outside the key separately, graded as true or false positives, rather than ignoring them.
- Why: section 0 settles pass criteria fixed before any v2 result. This lesson is about fixture difficulty, which pre-registration alone does not cover. "Catches things v1 misses" (1.10) can only be shown on fixtures v1 does not ceiling. Unregistered findings are also where v2's false positives will show up.
- Evidence: evals/runs/2026-09-05-deep-review-ablation.md:82-104, 166-169; specs/skills.md:750-751; specs/drafts/review-md-v2-discovery.md:25-31, 99-102
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D39: Behavioral-harness limits
- What: deep-review's behavioral harness passes `Skill path:` to every executor, so a should-not-fire case cannot be tested there. `AskUserQuestion` is unavailable in executors, so only the plain-text fallback is gradeable. On 2026-09-11 the grader was the dispatching agent at Sonnet, not a separate grader.
- Recommendation: carry forward - test routing negatives only in the trigger harness. Write question-asking assertions against the plain-text form. Grade with a separate grader at a tier no lower than the pass under test.
- Why: without this, Plan B would repeat eval 1's non-discriminating pass. Grading an Opus judgment pass with a Sonnet self-grader cannot reliably judge the zero-false-positive criterion (1.10).
- Evidence: evals/runs/2026-09-11-deep-review-full-suite.md:88-89, 152-159; specs/skills.md:734-736, 762-763; specs/drafts/review-md-v2-discovery.md:99-100
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D40: Test every filter in both directions
- What: deep-review's gate was "measured only in the direction where it should stop", so "the evidence cannot distinguish a gate that works from one that always stops". When it was measured in the proceed direction, it over-fired (evals 8 and 10).
- Recommendation: carry forward - every v2 filter (the P4 tracking filter, the D12 false-positive check, the D15 concrete-change filter, any confidence threshold) gets fixtures where a real planted defect must survive it, as well as fixtures where a non-defect must be dropped.
- Why: v2's zero-false-positive criterion pushes toward aggressive filters. Tested only on false positives, a filter that drops everything passes. This is deep-review's exact measured failure.
- Evidence: specs/skills.md:699-702; evals/runs/2026-09-11-deep-review-full-suite.md:161-169; specs/drafts/review-md-v2-discovery.md:99-102
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### D41: Read the live artifact before comparing runs
- What: the 2026-09-11 run first reported a "sharp regression" by comparing against a description variant from memory. The author "never actually read the live `SKILL.md` description", so the comparison was invalid.
- Recommendation: carry forward - every v1 and v2 run record names the exact commit and file hash of the skill under test, and a comparison is valid only between records of the same fixture set.
- Why: section 0 requires a v1 baseline compared against v2. With v1 and v2 side by side and the description changing across Plan B, pinning what was tested is the cheap guard against this specific recorded error.
- Evidence: evals/runs/2026-09-11-deep-review-full-suite.md:13-26, 196-197; specs/drafts/review-md-v2-discovery.md:21-22
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)


### 3.3 Research (R)

#### R1: Deterministic drift check as a pre-filter, not a model job
- What: run a conservative rule-based or scripted check for documentation-vs-code drift (does a
  referenced file, flag, or command still exist) before either model pass runs, and only hand the
  model the claims that need reading in context.
- Recommendation: carry forward - modify P2's claim-extraction script to explicitly exclude
  anything a drift tool already resolves.
- Why: driftcheck's own design principle is to flag only clear, factual contradictions and skip
  anything already fixed or still in flux; that same discipline directly targets the interview's
  top priority (accuracy against source first) and its zero-false-positive bar, without spending a
  model call on lookups a script can do exactly.
- Evidence: https://github.com/deichrenner/driftcheck (fetched) - "Only flags clear, factual
  errors," "Checks git history to avoid flagging issues you've already fixed," "Ignores stylistic
  issues."
- Overlap: also P2
- Settled: no
- Decision: carry forward (2026-09-29)

#### R2: Vale for prose style and terminology, out of the model's scope
- What: adopt Vale-style rule packs (or note where Vale already exists in a repo) for spelling,
  capitalization, and terminology consistency, and scope the model passes away from anything a
  Vale rule already catches.
- Recommendation: modify - do not run Vale itself inside the skill (no new dependency), but use its
  rule categories as the boundary line for what the Sonnet/Opus passes should NOT re-flag.
- Why: Vale is explicitly a rule-enforcement tool, not an editorial-judgment tool ("doesn't offer
  any of its own advice"); the polish layer (lowest of the interview's four priorities) is exactly
  what a deterministic tool already does well, so the model pass should be told to defer to it
  rather than duplicate it.
- Evidence: https://docs.vale.sh/ (fetched) - style vs. grammar distinction, "a tool *for*
  writers," rule-based terminology checks.
- Overlap: none
- Settled: no
- Decision: modify - treat Vale like markdownlint (R3): run it when installed, with the project config (.vale.ini) or a conservative skill-shipped config; when missing, the run declaration says so and points to a setup reference; no question, no guard file; the model passes skip only categories a tool actually ran on this call (2026-09-29)

#### R3: markdownlint's rule catalog as the mechanical-error boundary
- What: use markdownlint's rule categories (heading structure, list markers, whitespace, code
  fence languages, duplicate headings, alt text) as the explicit list of "mechanical" issues the
  model passes should assume are already handled and not re-report.
- Recommendation: modify - reference the rule catalog in the skill's prompt templates as an
  exclusion list rather than running markdownlint itself.
- Why: v1's own strength per the interview is "catches inconsistencies and mechanical errors";
  making that boundary explicit stops the model from spending output (and false-positive risk) on
  things a linter already owns, freeing it for the bigger-picture misses the interview flags.
- Evidence: https://github.com/DavidAnson/markdownlint (fetched) - rule categories for headings,
  lists, whitespace, code fences, alt text, duplicate content.
- Overlap: none
- Settled: no
- Decision: modify - run markdownlint when installed, with the project config or a conservative skill-shipped config that turns off style-opinion rules, never with --fix; when missing, the run declaration says so and points to references/markdownlint-setup.md (install steps and a starter config); no question, no guard file; the exclusion list covers only what actually ran on this call (2026-09-29)

#### R4: Link-check results split into confirmed-broken vs inconclusive, using lychee's own categories
- What: when a link check runs, classify results using lychee's built-in distinction between a
  genuinely broken link and one that returned a rate-limited or transient status (429, 403,
  timeout), and carry that distinction into the findings rather than collapsing both into "broken."
- Recommendation: carry forward - this is close to a direct fix for a named baseline failure.
- Why: the v1 baseline failed exactly this majority expectation (eval-2 #2 and #3, eval-5 #4:
  treat broken and inconclusive links differently and keep both visible in the summary); lychee
  already has the vocabulary and retry/cache machinery to make that distinction cheaply.
- Evidence: https://github.com/lycheeverse/lychee (fetched) - retry/backoff, `--cache-exclude-
  status` for 429/5xx, configurable accepted status codes;
  `evals/runs/2026-09-29-review-md-v1-baseline.md` eval-2 #2, eval-2 #3, eval-5 #4 (failed by
  majority).
- Overlap: same as E20
- Settled: no
- Decision: carry forward (2026-09-29)

#### R5: textlint's pluggable rule model as a template for a "deterministic-first" layer
- What: structure the skill's non-model checks (if any are added) as swappable rule packages
  (spelling, todo-markers, common misspellings) rather than one monolithic script, so a repo can
  opt into or out of specific deterministic checks.
- Recommendation: drop for v2 - out of scope; v2 is explicitly a model-pass redesign, and adding a
  configurable rule-plugin system is new infrastructure the interview never asked for.
- Why: worth recording as a rejected option so a future v3 doesn't have to re-derive why it wasn't
  taken: textlint already solves "configurable deterministic prose rules" well, and duplicating it
  inside review-md would be its own maintenance burden.
- Evidence: https://github.com/textlint/textlint (fetched) - "no built-in rules," plugin
  architecture, 100+ community rule packages.
- Overlap: none
- Settled: no
- Decision: drop (2026-09-29)

#### R6: Diataxis quadrant as the purpose-and-fit test for a section
- What: for each section (or each document in a set), classify what reader need it claims to serve
  (learning, task, reference, understanding) and flag a section whose content no longer matches
  its own claimed role - e.g. a "how-to" step that has drifted into unexplained reference tables.
- Recommendation: carry forward - gives the Opus judgment pass a concrete test for "does this
  section still serve the document's purpose" instead of an unstructured holistic read.
- Why: the interview names purpose-and-fit as the second priority after accuracy, and today's spec
  language ("whether each section still serves the document's purpose") has no operational test;
  Diataxis supplies one that is lightweight and was built for exactly this judgment.
- Evidence: https://diataxis.fr/ (fetched) - four content types (tutorial, how-to, reference,
  explanation), each tied to a distinct reader need; "helps maintainers think effectively about
  their own work."
- Overlap: same as E27
- Settled: no
- Decision: carry forward (2026-09-29)

#### R7: "Delete dead documentation" as an explicit finding category
- What: add a finding category for content that is not wrong but is stale, redundant, or no
  longer earns its place - distinct from "inaccurate" and from "poorly phrased."
- Recommendation: carry forward - modify the fixed findings format (P3) to include this as a
  category value, not just severity.
- Why: Google's own documentation guidance treats staleness as a first-class defect ("docs work
  best when they are alive but frequently trimmed"), and the interview's "bigger picture" miss is
  partly this: v1 catches wrongness, not obsolescence.
- Evidence: https://google.github.io/styleguide/docguide/best_practices.html (fetched) - "Minimum
  Viable Documentation," "delete dead documentation... they mislead engineers," bonsai-tree
  metaphor.
- Overlap: also P3
- Settled: no
- Decision: carry forward (2026-09-29)

#### R8: Docs-updated-with-code as one deterministic accuracy signal
- What: when the target sits in a code repository, check whether the files or symbols a document
  references changed more recently than the document itself (a cheap timestamp/git-log signal),
  and surface that as a prompt for the accuracy pass rather than a verdict.
- Recommendation: modify - fold into R1's pre-filter as one more candidate signal, not a
  standalone feature.
- Why: docs-as-code practice treats "doc changed in the same PR as the code it describes" as the
  review bar; a document whose referenced code moved on without it is a strong drift candidate
  worth flagging to the Sonnet pass even before reading content.
- Evidence: https://google.github.io/styleguide/docguide/best_practices.html (fetched) - "Change
  documentation in the same commit as code changes to prevent staleness."
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### R9: Two-stage claim pipeline: extract, then verify separately
- What: keep claim extraction (what does this document assert, as atomic claims) and claim
  verification (is each claim true against the source) as two distinct steps with separate outputs,
  rather than one pass that both spots and judges a claim.
- Recommendation: carry forward - this is the concrete mechanism behind P2, not a new idea; record
  it because it also justifies why P2 should stay two steps rather than collapse into one Sonnet
  prompt.
- Why: LLM-as-judge research on hallucination detection specifically credits this split for
  making failures diagnosable - a bad final verdict can be traced to "missed the claim" versus
  "misjudged the evidence" - which matters for a skill whose success bar is zero false positives
  on eval fixtures.
- Evidence: https://arxiv.org/abs/2506.07446 "Fact in Fragments: Deconstructing Complex Claims via
  LLM-based Atomic Fact Extraction and Verification" (fetched) - names atomic fact extraction and
  verification as separate pipeline phases (extraction feeds retrieval and reasoning); cross-
  checked against R11's fetched overcorrection study, which reaches the same conclusion from the
  opposite direction (collapsed, over-elaborated single-pass judgment produces more errors, not
  fewer).
- Overlap: also P2
- Settled: no
- Decision: carry forward (2026-09-29)

#### R10: Confidence floor - do not trust self-reported "high confidence" without a held-out check
- What: before wiring a numeric or verbal confidence field into the fix-autonomy policy, verify on
  a labeled sample that the model's stated confidence actually separates correct from incorrect
  findings; if confidence clusters near the top regardless of correctness, use a different signal
  (e.g., requiring a quoted match plus an independent re-check) instead of a bare self-reported
  score.
- Recommendation: modify - directly informs P3 and the open "define high-confidence concretely"
  question; do not just add a confidence field and trust it.
- Why: research on LLM grader calibration finds confidence self-reports concentrate at high values
  regardless of correctness (a "confidence floor"), which would silently break a fix policy that
  gates on "apply high-confidence fixes."
- Evidence: https://arxiv.org/abs/2603.29559 "When Can We Trust LLM Graders? Calibrating
  Confidence for Automated Assessment" (fetched) - "confidence is strongly top-skewed across
  methods, creating a 'confidence floor' that practitioners must account for when setting
  thresholds."
- Overlap: also P3
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### R11: Verification-filter pattern to counter prompt-driven overcorrection
- What: when the review prompt gets more elaborate (explicit fault-finding instructions, suggested
  fixes baked into the ask), treat the model's own proposed fix as evidence to re-check against,
  rather than trusting the original finding at face value; do not assume a more detailed prompt
  produces a more accurate one.
- Recommendation: carry forward - a caution for P5 (fixed prompt templates): more detail in a
  template is not automatically safer, and each template revision needs an eval check, not just a
  read-through.
- Why: an empirical study of LLM code reviewers found that increasing prompt complexity with
  explicit explanations and suggested corrections counterintuitively raised misjudgment rates; a
  "fix-guided verification filter" (using the proposed fix as a counterfactual check) recovered
  precision. Directly relevant since review-md's fix-policy case 2 asks the model to both find and
  fix in one prompt.
- Evidence: arxiv 2601.18844 "Reducing False Positives in Static Bug Detection with LLMs: An
  Empirical Study in Industry" (https://arxiv.org/html/2601.18844v1, fetched) - hybrid methods
  eliminated 94-98% of false positives; few-shot outperformed chain-of-thought; long-context and
  complex-constraint handling both degrade LLM review accuracy.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### R12: Multi-pass aggregation to raise precision without lowering recall
- What: treat disagreement between the Sonnet per-document pass and the Opus whole-target pass as
  a signal, not noise - a finding only one pass raises is a candidate for the "report, do not
  auto-fix" bucket; a finding both passes raise independently is a stronger candidate for
  high-confidence.
- Recommendation: carry forward - gives the two-pass architecture (already settled in section 0) a
  concrete payoff beyond division of labor, and gives "high-confidence" an operational definition
  that does not depend solely on a self-reported score (see R10).
- Why: aggregating independent LLM reviews is reported to raise precision by filtering
  low-confidence or sporadically raised issues while preserving recall on issues flagged
  consistently; the skill already runs two passes, so this costs no extra call, only a comparison
  step.
- Evidence: https://arxiv.org/abs/2509.01494 "Benchmarking and Studying the LLM-based Code
  Review" (fetched) - its Multi-Agg/Self-Agg aggregation strategy is stated to "improve recall by
  identifying high-confidence issues consistently flagged across multiple reviews, and enhance
  precision by filtering out low-confidence or sporadically identified issues," with Self-Agg
  (n=10) raising F1 by 43.67% and recall by 118.83% on Gemini-2.5-Flash.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### R13: No dedicated Markdown-proofreading skill exists in the official or major community catalogs
- What: neither `anthropics/skills` nor the largest community catalogs (ComposioHQ/awesome-
  claude-skills) list a skill scoped to "review/proofread a Markdown document for accuracy,
  consistency, and fit" - the closest matches are document-format converters (EPUB) and general
  content-writing helpers, not reviewers.
- Recommendation: carry forward as context, not an action item - confirms review-md is not
  duplicating a maintained public skill, so the design work here is not wasted on a solved problem.
- Why: worth recording once so it does not get re-investigated in Plan B; also means there is no
  off-the-shelf prompt template to borrow from a peer skill.
- Evidence: https://github.com/anthropics/skills (fetched) - document skills are docx/pdf/pptx/
  xlsx format handlers, not review tools; https://github.com/ComposioHQ/awesome-claude-skills
  (fetched) - closest hits are "Markdown to EPUB Converter" and "Content Research Writer," neither
  a reviewer.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### R14: Cursor's four rule-activation modes as a portability check, not a review-content idea
- What: Cursor's `.mdc` rules activate by always-on, description-matched, glob-matched, or
  manual @-mention - none of these map to "run a multi-pass review with subagent dispatch and
  AskUserQuestion," which Cursor rules cannot do (a rule is inlined context, not an orchestrator).
- Recommendation: drop - confirms the interview's own note ("Cursor: not a concern for v2, but
  keep v2 portable where possible") without finding a portable mechanism; record so the portability
  question is not silently dropped.
- Why: v2's core mechanism (dispatch, ask the user, structured findings) has no Cursor equivalent;
  the honest answer for portability is "the checklist content ports, the orchestration does not,"
  which is worth stating plainly rather than leaving implicit.
- Evidence: https://cursor.com/docs/rules (fetched) - four activation modes (always, description-
  matched/"agent-requested", glob, manual); rules are context injected before the model runs, not
  an agent that can call tools or ask questions mid-review.
- Overlap: none
- Settled: no
- Decision: drop (2026-09-29)

#### R15: Google's documentation-vs-code review standard differs from a code-review standard
- What: Google's own guidance explicitly separates the bar for a documentation review from a code
  review (different reviewers, different criteria) and states the author invokes a "Better/Best"
  rule rather than being held to a single objectively-correct version.
- Recommendation: modify - use this to justify keeping review-md's findings advisory (report,
  multi-select for the user to choose) rather than auto-applying anything below the named-fix or
  high-confidence bar, which the interview's fix-autonomy answer already implies but does not
  ground in outside practice.
- Why: gives an external precedent for why a documentation reviewer should present options rather
  than dictate a single fix, reinforcing the interview's kept-from-v1 multi-select policy (1.4, 1.7).
- Evidence: https://google.github.io/styleguide/docguide/best_practices.html (fetched) -
  "standards for an internal documentation review are different from the standards for code
  reviews," "Better/Best Rule."
- Overlap: none
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### R16: Long-context degradation as the concrete rationale for a whole-target size cap
- What: use the documented pattern that LLM review accuracy degrades with longer context and more
  complex cross-references as the justification (not just intuition) for P7's size cap on the
  Opus whole-target pass, and as a reason to keep per-document Sonnet passes short and separate
  rather than one long combined prompt.
- Recommendation: carry forward - strengthens P7 with cited rationale; still does not supply the
  actual size threshold, which remains an open measurement question.
- Why: P7 currently has "no measurement yet of where the limit falls" as its own evidence gap;
  this at least establishes that the risk is real and directionally why splitting per-document
  work from the cross-document pass (already the two-pass design) is the right shape, not just a
  convenient one.
- Evidence: arxiv 2601.18844 (https://arxiv.org/html/2601.18844v1, fetched) - "long-context
  reasoning degradation: performance declines significantly with extended documents" as one of
  three named limitations of LLM-based review.
- Overlap: also P7
- Settled: no
- Decision: modify - keep it as directional rationale only (the source is about code); the spec sets a provisional file-count and character threshold for P7, and Plan B measures the real one with a scaling fixture (2026-09-29)


### 3.4 Gaps and additions (G)

#### G1: Filter directory targets to Markdown instead of aborting
- What: v1 stops the whole review if any file a directory resolves to is not `.md`, so "review everything in docs/" aborts when docs/ holds one image or JSON file. v1 also never says what "stop" means for a named non-Markdown file.
- Recommendation: modify - for a directory target, review only its Markdown files (`.md`, and decide on `.markdown` and `.mdx`) and list the skipped files in the summary. For a named non-Markdown file, decline in one line and do no review of any kind.
- Why: the aborting gate rejects common real directories. The fall-through wording is what let the eval-4 executor do a best-effort prose review anyway, which failed by majority.
- Evidence: `skills/review-md/SKILL.md:44-50`; `specs/skills.md:143-145`; baseline eval-4 #4 failed (`evals/runs/2026-09-29-review-md-v1-baseline.md:95`, the gate "licenses the best-effort fallback review").
- Overlap: same as E1
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### G2: Scope house-rule checks to the repository that has the rules
- What: md-checks.sh always applies this repository's typography rule. v1 runs in work repositories and personal projects too, where em dashes and curly quotes are not a rule, so those findings are false positives.
- Recommendation: carry forward - the orchestrator reads the target repository's context files (CLAUDE.md, AGENTS.md) and passes the rule set to the checks; md-checks.sh gets a switch to turn off the typography category. With no such rule in the target repository, typography findings are omitted or reported once as a single minor note.
- Why: the zero-false-positive success criterion covers every repository the user reviews in, and this is the most frequent mechanical finding.
- Evidence: `scripts/md-checks.sh:24-25` and `:98-102` (hardcoded "per CLAUDE.md"); `specs/drafts/review-md-v2-discovery.md` section 1.1 (work repos, personal projects) and 1.10 (no false positives).
- Overlap: same as E15
- Settled: no
- Decision: modify - as recommended; whether a project adopts the ASCII rule is decided by the orchestrator reading its context files (CLAUDE.md, AGENTS.md), and the decision and its reason are stated in the run declaration line; language characters (for example Japanese Kanji) are always allowed (2026-09-29)

#### G3: Typography scan misses most banned non-ASCII symbols
- What: CLAUDE.md bans en and em dashes, curly quotes, the ellipsis "or other typographic substitutions (non-ASCII punctuation and symbols)", but md-checks.sh matches only five characters. A probe with an arrow (U+2192) and a multiplication sign (U+00D7) outside a fence produced no finding.
- Recommendation: carry forward - add a general check for non-ASCII punctuation and symbols (Unicode categories P and S, plus no-break and zero-width spaces) outside fences and inline code, and name the code point in each finding. Keep the five named messages.
- Why: the house rule is broader than the script, so in this repository v1 passes files that break the rule. Zero-width and no-break spaces also break search and anchors without being visible.
- Evidence: `CLAUDE.md:104-107`; `scripts/md-checks.sh:98-102`; probe run 2026-09-29 (arrow and multiplication sign not reported).
- Overlap: none
- Settled: no
- Decision: modify - flag non-ASCII punctuation, symbols, and emoji only where the project adopts the ASCII rule; language characters (for example Japanese Kanji) are always allowed; adoption is decided by the orchestrator reading the context files, with the decision and its reason stated in the run declaration line (2026-09-29)

#### G4: md-checks parsing false positives and fence-state errors
- What: probes found five false positives: an anchor to a heading with an underscore (`#my_heading`), a GitHub duplicate-heading anchor (`#dup-1`), a link whose target is followed by a quoted title, Go generics in a fence (`errors.AsType[T]` called on `err`), and a TODO marker with a colon inside an inline code span. Fence tracking is also wrong: any fence line toggles state regardless of fence character or length, so a `~~~` fence holding a ``` line inverts the rest of the file. An unclosed fence silently turns off every check below it and is never reported, and `#` comment lines inside fences are counted as headings for anchor lookups.
- Recommendation: carry forward - fix slugify (keep `_`, add `-1`, `-2` suffixes), strip link titles and `<...>` targets, skip inline code spans for placeholders and typography, track fence opener character and length, skip fenced lines when collecting heading slugs, and report an unclosed fence as a finding. Add each probe case as a script test.
- Why: every one of these breaks the zero-false-positive criterion, and the fence errors silently hide real defects. The Go generics case is already a known open issue.
- Evidence: `scripts/md-checks.sh:51-55` (slugify), `:78` (fence toggle), `:117-119` (heading slugs include fenced lines), `:149` (link regex); probe run 2026-09-29 reported all five false positives and did not report the heading hidden after an unclosed fence.
- Overlap: same as E14, same as E17, same as E18
- Settled: no
- Decision: carry forward (2026-09-29)

#### G5: Add missing structural checks to md-checks
- What: md-checks does not flag a fenced code block without a language tag, an image with empty alt text, more than one H1 or a first heading that is not H1, or a repeated heading text among siblings.
- Recommendation: carry forward - add these four as md-checks categories rather than adding markdownlint as a dependency. `scripts/markdownlint-hook.sh` only runs `markdownlint --fix`, markdownlint is not installed on this machine, and the repository has no markdownlint config.
- Why: alt text is the one accessibility check that fits Markdown. Language tags decide highlighting and whether a reader can tell which shell a command is for. All four are grep work, which the script header says belongs in the script and not in a model pass.
- Evidence: `scripts/md-checks.sh:22-28` (the five categories); `scripts/markdownlint-hook.sh:21-23`; `command -v markdownlint` found nothing on 2026-09-29; a probe image with empty alt text was not reported.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### G6: Check cross-file anchors and section references by name
- What: `other.md#anchor` links are checked only for the file, never for the anchor (a probe link to `other.md` with a missing anchor was not reported). Prose references to a section of another document by quoted name, such as a backticked path followed by a quoted heading, are not checked at all.
- Recommendation: carry forward - extend P2's claim extraction to pull out (path, heading) pairs from both link anchors and "path's 'Heading'" prose. Check mechanically that the heading exists in the target file, and pass unresolved pairs to the Sonnet pass.
- Why: extends P2. The interview names "interconnectedness errors" as v1's main miss, and a renamed heading breaking a named reference in another file is exactly that. CLAUDE.md's own header comment warns that its `## Subagents & Models` heading is cited by name from six other files.
- Evidence: `scripts/md-checks.sh:137-146` (anchor part dropped via `${target%%#*}`); `CLAUDE.md:18-20`, `:81`; `specs/drafts/review-md-v2-discovery.md` section 1.2.
- Overlap: also P2
- Settled: no
- Decision: carry forward (2026-09-29)

#### G7: Link liveness covers only References and hides cache skips
- What: link-recheck-hook.sh checks only links under a "References" heading, so external links in the body are never checked. It prints nothing both when every link is fine and when it skips a document checked in the last 24 hours. It also does not flag a document that cites external pages with no References section.
- Recommendation: modify - give review-md a mode that checks every external link outside fences, a force switch used when the user asks about links, and a one-line "skipped: checked at <time>" output so the report can say what was actually checked. Where the target repository adopts the References rule (see G2), flag body links with no References section.
- Why: in the baseline, the dead-versus-inconclusive call in eval-1 rested on the document's own prose because the script printed nothing. eval-5, which asks explicitly about broken links, failed its summary expectation.
- Evidence: `scripts/link-recheck-hook.sh:15-16`, `:71-84`, `:49` (`FRESH_MINUTES=1440`); `CLAUDE.md:108-111`; `evals/runs/2026-09-29-review-md-v1-baseline.md:69-70`; baseline eval-5 #4 failed.
- Overlap: same as E19
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### G8: Freshness of `updated:` headers and dated claims
- What: v1 applies fixes without bumping a file's `updated:` header, and it never flags an `updated:` date that is older than the file's last content change or claims tied to a date or version ("as of", a pinned version number).
- Recommendation: carry forward - when a fix edits a file that has a `created:`/`updated:` header, set `updated:` to today. In the review, report `updated:` older than the file's last commit where git is available, reusing health-check's `fm_date` logic. Have the claim pass list dated and versioned statements as candidates to verify.
- Why: the repository convention is to bump `updated:` with any tracked Markdown edit. A v1 fix run creates exactly the drift health-check later flags as `updated-bump`. Stale version claims are an accuracy defect, which is the top interview priority.
- Evidence: `scripts/health-check.sh:516-528` (updated-bump), `:556-569` (updated-history via `git log`); `skills/review-md/SKILL.md:84-103` (fix policy, no header step); `specs/drafts/review-md-v2-discovery.md` section 1.3.
- Overlap: none
- Settled: no
- Decision: modify - a script check (sharing health-check's fm_date logic) reports an updated: header older than the file's last commit; applying a fix bumps updated:; P2's claim script extracts dated and versioned statements for the Sonnet pass to verify; files without the header are skipped (2026-09-29)

#### G9: Check generated artifacts against their spec
- What: this repository is spec-anchored, and generated files name their spec in a header (`spec: specs/skills.md (review-md section)`). v1 neither checks such a file against its spec nor warns that a fix belongs in the spec first.
- Recommendation: carry forward - when a target has a `spec:` header, give the named spec section to the Sonnet claim pass as a source, report drift between them, and label fixes to the artifact "update the spec first" rather than applying them to generated output.
- Why: the spec is the most authoritative source for accuracy in this repository. Hand-editing generated output is what CLAUDE.md says to avoid. Complements P2, which checks existence, not agreement with a source.
- Evidence: `skills/review-md/SKILL.md:24`; `CLAUDE.md:186-188`; `specs/skills.md:81-226`.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### G10: Verify each finding before it is reported
- What: v1 reports what a single pass produced, with no second look. v2 has no step that confirms or drops a finding before the user sees it.
- Recommendation: carry forward - the Opus pass (or the orchestrator for mechanical findings) marks each Sonnet finding confirmed, plausible, or rejected against its quoted evidence. Rejected ones are dropped; plausible ones cannot be auto-applied under the fix policy.
- Why: extends P3, which adds a confidence field but no step that tests it. Zero false positives on the fixtures is a pass criterion, and one independent re-check is the cheapest control that targets it directly.
- Evidence: `specs/drafts/review-md-v2-discovery.md` section 1.10; `skills/review-md/SKILL.md:264-265` (fixes applied straight from the pass results).
- Overlap: also P3
- Settled: no
- Decision: modify - as recommended, absorbing D12: for blocker and major findings the verification also names the best case that the text is correct as written (2026-09-29)

#### G11: Define the severity levels
- What: the interview asks for findings grouped by blocker, major, and minor, but neither v1 nor P3 defines the levels.
- Recommendation: carry forward - add severity to P3's finding format with fixed definitions tied to the interview's priority order. Blocker: a reader following the document fails, or it contradicts its source. Major: misleading, a gap a reader trips on, or a purpose-and-fit problem. Minor: polish and house style.
- Why: extends P3. Without a rubric, the same finding moves between groups from run to run, and severity grouping is the report's main structure.
- Evidence: `specs/drafts/review-md-v2-discovery.md` sections 1.3 and 1.7; P3 lists confidence but not severity.
- Overlap: also P3
- Settled: no
- Decision: carry forward (2026-09-29)

#### G12: Fixed report skeleton with the question last
- What: v1 says both "end with a summary" and "end with a multi-select question" without fixing their order. That tension drives most of the baseline's failures and flaky results.
- Recommendation: carry forward - fix one report order: summary, per-document findings by severity, the across-the-set section, applied changes, not checked (tracked items, cache skips, non-Markdown files), then the question last. Plan B's updated evals should grade the presence of sections, not "ends with".
- Why: 2 of the 6 majority failures and 4 of the 6 flaky expectations are about the closing summary, one more of each is about the multi-select question, and grader notes blame the "ends with" wording in evals 1, 5, 6, 9, 11, and 12.
- Evidence: `skills/review-md/SKILL.md:96-98`, `:267-274`; `evals/runs/2026-09-29-review-md-v1-baseline.md:71-75`; `specs/drafts/review-md-v2-discovery.md` section 2.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### G13: Pick-what-to-fix question does not fit the question tool
- What: v1 puts all findings in one multi-select question, but this repository records that `AskUserQuestion` allows at most 4 options per question and 4 questions per call. A review with 12 findings cannot fit, and in the baseline the eval-11 executor used three single-select questions instead.
- Recommendation: modify - list findings with IDs in the report, then ask at most 4 multi-select questions (for example by severity, with "all minor" as one option). With no question tool (headless or subagent run), write the same question in plain text with finding IDs.
- Why: the interview keeps the multi-select question, so it has to work at real finding counts. The baseline's no-live-user runs show the plain-text fallback is the path taken in practice.
- Evidence: `CLAUDE.md:50-51`; `skills/review-md/SKILL.md:96-98`; `evals/runs/2026-09-29-review-md-v1-baseline.md:156-159`, `:174-175`; baseline eval-2 #3 failed and eval-11 #5 was flaky.
- Overlap: same as E12
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### G14: Re-check after applying fixes
- What: v1 applies fixes and reports them without re-running any check on the changed files.
- Recommendation: carry forward - after applying fixes, re-run md-checks on every changed file, and report a fix as done only if it introduced no new finding. Otherwise show the new finding next to the fix.
- Why: a fix can break an anchor, add a typographic character, or unbalance a fence. CLAUDE.md requires verifying before saying "done". The check costs one script call.
- Evidence: `skills/review-md/SKILL.md:264-265`; `CLAUDE.md:66-67`.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### G15: Coverage report so one run finds everything
- What: v1 cannot show which parts of a document a pass actually read and checked, so a partial pass looks the same as a complete one.
- Recommendation: carry forward - the Sonnet pass returns, for each heading, how many claims it found and how many it verified. The orchestrator reruns or splits any section with unverified claims before reporting, and long documents are sent to the pass split by section.
- Why: "often has to be run more than once" is a named v1 miss, and "one run finds all significant issues" is a success criterion. A coverage list turns a silent partial pass into something the orchestrator can see. P7 caps the Opus pass across a target; this covers the per-document pass.
- Evidence: `specs/drafts/review-md-v2-discovery.md` sections 1.2 and 1.10; `skills/review-md/SKILL.md:130-140` (checklist with no coverage output).
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### G16: Safety boundary for checking commands in documents
- What: P2 hands commands and flags to the Sonnet pass to verify, but nothing says how. Documents in this repository contain state-changing commands such as `git worktree add` and `git worktree remove`.
- Recommendation: modify - allow only non-executing checks: `command -v`, `<tool> --help` or `man` for flags, reading a script's usage header, and `git ls-files`. Never run a command taken from the document under review, and say in the finding that a flag was checked against help text.
- Why: extends P2. A dispatched pass told to "verify commands" with Bash access may run them. Documents under review are untrusted input, especially in work repositories.
- Evidence: `CLAUDE.md:123-127`; P2 in `specs/drafts/review-md-v2-discovery.md` section 3.5.
- Overlap: also P2
- Settled: no
- Decision: modify - as recommended (2026-09-29)

#### G17: Public-repo hygiene check for this repository's documents
- What: when the target is in this config repository, v1 does not check for home-directory paths, usernames, hostnames, or credential-shaped tokens, which CLAUDE.md bans from tracked files.
- Recommendation: carry forward - when the target is inside this repository, run `scripts/scrub-check.sh` limited to the reviewed files and report hits as blockers. scrub-check already has a `<path> ...` mode that checks named paths in the working tree, untracked files included.
- Why: a review is the natural point to catch this before commit. Relying on the pre-commit hook alone misses new untracked documents, per the repository's scrub-check notes.
- Evidence: `CLAUDE.md:171-175`; `scripts/scrub-check.sh:41-52` (`<path> ...` mode checks named paths in the working tree, untracked files included).
- Overlap: none
- Settled: no
- Decision: modify - portable form: when the target repository has scripts/scrub-check.sh, run it on the reviewed files and report hits as blockers; scrub-check needs a per-file mode that also covers untracked files (2026-09-29); met by the existing `<path> ...` mode, so no new mode is built

#### G18: A document's own claims of intent do not settle a finding
- What: in the baseline, the eval-2 executor closed two link findings as "intentional-by-design" based on the fixture's own prose, rather than reporting them. v1 has no rule for text in a document that says a defect is deliberate.
- Recommendation: carry forward - text in a document about its own intent is evidence reported in the finding, never a reason to drop it. Only tracking entries (P4) or an explicit user instruction suppress a finding.
- Why: without this rule, every document that explains itself gets a pass. That caused a majority failure in eval-2 and the knock-on failure of its multi-select expectation, and the baseline caveats flag the same cueing risk for new fixtures.
- Evidence: `evals/runs/2026-09-29-review-md-v1-baseline.md:77-80`, `:176-177`; baseline eval-2 #2 and #3 failed.
- Overlap: none
- Settled: no
- Decision: carry forward (2026-09-29)

#### G19: Checks specific to document type, starting with agent config
- What: v1 applies one generic checklist to every document. The user reviews four kinds (agent config, specs and plans, READMEs and doc sets, notes), each with its own failure modes.
- Recommendation: modify - add a short check profile chosen by path or frontmatter, starting with agent config only: instructions that conflict with each other or with the global CLAUDE.md, ambiguous directives, headings other files cite by name, and length for always-loaded files. Add other profiles only if the evals show a need.
- Why: agent config is the kind where a wrong or conflicting sentence changes behavior on every turn, and the generic checklist does not look for it. Limiting it to one profile keeps it concrete and avoids a checklist that grows without bound.
- Evidence: `specs/drafts/review-md-v2-discovery.md` section 1.1; `skills/review-md/SKILL.md:130-140`; `CLAUDE.md:5-20` (heading order and names that are load-bearing).
- Overlap: none
- Settled: no
- Decision: modify - as recommended: an agent-config profile only, absorbing D5; profile findings are minor unless there is a concrete conflict; it stays within reviewing the named document, not auditing skills (2026-09-29)


### 3.5 Proposals from the 2026-09-29 discussion (P)

#### P1: Inline orchestrator, no `context: fork`

- What: run the skill's orchestration in the invoking context and drop the `context: fork`,
  `agent:`, and `background:` frontmatter; the review passes stay in dispatched subagents.
- Recommendation: carry forward
- Why: the orchestrator must dispatch subagents and ask the user questions, and a forked skill may
  be able to do neither; the isolation that matters already comes from the dispatched passes, and
  structured findings keep the returned context small.
- Evidence: `skills/review-md/SKILL.md` frontmatter lines 16-18; the "Why the dispatch stays even
  when the skill is forked" section; unverified whether a forked skill can nest subagents or call
  `AskUserQuestion`.
- Overlap: same as E47, same as E48, same as E49
- Settled: no
- Decision: carry forward (2026-09-29)

#### P2: Claim-extraction script feeding the Sonnet pass

- What: a script that extracts concrete claims (backticked paths, commands, script names, flags,
  code identifiers), checks mechanically whether each exists, and hands the rest to the Sonnet pass
  to verify against the source with a citation.
- Recommendation: carry forward
- Why: "accuracy" is the most valuable check and today has no method; a script settles existence
  cheaply and leaves the model the claims that need reading.
- Evidence: `skills/review-md/SKILL.md` "What to check" lists accuracy as one bullet with no
  method; `scripts/md-checks.sh` checks only relative links and anchors. Risk: example paths in
  docs produce false positives, tolerable because the script produces candidates, not verdicts.
- Overlap: same as E22, same as R1, same as R9, same as G6, same as G16
- Settled: no
- Decision: carry forward (2026-09-29)

#### P3: Fixed findings format

- What: every finding carries file, line, category, confidence, evidence (quoted text plus what was
  checked), and exact replacement text.
- Recommendation: carry forward
- Why: confidence makes fix-policy case 2 ("apply high-confidence fixes") checkable, and exact
  replacement text makes applying a fix a plain edit rather than a second judgment.
- Evidence: `skills/review-md/SKILL.md` "Decide the fix policy from the prompt" case 2 uses
  "high-confidence" without defining it.
- Overlap: same as D8, same as D9, same as D15, same as R7, same as R10, same as G10, same as G11
- Settled: no
- Decision: modify - fields are file, line, severity (G11), category (including R7's dead-documentation value), a plain leading sentence (D9), quoted evidence plus what was checked (D8), and exact replacement text or a labelled question (D15); G10's verification status (confirmed or plausible) replaces a self-rated confidence (R10); "high-confidence" for fix case 2 means confirmed and meeting E9's conditions, with agreement across passes (R12) as extra support (2026-09-29)

#### P4: Quote-anchored tracking, filtered by the orchestrator

- What: each tracking decision stores a short quote from the text it covers; subagents report
  every finding and the orchestrator drops those whose quote matches a stored decision; an item
  whose quoted text has changed resurfaces, flagged as stale.
- Recommendation: carry forward
- Why: it removes tracking logic from the subagent prompts, and today a dismissed item stays hidden
  even after its section is rewritten.
- Evidence: `skills/review-md/SKILL.md` "Track decisions so they stick" keys entries by free-text
  description only.
- Overlap: same as E29, same as E32, same as D18
- Settled: no
- Decision: carry forward (2026-09-29)

#### P5: Prompt templates in references, rationale in the spec only

- What: `SKILL.md` holds only the orchestration steps (about 100 lines); the dispatch prompts live
  as fixed templates under `references/`; design reasoning lives only in the spec.
- Recommendation: carry forward
- Why: fixed templates stop prompt drift between runs and can be tested; the current body repeats
  the spec's reasoning.
- Evidence: `skills/review-md/SKILL.md` is 274 lines, including "Why the dispatch stays even when
  the skill is forked" and the batching rationale that `specs/skills.md` also carries.
- Overlap: same as E40, same as D27, same as D31
- Settled: no
- Decision: carry forward (2026-09-29)

#### P6: Drop the `effort:` pin; use `ultrathink` in the Opus pass prompt

- What: remove `effort: medium` and put `ultrathink` in the Opus judgment pass's dispatch prompt.
- Recommendation: carry forward
- Why: the pin never reaches the dispatched subagents that do the work, because the Agent tool has
  no effort parameter; `ultrathink` in a prompt is the mechanism that does.
- Evidence: `evals/runs/2026-09-05-deep-review-ablation.md` finding 4 ("`effort: high` is inert").
- Overlap: same as E46, same as D26
- Settled: no
- Decision: carry forward (2026-09-29)

#### P7: Size cap for the whole-target Opus pass

- What: above a set size (file count or total characters), the orchestrator either asks the user or
  splits the target into groups for the Opus pass.
- Recommendation: carry forward
- Why: one Opus pass cannot hold an arbitrarily large directory.
- Evidence: 2026-09-29 discussion; no measurement yet of where the limit falls.
- Overlap: same as R16
- Settled: no
- Decision: modify - the spec sets a provisional file-count and character threshold; above it the orchestrator asks whether to split into groups or proceed, and the question ends the turn (D21); Plan B measures the real threshold (R16); any split is shown in the declaration line (D25) (2026-09-29)

## References

- anthropics/skills repository (https://github.com/anthropics/skills) (verified 2026-09-29)
- Diataxis framework (https://diataxis.fr/) (verified 2026-09-29)
- Google documentation best practices (https://google.github.io/styleguide/docguide/best_practices.html) (verified 2026-09-29)
- driftcheck (https://github.com/deichrenner/driftcheck) (verified 2026-09-29)
- Vale documentation (https://docs.vale.sh/) (verified 2026-09-29)
- lychee link checker (https://github.com/lycheeverse/lychee) (verified 2026-09-29)
- ComposioHQ/awesome-claude-skills (https://github.com/ComposioHQ/awesome-claude-skills) (verified 2026-09-29)
- "Reducing False Positives in Static Bug Detection with LLMs: An Empirical Study in Industry" (https://arxiv.org/html/2601.18844v1) (verified 2026-09-29)
- markdownlint (https://github.com/DavidAnson/markdownlint) (verified 2026-09-29)
- textlint (https://github.com/textlint/textlint) (verified 2026-09-29)
- Cursor rules documentation (https://cursor.com/docs/rules) (verified 2026-09-29)
- "Fact in Fragments: Deconstructing Complex Claims via LLM-based Atomic Fact Extraction and
  Verification" (https://arxiv.org/abs/2506.07446) (verified 2026-09-29)
- "When Can We Trust LLM Graders? Calibrating Confidence for Automated Assessment"
  (https://arxiv.org/abs/2603.29559) (verified 2026-09-29)
- "Benchmarking and Studying the LLM-based Code Review" (https://arxiv.org/abs/2509.01494)
  (verified 2026-09-29)
