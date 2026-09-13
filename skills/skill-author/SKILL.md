---
name: skill-author
description: |
  This skill should be used when the user asks to create, author, or audit a Claude Code skill,
  or asks how skills work - e.g. "create a skill for...", "make a skill that...",
  "how do skill descriptions work?", "audit my skills", or "check skill description budgets".
  Covers SKILL.md frontmatter, the trigger-description pattern, description-budget discipline,
  references/examples/scripts layout, and knowledge/action-split design, then hands off to the
  harness's skill scaffolder (skill-creator or /create-skill) for scaffolding and evals. Does not
  cover general Markdown proofreading of arbitrary .md files (see review-md). Scope: personal
  (~/.claude/skills/) by default, project-scoped when asked.
model: opus
effort: high
---

<!--
created: 2026-07-23
updated: 2026-09-11
spec: specs/skills.md (skill-author section)
provenance: predates provenance tracking; regenerate to populate generated-by / model / harness
-->

# Skill Authoring

Author, audit, or explain Claude Code skills - decide the mode first, then follow the matching
sections below. `references/skills.md` (synced from this repository's `docs/features/skills.md`) is
the source of truth for the skills-architecture facts used throughout this file; load it before
answering architecture questions or auditing/authoring skills.

This skill owns skill-system questions and `SKILL.md` authoring/audit concerns. For general
Markdown proofreading of arbitrary `.md` files, defer to `review-md` instead.

## Run judgment-heavy passes at the Opus tier

This skill is pinned `model: opus` because authoring and auditing decisions are judgment-heavy, so
the guidance survives a harness that drops the pin: dispatch the two non-interactive heavy passes -
the audit pass (Audit mode) and the tool-probing and overlap/collision analysis (Create / targeted
fix's Research steps 2-3) - to an Opus-tier subagent (a `Task`/`Agent` subagent with
`model: opus`). Keep the interactive intake and the frontmatter/layout decisions in the main
thread - they are rule-guided by this file, so they hold at the session model - and if a complex
authoring job needs deeper reasoning, ask the user to select a stronger model.

## Decide the mode

Determine the mode from `$ARGUMENTS` and conversation context before doing anything else. If it's
ambiguous which mode applies, ask once rather than guessing.

| Mode | When | Behavior |
| --- | --- | --- |
| Q&A | No create/audit/fix intent - empty `$ARGUMENTS`, or a question about skills architecture, frontmatter, budgets, progressive disclosure, etc. | Read `references/skills.md`, answer from it, stop. Do not create or edit skill files. |
| Audit | User asks to audit, check, or review existing skills' triggers/frontmatter/budget/layout (optionally scoped to personal, project, or a path) | Follow the audit checklist below; report findings with path references. Do not invent new skills or apply fixes unless the user then asks. |
| Create | User asks to create, author, or scaffold a skill (or to regenerate one from scratch) | Follow intake through the testing gate below, then hand off to the harness scaffolder for file writes. |
| Targeted fix | User asks to apply specific fixes to an existing skill (e.g. after an audit), or to make a small frontmatter/description/layout edit | Apply only the requested edits directly; do not re-scaffold via the harness scaffolder unless they ask to regenerate. Re-run the relevant testing-gate items after material trigger or argument changes. |

## Q&A mode

Read `references/skills.md` and answer directly from it. If the question needs the absolute latest
platform details beyond what's there, cross-check `https://code.claude.com/docs/llms.txt`. Do not
create, edit, or scaffold anything in this mode.

## Scope

Default new skills to personal scope (`~/.claude/skills/`) - this skill is itself part of the
global bootstrap, so personal is the default context. Only apply the "start project-scoped,
promote later" strategy from `references/skills.md` if the user explicitly asks for a
project-scoped skill.

## Intake (create / targeted fix)

If `$ARGUMENTS` is given, treat it as the initial pitch for what the skill should do. Otherwise,
and for whatever isn't already given, ask the user for:

1. What the skill should do, and a proposed kebab-case name for it.
2. 3-5 example phrases a user would say to trigger it.
3. Whether it performs a destructive/dangerous action (deploy, database change, PR creation, git
   push).
4. Whether it's research-heavy (produces lots of intermediate output).
5. Whether it needs positional/named arguments.
6. Scope: personal (default) or project - only deviate from personal if the user explicitly asks
   for a project-scoped skill.
7. Whether the domain needs a knowledge/action split (see below) - ask this specifically when the
   pitch includes both reference data (mappings, field IDs, conventions) and a side-effectful
   action (create ticket, deploy, send message).

## Research (create / targeted fix)

Before finalizing the brief for the scaffolder, or before applying a targeted fix that changes
behavior, do step 1 directly in this turn - convention-matching needs the example files' exact text,
and a subagent summarizing them would lose that fidelity. Run steps 2 and 3 as an Opus-tier subagent
pass instead (see "Run judgment-heavy passes at the Opus tier").

1. Read 2-3 existing skills in the same scope (personal or project) and match their conventions -
   only match conventions that don't conflict with this file or `references/skills.md`, which take
   precedence.
2. If the skill wraps an external tool or MCP, probe the real tool calls first to discover required
   fields, IDs, and error modes; put the discovered constants in the brief so they land in the new
   skill's `SKILL.md` or `references/`.
3. Check for overlapping existing skills or docs, including name collisions against existing
   personal (`~/.claude/skills/`), project (`.claude/skills/`, searched from the working directory
   upward), and plugin skill names:
   - Taken by an unrelated skill - pause and ask the user to confirm a different name rather than
     picking one without checking back.
   - Taken by what looks like an earlier version of the same skill - ask whether to update it,
     recreate it from scratch, or leave it alone; default to update if the user doesn't say.
   - Overlapping content that isn't a name collision - ask the user how to proceed.

### Why not fork this instead

A fork always inherits the parent's model (see
`${CLAUDE_CONFIG_DIR:-~/.claude}/reference/subagent-orchestration.md`'s "Delegation shape: fork vs.
fresh subagent"), so it cannot substitute for step 2/3's fresh-subagent dispatch: forking would drop
the Opus-tier guarantee this section exists to provide, so the guidance survives a harness that
drops this file's `model: opus` pin. Step 1 solves the convention-matching fidelity problem more
simply, by not delegating that read at all.

## Write the description

Every generated description must:

1. Start with "This skill should be used when the user asks to ..."
2. Include 3-5 exact trigger phrases in quotes
3. Mention relevant file types or keywords
4. End with a brief scope statement

## Format the description as a wrapped block scalar

Write every `description:` as a YAML `|` block scalar, indented two spaces and wrapped to the
width of the surrounding prose - no width is enforced anywhere, and tracked prose in this repo
sits at roughly 95-100 characters:

````
description: |
  This skill should be used when the user asks to ...
  ... "trigger phrase", "another trigger phrase" ...
````

Use `|`, not `>` or a plain single-line scalar:

- A plain scalar is invalid YAML when a colon in it is followed by a space or a line end - a
  strict parser rejects the whole frontmatter. A colon with a non-space after it (`docs/a:b`)
  is fine, so this is narrower than "contains a colon" but still easy to hit: the natural way
  to write a description reaches for `Scope: personal` or `judge: whether`. Claude Code parses
  it leniently today, so the breakage is latent rather than visible, and it stays latent only
  for as long as that leniency does.
- `scripts/health-check.sh`'s `desc_len` handles `|` and the plain form only. A `>` folded
  scalar falls through to its plain-form branch and measures as the single `>` character, so
  an over-budget description would pass the budget check unnoticed.

Never let a line break fall inside a quoted trigger phrase. `|` preserves newlines, so a break
inside the quotes leaves a literal newline mid-phrase, and the phrase the description advertises
is then not the string a user types. Break before the opening quote instead, even when that
leaves a short line. Whether a mid-phrase newline measurably costs fires is untested - this is a
cheap precaution, not a measured effect, and it should not be cited as one.

One tradeoff to know: a `grep`-based one-liner that prints descriptions cannot show a block
scalar in full (see `references/skills.md`). Open the file, or parse the YAML, to read one.

## Check the budget

All skill descriptions share one pool: 1% of the context window (8,000-character fallback),
capped at 1,536 characters per individual description. Check `/context` (post-budget size) or
`/doctor` (cost estimate and biggest contributors) against that before finalizing.

Personal skills load into every project's context, so weigh each new one against a practical
ceiling of about 20-30 well-curated global skills. If near that ceiling, still create the skill,
but flag it to the user and suggest either trimming an existing description or moving a niche
skill to project scope instead.

## Apply frontmatter defaults

Set fields deliberately based on what the skill actually does, not by leaving everything at
default:

| Situation | Field |
| --- | --- |
| Destructive/dangerous action (deploy, DB change, PR creation, git push) | `disable-model-invocation: true` |
| Planning, architecture, designing multi-agent plans, or judgment-heavy (e.g. security) review | `model: opus` |
| Implementation, generation, tests, routine/checklist review, or synthesis-heavy search | `model: sonnet` |
| Mechanical formatting/grep or fully prescribed edits | `model: haiku` |
| Research-heavy, produces lots of intermediate output | `context: fork` plus `agent: Explore` (read-only), `agent: Plan`, or `agent: general-purpose` |
| Background knowledge Claude should auto-invoke but shouldn't clutter the `/` menu | `user-invocable: false` |
| Needs validation/setup logic tied to invocation | `hooks` |
| Should always/never touch a specific tool without a prompt | `allowed-tools` / `disallowed-tools` |

Model tiers follow this environment's own "Subagents & Models" policy where one is defined (see
`CLAUDE.md`); use the table above as-is otherwise.

