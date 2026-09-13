---
created: 2026-07-26
updated: 2026-09-13
---

# Skill Specs

Per-skill intent and acceptance criteria: the source a regeneration reads. One section per
skill, except the `write-plan`/`execute-plan` pair, which is specified together in
`specs/behaviors.md`'s Plan and Execute section because the two skills are one capability
delivered as two artifacts. These specs describe what each skill should do and how to tell it
is correct; they do not copy the skill's body or restate authoring procedure (that lives in the
`skill-author` skill and `reference/`). Where a skill's frontmatter pin (`model`, `effort`, and
similar) needs to hold even where a pin can be dropped, that intent is restated in the skill's
body as well; see the `cursor-projection` skill for the harness facts behind that pattern.

Shared conventions for every skill spec:

- Location: `~/.claude/skills/<name>/`.
- Description form: a YAML `|` block scalar, indented two spaces and wrapped to the width of the
  surrounding prose (unenforced; roughly 95-100 characters in tracked files), with no line break
  inside a quoted trigger phrase. `|` rather than a plain scalar because a plain scalar is
  invalid YAML once a colon in it is followed by a space or a line end, and descriptions reach
  for that punctuation constantly (`Scope: personal`); `|` rather than `>` because
  `scripts/health-check.sh`'s `desc_len` handles `|` and the plain form only, and measures a
  folded scalar as the single `>` character, so an over-budget description would pass the check
  unnoticed. The no-break-inside-quotes rule follows from `|` preserving newlines: a break there
  leaves a newline mid-phrase, so the advertised phrase is not the string a user types. That the
  newline measurably costs fires is untested - the rule is a cheap precaution, not a measured
  effect. Adopted 2026-09-11; the authoring procedure is in the `skill-author` skill's "Format
  the description as a wrapped block scalar" section.
- Regeneration: via the `skill-author` skill (create/regenerate or targeted-fix mode), gated by
  the skill's testing gate.
- Provenance: the generated `SKILL.md` carries a provenance header pointing back to its
  section here (see `reference/spec-driven-architecture.md`).

---

## skill-author

- Purpose: create, audit, and explain agent skills, then hand off to the harness's own
  scaffolder (`skill-creator`, or the equivalent named in
  `skills/cursor-projection/references/harness-matrix.md`) for scaffolding and evals.
- Modes: Q&A, audit, create/regenerate, targeted fix. Decide mode from `$ARGUMENTS` and
  context before acting; ask once if ambiguous.
- Trigger phrases: "create a skill for ...", "make a skill that ...", "how do skill
  descriptions work?", "audit my skills", "check skill description budgets".
- Non-goals: general Markdown proofreading of arbitrary `.md` files (that is `review-md`).
  Does not write skill files directly in create mode (hands off to the scaffolder);
  targeted-fix mode edits in place for the requested change only.
- Model/tier: judgment-heavy authoring and audit run at the Opus tier, pinned `model: opus`
  so the guidance survives a harness that drops the pin. The heaviest passes (Audit,
  Create/targeted-fix research) are additionally dispatched to an explicit Opus-tier subagent
  regardless; see `skills/cursor-projection/references/harness-matrix.md`.
- Effort: pinned `effort: high` so the session's baseline effort setting cannot understate
  reasoning depth for this skill's research, description synthesis, and audit judgment - so
  the guidance survives a harness that drops the pin. Weaker case than `write-plan`'s pin,
  since the heaviest passes (Audit, Create/targeted-fix research) already dispatch to an Opus
  subagent regardless of the main thread's effort; kept for consistency with the skill's own
  Opus pin.
- Knowledge source: loads `references/skills.md` (synced from `docs/features/skills.md`)
  before answering architecture questions or auditing/authoring.
- Constraints: enforce the 4-part description pattern, the wrapped-block-scalar description
  form from the shared conventions above, the description-budget discipline
  (1% of context or 8,000-char fallback, 1,536-char per description; harness-specific figures
  are in `skills/cursor-projection/references/harness-matrix.md`), the frontmatter-defaults
  decision table, and the knowledge/action-split guidance. Default new skills to personal
  scope.
- Acceptance criteria:
  - Correctly routes each of the four modes from representative prompts, and asks when
    ambiguous.
  - Create mode produces a brief and hands off to the scaffolder without writing skill
    files itself; targeted-fix mode edits only the requested change.
  - Generated descriptions follow the 4-part pattern, are emitted as wrapped `|` block scalars
    that parse under a strict YAML parser, and stay within budget.
  - Audit mode reports findings with path references and applies no fixes unless asked.
  - Testing gate is run on each target harness for new or trigger-changed skills.

---

## review-md

- Purpose: proofread and review Markdown documents for accuracy, consistency, omissions,
  errors, and whether each section still serves the document's stated purpose - either a
  single document (single-document mode) or a named set of documents reviewed for how they
  hold together as well as individually (multi-document mode).
