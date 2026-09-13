---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# 5. Python TUI Frameworks

## 5.1 Textual

[Textual](https://github.com/Textualize/textual) ([textual.textualize.io](https://textual.textualize.io/)),
by Will McGugan, is a component-based application framework modeled on web development patterns.
It composes a widget tree that mirrors a DOM-like hierarchy -- widgets nest inside
containers/screens -- and layout/appearance are controlled by a CSS-like stylesheet system rather
than imperative layout code. Stylesheets use the `.tcss` extension (distinct from browser CSS) and
support type selectors (matching a widget's Python class, including base classes), ID selectors
(`#dialog`), class selectors (`.success`), the universal selector (`*`), pseudo-classes (`:hover`,
`:focus`, `:disabled`), descendant/child combinators, and CSS nesting with the `&` parent
selector.

The framework is asynchronous at its core (built on Python's `asyncio`) but doesn't force async
onto simple synchronous handlers. All interaction flows through a message-driven event system
managed by a `MessagePump`, with events bubbling from child widgets up to ancestors --
conceptually similar to DOM event bubbling.

**Reactive attributes.** Declared via the `reactive()` descriptor at class level (e.g.
`count = reactive(0)`). Changing a reactive attribute automatically triggers a refresh; multiple
reactive changes within one update cycle are coalesced into a single refresh. `watch_<name>`
methods fire when a value actually changes (identical re-assignment is skipped); `validate_<name>`
methods can intercept/coerce incoming values; `compute_<name>` methods derive computed reactive
values; `recompose=True` can trigger full child-widget rebuilds. This gives declarative
state-to-UI binding without manual update bookkeeping -- a different route to the same
state-drives-render idea as the Elm Architecture in [1.6](01-principles.md#16-architecture-the-elm-architecture-tea),
though Textual's model is reactive-attribute-driven rather than a single centralized `update`
function.

**Relationship to Rich.** Textual is built directly on top of Rich, its sister project by the same
author/company. Rich supplies the low-level terminal rendering primitives (styled text, color,
layout renderables); Textual is the full application framework layered on top -- widgets, DOM
composition, CSS, event loop, focus/input handling -- that uses Rich's renderables as the actual
paint layer for individual widgets.

**Web export.** Textual apps can run unmodified in a terminal or a browser. `textual serve` (part
of the `textual-serve` project) locally serves an app to a browser tab. A separate project,
[Textual Web](https://github.com/Textualize/textual-web), provides firewall-busting tunneling to
publish a running TUI/terminal session to a public URL for remote/multi-user access -- confirmed
still in **beta** (actively soliciting community testing), MIT-licensed, with noted limitations
around color fidelity and mobile UX.

**Devtools.** The `textual-dev` package/`textual` CLI provides `textual run --dev` for live CSS
editing (edits reflect in the running app within milliseconds, no restart); `textual console`, a
separate process that receives print/log output and app events over a socket so `print()` calls
don't corrupt the TUI's rendered frame (supports `-v` for verbose events like keypresses/clicks,
`-x` to exclude message groups, a custom `--port`); and a `log()` function plus a `TextualHandler`
for integrating the standard `logging` module into the devtools console.

**Maturity and a status change worth knowing.** Textual reached its 1.0 milestone in December
2024. GitHub: ~36.9k stars, ~1.3k forks, 13,000+ commits, MIT license. Textualize the *company*
wound down in 2025 -- McGugan announced in a May 2025 post,
["The future of Textualize"](https://textual.textualize.io/blog/2025/05/07/the-future-of-textualize/),
that the company couldn't find a sustainable business model and was closing, but stated both
Textual and Rich would continue as open-source projects under his personal maintenance, calling
Textual "mature and battle-tested." This is borne out by continued releases: PyPI shows Textual at
v8.2.8 (June 2026) -- active maintenance has in fact continued post-shutdown, worth flagging as
"strong project, no more funded company behind it" rather than either "abandoned" or "corporately
backed."

## 5.2 Rich (Standalone)

[Rich](https://github.com/textualize/rich) is the terminal rendering/formatting library Textual is
built on, but it's heavily used standalone by CLIs that don't need a full TUI. Core capabilities:

- **Pretty-printing/inspection** -- an `inspect()` function and `pretty` module that auto-format
  Python objects/data structures with syntax highlighting.
- **Tables** -- a `Table` class rendering flexible Unicode-box tables that auto-resize columns to
  terminal width.
- **Progress bars** -- flicker-free, multiple simultaneous progress bars (`rich.progress`,
  including a simple `track()` wrapper for iterables). See
  [1.4](01-principles.md#14-visual-and-styling-conventions) for progress-indicator design
  guidance generally.
- **Tracebacks** -- enhanced, more-readable Python tracebacks showing more surrounding code than
  the stdlib default.
- **Markdown/syntax rendering** -- Markdown-to-terminal rendering and Pygments-backed syntax
  highlighting for code blocks.
- **Console markup** -- a BBCode-like inline markup syntax for styling text, plus a
  `logging.Handler` integration for colorized/structured log output.

MIT licensed, ~57k GitHub stars, ~2.3k forks. PyPI shows Rich at v15.0.0 (April 2026) -- actively
maintained. Notable consumers include pip (uses Rich for terminal output) and httpx (optional
`httpx[cli]` Rich integration), plus it underpins Textual itself.

## 5.3 Other Python TUI Libraries

| Library | Style | License | Status |
| --- | --- | --- | --- |
| **urwid** ([urwid.org](http://urwid.org/)) | Widget-based console UI library, one of the oldest in this space | LGPL-2.1-or-later | Still actively released -- PyPI shows v4.0.8 (July 2026). Real production usage: `wicd-curses` (the Wicd network manager's curses interface) and `s-tui` (terminal CPU stress/monitoring tool) are both built on it. Its widget set/architecture is often described as harder to extend than newer frameworks. |
| **prompt_toolkit** ([prompt-toolkit/python-prompt-toolkit](https://github.com/prompt-toolkit/python-prompt-toolkit)) | Purpose-built for interactive command-line apps and REPLs rather than full-screen dashboard TUIs: syntax highlighting, multi-line editing, auto-completion, Vi/Emacs keybindings, mouse support | BSD-3-Clause | Actively maintained -- PyPI shows v3.0.53 (July 2026); ~10.5k stars. Powers ptpython and IPython. Architecture emphasizes small composable functions, no global state (multiple independent instances per process are supported), and a layered API from low-level primitives up to high-level helpers. |
| **npyscreen** | Curses-based forms/widget framework for building form-driven console apps quickly | BSD-3-Clause | Maintained but sparse -- version 5.0 was described in its own README as "the first release in 10 years," fixing Python 3.14 compatibility and dropping Python 2 support. Best characterized as maintained-for-compatibility rather than active feature development. |
| **py_cui** | Grid-layout TUI framework, explicitly inspired by Tkinter's grid geometry manager and Go's gocui, built on `curses` (+ `windows-curses` for Windows) | BSD-3-Clause | Effectively stale -- latest PyPI release is 0.1.6 (~2023), no recent releases, still pre-1.0 versioning. Largely superseded by Textual for new full-screen TUI development. |

Overall trend: urwid and prompt_toolkit remain genuinely active and serve needs Textual doesn't
directly target (prompt_toolkit for REPL/line-editing UX specifically; urwid for lightweight or
legacy widget apps). npyscreen and py_cui are effectively legacy/low-activity.

## 5.4 Best-in-Class Open-Source Python TUI Applications

- **Harlequin** ([tconbeer/harlequin](https://github.com/tconbeer/harlequin),
  [harlequin.sh](https://harlequin.sh/)) -- "The SQL IDE for Your Terminal." Built on Textual.
  Ships a data catalog (schema/table browser), query editor, and results viewer in one TUI;
  built-in support for DuckDB and SQLite3, with adapter plugins extending to Postgres, MySQL/
  MariaDB, ODBC, and others. MIT licensed. A good UX study for multi-pane data-app layout,
  theming, and a plugin/adapter architecture layered on a TUI.
- **Dolphie** ([charles-001/dolphie](https://github.com/charles-001/dolphie)) -- real-time MySQL/
  MariaDB/ProxySQL monitoring, "single pane of glass." Built on Textual. Notable UX patterns:
  multiple switchable/simultaneous panels (dashboard, processlist, graphs, replication, metadata
  locks), configurable-interval live refresh (default 1s), a record-and-replay feature capturing
  live sessions for later scrubbing/investigation, tabbed multi-host connections with per-tab
  color/title customization, and a daemon mode for unattended background recording. GPL-3.0
  licensed. A strong example of a high-density, real-time ops-monitoring TUI.
- **Posting** ([darrenburns/posting](https://github.com/darrenburns/posting)) -- a Postman/
  Insomnia-style HTTP client that lives entirely in the terminal. Built with Textual. UX
  highlights: works over SSH (unlike GUI clients), requests stored as plain YAML on disk
  (diffable/version-controllable), Vim-style keys and fully customizable keybindings, jump-mode
  navigation, tree-sitter-based syntax highlighting, a command palette, and support for running
  Python pre/post-request scripts plus importing curl commands and Postman collections.
  Apache-2.0 licensed. A good example of a keyboard-first, config-as-code TUI replacing a
  traditionally GUI-only workflow.
- **Trogon** ([Textualize/trogon](https://github.com/Textualize/trogon)) -- auto-generates a
  Textual TUI directly from a Click (or Typer) CLI's argument/option definitions. Mechanism: it
  introspects the Click app to extract a schema of options, switches, arguments, and help text,
  then builds an interactive form-like Textual UI from that schema and wires up a new `tui`
  subcommand that launches it. The UX pattern is notable on its own merits: CLIs "reward repeated
  use but lack discoverability," and Trogon's generated UI lets users browse and rediscover flags
  and compose+preview a command interactively before running it -- essentially a zero-effort
  discoverability layer bolted onto an existing argument parser (compare to the footer/`?`-overlay
  discoverability pattern in [1.2](01-principles.md#12-interaction-design-for-terminals), achieved
  here at the framework level instead of by hand). Integration is minimal, roughly two lines of
  code. MIT licensed, actively maintained.

Curated lists confirmed as legitimate, active community indexes:
[Kludex/awesome-textual](https://github.com/Kludex/awesome-textual) and
[oleksis/awesome-textualize-projects](https://oleksis.github.io/awesome-textualize-projects/) --
useful for browsing further examples beyond the headline apps above.

**Older-generation contrast: Glances.** [Glances](https://github.com/nicolargo/glances)
(`nicolargo/glances`) is a cross-platform `top`/`htop`-style system monitor, ~33.3k stars,
LGPL-3.0, very active. **Correction to a common assumption**: Glances is *not* built on urwid --
verified directly against its source (`glances/outputs/glances_curses.py`), it imports Python's
standard `curses` module directly (plus `curses.panel`, `curses.textpad`), with `windows-curses`
providing Windows support, on top of `psutil` for the underlying metrics. It also ships a REST API
and web-UI mode, not just the curses TUI. A good contrast case: raw-curses, non-declarative,
imperative-refresh UI code versus the declarative/reactive/CSS-styled model of Textual apps -- but
the "built on urwid" framing shouldn't be repeated as fact. If an urwid-based example is wanted
instead, `wicd-curses` or `s-tui` (5.3, above) are the verified ones.

## 5.5 Comparison Table

| Library | Architecture style | Learning curve | Best-fit use case | License | Maintenance status |
| --- | --- | --- | --- | --- | --- |
| Textual | Reactive widget/DOM tree, CSS-like stylesheets, async message-passing event system | Moderate-high -- own concepts: reactive descriptors, CSS, workers | Full-screen, polished, app-grade TUIs; needs browser export too | MIT | Active; v8.2.8 (Jun 2026). Funded company shut down 2025; project continues under the original author as community/personal OSS maintenance |
| Rich (standalone) | Renderable/Console rendering primitives, not a full app framework | Low | Pretty CLI output: tables, progress bars, tracebacks, markdown, logging -- without building a TUI | MIT | Active; v15.0.0 (Apr 2026) |
| urwid | Classic widget-tree, callback-driven event loop | Moderate | Lightweight full-screen TUIs, especially where a long-lived stable API matters | LGPL-2.1-or-later | Active; v4.0.8 (Jul 2026) |
| prompt_toolkit | Layered primitives up to a high-level API; line-editing/REPL buffer model | Moderate | Interactive shells, REPLs, custom line editors (not full dashboard TUIs) | BSD-3-Clause | Active; v3.0.53 (Jul 2026); powers ptpython, IPython |
| npyscreen | Curses-based forms/widgets framework | Low-moderate | Quick form-driven admin/config screens | BSD-3-Clause | Low-activity; v5.0 was the first release in ~10 years |
| py_cui | Tkinter-style grid layout over curses | Low | Simple grid-based dashboards | BSD-3-Clause | Stale; latest PyPI release ~0.1.6 (~2023) |

## References

### Official Documentation

- [Textualize/textual (GitHub)](https://github.com/Textualize/textual)
- [Textual - Home](https://textual.textualize.io/)
- [Textual CSS guide](https://textual.textualize.io/guide/CSS/)
- [Textual Reactivity guide](https://textual.textualize.io/guide/reactivity/)
- [Textual Devtools guide](https://textual.textualize.io/guide/devtools/)
- [The future of Textualize (Textual blog, May 2025)](https://textual.textualize.io/blog/2025/05/07/the-future-of-textualize/)
- [Textual on PyPI](https://pypi.org/project/textual/)
- [Textualize/textual-web (GitHub)](https://github.com/Textualize/textual-web)
- [Textualize/rich (GitHub)](https://github.com/textualize/rich)
- [Rich documentation - Introduction](https://rich.readthedocs.io/en/latest/introduction.html)
- [Rich on PyPI](https://pypi.org/project/rich/)
- [Urwid - Home](http://urwid.org/)
- [Urwid on PyPI](https://pypi.org/project/urwid/)
- [python-prompt-toolkit (GitHub)](https://github.com/prompt-toolkit/python-prompt-toolkit)
- [prompt_toolkit on PyPI](https://pypi.org/project/prompt_toolkit/)
- [npcole/npyscreen (GitHub)](https://github.com/npcole/npyscreen)
- [npyscreen on PyPI](https://pypi.org/project/npyscreen/)
- [jwlodek/py_cui (GitHub)](https://github.com/jwlodek/py_cui)

### Example Applications

- [tconbeer/harlequin (GitHub)](https://github.com/tconbeer/harlequin)
- [Harlequin - harlequin.sh](https://harlequin.sh/)
- [charles-001/dolphie (GitHub)](https://github.com/charles-001/dolphie)
- [darrenburns/posting (GitHub)](https://github.com/darrenburns/posting)
- [Textualize/trogon (GitHub)](https://github.com/Textualize/trogon)
- [Kludex/awesome-textual (GitHub)](https://github.com/Kludex/awesome-textual)
- [oleksis/awesome-textualize-projects](https://oleksis.github.io/awesome-textualize-projects/)
- [nicolargo/glances (GitHub)](https://github.com/nicolargo/glances)
- [glances_curses.py source (nicolargo/glances)](https://raw.githubusercontent.com/nicolargo/glances/develop/glances/outputs/glances_curses.py) -
  confirms Glances uses raw curses, not urwid.
- [urwid/urwid - Application list wiki](https://github.com/urwid/urwid/wiki/Application-list)
- [amanusk/s-tui (GitHub)](https://github.com/amanusk/s-tui)

### Further Local Reading

- `01-principles.md` - the discoverability principle Trogon implements at the framework level.
