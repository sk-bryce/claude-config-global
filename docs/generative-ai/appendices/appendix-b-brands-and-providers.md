---
audience: human
created: 2026-07-28
updated: 2026-07-28
---

# Appendix B: Brands and Providers

A field guide to the organizations behind the model families, products, and platforms referenced throughout this guide. Each entry covers what the organization makes, its flagship model family, what it is generally known for (with a source), and the differentiators and caveats worth knowing before you standardize on it.

## In short

- The market splits into three rough categories: frontier model labs (OpenAI, Anthropic, Google DeepMind, Meta AI, Mistral AI, xAI), cloud/platform aggregators that host models from many labs (Microsoft Azure, Amazon Bedrock), and enterprise-focused specialists (Cohere). Hugging Face anchors a fourth category: the open-weight ecosystem, which is a community rather than a single vendor.
- Nearly every lab now ships a tiered family (a flagship "large" model, a balanced mid-tier model, and a fast/cheap small model) rather than a single model, because the right choice depends on the task's complexity-versus-cost trade-off.
- Open-weight availability is not fixed by vendor: it is decided release by release. Meta's flagship as of this writing is a closed, API-only model (Muse Spark), while its Llama family remains open-weight; Mistral publishes both fully open (Apache 2.0) and more restrictively licensed lines side by side.
- Coding-focused harness vendors (Cursor, GitHub Copilot, and others) are a separate category from the model vendors in this appendix: a harness is the tool you type into, and it can usually be pointed at several of the model families described here. See [Chapter 4](../04-agents-subagents-harnesses-and-tools.md) and [Appendix A](appendix-a-plugins-and-config-paradigms.md).
- Model names, tiers, and licensing terms in this space change every few months. Treat the specific model names below as a snapshot as of July 2026, not a permanent reference; check each vendor's own model or pricing page for what is current when you read this.
- This appendix intentionally omits exact pricing figures; see [Appendix C](appendix-c-costs-and-getting-value.md) for cost and value guidance, which is easier to keep current than this document.

## How to read this appendix

Each entry below grounds its "known for" claim in one of three kinds of evidence: the vendor's own official positioning (its homepage, product pages, or documentation), an independent benchmark or leaderboard with a published methodology (principally Artificial Analysis and Arena, formerly known as LMArena or Chatbot Arena, cited where used), or a directly observable fact (for example, what license text a vendor actually publishes, or what a product page actually offers for download). Artificial Analysis publishes a documented composite index built from third-party benchmark runs; Arena instead measures anonymized, crowdsourced human head-to-head preference, aggregated with a Bradley-Terry pairwise comparison model into per-category leaderboards (text, coding, vision, and others). The two measure different things (benchmark-derived capability versus revealed human preference) and do not always agree, which is itself a useful check against treating either one as a single ground truth. This appendix deliberately avoids ranking vendors against each other on a single "best" axis: model rankings on independent leaderboards routinely reorder within weeks as new versions ship, and a ranking snapshot would be stale before this guide's next revision. Where a vendor's own materials include a benchmark comparison against competitors, that is noted as the vendor's own claim, not adopted as this guide's independent judgment.

## 1. OpenAI

**What they make:** The ChatGPT consumer application, a developer API platform (the Responses API and SDKs), the Codex coding agent, and specialized models for images (GPT Image), voice (the Realtime API), and video (Sora).

**Flagship model family:** GPT, currently organized as the GPT-5.6 generation with three named capability tiers rather than a single flagship: Sol (frontier reasoning and coding), Terra (a balanced mid-tier model), and Luna (fast, cost-sensitive workloads). All three share a roughly 1-million-token context window and support text and image input with text output, including vision (OpenAI, "Models").

**Known for:** OpenAI's ChatGPT product is widely credited with bringing conversational generative AI to mainstream consumer use, and OpenAI's API and SDK conventions (the Chat Completions and Responses request formats) have become a de facto integration standard that other vendors, including Meta and xAI, explicitly support compatibility with in their own developer tooling.

**Differentiators:**

- Context window: large class, on the order of 1 million tokens for the current flagship tier (OpenAI, "Models").
- Multimodality: text, image input, and vision across the main GPT-5.6 line, plus dedicated realtime speech and image-generation models.
- Pricing tier: a three-tier structure (flagship, balanced, efficient) within the same generation, letting a team pick a cost/capability point without changing vendors.
- Coding: the Codex agent and Sol-tier reasoning models are positioned specifically for complex reasoning and coding, including long-running agentic tasks (OpenAI, "Models").
- Open-weight releases: OpenAI is primarily a closed, API-first vendor for its flagship GPT line, but it has also published open-weight models (gpt-oss-120b and gpt-oss-20b) under the Apache 2.0 license, sized to run on a single high-end GPU or consumer hardware respectively (OpenAI / GitHub, "openai/gpt-oss").
- Enterprise features: data residency options, reserved and priority processing capacity, and batch processing discounts for asynchronous workloads.