- Modes: single-document (default), multi-document (holistic), and an ask-once branch for the
  ambiguous case in between. Decide from the request's own wording, before reading any
  document's content: one resolved target file - named directly, or the sole file a directory
  target resolves to - is single-document; a directory target that resolves to more than one
  file, or explicit holistic-signaling language ("together", "as a whole", "do these still
  agree with each other", "hang together") in the request naming two or more targets, is
  multi-document unconditionally - a directory and explicit language are each unambiguous
  signal on their own. Multiple named files with
  none of that signal is the ambiguous case: it is not treated as multi-document by file
  count alone, and not treated as several independent single-document reviews either - ask
  once whether independent single-document passes or one holistic pass over the set is
  wanted, rather than guessing, since the two produce materially different output. A document
  that describes itself as paired with, or designed to agree/disagree with, another document
  is not a substitute for that signal - noticing it while reading is not the same as the user
  asking for a holistic pass, and treating it as such skips the ask-once branch by the back
  door. The ask-once question must actually be asked even when no interactive question tool is
  available in the execution context - fall back to asking in plain text rather than silently
  defaulting to either mode, since a missing tool is not license to guess.
- Trigger phrases: single-document - "review this", "proofread this", "review and fix",
  "refine this doc", applied when a `.md` file is the clear subject. Multi-document -
  "review these docs together/holistically", "review this doc set", "do these docs still
  agree with each other", "review everything in docs/", applied when a directory of `.md`
  files is the subject or the request's language signals holism regardless of file count.
  Multiple named files with neither signal still triggers this skill (it is Markdown review),
  but resolves to the ask-once branch above rather than either mode automatically.
- Non-goals: non-Markdown files (defer to normal code-review conventions). Skill authoring
  and skill-system questions (that is `skill-author`). Multi-document mode reviews a bounded
  set the user points at (named files, or a named directory) - it does not go looking beyond
  that set for other documents it judges related.
- Model/tier: Sonnet for both modes. The work is a bounded checklist pass - in multi-document
  mode, plus a bounded cross-referencing pass over a known, closed set - not open-ended
  architecture judgment; Opus is not warranted and Haiku is too weak for accuracy/consistency
  calls. Every review pass (per-document and, in multi-document mode, cross-document) is
  dispatched to a Sonnet subagent; the invoking turn applies only approved fixes and updates
  the tracking file.
- Effort: pinned `effort: medium` so the guidance survives a harness that drops the pin. The
  same "bounded checklist, not open-ended judgment" reasoning that rules out Opus also caps
  effort here:
  the pin trades a small amount of reasoning headroom for lower latency and cost on a
  well-specified, repetitive pass. Unlike `skill-author`'s `effort: high` pin, which guards
  against the session default understating needed depth, this pin is a ceiling, not a
  floor - it does not guarantee any minimum above the session default.
- Context: pinned `context: fork` (`agent: general-purpose`, `background: false`) so the
  skill runs isolated where the harness honors the pin, and inline elsewhere - see
  `skills/cursor-projection/references/harness-matrix.md`. Rationale: the whole
  invocation - target confirmation, tracking-file reads, the Sonnet-tier review dispatch(es),
  and applying fixes - is self-contained from the target path(s) alone and needs nothing from
  the prior conversation, which is exactly the profile a cold-start fork is safe for; this
  holds for a directory or file list exactly as it does for one path. This keeps that entire
  sequence out of the calling conversation's transcript, not just the review pass(es) the
  skill was already isolating manually. `background: false` because the fix-policy branch
  presents an interactive multi-select prompt; a backgrounded fork would not be able to
  surface that. The manual Sonnet-tier dispatch(es) inside the body are kept, not removed,
  since they provide isolation where the skill runs inline and additionally tier-separate the
  review pass(es) within the already-forked run; see the skill body's note under "Do the
  review with a subagent".
- First step: confirm every resolved target file is `.md` (for a directory target, its
  contents); if any is not, exit immediately so the request falls through to another skill
  or default.
- Dispatch shape:
  - Single-document mode: one Sonnet subagent dispatch, as today.
  - Multi-document mode: one Sonnet subagent dispatch per document - separate dispatches, never
    merged into one call that covers more than one document - run concurrently, applying the
    unchanged single-document checklist to each - followed by one further
    Sonnet subagent dispatch that is given the full set's content (or, at minimum, each
    document plus its own per-document findings) and reports cross-document findings only:
    contradictions between documents, terminology or heading drift across the set,
    redundant or duplicated coverage, and coverage gaps (something the set collectively
    should cover but doesn't, or something covered in more than one place that should live
    in exactly one). This is a genuine shape change from single-document mode's one-dispatch
    design - a fan-out plus a synthesis pass, not a mode flag on the same call - and should
    be treated as such when regenerating the skill body. Per-document and cross-document
    findings are kept distinct in what gets reported back, never merged into one
    undifferentiated list.
- Dispatch prompt discipline: every dispatched review pass - the single-document dispatch, each
  per-document fan-out dispatch, and the cross-document synthesis dispatch - must be told
  explicitly, in the dispatch prompt itself, to batch independent verification tool calls
  (unrelated `Read`/`Grep`/`Bash` lookups with no ordering dependency between them) into as few
  tool-call rounds as possible rather than issuing them one at a time. A subagent dispatched via
  `Task`/`Agent` does not automatically inherit the invoking session's global `CLAUDE.md`
  working-style rules (including the "batch independent tool calls" rule), so relying on
  inheritance silently loses this discipline - it has to be restated in the dispatch prompt, not
  assumed. This is a pure efficiency instruction with no effect on review depth or findings: it
  changes how many round trips a dispatched pass takes to reach its conclusions, not what it
  checks. Motivated by a measured incident where a 10-document multi-document review's per-document
  dispatches issued their verification lookups serially (7-26 turns each), and because Claude
  Code's prompt cache re-bills the accumulating conversation prefix on every turn, that serial
  pattern multiplied into several million cache-read tokens across the fan-out for what was
  substantively a bounded 10-document proofread.
- Fix policy (in precedence order): explicit itemized instructions apply exactly those;
  prompts containing "refine"/"fix" apply high-confidence fixes and report the rest;
  "review"/"proofread" alone reports only. Present reported findings as a multi-select
  prompt. In multi-document mode this applies per finding, whether it's scoped to one
  document or (for a cross-document finding) implies edits across more than one; when
  applying a fix that touches more than one file, state which files changed and why, the
  same as any other applied fix.
- Knowledge source (see `specs/behaviors.md` Document Generation and
  `decisions/0004-document-generation-as-always-on-rule.md`): loads
  `references/document-generation.md` (synced from `reference/document-generation.md` by
  `scripts/sync.sh`) before checking links, for the verification rules (including the
  403/429-inconclusive judgment).
- Tracking: persist settled/deferred decisions in the project's `.claude/review-tracking.md`
  (not a cache directory); when the project root is itself a `.claude` directory (for example
  this repo, `~/.claude`), use `<root>/review-tracking.md` directly rather than a nested
  `.claude/`. Single-document findings keep the existing per-document section, keyed by path.
  Cross-document findings have no single owning file, so multi-document mode tracks them
  under a separate set-level key instead - the directory path or the comma-joined file list
  that scoped that review - so a cross-document `intentional`/`deferred` call is never
  attributed to (or lost inside) one document's section. Read the relevant section(s) before
  reviewing and skip listed items; append newly decided items at the end. When the user asks
  for a full/fresh review, "clear only the current document's section" extends in
  multi-document mode to: clear the in-scope file sections plus the matching set-level
  section, never the whole tracking file.
- Acceptance criteria:
  - Shared (both modes):
    - Non-Markdown targets exit without acting.
    - Fix policy behaves per the precedence order for each prompt style.
    - Broken-link findings respect the verification rules from the loaded reference.
    - Tracked `intentional` items are never re-flagged; `deferred` items are skipped until
      revisited.
    - Every invocation ends with a summary of items and changes.
    - Every dispatched review pass's prompt includes the batching instruction from "Dispatch
      prompt discipline" above, verbatim in intent - not left to inheritance.
  - Multi-document mode only:
    - Correctly distinguishes single- from multi-document intent per the Modes rule above, or
      asks once when several files are named with no holistic signal.
    - A directory target resolving to exactly one file runs single-document mode, not
      multi-document.
    - The ask-once question is still asked, in plain text, when no interactive question tool
      is available in the execution context - never silently defaults to either mode.
    - The per-document pass satisfies every criterion in the shared group above, for each
      file in the set.
    - The per-document fan-out issues one dispatch per document, never one dispatch covering
      more than one document.
    - Cross-document findings (contradictions, terminology drift, redundancy, coverage gaps)
      are surfaced distinctly from per-document findings, never merged into one list.
    - Set-level `intentional`/`deferred` entries are tracked and honored the same way
      per-document entries are.
    - The closing summary separates "per-document" findings from "across the set" findings.

