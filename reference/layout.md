---
created: 2026-09-14
updated: 2026-09-14
---

# Repository layout

This is the full inventory: every top-level file and directory, every hook script with its
registration state, and every skill and subagent, each with the rationale a one-line summary
would lose. `README.md`'s own Layout section is the short version - start there for orientation;
come here when you need to know exactly what a given script does, whether it is registered, or
why it exists.

The inventory covers only what this repository tracks. The harness keeps its own runtime state in
`~/.claude` as well - `cache/`, `sessions/`, `daemon/`, `plans/`, `projects/`, and more - all of it
gitignored, none of it part of this config, and none of it listed below.

"Registered" means two different things below, and the difference matters to a fresh clone.
Claude Code hooks (`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`) are declared in the
tracked `settings.json`, so they are live the moment you clone the repo. Git hooks
(`.git/hooks/pre-commit`, `post-commit`, `post-merge`, `post-rewrite`) are local, untracked state
that only `scripts/setup.sh` creates - a fresh clone has none of them until you run it, regardless
of what a script's entry below says its registered state is. See README.md's Setup After Cloning
section.

- `CLAUDE.md` - global agent configuration (constitution/steering), loaded by Claude Code at user
  scope and the hand-maintained source of truth for global rules, including a Canary/Compact
  Instructions verification mechanism for the compaction/summarization survival gap - see
  `decisions/0006-global-config-compaction-verification.md`.
- `settings.json` - Claude Code settings (including the Markdown hooks and the `statusLine`
  key pointing at `scripts/statusline.sh`) for this config directory. See
  `skills/cursor-projection/SKILL.md` for the Cursor counterparts of these.
- `specs/` - per-artifact intent and acceptance criteria; the source a regeneration reads
  (`skills.md`, `agents.md`, `behaviors.md`, `rules.md`, `backlog.md`). Holds intent only, never
  copied artifact content.
- `decisions/` - numbered, immutable Architecture Decision Records.
- `reference/` - internally-authored operational protocols that artifacts draw on:
  `spec-driven-architecture.md`, `subagent-orchestration.md`, `context-file-authoring.md`,
  `document-generation.md`, `research-discipline.md`, `model-selection.md` (the tier ladder,
  effort mechanics, and delegation-shape rules behind `CLAUDE.md`'s Subagents & Models
  section), `public-repo-hygiene.md` (what must never enter a tracked file in this
  public-facing repo, and the neutral substitutes to use instead), and this file.
- `docs/` - human-oriented notes and platform documentation. Multi-chapter guides:
  - `features/` - how two specific Claude Code features actually behave: `goal.md` on `/goal` as a
    session-scoped Stop hook with a natural-language predicate, and `skills.md` on the skill
    triggering system and description optimization.
  - `generative-ai/` - a seven-chapter primer taking a reader from fundamentals through models and
    inference, prompts and caching, agents and harnesses, retrieval, and security, with appendices.
  - `efficient-agentic-use/` - a six-chapter guide to cost-effective agentic tool use, with
    harness and model-family appendices.
  - `tui-ux/` - a six-chapter reference on terminal interface design, accessibility, and the
    Go/Rust/Python TUI framework ecosystems.
  - `cyberdecks/` - a five-part guide to the DIY cyberdeck hobby, from etymology and history
    through a component-by-component build guide.

  Standalone documents:
  - `plugin-research.md` - evaluation of a set of third-party plugin and skill repos, ranked by
    recommendation strength.
  - `context-rot.md` - a citation-graded survey of the long-context-degradation research
    literature, including where Claude specifically has and hasn't been measured.
  - `progressive-disclosure.md` - traces progressive disclosure from its 1980s HCI origins through
    its 2025-2026 use in Anthropic's Agent Skills architecture, flagging where the evidence for
    agent use is still thin.
  - `multi-account-claude-code.md` - setup and pitfalls for running two or more Claude accounts on
    one machine via `CLAUDE_CONFIG_DIR`, on both macOS and Linux, with the undocumented macOS
    Keychain service-name scoping in an appendix.
