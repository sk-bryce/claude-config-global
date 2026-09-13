---
audience: human
created: 2026-08-05
updated: 2026-08-31
---

# Progressive Disclosure in Agentic Tools: From UX Pattern to Context Primitive

"Progressive disclosure" started as a 1980s human-computer interaction (HCI) pattern for
keeping software interfaces learnable: show a novice user only the core controls, and defer
advanced or rarely-used features to a secondary screen. In 2025-2026 the same name was applied
to a different problem: keeping an LLM agent's context window from being exhausted by tool
definitions, skill instructions, and reference material it may never need for the current task.
This document traces both halves of that story - what the term meant before agents existed, and
what evidence actually backs its use as an agent-context-management technique today - and is
explicit about where the second half is thin.

## 1. The original HCI pattern, and how solid its evidence base actually is

The earliest articulation on record is Kristina Hooper Woolsey's, writing in 1985 (as reproduced
in Norman & Draper's 1986 edited volume *User Centered System Design*): a good interface
"selectively informs a user about a particular system, providing well-chosen bits and pieces that
can constitute a general understanding of a system" rather than exposing everything at once.

The first controlled empirical test of a version of this idea is Carroll & Carrithers' 1984
"training wheels" study: a word-processor interface was deliberately modified to make advanced,
error-prone functions unreachable for new users. Users trained on the restricted ("training
wheels") interface learned faster, made fewer errors, and scored better on a comprehension
post-test than users given the full interface from the start.

Jakob Nielsen's 2006 Nielsen Norman Group article is the definition most commonly cited today:
progressive disclosure "defers advanced or rarely used features to a secondary screen," improving
learnability, efficiency, and error rates. Nielsen's own article is notable for what it does
*not* do - it states the pattern is "more than 30 years old" but supplies no citation trail back
to Woolsey or Carroll, and the empirical support it references is described only in passing
("people understand a system better when you help them prioritize features"), without naming the
study.

This matters for what follows: even at its HCI origin, progressive disclosure was never
established with heavy quantitative rigor. Carroll & Rosson's own later assessment, dated 1997
(cited secondhand via search results, not independently fetched - see Notes on Sourcing), is
blunter still: it reportedly states no controlled empirical evidence exists for the general
pattern's effectiveness outside the narrow training-wheels result. George Miller's classic 1956
finding that working memory holds roughly seven (plus or minus two) chunks of information is
frequently invoked to *motivate* progressive disclosure and similar chunking patterns, but it is
evidence for a general capacity limit, not a direct test of progressive disclosure as an interface
technique.

Net assessment: the pattern has one solid, specific empirical result (Carroll & Carrithers, 1984,
on a training-wheels word processor), a body of design-practice consensus built on top of it
(Nielsen and three decades of interaction-design literature), and comparatively little rigorous
testing of the general principle itself.

## 2. Why agent builders reached for the same name

Anthropic's Agent Skills architecture, announced October 16, 2025, is the source that carried the
term into agentic-AI usage. The problem as stated in that announcement is structural rather than
cognitive (a point the third paragraph below revisits): an agent system prompt cannot contain every
tool description, skill instruction set, and reference document that might be relevant across all
possible tasks, because each one consumes tokens whether or not the current task needs it.
Anthropic's engineering post states the design goal directly:
"Progressive disclosure is the core design principle that makes Agent Skills flexible and
scalable," and explains that this makes "the amount of context that can be bundled into a skill...
effectively unbounded," because most of it is never loaded at all.

A February 2026 academic survey on Agent Skills (Xu & Yan, Zhejiang University) frames the same
shift in terms of a threshold effect rather than a smooth tradeoff: skill libraries reportedly
exhibit a "phase transition" beyond some critical size, past which an agent's ability to select the
right skill from its available set degrades sharply if everything is preloaded. Progressive
disclosure is presented as the mechanism that keeps selection accuracy stable as the library grows,
by keeping the agent's up-front view limited to lightweight metadata rather than full content.

There is a second rationale, distinct from the token-accounting one, that Anthropic makes in a
separate September 2025 post on context engineering: deferral is worth doing not only because
unneeded tokens cost budget, but because they degrade what the model does with the tokens that do
matter. That post argues context "must be treated as a finite resource with diminishing marginal
returns," on the observation that "LLMs, like humans, lose focus or experience confusion at a
certain point," and that "every new token introduced depletes this budget by some amount." On this
framing progressive disclosure is an attention-management technique, not merely a
storage-management one. That is the stronger claim, and it rests on a substantially better
independent evidence base than the context-efficiency claim does: the long-context degradation
literature (lost-in-the-middle position bias, effective-versus-advertised context length, accuracy
loss under distractor padding) is surveyed with per-source citation grading in
`docs/context-rot.md`. Note the limit of that support, though - none of that work tests
progressive disclosure itself. It establishes that irrelevant context is costly, which is the
premise progressive disclosure acts on, not evidence that this particular mechanism is the right
response to it.

## 3. The canonical mechanism: three levels of loading

Anthropic's own description of the SKILL.md format lays out three levels, quoted directly from the
October 2025 engineering post:

- **Level 1 - metadata.** "This metadata is the first level of progressive disclosure: it provides
  just enough information for Claude to know when each skill should be used without loading all of
  it into context." This is the `name`/`description` frontmatter every installed skill exposes at
  startup. Claude Code's skills documentation puts a hard bound on what one entry can cost: the
  combined `description` and `when_to_use` text "is truncated at 1,536 characters in the skill
  listing to reduce context usage." Measured against the skills installed in this configuration,
  `name` plus `description` runs 701 to 884 characters each, comfortably inside that cap.
- **Level 2 - the SKILL.md body.** "If Claude thinks the skill is relevant to the current task, it
  will load the skill by reading its full SKILL.md into context." Only triggered skills reach this
  level.
- **Level 3 and beyond - bundled resources.** "These additional linked files are the third level
  (and beyond) of detail, which Claude can choose to navigate and discover only as needed" -
  reference material, scripts, and examples that sit in subdirectories and are read only if the
  Level 2 instructions point to them and the task requires it.

The companion announcement (claude.com/blog/skills, same date) describes the runtime behavior in
practice: "Claude scans available skills to find relevant matches. When one matches, it loads only
the minimal information and files needed - keeping Claude fast while accessing specialized
expertise." This three-level structure is exactly the pattern this repository's own `skills/`
directory follows (`SKILL.md` frontmatter description, then body, then `references/` files loaded
on demand) - see `reference/spec-driven-architecture.md` for how this config applies it.

Level 1 is also budgeted in aggregate, not only per entry, which matters for the library-growth
argument Section 2 makes. Per the same documentation, the listing "always contains every skill
name," but its total size is capped by a budget that "scales at 1% of the model's context window,"
and on overflow Claude Code "drops descriptions starting with the skills you invoke least, so the
skills you use most keep their full text." So the harness does not let Level 1 grow without bound
as skills accumulate; it degrades, and it degrades by discarding the descriptions that do the
trigger-matching work. That is a concrete engineering answer to the phase-transition concern - and
also a reminder that the metadata level has its own failure mode, since a skill whose description
gets dropped is one the agent can no longer match on anything but its name.

It's worth noting explicitly: those are configuration limits, not effectiveness measurements.
Neither Anthropic post supplies benchmark numbers for the mechanism itself. The three-level
description is presented as architecture and design rationale, not as a result validated against a
measured alternative.

## 4. The same principle, applied without the name

Three adjacent lines of work apply the identical idea - defer detail until it's needed - to
problems other than skill libraries, without necessarily using the term "progressive disclosure":

**Tool-response shaping.** Anthropic's separate "Writing effective tools for agents" engineering
post (published September 2025) does not use the phrase, but describes the same tradeoff at the
level of individual tool calls: exposing a `response_format` parameter so an agent can request
`"concise"` or `"detailed"` output, and recommending "pagination, range selection, filtering,
and/or truncation with sensible default parameter values" so a single tool call doesn't flood the
context window. Where Agent Skills apply progressive disclosure to *which instructions* an agent
sees, this applies it to *how much of a single result* the agent sees.

**Just-in-time context loading.** The same Anthropic context-engineering post cited in Section 2
describes the retrieval counterpart: "Rather than pre-processing all relevant data up front, agents
built with the 'just-in-time' approach maintain lightweight identifiers (file paths, stored queries,
web links, etc.) and use these references to dynamically load data into context at runtime using
tools." The post names Claude Code itself as a hybrid case - "CLAUDE.md files are naively dropped
into context up front, while primitives like glob and grep allow it to navigate its environment and
retrieve files just-in-time" - which is the same metadata-then-detail split as the Skills
three-level model, applied to a file tree rather than to a bundled skill directory. This is
corroborating design rationale from the same vendor that designed the Skills model, not independent
confirmation of it.

**Dynamic tool selection.** A July 2025 paper, MemTool (Lumer, Gulati, Subbiah, Basavaraju & Burke),
addresses a related but distinct problem: in long multi-turn conversations, holding every available
tool's schema in context for the entire conversation is expensive and, past a point, degrades
tool-call accuracy. MemTool's proposed system adaptively adds and removes tool schemas from context
based on conversation state, reporting reduced token consumption alongside maintained or improved
tool-calling accuracy versus a static full-tool-list baseline. This is progressive disclosure's
logic (load only what the current step needs) applied to the tool-calling loop itself rather than
to a skill's own internal document structure.

## 5. What the direct evidence on agents actually shows

The most directly relevant empirical study located is a July 2026 preprint, "Is Progressive
Disclosure All You Need for Long-Context Agents?" (He, Zhao, Wang & Chen). It compares three
approaches to long-document question answering - raw-document navigation, several Agent-Skills-pack
designs using progressive disclosure, and classical hybrid-retriever systems - across three agent
harnesses, three model families, and the InfiniteBench benchmark (a long-context QA benchmark
suite). Findings, as summarized from the paper:

- On single-document tasks, whether progressive disclosure helps at all depends heavily on how
  strong the underlying agent harness already is; reported gains range from substantial to nearly
  zero.
- At larger scale (many documents), plain raw-document navigation fails outright, while
  single-level progressive disclosure "degrades more slowly and pulls ahead" of it.
- Adding a *second* routing level on top of the first provided no additional benefit in their
  tests, and sometimes reduced accuracy.
- Their overall framing: progressive disclosure functions as a context-management tool, not an
  intelligence enhancer - its value shows up specifically once corpus size exceeds what the agent
  could otherwise navigate directly.

This is a single preprint from one research group, submitted only about two weeks before this
document was written, evaluated on one benchmark family (InfiniteBench) - treat the specific
numbers and the "second level doesn't help" finding as an early result, not an established fact,
until independently replicated.

The February 2026 survey (Section 2) also flags a consequence of the pattern's fast informal
adoption rather than a benefit: it reports that security studies it cites (Liu et al.; Schmotz et
al. - not independently verified here) found 26.1% of community-contributed Agent Skills contained
vulnerabilities. That is a finding about the ecosystem that grew up around progressive disclosure,
not about the mechanism's context-efficiency claims, but it is a relevant caution for anyone
adopting third-party skills under this architecture.

## 6. Synthesis: what's solid, what's design rationale, what's speculative

| Claim | Status |
| --- | --- |
| Deferring detail until needed reduces context/token consumption | Solid - follows directly from how tokens are counted; not seriously in dispute |
| The specific "training wheels" restricted-interface pattern helped novice users (1984 study) | Solid - one well-defined controlled study, narrow scope (a specific word processor) |
| Progressive disclosure as a *general* UX principle is empirically well-validated | Not solid - even HCI's own literature is described as thin on this point |
| Anthropic's three-level Agent Skills loading model reduces context bloat as skill libraries scale | Design rationale, stated by the pattern's own designer, not independently benchmarked in either Anthropic post |
| Progressive disclosure outperforms raw navigation at scale for long-document agent tasks | Early empirical signal - one 2026 preprint, one benchmark family, not yet replicated |
| A second level of routing/disclosure adds further benefit | Contradicted by the one study that tested it - no benefit, sometimes worse |
| Dynamic/adaptive tool-context loading improves multi-turn tool-calling accuracy | Supported by one 2025 preprint (MemTool) with its own reported baseline comparison |
| Irrelevant context degrades model focus, not just token budget | Well-supported in the long-context literature generally (surveyed in `docs/context-rot.md`), but that work tests context length and distractors, not progressive disclosure as such |
| Progressive disclosure is worth applying to small documents and prompts | Not supported - no source located here establishes a lower bound, and Anthropic's own "simplest thing that works" guidance cuts against applying it prophylactically |

## 7. A practical inference for this configuration (labeled as such, not as established fact)

Given the above, the strongest-supported takeaway for how this repository already uses progressive
disclosure (skill frontmatter -> body -> `references/`) is narrow: it is a reasonable, low-risk way
to keep per-skill token cost proportional to whether that skill actually fires, and it matches the
one mechanism Anthropic itself ships and documents. It should not be read as a technique proven to
improve task *accuracy* in general - the one study that tested accuracy directly found the benefit
was scale-dependent and did not extend cleanly to a second disclosure level. A reasonable practical
guardrail following from Section 5's finding: if this config is ever tempted to add a second
routing/indirection layer on top of existing skill structure (a "skill of skills," a meta-index),
treat that as an open research question rather than an assumed improvement, given the one directly
relevant study found no benefit and some regression from doing so.

A second guardrail runs in the other direction, on document size rather than layer count. None of
the sources above establishes a lower bound - nothing located here measures the point below which
splitting a document costs more, in maintenance burden and in navigation cost for the human who
maintains it, than the deferred tokens save. Practitioner guidance in circulation does propose
specific numeric thresholds for exactly this decision, but the versions reviewed while writing this
document asserted them without sourcing, so they are noted here as heuristics rather than adopted
as findings (see Notes on Sourcing). What can be said with a real source behind it is Anthropic's
own closing advice in the context-engineering post: "'do the simplest thing that works' will likely
remain our best advice for teams building agents on top of Claude." Applied here, that argues for
treating progressive disclosure as a response to an observed problem - a document large enough that
most of it is irrelevant to most tasks that load it - rather than as a structure applied to every
file by default.

## Notes on Sourcing

- The claim that "Carroll & Rosson (1997)" stated no empirical evidence exists for progressive
  disclosure's general effectiveness came from a search-engine-generated summary of secondary
  sources, not from a document this session opened and read directly. It is plausible and
  consistent with the rest of the HCI record here, but it is reported, not verified, and is
  deliberately excluded from the References list below on that basis.
- Carroll & Rosson's 1987 "Paradox of the active user" (in *Interfacing Thought: Cognitive Aspects
  of Human-Computer Interaction*) came up as a related citation in search results but was never
  independently fetched this session; it is mentioned above only as context, not cited as a
  verified source.
