---
created: 2026-07-31
updated: 2026-08-31
---

# Plugin Research

Research on the plugins and skill repos from this config's candidate list, recorded here as a
point-in-time evaluation of what was on it. Done to answer, for each: does it overlap with what
claudeconf already has, does it complement the current skills/agents (including the
named-but-unbuilt backlog items in `specs/backlog.md`), what real value does it provide day to
day, and does it help or hurt cost-efficient agentic tool use.

Method: each of the 8 named repos was researched independently (README, repo structure,
install method, star/commit/license signals). The three listicle/comparison articles linked
alongside that list were also surveyed to see whether they named anything not already on it; that
appears as a separate, more shallowly-researched appendix at the end. The Reddit thread
(`r/AskVibecoders`) could not be fetched - it is blocked for automated retrieval - so it
contributed nothing here.

The research itself is a 2026-07-31 snapshot; every claim below is scoped to that date and has
not been re-verified against the current state of any researched repo.

Star and fork counts below are single point-in-time API pulls, not independently audited -
treat them as a rough popularity signal only. Several repos here carry very large counts
relative to their age (mattpocock/skills, superpowers, caveman, and rtk in particular); that
caveat applies equally to all of them, not just the one it's called out on explicitly below.

Two of the researched repos (`caveman`, `rtk`) returned content that an automated filter
flagged as resembling embedded instructions rather than plain documentation, specifically
around the phrase patterns used to describe their `settings.json`-patching installers. Nothing
from either repo was executed. This is called out again in each repo's own section below,
alongside the same underlying fact as a normal red flag (both installers really do patch
`settings.json` automatically), but is worth knowing as a general caution about treating
fetched repo content as executable instructions.

Overall ranking (strongest recommendation first): `mattpocock/skills` is the one repo worth
adopting from directly (cherry-pick `grill-me`/`grilling` into the plan/execute workflow);
`compound-engineering-plugin`, `superpowers`, and `rtk` are worth reading and mining for design
ideas or infrastructure but not installing as-is; `claude-code-production-grade-plugin`,
`caveman`, `i-have-adhd`, and `openskills` are not recommended.

---

## 1. mattpocock/skills (recommended - cherry-pick, do not adopt wholesale)

- Homepage/blog: <https://tosea.ai/blog/matt-pocock-skills-claude-code-guide>,
  <https://www.aihero.dev/my-grill-me-skill-has-gone-viral>
- Repo: <https://github.com/mattpocock/skills>
- Specific file of interest: `skills/productivity/grill-me/SKILL.md` (hands off to `grilling`)

**What it provides.** A skills library organized as `engineering/` (ask-matt, code-review,
codebase-design, diagnosing-bugs, domain-modeling, grill-with-docs, implement,
improve-codebase-architecture, prototype, research, resolving-merge-conflicts, tdd, to-spec,
to-tickets, triage, wayfinder), `productivity/` (grill-me, grilling, handoff, teach,
writing-great-skills), and `misc/` (git-guardrails-claude-code, migrate-to-shoehorn,
scaffold-exercises, setup-pre-commit), plus personal-use skills. `grilling` is the mechanism
behind `grill-me`: it asks one question at a time, proposes a recommended answer for each,
researches factual questions itself instead of asking about them, defers strategic calls to the
user, and works branch-by-branch through a decision tree until there is shared understanding
before any implementation starts. Both blog posts describe it going viral specifically for that
simplicity, not sophistication - a formalized version of rubber-ducking that works on
non-coding decisions too.

**Maturity.** 197,757 stars, 17,021 forks, MIT license, created 2026-02-03, pushed as recently as
2026-07-31 - actively maintained with a large community (see the star-count caveat above).
Installable two ways: the managed Claude Code plugin marketplace, via the terminal command
`claude plugins install mattpocock-skills` (read-only, auto-updating - note this is a different
install surface than the in-session `/plugin install` command used by most other repos in this
document; confirm the exact current syntax before use), or `npx skills@latest add
mattpocock/skills`, which copies editable files into a repo. Only the second path fits
claudeconf's regenerate-from-spec model; the managed-plugin path would sit outside `specs/`
entirely and can't be hand-edited to fit house conventions.

