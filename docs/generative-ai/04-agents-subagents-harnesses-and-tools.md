---
audience: human
created: 2026-07-28
updated: 2026-08-03
---

# Chapter 4: Agents, Subagents, Harnesses, and Tools

## In short

- An "agent" is a system where the model directs its own loop of planning, acting through tools, and observing results, rather than answering once and stopping. Autonomy is a spectrum, not a binary switch.
- "Subagent" delegation exists to isolate context, run work in parallel, specialize behavior, and route cheap or expensive models to the right task. Subagents report summaries back; they do not share memory with the caller.
- A "harness" is the application layer wrapping a model: the loop, the tools, the permissions, the memory, the interface. The same underlying model behaves very differently in different harnesses.
- Tool use (function calling) is the mechanical foundation everything else in this chapter builds on: a model requests a named, schema-defined action, the harness executes it, and the result feeds back into the model's context - as a full, separate request that resends everything accumulated so far, which is why one user-visible turn can expand into many individually-billed round trips (Section 4.1).
- Plugins, skills, and MCP are three different answers to "how does an assistant gain new capabilities," built at different layers and with different tradeoffs; they are not competitors so much as points on a spectrum from lightweight instructions to live network integrations.
- Every extension mechanism in this chapter (plugins, skills, MCP servers) widens what an agent can be tricked or misused into doing. [Chapter 6](06-security-privacy-and-data.md) covers the security implications; this chapter stays conceptual.

This chapter builds on model and inference basics from [Chapter 2](02-models-training-and-inference.md) and context management from [Chapter 3](03-prompts-context-memory-and-caching.md). It is the conceptual companion to two other chapters: [Chapter 7](07-related-and-advanced-topics.md) covers specific orchestration patterns and observability in depth, and [Appendix A](appendices/appendix-a-plugins-and-config-paradigms.md) gives a practical, product-by-product rundown of popular plugins, skills, and MCP servers.

---

## 1. Agents: from chatbot to agentic loop

### 1.1 What makes a system "agentic"

A plain single-turn chatbot receives a prompt and returns text. It has no way to check whether that text is accurate, no way to act on the world, and no memory of the exchange beyond what the harness re-supplies on the next call. Everything the model needs must already be in the prompt, and everything it produces is the final answer.

An agentic system is different in one specific way: the model can take actions that change what it knows before it produces a final answer, and it decides for itself when to do so. Anthropic's own framing, from its 2026 policy writeup on agent trustworthiness, states this plainly:

> "We define an agent as an AI model that directs its own processes and tool use when accomplishing a task, that is, deciding for itself how to achieve what users want, rather than following a fixed script. The practical difference between this and a chatbot is that an agent operates in a self-directed loop: it plans, acts, observes the result, adjusts, and repeats until the task is done or it needs to check in for human input."

That loop, not any particular capability or model size, is the defining feature of agentic behavior. The table below makes the contrast concrete:

| | Single-turn chatbot | Agentic system |
| --- | --- | --- |
| Input to output | One prompt in, one response out. | A task in, an unknown number of intermediate steps, then a final response. |
| What it can act on | Only what is already in the prompt or the model's training data. | Whatever its tools let it read, write, or execute, updated as it goes. |
| Who decides the next step | The human, every time. | The model, within whatever limits the harness sets. |
| How errors surface | Not at all until the human reads the output. | Often mid-task, as a failed tool call the model can see and react to. |
| Failure mode | A wrong or incomplete answer. | A wrong or incomplete answer, or, in the worst case, a wrong or harmful action already taken. |

That last row is worth sitting with: an agent's mistakes are not always just words on a screen. This is part of why the autonomy and security topics in this chapter (Sections 1.3, 5.4, 6.4, 7.6, and [Chapter 6](06-security-privacy-and-data.md) generally) matter more for agentic systems than for chatbots.

### 1.2 The agentic loop

Stripped to its essentials, the loop has four repeating phases:

| Phase | What happens |
| --- | --- |
| Perceive / gather context | The model reads the current state: the task, prior tool results, relevant files or data. |
| Plan | The model decides what to do next, sometimes producing a visible reasoning trace. |
| Act | The model invokes a tool (see Section 4) rather than, or in addition to, writing a final answer. |
| Observe | The tool's result (or an error) is appended to context, and the loop returns to perceiving. |

Drawn out as a cycle, with the harness (Section 3) as the machinery that actually runs it:

```
        ┌─────────────────────────────────────────────┐
        │                                               │
        ▼                                               │
 ┌─────────────┐     ┌──────────┐     ┌────────────┐   │
 │  Perceive / │ ──▶ │   Plan   │ ──▶ │    Act     │   │
 │  gather     │     │ (reason  │     │ (call a    │   │
 │  context    │     │  about   │     │  tool, or  │   │
 └─────────────┘     │  next    │     │  answer)   │   │
        ▲            │  step)   │     └─────┬──────┘   │
        │            └──────────┘           │          │
        │                                   ▼          │
        │                          ┌──────────────┐    │
        └───────────────────────── │   Observe    │ ───┘
                                    │ (tool result │
                                    │  or error)   │
                                    └──────────────┘

   Loop exits when: the model judges the task done,
   a human interrupts, or a stopping condition fires
   (e.g. a maximum number of iterations).
```

