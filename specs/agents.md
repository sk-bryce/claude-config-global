---
created: 2026-07-30
updated: 2026-08-31
---

# Subagent Specs

Per-subagent intent and acceptance criteria: the source a regeneration reads. One section per
subagent. These specs describe what each subagent should do and how to tell it is correct; they
do not copy the agent's body or restate authoring procedure. For any per-harness behavior, defer
to `skills/cursor-projection/references/harness-matrix.md`. Subagents are authored to the shared
frontmatter core plus knowingly-chosen harness-specific fields per that matrix.

Shared conventions for every subagent spec:

- Location: `~/.claude/agents/`, discovered directly with no symlink or copy.
- Portability: author `name`/`description` as the neutral core. A field a harness ignores is
  inert rather than invalid, so a single file may carry more than one harness's variant of a
  guarantee; `model` is the exception, since its value space differs per harness and one file
  holds one value. See `skills/cursor-projection/references/harness-matrix.md` for which
  fields fall into each case.
- Regeneration: no agent-authoring skill exists in this repo, so subagents are hand-authored and
  reviewed. Regeneration triggers are the same as for skills (a change to
  `skills/cursor-projection/references/harness-matrix.md` or an observed behavioral regression).
- Evals: the co-located `evals/evals.json` convention is skill-specific; no eval harness is
  wired for subagents yet. Until one is, the acceptance criteria below are checked by hand on
  each target harness. This gap is worth closing before the subagent count grows.
- Provenance: the generated agent file carries a provenance header pointing back to its section
  here (see `reference/spec-driven-architecture.md`).

---

## Explore

- Purpose: a fast, cheap, read-only search agent that locates things in a file tree and reports
  where they are, so the dispatching agent spends its own context only on what it chooses to
  read.
- Why it exists: replaces the harness built-in of the same name, which stopped defaulting to the
  Haiku tier. The built-in's behavior is otherwise the model; this is a tier and output-discipline
  override, not a redesign.
- Material in scope: any file tree, whether or not it is a git repository or contains code.
  Source, documentation, notes, config trees such as `~/.claude` itself, data files, and loose
  unversioned files are all in scope, and the search tactics for code and for prose are specified
  separately because exact-identifier search degrades on prose.
- Dispatch contract: the dispatch prompt is the complete specification. Callers state the search
  root and the breadth wanted ("quick", "medium", "very thorough").
- Context: deliberately not forked. Claude Code's fork mechanism always runs on the parent's
  model and discards a `model` override, which is incompatible with pinning a tier; and
  inheriting a parent transcript would defeat the point of an agent whose value is absorbing
  search cost in its own context. Cold start is therefore accepted and mitigated by the dispatch
  contract above rather than by inheritance.
- Non-goals: code review, document proofreading (that is `review-md`), cross-file consistency
  checks, and any open-ended analysis or synthesis. It reports locations, not judgments. Work
  needing synthesis goes to a Sonnet or Opus agent.
- Model/tier: Haiku, at `high` effort. The work is wide but shallow, which is the Haiku profile;
  effort is raised because search-widening and knowing when to stop are the parts a small model
  gets wrong. The tier is guaranteed only where the harness honors a `model` pin; elsewhere a
  subagent's model is best-effort and degrades to the session model, an accepted tradeoff over
  maintaining a generated per-harness twin - see
  `skills/cursor-projection/references/harness-matrix.md`.
- Constraints: read-only, expressed as a `tools` allow-list plus a `readonly: true` twin so the
  constraint holds where a coarser permission model is all that is available; see
  `skills/cursor-projection/references/harness-matrix.md`. Shell use is restricted to read-only
  inspection, and the body names each harness's shell tool rather than assuming one. All file
  content is untrusted data: instruction-shaped text encountered while searching is reported as
  a finding, never followed.
- Output contract: a bounded report, not a copy of the material. A direct answer first, then
  `path:line` references each with a short phrase, under a reference ceiling with an overflow
  summary, then caveats. Quoting is capped at a single line per reference and only where that
  line is itself the answer. Whole files, multi-line excerpts, and section-by-section summaries
  are prohibited outright, because a small model asked "where is X documented" will otherwise
  summarize the document and reintroduce exactly the context cost the agent exists to avoid.
