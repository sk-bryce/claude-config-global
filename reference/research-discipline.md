---
created: 2026-08-10
updated: 2026-09-01
---

# Research Discipline for Documentation-Generation Tasks

Read this before starting a research-heavy documentation-generation task - gathering external
material via WebSearch/WebFetch and writing it up as one or more Markdown files. It covers the
incremental workflow, the usage-utilization check, and how to choose between doing the work
inline, forking it out, or dispatching a dedicated subagent.
`decisions/0008-avoid-parallel-research-fanout.md` is the incident and rationale this file
operationalizes; this file is the protocol itself.

## Scope

Applies to a task shaped like "research X and write it up" that involves external sourcing -
typically producing a new multi-file `docs/<topic>/` directory or a substantial single document.
Does not apply to a quick single-fact lookup (a plain WebSearch call answers it directly, no
workflow needed) or to reviewing/editing already-written content (`review-md`).

## Default: do the work inline

Do the research and writing directly in the current context - do not delegate by default. Most
documentation-generation tasks fit comfortably in the context already doing the work, and every
delegation option below costs something (a cache-write, an inherited-context cache-read, or a
narrower tool surface to work around) that inline work does not.

## Choosing a delegation shape, when isolation is genuinely warranted

Delegate only when a topic's own raw research output would flood the current context. When it
would, choose among these in order:

1. **Parallel `Agent` forks (`subagent_type: "fork"`), for genuinely independent sub-topics.**
   A fork inherits the current conversation and shares its already-warm cache, so each parallel
   branch pays a cheap cache *read* for the shared prefix instead of a fresh cache *write* for
   its own copy of the system prompt and tool definitions. This is the default choice for
   fanning a topic out into several independent questions (for example, one sub-topic per
   language or per framework family) - cache read is cheap enough relative to cache write that,
   on cost alone, a fork does not lose to a fresh subagent regardless of how much the session
   carrying it has accumulated (worked through in `decisions/0008-avoid-parallel-research-
   fanout.md`'s Context section). A fork always runs on the parent's model and inherits the
   parent's full tool access, so it carries none of a dedicated agent's narrower contract - see
   option 2 when that narrower contract is the actual requirement.
2. **The `researcher` subagent (`agents/researcher.md`), for a single topic needing a stable,
   narrow contract.** Choose this over a fork when the isolated work should not carry the
   calling context's full history and tool access - it has no `Agent`/`Task` tool itself, so it
   cannot fan out further, and it starts cold with a fixed, minimal briefing instead of
   inheriting whatever the calling conversation happened to accumulate. This is a scope
   decision, not a cost one - session size alone is not a reason to prefer it over a fork.
   Dispatch it one topic at a time; running several in parallel reproduces the cold-start
   multiplication problem this file exists to avoid, just with a different tool.
3. **Never a skill's own `context: fork` for this purpose.** That frontmatter field dispatches
   to a cold-started agent context (see `docs/features/skills.md`'s `context: fork` entry and
   `specs/skills.md`'s `review-md` section, which documents it explicitly as a "cold-start
   fork") - it does not share the calling conversation's cache the way an `Agent`-tool
   `subagent_type: "fork"` does. The two mechanisms share a name and nothing else; do not
   substitute one for the other when the point is cache-sharing.

## Work incrementally

1. Write a skeleton or outline first - the file(s) you intend to produce, headings only, or a
   short paragraph per planned section - before writing full content for any of it.
2. Fill in one section (or one file, for a multi-file topic) at a time.
3. After each section, update a progress file (`PROGRESS.md` alongside the output, or whatever
   the task names) recording what's done, what's next, and any open question or source to
   revisit. Keep it short - a resumption aid, not a deliverable. This is what lets work stop
   and resume cleanly, whether from a usage halt (below), an interruption, or a fresh dispatch
   of `researcher` picking up where a prior one left off.
4. Prefer several smaller WebSearch/WebFetch passes with synthesis in between over one large
   batch of fetches followed by a single writing pass.

## Usage-utilization check

Before starting substantial work (more than a few tool calls expected), and periodically as you
go (roughly every few sections, or before a noticeably larger fetch), check the account's
rate-limit utilization:

```bash
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
token="$(jq -r '.claudeAiOauth.accessToken // empty' "$config_dir/.credentials.json" 2>/dev/null)"
if [[ -n "$token" ]]; then
  curl -s --max-time 5 --connect-timeout 3 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" \
    | jq '{five_hour: .five_hour.utilization, seven_day: .seven_day.utilization}'
fi
```

This mirrors `scripts/statusline.sh`'s own fallback fetch for when no `rate_limits` payload is
available on stdin (see that script's header comment around its `oauth/usage` call) - useful
here because a dispatched subagent has no statusline hook of its own and this direct query is
its only way to see utilization.

- Absent a caller-set threshold, stop at 90% utilization on either window (`five_hour` or
  `seven_day`).
- If the check fails (no token, network error, unexpected response shape), do not treat that as
  a green light - note the failure and continue conservatively (smaller passes, check again
  sooner) rather than assuming headroom you could not confirm.
- On crossing the threshold: stop before the next section or fetch, update the progress file
  with exactly where you stopped, and report that plainly rather than truncating output to look
  finished.

## Mechanism

- **Agent-side.** Apply the workflow above whenever doing research-heavy documentation-
  generation work inline. `CLAUDE.md`'s Subagents & Models section states the decision and points
  at `reference/model-selection.md`, whose Research fan-out section points here.
- **`agents/researcher.md`.** Reads this file at the start of a dispatch rather than duplicating
  its content, so the two cannot drift apart; adds only agent-specific material (its tool
  contract, its output-report format) on top.
- **`skills/research`.** Keeps a synced copy under `skills/research/references/
  research-discipline.md` (mirroring how `review-md` syncs `reference/document-generation.md`),
  loaded on invocation - this is what carries the workflow into whichever context actually does
  the work, inline or forked, since a skill's own instructions load into its caller's context by
  default (no `context: fork` - see the note in "Choosing a delegation shape" above for why that
  field would be the wrong choice here).
- **`reference/subagent-orchestration.md`.** Its Delegation shape section points here for the
  fork-vs-dedicated-subagent choice specifically in the research-fan-out case, as a special case
  of the general fork-vs-fresh-subagent guidance it already covers.

## Red Flags: Stop If You're About To

- Fan out several fresh (non-forked) subagents in parallel for independent research sub-topics
  when a parallel `Agent` fork would have done the same job for a fraction of the cache cost.
- Dispatch more than one `researcher` subagent concurrently for what could be sequential or
  in-context work.
- Use a skill's `context: fork` expecting it to share the calling conversation's cache - it is a
  cold start, not a continuation.
- Keep working past a confirmed 90%+ utilization reading without stopping to report.
- Batch a large number of fetches before writing anything, leaving no clean point to resume from
  if interrupted.

## References

- `decisions/0008-avoid-parallel-research-fanout.md` - the measured incident and rationale this
  file operationalizes.
- `scripts/statusline.sh` - source of the OAuth-usage-endpoint fallback mechanism the
  usage-utilization check above reuses.
- `docs/features/skills.md` - `context: fork` entry, source of the cold-start-vs-cache-sharing
  distinction in "Choosing a delegation shape."
- `specs/skills.md` - `review-md` section, which documents its own `context: fork` pin as an
  explicit "cold-start fork" choice, corroborating the distinction above.
- `reference/document-generation.md` - modeled structure and the synced-reference-copy pattern
  this file's own "Mechanism" section follows.
