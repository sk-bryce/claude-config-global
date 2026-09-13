---
audience: human
created: 2026-07-28
updated: 2026-07-28
---

# Chapter 2: Models, Training, and Inference

This chapter assumes you have read [Chapter 1](01-fundamentals.md) and know the basic vocabulary: what a large language model is, roughly what a prompt is, and why "AI" in this context means a specific class of statistical model rather than a general intelligence. This chapter goes underneath those definitions: what a model is made of, how it gets built, and what actually happens when it produces a response.

## In short

- A model is a very large collection of numeric parameters (weights) arranged into a neural network. Nearly all current large language models use the transformer architecture, built around an attention mechanism that lets every token in a sequence weigh how relevant every other token is to it.
- Capability scales predictably with three resources scaled together: parameter count, training data, and compute. Increasing one without the others wastes the other two; this is what "scaling laws" describe.
- Building a usable model takes two distinct phases. Pretraining (self-supervised next-token prediction over huge text corpora) produces a base model that predicts plausible text but is not a reliable assistant. Post-training (supervised fine-tuning, RLHF, RLAIF, DPO) turns a base model into one that follows instructions and holds a conversation.
- Models do not see characters or whole words. They see tokens, produced by a tokenizer (commonly a byte pair encoding, BPE, variant). Token count, not character count, determines both API cost and how much text fits in a model's context window, and different vendors' tokenizers split the same text into different numbers of tokens.
- At inference time, a model generates one token at a time in a feedback loop (autoregressive generation). Decoding settings (temperature, top-p, top-k) control how deterministic or varied that generation is.
- Inference is cheap per request but happens at massive aggregate scale; training is enormously expensive but happens rarely. Over a model's deployed lifetime, cumulative inference compute typically dwarfs the one-time training cost, which is why inference efficiency dominates most real-world cost conversations (see [Appendix C](appendices/appendix-c-costs-and-getting-value.md)).

## 1. What a Model Actually Is

### 1.1 Parameters and weights

A trained model is, mechanically, a very large mathematical function: it takes numbers in and produces numbers out. The behavior of that function is controlled by its parameters, also called weights: individual numeric values, typically stored as 16-bit or lower-precision floating point numbers, that get multiplied and added together as data flows through the network. A model described as having "70 billion parameters" has roughly 70 billion of these tunable numbers.

Parameter count is a rough, imperfect proxy for how much a model can represent: more parameters generally mean more capacity to encode grammar, facts, and reasoning patterns, but capacity is only useful if the model was also trained on enough data with enough compute to make good use of it (see 1.5). Training is the process of adjusting those weights, iteration by iteration, so that the function's output gets closer to a desired target. Inference (Section 6) is what happens when those weights are held fixed and the function is simply run forward to produce output.

Public model sizes at each architectural era illustrate the trend, though comparisons across eras should be read as illustrative rather than an apples-to-apples measure of capability, since data quality, training duration, and architecture also changed:

| Model | Year | Parameters | Notes |
| --- | --- | --- | --- |
| GPT-2 | 2019 | up to 1.5 billion | Among the first widely discussed models to show fluent, general-purpose text generation |
| GPT-3 | 2020 | 175 billion | Basis for the scaling laws study in Section 1.5 |
| Gopher | 2021 | 280 billion | DeepMind model used as the compute-budget baseline for Chinchilla |
| Chinchilla | 2022 | 70 billion | Trained on 1.4 trillion tokens; outperformed the much larger Gopher on the same compute budget |

Since GPT-4, most frontier labs, including OpenAI, no longer disclose parameter counts, training compute, or architecture details for competitive and safety reasons, so no comparable public figures exist for current-generation frontier models.

### 1.2 Neural networks, conceptually