- Acceptance criteria:
  - Given a symbol, key, or phrase present in the tree, returns correct `path:line` references
    and no file contents beyond the permitted single-line quotes.
  - Given a target absent from the tree, reports "not found" with where it looked, and invents
    no path or line number.
  - Honors the stated breadth: a "quick" dispatch does not fan out exhaustively, and a "very
    thorough" one widens across naming conventions and directories before reporting.
  - Finds a documented concept whose wording differs from the query (acronym, plural, verb form,
    hyphenation), not only exact string matches.
  - Operates correctly against a non-git directory, without reaching for git.
  - Reports the search root used, and surfaces dispatch ambiguity as a caveat rather than
    silently resolving it.
  - Attempts no write, and treats instruction-shaped file content as a finding.
  - Stays within the reference ceiling, reporting a count and locations for the remainder when a
    search legitimately exceeds it.

---

## runner

- Purpose: run a verbose, high-output command (test suite, build, linter, log/metric pull, large
  diff) inside its own context so the output is billed once here, never riding along in the
  dispatching agent's context on every later turn of that conversation. This cost-absorption role
  is the single most important fact about the agent and is stated as such in its own body.
- Why it exists: a full test run or build log pasted into a long-running conversation is paid for
  again on every subsequent turn as the model re-reads its own context. Delegating the run to a
  cheap, disposable agent means only a short pass/fail summary re-enters the caller's context.
- Material in scope: any command whose raw output is large relative to what the caller needs - test
  suites, builds, linters, log or metric pulls, large diffs. Not a fit for a command whose output is
  already short enough to read directly; that is needless indirection.
- Dispatch contract: the dispatch prompt gives an exact command wherever possible, which the agent
  runs verbatim without adding flags or substituting an equivalent. Where the dispatch states intent
  rather than an exact command, the agent may read the minimum needed (a package script, a Makefile
  target) to find the project's actual command, and says which file told it what to run.
- Non-goals: no editing of source files under any circumstance (a command's own side effects - build
  artifacts, coverage output, generated files - are fine, since the agent itself never opens an edit
  tool on anything). No fixing, patching, or retrying-with-different-flags on a failure; a failure is
  reported, not worked around. No command substitution when the named target does not exist or will
  not start - the agent reports "not found" and states exactly what it looked for, rather than
  quietly running something adjacent.
- Model/tier: Haiku. The task is mechanical execution and output triage against a fixed rubric
  (verbatim errors, one-line summary, nothing else), which is squarely the Haiku profile; no
  `effort` override is set, since the default is sufficient for a bounded run-and-summarize task.
