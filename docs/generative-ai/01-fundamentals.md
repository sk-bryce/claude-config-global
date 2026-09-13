---
audience: human
created: 2026-07-28
updated: 2026-07-31
---

# Chapter 1: Fundamentals

## In short

- Generative AI describes systems that produce new content (text, images, audio, code) rather than only classifying, scoring, or retrieving existing content.
  Large language models (LLMs) are the dominant form for text and code today.
- An LLM is a type of foundation model trained to predict the next chunk of text in a sequence.
  "Talking to an AI" means sending it a prompt and receiving its generated continuation as a reply; there is no separate, hidden "understanding" step.
- This chapter is a reference, not a one-time read.
  It defines the terms used throughout the rest of this guide, organized as a glossary you can return to whenever a later chapter uses an unfamiliar word.
- Deeper mechanics, agent design, retrieval systems, and security risks each get their own dedicated chapter.
  This chapter gives you just enough of each term to follow along there.
- A compact, alphabetical companion glossary lives in [Appendix D](appendices/appendix-d-glossary-quick-reference.md) for quick lookups once you already understand the concepts.

## What "generative AI" actually is

Generative AI is a category of artificial intelligence systems that produce new content: text, images, audio, video, or code.
This is different from older AI and software systems, which mostly classify input (is this email spam?), score input (how likely is this transaction to be fraud?), or retrieve existing records (find documents matching this query) rather than generate something new.

The table below places generative AI against what came before it.

| Kind of system | How it decides what to do | Typical example |
| --- | --- | --- |
| Traditional, rule-based software | Follows explicit rules and logic written by a programmer, exactly the same way every time | A tax calculator applying a fixed formula |
| Older ("discriminative") machine learning | Learns from labeled examples to predict a specific label or score for new input | A spam filter, a fraud-risk score, a recommendation ranking |
| Generative AI (including LLMs) | Learns general patterns from large amounts of data, then generates new, open-ended content across many different tasks | A chatbot answering an open-ended question, a code assistant writing a function |

Large language models (LLMs) are the technology behind most of what people mean by "generative AI" for text.
Instead of being trained for one narrow task, an LLM is trained on enormous amounts of text using a single, general objective: predicting the next chunk of text in a sequence.
That training turns out to produce a system that can then be applied to a very wide range of text-based tasks, answering questions, writing code, summarizing documents, translating languages, without needing separate, task-specific engineering for each one.
The rest of this guide is mostly about LLMs and the software built around them, though later chapters also touch on models that work with images, audio, or other content types.

## A simple mental model

A useful, if imperfect, mental model: an LLM is an extremely sophisticated, large-scale version of the autocomplete feature on a phone keyboard.
It is trained on a much larger and more diverse set of text, uses a far more capable underlying model, and is refined afterward to be helpful and follow instructions rather than simply continue whatever was typed.

When someone "talks to an AI," they are not having a conversation with a mind that stores memories and forms intentions between messages the way a person does.
They are supplying an input, a prompt, and the model performs a large but fixed computation over its trained parameters to generate an output, one token at a time, based on everything currently in front of it.
Nothing persists afterward inside the model itself, unless some other piece of software (what later chapters cover under "memory") explicitly stores and re-supplies that information.

Do not stretch this analogy further than that.
It explains the mechanical, predict-what-comes-next nature of generation, but it does not explain why the results are often useful, coherent, or seemingly reasoned; that comes from the model's scale and design, covered in [Chapter 2](02-models-training-and-inference.md).

A single exchange, in slightly more mechanical terms, looks like this:

1. You (or an application acting for you) assemble a prompt.
2. That prompt is broken into tokens (see the glossary below).
3. The model runs inference over those tokens and generates a reply, one token at a time.
4. The generated tokens are turned back into readable text and shown to you.
5. Unless something outside the model explicitly saves it, none of this exchange is retained once the session ends.

