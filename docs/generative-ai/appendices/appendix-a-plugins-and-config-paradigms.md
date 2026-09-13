---
audience: human
created: 2026-07-28
updated: 2026-07-28
---

# Appendix A: Plugins, Extensions, and Configuration Paradigms

A practical companion to [Chapter 4](../04-agents-subagents-harnesses-and-tools.md) (agents,
subagents, harnesses, and tools), which covers what skills, MCP servers, and plugins are
conceptually. Hooks, event-triggered scripts that run at defined points in an agent's lifecycle
(for example, before a tool call or after a session ends) rather than being invoked by the model
itself, are introduced here rather than in Chapter 4, since they are more of a configuration
mechanism than an agentic concept. This appendix is the applied reference:
which specific integrations show up in day-to-day use, and how the underlying systems are actually
configured across the major products, as of mid-2026.

## In short

- AI coding harnesses (Claude Code, Cursor, GitHub Copilot) converge on the same four building
  blocks: on-demand instruction packages (skills/custom commands), deterministic automation
  (hooks), external tool/data access (MCP servers), and an always-loaded project instructions
  file. The file names, exact triggers, and packaging differ by vendor.
- The Model Context Protocol project maintains a small set of official reference servers
  (Everything, Fetch, Filesystem, Git, Memory, Sequential Thinking, Time). A much larger
  population of vendor and community servers lives outside that repository, in the official MCP
  Registry and in each client's own marketplace.
- ChatGPT's Custom GPTs (with Actions) and Claude's connectors both give a general chat assistant
  the same two things: a curated instructions and knowledge layer, and a tool-calling bridge to
  external systems. The mechanics (OpenAPI-based Actions vs. MCP-based connectors) differ.
- Two configuration paradigms dominate: always-on context files read at the start of every session
  (CLAUDE.md, AGENTS.md, `.cursor/rules`, `copilot-instructions.md`) and on-demand packages loaded
  only when relevant (skills, covered conceptually in
  [Chapter 4](../04-agents-subagents-harnesses-and-tools.md)).
- Regardless of vendor file format, an MCP server configuration always reduces to the same three
  ingredients: an identifier, a way to reach the server (a local command or a remote URL and
  transport), and credentials.
- Every plugin, extension, or MCP server is third-party code with tool-calling and often network
  access. Vet it accordingly; see [Chapter 6](../06-security-privacy-and-data.md) for the security
  posture this implies.

## 1. Plugins, extensions, and integrations in practice

### 1.1 AI coding assistants and harnesses

The three most widely documented coding harnesses expose comparable surfaces, described here
neutrally and grounded in each vendor's own documentation.

#### Claude Code

| Mechanism | What it does | Configuration surface |
| --- | --- | --- |
| Skills (custom commands) | Reusable, invokable procedures. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create a `/deploy` command; skills add an optional directory of supporting files and frontmatter that controls who can invoke them. | `~/.claude/skills/` (personal), `.claude/skills/` (project, including nested per-package directories), or a plugin's `skills/` directory |
| Hooks | Shell commands, HTTP webhooks, LLM-evaluated prompts, subagent tasks, or direct MCP tool calls run before or after lifecycle events such as `PreToolUse`, `PostToolUse`, or `SessionStart`. | JSON hook definitions in settings, or bundled inside a plugin |
| MCP servers | Connects Claude Code to external data sources and tools (tickets, docs, chat, custom APIs). | Added with `claude mcp add` or defined directly in configuration; also distributable via a plugin's `.mcp.json` |
| CLAUDE.md | Persistent, human-authored project instructions loaded in full at the start of every session: coding standards, architecture decisions, preferred libraries, review checklists. | `./CLAUDE.md` or `./.claude/CLAUDE.md` (project, shared via git), `~/.claude/CLAUDE.md` (personal), plus a managed policy scope and a `CLAUDE.local.md` for uncommitted personal notes |
| Plugins | Bundle skills, subagents, hooks, MCP servers, LSP servers, and monitors into one installable, versioned unit, distributed through marketplaces. | `.claude-plugin/plugin.json` manifest at the plugin root; marketplaces are `.claude-plugin/marketplace.json` files added with `/plugin marketplace add` and installed with `/plugin install` |

