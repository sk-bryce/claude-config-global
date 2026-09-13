---
audience: human
created: 2026-08-04
updated: 2026-08-04
---

# Context Rot: How LLM Performance Degrades as Input Length Grows

"Context rot" (also called "context degradation" or, in the narrower needle-in-a-haystack
literature, "lost in the middle") describes a consistent finding across long-context research:
large language models do not use their advertised context window uniformly. As the amount of
text in the prompt grows, and even more so as the relevant information moves away from the
start or end of that text, model accuracy drops, sometimes sharply, well before the model's
stated token limit is reached. A context window number on a spec sheet is a ceiling on what the
model will accept, not a guarantee of how well it will reason over everything inside that
ceiling.

This document summarizes what the research actually shows, where Claude specifically has been
measured, and where the evidence runs out.

## 1. The core finding, and why it happens

The foundational result is Liu et al.'s "Lost in the Middle" (2023), which tested multi-document
question answering and key-value retrieval across several LLMs and found a consistent U-shaped
performance curve: accuracy is highest when the relevant information sits at the very start or
very end of the input, and drops when it sits in the middle, even though the task itself does
not change, only the position of the answer within the context.

One mechanistic explanation comes from Xiao et al.'s StreamingLLM paper (2023), which identified
"attention sinks": transformer attention consistently allocates disproportionate weight to the
first few tokens of a sequence, regardless of their semantic relevance. This isn't a bug fixed
by longer training; it appears to be an emergent property of how attention patterns form during
pretraining. It offers a partial explanation for the U-shape (early tokens get privileged
attention) but not a complete one; positional bias in long contexts is an active research area,
not a fully solved one.

## 2. Early retrieval-style evidence: needle-in-a-haystack (NIAH)

The original "needle in a haystack" (NIAH) methodology, introduced by Greg Kamradt
(`gkamradt/LLMTest_NeedleInAHaystack`), sweeps a grid of context length x needle depth, inserting
a single fact into a long document and scoring whether the model retrieves it. This became the
default long-context marketing benchmark through late 2023 and 2024.

- **Claude 2.1 (Anthropic, December 2023).** Anthropic's own blog post on Claude 2.1's 200K
  context window found the model would often decline to answer based on an isolated, out-of-place
  sentence, not because it couldn't find the sentence, but because its training on real-world
  retrieval had made it reluctant to commit to answers built on a single fragment. Anthropic
  reported that prepending "Here is the most relevant sentence in the context:" to the response
  instructions raised accuracy on the evaluation task from 27% to 98%. This is a striking finding
  but is a single vendor blog post describing an internal evaluation, not a peer-reviewed or
  independently reproduced study; treat the specific numbers as Anthropic's own reporting, not
  third-party verification.
- **Gemini 1.5 (Google, 2024).** Google's technical report claims greater than 99% recall on
  single-needle NIAH tasks up to at least 10M tokens. This is a genuinely strong single-needle
  result, but single-needle literal-match retrieval is exactly the "shallow" test type that later
  benchmarks (RULER, NoLiMa, BABILong, below) were built to move past, because models can learn to
  do well on it without demonstrating real reasoning over the full context. High NIAH scores and
  real degradation under harder tests are not in tension; they are measuring different things.

## 3. Harder evals built to defeat shallow retrieval

Because simple NIAH scores saturated (many frontier models hit ~100%), a second generation of
benchmarks introduced semantic distractors, multi-hop reasoning, or literal-match avoidance to
force models to actually process the surrounding context rather than pattern-match a literal
string.

- **RULER (NVIDIA, Hsieh et al., 2024).** Thirteen tasks across categories including multi-hop
  tracing and aggregation, tested on 34 models up to 1M tokens claimed context. The paper's
  headline finding: only about half of the tested models "maintain satisfactory performance" at
  32K tokens, well short of their advertised windows. **No Claude/Anthropic model is included in
  RULER's published results** (confirmed against the project's current results table) -- this is
  a real gap in the Claude-specific evidence base, not an omission on our part.
