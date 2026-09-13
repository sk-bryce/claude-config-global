---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# Modern TUI/UX: A Reference for Building Usable Terminal Interfaces

A guide to designing and building terminal user interfaces (TUIs) and command-line tools that
are usable, informative, and feel modern -- covering the interaction-design and accessibility
principles that apply regardless of language, how Anthropic built Claude Code's own terminal UI
and how comparable AI-agent CLIs approach the same problems, and the framework and best-example
landscape in Go, Rust, and Python. Written with a Go-first bias (that is the primary language in
use day to day) but the Rust and Python chapters are equally thorough.

## Who this is for

Anyone designing or building a terminal application -- a full-screen interactive TUI, a scriptable
CLI, or something in between -- who wants the result to feel considered rather than accidental.
No assumption is made about which language you are using; language-specific chapters are separated
so you can skip straight to the one you need, but Chapter 1's principles apply everywhere.

## How to use this guide

1. **Read [Chapter 1](01-principles.md) first**, regardless of language. It covers the
   established CLI design guidelines (clig.dev, 12-Factor CLI Apps, POSIX/GNU conventions),
   interaction design for a character grid, accessibility (including a genuinely unsolved problem
   worth understanding before you build), visual/styling conventions, error handling, and testing
   tooling. Everything after this chapter assumes it.
2. **Read [Chapter 2](02-anthropic-and-ai-clis.md)** for how Claude Code itself is built, and how
   it and comparable AI-agent CLIs (OpenAI Codex CLI, Google Gemini CLI, opencode, Aider) handle
   the UX problems unique to agentic tools: showing an agent "at work," gating risky actions
   behind approval, and surfacing plans/diffs before applying them.
3. **Jump to whichever language chapter(s) you need**: [Go](03-go-frameworks.md),
   [Rust](04-rust-frameworks.md), [Python](05-python-frameworks.md). Each covers the framework
   ecosystem, an architecture comparison, best-in-class open-source example applications worth
   studying, and a recommendation table.
4. **Use [Chapter 6](06-patterns-and-checklist.md) as a working checklist** once you're building
   something -- it distills Chapters 1-5 into a practical, cross-language reference you can check
   a real project against.
5. **Every non-obvious factual claim is cited.** Treat a citation's date as when it was last
   checked, not a permanent guarantee -- this ecosystem moves fast (see the Scope section below
   for a concrete example of how fast).

## Table of contents

| Chapter | Covers |
| --- | --- |
| [1. Principles and Guidelines](01-principles.md) | clig.dev, 12-Factor CLI Apps, POSIX/GNU conventions; keyboard navigation, discoverability, progressive disclosure, responsive layout; accessibility (NO_COLOR, light/dark detection, screen readers, contrast); visual conventions, spinners/progress; error handling, confirmation prompts, TTY-aware mode switching; the Elm Architecture; testing and demo tooling. |
| [2. Claude Code and Comparable AI-Agent CLIs](02-anthropic-and-ai-clis.md) | What Claude Code is actually built with (confirmed vs. speculative), its documented UX mechanisms (permission modes, statusline, todo tracking); how OpenAI Codex CLI, Google Gemini CLI, opencode, and Aider approach the same problems; the UX patterns specific to AI-agent CLIs as a category. |
| [3. Go Frameworks](03-go-frameworks.md) | The Charm ecosystem (Bubble Tea, Bubbles, Lip Gloss, Glamour, VHS, Wish, Huh); tview, gocui, termui, termdash, tcell; best-in-class apps (lazygit, k9s, gh-dash, glow, superfile); comparison table. |
| [4. Rust Frameworks](04-rust-frameworks.md) | ratatui (and the tui-rs abandonment/fork story); cursive; crossterm/termion backends; best-in-class apps (gitui, bottom, zellij, atuin, helix); comparison table. |
| [5. Python Frameworks](05-python-frameworks.md) | Textual and Rich; urwid, prompt_toolkit, npyscreen, py_cui; best-in-class apps (Harlequin, Dolphie, Posting, Trogon); comparison table. |
| [6. Patterns and Checklist](06-patterns-and-checklist.md) | A practical, cross-language synthesis: a framework-selection decision guide, an actionable UX checklist, and two small ASCII diagrams (the Elm Architecture loop, and the TTY-aware mode-switch decision). |

## A one-paragraph summary, before you start

Terminal UIs are having a genuine renaissance, driven by two things converging: modern terminal
emulators (Kitty, Alacritty, WezTerm, and others) now reliably support true color, precise cursor
positioning, and richer input protocols than the terminals these conventions were designed
against decades ago, and a new generation of frameworks (Bubble Tea, ratatui, Textual) makes
building on top of that reliable enough to be worth it. But the fundamentals have not changed:
a terminal is still a fixed character grid, most of your users are still keyboard-first, and the
best terminal tools still borrow more from Unix philosophy (composability, plain text, scriptable
non-interactive modes) than from GUI conventions. Every chapter in this guide comes back to the
same handful of tensions: rich and discoverable versus simple and scriptable, interactive versus
pipeable, and -- a genuinely unresolved one, covered in Chapter 1 -- visually rich versus
accessible to a screen reader.

## Scope and limitations

- Reflects the terminal-tooling ecosystem as of early August 2026. This space moves fast enough
  that one finding from this research is already stale by the time you're reading it: Google's
  Gemini CLI is being sunset for consumer use, with free-tier access ending June 18, 2026 (already
  past, as of this guide's writing) in favor of a new Antigravity CLI -- see
  [Chapter 2](02-anthropic-and-ai-clis.md) for detail. Framework star counts, release versions,
  and maintenance status throughout are similarly a snapshot, not a permanent fact.
- This guide is about interaction design and the framework landscape, not a line-by-line coding
  tutorial for any specific framework. Each framework chapter links to the official docs for that
  depth.
- Accessibility coverage in Chapter 1 is honest about an open problem rather than presenting a
  solved one: modern, full-screen-repaint TUI frameworks are, per current investigative reporting,
  genuinely difficult for screen-reader users, and no framework covered in this guide has fully
  solved it. Where mitigations exist, they are called out specifically.