**Overlap.** `grill-me`/`grilling` does not duplicate `write-plan`/`execute-plan` - see below.
`teach` overlaps the unbuilt Learning/Teaching/KB backlog item. `research` overlaps the unbuilt
Research fan-out backlog item. `code-review` overlaps the unbuilt Code Review fan-out backlog
item. `handoff` overlaps `write-plan`'s self-contained-unit philosophy but is scoped narrower
(compacts a conversation to a temp file for a fresh agent). `writing-great-skills` overlaps
`skill-author`.

**Complement.** This is the strongest fit found: `write-plan` currently produces a plan with no
adversarial-critique step before it's finalized - nothing forces assumption-surfacing or
edge-case interrogation before the plan goes to `execute-plan`. A grilling-style pass inserted
between drafting and finalizing would harden plans before they become expensive to execute
wrong. Separately, `teach`, `research`, and `code-review` are working reference
implementations for all three named-but-unbuilt backlog items - worth reading as design
material even where not adopted verbatim.

**Real-world value.** High for the grilling pattern specifically - cheap insurance against
building the wrong thing, mirrors what a careful senior engineer already does in a design
review, costs only conversation turns. The rest of the `engineering/` skills (tdd, triage,
to-spec, domain-modeling) assume a TypeScript/Node/GitHub/Husky workflow, so a Go/Linux/
embedded-hardware shop gets only partial value from those specifically.

**Cost-efficiency.** Grilling is deliberately one-question-at-a-time to avoid the rework cost of
batched, ambiguous questions - a context-minimization design choice. `research` and
`code-review` dispatch parallel sub-agents to keep contexts isolated, the same rationale
claudeconf already applies with `Explore`/`runner`. Nothing here does explicit
Sonnet/Opus/Haiku tier routing - that discipline is claudeconf's own, not imported.

**Red flags / other notes.** `git-guardrails-claude-code` is a real conflict: it's a skill that
programmatically writes a `PreToolUse` hook into `settings.json` to block `git push`/
`reset --hard`/etc. `decisions/0003-hooks-and-scripts-authoring-policy.md` requires hook
registration be done by hand precisely because a hook activates before any commit review -
adopting this specific skill as shipped would violate that ADR; the underlying protection idea
is fine, the auto-writing mechanism is not. No other auto-registering hooks. License is not an
issue. Recommendation: pull in `grill-me`/`grilling` (adapted, by hand, into the plan/execute
workflow) and use `teach`/`research`/`code-review` as design references for the backlog items;
skip the TS-flavored `engineering/` skills and the auto-hook-writing `git-guardrails` skill.

---

## 2. everyinc/compound-engineering-plugin (recommended - mine for design, don't install whole)

- Homepage: <https://every.to> (see the article "My AI had already fixed the code before I saw
  it")
- Repo: <https://github.com/everyinc/compound-engineering-plugin>

**What it provides.** A full plugin bundling 32 skills, each exposed as a slash command:
`/ce-brainstorm` -> `/ce-plan` -> `/ce-work` -> `/ce-simplify-code` -> `/ce-code-review` ->
`/ce-compound`, plus `/ce-strategy`, `/ce-ideate`, `/ce-pov`, `/ce-debug`, `/ce-doc-review`,
`/ce-compound-refresh`, `/ce-sweep`, PR-lifecycle commands (`/ce-commit`,
`/ce-commit-push-pr`, `/ce-babysit-pr`, `/ce-resolve-pr-feedback`, `/ce-worktree`,
`/ce-promote`), test commands (`/ce-test-browser`, `/ce-test-xcode`), and `/lfg` (a full
autonomous run). Native `.claude-plugin/plugin.json` manifest, with equivalents for Cursor,
Codex, Kimi, Cline, Devin, Copilot. No standalone `agents/` directory or hooks in the
manifest - specialist behavior lives as per-skill prompt assets and scripts.

