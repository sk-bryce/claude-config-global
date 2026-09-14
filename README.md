# claudeconf

Personal agent config, skills, and more. Lives at `~/.claude` and targets Claude Code. See
`skills/cursor-projection/SKILL.md` for how this config projects onto Cursor.

This repo uses a spec-anchored architecture: intent lives in `specs/`, generated artifacts are
committed and regenerated from those specs, decisions are recorded in `decisions/`, and persistent
governing context lives in `CLAUDE.md` plus `reference/`. See
`reference/spec-driven-architecture.md` for the rationale and operating model, and
`decisions/0001-adopt-spec-driven-config-architecture.md` for the decision.

## About this repo

This repo is published as a reference rather than as a product. It is not a framework, a plugin,
or a starter template, and it carries no support, versioning, or stability guarantee: files
change when the workflow behind them changes, and nothing here is built to be installed
wholesale.

Two things to know before borrowing from it. Several of the scripts under `scripts/` are
registered as hooks and as the status line, which means they run automatically on every matching
tool call, edit, or render - read any of them in full before registering one yourself, and see
`decisions/0003-hooks-and-scripts-authoring-policy.md` for the review bar this repo holds itself
to. The Layout section below gives each script's actual registration state; several are
deliberately left unregistered. And the rules in `CLAUDE.md` are tuned to one person's habits;
the reasoning is the transferable part, not the settings themselves.

Licensed under the MIT License, except `docs/`, which is licensed under CC BY 4.0. See the
License section at the end of this file.

## Setup After Cloning

A fresh clone is missing the local-only state this repo deliberately does not track: the git hook
registrations, your machine's scrub patterns, and the scrub self-test fixtures. Everything else
travels with the clone.

```sh
scripts/setup.sh            # install what is missing; prompts for scrub patterns and test fixtures on first run
scripts/setup.sh --check    # report what is missing, change nothing
scripts/setup.sh --scrub    # add more scrub patterns or test fixture lines later
```

`setup.sh` is idempotent - re-running a completed setup changes nothing - and it never overwrites a
hook it did not write. Run `--check` any time to confirm nothing has drifted; a hook registration
is untracked local state, so it can silently go missing and nothing else will notice.

**Run it yourself rather than asking an agent to.** It performs hook registration, which
`decisions/0003-hooks-and-scripts-authoring-policy.md` requires be your explicit, in-the-moment act.
`--check` is read-only and safe for anyone to run.

What it sets up:

1. **`.git/hooks/pre-commit`** -> `scripts/pre-commit-check.sh`. Gates a commit on four read-only
   checks: `settings.json` parses as JSON, `scripts/sync.sh --check` reports no projection drift,
   `scripts/scrub-check.sh` finds nothing unsuited to a public remote in the staged content, and
   `scrub-check.sh --test` confirms its own patterns are still firing. Without this hook, none of
   them run.
2. **`scrub-patterns.local`** (repository root, gitignored). The client, engagement, and
   internal-hostname patterns only you know - one extended regex per line, `#` for comments.
   `scrub-check.sh` **refuses to run** without this file rather than passing quietly, because its
   built-in coverage (structural shapes plus literals derived from this machine) is the kind of
   partial coverage that looks adequate right up until a client name reaches a public remote. An
   empty file is a valid answer and means "I have no such tokens"; a missing file is an unanswered
   question. It needs no `.gitignore` rule: the leading `/*` there ignores every root entry not
   explicitly whitelisted, so it cannot be committed by accident.
3. **`scrub-test.local`** (repository root, gitignored, same mechanism as above). Fixture lines
   known to match one of the patterns above, used by `scrub-check.sh --test` to prove they still
   fire rather than having silently stopped matching. Its absence is a hard error for `--test` the
   same way `scrub-patterns.local`'s absence is for the default scan, and for the same reason.
4. **`.git/hooks/post-commit`, `post-merge`, and `post-rewrite`** -> `scripts/replicate.sh`, which
   mirrors this config into other `CLAUDE_CONFIG_DIR` profiles. Three hooks because replication has
   to follow content onto a machine, not just off the one that wrote it: with `post-commit` alone, a
   commit authored on another machine arrives here by pull and this machine's other profiles stay
   stale until it happens to commit something itself. Git has no post-pull hook, so `git pull` is
   caught by the two hooks its integration step fires - `post-merge` for the merge (fast-forwards
   included), `post-rewrite` for `--rebase`. Each path syncs exactly once: `post-rewrite` ignores
   its `amend` invocation (already covered by `post-commit`), and `post-commit` stands down while a
   rebase is replaying commits through it.
