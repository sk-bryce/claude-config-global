---
created: 2026-07-24
updated: 2026-08-31
---

# Document Generation and Source Verification

Read this before ending any generated Markdown output - a file, a report, or a plain chat response - that draws on a web page or a document consulted as a source. It covers what counts as an external source, the References section format, how to verify a link actually works, and what to do when one doesn't.

## Scope

Applies whenever the output draws on a source outside the content being produced:

- Web pages: search results, fetched documentation, articles.
- Documents or files consulted as supporting material, whether inside this repository (another `./docs/` or `./reference/` file) or truly external (another repo, a PDF, a non-project doc).

Excludes the actual code or file being read/edited as the direct subject of the current task - that uses the harness's inline code-citation convention instead, not a References entry. A markdown file consulted as supporting material is a citation; the file being modified is not. The distinction is role (source vs. subject), not location (this repository vs. elsewhere) - a same-repository reference file cited as a source still belongs in References, exactly like this file's own "Further Local Reading" entries below.

If, and only if, at least one such source was actually used, end the output with a References section (see format below). Omit the section entirely otherwise - an empty or contentless References heading is worse than no heading at all.

## References Section Format

Two tiers. Default to the first; only reach for the second when it earns its own complexity.

**Tier 1 (default).** A flat bullet list, ordered by first appearance, no grouping, no inline `[1]`/`[2]` markers. Always use this tier for chat-only responses and typical one-off reports:

```markdown
## References

- [Title of page or document](https://example.com/path)
- [Another source title](https://example.com/other)
```

**Tier 2 (substantial reference documents only).** Group entries by genuinely distinct category (for example "Official Documentation", "Research", "Further Local Reading"), each followed by a short attribution or description after a hyphen. Cite a same-repository or other local file with a bare backtick path, not a markdown link, since there is no URL to point to:

```markdown
## References

### Official Documentation

- [Page title](https://example.com/path) - Publisher; what it covers.

### Further Local Reading

- `docs/research/some-file.md` - what it covers.
```

Use Tier 2 only when the document already has two or more genuinely distinct source categories and is meant to be a durable reference, not a one-off answer - see `context-file-authoring.md`'s own References section for a live example already following this convention. Forcing categories onto two or three miscellaneous links adds structure without adding clarity.

Use a `##`-level heading, or whatever level sits alongside the document's other major sections; for a heading-free chat response, a bold `**References**` label is enough.

## Verification

Every listed link must be confirmed working before it is included, regardless of tier:

- A link already fetched successfully earlier in the same session (for example opened via WebSearch or WebFetch while researching) counts as verified - do not re-fetch it just to compile the list. A link that only appeared in search-result snippets, without being opened, does not count as fetched.
- Any link reaching the list without a prior successful fetch this session (a URL supplied by the user, or found but never opened) must be explicitly fetched and confirmed before it is included.
- A citation to a local or external file rather than a URL is "working" once its existence and readability are confirmed.
- "Same session" means this conversation only. Do not assume a link fetched in an earlier, separate session is still good.

Not every failure means the resource is actually gone:

| Signal | Treat as | Why |
| --- | --- | --- |
| 404, DNS failure, connection refused | Broken | The resource is actually gone or never existed |
| 403, 429, or other bot-protection/rate-limit response | Inconclusive, not broken | May still work for a human browser; MDN's own 403 page notes servers sometimes send 403 in place of 404 for access-restricted resources, so a 403 does not confirm absence either (see References) |
| 3xx redirect that resolves | Working | Follow the redirect; the destination is what matters |
| Timeout or tool error unrelated to the resource itself | Inconclusive; retry once | Distinguish tool/network flakiness from an actually-dead resource before concluding anything |

## On a Broken or Inconclusive Link

Try once to find an alternative working source for the same claim. If none exists, drop the link and add a short note that a source could not be verified - never drop it silently. The alternative must actually support the original claim; if it doesn't, drop the citation rather than keep a link by loosening what the claim says.

## Mechanism

- **Agent-side.** Apply the rules above whenever generating content. This is the only part that covers chat-only responses that are never written to a file. `CLAUDE.md`'s Output Formatting section points here.
- **Complementary hook.** A non-blocking hook re-checks the links in any `*.md` file's References section, reporting (not blocking on) failures - a mechanical safety net alongside the agent-side rule, intentionally redundant with it. It runs at the end of the agent loop, not on each edit: a recorder on the file-edit event notes which `*.md` files changed, and a stop-event drain then checks each distinct file once. Serial link checks at up to 10s each are too expensive to pay per edit. See `specs/behaviors.md`'s "Deferred Markdown Checks" for the recorder/drain pair and `skills/cursor-projection/references/harness-matrix.md`'s Hooks section for the per-harness event names.
- **`review-md`.** Keeps its own synced `references/document-generation.md` copy (mirroring how `skill-author/references/skills.md` is synced from `docs/features/skills.md`), loaded before checking links during a review. This is what catches link rot in documents nothing has touched since they were written; the hook above only re-fires after a turn that edited the file.

## Red Flags: Stop If You're About To

- Cite a URL that only appeared in a search-result snippet without opening it.
- Drop a source solely because it returned 403 or 429, without considering it might just be bot-blocked.
- Add an empty `## References` heading when nothing external was actually used.
- Force Tier 2 categorization onto two or three miscellaneous links.
- Swap in an alternative source that doesn't actually support the original claim, just to keep a citation.
- Cite this project's own code being edited as if it were an external source, instead of using the inline code-citation convention.

## References

### Official Documentation

- [403 Forbidden](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/403) - MDN; notes servers may send 403 or 404 interchangeably for access-restricted resources.
- [404 Not Found](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/404) - MDN; "broken or dead links" and link-rot terminology.
- [RFC 6585: Additional HTTP Status Codes](https://www.rfc-editor.org/rfc/rfc6585.html) - IETF; defines 429 Too Many Requests (section 4).
- [Automate actions with hooks](https://code.claude.com/docs/en/hooks-guide) - Anthropic; PostToolUse hook mechanics used by the mechanism above.

### Further Local Reading

- `reference/context-file-authoring.md` - the sibling reference this file's structure and References-section conventions (including Tier 2) are modeled on.
- `skills/skill-author/SKILL.md` - the source of the synced-reference-copy pattern used for `review-md` under Mechanism above.