Every term in step 1 through step 5 above gets its own glossary entry next, and its own deep-dive chapter later in this guide.

## How to use this guide

This chapter gives quick, precise definitions so the deeper chapters do not need to stop and re-explain basic vocabulary.
Once a term is familiar, move on to whichever chapter covers it in depth:

- **`02-models-training-and-inference.md`**: how models are actually built and run, training, post-training, inference, tokens and tokenization, and context window mechanics.
- **`03-prompts-context-memory-and-caching.md`**: how you interact with a model in practice, prompts, context engineering, memory, sessions, and caching.
- **`04-agents-subagents-harnesses-and-tools.md`**: the software built around models to make them act, agents, subagents, harnesses, tool use, plugins, skills, and MCP.
- **`05-retrieval-embeddings-and-vector-databases.md`**: how systems give a model access to information it was not trained on, embeddings, vector databases, and retrieval-augmented generation.
- **`06-security-privacy-and-data.md`**: prompt injection, plugin and tool security risks, and what happens to your data when you use these systems.
- **`07-related-and-advanced-topics.md`**: multimodality, hallucination and evaluation, alignment and guardrails, quantization, open versus closed weights, fine-tuning versus RAG, agentic patterns, and observability.
- **`appendices/appendix-a-plugins-and-config-paradigms.md`**: specific useful plugins and configuration approaches.
- **`appendices/appendix-b-brands-and-providers.md`**: notable AI companies and what each is best known for.
- **`appendices/appendix-c-costs-and-getting-value.md`**: pricing models and how to optimize cost against quality.
- **`appendices/appendix-d-glossary-quick-reference.md`**: a compact, alphabetical version of this chapter's glossary for fast lookups.

The glossary below is the centerpiece of this chapter.
Each entry links onward to whichever chapter covers that concept in depth.

## Glossary of core terms

### Core Concepts

**Model**
A model is a large software artifact: in essence a very large set of numbers (see "Parameters / weights" below) plus the code needed to use them, that has learned statistical patterns from data and produces new output in response to new input.
Unlike a traditional program built from explicit, hand-written rules, a model's behavior emerges from training rather than being programmed line by line.
When people casually say "the AI," they usually mean one specific trained model, such as GPT-5 or Claude Opus 5, not the generative AI field as a whole.
See [Chapter 2](02-models-training-and-inference.md) for how models are built and evaluated.

**Foundation model**
A foundation model is a model trained on a broad range of general data using self-supervised learning (learning from the structure of the data itself, without hand-labeled examples).
This produces a general-purpose base that can then be adapted to many different downstream tasks, rather than one narrow job it was built for from the start.
NIST's glossary defines the term as "models trained on broad data using self-supervised learning that can be adapted such as through fine-tuning for a variety of downstream tasks."
Nearly every well-known large language model, GPT, Claude, Gemini, Llama, is a foundation model. See [Chapter 2](02-models-training-and-inference.md).

**Parameters / weights**
Parameters, also called weights, are the numerical values inside a model that were adjusted during training and that collectively encode everything the model can do.
A model with more parameters generally has more capacity to represent complex patterns, though parameter count alone is not the only, or even the best, predictor of quality.
Frontier models today range from billions to well over a trillion parameters, though exact counts for the largest closed models are usually not published by their makers.
[Chapter 2](02-models-training-and-inference.md) covers this in more depth.

**Training**
Training is the process of exposing a model to data and repeatedly adjusting its parameters so its predictions get closer to a target output, most commonly by having it predict the next chunk of text in a huge corpus of text and code.
This initial, large-scale phase is often called pretraining, and it is extremely computationally expensive, run across large clusters of specialized hardware over weeks or months.
Everything a model does afterward builds on the patterns learned during this phase.
See [Chapter 2](02-models-training-and-inference.md).