- **NoLiMa (Modarressi et al., ICML [International Conference on Machine Learning] 2025).**
  Deliberately minimizes literal lexical overlap between the question and the needle, forcing
  association-based rather than string-matching retrieval, across 12 models. **Claude 3.5 Sonnet
  is included** and shows a base (short-context) score of 87.6%, dropping to 77.6% at 4K tokens,
  61.7% at 8K, 45.7% at 16K, and 29.8% at 32K. NoLiMa defines "effective context length" as the
  largest tested length whose score still holds within 85% of the base score (a threshold of
  74.4% here); by that definition Claude 3.5 Sonnet's effective context length is 4K tokens
  against a claimed 200K, since 8K's score of 61.7% falls below the threshold. The paper notes
  Claude showed comparatively better length generalization (a slower relative decay) than some
  models with higher raw base scores, such as Llama 3.1 70B, but the absolute degradation curve
  is still steep.
- **BABILong (Kuratov et al., 2024).** Tests 20 reasoning tasks embedded in book-length filler
  text, up to 1M+ tokens with specialized recurrent architectures. Across more than 30 models
  tested (GPT-4, GPT-3.5-Turbo, Gemini 1.5 Pro, Llama-3, Mistral, and others), the paper's central
  claim is that popular LLMs "effectively utilize only 10-20% of the context" they claim to
  support, with most models holding satisfactory accuracy only up to about 4,000 tokens even on
  single-fact questions. **No Claude model appears in BABILong's published results.**
- **LongBench v2 (2024/2025, ACL [Association for Computational Linguistics] 2025).** 503
  multiple-choice questions spanning 8K to 2M words across six task categories, meant to require
  genuine long-context reasoning under a realistic time budget. The best directly-answering model reached only 50.1% accuracy; a model using
  extended reasoning (o1-preview) reached 57.7%, edging out the human expert baseline of 53.7%
  (under a 15-minute constraint). **We could not confirm from the sources checked whether a
  Claude model was included in LongBench v2's evaluation, or what its score was** -- flagging
  this explicitly as an unverified gap rather than guessing.

## 4. Degradation isn't only about retrieval -- reasoning degrades too

Levy et al.'s "Same Task, More Tokens" (ACL 2024) isolates input length as a variable
independent of task difficulty: the same reasoning problem is padded with irrelevant text of
varying length, type, and position, so the task itself never changes, only the surrounding
context volume. The paper reports "notable degradation in LLMs' reasoning performance at much
shorter input lengths than their technical maximum," and, notably, that standard next-token
prediction quality does not predict this reasoning robustness -- a model can be a good language
modeler over long text while still reasoning worse as that text grows. **We could not confirm the
specific model list from the sources checked**, so we cannot say whether Claude was among the
models tested here either; this is worth checking against the full paper if the reasoning-specific
angle matters for a specific decision.

## 5. The broadest multi-vendor study: Chroma's "Context Rot" report

Chroma's July 2025 technical report ("Context Rot," trychroma.com/research/context-rot) is the
most directly relevant source for Claude specifically, because it is the one study in this
document's evidence base that deliberately includes multiple Claude generations. It tested 18
models total, including five Claude models: **Claude Opus 4, Claude Sonnet 4, Claude Sonnet
3.7, Claude Sonnet 3.5, and Claude Haiku 3.5**.

Findings specific to Claude:

- Across tasks with distractors present, Claude models had the **lowest hallucination rates** of
  the models tested -- when uncertain, they tended to abstain rather than fabricate an answer.
  Claude Opus 4 and Sonnet 4 were described as "particularly conservative," abstaining under
  ambiguity.
- On LongMemEval (a long-term conversational memory benchmark, where the model must recall and
  reason over facts from earlier in a long multi-session chat history), Claude models showed the
  **largest gap** between a focused (short, relevant-only) prompt and a full (long,
  distractor-laden) prompt -- largely driven by increased abstentions under the full-context
  condition, not by increased hallucination.