**Maturity.** 23.7k stars, 1.9k forks, MIT license, 1,105+ commits, five commits merged today
(2026-07-31) - actively maintained. Installable via
`/plugin marketplace add EveryInc/compound-engineering-plugin` then
`/plugin install compound-engineering`.

**Overlap.** `ce-brainstorm` + `ce-plan` + `ce-work` conceptually duplicate `write-plan`/
`execute-plan`, but as one monolithic loop rather than claudeconf's two separable,
spec-governed skills. `ce-doc-review` loosely overlaps `review-md`. No analog to
`skill-author`.

**Complement.** Directly hits both remaining unbuilt backlog gaps. `ce-code-review` is prior
art for the Code Review fan-out item: a dynamic reviewer roster dispatched in parallel, an
optional cross-model adversarial peer, merged/deduped findings. `ce-compound`/
`ce-compound-refresh` is prior art for the Learning/Teaching/KB item: it writes structured
bug/knowledge docs to `docs/solutions/`, maintains a `CONCEPTS.md` glossary, cross-references
prior notes, and has an explicit lightweight mode for tight context budgets. Good design
reference for both gaps, not necessarily a drop-in adoption.

**Real-world value.** The `ce-compound` frontmatter schema (bug-track vs. knowledge-track
split, cross-referencing) is genuinely useful and worth studying directly. But the 32-skill
bundle presumes its own brainstorm/plan/work loop end to end; importing it wholesale would
create two competing planning regimes rather than complement `write-plan`/`execute-plan`.

**Cost-efficiency.** Mixed but reasonable: `ce-compound` does a cheap metadata scan before
expensive synthesis and has an explicit lightweight/context-constrained mode; `ce-code-review`
gates parallel dispatch to "host's agent capacity." Nothing here does explicit Sonnet/Opus/
Haiku tier routing or caching guidance, and full-mode multi-agent fan-out (plus an optional
cross-model peer CLI call) could get expensive if adopted as-is.

**Red flags / other notes.** No auto-executing hooks (the manifest has no `hooks` field).
`ce-compound` documents ambient "auto-invoke triggers" on phrases like "that worked"/"it's
fixed" - this cuts against claudeconf's "skill named = skill invoked" discipline and would need
to be disabled or rewritten as explicit-invoke-only if adopted. The cross-model adversarial peer
in `ce-code-review` shells out to another provider's CLI - review that specifically before
enabling. Recommendation: study the `ce-compound` schema and `ce-code-review` reviewer-roster
mechanism as the starting design for the two unbuilt backlog items rather than installing the
plugin.

---

## 3. obra/superpowers (reference only - do not install alongside write-plan/execute-plan)

- Homepage: <https://claude.com/plugins/superpowers>,
  <https://primeradiant.com/superpowers/>, announcement:
  <https://blog.fsck.com/2025/10/09/superpowers/>
- Repo: <https://github.com/obra/superpowers>

**What it provides.** 14 skills framed as a software-development methodology, no separate
`commands/` or `agents/` directories: `brainstorming`, `using-git-worktrees`, `writing-plans`,
`executing-plans`, `subagent-driven-development`, `dispatching-parallel-agents`,
`test-driven-development`, `systematic-debugging`, `verification-before-completion`,
`requesting-code-review`, `receiving-code-review`, `finishing-a-development-branch`,
`writing-skills`, and the bootstrap meta-skill `using-superpowers`. One `SessionStart` hook
(triggered on startup/clear/compact) reads `using-superpowers/SKILL.md` and injects it as
forced context every session - a benign local file read, not a network call.

**Maturity.** 264,444 stars, 23,605 forks, 310 open issues, MIT license, created 2025-10-09,
pushed as recently as 2026-07-31 - very active (see the star-count caveat above). Packaged as a
real installable plugin
(`/plugin install superpowers@claude-plugins-official`), with equivalents for Cursor,
Antigravity, Codex, Gemini CLI, Copilot CLI, Kimi, OpenCode, Pi.

