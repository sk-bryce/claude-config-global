---
name: go-dev
description: |
  This skill should be used when the user is writing, editing, reasoning about, or fixing Go
  code - any `.go` file, a `go.mod`, or a Go project - or asks a question naming Go or golang,
  e.g. "write a Go function that ...", "add a worker pool to this service",
  "why is this goroutine leaking?", "wrap this error properly",
  "how should context get passed through here?", "add logging to this Go package",
  "set a timeout on this HTTP client", "this handler returns the wrong status code",
  "this test flakes in CI - what should I look at?", or "I profiled this and there is an
  allocation hot spot - how do I cut it down?". Use it for a Go test that already exists and
  is failing or flaking, and for Go profiling or benchmark output the user brings.
  Loads this user's Go house style (declaration style,
  naming, and zap-with-typed-fields logging) plus on-demand references for concurrency,
  context propagation, error handling, HTTP clients and servers, performance and profiling,
  testing, project and style conventions, and known gotchas, so Go output matches these
  preferences rather than generic idiom. It is guidance, not execution: it does not review a
  diff or a pull request, and does not attach to or debug a live running process. On tests it
  helps with one specific test you already have; writing a package's test suite or raising its
  coverage is bulk generation and is out of scope. It does not proofread Markdown (see
  review-md), and it is for Go only, not the same problem in another language.
  Scope: personal (~/.claude/skills/).
---

<!--
created: 2026-09-19
updated: 2026-09-23
spec: specs/skills.md (go-dev section)
generated-by: skill-author, Opus subagent dispatched from Claude Code main thread
model: claude-opus-5
harness: Claude Code

No `context`/`agent`/`model`/`effort` frontmatter, matching skills/research/SKILL.md and for the
same reason: this skill carries knowledge into whichever context invoked it and must share that
context's already-warm prompt cache. `context: fork` dispatches to a cold-started agent context,
which would defeat the purpose (see decisions/0008-avoid-parallel-research-fanout.md).
-->

# Go Development

House style and domain references for Go. `references/go-style-preferences.md` carries this
user's positions and overrides every other reference file wherever they disagree; load it when
writing or changing Go, and load the domain files below on demand by topic.

## House rules for new Go code

These two rules govern the Go you write. They are inline here, rather than only in
`references/go-style-preferences.md`, because a rule the model must choose to open a file to find
is a rule that does not reliably fire.

Declaration style: prefer explicit `var` declarations. Use `:=` ONLY as part of an
initializer expression in `if`, `for`, `switch`, or a `select` case, where the declared
variable's scope is visibly limited to that statement. Everywhere else, use `var`. Do not
use grouped `var (...)` blocks; write one `var` per line.

Naming: descriptiveness scales with the scope's nesting depth and complexity. Avoid one-
and two-letter names. `ok` (map access, channel receive, type assertion) and `err` (local
error values) are the standing exceptions. Use three- to five-letter names sparingly. The
more nested or complex the scope, the more descriptive the name must be.

The code examples inside the reference files are upstream Go idiom and are exempt from these two
rules by a settled decision; each file says so in a note at the top. Keeping them in upstream form
keeps them comparable to the external Go a reader would cross-check them against. Apply the rules
to new code, not to those examples. When asked about one of those examples directly, say plainly
that it is upstream idiom carried deliberately, rather than defending the line on other grounds.

## Canonical shapes

- Error wrapping with `%w`, plus sentinel errors and `errors.Is`/`errors.As`:
  `references/go-error-handling.md`.
- Table-driven tests with subtests: `references/go-testing.md`.
- `http.NewRequestWithContext` over a bare `Client.Timeout`: `references/go-http.md`.
- A worker pool carrying both error collection and context cancellation:
  `references/go-concurrency.md`.
- `zap` with typed fields as the application logger, with `log/slog` confined to a bridge:
  `references/go-style-preferences.md`.

## Reference routing

- `references/go-style-preferences.md` - declaration style, naming, and the logging position.
  Overrides the files below.
- `references/go-style-conventions.md` - project structure, consumer-defined interfaces, naming
  conventions, type safety, linting.
- `references/go-error-handling.md` - wrapping, sentinel errors, error classification.
- `references/go-concurrency.md` - goroutine ownership, `errgroup`, worker pools, channels, sync
  primitives.
- `references/go-context-patterns.md` - cancellation, timeouts, and the narrow case for context
  values.
- `references/go-http.md` - client construction and server routing.
- `references/go-testing.md` - test organization, table-driven tests, naming.
- `references/go-performance.md` - profile first, then I/O, readers, and buffers.
- `references/go-gotchas.md` - variable shadowing, slice aliasing, and other footguns worth
  recognizing before they bite.

Where a project states its own decision (logging library, structure, lint config), the project
governs and these preferences yield.