Claude Code's skill format follows the Agent Skills open standard, which several tools implement,
rather than being purely proprietary. The official plugin marketplace
(`anthropics/claude-plugins-official`) is added automatically on first run; a community marketplace
and self-hosted marketplaces are also supported through the same `/plugin marketplace add` command,
accepting GitHub repositories, generic git URLs, local paths, or direct URLs to a `marketplace.json`
file.

#### Cursor

| Mechanism | What it does | Configuration surface |
| --- | --- | --- |
| Rules | Persistent, version-controlled instructions. Frontmatter fields (`alwaysApply`, `globs`, `description`) produce four activation modes: Always Apply, Auto Attached (by file glob), Agent Requested (by description relevance), and Manual (only when `@`-mentioned). | `.cursor/rules/*.mdc` files; team/enterprise plans can also push managed rules from a dashboard, with precedence Team Rules, then Project Rules, then User Rules |
| Skills | Specialized, on-demand workflows and domain knowledge, structurally identical to the Agent Skills format Claude Code uses. | `.cursor/skills/` or `.agents/skills/` (project, including nested per-package directories), `~/.cursor/skills/` or `~/.agents/skills/` (global); for compatibility, Cursor also reads `.claude/skills/` and `.codex/skills/` |
| Hooks | Spawned processes communicating over stdio in JSON, observing or blocking agent-loop, Tab-completion, and workspace-lifecycle events (`sessionStart`, `preToolUse`, `beforeShellExecution`, `beforeMCPExecution`, `afterFileEdit`, and others). Cursor can also load hooks written for Claude Code. | `.cursor/hooks.json` (project) or `~/.cursor/hooks.json` (user); cloud agents run project- and team-level command hooks but not user-level ones |
| MCP servers | Connects Cursor's agent to external tools and data sources, either as locally spawned processes or remote endpoints. | `.cursor/mcp.json` (project, git-committed) and `~/.cursor/mcp.json` (global), merged with project taking precedence on name conflicts; installable with one click from the Cursor Marketplace |

Cursor's rules and skills systems are deliberately split by loading behavior: rules are meant for
what the agent should always know, and cost context on every turn, while skills are loaded
dynamically and only spend context when actually invoked.

#### GitHub Copilot

| Mechanism | What it does | Configuration surface |
| --- | --- | --- |
| Custom instructions | Natural-language, markdown guidance for Copilot Chat, code review, and the cloud coding agent. | Repository-wide: `.github/copilot-instructions.md`. Path-scoped: `.github/instructions/*.instructions.md`, with an `applyTo` glob in YAML frontmatter. User-level (Copilot CLI): `$HOME/.copilot/copilot-instructions.md` and `$HOME/.copilot/instructions/**/*.instructions.md` |
| Agent file interoperability | The Copilot cloud agent and code review additionally read `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md` files as agent instructions, alongside the Copilot-specific files above. | Same repository locations as those files' own conventions |
| MCP servers | Extends Copilot Chat, the cloud agent, and CLI with external tools and data. | VS Code: `.vscode/mcp.json`. Copilot CLI: `~/.copilot/mcp-config.json` (user) or project `.mcp.json`. GitHub.com repositories: an `mcpServers` JSON block configured in repository settings. Discoverable through the GitHub MCP Registry inside VS Code |

As of this writing, GitHub's public documentation does not describe a general-purpose,
deterministic hooks system comparable to Claude Code's or Cursor's; automation around Copilot is
instead typically built with GitHub Actions workflows that wrap the Copilot cloud agent or code
review.

### 1.2 MCP servers: a practical survey

The MCP steering group maintains a small, actively updated set of *reference* servers in the
`modelcontextprotocol/servers` repository. These exist to demonstrate protocol and SDK features,
not to be an exhaustive marketplace:

| Server | Problem class it solves |
| --- | --- |
| Everything | Reference and test server exposing prompts, resources, and tools; used to validate a new MCP client implementation |
| Fetch | Retrieves web content and converts it to markdown for efficient LLM consumption |
| Filesystem | Secure local file operations, with configurable allowed directories |
| Git | Reads, searches, and manipulates local git repository history and diffs |
| Memory | Knowledge-graph-based persistent memory across conversations |
| Sequential Thinking | Structured, reflective multi-step problem solving |
| Time | Time and timezone conversions |

