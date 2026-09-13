---
created: 2026-07-23
updated: 2026-09-12
---

# Context File Authoring Rules

Read this before creating or editing a `CLAUDE.md`, `AGENTS.md`, a nested/subdirectory context file, or a `.claude/rules/*.md` file, in this repository or any other. It covers what content earns its place in these files, what belongs somewhere else instead, and the loading mechanics (precedence, imports, size limits) that determine whether an edit actually changes agent behavior.

## The Decision Rule

Before adding a line to any context file, apply both checks:

1. **Specificity check** (Gloaguen et al., 2026): does this name a specific tool, command, path, or constraint unique to this repository that an agent would get wrong without it?
2. **Necessity check** (Anthropic's own guidance): would removing this line cause the agent to make a mistake? If not, cut it.

If either answer is no, the line does not belong. This applies to edits, not just new files. Trimming an existing bloated file is at least as valuable as writing a lean new one, and is often the actual task you were asked to do.

## What Belongs, What Doesn't

| Include | Exclude |
| --- | --- |
| Exact commands the agent cannot guess (`uv run pytest`, `mage testProject`, `buf generate proto --include-imports`) | Commands already discoverable in `package.json` / `Makefile` / CI config, which the agent will read anyway |
| Constraints invisible from the code (shared-repo git worktree rules, required env vars, non-obvious ordering requirements) | Codebase overviews ("this is a Go monorepo with 15 services...") |
| Code style rules that differ from language or framework defaults | Standard language or framework conventions the model already knows |
| Proprietary or internal library APIs (near-zero training data coverage) | Full API documentation (link to it instead) |
| Testing instructions: exact runner, how to run a single test, what to mock and what not to | Generic "write tests" / "follow best practices" |
| Explicit boundaries: files or directories the agent must never touch | Self-evident practices ("write clean code", "be consistent") |
| Repository etiquette: branch naming, commit format, PR and merge requirements | Information that changes weekly (put that behind a live-fetched source, not a static file) |
| Version-gated features or breaking changes from defaults | File-by-file descriptions of the codebase |
| Conditional-loading pointers to reference files, rules, or skills | README duplication |

A one-line causal clause on a non-obvious rule is fine, and often helps the agent generalize correctly ("Use `unknown`, not `any`; we had three runtime crashes from mistyped API responses"). A standalone "Rationale" or "Why This Matters" section, or a narrated "real-world impact" story, is not the same thing and should be cut. The line should teach a decision, not tell a story.

## Route Content To The Right Mechanism

Not everything true and important belongs in a context file. Identify what kind of content it is before writing it down:

| If the content is... | Put it in... | Not in a context file, because... |
| --- | --- | --- |
| A rule that must fire with zero exceptions (formatting, blocking a command, blocking a branch) | A hook (`PreToolUse` / `PostToolUse` in `settings.json`) | CLAUDE.md content is delivered as a user message after the system prompt, not enforced configuration; the agent can read a rule and still deviate. Hooks execute as shell commands at fixed lifecycle events and apply regardless of what the agent decides. |
| A multi-step, reusable, sometimes-needed workflow (deploy steps, a scaffolding recipe) | A skill (`SKILL.md`) | Loads on demand instead of consuming budget in every session. |
| Something relevant to only one file type or subtree (component conventions, one package's test setup) | A path-scoped `.claude/rules/*.md` (`paths:` frontmatter) or a nested `CLAUDE.md` / `AGENTS.md` in that subtree | Keeps the always-loaded root file small; loads only when relevant. |
| A learned pattern, debugging insight, or preference discovered mid-session | Auto memory (`MEMORY.md` and topic files) | Auto memory is agent-written and machine-local; hand-authoring the same thing into CLAUDE.md duplicates a system that already exists for it. |
| A hard technical restriction (block a tool, a path, a domain) that must hold no matter what the agent decides | `permissions.deny` or managed settings | Settings are enforced by the client; CLAUDE.md is not. |
| Detailed API reference, architecture rationale, or onboarding narrative for humans | A README or docs file, linked from the context file | Context files are read by agents every session; humans read READMEs on demand. Don't make every session pay for human-onboarding prose. |

If none of these fit and the fact is genuinely something the agent needs every session and cannot infer on its own, it belongs in the context file.

## Size and Structure

- Anthropic's official target for a single `CLAUDE.md` file is under roughly 200 lines. Longer files consume more context and measurably reduce adherence; content past that point tends to get ignored rather than followed.
- `AGENTS.md` has no formal size rule in the spec itself (plain markdown, no required fields), but community practice converges on roughly 20 to 150 lines for a root file, splitting into nested per-directory `AGENTS.md` files once a single file would otherwise run past 150 to 200 lines. Individual tools may add their own hard caps on top of the spec (for example, community reports describe Codex silently truncating an `AGENTS.md` past a default size limit), so verify the current limit of whichever tool must read the file in full rather than assuming there is none.
- As a repository-local convention (not a spec requirement): hold an always-loaded root file to Anthropic's roughly 200-line target above - commands, constraints, and a conditional-loading table - and push detail into on-demand reference files or rules of roughly 200 to 400 lines each, loaded only for the tasks that need them. Overrunning that target is permitted up to a hard ceiling of 300 lines, but it is a tolerance rather than a budget to spend: past 200, each added rule trades against the adherence of the rules already there, so pair the addition with a cut or with a deliberate decision to accept that trade. Past 300, trim before adding anything.
- Structure with markdown headers and bullets, not dense paragraphs. Scannability matters to the agent as much as to a human skimming the same file.
- Write verifiable, specific instructions. "Use 2-space indentation" and "run `npm test` before committing" survive; "format code properly" and "test your changes" do not, because compliance can't be checked.
- Emphasis words ("IMPORTANT", "YOU MUST") measurably improve adherence on the handful of rules that matter most. Do not use them on every line, or they stop meaning anything.
- In `CLAUDE.md` specifically, block-level HTML comments (`<!-- ... -->`) are stripped before injection into context, so maintainer-only notes (timestamps, TODOs, links for humans) placed there cost nothing. Comments inside fenced code blocks are preserved, and opening the file directly with a file-reading tool still shows them.

## CLAUDE.md and AGENTS.md Are Not The Same Loader

Claude Code reads `CLAUDE.md`. It does not read `AGENTS.md` on its own. GitHub Copilot's coding agent is one of the tools shown natively supporting `AGENTS.md` on the spec's own site, and the spec's "About" page separately credits OpenAI Codex, Amp, Google's Jules, and Factory as collaborators who helped define the format. If more than one agent CLI works on a repository, do not maintain parallel files that will drift:

- Make `AGENTS.md` the shared source of truth, and give `CLAUDE.md` a first-line import, `@AGENTS.md`, followed by any Claude-specific additions below it.
- Or symlink: `ln -s AGENTS.md CLAUDE.md`. This loses Claude-specific extras like additional imports below the shared content, and requires Administrator privileges or Developer Mode on Windows; use the `@AGENTS.md` import there instead.
- By default, running `/init` in a repository reads existing Cursor rules (`.cursor/rules/` or `.cursorrules`) and GitHub Copilot rules (`.github/copilot-instructions.md`) and folds the relevant parts into the generated `CLAUDE.md`. With `CLAUDE_CODE_NEW_INIT=1` set, it also reads `AGENTS.md`, `.devin/rules/`, `.windsurf/rules/` or `.windsurfrules`, and `.clinerules`.
- Do not hand-copy the same content into both files. Duplication is exactly what the format split was meant to avoid, and the copies will drift the first time only one gets updated.

## Loading Mechanics

### CLAUDE.md

- Five scopes, broadest to most specific: managed policy (org-wide, cannot be excluded by users), user (`~/.claude/CLAUDE.md`), project (`./CLAUDE.md` or `./.claude/CLAUDE.md`), local (`./CLAUDE.local.md`, gitignored, personal), subdirectory (`<subdir>/CLAUDE.md`, team-shared).
- Files in the directory tree above and at the working directory are concatenated in full at session start, ordered root-to-leaf, so the file closest to where the session started is read last. They are not merged by override: if two files disagree, the agent may pick one arbitrarily. Fix contradictions by removing or reconciling one of them, not by adding a third file that tries to arbitrate.
- Within a single directory, `CLAUDE.local.md` is appended after `CLAUDE.md`, so personal overrides are the last thing read at that level.
- Subdirectory `CLAUDE.md` files are not loaded at launch. They load on demand the first time the agent reads a file inside that subdirectory, and sibling subdirectories never see each other's files. A rule that must always apply does not belong in a subdirectory file; it will not be loaded until the agent happens to touch that subtree.
- `@path/to/file` imports are a Claude Code extension, not part of the `AGENTS.md` spec. They resolve relative to the importing file, not the working directory; recurse up to 4 hops deep; are skipped inside fenced code blocks and inline code spans (wrap a path in backticks to mention it without importing it); and, the first time a project-level file imports something that resolves outside the working directory, trigger a one-time user approval dialog (imports in user-scope files such as `~/.claude/CLAUDE.md` are trusted without a dialog). Imports do not save tokens; an imported file still loads in full at launch alongside the file that references it, so use them for organization, not as a way around the size guidance above.
- `claudeMdExcludes` (a settings field) skips specific CLAUDE.md files by glob pattern, useful when a monorepo pulls in another team's file that isn't relevant to your work. Managed policy files cannot be excluded this way.
- Compaction (`/compact`, automatic or manual) re-injects from disk: the project-root `CLAUDE.md` and unscoped rules, and auto memory. `paths:`-scoped rules and nested subdirectory `CLAUDE.md` files are lost until their trigger file is read again. Invoked skill bodies are also re-injected, capped and truncated (oldest dropped first past the total budget). None of Anthropic's documentation states whether the project-root guarantee extends to user-scope `~/.claude/CLAUDE.md` - confirmed gap as of 2026-07-30. (This repository's own root file is `CLAUDE.md` and hits this gap directly; see `decisions/0006-global-config-compaction-verification.md` for the research and a canary-based mitigation, if useful elsewhere.) Do not assume an instruction given only in conversation persisted through compaction; if it matters, put it in a file.
- To control what compaction preserves, Anthropic documents adding a section literally named `## Compact Instructions` to CLAUDE.md, as an alternative to a human running `/compact focus on <text>` at the terminal. The docs don't specify matching details (exact heading level, case sensitivity), nor whether the mechanism is honored when that heading lives inside an `@`-imported file rather than CLAUDE.md's own literal text. Treat the literal name as the safest bet and verify with `/compact` if it matters.

### AGENTS.md

- No hierarchy-wide concatenation. The agent reads the nearest `AGENTS.md` to the file being edited, and that file wins for its subtree. This is the opposite of CLAUDE.md's "load every ancestor" behavior. Put shared rules at the root and only override what genuinely differs in a nested file; do not assume the root file is always in view the way a CLAUDE.md ancestor would be.
- Plain markdown: no required sections, no frontmatter, no import syntax. Nested files are the only built-in mechanism for scoping in a large monorepo (OpenAI's own Codex repository uses 88 of them).

### `.claude/rules/*.md`

A middle ground for content that is neither "every session, everywhere" (CLAUDE.md) nor "an occasional multi-step workflow" (a skill):

- No `paths` frontmatter: loads at launch, same priority as `.claude/CLAUDE.md`.
- `paths: ["src/api/**/*.ts"]`: loads only when the agent reads a matching file. Supports multiple patterns and brace expansion (`**/*.{ts,tsx}`); user-level rules load before project rules, so a project rule on the same topic takes effective precedence.
- Supports symlinks, so a shared rules directory can be linked into multiple projects without duplicating content.
- The filename is for humans only; name files by topic (`testing.md`, `api-design.md`), not by mechanism.

## Red Flags: Stop If You're About To

- Add a "Project Overview" or "Architecture" section that just restates what a directory listing or the README already shows.
- Write "We value..." or "Our philosophy is..." anywhere.
- Enumerate the file or directory structure.
- Copy content that already lives in the README, a setup guide, or another context file, instead of linking or importing it.
- Add a generic language or framework convention the model already knows from training.
- Explain what CLAUDE.md or AGENTS.md is, to the agent that is reading a CLAUDE.md or AGENTS.md file.
- Write a standalone rationale, motivation, or "impact" section instead of a short causal clause on the rule itself.
- Put a must-always-happen rule in a context file instead of a hook, or a sometimes-needed procedure in a context file instead of a skill.
- Push a root file past roughly 200 lines without splitting into nested files, rules, or skills.
- Hand-write into CLAUDE.md something auto memory already tracks, such as a build command it already learned or a debugging insight from a prior session.

## Editing Checklist

1. Read the full existing file before changing anything. Do not assume line numbers or prior content from memory.
2. Identify the correct scope first: root, a subdirectory file, or a path-scoped rule. Defaulting everything to the root file is how it grows past 200 lines.
3. Check for contradictions with parent, imported, and subdirectory files before adding a rule. Two conflicting rules are worse than one missing rule.
4. Prefer trimming or rewriting an existing line over appending a new section. Growth is easy and rarely reversed; every addition should displace something or clearly justify its own cost.
5. State each rule as something verifiable, not aspirational.
6. If the rule must always hold with no exceptions, redirect it to a hook or `permissions.deny` instead of adding it here.
7. If the content is a multi-step workflow only needed sometimes, redirect it to a skill instead.
8. After editing, recount lines. If the file now exceeds the target for its tier, split before finishing rather than leaving it oversized.
9. Preserve existing HTML comments and human-maintainer notes; do not delete them as a side effect of an unrelated edit.
10. Leave managed or policy-level files alone unless explicitly asked; they are organization-controlled.
11. Where available, verify the edit actually loaded: `/context` lists loaded memory files, `/memory` opens them for inspection, `/doctor` (Claude Code v2.1.206+) proposes trims for a checked-in CLAUDE.md automatically, and an `InstructionsLoaded` hook can log exactly which files loaded and why if a rule seems to be silently missing.
12. Treat the file like code: it is meant to be checked into version control and reviewed like any other change, not edited freely without inspection.

## Non-Python Languages: Be Less Aggressive About Trimming

The primary research base behind these rules (Gloaguen et al., see References) evaluated Python repositories exclusively. The authors note that Python's heavy representation in training data may be masking benefits that would show up more clearly for less-represented languages and toolchains. Until that gap is studied directly, treat the guidance above as a firm floor for Python and only a starting point for languages with more footgun patterns (Go concurrency and error handling, Java or Spring conventions, React rendering pitfalls):

- Keep concrete code examples for patterns an agent plausibly gets wrong even when they are "generic" language knowledge, such as `defer cancel()`, loop-variable capture, or `t.Fatal` inside a goroutine.
- Err toward keeping useful patterns in on-demand reference files or rules rather than cutting them for length alone.

## Research Basis

Two empirical studies anchor the guidance above, and they do not fully agree with each other, which is itself informative: outcomes depend heavily on file quality, agent, and task type, not simply on whether a file exists.

- **Gloaguen et al., 2026**, "Evaluating AGENTS.md" (see References), ran 4 agents and models across SWE-bench Lite (300 tasks) and a new AGENTbench (138 tasks, 12 Python repositories). LLM-generated context files reduced task success by 0.5 to 2 percent while increasing inference cost by 20 to 23 percent. Developer-written files improved AGENTbench success by about 4 percent on average, with no improvement measured for Claude Code specifically, while still increasing cost by up to 19 percent. The one clearly positive signal was repository-specific tool mentions: agents used a named tool roughly 2.5 times more often than when it went unmentioned.
- **Lulla et al., 2026**, "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents" (see References), paired 124 real merged pull requests across 10 repositories, running OpenAI Codex with and without each repository's existing `AGENTS.md` file. Presence of the file was associated with a 28.64 percent lower median runtime and a 16.58 percent lower median output token count, with comparable task completion. Some secondary sources misattribute this paper to Princeton; the actual authors are affiliated with Singapore Management University, Heidelberg University, the University of Bamberg, and King's College London.
- Read together, a minimal, specific, human-written file grounded in real repository knowledge is the common thread every study and vendor guide converges on. What remains contested is the exact magnitude and even direction of cost and efficiency effects, which vary by agent, benchmark design, and how "developer-written" a file actually is in practice. Do not treat a specific percentage from either paper as a universal constant; treat the direction as the takeaway (specific and lean helps or is neutral, generic and bloated hurts).

## Minimal Starting Template

```markdown
# <Project name>

<One line: primary language/framework/stack, with versions.>

## Commands

- Build: `<exact command>`
- Test (full suite): `<exact command>`
- Test (single file or case): `<exact command>`
- Lint: `<exact command>`

## Conventions

- <A rule that differs from language/framework defaults, stated as a check.>
- <A rule the agent would otherwise get wrong, with a short reason if it's non-obvious.>

## Boundaries

- Never <specific file, directory, or action>.
- Ask first before <specific action>.

## Conditional Loading

- <Trigger, e.g. "working in src/api/"> -> `<path to rule or reference file>`
```

Delete any section that doesn't apply. A shorter, accurate file beats a comprehensive, generic one. Add sections only after the agent actually gets something wrong that a line here would have prevented.

## References

### Official Documentation

- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) - Anthropic; current CLAUDE.md include/exclude guidance and common failure patterns.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) - Anthropic; CLAUDE.md loading order, imports, `.claude/rules/`, auto memory, and AGENTS.md interop.
- [Explore the context window](https://code.claude.com/docs/en/context-window) - Anthropic; the compaction survival table this file's compaction bullet is based on, and the `/compact focus on X` human-invoked lever.
- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up) - Anthropic; documents the `## Compact Instructions` mechanism this file cites.
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Anthropic Applied AI team, September 2025; just-in-time context, compaction, and sub-agent architectures.
- [AGENTS.md](https://agents.md/) - the open, cross-tool specification, stewarded by the Agentic AI Foundation under the Linux Foundation.
- [Debug your configuration](https://code.claude.com/docs/en/debug-your-config.md) - Anthropic; `/context`, `/doctor`, `/memory`, and why a CLAUDE.md rule might not be taking effect.
- [Automate actions with hooks](https://code.claude.com/docs/en/hooks-guide) - Anthropic; the `InstructionsLoaded` event and other lifecycle hooks.

### Research

- Gloaguen et al., "Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?" (2026). [arXiv:2602.11988](https://arxiv.org/abs/2602.11988).
- Lulla, Mohsenimofidi, Galster, Zhang, Baltes, and Treude, "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents" (2026). [arXiv:2601.20404](https://arxiv.org/abs/2601.20404).

### Further Local Reading

- `docs/progressive-disclosure.md` - when and how to split a file into on-demand references.
