---
audience: human
created: 2026-07-28
updated: 2026-07-28
---

# Chapter 6: Security, Privacy, and Data

This chapter covers the security properties of generative AI systems and what actually happens to the text you send them. It assumes the vocabulary from [Chapter 1](01-fundamentals.md) and the architectural concepts from [Chapter 4](04-agents-subagents-harnesses-and-tools.md): agents, tools, plugins, skills, and MCP servers are defined there and are not redefined here.

Two framing notes before the detail.

First, this is a fast-moving area where vendor policy changes more often than the underlying engineering. Every per-vendor claim below is tied to a specific document that was read while this chapter was written, and is dated accordingly. Treat those claims as a starting point for your own verification, not as a substitute for it.

Second, one narrow point in this chapter rests on OpenAI help-center content retrieved through search rather than a direct page fetch, since OpenAI's consumer-facing pages blocked direct automated retrieval during writing. That is noted in place in section 5.2 rather than silently treated as equivalent to the directly-fetched sources used elsewhere in this chapter.

## In short

- Prompt injection is not a bug that will be patched. Language models consume instructions and data as one undifferentiated token stream, so there is no reliable equivalent of parameterized queries. OWASP's own guidance says it is unclear whether fool-proof prevention exists.
- Jailbreaking and prompt injection are different threats with different victims. Jailbreaking targets the provider's safety training using the attacker's own prompt. Injection targets your application using content a third party controls.
- Tools, plugins, skills, and MCP servers are where injection becomes expensive. The controls that actually work are architectural: least privilege, per-user scopes, enforcement in the downstream system rather than in the model, and human approval gates on irreversible actions.
- Consumer chat products and API or enterprise tiers have materially different data terms. As of this writing, every commercial or API document verified here states that customer traffic is not used for model training by default or without permission, while the consumer products verified here make training use contingent on a user-facing setting whose mechanism differs by vendor.
- Zero data retention exists but is narrower than the name suggests. Every vendor that offers it carves out safety classification, legal holds, and specific stateful endpoints or features.
- Nothing here removes the need to read the current terms. Check the provider's trust center, data processing addendum, and product-specific data page before making a decision that depends on the details.

---

## 1. Prompt Injection

### 1.1 The two shapes of the attack

OWASP (the Open Worldwide Application Security Project, a nonprofit best known for maintaining consensus lists of the most critical security risks for a given technology area) publishes a Top 10 for LLM Applications that lists prompt injection as LLM01, its highest-ranked risk, and defines it as a vulnerability that "occurs when user prompts alter the LLM's behavior or output in unintended ways," explicitly noting that the injected content does not need to be human-visible as long as the model parses it.

OWASP splits it into two types:

| Type | Who supplies the malicious text | Typical delivery | Who is harmed |
| --- | --- | --- | --- |
| Direct prompt injection | The person typing into the system | Chat message, form field, uploaded file the user chose | Usually the operator: policy bypass, system prompt disclosure, unauthorized function access |
| Indirect prompt injection | A third party who controls content the model will later read | Web page, email, PDF, code comment, issue tracker, tool output, image | Usually the user: their data is read and exfiltrated using their own permissions |

The distinction matters operationally. Direct injection is an abuse problem: a user attacking the system they are logged into. Indirect injection is a classic confidentiality and integrity problem: an outsider with no account and no credentials influencing a privileged process, because your model reads attacker-controlled bytes.

Indirect injection was formalized by Greshake et al. in "Not what you've signed up for: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection." Their central observation is the one to carry forward: LLM-integrated applications "blur the line between data and instructions," which lets an adversary "remotely (without a direct interface) exploit LLM-integrated applications by strategically injecting prompts into data likely to be retrieved." They demonstrated the attacks against production systems, including Bing's GPT-4 powered chat and code-completion engines, and showed that processing retrieved prompts can act as arbitrary code execution over the application's own capabilities.

### 1.2 Why it is structurally hard

Traditional injection classes have structural fixes. SQL injection is solved by parameterized queries, which separate the query plan from the values. Cross-site scripting is solved by context-correct output encoding. Both fixes work because the underlying system has a real boundary between code and data that the defender can put the untrusted bytes on the correct side of.

A transformer has no such boundary. The system prompt, the conversation history, the retrieved document, and the tool result are concatenated into one sequence of tokens. Instruction-following is a learned statistical behavior over that sequence, not a privileged interpreter mode. Role markers such as "system" and "user" are conventions the model was trained to weight more heavily, not access controls the runtime enforces.

Three consequences follow, and they explain why this problem resists the fixes people reach for first.

1. **Defenses are probabilistic, not structural.** Telling the model to ignore instructions found in documents reduces success rates. It cannot bound them, because the space of phrasings, encodings, languages, and modalities is unbounded. OWASP states the position plainly: given the stochastic nature of these models, "it is unclear if there are fool-proof methods of prevention for prompt injection."
2. **Injected instructions inherit the agent's authority.** The model is not tricked into gaining new permissions. It is tricked into using the permissions it legitimately holds. This is why the severity of an injection is set almost entirely by the agent's tool surface rather than by the cleverness of the payload.
3. **The channel widens as capability grows.** OWASP calls out multimodal injection specifically: instructions hidden in an image that accompanies benign text, with cross-modal attacks that current text-oriented filters do not see. Retrieval, browsing, code execution, and multi-agent messaging each add another surface that carries untrusted tokens into context.

NIST's Generative AI Profile makes the same point from a risk-management perspective, noting that generative AI "expands the available attack surface" and describing both direct and indirect prompt injection under its Information Security risk category, with the observation that researchers have already demonstrated indirect injections against real systems.

A useful practitioner framing, from Simon Willison, who coined the term prompt injection, is the "lethal trifecta": an agent is exposed when it combines access to private data, exposure to untrusted content, and the ability to communicate externally. Any two of the three is usually survivable. All three together means an attacker who controls the untrusted content can route your private data outward. This is a heuristic rather than a formal result, but it is the most useful single test for triaging an agent design, and it maps cleanly onto the mitigations below.

### 1.3 Documented examples and attack classes

Concrete, citable cases matter here, because this class of attack is frequently discussed in the abstract.

- **A vendor-tracked CVE in a shipping product.** CVE-2025-32711 records an "AI command injection in M365 Copilot" that "allows an unauthorized attacker to disclose information over a network." Microsoft, as the assigning authority, scored it CVSS 3.1 at 9.3 (critical); NVD's own enrichment scored it 7.5 (high). It is classified under CWE-74/CWE-77 injection weaknesses and was published in June 2025. This is a clean instance of the general pattern: untrusted content reaching an assistant that holds a user's data, resulting in disclosure without any credential compromise.
- **An email-assistant CVE cited by OWASP.** OWASP's LLM01 entry references CVE-2024-5184 as a scenario where an attacker exploits an LLM-powered email assistant to inject malicious prompts, gaining access to sensitive information and manipulating email content. (This chapter cites OWASP's characterization; the CVE record itself was not independently reviewed here.)
- **Attack classes named in OWASP's LLM01 scenarios.** Payload splitting, where malicious instructions are divided across a document so that no single fragment looks hostile. Multilingual and obfuscated attacks, using another language or an encoding such as Base64 to evade filters. Adversarial suffixes, where a seemingly meaningless string steers the model's output. Multimodal injection, with instructions carried in an image. Exfiltration through rendered content: OWASP's canonical indirect example is a summarization request against a page containing hidden instructions that cause the model to emit an image linked to an attacker URL, leaking the conversation through the image fetch.
- **Data-flow poisoning of retrieval.** OWASP describes an attacker modifying a document in a repository used by a RAG application so that a user's query returns the modified content and the injected instructions alter the output. See [Chapter 5](05-retrieval-embeddings-and-vector-databases.md) for how retrieval pipelines assemble that context, and note that OWASP tracks the storage layer separately as LLM08, vector and embedding weaknesses.

### 1.4 Mitigations and their limits

Every control below is real and worth deploying. None is sufficient alone, and it is worth being explicit about where each one fails.

