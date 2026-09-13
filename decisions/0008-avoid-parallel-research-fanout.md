---
created: 2026-08-10
updated: 2026-08-31
---

# 8. Avoid parallel research fan-out for documentation-generation tasks

- Status: Accepted
- Date: 2026-08-10
- Deciders: repository owner
- Related: `CLAUDE.md` (Subagents & Models), `reference/subagent-orchestration.md` (Delegation
  shape), `reference/research-discipline.md`, `specs/agents.md` (researcher section),
  `agents/researcher.md`, `specs/skills.md` (research section), `skills/research`,
  `decisions/0004-document-generation-as-always-on-rule.md`

## Context

Two local Claude Code sessions generated a multi-file documentation set under `docs/`:
`docs/tui-ux/` (2026-08-08) and `docs/cyberdecks/` (2026-08-10). The repository owner noticed
the first used far more of the account's usage limit than the second and asked for the cause
and any repeatable strategy.

Reconstructing both sessions' local transcripts (each session's own `*.jsonl` under this
machine's Claude Code projects directory and, for tui-ux, its `subagents/*.jsonl` sidechains)
found:

| | tui-ux (first) | cyberdecks (second) |
| --- | --- | --- |
| Output | 13,626 words / 7 files | 7,004 words / 7 files |
| Research method | 5 parallel `Agent` dispatches (fresh `general-purpose` subagents), one per subtopic, each running its own WebSearch/WebFetch | Direct WebSearch (18x) / WebFetch (9x) in the main thread; no subagents dispatched |
| Progress tracking | `TaskCreate`/`TaskUpdate` only | `TaskCreate`/`TaskUpdate` plus a written `PROGRESS.md` |
| Combined tokens (main + subagents where applicable) | in 170,122 / out 302,309 / cache-write 1,590,566 / cache-read 19,854,128 | in 9,759 / out 110,323 / cache-write 320,365 / cache-read 11,364,464 |

Claude Code does not log a per-session dollar figure or the account's historical five-hour/
seven-day utilization at a past point in time, so the two sessions' relative cost is
approximated here by weighting each token category with Anthropic's published Sonnet price
ratios (input 1x, output 5x, 5-minute cache write 1.25x, cache read 0.1x, all relative to
input) - the same signal the account's utilization meter is understood to be built from, even
though the absolute numbers below are a proxy, not the historical statusline reading itself.

- tui-ux (combined, including all 5 subagents): weighted cost approximately 2.7x cyberdecks'.
- Even normalized per word of final output (tui-ux produced ~1.95x the words), tui-ux still
  cost approximately 1.4x more per word than cyberdecks - the fan-out tax survives adjusting
  for the larger deliverable.