**Post-training**
Post-training is the collection of additional training steps applied after pretraining to turn a raw, next-token-predicting base model into something more useful and controllable.
The two main components are instruction tuning (teaching the model to follow instructions and answer in a question-and-answer format) and preference alignment methods such as reinforcement learning from human feedback (RLHF) or direct preference optimization (DPO).
Researchers distinguish a "base model" (pretrained only) from an instruction-tuned or aligned model (after post-training) because their behavior differs substantially: a base model tends to continue text in whatever direction is statistically likely, while a post-trained model tends to answer the question it was actually asked.
See [Chapter 2](02-models-training-and-inference.md).

**Fine-tuning**
Fine-tuning is the practice of continuing to train an existing, usually already post-trained, model on a smaller, task-specific or domain-specific dataset, in order to change its style, consistency, or narrow-domain behavior without training an entirely new model from scratch.
It is typically used either to improve accuracy on a specific task or to get comparable quality from a smaller, cheaper model.
Fine-tuning is distinct from retrieval-augmented generation (see below): fine-tuning changes the model's weights permanently, while RAG leaves the model unchanged and instead supplies new information at the moment of each request.
See [Chapter 2](02-models-training-and-inference.md) for mechanics and [Chapter 7](07-related-and-advanced-topics.md) for guidance on choosing between fine-tuning and RAG.

**Inference**
Inference is what happens every time a trained model is actually used: an input is supplied, and the model runs a comparatively fast, fixed sequence of computations over its already-trained parameters to produce an output.
Inference is far cheaper and faster than training, which is why a provider can serve enormous numbers of user requests per day against a model that took months to train once.
Every reply from a chat assistant is the result of one or more inference calls.
See [Chapter 2](02-models-training-and-inference.md).

**Tokens**
Tokens are the small chunks of text, sometimes a whole word, sometimes only a few characters, sometimes a single punctuation mark, that a model actually reads and writes, rather than raw individual characters.
Providers measure context window limits and price API usage in tokens, not words or characters, because tokens are the unit the model's internal computation actually operates on.
As a rough rule of thumb for English text, one token is roughly four characters, or about three quarters of a word.
See [Chapter 2](02-models-training-and-inference.md).

**Tokenization**
Tokenization is the process, run before a model ever processes a piece of text, of splitting a string into that sequence of tokens using a fixed vocabulary and algorithm.
OpenAI's own open-source tokenizer, tiktoken, uses a technique called byte pair encoding, and different OpenAI model families use different named encodings, such as `cl100k_base` or `o200k_base`, each with its own vocabulary.
Because tokenizers differ across model families, the same sentence can produce a different number of tokens, and therefore a different cost or context usage, depending on which model receives it.
See [Chapter 2](02-models-training-and-inference.md).

**Context window**
The context window is the maximum amount of text, measured in tokens, that a model can hold in view at once: it covers the system instructions, the conversation so far, any retrieved documents or tool results, and the response currently being generated.
Context windows have grown enormously, from a few thousand tokens in early models to hundreds of thousands, or on some current frontier models up to a million tokens.
A larger window is not automatically better, though: accuracy and recall can degrade as a window fills, an effect Anthropic's engineering documentation calls "context rot."
See [Chapter 2](02-models-training-and-inference.md) for window mechanics and [Chapter 3](03-prompts-context-memory-and-caching.md) for the practice of managing what actually goes into that window.

**Temperature / sampling**
When a model generates its next token, it does not simply always pick the single most likely candidate; it samples from a probability distribution over candidate tokens, and sampling parameters control how that distribution is shaped before a choice is made.
Temperature is the most common such parameter: a low temperature, near 0, makes output more focused and repeatable, favoring the highest-probability tokens, while a higher temperature flattens the distribution and produces more varied, less predictable output.
OpenAI's API, for example, accepts temperature values between 0 and 2, with 1 as a typical default.
A related parameter, top-p (nucleus sampling), trims away unlikely tokens before sampling and is generally tuned instead of temperature rather than alongside it.
See [Chapter 2](02-models-training-and-inference.md).

