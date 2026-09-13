---
created: 2026-07-26
updated: 2026-09-12
---

# Behavior Specs

Multi-artifact behaviors: intent and acceptance criteria for capabilities that span more
than one artifact. Behavior delivered as an always-on `CLAUDE.md` rule is specified in
`specs/rules.md`. Design decisions and their rationale live in `decisions/`; this file is the
buildable intent.

---

## Plan and Execute

- Decisions recorded in `decisions/0002-plan-and-execute-framework.md`; shared protocol in
  `reference/subagent-orchestration.md`.
- Purpose: produce a self-contained, agent-executable plan, then dispatch it to subagents
  with per-unit verification.
- Shape: two skills over one shared orchestration reference.
  - `write-plan`: auto-invocable, reasoning-heavy (Opus tier, `effort: high` - a wrong plan is
    expensive to unwind, so reasoning depth is pinned rather than left to the session's baseline
    effort). Triggers: "plan this", "design an approach for ...", "make a plan for ...".
    Produces a meaningful-slug Markdown plan with a one-line Goal, a testable Definition of
    Done, self-contained units, dependency waves, a model-role map, per-unit acceptance
    gates, and an embedded
    orchestration block; runs the refinement loop (2 to 5 rounds) and a plan-level
    verification gate. Whenever two or more units share an interface (one implements it,
    another tests or consumes it), the exact literal contract is authored once and pasted
    verbatim into every unit that touches it - never independently re-described - and both the
    refinement loop and the verification gate check this by diffing literal values across
    such unit pairs, since self-containment alone does not catch two units each inventing a
    plausible-looking but different literal (a health-endpoint plan whose implementation unit and
    test unit assert different JSON response shapes - `db`/`unavailable` vs
    `database`/`degraded` - is exactly the defect a static-only verification pass, with no runtime
    available to execute the code, cannot catch). Composes with native Plan Mode
    (ingest-and-upgrade rather than double-plan) and does not write the artifact during Plan
    Mode. Ships a filled-in example plan under `skills/write-plan/examples/` to anchor the
    planner and give the testing gate a concrete artifact.
  - `execute-plan`: manual only (`disable-model-invocation: true`), orchestrator turn at
    the Sonnet tier. Trigger: `/execute-plan <plan path or slug>`. Dispatches each unit to
    a subagent (never implements the initial unit itself), applies the escalation ladder
    and halt-vs-escalate, verifies per-unit and against the Definition of Done, runs in a
    worktree by default, is resumable via per-unit marks, confirms blast radius before
    spawning, and enforces a per-run circuit breaker.
    - Context: pinned `context: fork` (`agent: general-purpose`, `background: false`).
      Rationale for forking at all: the orchestrator's own job is high tool-call-volume
      (dispatch, verify, repeat per unit) over a run that can span many units, which is
      exactly the transcript-noise this skill most wants out of the calling conversation. It
      runs in the foreground because pre-flight step 5 requires pausing for an interactive,
      blocking user confirmation of the blast-radius summary before any unit is dispatched, and
      a backgrounded fork has no tool that can pause execution and receive a real reply mid-run
      - whatever it writes is delivered once, as a final report, when the subagent terminates.
      `background: false` sacrifices the fire-and-forget benefit but keeps the
      transcript-isolation benefit, preserves a real blocking confirmation, and is known-safe by
      the same reasoning already applied to `review-md`.
- Plans directory resolution: both skills resolve the plans directory identically, in priority
  order - (1) an explicitly-set native setting (a `plansDirectory` the user actually set; the
  built-in `${CLAUDE_CONFIG_DIR:-~/.claude}/plans` default does not count as set); (2) else a
  project agent-config directory under the working directory (`<cwd>/.claude/plans/`, or
  `<cwd>/plans/` when the working directory is itself a `.claude` directory such as this repo,
  `~/.claude`, so no nested `.claude/` is created); (3) else the global
  `${CLAUDE_CONFIG_DIR:-~/.claude}/plans`. Keep project-local plans ephemeral by
  default (gitignore `.claude/plans/`, for example via `core.excludesfile`); to version and share
  them instead, do not ignore the directory. Native plan modes do not follow step 2, so this
  resolution is authoritative for the framework.
- Tier delivery: a `model:` pin carries the tier where the harness honors it, and the skill body
  also names the tier at subagent dispatch so the guidance survives a harness that drops the pin.
- Read-only enforcement: a skill-first `PreToolUse` hook, `scripts/read-only-plan-guard.sh`,
  denies `Write`/`Edit`/`MultiEdit` while `permission_mode` is `"plan"` - a backstop for the
  case where native Plan Mode enforcement
  degrades to advisory after an `ExitPlanMode` rejection. Logic is model-generated and reviewed
  before commit; a human registers it as a `hooks` entry in `write-plan/SKILL.md`'s frontmatter
  (per `decisions/0003-hooks-and-scripts-authoring-policy.md` - see that file's body for the exact
  snippet). Where no equivalent pre-write hook event exists, the skill relies on native Plan
  Mode's write-block for the human planning phase plus a read-only subagent (the built-in
  `Explore` subagent, or an equivalent) for its own research fan-out, so the constraint holds
  where a coarser permission model is all that is available.
- Team guard: both skills must instruct the orchestrator to use plain subagents and not
  propose or spawn an agent team.
- Executor default: code units take the shared reference's Haiku-first executor default, which
  holds only as long as it is confirmed empirically; where mechanical edits escalate often, they
  default to the Sonnet tier instead (see `reference/subagent-orchestration.md`).
- Acceptance criteria:
  - `write-plan` auto-triggers on planning prompts and produces a plan meeting the
    plan-level verification gate (self-contained units, explicit dependency order, testable
    criteria, named working directory and gates, no unit that says "consult the plan", and no
    two units sharing an interface asserting different literal contracts). The gate's
    orchestration-block check is performed by **diffing the embedded block against its source in
    `reference/subagent-orchestration.md`**, not by reading it: a hand-transcribed block can drop a
    whole bullet and still read as complete prose, which every other gate item passes (observed
    2026-09-08).
  - `execute-plan` only runs manually, dispatches every substantive unit to a subagent,
    and verifies the Definition of Done, not just a green build.
  - Escalation ladder and halt-vs-escalate behave per the recorded decision.
  - Neither skill proposes or spawns an agent team.
  - Testing gate (including a "native plan already present" case) passes.

---

## Document Generation

- Decision recorded in `decisions/0004-document-generation-as-always-on-rule.md`; policy in
  `reference/document-generation.md`.
- Purpose: apply a consistent References-section and link-verification policy to all
  Markdown output that draws on external sources. Always-on, not an invoked skill.
