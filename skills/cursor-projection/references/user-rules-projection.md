---
created: 2026-08-24
updated: 2026-09-02
---

# User Rules Projection

Procedure for generating a Cursor User Rules blob from `CLAUDE.md`'s global sections: a
paste-able blob a human copies into Cursor's Settings > Rules > User Rules panel. Follow this
whenever regenerating that blob. `harness-matrix.md` (sibling of this file) is the harness fact
base this procedure leans on for what's actually true of Cursor; point back to it rather than
restating a harness fact independently.

## Source and purpose

The source is `CLAUDE.md`'s global sections: Canary, Compact Instructions, Skills, Working
Style, Output Formatting, Git & GitHub, and Subagents & Models.

Cursor reads no file under `~/.claude` as global instructions. Its only global mechanism is User
Rules in the Settings UI, which is cloud-synced and cannot be installed from a committed file - a
human has to paste the content in by hand. This procedure exists to give that paste something
faithful and repeatable to copy from: a rewrite of `CLAUDE.md`'s global sections into text a
Cursor-only audience can act on directly, generated fresh from the source each time rather than
kept as a stored file.

## Exclusion: Repository Maintenance

`CLAUDE.md`'s "Repository Maintenance" section never projects, in whole or in part. It is scoped
to the `~/.claude` config repo itself, and both harnesses already reach it project-side without
this projection: Claude reads `~/.claude/CLAUDE.md`, and Cursor reads the repo-root `CLAUDE.md`
natively. Projecting it into global User Rules would apply its
"when the working directory is a git checkout of this config repository" scoping globally
instead of only in this repo - redundant at best, misleading at worst.

## Neutralization rules

Apply every one of these on each regeneration; none is optional.

- **Strip Claude-only tool and command mentions.** Remove parentheticals and asides written for
  a Claude reader: the Skill tool, `/context`, `/doctor`, `/compact`-style command names, and any
  `~/.claude/reference/*`-style pointer whose surrounding prose addresses a Claude reader.
- **Rewrite "Subagents & Models" for a Cursor-only audience.** Drop the `model:`
  frontmatter-pin guidance entirely (Cursor ignores that field). Keep the tier philosophy: Sonnet
  as the default, the Opus/Haiku fit criteria, the escalation ladder, and the dispatch guidance.
  Rename the heading so it doesn't imply skill-frontmatter mechanics (for example "Subagents and
  Models"). Drop the Effort bullet in full - `/effort`, the `/model` slider, `claude --effort`,
  `max`, `ultracode`, and `ultrathink` are all Claude Code-specific with no Cursor equivalent, so
  neutralizing that bullet leaves nothing behind. That section also points at
  `reference/model-selection.md`; do not chase the pointer to bulk the projection back up, since
  what it holds beyond the inline rules is the same Claude Code-specific effort and
  delegation-shape mechanics.
- **Retitle "Compact Instructions."** Give it a harness-neutral heading (for example "Context
  Preservation") rather than projecting the heading verbatim - "Compact Instructions" is a
  Claude Code-recognized convention tied to a documented mechanism, with no confirmed Cursor
  equivalent. Reword the trigger condition in Cursor's own terminology (automatic summarization,
  `/summarize`, its `/compress` alias - not `/compact`). State any claim about a rule surviving
  summarization using only what's confirmed for Cursor specifically, which is narrower than
  what's confirmed for Claude Code (see
  `decisions/0006-global-config-compaction-verification.md`), rather than reusing Claude Code's
  hedge unexamined.
- **Reflow dangling bullets.** When removing a Claude-only clause leaves the rest of a bullet
  reading awkwardly or pointing at a clause that isn't there, rewrite the whole bullet so it
  reads naturally on its own, rather than leaving a fragment.
- **Keep repo pointers as literal, absolute `~/.claude/...` paths.** Every pointer into the
  config repo stays a literal absolute path in the projected text - for example
  `~/.claude/decisions/0006-global-config-compaction-verification.md` or
  `~/.claude/skills/cursor-projection/references/harness-matrix.md` - even though `CLAUDE.md`
  itself uses bare-relative pointers under its own "Path Conventions" section. The two documents
  sit in different resolution contexts: a bare-relative pointer in `CLAUDE.md` resolves against
  the directory holding that file, which the harness names when it loads the content, so the
  bare form stays correct under any `CLAUDE_CONFIG_DIR` profile or machine. The projected blob
  has no such directory ever named for it - it is pasted text living inside Cursor's
  cloud-synced User Rules setting, with no file location behind it, and Cursor has no
  `CLAUDE_CONFIG_DIR`-equivalent variable to spell instead. Absolute `~/.claude/...` is the form
  that resolves correctly with no surrounding file context, which makes it the correct choice
  here, not a portability gap to close.
- **Paraphrase everything else faithfully.** Skills, Working Style, Output Formatting, Git &
  GitHub, and Canary carry over as the same rules and the same intent, in harness-neutral
  wording, even where no neutralization rule above applies to them specifically.

## Review step

There is no automated eval for this artifact - it is a prose paraphrase of another file, not a
testable behavior. Review it by reading the freshly generated blob directly
against the current `CLAUDE.md`'s global sections, section by section, confirming every rule
maps and every neutralization rule above was actually applied. This is a fresh read against the
live source each time, not a diff against a stored earlier version of the projection.

## Acceptance criteria

- Every rule in `CLAUDE.md`'s global sections (Canary, Compact Instructions, Skills, Working
  Style, Output Formatting, Git & GitHub, Subagents & Models) has a corresponding rule in the
  generated blob, in substance if not identical wording.
- The "Repository Maintenance" section does not appear, in whole or in part.
- No Claude-only tool name, command, or file path (the Skill tool, `/context`, `/doctor`,
  `/compact`, a `~/.claude/reference/*` pointer whose surrounding prose addresses a Claude
  reader) appears anywhere in the projected text. This bans the Claude-only audience, not the
  absolute path form itself: an absolute `~/.claude/...` pointer written for a Cursor reader is
  correct and expected.
- The "Subagents and Models" section reads coherently as Cursor-only guidance, with no dangling
  reference to a `model:` frontmatter pin.
- The retitled Compact Instructions section does not use the verbatim heading, and its trigger
  condition and any rule-survival claim are stated in Cursor's own confirmed terms rather than
  carried over from the Claude Code source unchanged.
- No bullet reads as a fragment or points at a clause that isn't there.
- The file's own instructions-for-use section (how to reach Settings > Rules > User Rules, the
  paste-below-this-line marker) is present.

## Instructions for use (carry into the generated file)

The generated blob needs its own short usage note above the pasted content, so a human opening it
later knows what to do with it without reading this procedure. A suggested scratch filename for
the generated output is `cursor-user-rules.md`:

1. Open Cursor: Settings > Rules > User Rules.
2. Replace the contents with everything below a `--- paste below this line ---` marker.
3. Regenerate from `CLAUDE.md` rather than hand-editing the two independently.

## References

- `harness-matrix.md` - the harness fact base this procedure leans on: Instructions delivery
  (why Cursor has no file-based bridge), Context compaction / summarization (the Compact
  Instructions retitling rationale), and Model tiers (the Subagents and Models rewrite).
- `decisions/0006-global-config-compaction-verification.md` - why the retitled section's
  rule-survival claim can't just reuse Claude Code's hedge.