---

## research

- Purpose: carry the research-discipline workflow - skeleton-first incremental output, a
  progress-file convention, and a periodic usage-utilization check - into whichever context
  actually does a research-heavy documentation-generation task, and state the delegation
  decision for when isolation is genuinely warranted.
- Why it exists: `decisions/0008-avoid-parallel-research-fanout.md` found that the `researcher`
  subagent alone left a gap - its discipline only applied when work was delegated to it, not
  when the work stayed inline, which is the default this decision establishes. This skill
  closes that gap by loading the same protocol (`reference/research-discipline.md`, synced as
  `references/research-discipline.md`) into the calling context directly.
- Trigger phrases: "research X and write docs about it", "create a docs/<topic>/ documentation
  set on X", "research and document Y", "look into X and write it up", "build documentation on
  X". Does not trigger for a quick single-fact lookup (a plain WebSearch call is cheaper), for
  reviewing or editing already-written content (`review-md`), or for planning
  non-documentation work (`write-plan`).
- Context: deliberately no `context: fork` (or `agent`, `model`, `effort`) pin. `context: fork`
  dispatches to a cold-started agent context (`docs/features/skills.md`; this file's own
  `review-md` section above documents its use of that field as an explicit "cold-start fork")
  - it does not share the invoking conversation's prompt cache. This skill's entire purpose is
  to carry its workflow into whichever context invoked it, usually inline, so it can share that
  context's already-warm cache; `context: fork` here would silently reintroduce the cold-start
  cost problem `decisions/0008-avoid-parallel-research-fanout.md` diagnoses. This also means
  the skill behaves identically where a harness ignores those fields anyway (see
  `skills/cursor-projection/references/harness-matrix.md`) - there is nothing harness-specific
  to lose.
- Delegation decision (stated in the body, not just this spec, since it is exact steps rather
  than architecture rationale): stay inline for one self-contained topic regardless of size;
  for genuinely independent sub-topics whose combined raw output would flood the current
  context, dispatch each as a parallel `Agent`-tool fork (`subagent_type: "fork"`), never a
  fresh subagent, since a fork shares the calling context's warm cache; fall back to the
  `researcher` subagent, one topic at a time, only when forking is a poor fit - the isolated
  work should not carry the calling context's full history/tool access. This is a scope
  decision, not a cost one: `decisions/0008-avoid-parallel-research-fanout.md`'s Context section
  found a fork does not lose to a fresh subagent on cost within any reachable session size, so
  session size alone is never the reason to prefer `researcher`.
- Non-goals: this skill does not itself perform research or writing beyond loading the protocol
  and stating the decision - the actual work happens inline, in a fork, or in `researcher`
  per the decision above. It is not a wrapper that always dispatches `researcher`.
- Model/tier: no pin, inherits the calling context's model. The skill's entire purpose is to
  carry its workflow into whichever model is already doing the research-heavy work, so pinning
  a tier here would work against the cache-sharing rationale in Context above.
- Effort: no pin, inherits the calling context's effort. Same rationale as Model/tier - this
  skill augments the invoking context rather than running as its own bounded pass.
- Acceptance criteria:
  - Loads `references/research-discipline.md` before giving any research or writing guidance.
  - Recommends parallel `Agent` forks, not fresh subagents, for independent parallel
    sub-topics needing isolation.
  - Recommends the `researcher` subagent only for the narrow-tool-contract case, and never
    recommends more than one concurrent `researcher` dispatch.
  - Testing gate partially closed: this skill was added as a fast-follow to an already-reviewed
    decision record within the same working session that produced it, rather than through
    skill-author's full create-mode interview and testing-gate loop. An eval set covering the
    criteria above plus the three negative triggers was authored 2026-09-01 at
    `evals/evals.json`, but has not yet been run through the harness in `evals/README.md`, so
    this entry should not be treated as validated until it has.
  - Does not fire for a quick single-fact lookup, a review/edit request, or a non-documentation
    planning request.

---

## health-check

- Purpose: the judgment half of the repository's periodic self-evaluation. Runs
  `scripts/health-check.sh` for the mechanical findings, then assesses what no regex can - whether
  each artifact still earns its place, what has gone stale, and where two documents contradict
  each other. Full behavior intent is in `specs/behaviors.md`'s Config Health Check section.
- Modes: single review pass (run the script, triage its findings, run the judgment pass, report).
  The script itself has a full mode and a `--quick` mode that skips the four delegated scripts and
  the git-history scan; the skill defaults to the full run.
- Trigger phrases: "run a health check", "check the health of this config", "audit this repo",
  "is anything stale", "does this config still hang together", "self-evaluation of ~/.claude", and
  ahead of a publication pass.
- Non-goals: proofreading an arbitrary Markdown file (that is `review-md`); reimplementing or
  second-guessing the script's mechanical checks; applying edits, which it proposes but never makes
  unless asked.
- Model/tier: pinned `model: opus`, `effort: high` so the guidance survives a harness that drops
  the pin. Cross-document coherence judgment over the whole tree is the Opus case, and the
  weekly-to-monthly cadence makes the tier affordable in a way a per-commit check never would
  be; see `skills/cursor-projection/references/harness-matrix.md`.
- Consumes: `scripts/health-check.sh` output, as `<path>:<line> - <description>` lines grouped
  under `== <category> ==` headers, with `(advisory)` categories excluded from the exit code.
  Exit 0 means no failures, 1 at least one failing check, 2 a usage or environment error. The
  `orphans`, `eval-coverage`, and `context-budget` advisories are inputs to the judgment pass, not
  findings to dismiss: each reports a measurement whose meaning the skill has to decide.
- Covers the script's deliberate blind spots by reading rather than by grep: `decisions/` and
  `docs/` are both excluded from the path-reference check for principled reasons (immutability and
  external subject matter respectively), so a stale claim in either is only visible to this pass.
- Constraints: read-only by default; never registers a hook or wires the script into the commit
  gate; never runs `scripts/setup.sh` without `--check` or `scripts/sync.sh` without `--check`;
  treats `decisions/` records as immutable; bumps `updated:` on any tracked Markdown it does edit.