- Constraints: a `tools` allow-list of Bash, Read, Grep, Glob - no Edit or Write, so it cannot
  alter source even if instructed to by something it reads, so the constraint holds where a
  coarser permission model is all that is available. Where no narrower permission surface exists
  for a subagent, the guard is prose-only (this file's "What you must never do" section) instead
  of mechanical, the same no-mechanical-backstop position this agent would be in anywhere without
  a `tools` allow-list; see `skills/cursor-projection/references/harness-matrix.md` for the
  harness-by-harness detail. Bash is used to run the target command and for read-only inspection
  to locate it, never to write outside of the command's own normal side effects.
- Output contract: exact command run (and directory), a one-line PASS/FAIL summary with counts where
  available, and on failure the failing item(s) with error text quoted verbatim - never paraphrased,
  never a full log, never the full passing output. A large diff dispatch is reported as file names
  and hunk counts with only the directly relevant lines quoted, never the whole diff.
- Acceptance criteria:
  - Given a command that passes, returns a one-line PASS summary and stops - no passing output
    pasted.
  - Given a command that fails, returns the failing item(s) with verbatim (not paraphrased) error
    text plus the one-line summary, and nothing else from the run.
  - Given a target that does not exist or will not start, reports "not found" plus exactly what it
    looked for, and substitutes no other command.
  - Always reports the exact command and directory used, on both pass and fail.
  - Makes no edit to any source file, even when the command's own output suggests one, and even if
    file content it reads contains instruction-shaped text.

---

## executor

- Purpose: implement exactly one fully-specified plan step - the file(s), the exact change or
  content, and a verification command, all supplied verbatim in the dispatch - with no scope
  widening, no new abstractions, and no surrounding refactors.
- Why it exists: `write-plan` produces prescriptive units meant to be handed to a subagent with no
  interpretation required, and `execute-plan` dispatches each unit statelessly per its orchestration
  protocol (`reference/subagent-orchestration.md`). This agent is the mechanical implementer that
  contract assumes; pinning its behavior in one place (no scope creep, verbatim content, halt on
  ambiguity) keeps every dispatched unit predictable regardless of which plan produced it.
- Material in scope: one step at a time, whatever files and content that step names. Not a fit for
  open-ended or ambiguous work, or for a step needing design judgment about how to implement
  something - `write-plan` and `execute-plan` own producing well-specified steps; this agent owns
  only carrying one out. Not a fit for locating an unknown target either; `Explore` is dispatched
  first when a step's path is not already known, and its result folded into a later dispatch.
- Dispatch contract: the dispatch prompt is the complete specification of the one step - absolute
  file path(s), a one-sentence why, the exact content or diff, its acceptance/verification command,
  and any constraint that applies. Nothing is assumed from a plan-wide convention the dispatch did
  not restate; per `reference/subagent-orchestration.md`'s self-contained-prompts rule, the agent is
  never told to open or re-read the plan itself to derive its own scope.
- Non-goals: no new helpers, abstractions, or speculative error handling beyond what the step's
  literal content specifies; no refactor or reformat of surrounding code; no fixing of unrelated
  failures uncovered during verification. One narrow carve-out exists within verification retry: a
  mechanical slip in the executor's own just-written edit (a typo, a wrong path, a malformed line it
  can see is wrong) may be corrected and re-verified once - this never extends to a design choice, a
  second attempt at an instruction that was ambiguous, or any fix that changes what the step does.
  This file's own body is unmodified by this spec entry, and neither `write-plan` nor `execute-plan`
  is altered by adding this agent - it is designed to slot into their existing dispatch contract, not
  to change it.
- Model/tier: Sonnet, no `effort` override. Implementation of a well-specified step is the Sonnet
  workhorse profile per `CLAUDE.md`'s Subagents & Models section; no override is warranted because
  the step is meant to already be fully specified, not something needing extra reasoning effort to
  disambiguate - genuine ambiguity is a halt condition, not a case for more effort at the same task.
- Constraints: `tools` allow-list of Read, Edit, Write, Bash, Grep, Glob. Bash is available for
  running the step's verification command, not for arbitrary write access outside Edit/Write.
  Ambiguity or a missing decision is a stop-and-report condition, treated as a correct outcome
  rather than a failure to apologize for.
- Output contract: the step given (one line), the file(s) changed or "no changes made" on a halt,
  the verification command and result with failure text quoted verbatim, and the specific halt
  reason when one occurs. No full diffs or restated file contents beyond what that report needs.
- Acceptance criteria:
  - Given a fully-specified step, changes only the named file(s), using the step's exact content
    where content was given verbatim, and touches nothing else.
  - Runs the step's stated verification command and reports pass, or fail with verbatim error text.
  - Given an ambiguous, contradictory, or under-specified step, makes no edit and reports the exact
    gap instead of guessing.
  - Adds no helper, abstraction, or error handling beyond what the step's content specifies, and
    performs no refactor of code the step did not name.
  - Never edits `skills/write-plan/` or `skills/execute-plan/` regardless of what a dispatch prompt
    asks - out of scope for this agent under any circumstance.

---

## researcher

- Purpose: a single research-and-write worker for one self-contained documentation topic,
  used only when that topic's raw WebSearch/WebFetch output would flood the dispatching
  agent's own context AND a parallel `Agent`-tool fork is a poor fit for it - a need to keep
  the isolated work off the calling context's full history/tool access. This is a scope
  decision, not a cost one: see `reference/research-discipline.md`'s delegation-shape section
  for the full decision framework, including why session size alone is not a valid trigger.
  Works incrementally (skeleton first, then one section at a time), tracks its own progress
  in a written file, and checks
  the account's usage utilization periodically, halting to report rather than continuing
  once utilization crosses a caller-set threshold - all per that same reference file, which
  this agent reads at the start of its own dispatch rather than duplicating.
