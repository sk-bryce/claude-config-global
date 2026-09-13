---
audience: human
created: 2026-07-28
updated: 2026-09-01
---

# Appendix C: Costs and Getting Value

A companion to the rest of the guide, focused on one question: given a task and a quality bar, what is
the cheapest defensible way to hit it? Specific prices change monthly, so this appendix is built
around mechanisms, ratios, and break-even arithmetic rather than a price table. Where a dollar figure
appears it is marked as of this writing (July 2026), cited to the vendor page it came from, and
treated as an illustration. For current numbers, read the provider's own live pricing page.

## In short

- Almost all API pricing is per token, with output priced several times higher than input (roughly 5x
  across the Claude line and 6x across the GPT-5.6 line as of this writing). For anything that
  generates substantial text, output dominates the bill even when the prompt looks large.
- Cost, quality, and speed form a real tradeoff triangle. You can usually buy two. The most common
  expensive mistake is buying quality and speed on a workload that did not need either.
- Four levers do most of the work, in rough order of payback per hour of engineering effort: prompt
  caching, right-sizing the model per step, asynchronous or batch tiers for work nobody is waiting
  on, and simply sending fewer tokens.
- Model routing only pays off when the price gap is wide and the escalation rate is low. With a 5x
  price gap, a cheap-first router wins as long as it escalates less than about 80 percent of the
  time; with a 2x gap the threshold falls to 50 percent, and a badly tuned router costs more than
  always using the expensive model.
- Fine-tuning and self-hosting are real cost levers but neither is free. Both trade recurring per-token
  cost for fixed cost, which only wins above a volume threshold you should calculate before committing.
- Compare providers by estimating a blended cost per completed task on a representative real
  workload, never by comparing headline per-token prices. Tokenizers, reasoning-token billing,
  long-context tiers, and per-call side charges differ enough to invert a naive comparison.

## 1. How generative AI pricing generally works

### 1.1 Tokens are the unit of account

Providers bill for text by the token, not the word or the character, and quote prices per million
tokens (MTok). As a rough English-language estimate, Anthropic's documentation puts one token at about
4 characters or 0.75 words, while cautioning that the true count varies by language and content type
(Anthropic, "Pricing," see References).

Everything that enters or leaves the model counts: system prompt, tool definitions, retrieved
documents, prior conversation turns, tool results fed back into the loop, and the model's own
response. [Chapter 3](../03-prompts-context-memory-and-caching.md) covers what accumulates in a context
window; this appendix covers what that accumulation costs.

Tool definitions are a frequently overlooked line item: Anthropic documents that merely enabling tool
use adds a per-model system prompt of roughly 286 to 804 input tokens before any of your own schemas
are counted, with built-in tools adding hundreds more each (Anthropic, "Pricing," see References).
Small numbers per request, large numbers across a million requests.

### 1.2 Input and output are priced differently

Every major provider charges more for output than for input, because generating tokens one at a time
is a fundamentally different and more serial computation than processing a prompt in parallel
([Chapter 2](../02-models-training-and-inference.md) covers the prefill and decode phases behind this
asymmetry). See [Appendix B](appendix-b-brands-and-providers.md) for what each named model below
actually is and how its vendor positions it. As of this writing the ratio is remarkably consistent:

| Provider | Illustrative output-to-input ratio (as of July 2026) |
| --- | --- |
| Anthropic Claude API | 5x across the current model line (for example Opus 5 at $5/MTok input and $25/MTok output, Haiku 4.5 at $1/MTok and $5/MTok) |
| OpenAI platform | 6x across the GPT-5.6 family (for example gpt-5.6-sol at $5.00/MTok input and $30.00/MTok output) |
| Google Vertex AI | 6x for Gemini 3.1 Pro Preview ($2/MTok input, $12/MTok output) |

Sources: Anthropic, "Pricing"; OpenAI, "Pricing"; Google Cloud, "Agent Platform Pricing" (see
References). Treat the ratio as the durable insight and the dollar figures as perishable.

### 1.3 Why output dominates cost for long generations

The ratio has a direct consequence that surprises people who assume a large prompt means a large
bill. Consider a request with a 2,000-token prompt and a 2,000-token answer at a 5x output premium.
The input contributes 2,000 price units; the output contributes 10,000. Output is 83 percent of the
cost of a request whose prompt and answer are the same length.

The practical rules that follow:

- **Generation length is the most controllable cost variable in most applications.** Asking for a
  300-word summary instead of an unbounded essay often saves more than any caching or routing work.
- **Long-prompt, short-answer workloads are cheap.** Classification, extraction, routing, and scoring
  push nearly all their tokens through the discounted input side, which is exactly where a large
  context is affordable.
- **Short-prompt, long-answer workloads are expensive.** Drafting, code generation, and report writing
  are where the money goes, and where output discipline (`max_tokens` limits, explicit length targets,
  structured formats) pays.

### 1.4 Reasoning tokens are billed as output

Models that produce internal reasoning before answering bill that reasoning at the output rate.
Google's pricing page makes this explicit by labeling the line item "Text output (response and
reasoning)" (Google Cloud, "Agent Platform Pricing," see References). This matters because reasoning
tokens are invisible in your prompt design and often exceed the visible answer in length. A
reasoning-effort or thinking-budget setting is therefore a direct cost dial as well as a quality dial,
and raising it on a high-volume endpoint multiplies the bill without changing a line of your prompt.

### 1.5 Cache reads and cache writes are separate price categories

