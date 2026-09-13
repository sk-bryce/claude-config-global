---
audience: human
created: 2026-07-28
updated: 2026-07-28
---

# Chapter 7: Related and Advanced Topics

## In short

- Multimodal models handle text, images, audio, and video either by projecting each modality into a shared embedding space (CLIP-style) or by training one network end to end across modalities (GPT-4o style); both approaches enable vision understanding, image generation, and voice interaction.
- Hallucination is a structural byproduct of next-token prediction and of how models are evaluated, not a bug that better prompting alone removes; research indicates it cannot be fully eliminated with current training and scoring methods, only mitigated.
- Benchmarks are useful but gameable: contamination, "benchmaxxing," and ceiling effects mean a leaderboard rank does not reliably predict how well a model will do your specific task.
- Alignment and guardrails sit in real tension with capability: the safest possible model is also the least useful one, and every deployment has to pick a point on that curve.
- Quantization (fewer bits per weight) and distillation (a small model trained to imitate a large one) are the two main levers for running models cheaply, locally, or on edge devices, each with a measurable quality cost.
- "Open weight" is not "open source": weights being downloadable says nothing about training data, code, or licensing terms, and the license (Apache 2.0, Llama's community license, Mistral's tiered licenses, etc.) determines what you can actually do with a model.
- Fine-tuning, RAG, and prompting are not competing choices so much as a stack: most production systems use prompting as the default, add RAG for freshness and grounding, and reserve fine-tuning for behavior or format changes that neither can fix.
- Long context windows have not made retrieval obsolete: cost, latency, and "lost in the middle" accuracy degradation still favor retrieval for large or frequently changing corpora.
- Agentic orchestration beyond the basics includes ReAct, plan-and-execute, reflection loops, and multi-agent orchestrator/worker patterns, each trading off cost, latency, and reliability differently.
- Observability for LLM applications means treating nondeterministic, expensive, rate-limited API calls as a first-class production dependency: trace them, log them, evaluate them continuously, and design for retries.

## 1. Multimodality

A multimodal model accepts or produces more than one kind of data (text, images, audio, video) rather than text alone. There are two broad architectural strategies for getting there.

### Shared embedding space (contrastive, dual-encoder)

The canonical example is OpenAI's CLIP (Contrastive Language-Image Pre-training). CLIP trains two separate encoders, one for images and one for text, that each map their input into vectors in the same dimensional space. Training uses a contrastive objective: given a batch of `N` (image, caption) pairs, the model learns to make the `N` correct pairings have high cosine similarity while the `N^2 - N` incorrect pairings have low similarity. No manually labeled classes are needed; the model simply learns "what images and captions go together" from hundreds of millions of pairs scraped from the web.

The payoff is that images and text become directly comparable: you can embed a text query and an image with two different encoders and compare their vectors with a dot product. This underlies zero-shot image classification, text-to-image and image-to-text retrieval, and it also provides the "bridge" that diffusion-based image generators use to condition on a text prompt. A diffusion model is a generative model trained to reverse a gradual noising process: during training it learns to remove a small amount of random noise from an image at a time, and at generation time it starts from pure noise and repeatedly applies that learned denoising step until a coherent image remains, optionally steered at each step by a text embedding like CLIP's so the result matches a prompt. See `05-retrieval-embeddings-and-vector-databases.md` for how embedding spaces and similarity search work in the retrieval context; CLIP-style embeddings are the multimodal analog of the text embeddings discussed there.

A known limitation, sometimes called the "modality gap," is that image and text embeddings cluster in distinguishable regions of the shared space rather than fully interleaving, even after contrastive training pulls matched pairs together. This affects calibration in cross-modal retrieval but does not prevent the approach from working well in practice.

### Natively multimodal (single network, joint training)

The alternative, exemplified by OpenAI's GPT-4o, trains one neural network end to end across text, vision, and audio from the start, rather than bolting modality-specific encoders onto a text backbone or gluing together separate models (a language model plus a separate speech-to-text model plus a separate text-to-speech model). OpenAI reports that this joint, single-network training is what let GPT-4o respond to spoken audio in about 320 milliseconds on average, close to human conversational response time, versus multiple seconds for the prior staged pipeline of separate models. Images, audio, and text are converted into token-like representations, interleaved, and processed by the same transformer, and the model can generate text, audio, or images as needed.

The practical distinction is training regime, not just inference: a CLIP-plus-language-model pipeline trains each piece separately and connects them afterward, while a natively multimodal model sees all modalities together during pretraining, which tends to improve cross-modal reasoning and reduce latency at the cost of much more complex and expensive training infrastructure.

### Notable capabilities enabled by multimodality

| Capability | What it means in practice |
| --- | --- |
| Vision understanding | Answering questions about an image or document (charts, screenshots, handwriting, diagrams), not just recognizing objects |
| Image generation | Producing new images from a text description, either via a diffusion model conditioned on a shared embedding or via native autoregressive image-token generation |
| Voice / speech | Real-time spoken conversation, including tone and prosody in some systems, without a separate transcription step as a hard boundary |
| Video understanding | Reasoning over a sequence of frames plus audio track, used for summarization, captioning, and moderation |

### Cascaded vs. native voice pipelines

Voice interaction can be built two ways, and the difference matters for latency and expressiveness. A **cascaded pipeline** chains three separate models: speech-to-text (transcribing audio to text), a language model (reasoning over that text), and text-to-speech (synthesizing audio from the response). This is straightforward to build from off-the-shelf components but adds the latency of three sequential model calls and discards paralinguistic information (tone, pace, emphasis, emotion) at the transcription step, since text alone cannot carry it. A **native (speech-to-speech) pipeline**, as used in GPT-4o's voice mode, processes audio tokens directly within the same network that handles text and images, without a hard transcription boundary in between. This is what allows sub-second response latency and lets the model pick up on and reproduce vocal nuance that a cascaded pipeline would lose, at the cost of far more complex and expensive training.

### Limitations that persist despite multimodality