A neural network is a function built out of layers. Each layer takes a vector of numbers (a "representation" of the input so far), applies a linear transformation (a weighted combination of the inputs, controlled by that layer's weights) followed by a nonlinear adjustment, and passes the result to the next layer. Stacking many such layers ("deep" learning) lets each layer build on the abstractions of the one before it: early layers might capture something like local token patterns, later layers something closer to meaning or relationships between distant parts of a document. No layer is hand-designed to do this. The behavior emerges from training on data.

### 1.3 The transformer architecture

Before 2017, the dominant architectures for processing sequences of text (recurrent neural networks, RNNs) processed a sequence one token at a time, carrying forward a compressed summary (a "hidden state") of everything seen so far. This made them slow to train (each step depended on the previous one, so computation could not be parallelized) and prone to forgetting information from far earlier in the sequence.

The transformer architecture, introduced by Google researchers in the 2017 paper "Attention Is All You Need," discarded recurrence entirely and replaced it with a mechanism called attention (Section 1.4), applied in parallel across an entire sequence at once. This unlocked two things simultaneously: much better use of parallel hardware (GPUs and TPUs are built for exactly this kind of parallel matrix computation) during training, and a more direct way for a model to relate distant parts of a sequence without funneling everything through a single compressed running summary. The original paper used an encoder-decoder structure for machine translation; nearly every modern large language model instead uses a decoder-only variant, where a single stack of transformer layers both reads the input and generates the output, one token at a time, in the same pass.

A transformer layer, in outline, does the following to a sequence of token representations:

1. Self-attention: each token position looks at every other token position (including itself) and computes an updated representation that blends in relevant context from elsewhere in the sequence.
2. A feedforward sublayer: a smaller per-position neural network that further transforms each token's representation independently.
3. Residual connections and normalization: mechanisms that keep training stable across many stacked layers by letting information skip around a sublayer and keeping the scale of the numbers consistent.

A full model stacks dozens to well over a hundred of these layers, plus an initial step that converts each input token into a numeric vector (an embedding) and adds information about token order (positional encoding, since attention on its own has no inherent sense of sequence position), and a final step that converts the last layer's output back into a probability distribution over possible next tokens.

### 1.4 Attention, explained conceptually

Attention is the mechanism that lets a token's representation be updated based on other tokens the model judges relevant, regardless of how far away they are in the sequence. The standard intuition uses three roles, computed from each token's current representation via separate learned transformations:

- Query: a representation of "what this token is looking for."
- Key: a representation of "what this token has to offer," used to be matched against other tokens' queries.
- Value: the actual content a token contributes once it has been judged relevant.

For a given token, its query is compared against every other token's key to produce a relevance score for each. Those scores are converted into weights (via a softmax function, which turns arbitrary scores into a set of positive numbers that sum to one) and used to compute a weighted blend of every token's value. The result is a new representation for that token that has pulled in exactly the context the model has learned is useful: a pronoun's representation might pull in information from the noun it refers to several sentences earlier; a closing parenthesis might attend back to its matching opening one.

This whole process is done many times in parallel per layer (multi-head attention), with each "head" free to learn a different kind of relationship (one head might specialize in tracking grammatical subject-verb agreement, another in topical similarity). Doing this within a single sequence is called self-attention, as distinct from the cross-attention used in encoder-decoder transformers to let a decoder attend to a separate encoder's output.

A classic illustration of what this buys a model: in the sentence "The trophy didn't fit in the suitcase because it was too big," resolving what "it" refers to requires relating a pronoun back to one of two candidate nouns several words earlier, using the rest of the sentence as context. A recurrent model has to carry that information forward through every intervening word in its compressed hidden state; an attention-based model can instead let the pronoun's representation directly attend back to "trophy" (the more plausible referent for "too big" in this context) in a single step, regardless of the distance involved.

The important conceptual takeaways, without the underlying linear algebra: attention lets every token see every other token in a single step (not one-at-a-time as in older architectures), the "relevance" weighting is learned from data rather than hand-coded, and this mechanism scales in compute and memory with the square of the sequence length in its original form, which is a central reason context windows are finite (Section 6.3) and long inputs are slower to process (Section 6.4).

### 1.5 Why scale matters: parameters, data, and compute together

A 2020 OpenAI study found that a transformer language model's loss (a measure of how well it predicts held-out text) improves as a smooth, predictable power law as you increase model size, dataset size, or training compute, each considered on its own. This class of result is generally called a scaling law. Based on this, that paper's practical guidance was to prioritize larger models trained on a comparatively modest amount of data, stopped well before the model had "seen" all of it multiple times.

A 2022 DeepMind study revisited that guidance and found that most large models being trained at the time were significantly undertrained relative to their size: they had far more parameters than their training data justified. Its central finding was that for a fixed compute budget, model size and training data should be scaled together in roughly equal proportion. Its resulting Chinchilla model, at 70 billion parameters trained on 1.4 trillion tokens, outperformed DeepMind's own 280-billion-parameter Gopher model, which had been trained on much less data for the same compute budget, and needed far less compute to fine-tune and run afterward.

The practical upshot for readers who are not training models themselves: a bigger model is not automatically a better model. What matters is parameters, training data, and compute scaled together, in roughly the ratios the scaling literature has empirically found. This is also why frontier labs continue to invest in progressively larger data pipelines and GPU/TPU clusters rather than only increasing parameter counts: all three levers have to move together to keep improving results.

## 2. Types of Models

Models are commonly grouped along a few independent axes. A given model typically belongs to a combination of these categories, not just one: a single deployed model might be instruction-tuned, capable of reasoning, and multimodal, all at once.

| Category | What distinguishes it | Typical use |
| --- | --- | --- |
| Base or foundation model | Output of pretraining only; no post-training | Rarely used directly; the starting point for everything else |
| Instruction-tuned or chat model | Post-trained (SFT plus a preference-optimization step) to follow instructions | General-purpose assistants and chat products |
| Reasoning model | Additionally trained via RL to generate extended chain of thought before answering | Complex, multi-step problems: math, coding, planning |
| Multimodal model | Accepts or produces more than text (images, audio, video, documents) | Tasks involving non-text input or output |

These categories describe training and capability. Whether a model's weights are published (open-weight) or served only through a private API (closed) is a separate, orthogonal axis, covered briefly in Section 2.5.

### 2.1 Base or foundation models

A base model (also called a foundation model) is the direct output of pretraining (Section 3): a next-token predictor with no explicit training to be helpful, follow instructions, or refuse harmful requests. Given a prompt, a base model will simply continue it in whatever way is statistically plausible given its training data, which might mean answering a question well, might mean continuing it as though it were a forum post someone else will reply to, and might mean drifting off-topic or repeating itself. Base models are rarely exposed directly to end users today; they are the starting point that post-training (Section 4) turns into a usable assistant.

### 2.2 Instruction-tuned or chat models

These are base models that have gone through post-training specifically to follow instructions, hold multi-turn conversations, and behave more predictably and safely. Nearly every consumer-facing product (ChatGPT, Claude.ai, Gemini) is backed by an instruction-tuned or chat model, not a raw base model.

### 2.3 Reasoning models

Reasoning models are trained, on top of instruction tuning, to generate an extended internal chain of thought before producing a final answer, typically using reinforcement learning against tasks with a verifiable correct answer (math, code execution, logic puzzles). OpenAI's o-series and Anthropic's Claude extended and adaptive thinking modes are examples of this category. The model is not just prompted to "think step by step"; it has been trained via RL to use additional inference-time computation productively, checking its own intermediate steps, backtracking, and trying alternative approaches before committing to an answer. This generally improves accuracy on complex, multi-step problems at the cost of higher latency and token usage, and most vendors expose a control (commonly called "effort," "budget," or similar) to trade off reasoning depth against speed and cost.

### 2.4 Multimodal models

A multimodal model accepts, produces, or both, more than one type of content: text plus images, audio, video, or documents. Under the hood, non-text input is converted into the same kind of token-like numeric representation the transformer already processes, so the same attention machinery can relate a described object in text to a region of an image, or a spoken word to its transcription. GPT-4, for example, was trained to accept interleaved text and image inputs and produce text output, extending capabilities like few-shot and chain-of-thought prompting that had previously been developed for text-only models into the visual domain.

### 2.5 Open-weight versus closed models (brief)

Models also differ in whether their trained weights are published for anyone to download and run (open-weight) or kept private and accessible only through a hosted API (closed or proprietary). This distinction affects cost structure, customization ability, data handling, and deployment flexibility, but it is orthogonal to the base and post-training concepts above: both open-weight and closed models go through the same pretraining and post-training pipeline described in Sections 3 and 4. A full comparison of open-weight and closed-model trade-offs, and of who currently offers what, belongs to [Chapter 7](07-related-and-advanced-topics.md) and [Appendix B](appendices/appendix-b-brands-and-providers.md); this chapter does not repeat it.

## 3. Pretraining

Pretraining is the first and by far most compute-intensive phase of building a model. Its job is to produce a base model (Section 2.1): something that has absorbed broad patterns of language, facts, and reasoning from enormous amounts of text, without yet being shaped into an assistant.

### 3.1 What data models are trained on

Pretraining corpora are built from a mix of sources that typically includes: large-scale crawls of public web pages, digitized books, code repositories, academic papers and reference material, and, increasingly, data licensed directly from third-party providers. OpenAI's GPT-4 technical report confirms this general shape (public internet data plus licensed data) while explicitly declining to disclose further detail about dataset construction, citing competitive and safety considerations. This lack of disclosure is now common across frontier labs: exact dataset composition, filtering criteria, and deduplication methods are generally treated as proprietary.

### 3.2 Self-supervised next-token prediction

Pretraining uses a self-supervised objective, meaning it needs no human-provided labels. The "label" for any given position in a training document is simply the token that actually comes next in that real document, which is available for free at essentially unlimited scale from any text corpus. Concretely, the model is repeatedly shown a chunk of text, asked to predict the next token, compared against the actual next token in that document, and its weights are nudged (via gradient descent, minimizing a loss function called cross-entropy) to make the correct token slightly more probable next time. Doing this billions or trillions of times, across a sufficiently large and varied corpus, is what teaches a model grammar, facts, common reasoning patterns, and style, entirely as a side effect of getting good at "predict the next token."

### 3.3 Compute scale

Pretraining a frontier model is measured in floating-point operations (FLOPs) on the order of 10^23 to 10^25 or more, run across thousands of GPUs or TPUs over a period of weeks to months. As one illustrative published data point, DeepMind's Chinchilla and Gopher models were both trained to roughly 5 to 6 times 10^23 FLOPs, using the same total compute budget split differently between model size and training tokens. Frontier training runs today are widely understood to cost tens to hundreds of millions of dollars in compute alone, though exact figures for current-generation models are generally not published.

### 3.4 Why pretraining alone does not produce a helpful assistant

A base model optimized purely to predict the next token in arbitrary internet-scale text is optimized to match the distribution of that text, not to be helpful, truthful, or safe. As the researchers behind OpenAI's InstructGPT put it, making a language model bigger does not inherently make it better at following a user's intent: a base model can be fluent and knowledgeable while still generating output that is untruthful, unhelpfully evasive or verbose, or actively harmful, because nothing in the next-token-prediction objective rewards any of "helpful," "honest," or "safe" specifically. This gap between "predicts plausible text" and "acts as a good assistant" is exactly what post-training exists to close.

## 4. Post-Training

Post-training covers everything done to a base model after pretraining to turn it into a model that reliably follows instructions, converses naturally, and avoids harmful or unhelpful behavior. It uses orders of magnitude less data and compute than pretraining, but has an outsized effect on how a model actually behaves in practice.

### 4.1 Supervised fine-tuning (SFT)

SFT is the most direct post-training step: the base model is further trained, using ordinary supervised learning, on a dataset of example prompts paired with high-quality demonstration responses, typically written or curated by trained human labelers. This teaches the model the format and tone of good assistant behavior (answering directly, following instructions, structuring output helpfully) by imitation. In OpenAI's InstructGPT work, this labeler-demonstration dataset was the first of three stages in the full pipeline.

### 4.2 RLHF: reinforcement learning from human feedback

RLHF goes a step further than SFT by directly optimizing for human preferences rather than only imitating demonstrations. The InstructGPT pipeline that popularized this approach for chat-style models works in three stages:

1. Start from an SFT model (Section 4.1).
2. Collect comparison data: human labelers rank multiple model outputs for the same prompt from best to worst, and this data is used to train a separate reward model that learns to predict which of two outputs a human would prefer.
3. Use reinforcement learning, specifically Proximal Policy Optimization (PPO), to further fine-tune the SFT model so that it maximizes the reward model's score, while a penalty keeps it from drifting too far from the original SFT model's behavior.

In OpenAI's evaluations, human labelers preferred outputs from a 1.3-billion-parameter InstructGPT model over the much larger 175-billion-parameter base GPT-3, despite the InstructGPT model having roughly 100 times fewer parameters, illustrating how much post-training changes the perceived quality of a model independent of raw scale.

### 4.3 RLAIF and Constitutional AI

RLHF's dependence on large volumes of human-labeled comparisons is expensive and, for judgment calls about what counts as harmful, can push labelers toward rewarding evasive but unhelpful answers (an assistant that refuses everything is technically harmless but useless). Anthropic's Constitutional AI (CAI) approach replaces most human harmlessness labeling with AI-generated feedback, guided by a written set of principles (a "constitution") rather than per-example human judgments. It has two phases:

1. A supervised phase: the model generates a response, critiques its own response against the constitution's principles, revises it accordingly, and the model is fine-tuned on these self-revised outputs.
2. A reinforcement learning phase: the model generates pairs of candidate responses, an AI evaluator (not a human) judges which better satisfies the constitution, and this AI-generated preference data trains a preference model used to run reinforcement learning, in the same structural role RLHF's human-labeled preference data plays. Anthropic calls this specific substitution reinforcement learning from AI feedback (RLAIF).

Anthropic reports that this approach produces a model that is both more harmless and more willing to explain its objections to a harmful request, rather than simply refusing, compared to models trained with RLHF's human harmlessness labels alone, and that it does so with far fewer human labels overall.

### 4.4 DPO: direct preference optimization

DPO, introduced in a 2023 paper, is a simpler alternative to the reward-model-plus-PPO structure used in RLHF. RLHF's PPO stage is a genuinely complex and often unstable reinforcement learning procedure: it requires fitting a separate reward model, then repeatedly sampling from the model being trained during optimization, and careful hyperparameter tuning to keep training stable. DPO's authors showed that, mathematically, the same preference-alignment objective RLHF optimizes can be reformulated as a direct classification loss over pairs of preferred and rejected responses, applied straight to the policy model, with no separate reward model and no reinforcement learning loop at all. Their experiments found DPO could match or exceed PPO-based RLHF in output quality on several tasks while being substantially simpler to implement and train, which has made it a widely adopted alternative or complement to full RLHF in current post-training pipelines.

### 4.5 Instruction tuning as an umbrella term

"Instruction tuning" is often used loosely to refer to the entire process of turning a base model into one that reliably follows instructions, encompassing SFT and whichever preference-optimization step (RLHF, RLAIF, DPO, or some combination) a given lab uses, rather than naming one specific additional technique. If you see a model described as "instruction-tuned," treat that as a claim about the overall post-training pipeline, not a specific algorithm.

### 4.6 Distillation (brief mention)

Knowledge distillation, introduced by Hinton, Vinyals, and Dean in 2015, trains a smaller "student" model to reproduce a larger "teacher" model's full output probability distribution (its "soft" predictions across many possible answers) rather than only the single correct label a student would otherwise be trained on. Because the teacher's soft distribution encodes information about which wrong answers are "less wrong" than others, a distilled student model can recover much of a much larger teacher's behavior at a fraction of the size and inference cost. In current large language model post-training, distillation is commonly used to produce smaller, cheaper model variants from a larger, more capable one that acts as the teacher. It sits adjacent to the post-training techniques above rather than squarely inside them, since its goal is compression and deployment efficiency rather than alignment. The fuller discussion of distillation as a deployment and cost-optimization strategy, alongside quantization, belongs to [Chapter 7](07-related-and-advanced-topics.md).

### 4.7 Comparing the post-training techniques

| Technique | What it optimizes against | Human labeling required | Relative complexity |
| --- | --- | --- | --- |
| SFT | Imitating demonstration examples | High: humans write or curate example responses | Low: ordinary supervised learning |
| RLHF | A learned reward model trained on human preference comparisons | High: humans rank multiple outputs per prompt | High: separate reward model plus a PPO reinforcement learning loop |
| RLAIF / Constitutional AI | A learned preference model trained on AI-generated comparisons against written principles | Low: only the constitution's principles are human-written | High: still a full RL loop, but the labeling burden shifts to an AI evaluator |
| DPO | Human (or AI-generated) preference pairs directly, without a separate reward model | Same as RLHF or RLAIF, depending on how the pairs are sourced | Lower: a single classification-style loss, no RL loop or sampling during training |

These are not mutually exclusive. A single lab's post-training pipeline commonly chains several of these together (for example, SFT, then DPO, then a further RLHF or RLAIF pass), rather than choosing exactly one.

### 4.8 Putting the pipeline together

```
Pretraining data          Post-training data
(web, books, code,   ->   (demonstrations,     ->  Base model  ->  SFT  ->  RLHF / RLAIF / DPO  ->  Assistant model
 licensed sources)         preference pairs)
```

Every stage after the base model is optional in principle and combinable in practice: many current pipelines use SFT followed by some mix of RLHF, RLAIF-style AI feedback, and DPO, rather than picking exactly one preference-optimization method.

## 5. Tokens and Tokenization

### 5.1 What a token is

A token is the actual unit of text a model reads and generates. It is not reliably a character, and it is not reliably a whole word: it might be a common whole word, a fragment of a longer word, a punctuation mark, a chunk of whitespace, or part of a multi-byte sequence representing a non-Latin character or emoji. Every prompt sent to a model, and every response it generates, is first converted to and from a sequence of tokens by a tokenizer, invisibly to the end user.

### 5.2 How BPE-family tokenizers work

Most current tokenizers, including OpenAI's `tiktoken` family and comparable tokenizers used by other vendors, are built using a byte pair encoding (BPE) style algorithm. Conceptually: start with a base vocabulary of individual bytes or characters, then repeatedly find the most frequently occurring adjacent pair of symbols across a large training corpus and merge it into a new, single symbol, adding it to the vocabulary. Repeating this merging process tens of thousands of times produces a fixed vocabulary, commonly on the order of 100,000 to 200,000 entries, that mixes common whole words, frequent subword fragments (like "ing" or "tion"), and individual bytes for anything rarer, such that any input text, even text unlike anything the tokenizer was built from, can still be represented exactly.

OpenAI's own tokenizer documentation illustrates this with the word "antidisestablishmentarianism," which different OpenAI tokenizer versions split into five or six subword tokens rather than one token per word or one token per character; `cl100k_base`, for example, splits it into six (`ant`, `idis`, `establish`, `ment`, `arian`, `ism`), while the older `r50k_base`/`p50k_base` encodings split it into five and the newer `o200k_base` produces a different six-way split. The same documentation shows that a short Japanese greeting, "お誕生日おめでとう," is split into as many as 14 tokens by an older encoding (`r50k_base`) but only 8 by a newer one (`o200k_base`), which is a direct illustration of Section 5.4 and 5.5 below: how a text is tokenized, and how efficiently, depends heavily on which tokenizer is used and what data it was built from.

OpenAI alone has shipped several distinct encodings as its models evolved, each with a different vocabulary:

| Encoding | Used by | Notes |
| --- | --- | --- |
| `r50k_base` (`gpt2`) | Original GPT-3 family | Smallest, oldest vocabulary of the four |
| `p50k_base` | Codex models, older `text-davinci` models | Overlaps substantially with `r50k_base` |
| `cl100k_base` | GPT-4, GPT-4 Turbo, GPT-3.5 Turbo, and OpenAI's embedding models | ~100,000-entry vocabulary |
| `o200k_base` | GPT-4o-generation models | ~200,000-entry vocabulary; more efficient on non-English and mixed content than earlier encodings |

Anthropic, Google, and other vendors maintain their own separate tokenizers, not derived from any of the above, which is the root cause of the cross-vendor inconsistency described in Section 5.4.

### 5.3 Why token count matters: cost and context limits

Token count matters for two closely related, practical reasons:

- Cost: essentially every hosted model API prices usage per token, separately for input and output tokens (and often at a lower rate for cached input tokens; caching is covered in [Chapter 3](03-prompts-context-memory-and-caching.md)). Character or word count is not what you are billed on.
- Context limits: every model has a fixed context window, measured in tokens, covering both what you send in and what it generates back (Section 6.3). A prompt or conversation that is "too long" is too long in tokens, not in characters, and the same text can consume noticeably different numbers of tokens depending on model and language (Sections 5.4 and 5.5).

Longer token sequences also cost more compute to process, because the attention mechanism's work scales with sequence length (Section 1.4), which is part of why longer inputs and outputs are both more expensive and slower (Section 6.4).

### 5.4 Tokenizers differ across vendors and models

There is no single, universal tokenizer. OpenAI's models use one of several `tiktoken`-family encodings depending on model generation (for example `o200k_base` for GPT-4o-generation models, `cl100k_base` for the GPT-4 and GPT-3.5 generation). Anthropic's Claude models use a separate, proprietary tokenizer, and Anthropic explicitly notes that its Claude 4.7-and-later models use a newer tokenizer that produces roughly 30 percent more tokens than earlier Claude models for the same input text, meaning even token counts from the same vendor are not stable across model generations. The practical consequence: a token count computed for one model, or estimated with one vendor's tokenizer library, is not a reliable estimate for a different model or vendor. Anthropic provides a dedicated token-counting API endpoint for this reason, and recommends against reusing a token count computed with a different tokenizer.

### 5.5 Non-English languages and token cost

Because BPE-style vocabularies are built by finding frequent patterns in a training corpus, and most large tokenizer training corpora are disproportionately English and Latin-script text, the resulting vocabulary is disproportionately efficient at representing English. Peer-reviewed analysis of commercial tokenizers has found that text in non-Latin-script or morphologically complex languages is fragmented into substantially more tokens per unit of meaning than equivalent English text, in some studied mid-resource languages with non-Latin scripts by close to a factor of 5, with the effect varying by script and language family rather than being a flat "non-English" penalty. Because API pricing and context windows are both denominated in tokens, this fragmentation directly translates into higher cost and a smaller effective context window for speakers of the affected languages, for the same underlying content and meaning.

## 6. Inference: How Generation Actually Works

Inference is what happens after training is complete: the model's weights are fixed, and it is simply run forward to produce output for a given input.

### 6.1 Forward pass and autoregressive generation

Given a sequence of input tokens, the model performs a forward pass: the tokens are converted to embeddings, passed through the full stack of transformer layers (Section 1.3), and the final layer produces a probability distribution over every possible next token in the model's vocabulary. One token is then chosen from that distribution (Section 6.2), appended to the sequence, and the entire process repeats, now including the newly generated token as part of the input, to produce the token after that. This token-by-token feedback loop is called autoregressive generation, and it is why generating a response takes time roughly proportional to how many tokens are generated: each new token requires another full pass through the model.

### 6.2 Decoding strategies

The probability distribution the model produces at each step does not fully determine the output on its own; a decoding strategy decides how to turn that distribution into an actual chosen token.

| Strategy | What it does | Practical effect |
| --- | --- | --- |
| Greedy decoding | Always picks the single highest-probability token | Fully deterministic, but often dull, repetitive, or stuck in loops |
| Sampling | Picks a token randomly, weighted by the model's probability distribution | Introduces variety; can occasionally pick a poor token |
| Temperature | Rescales the probability distribution before sampling | Low temperature sharpens the distribution toward the top choices (more focused, closer to deterministic); high temperature flattens it (more random and diverse); OpenAI's API accepts values from 0 to 2, with 1 as an unscaled baseline |
| Top-p (nucleus sampling) | Restricts sampling to the smallest set of tokens whose cumulative probability exceeds a threshold p | Cuts off the long tail of unlikely tokens while still allowing variety among the plausible ones; for example, p of 0.1 means only tokens making up the top 10 percent of probability mass are considered |
| Top-k | Restricts sampling to only the k most probable tokens | Similar goal to top-p, using a fixed count instead of a probability threshold |

These settings are typically combined, most commonly temperature with top-p, and vendor documentation generally recommends adjusting one or the other deliberately rather than both aggressively at once, since their effects overlap. Lower temperature and top-p values suit tasks that want consistent, focused output (code generation, factual extraction); higher values suit open-ended or creative tasks.

As a concrete illustration: given the prompt "The weather today is," a model might assign roughly 40 percent probability to "sunny," 25 percent to "cloudy," 15 percent to "cold," and the remaining 20 percent spread thinly across dozens of less likely continuations. At low temperature, sampling will almost always land on "sunny." At high temperature, the distribution flattens, so "cold" or even a low-probability word becomes meaningfully more likely to be chosen, at the cost of coherence. A top-p value of 0.7 in this example would restrict sampling to roughly "sunny," "cloudy," and "cold," discarding the long thin tail of unlikely continuations regardless of temperature.

### 6.3 Context window

The context window is the total number of tokens a model can hold in view for a single request, covering the system prompt, conversation history, any documents or tool results included, and the response it generates, all counted together. It is finite for a structural reason described in Section 1.4: the standard attention mechanism's compute and memory requirements grow sharply with sequence length, so there is a practical ceiling past which processing a request becomes too slow or too expensive to serve, even before accounting for the model's own ability to make good use of very long input. Anthropic's own documentation notes that a larger context window is not automatically better: as token count grows, a model's accuracy and recall over that content tend to degrade, an effect it terms "context rot," which is one reason curating what goes into context matters as much as how much room is available.

As of mid-2026, published context windows across frontier hosted models range from roughly 128,000 tokens up to 1,000,000 tokens depending on vendor and model tier; exact current figures per model belong in [Appendix B](appendices/appendix-b-brands-and-providers.md)'s provider comparison rather than here. The full practical treatment of managing context, including conversation memory strategies and prompt caching to reduce the cost of repeated context, is covered in [Chapter 3](03-prompts-context-memory-and-caching.md).

### 6.4 Latency and throughput

Two different kinds of speed matter for a generation request, and they are driven by different parts of the pipeline:

- Time to first token (TTFT): how long it takes from sending a request to receiving the first generated token back. This is dominated by the "prefill" step, processing the entire input prompt in one pass to build up the internal state (commonly called the KV cache) the model needs before it can start generating. Because prefill has to process the whole input at once, TTFT grows with input length: a long prompt or long conversation history produces a noticeably longer wait before the response even starts, independent of how long the eventual response will be.
- Tokens per second, or equivalently inter-token latency (the average time between consecutive generated tokens): the steady-state generation speed once output has started. Because autoregressive generation requires one full forward pass through the model per output token (Section 6.1), this speed is governed by the model's size and the serving hardware. Larger models generally generate more slowly per token, in exchange for typically higher quality output, and serving many requests concurrently trades off total system-wide throughput against the token rate any single user experiences.

Both metrics matter for different use cases: a low TTFT matters most for responsive interactive chat, while high tokens-per-second matters most for generating long documents or running many requests in bulk.

Serving systems also batch multiple users' requests together on the same GPU to make better use of its compute, since generating one token for one user at a time would leave most of the hardware idle. Batching increases total system-wide throughput (more tokens produced per second in aggregate), but each additional concurrent request competing for the same hardware tends to slow down the per-user token rate, which is why the per-user tokens-per-second a person experiences can vary with how busy a service is at that moment, independent of anything about their specific request.

### 6.5 Training versus inference compute: a cost asymmetry

Training a frontier model is an enormous, concentrated compute expenditure (Section 3.3), but it happens rarely, once per model or per major update. Inference, by contrast, is comparatively cheap per individual request, roughly on the order of the square root of the training cost as a very rough rule of thumb, but it happens an essentially unbounded number of times over a model's deployed life, since the same trained weights serve every user request from launch until retirement. Independent compute-forecasting research from Epoch AI notes that while any single inference is much cheaper than training, the aggregated cost of inference across a model's full lifetime often greatly exceeds the total cost of training it, precisely because the same model is invoked so many more times than it was trained.

This asymmetry has direct practical consequences: it is a large part of why compute-optimal training research (Section 1.5) increasingly accounts for downstream inference cost, not only training cost, when deciding how large to make a model, and why inference-side cost optimization (covered fully in [Appendix C](appendices/appendix-c-costs-and-getting-value.md)) tends to matter more to most organizations' ongoing budgets than the one-time cost of training.

### 6.6 Reasoning models add another inference cost dimension

Reasoning models (Section 2.3) make the training-versus-inference distinction, and the cost mechanics in this section, directly visible to users of an API. Because a reasoning model's internal chain of thought is itself generated autoregressively, one token at a time, before the visible answer, OpenAI's API reports these as a distinct "reasoning tokens" count within the output token usage for a request, and they are billed as output tokens even though a user never sees them by default. Practically, this means a reasoning model's TTFT for the visible answer is higher (the model must finish its hidden reasoning first), and total output token count, and therefore cost, is not just a function of how long the visible answer is. Both the OpenAI and Anthropic reasoning controls described in Section 2.3 exist specifically to let a caller trade this additional inference-time cost against answer quality on a per-request basis.

### 6.7 Putting it together: what happens when you send a message

Tying together Sections 5 and 6, sending a single message to a hosted chat model triggers roughly this sequence:

1. Your text, the system prompt, conversation history, and any tool definitions are converted to tokens by that model's tokenizer (Section 5).
2. The full input token sequence is processed in one prefill pass through the model's transformer layers (Section 1.3), building the internal KV cache; this is what determines time to first token (Section 6.4).
3. The model generates output tokens one at a time (Section 6.1), each chosen according to the active decoding settings (Section 6.2), until it produces a stop token, hits a length limit, or (for a reasoning model) finishes its hidden reasoning and its visible answer (Section 6.6).
4. The output token sequence is converted back to text by the same tokenizer and returned to you, alongside a usage report of input, output, and (where applicable) reasoning tokens, which is what your bill and your remaining context window budget (Section 6.3) are both based on.

No weights change anywhere in this sequence. Everything that shapes the answer's quality and character was already fixed during pretraining (Section 3) and post-training (Section 4); inference only decides which path through that fixed model gets taken for this particular input.

## Where to go next

This chapter covered what a model is, how it is trained, and what happens mechanically at inference time. The following chapters build directly on it:

- [Chapter 3](03-prompts-context-memory-and-caching.md): how to work with the context window described in 6.3, including conversation memory and prompt caching.
- [Chapter 4](04-agents-subagents-harnesses-and-tools.md): how models call tools and are wrapped into agents and harnesses.
- [Chapter 5](05-retrieval-embeddings-and-vector-databases.md): embeddings, a related but distinct representation from the token-level mechanics covered here, and retrieval-augmented generation.
- [Chapter 6](06-security-privacy-and-data.md): security and data-handling implications of how models are trained and served.
- [Chapter 7](07-related-and-advanced-topics.md): quantization, distillation for deployment, and the full open-weight versus closed-model comparison only briefly introduced in Section 2.5.
- [Appendix B](appendices/appendix-b-brands-and-providers.md): current models, providers, and their context window and pricing specifics.
- [Appendix C](appendices/appendix-c-costs-and-getting-value.md): cost optimization strategy building on the token and compute economics introduced in Sections 5 and 6.
- [Appendix D](appendices/appendix-d-glossary-quick-reference.md): quick lookup for any term introduced in this chapter.

## References

### Official Documentation

- [How to count tokens with Tiktoken](https://developers.openai.com/cookbook/examples/how_to_count_tokens_with_tiktoken) - OpenAI; explains byte pair encoding, OpenAI's tokenizer families, and includes the worked examples of subword and cross-lingual tokenization cited in Section 5.
- [Create chat completion (API reference)](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create/) - OpenAI; parameter definitions for temperature and top_p (nucleus sampling) used in Section 6.2.
- [Reasoning models](https://developers.openai.com/api/docs/guides/reasoning) - OpenAI; how reasoning tokens and effort settings work for reasoning models, cited in Section 2.3.
- [Learning to reason with LLMs](https://openai.com/index/learning-to-reason-with-llms/) - OpenAI; describes training reasoning models via reinforcement learning on chain-of-thought, cited in Section 2.3.
- [GPT-4](https://openai.com/index/gpt-4-research/) - OpenAI; confirms GPT-4's pretraining data mix, RLHF post-training, and multimodal (text and image) input handling, cited in Sections 2.4, 3.1, and 3.4.
- [Token counting](https://platform.claude.com/docs/en/build-with-claude/token-counting) - Anthropic; documents Claude's dedicated token-counting endpoint and the tokenizer change across Claude model generations, cited in Section 5.4.
- [Context windows](https://platform.claude.com/docs/en/build-with-claude/context-windows) - Anthropic; defines the context window, describes "context rot," and gives current context window sizes by model, cited in Section 6.3.
- [Extended thinking](https://platform.claude.com/docs/en/build-with-claude/extended-thinking) - Anthropic; documents Claude's reasoning/thinking modes, cited in Section 2.3.
- [Metrics Reference](https://docs.nvidia.com/aiperf/reference/ai-perf-metrics-reference) - NVIDIA AIPerf documentation; defines time to first token, inter-token latency, and tokens-per-second, cited in Section 6.4.

### Research

- [Attention Is All You Need](https://arxiv.org/abs/1706.03762) - Vaswani et al., 2017; the original transformer architecture paper, cited in Sections 1.3 and 1.4.
- [Scaling Laws for Neural Language Models](https://arxiv.org/abs/2001.08361) - Kaplan et al., 2020; the original neural scaling laws study, cited in Section 1.5.
- [Training Compute-Optimal Large Language Models](https://arxiv.org/abs/2203.15556) - Hoffmann et al., 2022; the Chinchilla paper on compute-optimal scaling of model size versus training data, cited in Sections 1.5 and 3.3.
- [Training language models to follow instructions with human feedback](https://cdn.openai.com/papers/Training_language_models_to_follow_instructions_with_human_feedback.pdf) - Ouyang et al., 2022; the InstructGPT paper describing the SFT and RLHF pipeline, cited in Sections 3.4, 4.1, and 4.2.
- [Constitutional AI: Harmlessness from AI Feedback](https://arxiv.org/pdf/2212.08073) - Bai et al., 2022; describes Constitutional AI and RLAIF, cited in Section 4.3.
- [Direct Preference Optimization: Your Language Model is Secretly a Reward Model](https://arxiv.org/abs/2305.18290) - Rafailov et al., 2023; the DPO paper, cited in Section 4.4.
- [Distilling the Knowledge in a Neural Network](https://www.cs.toronto.edu/~hinton/absps/distillation.pdf) - Hinton, Vinyals, and Dean, 2015; the original knowledge distillation paper, cited in Section 4.6.
- [Do All Languages Cost the Same? Tokenization in the Era of Commercial Language Models](https://aclanthology.org/2023.emnlp-main.614.pdf) - Ahia et al., EMNLP 2023; peer-reviewed analysis of tokenization cost disparity across languages, cited in Section 5.5.
- [Trading off compute in training and inference](https://epoch.ai/publications/trading-off-compute-in-training-and-inference) - Epoch AI; independent research on the relative cost of training versus lifetime inference compute, cited in Section 6.5.
