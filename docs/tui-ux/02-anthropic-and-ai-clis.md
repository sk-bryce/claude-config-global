---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# 2. Claude Code and Comparable AI-Agent CLIs

This chapter covers how Anthropic's own terminal tool is built, what's documented about its UX
mechanisms, and how it compares to other terminal-based AI coding agents. AI-agent CLIs are a
distinct sub-genre of TUI with UX problems traditional terminal tools never had to solve --
representing an agent "at work," gating risky autonomous actions, and surfacing plans and diffs
before applying them -- covered in 2.3.

A note on confidence throughout this chapter: public documentation of *why* these tools look the
way they do is thin. What exists is mostly reference documentation (what a feature does) rather
than design-rationale writing (why it was built that way). Claims are marked confirmed,
speculative, or unconfirmed accordingly -- do not treat a plausible-sounding claim from a
third-party teardown as equivalent to something Anthropic has stated.

## 2.1 Claude Code's Own Implementation

**UI toolkit -- confirmed, with caveats.** Claude Code's terminal UI is built with React, rendered
via Ink (the React-for-CLIs renderer), in TypeScript. This is corroborated by two independent
threads: [GitHub issue #3045](https://github.com/anthropics/claude-code/issues/3045) in the
official `anthropics/claude-code` repository -- a community technical investigation that extracted
strings from the bundled `cli.js` and found direct references to Ink internals (`ink-text-input`,
`TextInput`, `useInput`), and which carries Anthropic's own `area:tui` label -- and Gergely
Orosz's Pragmatic Engineer newsletter piece, ["How Claude Code is
built"](https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built), which independently
states the stack is TypeScript + React + Ink plus Yoga (Meta's flexbox layout engine) for terminal
layout, and attributes a "radical simplicity" philosophy to Boris Cherny (Claude Code's original
creator/lead), quoting him: *"With every design decision, we almost always pick the simplest
possible option."*

Beyond this, several third-party reverse-engineering write-ups (blog teardowns of the published,
source-mapped npm bundle) claim Claude Code forked Ink into a fully custom React reconciler with
a hand-written ANSI/CSI/OSC parser stack. This is plausible -- a heavily polished Ink-based app at
this scale would plausibly need exactly that -- but it is **not corroborated by any official
Anthropic source**. Treat it as informed speculation from community code analysis, not as fact.

**Runtime -- confirmed.** Claude Code ships as a Bun executable, not a plain Node.js script. Per
Bun's own blog post announcing [Bun joining Anthropic](https://bun.com/blog/bun-joins-anthropic):
*"Claude Code ships as a Bun executable to millions of users. If Bun breaks, Claude Code breaks."*
Bun's single-file-executable compilation is the specific fit for CLI distribution -- end users
don't need a separate Node/npm install.

**Official UX documentation -- confirmed, directly from Anthropic's docs.** Several concrete UX
mechanisms are documented (not third-party-inferred):

- **Permission modes** ([code.claude.com/docs/en/permission-modes](https://code.claude.com/docs/en/permission-modes)):
  Claude pauses before editing files, running shell commands, or making network requests.
  `default` reads freely but prompts for everything else; `acceptEdits` auto-allows reads, file
  edits, and common filesystem commands; **plan mode** (Shift+Tab twice, or
  `--permission-mode plan`) restricts Claude to research and proposing changes -- it can read
  files and run read-only exploration, but edits stay blocked until the user explicitly approves
  the plan, at which point they choose "approve and start in auto mode," "approve and review each
  edit individually," or "keep planning."
- **Statusline** ([code.claude.com/docs/en/statusline](https://code.claude.com/docs/en/statusline)):
  a customizable bar at the bottom of the CLI, fed a JSON blob on stdin describing session state
  (model, working directory, git state, token/context usage, cost); a user script decides what to
  render. Once a custom statusline is configured, Claude Code suppresses most of the default
  footer hints (`esc to interrupt`, `? for shortcuts`, voice-dictation hint) to avoid duplicated
  chrome -- an explicit tradeoff between the built-in footer and a user-configured status row.
- **Todo/task tracking** ([code.claude.com/docs/en/agent-sdk/todo-tracking](https://code.claude.com/docs/en/agent-sdk/todo-tracking)):
  a built-in tool (`TodoWrite`, in the process of being replaced by structured
  `TaskCreate`/`TaskUpdate`/`TaskGet`/`TaskList` tools as of Agent SDK 0.3.142 / Claude Code
  v2.1.142) renders a live checklist with pending/in-progress/completed states, used for
  multi-step work requiring three or more distinct actions.

No official Anthropic engineering blog post or talk dedicated to *why* Claude Code's terminal UX
looks the way it does (streaming rendering internals, spinner/animation design, theming rationale)
turned up in research. What's public is reference documentation describing features, plus one
paywalled independent-journalist interview quote -- nothing at the level of, say, Google's
Gemini CLI design-rationale post below.

## 2.2 Comparable AI-Agent CLIs

### OpenAI Codex CLI

**Confirmed via primary source.** Codex CLI is written in Rust. Its actual `codex-rs/tui/Cargo.toml`
(fetched directly from GitHub) confirms the TUI crate depends on
[ratatui](04-rust-frameworks.md) (immediate-mode TUI rendering) and crossterm (terminal backend),
plus `diffy` (diff rendering), `syntect`/`two-face` (syntax highlighting), and `image` (inline
image rendering).

**Approval model -- confirmed via official docs.** Per
[learn.chatgpt.com/docs/agent-approvals-security](https://learn.chatgpt.com/docs/agent-approvals-security),
approval policy (`untrusted`, `on-request`, `never`, `auto_review`) is deliberately **orthogonal**
to sandbox mode (`read-only`, `workspace-write`, `danger-full-access`) -- "what the agent can do"
and "when it must pause and ask" are two independent axes, not one combined setting. `.git` and
`.codex` stay protected even in writable sandbox modes. `/status` and `/permissions` are
documented in-CLI commands for inspecting/changing this. This is arguably the most precisely
documented version of the approval-gating pattern among the tools checked.

### Google Gemini CLI

**Framework -- confirmed.** Node.js/TypeScript, React via Ink, directly confirmed by fetching
`gemini-cli`'s actual `package.json` on GitHub, which lists `ink` (currently pinned to a fork,
`npm:@jrichman/ink@6.6.9`) as a runtime dependency and React 19 types/`react-dom` as dev
dependencies.

**A genuine design-rationale write-up.** Unlike anything found for Claude Code, Google published
a developer-blog post specifically about terminal UX: ["Making the terminal beautiful one pixel at
a time"](https://developers.googleblog.com/making-the-terminal-beautiful-one-pixel-at-a-time/).
It describes a rendering-foundation overhaul that eliminated screen flicker, fixed a "bouncing"
input prompt, kept the input field anchored at the bottom via an alternate-screen-buffer approach,
added sticky headers for tool-confirmation prompts, and improved resize handling -- explicitly
framed as bringing "a level of polish you typically only expect from graphical interfaces" into
the terminal. Shipped default in v0.15.0.

**Currency note.** A second official Google post confirms
[Gemini CLI is being sunset for consumer use](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/),
transitioning into a new unified Antigravity CLI (Go-based backend). Consumer/free-tier access to
Gemini CLI stopped June 18, 2026 -- already past as of this guide's writing (August 2026);
enterprise/paid-license customers keep access via the Gemini Agent Platform API. Flagging this
plainly: anything above describing Gemini CLI's UX describes a product whose consumer-facing life
has already ended by the time you're reading this.

### opencode

Originally built with Go, on Bubble Tea/Lip Gloss (see [Chapter 3](03-go-frameworks.md)), per
multiple secondary sources. More recently, opencode's own team (Anomaly/sst) built **OpenTUI**, a
from-scratch terminal UI framework with a Zig core and TypeScript bindings (React/Solid/vanilla
reconcilers), and opencode itself moved onto it -- it now runs on a bespoke, non-Ink rendering
framework rather than Bubble Tea. Official docs ([opencode.ai/docs/](https://opencode.ai/docs/))
describe distribution via npm/Bun/pnpm/Homebrew, and distinctive UX: a Tab-key Plan/Build mode
toggle with a lower-right visual indicator (directly analogous to Claude Code's plan mode),
`/undo` and `/redo` for reverting agent changes, `@`-triggered fuzzy file search for injecting
context, and a `/share` command for shareable session links.

### Aider

Official site ([aider.chat](https://aider.chat/)) confirms: automatic git commits with generated
commit messages after each change, and a diff/undo workflow built on familiar git tooling ("use
familiar git tools to easily diff, manage and undo AI changes"). The homepage itself doesn't
state Aider's implementation language; it's broadly documented elsewhere as a Python CLI
(`pip`/`pipx` install path), though this wasn't independently re-verified against a primary Aider
source in this research pass -- treat as high-confidence but not freshly verified. Distinctive UX
per secondary sources: a repository map (via tree-sitter) so the model can reason about unseen
files, multiple chat modes (`code`/`architect`/`ask`/`help`), and diff-before-commit transparency.

## 2.3 Cross-Cutting UX Patterns in AI-Agent CLIs

Drawing only on what's documented above, four patterns recur across this category and don't
really have precedent in pre-agent TUIs:

**Representing agent "work in progress."** Claude Code and opencode both show a live, updating
todo/task checklist with per-item state (pending/in-progress/done) rather than just a spinner --
explicitly documented for Claude Code's `TodoWrite`/Task tools. Gemini CLI's redesign specifically
targeted the failure mode of "losing your place" during long streaming output, a problem made
worse because agent responses interleave streamed text with tool calls, unlike a traditional
single-purpose TUI's simpler output stream.

**Approval/risk gating before mutating actions.** All three agent CLIs with a documented approval
model (Claude Code, Codex, and implicitly opencode via its plan/build toggle) converge on the same
shape: a low-risk default state (read-only, or "ask about everything risky") with an explicit,
user-chosen escalation to a less-interrupted mode for edits and commands. Codex's docs make the
separation between "sandbox" (what's technically possible) and "approval policy" (when to pause
and ask) explicit and named as intentionally orthogonal axes.

**Diffs and plans before applying changes.** Codex bundles the Rust `diffy` crate specifically
for inline diff rendering in its TUI. Aider's core loop is diff-then-commit. Claude Code's plan
mode produces a plan the user must explicitly approve before any edit tool runs. opencode's
Plan/Build toggle is the same idea with a persistent visual mode indicator rather than a one-time
gate.

**Context/session indicators.** Claude Code's statusline (context-usage progress bar, cost, git
branch) and Codex's `/status` command (workspace boundary, sandbox state) both surface
session/resource state persistently rather than only at the point of an error -- a pattern that
doesn't really exist in pre-agent TUIs, where "how much of my budget is left" wasn't a concept a
terminal tool needed to represent.

Only Google's Gemini CLI post explicitly frames "make it feel like a GUI" as a named design goal
with before/after specifics (flicker, bouncing prompt, sticky headers). No equivalent Anthropic
statement of design philosophy at this level of detail turned up from an official source -- the
closest is the single Boris Cherny "simplest possible option" quote relayed by Gergely Orosz.

## References

### Official Documentation

- [Choose a permission mode (Claude Code Docs)](https://code.claude.com/docs/en/permission-modes)
- [Customize your status line (Claude Code Docs)](https://code.claude.com/docs/en/statusline)
- [Todo Lists (Claude Code / Agent SDK Docs)](https://code.claude.com/docs/en/agent-sdk/todo-tracking)
- [openai/codex - codex-rs/tui/Cargo.toml (GitHub)](https://github.com/openai/codex/blob/main/codex-rs/tui/Cargo.toml)
- [Agent approvals and security (OpenAI Codex Docs)](https://learn.chatgpt.com/docs/agent-approvals-security)
- [google-gemini/gemini-cli - package.json (GitHub)](https://github.com/google-gemini/gemini-cli/blob/main/package.json)
- [Making the terminal beautiful one pixel at a time (Google Developers Blog)](https://developers.googleblog.com/making-the-terminal-beautiful-one-pixel-at-a-time/)
- [An important update: Transitioning Gemini CLI to Antigravity CLI (Google Developers Blog)](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/)
- [opencode Docs](https://opencode.ai/docs/)
- [Aider - AI Pair Programming in Your Terminal](https://aider.chat/)

### Community and Case Studies

- [Investigation: Fixing IME Issues in Claude Code by Patching React Ink - Issue #3045, anthropics/claude-code](https://github.com/anthropics/claude-code/issues/3045)
- [How Claude Code is built (Pragmatic Engineer / Gergely Orosz)](https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built)
- [Bun is joining Anthropic (Bun Blog)](https://bun.com/blog/bun-joins-anthropic)

### Further Local Reading

- `03-go-frameworks.md` - detail on Bubble Tea/Lip Gloss, opencode's original framework.
- `04-rust-frameworks.md` - detail on ratatui, Codex CLI's TUI framework.