| Mitigation | What it does | Where it fails |
| --- | --- | --- |
| Instructional hardening (constrain the model's role, tell it to ignore embedded instructions) | Raises the cost of casual attacks; reduces accidental misbehavior | Bypassable by rephrasing, encoding, role-play framing, or another modality. It is a hint, not a control |
| Input and output filtering or classifiers | Catches known attack shapes at scale; useful telemetry | Detection-based, so false negatives are structural. Microsoft's own Prompt Shields documentation states that it "may not catch all attack vectors or may flag legitimate prompts" and advises additional validation layers |
| Segregating and marking untrusted content | Makes provenance explicit and gives downstream logic something to enforce on | The model still sees one token stream; marking is advisory unless something outside the model acts on it |
| Privilege separation and least privilege | Bounds the blast radius of a successful injection. OWASP's guidance is to give the application its own tokens, handle privileged functions in code, and restrict the model to the minimum needed | Does not prevent injection; only limits its consequences. Requires accurate scoping work per tool |
| Human-in-the-loop approval for high-impact actions | Stops irreversible actions taken on injected instructions | Degrades under approval fatigue. Users click through prompts they see hundreds of times, and batched or fast-moving agent runs make careful review harder |
| Sandboxing and isolation | Contains code execution and file access; limits network egress | Contains the consequence, not the decision. An agent with legitimate read access to a secret can still be induced to reveal it inside the sandbox and then transmit it through an allowed channel |
| Deterministic output validation | Enforces schema and format so downstream code cannot be driven by free text | Only covers what you can specify. Semantically wrong but structurally valid output passes |
| Adversarial testing and red teaming | Finds real failures before attackers do; the only way to measure the rest | A point-in-time result. Model updates, new tools, and new content sources invalidate prior findings |

Two research directions are worth knowing because they attack the structural problem rather than the symptom.

- **CaMeL** ("Defeating Prompt Injections by Design," Debenedetti et al.) builds a protective system layer around the model that extracts control and data flow from the trusted query, so untrusted data retrieved later "can never impact the program flow," and enforces capability-based policies at tool-call time to prevent exfiltration. The published evaluation solved 77 percent of AgentDojo tasks with provable security, against 84 percent for an undefended system. That gap is the honest price of the approach today.
- **Design patterns for securing LLM agents** (Beurer-Kellner et al.) proposes a set of patterns with provable resistance to injection and analyzes their utility-versus-security trade-offs. The core principle both papers share: once an agent has ingested untrusted input, that input must not be able to trigger consequential actions.

The practical reading is that prompt injection is currently managed by architecture, not prevented by detection. If your design depends on the model reliably ignoring hostile text, it is not a secure design.

---

## 2. Jailbreaks

### 2.1 How jailbreaking differs from prompt injection

The terms are widely conflated. OWASP treats jailbreaking as a form of prompt injection, describing it as the case where "the attacker provides inputs that cause the model to disregard its safety protocols entirely," and notes that safeguards in system prompts and input handling can mitigate injection while effective jailbreak prevention "requires ongoing updates to the model's training and safety mechanisms."

For engineering purposes the more useful distinction is by victim and by owner of the fix:

| | Jailbreak | Prompt injection (indirect) |
| --- | --- | --- |
| Whose prompt carries the attack | The attacker's own | A third party's content that the victim's agent reads |
| What is targeted | The model's safety training and the provider's policy | The application's data and permissions |
| Who is primarily harmed | The provider, and society if harmful output results | The user or operator whose data and tools are misused |
| Who can fix it | The model provider, through training and safety systems | The application builder, through architecture and permissions |

Microsoft's Prompt Shields documentation encodes exactly this split at the product level: it separates "User Prompt attacks" (attacker is the user, entry point is the user prompt, method is ignoring system prompts or safety training) from "Document attacks" (attacker is a third party, entry point is third-party content such as documents and emails, objective is gaining unauthorized access or control).

If you build applications, indirect injection is almost always your larger risk. Jailbreaking mostly matters to you as a policy and reputational concern, and as an abuse-detection signal.

### 2.2 Categories of technique, conceptually

Described at the level of category only, no working examples. These are the classes that vendors and researchers publicly name.

- **Instruction override.** Requests to disregard prior rules, instructions, or previous turns, or to operate as a new unrestricted assistant. Named by Microsoft as "attempt to change system rules."
- **Persona and role-play framing.** Instructing the model to adopt a different system persona said to lack restrictions, or attributing human qualities to it that license different behavior.
- **Fabricated conversational context.** Embedding invented prior turns inside a single message so the model treats permission as already granted. Microsoft calls this "embedding a conversation mockup."
- **Encoding and transformation.** Ciphers, character transformations, alternate output styles, or requests to converse in an encoding, aiming to slip past filters that operate on plain text. OWASP separately lists multilingual and obfuscated attacks in the same family.
- **Payload splitting.** Distributing a request across turns or documents so no single piece is individually refusable.
- **Automated adversarial suffix search.** Rather than human ingenuity, gradient and search methods find token strings that raise the probability of a compliant response. Zou et al. showed in "Universal and Transferable Adversarial Attacks on Aligned Language Models" that such suffixes can be optimized against open models and then transfer to black-box production systems, including, at the time of that work, ChatGPT, Bard, and Claude. The significance is not any particular string but the demonstration that jailbreaks can be generated at machine scale and transferred across vendors.

### 2.3 Why providers treat it as an arms race

Safety behavior is trained, and trained behavior generalizes imperfectly to inputs unlike anything in the training distribution. Three properties keep this open-ended:

- The input space is unbounded and cheap to search, while each defensive update is a costly training or classifier change.
- Transferability, as Zou et al. demonstrated, means an attack developed against an open model may work against closed ones, so a provider's defenses are probed by research they do not control.
- Safety and usefulness pull against each other. A model that refuses aggressively enough to be hard to jailbreak refuses legitimate work, which is itself a product failure. Every provider is choosing a point on that curve, and the point moves.

The reasonable expectation is continuous, incremental hardening rather than a solved state. For builders, that means: do not treat model-level safety as a security control in your own threat model. It is the provider's policy layer, tuned to the provider's risk, and it is regularly bypassed. Your controls need to hold even when it does not.

There is a second consequence that is easy to miss: repeated jailbreak attempts are themselves a monitored signal. Microsoft's abuse monitoring documentation for Models sold by Azure describes scoring potential abuse based on the frequency and severity of harmful content detected in prompts and completions as well as the apparent intentionality of the behavior, and gives "recurring jailbreak attempts" as an example of conduct more likely to receive a high abuse score, with confirmed thresholds leading to customer notification and, for failure to address the behavior or recurring or severe abuse, potentially to suspension or termination of access. If you are red-teaming a hosted model, do it under whatever program or agreement the provider offers rather than assuming safety testing is invisible.

---

## 3. Plugin, Skill, Tool, and MCP Server Security

[Chapter 4](04-agents-subagents-harnesses-and-tools.md) covers what these components are. This section covers what they do to your attack surface.

### 3.1 What changes when the model can act

OWASP's LLM06, Excessive Agency, describes the shift precisely: an LLM-based system is granted "the ability to call functions or interface with other systems via extensions (sometimes referred to as tools, skills or plugins by different vendors)," and the choice of which extension to invoke may itself be delegated to the model. Excessive Agency is then defined as the vulnerability "that enables damaging actions to be performed in response to unexpected, ambiguous or manipulated outputs from an LLM, regardless of what is causing the LLM to malfunction."

Note the last clause. The vulnerability does not require an attacker. A confabulated tool call from a poorly grounded prompt can delete the same records that a successful injection would. OWASP names two common triggers: hallucination from benign but poorly engineered prompts or a weak model, and direct or indirect prompt injection from a malicious user, a compromised extension, or in multi-agent systems a compromised peer agent.

OWASP roots the problem in three excesses, which are worth memorizing as a review checklist: excessive functionality, excessive permissions, and excessive autonomy.

The reason this is worth drawing rather than only describing is that the trust boundaries in an agent system do not sit where most people's intuition places them. The model is not a trusted component that occasionally receives bad input; it is a component whose behavior is partly controlled by whoever authored the content it reads:

```
                 attacker-influenceable
   ┌──────────────────────┴───────────────────────┐
   │  web pages   emails   documents   code repos │
   │  issue trackers   tool results   images      │
   └──────────────────────┬───────────────────────┘
                          │  untrusted tokens
                          v
  ┌───────────────────────────────────────────────┐
  │  MODEL CONTEXT                                │
  │  system prompt + user turn + history +        │
  │  retrieved content + tool output              │
  │  (one undifferentiated token sequence)        │
  └───────────────────────┬───────────────────────┘
                          │  proposed tool call
                          v
  ══════════ TRUST BOUNDARY THAT MUST HOLD ═══════
                          │
     ┌────────────────────┴────────────────────┐
     │ authorization in the downstream system  │
     │ per-user scopes, allowlists, quotas     │
     │ human approval for irreversible actions │
     └────────────────────┬────────────────────┘
                          v
              private data   money   email
              code push      permissions
```

The boundary that has to hold is below the model, not above it. Anything you enforce inside the context window is advice; anything you enforce in the tool layer and the downstream system is a control.

OWASP's Agentic Security Initiative published a separate Top 10 for Agentic Applications in December 2025, described as a peer-reviewed framework developed with more than 100 contributors covering risks specific to systems that plan, hold memory, call tools, and act with delegated authority. If you are designing agent systems, read that list alongside the LLM Top 10; this chapter cites the LLM Top 10 for the specific risk definitions because those entries are published in full detail.

### 3.2 Specific risk patterns

**Malicious or compromised servers reading what they should not.** Anything that enters the model's context is visible to whatever the model can talk to next. OpenAI's own MCP documentation is unusually direct about this: developers must trust any remote MCP server they use, because "a malicious server can exfiltrate sensitive data from anything that enters the model's context." It further notes that remote MCP servers "have not been verified by OpenAI," are third-party services subject to their own terms, and that data sent to an MCP server is subject to that server's retention policies rather than OpenAI's.

**Confused deputy.** The agent is not a broken control; it is a legitimate deputy holding real authority, induced to use it on an attacker's behalf. OWASP's canonical LLM06 scenario is a mail assistant that needs read access to summarize incoming email but is wired to an extension that can also send; an incoming email carries an injection instructing the agent to scan the inbox for sensitive data and forward it to the attacker. Nothing was hacked. The permissions worked as designed.

The MCP specification documents a distinct protocol-level confused deputy problem: an MCP proxy server using a static client ID with a third-party authorization server, combined with dynamic client registration and the authorization server's consent cookie, can be induced to issue authorization codes to an attacker-supplied redirect URI without a fresh consent screen. The specification's mitigation is mandatory: proxy servers MUST implement per-client consent, MUST validate redirect URIs by exact string match, and MUST NOT set the consent-tracking state cookie before the user has actually approved the consent screen.

**Token passthrough.** The MCP specification names as an anti-pattern any server that accepts a token from a client without validating that the token was issued to that server, then forwards it to a downstream API. The requirement is absolute in the spec's language: MCP servers MUST NOT accept tokens that were not explicitly issued for them. The failure mode is audit and authorization collapse, since the downstream API sees a valid token and cannot distinguish a legitimate path from a laundered one.

**Over-broad scopes.** The MCP security guidance describes servers that advertise their entire scope catalog and clients that request all of it, so a single leaked token carries broad authority (`files:*`, `db:*`, `admin:*`), enabling lateral access and privilege chaining and making revocation impossible without re-consenting the whole surface. OWASP's parallel formulation: an extension that only needs `SELECT` connecting with an identity that also holds `UPDATE`, `INSERT`, and `DELETE`, or a per-user feature connecting with one high-privileged shared identity that can read every user's files.

**Local execution and installation-time supply chain.** Locally installed servers are ordinary programs running with your user's privileges. The MCP specification enumerates the attacks that follow when consent is missing: a malicious startup command placed in client configuration, a malicious payload inside the server binary itself, and access to an insecure local server left listening on localhost via DNS rebinding. Its mitigation for one-click installation is that clients MUST show the exact command to be executed, without truncation, identify it as a potentially dangerous operation, and require explicit approval. It also requires clients to reject dangerous URL schemes such as `javascript:`, `data:`, and `file:` from servers, and to avoid opening URLs through a shell, since either path leads to script execution or command injection.

OWASP's LLM03 (Supply Chain) covers the same class at the ecosystem level: third-party components, weak provenance for published models and artifacts, and the observation that unclear terms and privacy policies from an upstream operator can result in your sensitive data being used for training. Its recommended controls are the familiar ones applied to a new artifact type: vet suppliers and their terms, maintain a signed inventory (an SBOM, or software bill of materials: an itemized list of every component, library, and dependency that went into a piece of software, with AI BOM and ML SBOM as emerging equivalents scoped to models and training data), verify integrity with signing and hashes, patch deprecated components, and re-audit when a supplier's posture or terms change.

**Unexpected behavior change after review.** OpenAI's MCP documentation notes that servers "may update tool behavior unexpectedly, potentially leading to unintended or malicious behavior." A review at install time does not bind future versions. This is the AI-specific analogue of a dependency that changes its behavior on a minor version bump, with the difference that the tool description itself is model-facing input and can be rewritten to steer the model.

### 3.3 Mitigations that actually hold

OWASP's LLM06 prevention list is the best short specification available, and it is notable for what it puts first: reduce capability, then reduce permission, then add oversight.

- **Minimize extensions and extension functionality.** Do not offer a tool the workflow does not need, and do not use a broad tool where a narrow one exists.
- **Avoid open-ended extensions.** OWASP is explicit that "run a shell command" or "fetch a URL" tools should be replaced with granular ones. A file-writing tool is a smaller surface than a shell that can write files.
- **Minimize permissions and execute in the user's context.** Track user authorization so downstream actions run as that user with minimum scope, for example OAuth with a read-only scope rather than a shared privileged identity.
- **Require user approval for high-impact actions.** OWASP's example is a social posting agent that implements approval inside the `post` operation itself, rather than trusting an earlier stage.
- **Complete mediation.** Implement authorization in the downstream system, not in the model. All requests through extensions get validated against policy regardless of what the model decided.
- **Log, monitor, and rate-limit.** OWASP is clear these do not prevent Excessive Agency but do limit damage and shorten detection time.

Two production implementations show what this looks like when shipped, and both are useful as a design reference.

Anthropic's Claude Code security documentation describes a permission-based architecture: read-only permissions by default with explicit approval for anything that modifies the system, a working-directory boundary that prevents writes outside the launch directory without approval, a sandboxed bash mode with filesystem and network isolation, network-fetch commands such as `curl` and `wget` excluded from auto-approval, web fetch running in an isolated context window specifically "to avoid injecting potentially malicious prompts," trust verification on first run in a codebase and on new MCP servers, command-injection detection that forces manual approval even for previously allowlisted commands, and fail-closed matching so unmatched commands require approval. The same document states the residual-risk position that any honest vendor has to state: "While these protections significantly reduce risk, no system is completely immune to all attacks."

It is equally worth reading what that page does not promise. On MCP it says Anthropic "reviews connectors against its listing criteria before adding them to the Anthropic Directory, but does not security-audit or manage any MCP server," and recommends writing your own servers or using ones from providers you trust. Directory presence is a curation signal, not a security audit.

OpenAI's MCP guidance lands in the same place from the API side: tool-call approval is required by default (`require_approval` defaults to requiring it, and can be narrowed or disabled per tool once you trust a server), prefer official servers hosted by the service provider itself over third-party aggregators, do due diligence on aggregators and how they use your data, log what is sent to third-party servers and review it periodically, and treat URLs returned in tool output as untrusted rather than fetching or embedding them. It also notes that OpenAI has built-in safeguards intended to detect hidden instructions from malicious servers while still advising careful review of inputs and outputs, which is the right way to describe a probabilistic defense.

For installation-time hygiene, permission scoping in configuration files, and where these settings live on disk, see [Appendix A](appendices/appendix-a-plugins-and-config-paradigms.md).

### 3.4 A review checklist for third-party skills, plugins, and MCP servers

Before installing anything that will run alongside a model with access to your data:

1. **Identify the publisher.** Is this operated by the service it integrates with, or by an intermediary proxying your credentials? OpenAI's guidance to prefer the first-party server is well founded.
2. **Read the source or the tool manifest.** Tool names and descriptions are model-facing text. Look for instructions aimed at the model rather than descriptions aimed at you.
3. **Enumerate the scopes it requests.** Compare them against what the feature actually needs. A summarizer that asks for write or send scopes has failed the check.
4. **Find the egress paths.** Any HTTP capability, link rendering, or image fetch is a potential exfiltration channel. Combined with private data access and untrusted content, that completes the trifecta.
5. **Check the credential model.** Does it hold long-lived tokens? Are they scoped per user? Does it accept tokens issued for someone else, contrary to the MCP specification?
6. **Confirm the update posture.** Is the version pinned? Will a behavior change be visible to you?
7. **Decide the confirmation policy explicitly.** Which of its actions are irreversible, and which of those will require human approval every time.
8. **Confirm where the data goes.** Third-party servers are subject to their own retention terms, not your model provider's.

---

## 4. Other General Security Risks

Concise treatment, one risk at a time, each anchored to a source. NIST's Adversarial Machine Learning taxonomy (AI 100-2 E2025) is the standard reference for terminology across all of these, and is a good place to standardize vocabulary across a security team.

**Training data poisoning.** OWASP's LLM04 defines data and model poisoning as manipulation of pre-training, fine-tuning, or embedding data to introduce vulnerabilities, backdoors, or biases, and classifies it as an integrity attack. Its most operationally uncomfortable observation is about backdoors: a poisoned model's behavior may be untouched until a trigger fires, which "may make such changes hard to test for and detect." That this is practical rather than theoretical was shown by Carlini et al. in "Poisoning Web-Scale Training Datasets is Practical," which introduced split-view poisoning, exploiting the mutability of web content so a dataset annotator's view differs from what later clients download, and frontrunning poisoning against periodically snapshotted crowd-sourced sources. The authors report they could have poisoned 0.01 percent of LAION-400M or COYO-700M for roughly 60 US dollars, and notified the affected dataset maintainers. OWASP also flags a related distribution risk: models shared through repositories can carry malware through mechanisms such as malicious pickling that executes on load.

**Model extraction and theft via API queries.** Tramèr et al. showed in "Stealing Machine Learning Models via Prediction APIs" that an adversary with black-box query access and no knowledge of parameters or training data can duplicate model functionality, with near-perfect fidelity for several model classes, and that withholding confidence values does not eliminate the risk. OWASP's LLM02 records the same concern for LLM systems, citing the Proof Pudding case (CVE-2019-20634) in which disclosed training data facilitated model extraction and inversion. For an application owner the practical exposure is usually not losing the frontier model but losing a fine-tuned model or classifier that encodes proprietary work, which makes rate limiting, per-key quotas, and anomaly detection on query patterns a defense of commercial value rather than only a cost control. OWASP's LLM10, Unbounded Consumption, covers the adjacent cost and availability dimension.

**Membership inference and training-data extraction.** Shokri et al. established the basic membership inference attack: given a data record and black-box access to a model, determine whether that record was in the training set, which matters whenever membership itself is sensitive, their example being a hospital discharge dataset. Carlini et al. then demonstrated verbatim extraction from a language model, recovering hundreds of exact sequences from GPT-2's training data, including personally identifiable information such as names, phone numbers, and email addresses, in cases where a sequence appeared in only a single training document, and found that larger models were more vulnerable. NIST's Generative AI Profile summarizes the resulting privacy position: models may leak, generate, or correctly infer sensitive information about individuals, a problem it names data memorization, and may also infer sensitive attributes that were never in the training data by combining information from disparate sources. The practical implication for anyone fine-tuning on internal data is that the resulting model should be treated as a potential disclosure channel for that data, not as a safe derivative of it.

**Adversarial inputs.** Beyond natural-language injection, inputs can be optimized to produce a chosen model behavior. Zou et al.'s transferable adversarial suffixes are the language-model case; NIST AI 100-2 places evasion attacks in a broader taxonomy alongside poisoning and privacy attacks and provides the standard terminology. OWASP's LLM01 lists adversarial suffixes as a prompt injection scenario, which is a reasonable classification for application defenders even though the mechanism is closer to gradient-based optimization than to social engineering. The defensive consequence is that a filter tuned on human-legible attack text will not necessarily see machine-optimized input.

**Excessive Agency.** Covered in detail in section 3, but worth naming here because it is a distinct OWASP category (LLM06) and because it is the risk that converts every other item on this list into real-world impact. OWASP explicitly distinguishes it from improper output handling (LLM05), which concerns insufficient scrutiny of model outputs before they reach a downstream interpreter, browser, or shell. Both belong in a design review: LLM05 asks whether you treat model output as untrusted input to the next system, LLM06 asks whether the model should have been able to request that action at all.

**Vector and embedding weaknesses.** OWASP tracks the retrieval layer as its own category, LLM08, distinct from both poisoning of model training data and injection at inference time. The practical concern for anyone running the pipelines described in [Chapter 5](05-retrieval-embeddings-and-vector-databases.md) is that a vector store is a data store with normal access-control obligations that is frequently deployed without them: chunks from documents the requesting user should not see get retrieved into their context, tenants share an index without filtering, and any writeable ingestion path becomes a way to plant instructions that will later be retrieved as if they were trusted reference material. OWASP's LLM01 scenario of an attacker modifying a document in a RAG repository is the same attack seen from the injection side. Treat ingestion as an untrusted input path and retrieval as an authorization decision, not merely a similarity search.

**Sensitive information disclosure and system prompt leakage.** OWASP's LLM02 covers disclosure of PII, credentials, and confidential business data through model output, and notes that system-prompt restrictions on what the model may return "may not always be honored and could be bypassed via prompt injection or other methods." LLM07 covers system prompt leakage specifically. The design conclusion is that a system prompt is not a secret store: anything placed there should be assumed eventually readable by a determined user.

### Summary: mapping attacker capability to consequence

A compact way to run a design review. For each row, ask whether the attacker capability is present in your system, and whether the listed control is actually implemented below the model rather than inside the prompt.

| If an attacker can | The risk is | The control that bounds it |
| --- | --- | --- |
| Put text where your model will read it | Indirect prompt injection (LLM01) | Tool-layer authorization, egress restriction, approval gates |
| Type directly into your product | Direct injection, jailbreak (LLM01) | Abuse monitoring, output validation, least privilege |
| Get content into your retrieval index | Retrieval poisoning (LLM01, LLM08) | Authenticated ingestion, per-user retrieval filters, provenance |
| Publish an artifact you install | Supply chain compromise (LLM03) | Source review, pinning, signing and hashes, inventory |
| Get content into a training corpus | Data and model poisoning (LLM04) | Vetted sources, dataset versioning, red teaming for triggers |
| Query your model at volume | Model extraction, unbounded consumption (LLM02, LLM10) | Rate limits, quotas, query anomaly detection |
| Query a model fine-tuned on your data | Membership inference, memorization disclosure | Data minimization before fine-tuning, output filtering |
| Influence what your agent decides to do | Excessive Agency (LLM06) | Narrow tools, per-user scopes, complete mediation, human gates |
| Read your model's raw output downstream | Improper output handling (LLM05) | Treat output as untrusted input, encode and validate per sink |

---

## 5. What Actually Happens to Your Data

### 5.1 How to read this section

This is the section where imprecision does the most damage, so a few ground rules.

- Every claim below is attributed to a specific vendor document that was read while writing this chapter, with the document's own date where the page states one. Policies change without notice; a claim here is evidence of what a page said, not a guarantee of what it says today.
- The consumer-versus-commercial split is real at every vendor verified here, but it is not implemented identically, and it is not safe to generalize from one vendor to another. Each is stated separately below for that reason.
- Where a vendor's documentation did not clearly answer a sub-question, this chapter says so rather than filling the gap.
- Before making a decision that depends on any of this, check the general documentation areas rather than a single deep link: the provider's trust center, its data processing addendum, its commercial or business terms, and the product-specific data and privacy page for the exact product tier you use. Deep links in this area move frequently; the categories persist.

### 5.2 OpenAI

**API platform.** OpenAI's data controls guide for the API states plainly that "as of March 1, 2023, data sent to the OpenAI API is not used to train or improve OpenAI models (unless you explicitly opt in to share data with us)."

Retention on the API side is documented in unusual detail:

- Abuse monitoring logs, which may contain prompts and responses plus derived metadata such as classifier outputs, are generated by default for all API feature usage and retained for up to 30 days, "unless longer retention is required by law, or is reasonably necessary to protect our services or any third party from harm."
- Application state is separate from abuse logs and varies by endpoint. Per the endpoint table, `/v1/chat/completions` stores no application state by default; `/v1/responses` has a 30-day application state retention period by default or when `store` is true; stateful objects such as `/v1/conversations`, `/v1/files`, `/v1/threads`, `/v1/vector_stores`, and fine-tuning jobs are retained until deleted; Assistants API objects are removed from OpenAI servers 30 days after deletion, and objects never deleted through the API or dashboard are "retained indefinitely."
- Prompt caching may hold encrypted key/value tensors in GPU-local storage, not retained after a 24-hour expiration. Background mode stores response data for roughly 10 minutes; audio outputs for one hour.
- Every endpoint row in that table lists "Data used for training: No."

**Zero data retention and modified abuse monitoring.** Both are approval-gated controls, "subject to prior approval by OpenAI and acceptance of additional requirements," configurable at organization or project level once granted. Modified Abuse Monitoring excludes customer content from abuse monitoring logs across all endpoints. Zero Data Retention does the same and additionally forces `store` to false for `/v1/responses` and `/v1/chat/completions`. Two limits matter: endpoints marked ineligible may still store application state even with ZDR enabled, and image and file inputs are scanned for CSAM (child ------ abuse material) on submission, with flagged images retained for manual review "even if Zero Data Retention, Modified Abuse Monitoring, or Eyes Off is enabled." OpenAI also documents Eyes Off and Safety Retention as named exceptions under which it reserves the right to make specific models ineligible for ZDR or MAM for a given customer, with advance written notice.

**Data residency.** Data residency is a per-project configuration, eligibility-gated through sales, with a documented 10 percent price uplift for models released on or after March 5, 2026. Supported regions at the time of reading include the United States and Europe (EEA plus Switzerland) with both regional storage and regional processing, and Australia, Canada, and Japan with regional storage but no regional processing. Any region other than the United States requires approval for abuse monitoring controls and execution of a Modified Retention amendment. Residency covers customer content, not system data such as account, metadata, and usage information.

**ChatGPT consumer (Free, Plus, Pro, personal workspace).** Unlike the API, personal ChatGPT accounts have data sharing for model training enabled by default. OpenAI's help center states plainly that "if you are on a ChatGPT Plus, ChatGPT Pro or ChatGPT Free plan on a personal workspace, data sharing is enabled for you by default." The opt-out control is a toggle named "Improve the model for everyone," reached through Settings, then Data Controls. Turning it off applies immediately to new conversations and to the whole account regardless of device; existing conversations already used for training are not retroactively withdrawn. Conversations still appear in chat history after opting out, they are simply excluded from training. A separate, unauthenticated (signed-out) flow offers the same choice before account creation.

**Temporary Chat** is a per-conversation alternative to the account-level toggle: it does not appear in chat history, does not create or use saved memories, and is not used to train models, regardless of the account-level setting. OpenAI states Temporary Chats are retained for 30 days for safety purposes and then deleted.

**ChatGPT Business, Enterprise, and Edu, and the API.** OpenAI states that, by default, it does not train on inputs or outputs from business users, "including ChatGPT Team, ChatGPT Enterprise, and the API." This is a stronger, opt-in-only default than the personal-workspace setting above: an organization must explicitly opt in (for example through Playground feedback) to share data for training, and is otherwise opted out automatically. This chapter did not separately verify a numeric retention window for ChatGPT Business or Enterprise conversation history distinct from the API figures already documented above; check the current Enterprise Privacy page for that detail.

What can be confirmed is narrow and is about assurance rather than data use: OpenAI's Trust Portal states that its products are covered by a SOC 2 Type 2 report evaluated by an independent third-party auditor and are certified to ISO 27001, 27017, 27018, and 27701, and describes a 2025 SOC 2 report covering the API Platform, ChatGPT Enterprise, ChatGPT Edu, and ChatGPT Team. That is a controls attestation. It says nothing about training use or retention windows.

### 5.3 Anthropic

Anthropic publishes separate articles for consumer and commercial products, both dated March 16, 2026 at the time of reading.

**Consumer (Claude Free, Pro, Max, and Claude Code used from those plans).** Anthropic states it will use chats and coding sessions, including to improve models, in three cases: if you choose to allow it through your privacy settings, if conversations are flagged for safety review (in which case they may be used to improve detection and enforcement of the Usage Policy, including training models used by the Safeguards team), or if you explicitly opt in another way, such as joining the Trusted Tester program. The control is a toggle labeled "Help Improve Claude" under Settings, Privacy. Anthropic's documentation frames model-improvement use as governed by this setting; the articles reviewed do not state a single global default value for it, so check the setting in your own account rather than assuming.

Scope details worth knowing: data used for improvement can include the entire related conversation along with content, custom styles, and conversation preferences, plus data from Claude for Chrome, but it "does not include raw content from connectors (e.g. Google Drive), including remote and local MCP servers, though data may be included if it's directly copied into your conversation with Claude." Incognito chats are not used to improve Claude even when the model improvement setting is on. Turning the setting off stops use of both new and previously stored chats in future training runs, but Anthropic is explicit that data already included in training that has started, or in models already trained, cannot be withdrawn.

Consumer retention, per Anthropic's retention article: a deleted conversation is removed from chat history immediately and from back-end storage within 30 days. If model improvement is enabled, data may be retained de-identified for up to five years in model training pipelines, applying only to new or resumed chats after the setting was enabled. Content flagged by automated trust and safety systems as violating the Usage Policy is retained up to two years, with classification scores up to seven years. Feedback submitted through the thumbs up or down button is stored for five years, de-linked from the user ID.

**Commercial (Claude for Work, Anthropic API, Claude Gov).** "By default, we will not use your inputs or outputs from our commercial products to train our models." The stated exceptions are explicitly reporting feedback or bugs, or otherwise choosing to allow it. Team and Enterprise owners can disable the feedback button organization-wide through a "Rate chats" setting under Organization settings, Data and Privacy.

Commercial retention: for Anthropic API users, inputs and outputs are automatically deleted from the back end within 30 days of receipt or generation, with four documented exceptions: services with longer retention under the customer's control such as the Files API, an agreed zero data retention arrangement, retention needed to enforce the Usage Policy, and legal compliance. Products that save conversations, such as Claude for Work and the Console, retain chats in the product to provide continuity, with the same immediate-removal and 30-day back-end deletion behavior on user deletion. Incognito chats are deleted within 30 days unless flagged. Usage Policy violations follow the same two-year and seven-year windows as consumer. Anthropic also notes that for what it calls Covered Models it requires limited data retention and review as part of its safety work, documented separately.

**Zero data retention.** Anthropic's ZDR article (dated June 9, 2026) describes arrangements available to some Claude Platform (API) and Claude Code for Enterprise customers, subject to Anthropic's approval, under which Anthropic does not store inputs or outputs except where needed to comply with law or combat misuse or harm. Two boundaries are stated clearly: Anthropic "still retains User Safety classifier results in order to enforce our Usage Policy," and ZDR applies only to eligible Anthropic APIs, products using a commercial organization API key including Claude Code accessed via the API, and Claude Code for Enterprise plans. Requests are reviewed and applied per organization, and Claude Platform customers can confirm ZDR is active under Settings, Privacy Controls, Data retention period.

**Regional data residency.** Anthropic's documentation reviewed for this chapter does not describe a customer-configurable regional data residency control comparable to OpenAI's per-project regions or Google Cloud's location settings. That absence is not evidence that no such option exists; verify directly through Anthropic's Trust Center, Commercial Terms, and Data Processing Addendum, all of which the retention articles point to, before relying on a residency assumption.

### 5.4 Google

**Gemini consumer apps.** Google's Gemini Apps privacy documentation is the governing page, and its central mechanism is the Keep Activity setting.

With Keep Activity on, Google states it uses your activity "to provide, develop, and improve its services (including training generative AI models), as well as to protect Google, its users, and the public with the help of human reviewers." Human review is documented explicitly: a subset of chats is reviewed by human reviewers including trained service providers, the reviewed data is disconnected from the Google Account, and it is retained for up to three years, notably "not deleted when you delete your activity." The page's own instruction to users is the sharpest sentence in any of the documents surveyed for this chapter: "Please don't enter confidential information that you wouldn't want a reviewer to see or Google to use to improve our services, including machine-learning technologies."

With Keep Activity off, future chats do not appear in Activity and are not used to train Google's AI models unless you submit feedback, but they are still saved with your account for 72 hours so that Gemini can respond, process feedback, and protect Google and its users. Temporary chats are likewise not used to train Google's AI models.

Retention controls: the Gemini Apps Activity auto-delete period defaults to 18 months and can be changed to 3 months, 36 months, or no auto-delete, and chats can be deleted manually at any time. Google notes it retains some data longer where necessary for legitimate business or legal purposes. Separately, audio and Gemini Live video and screenshares "aren't used to improve Google services by default," a distinct opt-in from Keep Activity. Turning off Keep Activity or deleting Gemini Apps activity does not delete data held by other Google services.

One caveat on defaults: the documentation reviewed describes both Keep Activity states and the 18-month default auto-delete period, but does not, in the text reviewed, state a single global default value for the Keep Activity toggle itself across all account types and regions. Check the setting in your own account.

**Google Cloud (Vertex AI generative AI, presented in current documentation as the Gemini Enterprise Agent Platform).** The training position is a contractual commitment rather than a setting: "As outlined in 'Training Restriction' in the Service Terms section of the Service Specific Terms, Google won't use your data to train or fine-tune any AI/ML models without your prior permission or instruction," and this "applies to all managed models," including pre-GA ones. Data processing is governed by Google's Cloud Data Processing Addendum.

Google's zero data retention documentation is the most explicit of the four vendors about ZDR being a configuration outcome rather than a default state. To achieve it, a customer must address each of these:

| Retention source | Documented behavior | Action required for ZDR |
| --- | --- | --- |
| Prompt logging for abuse monitoring (Google models) | Google may log prompts to detect abuse and policy violations, for customers governed by the Google Cloud Platform Terms of Service | Request an abuse monitoring exception |
| Prompt and response logging for Advanced AI models | Additional logging per the Advanced AI Safety Addendum | Google states ZDR "may not be possible when using some Advanced AI features"; contact the account team |
| Grounding with Google Search | Logs containing queries derived from end-user prompts and contextual data are stored up to 3 days for debugging, with "no way to disable" it | Use Web Grounding for Enterprise instead |
| Grounding with Google Maps | Prompts, contextual information, and generated output stored 30 days, no way to disable | No ZDR-compatible option documented for this feature |
| Request-response logging to BigQuery | Disabled by default; per-model, per-project setting | Do not enable it |
| Session resumption for Gemini Live API | Disabled by default; when enabled, caches text, video, and audio prompt data and outputs up to 24 hours | Do not enable it |
| In-memory data caching | On by default; in-memory only, project-isolated, 24-hour TTL, honors data residency for the selected location | Google states this "does not violate zero data retention"; can be disabled per project via the `cacheConfig` API |

Google also documents an agent-product example of the same pattern: CodeMender stores encrypted session state, including target source snippets and diffs, for up to seven days from session creation, clearing source content within seconds of a session reaching a terminal state and deleting the record at the seven-day TTL, with customer-initiated deletion available earlier.

The general lesson generalizes past Google: ZDR is a property of a configured deployment, not of a vendor. Grounding, caching, logging, and stateful conveniences each create retention, and each has to be handled individually.

### 5.5 Microsoft

Microsoft's story splits three ways, and the differences between the three are larger than the differences between vendors elsewhere.

**Consumer Copilot (personal Microsoft Account).** Microsoft's Copilot privacy FAQ states that "except for certain categories of users or users who have opted out, Microsoft uses data from Bing, MSN, Copilot, and interactions with ads on Microsoft for AI training," and that this "includes de-identified search and news data, interactions with ads, and your voice and conversation activity with Copilot, including the images or files you upload." This is therefore an opt-out regime for signed-in consumer users who are not otherwise excluded.

The controls are two toggles, "Training on conversation activity" and "Training on voice conversations," reachable through the profile icon, then Privacy, on copilot.com, Windows, macOS, and mobile. Microsoft states that opting out "will exclude your future conversation activities from being used for training these AI models," and, importantly, that the setting "will not exclude your conversations from being used for other general product or system improvements nor from use for advertising, digital safety, security, and compliance purposes."

Documented exclusions from training: users under 18 who are signed in, users who have opted out, and users in Brazil, China (excluding Hong Kong), Israel, Nigeria, South Korea, and Vietnam, where Microsoft states no user data will be used for generative AI model training "until further notice." Also excluded are Copilot users on organizational Entra ID accounts and Microsoft 365 consumer users or Copilot conversations inside Microsoft 365 consumer apps such as Word, Excel, PowerPoint, and Outlook, who "will not see this setting."

Retention: "By default, we store conversation activity for 18 months," with individual or full history deletion available at any time. Files shared with Copilot are stored up to 18 months and then automatically deleted. Microsoft also states it removes identifying information such as names, phone numbers, device or account identifiers, sensitive personal data, physical addresses, and email addresses before training AI models.

**Microsoft 365 Copilot (work or school account).** The commitment is direct: "Prompts, responses, and data accessed through Microsoft Graph aren't used to train foundation LLMs, including those used by Microsoft 365 Copilot." Optional customer feedback may be used to improve the product but is not used to train the foundation models, and admins can manage feedback through admin controls.

Interaction content is stored: prompts, responses, and citations form the user's Copilot activity history, processed and stored in alignment with the organization's other Microsoft 365 content, encrypted at rest, and not used for foundation model training. Admins can view and manage that data with Content Search or Microsoft Purview, including setting Purview retention policies for Copilot chat interactions. This is the important structural point for enterprises: retention here is largely your tenant's policy decision, not a vendor-fixed window.

Residency: Microsoft 365 Copilot is covered by the data residency commitments in the Microsoft Product Terms and Data Protection Addendum, added as a covered workload on March 1, 2024, and included in Advanced Data Residency and Multi-Geo offerings from that date. For EU users, Microsoft 365 Copilot is an EU Data Boundary service, with EU traffic staying within the boundary while worldwide traffic may be sent to the EU and other regions for LLM processing; customers outside the EU may have queries processed in the US, EU, or other regions. One specific carve-out is documented: "Models provided by Anthropic as a subprocessor are currently excluded from the EU Data Boundary."

**Azure OpenAI and Models sold by Azure in Microsoft Foundry.** The strongest and most specific set of commitments of any document surveyed. Microsoft states that your prompts, completions, embeddings, and training data are not available to other customers, are not available to OpenAI or other model providers, are not used by those providers to improve their models or services, are not used to train any generative AI foundation model without your permission or instruction, and that customer data, prompts, and completions are not used to improve Microsoft or third-party products without explicit permission or instruction. Fine-tuned models are available exclusively to the customer that created them. The models are described as stateless: no prompts or completions are stored in the model, and they are not used to train, retrain, or improve base models.

Abuse monitoring is the retention surface to understand. Prompts and completions are evaluated in real time, and the abuse monitoring system may select a sample of flagged content for review. Review is conducted by automated means including LLMs by default, with human review as necessary; content that undergoes automated review "is not stored by the system or used to train the AI models or other systems." The abuse monitoring data store used for human review is logically separated per customer resource, located in the geography where the customer's Foundry resource is deployed, and human reviewers are authorized Microsoft employees using Secure Access Workstations with just-in-time approval, located in the European Economic Area for models deployed there. Eligible customers meeting Limited Access criteria can apply for modified abuse monitoring, in which case the storage and human review process is not performed, though automated review may continue; Microsoft notes that detection of potential abuse "may be less accurate" in that configuration. Customers approved for it can verify the state through a `ContentLogging` capability value of false in the Azure portal or CLI. Notably, neither the data privacy page nor the abuse monitoring page reviewed for this chapter states a specific retention window in days for abuse monitoring data; if that number matters to you, obtain it contractually rather than inferring it from another vendor's 30-day figure.

Stored data for stateful features (Files API, vector stores, Responses API, Assistants threads, stored completions) is held at rest in the Foundry resource in the customer's tenant within the same geography, encrypted with AES-256 by default with a customer-managed key option, and deletable by the customer at any time. Preview features may not support all of those conditions.

Residency: prompts and responses are processed within the customer-specified geography except for Global and DataZone deployment types. Global deployments may process in any geography where the model is deployed; DataZone deployments process within the specified data zone, so a DataZone deployment in an EU member nation may process in that or any other EU member nation. For both, data stored at rest, including the abuse monitoring store, remains in the customer-designated geography.

Microsoft also documents a defensive product relevant to section 1: Prompt Shields in Azure AI Content Safety, which classifies both user prompt attacks and document attacks, with the limitations noted earlier.

### 5.6 Cross-vendor summary

Read this table as a map of where to look, not as a substitute for the subsections above. Every cell is sourced there.

| | Consumer product | API / commercial tier |
| --- | --- | --- |
| OpenAI | ChatGPT personal (Free/Plus/Pro): training on by default, opt out via Settings, Data Controls; Business/Enterprise/Edu and API: training off by default, opt-in only | API: not used for training since March 1, 2023 unless you opt in; abuse logs 30 days by default; ZDR and MAM by approval; per-project data residency |
| Anthropic | Chats used to improve models where the privacy setting allows it, plus safety-flagged content and explicit opt-ins; incognito excluded; deletions purge back end within 30 days | Not used for training by default (Claude for Work, API, Claude Gov); API inputs and outputs deleted within 30 days; ZDR by approval for eligible APIs and Claude Code Enterprise |
| Google | Keep Activity on means activity is used to develop and improve services including training generative AI models, with human review retained up to 3 years; off means 72-hour retention and no training use absent feedback; 18-month default auto-delete | Google Cloud: contractual training restriction absent permission or instruction; ZDR achievable only after addressing abuse logging, grounding logs, request logging, session resumption, and caching individually |
| Microsoft | Consumer Copilot: used for training unless you opt out or fall in an excluded category; 18-month default conversation retention | M365 Copilot: prompts, responses, and Graph data not used to train foundation LLMs; tenant-controlled retention via Purview. Azure Foundry: not used to train foundation models without permission; abuse monitoring with modified option |

Three patterns are worth extracting.

1. **The consumer-versus-commercial split is consistently real but differently implemented.** Every commercial or API document verified here, across all four vendors, states no training use by default or absent permission. For the three vendors whose consumer products are verified here (Anthropic, Google, Microsoft), training use is contingent on a user-facing setting, but the mechanism differs: an opt-out toggle at Microsoft, an activity setting at Google, a model-improvement setting at Anthropic. Do not infer a specific mechanism at one vendor from another vendor's mechanism.
2. **"Not used for training" is not "not retained."** Every vendor retains something for abuse monitoring, safety classification, or legal compliance, and several retain considerably more for stateful conveniences you opted into without thinking of them as retention decisions.
3. **Human review is a real and separately documented exposure.** Google states reviewed consumer chats are kept up to three years even after you delete your activity. Microsoft describes authorized-employee review of flagged Azure content under just-in-time approval. Anthropic retains feedback conversations for five years. "Nobody reads it" is not what any of these documents say.

### 5.7 Verify before you rely

Policies in this area change on the order of months. When you need current ground truth, go to these categories rather than to a saved link:

- The provider's **trust center or trust portal**, for certifications, subprocessors, and security documentation.
- The **Data Processing Addendum** or equivalent, for the contractual processing terms including residency commitments.
- The **commercial, business, or enterprise terms**, for training use and confidentiality obligations on paid tiers.
- The **product-specific data and privacy page** for your exact tier, since consumer, team, enterprise, and API tiers routinely differ.
- Your own **in-product settings** page, since several controls discussed above are per-account or per-organization and their defaults vary by region, age, and account type.

---

## 6. Practical Guidance

### 6.1 For end users

**Assume anything you paste may be read by a human or retained longer than the chat window suggests.** Google's own consumer documentation asks you not to enter confidential information you would not want a reviewer to see. That is the correct default posture for any consumer chat product.

Do not paste into a consumer chat tool:

- Credentials, API keys, tokens, private keys, or connection strings. If you already did, rotate them; deletion of the conversation does not undo exposure.
- Personal data about other people, especially health, financial, biometric, or location data, which you likely have no authority to disclose.
- Material covered by an NDA, customer contract, or regulatory regime (PHI, cardholder data, export-controlled material) unless you are using a tier your organization has approved for it under written terms.
- Unreleased business material such as source code, pricing, deal terms, or roadmaps, unless the same condition holds.
- Anything you would not want surfaced by a future model that memorized it. Carlini et al. demonstrated verbatim extraction of training data, including PII, from GPT-2, a publicly released model trained on web scrapes.

Check and set your training and retention controls, and re-check after major product updates:

| Product | Where to look | What you are setting |
| --- | --- | --- |
| Claude consumer | Settings, Privacy, "Help Improve Claude"; incognito chats for one-offs | Whether new and stored chats feed future training; 5-year de-identified training-pipeline retention applies when on |
| Gemini apps | Gemini Apps Activity: Keep Activity, auto-delete period, audio and Live video setting; temporary chats | Whether activity trains models and is human-reviewed; auto-delete window (18-month default) |
| Consumer Copilot | Profile, Privacy: "Training on conversation activity" and "Training on voice conversations" | Whether future conversations train models; note 18-month default conversation retention and that opt-out does not cover product improvement, ads, safety, security, or compliance uses |
| ChatGPT | Settings, Data Controls, "Improve the model for everyone" toggle (personal plans); Temporary Chat for a one-off excluded conversation | Personal plans: on by default, opt out any time; Business/Enterprise/Edu: off by default, opt-in only |

Four more habits that matter more than settings:

- **Prefer the tier that matches the sensitivity.** If work data is involved, use the account and tier your employer has terms for. Consumer and enterprise tiers of the same brand can have materially different data terms, as the tables above show.
- **Turning training off is not retroactive.** Anthropic states data already in a started training run or a trained model stays there. Microsoft's opt-out applies to future conversations. Google keeps human-reviewed chats up to three years regardless of your deletions.
- **Treat browsing, file upload, and connectors as risk-increasing.** The moment an assistant reads attacker-influenceable content while holding access to your data, section 1 applies to you personally, not just to developers.
- **Be suspicious of unexpected assistant behavior after it read something.** An assistant that suddenly wants to fetch an odd URL, email someone, or summarize your inbox after processing an external document is exhibiting the signature of indirect injection.

### 6.2 For builders

**Design so that a successful injection is survivable.** Assume the model will at some point follow instructions from content you do not control. Then ask what that costs you. If the answer is unbounded, the architecture is the problem, not the prompt.

Least privilege, concretely:

- Give each tool the narrowest capability that satisfies the use case; do not ship a shell or a generic fetch tool where a specific operation would do (OWASP LLM06).
- Scope credentials per user, not per application, and run downstream actions in the requesting user's authorization context with minimum scopes.
- Enforce authorization in the downstream system, not in the model or the prompt. Complete mediation means every request through a tool is checked against policy independently of what the model decided.
- Separate read paths from write paths, and separate high-sensitivity data access from any tool with external egress. Breaking up the lethal trifecta is the highest-leverage architectural move available.
- Remove tools that are no longer used. OWASP specifically calls out abandoned extensions left reachable by the agent.

Third-party components, before installation:

- Review the source, the tool manifest, and the requested scopes; use the checklist in section 3.4.
- Prefer first-party servers operated by the service being integrated, per OpenAI's guidance; do extra diligence on aggregators that proxy your credentials.
- Pin versions and re-review on update, since tool behavior can change after your review (OpenAI documents exactly this risk).
- Remember that data sent to a third-party MCP server is governed by that server's retention terms, not your model provider's, which also means it may sit outside your ZDR or residency posture.
- Maintain an inventory of models, tools, servers, and datasets with provenance and integrity verification (OWASP LLM03: signing, hashes, SBOM or AI BOM).

Logging and audit:

- Log tool calls with their arguments, the identity they executed as, and the decision that authorized them. OWASP is explicit that logging and monitoring do not prevent Excessive Agency but do limit damage and shorten detection time.
- Log what you send to third-party servers specifically, and review it periodically against expectations, as OpenAI recommends.
- Retain enough context to reconstruct why an action happened, including which retrieved content was in scope, since that is the evidence you will need to identify an injection source.
- Rate-limit high-impact operations so that a compromised run cannot complete thousands of actions before anyone notices.
- Be deliberate about what your own logs retain. Prompt and tool-call logs are a new copy of sensitive data with its own retention and access-control obligations, and they can quietly undo a ZDR posture at the provider level.

Human confirmation gates:

- Require approval for actions that are irreversible, externally visible, financially material, or that move data outside a trust boundary: sending messages, deleting data, changing permissions, spending money, publishing, or pushing code.
- Put the gate in the operation that performs the action, not in an earlier layer the model can route around (OWASP's LLM06 guidance).
- Show the user what will happen with enough fidelity to judge it: the exact command, recipient, or diff. The MCP specification requires exactly this for one-click local server installation, including the untruncated command.
- Design against approval fatigue. Reserve prompts for genuinely consequential actions, batch what is safe to batch, and make the default for anything unmatched a prompt rather than an allow (fail-closed, as Claude Code documents).
- Combine gates with sandboxing and egress restriction so that the approved action is also a contained one.

Testing and operations:

- Red-team your own agent with indirect injection through every content channel it consumes: documents, web pages, tool outputs, retrieved chunks, images, and peer-agent messages. OWASP recommends treating the model as an untrusted user when testing trust boundaries.
- Re-test after model upgrades, prompt changes, and new tool integrations. Prior results do not carry over.
- Adopt a shared vocabulary for findings. NIST AI 100-2 for adversarial ML terminology, OWASP's LLM Top 10 for application risks, and OWASP's Top 10 for Agentic Applications for agent-specific ones.
- Treat filters and shields as depth, not as the boundary. Microsoft's own documentation for Prompt Shields advises additional validation layers because it may miss attacks and may flag legitimate prompts.

For where these settings live in configuration files, how to keep them under version control, and general config hygiene, see [Appendix A](appendices/appendix-a-plugins-and-config-paradigms.md). For the vendor and product landscape referenced throughout section 5, see [Appendix B](appendices/appendix-b-brands-and-providers.md). Terms used here without definition are in the glossary, [Appendix D](appendices/appendix-d-glossary-quick-reference.md).

---

## References

### Official Documentation

- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/llm-top-10/) - OWASP Gen AI Security Project; index of the ten current LLM application risk categories.
- [LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) - OWASP Gen AI Security Project; direct and indirect injection definitions, mitigation list, and the nine example attack scenarios cited in section 1.
- [LLM02:2025 Sensitive Information Disclosure](https://genai.owasp.org/llmrisk/llm022025-sensitive-information-disclosure/) - OWASP Gen AI Security Project; disclosure risks, model inversion and extraction references including the Proof Pudding case, and the limits of system-prompt restrictions.
- [LLM03:2025 Supply Chain](https://genai.owasp.org/llmrisk/llm032025-supply-chain/) - OWASP Gen AI Security Project; third-party model and component risk, weak provenance, unclear terms as a data-use risk, and SBOM-based controls.
- [LLM04:2025 Data and Model Poisoning](https://genai.owasp.org/llmrisk/llm042025-data-and-model-poisoning/) - OWASP Gen AI Security Project; poisoning across pre-training, fine-tuning, and embedding stages, backdoor detectability, and malicious pickling.
- [LLM06:2025 Excessive Agency](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/) - OWASP Gen AI Security Project; excessive functionality, permissions, and autonomy, plus the prevention list used in section 3.3.
- [OWASP Top 10 for Agentic Applications for 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) - OWASP Gen AI Security Project; scope and provenance of the agent-specific risk framework published December 2025.
- [Security Best Practices](https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices) - Model Context Protocol specification; confused deputy, token passthrough, session hijacking, local server execution consent, OAuth URL validation, and scope minimization requirements.
- [AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework) - NIST; status of the AI RMF and its generative AI profile.
- [NIST AI 100-2 E2025, Adversarial Machine Learning: A Taxonomy and Terminology of Attacks and Mitigations](https://csrc.nist.gov/pubs/ai/100/2/e2025/final) - NIST; current standard vocabulary for poisoning, evasion, and privacy attacks.
- [NIST AI 100-2 E2023, Adversarial Machine Learning: A Taxonomy and Terminology of Attacks and Mitigations](https://csrc.nist.gov/pubs/ai/100/2/e2023/final) - NIST; the prior edition, useful when reconciling older citations.
- [NIST AI 600-1, Artificial Intelligence Risk Management Framework: Generative Artificial Intelligence Profile](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf) - NIST; the Information Security and Data Privacy risk categories, including direct and indirect prompt injection and data memorization.
- [CVE-2025-32711](https://nvd.nist.gov/vuln/detail/CVE-2025-32711) - NIST National Vulnerability Database; AI command injection in Microsoft 365 Copilot enabling information disclosure, with vendor and NVD severity scores.
- [Data controls in the OpenAI platform](https://developers.openai.com/api/docs/guides/your-data) - OpenAI; API training position, per-endpoint abuse-monitoring and application-state retention, Zero Data Retention, Modified Abuse Monitoring, Eyes Off, Safety Retention, and data residency regions.
- [MCP and connectors](https://developers.openai.com/api/docs/guides/tools-connectors-mcp) - OpenAI; risks and safety guidance for remote MCP servers, default tool-call approval, and third-party retention implications.
- [OpenAI Trust Portal](https://trust.openai.com/) - OpenAI; SOC 2 Type 2 and ISO 27001, 27017, 27018, and 27701 coverage for the API Platform, ChatGPT Enterprise, ChatGPT Edu, and ChatGPT Team.
- [What if I want to keep my history on but disable model training?](https://help.openai.com/en/articles/8983130) - OpenAI Help Center; the personal-workspace default of data sharing enabled, the Business/Enterprise/Edu/API default of training disabled, and the Data Controls opt-out location.
- [How your data is used to improve model performance](https://openai.com/policies/how-your-data-is-used-to-improve-model-performance/) - OpenAI; the general consumer-versus-business training policy statement and Temporary Chat's exclusion from training.
- [How ChatGPT learns about the world while protecting privacy](https://openai.com/index/how-chatgpt-protects-privacy/) - OpenAI; the "Improve the model for everyone" toggle mechanics and Temporary Chat's 30-day safety retention window before deletion.
- [Is my data used for model training? (consumer products)](https://privacy.anthropic.com/en/articles/10023580-is-my-data-used-for-model-training) - Anthropic; the three cases in which consumer chats are used for model improvement, connector and MCP exclusions, incognito behavior, and feedback handling.
- [Is my data used for model training? (commercial products)](https://privacy.anthropic.com/en/articles/7996868-is-my-data-used-for-model-training) - Anthropic; the default no-training position for Claude for Work, the Anthropic API, and Claude Gov, plus organization-level feedback controls.
- [How do I change my model improvement privacy settings?](https://privacy.anthropic.com/en/articles/12109829-how-do-i-change-my-model-improvement-privacy-settings) - Anthropic; location of the consumer model-training toggle and what turning it off does and does not undo.
- [How long do you store my data? (consumer)](https://privacy.anthropic.com/en/articles/10023548-how-long-do-you-store-my-data) - Anthropic; 30-day back-end deletion, 5-year de-identified training-pipeline retention, and the 2-year and 7-year Usage Policy windows.
- [How long do you store my organization's data? (commercial)](https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data) - Anthropic; 30-day API deletion with its four documented exceptions, product retention for saved conversations, and Covered Models.
- [I have a zero data retention agreement with Anthropic. What products does it apply to?](https://privacy.anthropic.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to) - Anthropic; ZDR scope, eligibility, retained safety classifier results, and per-organization application.
- [Claude Code security](https://docs.claude.com/en/docs/claude-code/security) - Anthropic; permission-based architecture, sandboxing, isolated web-fetch context, trust verification, and the statement that Anthropic does not security-audit MCP servers.
- [Gemini Apps Privacy Hub](https://support.google.com/gemini/answer/13594961) - Google; Keep Activity behavior, human review and its 3-year retention, 72-hour retention when off, temporary chats, and the 18-month default auto-delete.
- [Gemini Enterprise Agent Platform and zero data retention](https://cloud.google.com/vertex-ai/generative-ai/docs/data-governance) - Google Cloud; the contractual training restriction and the per-feature actions required to reach zero data retention.
- [Data, privacy, and security for Models sold by Azure in Microsoft Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/responsible-ai/openai/data-privacy) - Microsoft; the training and isolation commitments, stateful-feature storage, abuse monitoring data handling, and Global and DataZone processing locations.
- [Abuse monitoring](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/concepts/abuse-monitoring) - Microsoft; content classification, abuse pattern capture, automated versus human review, and modified abuse monitoring eligibility.
- [Prompt Shields in Azure AI Content Safety](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/concepts/jailbreak-detection) - Microsoft; the user-prompt versus document attack taxonomy, jailbreak technique categories, and the stated detection limitations.
- [Data, privacy, and security for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-privacy) - Microsoft; no foundation-model training on prompts, responses, or Graph data, Purview-managed retention, EU Data Boundary status, and the Anthropic subprocessor exclusion.
- [Privacy FAQ for Microsoft Copilot](https://support.microsoft.com/en-us/microsoft-copilot/privacy-faq-for-microsoft-copilot) - Microsoft; consumer training use and its exclusions, 18-month default conversation retention, and the Microsoft 365 boundary.
- [Microsoft Copilot privacy controls](https://support.microsoft.com/en-US/microsoft-copilot/microsoft-copilot-privacy-controls) - Microsoft; location of the consumer training toggles and the scope limits of opting out.

### Research

- [Not what you've signed up for: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection](https://arxiv.org/abs/2302.12173) - Greshake et al. (arXiv); the foundational indirect prompt injection paper, including demonstrations against production systems.
- [Universal and Transferable Adversarial Attacks on Aligned Language Models](https://arxiv.org/abs/2307.15043) - Zou et al. (arXiv); automated adversarial suffix generation and transfer to black-box production models.
- [Extracting Training Data from Large Language Models](https://arxiv.org/abs/2012.07805) - Carlini et al. (arXiv); verbatim extraction of training data including PII, with larger models more vulnerable.
- [Membership Inference Attacks Against Machine Learning Models](https://arxiv.org/abs/1610.05820) - Shokri et al. (arXiv); the canonical membership inference formulation and its evaluation against commercial ML services.
- [Stealing Machine Learning Models via Prediction APIs](https://arxiv.org/abs/1609.02943) - Tramèr et al. (arXiv); black-box model extraction, including why withholding confidence values is insufficient.
- [Poisoning Web-Scale Training Datasets is Practical](https://arxiv.org/abs/2302.10149) - Carlini et al. (arXiv); split-view and frontrunning poisoning, with cost estimates against real datasets.
- [Defeating Prompt Injections by Design](https://arxiv.org/abs/2503.18813) - Debenedetti et al. (arXiv); CaMeL's control-and-data-flow separation and capability-based tool policies, with the measured utility cost.
- [Design Patterns for Securing LLM Agents against Prompt Injections](https://arxiv.org/abs/2506.08837) - Beurer-Kellner et al. (arXiv); principled agent design patterns with provable injection resistance and their security-utility trade-offs.

### Further Reading

- [The lethal trifecta for AI agents: private data, untrusted content, and external communication](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) - Simon Willison; the practitioner framing used in section 1.2, from the author who coined the term prompt injection, including a catalogue of vendor incidents and the jailbreak-versus-injection distinction.
