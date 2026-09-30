# Agent instructions

Guidance for coding agents working in this repository. `CLAUDE.md` holds the writing rules; this
file covers the workflow.

## Layout

- `docs/guide.md` is the note-writing guide.
- `docs/notes.md` holds the running notes.
- `scripts/scrub-check.sh` checks files for home-directory paths.

## Workflow

- Always run the full test suite before a commit.
- Keep each commit to one logical change.
- Format files properly before you push.
- Never run tests locally; CI runs them on every push.

## Review

- Ask a docs owner to review any change under `docs/`.