- The 26.1%-vulnerable-skills statistic is the February 2026 survey's own citation of other work
  (Liu et al., Schmotz et al.); this document did not independently fetch those underlying studies,
  so the number should be read as "one survey's reported figure," not independently confirmed here.
- Two direct-access attempts (ACM Digital Library, ResearchGate) for the Carroll & Carrithers 1984
  paper returned HTTP 403 - per this repo's link-verification policy that is inconclusive
  bot-blocking, not confirmed absence, so an alternative working mirror (Penn State's PURE
  repository) is used in the References below instead.
- The numeric thresholds referenced in Section 7 (specific token counts marking a document as
  worth splitting, and a percentage-of-irrelevant-content ratio) come from practitioner
  documentation reviewed while writing this document. That material states the figures directly but
  cites no study, measurement, or derivation for any of them, and no independent source for them
  was located. They are mentioned in Section 7 as evidence that the lower-bound question is being
  asked in practice, and are deliberately not adopted as this document's own guidance or listed in
  the References below.
- The 701-to-884-character range in Section 3 is a local measurement, not a published figure: it
  is the byte count of the `name` and `description` frontmatter fields across the skills in this
  repository's `skills/` directory. It is included to show where real skill metadata sits
  relative to the documented 1,536-character cap, and should be read as one configuration's
  sample rather than as a general characterization of skill frontmatter. The character counts are
  exact; no token conversion is asserted, since the characters-per-token ratio varies by
  tokenizer and content and no source for a specific ratio is cited here.
