---
audience: human
created: 2026-07-28
updated: 2026-07-31
---

# Appendix D: Glossary Quick Reference

## In short

- This is a compact, alphabetical version of the glossary in [Chapter 1](../01-fundamentals.md).
- Each entry is a one- or two-sentence reminder, not a full explanation. Use it for a fast lookup once you already understand the concept; use Chapter 1 for the full definition and this appendix's linked chapters for the deep-dive treatment.
- Terms are listed exactly as they appear in Chapter 1's glossary, alphabetized here for scanning rather than grouped by theme.

## A

**Agent**
A model given the ability to take multiple actions, typically by calling tools, in a loop, using the result of one action to decide the next, until a goal is reached. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

**Alignment**
The set of techniques used to shape a model's behavior toward helpful, honest, and non-harmful outputs, rather than simply whatever text is statistically likely to follow a prompt. See [Chapter 7](../07-related-and-advanced-topics.md).

## C

**Cache / caching**
Storing the processed representation of a repeated prompt prefix so later requests sharing that prefix are cheaper and faster to process. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

**Context**
Everything actually visible to a model when it generates a response: system prompt, conversation so far, retrieved documents, and tool results. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

**Context engineering**
Deliberately deciding what belongs in a model's context on a given turn, and what to trim, summarize, retrieve, or leave out, so the model sees the smallest set of high-signal information rather than everything available. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

**Context window**
The maximum amount of text, in tokens, a model can hold in view at once across the whole assembled input and output. See [Chapter 2](../02-models-training-and-inference.md) for mechanics and [Chapter 3](../03-prompts-context-memory-and-caching.md) for managing it.

## E

**Embedding**
A numerical vector produced by a specialized model to represent the meaning of text, image, or other content, such that similar meanings land close together in vector space. See [Chapter 5](../05-retrieval-embeddings-and-vector-databases.md).

## F

**Fine-tuning**
Continuing to train an existing model on a smaller, task-specific dataset to change its style or narrow-domain behavior, as distinct from RAG, which leaves the model's weights unchanged. See [Chapter 2](../02-models-training-and-inference.md) for mechanics and [Chapter 7](../07-related-and-advanced-topics.md) for when to use it instead of RAG.

**Foundation model**
A model trained on broad data using self-supervised learning, producing a general-purpose base later adapted to many downstream tasks. See [Chapter 2](../02-models-training-and-inference.md).

## H

**Hallucination**
Confidently stated, fluent model output that is factually wrong, fabricated, or unsupported, with no built-in signal that anything is amiss; NIST prefers the term "confabulation." See [Chapter 7](../07-related-and-advanced-topics.md).

**Harness**
The surrounding software, prompts, and orchestration logic that turns a raw model into a usable agentic application. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

## I

**Inference**
What happens every time a trained model is actually used: an input goes in, and the model runs a fixed sequence of computations over its already-trained parameters to produce an output. See [Chapter 2](../02-models-training-and-inference.md).

## M

**MCP (Model Context Protocol)**
An open standard, originally released by Anthropic in November 2024, defining a common way for AI applications to connect to external data sources, tools, and workflows. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

**Memory**
Information that persists and remains available to a model across turns or sessions, distinct from the model's trained-in knowledge or a single context window's transient contents. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

**Model**
A large software artifact, in essence a very large set of trained numerical parameters plus the code to use them, that produces new output in response to new input based on statistical patterns learned from data. See [Chapter 2](../02-models-training-and-inference.md).

**Multimodal**
A model that can accept, and often produce, more than one kind of content, such as text together with images, audio, or video. See [Chapter 7](../07-related-and-advanced-topics.md).

## O

**Open-weight vs. closed-weight (proprietary) model**
Whether a model's trained parameters are published for anyone to download and run (open-weight) or kept private behind a hosted interface (closed-weight). See [Chapter 7](../07-related-and-advanced-topics.md).

## P

**Parameters / weights**
The numerical values inside a model, adjusted during training, that collectively encode everything it can do. See [Chapter 2](../02-models-training-and-inference.md).

**Plugin**
A packaged extension, distributed and installed as a single unit, that adds capability to an AI application or harness. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md) for the concept and [Appendix A](appendix-a-plugins-and-config-paradigms.md) for specific recommendations.

**Post-training**
The additional training steps applied after pretraining, chiefly instruction tuning and preference alignment (RLHF, DPO), that turn a raw base model into a useful, controllable assistant. See [Chapter 2](../02-models-training-and-inference.md).

**Prompt**
The input given to a model, from a single typed question to a large, carefully assembled block of instructions and data. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

**Prompt engineering**
Deliberately structuring, wording, and organizing a prompt to reliably get better, more consistent output from a model. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

## R

**Retrieval-augmented generation (RAG)**
Retrieving relevant information from an external knowledge source, usually via a vector database, and inserting it into the prompt before the model generates its answer. See [Chapter 5](../05-retrieval-embeddings-and-vector-databases.md), and [Chapter 7](../07-related-and-advanced-topics.md) for RAG versus fine-tuning.

## S

**Session**
A single, continuous interaction between a user or application and a model, typically one open conversation or one API connection. See [Chapter 3](../03-prompts-context-memory-and-caching.md).

**Skill**
A modular, typically filesystem-based package of instructions and optional scripts that gives a model repeatable, specialized expertise, loaded only when relevant. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

**Subagent**
A separate agent invoked by a primary, orchestrating agent to handle a defined subtask, usually in its own context window, reporting a result back rather than joining the main conversation. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

## T

**Temperature / sampling**
A parameter controlling how a model samples its next token from a probability distribution over candidates; low temperature favors the most likely tokens, higher temperature produces more varied output. See [Chapter 2](../02-models-training-and-inference.md).

**Tokenization**
The process of splitting text into tokens using a fixed vocabulary and algorithm, run before a model processes any input. See [Chapter 2](../02-models-training-and-inference.md).

**Tokens**
The small chunks of text, sometimes a word, sometimes a few characters, that a model actually reads and writes, and the unit context limits and API pricing are measured in. See [Chapter 2](../02-models-training-and-inference.md).

**Tool use / function calling**
A model capability where, instead of only producing text, the model emits a structured request to invoke a developer-defined function and continues reasoning with the result. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

**Training**
The process of exposing a model to data and repeatedly adjusting its parameters so its predictions improve, most commonly by predicting the next chunk of text in a huge corpus. See [Chapter 2](../02-models-training-and-inference.md).

**Turn**
One exchange within a session: a user message followed by the model's response. An agentic turn can expand into many underlying model calls, one per tool-result round trip, each resending the accumulated context. See [Chapter 3](../03-prompts-context-memory-and-caching.md) and [Chapter 4](../04-agents-subagents-harnesses-and-tools.md).

## V

**Vector database**
A database purpose-built to store and efficiently search large collections of embeddings by nearest-neighbor similarity rather than exact keyword matching. See [Chapter 5](../05-retrieval-embeddings-and-vector-databases.md).

## References

### Further Local Reading

- `../01-fundamentals.md` - the full-length version of every entry above, with sourced quotes and surrounding explanation.