Multimodality does not remove the core limitations covered elsewhere in this guide: a vision-capable model can still hallucinate details about an image it has "read" incorrectly (misreading a chart's axis, inventing text that is not actually present in a photo), and voice models still inherit the underlying language model's factuality and alignment properties. Vision capability is also uneven across task types: current models are generally reliable at describing a scene's contents or explaining a straightforward chart, but less reliable at precise counting, fine-grained spatial reasoning ("is object A to the left of object B"), or transcribing dense, small, or degraded text with full accuracy, and errors compound when a multi-panel or highly technical image is involved.

## 2. Hallucination and Factuality

### What hallucination is

Hallucination refers to a model generating a confident, fluent statement that is false, whether that is a fabricated citation, an incorrect date, a nonexistent API method, or a plausible-sounding but wrong factual claim. The output is not distinguishable in style or confidence from a correct answer, which is what makes it dangerous in practice. As noted in [Chapter 1](01-fundamentals.md)'s glossary, NIST's generative AI risk guidance prefers the term "confabulation" for this same phenomenon, specifically to avoid implying the model has any human-like intent to deceive; this chapter uses the more common "hallucination" throughout, since that is the term the research discussed below uses.

It is useful to distinguish two related but different failure modes that both get called "hallucination":

- **Factuality failures**, where the model states something false about the world (an incorrect date, a fabricated statistic, a person who does not exist), independent of any source document.
- **Faithfulness failures**, where the model is given source material (as in RAG) and produces a claim that is not actually supported by that source, even if the claim happens to be true, or misattributes a real claim to the wrong source. This is the failure mode citations and verification steps target most directly, since a faithfulness failure can in principle be caught by checking the output against the specific source it claims to be drawn from, whereas a pure factuality failure has no source to check against in the first place.

### Why it happens

A widely cited 2025 OpenAI research paper (formalized further in a 2026 companion paper in *Nature*) argues that hallucination is a predictable, statistically inevitable consequence of two separate mechanisms, not a mysterious failure of reasoning:

1. **Pretraining has no ground-truth signal for arbitrary facts.** Next-token prediction trains a model to approximate the distribution of text it has seen, with only positive examples of fluent language and no explicit true/false labels attached to most statements. Patterns that recur predictably (spelling, syntax, common facts) are learned well and errors on them shrink with scale. Arbitrary, low-frequency facts that cannot be predicted from any pattern, such as an obscure person's exact birthday, behave statistically like noise: the model has no mechanism to know it does not know, so it produces its best guess. The researchers frame this as equivalent to a binary classification problem: if a model cannot reliably distinguish a plausible-but-false statement from a true one during training, hallucinations are the mathematically expected outcome.
2. **Evaluation and post-training reward guessing over honesty.** Even after pretraining, further stages (instruction tuning, RLHF) could in principle teach a model to say "I don't know." But the paper's audit of major benchmarks found that most use binary, accuracy-based grading that scores an abstention exactly the same as a wrong answer: zero credit. Under that incentive, the optimal strategy for any test-taker, human or model, is to always guess rather than abstain, because guessing has a nonzero chance of being scored correct and abstaining has none. Because these accuracy-only benchmarks dominate the leaderboards and model cards used to evaluate and market models, developers are structurally incentivized to build models that guess confidently rather than express calibrated uncertainty.

### Why it cannot be fully eliminated with current architectures

Because hallucination arises from the combination of an architecture that has no built-in notion of truth (it predicts likely next tokens, not verified facts) and an evaluation ecosystem that penalizes uncertainty, no purely architectural fix removes it; the researchers' own proposed mitigation is a change to how benchmarks are scored (rewarding calibrated abstention), not a change to the transformer architecture. The same paper's own statistical framework further shows total error rates for full-sentence generation running at least double the error rate the same model would show on an equivalent yes/no question, since errors can compound across a multi-token generation. In short: as long as models generate text one likely token at a time and are graded primarily on accuracy, some rate of confident falsehood is expected, not incidental.

### Mitigation approaches

None of these eliminate hallucination; they reduce its frequency or its blast radius.

| Approach | Mechanism | Where covered |
| --- | --- | --- |
| Retrieval-augmented generation (RAG) | Grounds the model's answer in retrieved source documents at inference time, so it has relevant facts in context instead of relying purely on parametric memory | `05-retrieval-embeddings-and-vector-databases.md` |
| Citations | Forcing the model to attribute claims to specific retrieved passages makes fabrication easier to catch, though a model can still cite a real source for a claim it does not actually support |
| Verification / self-check steps | A second pass (by the same model or another model) checks claims against sources or asks the model to flag low-confidence statements before returning an answer |
| Lower temperature | Reducing sampling randomness makes output more deterministic and often more conservative, though it does not add any factual grounding the model did not already have |
| Calibrated abstention prompting | Explicitly instructing the model that it is acceptable, and preferred, to say "I don't know" rather than guess, partially counteracting the evaluation incentive described above |

## 3. Evaluation and Benchmarks

### How models are evaluated

Three broad evaluation families are in common use, and most serious model comparisons draw on more than one:

- **Benchmark suites.** Fixed test sets with automatically gradable answers, such as MMLU (broad academic knowledge), HumanEval (code generation correctness), and GSM8K (grade-school math). These are cheap to run repeatedly and easy to put on a leaderboard.
- **Human preference evaluation.** Platforms such as Chatbot Arena (LMArena) show two anonymized models' responses to the same prompt to a human rater, who picks a preference or a tie, then reveal model identity only after the vote to avoid bias. Despite being commonly called "Elo," the platform has moved to a Bradley-Terry statistical model, which estimates every model's latent strength simultaneously from all pairwise votes via maximum likelihood rather than updating one match at a time, and reports 95 percent confidence intervals via bootstrap resampling. Models whose intervals overlap are considered statistically tied rather than meaningfully ranked.
- **Task-specific evals.** Custom evaluation sets built around an organization's own use case (a support-ticket classification eval, a specific coding-style eval, a domain question set), typically the most predictive of real-world usefulness for that use case precisely because they are not public and not what a model was tuned against.
- **LLM-as-judge.** Because human preference evaluation does not scale cheaply, a common technique (formalized by Zheng et al., 2023, alongside the MT-Bench benchmark) uses a strong model to grade another model's open-ended output, either scoring a single answer or picking a winner between two candidates. The same paper found that a strong judge model agreed with human preference judgments over 80 percent of the time, roughly matching the level of agreement between two different human raters, which is what makes the technique credible rather than circular. The paper also documents specific judge biases that any team relying on this technique needs to actively correct for: **position bias** (favoring whichever answer appears first or second in the prompt, corrected by swapping the order and averaging), **verbosity bias** (favoring longer answers regardless of quality, mitigated with reference-guided grading where a known-good answer is provided for comparison), and **self-enhancement bias** (a model favoring outputs that resemble its own style, which is a particular risk when using a model to judge its own outputs or a close relative's).

### Important caveats