- Acceptance criteria:
  - Invokes `scripts/health-check.sh` rather than re-deriving its findings by hand.
  - Distinguishes a defect to fix from a check that fired but is correct as it stands, and never
    proposes loosening a check purely to make a run come out clean.
  - Reports every finding with a path reference, and applies no edits unless asked, using the
    five-part report shape (mechanical summary, findings to fix, judgment findings, no action
    needed, suggested next pass).
  - Testing gate partially closed: this skill was authored from a plan rather than through
    skill-author's create-mode interview. An eval set covering the criteria above, the
    constraints, and a negative trigger was authored 2026-09-01 at `evals/evals.json`, but has
    not yet been run through the harness in `evals/README.md`, so this entry should not be
    treated as validated until it has.

---

## cursor-projection

- Purpose: the single home for Cursor knowledge in this configuration. The core repository
  targets Claude Code alone; everything harness-specific - the fact matrix, the
  `CLAUDE.md`-to-User-Rules projection procedure, the status line implementation for that
  other harness, and the script that writes its hooks/status-line/MCP config - lives here and
  is loaded only when that harness is actually the task at hand.
- Trigger phrases: "get Cursor using these skills", "update my Cursor user rules", "sync the
  hooks to Cursor", "set up Cursor on this machine", "does Cursor honor `model:`?", "why is the
  tier stated in the skill body?", "what happens to `effort:` under Cursor?".
- Non-goals: does not author or audit skills (`skill-author`); does not proofread Markdown
  (`review-md`).
- Carries:
  - `references/harness-matrix.md`, the source of truth for every per-harness claim other
    skill and subagent specs in this repository point at rather than restate.
  - `references/user-rules-projection.md`, the procedure that turns `CLAUDE.md`'s global
    sections into a paste-able Cursor User Rules blob: source sections, exclusions,
    neutralization rules, and an acceptance checklist.
  - `scripts/statusline-cursor.sh`, kept separate from `scripts/statusline.sh` because the two
    status line payloads use different field names for the same data.
  - `scripts/project-to-cursor.sh`, which writes `~/.cursor/hooks.json`, the `statusLine` key
    in `~/.cursor/cli-config.json`, and `~/.cursor/mcp.json`, with a `--check` mode that
    reports divergence without writing.
- Constraints: `--apply` is the user's own step, not an agent's - writing `~/.cursor/hooks.json`
  registers hooks, and a hook activates before any later review can catch it, so
  `decisions/0003-hooks-and-scripts-authoring-policy.md` requires that registration be the
  user's explicit, in-the-moment act. The skill runs `--check`, shows what would change, and
  asks the user to run `--apply` themselves.
- Generated output: the User Rules blob is generated on demand and is not tracked, so there is
  no stored copy and no drift check for it; regenerate it whenever `CLAUDE.md`'s global
  sections change.
- Model/tier: no pin, inherits the calling context's model. The work is directory/script
  inspection and templated text generation against a fixed procedure, not open-ended judgment
  needing a fixed tier.
- Acceptance criteria:
  - Distinguishes a `--check` request from an `--apply` request, and never runs `--apply` on
    its own initiative.
  - Loads `references/harness-matrix.md` before answering a "does Cursor honor X" question.
  - Generates the User Rules blob by following `references/user-rules-projection.md` in full,
    not from memory of its shape.
  - Reports what `project-to-cursor.sh --check` found before asking the user to apply it.
  - Testing gate partially closed: an eval set covering the criteria above, the `--apply`
    constraint, and two negative triggers was authored 2026-09-01 at `evals/evals.json`, but
    has not yet been run through the harness in `evals/README.md`, so this entry should not be
    treated as validated until it has.

---

## deep-review

- Purpose: the premise-level questions that other reviews leave unasked. `code-review` and
  `review-md` measure accuracy, correctness, and consistency; this pass asks, of any target -
  code, a document, a plan, or a claim made in conversation with nothing built yet - the
  questions that get skipped once something exists: does this belong here, is it actually
  valuable, is there a better way to accomplish the same thing, is this the best way to do it,
  does it serve its stated purpose, and what does it rest on. In the checklist those are the
  value, fit, alternatives, purpose-fit, and assumptions checks. Closes with an explicit verdict.
  `review-md` and `health-check` also ask about purpose, but each inside
  a fixed frame - `review-md` measures a document's sections against that document's own stated
  purpose, `health-check` measures this repository's artifacts against this repository. This skill
  questions the frame itself. The difference is scope and the forced verdict, not a claim that the
  others never ask about purpose; the spec should not be regenerated into that stronger claim.
- Modes: one mode, plus a confirm branch. When the resolved target looks trivial or low-stakes,
  the skill asks once whether to spend the full pass, before writing the context brief rather than
  after, so the cheap path stays cheap. Mirroring `review-md`'s ask-once branch: the question must
  actually be asked even where no interactive question tool is available - fall back to plain text
  rather than silently picking a mode - and where the answer is unavailable or ambiguous, default
  to the full pass, since failing toward rigor is the point of the skill. Stakes and reversibility
  decide the branch, not size and not whether an artifact exists: a one-line config change with a
  wide blast radius warrants the full pass, and an in-conversation idea with nothing built yet is
  among the highest-value targets there is. Declining yields a short inline answer, not silence.
  Asking means the turn ends there: the question is the last thing in the turn, and no dispatch
  and no review happen while it is unanswered. Two shapes are excluded by name because both were
  observed on 2026-09-08 - narrating the question ("normally I would ask...") and then continuing,
  and asking it and then supplying the answer in the same reply. Both are the silent mode-pick the
  branch exists to prevent, and a belief that no reply can reach the session does not resolve the
  gate either, since from inside a run that cannot be answered looks the same as one whose answer
  has not arrived yet.
- Target resolution: `$ARGUMENTS`, when given, names the target; with no argument the target is
  the most recent artifact or claim in the conversation. A named file, a diff, an artifact just
  produced, an unbuilt idea, or a claim someone made all qualify, and there is no file-type gate.
  If it is genuinely ambiguous which is meant, ask rather than guess: a premise review aimed at the
  wrong target wastes the whole pass, and both the confirm branch and the brief depend on the
  target being the right one.