- No peer-reviewed, replicated study specifically measuring progressive disclosure's effect on
  agent task *accuracy* (as opposed to token cost) was found beyond the single July 2026 preprint
  in Section 5. This is the single biggest evidence gap in this document: the technique is
  architecturally well-documented by its own designer but only thinly tested against alternatives.

## References

### Research Papers

- [The Magical Number Seven, Plus or Minus Two](https://psychclassics.yorku.ca/Miller/) - Miller, G.A. (1956), *Psychological Review*, 63, 81-97; foundational cognitive-capacity result often invoked to motivate chunking/progressive-disclosure-style designs, not a direct test of the pattern itself.
- [Training Wheels in a User Interface](https://pure.psu.edu/en/publications/training-wheels-in-a-user-interface/) - Carroll, J.M. & Carrithers, C. (1984), *Communications of the ACM*, 27(8), 800-806; the earliest controlled empirical study behind the pattern.
- [Is Progressive Disclosure All You Need for Long-Context Agents?](https://arxiv.org/abs/2607.17598) - He, Zhao, Wang & Chen (2026); the one located empirical study testing progressive disclosure against alternatives for long-document agent tasks.
- [Agent Skills for Large Language Models: Architecture, Acquisition, Security, and the Path Forward](https://arxiv.org/html/2602.12430v3) - Xu & Yan (2026), Zhejiang University; survey synthesizing the Agent Skills architecture and citing third-party security findings.
- [MemTool: Optimizing Short-Term Memory Management for Dynamic Tool Calling in LLM Agent Multi-Turn Conversations](https://arxiv.org/pdf/2507.21428) - Lumer, Gulati, Subbiah, Basavaraju & Burke (2025); adaptive tool-context loading for multi-turn tool-calling.

### Industry and Practitioner Sources

- [Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) - Nielsen, J. (2006), Nielsen Norman Group; the most commonly cited modern definition, with the caveats about thin sourcing noted in Section 1.
- [Progressive disclosure](https://en.wikipedia.org/wiki/Progressive_disclosure) - Wikipedia; used here only for the Woolsey (1985) / Norman & Draper (1986) attribution.
- [Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) - Anthropic Engineering (2025-10-16); primary source for the three-level loading model quoted in Section 3.
- [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Anthropic Engineering (2025-09-29); the finite-resource/attention-budget framing in Section 2, just-in-time loading and the Claude Code hybrid model in Section 4, and the "simplest thing that works" guidance in Section 7.
- [Introducing Agent Skills](https://claude.com/blog/skills) - Anthropic/Claude (2025-10-16); companion announcement describing runtime loading behavior.
- [Extend Claude with skills](https://code.claude.com/docs/en/skills) - Anthropic, Claude Code documentation; product reference giving the concrete Level 1 budget figures cited in Section 3 (the 1,536-character per-entry cap and the listing budget at 1% of the context window).
- [Writing effective tools for agents - with agents](https://www.anthropic.com/engineering/writing-tools-for-agents) - Anthropic Engineering (2025-09); adjacent context-shaping techniques (response format, pagination/truncation) that apply the same underlying principle without using the term.

### Further Local Reading

- `docs/context-rot.md` - citation-graded survey of the long-context-degradation research underwriting Section 2's premise that irrelevant context costs more than the tokens it occupies.
- `reference/spec-driven-architecture.md` - how this configuration's own skill structure implements the metadata/body/reference-file loading levels described in Section 3.
- `reference/document-generation.md` - the source-verification and References-formatting policy this document follows.