The loop terminates when the model judges the task complete, when a human interrupts or redirects it, or when a stopping condition built into the harness fires, such as a maximum number of iterations. Anthropic's engineering guidance on agent design is explicit that this last safeguard matters: agents "will potentially operate for many turns," so designers should build in a level of trust in the model's decision-making balanced against explicit limits on how long it can run unsupervised.

### 1.3 Autonomy is a spectrum, not a switch

Anthropic draws an architectural line between two categories of agentic systems, and this distinction is worth internalizing before looking at any specific pattern:

- **Workflows.** LLMs and tools are orchestrated through code paths the developer wrote in advance. The sequence of steps is fixed; only the content flowing through each step varies.
- **Agents.** The LLM dynamically directs its own process and tool usage, choosing at runtime which steps to take and in what order, and retaining control over how it accomplishes the task.

Most production systems sit somewhere between these poles rather than purely at one end, and the choice of where to sit is really a choice about where to place human checkpoints. A concrete illustration, drawn from Anthropic's own writing on agent design: imagine asking an agent to submit receipts from a business trip. It plans the steps (transcribe each photo, pull the amount and vendor, categorize the expense, submit it through the company's system) and works through them in sequence. If a hotel charge exceeds a spending cap, the agent might recognize that it does not actually know what the cap is or what other rules apply, and pause to ask whether it should pull the expense policy before trying again. With approval, it folds that new information into its plan and continues until done or until it hits something else that needs a decision only the user can make. Nothing about that scenario required a human to approve each individual transcription or categorization step; the checkpoints exist only where genuine ambiguity or risk appears.

Claude Code's Plan Mode shows the same idea from a different angle: instead of approving every tool call one at a time (low autonomy, high friction) or letting the agent run completely unsupervised (high autonomy, low visibility), the agent proposes a full plan up front, the human reviews and edits the whole thing once, and execution then proceeds with the human able to intervene at any point. That single feature moves the point of human oversight from the level of individual actions to the level of overall strategy, illustrating that "autonomy" is really a design decision about where checkpoints go, not a fixed property of a model.

Whatever point on the spectrum a system sits at, agentic autonomy trades latency and cost for the ability to handle problems where the number of required steps cannot be predicted in advance and a fixed code path would not work. That tradeoff is worth making deliberately, not by default: Anthropic's own guidance recommends finding the simplest solution first, and reaching for full agentic autonomy only when a workflow demonstrably falls short. The tension does not disappear once an agent is deployed, either: an agent that pauses to ask about every possible ambiguity gives up most of the autonomy that makes it useful in the first place, while one that never pauses risks acting on a misreading of what the user actually wanted. Calibrating that balance, knowing when a gap in the plan is something the agent can resolve on its own versus something only the user can settle, is one of the harder open problems in agent design, not a solved one.

### 1.4 Conceptual architectures

Two patterns come up constantly in descriptions of how an agent structures its own reasoning and delegation. Both are covered only at a conceptual level here; a full comparison of orchestration patterns (prompt chaining, routing, parallelization, evaluator-optimizer, and more) belongs in [Chapter 7](07-related-and-advanced-topics.md).