A skill's `model`, `context`/`agent`, `user-invocable`, `hooks`, and
`allowed-tools`/`disallowed-tools` frontmatter fields are honored by Claude Code. Also encode any
guarantee that must hold regardless directly in the skill's body - a model tier via subagent
dispatch, research isolation via a dispatched read-only subagent - so the guidance survives a
harness that drops the pin; use `disable-model-invocation` for the manual-only case.

## Follow the decision rule

Every line planned for a skill body must answer yes to: does this name a specific tool, command,
path, constraint, or step the agent would get wrong without it? Drop philosophy, motivation, "Why
use this?" sections, and vague guidance. Lead with exact steps; put examples last. Prefer
`SKILL.md` under 500 lines (Anthropic guidance); move conditionally needed material to
`references/`.

## Plan the layout

Keep in `SKILL.md` only what's needed on every invocation (core workflow, constants). Split:

- Language-specific patterns and deep-dive docs to `references/`
- Templates and samples to `examples/`
- Helper scripts to `scripts/`

Supporting files under `references/`, `examples/`, and `scripts/` must not carry their own
`name`/`description` frontmatter - that wastes description budget and confuses discovery.

Include created/updated timestamps as an HTML comment immediately after the frontmatter block:

````
<!--
created: YYYY-MM-DD
updated: YYYY-MM-DD
-->
````