- `scripts/` - scripts for the mechanical (deterministic) config outputs (`sync.sh`), the hook
  logic a registration points at (below), and the `statusLine` command script (`statusline.sh`,
  registered via the `statusLine` key in `settings.json`; `statusline-tests/` holds that script's
  fixtures, structural assertions, and its own README; see `skills/cursor-projection/SKILL.md` for
  the status line counterpart); model-generated where useful and
  reviewed before commit, with hook registration requiring the user's explicit, in-the-moment
  direction each time (see `decisions/0003-hooks-and-scripts-authoring-policy.md`). Hook logic, by
  registration state:
  - `md-ledger-append.sh` (`PostToolUse`) and `md-deferred-checks.sh` (`Stop`) - the registered
    pair. `md-ledger-append.sh` records each edited Markdown file to a per-session ledger;
    `md-deferred-checks.sh` drains that ledger at the end of each agent loop and invokes
    `markdownlint-hook.sh`, `md-checks.sh`, and `link-recheck-hook.sh` once per distinct file in
    the ledger, so those three run once per agent-loop stop rather than once per edit.
    - `markdownlint-hook.sh` - runs `markdownlint --fix` on the changed file, no-oping silently on
      anything that isn't Markdown. Not registered directly in `settings.json`; reached only
      through `md-deferred-checks.sh`. Runs first in the drained-ledger sequence, since it can
      reformat the file before `md-checks.sh` reads it.
    - `md-checks.sh` - the deterministic, offline mechanical checks over a Markdown file
      (placeholders, CLAUDE.md typography compliance, skipped heading levels, relative link targets
      that do not resolve, same-file anchors with no matching heading). Silent for a clean file,
      never edits anything, always exits 0. Also invoked directly by the `review-md` skill, so one
      implementation serves both the hook path and the review path.
    - `link-recheck-hook.sh` - the only network-touching check. Probes References-section links in
      parallel, prints nothing when every link resolves, and self-gates on a freshness window keyed
      to the document's URL set, so a repeat run makes no network call at all.
  - `filter-verbose-output.sh` (`PreToolUse`, matcher `Bash`) - registered.
  - `destructive-git-guard.sh` (`PreToolUse`, matcher `Bash`, ordered before
    `filter-verbose-output.sh` in the same matcher block) - registered. The operations it catches:
    - `push --force`/`-f`/`--force-with-lease`, a leading `+` refspec, or a `--delete`/`:branch`
      delete refspec
    - `reset --hard`
    - `clean -f`/`--force`, including combined clusters like `-fd`
    - `branch -D` or `--delete --force`
    - `commit --no-verify`/`-n`/`--no-gpg-sign`
    - `rebase -i`/`--interactive`
    - `checkout`/`restore` targeting a bare `.` (`restore --staged` without `--worktree` is exempt,
      since unstaging alone doesn't discard working-tree edits)
    - `stash drop`/`clear`
    - `filter-branch`
    - `reflog expire --all` combined with `--expire=now`/`--expire-unreachable=now`

    Position does not matter: the flag is found wherever it falls on the command line, and the git
    call is found wherever it sits in the command string, since each segment of a compound command
    is inspected. Leading environment assignments, command wrappers (`env`, `time`, `sudo`,
    `xargs`, ...) and git's own pre-subcommand options are skipped, so `cd repo && git push
    --force`, `git -C repo push --force`, and `time git push --force` are all caught. This closes
    the gap `permissions.deny`'s prefix-only matching leaves open - see `specs/behaviors.md`'s
    Destructive Git Guard section. `git-guard-tests/` holds its assertion suite, which has its own
    README and should be run after any change to the script: because the guard fails open, a broken
    one and a working one look identical on every allowed command.
  - `health-check.sh` - logic only, deliberately NOT registered and meant to stay that way: the
    full-tree mechanical half of the periodic self-evaluation, run by hand rather than on any hook
    path. Checks JSON validity of every tracked `*.json`, that every command `settings.json` points
    at exists and is tracked, `created:`/`updated:` frontmatter (presence, ordering, and no future
    dates), skill description budgets, spec coverage in both directions, README coverage, script
    executable bits, `bash -n` and shebangs, a skill's or subagent's `name:` against its own path,
    `decisions/` numbering, backticked repo-internal path references in prose, and unbumped
    `updated:` dates in the working tree; advisory scans cover eval coverage, always-loaded context
    budget, unreferenced artifacts, and `updated:` dates trailing a file's last commit. Delegates to
    `md-checks.sh`, `scrub-check.sh`, `sync.sh --check`, and `setup.sh --check` rather than
    reimplementing them. Read-only apart from `.health-check-stamp`, a gitignored marker recording
    the last full run's date, commit, and finding count so `session-setup-check.sh` can nudge when a
    run is overdue or left findings unaddressed; exits non-zero on findings. The stamp records the
    finding count, not just the date, because otherwise a run that turned up nine problems and was
    then ignored would reset the clock exactly as a clean one did. See README.md's Health check
    section, and `specs/behaviors.md`'s Config Health Check section.
  - `read-only-plan-guard.sh` - logic only, deliberately NOT registered; activating it needs that
    same explicit direction and the snippet to do it lives in `skills/write-plan/SKILL.md`.
  - `pre-commit-check.sh` - registered as `.git/hooks/pre-commit` (a git hook, not a Claude
    Code lifecycle hook - see `specs/behaviors.md`'s Pre-commit Drift Check section for why
    that's a different risk class). Runs four read-only checks: `settings.json` JSON validity,
    `sync.sh --check` projection drift, `scrub-check.sh --staged` over the staged content, and
    `scrub-check.sh --test` to confirm scrub-check's own patterns are still firing. Takes
    `--repo <dir>` naming the checkout being committed to, which every registration passes, so a
    repository wanting the same gate borrows this script rather than copying it and carries no more
    than its own hand-written `.git/hooks/pre-commit`. The gate may inspect a borrowed repository
    but never execute anything out of one, so the leak checks and the JSON check travel there and
    the projection check does not - nor does it run in a linked worktree, where it would compare
    machine-level artifacts against a checkout that never installs them. Local-only; not tracked by
    git, so it needs reinstalling on a fresh clone - see README.md's Setup After Cloning section.
  - `session-setup-check.sh` (`SessionStart`) - warns at session start about two things: this
    machine's setup being incomplete, so a missing pre-commit registration surfaces before the
    commit that needed it (`setup.sh --check`), and the health check being overdue or having left
    findings unaddressed, read from `.health-check-stamp`. The two are independent and compose into
    one message. Registered twice: bare on `startup|resume` for the full warning, and
    with `--context-only` on `clear|compact`, which re-tells Claude (both events wipe its copy of
    the note) without re-nagging the user who saw it minutes ago. `fork` is left unregistered since
    it inherits context. Silent on a healthy machine, silent for sessions outside this repo, and
    silent in a replicated profile with no repository. Emits JSON rather than plain text because
    `SessionStart` stdout goes to Claude's context, not to the terminal - see `specs/behaviors.md`'s
    Session Setup Check section.
  - `setup.sh` - brings a fresh clone or a new machine to the state cloning cannot produce: the
    git hook registrations, `scrub-patterns.local`, and `scrub-test.local`. Idempotent, never
    overwrites a hook it did not write, and `--check` reports what is missing without changing
    anything. Human-run only, per `decisions/0003-hooks-and-scripts-authoring-policy.md` - it
    registers hooks. See README.md's Setup After Cloning section.
  - `scrub-check.sh` - detects content unsuited to a public remote in tracked files: absolute home
    paths and their projects-path spellings, the local username and hostname, session UUIDs, email
    addresses, and credential-shaped tokens. `--repo <dir>` scans a different checkout instead,
    while still reading `scrub-patterns.local` and `scrub-test.local` from this repository's main
    checkout - they describe a person and a machine rather than a repository, and being gitignored
    they do not exist in a linked worktree. Read-only, exits non-zero on findings, silent when
    clean. Bare, it audits every tracked file in the working tree (`--all` says the same thing
    explicitly, and explicit paths check just those). The commit gate passes `--staged`, which
    checks the bytes about to be committed rather than the working tree - the difference between
    blocking a leak and waving it through, since a secret staged and then tidied out of the working
    tree still passes. A third mode, `--test`, is the commit gate's self-test: it scans the
    gitignored `scrub-test.local` and fails unless every fixture line there triggers at least
    one warning, catching a pattern that has silently stopped matching before it lets something
    real through. Carries no sensitive values itself - machine literals are derived at run time and
    client-specific patterns come from the gitignored `scrub-patterns.local`, whose absence (like
    `scrub-test.local`'s, for `--test`) is a hard error (exit 2) rather than a silent skip. Policy
    in `reference/public-repo-hygiene.md`, rationale in
    `decisions/0009-public-repo-hygiene-as-an-always-on-rule.md`.
  - `replicate.sh` - mirrors shared config (`skills/`, `agents/`, `scripts/`, `commands/`, `rules/`,
    `hooks/`, `reference/`, `decisions/`, `settings.json`, and a managed copy of this repo's
    `CLAUDE.md`) into one or more other `CLAUDE_CONFIG_DIR` directories, e.g. a second account's
    config dir, passed as arguments - see the file's own header for usage and install steps.
    Registered as the `post-commit`, `post-merge`, and `post-rewrite` hooks, which
    take the target dir(s) from `.git/hooks/replicate-targets.sh` (which accounts exist is
    per-machine state, not committed to the repo), so every commit to `main` in the main working
    tree - and every pull that brings one in from another machine - replicates automatically. Each
    path syncs exactly once: `post-rewrite` ignores its `amend` invocation (already covered by
    `post-commit`), and `post-commit` stands down while a rebase is replaying commits through it.
    `replicate-targets.sh` guards on its own emptiness rather than letting the hooks call
    `replicate.sh` with no arguments, which would print the script's usage message after every
    commit and pull. The script itself skips quietly on a linked worktree or any other branch,
    since `git rev-parse --show-toplevel` (which `replicate-targets.sh` uses to locate it) resolves
    per-worktree. Local-only; not tracked by git, so it needs reinstalling (with its target dir(s))
    on a fresh clone, same as `pre-commit-check.sh`. A
    target's CLAUDE.md is a copy rather than a symlink or an `@`-import - see the file's own
    comments for why, including which of `CLAUDE.md`'s own pointers that leaves unresolvable in a
    target. `mkdir`-locked (no `flock` on macOS) so overlapping runs can't rsync into the same
    target at once; a run that fails partway logs which target may now have a mix of old and new
    config, rather than staying silent about it.
- `evals/` - the repo-wide eval run procedure, thresholds, and results log; per-artifact test
  cases stay co-located under each skill's own `evals/` directory, split into `evals.json`
  (behavioral, run by the plugin's grader) and `trigger-evals.json` (did the skill fire, run by the
  plugin's `run_loop.py`). The two cannot be combined: see `evals/README.md`.
- `skills/` - personal agent skills:
  - `skill-author` - create, audit, or explain agent skills; hands off to `skill-creator` for
    scaffolding and evals. See `specs/skills.md`'s skill-author section.
  - `review-md` - proofread a single Markdown document, tracking settled/deferred findings in
    `review-tracking.md`. See `specs/skills.md`'s review-md section.
  - `write-plan` - plan a multi-step piece of work into a self-contained, agent-executable
    Markdown plan file (auto-invocable). Ships a filled-in example under `examples/`.
  - `execute-plan` - execute an already-written plan by dispatching its units to subagents, with
    the escalation ladder, a circuit breaker, and a Definition-of-Done gate (manual invocation
    only). Both plan skills share the orchestration protocol in
    `reference/subagent-orchestration.md`.
  - `health-check` - the judgment half of the periodic self-evaluation (Opus tier). Runs
    `scripts/health-check.sh`, triages its findings, then assesses cross-document coherence,
    staleness, and whether each artifact still earns its place. Read-only by default; proposes
    changes rather than applying them. See `specs/skills.md`'s health-check section.
  - `research` - auto-invocable; loads the skeleton-first/progress-file/usage-check research
    discipline (`references/research-discipline.md`) into whichever context is doing a
    research-heavy documentation-generation task, and states the delegation decision (inline by
    default; parallel `Agent` forks for independent sub-topics; the `researcher` subagent only
    for the narrow-tool-contract case - session size alone is not a valid trigger). Deliberately
    has no `context: fork` pin - see `decisions/0008-avoid-parallel-research-fanout.md` and
    `specs/skills.md`'s research section.
  - `cursor-projection` - the single home for Cursor knowledge in this config, including the
    harness fact base, the `CLAUDE.md`-to-User-Rules projection procedure, the status line
    implementation, and the config writer that projects hooks, status line, and MCP config into
    `~/.cursor/`. See `decisions/0005-cursor-projection-as-a-skill.md` and `specs/skills.md`'s
    cursor-projection section.
  - `deep-review` - the premise-level questions other reviews leave unasked, of code, a document,
    a plan, or an in-conversation idea (Opus tier): is it actually useful, does it belong here, is
    there a better way, does it serve its stated purpose, and what does it rest on - each answered
    by name, closing with an explicit verdict. Auto-invocable on explicit premise or depth language
    only ("deep review", "be critical", "is this a good idea", "does this belong here", "does this
    provide value", "is there a better way"), so plain "review this doc" still falls to
    `review-md`. Runs its judgment pass on a dispatched
    Opus subagent when the caller is below that tier, rather than relying on the frontmatter pin,
    which is known not to hold; at Opus the dispatch folds inline. The reason behind each
    dispatch parameter lives in `skills/deep-review/references/dispatch.md`. See
    `specs/skills.md`'s deep-review section.
- `agents/` - personal subagent definitions:
  - `Explore` - read-only search agent pinned to Haiku at high effort, replacing the built-in
    `Explore` after it stopped defaulting to Haiku. Searches any file tree (code, documentation,
    config, loose files), git or not, with separate tactics for code and prose. Returns
    `path:line` references under a bounded output budget rather than file contents, so the caller
    spends its own context only on what matters. Starts cold by design; see the file's
    dispatch-brief contract. Its `tools:` allow-list is paired with `readonly: true` so the
    constraint holds where a coarser permission model is all that is available; see
    `skills/cursor-projection/references/harness-matrix.md` for how the `haiku` pin and `effort`
    project onto other harnesses.
  - `runner` - Haiku-tier command runner for verbose output (test suites, builds, linters, log or
    metric pulls, large diffs), so that output is billed once inside the subagent instead of
    riding along in the caller's context on every later turn. Reports only failures plus a
    one-line pass/fail summary, quoting error text verbatim; never edits source.
  - `executor` - Sonnet-tier mechanical implementer for one fully-specified plan step: the
    file(s), the exact change, and a verification command, all supplied in the dispatch. No scope
    widening; halts and reports rather than guessing when a step is ambiguous. Intended for the
    prescriptive units `write-plan` produces and `execute-plan` dispatches.
  - `researcher` - Sonnet-tier research-and-write worker for one self-contained documentation
    topic, used only when its raw WebSearch/WebFetch output would flood the caller's own
    context. Works incrementally (skeleton first, then section by section) with progress
    tracked in a written file, and checks account usage utilization periodically, halting to
    report rather than continuing once it crosses a caller-set threshold. No `Agent`/`Task`
    tool, so it cannot fan out further, and is never dispatched more than one at a time - see
    `decisions/0008-avoid-parallel-research-fanout.md` for why.

This list will grow as commands and hooks are added.