**Caveat:** OpenAI iterates its naming and tiering scheme frequently (it moved from single numbered releases to the Sol/Terra/Luna tier names within the GPT-5.x generation); pin exact model IDs in production rather than relying on a tier name to mean the same thing indefinitely.

## 2. Anthropic

**What they make:** The Claude family of models; the Claude.ai consumer and business chat product; Claude Code, a terminal- and IDE-based agentic coding tool; and a growing set of domain-specific apps built on the same models, including Claude Cowork (an agentic feature that delegates multi-step tasks across a user's files, calendar, email, and connected apps) and Claude Science (research-oriented workflows) (Anthropic, "Claude Cowork on web and mobile"). Cowork is a specific product feature, not to be confused with "Claude for Work," Anthropic's own umbrella term (used in its privacy documentation, see [Chapter 6](../06-security-privacy-and-data.md)) for its commercial Team and Enterprise plans generally.

**Flagship model family:** Claude, currently spanning (from most to least capable per Anthropic's own tiering) a restricted top tier (Fable/Mythos class), Opus (Anthropic's recommended tier for "serious coding and knowledge work"), Sonnet (the balanced, high-volume agentic tier), and Haiku (the fastest, most cost-efficient tier) (Anthropic, "Models overview").

**Known for:** Anthropic states its mission is to ensure "the world safely makes the transition through transformative AI," and structures its public communication and product design (Responsible Scaling Policy, published safeguards on its most capable releases) around that framing (Anthropic, "Claude's Constitution"). Separately, Claude Code is widely used as an agentic coding harness that operates directly in a terminal, IDE, or CI pipeline rather than only through a chat window (Anthropic, "Claude Code").

**Differentiators:**

- Context window: large class, 1 million tokens for the current Opus, Sonnet, and top-tier models; the fast/cheap Haiku tier uses a smaller 200,000-token window (Anthropic, "Models overview").
- Multimodality: text and image input with text output and vision across all current models.
- Coding-specific strength: Claude Code is a first-party, purpose-built coding harness (not just API access to a general chat model), with support for multi-file edits, running commands, and orchestrating many parallel subagents on a single task.
- Open-weight releases: none. Anthropic does not publish open-weight models; every Claude model is accessed through Anthropic's own API or a partner cloud, not downloaded and self-hosted.
- Pricing tier: a four-tier structure (from the restricted top tier down through Opus, Sonnet, and Haiku) rather than one flagship, letting customers trade capability for cost the same way OpenAI's Sol/Terra/Luna tiers do.
- Enterprise features: available directly and through Amazon Bedrock, Google Cloud Vertex AI, and Microsoft Foundry, so enterprises already committed to one of those clouds can consume Claude through their existing procurement relationship.
- Availability quirk: Anthropic's most capable tier is released in two variants, a generally available one with conservative safety filters and a second, capability-identical variant with certain safeguards (particularly around cybersecurity) lifted, restricted to a small set of vetted organizations rather than sold generally.

**Caveat:** rate limits and available "effort" or reasoning levels vary by plan and surface (API vs. Claude Code vs. claude.ai); a workflow that runs fine in one surface can hit different throttling in another.

## 3. Google DeepMind / Google

**What they make:** The Gemini model family, the Gemini consumer app, Google AI Studio and Vertex AI for developers, and deep integration of Gemini into Google Search (AI Mode), Google Workspace, and Android.

**Flagship model family:** Gemini, developed by Google DeepMind, Alphabet's consolidated AI research division. The family is organized around a Pro tier for complex reasoning and creative tasks and a Flash tier optimized for token efficiency in coding, agentic, and high-volume work; Google also ships a "Deep Think" variant aimed at research-grade problems (Google DeepMind, "Gemini").

**Known for:** Google positions Gemini's Flash tier specifically around agentic coding and multimodal throughput, publishing head-to-head benchmark comparisons (including SWE-Bench Pro, Terminal-Bench, and long-context retrieval tests) against competing frontier models on its own model page (Google DeepMind, "Gemini"). Independently, Gemini's native integration across Google's own products, Search, Gmail, Docs, Sheets, and Meet, is a differentiator Google markets directly to enterprise Workspace customers (Google Workspace, "AI tools for a better way to work").

**Differentiators:**

- Context window: very large class; Google has previously marketed million-token-plus context windows as a signature Gemini capability, and its long-context retrieval benchmarks are a standing part of its own model comparisons.
- Multimodality: native text, image, audio, video, and code handling as both input and output is a longstanding Gemini design goal, extending to dedicated Gemini Robotics (vision-language-action) and Gemini Image models.
- Ecosystem integration: the deepest first-party integration into a major existing consumer and productivity suite (Search, Gmail, Docs, Sheets, Slides, Drive, Meet) of any vendor in this appendix.
- Open-weight releases: Google publishes a separate open-weight family, Gemma, distinct from the closed Gemini API models. The latest generation (Gemma 4) is released under the Apache 2.0 license, spans edge-sized to 31-billion-parameter variants, natively handles text, image, and (on smaller variants) audio input, and supports context windows up to 256,000 tokens (Google, "Gemma 4: Byte for byte, the most capable open models").
- Coding-specific strength: Google Antigravity, a dedicated "AI-first development platform," and the Flash-tier models' published token-efficiency claims on agentic coding benchmarks are Google's primary coding-focused offerings, distinct from the general-purpose Gemini app (Google DeepMind, "Gemini").
- Pricing tier: spans a no-cost path through the Gemini app and Google AI Studio, a paid consumer tier bundled into Google One/Workspace subscriptions, and metered developer API pricing that varies by model tier (Pro, Flash, Flash-Lite), so the relevant "price" depends heavily on which surface (consumer app vs. developer API vs. Workspace seat) you are evaluating.
- Enterprise features: a dedicated Gemini Enterprise Agent Platform for building, scaling, and governing agents, distinct from the consumer Gemini app.

**Caveat:** Google's release cadence for its top "Pro" reasoning tier has been publicly inconsistent; a next-generation Pro model has been reported as delayed past its original announced window, with smaller "Flash" tier models shipping in the interim. Treat any specific Pro-tier version number as likely to be superseded soon, and check Google's own model page for the current generally available flagship before committing to it in production.

## 4. Meta AI

**What they make:** The Llama family of open-weight models, the Meta AI app and assistant, and, as of 2026, a separate proprietary model line (Muse) developed by Meta Superintelligence Labs.

**Flagship model family:** This is the one entry in this appendix where "flagship" and "open-weight" have diverged. Llama (currently Llama 4, in Scout and Maverick variants) remains Meta's open-weight family, released under a custom Llama Community License (Meta, "Llama 4 Community License Agreement"). Meta's newest and most capable model, Muse Spark, is offered only through Meta's own hosted Meta Model API and the Meta AI app, not as downloadable weights, marking a shift away from open-weight releases at the frontier (Meta AI, "Llama").

**Known for:** Llama was one of the first widely adopted open-weight large model families and is credited with substantially lowering the barrier to self-hosted, fine-tunable large language models across the industry; Meta's own Llama 4 model card documents multilingual text-and-image input with multilingual text-and-code output and mixture-of-experts (MoE) architectures, models that route each input to only a small subset of a larger pool of specialized "expert" sub-networks rather than running every parameter on every input, trading some added routing complexity for cheaper inference at a given parameter count, at up to a 10-million-token context window for the Scout variant (Meta AI / GitHub, "Llama 4 model card"). Muse Spark, by contrast, is positioned by Meta around agentic workflows, computer use, and multimodal perception as a step toward what Meta calls "personal superintelligence," rather than around open distribution (Meta AI, "Llama").

**Differentiators:**

- Context window: very large class for Llama 4 Maverick and Scout (up to 10 million tokens for Scout, per Meta's own model card); Muse Spark's context window is not published on Meta's consumer-facing pages in the same way.
- Multimodality: native early-fusion multimodality (text and image in, text and code out) across the Llama 4 line.
- Open-weight strategy: Llama weights are downloadable and self-hostable under the Llama Community License; Muse Spark is not.
- Pricing tier: because Llama is self-hosted, "pricing" is really an infrastructure cost you control directly, and Meta does not sell a first-party hosted API for it. Muse Spark, by contrast, is metered, usage-based access through Meta's own Meta Model API, with an OpenAI SDK-compatible interface to lower switching friction for existing developers.
- Coding-specific strength and enterprise features: Muse Spark is explicitly positioned around agentic coding, tool use, web search grounding, and computer use, with a public preview API aimed at developers rather than a packaged enterprise product; Meta does not currently offer the kind of dedicated enterprise compliance tooling (certifications, guardrails-as-a-product) that Azure, Bedrock, or Google Cloud package around their hosted models.
- Licensing quirk: the Llama Community License is a custom Meta license, not a standard OSI-recognized open-source license such as MIT or Apache 2.0. It requires a "Built with Llama" attribution notice, requires any AI model fine-tuned on Llama outputs to include "Llama" at the start of its name if redistributed, and requires products or services with more than 700 million monthly active users (as of the Llama 4 release date) to obtain a separate commercial license from Meta at Meta's discretion (Meta, "Llama 4 Community License Agreement").

**Caveat:** treat Llama as Meta's open-weight, developer-self-hosted line and Muse as Meta's closed, API-hosted frontier line. As of this writing, Meta has stated Llama models will "continue to be available as open source" but has not committed to a timeline for further Llama-generation releases, so the open-weight line may age relative to Meta's own closed frontier work.

## 5. Mistral AI

**What they make:** A European AI lab offering both open-weight and proprietary models, plus an enterprise platform (Studio), an agent product (Vibe), a custom-model training service (Forge), and dedicated compute infrastructure, marketed under the tagline "Frontier AI. In your hands." (Mistral AI, "Frontier AI. In your hands.").

**Flagship model family:** Mistral ships parallel model lines rather than one flagship: Mistral Large 3 (a 675-billion-parameter, granular mixture-of-experts model, fully open-weight under Apache 2.0) and the newer Mistral Medium 3.5 (described by Mistral as its "frontier-class multimodal model optimized for agentic and coding use cases," released as open weights under a Modified MIT license rather than plain Apache 2.0) (Mistral AI docs, "Models Overview"; Mistral AI docs, "Mistral Medium 3.5"). Mistral also maintains a Small line for efficient deployment and specialized models (Codestral for code, Voxtral for audio, OCR for document extraction).

**Known for:** Mistral markets itself around EU-hosted infrastructure, self-hosted and sovereign deployment options, and permissive open licensing as a differentiator from the primarily US-based frontier labs; its own materials cite deployments with organizations such as HSBC, ASML, and the European Patent Office as evidence of this enterprise and public-sector positioning (Mistral AI, "Frontier AI. In your hands.").

**Differentiators:**

- Context window: large class, 256,000 tokens for both Large 3 and Medium 3.5 (Mistral AI docs, "Models Overview").
- Multimodality: vision (image input) alongside text across its current Large and Medium tiers.
- Open-weight strategy: unusually for a frontier-scale lab, Mistral publishes full weights for multiple tiers, not just smaller distilled models, though the exact license (Apache 2.0 vs. Modified MIT) varies by release.
- Pricing tier and deployment: available as a managed cloud API, self-hosted on your own infrastructure, or through major cloud marketplaces (AWS, Azure, Google Cloud), which is a differentiator for data-residency-sensitive customers.
- Coding-specific strength: a dedicated Codestral model line and a "Vibe for code" agent product aimed specifically at asynchronous code generation and legacy code translation.
- Enterprise features: Mistral Studio for building and running agents, Mistral Forge for training and aligning custom models on proprietary data, and dedicated compute infrastructure, aimed at large customers who want an end-to-end AI stack rather than only API access (Mistral AI, "Frontier AI. In your hands.").

**Caveat:** Mistral's model catalog turns over quickly, with frequent point releases and a published deprecation/retirement schedule for older versions (visible on its own docs site); confirm a specific model ID is still active before building against it long-term.

## 6. xAI

**What they make:** The Grok model family and a unified API spanning text, code, voice, image, and video generation, offered under a company now branding itself as SpaceXAI (xAI, "SpaceXAI").

**Flagship model family:** Grok, currently at Grok 4.5, described by xAI as its model "built for coding, agentic tasks, and knowledge work" (xAI docs, "Grok 4.5"). An earlier model, Grok 4.3, remains active in the API with a larger context window and no announced retirement date, so xAI currently fields two concurrently supported frontier-class models rather than deprecating the prior one outright (xAI docs, "Models").

**Known for:** xAI markets Grok around real-time grounding through built-in web and X (formerly Twitter) search tools, and around coding performance specifically: Grok 4.5 was developed and trained in part alongside Cursor, and xAI's own materials describe it as tuned for "intelligence per unit of time and cost" in agentic coding tasks (x.ai, "Introducing Grok 4.5").

**Differentiators:**

- Context window: large class; Grok 4.5 uses a 500,000-token window, while the still-supported Grok 4.3 uses a 1-million-token window (xAI docs, "Models").
- Multimodality: text and image input on the main Grok line, plus separate Grok Imagine models for image and video generation and a dedicated Grok Voice API.
- Coding-specific strength: explicit co-development with a coding harness vendor (Cursor) rather than a general-purpose model retrofitted for coding.
- Open-weight releases: xAI's current Grok flagship is closed and API-only, but the lab has an open-weight precedent: it released the base Grok-1 model (314 billion parameters) and architecture under the Apache 2.0 license in 2024 (xAI, "Open Release of Grok-1"). That release predates and is far less capable than the current Grok 4.x line, which has not been released as open weights.
- Pricing tier: xAI prices Grok 4.5 as a premium frontier-tier model, with a lower-cost, higher-context legacy tier (Grok 4.3) kept available in parallel rather than retired.
- Enterprise features: custom rate limits, invoice billing, single sign-on, and audit logging available on request rather than by default.

**Caveat:** the company's branding is in flux (operating publicly as "SpaceXAI" as of mid-2026 alongside the longstanding x.ai domain and Grok product name), and xAI concurrently supports multiple non-sequential model versions (4.3, 4.5, and specialized build/multi-agent variants) rather than a single linear version history; check the model ID table in xAI's own docs rather than assuming the highest version number is the right default.

## 7. Microsoft

**What they make:** Microsoft is not a frontier model lab in its own right for general-purpose chat models; it is primarily a distribution and productization layer. Its two main offerings in this space are Azure OpenAI (later rebranded as part of Microsoft Foundry), which hosts OpenAI's models on Azure infrastructure with enterprise security and compliance wrapped around them, and the Copilot brand, applied across a family of distinct AI assistants embedded in different Microsoft products (Microsoft, "Microsoft Copilot").

**Flagship model family:** Microsoft's own house models (branded "MAI") exist for narrow purposes (for example, a fine-tuned coding-focused model has appeared as an option inside GitHub Copilot), but Microsoft's primary offering is hosting other labs' models, principally OpenAI's, rather than fielding its own general-purpose frontier model family (GitHub Docs, "Supported AI models in Copilot"; Azure, "Azure OpenAI in Foundry Models").

**Known for:** Microsoft is Anthropic's, and especially OpenAI's, largest distribution partner in the enterprise cloud market, wrapping OpenAI's models in Azure's compliance certifications, security tooling, and provisioned-throughput capacity commitments for regulated customers (Azure, "Azure OpenAI in Foundry Models"). Separately, "Copilot" is used as an umbrella brand across at least five distinct products: Microsoft 365 Copilot (productivity apps), Microsoft Copilot (consumer assistant), Microsoft Security Copilot (cybersecurity operations), GitHub Copilot (coding), and Copilot Studio (a no-code agent builder) (Microsoft, "Microsoft Copilot").

**Differentiators:**

- Model choice: because Azure OpenAI/Foundry hosts models from OpenAI (and, via Foundry, other labs), the effective context window, multimodality, and capability class track whichever underlying model a customer deploys, not a fixed Microsoft-specific ceiling.
- Open-weight releases: none of Microsoft's own house models are published as open weights; Microsoft's role here is almost entirely as a distributor and enterprise wrapper around other labs' models.
- Pricing tier: Azure OpenAI offers both metered pay-as-you-go pricing and Provisioned Throughput Units (reserved, predictable capacity), a deployment-model choice layered on top of whatever the underlying model's own price class is (Azure, "Azure OpenAI in Foundry Models").
- Enterprise features: this is Microsoft's core differentiator, deep integration with Azure's existing identity, compliance (including sector-specific certifications), and provisioned-capacity tooling for customers who are already Azure enterprise customers.
- Coding-specific strength: GitHub Copilot supports selecting among many underlying models (OpenAI, Anthropic, Google, xAI, and others) from within a single product, rather than shipping one fixed model (GitHub Docs, "Supported AI models in Copilot").

**Caveat:** the "Copilot" name alone does not tell you which underlying model, or even which vendor's model, is doing the work in a given product; check each Copilot surface's own documentation for its current supported-model list, since it can differ by product and by licensing tier.

## 8. Amazon

**What they make:** Amazon Bedrock, a managed platform for building generative AI applications and agents that gives access to models from many labs through one API and toolchain, plus Amazon's own first-party model lines (Nova, and the earlier Titan family) (AWS, "Amazon Bedrock").

**Flagship model family:** Nova is Amazon's current first-party foundation model family, spanning fast/cost-efficient (Lite), higher-capability (Pro), and speech-to-speech (Sonic) variants, along with Nova Forge (a service for training a customized frontier model on top of Nova) and Nova Act (an agent framework for browser/UI automation) (AWS, "Amazon Nova"). Titan was Amazon's earlier first-party model line; Amazon's own product pages now center on Nova as the primary offering.

**Known for:** Bedrock's core positioning is as a model marketplace and aggregator rather than a single-model product: Amazon's own materials describe access to "hundreds of FMs from leading AI companies" through one platform, explicitly including OpenAI's models (now generally available on Bedrock) alongside Anthropic's Claude, Meta's Llama, Mistral's models, and Amazon's own Nova (AWS, "Amazon Bedrock").

**Differentiators:**

- Context window and multimodality: not fixed; these depend entirely on which hosted model (Nova, Claude, GPT-5.6, Llama, Mistral, etc.) a given Bedrock deployment uses.
- Model choice as the core feature: Bedrock's own marketing leads with "choose the best model for your use case" and evaluation tooling to compare hosted models, rather than pushing a single house model.
- Open-weight releases: none for Amazon's own first-party lines (Nova and the earlier Titan family are both closed, hosted-only models); open-weight models from other labs (Llama, Mistral) are available through Bedrock as a hosting platform, not as an Amazon-authored release.
- Pricing tier: Amazon markets Nova specifically around "industry-leading price performance" as a lower-cost alternative to other labs' flagship models, positioning it for high-volume, cost-sensitive production workloads rather than as a capability leader (AWS, "Amazon Nova").
- Coding-specific strength: not a primary focus of Amazon's own first-party models; Amazon's agent tooling (AgentCore, Nova Act) targets general business-process and browser-UI automation rather than shipping a dedicated coding assistant, so coding-specific workloads on Bedrock typically mean selecting a hosted model from another lab (such as Claude) rather than using Nova.
- Enterprise features: Bedrock Guardrails for automated content and hallucination checks, a broad compliance certification list (including FedRAMP High and HIPAA eligibility), and AgentCore for building, connecting, and operationalizing agents with built-in memory and identity/access controls (AWS, "Amazon Bedrock").
- AWS ecosystem integration: tight coupling with other AWS services (Knowledge Bases for retrieval, Bedrock Data Automation, IAM-based access policies), which matters most to teams already standardized on AWS.

**Caveat:** Amazon's own first-party model strategy has shifted more than once (from Titan to Nova, with subsequent internal reorganization of Nova's roadmap reported in the trade press); if evaluating Amazon's own models specifically (as opposed to using Bedrock purely as a marketplace for other labs' models), confirm current model status directly on AWS's own Nova and Bedrock pages rather than assuming continuity of any specific Nova model name.