Prompt caching (mechanism in [Chapter 3](../03-prompts-context-memory-and-caching.md), Section 5) introduces two additional price categories beyond
plain input and output. Anthropic publishes them as multipliers on the base input rate: a 5-minute
cache write costs 1.25x base input, a 1-hour cache write costs 2x, and a cache read costs 0.1x
(Anthropic, "Prompt caching," see References). OpenAI's pricing tables show the same shape, with
cached input at roughly a tenth of standard input and cache writes at 1.25x on the models that
charge for them (OpenAI, "Pricing," see References). Google discounts cached input tokens by 90
percent relative to standard input on Gemini 2.5 and later (Google Cloud, "Context caching
overview," see References).

Section 3.1 works through when this pays off. The structural point is that a cached prompt is not free,
it is repriced, and the write premium means caching loses money if the content is never read again.

### 1.6 Service tiers: standard, priority, flex, and batch

The same model is often sold at several prices, differentiated by latency and delivery guarantee rather
than by capability. As of this writing all three major providers offer a version of this ladder:

| Tier | What you trade | Illustrative multiplier vs standard | Where to use it |
| --- | --- | --- | --- |
| Priority / fast | Pay more for lower and more predictable latency | Roughly 1.8x to 2x (OpenAI Priority; Google Vertex Priority; Anthropic fast mode on Opus 5 and 4.8) | Interactive, latency-sensitive user-facing paths where response time is the product |
| Standard | Baseline | 1x | Default for interactive work |
| Flex | Slower responses and occasional capacity unavailability | Priced at batch rates (OpenAI) | Evaluations, data enrichment, and asynchronous work that still needs a synchronous-style API |
| Batch / asynchronous | Results within a processing window rather than immediately | 50 percent off input and output (Anthropic, OpenAI, Google) | Bulk offline jobs where nobody is waiting |

Sources: Anthropic, "Pricing" and "Batch processing"; OpenAI, "Pricing" and "Flex processing";
Google Cloud, "Agent Platform Pricing" (see References).

Two details matter before you commit to the cheap end of the ladder. Anthropic's Message Batches API
processes most batches in under an hour but guarantees only that results arrive when all requests
complete or after 24 hours, whichever comes first, with unfinished requests expiring unbilled
(Anthropic, "Batch processing," see References). OpenAI's Flex tier can return an unbilled 429
resource-unavailable error when capacity is short, and its 10-minute default SDK timeout is often too
short for flex latency (OpenAI, "Flex processing," see References). Both are manageable, and both
require retry logic you would not otherwise write.

Discounts generally stack: Anthropic documents batch and prompt-caching discounts combining, with the
caveat that cache hit rates inside batches are best-effort and observed between 30 and 98 percent
depending on traffic patterns (Anthropic, "Batch processing," see References).

### 1.7 Subscription tiers for consumer and team products

Chat products are sold per seat rather than per token, and the tier ladder is broadly consistent
across vendors even though the specifics differ. As of this writing:

| Tier | What typically changes | Concrete examples (July 2026) |
| --- | --- | --- |
| Free | Lowest usage allowance, restricted model selection, limited or no access to premium features such as deep research, image generation, or agentic coding | Claude Free covers "everyday questions"; ChatGPT Free has limited messages, uploads, deep research, and Codex access |
| Paid individual (entry) | More usage, access to more capable models, longer memory and context | ChatGPT Go at $8/month and Plus at $20/month; Claude Pro at 5x or more of Free usage per session window; Google AI Pro at 4x higher Gemini usage limits |
| Paid individual (heavy) | Large usage multipliers, priority or research-preview model access, higher output limits | Claude Max at 5x or 20x Pro usage; ChatGPT Pro from $100/month with 5x or 20x Plus rate limits; Google AI Ultra at up to 20x the Pro plan |
| Team / business | Central billing, admin controls, mixed seat types, workspace-level credit pools, no-training-by-default data handling | Claude Team standard and premium seats (premium at 5x standard usage); ChatGPT Business with purchasable workspace credits |
| Enterprise | SSO/SCIM, audit logs, RBAC, retention and residency controls, negotiated terms, and often usage billed separately from the seat | Claude Enterprise at $20/seat/month plus usage billed at API rates; ChatGPT Enterprise flexible pricing where usage scales with credits instead of fixed rate limits |

Sources: Anthropic, "Pricing" (claude.com plans); OpenAI/ChatGPT, "Pricing" (learn.chatgpt.com);
Google One, "Google AI plans" (see References).

Four mechanics matter more than the headline price:

- **Limits are usually windowed, not monthly.** Anthropic documents usage limits that reset on a
  rolling five-hour session window with weekly caps layered on top, drawn from one pool across web,
  desktop, mobile, and Claude Code; OpenAI's published Codex limits are likewise per five-hour window
  with additional weekly limits (Anthropic, "Pricing"; OpenAI/ChatGPT, "Pricing," see References). A
  subscription is a rate allowance, not a quota you can spend in one sitting.
- **There is no fixed message count.** Both vendors state that consumption depends on conversation
  length, model choice, reasoning, tool use, and caching, so identical-looking tasks can consume very
  different amounts of allowance.
- **Overflow routes to metered pricing.** Anthropic lets paid plans enable usage credits billed at
  standard API rates once limits are hit, and OpenAI sells additional credits priced per million
  tokens on a published rate card. The seat price is a floor, not a cap.
- **At the enterprise tier, seat and usage decouple.** When usage is billed at API rates on top of a
  seat fee, every technique in Section 3 applies to your chat deployment too.

For an individual, the decision is usually settled by the metered rate card: if your monthly metered
usage would exceed the seat price, the subscription is the cheaper way to buy the same tokens, plus
the product surface around them.

### 1.8 Committed capacity

Providers also sell reserved throughput, converting variable per-token cost into fixed cost in
exchange for predictable capacity. Google sells Provisioned Throughput in Generative AI Scale Units on
commitments from 1 week to 1 year, with the per-unit rate falling as the term lengthens (Google Cloud,
"Agent Platform Pricing," see References). This only saves money at high, steady utilization; idle
reserved capacity is pure loss, making it the wrong instrument for spiky or still-growing workloads.

### 1.9 Charges that are not tokens

Token math alone understates an agentic system's bill. Real per-call and per-hour charges documented
as of this writing include:

- **Server-side web search:** $10 per 1,000 searches on both Anthropic's and OpenAI's platforms, plus
  token cost for retrieved content. Google's Grounding with Google Search includes 5,000 queries per
  month free, then $14 per 1,000, and one model request may issue several queries.
- **Code execution and container time:** Anthropic gives 1,550 free container-hours per organization
  per month, then $0.05 per hour per container; OpenAI prices hosted containers from $0.03 to $1.92
  per 20-minute session by memory size.
- **Managed agent runtime:** Anthropic's Claude Managed Agents adds $0.08 per session-hour of `running`
  time on top of tokens.
- **Retrieval storage and tool calls:** OpenAI's file search charges $0.10 per GB-day beyond a free
  gigabyte, plus $2.50 per 1,000 tool calls.
- **Data residency and regional routing:** roughly 10 percent uplifts across all three providers for
  US-only or regional endpoints.

Sources: Anthropic, "Pricing"; OpenAI, "Pricing"; Google Cloud, "Agent Platform Pricing" (see
References). The point is not to memorize these but to recognize that a cost model built only on input
and output tokens will be wrong, in the unfavorable direction, for any system that searches, executes
code, or maintains storage.

## 2. The cost, quality, and speed tradeoff triangle

### 2.1 You can generally optimize for two

```
                    QUALITY
                   /       \
                  /         \
       flagship  /           \  flagship
       + batch  /             \  + priority
   (slow, good, /               \ (fast, good,
    affordable)/                 \  expensive)
              /                   \
             /                     \
        COST ------------------------ SPEED
                 small model
                 + caching
              (fast, cheap, weaker
               on hard reasoning)
```

Each edge is a real, purchasable configuration that buys two vertices and gives up the third:

- **Quality plus speed, at a price.** A flagship model on a priority or fast tier. Anthropic's fast
  mode on Opus 5 and 4.8 and OpenAI's Priority tier both sell exactly this, at roughly double
  standard rates (Anthropic, "Pricing"; OpenAI, "Pricing," see References).
- **Quality plus low cost, slowly.** A flagship model on a batch or flex tier at half price, with
  results arriving within a processing window rather than immediately.
- **Low cost plus speed, at lower quality.** A small model. Across the Claude line as of this
  writing, the smallest current model is priced at one fifth of the flagship's input and output
  rates, and small models also generate faster per token.

### 2.2 What the price ladder actually buys

Larger and newer flagship models generally cost more per token, run slower per token, and win on tasks
with long dependency chains: multi-file code changes, ambiguous specifications, subtle reasoning,
adversarial edge cases, and anything where a plausible-but-wrong answer is expensive. Smaller, older,
and distilled models ([Chapter 7](../07-related-and-advanced-topics.md), Section 5 covers quantization and distillation as the mechanisms)
can be dramatically cheaper and faster, and on narrow or easy tasks the quality difference is often
unmeasurable. Vendors say this themselves: Anthropic's cost-optimization guidance is to use the small
model for simple tasks, the mid-tier for most production workloads, and the flagship for the most
complex reasoning, and OpenAI's consumer documentation advises users approaching a usage limit to
switch to a smaller model (Anthropic, "Pricing"; OpenAI/ChatGPT, "Pricing," see References).

### 2.3 Where the cheap model is genuinely the better engineering choice

Right-sizing is not only about money. A small model is preferable, not merely tolerable, when the
task is narrow and well specified (classification into a fixed label set, schema-driven extraction,
format conversion, routing); when latency is part of the user experience, as in autocomplete or live
moderation; when the step is one of many inside a loop, where per-step latency compounds into
unusable end-to-end time; or when output is validated downstream anyway by a schema, a test suite, a
compiler, or a human, so a recoverable error is cheap. Spending flagship money on these tasks buys
nothing measurable, and doing so is the single most common source of avoidable spend in production
LLM systems.

### 2.4 Correctness changes the arithmetic

There is a fourth dimension the triangle hides: rework. A cheap model that needs two attempts plus a
verification pass is not cheap. Before adopting one, measure its task success rate on your own
workload, then compare the expected cost of the full loop including retries against the expensive
model's single-pass cost. Section 5.2 gives the methodology and Section 3.2 gives the threshold
formula.

## 3. Concrete cost-reduction strategies

### 3.1 Prompt and context caching

**Mechanism:** [Chapter 3, Section 5](../03-prompts-context-memory-and-caching.md). Briefly, the
provider retains the computed key-value representations of a stable prompt prefix and reuses them on a
later request that shares that prefix byte for byte, so you pay a small read fee instead of full input
price for the repeated portion.

**Cost impact.** Using Anthropic's published multipliers (0.1x read, 1.25x write for the 5-minute
TTL, 2x write for the 1-hour TTL), caching a prefix reused N times costs `1.25 + 0.1(N - 1)` price
units against N units uncached. That breaks even between the first and second use, which is why
Anthropic's own documentation says the 5-minute cache pays off after a single cache read and the
1-hour cache after two (Anthropic, "Prompt caching," see References).