A second group of servers that the same repository previously hosted, including GitHub, GitLab,
Google Drive, Google Maps, PostgreSQL, SQLite, Slack, Redis, Sentry, Puppeteer, Brave Search,
EverArt, and an AWS Knowledge Base retrieval connector, has been moved to an archived repository. The project's
own README is explicit that these are historical: for current, actively maintained servers
(including vendor-hosted equivalents, such as GitHub's own remote MCP server referenced in GitHub
Copilot's documentation, or Slack's server now maintained by a third party) it directs users to the
official MCP Registry rather than the reference repository.

By problem class, the ecosystem generally breaks down as:

- **Local development environment access**: filesystem and git servers, for reading and modifying
  code and repository history directly.
- **Live external data retrieval**: web fetch or browser-style servers, for pulling in content the
  model was not trained on.
- **Structured data access**: database connectors (Postgres, SQLite, and similar), for letting an
  agent query and reason over an organization's own data.
- **Team communication and collaboration**: chat and project-tracker connectors (Slack, issue
  trackers), for pulling in and acting on team context.
- **Cross-session memory**: knowledge-graph or file-backed memory servers, for persisting facts
  the model would otherwise lose at the end of a conversation.

For discovery beyond the reference set, the two most relevant surfaces are the official MCP
Registry (a vendor-neutral index of published servers) and each client's own curated
marketplace layered on top of it (for example, Cursor's Marketplace or GitHub's MCP Registry
integration in VS Code), which typically add one-click install and, in enterprise settings,
organization-level allowlisting.

### 1.3 General chat assistants

#### ChatGPT: Custom GPTs and Actions

A Custom GPT bundles several configuration elements into one shareable, purpose-built version of
ChatGPT:

- **Instructions**: define behavior, tone, and boundaries, applied to every conversation.
- **Knowledge**: uploaded reference files (documentation, handbooks, policies) the GPT can draw on
  when answering; OpenAI's own guidance is to use knowledge for reference material and put rules
  or workflow guidance in instructions instead.
- **Conversation starters** and selected built-in **capabilities** (for example, code
  interpreter/data analysis, image generation, or canvas).
- **Actions**: the tool-calling layer, described below.

GPT Actions let a Custom GPT call external RESTful APIs from natural language. The builder supplies
an OpenAPI schema describing the API, and the model uses function calling to decide which operation
is relevant and to generate the matching JSON request; the Custom GPT itself never sees raw
credentials beyond what's needed to complete the call. Authentication is configured per action as
none, an API key, or OAuth. A schema-level `x-openai-isConsequential` flag controls whether ChatGPT
must always prompt the user for confirmation before running an operation (the default for
non-`GET` operations) or can offer an "always allow" option (the default for `GET`). Production
constraints documented by OpenAI include a 45-second request timeout, TLS 1.2 or later, request and
response payloads under 100,000 characters each, and no custom headers.

A GPT's instructions, knowledge, and actions are the only persistent context it has: Custom GPTs do
not use ChatGPT's separate saved-memory or custom-instructions system, and each conversation with a
GPT starts fresh.

#### Claude: connectors

Claude's equivalent extension mechanism for its general chat surfaces (claude.ai, Claude Desktop,
Claude Mobile, and Cowork) is connectors, built on MCP rather than an OpenAPI/Actions model.
Directory connectors are pre-built integrations, some verified by Anthropic and others community
built, browsable from a connectors directory. Custom connectors let a user or an organization admin
point Claude at any remote MCP server by URL. Custom connectors are explicitly flagged as
potentially unverified: Claude reaches them from Anthropic's cloud infrastructure rather than the
local device, which matters for servers that sit behind a corporate firewall.