**Multimodal**
A multimodal model can accept, and in many cases produce, more than one kind of content, for example text together with images, rather than being limited to text alone.
Common combinations include text with images, audio, or video.
Microsoft's documentation describes vision-enabled multimodal models as models "that can analyze images and provide textual responses to questions about them," combining natural language processing with visual understanding in a single system.
Most current frontier chat models are multimodal to at least some degree. See [Chapter 7](07-related-and-advanced-topics.md).

**Open-weight vs. closed-weight (proprietary) model**
An open-weight model is one whose trained parameters are published for anyone to download, inspect, run, and often modify on their own hardware.
A closed-weight, or proprietary, model keeps its parameters private, accessible only through a hosted interface such as an API or chat application.
The distinction concerns who can access the underlying weights, not whether a model is free to use or whether any of its surrounding code is open source.
Anthropic, for example, has stated publicly that open-weight models without dangerous capabilities are "a public good," even though it has generally kept its own frontier Claude models closed-weight. See [Chapter 7](07-related-and-advanced-topics.md).

**Hallucination**
A hallucination, which NIST's generative AI risk guidance describes with the more precise term "confabulation," is confidently stated, fluent model output that is factually wrong, fabricated, or unsupported by the input it was given, with no built-in signal to the user that anything is amiss.
NIST prefers "confabulation" specifically to avoid implying the model has human-like intent to deceive: the phenomenon is a natural byproduct of how these models are trained to produce plausible continuations, not evidence of conscious dishonesty.
Because the output reads just as confidently whether or not it is accurate, hallucination is a central risk in any application where a user might act on an unverified answer.
See [Chapter 7](07-related-and-advanced-topics.md).

**Alignment**
Alignment is the broad set of techniques used to shape a model's behavior so that it acts in accordance with its developer's and users' intentions, typically meaning helpful, honest, and non-harmful, rather than simply producing whatever text is statistically likely to follow a prompt.
Anthropic's published approach includes a "constitution" that documents the values it trains Claude to weigh, in priority order: remaining broadly safe, then broadly ethical, then compliant with Anthropic's own guidelines, then genuinely helpful, built using techniques such as Constitutional AI and reinforcement learning from human feedback.
Alignment is an ongoing area of active research, not a single step that is finished once and never revisited.
See [Chapter 7](07-related-and-advanced-topics.md).

### Building and Interacting

**Turn**
A turn is one exchange within a session: a message from the user (or calling application) followed by the model's response, built on the conversation history accumulated so far.
In a plain chat, one turn is one API request. In an agentic system a single user-visible turn can expand into many separate underlying model calls, because each tool the model invokes returns a result the model must see before it can finish responding, and every one of those intermediate calls resends the full context accumulated to that point.
See [Chapter 3](03-prompts-context-memory-and-caching.md) for what a turn resends, and [Chapter 4](04-agents-subagents-harnesses-and-tools.md) for why an agentic turn's tool-calling loop multiplies that cost.

**Context**
Context is everything actually visible to a model at the moment it generates a response: the system prompt, the conversation so far, any retrieved documents, tool definitions, and tool results, all assembled into a single input.
"Context" describes that content itself, while the "context window" (covered above under Core Concepts) is the capacity limit on how much of it fits at once.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

**Context engineering**
Context engineering is the practice of deliberately deciding what belongs in a model's context on a given turn, and what to trim, summarize, retrieve, or leave out entirely, so the model sees the smallest set of high-signal information rather than everything available.
It sits one level above prompt engineering: prompt engineering shapes the wording of a single input, while context engineering manages the whole assembled input, including conversation history, retrieved documents, and tool results, across a session.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