- On a repeated-words task, Claude Sonnet 3.5 outperformed the newer Claude Sonnet/Opus 4 models
  up to its 8,192-token output limit (the point past which 3.5 simply could not generate more
  output for the test to measure, capping how far its result could be compared against models
  with larger output limits), while Opus 4 had the slowest degradation rate of the Claude models
  but refused about 3% of tasks outright.

Chroma's overall conclusion, holding across all 18 models: LLMs do not process context uniformly,
performance degrades substantially with input length even on simple tasks, and the degradation
pattern differs by task structure and distractor presence -- long-context capability is not a
solved problem just because a model accepts a large token count.

## 6. Anthropic's own reporting on Claude specifically

Anthropic's system cards (for example, the Claude Opus 4.6 / Sonnet 4.6 system cards) report
long-context performance using OpenAI's MRCR v2 (Multi-Round Co-Reference Resolution) benchmark,
an eight-needle multi-round retrieval task, averaged over five trials. Per Anthropic's reporting,
Claude Opus 4.6 scores 76% on 8-needle MRCR v2 at a 1M-token context window -- described
externally as the strongest verified score on this specific multi-needle task at that length.
This is Anthropic's own primary reporting (a system card, not a marketing blog post), but it is a
single benchmark family and we did not independently verify the raw numbers by parsing the PDF
directly in this session -- treat this as Anthropic-reported, not independently reproduced.

Separately, a real-world anecdotal data point: GitHub issue
`anthropics/claude-code#35296`, "Claude 1M Context Window - Advertised Capability Does Not Work as
Marketed," is a user report describing degraded behavior in Claude Code at large context sizes.
This is one user's experience, not a controlled study, and should be weighted accordingly, but it
is consistent with the broader pattern above: an advertised context ceiling and reliable
performance across that entire ceiling are different claims.

## 7. Synthesis: what the evidence agrees on, and where it's thin

**Broad agreement across every source above, regardless of vendor:**

- Advertised context window size is not the same as effective context window size. Every
  benchmark that tested this directly (RULER, NoLiMa, BABILong, Chroma) found real accuracy well
  below what a model's stated token limit would imply.
- Position matters, not just volume: information in the middle of a long context is retrieved
  and reasoned about worse than information at the edges (Lost in the Middle, and implicitly in
  the attention-sink mechanism from StreamingLLM).
- Simple single-needle NIAH scores are close to saturated for frontier models and no longer
  discriminate between them; the harder benchmarks (semantic distractors, multi-hop, reasoning
  under padding) are where degradation actually shows up.
- Degradation is not just "the model forgets the fact" -- it shows up as increased abstention,
  increased hallucination, or slower/worse reasoning, depending on the model and task, and these
  failure modes differ by vendor.

**Where the Claude-specific evidence is thin or missing**, and should not be papered over:

- RULER and BABILong, two of the more rigorous harder-eval benchmarks, simply do not include any
  Claude model in their published results. We cannot say how Claude performs against those
  specific tasks from the sources checked here.
- LongBench v2's model list and any Claude score within it could not be confirmed.
- "Same Task, More Tokens" (the reasoning-specific degradation paper) also has an unconfirmed
  model list with respect to Claude.
- The one benchmark with the broadest multi-generation Claude coverage (Chroma) is a single
  vendor-independent technical report, not a peer-reviewed paper, and NoLiMa tested only one
  Claude generation (3.5 Sonnet). Neither is nothing, but neither is a large, converging body of
  independent evidence the way, say, the general "long context != uniform performance" finding is
  across non-Claude models.
- Anthropic's own system-card numbers (MRCR v2) are self-reported and benchmark-specific; they
  are not directly comparable to the third-party benchmarks above, which use different tasks and
  methodologies entirely.