- Trigger phrases: explicit depth or premise language only. The live description, written by
  the user on 2026-09-11 (the "Refine and improve the description for deep-review" commit), quotes
  nine: "deep review", "rigorous review",
  "be critical", "is this a good idea", "does this belong here", "does this provide value",
  "is there a better way", "does this serve its purpose", "is this the best way to do this".
  Phrases are quoted as stems where the stem is what a user types ("deep review", "is there a
  better way"), the opener is the 2026-09-07 one ("explicitly asks for a rigorous, critical, or
  adversarial review"), the scope clause is "any target", and the field is a YAML block scalar
  (`description: |`), the same form `research`, `cursor-projection`, and every subagent
  definition use. **This text is unmeasured**: the trigger gate reopened when it was written and
  has not been run against it. Three phrases that were quoted in every earlier version - "poke
  holes in this", "play devil's advocate", "should we even do this" - are no longer in the
  description; their eval cases stay in `trigger-evals.json` as measured-but-unquoted positives,
  because deleting a case does not change whether the skill fires on the phrase. "push back on
  this" and "critique this approach" left the description on 2026-09-11 and their cases on
  2026-09-08; measured, they diluted the phrases around them. Every quoted phrase has at least
  one case carrying the stem verbatim; "does this provide value" was added 2026-09-11 with the
  description that introduced it, and the "serve its purpose" case dropped an "actually" the
  same day so the stem matches, which makes its earlier 2/9-4/9 figures a near-match rather than
  an exact one.
  A premise-led opener on this phrase list is an open experiment, expected to cost about two
  fires, and must be measured before it ships. The 2026-09-09 additions reopened the trigger gate
  and it was run, five variants at n=9
  (`evals/runs/2026-09-09-deep-review-trigger-regen.md`). Measured: the regenerated description
  with all thirteen phrases FAILS at 2 of 11 positives, and the cause is a phrase budget - fires
  on the original seven track quoted-phrase count (13 phrases 43-45 of 63, 11 phrases 59, 9
  phrases 57-61), while the premise-led opener costs about two fires, inside noise. Swapping out
  "push back on this" and "critique this approach" (no cases since 2026-09-08, about half-firing)
  RAISES the originals above the control, so those two phrases are the budget to spend. "does this
  belong here" reaches 8/9 in that shape; "is there a better way to do this", "is this the best
  way to do this", and "does this serve its purpose" stay at 2/9 to 4/9 under every variant and
  are generic enough that the harness's own caveat applies - the model answers them directly
  rather than consulting a skill. The control, the 2026-09-07 description verbatim, scores 0/9
  on all four user phrasings, so leaving the description alone does not close the gap. The
  user chose variant E on 2026-09-11 - 7 of 11 positives, the original seven at 6 of 7 with the
  miss (`deep review this` 7/9) at the same day's control level, "does this belong here" 8/9,
  the three generic phrasings 2/9 to 4/9 - then refined it by hand the same day into the
  nine-phrase text above, which is the description in the body and has not been measured. E is
  the last measured figure and the baseline the next run compares against. No variant has
  passed every positive at >= 8 of 9; the generic-phrasing cases are kept as measured failures
  rather than deleted. The negatives
  fired zero times in 81 runs under every variant, including a new near-miss for "is there a
  better way" on a trivial snippet. Two further sentences in the description are load-bearing and
  measured: one asserting
  that the depth phrases win regardless of file type, and one conceding bare "review the diff" and
  bare "review this" on a `.md` to `code-review` and `review-md`. A variant that dropped the second
  sentence measured worst of three (66/81 against 71/81) and lowered queries it did not touch; do
  not re-run that experiment without changing something else first. Two phrases, "is this a good
  idea" and "be critical", are ordinary conversational language and will sometimes land on a
  trivial target; they are kept deliberately so no real request is missed for want of the right
  wording, and the confirm branch contains the cost rather than a narrower trigger list.
  **The description is a measured artifact and is not regenerated with the body.** A regeneration
  keeps the frontmatter `description:` line verbatim. Any change to it, however small, reopens the
  trigger gate and needs a fresh run at n>=9 against
  `skills/deep-review/evals/trigger-evals.json` (the separate format the trigger harness can run,
  not `evals.json`) before the skill ships.
  Prior state, 2026-09-08, against the pre-2026-09-09 description: seven of seven positives at the
  `>= 8 of 9` rule and eight
  negatives at zero fires in 72 runs, with three caveats that travel with the figure. It is a
  rescoring of the 2026-09-07 n=9 rates, valid only because the description has not changed since;
  `be critical about this` sits exactly on the 8/9 boundary; and "push back on this" and "critique
  this approach" have no cases, removed 2026-09-08 at the user's direction as the least likely
  invocations, so the description fires on them roughly half the time and that is unmeasured, not
  fixed. "strong review" was never in the description and left the eval set 2026-09-07.
  Lessons that constrain the next description edit: quoting a phrase verbatim is necessary and not
  sufficient (`deep review this` and `rigorous review` were both quoted and both weakest until the
  file-type sentence landed, because that query competes with `code-review` on three hooks);
  phrase position does not predict firing; and the one untested mechanism is the trailing `Scope:`
  clause overriding an in-description quote, already seen in `health-check`. A coverage claim in
  prose is not coverage: check the case file before repeating a count. Per-query rates and the
  variant comparison: `evals/runs/2026-09-07-deep-review-trigger.md` and
  `evals/runs/2026-09-08-deep-review-readiness.md`.
- Non-goals: bare "review this" or "review this doc" on a Markdown file (that is `review-md`) and
  bare "review the diff" (that is `code-review`). Leaving those alone is what keeps the always-on
  CLAUDE.md "Reviews take a position" rule and this skill non-redundant, and it removes the risk
  of displacing a requested proofread or correctness pass. Also not a wrapper: the skill does not
  invoke `review-md` or `code-review` and layer a verdict on their output, which would duplicate
  each host skill's target resolution and couple this skill to their changes. When another review
  pass is already running, this one does not re-litigate the mechanics that pass owns - prose
  nits, link checks, lint, formatting. Not being a wrapper is not the same as not being a
  neighbour, and the skill must not read the sentence above as licence to skip those checks when
  no companion pass exists. On a document-heavy target it either runs `review-md` alongside or
  states plainly that the mechanical layer went unchecked. Observed 2026-09-07: a deep pass over
  a mostly-Markdown branch, having treated the mechanics as another pass's job while no such pass
  was running, missed a stale coverage claim that had propagated wrongly across four artifacts;
  a `review-md` pass over the same target caught it.
- Model/tier: pinned `model: opus`, `effort: high` so the intent survives a harness that drops the
  pin - but here the pin is known not to hold. An unforked `model:` frontmatter pin was confirmed
  unenforced on 2026-09-04 (3 of 3 controlled trials: session on Sonnet, skill pinned Opus, every
  message served by Sonnet). The pin is therefore carried for forward compatibility only, and the
  Opus tier is delivered by the in-body `Agent` dispatch parameter, which was verified to work.
  A regeneration must not drop that dispatch on the theory that the frontmatter covers it, and
  must not substitute `subagent_type: "fork"` - an `Agent`-tool fork always inherits the parent
  model. `context: fork` frontmatter would set the tier correctly but is deliberately not used:
  a forked skill's whole body becomes the subagent prompt with no conversation history, which
  removes both inline parent phases the design requires.
- Dispatch shape: three phases. (1) Inline parent resolves the target, gathers the artifact, and
  writes the context brief. (2) One fresh `Agent` subagent with `subagent_type:
  "general-purpose"` and `model: opus` runs the checklist against artifact plus brief and returns
  findings and a verdict; `general-purpose` because the pass must read, search, and judge, which
  the read-only search and narrow implementer types cannot do. The dispatch is made in the
  foreground (`run_in_background: false`): a backgrounded dispatch returns control immediately,
  phase 3 is reached with nothing to present, and the pass ends with no findings and no verdict -
  observed 2026-09-05, and silent, because reporting nothing is correct given that state. (3)
  Inline parent presents the findings and fields follow-ups the subagent could not have been asked
  mid-run, since it cannot see the conversation, and reproduces the returned verdict verbatim -
  the ladder term, its one-sentence reason, and the counter-argument - rather than paraphrasing it
  or restructuring it into a menu of options, since a list of choices is not a verdict and
  substituting one silently removes the single output this skill exists to force. Exactly one
  dispatch per invocation, and only when the session is not already at the target tier: if the
  caller is already running at Opus, phase 2 folds into phase 1 and the checklist runs inline.
  This is measured rather than assumed - in the all-Opus arm table in
  `evals/runs/2026-09-05-deep-review.md` the dispatching arm scored lowest of the three and
  returned fewer findings than a plain inline review, and that record concludes twice that the
  dispatch adds little when the caller is already at Opus. The dispatch buys a tier the caller
  lacks; at equal tier it costs a cold subagent and measurably some rigor.
  The brief is shown in the conversation before the dispatch goes out - printed, then dispatched
  in the same turn, as a display step and not a second confirmation gate. The brief is written by
  the caller, which under `settings.json`'s `"model": "sonnet"` is the lower tier, and it is
  everything the dispatched pass can see; the ablation found that which defects get found is
  decided by the brief. A verdict reasoned soundly from a mis-stated premise is indistinguishable
  from a good one in the output, and phase 3 reproduces it verbatim, so the brief is the only
  place that error is catchable.
  **The dispatch prompt must be self-contained.** The subagent cannot see the conversation or the
  skill body, and while the global working-style rules were measured arriving in 10 of 10 fresh
  general-purpose subagents on 2026-09-08, nothing in the harness guarantees that, so the skill
  assumes nothing is inherited and the prompt carries everything. It carries: the four-field
  brief inline, quotes and sources intact; the target's identity *and* its content (a path
  suffices only for a file the subagent can read - a claim made in conversation must be quoted
  in, and that is the case with no file to fall back on); the checklist inlined verbatim rather
  than referred to; a brief-validation step that runs first, with the need test inlined,
  returning `Brief invalid: Purpose` with no verdict when no Purpose quote states a need, so the
  higher tier judges the brief before a verdict exists; the verdict instruction including the
  four ladder terms and the counter-argument; and `ultrathink` plus an instruction to batch
  independent tool calls. `ultrathink` is there because the `Agent` tool takes no effort parameter, so the `effort: high` frontmatter pin reaches the dispatch no more than the
  `model:` pin does - same evidence, same remedy, and a regeneration must not treat the pin as
  delivering depth.
  `decisions/0008-avoid-parallel-research-fanout.md` argues against cold fresh-subagent
  dispatches, and the divergence is deliberate: 0008 measured parallel fan-out of five, where
  the cold-start tax multiplies by N.
  One dispatch does not multiply. If this skill ever fans out to several subagents, 0008 applies
  directly and this design must be revisited.