**Prompt**
A prompt is the input given to a model: it can be as simple as a single question typed into a chat box, or a large, carefully assembled block of instructions, examples, and data constructed by an application on a user's behalf.
Everything a model produces is, in a technical sense, a response conditioned on the prompt it received; there is no separate "comprehension" stage distinct from generating a reply to that prompt.
A system prompt is a specific, privileged kind of prompt: instructions supplied by the application rather than the end user, typically set once and prepended ahead of the conversation on every turn, used to set the model's role, tone, or constraints for the whole session.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

**Prompt engineering**
Prompt engineering is the practice of deliberately structuring, wording, and organizing a prompt to reliably get better, more consistent output from a model.
Common techniques include giving explicit instructions, providing worked examples (often called few-shot prompting), or asking the model to reason through a problem step by step.
It sits alongside fine-tuning as a way to improve a model's behavior for a given use case, and is usually far cheaper and faster to iterate on.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

**Memory**
In an AI system, memory is information that persists and remains available to a model across turns or across separate sessions, as distinct from the model's fixed, trained-in knowledge or the transient contents of a single context window.
Memory can be as simple as an application re-inserting a summary of earlier conversation into a new prompt, or as involved as a dedicated store of facts about a user that multiple tools and sessions read from and write to.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

**Cache / caching**
Caching, in this context, most commonly refers to prompt caching: storing the processed representation of a repeated prompt prefix, such as a long system prompt or a reference document, on the provider's servers.
This makes later requests that share that prefix cheaper and faster, because the model does not have to reprocess those tokens from scratch each time.
Cached tokens still occupy space in the context window; caching changes what a request is billed for, not whether those tokens count toward the window's limit.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

**Session**
A session is a single, continuous interaction between a user (or an application) and a model, typically bounded by one open conversation in a chat interface or one connection in an API integration.
The distinction matters because a model has no memory beyond what is explicitly carried forward into its next prompt: once a session ends, nothing persists unless something outside the model, an application, a dedicated memory feature, or a saved transcript, deliberately preserves that information for later use.
See [Chapter 3](03-prompts-context-memory-and-caching.md).

### Systems Around the Model

**Agent**
An agent is a model given the ability to take multiple actions, typically by calling tools, in a loop, using the result of one action to decide the next, in order to accomplish a goal that cannot be completed in a single reply.
This differs from a plain chat model, which only produces text: an agent can, for example, read a file, run a command, observe the result, and decide what to do next on its own, repeating that cycle until the task is finished or it decides to stop.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md).

**Subagent**
A subagent is a separate agent invoked by a primary, orchestrating agent to handle a defined subtask, typically running in its own context window so its work does not consume the primary agent's context budget, and reporting a result back rather than participating directly in the main conversation.
One common pattern uses a subagent purely as an independent evaluator, one that never saw the work being produced, to check a builder agent's output, rather than letting a single agent grade its own work.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md).

**Harness**
A harness is the surrounding software, prompts, and orchestration logic, system prompts, tool definitions, loop control, memory handling, that turns a raw model into a usable agentic application; the same underlying model can behave very differently depending on the harness built around it.
Anthropic's engineering team, describing long-running coding agents, compares the underlying problem to staffing a project with engineers who each show up for a single shift with no memory of the one before.
It describes the harness as what compensates for that gap, through mechanisms such as structured progress files, version-control commits, and separate initializer and worker agent roles.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md).

**Plugin**
A plugin is a packaged extension, distributed and installed as a single unit, that adds capability to an AI application or harness, commonly bundling tool definitions, skills, or configuration together for a specific integration or workflow.
Plugins let users and organizations extend an AI tool without modifying its core, in much the same way that browser or IDE plugins extend other kinds of software.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md) for the general concept and [Appendix A](appendices/appendix-a-plugins-and-config-paradigms.md) for specific plugin recommendations.

**Skill**
A skill is a modular, typically filesystem-based package of instructions, and optionally scripts or reference material, that gives a model repeatable, specialized expertise for a class of task, loaded only when relevant rather than being repeated in every prompt.
Anthropic describes Agent Skills as turning "a general-purpose agent into a specialist," first discovering lightweight metadata about which skills are available and only loading a given skill's full instructions once a request actually needs it, a pattern known as progressive disclosure.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md).

