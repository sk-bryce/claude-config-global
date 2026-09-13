---
audience: human
created: 2026-07-22
updated: 2026-08-31
---

# Claude Code Skills: How They Actually Work

> Synced copy of `docs/features/skills.md` (source of truth) as of 2026-08-31. If that file
> changes, re-sync this copy - do not edit the two independently.

A practical guide for understanding and improving Claude Code skills. Written for someone who already builds skills but wants to understand the triggering system, optimize descriptions, and use advanced features.

## Scope

This guide documents Claude Code's skill system in depth: every field, behavior, and budget
below is specific to Claude Code.

## Mental Model: The 3-Level System

When Claude Code starts, it doesn't load your entire skill. It works in 3 stages:

```
Startup:     Load ONLY frontmatter (name + description) for ALL skills
             This is the "menu" Claude sees to decide what's available.
             Budget: 1% of context window (~8K chars total across all skills)

On Trigger:  Load SKILL.md body (instructions, steps, constraints)
             Triggered by auto-match OR explicit /slash-name

On Demand:   Load references/, examples/, scripts/
             Only when the skill explicitly reads them
```

**Why this matters:** If your description is vague, Claude literally doesn't know the skill exists for that use case. The description is your skill's entire advertisement.

## The #1 Problem: Bad Descriptions

Most skill failures come from descriptions that don't include trigger phrases. Compare:

```yaml
# BAD: when does Claude trigger this?
description: Helps with CI/CD things

# GOOD: Claude knows exactly when to fire
description: This skill should be used when the user asks to "optimize CI pipelines",
  "fix GitHub Actions", "add caching to workflows", "debug CI failures", or mentions
  .github/workflows/ files. Covers caching, summaries, observability, and security.
```

### The Pattern

1. Start with "This skill should be used when the user asks to..."
2. Include 3-5 exact phrases in quotes
3. Mention relevant file types or keywords
4. End with a brief scope statement

### Audit Your Skills

Run this to see all your descriptions at once:

```bash
for f in ~/.claude/skills/*/SKILL.md; do
  echo "=== $(basename $(dirname $f)) ==="
  awk '/^---$/{c++; next} c==1' "$f" | grep -E "^(name|description):"
  echo
done
```

(This reads the whole frontmatter block rather than a fixed line count, so it won't clip a description that has several fields before it. Multi-line YAML block-scalar descriptions still won't print in full - open the file directly for those.)

Ask yourself for each: "If I said [phrase] to Claude, would this description match?"

## Frontmatter Fields You're Probably Not Using

### `disable-model-invocation: true`

Prevents auto-triggering. Claude will NEVER fire this skill on its own; only when you type `/skill-name` explicitly. **Use for anything destructive**: deploys, database changes, PR creation, git push.

### `model: sonnet`

Overrides the model for the current turn only - it's not saved to settings, so the session model resumes on your next prompt. Great for cost optimization:

- `opus` for architecture/planning skills
- `sonnet` for implementation/generation skills
- `haiku` for simple formatting/grep tasks

### `context: fork`

Runs in a subagent fork. The skill's work doesn't pollute your main conversation context. Use for research-heavy skills that generate lots of intermediate output. Pair with `agent: Explore` (read-only research), `agent: Plan`, or `agent: general-purpose`.

**Note:** The value is `fork`, not `forked`.

### `user-invocable: false`

Hides from the `/` menu. For background-knowledge skills Claude should still auto-invoke via normal relevance matching, just not something a user would type as a slash command (e.g. a `legacy-system-context` skill).

**Subtle distinction:** `user-invocable: false` only hides from the menu; it does NOT block programmatic invocation via the Skill tool. To fully prevent Claude from triggering a skill, use `disable-model-invocation: true`.

### `hooks`

Lifecycle events. Can run shell commands when the skill is invoked. Advanced: useful for validation or setup before the skill runs.

### `allowed-tools` / `disallowed-tools`

Pre-approve (or block) specific tools for this skill's invocation, without touching your global permission settings. Useful for a skill that should always be able to run a specific command without a prompt, or one that should never be allowed to touch the network or filesystem.

## Description Budget: The Hidden Limit

All skill descriptions share a pool: **1% of context window** (fallback: 8,000 characters), configurable via `skillListingBudgetFraction`. Each individual description is also capped at 1,536 characters (`skillListingMaxDescChars`); longer ones get truncated.

A well-written trigger description (per the pattern above) easily runs 300-400+ characters. ~20 skills at that length already uses 6,000-8,000 characters, right at the edge of the default budget. Beyond that, descriptions start silently dropping.

Check your status: `/doctor` shows an estimate of context cost and the biggest contributors; `/context` reports the post-budget size.

Override: `SLASH_COMMAND_TOOL_CHAR_BUDGET=32000` env var.

**Practical limit**: Keep to ~20-30 well-curated global skills. Move niche skills to project scope.

## Precedence: Who Wins

When skills share the same name, higher-priority locations win:

```
Enterprise (managed settings)              HIGHEST, overrides everything
Personal:  ~/.claude/skills/foo/SKILL.md
Project:   .claude/skills/foo/SKILL.md     LOWEST
Plugin:    <plugin>/skills/foo/SKILL.md    Namespaced (plugin-name:skill-name), no conflicts
```

This also applies to bundled skills: a same-named skill at any of the levels above overrides the bundled version.

Project skills auto-discover from working directory upward. If you're in `packages/frontend/`, it finds skills from `packages/frontend/.claude/skills/` too. Skills from `--add-dir` directories also auto-load with live change detection.

**Strategy**: Start skills as project-scoped. Promote to personal only after battle-testing.

## When to Split Files

```
Keep in SKILL.md:
  - Data needed EVERY invocation (field IDs, mappings, constants)
  - Core workflow steps

Split to references/:
  - Language-specific patterns (only one used per invocation)
  - Deep-dive docs for conditional paths
  - Large code templates
```

Rule: if the skill always needs it, it stays in SKILL.md. Splitting adds a tool-call round-trip.

## Directory Layout

```
skills/my-skill/
├── SKILL.md              # Frontmatter + core instructions
├── references/           # Conditionally loaded docs
│   ├── go-patterns.md
│   └── js-patterns.md
├── examples/             # Templates and samples
│   └── manifest.yaml
└── scripts/              # Helper scripts
    └── validate.sh
```

## Features You Might Not Know About

### Dynamic Context Injection (`!`command``)

Shell commands run **before** Claude sees the skill content. Output replaces the placeholder (_Claude-only feature_):

```yaml
---
name: pr-summary
context: fork
agent: Explore
---
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

Summarize this pull request...
```

Claude receives the rendered output, not the commands. Powerful for injecting live data.

**Gotchas:**

- The `!` trigger only fires at the start of a line or after whitespace.
- Multi-line commands need the fenced ` ```! ` form instead of backticks.
- Substitution runs once when the skill loads; it isn't re-scanned afterward.
- `disableSkillShellExecution` can turn this feature off entirely.

### String Substitutions

Beyond `$ARGUMENTS`, you get:

- `$ARGUMENTS[N]` or `$N`: positional args (0-based). Example: `/migrate-component SearchBar React Vue` yields `$0`=SearchBar, `$1`=React, `$2`=Vue
- `$name`: named args, when the skill's frontmatter declares an `arguments` field
- `${CLAUDE_SESSION_ID}`: current session ID (logging, session-specific files)
- `${CLAUDE_SKILL_DIR}`: directory containing the SKILL.md (reference bundled scripts regardless of cwd)
- `${CLAUDE_PROJECT_DIR}`: the project root, regardless of current working directory
- `${CLAUDE_EFFORT}`: the current reasoning effort level

### Extended Thinking

Include the word **"ultrathink"** anywhere in skill content to activate extended thinking mode.

### Permission Rules

Control which skills Claude can invoke via `/permissions`:

```text
Skill(commit)        # allow exact match
Skill(review-pr *)   # allow prefix match
Skill(deploy *)      # deny prefix match
Skill                # deny all skills
```

### Bundled Skills

These ship with Claude Code, no setup needed:

- **`/simplify`**: reviews changed files for reuse/quality/efficiency, spawns 3 parallel agents
- **`/batch <instruction>`**: orchestrates large-scale parallel changes, each unit in its own worktree + PR
- **`/debug [description]`**: troubleshoots your current session via debug log
- **`/claude-api`**: loads Claude API + Agent SDK reference for your project's language
- **`/doctor`**: diagnoses your Claude Code setup; the one bundled skill that can't be fully disabled
- **`/code-review`**: reviews a working diff for bugs and quality issues
- **`/loop`**: runs a prompt or slash command on a recurring interval
- **`/run`**: launches and drives your project's app to verify a change works
- **`/verify`**: checks that a change actually does what it claims
- **`/run-skill-generator`**: scaffolds a new bundled-style skill

Disable all of these at once with the `disableBundledSkills` setting (plugins and your own `.claude/skills/` are unaffected).

## Testing Skills

1. **Auto-trigger test**: Type a natural prompt that should trigger it. Does Claude activate it?
2. **Manual test**: Type `/skill-name`. Does it work correctly?
3. **Negative test**: Type something unrelated. Does it accidentally trigger?
4. **Argument test**: Type `/skill-name some args`. Does `$ARGUMENTS` work?

For more rigor than these manual checks, `skill-creator` has a full eval framework built in: test cases, automated grading, quantitative benchmarking against a baseline, and a description-tuning loop that measures trigger accuracy directly.

## Resources

- Official docs index: `https://code.claude.com/docs/llms.txt` (fetch this to discover all page URLs)
- Skills page: `https://code.claude.com/docs/en/skills`
- Check budget: `/doctor` (cost estimate + biggest contributors) or `/context` (post-budget size)
- Agent Skills open standard: `https://agentskills.io`
- Anthropic guidance: SKILL.md under 500 lines, move reference material to separate files