**Overlap.** `writing-plans`/`executing-plans`/`subagent-driven-development`/
`dispatching-parallel-agents` overlap `write-plan`/`execute-plan` directly, with no awareness
of claudeconf's model-tier discipline or its specific subagents - installing both would create
two competing planning regimes. `writing-skills` overlaps `skill-author`.
`requesting-code-review`/`receiving-code-review` have no current equivalent.

**Complement.** `requesting-code-review`/`receiving-code-review` partially address the unbuilt
Code Review fan-out backlog item, though they're single-reviewer dispatch, not multi-angle
fan-out-and-collate - would need real adaptation, not a straight port. Nothing here touches
Research fan-out or Learning/KB.

**Real-world value.** For a config that already has bespoke TDD/worktree/planning discipline,
most of this is redundant repackaging. The genuinely portable pieces are narrow techniques -
`systematic-debugging`'s 4-phase root-cause process, `verification-before-completion`, and
`receiving-code-review`'s "verify, don't performatively agree" pattern - worth lifting as
reference material into `reference/`, not adopting wholesale.

**Cost-efficiency.** Adds a small constant tax (roughly 3 KB / ~700 tokens) injected every
session/compact regardless of whether it's needed that session. `dispatching-parallel-agents`
does practice good context isolation, matching claudeconf's own fork/`Explore` philosophy. No
model-tier routing or caching guidance - it assumes a single agent throughout.

