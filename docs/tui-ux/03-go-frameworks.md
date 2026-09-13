---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# 3. Go TUI Frameworks

Go has the most mature, cohesive TUI ecosystem of the three languages covered in this guide,
centered on the Charm organization's tools. This chapter is the most detailed of the three
framework chapters accordingly.

## 3.1 The Charm Ecosystem

Charm's stated mission ([charm.land](https://charm.land/)) is to "make the command line
glamorous" -- an open-source toolkit deployed across tens of thousands of applications (Bubble
Tea's own README states 18,000+ dependent apps).

**Bubble Tea** ([charmbracelet/bubbletea](https://github.com/charmbracelet/bubbletea), 44.2k
stars, MIT). The core Elm-Architecture TUI framework (see [1.6](01-principles.md#16-architecture-the-elm-architecture-tea)).
Programs implement `tea.Model`:

```go
type Model interface {
    Init() Cmd
    Update(Msg) (Model, Cmd)
    View() string
}
type Msg interface{}
type Cmd func() Msg
```

`Init` returns an optional startup command; `Update` receives a `tea.Msg` (keypress, timer tick,
HTTP response, etc.) and returns a new immutable `Model` plus an optional `Cmd` -- an async I/O
operation that runs in its own goroutine and reports back via a channel-fed message rather than
requiring manual mutex/goroutine plumbing in application code; `View` renders the current state to
a string after every update. `tea.NewProgram(model, opts...).Run()` drives the loop. This fits Go
well: state mutation stays centralized and explicit rather than scattered across callback-mutated
shared widget state, concurrency is handled by returning `Cmd`s instead of hand-rolled
goroutine/mutex code, and the interface-based `Model` composes cleanly with Go's preference for
small interfaces over inheritance. Notable adopters include Aztify (Microsoft Azure) and
CockroachDB; it underlies Glow, Huh, Mods, and chezmoi's interactive parts.

**Bubbles** ([charmbracelet/bubbles](https://github.com/charmbracelet/bubbles), 8.8k stars, MIT).
Reusable `tea.Model`-compatible components: spinner, textinput, textarea, table, progress,
paginator, viewport, list, filepicker, timer, stopwatch, help, and a `key` package for
keybinding management and help-text generation. Each component is itself a small Bubble Tea model
that a parent model embeds and delegates `Update`/`View` calls to.

**Lip Gloss** ([charmbracelet/lipgloss](https://github.com/charmbracelet/lipgloss), 11.7k stars,
MIT). A declarative, CSS-inspired styling layer:
`lipgloss.NewStyle().Bold(true).Foreground(...).Padding(2,4).BorderStyle(lipgloss.RoundedBorder())`,
with CSS-box-model-style padding/margin shorthand, plus `JoinHorizontal`/`JoinVertical` for
flex-like composition of rendered blocks. Handles automatic color downsampling (TrueColor -> 256
-> 16 ANSI) based on terminal capability, and has `table`, `list`, and `tree` subpackages for
structured rendering. Bubble Tea itself is unopinionated about styling; Lip Gloss is the piece
that answers "how do I make a Bubble Tea view look good."

**Glamour** ([charmbracelet/glamour](https://github.com/charmbracelet/glamour), 3.6k stars, MIT).
Stylesheet-based Markdown-to-ANSI renderer. Powers Glow, GitHub CLI (`gh`), GitLab CLI, and Gitea
CLI's markdown rendering.

**VHS** ([charmbracelet/vhs](https://github.com/charmbracelet/vhs), 20.6k stars, MIT). Records
terminal sessions to GIF/MP4/WebM/PNG from declarative `.tape` scripts, rendered via ffmpeg. See
[1.7](01-principles.md#17-testing-and-tooling) for its use as both a demo and integration-testing
tool.

**Wish** ([charmbracelet/wish](https://github.com/charmbracelet/wish), 5.4k stars, MIT). A
middleware-based SSH app server framework (built on `gliderlabs/ssh`) for exposing a Bubble Tea
(or any) TUI directly over SSH without a shell. Used by Soft Serve (Charm's git server) and
pico.sh.

**Huh** ([charmbracelet/huh](https://github.com/charmbracelet/huh), 7.1k stars, MIT). A
forms/prompts library with a `Form -> Group -> Field` builder hierarchy (`Input`, `Text`,
`Select`, `MultiSelect`, `Confirm`), built-in themes (Charm, Dracula, Catppuccin, Base16), an
accessible/screen-reader mode (see [1.3](01-principles.md#13-accessibility) -- this is the same
library GitHub CLI adopted for its accessibility work), and first-class Bubble Tea integration for
embedding forms inside larger programs.

Adjacent ecosystem tools worth a name-check: **Gum** (24.2k stars) -- shell-script-friendly
glamorous prompts without writing Go; **Crush** (27.2k stars) -- Charm's own agentic coding TUI,
itself a large real-world Bubble Tea app worth studying.

## 3.2 Other Go TUI Frameworks

| Library | Style | Notes |
| --- | --- | --- |
| **tcell** ([gdamore/tcell](https://github.com/gdamore/tcell), 5.2k stars, Apache-2.0) | Low-level terminal-cell library | Not a UI framework -- a foundation. Cell-based screen abstraction, Unicode/grapheme handling, mouse/keyboard events, 24-bit color negotiation, pure Go (no CGO), cross-platform including WASM. `tview` is built directly on it; **lazygit's current `go.mod` depends directly on `gdamore/tcell/v3`** with no `gocui`/`tview` dependency -- see 3.3. |
| **tview** ([rivo/tview](https://github.com/rivo/tview), 14k stars, MIT) | Widget-based (retained composition) | Built on tcell plus `rivo/uniseg`. Ships batteries-included widgets: Form, Table, TreeView, List, TextView/TextArea, Grid/Flex/Pages layout managers, modals. You compose pre-built widget objects and wire callbacks, rather than writing a single Update function. Good fit for dashboard-style multi-panel apps built fast without designing your own component model. Powers k9s and GitHub CLI's interactive prompts. |
| **gocui** ([awesome-gocui/gocui](https://github.com/awesome-gocui/gocui), community-maintained fork, 385 stars, BSD-3-Clause) | Minimalist, view-based | Views behave as `io.ReadWriter`; concurrency-safe update model with explicit keybindings and overlapping views. Built on tcell in this maintained fork. Used by lazydocker and cointop. Good for small, tightly-scoped console UIs where a large widget library isn't wanted. |
| **termui** ([gizak/termui](https://github.com/gizak/termui), 13.6k stars, MIT) | Dashboard/widget, built on `termbox-go` | Charts/gauges/tables/sparklines-oriented -- a metrics-dashboard toolkit, not a general app framework. The maintainer has flagged inconsistent update cadence and is seeking co-maintainers -- a maintenance-risk pick to flag before building on it. |
| **termdash** ([mum4k/termdash](https://github.com/mum4k/termdash), 3k stars, Apache-2.0) | Widget-based dashboard | Google-adjacent (explicitly "not an official Google product") rewrite inspired by termui/blessed-contrib, focused on readability/testability. Pre-1.0, API not yet stable. Rich widget set (BarChart, LineChart, HeatMap, Radar) for dashboard/monitoring UIs specifically. |

**Architecture philosophy.** Bubble Tea is the only mainstream Go option using Elm-style MVU (a
single immutable model, a pure `Update` function, message-passing concurrency), which scales well
to complex apps because state transitions stay centralized and testable -- `Update` can be
unit-tested as a pure function. tview/gocui/termui/termdash are widget-based: you instantiate
stateful widget objects and attach callbacks or mutate their state directly, which is faster to
get a dashboard-shaped app running but pushes state-management discipline onto the developer as
the app grows. None of the Go libraries are "immediate mode" in the Dear ImGui sense (rebuild the
whole UI from scratch every frame with no retained widget objects at all) -- that pattern shows up
more in Rust's ratatui (see [Chapter 4](04-rust-frameworks.md)). Go's closest analogue is Bubble
Tea's re-render-`View()`-every-update model, which retains a structured `Model` and so sits
between "widget-retained" and "true immediate mode."

**When to pick which.** Prefer tview/gocui over Bubble Tea when the app is fundamentally a
multi-panel dashboard of largely independent widgets and less boilerplate matters more than
testable state transitions. Prefer Bubble Tea when the app has meaningfully cross-cutting state,
async I/O, or you want UI logic to be unit-testable as pure functions.

## 3.3 Best-in-Class Go TUI Applications

- **lazygit** ([jesseduffield/lazygit](https://github.com/jesseduffield/lazygit), 81.1k stars,
  MIT). Built directly on `gdamore/tcell/v3` with a custom widget layer -- **not** gocui or tview,
  contrary to several older articles; verified against the current `go.mod`, which has moved to a
  tcell-based UI layer with no gocui/tview dependency present. UX highlights: a five-panel layout
  keeping status/files/branches/commits/stash simultaneously visible; spacebar line-level staging;
  color-coded commit graph (green/yellow/red for merge state); one-key interactive rebase and
  cherry-pick that would otherwise require memorized git flag combinations. A good example of a
  TUI that discoverably surfaces a CLI tool's full power without a menu tree.
- **k9s** ([derailed/k9s](https://github.com/derailed/k9s), 34.3k stars, Apache-2.0). Built on
  tview. UX highlights: a `:resource` colon-command palette (vim/dmenu-like) for jumping between
  Kubernetes object types instead of nested menus; live-updating resource tables with regex/label
  filtering; YAML-defined custom plugins for extending hotkeys. A good example of tview's
  widget-table strengths.
- **gh-dash** ([dlvhdr/gh-dash](https://github.com/dlvhdr/gh-dash), 12.3k stars, MIT). Built on
  Bubble Tea + Lip Gloss + Glamour. UX highlights: user-configurable YAML "sections" (saved
  searches) for PRs/issues rendered as columns; vim-style keys; inline diff/comment/checkout
  without leaving the dashboard. A good reference for Bubble Tea + Lip Gloss + Glamour used
  together in one real app, and for config-driven UI where the view shape is data, not hardcoded.
- **glow** ([charmbracelet/glow](https://github.com/charmbracelet/glow), 26.8k stars, MIT). Built
  on Glamour + Bubble Tea. Dual-mode: a TUI file browser/pager for local markdown, or one-shot CLI
  rendering (files, stdin, GitHub/GitLab URLs). A good reference for Glamour styling and Bubble
  Tea pager patterns.
- **superfile** ([yorukot/superfile](https://github.com/yorukot/superfile), 22.4k stars, MIT).
  Built on Bubble Tea. Multi-pane file manager with vim-mode hotkeys, a plugin system, theming,
  and image preview -- a useful counterpoint showing Bubble Tea isn't only for simple, single-pane
  tools.
- **chezmoi** ([twpayne/chezmoi](https://github.com/twpayne/chezmoi), 21.1k stars, MIT). Primarily
  a CLI dotfile manager with interactive subcommands (`chezmoi edit`, `chezmoi merge`) that shell
  out to external editors/diff tools rather than presenting a full custom TUI screen -- worth
  noting as "TUI-adjacent" rather than a full TUI showcase.

The curated list [rothgar/awesome-tuis](https://github.com/rothgar/awesome-tuis) (20.1k stars,
community-maintained, PR-accepting) was checked and confirmed live, and surfaces further Go
examples worth a look: `ctop` (container metrics top), `dry` (Docker terminal manager), `lf`
(ranger-inspired file manager), `gotop` (activity monitor).

## 3.4 Comparison Table

| Framework | Architecture | Styling | Learning curve | Best-fit use case | License |
| --- | --- | --- | --- | --- | --- |
| Bubble Tea (+ Bubbles + Lip Gloss) | Elm/MVU (message-passing) | Lip Gloss: CSS-like, composable, very rich | Moderate -- MVU is a mental-model shift if new to Elm/Redux-style patterns | Complex, stateful, async-heavy apps; anything needing unit-testable UI logic | MIT |
| tview | Widget-based (retained, callback-driven) | Built-in but plainer; tag-based color/attribute strings | Low -- closest to traditional GUI-toolkit thinking | Dashboard/admin tools with tables, forms, trees (k9s-style) | MIT |
| gocui (awesome-gocui fork) | Minimalist view-based | Manual, low-level | Low-moderate | Small, focused console UIs, tight control over rendering | BSD-3-Clause |
| termui | Widget/dashboard | Chart/gauge-focused | Low | Read-only metrics dashboards | MIT (maintenance risk: seeking maintainers) |
| termdash | Widget/dashboard | Chart/gauge-focused, richer widget set than termui | Low-moderate | Monitoring dashboards; API still pre-1.0 | Apache-2.0 |
| tcell (foundation, not a framework) | Low-level cell/event abstraction | None (build your own) | High if used raw | Building a custom framework, or when tview/Bubble Tea's abstractions don't fit | Apache-2.0 |

## References

### Official Documentation

- [charmbracelet/bubbletea (GitHub)](https://github.com/charmbracelet/bubbletea)
- [tea package docs (pkg.go.dev)](https://pkg.go.dev/github.com/charmbracelet/bubbletea)
- [charmbracelet/bubbles (GitHub)](https://github.com/charmbracelet/bubbles)
- [charmbracelet/lipgloss (GitHub)](https://github.com/charmbracelet/lipgloss)
- [charmbracelet/glamour (GitHub)](https://github.com/charmbracelet/glamour)
- [charmbracelet/vhs (GitHub)](https://github.com/charmbracelet/vhs)
- [charmbracelet/wish (GitHub)](https://github.com/charmbracelet/wish)
- [charmbracelet/huh (GitHub)](https://github.com/charmbracelet/huh)
- [charmbracelet organization page (GitHub)](https://github.com/charmbracelet)
- [Charm official site](https://charm.land/)
- [rivo/tview (GitHub)](https://github.com/rivo/tview)
- [gdamore/tcell (GitHub)](https://github.com/gdamore/tcell)
- [gizak/termui (GitHub)](https://github.com/gizak/termui)
- [mum4k/termdash (GitHub)](https://github.com/mum4k/termdash)
- [awesome-gocui/gocui (GitHub)](https://github.com/awesome-gocui/gocui)

### Example Applications

- [jesseduffield/lazygit (GitHub)](https://github.com/jesseduffield/lazygit)
- [jesseduffield/lazygit go.mod (raw)](https://raw.githubusercontent.com/jesseduffield/lazygit/master/go.mod) -
  confirms the tcell-not-gocui dependency claim above.
- [derailed/k9s (GitHub)](https://github.com/derailed/k9s)
- [dlvhdr/gh-dash (GitHub)](https://github.com/dlvhdr/gh-dash)
- [charmbracelet/glow (GitHub)](https://github.com/charmbracelet/glow)
- [yorukot/superfile (GitHub)](https://github.com/yorukot/superfile)
- [twpayne/chezmoi (GitHub)](https://github.com/twpayne/chezmoi)
- [rothgar/awesome-tuis (GitHub)](https://github.com/rothgar/awesome-tuis) - curated list, checked
  for legitimacy (active, community-maintained, PR-accepting).

### Further Local Reading

- `01-principles.md` - the Elm Architecture background behind Bubble Tea's design.
- `02-anthropic-and-ai-clis.md` - opencode's original Bubble Tea/Lip Gloss implementation.
