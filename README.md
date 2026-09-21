# Claude Config

A personal Claude Code configuration: global rules, skills, subagents, hooks, and reference docs,
all under one directory (`~/.claude`). Published so others can reuse the reasoning behind these
choices, even though the settings themselves are tuned to one person's workflow.

## What's here and why you might care

If you're just browsing, the parts worth a look are:

- **`CLAUDE.md`** - the global rules file: working style, response style, git conventions,
  subagent and model selection, and a mechanism for surviving context compaction. Read it for the
  shape of the rules, not as something to install verbatim.
- **`skills/` and `agents/`** - the Claude Code skills and subagent definitions this config runs
  on day to day. `reference/layout.md` describes what each one does.
- **`decisions/`** - numbered Architecture Decision Records explaining why this config is shaped
  the way it is (why hooks require in-the-moment human registration, why Cursor projection is a
  skill rather than a script, why research fan-out is restricted, and more).
- **`docs/`** - standalone long-form guides that don't depend on the rest of the config, including
  a from-zero-to-advanced generative AI and LLM primer, a cost-effective agentic tool use guide, a
  terminal UI design reference, a DIY cyberdeck build guide, a guide to running several Claude
  accounts on one machine, and research write-ups on context rot, progressive disclosure, and the
  third-party plugin/skill ecosystem. These are useful on their own even if you never touch the
  config itself.
- **`reference/spec-driven-architecture.md`** - the operating model this whole repo follows:
  intent lives in `specs/`, generated or hand-authored artifacts are checked against it, and
  `decisions/` records why. Read this before proposing changes to how the repo itself works.

This repo is published as a reference, not a product. It is not a framework, a plugin, or a
starter template, and it carries no support, versioning, or stability guarantee - files change
when the workflow behind them changes, and nothing here is built to be installed wholesale.

One thing to know before borrowing from it: several scripts under `scripts/` are registered as
hooks and as the status line, meaning they run automatically on every matching tool call, edit, or
render. Read any script in full before registering it yourself - see
`decisions/0003-hooks-and-scripts-authoring-policy.md` for the review bar this repo holds itself
to, and `reference/layout.md` for each script's actual registration state (several are
deliberately left unregistered).