The honest summary: the general phenomenon of context rot is well-established across many
models and many independent research groups. The claim that "Claude specifically suffers from
context rot in the same way" is supported by real but comparatively sparse evidence (mainly
Chroma's report and one NoLiMa data point), Anthropic's own reporting on Claude's long-context
retrieval is not independently reproduced in the papers reviewed here, and several of the more
rigorous adversarial benchmarks simply never tested Claude at all.

## 8. A practical inference (labeled as such, not as established fact)

None of the sources above studied Claude Code's specific auto-compaction behavior, and this
document makes no claim that they did. But the general finding they do converge on, that
performance can degrade well before a stated context ceiling is reached, and that degradation is
often driven by irrelevant or accumulated content rather than by raw token count alone, is a
reasonable basis for treating "keep the context window smaller and more relevant" as a good
practice on its own terms, separate from any argument about hitting a hard token limit. That is
an inference drawn from this research, not a finding any of the cited studies made directly about
Claude Code.

## References

### Research Papers

- [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/abs/2307.03172) - Liu et al., TACL 2024; the original U-shaped position-bias finding.
- [Efficient Streaming Language Models with Attention Sinks](https://arxiv.org/abs/2309.17453) - Xiao et al., ICLR 2024; mechanistic explanation for early-token attention bias.
- [RULER: What's the Real Context Size of Your Long-Context Language Models?](https://arxiv.org/abs/2404.06654) - Hsieh, Sun, Kriman, Acharya, Rekesh, Jia, Zhang, Ginsburg (NVIDIA); does not include Claude.
- [RULER GitHub repository](https://github.com/NVIDIA/RULER) - results table confirming model list and scores.
- [NoLiMa: Long-Context Evaluation Beyond Literal Matching](https://arxiv.org/abs/2502.05167) - Modarressi et al., ICML 2025; includes Claude 3.5 Sonnet with specific degradation figures.
- [BABILong: Testing the Limits of LLMs with Long Document Understanding](https://huggingface.co/papers/2406.10149) - Kuratov et al.; does not include Claude.
- [LongBench v2: Towards Deeper Understanding and Reasoning on Realistic Long-Context Multitasks](https://arxiv.org/abs/2412.15204) - ACL 2025; Claude presence/score unconfirmed from sources checked.
- [Same Task, More Tokens: The Impact of Input Length on the Reasoning Performance of Large Language Models](https://arxiv.org/abs/2402.14848) - Levy et al., ACL 2024; model list unconfirmed with respect to Claude.
- [Gemini 1.5: Unlocking Multimodal Understanding Across Millions of Tokens of Context](https://arxiv.org/abs/2403.05530) - Google; single-needle NIAH result, methodological caveat noted in Section 2.

### Industry Reports and Vendor Documentation

- [Context Rot: How Increasing Input Tokens Impacts LLM Performance](https://www.trychroma.com/research/context-rot) - Chroma, July 2025; broadest multi-vendor study including five Claude generations.
- [Claude 2.1 prompting tips for long context](https://claude.com/blog/claude-2-1-prompting) - Anthropic, December 2023; original NIAH-era finding and the "most relevant sentence" mitigation.

### Real-World Reports

- [Claude 1M Context Window - Advertised Capability Does Not Work as Marketed](https://github.com/anthropics/claude-code/issues/35296) - GitHub issue; single user report, not a controlled study.

### Methodology Origin

- [LLMTest_NeedleInAHaystack](https://github.com/gkamradt/LLMTest_NeedleInAHaystack) - Greg Kamradt; the original needle-in-a-haystack testing methodology, including the November 2023 GPT-4-128K vs. Claude 2.1 comparison that popularized the technique.

### Notes on Sourcing

- Anthropic's Claude Opus 4.6 / Sonnet 4.6 system card MRCR v2 figures (Section 6) are drawn from
  secondary reporting of the system card's contents; the primary PDF was fetched during this
  research but its embedded tables could not be reliably extracted, so the specific 76% figure
  should be treated as Anthropic-reported and not independently re-verified against the raw PDF
  in this session.