- Delivery (three pointers to the one policy file, no duplication):
  1. A `CLAUDE.md` Output Formatting pointer naming `reference/document-generation.md`.
  2. `scripts/link-recheck-hook.sh` scans a changed `.md` file's References section (skipping
     fenced code blocks) and reports each link's status per `reference/document-generation.md`'s
     verification table, never blocking or editing. It does not run directly on a `PostToolUse`
     `Write|Edit` matcher: it is invoked by the deferred drain described under "Deferred Markdown
     Checks" below, once per distinct file at the end of the agent loop rather than once per
     edit.
  3. `skills/review-md/references/document-generation.md` exists (synced by
     `scripts/sync.sh`'s `sync_reference_copies()`), and `review-md`'s `SKILL.md` loads it
     before checking links.
- Acceptance criteria:
  - Generated Markdown that used external sources ends with a verified References section
    per the policy.
  - The hook reports (without blocking on) broken links after a Markdown edit, at the end of the
    turn that made the edit per "Deferred Markdown Checks".
  - `review-md` loads the synced policy copy before its link checks.

---

## Deferred Markdown Checks

- Registration: the `settings.json` `PostToolUse` (`Write|Edit`) recorder and `Stop` drain
  entries are written by the model at the user's explicit, in-the-moment direction, which is what
  `decisions/0003-hooks-and-scripts-authoring-policy.md`'s registration rule requires - an
  explicit, contemporaneous human decision to activate, not that the human's own fingers do the
  typing.
- Purpose: stop paying `markdownlint-hook.sh` and `link-recheck-hook.sh` on every Markdown edit.
  link-recheck curls every References link serially at up to 10s each and prints a line per link
  into the calling agent's context; markdownlint reformats the whole file, so unrelated cosmetic
  churn lands mid-turn. Both belong at the end of the agent loop, run once per distinct file.
- Shape: a recorder/drain pair, because neither harness's stop-event payload says which files
  changed. `md-ledger-append.sh` stays on the file-edit event and is the only remaining per-edit
  cost: one `jq` call appending a path to `~/.claude/cache/md-ledger/<session>.paths`, silent on
  every path since its stdout would land in context. `md-deferred-checks.sh` runs on the stop
  event, claims the ledger with a single `mv` (so edits appended during a slow curl carry to the
  next turn instead of being lost), dedupes with `sort -u`, and runs both existing scripts per
  surviving file. Harness is selected by a positional argument naming the harness or the
  `MD_HOOK_HARNESS` env var, defaulting to `claude` - the same convention as
  `filter-verbose-output.sh` - because harnesses disagree on both the path field
  (`.tool_response.filePath`/`.tool_input.file_path` vs `.file_path`) and the session key
  (`.session_id` vs `.conversation_id`); see
  `skills/cursor-projection/references/harness-matrix.md`'s Hooks section.
  Registering the recorder without the drain, or the drain without the recorder, silently disables
  the checks rather than failing loudly.
- Cost shape: bounded by turn, not by session. Both harnesses' stop events fire at the end of every
  agent loop, so a file edited across three turns is checked three times, once per turn, instead of
  once per file-edit call.
- Acceptance criteria:
  - The recorder ignores a non-`.md` path, a payload with no path, and a malformed payload, exiting
    0 and printing nothing in every case.
  - The recorder reads the field names of the harness it was given, and records nothing when handed
    a different harness's payload shape.
  - The drain checks each distinct file once per turn however many times it was edited, skips a
    path that does not exist, leaves no `.batch` file behind, and exits 0.
  - The `PostToolUse` recorder and the `Stop` drain are registered together; neither alone is a
    valid state, since the recorder without the drain writes a ledger nothing reads.

---

## Global Config Compaction Verification

- Decision recorded in `decisions/0006-global-config-compaction-verification.md`; facts in
  `reference/context-file-authoring.md` (Loading Mechanics > CLAUDE.md).
- Purpose: verify, rather than silently assume, that this repo's global `CLAUDE.md` content
  actually survives compaction. Anthropic's docs confirm only project-root CLAUDE.md reload, not
  this repo's actual user-scope file. Always-on, not an invoked skill.
- Shape: a canary phrase plus a documented preservation lever.
  - `## Canary` (a fixed phrase the assistant states after reading the file) and
    `## Compact Instructions` (the section name Anthropic's docs confirm shapes what `/compact`
    preserves), holding a Preserve/Discard checklist and a re-read-and-reconfirm rule that fires
    after any compaction event, not on a fixed turn-count or percentage schedule.
  - Rules for carrying this content into another harness's user-rules blob, including how the
    heading and its trigger wording are neutralized there, live in
    `skills/cursor-projection/references/user-rules-projection.md`.
- Known limitation (accepted, not solved): the canary can only prove the success case. If the
  global file failed to reload after a compaction/summarization event, the instruction telling the
  assistant to check would also be gone, so nothing prompts it to flag the gap - see
  `decisions/0006-global-config-compaction-verification.md`'s Consequences for the full accounting.
- Acceptance criteria:
  - `CLAUDE.md` states the canary phrase after being read, and re-reads/reconfirms after a
    compaction event rather than a numeric self-trigger the assistant cannot observe or invoke.
  - The Preserve/Discard checklist lives under the exact heading Anthropic's docs name
    (`## Compact Instructions`).

---

## Verbose Output Filtering

- Registration: `scripts/filter-verbose-output.sh` is wired in as a `settings.json` `PreToolUse`
  entry (matcher `Bash`). Logic is reviewed per
  `decisions/0003-hooks-and-scripts-authoring-policy.md`, and the entry is written under the
  user's explicit, in-the-moment direction, the same as the `Stop`/`PostToolUse` entries under
  "Deferred Markdown Checks".
- Purpose: rewrite a verbose test/build/lint command before it runs, so a passing run's full
  output never reaches the calling agent's context and only failure output does.
- Shape: one script shared by every harness (real logic in `scripts/<name>.sh`, thin
  registration wrappers per harness), since harnesses agree on where the command lives on stdin
  (`.tool_input.command`) and differ only in the response shape expected back. Shape is selected
  by a positional argument naming the harness or the `FILTER_VERBOSE_OUTPUT_SHAPE` env var,
  defaulting to `claude`. Covers `go test`, `go build`, `npm test`, `npm run build`, `pytest`,
  `mage`, and `golangci-lint`; leaves any other command, or
  one that already pipes, redirects, or is itself a pager/filter, unrewritten (`{}`, meaning
  no-op). Fails open on every error path (missing `jq`, unparsable input, empty command) by
  printing `{}` rather than blocking the tool call. Captures output and re-raises the original
  command's exit status rather than closing the pipeline with `exit ${PIPESTATUS[0]}`, since
  `PIPESTATUS` is a bash builtin that zsh - the shell the rewritten command actually runs under on
  this machine - does not define; the naive form would silently report a failing run as passing.
- Acceptance criteria:
  - A recognized command prefix is rewritten to surface only failure lines (or capped full output,
    for `golangci-lint`/`go build`, since their output is the finding list itself), while the
    rewritten command still exits with the original command's status.
  - An unrecognized command, or one that already pipes, redirects, or pages its own output, passes
    through unrewritten.
  - Every error path (missing `jq`, empty stdin, unparsable input) prints `{}` and exits 0 rather
    than blocking the tool call.

---

## Destructive Git Guard

- Registration: `scripts/destructive-git-guard.sh` is registered as a `settings.json`
  `PreToolUse` entry, matcher `Bash`, ordered before `filter-verbose-output.sh` in the same
  matcher block, at the user's explicit, in-the-moment direction, per
  `decisions/0003-hooks-and-scripts-authoring-policy.md`.
- Provenance: the underlying idea - a `PreToolUse` hook that blocks destructive git commands
  regardless of flag position - is a documented, established community pattern, not novel here.
  Prior art: `mattpocock/skills`' `misc/git-guardrails-claude-code` skill
  (already researched in `docs/plugin-research.md`'s mattpocock/skills section, which blocks the
  same command set) and a dedicated write-up
  (<https://www.aihero.dev/this-hook-stops-claude-code-running-dangerous-git-commands>) framing
  this exact pattern as the fix for `permissions.deny`'s flag-position blind spot.
  `docs/plugin-research.md` explicitly flags `git-guardrails-claude-code` itself as a real
  conflict with this repo - it programmatically writes its hook registration into `settings.json`,
  which `decisions/0003` requires be an explicit, in-the-moment human step - concluding "the
  underlying protection idea is fine, the auto-writing mechanism is not." This script follows that
  conclusion: the protection idea is reimplemented independently here, hand-written and reviewed,
  and registration goes through the explicit-direction step `decisions/0003` requires, rather than
  adopting the flagged skill as shipped.
- Purpose: `permissions.deny` in `settings.json` only matches on literal command-string prefix
  (confirmed against Claude Code's permissions docs), so a deny rule like
  `Bash(git push --force:*)` blocks `git push --force` but not `git push origin main --force` -
  the flag has moved out of prefix position. This hook closes that gap for the same command set
  already covered by the prefix-based deny rules, by tokenizing the command after the git
  subcommand instead of matching a fixed prefix.
- Shape: one `PreToolUse` hook, matcher `Bash`, reading `.tool_input.command` from stdin (same
  shape `filter-verbose-output.sh` uses). Strips quoted substrings (commit messages, etc.) before
  matching, so a flag-shaped token inside quoted text can't false-positive and a real flag placed
  after a quoted argument isn't missed either way. Denies, regardless of flag position:
  - The canonical five from the assistant's own Git Safety Protocol: `git push --force`/`-f`
    (including `--force-with-lease`); `git reset --hard`; `git checkout` targeting a bare `.`;
    `git restore` targeting a bare `.` (unless `--staged` is used without `--worktree`, which only
    unstages); `git clean -f`/`--force` (including combined short-flag clusters like `-fd`); and
    `git branch -D` (or `--delete` combined with `--force`/`-f`).
  - Beyond the canonical five, at the repository owner's request: `git commit
    --no-verify`/`-n`/`--no-gpg-sign`; `git rebase -i`/`--interactive`; `git push --delete` or a
    `:<branch>` delete refspec (removes a remote branch - `git push` has no documented `-d` short
    form for `--delete`, unlike `git branch -d/-D`, so only `--delete` and the colon-refspec form
    are matched); `git stash drop`/`clear` (permanently deletes stashed changes); `git
    filter-branch` (rewrites repository history); and `git reflog expire --all` combined with
    `--expire=now`/`--expire-unreachable=now` (destroys the recovery safety net other mistakes
    rely on).
  - Deliberately not guarded: a bare `git gc --prune=now` (without a preceding `git reflog expire
    --all --expire=now`) - gc respects reflog-referenced objects by default, so its risk is
    secondary to and smaller than the reflog-expire case that is guarded. `rm -rf` (named in the
    same safety protocol) is out of scope for this script entirely - it is not a git command, and
    unlike a force-push it has a high legitimate-use rate (`rm -rf node_modules`, `rm -rf dist`),
    so guarding it well needs to distinguish "risky target" from "routine cleanup" - a separate,
    harder design problem than flag-position matching, deserving its own script and its own
    explicit direction rather than folding into this one.
  - `permissions.deny` in `settings.json` covers a subset of the same commands as a second,
    independent layer for their fixed-position forms - the two mechanisms overlap by design
    rather than one superseding the other.
  Fails open (no output, exit 0) on missing `jq` or unparsable input, matching
  `filter-verbose-output.sh`'s precedent for the same tradeoff - a broken hook must never block a
  legitimate tool call, and `permissions.deny`'s fixed-position rules still apply independently
  either way.
- Known limitation (accepted): regex-based matching on the command string, not a real shell
  parser, so an adversarial rewrite (command substitution, an alias, a wrapper script) is not
  guaranteed to be caught. This raises the bar over prefix-only matching; it is not a sandbox.
- Acceptance criteria (all verified by a standalone test harness run against the script directly,
  not just read for plausibility - 30 cases, 0 false positives/negatives):
  - `git push origin main --force` (and the `-f` form) is denied, not just the prefix form
    `git push --force`.
  - `git clean -fd`/`-df` and `git branch --delete --force` are denied via their combined/split
    flag forms, not just the single-flag forms already in `permissions.deny`.
  - `git checkout -- .` and `git checkout HEAD -- .` are denied via the bare-`.` target, not just
    the literal `git checkout .` prefix form.
  - `git restore --staged .` (no `--worktree`) is allowed; `git restore --staged --worktree .` and
    bare `git restore .` are denied.
  - `git push origin --delete somebranch`, `git push --delete origin somebranch`, and `git push
    origin :somebranch` are all denied; `git push origin HEAD:refs/heads/main` (an explicit
    refspec, not a delete) is allowed.
  - `git stash drop`/`clear` and `git filter-branch` are denied regardless of trailing arguments;
    `git stash list`/`show` are allowed.
  - `git reflog expire --all --expire=now` is denied in either argument order; `git reflog expire
    --expire=now` alone (no `--all`) and `git reflog show` are allowed.
  - A commit message or stash message containing flag-shaped text (e.g. `git commit -m 'fix -n
    flag handling'`, `git stash push -m 'clear old test data'`) is not denied.
  - A non-destructive git command (`git push origin main`, `git checkout main`, `git checkout -b
    newbranch`, `git branch -d`, `git rebase main`, `git clean -n`, `git gc --prune=now`) and any
    non-`git` Bash command pass through with no output and exit 0.
  - Missing `jq` or an unparsable stdin payload exits 0 with no output rather than blocking the
    call.

---

## Pre-commit Drift Check

- Registration: `.git/hooks/pre-commit` execs `scripts/pre-commit-check.sh`, installed at the
  repository owner's explicit direction per
  `decisions/0003-hooks-and-scripts-authoring-policy.md`. It is registered as a git hook rather
  than an agent lifecycle hook. Registration is local-only and untracked by design, so drift stays
  possible on any machine at any time: `scripts/setup.sh --check` is what detects it, and
  `scripts/session-setup-check.sh` is what surfaces it at session start rather than at the commit
  that needed it (see the Machine Setup and Session Setup Check sections).
- Purpose: this repository has no automated gate at all outside a human remembering to run
  `scripts/sync.sh --check` by hand, so a stale projected copy or a broken `settings.json` can
  ship silently. A git `pre-commit` hook fires at the one point a human is already reviewing the
  diff (unlike an agent lifecycle hook, which fires on every future tool call before any review),
  so it is a materially different risk class from the hooks `decisions/0003` was written about,
  even though the same explicit-direction registration rule applies to it.
- Shape: a tracked, reviewed script (`scripts/pre-commit-check.sh`) holding the actual checks,
  plus a thin, untracked `.git/hooks/pre-commit` wrapper that execs it - the same
  logic/registration split `decisions/0003` uses elsewhere. Checks, in order: `settings.json`
  parses as valid JSON (via `jq empty`, skipped with a note if `jq` is absent, and skipped silently
  if there is no `settings.json` at all - an absent file has nothing to validate);
  `scripts/sync.sh --check` exits clean; `scripts/scrub-check.sh --staged` finds nothing in the
  staged content; and `scripts/scrub-check.sh --test` confirms the scrub patterns are still
  firing (for both, see this file's Public Repo Hygiene section). All four are read-only. A
  non-zero exit from any of them blocks the commit; git's own hook mechanism prints the script's
  stderr to the terminal.
- Missing-dependency policy, which differs by check on purpose. An absent `jq`, or an absent
  `scripts/sync.sh`, is a skip with a note: neither absence means content is going unexamined. An
  absent or non-executable `scripts/scrub-check.sh` fails the commit instead, because a missing
  leak detector is not "nothing to check", it is a commit heading for a public remote with no gate
  in front of it - the same fail-closed reasoning behind `scrub-check.sh` exiting 2 on a missing
  `scrub-patterns.local`.
- Gating another checkout (`--repo <dir>`, also `--repo=<dir>`): the script takes
  the repository containing `<dir>` as its target instead of its own, so a repository that wants
  this same gate can borrow the script rather than copy it - a copy drifts silently, since a scrub
  check that has stopped matching still exits 0. `scrub-check.sh` is always the one beside this
  script, never the target's, and `--test` is not given `--repo`: the fixtures belong to this
  repository, not to whichever checkout is being gated. Opting in and keeping it current is the
  borrower's to do; nothing here holds a list of who has, which is also why the flag is a stable
  interface - a borrower has no way to notice if it changes shape.
- What travels to a borrowed repository, on one principle: this gate may INSPECT one, never EXECUTE
  anything out of one. The leak checks travel, and so does the `settings.json` validation, since
  `jq` only reads the file. The projection check does not, because running it means executing
  whatever sits at the target's `scripts/sync.sh` - a common enough filename that a borrower could
  not anticipate it. A fork wanting its projections checked has its own copy and need not borrow.
- One hook shape everywhere: `scripts/setup.sh` writes
  `exec "$root/scripts/pre-commit-check.sh" --repo "$root"` over
  `root="$(git rev-parse --show-toplevel)"`, which is what a borrower installs by hand except for
  where the script lives. One line to keep right rather than two that can diverge. Because `--repo`
  is present in every registration, the script cannot read "borrowed" off the flag; it compares
  the target against its own main checkout instead, which is also what makes a symlinked
  invocation and a linked worktree resolve correctly where a path comparison would not.
- Worktrees, which this config's own Git conventions prescribe for branch work, are handled on
  two points. `scrub-check.sh` resolves `scrub-patterns.local` in the main checkout rather than
  beside the running one: those files are gitignored and so absent from a worktree, where
  resolving them beside the running checkout exits 2 on a missing pattern file for every branch
  commit. And `scripts/sync.sh --check` compares its projections against the checkout that
  installs them, always the main one, so the projection check runs only there; from a worktree it
  would report drift however clean the tree. The second is a narrow coverage trade: branch drift
  is still caught by the commit that lands it here, whereas a gate that always fails is one whose
  author starts passing `--no-verify` and loses the leak checks too.
- Known limits (accepted): local-only and not tracked by git, so it does not travel with a fresh
  clone or another machine without being reinstalled by hand - `scripts/setup.sh --check` and
  `scripts/session-setup-check.sh` cover detecting that, nothing prevents it; skips the JSON check
  with a note if `jq` is missing rather than failing closed, matching `scripts/sync.sh`'s own
  precedent for that same dependency.
- Known limits (open):
  - A borrower's hook is written by hand, deliberately: `scripts/setup.sh` installs into the
    repository it lives in and nothing else, because registering a hook in someone else's
    repository is the act `decisions/0003` reserves for that repository's owner.
  - Nothing detects that a borrower's registration has gone stale or been removed, for the same
    reason nothing detects it here: the registration is untracked, and no list of borrowers exists
    to check against.
  - `scripts/setup.sh --check` accepts any `pre-commit` hook mentioning `pre-commit-check.sh`, so
    one written without `--repo` reports `[ok]` with a note. That is correct: it still gates
    its own repository, and this script does not rewrite a hook it did not just write.
- Acceptance criteria:
  - A commit with invalid JSON in `settings.json` is blocked, with a message naming the file.
  - A commit made while `scripts/sync.sh --check` reports mechanical drift (a synced copy out of
    date) is blocked, with the drift output visible and a pointer to `scripts/sync.sh` to resync.
  - A commit staging a file that carries an absolute home path, the local username or hostname,
    a session UUID, an email address, or a credential-shaped token is blocked, with the offending
    `path:line` printed.
  - A commit made while a `scrub-test.local` fixture line matches no pattern is blocked, naming the
    fixture line, so a pattern that has silently stopped firing surfaces before it lets a real
    finding through.
  - A commit made with `scripts/scrub-check.sh` absent or not executable is blocked, not skipped.
  - A repository with no `settings.json` is not reported as carrying invalid JSON.
  - `--repo <dir>` and `--repo=<dir>` both gate the checkout containing `<dir>`: `--staged` reads
    that repository's index and findings print under its paths.
  - Under `--repo` aimed at another repository, an executable `scripts/sync.sh` there is NOT run,
    and its absence produces no note; aimed at this repository's main checkout - which every
    registered hook does - the projection check still fires.
  - `--repo` with no argument, an empty argument, a path that does not exist, or a path in no git
    checkout at all exits 2 rather than silently falling back to this repository.
  - A commit made from a linked worktree of this repository succeeds on a clean tree: the pattern
    and test files resolve to the main checkout rather than failing as absent, and the projection
    check is skipped rather than reporting drift that a worktree can never satisfy.
  - A clean, non-drifted working tree commits normally with no visible output from the hook.

---

## Public Repo Hygiene

- Decision recorded in `decisions/0009-public-repo-hygiene-as-an-always-on-rule.md`.
- Purpose: this repository targets a public remote, and nothing else prevents a local username, an
  absolute workspace path, an engagement-naming config directory, or a session UUID from being
  introduced by the next edit. Scope is the working tree only: commit history and commit identity
  are a separate remediation this behavior does not cover.
- Shape: an always-on rule plus a mechanical gate, in the three-pointer shape
  `decisions/0004-document-generation-as-always-on-rule.md` established - not a skill, which would
  load only when invoked and spend always-loaded description budget in every project for a rule
  that applies in one directory.
  - `reference/public-repo-hygiene.md` - the full policy: the categories, the neutral substitutes
    already in use (`~/.claude-work`, `/tmp` fixture paths, `$HOME` and
    `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, describe-rather-than-name), where a real value goes when
    one is genuinely needed, and what the check does and does not cover.
  - A `CLAUDE.md` Repository Maintenance bullet pointing at that file. That section is already
    gated on the working directory being a checkout of this repository, so the rule costs other
    projects one line of context.
  - `scripts/scrub-check.sh` - read-only, exits non-zero on findings, output grouped by category
    per file in `md-checks.sh`'s format. Unlike `md-checks.sh` it does not skip fenced code blocks:
    a real home directory inside an example command is as much of a leak as one in prose. The
    three files that must name the categories to document them - the policy, its decision record,
    and the script itself - carry no path exemption and need none: a placeholder and a regex source
    do not match the patterns.
  - Wired into `scripts/pre-commit-check.sh` as `scrub-check.sh --staged`, and as
    `scrub-check.sh --test` alongside it; the hook does not enumerate staged paths itself. Staged
    content, not the working tree, because scanning the latter while git commits the former is a
    hole rather than an approximation - a secret staged and then tidied out of the working tree
    passes a working-tree scan and commits. The flag sits on the hook rather
    than being the default because the hook is written once by `scripts/setup.sh` and never typed
    again, while the bare command - the full-tree audit - is what a human types ad hoc; defaulting
    to the wider scan also fails in the safe direction, since an audit can only over-report
    relative to a staged check. Staged content only, not the whole tree:
    a pre-existing finding elsewhere is a separate cleanup, and blocking every commit on it would
    only teach the author to pass `--no-verify`. Adds no new hook registration of its own; it
    inherits whatever registration `pre-commit-check.sh` has (see the Pre-commit Drift Check
    section).
  - `--test`, the self-test, runs on every commit rather than only when a pattern changes. Every
    pattern here is only as good as its regex syntax, and a typo that breaks
    a character class fails silently: grep simply stops matching, and every other check keeps
    exiting 0 because there is nothing left to trip over. `scrub-test.local` holds lines already
    known to match something, and `--test` asserts they still do, so a broken pattern surfaces the
    moment it breaks rather than the moment it lets something real through. Its pass/fail unit is a
    fixture line, not a file, so it is handled separately from every other mode. Its absence is a
    hard error (exit 2) for the same reason `scrub-patterns.local`'s is: a self-test that quietly
    no-ops when its fixtures go missing is worse than one that refuses to run.
  - `--repo <dir>` (also `--repo=<dir>`): scans the repository containing `<dir>`
    instead of the one the script lives in, so another checkout can borrow this detector rather
    than copy it. A copy drifts the first time a pattern is fixed in only one place, and drifts
    silently, because a scrub check that has stopped matching still exits 0. Everything that reads
    the tree is already relative to the repository root - `git ls-files`, `git cat-file`, the
    reported paths - so redirecting that one variable is the whole of it. `git rev-parse
    --show-toplevel` resolves the argument, which makes any path inside the target work and turns
    both failure shapes (a path that does not exist, a path in no checkout) into exit 2 rather than
    a pass - outside a repository `git ls-files` returns nothing, and an empty file list reads as a
    perfectly clean tree. It combines with the default, `--all`, `--staged`, and explicit paths;
    under `--test` it changes nothing, since the fixtures are this repository's either way. Whose
    repositories borrow it, and whether they still do, is theirs to track: nothing here holds a
    list. The flag is nonetheless a stable interface - a borrower holds no copy of this code and
    has no way to notice if it changes shape - so changing it is a breaking change.
- Pattern sources, of which only the first is committed - a tracked list of client and employer
  names would be the leak the check exists to prevent:
  - Structural patterns, matching shapes not values: absolute home paths, projects-path spellings,
    UUIDs, credential prefixes, email addresses. Angle-bracket placeholders and the reserved
    example domains are exempt by construction.
  - Literals derived at run time and never written down: the current username, the short hostname,
    and the git-configured email address and its domain. A derived value generic enough to appear
    as ordinary prose (`admin`, `test`, `localhost`) is dropped rather than searched for.
  - `scrub-patterns.local` - at the root of THIS script's MAIN checkout, gitignored, one extended
    regex per line, holding project- and client-specific tokens. Read from there whichever checkout
    is being scanned, `--repo` included, as is `scrub-test.local`: both describe a person and a
    machine - the client names their owner knows - rather than any one repository, and a borrowed
    repository keeping its own copy would be the same list twice, with only one of them updated the
    next time a name enters that vocabulary. The main checkout specifically, not whichever
    checkout is running the script: being gitignored, these files do not exist in a linked
    worktree, where resolving them beside the running checkout would make every commit from one
    fail on their absence. The same
    tracked-logic/untracked-configuration split `scripts/replicate.sh` uses for its target
    directories. Located at the root rather than beside the script because the root `.gitignore`
    opens with `/*`: every unwhitelisted root entry is ignored structurally, where anything under
    the whitelisted `scripts/` stays tracked unless an explicit ignore line survives. Its absence
    is a hard error (exit 2), not a silent skip, so an unconfigured machine fails closed instead of
    reporting a clean tree it cannot vouch for; an empty or comments-only file is a valid "no
    project tokens" answer. `scrub-check.sh` never creates it - it writes nothing at all, since
    materializing files from inside a pre-commit hook is a bad surprise - so `scripts/setup.sh`
    owns creation. A line that does not compile as an
    extended regex is skipped with a stderr warning rather than folded in silently - `--scrub`
    already rejects one at collection time, but this file is meant to be hand-edited too, which
    bypasses that check, and a script that otherwise fails closed on missing coverage should not
    then go quiet about a narrower version of the same gap.
- Known limits (accepted): inherits `pre-commit-check.sh`'s local-only registration, so a fresh
  clone is unprotected until the hook is reinstalled - `scripts/setup.sh --check` reports that
  state, but nothing runs it automatically; cannot catch a client name it has no pattern for, or a
  paraphrase that identifies someone without naming them; and `scrub-patterns.local` is
  per-machine, so a second machine starts with structural coverage only until its owner fills the
  file in.
- Acceptance criteria:
  - `scripts/scrub-check.sh` with no arguments audits the whole tracked tree, is silent on a clean
    tree, and exits 0; `--all` produces byte-identical output.
  - `--staged`, `--test`, and explicit paths are mutually exclusive; supplying more than one is
    rejected with exit 2 rather than silently honouring one of them.
  - Under `--staged`, a file staged with a finding and then cleaned in the working tree still blocks
    the commit; a clean staged version is not blocked by an unrelated dirty working-tree edit.
  - Findings from staged content are reported under the real repository path, not a temp path, and
    the extracted blobs are removed on exit.
  - A file carrying an absolute home path, a projects-path spelling, a UUID, an email address, a
    credential-shaped token, the local username, or the hostname is reported with the correct
    `path:line` and category, and the script exits 1.
  - The deliberate placeholders already in the tree (`/Users/example/...`,
    `fixture@example.invalid`, angle-bracket forms) produce no findings.
  - The policy file, its decision record, and `scrub-check.sh` itself produce no findings despite
    naming the categories, with no path exemption in play.
  - `git check-ignore` confirms `scrub-patterns.local` is untracked with no rule of its own.
  - `scrub-check.sh` exits 2 with an actionable message when `scrub-patterns.local` is absent, and
    does not create it.
  - Two distinct findings in the same category on the same line (e.g. two different email
    addresses) are both reported, not collapsed to one.
  - A line in `scrub-patterns.local` that does not compile as an extended regex produces a stderr
    warning naming it and is excluded from matching; the remaining valid patterns still apply.
  - `--test` exits 0 when every active fixture line in `scrub-test.local` triggers at least one
    finding, and exits 1 naming each fixture line that matched nothing.
  - `--test` exits 2 with an actionable message when `scrub-test.local` is absent, and does not
    create it; a fixtures file with no active lines reports that there is nothing to verify and
    exits 0 rather than claiming a pass.
  - `--help` prints the usage block and exits 0 on a machine with no `scrub-patterns.local`, before
    the missing-file error can fire - that is the machine someone runs it on to find out how to set
    it up.
  - `--repo <dir>` and `--repo=<dir>` scan the checkout containing `<dir>`, report findings under
    that repository's paths, and still read `scrub-patterns.local` and `scrub-test.local` from this
    repository's main checkout.
  - Run against a linked worktree of this repository, the pattern and test files resolve to the
    main checkout rather than being reported absent.
  - `--repo` with a missing or empty argument, a nonexistent path, or a path in no git checkout
    exits 2, never 0.

---

## Machine Setup

- Purpose: a clone cannot produce the state this repository expects - hook registrations are
  untracked by design, and `scrub-patterns.local` holds values that must never be committed. README
  prose conveys that state unverifiably: nothing detects that a registration has gone missing, and
  better install instructions would not catch it. The script exists mainly so `--check` can answer
  "is this machine actually set up?" with evidence.
- Shape: one tracked, reviewed shell script - deliberately not a skill. The work is deterministic
  file writes and a `chmod`, which `scripts/md-checks.sh`'s header already argues belongs in a
  script rather than a model; a setup skill would also spend always-loaded description budget in
  every session, in every project, to be used about twice per machine. Setup additionally runs on a
  fresh clone, possibly before the agent config works at all, and bootstrapping the config with the
  agent it configures is circular.
  - Idempotent: every action is skipped when already satisfied; a completed setup re-runs clean and
    exits 0.
  - `--check` is read-only and exits 1 when incomplete, so it can be wired into any future
    consistency surface without risk.
  - `--scrub` re-opens pattern collection on an existing file and appends, never truncates.
  - Never overwrites a hook it did not write: an unrecognized `pre-commit` is preserved and
    reported, and the run is marked incomplete rather than claiming a gate that is not there. A
    recognized one written without the `--repo` hook shape (see the Pre-commit Drift Check
    section) is left alone too, with a note rather than a failure: it still gates its own repository
    correctly, so re-registering it is the owner's call and a hand edit away.
  - Installs into the repository it lives in and nothing else. A repository borrowing the gate
    writes its own hook by hand, deliberately: registering a hook in someone else's repository is
    precisely the act `decisions/0003` reserves for that repository's owner.
  - Installs the replication hooks too, prompting for replication targets. Zero targets is a valid
    answer and still writes every hook: that keeps "no hook" meaning "setup was never run" rather
    than conflating it with "nothing to replicate", which `--check` could not otherwise distinguish.
    Nothing may call `replicate.sh` with no arguments, which prints its usage message after every
    commit and every pull; the generated target list guards on its own emptiness instead.
  - Three hooks, not one: replication must follow content onto a machine, not only off the machine
    that authored it. A commit made on machine A reaches machine B by pull, and with `post-commit`
    as the only trigger B's other profiles stay stale until B happens to commit something itself.
    Git has no post-pull hook, so `git pull` is covered by its two integration hooks - `post-merge`
    for the merge it performs (fast-forwards included) and `post-rewrite` for `--rebase`.
    `post-rewrite` acts only on its `rebase` argument: the `amend` case already fires `post-commit`.
    `post-commit` conversely skips while a rebase is in progress (a rebase replays each commit
    through it), so a `--rebase` pull replicates once, at the end, rather than once per replayed
    commit plus once more - and never from a half-rebased tree.
  - The targets live in one generated `.git/hooks/replicate-targets.sh` that all three hooks exec,
    rather than being hardcoded in each: three copies of a per-machine list is three places to edit
    and two places to forget. This keeps the same tracked-logic/untracked-configuration split the
    single hook had. A `post-commit` carrying its targets hardcoded instead is migrated - its
    target list is recovered and rewritten into the shared file - so a machine that already
    answered the targets question is not asked again, and cannot silently lose replication when
    the script runs non-interactively.
  - Expands a leading `~` in a target path by hand, since `read` does not - an unexpanded `~` would
    otherwise create a directory literally named `~` on the first replication.
  - Refuses to run when `core.hooksPath` is set or from a linked worktree, both of which would make
    an install here silently ineffective.
  - Ends by running `scrub-check.sh`, proving the gate works rather than asserting it.
- Registration policy: this script performs hook registration, which
  `decisions/0003-hooks-and-scripts-authoring-policy.md` reserves to the repository owner's
  explicit, in-the-moment act. A human typing `scripts/setup.sh` is that act; an agent choosing to
  run it is exactly what the policy forbids, and the script's header says so. `--check` is
  read-only and carries no such restriction.
- Known limits (accepted): `--check` is invoked automatically only at session start, and only for
  sessions whose cwd is inside this repository (see the Session Setup Check section) - drift on a
  machine nobody opens a session on is still found only when someone looks. `sync.sh --check` was
  rejected as the host because it is itself run by the pre-commit hook, and so is unavailable on
  exactly the machines where that hook is missing. Pattern collection needs a terminal; with piped
  stdin the script installs the hooks, reports the pattern file as outstanding, and exits 1.
- Acceptance criteria:
  - `--check` on an unconfigured clone reports each missing piece - pre-commit, the three
    replication hooks, the shared target list, and the pattern file - creates nothing, and exits 1.
  - A target list installed with no targets is reported as present-but-target-less rather than
    missing, and an ordinary commit through the hooks produces no output.
  - With targets configured, each of a commit, a merge-mode `git pull`, and a `git pull --rebase`
    replaying several local commits invokes `replicate.sh` exactly once; `git commit --amend`
    likewise invokes it once, not twice.
  - A run against a `post-commit` that hardcodes its targets recovers them into
    `replicate-targets.sh` and reports the recovery, prompting for nothing.
  - A plain run installs the pre-commit hook and, interactively, creates `scrub-patterns.local`.
  - A second run reports everything `[ok]`, changes no file, and exits 0.
  - `--check --scrub` collects nothing and leaves the pattern file byte-identical.
  - A malformed regex offered during collection is rejected with a message and not written.
  - An existing `pre-commit` that does not call `pre-commit-check.sh` survives the run untouched,
    and the run exits 1.

---

## Session Setup Check

- Registration: `scripts/session-setup-check.sh` is registered twice as a `SessionStart` hook in
  `settings.json` - `matcher: "startup|resume"` bare, and `matcher: "clear|compact"` with
  `--context-only` - each at the repository owner's explicit, in-the-moment direction per
  `decisions/0003-hooks-and-scripts-authoring-policy.md`. Each matcher is its own explicit act: a
  prior registration authorizes nothing, which is what that decision means by "on the strength of
  a prior registration".
- Purpose: make two invisible conditions visible without anyone having to think to look -
  incomplete machine setup, and an overdue health check. Both are things a section elsewhere in this
  file can answer when asked, and neither is ever asked; this fires once per session start so a
  missing pre-commit registration surfaces before the commit that needed it rather than after a
  push, and so a manual weekly-to-monthly check does not quietly become an annual one.
- Two conditions, one message, evaluated independently: either can fire alone, and when both fire
  their sentences compose into a single `systemMessage` and a single `additionalContext`, because
  `SessionStart` affords one of each.
  - Setup: `scripts/setup.sh --check` exiting non-zero, reduced to its `[MISSING]`/`[warn]` lines.
  - Health check, which fires on either of two sub-conditions read from `.health-check-stamp`:
    - **Overdue**: more than `HEALTH_STALE_DAYS` (7) since `date=`, or the marker absent entirely
      ("has never been run on this machine"). The threshold stretches to `HEALTH_IDLE_DAYS` (30)
      only when all three hold: `commit=` still resolves and equals HEAD, `git status --porcelain`
      is empty, and `findings=` is 0. Any unknown or unreachable commit means idleness cannot be
      claimed, so it is not claimed. This is a longer leash, never an off switch - see the Config
      Health Check section for why HEAD does not determine the findings.
    - **Unaddressed findings**: `findings=` is non-zero and the run is at least
      `HEALTH_FINDINGS_GRACE_DAYS` (3) days old. Independent of age otherwise, and it defeats the
      idle extension by construction: if the last run found something, "nothing has changed since"
      argues the findings are still there, not that they are gone. The grace period exists because
      a standing nag with no way to be mid-fix is what teaches a reader to skim past this hook.
    - Day arithmetic tries GNU `date -d` then BSD `date -j -f`; a machine that does neither gets no
      nudge rather than a wrong one. An unreadable or malformed marker degrades to silence for the
      same reason - the marker is a convenience and never a gate, and a nag nobody can clear is
      worse than none.
  - The staleness half tells Claude explicitly *not* to run `scripts/health-check.sh` or invoke the
    health-check skill unprompted, mirroring how the setup half leaves running `scripts/setup.sh` to
    the owner. The reasons differ - registration is the owner's act; the health check is simply too
    slow and too noisy to run uninvited - but the shape of the instruction is the same.
- Shape: a `SessionStart` hook evaluating the two conditions above and translating either into a
  warning. Silent on a healthy machine, matching `md-checks.sh`'s convention - a hook that speaks on
  every healthy start teaches its reader to ignore it. Measured at 0.03 s.
  - Output contract (`code.claude.com/docs/en/hooks`, confirmed 2026-08-21): for `SessionStart`,
    plain stdout is added to **Claude's context** and is **not** shown to the user, so a bare `echo`
    would be invisible to the person who has to act. Reaching the user requires a **top-level**
    `systemMessage` field, which renders in the transcript; `additionalContext` is the field Claude
    reads and it lives **inside** `hookSpecificOutput`. The two sit at different levels, and a
    `systemMessage` nested inside `hookSpecificOutput` is dropped silently rather than rejected,
    which produces a session in which Claude has been warned and the user has not. This hook emits
    both - the user learns the gate is off, and Claude is told not to imply a commit was checked
    when it may not have been, and to leave running `scripts/setup.sh` to the owner.
  - `SessionStart` cannot block and its exit code is ignored for control purposes, so the hook
    always exits 0 - an unrecognized argument is reported to stderr and ignored rather than treated
    as fatal, since this must never be why a session fails to start. It is advisory; the pre-commit
    hook remains the actual gate.
  - Two registrations, one script, with the mode carried as a command-line argument:
    - `startup|resume` runs it bare, for the full warning. A resume can be days later on a machine
      whose clone was replaced or whose `.git/hooks` were wiped, so it is a real session start from
      the reader's point of view.
    - `clear|compact` runs it with `--context-only`, which emits `additionalContext` and omits
      `systemMessage`. Both events destroy Claude's copy of the warning, which is how a session ends
      up reporting a commit as checked when the gate never ran - the same survive-compaction concern
      behind `decisions/0006-global-config-compaction-verification.md` and `CLAUDE.md`'s canary. The
      user, though, saw the message minutes earlier in the same terminal, and re-showing it is the
      nagging that teaches people to ignore hooks.
    - `fork` is deliberately unregistered: a fork inherits context, so the note is already present.
  - The mode is an argument rather than something read from the payload because Anthropic's
    documented `SessionStart` input fields (`session_id`, `transcript_path`, `cwd`,
    `permission_mode`, `hook_event_name`, `model`) include none carrying which of the five start
    types occurred. Branching on a guessed field name would be a silent single point of failure; the
    matcher already knows, so the registration says so out loud. Matcher alternation with `|` is
    documented and confirmed.
  - Gated on the session's cwd being inside this repository, parsed from the payload (`jq` when
    available, a `sed` fallback otherwise) and resolved with `pwd -P` on both sides so a symlinked
    or `/private`-prefixed path still matches. The hook is registered at user scope and therefore
    fires in every project on the machine; a warning about `~/.claude`'s git hooks is noise in an
    unrelated codebase, and this repository cannot be committed to from outside it anyway.
  - Exits silently in a replicated `CLAUDE_CONFIG_DIR` profile, which receives a copy of `scripts/`
    but has no repository to check.
- Why not the status line: setup state changes perhaps twice a year, where the status line
  re-renders continuously - checking there would need a caching layer to stay off a hot path, and
  would have a fraction of one shared line to explain itself in. `SessionStart` runs once, can
  carry a full actionable sentence, and is the only one of the two whose output can reach Claude as
  well as the user.
- Known limits (accepted): the user-visible warning still scrolls away, unlike a status-line
  indicator; a session started outside the repository is never warned, even though the drift still
  exists; the nudge knows how many findings the last run produced but not whether any were since
  fixed, so the only way to clear a findings nudge is to run the check again; and on a `clear` or
  `compact` only Claude is re-informed, so a user who missed the original message and then
  compacts never sees it in that session.
- Acceptance criteria:
  - On a machine with incomplete setup, a session started in this repository emits valid JSON whose
    **top-level** `systemMessage` names what is missing and points at `scripts/setup.sh`, and the
    message is visible in the transcript - not merely well-formed.
  - The same invocation with `--context-only` emits valid JSON carrying `additionalContext` and no
    `systemMessage` key at all.
  - An unrecognized argument is reported on stderr, does not suppress the output, and exits 0.
  - The same machine emits nothing for a session started outside the repository.
  - A fully set-up repository whose health check ran within the window emits nothing at all.
  - A stamp dated more than 7 days ago produces a nudge naming the day count and the date; one
    dated exactly 7 days ago does not; an absent stamp produces the never-run wording; a malformed
    one produces nothing.
  - A stamp 12 days old whose commit equals HEAD, with a clean tree and `findings=0`, is silent;
    the same stamp at 40 days is not; the same stamp with `findings=5` is not; the same stamp with
    any dirty working tree is not.
  - A stamp 3 days old with `findings=5` names the count; the same stamp 2 days old does not.
  - Counts are pluralized correctly at 1 and at more than 1.
  - With setup incomplete and the check overdue, one message carries both sentences.
  - A directory carrying a copy of `scripts/` but no `.git` emits nothing.
  - The hook exits 0 in every case above.

---

## Status Line

- Registration: `settings.json`'s `statusLine` key points at
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/scripts/statusline.sh`, matching this script's own internal
  use of the same fallback for locating the credentials file inside `get_usage_token()`.
  `.claude.json` is a separate lookup, also scoped by `CLAUDE_CONFIG_DIR` but against a different
  fallback base -
  `${CLAUDE_CONFIG_DIR:-$HOME}`, since an unscoped `.claude.json` sits at `$HOME` as a sibling of
  the config directory rather than inside it; see the script's header comment on `organization`
  for the side-by-side verification behind that. Script logic is model-generated and reviewed per
  `decisions/0003-hooks-and-scripts-authoring-policy.md`, and the human wiring step that policy
  calls for is done.
- Purpose: make context growth and session spend visible at a glance in one compact line, so a
  long session gets noticed before it becomes an expensive one.
- Shape: a Claude Code `statusLine` command script. Reads only the fields documented at Claude
  Code's statusline docs (verified 2026-07-30 against the "Available data" table and the "Full
  JSON schema" accordion): `.model.display_name`, `.effort.level`,
  `.context_window.used_percentage`, and `.cost.total_cost_usd`; never opens `transcript_path`.
  Omits a segment entirely when its field is absent (for example `effort.level` on a model that
  does not support it) rather than faking or zeroing a value, except that a genuinely-zero cost is
  still shown as `$0.00`, since Claude Code reports that as a real value, not an "unavailable"
  placeholder. Marks context usage with a trailing "!" once `used_percentage` reaches 80, as a
  visible warning. Fails open on every path (missing `jq`, unparsable stdin) by printing a minimal
  `[claude]` line rather than leaving the status line blank or exiting non-zero.
- Acceptance criteria:
  - Renders model name, effort (when present), context percentage (with the ">=80%" marker when
    applicable), and cost, omitting any field absent from the input rather than substituting a
    fake value.
  - Never reads `transcript_path` or any file besides its stdin payload.
  - On missing `jq` or unparsable input, prints `[claude]` and exits 0 rather than leaving the
    status line blank.
  - A genuinely-zero cost is shown as `$0.00`, not omitted as though absent.

---

## Config Health Check

- Purpose: give the repository a periodic self-evaluation that the commit gate structurally cannot
  provide. `scripts/pre-commit-check.sh` sees only the staged bytes of one commit, so drift that no
  single commit introduces - a skill with no spec section, a spec section naming an artifact that
  does not exist, a script the README forgot, a description grown past its budget, an unbumped
  `updated:` date - accumulates unobserved.
- Invocation model: manual, on demand or on a weekly-to-monthly cadence, or before a publication
  pass. Deliberately NOT a hook of any kind and not part of the commit gate. Because it never runs
  on a hot path it is thorough rather than fast: it walks every tracked file, not the staged set.
  `--quick` trades that away, skipping the four delegated scripts and the history scan; the full
  run is the default.
- Shape: two halves over one output format.
  - `scripts/health-check.sh` - the mechanical half. Read-only; registers nothing; never edits.
    Self-implemented checks: JSON validity of every tracked `*.json` plus `settings.local.json` and
    `scripts/mcp-servers.json`, both of which are untracked-or-absent by design; every command
    `settings.json` points at existing, being executable, and being tracked, since a renamed hook
    script fails silently at runtime and an untracked one works on one machine only; `created:`/
    `updated:` frontmatter presence, well-formedness, ordering, and absence of future dates on
    tracked Markdown; skill description budgets against the 1,536-char per-description cap and the
    8,000-char pool fallback, plus an advisory per-subagent description length and total, which
    carry no cap because none is documented for subagents; spec coverage in both directions between
    `skills/` and `agents/` and their sections in `specs/skills.md`, `specs/behaviors.md`, and
    `specs/agents.md`; README coverage for top-level scripts, skills, and subagents, with a reverse
    direction (the README naming something that does not exist) for scripts only; tracked mode
    `100755` and on-disk executability for every `*.sh`; `bash -n` and a shebang on every tracked
    `*.sh`, with `shellcheck` advisory when installed; a skill's or subagent's frontmatter `name:`
    matching its own path, and a non-empty `description:`; `decisions/` as a gapless series with no
    duplicate number; backticked repo-internal path references in prose resolving, which
    `md-checks.sh`'s link check structurally cannot see because this repository cites paths as
    inline code spans rather than as Markdown links; an `updated:`-not-bumped check over the working
    tree; and four advisories - a skill with no `evals/evals.json`, files over the line
    conventions in `reference/context-file-authoring.md` (the always-loaded root file in two
    tiers, one for the roughly 200-line target and a sharper one for the hard ceiling above it,
    since the convention treats a considered overrun of the target differently from breaching the
    ceiling, plus each on-demand `reference/*.md` against the 400-line convention), a
    reference/example/decision nothing else cites, and `updated:` trailing a file's last commit by
    more than a day. Delegated rather than reimplemented: `scripts/md-checks.sh`,
    `scripts/scrub-check.sh` (full-tree, no arguments),
    `scripts/sync.sh --check`, and `scripts/setup.sh --check`.
  - `skills/health-check/SKILL.md` - the judgment half, pinned to the Opus tier at high effort.
    Consumes the script's output rather than re-deriving it, then assesses coherence between
    documents, whether each artifact still earns its place, staleness, specs against actual
    artifact behavior, and gaps. Opus is affordable here precisely because the cadence is long.
- Output contract: findings print as `<path>:<line> - <description>`, grouped under a
  `== <category> ==` header; a line number of 0 means the finding is about the file as a whole.
  Advisory findings are grouped under `== <category> (advisory) ==` and never affect the exit code.
  Exit 0 means no failures, 1 means at least one check failed, 2 means a usage or environment
  error. Delegated output is capped per category with the true total named on a trailing line: a
  single over-broad pattern in `scrub-patterns.local` can emit 868 lines, against which every
  self-implemented finding would be invisible.
- Advisory rather than failing, deliberately: machine-local setup state (`setup.sh --check`
  non-zero, and `scrub-check.sh` exiting 2 for a missing `scrub-patterns.local`) is a per-machine
  condition rather than a defect in the tree, and a fresh clone is legitimately incomplete until
  its owner runs `setup.sh`. Historical `updated:` drift is advisory for the same reason a commit
  landing the day after its edit is ordinary rather than wrong; the working-tree variant of that
  check is the one that fails. Eval coverage, context budget, and orphaned artifacts are advisory
  because each measures against a "roughly N" convention or reports an absence whose meaning is a
  judgment call - zero inbound references says nothing about whether a file still earns its place,
  which is exactly the skill's half.
- Scoped deliberately, because an over-broad check is worse than none. The path-reference check is
  applied only to files that describe this repository: `docs/` is a research library citing other
  projects' paths, `evals/runs/` holds fixture transcripts, `decisions/` records are immutable and
  describe the tree as it stood when accepted, and fenced code blocks hold template text. Without
  those exclusions the check would emit 21 lines of which 5 are real; with them it emits the 5. The
  one-day tolerance on `updated-history` has the same justification: untolerated it would produce
  36 advisory lines on a healthy tree, and an advisory nobody reads is worse than none.
- Cadence enforcement: a full run records three fields in `.health-check-stamp` at the repository
  root, gitignored and machine-local - `date=` when it ran, `commit=` the HEAD it ran against, and
  `findings=` how many non-advisory finding lines it produced - and
  `scripts/session-setup-check.sh` reads them at session start (see the Session Setup Check
  section). This is the answer to
  "how does a manual check on a long cadence stay honest without becoming a hook": the check itself
  stays off every hot path, and only a one-`stat` date comparison rides the session-start path that
  already exists. Measured, the full run is 16.2 s and `--quick` 5.6 s, against that
  hook's own 0.02 s, so running the check there is not viable on time alone - and the stronger
  objection is that `SessionStart` output enters Claude's context, where a per-session dose of
  repository-maintenance findings would prime unrelated work.
  - `--quick` deliberately does not stamp. It skips the four delegated scripts and both history
    scans, which is most of what distinguishes this from a linter; letting a five-second run buy a
    week of silence would hollow out the cadence it exists to keep.
  - Stamped regardless of findings, and regardless of exit code: the question "when did you last
    look" is answered by `date=`, and "was it clean when you did" by `findings=`, so the nudge can
    ask both rather than conflating them. A run that reports findings and is then ignored would
    otherwise reset the clock exactly as a clean one does; recording the count is what closes that.
  - `commit=` exists so the nudge can say how far the tree has moved since, and so an idle tree can
    earn a longer threshold. It deliberately does NOT earn silence: HEAD does not determine what
    this script finds. Eight of its twenty check functions read state that is in no commit -
    `check_updated_bump` (the working-tree diff), `check_script_modes` and
    `check_settings_references` (on-disk permission bits), `check_json_validity`
    (`settings.local.json`, `scripts/mcp-servers.json`, both absent or untracked by design),
    `check_frontmatter` (compares against today's date), and the delegated scripts reading
    `scrub-patterns.local` (gitignored), machine-level state outside the repository entirely, and
    `.git/hooks/` (untracked). `scrub-check.sh` is the pointed case: adding a client pattern makes
    a file the last run passed fail with no commit anywhere, and it is the check guarding a public
    remote.
  - Never fatal. A read-only checkout that cannot write the marker still completes the run and says
    on stderr that the nudge will not update.
- Non-goals: it is not a commit gate, it never edits or registers anything (`.health-check-stamp` is
  the one file it writes, and it is untracked by design), it does not reimplement a check that
  already exists elsewhere in `scripts/`, and the nudge never runs the check it nags about.
- Acceptance criteria:
  - `scripts/health-check.sh` exits 0 on a clean tree, 1 when any non-advisory check fails, and 2
    on a usage or environment error.
  - Each self-implemented check has been observed to fire against a deliberately introduced defect,
    not merely asserted to work, by injecting one defect at a time into a scratch clone.
  - No check produces more noise than signal on a healthy tree. A category whose findings are
    routinely dismissed is retuned or removed, not left to train the reader to skim past it.
  - The script registers itself nowhere and modifies no file.
  - A machine with no `scrub-patterns.local` and no installed hooks still gets a useful run, with
    both conditions reported as advisory.
  - The skill's report distinguishes defects to fix from checks that fired but are correct as they
    stand.
  - A full run leaves `.health-check-stamp` holding today's date, the current HEAD, and the run's
    finding count; a `--quick` run leaves it untouched; neither run stages or tracks it.
- Testing gate partially closed: an eval set covering this skill's triggers and criteria was
  authored 2026-09-01 at `skills/health-check/evals/evals.json`, but no run backs it yet; see
  `evals/README.md` and the health-check section of `specs/skills.md`.