Licensed under the MIT License, except `docs/`, which is licensed under CC BY 4.0 - see
[License](#license) below.

## Using this as your own config

To actually run Claude Code against this configuration:

1. Clone the repo to `~/.claude`, or point `CLAUDE_CONFIG_DIR` at wherever you put it.
2. Run `scripts/setup.sh` (see [Setup After Cloning](#setup-after-cloning) below) to install the
   local-only state a clone can't carry: git hook registrations, your own scrub patterns, and the
   fixtures that self-test them.
3. Read `CLAUDE.md` and decide what to keep. Its rules encode one person's preferences - trim,
   replace, or rewrite freely; the ADRs in `decisions/` explain the reasoning behind the parts
   that aren't obviously arbitrary.
4. Skim `reference/layout.md` for what each skill, subagent, and hook script actually does before
   relying on any of them, since several are opinionated in ways that won't suit every workflow.

From there, day-to-day use is just using Claude Code - the skills and subagents in this config
activate on their own triggers (described in each `SKILL.md` and agent file) or by name.

## Setup After Cloning

A fresh clone is missing the local-only state this repo deliberately does not track: the git hook
registrations, your machine's scrub patterns, and the scrub self-test fixtures. Everything else
travels with the clone.

```sh
scripts/setup.sh            # install what is missing; prompts for scrub patterns and test fixtures on first run
scripts/setup.sh --check    # report what is missing, change nothing
scripts/setup.sh --scrub    # add more scrub patterns or test fixture lines later
scripts/setup.sh --repo <dir>   # register just the commit-message gate in another repo you work in
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
2. **`.git/hooks/commit-msg`** -> `scripts/commit-msg-check.sh`. Gates a commit on its
   *message*: rejects a `Co-Authored-By` trailer, and scans the message for the same content
   `scrub-check.sh` looks for in files. A commit message is not a tracked file, so no other check
   here has ever seen one. `git commit --no-verify` bypasses it, which is also how you add a
   co-author trailer on purpose.
3. **`scrub-patterns.local`** (repository root, gitignored). The client, engagement, and
   internal-hostname patterns only you know - one extended regex per line, `#` for comments.
   `scrub-check.sh` **refuses to run** without this file rather than passing quietly. Its built-in
   coverage is structural shapes plus literals derived from this machine, so it cannot know your
   client names; without them a clean scan would mean nothing. An empty file is a valid answer and
   means "I have no such tokens"; a missing file is an unanswered question. It needs no
   `.gitignore` rule: the leading `/*` there ignores every root entry not explicitly whitelisted,
   so it cannot be committed by accident.
4. **`scrub-test.local`** (repository root, gitignored, same mechanism as above). Fixture lines
   known to match one of the patterns above, used by `scrub-check.sh --test` to prove they still
   fire rather than having silently stopped matching. Its absence is a hard error for `--test` the
   same way `scrub-patterns.local`'s absence is for the default scan, and for the same reason.
5. **`.git/hooks/post-commit`, `post-merge`, and `post-rewrite`** -> `scripts/replicate.sh`, which
   mirrors this config into other `CLAUDE_CONFIG_DIR` profiles. Three hooks rather than one,
   because replication has to follow content onto a machine, not just off the one that wrote it.
   `post-commit` alone would miss a commit that arrives by `git pull`, leaving this machine's other
   profiles stale. Git has no post-pull hook, so `post-merge` catches the merge (fast-forwards
   included) and `post-rewrite` catches `--rebase`. Each path syncs exactly once; see
   `reference/layout.md` for how the overlap between them is suppressed.
6. **`.git/hooks/replicate-targets.sh`**, the target list all three hooks exec. `setup.sh` prompts
   for the target directories, since which accounts exist is per-machine state it cannot invent.
   Keeping them in one file means a target is added or removed in one place rather than three.
   Giving no targets is a valid answer and still installs everything: the list guards on its own
   emptiness, so a missing hook always means setup was never run. A `post-commit` left over from
   before this file existed, with its targets hardcoded, is migrated automatically.

## Layout

- `CLAUDE.md` - global agent configuration, loaded by Claude Code at user scope.
- `settings.json` - Claude Code settings: hooks, the status line, and related config.
- `specs/` - per-artifact intent and acceptance criteria that generated or checked artifacts are
  measured against (`skills.md`, `agents.md`, `behaviors.md`, `rules.md`, `backlog.md`).
- `decisions/` - numbered, immutable Architecture Decision Records.
- `reference/` - internally-authored protocols on spec-driven architecture, subagent
  orchestration, context-file authoring, document generation, research discipline, model
  selection, and public-repo hygiene, plus `layout.md` - this repo's full inventory of every
  script, skill, and subagent.
- `docs/` - human-oriented notes and standalone platform/technical guides; see
  [What's here and why you might care](#whats-here-and-why-you-might-care) above.
- `scripts/` - hook logic, the status line script, and the deterministic sync/check tooling:
  `commit-msg-check.sh`, `destructive-git-guard.sh`, `filter-verbose-output.sh`, `health-check.sh`,
  `link-recheck-hook.sh`, `markdownlint-hook.sh`, `md-checks.sh`, `md-deferred-checks.sh`,
  `md-ledger-append.sh`, `pre-commit-check.sh`, `read-only-plan-guard.sh`, `replicate.sh`,
  `scrub-check.sh`, `session-setup-check.sh`, `setup.sh`, `statusline.sh`, `sync.sh`. See
  `reference/layout.md` for what each script does and its registration state.
- `evals/` - the repo-wide eval run procedure, thresholds, and results log; see `evals/README.md`.
- `skills/` - personal agent skills (`skill-author`, `review-md`, `write-plan`, `execute-plan`,
  `health-check`, `research`, `cursor-projection`, `deep-review`).
- `agents/` - personal subagent definitions (`Explore`, `runner`, `executor`, `researcher`).

`reference/layout.md` has the full version of this list: every script's registration state and
rationale, and a longer description of each skill and subagent.

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
scripts/health-check.sh --quick    # skip the delegated scripts and both history scans
```

It prints findings as `<path>:<line> - <description>` grouped under `== <category> ==` headers,
with advisory categories - machine-local setup, budget and coverage measurements, unreferenced
artifacts, historical `updated:` drift - marked and excluded from the exit code. Exit 0 means no
failures, 1 means at least one check failed, 2 means a usage or environment error. It never edits,
stages, or registers anything.

For what a regex cannot judge - is this still coherent, what has gone stale, does each artifact
still earn its place - invoke the `health-check` skill, which runs the script and then reviews what
it found.

Suggested cadence: weekly to monthly, and always before a publication pass. Nothing enforces that,
so a full run records its date, the commit it ran against, and its finding count in
`.health-check-stamp` (gitignored, machine-local), and `session-setup-check.sh` speaks up at session
start when either of two things is true:

```
Config health check was last run 12 days ago (2026-09-02), 3 commits back - a run is due. Run scripts/health-check.sh, or ask for the health-check skill for the full review.
Config health check was last run 3 days ago (2026-09-11), and left 5 findings unaddressed - a run is due. Run scripts/health-check.sh, or ask for the health-check skill for the full review.
```

- **Overdue** - more than 7 days since the last run, stretched to 30 when HEAD has not moved, the
  working tree is clean, and that run was clean. An idle tree gets a longer grace period, not
  indefinite silence: `scrub-patterns.local`, `.git/hooks/`, `settings.local.json`, on-disk
  permission bits, and the working-tree diff all feed checks here, and none of them lives in a
  commit.
- **Unaddressed findings** - the last run reported findings and is at least 3 days old. The three
  day delay keeps the nudge quiet while you are still working through what the last run found.

`--quick` deliberately does not stamp - it skips the delegated scripts and both history scans, so
letting it reset the clock would buy a week of silence for a fraction of the check. The nudge is
advisory in both directions: it never runs the check, and it tells Claude not to run one unprompted,
since a slow full-tree pass and its findings should not land in an unrelated session.

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
