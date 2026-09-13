---
audience: human
created: 2026-07-28
updated: 2026-08-31
---

# Generative AI: A Primer and Reference Guide

A guide to generative AI and large language models for a reader starting from zero knowledge, written to also hold up as a working reference once you already know the basics. It starts with plain-language definitions, then goes deep, chapter by chapter, into how these systems are built, how they are used, how they are secured, and how much they cost.

## Who this is for

Anyone who wants to genuinely understand generative AI rather than only use it: a technical reader who wants the real mechanics, not just the marketing, and who is willing to read a full glossary before the deep dives start paying off. No prior machine learning background is assumed. Chapter 1 defines every term used later in the guide.

## How to use this guide

1. **First time through:** read [Chapter 1](01-fundamentals.md) in full. It is short, plain-language, and defines every term the rest of the guide relies on.
2. **Then read Chapters 2 through 7 in order.** Each builds on the last: how models are built and run, how to work with them, how to build agentic systems on top of them, how to give them outside information, how to keep all of that secure, and the topics that cut across everything else.
3. **Already comfortable with models and prompting?** Skim Chapters 2 and 3 for vocabulary, then skip to [Chapter 4](04-agents-subagents-harnesses-and-tools.md) if agents and tooling are what you actually came for.
4. **Use the appendices as reference material, not a linear read.** Consult Appendix A when choosing plugins or configuration approaches, Appendix B when comparing vendors, Appendix C when reasoning about cost, and Appendix D whenever you need a one-line reminder of a term instead of the full glossary entry.
5. **Every non-obvious factual claim is cited.** Each chapter ends with a References section listing only sources that were actually verified as working. Vendor policies, pricing, and product names in this field change quickly; treat every citation's date as the point the claim was last checked, not a permanent guarantee.

## Table of contents

### Core chapters

| Chapter | Covers |
| --- | --- |
| [1. Fundamentals](01-fundamentals.md) | What generative AI is, a simple mental model for how it works, and a full glossary of the core vocabulary used throughout this guide. |
| [2. Models, Training, and Inference](02-models-training-and-inference.md) | What a model is made of, the transformer architecture, pretraining and post-training (SFT, RLHF, DPO), tokens and tokenization, and how inference actually generates a response. |
| [3. Prompts, Context, Memory, and Caching](03-prompts-context-memory-and-caching.md) | Prompts and prompt engineering, the context window and context engineering, short- and long-term memory, sessions, and prompt/context caching. |
| [4. Agents, Subagents, Harnesses, and Tools](04-agents-subagents-harnesses-and-tools.md) | What makes a system agentic, why work gets delegated to subagents, what a harness is, tool use and function calling, plugins, skills, and the Model Context Protocol (MCP). |
| [5. Retrieval, Embeddings, and Vector Databases](05-retrieval-embeddings-and-vector-databases.md) | Embeddings, similarity search, vector databases, and retrieval-augmented generation (RAG). |
| [6. Security, Privacy, and Data](06-security-privacy-and-data.md) | Prompt injection, jailbreaks, plugin/skill/tool/MCP security, other general risks, what actually happens to your data at major vendors, and practical guidance. |
| [7. Related and Advanced Topics](07-related-and-advanced-topics.md) | Multimodality, hallucination and evaluation, alignment and guardrails, quantization and distillation, open- vs. closed-weight models, fine-tuning vs. RAG vs. prompting, long context vs. RAG, agentic orchestration patterns, and observability. |

### Appendices (reference material, consult as needed)

| Appendix | Covers |
| --- | --- |
| [A. Plugins, Extensions, and Configuration Paradigms](appendices/appendix-a-plugins-and-config-paradigms.md) | Practical plugins, extensions, and MCP servers by ecosystem, and how these systems are actually configured (instruction files, skills directories, MCP config, memory). |
| [B. Brands and Providers](appendices/appendix-b-brands-and-providers.md) | An orientation to the major AI labs and vendors (OpenAI, Anthropic, Google, Meta, Mistral, xAI, Microsoft, Amazon, Cohere, the open-weight ecosystem) and what each is generally known for. |
| [C. Costs and Getting Value](appendices/appendix-c-costs-and-getting-value.md) | How generative AI pricing works, the cost/quality/speed tradeoff, concrete cost-reduction strategies, a decision framework matched to target output quality, a methodology for comparing providers head-to-head, and a reference table of common cost traps. |
| [D. Glossary Quick Reference](appendices/appendix-d-glossary-quick-reference.md) | A compact, alphabetical, one-line version of Chapter 1's glossary for fast lookups. |

## A one-paragraph summary, before you start

Generative AI systems, most visibly large language models (LLMs), are trained on huge amounts of text to predict the next chunk of text in a sequence, then further trained to turn that raw capability into something that follows instructions and holds a conversation. Every interaction, whether a single chat message or a complex autonomous coding agent, ultimately reduces to that same mechanism: text goes in as a prompt, the model runs inference over its trained parameters, and text comes out one token at a time. Everything else this guide covers, agents, tools, retrieval, memory, security, cost, is software and process built around that one core capability to make it useful, safe, and affordable at scale. [Chapter 1](01-fundamentals.md) starts there in full.

## Scope and limitations

- This guide reflects the state of the field as of late July 2026. Model names, prices, and specific vendor policies will drift; the underlying concepts, and the citations backing each chapter's claims, are the part meant to last.
- Coverage favors depth on the topics the guide was built to teach over encyclopedic completeness. Chapter 7 and the appendices exist specifically to catch important related topics that do not each warrant a full chapter.
- Chapter 6 in particular flags its own open questions and judgment calls in a short framing note near the top. Read that note before treating any single claim in that chapter as settled.

## Known gaps

- **Cosine similarity, ANN (approximate nearest neighbor), HNSW, and chunking** ([Chapter 5](05-retrieval-embeddings-and-vector-databases.md)): used and explained inline where first introduced, but do not have their own glossary entries in [Chapter 1](01-fundamentals.md) or [Appendix D](appendices/appendix-d-glossary-quick-reference.md).
- **LoRA (low-rank adaptation)** ([Chapter 7](07-related-and-advanced-topics.md)): referenced in the QLoRA discussion, without a standalone explanation elsewhere in the guide.