**ReAct (Reason + Act).** Introduced in a 2022 paper by researchers at Princeton and Google, ReAct interleaves two kinds of output from the model: a verbal "thought" (reasoning that updates the model's own plan but does not touch the outside world) and an "action" (a tool call that does touch the outside world and returns an observation). The two feed each other: reasoning helps the model decide what to do next, and the results of actions ground that reasoning in facts the model could not have produced from its own knowledge. A trace for a simple factual question looks roughly like this:

```
Thought: I need to find out who directed this film before I can
         answer the question about their other work.
Action:  search("director of [film title]")
Observation: The search result names the director.
Thought: Now I need that director's filmography.
Action:  search("[director name] filmography")
Observation: The search result lists several other films.
Thought: I have enough information to answer.
Answer:  [final response, grounded in the two search results above]
```

The original paper found this interleaving reduced hallucination and error propagation compared to reasoning alone (chain-of-thought with no way to check facts against the world), and outperformed acting alone (taking actions with no interleaved reasoning to plan or recover from mistakes) on interactive decision-making benchmarks. Nearly every modern tool-using agent, whatever it is branded, implements some variant of this reason-act-observe cycle; it is the same shape as the agentic loop in Section 1.2, described at the level of the model's own reasoning trace rather than at the level of the harness running it.

**Planner-executor / orchestrator-workers.** Instead of one model doing all the reasoning and acting itself, a central "orchestrator" model breaks a task into subtasks, delegates each to a "worker" (which may be a separate model call, a subagent, or a deterministic tool), and synthesizes the workers' results into a final answer. Anthropic's guidance describes this as well suited to tasks where the subtasks cannot be predicted in advance, such as a coding change that might touch an unknown number of files, or a research task that needs to gather information from a variable number of sources. The key difference from simply running several fixed steps in parallel is that the orchestrator decides the shape of the work at runtime rather than the developer deciding it in advance.

---

## 2. Subagents: delegating work within an agent

### 2.1 Why delegate

A single agent working through a long, multi-part task accumulates everything it has read and done in one context window: search results, file contents, logs, intermediate drafts. Most of that material is only useful for the moment it was produced. Subagents exist to keep that clutter out of the main conversation. Anthropic's own subagent documentation puts the trigger condition directly: use a subagent "when a side task would flood your main conversation with search results, logs, or file contents you won't reference again: the subagent does that work in its own context and returns only the summary."

Four benefits fall out of that basic move:

- **Context isolation.** The parent agent's context window stays focused on the task at hand instead of filling with exploratory work. See [Chapter 3](03-prompts-context-memory-and-caching.md) for how context windows fill and get compacted.
- **Parallelism.** Independent subtasks (auditing several files, researching several questions) can run as separate subagents at the same time rather than sequentially in one thread.
- **Specialization.** A subagent can be given its own system prompt, a restricted tool set, and independent permissions, effectively becoming a narrow specialist rather than a general-purpose assistant asked to context-switch.
- **Cost and model-tier routing.** Not every subtask needs the most capable (and most expensive) model. A narrow, well-defined task can run on a smaller, faster model while judgment-heavy work is reserved for a stronger one.

### 2.2 Orchestrator and worker roles

The pattern in practice mirrors the orchestrator-workers architecture from Section 1.4: a main, or "lead," agent decides that a piece of work should be delegated, invokes a subagent with a specific task description, and the subagent works independently, using only the tools and context it was given, until it produces a result. The main agent remains responsible for deciding what work exists and for combining the pieces once they come back. Anthropic's guidance frames the orchestrator-workers workflow as suited to coding tasks that touch an unpredictable set of files, and to research tasks that require gathering and synthesizing information from multiple sources, both cases where the number and shape of subtasks cannot be known before the work starts.

```
                        ┌──────────────────────┐
                        │   Orchestrator /      │
                        │   lead agent          │
                        │   (holds the task,    │
                        │   decides what work   │
                        │   exists)             │
                        └──────────┬────────────┘
                 dispatch          │          dispatch
        ┌──────────────────────────┼──────────────────────────┐
        ▼                          ▼                          ▼
 ┌─────────────┐           ┌─────────────┐            ┌─────────────┐
 │  Subagent A  │           │  Subagent B  │            │  Subagent C  │
 │  own context │           │  own context │            │  own context │
 │  own tools   │           │  own tools   │            │  own tools   │
 └──────┬──────┘           └──────┬──────┘            └──────┬──────┘
        │   summary only          │   summary only            │  summary only
        └──────────────────────────┼──────────────────────────┘
                                   ▼
                        ┌──────────────────────┐
                        │   Orchestrator        │
                        │   synthesizes results │
                        │   into a final answer │
                        └──────────────────────┘
```

A concrete example: asked to find every place in a codebase that calls a deprecated function and update each call site, a lead agent might dispatch one subagent per affected file (or per cluster of related files) rather than reading and editing everything itself in one long, ever-growing context window. Each subagent receives only the specific file paths and instructions it needs, does its own reading and editing, and reports back "updated three call sites in `payments.py`, no test changes needed" rather than returning every line it read along the way. The lead agent never has to hold all three files' full contents in its own context at once; it only holds the three short summaries.

### 2.3 How results come back: reports, not shared memory

A subagent does not hand its full working context back to the caller. It runs in its own context window and returns a summary, typically its final message, and the parent never sees the intermediate tool calls, false starts, or raw search results the subagent generated along the way. This is a deliberate design choice, not a limitation: it is exactly what makes the "context isolation" benefit in Section 2.1 work. If a subagent's entire scratch space were merged back into the parent's context, delegating the work would not have saved any context budget at all.

This report-back model is also what distinguishes a subagent from a more tightly coupled pattern sometimes called an agent team, where each participant is a fully independent, addressable session that can message other participants directly and share a task list, rather than reporting only to whoever spawned it. The comparison is useful precisely because it shows that "delegation" is not one single mechanism: report-back subagents suit quick, focused tasks where only the final result matters and token cost should stay low, while peer-to-peer teams suit work that genuinely benefits from participants discussing and challenging each other's findings, at a higher token cost since each participant is a full, separate instance.

### 2.4 Model-tier-per-task-type

Because a subagent (or, more simply, a single delegated model call) can be configured independently of the agent that spawned it, systems commonly route different kinds of subtasks to different model tiers rather than using one model for everything. Anthropic's own guidance on the routing pattern gives the canonical example: directing "easy/common questions to smaller, cost-efficient models" and "hard/unusual questions to more capable models... to optimize for best performance." Applied to subagents specifically, this means a narrow, mechanical task, extracting a value from a log, formatting output, checking a fact against a document, can run on a fast and cheap model, while a subagent asked to make a judgment call, weigh tradeoffs, or produce a plan warrants a stronger model. Frameworks that support custom subagents typically expose the model choice as a per-subagent setting precisely so this routing can be configured deliberately rather than defaulting every subagent to the same model as the parent.

---

## 3. Harnesses: the scaffold around the model

### 3.1 Definition

A raw model, called through an API, is a function: it takes text (and sometimes images or other modalities) in, and produces text out. It cannot read a file, run a command, remember a previous conversation, or decide to call a tool unless something outside the model gives it that capability and wires up the mechanics. That surrounding software, everything that is not the model's weights and inference code, is the harness.

Anthropic's own framing breaks an agent into exactly four components, of which the harness is one:

- **The model.** The trained intelligence: what it knows and how it reasons.
- **A harness.** "The instructions, and the guardrails, that the model operates under." (Their example: a harness might tell the model to flag any expense over a set threshold, or to never submit an action without user confirmation.)
- **Tools.** The services and applications the model can use to actually do something.
- **An environment.** Where the agent runs and what it can reach: a personal laptop, a sandboxed cloud container, a corporate network.

Claude Code's own glossary makes the split concrete for a specific product: "Claude Code is the harness; Claude is the model inside it. The harness supplies file access, shell execution, permission gating, memory loading, and the loop that chains actions together." The same relationship holds for every other agentic product: the model provides the reasoning, and the harness provides the loop, the tool wiring, the context assembly, the permission system, and the interface a human actually interacts with.

Putting those two descriptions together, a harness's responsibilities generally break down into a handful of concerns:

| Responsibility | What it covers |
| --- | --- |
| The loop itself | Orchestrating the prompt-response-tool call-observation cycle from Section 1.2 until the task ends or a human intervenes. |
| Tool wiring | Deciding which tools (file access, shell, web search, MCP servers, subagent spawning) the model is even allowed to see and call. |
| Context assembly | Loading instruction files, memory, and conversation history into the model's context, and handling compaction when it fills, covered further in [Chapter 3](03-prompts-context-memory-and-caching.md). |
| Permissions and safety | Enforcing which actions can run automatically and which need human approval, the primary safety mechanism in most agentic products. |
| Interface | Terminal, IDE panel, chat window, or voice: however a human actually sees and steers the agent's work. |

### 3.2 Harnesses in practice

Any application that wraps a model and gives it tools, memory, and a way to interact with a user is a harness, regardless of whether it is a polished commercial product or a small internal script. Some familiar examples:

| Harness | What it wraps the model with |
| --- | --- |
| Claude Code | A terminal- and IDE-based coding agent: file access, shell execution, subagents, hooks, and a permission system, wrapped around Claude. |
| Cursor | An IDE fork with an agent loop, codebase-aware tools, and an in-editor chat and diff interface, usable with several different underlying models. |
| ChatGPT | A chat interface with memory, built-in tools (web browsing, code execution), and, historically, plugin and Custom GPT extension points, wrapped around OpenAI's models. |
| GitHub Copilot | An IDE- and CLI-integrated assistant with its own extension and plugin system, wrapped around one or more underlying models depending on configuration. |
| A custom app built on a provider's API | Whatever tools, memory, and UI the developer chooses to build, wrapped around a model accessed purely through API calls. |

### 3.3 Same model, different harness, different behavior

Because so much of an agent's practical behavior, what it can touch, what it is told to prioritize, how much it is allowed to do before checking in, comes from the harness rather than the model, the same underlying model can feel like a fundamentally different product depending on where it runs. Anthropic's own security guidance makes this point directly: "A well-trained model can still be exploited through a poorly configured harness, an overly permissive tool, or an exposed environment," and even something as simple as running on a personal phone instead of a corporate network changes an agent's practical risk and capability profile without changing the model at all. LangChain's engineering blog frames the general principle the same way: a raw model "is not an agent" until a harness gives it "state, tool execution, feedback loops, and enforceable constraints," and "the model contains the intelligence" while "the harness is the system that makes that intelligence useful." This is why comparing two AI products by asking only "which model does it use" is often the wrong question; the harness usually explains more of the difference a user actually notices.

---

## 4. Tool use and function calling: the foundation

Everything in Sections 5 through 7 (plugins, skills, and MCP) is built on top of one underlying mechanic: a model's ability to request that a specific, named, schema-defined function be executed on its behalf, and to receive the result back into its context. This section covers that mechanic on its own terms.

### 4.1 The request/response loop

OpenAI's function calling documentation describes the flow as five steps, and the shape is the same regardless of vendor:

1. The application sends a request to the model that includes a list of tools it could call.
2. The model, if it judges a tool is needed, responds not with a final answer but with a tool call: a structured request naming a specific tool and providing arguments.
3. The application executes real code on its own side, using the arguments the model provided.
4. The application sends the tool's output back to the model in a second request.
5. The model produces a final response, or, if the task needs further steps, another tool call, and the loop continues.

Anthropic's tooling guidance describes the same mechanic from the model side: "Tools enable Claude to interact with external services and APIs by specifying their exact structure and definition in our API. When Claude responds, it will include a tool use block in the API response if it plans to invoke a tool." The vendor-specific names differ (tool call, function call, tool use block) but the underlying loop, model requests, application executes, application returns result, model continues, is identical.

Step 4 is easy to read past, but it is the detail that matters most for cost: "a second request" is a full, separate model request, and per [Chapter 3](03-prompts-context-memory-and-caching.md#11-what-a-prompt-is), a request resends everything accumulated so far, not just the new tool result. A task that takes ten tool calls to finish is not one billed exchange but roughly ten, each slightly larger than the last as the growing tool-call history rides along every time. This is exactly the mechanism the "Turn" glossary entry in [Chapter 1](01-fundamentals.md#building-and-interacting) points here for: an agentic harness's tool-calling loop is what turns one user-visible turn into many underlying, individually-billed requests. `docs/efficient-agentic-use`'s [Chapter 2](../efficient-agentic-use/02-turn-session-and-context-discipline.md) covers the habits that keep that round-trip count down; it isn't repeated here.

### 4.2 Structured tool schemas

A tool is not free-form; it is described to the model with a schema the model must conform to when it decides to call that tool. In OpenAI's implementation, a function definition has a name, a natural-language description that tells the model what the function does and when to use it, and a parameters field expressed as JSON Schema, for example:

```json
{
  "type": "function",
  "name": "get_weather",
  "description": "Get current weather for a city.",
  "strict": true,
  "parameters": {
    "type": "object",
    "properties": {
      "city": { "type": "string" },
      "unit": { "type": "string", "enum": ["celsius", "fahrenheit"] }
    },
    "required": ["city", "unit"],
    "additionalProperties": false
  }
}
```

Given a prompt like "what's the weather in Paris?", the model does not answer directly; it emits a tool call naming `get_weather` with `{"city": "Paris", "unit": "celsius"}` as arguments. The application runs its own weather lookup with those arguments, returns the result, and the model uses it to write the final answer. An optional strict mode constrains the model's output so the arguments are guaranteed to match the schema exactly, rather than merely being a best effort.

Getting a tool's schema and description right is not a minor implementation detail: Anthropic's own guidance on tool design argues that as much prompt-engineering attention should go into a tool's definition as into the surrounding prompt, since an ambiguous parameter name or an under-specified description is exactly the kind of thing that causes a model to misuse a tool, in the same way a poorly documented API confuses a human developer. Anthropic's guidance gives one telling example from building a coding agent: a tool that accepted relative file paths caused mistakes once the agent had moved out of the root directory, and simply requiring absolute paths in the tool's schema, rather than adding more prose explaining the problem, fixed the failure mode completely.

### 4.3 Why this is the foundation for everything else

Once a model can call a schema-defined function and receive a result, three further ideas become possible, and each is a variation on that same core loop rather than a separate mechanism:

- A **plugin** (Section 5) is, mechanically, a bundle of tool definitions (and often a live backend) that gets added to what the model can call.
- A **skill** (Section 6) usually does not add new tool-calling machinery at all; it adds instructions, and sometimes scripts the model runs through existing tools like a shell, that tell the model how to use tools it already has more effectively for a specific domain.
- **MCP** (Section 7) is a standardized protocol for exposing tools (along with two other primitives, resources and prompts) to a model in a vendor-neutral way, so that the same server can supply tool definitions to many different harnesses without a bespoke integration for each one.

Understanding tool calling as the shared foundation makes it easier to see plugins, skills, and MCP not as three unrelated technologies, but as three different answers to the same underlying question: how does a harness decide what functions to expose to the model, and how much infrastructure sits behind them.

---

## 5. Plugins

### 5.1 What plugins are, across ecosystems

"Plugin" is used loosely across the industry, but the common thread is a packaged, installable unit that extends what an assistant can do, distinct from a one-off tool a developer wires up for a single application. A few concrete shapes this has taken:

- **ChatGPT plugins (2023, now retired).** OpenAI's original description called plugins "tools designed specifically for language models with safety as a core principle" that help ChatGPT "access up-to-date information, run computations, or use third-party services," describing them as being like "eyes and ears" for the model. A plugin was defined by a manifest file and an OpenAPI specification describing its endpoints; when a user enabled a plugin, documentation about it was included in the model's context so it could decide when and how to call the plugin's API.
- **Custom GPT Actions (current OpenAI mechanism).** Rather than a separate plugin store, a builder configures a specific GPT with an API schema and authentication, and ChatGPT decides when that action is relevant to a user's request and converts natural language into a structured API call.
- **IDE assistant plugins/extensions.** GitHub's own documentation for Copilot CLI draws a specific distinction worth noting because it generalizes well beyond GitHub: "An extension is a single JavaScript module that you write to add tools and slash commands, backed by code that runs in your session. A plugin is an installable package that bundles reusable components, such as agents, skills, hooks, and integrations, and can be distributed through a marketplace." Claude Code uses the word the same way: a plugin there is "a bundle of skills, hooks, subagents, and MCP servers packaged as a single installable unit," distributed through a marketplace.
- **Browser-extension-style AI plugins.** A related but distinct category: browser extensions that inject AI-assistant capability into a user's existing browsing session (for example, summarizing a page or drafting a reply inline), typically by giving a model access to the current page's content and a small set of page-level actions rather than a backend API.

### 5.2 The general shape of a plugin

Despite the differences above, most plugin systems share a structure: a manifest or schema that declares what the plugin can do and how to authenticate, a description surfaced to the model (as text in its context, much like a tool schema) so it knows when to reach for the plugin, and, usually, a live backend or integration that the harness calls out to when the model decides to use it. Concretely, in the original ChatGPT design, that meant a plugin was described by an `ai-plugin.json` manifest (name, description, authentication method) plus an OpenAPI specification listing the plugin's HTTP endpoints, hosted on the developer's own server; enabling the plugin surfaced that documentation to the model as ordinary text in its context, and a matching user request triggered a tool-call-like invocation of the relevant endpoint. That last point is what tends to distinguish a "plugin" from a "skill" in the next section: a plugin typically implies a running integration with an external system, not just a set of instructions, and typically requires the developer to host and maintain that backend indefinitely.

### 5.3 How the concept has evolved

The ChatGPT plugin ecosystem is a clear, verifiable example of a mechanism being deprecated and replaced. OpenAI's original plugins page for ChatGPT now begins with a note that "OpenAI plugins have been deprecated." According to OpenAI's own developer community forum, plugin conversations stopped working entirely as of April 9, 2024, and OpenAI staff there confirmed that "with the launch of GPTs and the GPT Store, we were able to make many improvements that plugin users had asked for," describing Custom GPTs as the intended feature-parity replacement, with GPT Actions serving as the closest direct analog to the old plugin mechanism for developers who need to call a live API. There is no way to reactivate the legacy plugin mechanism; a builder who wants the same behavior today has to reconstruct it as a Custom GPT Action.

### 5.4 Security note

Any plugin is, by definition, giving a model a new way to reach outside its own context into a live external system, which is exactly the kind of expanded attack surface covered in depth in [Chapter 6](06-security-privacy-and-data.md). This chapter does not go further into that topic; see [Chapter 6](06-security-privacy-and-data.md) for prompt injection risk through untrusted plugin content, authentication and scoping concerns, and related mitigations.

---

## 6. Skills

### 6.1 What skills are

A skill is a reusable, on-demand package of instructions (and, optionally, scripts and reference material) that an agent loads only when it is relevant to the current task, rather than being present in every conversation regardless of need. The clearest concrete example is Anthropic's Agent Skills, built around a `SKILL.md` file: a directory containing at minimum that one file, with YAML frontmatter (a `name` and a `description`) followed by a markdown body of procedural instructions. The `description` field is what the model matches an incoming request against to decide whether the skill is relevant, so it has to state both what the skill does and when to use it. Claude Code's own glossary defines a skill the same way: "A SKILL.md file containing instructions, knowledge, or a workflow that Claude adds to its toolkit. Claude loads a skill automatically when relevant."

A skill directory can bundle more than the top-level file: additional markdown reference files for detail too long to keep in the main instructions, and executable scripts that the model runs (through a shell or code-execution tool it already has) rather than having to generate equivalent code from scratch each time. A minimal `SKILL.md` looks like this:

````markdown
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge
  documents. Use when working with PDF files or when the user mentions
  PDFs, forms, or document extraction.
---

# PDF Processing

## Quick start

Use pdfplumber to extract text from PDFs:

```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

For advanced form filling, see FORMS.md.
````

The `description` field is doing real work here: it is the only part of the skill that is always in context, and it is what the model compares against an incoming request to decide whether to bother reading the rest of the file at all.

### 6.2 How skills differ from plugins

The distinction is about what is actually being added. A plugin, per Section 5, typically bundles a live integration: an API, a backend, a running service the harness connects to. A skill is, in the words of Anthropic's own Skills documentation, closer to "instructions, metadata, and optional resources (scripts, templates)" that get read into context and acted on using tools the agent already has. A skill does not necessarily establish any new connection to an external system at all; it can be nothing more than a well-organized set of instructions for handling a recurring type of task. Some plugin systems (Claude Code's, for instance) explicitly nest skills inside plugins as one of several bundled component types, alongside hooks, subagents, and MCP servers, which illustrates the relationship directly: a skill is a narrower, more self-contained unit than a plugin, and a plugin can contain one or more skills along with other kinds of extensions.

### 6.3 How skills differ from plain system-prompt instructions

The real innovation of the skill pattern is not the instructions themselves, teams have always been able to paste extra guidance into a system prompt, but how and when those instructions enter the model's context. Anthropic's documentation calls this progressive disclosure, and describes three distinct loading stages:

| Level | When it loads | Typical cost | Content |
| --- | --- | --- | --- |
| Metadata | Always, at startup | About 100 tokens per skill | Just the `name` and `description` from the frontmatter |
| Instructions | Only when the skill is triggered | Under roughly 5,000 tokens | The body of `SKILL.md`: the actual procedural guidance |
| Resources and scripts | Only as referenced | Zero until accessed | Additional reference files (read into context) or scripts (run, with only their output entering context) |

A conventional system prompt, or a file like a project's `CLAUDE.md`, is always loaded in full for every turn of every session, whether or not it is relevant to the current request. A skill's full instructions occupy no context budget at all until a request actually matches its description, which is what makes it practical to install many skills covering many domains without paying a large, permanent context tax for capabilities that go unused most of the time. This is the same tension, always-loaded versus on-demand context, discussed more generally in [Chapter 3](03-prompts-context-memory-and-caching.md).

### 6.4 Security note

Because a skill's instructions (and any bundled scripts) enter the model's context and can direct it to invoke tools or run code, a skill from an untrusted source is a real risk, not a theoretical one; Anthropic's own documentation warns that a malicious skill's stated purpose and actual behavior can diverge in ways that lead to data exfiltration or unauthorized system access. As with plugins, the deeper treatment of this risk, and of vetting and governance practices for skills at scale, belongs in [Chapter 6](06-security-privacy-and-data.md).

---

## 7. MCP (Model Context Protocol)

### 7.1 The problem it solves

Before MCP, an application that wanted to connect a model to several external systems, a filesystem, a database, a project-tracker API, typically had to write a separate, bespoke integration for each pairing of model-facing application and external tool. The Model Context Protocol's own specification describes its purpose as providing "a standardized way to connect LLMs with the context they need" for building an AI-powered IDE, a chat interface, or a custom workflow, regardless of which specific tools or data sources are involved. Anthropic, which created the protocol, frames the motivation in terms of security and effort as much as convenience: "open protocols allow security properties to be designed into the infrastructure once, rather than patched together one deployment at a time," and keep competition focused on the quality of an integration rather than on who happens to control it.

### 7.2 Core architecture

MCP defines a client-host-server architecture built on JSON-RPC (a lightweight, text-based protocol for making remote procedure calls, encoding each request and response as a small JSON object):

- **Hosts** are the LLM applications that initiate connections, for example an IDE, a desktop chat app, or a custom agent. The host acts as the container and coordinator: it creates and manages client instances, enforces security policy, handles user authorization, and aggregates context across every connection.
- **Clients** live inside the host, one per server connection, each maintaining an isolated, stateful session with exactly one server, negotiating which protocol features that particular session supports, and routing messages between the host and the server.
- **Servers** are the programs that expose specific capabilities, files and git in a local process, a database, a set of external APIs, over the protocol. A server operates independently, exposes only its own resources, tools, and prompts, and, by design, cannot see the rest of the conversation or reach into other connected servers; the host is what enforces that isolation.

A single host commonly runs several clients at once, each talking to a different server, some running as local processes and some reached over the network, which is what lets one AI application draw on many independent, specialized integrations at the same time without those integrations having to know about each other:

```
              ┌───────────────────────────────────────────┐
              │            Host application                │
              │        (IDE, desktop app, custom agent)     │
              │                                              │
              │   ┌─────────┐  ┌─────────┐  ┌─────────┐     │
              │   │Client 1 │  │Client 2 │  │Client 3 │     │
              └───┴────┬────┴──┴────┬────┴──┴────┬────┴─────┘
                       │            │            │
                  1:1  │       1:1  │       1:1  │
                       ▼            ▼            ▼
               ┌──────────┐  ┌──────────┐  ┌──────────┐
               │ Server:   │  │ Server:   │  │ Server:   │
               │ files/git │  │ database  │  │ external  │
               │ (local)   │  │ (local)   │  │ API (net) │
               └──────────┘  └──────────┘  └──────────┘
```

Each server exposes its resources, tools, and prompts only to its own client; it has no visibility into the other two connections or into the host's full conversation, a deliberate isolation boundary the specification enforces at the host level.

### 7.3 The three primitives

MCP servers expose functionality through three building blocks, distinguished chiefly by who is in control of invoking them:

| Primitive | What it is | Who controls it | Example |
| --- | --- | --- | --- |
| Tools | Functions the model can actively call to take an action; schema-defined with JSON Schema, the same underlying idea as the function calling covered in Section 4 | The model | Search flights, send a message, create a calendar event |
| Resources | Passive, read-only data the application retrieves and can supply to the model as context | The application | File contents, a database schema, a calendar's contents |
| Prompts | Reusable, parameterized instruction templates that guide the model to use specific tools and resources together for a common task | The user | "Plan a vacation," "summarize my meetings" |

This three-way split is one of the more conceptually important design choices in MCP: a tool is something the model decides to invoke on its own initiative, a resource is context the host application chooses to surface, and a prompt is a workflow the human explicitly selects, and the protocol's specification is explicit that servers should not be able to see the whole conversation or peer into other connected servers, keeping each of these three concerns cleanly separated by who holds the initiative.

A travel-planning example from the protocol's own documentation shows all three working together: a user explicitly invokes a "plan a vacation" prompt with structured arguments (destination, dates, budget); the host retrieves relevant resources the user selected, calendar availability and past-trip history, and passes them to the model as context; the model, working through that context, decides on its own to call tools such as `searchFlights` and `checkWeather` to fill in gaps, then, with the user's approval where the server requires it, calls further tools to book a hotel and update the calendar. Nothing about that flow requires the travel server, the weather server, and the calendar server to know about one another; the host is what stitches their independent contributions together into one coherent interaction.

### 7.4 Who created and stewards MCP

Anthropic created and open-sourced MCP in November 2024. By December 2025, adoption had grown enough (more than 10,000 published public MCP servers, and support across ChatGPT, Cursor, Gemini, Microsoft Copilot, and Visual Studio Code, among others) that Anthropic donated the protocol to the Agentic AI Foundation (AAIF), a directed fund under the Linux Foundation co-founded by Anthropic, Block, and OpenAI, with support from Google, Microsoft, AWS, Cloudflare, and Bloomberg. Anthropic's announcement frames this as a continuation, not a handoff of responsibility: "The Model Context Protocol's governance model will remain unchanged: the project's maintainers will continue to prioritize community input and transparent decision-making," and Anthropic states it will keep investing in the protocol's development. The practical effect is that MCP is no longer a single vendor's proprietary standard, even though Anthropic originated it and remains an active contributor.

### 7.5 How MCP relates to plugins and tool use

MCP is best understood as a standardization of the same tool-calling foundation described in Section 4, extended to also cover the resource and prompt primitives from Section 7.3, wrapped in a protocol that any host or server can implement without a proprietary relationship to a single vendor. Where a ChatGPT plugin's manifest and OpenAPI schema described capabilities in a way specific to ChatGPT, and a Claude Code plugin's bundle format is specific to Claude Code, an MCP server's tools, resources, and prompts can, in principle, be connected to any MCP-compatible host, which is exactly what enabled its rapid adoption across otherwise-competing products. Put simply: tool calling is the mechanism, plugins are one (largely vendor-specific) way of packaging and distributing extended capabilities built on that mechanism, and MCP is an attempt to make the packaging and distribution layer itself a shared, open standard rather than something every vendor reinvents separately. MCP servers are also the mechanism behind one of the most common tools an agent uses: retrieval from an external knowledge base or vector store, covered in depth in [Chapter 5](05-retrieval-embeddings-and-vector-databases.md).

### 7.6 Security note

Connecting a model to arbitrary external MCP servers, especially third-party ones, expands the attack surface in the same family of ways plugins and skills do, and the protocol's own specification devotes explicit attention to tool safety, sampling controls, and user consent for exactly this reason. As with the rest of this chapter, the depth on that topic, including prompt injection through tool or resource content and practical mitigation patterns, is deferred to [Chapter 6](06-security-privacy-and-data.md).

---

## 8. How the pieces fit together

Each concept in this chapter sits at a different layer of the same stack, and it is worth seeing that stack assembled once, top to bottom:

| Layer | Concept | Role |
| --- | --- | --- |
| Reasoning | Agent / agentic loop | Decides what to do next, given the current context, and when to stop. |
| Delegation | Subagent | Splits work off into an isolated context to save the main loop's budget, run in parallel, specialize, or route to a cheaper or stronger model. |
| Scaffold | Harness | Supplies the loop, the tool wiring, the context assembly, the permissions, and the interface around the model. |
| Mechanism | Tool use / function calling | The schema-defined request/response cycle that lets the model act at all. |
| Packaging (integration-heavy) | Plugin | A bundle that adds a live, usually vendor-specific, backend integration to what the model can call. |
| Packaging (instruction-heavy) | Skill | A bundle of instructions, and optionally scripts and reference material, loaded on demand rather than always-on. |
| Packaging (open, cross-vendor) | MCP | A shared protocol for exposing tools, resources, and prompts so one server integration can serve many different harnesses. |

None of these layers works without the one below it: an MCP server is useless without a model that can call tools; a subagent is just an ordinary agent invocation with narrower scope; a harness with no tools wired up is a chatbot regardless of what model sits inside it. Building an intuition for which layer a given design question actually belongs to, "should this be a bigger system prompt or a skill," "should this be a plugin or an MCP server," "should this be one agent or three subagents," is most of what separates a well-architected agentic system from an over-engineered or under-powered one.

---

## References

### Official Documentation

- [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) - Anthropic; workflows vs. agents distinction, orchestrator-workers and routing patterns, agent-computer interface (tool design) guidance.
- [Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents) - Anthropic; definition of an agent as a self-directed loop, the four components of an agent (model, harness, tools, environment), Plan Mode and human-control tradeoffs, prompt injection framing.
- [Donating the Model Context Protocol and establishing the Agentic AI Foundation](https://www.anthropic.com/news/donating-the-model-context-protocol-and-establishing-of-the-agentic-ai-foundation) - Anthropic; MCP's creation date, adoption figures, and its December 2025 donation to the Linux Foundation's Agentic AI Foundation.
- [Glossary](https://code.claude.com/docs/en/glossary) - Claude Code documentation (Anthropic); definitions of agentic harness, agentic loop, subagent, skill, plugin, and MCP as used in Claude Code.
- [Create custom subagents](https://code.claude.com/docs/en/subagents) - Claude Code documentation (Anthropic); why and when to delegate to a subagent, and how subagents return summaries rather than full context.
- [Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams) - Claude Code documentation (Anthropic); contrast between report-back subagents and peer-to-peer agent teams.
- [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) - Anthropic; SKILL.md structure, the three-level progressive disclosure model, and skill security considerations.
- [Function calling](https://developers.openai.com/api/docs/guides/function-calling) - OpenAI; the five-step tool-calling request/response loop and structured schema/strict-mode mechanics.
- [Architecture](https://modelcontextprotocol.io/specification/2025-11-25/architecture/index) - Model Context Protocol specification; host/client/server roles, capability negotiation, and server isolation design principles.
- [Understanding MCP servers](https://modelcontextprotocol.io/docs/learn/server-concepts) - Model Context Protocol documentation; the tools/resources/prompts primitive table and who controls each one.
- [ChatGPT plugins](https://www.openai.com/blog/chatgpt-plugins) - OpenAI; original plugin concept and mechanism, with an editorial note confirming deprecation.
- [Error: Plugins are no longer supported](https://community.openai.com/t/error-plugins-are-no-longer-supported/715523) - OpenAI Developer Community; confirms the April 9, 2024 shutdown date and an OpenAI-staff statement on Custom GPTs as the replacement.
- [About extensions for GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-extensions) - GitHub; the extension-versus-plugin distinction in the Copilot CLI ecosystem.
- [Anatomy of an Agent Harness](https://www.langchain.com/blog/the-anatomy-of-an-agent-harness) - LangChain; "Agent = Model + Harness" framing and the observation that a harness dominates an agent's practical behavior.

### Research

- [ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/abs/2210.03629) - Yao et al., 2022 (arXiv); the interleaved reasoning-and-acting paradigm underlying most modern tool-using agents.

### Further Local Reading

- `02-models-training-and-inference.md`, model and inference mechanics referenced throughout this chapter.
- `03-prompts-context-memory-and-caching.md`, context window and memory concepts underlying subagent isolation and skill progressive disclosure.
- `05-retrieval-embeddings-and-vector-databases.md`, retrieval as a common tool agents call, referenced in Section 7.5.
- `06-security-privacy-and-data.md`, security implications of plugins, skills, and MCP, referenced in Sections 5.4, 6.4, and 7.6.
- `07-related-and-advanced-topics.md`, deeper coverage of orchestration patterns and observability, referenced in Sections 1.4 and 2.
- `appendices/appendix-a-plugins-and-config-paradigms.md`, practical rundown of specific plugins, skills, and MCP servers.