Worked example, using multipliers only so the arithmetic does not go stale. A 20-turn assistant
session with a stable 30,000-token prefix (system instructions, tool definitions, and a reference
document) resends that prefix on every turn:

| Approach | Prefix cost in base-input-token equivalents |
| --- | --- |
| No caching | 20 turns x 30,000 = 600,000 |
| 5-minute cache | one write at 1.25x (37,500) plus 19 reads at 0.1x (57,000) = 94,500 |

That is roughly an 84 percent reduction on the prefix portion of the bill, before any change to the
prompt itself. It is the highest-leverage, lowest-risk optimization available for most applications,
and it improves latency at the same time.

**When it pays off:** long system prompts, large tool-definition blocks, or few-shot example sets sent
on every request; a document, contract, codebase, or transcript queried repeatedly within a short
window; and multi-turn conversations and agent loops, where the shared prefix grows monotonically and
is therefore increasingly worth caching, not less. Google's documentation names the same cases:
chatbots with extensive system instructions, repeated analysis of long media, recurring queries
against large document sets, and codebase analysis (Google Cloud, "Context caching overview," see
References).

**When it does not:** single-shot requests with no reuse, where you pay the write premium and never
read; prefixes below the provider's minimum cacheable size, documented by Google as 2,048 to 6,144
tokens depending on model family (Google Cloud, "Context caching overview," see References); and
prompts whose early content changes per request, since caching is a prefix match and anything
variable must sit after everything cacheable.