**Red flags / other notes.** `using-superpowers` uses absolutist, hard-override language ("YOU
DO NOT HAVE A CHOICE... not negotiable") forcing skill invocation before any response - this
conflicts with claudeconf's more measured trigger discipline. Default phone-home telemetry
(fetches a logo/version from Prime Radiant's site via `brainstorming`'s visual companion,
opt-out via an env var) and a commercial upsell footer. Maintainers explicitly do not accept
community skill contributions, so despite the open license this is a single-vendor-controlled
roadmap. Recommendation: read `systematic-debugging` and `receiving-code-review` for technique
ideas; do not install the plugin.

---

## 4. rtk-ai/rtk (different category - infrastructure tool, not a skill; interesting but unproven)

- Homepage: <https://www.rtk-ai.app>
- Repo: <https://github.com/rtk-ai/rtk>

**What it provides.** Not a skills/agents repo at all - "RTK" (Rust Token Killer) is a
standalone Rust CLI proxy wrapping roughly 100+ dev commands (git, cargo, npm/pnpm, docker,
k8s, aws, pytest/jest/go test, eslint/tsc/ruff, curl, etc.) that filters, dedupes, truncates,
and groups their output to cut Bash-output tokens before they ever reach an agent's context.
No `SKILL.md`, no subagents, no slash commands, no plugin manifest. For Claude Code
specifically, its installer (`rtk init -g`) patches `settings.json` to register a `PreToolUse`
hook that intercepts Bash tool calls and transparently rewrites them (e.g. `git status` becomes
`rtk git status`). Only Bash calls are intercepted - native `Read`/`Grep`/`Glob` are untouched.
Note: while researching this repo, an automated filter flagged fetched content as resembling
embedded instructions around the settings.json-patching behavior described above; nothing was
executed, and the flagged behavior matches what the project's own docs openly describe as its
install mechanism.

**Maturity.** 74.2k stars, 4.6k forks, Apache-2.0 license, created January 2026, pushed as
recently as 2026-07-31, 1,796 open issues - very active, but only about six months old; a star
count this large for that age is worth a sanity check before leaning on it as a maturity signal.
Installed via
Homebrew/curl/cargo/prebuilt binaries plus `rtk init -g`; explicitly not a Claude Code
plugin-marketplace package.

**Overlap.** None of the existing skills overlap - they're prompt/orchestration-layer
artifacts, this is a shell-layer proxy. The closest conceptual neighbor is the `runner`
subagent, which exists to keep verbose command output out of the orchestrator's context. `rtk`
and `runner` solve the same underlying problem (verbose-output pollution) at different layers:
`runner` isolates output into a subagent's own context on demand; `rtk` filters it at the shell
layer before any context sees it, for every Bash call, all the time.

**Complement.** Nothing tied to the named backlog items. Its value would be
infrastructure-level - reducing token cost on every Bash call globally, not just calls
intentionally routed through `runner`.

**Real-world value.** Real savings are plausible on noisy commands (test failures, lint dumps,
docker/k8s logs) in long sessions. Benefit is workflow-dependent (Bash-only coverage) and it is
lossy by design - the project's own docs warn filtered output should be verified before relying
on it for critical decisions, which matters for a config with a "verify before claiming" rule.

**Cost-efficiency.** The one repo in this list directly on-target for token/context
minimization specifically. Does nothing for model-tier routing or prompt caching.

**Red flags / other notes.** `rtk init -g` programmatically patches `settings.json` - the same
`decisions/0003` conflict as `caveman` below, since hook registration is supposed to be done by
hand. Telemetry documentation was internally inconsistent between the README and its own
disclaimer text - verify `docs/TELEMETRY.md` directly before trusting either claim. It sits
silently in front of every Bash result and is lossy by design, which is a real
"hides information from the agent" risk. It's also an external binary dependency that can't be
version-pinned or audited the way a markdown skill can. Recommendation: worth a closer look
specifically for token-cost reduction, but only with the hook wired in by hand rather than via
its installer, and only after verifying the telemetry story directly.

---

## 5. nagisanzenin/claude-code-production-grade-plugin (not recommended)

- Homepage: none separate from the repo.
- Repo: <https://github.com/nagisanzenin/claude-code-production-grade-plugin>

**What it provides.** An installable plugin with 14 bundled skills: `product-manager`,
`solution-architect`, `software-engineer`, `frontend-engineer`, `qa-engineer`,
`security-engineer`, `code-reviewer`, `devops`, `sre`, `data-scientist`, `technical-writer`,
`skill-maker`, `polymath`, and `production-grade` (the orchestrator/router), invoked via
natural-language business requests and routed through 5 phases (DEFINE-BUILD-HARDEN-SHIP-
SUSTAIN) with 3 approval gates and 10 modes. Two hooks: a read-only `SessionStart` guard, and a
`PostToolUse` hook on Edit/MultiEdit/Write/NotebookEdit that runs the target project's own
`oracle.sh` typecheck/lint after edits and blocks on failure once armed (with an `oracle.off`
escape hatch).

**Maturity.** 169 stars, 48 forks, 1 open issue, not archived, created 2026-03-04 (about 5
months old), last push 2026-07-08, currently v5.5.2. Requires Docker/Compose and Git. Installed
via `/plugin marketplace add nagisanzenin/claude-code-plugins` then
`/plugin install production-grade@nagisanzenin`.

**Overlap.** `code-reviewer` + `qa-engineer` + `security-engineer` overlap the Code Review
fan-out backlog item. `skill-maker` overlaps `skill-author`. The orchestrator overlaps
`write-plan`/`execute-plan`'s planning-and-dispatch role, but as one monolithic pipeline rather
than two composable, spec-governed skills.

**Complement.** The one concrete idea worth taking is `oracle-gate.sh`: a real, executable
"definition of done enforced by a tool, not agent self-report" mechanism - a working
implementation of the DoD-gate idea `execute-plan` already gestures at conceptually. Nothing
here touches Learning/KB or general Research fan-out.

**Real-world value.** Low for augmenting an already-careful individual engineer's workflow;
this is a fire-and-forget "build me a whole SaaS" pipeline, not a surgical tool. The oracle-gate
concept is worth stealing on its own; the rest is not.

**Cost-efficiency.** No visible model-tier routing across its 14 agents, and 10+ parallel points
across 5 phases with iterative loop-until-green retries suggests high token burn relative to
claudeconf's lean, tiered skills. Likely costly rather than cost-neutral.

**Red flags / other notes.** `plugin.json` and the README badge claim MIT, but there is no
`LICENSE` file at the repo root (404) - a real inconsistency to resolve before trusting the
license claim. Single maintainer, young repo (169 stars is a modest signal compared to the
other repos here). Auto-registers hooks that run shell scripts on every Edit/Write, conflicting
with `decisions/0003`'s hand-review requirement. The rigid 5-phase gated pipeline with
essentially no open-ended questions conflicts with this config's "pause on ambiguity" and
"smallest correct change" ethos. Requires Docker infrastructure not currently in use here.
Recommendation: skip; read `oracle-gate.sh` for the DoD-enforcement idea only.

---

## 6. juliusbrussee/caveman (not recommended)

- Homepage: <https://caveman.so/>
- Repo: <https://github.com/juliusbrussee/caveman>

**What it provides.** A Claude Code plugin plus a skills-registry package that compresses agent
*output* text (roughly 65% claimed reduction) by dropping filler while preserving code/
commands/errors verbatim. Ships skills `caveman`, `caveman-commit`, `caveman-review`,
`caveman-stats`, `caveman-compress`, `caveman-help`, `cavecrew`; commands
`/caveman [lite|full|ultra|wenyan]`, `/caveman-commit`, `/caveman-review`, `/caveman-stats`,
`/caveman-compress <file>`; subagents `cavecrew-investigator` (Haiku, read-only locator),
`cavecrew-builder`, `cavecrew-reviewer`; two auto-registered hooks (`SessionStart` and
`UserPromptSubmit`); a statusline script; and an optional MCP proxy that compresses tool
descriptions. Note: while researching this repo, an automated filter flagged fetched content as
resembling embedded instructions around the settings.json-patching behavior described below;
nothing was executed, and the flagged behavior matches what the project's own installer openly
does.

**Maturity.** 94.9k stars, 5.4k forks, MIT license, created 2026-04-04, last push 2026-07-26 (5
days before the 2026-07-31 snapshot date above), 446 open issues - actively maintained (see the
star-count caveat above). Installable as a real plugin or via a one-line curl/npx installer
targeting 30+ agents.

**Overlap.** `cavecrew-investigator` duplicates the existing `Explore` subagent almost exactly
(Haiku, read-only, path:line output, refuses to fix or design). `cavecrew-builder`/
`cavecrew-reviewer` overlap `executor` and a future Code Review fan-out capability, but aren't
parallel/fan-out by design. No overlap with `review-md`, `write-plan`, `execute-plan`,
`skill-author`, or `runner`.

**Complement.** Nothing tied to Learning/KB or Research fan-out. `caveman-stats` pulls real
token/cost metrics from session logs (not model-estimated), and `caveman-compress` shrinks
memory/CLAUDE.md files - loosely adjacent to token-cost discipline but not tied to any named
backlog item.

**Real-world value.** Modest and speculative for someone already writing terse prompts.
Benchmarks are self-reported (a 22-87% range, easy to cherry-pick) and it adds roughly 1-1.5k
input tokens per turn as overhead. The `cavecrew-investigator` design (Haiku, tabular
path:line, hard refusal boundary) is a genuinely good idea - already implemented independently
as `Explore`.

**Cost-efficiency.** Mixed: claims net token savings via output compression and a
caching-friendly design, but adds fixed per-turn input overhead and a background MCP proxy;
savings depend heavily on task verbosity and aren't guaranteed net-positive for a user who
already writes tight prompts.

**Red flags / other notes.** The installer directly patches `~/.claude/settings.json` (adding
`SessionStart`/`UserPromptSubmit` hooks) and auto-appends to `AGENTS.md`/`SOUL.md` on other
agents - this violates `decisions/0003`'s rule that hook registration must be done by hand,
never by an automated installer. It also imposes a persistent, global communication-style
override ("caveman mode") that would conflict with this config's own tone/formatting rules
unless carefully scoped. No sign of arbitrary remote code execution beyond normal npx package
resolution; MIT license is fine. Recommendation: skip - `Explore` already covers the one good
idea here, and the installer's auto-patching behavior is a real policy conflict.

---

## 7. ayghri/i-have-adhd (not recommended)

- Homepage: none separate from the repo.
- Repo: <https://github.com/ayghri/i-have-adhd>

**What it provides.** A single skill (not a suite) that reshapes assistant output style:
action-first replies, numbered steps, one concrete next step at the end, no preamble/recap/
closers, a 5-item list cap, concrete time estimates. Ten rules with five stated exceptions
(full explanations on request, confirm before destructive actions, etc.). One opt-in
`SessionStart` hook (gated behind a flag file the user must create) injects the skill body into
context every session; otherwise it's invoked on demand (`disable-model-invocation: true` by
default). Also ships per-harness adapters and an eval harness that checks output-style
compliance against a rubric.

