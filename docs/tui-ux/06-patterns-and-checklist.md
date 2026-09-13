---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# 6. Patterns and Checklist

A practical synthesis of Chapters 1-5, meant to be checked against a real project rather than
read straight through. Nothing here is a new claim -- it's a working distillation of what came
before, with pointers back to the source chapter for the reasoning.

## 6.1 Choosing an Architecture: Two Diagrams

**The Elm Architecture loop** (see [1.6](01-principles.md#16-architecture-the-elm-architecture-tea)),
the dominant pattern behind Bubble Tea (Go) and several ratatui-adjacent crates (Rust):

```
                +-------------------+
                |       Model       |  <- plain state, nothing else
                +-------------------+
                    |            ^
          (current) |            | (new model)
                    v            |
                +-------------------+
    Msg  ------> |      Update       |
 (keypress,      +-------------------+
  resize,             |
  tick,               | (Cmd: async work,
  async I/O           |  reports back as
  completion)         |  a future Msg)
                      v
                +-------------------+
                |       View        |  <- pure: model in, terminal
                +-------------------+     output out, deterministic
                      |
                      v
                terminal grid
```

Every state change goes through one visible `Update` step; every render goes through one pure
`View` step. This is what makes `Update` unit-testable without a real terminal, and what avoids
the classic MVC-in-a-TUI failure mode of cascading, hard-to-trace mutations.

**The TTY-aware mode switch** (see [1.5](01-principles.md#15-error-handling-confirmation-and-mode-switching)),
the decision every CLI/TUI has to make at startup:

```
                    is stdout a TTY?
                          |
              +-----------+-----------+
              |                       |
             yes                      no
              |                       |
              v                       v
      rich interactive mode    plain scripting mode
      - color, by default      - no color (unless
      - spinners / progress      --color=always)
        animation               - no spinner animation
      - interactive prompts     - no interactive prompts;
      - box-drawing / icons       require flags instead
                                 - stable, greppable,
              |                    line-oriented output
              |                       |
              +-----------+-----------+
                          |
                          v
              NO_COLOR env var, if set and
              non-empty, forces color off
              regardless of the branch above
              (explicit --color=always still
              wins over NO_COLOR)
```

Check `isatty(stdin)` separately from `isatty(stdout)` -- they can differ when only one side of a
pipeline is redirected, and a program that silently reads from an interactive stdin it wasn't
expecting will appear to hang.

## 6.2 Framework Selection Guide

Start from what the app fundamentally is, not from which framework is trendiest:

| If the app is mostly... | Consider | Why |
| --- | --- | --- |
| A multi-panel dashboard of largely independent widgets (tables, trees, forms) | Go: tview. Rust: cursive. Python: Textual (widget/DOM model) or urwid for something lighter. | Retained-mode widget composition gets you there with less boilerplate than hand-rolling MVU. |
| Complex, cross-cutting state; async I/O; something you want to unit-test | Go: Bubble Tea. Rust: ratatui (+ tui-realm if you want component ergonomics back). Python: Textual (reactive attributes give you a comparable state-drives-render model). | Centralized, pure state-transition functions are the whole point of Elm-style architectures -- see 6.1. |
| A read-only metrics/monitoring dashboard | Go: termui or termdash. Rust: ratatui with the built-in chart/gauge widgets (see bottom, 4.3). Python: Textual (see Dolphie, 5.4) or Rich alone if it doesn't need to be full-screen. | Purpose-built dashboard widget sets save real time over building charts/gauges from scratch. |
| An interactive REPL or line editor, not a full-screen app | Python: prompt_toolkit is purpose-built for exactly this; don't reach for a full TUI framework. | Full-screen frameworks solve a different problem than line editing/completion. |
| Auto-generating a UI from an existing CLI's argument definitions | Python: Trogon, if the CLI is already built on Click/Typer (5.4). | Zero-effort discoverability layer bolted onto an existing parser, rather than a second UI to maintain by hand. |
| Pretty CLI output without needing a full interactive screen | Python: Rich alone. Go: Lip Gloss alone (without the rest of Bubble Tea). | Don't build a whole TUI when styled tables/progress bars/tracebacks are all you need. |

Before committing to any single-maintainer crate at the center of your dependency tree, read the
tui-rs to ratatui story in [4.1](04-rust-frameworks.md#history-from-tui-rs-to-ratatui-a-cautionary-tale)
and weigh "what happens if this maintainer disappears" as a real, precedented risk, not a
hypothetical.

## 6.3 The Checklist

Grouped by the chapter that explains the reasoning. Not every item applies to every app --
treat this as a prompt to make a deliberate choice, not a mandate.

**Help and discoverability** ([1.1](01-principles.md#11-established-cli-design-guidelines),
[1.2](01-principles.md#12-interaction-design-for-terminals))
- [ ] `--help`/`-h` and a bare invocation with missing/bad args both produce useful, non-identical
      output (concise on error, full on explicit `--help`).
- [ ] `--version`/`-V` works.
- [ ] Every keybinding is reachable without memorization: a persistent footer shows the 3-5 most
      relevant bindings for the current context, and a `?` key opens a full, context-aware
      overlay.
- [ ] Subcommand names are not silently abbreviation-tolerant, and there's no implicit default
      subcommand.

**Output modes and scripting** ([1.1](01-principles.md#11-established-cli-design-guidelines),
[1.5](01-principles.md#15-error-handling-confirmation-and-mode-switching))
- [ ] `isatty(stdin)` and `isatty(stdout)` are checked separately, and drive an automatic
      rich-vs-plain mode switch (6.1's second diagram).
- [ ] A machine-readable output mode exists behind an explicit flag (`--json`, `--plain`) with one
      record per line and no table borders.
- [ ] Real output goes to stdout, diagnostics/logs go to stderr.
- [ ] No secret is ever required via a bare flag; accept it via a file or stdin.

**Color and visual styling** ([1.3](01-principles.md#13-accessibility),
[1.4](01-principles.md#14-visual-and-styling-conventions))
- [ ] `NO_COLOR` (present and non-empty) disables ANSI color; an explicit `--color=always` still
      overrides it.
- [ ] `--no-color` and `TERM=dumb` are both respected.
- [ ] Color is never the only channel for meaning -- pair it with an icon, label, or symbol; avoid
      red/green, blue/green, and yellow/purple pairings.
- [ ] Palette works against both light and dark backgrounds, ideally via a runtime OSC 11 check
      with a safe fallback rather than a hardcoded assumption.
- [ ] Icon/Nerd Font glyphs are opt-in or gracefully fall back to plain ASCII/standard Unicode --
      there's no reliable way to detect font support.

**Progress and animation** ([1.4](01-principles.md#14-visual-and-styling-conventions))
- [ ] Short, unmeasurable work uses a spinner that only advances on real progress events (so a
      stall visibly freezes it).
- [ ] Measurable work defaults to an "X of Y" counter, not a progress bar, unless summarizing
      several simultaneous operations.
- [ ] Progress indicators are cleared on completion and switch to past tense ("downloaded," not
      "downloading").
- [ ] No spinner/progress control characters leak into non-TTY output.

**Errors and confirmation** ([1.5](01-principles.md#15-error-handling-confirmation-and-mode-switching))
- [ ] Every error states what went wrong, why, and what to do about it -- not just a raw stack
      trace.
- [ ] Confirmation is reserved for genuinely serious/irreversible actions; the prompt states the
      actual consequence, not a generic "Are you sure?"; no default answer is pre-selected for a
      dangerous action.
- [ ] Where feasible, prefer "do it, but make it undoable for a window" over a blocking
      confirm-then-act prompt.

**Layout and resize** ([1.2](01-principles.md#12-interaction-design-for-terminals))
- [ ] Resize is handled via a live layout recompute (constraint-based, not hardcoded absolute
      positions), not a frozen or corrupted redraw.
- [ ] A minimum supported size is defined (80x24 is the conventional floor) with an explicit
      "terminal too small" message below it.
- [ ] Tested at more than one terminal size.

**Mouse support** ([1.2](01-principles.md#12-interaction-design-for-terminals))
- [ ] Every feature reachable by mouse is also reachable by keyboard; nothing is mouse-only.

**Accessibility** ([1.3](01-principles.md#13-accessibility)) -- treat this as a genuinely unsolved
problem, not a checkbox to clear
- [ ] A flat, non-interactive, argument-based mode exists as an escape hatch outside any 2D
      full-screen rendering, for screen-reader users.
- [ ] If animation/redraw is used, consider whether a scrolling-region approach (like `irssi`'s)
      could replace full-screen repaint for the parts of the UI that are fundamentally a log
      stream.
- [ ] Cursor movement during redraw is minimized or made optional, rather than "teleporting" for
      every status update.

**Testing and demos** ([1.7](01-principles.md#17-testing-and-tooling))
- [ ] Golden-file/snapshot tests exist for CLI output where feasible, with a documented
      regenerate-and-diff-review workflow.
- [ ] Anything that requires a real TTY to test correctly (password prompts, y/n confirmations)
      is tested with an expect-style tool, not plain piped subprocess tests.
- [ ] Demo GIFs/recordings (VHS, asciinema) are generated from a script, not hand-captured, so
      they can be regenerated when the UI changes.

## 6.4 If You're Building an AI-Agent CLI Specifically

The four cross-cutting patterns from [Chapter 2](02-anthropic-and-ai-clis.md#23-cross-cutting-ux-patterns-in-ai-agent-clis)
worth treating as a baseline, not a novelty:

- [ ] Long-running or multi-step agent work is represented as a live, per-item checklist
      (pending/in-progress/done), not just a spinner -- the interleaving of streamed text and
      tool calls makes "did it lose my place" a real failure mode a spinner alone can't signal.
- [ ] Risky actions (file writes, shell commands, network requests) are gated behind an explicit
      approval step by default, with a clearly named, user-chosen escalation path to a
      less-interrupted mode -- and "what's technically permitted" (sandbox) is kept a separate
      axis from "when to pause and ask" (approval policy), rather than one combined setting.
- [ ] Proposed changes are shown as a diff or an explicit plan before being applied, with a real
      approval gate, not an implicit one.
- [ ] Session/resource state (context usage, cost, scope boundaries) is surfaced persistently
      (a statusline, a `/status` command), not only revealed at the point of an error.