**Implementation note.** Google enables implicit caching by default on Gemini 2.5 and later and
passes savings on opportunistically without a guarantee, while explicit caching guarantees the
discount but adds a TTL-based storage charge (Google Cloud, "Context caching overview"; Google
Cloud, "Vertex AI context caching," see References). Anthropic offers automatic caching via a single
top-level `cache_control` field, or explicit per-block breakpoints for finer control (Anthropic,
"Prompt caching," see References). Start with the automatic or implicit path; reach for explicit
control when you need guaranteed savings or have sections that change at different rates.

**Compaction versus carrying context forward.** Compaction (summarizing and discarding older
context so less gets resent) is a related but distinct decision from the caching pass above:
caching pays a small premium to keep reusing content unchanged, while compaction pays a one-time
premium specifically to stop reusing content unchanged and shrink what gets resent from here on.
The same read and write multipliers make this decision calculable rather than a guess. Model a
session that would otherwise keep carrying a context of `C` tokens forward every remaining turn,
against one that compacts it down to a summary of `S` tokens right now. Compacting costs, once:
rereading the full context at the cache-read rate to produce the summary, plus generating that
summary as output and writing it into the cache going forward. Not compacting costs the
cache-read rate on the full `C` every remaining turn instead. Compacting pays for itself once the
number of turns still left in the session, `N`, exceeds:

```
N > 1 + [S x (write + output)] / (read x C)
```

using the same multipliers as Sections 1.2 and 1.5 above (`read` = 0.1x, `write` = 1.25x for a
5-minute TTL or 2x for a 1-hour TTL, `output` roughly 5x base input across the current Claude
line), and assuming the summary is much smaller than the context it replaces (`S << C`), which
holds for any compaction that is actually doing its job.

Worked example: a session carrying a 100,000-token context that compaction would reduce to a
3,000-token summary, on the 1-hour cache TTL (`write` = 2x):

```
N > 1 + [3,000 x (2 + 5)] / (0.1 x 100,000)
N > 1 + 21,000 / 10,000
N > 3.1
```

