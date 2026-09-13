---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# 4. Rust TUI Frameworks

## 4.1 ratatui

[ratatui](https://github.com/ratatui/ratatui) ([ratatui.rs](https://ratatui.rs/)) is the
community-maintained crate for building terminal UIs in Rust. MIT licensed, ~22.1k GitHub stars,
5,200+ dependent crates, 42.4M crates.io downloads. Used by teams at Netflix, OpenAI, and AWS
for internal dev tools; it is also what [OpenAI's Codex CLI](02-anthropic-and-ai-clis.md)
is built on.

**Rendering architecture: immediate mode, not a retained widget tree.** Per the
[official rendering docs](https://ratatui.rs/concepts/rendering/): *"Immediate mode rendering is
a UI paradigm where the UI is recreated every frame. Instead of creating a fixed set of UI widgets
and updating their state, you 'draw' your UI from scratch in every frame based on the current
application state."* Concretely, the app loop calls `terminal.draw(|frame| { ... })` every tick,
constructing widget values fresh from current app state and calling `frame.render_widget(...)`.
There's no persistent widget object graph the framework mutates for you -- no "find this button
and update its label." Internally, ratatui still does double-buffer diffing (comparing the newly
drawn frame's cell buffer against the previous frame and writing only the changed cells to the
terminal), which is what gives sub-millisecond rendering despite redrawing the whole UI
description each frame.

This is the key conceptual contrast with **retained-mode** frameworks (cursive, below; most
desktop GUI toolkits): you build a widget tree once and mutate node state, and the framework
tracks what changed and repaints only the affected subtree, owning event dispatch to the right
widget. Immediate mode gives simplicity and flexibility -- the UI is a pure function of state, with
no state-sync bugs between "widget state" and "app state" -- but pushes render-loop and event-loop
orchestration entirely onto the application, which is why the ecosystem grew Elm/React-style
wrapper crates on top (see below).

**Backend crates.** ratatui doesn't talk to the terminal directly; it delegates raw-mode setup,
cursor control, and input events to a backend crate, then draws styled cells into a buffer the
backend flushes to the screen. Per the
[backend comparison page](https://ratatui.rs/concepts/backends/comparison/):

| Backend | Platform | Notes |
| --- | --- | --- |
| **crossterm** (default) | Cross-platform, including Windows 7+ | No background threads for input, actively maintained, MIT. Used by ratatui, cursive, and broot. The recommended default "for most tasks." |
| **termion** | Unix-only (Linux/macOS/BSD/Redox) | Pure Rust, spawns threads for input/resize handling. MIT/X11. Still labeled "stable" by maintainers, but crossterm has largely superseded it in new projects. |
| **termwiz** | Cross-platform | From the WezTerm project; recommended specifically "for Wezterm-only TUIs." |
| **termina** | Cross-platform | Newer, lower-level (exposes raw escape sequences rather than crossterm's higher-level event abstraction); helix-editor is migrating to it (see 4.3). |
| **TestBackend** | N/A | In-memory backend for unit-testing UI output without a real terminal. |

**Widget set.** Charts, sparklines, tables, gauges, scrollable lists, progress bars,
wrapping paragraphs/text blocks, and a constraint-based layout engine (percentage/fixed/min/max
constraints, nested horizontal/vertical splits) that adapts to terminal size -- see
[1.2](01-principles.md#12-interaction-design-for-terminals) for why constraint-based layout
matters for resize handling generally.

**Ecosystem crates built on ratatui:**

- **tui-realm** ([veeso/tui-realm](https://github.com/veeso/tui-realm)) -- an Elm/React-inspired
  application framework layered on top of ratatui's raw immediate-mode API. Introduces a `View`
  that owns mounting/unmounting, focus, and event routing for reusable Components with
  props/state, communicating via a Message/Event update loop -- i.e. it re-adds retained-mode-like
  component ergonomics on top of ratatui's immediate-mode core.
- **tui-textarea** / **ratatui-textarea** ([rhysd/tui-textarea](https://github.com/rhysd/tui-textarea),
  now also at [ratatui/ratatui-textarea](https://github.com/ratatui/ratatui-textarea)) -- a
  multi-line text-editor widget.
- **ratatui-kit** -- a newer React-style component framework with hooks, routing, and async state.
- **tui-tree-widget**, **ratatui-image** (sixel/unicode-halfblock image rendering), **malevich**
  (plotting widget: line/scatter/bar/histogram/heatmap/violin).
- [ratatui/templates](https://github.com/ratatui/templates) -- official `cargo-generate` starter
  templates for bootstrapping a ratatui + crossterm app.
- [ratatui/awesome-ratatui](https://github.com/ratatui/awesome-ratatui) -- the curated list of
  ecosystem crates and showcase apps, a good source for further examples.

### History: from tui-rs to ratatui, a cautionary tale

Verified via [Orhun Parmaksiz's blog post on the transition](https://blog.orhun.dev/ratatui-0-23-0/),
[orhun/tui-rs-revival](https://github.com/orhun/tui-rs-revival), and the
[archived tui-rs repo](https://github.com/fdehau/tui-rs) itself:

- Aug 14, 2022: a "Future of tui-rs" GitHub discussion opened, flagging that original author
  Florian Dehau had gone quiet on maintenance.
- Feb 2, 2023: a community Discord formed to discuss forking; Feb 8, Dehau responded positively
  with a plan to transfer ownership; the fork was created Feb 14, 2023.
- Mar 19, 2023: ratatui 0.20.0 shipped -- backward-compatible with tui-rs, migration was
  effectively "rename the dependency."
- Aug 7, 2023: Dehau formally archived `fdehau/tui-rs`. The repo now displays: *"August 2023: This
  crate is no longer maintained. See ratatui for an actively maintained fork."*

Orhun Parmaksiz led the fork/revival effort. The lesson for anyone evaluating a framework: a
single-maintainer crate at the center of an entire GUI ecosystem went quiet with no succession
plan for months before the community had to organize a fork outside the original repo, and it was
only clean because the original author cooperated rather than staying silent or objecting. Any
decision to build on a single-crate ecosystem should weigh "what happens if this maintainer
disappears" as a real, precedented risk in exactly this space -- see also spotify-tui's fate in
4.3.

## 4.2 Other Rust TUI/Terminal Libraries

**cursive** ([gyscos/cursive](https://github.com/gyscos/cursive), MIT, actively maintained).
Philosophically the opposite of ratatui: **retained-mode, widget-tree based**. You construct a
tree of Views/Dialogs once, and cursive owns the render loop, diffing, and event dispatch to the
focused widget -- closer to a traditional GUI toolkit than to ratatui's redraw-from-state model.
Uses crossterm as its default backend, pluggable. Good fit for apps that feel more like
traditional dialog-driven forms than dashboards; steeper conceptual model (callbacks, focus
management) but less manual render-loop bookkeeping than ratatui.

**crossterm vs. termion -- backend crates, not frameworks.** Neither draws widgets, lays out UI,
or manages app state; both are thin, low-level wrappers over raw terminal control: entering/
leaving raw mode and the alternate screen, moving the cursor, setting colors/styles per cell, and
reading raw keyboard/mouse/resize events. A "TUI framework" (ratatui, cursive) sits on top of one
of these and adds the widget/layout/rendering abstraction. crossterm is pure Rust,
cross-platform including Windows 7+, has no background threads for input, is MIT licensed, and is
the safe default recommendation. termion is pure Rust, Unix-only, spawns threads for input/resize,
MIT/X11 licensed, and is a reasonable choice if you deliberately don't need Windows and want a
lighter dependency.

**termwiz and termina.** termwiz (WezTerm's terminal crate) is usable standalone or as a ratatui
backend. termina is a newer, lower-level crate exposing raw escape sequences instead of
crossterm's higher-level event model -- see helix-editor's migration in 4.3.

## 4.3 Best-in-Class Open-Source Rust TUI Applications

- **gitui** ([gitui-org/gitui](https://github.com/gitui-org/gitui), formerly
  `extrawurst/gitui`, ~22.4k stars, MIT, actively maintained). Fully keyboard-driven git client
  with context-sensitive help so users never need to memorize a keybinding chart; per-hunk/
  per-line staging; async git calls keep the UI responsive on huge repos (benchmarked: a 900k+
  commit, Linux-kernel-scale repo history parsed in 24 seconds using 0.17GB RAM without freezing).
  A good study case for keeping an immediate-mode UI responsive when the underlying operation is
  slow.
- **bottom / btm** ([ClementTsang/bottom](https://github.com/ClementTsang/bottom), ~13.9k stars,
  MIT, actively maintained). Real-time multi-widget dashboard (CPU/mem/network/disk/temp/battery
  graphs), an htop-inspired "basic mode" for simpler needs, widget-zoom/expand-to-fullscreen,
  tree-mode process view, and fully customizable layouts/themes -- a strong reference for
  constraint-based multi-pane dashboard layout done well.
- **zellij** ([zellij-org/zellij](https://github.com/zellij-org/zellij), ~34.8k stars, MIT,
  actively maintained, WASM plugin system, floating/stacked panes, built-in web client). Its
  onboarding/discoverability UX is its most-cited strength: an always-visible, context-aware
  status/hint bar at the bottom of the screen shows exactly which keys are live for the current
  mode, updating live as the mode changes -- e.g. entering pane mode shows pane-mode keys. Per an
  [independent writeup](https://timvw.be/2026/02/12/tmux-training-wheels-a-zellij-inspired-shortcut-hints-bar/),
  this "removes the need for an external reference entirely," and was influential enough that the
  author built a tmux plugin cloning the idea. Arguably the single best concrete discoverability
  pattern in this guide -- see [1.2](01-principles.md#12-interaction-design-for-terminals).
- **atuin** ([atuinsh/atuin](https://github.com/atuinsh/atuin), ~13.7k stars, MIT, actively
  maintained). A full-screen fuzzy-search TUI over shell history (bound to Ctrl+R/Alt+R), with
  scoped toggles (global/session/host/directory) -- a good reference for search-as-you-type over a
  large dataset in a terminal popup.
- **bandwhich** ([imsnif/bandwhich](https://github.com/imsnif/bandwhich), MIT). A responsive
  tabular layout (process/connection/remote-host views) that collapses gracefully to less
  information in small terminals, with background DNS resolution so the UI doesn't block on
  lookups. Maintenance note: the repo explicitly states it's in passive maintenance -- "critical
  issues will be addressed, but no new features are being worked on" -- a good UX study, but not a
  model of an actively evolving codebase.
- **helix** ([helix-editor/helix](https://github.com/helix-editor/helix), MPL-2.0, ~45.8k stars,
  very actively maintained). Not built on ratatui: it vendors its own `helix-tui` crate, a fork of
  the original tui-rs "mainly relying on the double buffer implementation and render diffing,
  side-stepping its widget and layouting" -- i.e. helix kept tui-rs's rendering core but wrote its
  own UI/editor widgets rather than using the shared widget set. It also runs a soft fork of
  crossterm ([helix-editor/crossterm](https://github.com/helix-editor/crossterm)) to experiment
  with terminal features (theme-mode detection, Kitty keyboard protocol, synchronized-output
  rendering) ahead of upstreaming, and is mid-migration from crossterm to termina
  ([PR #13307](https://github.com/helix-editor/helix/pull/13307)). UX value: selection-first
  modal editing (Kakoune-inherited -- select, then act, rather than vim's act-then-move) and
  built-in discoverable keymaps. Important nuance: helix is a terminal-UX exemplar but an
  architectural outlier -- it shows that a serious application may need to fork its rendering
  layer rather than depend on the shared ecosystem crate wholesale.
- **gping** ([orf/gping](https://github.com/orf/gping), ~12.6k stars, MIT, actively maintained).
  "Ping but with a live graph," multi-host overlay graphs, a `--cmd` mode to graph arbitrary
  command execution time. A good minimal-scope reference (single-screen, single-purpose TUI) to
  contrast against the larger dashboard apps above.
- **spotify-tui, a second abandonment case study.** The originally well-known
  `Rigellute/spotify-tui` is archived and broken against current Spotify API changes; a community
  continuation, [spotatui](https://github.com/LargeModGames/spotatui), is now the actively
  maintained option -- worth a mention alongside the tui-rs story in 4.1 if reinforcing that
  ecosystem-abandonment theme.

## 4.4 Comparison Table

| Library | Architecture style | Learning curve | Best-fit use case | License | Maintenance status |
| --- | --- | --- | --- | --- | --- |
| ratatui | Immediate-mode (redraw-from-state each frame, double-buffer diffing) | Moderate -- no built-in app framework, you own the render/event loop | Dashboards, monitors, custom-widget apps, anything wanting full control over draw logic | MIT | Actively maintained (22.1k stars, official tui-rs successor) |
| tui-rs (original) | Immediate-mode | N/A -- do not start new projects on this | Historical / legacy only | MIT | Archived Aug 2023 |
| cursive | Retained-mode widget tree | Moderate -- different mental model (views/callbacks/focus) than immediate-mode | Form-like / dialog-driven apps, apps that feel more like a traditional GUI | MIT | Actively maintained |
| tui-realm (on ratatui) | Elm/React-style component framework atop ratatui's immediate mode | Moderate-high -- extra abstraction on top of ratatui | Larger ratatui apps wanting component reuse and structured state updates | MIT | Actively maintained |
| crossterm | Low-level terminal backend, not a UI framework | Low | The I/O layer under a TUI framework, or hand-rolled minimal terminal apps | MIT | Actively maintained; cross-platform including Windows |
| termion | Low-level terminal backend, not a UI framework | Low | Unix-only apps wanting a lighter dependency than crossterm | MIT/X11 | Maintained but lower activity; no Windows support |

## References

### Official Documentation

- [ratatui/ratatui (GitHub)](https://github.com/ratatui/ratatui)
- [Ratatui official site](https://ratatui.rs/)
- [Ratatui: Rendering concepts](https://ratatui.rs/concepts/rendering/)
- [Ratatui: Backends](https://ratatui.rs/concepts/backends/)
- [Ratatui: Backend comparison](https://ratatui.rs/concepts/backends/comparison/)
- [ratatui/awesome-ratatui (GitHub)](https://github.com/ratatui/awesome-ratatui)
- [ratatui/templates (GitHub)](https://github.com/ratatui/templates)
- [ratatui/ratatui-textarea (GitHub)](https://github.com/ratatui/ratatui-textarea)
- [rhysd/tui-textarea (GitHub)](https://github.com/rhysd/tui-textarea)
- [veeso/tui-realm (GitHub)](https://github.com/veeso/tui-realm)
- [gyscos/cursive (GitHub)](https://github.com/gyscos/cursive)
- [crossterm-rs/crossterm (GitHub)](https://github.com/crossterm-rs/crossterm)
- [redox-os/termion (GitHub)](https://github.com/redox-os/termion)

### The tui-rs to ratatui Transition

- [From tui-rs to Ratatui: 6 Months of Cooking Up Rust TUIs (Orhun's Blog)](https://blog.orhun.dev/ratatui-0-23-0/)
- [orhun/tui-rs-revival (GitHub)](https://github.com/orhun/tui-rs-revival)
- [fdehau/tui-rs (archived GitHub repo)](https://github.com/fdehau/tui-rs)

### Example Applications

- [gitui-org/gitui (GitHub)](https://github.com/gitui-org/gitui)
- [ClementTsang/bottom (GitHub)](https://github.com/ClementTsang/bottom)
- [zellij-org/zellij (GitHub)](https://github.com/zellij-org/zellij)
- [Tmux Training Wheels: A Zellij-Inspired Shortcut Hints Bar (timvw.be)](https://timvw.be/2026/02/12/tmux-training-wheels-a-zellij-inspired-shortcut-hints-bar/)
- [atuinsh/atuin (GitHub)](https://github.com/atuinsh/atuin)
- [imsnif/bandwhich (GitHub)](https://github.com/imsnif/bandwhich)
- [helix-editor/helix (GitHub)](https://github.com/helix-editor/helix)
- [helix-editor/crossterm (GitHub, soft fork)](https://github.com/helix-editor/crossterm)
- [helix/helix-tui/README.md (GitHub)](https://github.com/helix-editor/helix/blob/master/helix-tui/README.md)
- [Switch terminal backend from Crossterm to Termina, PR #13307 (GitHub)](https://github.com/helix-editor/helix/pull/13307)
- [orf/gping (GitHub)](https://github.com/orf/gping)
- [Rigellute/spotify-tui (GitHub, archived)](https://github.com/Rigellute/spotify-tui)
- [LargeModGames/spotatui (GitHub)](https://github.com/LargeModGames/spotatui)

### Further Local Reading

- `02-anthropic-and-ai-clis.md` - OpenAI Codex CLI, built on ratatui.