**MCP (Model Context Protocol)**
The Model Context Protocol (MCP) is an open standard, originally released by Anthropic in November 2024, that defines a common way for AI applications to connect to external data sources, tools, and predefined workflows.
This lets developers build one integration, called a server, and have it work with any compliant AI application, called a host, instead of writing custom, one-off connectors for every combination of model and system.
Anthropic describes MCP as being "like a USB-C port for AI applications," and as of 2026 it is supported by a wide range of tools including Claude, ChatGPT, Visual Studio Code, and Cursor.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md).

**Tool use / function calling**
Tool use, also called function calling, is a model capability where, instead of only producing text, the model can emit a structured request to invoke a specific, developer-defined function, such as searching the web, querying a database, or running code, receive that function's result, and continue reasoning with it.
This is the mechanism that lets an agent actually act in the world rather than only describe what it would do.
MCP, described above, is largely a standardized way of exposing tools, along with other context, for exactly this purpose.
See [Chapter 4](04-agents-subagents-harnesses-and-tools.md).

### Retrieval and Data

**Vector database**
A vector database is a database purpose-built to store and efficiently search large collections of embeddings (see below), high-dimensional numerical vectors, by finding the vectors nearest to a given query vector rather than by exact keyword matching.
AWS describes this as enabling "unique experiences like taking a photograph with your smartphone and searching for similar images."
This nearest-neighbor search is what enables semantic search: finding content that is conceptually related to a query even when it shares none of the query's exact words.
See [Chapter 5](05-retrieval-embeddings-and-vector-databases.md).

**Embedding**
An embedding is a numerical vector, a fixed-length list of floating-point numbers, produced by a specialized model to represent the meaning of a piece of text, image, or other content, such that inputs with similar meaning end up with vectors that are close together in that vector space.
OpenAI's documentation notes that "the distance between two vectors measures their relatedness": small distances suggest high relatedness, and large distances suggest low relatedness.
Embeddings are the raw material that vector databases store and search, and they underpin semantic search, recommendation, clustering, and retrieval-augmented generation.
See [Chapter 5](05-retrieval-embeddings-and-vector-databases.md).

**Retrieval-augmented generation (RAG)**
Retrieval-augmented generation is a technique that improves a model's output by first retrieving relevant information from an external knowledge source, usually via a vector database and embedding-based similarity search, and inserting that retrieved information into the prompt before the model generates its answer.
AWS's documentation frames the goal as letting a model "reference an authoritative knowledge base outside of its training data sources before generating a response," without the cost of retraining the model itself.
This makes RAG a common way to ground answers in current, private, or domain-specific information and to reduce hallucination.
See [Chapter 5](05-retrieval-embeddings-and-vector-databases.md), and [Chapter 7](07-related-and-advanced-topics.md) for guidance on choosing between RAG and fine-tuning.

## Suggested reading order

For a first pass through this guide, read the numbered chapters in order (1 through 7); each builds on the concepts introduced in the last, per the topic map above.

Readers who already have working knowledge of models and prompting, and who mainly want to build agents or tools, can reasonably skip ahead to [Chapter 4](04-agents-subagents-harnesses-and-tools.md) after skimming Chapters 2 and 3 for vocabulary.

The appendices are reference material meant to be consulted as needed rather than read start to end: [Appendix A](appendices/appendix-a-plugins-and-config-paradigms.md) when choosing plugins or configuration approaches, [Appendix B](appendices/appendix-b-brands-and-providers.md) when comparing vendors, [Appendix C](appendices/appendix-c-costs-and-getting-value.md) when reasoning about cost, and [Appendix D](appendices/appendix-d-glossary-quick-reference.md) whenever this glossary is not close at hand.

## References