Authentication for connectors supports several types, most notably OAuth 2.0 with Dynamic Client
Registration or a Client ID Metadata Document (both supported out of the box), OAuth with
Anthropic-held or fully custom credentials (available on request), and, in beta, a static
request-header credential (an API key or bearer token) for servers that do not implement OAuth.
For building connectors, Anthropic documents the same MCP authorization specifications the broader
protocol uses and provides an interactive plugin for Claude Code that walks through building,
testing, and packaging a server.

## 2. Configuration paradigms

### 2.1 System prompts vs. project-level instruction files

A one-off system prompt solves a single conversation. It does not solve the recurring problem of a
team needing the same build commands, coding standards, and architectural context available to
every contributor's agent, every session, without being retyped or drifting out of sync. Project
instruction files exist to solve exactly that: a checked-in, versioned, human-and-agent-readable
file the harness loads automatically.

The most vendor-neutral answer to this problem is the AGENTS.md open specification. It defines no
schema and no required fields: it is standard markdown that an agent parses for relevant sections
(project overview, build and test commands, code style, security considerations, and similar).
Files are discovered by nearest-directory precedence, so a package inside a monorepo can override
its parent with more specific guidance. AGENTS.md originated from collaborative work across
several agent projects and is now stewarded by the Agentic AI Foundation under the Linux
Foundation; it is read by, among others, Cursor, GitHub Copilot's cloud agent and code review, and
Codex-family tools.

Several vendors also define their own file, either as an alternative or as a supplement:

| File | Primary reader | Notable characteristics |
| --- | --- | --- |
| `AGENTS.md` | Broad, cross-vendor (Cursor, Copilot cloud agent/code review, Codex-family tools, and others) | Open specification, no required schema, nearest-file precedence |
| `CLAUDE.md` | Claude Code | Four scopes (managed policy, user, project, local); read in full at every session start alongside a separate self-updating memory system (see 2.4) |
| `.cursor/rules/*.mdc` | Cursor | Frontmatter-driven activation modes (always, glob-scoped, description-scoped, manual), not plain markdown |
| `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md` | GitHub Copilot | Repository-wide plus glob-scoped path instructions via `applyTo` frontmatter |

GitHub's own documentation is a useful signal of where this is heading: its Copilot cloud agent and
code review features read AGENTS.md, CLAUDE.md, and GEMINI.md directly, in addition to Copilot's
own instruction files, rather than requiring a Copilot-specific duplicate.

**What makes an instructions file good** is less about format than about content. The AGENTS.md
project's own guidance is to provide precise, agent-focused instructions that complement (not
duplicate) a human-facing README: build steps, exact test commands, and conventions that would
clutter documentation aimed at people. In practice this means:

- Specific and verifiable over generic: an exact command a harness can run and check the exit code
  of, rather than a vague preference like "write clean code."
- Command-first, not narrative: state what to run, not a story about why the project exists.
- Scoped to what actually changes agent behavior: security gotchas, non-obvious build steps, and
  team conventions belong here; content already obvious from reading the code does not.
- Nested and overridden deliberately: a subproject's own instructions file should hold only what
  differs from the root, relying on precedence rather than repeating shared context.

### 2.2 Skills directories as a configuration paradigm

[Chapter 4](../04-agents-subagents-harnesses-and-tools.md) covers what a skill is conceptually: an
on-demand instruction package the agent loads only when relevant, rather than an always-in-context
rule. This section covers only how that
paradigm is configured and discovered in practice, which is now fairly consistent across harnesses:

- A skill is a directory containing a `SKILL.md` file (frontmatter plus markdown instructions),
  optionally alongside supporting scripts or reference files.
- Only the frontmatter (name and description) is loaded for every available skill at session
  start; the full body loads only when the skill is actually triggered, either because the model's
  relevance matching selects it based on the description, or because the user invokes it by name.
- Discovery happens across a small number of conventional locations that separate personal,
  project, and packaged (plugin) scope, with project-level directories typically auto-discovered
  from nested subdirectories as well, so a package inside a monorepo can ship its own skills.
- Claude Code's implementation follows the Agent Skills open standard, and Cursor's own skills
  system is structurally compatible with it; for cross-tool portability, Cursor additionally reads
  Claude's and Codex's skill directories directly, without requiring a copy.