**Benchmark contamination.** Because most public benchmarks are published openly on the web, and web-scale pretraining corpora scrape much of the public web, benchmark questions and close paraphrases routinely end up in training data, whether by accident (a benchmark question appears on a study-guide site) or by omission (no rigorous decontamination pass was run). One 2026 analysis of six frontier models found roughly 14 percent of MMLU questions showed contamination signals under a conservative detection rule, rising to over 66 percent in the single most affected subject area, and found that simply rephrasing contaminated questions (same content, different wording) dropped accuracy by an average of 7 percentage points, direct evidence that some of the reported performance reflects memorization rather than transferable capability.

**Benchmaxxing.** A related but distinct problem: even without direct contamination, labs can allocate post-training effort specifically toward improving scores on well-known benchmarks (an instance of Goodhart's law, "when a measure becomes a target, it ceases to be a good measure"). This can take the form of training on benchmark-formatted synthetic data, tuning specifically for benchmark question styles, or selecting release checkpoints based on leaderboard position rather than broader capability. Researchers modeling this as a game-theoretic problem have shown that current leaderboard designs do not have a stable equilibrium that ranks models by true underlying quality, meaning the incentive to game the benchmark is structural, not a matter of individual bad actors.

**Why rank does not predict real-world usefulness.** Several public benchmarks (MMLU, HumanEval among them) have reached the point where a dozen or more frontier models score within one or two percentage points of each other; at that resolution, differences reflect noise, evaluation-set idiosyncrasy, or minor formatting handling rather than meaningful capability gaps. A benchmark also measures a fixed, static task distribution that may not resemble your actual workload (tone, domain vocabulary, tool use, latency constraints). The practical implication, echoed across the evaluation literature, is to treat public benchmark rank as a rough, contamination-prone signal for narrowing a shortlist, and to make the final decision using a task-specific eval built from your own representative data.

## 4. Alignment and Guardrails

### What "alignment" means here

In the context of generative AI, alignment refers to training and configuring a model so that its behavior matches the intentions and values of its developers and users, as opposed to purely optimizing for the training objective (predicting likely next tokens). A base, pretrained language model has no built-in preference for being helpful, honest, or harmless; post-training steps such as instruction tuning and RLHF (reinforcement learning from human feedback, covered in `02-models-training-and-inference.md`) are what shape a base model into an assistant that follows instructions, declines certain requests, and behaves consistently across contexts. Alignment is therefore not a single switch but a stack of separate training and configuration steps, each of which can be tuned, and each of which can also fail or be circumvented (a jailbreak is precisely an attempt to find an input that defeats these trained behaviors and gets the underlying, less-constrained base capability to surface anyway; see `06-security-privacy-and-data.md` for jailbreaking and prompt injection as security concerns rather than alignment-training concerns).

### Content moderation and safety filtering

Most production LLM deployments add moderation as a layer separate from the core model:

- **Input filtering.** Screening user prompts for attempts to extract harmful content, jailbreak the system, or perform prompt injection before the prompt ever reaches the main model.
- **Output filtering.** Screening generated text (or images, audio) for disallowed content categories before it reaches the user.
- **Purpose-built safety classifier models**, such as Meta's Llama Guard, are smaller models trained specifically to classify a piece of text against a defined taxonomy of unsafe content categories, and are commonly used as the input/output check rather than relying on the main model to police itself.

### Guardrail frameworks

Guardrails exist at two levels:

- **System-level (model provider).** Baked into the model's post-training and API-level moderation, applying to every application built on that model regardless of what the developer does.
- **Application-level.** Added by whoever is building on top of the model, typically via an orchestration layer that sits between the user and the model. NVIDIA's open-source NeMo Guardrails is a representative framework here: it lets a developer define programmable rails (implemented as configuration plus flows) that can check input before it reaches the model and check output before it reaches the user, and can plug in third-party moderation models like Llama Guard, all without modifying the underlying LLM itself.

### The safety/capability tension

Every guardrail is also a constraint, and constraints trade off against usefulness. A model tuned to refuse anything remotely sensitive will decline legitimate requests (a security researcher asking about a vulnerability class, a nurse asking about drug interactions, a novelist writing a villain's dialogue), a failure mode sometimes called over-refusal. A model tuned to be maximally permissive increases the risk of generating genuinely harmful content, being used for abuse, or producing outputs that expose the developer to legal or reputational risk. There is no setting that eliminates both failure modes simultaneously: tightening one loosens the other. In practice this is why safety configuration is typically exposed as a tunable parameter (safety tiers, content filter strictness settings) rather than a single fixed answer, and why different deployments (a children's education product versus an internal security research tool) legitimately choose different points on that curve.

## 5. Quantization and Distillation for Deployment

Both techniques exist to solve the same underlying problem: frontier models are expensive to run in terms of memory and compute, and most real deployments (a laptop, a phone, an edge device, a cost-constrained production service) cannot afford the full-precision, full-size model.

### Quantization

A model's weights are normally stored as 16-bit floating point numbers (FP16 or BF16) after training, with 32-bit (FP32) used mainly as a training reference. Quantization converts those weights to a lower-precision numeric format, most commonly 8-bit integers (INT8) or 4-bit integers (INT4), storing a scale factor alongside each weight or group of weights so the model can approximately reconstruct the original value at inference time. This is a rounding operation: it is lossy, and the lost precision is permanent for that quantized copy of the model.

The practical payoff is substantial: INT8 roughly halves memory footprint versus FP16, and INT4 roughly quarters it, which directly determines whether a model fits on a given GPU or on a consumer device at all, since inference cost for large models is often dominated by memory bandwidth rather than raw compute. INT8 quantization typically produces a barely measurable quality drop on well-calibrated models. INT4 saves more memory but faces what practitioners call a "precision cliff": quality can degrade sharply, particularly on tasks like multi-step arithmetic, needle-in-haystack retrieval, and low-resource languages, if the quantization method or calibration data is poorly chosen.

Two calibration methods dominate practical INT4 quantization:

- **GPTQ** quantizes a model layer by layer, using second-order (Hessian) information to decide which weights to round first and how to adjust the remaining weights in that layer to compensate for the rounding error already introduced. It is widely supported and has an especially large ecosystem of pre-quantized community checkpoints.
- **AWQ (Activation-aware Weight Quantization)** takes a different approach: it identifies the small fraction of weights (often around 1 percent) that most strongly affect activation magnitudes and protects those specific weights from aggressive rounding, quantizing the rest more freely. This often preserves quality slightly better than GPTQ at the same bit width, particularly on instruction-tuned models.

The practical rule of thumb across sources: start at INT8 for production if VRAM allows it, since the quality hit rarely shows up in real use; move to INT4 (GPTQ or AWQ) when memory is the binding constraint, and always re-run your own evaluation set after quantizing rather than trusting perplexity alone, because the point at which quality degrades is model- and task-dependent.

### Quantization and fine-tuning together: QLoRA

Quantization and fine-tuning are usually discussed separately, but QLoRA (Dettmers et al., 2023) combines them directly and is worth calling out because it changed what hardware fine-tuning requires. Ordinary fine-tuning of a large model needs the full model plus optimizer state in high precision, which the QLoRA paper notes can require more than 780 GB of GPU memory for a 65-billion-parameter model at standard 16-bit precision, putting it out of reach of nearly all individual practitioners. QLoRA instead quantizes the frozen base model down to a custom 4-bit format (NF4, information-theoretically tuned for the roughly normal distribution of trained neural network weights) and trains only a small set of added low-rank adapter matrices (LoRA; see the README's "Known gaps" section, this guide does not yet cover LoRA itself in depth) on top of it, backpropagating through the quantized weights without ever updating them directly. Combined with a technique to quantize the quantization scale factors themselves (double quantization) and a memory-management technique to avoid out-of-memory crashes during training (paged optimizers), the paper reports this makes it possible to fine-tune a 65-billion-parameter model on a single GPU with performance matching standard full-precision fine-tuning. This is the direct link between quantization (Section 5's main subject) and fine-tuning (Section 7's subject): quantization is not only an inference-time deployment technique, it is also what makes fine-tuning itself affordable outside of large compute budgets.

### Distillation

Knowledge distillation, formalized by Hinton, Vinyals, and Dean in 2015, trains a smaller "student" model to reproduce the behavior of a larger, more capable "teacher" model, rather than training the student from scratch on raw labeled data alone. The key insight is that a teacher model's full output probability distribution (not just its single top answer) carries useful information: if an image classifier assigns a small but nonzero probability to "cat" when the correct answer is "dog," that reveals something about which classes the model considers similar, information a hard "correct/incorrect" label alone discards. Hinton's original method raises the "temperature" of the teacher's output softmax to soften this distribution into more informative "soft targets," then trains the student to match those soft targets (typically alongside the standard hard-label loss), often via a KL-divergence-based distillation loss.

For large language models, this same principle is applied to produce smaller models that retain much of a larger model's behavior at a fraction of the parameter count and inference cost, which is why many "small" or "mini" variants of frontier model families are distilled from a larger sibling rather than trained independently from scratch.

### Why both matter for cheap, local, and edge deployment

Quantization and distillation address different axes of the same cost problem and are frequently combined: distillation reduces the number of parameters (and therefore the theoretical minimum memory and compute), while quantization reduces the bits used to represent each of those parameters. A distilled model that is also quantized can run on hardware that could never host the original full-precision teacher, which is what makes local, offline, or on-device generative AI (a laptop, a phone, an embedded system with no reliable network connection) practical at all.

## 6. Open-Weight vs. Closed-Weight Models and Licensing

### What "open weight" actually means

"Open weight" means the trained model's numeric parameters are published and downloadable, so anyone can run the model themselves, inspect its outputs, and fine-tune it locally. This is a narrower claim than "open source." A genuinely open-source model, in the traditional software sense, would also require the training data (or a full account of it) and the training code to be available, so the model's behavior could in principle be reproduced or audited from scratch. Most "open weight" releases, including well-known ones, disclose the weights and often the inference code, but not the full training dataset, which means the label "open source AI" is frequently used loosely or inaccurately in marketing. Treat the two terms as distinct: open weight is a statement about distribution of the trained artifact, open source is a stronger statement about transparency of the whole pipeline that produced it.

### Licensing considerations

Licenses on open-weight models vary widely and materially affect what you can legally do:

| License family | Representative models | Key terms |
| --- | --- | --- |
| Llama Community License | Meta's Llama 4 family | Free to use, modify, and redistribute, but redistribution requires attribution ("Built with Llama") and, if you use Llama outputs to train another model you distribute, that model's name must begin with "Llama." Companies with more than 700 million monthly active users must obtain a separate license from Meta at Meta's discretion. The Llama 4 policy also withholds rights to the multimodal models specifically for individuals or companies domiciled in the EU (this does not restrict end users of a product built on Llama). |
| Apache 2.0 | Mistral 7B, the Mixtral series, Mistral Small 3 and later, Mistral Large 3, many Qwen and other community models | A standard, fully permissive open-source license: unrestricted commercial use, modification, and redistribution, with no field-of-use restrictions. |
| Mistral Research License (and its predecessor, the Mistral AI Non-Production License) | Mistral Large 2, Pixtral Large | Weights are public and downloadable, but usage is restricted to research and non-commercial purposes; production or commercial deployment requires a separate paid Mistral Commercial License. |
| DeepSeek Model License (custom, code separately under MIT) | DeepSeek-V3 and earlier | Code is MIT-licensed; model weights carry broad commercial-use permission plus explicit use-based restrictions (for example, a prohibition on military use) listed in an attached exhibit of restricted uses, and any redistributed derivative model must carry forward at least the same use-based restrictions, a "copyleft-lite" requirement not present in Apache 2.0 or MIT (DeepSeek, "LICENSE-MODEL," see References). |
| Gemma Terms of Use (custom) | Google's Gemma 1, 1.1, 2, 3, and 3n families | A source-available, Google-authored license, not an OSI-approved open-source license: it carries a Prohibited Use Policy, requires flow-down of the same use restrictions to anyone you redistribute to, and lets Google terminate the license unilaterally on a breach. Google switched its newest release, Gemma 4, to plain Apache 2.0 in March 2026, so the license attached to a Gemma model depends heavily on which generation you use. |
| Tongyi Qianwen License (custom) | Alibaba's original Qwen (2023) and some larger Qwen2 and Qwen2.5 variants (for example the 72B-parameter models) | Source-available: broad rights to use, modify, and redistribute, but commercial use by a product or service exceeding 100 million monthly active users requires a separate authorization from Alibaba Cloud. Alibaba moved its Qwen3 generation and later open-weight releases (including the large Qwen3-235B-A22B model) to plain Apache 2.0, so, as with Gemma, the applicable license depends on which Qwen generation and variant you use. |

License terms for any given model family are revised across versions, so the specific license attached to the specific model and version you intend to use should always be checked directly rather than assumed from a vendor's general reputation for openness. Gemma and Qwen both illustrate this well: each vendor ran a custom, more restrictive license on earlier generations before moving its newer flagship open-weight releases to unmodified Apache 2.0.

Mistral's own history illustrates that a single vendor can move between license models over time: after introducing the restrictive Non-Production License for Codestral in 2024, Mistral kept its largest flagship models (Mistral Large 2, Pixtral Large) under the Research License with a separate commercial track for over a year, before releasing the entire Mistral 3 family, including the 675-billion-parameter Mistral Large 3, under full Apache 2.0 in December 2025 (Mistral AI, "Introducing Mistral 3," see References). The takeaway for any specific model is to read that model's actual license text rather than assume a vendor's past licensing choices, even recent ones, still apply. See [Appendix B](appendices/appendix-b-brands-and-providers.md) for how specific vendors currently position themselves on the open-weight/closed-weight spectrum.

### Why the distinction matters

- **Cost.** Open-weight models can be self-hosted, avoiding per-token API fees at the cost of your own infrastructure and operations burden; closed-weight models are billed by the provider and require no hosting, at the cost of ongoing per-token spend.
- **Privacy.** Self-hosting an open-weight model means data never leaves your infrastructure, which matters for regulated data or strict data-residency requirements; see [Chapter 6](06-security-privacy-and-data.md) for the data-handling implications this raises.
- **Customization.** Open weights can be fine-tuned, quantized, or otherwise modified directly; closed-weight models can typically only be adapted through the provider's own fine-tuning API, prompt engineering, or RAG, since you never have direct access to the parameters.

## 7. Fine-Tuning vs. RAG vs. Prompting: A Decision Framework

These three techniques answer different questions and are frequently combined rather than chosen exclusively. The decision framework below assumes you have already read the mechanics in their respective chapters: `03-prompts-context-memory-and-caching.md` for prompting, `05-retrieval-embeddings-and-vector-databases.md` for RAG, and `02-models-training-and-inference.md` for fine-tuning mechanics.

| Question | If yes, lean toward |
| --- | --- |
| Can you describe the desired behavior clearly in instructions, with a few examples, within a reasonable context budget? | Prompting |
| Does the task need facts that are current, private, or too voluminous to fit in a prompt? | RAG |
| Does the task need a persistent change to tone, output format, domain jargon, or a narrow skill that prompting alone doesn't reliably produce? | Fine-tuning |
| Does the answer change as source documents change, week to week? | RAG (fine-tuning would need constant retraining to stay current) |
| Is the required knowledge stable and unlikely to change (a coding style, a classification taxonomy, a fixed persona)? | Fine-tuning is viable, since staleness is not a concern |
| Is your total data volume small (a handful of documents, a short reference)? | Prompting (put it directly in context) is often simpler and cheaper than building a retrieval pipeline |
| Do you need to cite sources or show provenance for an answer? | RAG, since fine-tuning bakes knowledge into weights with no per-answer source trail |
| Is latency or engineering complexity budget very tight? | Prompting first, since it requires no training pipeline or retrieval infrastructure |

### A practical ordering

Most teams should approach this roughly in order of increasing cost and complexity:

1. **Start with prompting.** It is the cheapest to iterate on, requires no training data pipeline, and a large fraction of tasks are solvable this way once prompting techniques (from `03-prompts-context-memory-and-caching.md`) are applied properly.
2. **Add RAG when the task needs external, current, or high-volume knowledge** that cannot reasonably live in the prompt: internal documentation, a product catalog, recent news, anything that changes independently of the model.
3. **Add fine-tuning only when prompting and RAG together still cannot produce the needed behavior**, typically because the issue is a systematic pattern in how the model responds (format, tone, a specialized skill, following a house style consistently) rather than a missing fact. Fine-tuning is comparatively expensive to iterate on (each change requires a new training run) and does not solve the freshness problem RAG solves, so it is best reserved for behavior changes rather than knowledge changes.

Combinations are common and often the right answer: a fine-tuned model that also uses RAG for current facts, or a prompted model with a RAG layer and a light fine-tune purely to enforce output formatting. None of these three are mutually exclusive.

### Worked examples

- **Customer support chatbot for a fast-changing product catalog.** Prices, stock levels, and product descriptions change daily. Fine-tuning would go stale almost immediately and would need constant retraining; the right combination is prompting (for tone and conversational behavior) plus RAG (to pull current catalog data at query time).
- **Code assistant that must follow a specific internal style guide and use a proprietary internal framework's idioms.** The relevant knowledge (the framework's conventions) is stable, not fact-lookup in nature, and hard to reliably convey through instructions alone across many interactions; this is a case where fine-tuning on internal code examples is more likely to produce consistent results than prompting or RAG alone, though RAG can still help by retrieving specific internal API documentation into context.
- **Legal research tool that must cite specific clauses from a large, frequently updated body of contracts.** This needs both the freshness and the source-attribution properties that only RAG provides; fine-tuning on the contract text would bake in facts as of training time with no way to show which specific clause an answer came from, which fails the citation requirement outright.

## 8. Long Context vs. RAG Tradeoffs

Context windows have grown from a few thousand tokens to hundreds of thousands or more across current frontier models, which raises a natural question: if you can fit an entire knowledge base in the prompt, do you still need retrieval?

### The case for "just put it in context"

When the total relevant material is modest and fits comfortably within budget, putting it directly in context is simpler to build (no vector database, no chunking strategy, no retrieval-quality tuning) and can outperform a poorly tuned retrieval pipeline, since there is no risk of the retriever failing to surface the right chunk.

### The case for retrieval, even with large context windows

**Cost.** Context tokens are not free: every token in the prompt is billed (and, absent prompt caching, re-processed) on every single call. Feeding an entire large corpus into every request scales cost linearly with corpus size per query, whereas retrieval pays a fixed, much smaller per-query token cost regardless of total corpus size.

**Latency.** Processing a very long prompt takes measurably longer than processing a short one, even before generation begins, because attention computation scales with sequence length. Retrieval keeps the effective prompt short by selecting only the relevant subset.

**Accuracy: the "lost in the middle" effect.** A widely cited study, "Lost in the Middle: How Language Models Use Long Contexts" (Liu et al., 2023, published in *Transactions of the Association for Computational Linguistics*), tested models on tasks requiring them to find and use a specific piece of relevant information placed at different positions within a long input. The finding was a consistent U-shaped performance curve: models perform best when the relevant information is at the very beginning or very end of the context, and performance degrades significantly, sometimes below what a model achieves with no retrieved context at all, when the relevant information sits in the middle of a long input. Critically, the paper found this held even for models explicitly designed for long contexts, and that performance continued to degrade as input length grew, meaning a larger context window does not, by itself, guarantee uniform ability to use everything inside it. The same paper's case study on open-domain question answering found that a reader model's performance saturates well before a retriever's recall does, meaning that beyond a certain point, retrieving more documents and stuffing them all into context stopped improving answers, because the model could not reliably use everything it was given even when the right document was present. Follow-up work has replicated variants of this effect in real-world retrieval-augmented pipelines, long-document summarization, and multi-hop reasoning, and while some newer models show a less sharply U-shaped curve, the general finding that models do not use long context uniformly has held up across subsequent studies.

### A caveat about "long context works great" marketing claims

Model providers commonly demonstrate long-context capability with a "needle in a haystack" test: a single fact is planted somewhere in a very long document, and the model is asked to retrieve it. Strong performance on this test is frequently cited as evidence of reliable long-context capability. The lost-in-the-middle research is a useful corrective here: needle-in-a-haystack tests typically involve retrieving one isolated fact, which is closer to the easiest end of the difficulty spectrum, whereas realistic tasks (multi-document question answering, reasoning that requires combining several scattered pieces of information, summarizing a long document faithfully throughout) are harder and more exposed to positional degradation. A model scoring well on a needle-in-a-haystack benchmark is not the same claim as a model reliably using every part of a long context for a realistic multi-fact task, and the two should not be treated as interchangeable evidence.

### Practical implication

Retrieval and long context are complementary rather than exclusive. A common pattern is to use retrieval to narrow a large corpus down to a smaller, genuinely relevant set of passages, then place that smaller set inside the context window, ordering the most important passages toward the beginning or end where models are most reliable, rather than relying on either "retrieve one tiny chunk" or "dump everything into a million-token window" alone. Long context is best understood as raising the ceiling on how much a model can be given, not as a guarantee that everything given will be used equally well.

## 9. Agentic Orchestration Patterns

`04-agents-subagents-harnesses-and-tools.md` introduces agents at a conceptual level: a model that can call tools and take multiple steps toward a goal, and how tool calling itself works mechanically (a model emitting a structured request for a named function with named arguments, which the surrounding harness executes and feeds back as an observation). This section assumes that mechanism and goes deeper into the specific control-flow patterns used to structure the resulting multi-step loop.

### ReAct (Reason + Act)

Introduced by Yao et al. in 2022, ReAct interleaves free-text reasoning ("thoughts") with concrete actions (tool calls) in a single loop: the model produces a thought, takes an action based on that thought, receives an observation from the environment (a tool's return value), and uses that observation to inform its next thought. The reasoning traces let the model track and adjust its plan as it goes and handle unexpected results, while the actions let it pull in real information rather than relying purely on what it already "knows." The original paper showed this interleaving reduced hallucination and error propagation compared to pure chain-of-thought reasoning without tool access, because the model's reasoning was periodically checked against real observations rather than drifting on its own assumptions.

ReAct's main characteristic, and its main cost driver, is that the model re-reasons and potentially re-plans at every single step. This makes it responsive to new information immediately but means the (often expensive) reasoning model is invoked once per tool call.

### Plan-and-execute

Plan-and-execute (sometimes called plan-then-execute, and related to the ReWOO and LLMCompiler variants) separates the ReAct loop's two functions into distinct components:

- **A planner**, typically a strong reasoning model, looks at the goal once (or at defined checkpoints) and produces a multi-step plan: an ordered list of steps, or a dependency graph of steps that can run in parallel.
- **An executor**, often a smaller and cheaper model or even a deterministic tool runner, carries out one step at a time, doing just enough reasoning to fill in arguments or parse a result, without re-deriving the overall plan.
- **A re-planner** periodically checks whether the existing plan is still valid given what has happened so far, and decides to continue, revise, or finish.

The tradeoff versus ReAct is roughly: plan-and-execute produces more accurate results on complex, multi-step tasks and allows using a cheap model for the repetitive execution steps while reserving the expensive model for planning, at the cost of higher latency and typically higher total token consumption per task, and reduced ability to react instantly to information that invalidates the plan mid-step (that is what the re-planner exists to catch, but it only runs periodically, not after every single action). Plan-and-execute style separation also has a security advantage worth noting: because the executor cannot alter its list of steps on its own, it is comparatively more resistant to an attacker manipulating a tool's output to redirect the agent's behavior (a form of indirect prompt injection), since command flow is fixed by the planner rather than re-derived from potentially compromised observations at every step.

### Reflection and self-critique loops

Reflexion (Shinn et al., 2023) adds a self-improvement mechanism on top of an acting agent: after attempting a task, an evaluator scores the outcome, and a separate self-reflection step has the model generate a natural-language critique of what went wrong, in effect converting a scalar success/failure signal into a written lesson. That reflection is stored in an episodic memory buffer and included in context on the next attempt at a similar task, letting the agent improve across attempts without any weight updates or fine-tuning, functioning as a form of in-context, "verbal" reinforcement learning rather than traditional gradient-based reinforcement learning. This pattern is most useful in settings where an agent gets multiple attempts at similar tasks (iterative coding, iterative research, game-like environments) rather than single-shot generation.

### Multi-agent orchestration

For sufficiently broad or parallelizable tasks, a single agent looping through ReAct or plan-and-execute can become a bottleneck: everything runs through one context window and one sequence of tool calls. The orchestrator-worker pattern addresses this by having one agent (the orchestrator, or lead agent) decompose a task into independent sub-tasks and dispatch each to a separate worker (subagent) that runs in its own isolated context window, in parallel with the others. Anthropic's published account of its own multi-agent research system describes the lead agent analyzing a query, saving its plan to external memory (since the plan needs to survive even if the lead agent's own context window fills up), spawning multiple subagents with clearly scoped, self-contained objectives, and then synthesizing the subagents' findings, in some configurations passing the synthesized result through a dedicated citation-checking agent as a final verification step before returning an answer to the user.

The key design decisions in this pattern, per that account and consistent with subsequent industry practice, are: give each worker a narrow, self-contained task description so it does not need to coordinate with siblings mid-task (which is what allows true parallelism); bound the depth of delegation (workers generally should not spawn their own workers, to avoid runaway cost); and have workers return condensed findings or references rather than full transcripts, to keep the orchestrator's own context from being overwhelmed. Anthropic reported this architecture meaningfully outperformed a single-agent baseline on complex, breadth-first research tasks, at the cost of substantially higher total token consumption, since duplicated context setup and coordination overhead are inherent to running multiple agents rather than one; the pattern is best reserved for tasks that genuinely benefit from parallel, independent exploration rather than applied by default.

### Common failure modes across these patterns

- **Compounding errors in long loops.** In any of the above patterns, an early mistake (a bad plan, a misread tool result, a flawed reflection) can propagate forward through every subsequent step, since later steps generally trust earlier context rather than re-verifying it from scratch.
- **Coordination blindness in multi-agent systems.** Because isolated workers deliberately cannot see each other's progress, they can duplicate work or, in adversarial or ambiguous cases, reach conflicting conclusions that the orchestrator must reconcile without having witnessed how each worker arrived at its answer.
- **Cost and latency scaling faster than task complexity.** Plan-and-execute and multi-agent patterns both trade higher token consumption and wall-clock latency for better accuracy or parallelism; applying them to tasks simple enough for a single ReAct loop, or a single direct prompt, adds cost and complexity without a corresponding benefit.

## 10. Observability and Reliability for LLM Applications

Running an LLM-backed application in production surfaces reliability concerns that do not exist, or are far less severe, in conventional deterministic software.

### Tracing and logging

An agent that reasons over multiple steps, calls several tools, and possibly spawns subagents produces a call graph, not a single request/response pair, and debugging a bad outcome requires being able to see that whole graph: which prompt was sent, which tool was called with which arguments, what the tool returned, and how that fed into the next step. The industry is converging on OpenTelemetry's GenAI semantic conventions, a vendor-neutral standard (using a `gen_ai.*` attribute namespace) for representing this information as spans: each model call, tool invocation, and agent step becomes a span with standardized attributes such as `gen_ai.request.model`, `gen_ai.usage.input_tokens`, and `gen_ai.usage.output_tokens`, letting traces produced by different frameworks and providers be consumed by any OpenTelemetry-compatible observability backend rather than a proprietary format. A deliberate design choice in these conventions is to store actual prompt and response text as span events rather than span attributes, since attributes are always indexed and size-limited while events can be filtered, size-capped, or dropped at the collection layer, an important distinction for controlling both cost and exposure of potentially sensitive prompt content (see `06-security-privacy-and-data.md` for the broader data-handling implications).

### Evaluation in production

A model or prompt that scored well in pre-deployment testing can still degrade after release, whether because the underlying model was updated by its provider, the input distribution shifted, or the RAG corpus behind it changed. Production evaluation means continuously scoring live or sampled outputs against defined quality criteria (task-specific evals, as described in Section 3 above, and LLM-as-judge scoring are both more relevant here than public benchmarks), rather than treating evaluation as a one-time pre-launch gate. Common practical patterns include sampling a percentage of live traffic for automated or human review, running a candidate prompt or model version against a held-out regression set before every deployment (an "eval gate" analogous to a test suite gating a code deployment), and shadow-testing a new model or prompt version against a fraction of real traffic without exposing its output to users, purely to compare its behavior against the current production version before committing to a full rollout.

### Rate limits and retries

LLM API calls are metered, latency-variable, and subject to provider-side rate limits and transient failures. Production systems need to treat this the way any external, rate-limited network dependency is treated: implement backoff-and-retry logic for transient errors, respect published rate limits proactively rather than reactively, and design for graceful degradation (a cached or simplified fallback response) when the model API is unavailable or throttled, rather than letting a single failed call cascade into a user-facing error.

### Why nondeterminism complicates debugging

Most conventional software debugging assumes that re-running the same input produces the same output, which lets you reproduce a bug reliably. An LLM call made with temperature above zero is intentionally stochastic: the same prompt can produce a different response on each call, which means a bug report of "the model said something wrong" may not reproduce on the next attempt even with identical inputs. This has two practical consequences for observability: first, logging the actual prompt and response for every call (not just the code path taken) is far more important than in deterministic systems, since it may be the only record of the specific failure; second, evaluation and testing for LLM applications generally need to account for output variance (running an eval multiple times and looking at a distribution of outcomes, or using temperature 0 for tests where reproducibility matters more than diversity) rather than treating a single output as representative.

## Where the Field Appears to Be Heading

The following is informed speculation based on visible trends as of mid-2026, not established fact, and should be weighted accordingly; none of it should be treated as a roadmap.

- **Native multimodality becoming the default, not the exception.** The shift from bolted-together modality pipelines toward single networks trained jointly across text, image, and audio (as with GPT-4o) appears likely to continue, since joint training has shown measurable latency and cross-modal reasoning benefits over staged pipelines.
- **Continued erosion of static-benchmark credibility.** Given the contamination and benchmaxxing dynamics described in Section 3, the trend toward rotating, private, or continuously refreshed evaluation sets (rather than fixed public test sets) seems likely to continue, though this concentrates evaluation authority in whoever curates those private sets, which is its own unresolved tradeoff.
- **Agent orchestration patterns maturing into standard infrastructure.** Just as web development converged on common patterns for request routing and caching, patterns like plan-and-execute and orchestrator-worker multi-agent systems seem to be moving from bespoke implementations toward more standardized frameworks and observability tooling (the OpenTelemetry GenAI conventions discussed in Section 10 are one visible sign of this).
- **The RAG-versus-long-context question likely stays a "both" answer rather than resolving toward one.** Context windows will likely keep growing, but the lost-in-the-middle research suggests raw window size alone does not solve uniform context utilization, so retrieval as a relevance filter seems likely to remain relevant rather than being made obsolete by bigger windows.

Treat all of the above as reasoned extrapolation from currently visible trends, subject to being wrong in ways that are hard to predict from inside the current moment.

## References

### Official Documentation

- [Llama 4 Community License Agreement (LICENSE file)](https://raw.githubusercontent.com/meta-llama/llama-models/refs/heads/main/models/llama4/LICENSE) - Meta; the current Llama community license terms, including the 700-million-MAU commercial threshold.
- [Llama 4 Acceptable Use Policy](https://github.com/meta-llama/llama-models/blob/main/models/llama4/USE_POLICY.md) - Meta; prohibited uses and the EU multimodal-model restriction.
- [The Mistral AI Non-Production License](https://mistral.ai/news/mistral-ai-non-production-license-mnpl/) - Mistral AI; the origin and rationale of Mistral's restricted-use license tier.
- [Introducing Mistral 3](https://mistral.ai/news/mistral-3/) - Mistral AI; announces the December 2025 release of the full Mistral 3 family, including the 675-billion-parameter Mistral Large 3, under Apache 2.0.
- [LICENSE-MODEL](https://github.com/deepseek-ai/DeepSeek-V3/blob/main/LICENSE-MODEL) - DeepSeek; the DeepSeek Model License text, including the military-use prohibition and the use-based-restriction carry-forward requirement for derivatives.
- [Gemma 4: Expanding the Gemmaverse with Apache 2.0](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html) - Google Open Source Blog; Gemma 4's move to Apache 2.0, its first OSI-approved license in the Gemma family.
- [Gemma Terms of Use](https://ai.google.dev/gemma/terms) - Google AI for Developers; the custom license covering Gemma 1 through 3n, including its Prohibited Use Policy, flow-down obligations, and unilateral termination clause.
- [QwenLM/Qwen3](https://github.com/QwenLM/Qwen3) - Alibaba Cloud (GitHub); the official statement that Qwen's open-weight models from Qwen3 onward are licensed under Apache 2.0.
- [LICENSE, Qwen/Qwen3-235B-A22B](https://huggingface.co/Qwen/Qwen3-235B-A22B/blob/main/LICENSE) - Alibaba Cloud (Hugging Face); direct confirmation that this large open-weight Qwen3 model ships under unmodified Apache 2.0.
- [Tongyi Qianwen LICENSE AGREEMENT](https://github.com/QwenLM/Qwen/blob/main/Tongyi%20Qianwen%20LICENSE%20AGREEMENT) - Alibaba Cloud (GitHub); the custom license used by the original Qwen release and some larger Qwen2/Qwen2.5 variants, including the 100-million-MAU commercial-authorization threshold.
- [Hello GPT-4o](https://openai.com/index/hello-gpt-4o/) - OpenAI; native end-to-end multimodal training and latency figures.
- [Overview: NVIDIA NeMo Guardrails Library](https://docs.nvidia.com/nemo/guardrails/about-nemo-guardrails-library/overview) - NVIDIA; application-level guardrail architecture.
- [Content Moderation and Safety Checks with NVIDIA NeMo Guardrails](https://developer.nvidia.com/blog/content-moderation-and-safety-checks-with-nvidia-nemo-guardrails/) - NVIDIA; Llama Guard integration for input/output moderation.
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) - Anthropic; orchestrator-worker multi-agent design and its cost/performance tradeoffs.
- [open-telemetry/semantic-conventions-genai](https://github.com/open-telemetry/semantic-conventions-genai) - OpenTelemetry; the `gen_ai.*` semantic conventions repository for LLM and agent observability.

### Research

- [Why Language Models Hallucinate](https://www.arxiv.org/pdf/2509.04664) - OpenAI and Georgia Tech (Kalai, Nachum, Vempala, Zhang); the statistical and evaluation-incentive account of why hallucination is structurally difficult to eliminate.
- [Why language models hallucinate](https://openai.com/index/why-language-models-hallucinate/) - OpenAI; the accessible summary of the above paper.
- [Evaluating large language models for accuracy incentivizes hallucinations](https://www.nature.com/articles/s41586-026-10549-w) - *Nature*; peer-reviewed follow-up formalizing the accuracy-versus-abstention scoring problem.
- [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/html/2307.03172v1) - Liu et al., 2023 (published in *Transactions of the Association for Computational Linguistics*); the primary source for the U-shaped positional-bias effect in long-context retrieval.
- [Leaderboard Incentives: Model Rankings under Strategic Post-Training](https://openreview.net/forum?id=gaEe0d0zqr) - Chen, Zhang, and Hardt, ICLR 2026 Workshop; game-theoretic analysis of why current benchmark designs incentivize benchmaxxing.
- [Are Large Language Models Truly Smarter Than Humans? Benchmark Contamination, Surface-Pattern Reliance, and Behavioral Memorization Across Six Frontier Models](https://arxiv.org/html/2603.16197v1) - arXiv; empirical contamination rates and accuracy drops under paraphrased MMLU questions.
- [Chatbot Arena: An Open Platform for Evaluating LLMs by Human Preference](https://proceedings.mlr.press/v235/chiang24b.html) - Chiang et al., ICML 2024; the Chatbot Arena methodology and Bradley-Terry ranking approach.
- [Learning Transferable Visual Models From Natural Language Supervision](https://ar5iv.labs.arxiv.org/html/2103.00020) - Radford et al. (OpenAI), 2021; the original CLIP paper describing the contrastive shared embedding space.
- [Distilling the Knowledge in a Neural Network](https://www.cs.toronto.edu/~hinton/absps/distillation.pdf) - Hinton, Vinyals, and Dean, 2015; the foundational knowledge-distillation paper.
- [ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/pdf/2210.03629v3) - Yao et al., 2022; the original ReAct paper.
- [Reflexion: Language Agents with Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366v4) - Shinn et al., 2023 (NeurIPS); the reflection/self-critique agent loop.
- [Architecting Resilient LLM Agents: A Guide to Secure Plan-then-Execute Implementations](https://arxiv.org/pdf/2509.08646) - arXiv, 2025; plan-then-execute architecture and its security properties relative to ReAct.

### Further Reading

- [How LLM Quantization Works: INT8, INT4, GPTQ, and AWQ Explained](https://towardsai.com/p/machine-learning/how-llm-quantization-works-int8-int4-gptq-and-awq-explained) - Towards AI; accessible walkthrough of quantization mechanics and the GPTQ/AWQ tradeoff.
- [Plan-and-Execute Agents](https://www.langchain.com/blog/planning-agents) - LangChain; practical comparison of plan-and-execute variants against ReAct.

### Further Local Reading

- `02-models-training-and-inference.md`, this guide; fine-tuning mechanics and post-training (RLHF, instruction tuning) referenced throughout this chapter.
- `03-prompts-context-memory-and-caching.md`, this guide; prompting technique referenced in the fine-tuning/RAG/prompting framework and the mitigation-approaches table.
- `04-agents-subagents-harnesses-and-tools.md`, this guide; the conceptual introduction to agents that Section 9 builds on.
- `05-retrieval-embeddings-and-vector-databases.md`, this guide; embedding spaces and retrieval mechanics referenced in the multimodality and RAG sections.
- `06-security-privacy-and-data.md`, this guide; data-handling implications referenced in the licensing and observability sections.
- `appendices/appendix-b-brands-and-providers.md`, this guide; brand-by-brand open-weight and licensing positioning.