Compacting pays for itself, in raw token cost alone, once at least 4 more turns remain in the
session. With fewer turns left, the one-time cost of rereading and resummarizing the context
exceeds whatever carrying it forward uncompacted would have cost over the rest of the session.
This is Section 6's "cache-invalidating micro-optimizations" trap applied to compaction
specifically: compacting a session that is about to end anyway pays the write-and-summarize
premium for savings nobody is left to collect. It also only models token cost, not the quality
risk that a summary drops something a later turn needed; weigh both. `docs/efficient-agentic-use`'s
[Chapter 2](../../efficient-agentic-use/02-turn-session-and-context-discipline.md#structure-work-across-threads-and-sessions)
covers when starting a fresh session beats compacting altogether, and
[Appendix A](../../efficient-agentic-use/appendices/appendix-a-claude-code.md#1-session-and-turn-commands-chapter-2)
covers the Claude-Code-specific environment variables that move the automatic-compaction trigger
this formula assumes you are choosing manually.

### 3.2 Model routing and right-sizing

**Mechanism.** Classify or triage each request, then dispatch it to the cheapest model that can
handle it, reserving the expensive model for genuinely hard steps. This is the same principle behind
subagent model-tiering described conceptually in
[Chapter 4](../04-agents-subagents-harnesses-and-tools.md): a coordinating agent runs at one tier
while delegated work runs at a tier matched to its difficulty.

**The threshold that determines whether it works.** Let `c` be the cheap model's cost per task, `e`
the expensive model's, and `p` the fraction of tasks that fail on the cheap model and must be
retried on the expensive one. A cheap-first router costs `c + (p * e)` per task versus `e` for
always-expensive, so it wins only when:

```
p  <  1 - (c / e)
```

With a 5x price gap (`c/e = 0.2`), the router wins up to an 80 percent escalation rate, which is a
comfortable margin. With a 2x gap (`c/e = 0.5`), the threshold falls to 50 percent, and a router
that escalates on most requests is strictly worse than skipping the cheap attempt. Two corrections
make the real threshold stricter: any classifier or judge call adds its own cost to `c`, and
escalation adds latency, which may itself be unacceptable.

**Design implications:**

- Prefer routing on cheap, reliable signals (task type, input size, endpoint, user tier, an explicit
  difficulty flag) over an LLM classifier, which adds both cost and a failure mode.
- Route by step, not by request. In an agent loop, file search, log parsing, and summarization can run
  on a small model while planning and final code generation run on a large one.
- Instrument the escalation rate as a first-class metric; it is what tells you whether the router is
  earning its complexity.
- Where quality is critical, escalating on verification failure is more defensible than a
  guess-up-front classifier, because the verifier catches what the classifier would have misrouted.

### 3.3 Batch and asynchronous tiers for bulk work

**Mechanism.** Submit many requests as one job; the provider schedules them against spare capacity
and returns results within a processing window. Anthropic, OpenAI, and Google all price this at
roughly half of standard rates (Anthropic, "Batch processing"; OpenAI, "Pricing"; Google Cloud,
"Agent Platform Pricing," see References).

**When it applies.** Any workload where no human is blocked on the result: backfilling
classifications or embeddings over a corpus, nightly summarization, dataset generation, offline
evaluation runs, bulk translation, periodic reporting. A 50 percent discount in exchange for a
scheduling change is the best raw return in this section, and it composes with caching.

**When it does not.** Interactive requests, anything on a synchronous user-facing path, and tightly
coupled agent loops where step N+1 depends on step N, since each hop would wait a full batch window.
Anthropic also notes that stateful Managed Agents sessions are not eligible for the batch discount at
all (Anthropic, "Pricing," see References).

**Operational requirements.** Budget for partial failure: Anthropic expires uncompleted requests
after 24 hours without billing them, and keeps results downloadable for 29 days (Anthropic, "Batch
processing," see References). OpenAI's Flex tier, priced at batch rates but called synchronously,
needs raised client timeouts and a 429 retry strategy, either exponential backoff or a fallback to
standard processing when the higher cost is worth the certainty (OpenAI, "Flex processing," see
References).

### 3.4 Eliminating wasted tokens

The cheapest token is the one you never send. This lever requires no vendor feature and often
improves quality at the same time, because context is a finite attention budget rather than free
storage: Anthropic's engineering guidance frames good context engineering as finding "the smallest
possible set of high-signal tokens" and documents context rot, where recall degrades as the context
window fills (Anthropic, "Effective context engineering for AI agents," see References). [Chapter 3](../03-prompts-context-memory-and-caching.md),
Section 2.3 covers this in depth.

Highest-value tactics, roughly in order of payoff:

- **Bound the output.** Set `max_tokens` deliberately, state a target length or format, and ask for
  the answer rather than the answer plus its own explanation. Output is the expensive side.
- **Use structured output formats.** A JSON object or fixed table constrains the model to the fields
  you need and eliminates conversational padding, reducing output tokens and removing a parsing
  failure mode at the same time.
- **Summarize or compact long histories.** Anthropic describes compaction as the first lever for
  long-horizon agent tasks, and calls tool-result clearing its safest lightest-touch form, reasoning
  that an agent rarely needs to re-read a raw tool result from deep in its history (Anthropic,
  "Effective context engineering for AI agents," see References).
- **Retrieve instead of re-sending.** Send the three relevant sections rather than the whole document.
  [Chapter 5](../05-retrieval-embeddings-and-vector-databases.md) covers retrieval; the cost argument
  is that a 500 kB PDF is roughly 125,000 input tokens by Anthropic's own estimate, charged on every
  request that includes it (Anthropic, "Pricing," see References).
- **Prune tools and integrations per request.** Every tool definition and connected MCP server adds
  context to every message. OpenAI's own user-facing guidance says as much: limit MCP servers, keep
  instruction files small, and provide only relevant source material (OpenAI/ChatGPT, "Pricing," see
  References).
- **Isolate exploration in subagents.** A subagent can burn tens of thousands of tokens exploring and
  return a 1,000 to 2,000 token summary, keeping the expensive parent context small (Anthropic,
  "Effective context engineering for AI agents," see References). See
  [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).
- **Turn down reasoning effort where depth is not needed.** Reasoning tokens bill as output
  (Section 1.4), making this a direct cost lever.

One caution: trimming context and caching context pull in opposite directions on the same bytes.
Restructuring a prompt to save 500 input tokens can invalidate a 30,000-token cached prefix and cost
you far more than it saves. Optimize the stable prefix for cache stability, and the variable suffix
for brevity.

### 3.5 Fine-tuning a smaller model for a narrow repeated task

**Mechanism and decision framework:** [Chapter 7, Section 7](../07-related-and-advanced-topics.md)
covers when to choose fine-tuning versus retrieval versus prompting, and that framework should
drive the decision. What follows is only the cost accounting.

**The cost case.** Fine-tuning can move quality up the ladder at a lower tier, and it can shorten
prompts substantially, because behavior encoded in weights no longer needs restating in a system
prompt and few-shot examples on every request. Google's documentation lists "lower inference latency
and cost due to shorter prompts" as an explicit benefit of tuning (Google Cloud, "Agent Platform
Pricing," see References).

**The honest costs.**

- **Training is a real upfront charge.** Google publishes per-1M-training-token tuning prices from
  $0.28 for a 1B-parameter open model to $25 for a flagship as of this writing (Google Cloud, "Agent
  Platform Pricing," see References). This is usually the smallest of the costs.
- **Inference on a tuned endpoint may cost more than the base model.** Google's pricing page states
  that a tuned model endpoint is billed at 1.5x the base model rate (Google Cloud, "Agent Platform
  Pricing," see References). A tuned small model must therefore beat the base small model by enough to
  cover a 50 percent inference premium, which sharply narrows the win unless prompt savings are large
  or the quality gain lets you drop a tier.
- **Dataset construction dominates.** Curating, labeling, and validating examples is engineering and
  domain-expert time, not a line item on a pricing page, and it is typically the largest true cost.
- **Maintenance recurs.** Task drift, new edge cases, and base-model deprecation all force retraining
  and re-evaluation. Every fine-tune is a long-lived asset that needs an owner.
- **Platform risk is real.** OpenAI's pricing page states as of this writing that it is winding down
  its fine-tuning platform, closed to new users, with existing fine-tuned models supported only until
  their base models are deprecated (OpenAI, "Pricing," see References). A cost strategy built on a
  provider's fine-tuning offering can be invalidated by that provider's roadmap.

**When it is worth it:** a stable, narrow, high-volume task with an objective quality measure, where
prompting has plateaued, where you can produce a few hundred to a few thousand good examples, and
where projected volume amortizes the upfront and premium-endpoint costs over months rather than years.

**When it is not:** requirements still moving; knowledge that is factual and better retrieved than
memorized ([Chapter 7](../07-related-and-advanced-topics.md), Section 7); low volume; or no owner for the retraining lifecycle. In those
cases prompting plus caching plus right-sizing gets most of the benefit for none of the commitment.

### 3.6 Open-weight and self-hosted models

**Mechanism.** Run open-weight models ([Chapter 7](../07-related-and-advanced-topics.md), Section 6 covers what "open weight" does and does not
mean) on infrastructure you control or rent, replacing a per-token price with a per-hour compute price.

**The cost case, honestly framed.** The relevant comparison is not open-weight against a flagship
proprietary model; it is self-hosted open-weight against a *managed* open-weight endpoint. Managed
open-weight serving is already dramatically cheaper than flagship pricing: as of this writing Google
lists gpt-oss-120b on Vertex AI at $0.09/MTok input and $0.36/MTok output, roughly a factor of 20 to
30 below Gemini 3.1 Pro Preview's $2/$12 (22x on input, 33x on output), with no infrastructure to
operate (Google Cloud, "Agent Platform Pricing," see References). Self-hosting must beat that
number, not the flagship number.

**The hidden costs.**

- **Utilization risk.** Per-hour compute is billed whether or not requests arrive, so a GPU at 10
  percent utilization has an effective per-token cost ten times its nameplate. This is the committed
  throughput arithmetic of Section 1.8, with more of the engineering on your side.
- **Operational burden.** Serving-stack tuning, batching and KV-cache configuration, autoscaling, GPU
  capacity acquisition, upgrades, monitoring, and on-call. This is a staffing decision, and staff cost
  usually dwarfs token savings at moderate volume.
- **Feature gap.** Prompt caching, batch tiers, server-side tools, structured-output enforcement, and
  safety filtering are provider features you may have to rebuild. Each rebuild erodes the savings, and
  the caching lever in Section 3.1 is worth more than most self-hosting differentials.
- **Quality gap on hard tasks.** Leading open-weight models are strong and often sufficient, but on the
  frontier reasoning tasks of Section 4's high-stakes tier the gap is usually real. Measure it on your
  own workload rather than assuming either direction.
- **Data control is a separate justification.** Self-hosting is often chosen for residency or
  confidentiality reasons ([Chapter 6](../06-security-privacy-and-data.md)), which can be decisive on
  its own. Conflating it with a cost argument produces bad decisions.

**Practical ordering.** Use a managed open-weight endpoint first: it captures most of the price
advantage at none of the ops cost, and it measures open-weight quality on your workload. Self-host only
when volume is high, steady, and measured, and when either the arithmetic clearly favors it or a
data-control requirement makes it necessary.

## 4. A decision framework by target output quality

Pick the tier by the cost of being wrong, not by the impressiveness of the task.

| Tier | What it covers | Model class to reach for | Verification expected | Highest-leverage cost levers | Levers to skip |
| --- | --- | --- | --- | --- | --- |
| **Quick / disposable** | Brainstorming, casual questions, throwaway drafts, name and idea generation, rough explanations | Smallest or mid-tier model; a consumer free or entry paid seat is usually the right purchase, not API access | None beyond a human glance | Right-sizing (3.2); bounded output (3.4); accept the default tier | Caching, batch, fine-tuning, self-hosting. Engineering effort exceeds the spend |
| **Everyday professional** | Typical work tasks where correctness matters but errors are caught and cheap to fix: internal docs, code review notes, summaries, first-draft emails, routine refactors | Mid-tier general model as default, escalating by exception | Human review in the normal workflow | Caching the stable prompt (3.1); right-sizing per step (3.2); trimming context and bounding output (3.4) | Fine-tuning and self-hosting. Volume rarely justifies fixed cost |
| **High-stakes / hard reasoning** | Complex multi-file coding, architecture decisions, and legal, financial, or medical-adjacent drafting where a plausible-but-wrong answer is expensive | Most capable available model, at high reasoning effort, plus a priority tier only if latency is genuinely part of the requirement | Mandatory and explicit: tests, a second-model or second-pass critique, citation checking, qualified human sign-off | Caching (3.1), which pays best here because prompts are long; spend deliberately on verification rather than shaving inference cost | Cheap-model substitution on the reasoning step. Batch, unless the work is genuinely offline |
| **High-volume / production** | A system serving many requests where unit economics decide viability: classification, extraction, enrichment, support triage, embeddings pipelines | Smallest model that passes your evaluation, chosen by measurement rather than reputation; escalate a measured minority of requests | Automated: schema validation, evaluation suites, sampled human audit, per-request cost and escalation telemetry | All of them, in this order: caching (3.1), right-sizing and routing (3.2), batch or flex for offline portions (3.3), token trimming (3.4). Then evaluate fine-tuning (3.5) and managed open-weight or self-hosting (3.6) against measured volume | Flagship-by-default. At volume it is the dominant cost line |

### 4.1 Decision tree

```
Is a human waiting on this response right now?
├─ No ──> Use a batch or flex tier (50% off). Then continue below.
└─ Yes ─> Is latency part of the product experience?
          ├─ Yes, critically ──> Consider a priority/fast tier, but only
          │                      after right-sizing the model.
          └─ No ──────────────> Standard tier.

What happens if the output is subtly wrong?
├─ Nothing much ─────────────> Quick/disposable tier. Smallest model. Stop optimizing.
├─ Someone fixes it in review > Everyday professional tier. Mid-tier model + caching.
├─ Real harm: money, legal
│  exposure, safety, broken
│  production code ──────────> High-stakes tier. Most capable model + mandatory
│                              verification. Do not economize on the reasoning step.
└─ Caught automatically, but
   happens 10,000x/day ─────> High-volume tier. Optimize unit cost aggressively.

Same task, repeatedly, at high volume, with prompting already plateaued
on quality, a stable spec, an objective metric, and volume that amortizes
fixed cost?
├─ No ──> Prompting + caching + right-sizing. Done.
└─ Yes ──> Evaluate fine-tuning a smaller model (3.5) and managed
         open-weight serving (3.6). Self-host only if volume is high,
         steady, measured, and ops capacity exists.
```

### 4.2 Notes on applying the tiers

- **Tiers apply to steps, not to products.** A coding assistant might route file search to the
  high-volume tier, ordinary edits to the everyday tier, and architectural changes to the high-stakes
  tier. Assigning one model to a whole product produces overspending and quality complaints at once.
- **Verification is a cost line, and often the right place to spend.** In the high-stakes tier, a
  second model reviewing the first model's output frequently buys more risk reduction per dollar than
  a marginally better single pass. Budget for it rather than treating it as overhead.
- **Move down a tier only on evidence,** measured on your own data rather than a benchmark. [Chapter 7](../07-related-and-advanced-topics.md),
  Section 3 covers why benchmark results transfer poorly to specific workloads.
- **Revisit tier assignments when models change.** Last quarter's flagship-only task is often this
  quarter's mid-tier task, so make the model a configuration value rather than a constant.

## 5. How to compare cost across providers and models

### 5.1 Why headline per-token prices are not comparable

Five differences routinely invert a naive price comparison:

1. **Tokenizers differ, so "a token" is not a fixed amount of text.** Anthropic's pricing page notes
   that Claude 4.7 and later use a newer tokenizer producing approximately 30 percent more tokens for
   the same text than earlier models (Anthropic, "Pricing," see References). A 30 percent difference
   in token yield swamps most of the price differences people argue about, and it can appear between
   models from the same vendor, not just across vendors.
2. **Input-to-output ratios differ,** so a provider that is cheaper on input can be dearer on output.
   Which side dominates depends entirely on your workload's shape (Section 1.3).
3. **Reasoning tokens are billed as output and vary by model and setting,** so two models with
   identical published rates can differ by multiples in practice (Section 1.4).
4. **Long-context pricing has cliffs, and they are not aligned.** Google's pricing states that once
   input context exceeds 200K tokens, all tokens for that request, input and output, are charged at
   long-context rates, roughly double for some models. Anthropic includes the full 1M-token window at
   standard pricing on Claude 4.6 and later (Google Cloud, "Agent Platform Pricing"; Anthropic,
   "Pricing," see References). A workload that straddles 200K tokens behaves very differently across
   the two.
5. **Bundling and per-call charges differ.** Search, code execution, container time, storage, and
   agent runtime are priced per call, per hour, or per gigabyte-day, with different free allowances
   (Section 1.9), and seat fees or credit systems sit on top for consumer and enterprise plans.

### 5.2 A methodology you can actually run

1. **Pick a representative real workload.** Take 50 to 200 actual requests from production or a
   realistic pilot, spanning the sizes and difficulties you really see. Synthetic examples and
   averages both hide the tail that drives cost.
2. **Run the same workload against each candidate.** Do not estimate tokens by hand; every provider
   returns exact usage per request, including cached, cache-write, and reasoning token counts.
3. **Record success, not just cost.** Score each response against your own acceptance criteria,
   ideally automated. A candidate that fails 20 percent of the time is not comparable to one that
   fails 2 percent until you price the retries and the human fixes.
4. **Compute blended cost per completed task**, not cost per token:

   ```
   cost_per_task = ( uncached_input x input_rate
                   + cache_reads    x cache_read_rate
                   + cache_writes   x cache_write_rate
                   + output_tokens  x output_rate     ; includes reasoning tokens
                   + per_call_tool_charges
                   + amortized_fixed_costs )         ; seats, reserved capacity, hosting
                   / tasks_completed_successfully
   ```

   Dividing by *successfully completed* tasks is the step that makes the comparison honest, because
   it prices retries and rework into the model that caused them.
5. **Apply realistic discounts, not best-case ones.** Use your measured cache hit rate rather than an
   aspirational one, and apply the batch discount only to the share of traffic that can genuinely run
   asynchronously.
6. **Multiply by projected volume and by an agent-loop factor.** If a task averages six model calls,
   the per-task figure is six calls, not one (Section 6).
7. **Sanity-check against a published worked example.** Anthropic's pricing documentation walks
   through a support-ticket workload averaging about 3,700 tokens per conversation and totaling
   roughly $37 per 10,000 tickets on its small model as of this writing (Anthropic, "Pricing," see
   References). If your estimate for a comparable workload is an order of magnitude away, find out
   why before believing it.
8. **Re-run it quarterly.** Prices, model lineups, and tokenizers all change. Keep the harness so
   re-running costs an afternoon rather than a project.

### 5.3 A comparison template

Fill one row per candidate, from measured data. The escalation rate recorded on the fourth row is what
decides whether routing is worth its complexity (Section 3.2).

| Candidate | Avg uncached input | Avg cache read | Avg output (incl. reasoning) | Measured cache hit rate | Task success rate | Cost per successful task | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Flagship, standard tier | | | | | | | Baseline quality reference |
| Mid-tier, standard | | | | | | | |
| Small, standard + caching | | | | | | | |
| Small default, escalate on failure | | | | | | | Record escalation rate |
| Mid-tier, batch tier | | | | | | | Only if latency permits |
| Managed open-weight endpoint | | | | | | | |

## 6. Common cost traps

| Trap | Mechanism | What it looks like | Fix |
| --- | --- | --- | --- |
| **Forgetting output dominates** | Output is priced several times higher than input, so an unbounded generation costs more than a large prompt | Cost estimates built from prompt size alone, then a bill several times larger | Estimate from output tokens first. Set `max_tokens`, specify target length, use structured formats, and treat reasoning effort as a cost setting (1.3, 1.4, 3.4) |
| **Ignoring the agent-loop multiplier** | An agentic task is many model calls, each resending a growing context plus tool results | Per-call cost looks fine; per-task cost is 5x to 50x the estimate | Measure and budget cost per completed *task*. Log tokens per task, not per call. Compact history and clear stale tool results (3.4) |
| **Retries billed silently** | Failed validations, malformed output, timeouts, and rate-limit backoffs all re-send the full prompt | A quiet multiplier that never appears in the design doc | Count retries in the cost model. Prefer schema-enforced output to reduce reparse loops. Cap retries per task and alert on the retry rate |
| **Over-provisioning "just in case"** | The flagship model is chosen for the whole product because some part of it is hard | The largest avoidable line item in most production systems | Right-size per step and escalate by exception (3.2). Make the model a config value so re-tiering is cheap |
| **Redundant context re-sends without caching** | An agent loop resends the same system prompt, tool definitions, and documents at full input price every step | Input token counts scale with step count, and latency does too | Enable caching and keep the prefix byte-stable. Order prompts static-first, variable-last (3.1) |
| **Cache-invalidating micro-optimizations** | Trimming or reordering the stable prefix changes the hash and forces a fresh cache write | A "token diet" that increases the bill | Freeze the cacheable prefix and optimize only the variable suffix (3.4). Cache writes cost more than plain input, so cache only prefixes that will be read again inside the TTL: break-even is the second use for a short TTL, the third for a long one (3.1) |
| **Unbounded agent loops** | Nothing limits steps, tool calls, or spend, so a stuck agent retries indefinitely | A runaway loop costing hundreds of dollars overnight, usually noticed on the invoice | Enforce hard limits: max steps, max tool calls, max wall-clock time, max tokens per task, and a per-task cost ceiling. Use provider workspace spend limits as a backstop, noting Anthropic's caveat that concurrent batch throughput can slightly overshoot a configured spend limit (Anthropic, "Batch processing," see References) |
| **Uninstrumented spend** | Cost is only visible in aggregate on a monthly invoice | Nobody can attribute cost to a feature, tenant, or prompt change | Log token usage per request with feature, model, and tenant tags. Every provider returns exact usage; store it |
| **Ignoring non-token charges** | Search, code execution, containers, storage, and agent runtime bill separately | A "token cost model" that understates the bill for any tool-using system | Include per-call and per-hour charges in the model, and monitor free-allowance consumption (1.9) |
| **Reserving capacity too early** | Committed throughput and self-hosting convert variable cost to fixed cost | Paying for idle GPUs or unused capacity units while traffic is still spiky | Commit only against measured, sustained utilization. Reserve the steady baseline and burst on pay-as-you-go (1.8, 3.6) |
| **Long-context cliffs** | Some providers reprice an entire request once input crosses a threshold | A modest prompt growth roughly doubles per-request cost | Know your provider's threshold. Keep requests below it via retrieval, or price the workload at long-context rates (5.1) |

Most of these traps are invisible without instrumentation, which makes cost control an observability
problem before it is an optimization problem ([Chapter 7](../07-related-and-advanced-topics.md), Section 10 covers LLM observability
generally). Record token counts by category, the model and tier actually used, cache hit rate, steps
and retries per task, task success rate, and enough tags that a cost regression has an owner. Two
derived numbers deserve a dashboard: **cost per successfully completed task**, the only figure that
supports a business decision, and **escalation rate**, which tells you whether your routing strategy
is earning its complexity or quietly costing more than the simpler approach it replaced.

---

## References

### Official Documentation

- [Pricing](https://docs.anthropic.com/en/docs/about-claude/pricing) - Anthropic; per-model input, output, cache-write and cache-read rates, batch and fast-mode multipliers, tokenizer token-yield change on Claude 4.7 and later, tool-use and server-tool token overheads, code execution and managed-agent runtime charges, data residency multipliers, and a worked support-ticket cost example.
- [Prompt caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching) - Anthropic; cache prefix ordering, automatic versus explicit breakpoints, 5-minute and 1-hour TTLs, and the 1.25x/2x write and 0.1x read multipliers behind the break-even arithmetic in Section 3.1.
- [Batch processing](https://docs.anthropic.com/en/docs/build-with-claude/batch-processing) - Anthropic; the 50 percent batch discount, the 24-hour expiry window and unbilled expired requests, 29-day result retention, observed 30 to 98 percent cache hit rates inside batches, and the spend-limit overshoot caveat.
- [Pricing](https://www.anthropic.com/pricing) - Anthropic; consumer and organizational plan structure (Free, Pro, Max 5x and 20x, Team standard and premium seats, Enterprise at $20 per seat plus API-rate usage), rolling five-hour usage windows with weekly caps, and overflow usage credits billed at standard API rates.
- [Pricing](https://platform.openai.com/docs/pricing) - OpenAI; standard, batch, flex, and priority rate tables including cached-input and cache-write columns, short versus long context rates, per-call tool and container charges, regional processing uplift, and the notice that the fine-tuning platform is being wound down.
- [Flex processing](https://platform.openai.com/docs/guides/flex-processing) - OpenAI; the `service_tier` parameter, pricing at batch rates, 429 resource-unavailable behavior without charge, and client timeout guidance.
- [Pricing](https://learn.chatgpt.com/docs/pricing) - OpenAI; individual and business plan ladder with prices, per-five-hour and weekly usage limits, the credits-per-million-tokens rate card, credit-based flexible pricing for Business and Enterprise, and vendor guidance on reducing usage through smaller models, tighter prompts, and fewer MCP servers.
- [Agent Platform Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing) - Google Cloud; Gemini standard, priority, and flex/batch rates, the "response and reasoning" output line item, the 200K-token long-context repricing rule, global versus non-global endpoint rates, grounding and search query charges, Provisioned Throughput GSU commitment pricing, per-1M-token tuning prices with the 1.5x tuned-endpoint multiplier, and managed open-weight model rates including gpt-oss and Llama.
- [Context caching overview](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/context-cache/context-cache-overview) - Google Cloud; implicit versus explicit caching, the 90 percent cached-token discount, explicit-cache storage costs and TTL behavior, minimum cacheable token counts by model family, and recommended use cases.
- [Google AI plans](https://one.google.com/about/google-ai-plans/) - Google; consumer plan tiers and the usage-multiplier structure (AI Pro at 4x higher Gemini limits, AI Ultra at up to 20x the Pro plan) used in the subscription comparison in Section 1.7.

### Further Reading

- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Anthropic; the smallest-set-of-high-signal-tokens principle, context rot and the attention budget, compaction and tool-result clearing, and subagent context isolation with condensed 1,000 to 2,000 token returns.
- [Save costs and decrease latency while using Gemini with Vertex AI context caching](https://cloud.google.com/blog/products/ai-machine-learning/vertex-ai-context-caching) - Google Cloud; the 10 percent cached-token cost, implicit cache retention behavior and 24-hour deletion, explicit-cache TTL storage billing, and cache-hit-rate best practices.