| Harness | Personal/global location | Project location | Packaged/plugin location |
| --- | --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` | `<plugin>/skills/<name>/SKILL.md` |
| Cursor | `~/.cursor/skills/` or `~/.agents/skills/` (also reads `~/.claude/skills/`, `~/.codex/skills/`) | `.cursor/skills/` or `.agents/skills/` (also reads `.claude/skills/`, `.codex/skills/`) | Bundled with an installed plugin |

A practical consequence for configuration hygiene: because only the frontmatter costs context by
default, a large skill library is comparatively cheap, but only if descriptions are written so the
agent can tell when a skill actually applies. An always-on rules or instructions file does not get
this discount, which is the main reason to prefer a skill over an instructions-file addition for
anything that is not needed on every single turn.

### 2.3 MCP server configuration

Exact key names and file locations vary by client and change over time, so treat the following as
the conceptual shape rather than a specific vendor's schema. Nearly every MCP client configuration
reduces to a map of server names to connection details:

```json
{
  "mcpServers": {
    "local-example": {
      "command": "npx",
      "args": ["-y", "some-mcp-server-package"],
      "env": {
        "API_KEY": "value-or-secret-reference"
      }
    },
    "remote-example": {
      "url": "https://example.com/mcp",
      "headers": {
        "Authorization": "Bearer token-or-secret-reference"
      }
    }
  }
}
```

Three ingredients recur across every client's version of this file:

1. **Identity.** A server name, used both as a map key and, in tool names surfaced to the model,
   as a namespace prefix.
2. **Reachability.** Either a locally spawned process (a `command` and `args`, communicating over
   stdio) or a remote endpoint (a `url`, communicating over the Streamable HTTP transport, which
   replaced the earlier HTTP+SSE transport in the MCP specification). Local, stdio-based servers
   run with the same privileges as the client process; remote servers are reached over the network
   and may be hosted by a third party.
3. **Credentials.** Environment variables for a locally spawned process, or headers and/or an
   OAuth flow for a remote one. OAuth with Dynamic Client Registration is increasingly the default
   for hosted, remote servers, reducing the need to hand-manage static secrets; static header
   credentials remain common for simpler API-key-authenticated servers.

Most clients also distinguish a project scope (checked into version control and shared with a
team) from a user or global scope (personal, not shared), with the project scope typically taking
precedence when the same server name appears in both. Several clients layer a curated marketplace
or registry on top of this raw file format purely for discovery and one-click install; the
underlying configuration is still just a server-name-to-connection-details map.

### 2.4 Memory and persistent-state configuration patterns

Distinct from a static instructions file, several products now maintain a second, self-updating
store the tool writes to itself across sessions, without the user authoring it directly:

- **Claude Code auto memory.** A background system, on by default alongside CLAUDE.md, that saves
  notes such as build commands, debugging insights, and workflow habits when the model judges them
  useful for a future session. An always-loaded index file acts as a table of contents (capped at
  the first 200 lines or 25 KB, whichever is smaller), pointing to separate topic files that load
  only on demand. It is toggled with an in-session command or an `autoMemoryEnabled` setting, and
  is explicitly treated as context the model can act on, not enforced configuration; blocking a
  specific action regardless of what the model decides still requires a hook.
- **Claude.ai memory.** A consumer-facing feature, separate from Claude Code's, that periodically
  summarizes a user's or team's chat history into an editable memory summary, referenced in new
  standalone conversations. It is optional, user-editable and exportable, and can be bypassed
  per-conversation with an incognito-style chat mode that does not read from or write to memory.
- **ChatGPT memory.** Two independently toggleable mechanisms: "saved memories" (specific facts the
  user or the model explicitly decided to keep) and "reference chat history" (softer inference from
  past conversations, which can change over time as new information arrives). Both are managed from
  a personalization settings panel, where individual memories can be viewed, edited, or deleted, and
  both can be bypassed for a single conversation with a temporary-chat mode.
- **Developer-facing memory tools.** At the API level, memory can also be implemented explicitly by
  the application rather than by the chat product: Anthropic's memory tool, for example, lets a
  model request file-style read, write, and list operations against a `/memories` path, while the
  calling application supplies the actual storage backend (disk, database, or object storage).

A related but architecturally different pattern, retrieving relevant prior context from a vector
store rather than a small self-maintained note file, is covered in
[Chapter 5](../05-retrieval-embeddings-and-vector-databases.md)'s discussion of retrieval and
embeddings; the memory systems above are file- or summary-based, not similarity-search based,
though a RAG pipeline can be used to implement a custom memory store for the developer-facing case.

## 3. Practical recommendations: configuration hygiene

- **Keep instruction files lean and specific, not exhaustive.** A CLAUDE.md, AGENTS.md, or rules
  file competes with the rest of the context window on every single turn. Command-first, verifiable
  instructions (exact build/test commands, explicit conventions the code itself does not make
  obvious) earn their place; general prose about the project's history or style preferences the
  model would infer anyway usually does not.
- **Prefer on-demand loading over always-on context whenever the content is not needed every
  turn.** A skill costs almost nothing until it is actually invoked; an instructions-file addition
  costs context on every conversation, forever. If a procedure is used occasionally rather than
  constantly, it almost always belongs in a skill rather than in the always-loaded file.
- **Treat every MCP server, plugin, and connector as installing third-party code, not just
  granting an API key.** A locally spawned MCP server runs with the same privileges as the client
  process; a remote connector can read and act on whatever the underlying service authorizes. Vet
  the source, scope credentials narrowly, and prefer OAuth over long-lived static secrets where the
  server supports it. [Chapter 6](../06-security-privacy-and-data.md) covers this security posture,
  including data handling and privacy implications, in depth; this appendix intentionally does not
  repeat it.
- **Prefer official or clearly maintained sources for MCP servers over ad hoc community listings.**
  The distinction between an actively maintained reference server and a historical, archived one
  matters in practice, since an archived implementation will not receive protocol or security
  updates.
- **Reserve self-updating memory for what genuinely needs to persist without being asked.** A
  memory system that writes itself is convenient, but it is also an additional place where stale,
  contradictory, or unwanted context can accumulate silently. Periodically reviewing (and, where
  supported, editing or clearing) auto-generated memory is as much a hygiene practice as pruning an
  instructions file.

## References

### Official Documentation

- [Claude Code overview](https://code.claude.com/docs/en/) - Anthropic; high-level tour of CLAUDE.md, skills, hooks, MCP, and subagents.
- [Skills](https://code.claude.com/docs/en/skills) - Anthropic; skill file format, discovery locations, and the Agent Skills open standard.
- [Slash commands](https://code.claude.com/docs/en/slash-commands) - Anthropic; custom command and skill invocation, including plugin-provided skills.
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide) - Anthropic; hook event types (command, http, prompt, agent, mcp_tool) and lifecycle events.
- [Memory](https://code.claude.com/docs/en/memory) - Anthropic; CLAUDE.md scopes and the auto memory system, including the MEMORY.md index behavior.
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) - Anthropic; plugin.json manifest schema and component paths.
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) - Anthropic; marketplace.json schema and distribution workflow.
- [Discover and install prebuilt plugins](https://code.claude.com/docs/en/discover-plugins) - Anthropic; marketplace sources and installation commands.
- [Memory tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool) - Anthropic; developer-facing, client-implemented memory tool for the API.
- [Use Claude's chat search and memory to build on previous context](https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context) - Anthropic; consumer-facing Claude.ai memory feature and controls.
- [Third party connectors with remote MCP](https://claude.com/docs/connectors/custom/remote-mcp) - Anthropic; directory vs. custom connectors and their security posture.
- [Building custom connectors](https://claude.com/docs/connectors/building) - Anthropic; connector development resources and the mcp-server-dev plugin.
- [Authentication for connectors](https://claude.com/docs/connectors/building/authentication) - Anthropic; supported connector authentication types (OAuth variants and static headers).
- [Use connectors to extend Claude's capabilities](https://support.claude.com/en/articles/11176164-use-connectors-to-extend-claude-s-capabilities) - Anthropic; how connectors are added and used across Claude surfaces.
- [Rules](https://cursor.com/docs/rules) - Cursor; `.mdc` rule format, activation modes, and team/project/user precedence.
- [Skills](https://cursor.com/docs/skills) - Cursor; SKILL.md format and discovery locations.
- [Skills (help center)](https://cursor.com/help/customization/skills) - Cursor; skill creation workflow and cross-tool compatibility directories.
- [Customizing agents](https://cursor.com/learn/customizing-agents) - Cursor; conceptual distinction between rules and skills.
- [Hooks](https://cursor.com/docs/hooks) - Cursor; hook categories, lifecycle events, and cloud agent support.
- [MCP](https://cursor.com/docs/mcp) - Cursor; mcp.json configuration, transports, and marketplace installation.
- [MCP (help center)](https://cursor.com/help/customization/mcp) - Cursor; mcp.json file locations and local vs. remote server examples.
- [LLM safety and controls](https://cursor.com/docs/enterprise/llm-safety-and-controls) - Cursor; enforcement hooks vs. rules vs. MCP in an enterprise context.
- [Configure MCP servers](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/configure-mcp-servers) - GitHub; repository-level MCP server configuration on GitHub.com.
- [Extending GitHub Copilot Chat with Model Context Protocol servers](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/extend-copilot-chat-with-mcp) - GitHub; VS Code MCP configuration and the GitHub MCP Registry.
- [Add custom instructions for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions) - GitHub; instruction file discovery locations, including Copilot CLI.
- [Add repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions) - GitHub; copilot-instructions.md and path-scoped instructions.instructions.md files.
- [Custom instructions support](https://docs.github.com/en/copilot/reference/custom-instructions-support) - GitHub; which Copilot features read which instruction file types, including AGENTS.md/CLAUDE.md/GEMINI.md.
- [Model Context Protocol reference servers](https://github.com/modelcontextprotocol/servers/) - Model Context Protocol project; the officially maintained reference server list and pointer to archived servers and the official registry.
- [Official MCP Registry](https://registry.modelcontextprotocol.io/) - Model Context Protocol project; vendor-neutral discovery index for published MCP servers.
- [What is the Model Context Protocol](https://modelcontextprotocol.io/introduction) - Model Context Protocol project; protocol overview and ecosystem scope.
- [Transports](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) - Model Context Protocol project; Streamable HTTP transport and its replacement of HTTP+SSE.
- [Streamable HTTP transport (draft)](https://modelcontextprotocol.io/specification/draft/basic/transports/streamable-http) - Model Context Protocol project; current transport-level request/response mechanics.
- [stdio transport (draft)](https://modelcontextprotocol.io/specification/draft/basic/transports/stdio) - Model Context Protocol project; local, subprocess-based transport framing.
- [AGENTS.md](https://agents.md/) - AGENTS.md project (Agentic AI Foundation, Linux Foundation); the open specification, its no-schema design, and nearest-file discovery.
- [GPT Actions](https://developers.openai.com/api/docs/actions/introduction) - OpenAI; how Actions bridge Custom GPTs to external REST APIs via function calling.
- [Getting started with GPT Actions](https://developers.openai.com/api/docs/actions/getting-started) - OpenAI; OpenAPI schema and authentication setup workflow.
- [Production notes on GPT Actions](https://developers.openai.com/api/docs/actions/production) - OpenAI; request limits, TLS requirements, and the `x-openai-isConsequential` confirmation flag.
- [Creating and editing GPTs](https://help.openai.com/en/articles/8554397) - OpenAI; instructions, knowledge, and capability configuration for a Custom GPT.
- [GPTs in ChatGPT](https://help.openai.com/en/articles/8554407) - OpenAI; GPT configuration elements and confirmation that GPTs do not use ChatGPT's memory or custom instructions.
- [Memory and new controls for ChatGPT](https://openai.com/index/memory-and-new-controls-for-chatgpt/) - OpenAI; announcement and controls for saved memories and chat history.
- [Memory FAQ](https://help.openai.com/articles/8590148-memory-faq) - OpenAI; current ChatGPT memory system behavior and settings location.
- [How does "Reference saved memories" work?](https://help.openai.com/en/articles/11146739-how-does-reference-saved-memories-work) - OpenAI; distinction between saved memories and reference chat history.