- Context brief: four required fields - Purpose (why the thing exists and what goal it serves),
  Alternatives already rejected, Constraints, and Prior findings already in hand. Purpose is what
  someone needed the thing to do, not what it does: a fact about the world around the artifact,
  which the artifact cannot supply, so when its contents are the only evidence the field is
  unfilled. Each field is carried as verbatim quotes with a named source, plus an optional gloss that
  never stands alone; synthesis belongs to the reviewer. The form was chosen 2026-09-11 because
  every recorded gate failure was a fluent synthesized sentence describing behaviour, and because
  the brief's author is fixed at the session tier (the conversation lives there, and no fresh
  subagent can see it), so lowering the skill the job needs is the only lever on tier
  sensitivity. Quoting being less tier-sensitive than summarizing is assumed, not measured.
  The test is content, not provenance - before dispatching, quote the sentence that
  states the need (why it exists, what depends on it, what breaks without it). Any source can
  carry that sentence - a prompt, a README, a ticket, a commit message - and none fills the field
  by existing; a citation is not a source, and "(from README.md)" attached to a behaviour summary
  makes an unfilled field look sourced, which is harder to catch than a blank one. This is a hard
  gate, not advice: a field whose answer is *unknown* blocks the dispatch, and the skill names
  that field and stops rather than dispatching with a caveat. A field whose true answer is
  *nothing* does not block: "no alternatives have been considered yet" is information the pass
  needs, and a proposal for something new will frequently and legitimately have nothing in that
  field - a finding to hand the reviewer, not a reason to refuse the review. Telling the two
  states apart is the whole of this gate. Stopping means not dispatching *and* not stating a
  verdict; it does not mean going silent - give what the artifact alone supports, labelled
  preliminary and explicitly not the verdict, then ask for the missing field. When the user,
  asked, cannot state the need either, that answer fills the field: Purpose becomes "no one can
  state why this exists", the pass proceeds, and that is its lead finding and usually its
  verdict. The unknown state is "I have not been told", not "there is nothing to tell", and the
  second is the question this skill was built to ask. A fresh subagent is
  context-isolated, so a thin brief reproduces exactly the shallow output the skill exists to
  prevent, wearing an Opus-reviewed stamp. A prose warning was rejected as the same soft-signal
  class as a model-self-reported tier gate. The original wording of this rationale claimed the
  gate "fails loudly" where a warning "fails silently"; that overstates it, and the correction is
  worth keeping. Both are prose in the same body, evaluated by the same model that wrote the
  brief, with nothing external checking either - and `run_in_background: false` is an equally
  emphatic prose instruction that was observed failing silently, twice. What earns the gate is
  that it names a specific state and a specific stop action rather than expressing a preference,
  not that the mechanism is categorically harder.
  Fresh-context rule, added 2026-09-11: when no conversation precedes the invocation, Purpose is
  fillable only by a quoted external source stating the need or by the user, and the skill asks
  for all four fields in one question rather than judging whether surrounding material
  suffices. The observed failures cluster on exactly this case (evals 9, 11, 12), where the
  model reads the surrounding files and synthesizes.