**Maturity.** 14,723 stars, 801 forks, MIT license, 15 open issues, created 2026-05-13, pushed as
recently as 2026-07-31 - actively maintained. Installable as a real plugin or via manual copy.

**Overlap.** None functionally - no existing skill/subagent shapes conversational output style
the way this does. The closest tangential relation is that `Explore` and `runner` are already
instructed to return terse path:line/pass-fail summaries rather than prose, philosophically
aligned with this skill's ethos but not generalized as a user-facing toggle.

**Complement.** Nothing tied to Learning/KB, Code Review fan-out, or Research fan-out - it's a
presentation-layer skill, not a capability.

**Real-world value.** Modest for this setup specifically. This config's own global `CLAUDE.md`
already mandates concise, non-emoji, action-oriented reporting, and subagents
are already prompted to be terse. Value would be marginal - an occasional manual toggle for a
chattier moment, not a load-bearing addition.

**Cost-efficiency claim: refuted.** Verified via the raw README, `SKILL.md`, `plugin.json`, and
hook source directly (not just a summary): zero mentions of "context window," "cost,"
"cache/caching," or token usage as a designed feature. The only occurrence of "token" in the
repo is inside an unrelated JWT-auth code example. Terser output incidentally reduces output
tokens, but that is not designed, measured, or marketed as a feature - the original reason for
evaluating it (whether it also helped with token usage) appears to be a red herring.