## Consider a knowledge/action split

When a domain has both reference data (mappings, field IDs, conventions) and side-effect-heavy
actions (create ticket, deploy, send message), prefer a paired design over one mixed skill:

| Role | Frontmatter | Trigger | Purpose |
| --- | --- | --- | --- |
| Knowledge | `user-invocable: false` | Auto-triggers on domain keywords | Injects or points at reference data without cluttering the `/` menu |
| Action | `disable-model-invocation: true` | Manual `/slash` only | Runs the destructive or side-effectful workflow |

Share one `references/` source of truth between the pair. If the user wants a single combined
skill instead, warn about the tradeoff (auto-trigger vs accidental side effects) and proceed only
if they confirm.

## Audit checklist (audit mode)

Dispatch this pass to an Opus-tier subagent (see "Run judgment-heavy passes at the Opus tier"),
having it return findings with path references. For each `SKILL.md` in scope, check and report:

- Description follows the 4-part pattern; trigger phrases are specific enough to distinguish from
  siblings
- Description is a wrapped `|` block scalar (not a plain or `>` scalar), and no line break falls
  inside a quoted trigger phrase. Check the YAML strictly rather than by eye - a plain scalar
  fails once a colon is followed by a space or a line end:
  `python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]).read().split("---")[1])' <f>`
- Destructive/side-effect skills set `disable-model-invocation: true`
- Research-heavy skills use `context: fork` (not `forked`) paired with an explicit `agent` value
- Supporting files do not declare `name`/`description` frontmatter
- Every substantive line passes the decision rule above; `SKILL.md` stays under ~500 lines where
  practical
- Description budget pressure: too many long personal-skill descriptions competing for the 1% pool
- Field names/values match `references/skills.md` (and official docs via
  `https://code.claude.com/docs/llms.txt` if unsure)

Do not invent new skills or apply fixes during an audit - report findings only, unless the user
then asks for a targeted fix.

## Hand off to the skill scaffolder (create / regenerate)

Once name, description, frontmatter, scope, and layout are all decided, hand the whole thing to the
skill scaffolder as a structured brief, including any knowledge/action-pair plan: invoke
`Skill(skill-creator)`. The scaffolder owns the actual file writes and skill-creator's built-in
eval framework (test cases, automated grading, benchmarking, description-tuning) for anything
warranting more rigor than the testing gate below. Do not `Write` or `Edit` the new skill's files
directly in create mode.

Targeted-fix mode is the exception: edit the existing skill's files in place for the requested
changes only - do not re-scaffold via the scaffolder unless the user asks to regenerate.

## Test before reporting done (create / targeted fix)

Do not report a newly authored or regenerated skill as finished until all of the following have
actually been run and observed, not assumed. For a targeted fix, re-run only the items affected by
the change (e.g. skip the argument test if arguments weren't touched):

1. Auto-trigger test - a natural prompt matching the intended trigger conditions
2. Manual test - `/skill-name` directly
3. Negative test - an unrelated prompt, confirming it does not accidentally fire
4. Argument test (if applicable) - `/skill-name some args`, confirming `$ARGUMENTS` substitution
   works

Q&A and audit-only modes skip this gate entirely - end those with a concise answer or findings
summary instead.

## Load it

If you can run `/reload-skills`, do so; otherwise pause and ask the user to, so the new or edited
skill is loaded and ready for the testing gate above.

## Finish with a summary

Report the mode used, what was created, changed, or found (name, scope, path), the frontmatter
decisions and why, and the outcome of each testing-gate check (or the findings list, for Q&A/audit
modes).