### Official Documentation

- [Context windows](https://platform.claude.com/docs/en/build-with-claude/context-windows) - Anthropic; explains context window mechanics, sizes by model, and prompt caching's relationship to the window.
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Anthropic; introduces and explains "context rot" as context windows fill.
- [What is the Model Context Protocol (MCP)?](https://modelcontextprotocol.io/docs/getting-started/intro) - Model Context Protocol documentation; official description of MCP, including the USB-C analogy.
- [Introducing the Model Context Protocol](https://www.anthropic.com/news/model-context-protocol) - Anthropic; announces MCP's November 2024 open-source release and architecture.
- [Tool use overview](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview.md) - Anthropic; explains how tool use and function calling work in the Claude API.
- [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) - Anthropic; describes Agent Skills, progressive disclosure, and the specialist framing quoted in this chapter.
- [Agent Skills quickstart](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/quickstart) - Anthropic; describes progressive disclosure of skill metadata versus full instructions.
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) - Anthropic; source of the shift-work engineer analogy and the initializer/coding agent harness pattern.
- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) - Anthropic; further detail on harness design, context resets, and evaluator subagents.
- [Our position on open-weights models](https://www.anthropic.com/news/position-open-weights-models) - Anthropic; states that open-weight models without dangerous capabilities are "a public good."
- [Claude's Constitution](https://www.anthropic.com/constitution) - Anthropic; describes the priority ordering (safe, ethical, compliant, helpful) used to align Claude's behavior.
- [Claude's Constitution (research overview)](https://www.anthropic.com/research/claudes-constitution) - Anthropic; explains the Constitutional AI training process referenced in the alignment entry.
- [Create completion (temperature and top_p parameters)](https://developers.openai.com/api/reference/resources/completions/methods/create) - OpenAI; official parameter reference confirming the 0 to 2 temperature range.
- [Vector embeddings](https://developers.openai.com/api/docs/guides/embeddings) - OpenAI; defines embeddings and the vector-distance relatedness measure quoted in this chapter.
- [Optimizing LLM accuracy](https://developers.openai.com/api/docs/guides/optimizing-llm-accuracy) - OpenAI; explains fine-tuning's purpose and process.
- [Fine-tuning techniques: choosing between SFT, DPO, and RFT](https://developers.openai.com/cookbook/examples/fine_tuning_direct_preference_optimization_guide) - OpenAI; defines fine-tuning and its main variants.
- [How to count tokens with Tiktoken](https://developers.openai.com/cookbook/examples/how_to_count_tokens_with_tiktoken) - OpenAI; explains tokenization, byte pair encoding, and named encodings such as `cl100k_base`.
- [What is a Vector Database?](https://aws.amazon.com/what-is/vector-databases/) - AWS; defines vector databases and nearest-neighbor search, source of the photo-search example quoted in this chapter.
- [What is RAG (Retrieval-Augmented Generation)?](https://aws.amazon.com/what-is/retrieval-augmented-generation/) - AWS; defines RAG and the "authoritative knowledge base" framing quoted in this chapter.
- [How to use vision-enabled chat models](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/gpt-with-vision) - Microsoft Learn; defines multimodal, vision-enabled models, source of the quoted definition.
- [foundation model - Glossary | CSRC](https://csrc.nist.gov/glossary/term/foundation_model) - NIST Computer Security Resource Center; official definition of "foundation model" quoted in this chapter.
- [Artificial Intelligence Risk Management Framework: Generative Artificial Intelligence Profile (NIST AI 600-1)](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf) - NIST; defines "confabulation" and explains its preference for that term over "hallucination."

### Research

- [Post-training: Instruction Tuning, Alignment, and Test-Time Compute](https://web.stanford.edu/~jurafsky/slp3/9.pdf) - Jurafsky and Martin, *Speech and Language Processing* (draft chapter); defines post-training, base models, instruction tuning, and preference alignment.