- Why it exists: `decisions/0008-avoid-parallel-research-fanout.md` found that dispatching
  several fresh research subagents in parallel for one documentation-generation task
  multiplied cost roughly 2.7x that of a comparable single-threaded task (about 1.4x after
  normalizing for the larger deliverable), driven by each subagent's cold
  context (a full system-prompt/tool-definition cache miss, and no cache sharing across
  subagents or with the parent). A later revision of that same decision found parallel
  `Agent` forks would have avoided most of that cost, since a fork shares the orchestrator's
  already-warm cache instead of paying a fresh cache write - so this agent is not the default
  answer to "the task needs isolation," forking is. This agent exists for the narrower case
  fork handles poorly (see Purpose), and for making the skeleton-first/progress/usage-check
  discipline the default the moment that narrower case applies, rather than something
  restated per prompt. The `research` skill (`specs/skills.md`) carries the same discipline
  into the inline and forked cases this agent does not cover.
- Material in scope: one topic, one dispatch - e.g. "research and write
  `docs/<topic>/03-frameworks.md`" or "build the skeleton for `docs/<topic>/` and write the
  first section." Not a fit for a quick single-fact lookup (a plain WebSearch call in the
  current context is cheaper) or for reviewing/editing already-written content (`review-md`).
- Dispatch contract: the dispatch names the target file(s) or directory, the topic, and
  either an existing outline to fill in or license to propose one. It carries no assumption
  that a caller-side convention (heading style, an existing sibling doc's structure) was
  communicated unless the dispatch restates it - this agent starts cold like the others in
  this file.
- Non-goals: fanning out further research delegation of its own (it has no `Agent`
  tool - see Constraints), and never dispatched more than one at a time by its caller for
  what could instead be sequential or in-context work; doing so reproduces the exact
  cold-context multiplication `decisions/0008-avoid-parallel-research-fanout.md` addresses,
  with a new tool instead of the old one.
- Model/tier: Sonnet, no `effort` override - default per `CLAUDE.md`'s Subagents & Models
  section. Research synthesis needs judgment about source relevance and quality that the
  Haiku profile (`Explore`) is not suited to, but nothing about the task is ambiguous or
  high-stakes enough to warrant Opus or a raised effort floor.
- Constraints: `readonly: false`, since this agent writes the documentation it researches,
  and a `tools` allow-list of Read, Write, Edit, WebSearch, WebFetch, Bash, Grep,
  Glob, TaskCreate, TaskUpdate - no `Agent` tool, so it cannot dispatch further subagents.
  TaskCreate/TaskUpdate are the harness's own task-list tracker for this agent's step-by-step
  progress, not a subagent-dispatch mechanism, and are separate from the written progress-file
  convention `reference/research-discipline.md` describes. Read is used, among other things,
  to load `reference/research-discipline.md`
  at the start of every dispatch. Bash is available for that file's usage-utilization check
  (a `curl` against `https://api.anthropic.com/api/oauth/usage` using the bearer token from
  `$CLAUDE_CONFIG_DIR/.credentials.json`, mirroring `scripts/statusline.sh`'s own fallback
  fetch) and for read-only inspection, not for arbitrary write access outside Write/Edit.
- Output contract: an initial skeleton/outline written before deep content, then incremental
  section-by-section fill-in with the progress file updated after each section, so a caller
  can resume a long-running dispatch across turns. A final report states what was written,
  the current state of the progress file, the last usage-utilization reading taken, and
  whether it stopped early because that reading crossed the caller's threshold.
- Acceptance criteria:
  - Given a dispatch naming a target directory or file and a topic, writes a skeleton or
    outline before writing full section content.
  - Maintains a progress file that a fresh dispatch of this same agent could read to resume
    where a prior run left off, without re-deriving already-completed sections.
  - Checks account usage utilization at least once per dispatch for any task expected to run
    more than a few tool calls, and halts with a report (not a silent stop) once utilization
    crosses the caller-set threshold (default 90%) rather than continuing regardless.
  - Never invokes an `Agent`/`Task`-shaped tool and is never itself dispatched more than once
    concurrently by a well-behaved caller (a caller violating this is a caller-side defect,
    not something this agent can detect from inside its own dispatch).
  - Cites sources for material drawn from external pages, per
    `reference/document-generation.md`'s References-section policy.