5. **`.git/hooks/replicate-targets.sh`**, the target list all three hooks exec. `setup.sh` prompts
   for the target directories, since which accounts exist is per-machine state it cannot invent, and
   keeps them in one file so a target is added or removed in one place rather than three. Giving no
   targets is a valid answer and still installs everything - the list simply guards on its own
   emptiness - so that a missing hook always means "setup was never run" rather than the ambiguous
   "maybe there was nothing to replicate". That guard is deliberate: `replicate.sh` with zero
   arguments prints its usage message, which would otherwise appear after every commit and pull. A
   `post-commit` left over from before this file existed, with its targets hardcoded, is migrated
   automatically.

## Layout

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
- `reference/` - internally-authored operational protocols artifacts draw on:
  `spec-driven-architecture.md`, `subagent-orchestration.md`, `context-file-authoring.md`,
  `document-generation.md`, `research-discipline.md`, `model-selection.md` (the tier ladder,
  effort mechanics, and delegation-shape rules behind `CLAUDE.md`'s Subagents & Models
  section), and `public-repo-hygiene.md` (what must never enter a tracked file in this
  public-facing repo, and the neutral substitutes to use instead).
- `docs/` - human-oriented notes and platform documentation (`features/`, `generative-ai/`,
  `efficient-agentic-use/` - a six-chapter guide to cost-effective agentic tool use, with
  harness and model-family appendices; `tui-ux/` - a six-chapter reference on terminal
  interface design, accessibility, and the Go/Rust/Python TUI framework ecosystems;
  `cyberdecks/` - a five-part guide to the DIY cyberdeck hobby, from etymology and history
  through a component-by-component build guide), plus `plugin-research.md` (evaluation of a set
  of third-party plugin and skill repos, ranked by recommendation strength),
  `context-rot.md` (a citation-graded survey of the long-context-degradation research literature,
  including where Claude specifically has and hasn't been measured),
  `progressive-disclosure.md` (traces progressive disclosure from its 1980s HCI origins through
  its 2025-2026 use in Anthropic's Agent Skills architecture, flagging where the evidence for
  agent use is still thin), and `multi-account-claude-code.md` (setup and pitfalls for running two
  or more Claude accounts on one machine via `CLAUDE_CONFIG_DIR`, on both macOS and Linux, with
  the undocumented macOS Keychain service-name scoping in an appendix).
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
    `filter-verbose-output.sh` in the same matcher block) - registered. Catches destructive git
    flags (force-push, including a `+` refspec prefix; `reset --hard`, `clean -f`, `branch -D`,
    `commit --no-verify`, `rebase -i`) regardless of where the flag falls on the command line, and
    regardless of where the git call sits in the command string - each segment of a compound
    command is inspected, and leading environment assignments, command wrappers (`env`, `time`,
    `sudo`, `xargs`, ...) and git's own pre-subcommand options are skipped, so `cd repo && git
    push --force`, `git -C repo push --force` and `time git push --force` are caught too. Closes the gap
    `permissions.deny`'s prefix-only matching leaves open - see `specs/behaviors.md`'s Destructive
    Git Guard section. `git-guard-tests/` holds its assertion suite, which has its own README and
    should be run after any change to the script: because the guard fails open, a broken one and a
    working one look identical on every allowed command.
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
    run is overdue or left findings unaddressed; exits non-zero on findings. See the Health check
    section below, and `specs/behaviors.md`'s Config Health Check section.
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
    git, so it needs reinstalling on a fresh clone - see Setup After Cloning above.
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
    registers hooks. See Setup After Cloning above.
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
    config dir, passed as arguments - see the file's own header for usage and install steps. Registered as the `post-commit`, `post-merge`, and `post-rewrite` hooks, which
    take the target dir(s) from `.git/hooks/replicate-targets.sh` (which accounts exist is
    per-machine state, not committed to the repo), so every commit to `main` in the main working
    tree - and every pull that brings one in from another machine - replicates automatically. The
    script itself skips quietly on a linked worktree or any other branch, since
    `git rev-parse --show-toplevel` (which `replicate-targets.sh` uses to locate it) resolves
    per-worktree. Local-only; not tracked by git, so it needs
    reinstalling (with its target dir(s)) on a fresh clone, same as `pre-commit-check.sh`. A
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
    scaffolding and evals.
  - `review-md` - proofread a single Markdown document, tracking settled/deferred findings in
    `review-tracking.md`.
  - `write-plan` - plan a multi-step piece of work into a self-contained, agent-executable
    Markdown plan file (auto-invocable). Ships a filled-in example under `examples/`.
  - `execute-plan` - execute an already-written plan by dispatching its units to subagents, with
    the escalation ladder, a circuit breaker, and a Definition-of-Done gate (manual invocation
    only). Both plan skills share the orchestration protocol in `reference/subagent-orchestration.md`.
  - `health-check` - the judgment half of the periodic self-evaluation (Opus tier). Runs
    `scripts/health-check.sh`, triages its findings, then assesses cross-document coherence,
    staleness, and whether each artifact still earns its place. Read-only by default; proposes
    changes rather than applying them. See `specs/skills.md`'s health-check section.
  - `research` - auto-invocable; loads the skeleton-first/progress-file/usage-check research
    discipline (`references/research-discipline.md`) into whichever context is doing a
    research-heavy documentation-generation task, and states the delegation decision (inline by
    default; parallel `Agent` forks for independent sub-topics; the `researcher` subagent only
    for the narrow-tool-contract case - session size alone is not a valid trigger). Deliberately
    has no `context: fork` pin -
    see `decisions/0008-avoid-parallel-research-fanout.md`.
  - `cursor-projection` - the single home for Cursor knowledge in this config, including the
    harness fact base, the `CLAUDE.md`-to-User-Rules projection procedure, the status line
    implementation, and the config writer that projects hooks, status line, and MCP config into
    `~/.cursor/`. See `decisions/0005-cursor-projection-as-a-skill.md`.
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

## Regenerating and checking drift

`scripts/sync.sh` keeps the skills' `references/` copies in sync with their in-repo sources and
drift-checks them. Run `scripts/sync.sh --check` to report divergence without writing anything
(exits non-zero if any output has drifted); apply mode writes only inside this repo, so it carries
no hook-registration hazard. See that script's header comment for the full source-to-output
mapping.

Cursor projection is a separate concern, handled entirely by the `cursor-projection` skill. Its
projection script writes `~/.cursor/hooks.json`, `~/.cursor/mcp.json`, and
`~/.cursor/cli-config.json`, all outside this repo, so its apply mode does register hooks - and
that write is the explicit, in-the-moment human act
`decisions/0003-hooks-and-scripts-authoring-policy.md` requires. See
`skills/cursor-projection/SKILL.md` for the script and how to run it; read it in full before ever
running it without `--check`.

## Health check

`scripts/health-check.sh` is the repository's self-evaluation pass. It is deliberately not a hook
and not part of the commit gate: `scripts/pre-commit-check.sh` stays the fast staged-only gate,
while this walks the whole tracked tree and can afford to be slow.

```
scripts/health-check.sh            # every check
scripts/health-check.sh --quick    # skip the delegated scripts and the git-history scan
```

It prints findings as `<path>:<line> - <description>` grouped under `== <category> ==` headers,
with advisory categories - machine-local setup, budget and coverage measurements, unreferenced
artifacts, historical `updated:` drift - marked and excluded from the exit code. Exit 0 means no
failures, 1 means at least one check failed, 2 means a usage or environment error. It never edits,
stages, or registers anything.

For the half a regex cannot do - is this still coherent, what has gone stale, does each artifact
still earn its place - invoke the `health-check` skill, which runs the script and then reviews what
it found.

Suggested cadence: weekly to monthly, and always before a publication pass. Nothing enforces that,
so a full run records its date, the commit it ran against, and its finding count in
`.health-check-stamp` (gitignored, machine-local), and `session-setup-check.sh` speaks up at session
start when either of two things is true:

```
Config health check was last run 12 days ago (2026-08-12), 3 commits back - a run is due.
Config health check was last run 3 days ago (2026-08-21), and left 5 findings unaddressed - a run is due.
```

- **Overdue** - more than 7 days since the last run. Stretched to 30 when HEAD has not moved, the
  working tree is clean, and that run was clean: an idle tree earns a longer leash, never silence,
  because `scrub-patterns.local`, `.git/hooks/`, `settings.local.json`, on-disk
  permission bits, and the working-tree diff all feed checks here, and none of them lives in a
  commit.
- **Unaddressed findings** - the last run reported findings and is at least 3 days old. Without
  this, a run that turned up nine problems and was then ignored reset the clock exactly as a clean
  one did. The three-day grace period is there so the nudge is not nagging you about findings you
  are in the middle of fixing.

`--quick` deliberately does not stamp - it skips the delegated scripts and both history scans, so
letting it reset the clock would buy a week of silence for a fraction of the check. The nudge is
advisory in both directions: it never runs the check, and it tells Claude not to run one unprompted,
since a 16-second full-tree pass and its findings have no business landing in an unrelated session.

## License

Two licenses, split at one directory boundary:

- **`docs/` - Creative Commons Attribution 4.0 International (CC BY 4.0).** See `docs/LICENSE`.
  This is the prose: the `generative-ai/`, `efficient-agentic-use/`, `tui-ux/`, and `cyberdecks/`
  guides plus the standalone research pieces. Reuse and adapt it freely, including commercially;
  credit it and indicate what you changed. Several of these documents quote or summarize
  third-party material that remains under its own terms - each one's References section lists
  its sources.
- **Everything else - MIT.** See `LICENSE`. Scripts, skills, agents, specs, decisions, reference
  protocols, and the global instruction files are all operational material meant to be installed
  and adapted, so they carry no attribution requirement to trip over inside your own config.

Both licenses disclaim warranties. Parts of this repo are model-generated, which in some
jurisdictions affects what is copyrightable in the first place; the licenses above are offered
over whatever rights do exist, not as a claim that every line is protected.