Root cause: for tui-ux, the assistant unilaterally chose to fan out 5 parallel research
subagents (nothing in the user's prompt requested that shape). Each fresh subagent starts
cold - it re-pays the system-prompt and tool-definition tokens as a cache miss, and none of
the 5 shared a cache with each other or with the parent session. That is what drove
cache-write to roughly 5x cyberdecks' figure and combined cache-read to roughly 1.7x, despite
comparable per-topic research depth.

For cyberdecks, the user's prompt explicitly said: "Build the skeleton first, work
incrementally, and track your progress carefully... Be careful about how much you
parallelize the work because of usage limits - check usage limits with statusline, and stop
if usage exceeds 90%." The session complied by doing research directly, writing a skeleton
first, and tracking progress in `PROGRESS.md`; it also queried the account's OAuth usage
endpoint directly (`GET https://api.anthropic.com/api/oauth/usage`, bearer token read from
`$CLAUDE_CONFIG_DIR/.credentials.json`) at a few checkpoints, mirroring `scripts/
statusline.sh`'s own fallback fetch for when no `rate_limits` payload is available on stdin.
That single per-session instruction is the entire explanation for the discrepancy - nothing
about the topic (TUI UX vs. cyberdecks) required the difference in method.

Two findings follow from that reconstruction, and the Decision below reflects both.

**Parallelism itself was not the problem; its shape was.** Had the 5-way fan-out used
`Agent`-tool forks (`subagent_type: "fork"`) instead of fresh `general-purpose` subagents, each
branch would have inherited the current conversation and its already-warm cache, paying a cheap
cache *read* on the shared prefix instead of independently paying a fresh ~220K-token cache
*write* for a from-scratch system prompt and tool catalog. The Agent tool's own guidance already
recommends exactly this ("if research can be broken into independent questions, launch parallel
forks... it inherits context and shares your cache"). tui-ux's fan-out happened early in a
freshly-cleared session, when the inherited context a fork would have carried was still small,
so forking would likely have avoided most of the cost blowup. The rule this record adopts is
therefore narrower than "avoid parallel fan-out": default to inline work over delegating at all,
and when independent parallel research fan-out is genuinely warranted, prefer forks over fresh
subagents, reserving a fresh, narrowly-scoped subagent for the cases forking handles poorly.

**Session size is not a valid trigger for reaching past a fork.** Working through the pricing
model above algebraically (cache read at 0.1x input, cache write at 1.25x input) shows a fork's
cost overtakes a fresh subagent's only once the inherited session context exceeds roughly 12.5x
the fixed system-prompt/tool payload a fresh subagent would otherwise cache-write. Using
tui-ux's own measured per-subagent cache-write (~220K-374K tokens) as that fixed cost puts the
crossover at roughly 2.75-4.7 million tokens of inherited context, past any context window a
real session can reach. On cost alone a fork essentially never loses to a fresh subagent, so
"the calling session has already grown large" is not a real cost-based threshold. The
`researcher` subagent rests only on the scope/isolation reason, which does hold up: keeping
isolated work off the calling context's full history and tool access, not session size.

## Decision

Make the working style that produced the cheaper result the default, rather than something
that has to be re-stated per prompt:

1. For research-heavy documentation-generation tasks, default to direct WebSearch/WebFetch
   in the current context. Do not delegate at all unless a topic's raw research output would
   genuinely flood the current context.
2. When isolation genuinely is warranted and a topic breaks into independent sub-questions,
   prefer parallel `Agent`-tool forks (`subagent_type: "fork"`) over fresh subagents - a fork
   shares the orchestrator's already-warm cache instead of paying a fresh system-prompt/
   tool-definition cache write, which is what made tui-ux's fan-out expensive. This is the
   default parallel shape.
3. Add a `researcher` subagent (`agents/researcher.md`, spec'd in `specs/agents.md`) for the
   case forking handles poorly: a need to keep the isolated work off the calling context's full
   history and tool access. This is a scope decision, not a cost one - per the crossover
   analysis in Context, a fork does not lose to a fresh subagent on cost within any reachable
   session size, so session size alone is never the reason to prefer `researcher`. It has no `Agent`
   tool, so it cannot fan out further, and the rule governing it is that it is dispatched at
   most one at a time; running several in parallel would reproduce the exact problem this
   decision addresses with a new tool instead of solving it.
   `CLAUDE.md`'s Subagents & Models section and `reference/subagent-orchestration.md`'s
   Delegation shape section both get a short pointer to points 1-3.
4. Extract cyberdecks' three concrete habits - skeleton-first incremental output, a written
   progress file, and a periodic usage-utilization check (the OAuth endpoint query above) that
   halts and reports rather than continuing once utilization crosses a caller-set threshold
   (default 90%) - into a single canonical protocol, `reference/research-discipline.md`, rather
   than duplicating that prose in `researcher`'s body. That file also holds the decision
   framework from points 1-3 above in fuller form.
5. Add a `research` skill (`skills/research/SKILL.md`) that loads `research-discipline.md`
   into whichever context actually does the work. A `researcher`-only design would carry that
   discipline solely into delegated work, leaving the default inline case uncovered; the skill
   is what closes that gap. The skill deliberately does NOT set `context: fork` in its own
   frontmatter: that field dispatches to a cold-started
   agent context (`docs/features/skills.md`; `specs/skills.md`'s `review-md` section calls its
   own use of it a "cold-start fork" explicitly), not the cache-sharing continuation that
   `subagent_type: "fork"` on the `Agent` tool provides - the two share a name and nothing
   else. Point 2's fork preference is something the skill's body recommends the orchestrator
   do explicitly via the `Agent` tool, not something the skill's own frontmatter can express.

## Consequences

- `CLAUDE.md` carries one short paragraph on this under Subagents & Models.
- `reference/subagent-orchestration.md`'s Delegation shape section carries one short note.
- A reference doc (`reference/research-discipline.md`) is the single source of truth
  for the incremental/progress/usage-check protocol and the inline/fork/researcher decision
  framework, delivered via pointers rather than duplicated, mirroring
  `decisions/0004-document-generation-as-always-on-rule.md`'s delivery pattern.
- A subagent artifact exists (`agents/researcher.md`, trimmed to point at
  `research-discipline.md` rather than duplicating it) alongside its `specs/agents.md` section,
  following the Explore/doc-reviewer/runner/executor convention (there is no agent-authoring
  skill, so it is hand-authored and reviewed, per that file's Shared conventions).
- A skill (`skills/research`) and its `specs/skills.md` section exist, authored via
  `skill-author` conventions, carrying the same discipline into inline and forked work.
- `README.md`'s `agents/` and `skills/` lists each carry one bullet for them.
- Future documentation-generation dispatches default to a cheaper, more predictable cost
  shape without the user needing to restate the cyberdecks-style instruction each time, and
  a genuinely-warranted parallel fan-out defaults to forks rather than fresh subagents. This
  does not prevent a deliberate, user-requested fresh-subagent fan-out when something about
  the task specifically calls for it (see Decision point 3); it changes only the unprompted
  default.
- The weighted-cost figures above are a reconstructed proxy from token counts, not the
  literal historical statusline percentage; if a future comparison needs the literal number,
  it is not recoverable after the fact and must be captured live via the same OAuth usage
  query at the time.

## Alternatives considered

- **Do nothing; rely on remembering to add the cyberdecks-style instruction per prompt.**
  Rejected: this is exactly the gap that produced the tui-ux overrun - an unprompted default
  choice, not a one-off lapse the user could have reliably caught by instruction alone.
- **Rule only, no new agent or skill.** Considered and offered to the user as the lighter
  option. Rejected in favor of also adding `researcher` and `research`: a rule alone still
  leaves the skeleton-first/progress-file/usage-check discipline to be re-derived by whichever
  context happens to do the work, where dedicated artifacts make that discipline the default
  regardless of whether the work stays inline, forks, or delegates to `researcher`.
- **Keep fresh subagents as the default parallel-fan-out mechanism.** Rejected on the first
  finding in Context: forking captures nearly all of a fresh subagent's isolation benefit for
  independent sub-questions, at a fraction of the cache cost, and does not lose that cost
  advantage as the calling session grows within any reachable session size.
- **Trigger `researcher` on a session-size threshold.** Rejected on the crossover analysis in
  Context: the pricing model in this record does not support a cost-based crossover within a
  reachable context-window size, so a size-based trigger would encode a threshold that cannot
  fire in practice. `researcher` is triggered by the scope/isolation reason alone.
- **A general "parallelism budget" setting applied to all subagent dispatch, not just
  research.** Rejected as broader than the observed problem: the two sessions compared here
  differ specifically in research fan-out, and other subagent uses (`execute-plan`'s
  per-unit dispatch, `Explore` fan-out for independent searches) do not exhibit the same
  cold-context multiplication risk at comparable scale, so a narrower fix was preferred over
  a repo-wide policy not backed by an observed incident.

## References

- The tui-ux session transcript and its `subagents/*.jsonl` sidechains, from this machine's
  local Claude Code projects directory - source of the token counts above.
- The cyberdecks session transcript, from the same directory.
- `scripts/statusline.sh` - source of the OAuth-usage-endpoint fallback mechanism reused in
  `reference/research-discipline.md`'s usage-check step (see its header comment around the
  `oauth/usage` fetch).
- `docs/features/skills.md` - `context: fork` entry, source of the cold-start-vs-cache-sharing
  distinction cited in Context and Decision point 5.
- `specs/skills.md` - `review-md` section, which documents its own `context: fork` pin as an
  explicit "cold-start fork" choice, corroborating the distinction above.