## 9. Cohere

**What they make:** Enterprise-focused generative AI: the Command family of generative models, Embed (text embeddings), Rerank (search relevance re-ranking), and Transcribe (speech-to-text), plus North, a packaged "sovereign AI workplace" product (Cohere, "Cohere").

**Flagship model family:** Command is Cohere's generative model line. Its current flagship, Command A+, is described by Cohere as an "open-source enterprise workhorse" that unifies the capabilities of the prior Command A family (a separate reasoning-specialized variant, a vision variant, and a translation variant) into a single model (Cohere, "Introducing Command A+").

**Known for:** Cohere positions itself around private, self-controlled enterprise deployment rather than a general consumer product, with Embed and Rerank in particular built specifically for retrieval-augmented generation pipelines, semantic search, and document ranking rather than open-ended chat (Cohere, "Cohere"). This retrieval/embeddings focus is a distinguishing emphasis relative to the primarily chat- and agent-first positioning of OpenAI, Anthropic, and Google.

**Differentiators:**

- Context window: mid-large class, 128,000 tokens input with up to 64,000 tokens of generation for Command A+ (Cohere, "Introducing Command A+").
- Multimodality: text and image input, plus tool use, on the flagship Command A+ model.
- Open-weight releases: unusually among enterprise-focused vendors, Cohere publishes Command A+ itself as open weights under the Apache 2.0 license, downloadable from Hugging Face in multiple quantizations small enough to run on as few as two GPUs, not just a smaller distilled sibling of a closed flagship (Cohere, "Introducing Command A+").
- Deployment model: Cohere explicitly supports deployment inside a customer's own virtual private cloud, on-premises, or in a dedicated managed environment ("Model Vault"), in addition to a standard API, which is a differentiator for data-sovereignty-sensitive customers.
- Retrieval and embeddings strength: Embed and Rerank are purpose-built, standalone products rather than a side feature of a chat model, aimed at teams building search or retrieval-augmented generation systems (see [Chapter 5](../05-retrieval-embeddings-and-vector-databases.md)).
- Enterprise features: North bundles Cohere's models, search, and agent orchestration into a single "sovereign AI workplace" product aimed at large organizations wanting one vendor relationship rather than assembling a stack themselves.

