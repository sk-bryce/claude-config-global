---
created: 2026-07-26
updated: 2026-08-31
---

# 4. Document generation is an always-on rule, not a dedicated skill

- Status: Accepted (wiring landed 2026-07-27; see `specs/behaviors.md`'s Document Generation
  section for current status - this record stays the fixed historical rationale)
- Date: 2026-07-24
- Deciders: repository owner
- Related: `reference/document-generation.md`, `specs/behaviors.md`, `skills/review-md`

## Context

Generating Markdown that draws on external sources needs a consistent References-section
and link-verification policy. The question was whether to implement this as an invoked
skill or as an always-on convention.

## Decision

Treat document generation as universal and always-on rather than invoked on request, so
no dedicated skill is created for it. The full policy (scope, References-section format,
verification rules, broken-link handling) lives in `reference/document-generation.md`,
which is classified as an internally-authored operational protocol (hence `reference/`,
not `docs/`). It is delivered through three pointers to that one file, not duplicated:

1. A `CLAUDE.md` Output Formatting pointer naming the concrete file path.
2. A complementary non-blocking `PostToolUse` hook (logic model-generated and reviewed before
   commit, human registration per ADR 3) that re-checks links after a Markdown Write/Edit.
3. A synced `references/document-generation.md` copy loaded by the `review-md` skill.

## Consequences

- No description-budget cost for a doc-generation skill.
- The buildable wiring (the `CLAUDE.md` pointer, the hook, the `review-md` sync) is
  captured in `specs/behaviors.md`, which carries its build status.

## Alternatives considered

- A dedicated invoked skill. Rejected: the policy should apply to all Markdown output, not
  only when explicitly requested.

## References

- `reference/document-generation.md` - the operational policy this rule delivers.