**Red flags / other notes.** None serious. Actively maintained, MIT-licensed, small auditable
hook (opt-in only, no network calls, fails open, pure POSIX sh - satisfies this config's
hand-review-before-registration bar). Default posture is inert until invoked, so it doesn't
force a workflow. Recommendation: skip - it duplicates conventions this config already
enforces, and the token-savings rationale for investigating it doesn't hold up.

---

## 8. numman-ali/openskills (not recommended)

- Homepage: none separate from the repo (npm page is the closest secondary link).
- Repo: <https://github.com/numman-ali/openskills>

**What it provides.** Not a skills-content repo - a TypeScript npm CLI (`npx openskills`) that
installs and syncs other people's `SKILL.md`-format skills into a project or `~/.claude`. It
ships zero skills, subagents, commands, or hooks of its own. It generates/rewrites an
`<available_skills>` XML block inside `AGENTS.md` (matching Claude Code's own prompt format) so
that Cursor/Windsurf/Aider/Codex/etc. can discover and load skills via
`npx openskills read <name>`, since those tools don't natively parse Claude Code's skill
loader.

**Maturity.** 10,652 stars, 666 forks, 43 open issues, Apache 2.0 license (GitHub's own
license-detector currently mis-reports this as "NOASSERTION," which appears to be a detection
quirk rather than a real ambiguity - the LICENSE file itself is unambiguous). Last commit
2026-01-18 - about 6.5 months stale as of the 2026-07-31 snapshot date above; creation date was
not captured during research and isn't stated here rather than guessed. Installed via
`npm i -g openskills`/`npx openskills`; not a Claude Code plugin.

**Overlap.** Essentially none - it doesn't compete with any existing skill or subagent, it's a
distribution/sync mechanism, not authored guidance or an orchestration workflow.

**Complement.** Nothing maps to the named backlog items - it's plumbing, not capability. Its
only relevant angle is cross-tool skill portability, but claudeconf already solves Claude Code/
Cursor dual-read through its own spec-driven generation pipeline (`specs/` -> generated
`skills/`/`agents/`), which is more deliberate and reviewable than an npx sync step.

**Real-world value.** Low for this repo specifically. It would matter if pulling third-party
skills into a non-Claude-Code agent, but claudeconf hand-curates and generates its own skills
rather than importing external ones.

**Cost-efficiency.** Neutral to mildly positive if used - it implements progressive disclosure
(skills loaded on demand via `read`, not dumped into context), the same discipline claudeconf
already follows. No model-tier routing or caching behavior of its own.

**Red flags / other notes.** Staleness (6.5 months, no commits) is the main one. `install`
clones arbitrary git repos/GitHub sources and later reads their `SKILL.md` content into an
agent's context unreviewed - the same trust model as any third-party skill import, not a
code-execution hook, but still a supply-chain vector if pointed at an untrusted source. No
opinionated workflow conflicts since it doesn't touch git or the docs workflow at all.
Recommendation: skip - it solves a portability problem this config doesn't have.

---

## Appendix: additional tools surfaced by the listicle articles

The candidate list also linked three "best Claude Code plugins" style articles, presumably as a
secondary discovery source rather than direct recommendations. They were surveyed more
shallowly than the 8 repos above (one fetch each, no repo-level investigation), so treat these
as leads to look into further, not vetted recommendations.

- **Medium** ("the Claude Code plugin stack that actually makes you ship faster"): a curated,
  opinionated 8-tool stack, closing specific gaps (stale docs, generic UI, missed security
  issues). Explicitly excludes Ralph Loop, GitHub MCP, Playwright MCP, and Claude-Mem as not
  worth it.
- **Composio** ("top Claude Code plugins"): a broad catalog of roughly 40 plugins across
  language servers, external-service connectors, code review, workflow/git automation,
  browser/testing, and dev tooling - doubles as a soft pitch for Composio's own integration
  platform.
- **Reddit** (`r/AskVibecoders`): could not be fetched (blocked for automated retrieval); no
  content was extracted or fabricated from it.

Distinct tools named across the two accessible sources, worth a closer look if any of these
problem areas matter:

| Name | What it does | Mentioned by |
|---|---|---|
| Context7 (`@upstash/context7-mcp`, context7.com) | Pulls live, version-specific library docs/API refs instead of relying on stale training data | Medium + Composio |
| Frontend Design skill (anthropics/skills) | Auto-activates on UI work to produce non-generic interface code | Medium + Composio |
| Skill Creator (anthropics/skills) | Build/test/benchmark custom Claude skills | Medium + Composio |
| Security Guidance skill (anthropics/skills) | Detects auth/SQL/validation/API code and injects security reasoning inline | Medium + Composio |
| Figma MCP (mcp.figma.com) | Connects Figma design files directly to spec-accurate code generation | Medium + Composio |
| PR Review Toolkit | Structured PR review across comments, tests, types, and quality | Composio |
| CodeRabbit | AI-powered code review / static analysis integration | Composio |
| Semgrep | Static-analysis security scanning via rule sets | Composio |
| Sentry | Pulls production error/incident data into Claude's context | Composio |
| Greptile | Natural-language semantic codebase search | Composio |
| Serena | Semantic code analysis and refactoring support | Composio |

Composio's list also includes many single-purpose language-server plugins (TypeScript, Pyright,
Rust, Go, Java, PHP, Clangd, Kotlin, Swift, Lua) and SaaS connectors (GitHub, GitLab, Slack,
Linear, Atlassian, Vercel, Supabase, Firebase), omitted above as infrastructure rather than
distinct alternatives to anything in the main 8. Both articles flagged Ralph Loop, Playwright/
Chrome DevTools MCP, and Claude-Mem/Remember as either promising-but-risky or explicitly not
recommended, worth knowing if those categories come up separately.

None of the appendix items were checked against claudeconf's specific overlap/complement/
red-flag criteria the way the main 8 were - anything here that looks worth pursuing should get
the same treatment before adoption.