**Caveat:** Cohere is less oriented toward general consumer-facing chat and coding-agent use cases than the other labs in this appendix; evaluate it specifically for enterprise retrieval, search, private-deployment, and self-hostable-open-weight scenarios rather than as a general ChatGPT/Claude/Gemini substitute.

## 10. The open-weight ecosystem and Hugging Face

Unlike the previous nine entries, this is not a single company, and treating it like one is a common category error. It is a community and marketplace, anchored by, but not limited to, one hosting platform.

**What Hugging Face makes:** A hub hosting more than 2 million models, hundreds of thousands of datasets, and over a million interactive "Spaces" (hosted demo applications), along with widely used open-source libraries (Transformers, Diffusers, Tokenizers, PEFT, and others) for working with those models (Hugging Face, "Hugging Face").

**What the broader ecosystem is:** Every open-weight model discussed in this appendix, Meta's Llama line, Mistral's Large and Medium lines, and open releases from many labs not covered individually here, typically gets published to and distributed through Hugging Face, alongside models from labs outside the scope of this appendix (for example, DeepSeek, Alibaba's Qwen family, and others active in the open-weight space). Hugging Face itself also hosts models from Amazon, Google, Microsoft, and Meta as organizational accounts, underscoring that it functions as shared infrastructure rather than a competing model vendor (Hugging Face, "Hugging Face").

**Why this differs from a single brand:** there is no one "open-weight company" to profile the way this appendix profiles OpenAI or Anthropic. Instead there is a hosting and tooling layer (Hugging Face), a set of standard library conventions it maintains (the `transformers` library in particular has become a common loading format many other tools assume), and a large, fast-moving set of independent labs and companies (some covered above, many not) that choose to publish some or all of their models as downloadable weights rather than, or in addition to, an API.

**Differentiators:**

- Breadth: far more model diversity (in size, language, modality, and specialization) than any single vendor's catalog, because it aggregates releases from many organizations.
- Self-hosting and inspection: open weights can be downloaded, run offline, fine-tuned, and audited directly, which is not possible with API-only models from any vendor in this appendix.
- Licensing variance: because every model on the hub is published under whatever license its own creator chose, license terms vary enormously from model to model (from permissive Apache 2.0 or MIT to restrictive custom terms), and there is no single "Hugging Face license" to check; you must check each model's own card.
- Paid infrastructure: Hugging Face itself monetizes through paid compute (hosted inference endpoints and GPU-backed Spaces) and team/enterprise plans layered on top of a free, open hub, rather than through the models themselves.

**Caveat:** "open-weight" is not synonymous with "open-source" in the traditional software sense, and it is not synonymous with "unrestricted." Always read the specific license attached to a given model card (as with Meta's Llama Community License, described above) before assuming a downloaded model can be used commercially, redistributed, or fine-tuned without restriction.

**Beyond the ten vendors in this appendix:** independent evaluators such as Artificial Analysis, in the course of tracking frontier and open-weight model performance, publish comparisons that routinely include labs outside this appendix's ten featured vendors, among them DeepSeek, Alibaba's Qwen team, Moonshot AI (the Kimi model family), MiniMax, and Zhipu (Z AI), alongside newer entrants (Artificial Analysis). A beginner-to-intermediate orientation to this landscape in 2026 should expect that list of active labs to keep growing rather than settling; this appendix focuses on the ten vendors most likely to appear elsewhere in this guide, not an exhaustive market map.

## 11. A note on coding harness vendors

Every organization above makes models. A separate category of vendor makes harnesses, the IDEs, command-line tools, and agent orchestration layers a developer actually types into, which call one or more of the models above rather than being a model themselves. Cursor and GitHub Copilot are two prominent examples: GitHub's own documentation lists supported models from OpenAI, Anthropic, Google, Microsoft's own fine-tuned models, Moonshot AI, and xAI as selectable options within a single product (GitHub Docs, "Supported AI models in Copilot"), and Cursor similarly supports multiple underlying model providers rather than shipping one house model.

This appendix does not re-explain how harnesses work, what a subagent is, or how tool-calling and context management function inside one; that material lives in [Chapter 4](../04-agents-subagents-harnesses-and-tools.md). For a comparison of harness-level configuration paradigms (rules files, plugin systems, and similar conventions across different tools), see [Appendix A](appendix-a-plugins-and-config-paradigms.md). The practical implication for this appendix specifically: when you pick "which AI to use" for coding, you are usually making two semi-independent choices, which harness, and which underlying model within it, and the harness vendor is often not the model vendor.

## 12. At a glance

| Vendor | Flagship model family (as of Jul 2026) | Open-weight options | Known for |
| --- | --- | --- | --- |
| OpenAI | GPT-5.6 (Sol / Terra / Luna tiers) | Partial (gpt-oss side release, not the flagship) | The ChatGPT product and API/SDK conventions widely adopted as a de facto standard |
| Anthropic | Claude (Opus / Sonnet / Haiku, plus a restricted top tier) | No | Safety-first framing and Claude Code as a dedicated agentic coding harness |
| Google DeepMind | Gemini (Pro / Flash tiers) | Partial (separate Gemma open line) | Deepest integration into Search, Workspace, and Android of any vendor here |
| Meta AI | Llama (open) and Muse (closed), diverging | Yes, for Llama; No, for Muse | Popularizing open-weight frontier-scale models, then pivoting its newest flagship to closed |
| Mistral AI | Mistral Large 3 / Medium 3.5 | Yes (license varies by release) | European, sovereignty- and self-hosting-oriented positioning with permissive licenses |
| xAI (SpaceXAI) | Grok 4.5 (4.3 also still supported) | Partial (Grok-1, 2024; not the current flagship) | Real-time X/web search grounding and coding co-development with Cursor |
| Microsoft | Hosts OpenAI (and others) via Azure/Foundry; Copilot brand across products | No (distribution layer, not a model lab) | The Copilot brand umbrella and enterprise-grade Azure hosting of others' models |
| Amazon | Nova (first-party); Bedrock hosts many labs' models | No (Nova); varies by hosted model | Bedrock as a multi-vendor model marketplace and agent platform |
| Cohere | Command A+ (plus Embed, Rerank, Transcribe) | Yes (Command A+ itself, Apache 2.0) | Private/self-hosted enterprise deployment and retrieval/embeddings specialization |
| Hugging Face / open-weight ecosystem | Not applicable, a hub, not a model family | Yes, by definition | Aggregating and distributing open-weight models from many labs in one place |

## References

### Official Documentation

- [Models](https://platform.openai.com/docs/models) - OpenAI; current GPT-5.6 tier lineup, context window, and modality details.
- [openai/gpt-oss](https://github.com/openai/gpt-oss) - OpenAI (GitHub); OpenAI's open-weight gpt-oss-120b and gpt-oss-20b models and their Apache 2.0 license.
- [Claude Code](https://www.anthropic.com/claude-code) - Anthropic; product positioning and capabilities of Anthropic's coding harness.
- [Claude Cowork on web and mobile](https://claude.com/blog/cowork-web-mobile) - Anthropic; Claude Cowork's positioning as an agentic feature for delegating multi-step tasks.
- [Claude's Constitution](https://www.anthropic.com/constitution) - Anthropic; the "world safely makes the transition through transformative AI" mission statement quoted in this appendix.
- [Anthropic](https://www.anthropic.com/) - Anthropic; company mission and safety framing.
- [Models overview](https://docs.claude.com/en/docs/about-claude/models/overview) - Anthropic; current Claude model tiers, context windows, and capabilities.
- [Gemini](https://deepmind.google/models/gemini/) - Google DeepMind; current Gemini model lineup and Google's own cross-model benchmark comparisons.
- [AI tools for a better way to work](https://workspace.google.com/solutions/ai/) - Google Workspace; Gemini integration across Google's productivity apps.
- [Gemma 4: Byte for byte, the most capable open models](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) - Google; Gemma 4's Apache 2.0 license, sizes, context windows, and multimodality.
- [Llama](https://ai.meta.com/llama/) - Meta AI; current Muse Spark positioning and its API-only (non-open-weight) distribution.
- [Llama 4 Community License Agreement](https://llama.com/llama4/license) - Meta; full license terms for the open-weight Llama 4 family.
- [Llama 4 model card](https://github.com/meta-llama/llama-models/blob/main/models/llama4/MODEL_CARD.md) - Meta (GitHub); Llama 4 Scout and Maverick architecture, supported languages, and the 10-million-token Scout context window.
- [Frontier AI. In your hands.](https://mistral.ai/) - Mistral AI; company positioning and product lineup.
- [Models Overview](https://docs.mistral.ai/getting-started/models/models_overview/) - Mistral AI; current model catalog, licenses, and versions.
- [Mistral Medium 3.5](https://docs.mistral.ai/models/model-cards/mistral-medium-3-5-26-04) - Mistral AI; model card, license, context window, and pricing class for Mistral's frontier-class agentic/coding model.
- [SpaceXAI](https://x.ai/) - xAI; current company and product positioning.
- [Models](https://docs.x.ai/developers/models) - xAI; current Grok model lineup, context windows, and capabilities.
- [Grok 4.5](https://docs.x.ai/developers/models/grok-4.5) - xAI; Grok 4.5's model card, context window, and pricing.
- [Introducing Grok 4.5](https://x.ai/news/grok-4-5) - xAI; the announcement that Grok 4.5 was trained alongside Cursor.
- [Open Release of Grok-1](https://x.ai/news/grok-os) - xAI; xAI's 2024 open-weight release of Grok-1 under the Apache 2.0 license.
- [Azure OpenAI in Foundry Models](https://azure.microsoft.com/en-us/products/ai-services/openai-service) - Microsoft; positioning of Azure's hosted OpenAI offering.
- [Microsoft Copilot](https://www.microsoft.com/en-us/microsoft-copilot) - Microsoft; the distinct Copilot products and how the brand umbrella is structured.
- [Amazon Bedrock](https://aws.amazon.com/bedrock/) - AWS; Bedrock's positioning as a multi-vendor model marketplace and agent platform.
- [Amazon Nova](https://aws.amazon.com/ai/generative-ai/nova/) - AWS; Amazon's first-party Nova model family.
- [Cohere](https://cohere.com/) - Cohere; company positioning, Command/Embed/Rerank/Transcribe product lineup.
- [Introducing Command A+](https://cohere.com/blog/command-a-plus) - Cohere; Command A+'s open-weight Apache 2.0 release, context window, and multimodality.
- [Hugging Face](https://huggingface.co/) - Hugging Face; hub scale, hosted organizations, and open-source library ecosystem.
- [Supported AI models in Copilot](https://docs.github.com/en/copilot/reference/ai-models/supported-ai-models-in-copilot) - GitHub; evidence that a single coding harness product supports multiple underlying model vendors.

### Research

- [Artificial Analysis](https://artificialanalysis.ai/) - Artificial Analysis; an independent, methodology-documented index (Intelligence Index, Coding Index, Agentic Index, and an Openness Index for open- vs. closed-weight comparison) tracking model performance across vendors.
- [Arena Leaderboard](https://arena.ai/leaderboard) - Arena (formerly LMArena and, before that, LMSYS Chatbot Arena); live, per-category leaderboards (agent, text, coding, vision, document, and image) ranked by anonymized human head-to-head voting.
- [Chatbot Arena: An Open Platform for Evaluating LLMs by Human Preference](https://proceedings.mlr.press/v235/chiang24b.html) - Chiang et al., ICML 2024; the peer-reviewed methodology paper behind Arena's Bradley-Terry pairwise ranking approach, also cited in [Chapter 7](../07-related-and-advanced-topics.md).