- Checklist: the text the dispatch prompt inlines verbatim, and the body's centre of gravity:
  the skill exists to ask these questions, and everything else in the body exists so they get
  asked well. Five premise questions, each with the sub-prompts that turn it from a heading into
  an answer. The sub-prompts are prompts, not required fields, so the answer stays a judgment
  rather than a form.
  - Value - is this actually useful? What real problem does it solve, who has that problem, and
    is it observed or hypothetical? What happens today without it? Does the cost of the solution
    (complexity, maintenance, attention) exceed the cost of the problem?
  - Fit - does this belong here? Right layer, right owner, right time, right artifact - or does
    it belong in a sibling, upstream, or nowhere? Does something already do this? A good thing
    in the wrong place is still a problem, independent of how well it is executed.
  - Alternatives - is there a better way? Two kinds, both named concretely: a different thing
    (do nothing, the smaller version, fix the upstream cause, the existing tool) and the same
    thing done differently, which is the "is this the best way to do it" question. Say why the
    proposal beats the best of them. An alternative you cannot name is one you have not
    considered, and "none considered" is a finding, not a blank.
  - Purpose-fit - does it serve its stated purpose? Hold the artifact against the brief's
    Purpose field: does it deliver that need, part of it, or something adjacent? Then turn on
    the purpose itself: is the stated need still real and current, and is it the need behind
    the need or a proxy for it?
  - Assumptions - what does it rest on? List them, say whether each holds, and mark the
    load-bearing one: the assumption that, if wrong, sinks the whole thing rather than a
    detail. Say how one would know it had stopped holding.
  Granularity serves those questions rather than replacing them: cite specific lines, sections,
  or claims as evidence for a premise finding, since "looks fine overall" is not a finding;
  trace second-order effects, meaning what this breaks, complicates, or forecloses later; and
  prefer precision over politeness, since a falsifiable objection ("this breaks when the input
  is empty") beats a hedge ("could be more robust"). The list stays this short on purpose:
  every item is dispatched to a cold subagent and reasoned through at Opus, and adding
  questions dilutes attention on the ones that decide worth.
- Output: every one of the five questions is answered by name, in that order, before the
  verdict, and "no concern" is a legitimate answer stated as such. A question silently skipped
  is the failure this skill exists to prevent, and a pass that returns only line-level findings
  has not run. Premise findings come first; execution-level findings (correctness, prose,
  style) appear only when they bear on the verdict, and are otherwise left to the sibling
  reviews or named in one line as unreviewed. The verdict ladder follows. The return is bounded
  per question rather than in total: 400 to 800 words for each of the five questions, 1200 words
  per question as the ceiling, findings as a one-to-two sentence list with supporting prose and
  evidence following, and the verdict block at roughly three sentences, never past five. The
  bound is stated per question because a total budget starves the later questions when the first
  one carries the evidence; it was widened to these figures on 2026-09-11, replacing a 500-word
  total with an 800-word ceiling. The bound travels in the dispatch prompt's output instruction,
  since phase 3 reproduces the subagent's output verbatim. Past the ceiling the call is buried; a
  run that must cut drops the weakest finding before a question's answer, and never the
  counter-argument.
- Verdict ladder: one ladder for every target - Proceed / Proceed with changes / Reconsider scope
  / Do not proceed - plus a one-sentence reason. For a standing artifact that proposes nothing,
  "Proceed" means "keep as is", stated explicitly rather than left to inference. The verdict
  addresses worth, not only execution: flawless execution of a low-value thing gets "Reconsider
  scope". The call is followed immediately by the strongest argument against it, in one sentence,
  and that is the check on the ladder itself - any of the four calls can be produced without
  reasoning, and "Proceed with changes" is defensible about almost anything, but a genuine
  counter-argument is hard to fake because it cannot be written for a verdict that was never
  reasoned through. A second artifact-shaped ladder was considered and dropped: it duplicated
  two of the four calls and forced a target-classification branch that can misfire. That is not in
  tension with the confirm
  branch, which also classifies - that branch surfaces a question the user can override, where a
  second ladder would silently pick a vocabulary. Loud classification is acceptable; silent
  classification is not.
- Body: the checklist sits first and gets the most lines; the dispatch mechanics and the gate
  rules are condensed behind it, since they exist to serve the questions and a reader who opens
  the file should meet the questions before the machinery. The Dispatch section carries the
  parameters and the five prompt contents only; the reason behind each parameter and what fails
  quietly when it is dropped lives in `references/dispatch.md`, which the body points at and a
  regeneration must keep. Rules live in the body; observations
  live here and in the run records. The body states
  each rule and the reason it holds, and may name an excluded shape ("narrating the question is
  not asking it"), since naming a shape is what has stopped most of them recurring. It does not
  carry the date a shape was observed, the eval that caught it, or the score: those belong to
  this section and the run records, and a body that carries them becomes a changelog that grows
  with every eval run. Measured 2026-09-09: 272 lines with nine dated observations, against the
  180-line trim of 2026-09-06. Length: a soft target of 200 lines; up to 500 is allowed when the
  rules genuinely need the room, and up to 700 only if absolutely necessary, since 500 is the
  harness guidance ceiling and every line past the target is loaded on every invocation. No
  observation dates in the body; pointers to run records for the two measured design choices
  (the brief ablation and the equal-tier dispatch result) are fine. The regression guard for a named
  failure is the eval
  that caught it, not the paragraph that describes it.
- Acceptance criteria:
  - Fires on explicit depth language and does not fire on bare "review this doc" or "review the
    diff", which fall to `review-md` and `code-review` respectively.
  - Asks once, before writing the context brief, when the resolved target is trivial or
    low-stakes; runs the full pass when the target is small but high-blast-radius, and when the
    answer to that question is unavailable or ambiguous.
  - Reaches the full pass for a substantive in-conversation proposal with no artifact, rather
    than treating the absence of an artifact as grounds for a lighter pass.
  - Refuses to dispatch while any of the four context-brief fields is unknown, and names that
    field; does not refuse when a field's true answer is "nothing", and states a preliminary,
    explicitly-not-the-verdict answer rather than going silent while it asks.
  - Proceeds after the user says they cannot state the need, carrying "no one can state why
    this exists" as Purpose and as the lead finding, rather than stalling a second time.
  - On a bare-path target with no prior discussion and no source stating the need, asks for all
    four fields in a single question and stops, rather than dispatching, emitting a verdict, or
    asking field by field.
  - Answers all five checklist questions by name, with an explicit "no concern" where that is
    the answer, and leads with premise findings. A run whose findings are all execution-level
    fails this even when a verdict is present.
  - Fills Purpose and dispatches when a source genuinely states the need, quoting that sentence
    in the shown brief. The gate has so far been measured only in the direction where it should
    stop; until this case passes, the evidence cannot distinguish a gate that works from one that
    always stops.
  - Every filled brief field is one or more verbatim quotes with a named source. A field
    consisting only of a paraphrase or a gloss counts as unfilled.
  - Dispatches exactly one fresh `Agent` subagent with `subagent_type: "general-purpose"` and
    `model: opus`, in the foreground, never `subagent_type: "fork"` - and only when the session is
    not already at that tier, running the checklist inline when it is.
  - Shows the four-field brief in the conversation before dispatching, without waiting for an
    answer.
  - On a document-heavy target, runs `review-md` alongside or says outright that the mechanical
    layer went unchecked.
  - Ends with one of the four verdicts plus a one-sentence reason, followed immediately by the
    strongest argument against that verdict in one sentence - *when the pass ran*. Three exits
    legitimately end without a verdict and must not be scored as failures: the user declining the
    full pass (short inline answer instead), a stop on an unknown brief field (preliminary
    answer, explicitly labelled not the verdict), and a `Brief invalid` return from the
    dispatched pass, presented as a stop.
  - The dispatch prompt is self-contained: brief, target content, checklist, brief-validation
    step, verdict instruction, and `ultrathink` all present in the prompt text rather than
    referred to.
  - The dispatched pass checks the Purpose quotes before answering the questions and returns
    `Brief invalid: Purpose` with no verdict when none states a need; phase 3 presents that as a
    stop, not a verdict.
  - Returns a clean "Proceed" on a genuinely sound artifact without manufacturing objections.
    For a skill built to find fault this is the likelier failure mode than missing a real one.
  - Testing gate: **HOLD** as of 2026-09-11. The gate closes on trigger positives at `>= 8 of 9`
    with negatives at zero fires, and on deterministic and judgment assertions at 100 percent of
    runs (`evals/README.md`). Current figures: trigger, last measured 2026-09-11 at n=9 on
    variant E, 7 of 11 positives with 9 of 9 negatives clean, and the live description has since
    been refined by the user and is UNMEASURED (see the trigger bullet; the three generic user
    phrasings failed under every measured variant); behavioral, ten-eval suite, `with_skill` arm
    only, one run each: deterministic **21/25**, judgment **14/14**; and the three brief-gate
    evals (9, 11, 12) at **12 of 12** on their latest matched re-run. The suite is now twelve
    evals; the 21/25 predates evals 11 and 12. The four deterministic failures split two ways:
    two in eval 1, a should-not-fire routing case the behavioral harness cannot run because it
    passes `Skill path:` in every executor prompt and the skill cannot decline; and two in eval 2,
    a real miss, where the run asks the confirm question and answers it in the same reply.
    Open items, in priority order: (0) run the trigger gate on the user's 2026-09-11 description
    (12 positives, 9 negatives, n=9, about 15 minutes), and behavioral evals for the three
    acceptance criteria added 2026-09-09 (every question answered by name, "I don't know" fills
    Purpose, proceed-direction), which have no cases yet; the 2026-09-09 body regeneration has not
    been through the behavioral suite at all;
    (1) every brief-gate result is n=1 against a 100-percent
    threshold, so a repeat at n>=3 is the cheapest confidence available and has not been done;
    (2) the gate is untested in the proceed direction (the acceptance criterion above); (3) eval
    2's self-answering mode persists after being named in the body, so naming a failure mode is
    not sufficient to stop it; (4) eval 1 is non-discriminating under this harness, and eval 9's
    third assertion passes vacuously when the run wrongly dispatches; (5) no assertion requires
    the labelled four-field brief the body asks to be shown, which eval 12's run supplied only as
    prose; (6) the ablation's tier columns are void, since both Sonnet arms ceilinged on a key too
    easy to discriminate, so a tier reading needs a re-run with a harder key.
    Lessons that constrain how the gate is read, each earned by a wrong result that was believed
    for a while: a threshold stated in prose does not enforce itself (`run_eval.py` scores at its
    0.5 default, and a recorded 8/8 was 7/8 under the repo's own rule); n=3 does not test a
    100-percent threshold, since a true rate near 0.85 passes 3 of 3 about 61 percent of the
    time, so nothing below n=9 goes into a results log; a gate that names a fixture learns that
    fixture, and the general rule replaced the worked example after an unnamed twin scored 0/4
    against the named case's 4/4; a provenance test lets a README-sourced behaviour summary
    through, and the content test (quote the sentence) replaced it after the partial-context eval
    scored 0/4; an executor told to search the repo will find the answer key, so fixtures run from
    neutral paths outside it and contaminated runs are discarded ungraded; and `AskUserQuestion`
    is unavailable inside a subagent, so confirm-branch assertions grade only the plain-text
    fallback; and a run that returns all-zero positives with nothing in stderr is void, not a
    result - observed 2026-09-09 on the evening's fifth 180-call run, and reproduced as a normal
    result two days later. Results that stand: the brief is load-bearing (only the arms given it
    caught a
    constraint violation not inferable from the artifact, and no amount of reasoning recovers a
    fact absent from the target); the dispatch adds nothing at equal tier; the working-style
    rules reached 10 of 10 fresh subagents; and the earlier 3/3-versus-0/3 tier result stands
    unqualified. Run records, in order, under `evals/runs/`:
    `2026-09-05-deep-review.md` (first gate, hand-rolled dispatch, all-Opus arm table);
    `2026-09-05-deep-review-ablation.md` (brief ablation and self-review);
    `2026-09-07-deep-review-trigger.md` (n=9 trigger rates and description variants);
    `2026-09-08-deep-review-readiness.md` (harness behavioral re-run and inheritance probe);
    `2026-09-08-deep-review-gate-verification.md` (eval 11 at 0/4);
    `2026-09-08-deep-review-gate-generalization.md` (matched pair at 4/4);
    `2026-09-08-deep-review-partial-context.md` (eval 12 at 0/4); and
    `2026-09-08-deep-review-purpose-quote-test.md` (12 of 12).
