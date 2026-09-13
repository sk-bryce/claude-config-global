---
audience: human
created: 2026-08-08
updated: 2026-08-19
---

# 1. Principles and Guidelines

This chapter covers the interaction-design and accessibility principles that apply to any
terminal application, independent of language or framework. Read this before the framework
chapters -- everything after this assumes it.

## 1.1 Established CLI Design Guidelines

Three layers of convention sit underneath modern CLI/TUI design, from formal grammar up to
opinionated UX judgment. It helps to know which layer a given rule comes from, because it tells
you how much you're allowed to deviate.

### POSIX Utility Conventions (the formal grammar)

[POSIX's Utility Conventions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)
(The Open Group) is the formal ancestor of every "getopt-style" flag parser:

- Utility names: 2-9 lowercase alphanumeric characters.
- Options are single alphanumeric characters preceded by `-`; several no-argument options may be
  bundled behind one `-` (`-abc` is equivalent to `-a -b -c`).
- An option's argument may be a separate token or concatenated (`-o foo` is equivalent to `-ofoo`).
- `--` terminates option parsing; everything after it is a literal operand even if it starts
  with `-`.
- `-` as a bare operand conventionally means stdin/stdout.

### GNU Coding Standards (long options and --help)

The [GNU Coding Standards](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html)
push long-named options (`getopt_long`) as equivalents to every short option, specifically so
flag names stay consistent and memorable across an entire toolset, and GNU's own `getopt`
conventionally permits options anywhere among arguments (not just before operands) unless `--` is
used. Every program is expected to support
[`--help`](https://www.gnu.org/prep/standards/html_node/_002d_002dhelp.html) (usage to stdout,
exit 0) and `--version`, and `--help` output is expected to end with a bug-report address and
project homepage -- the direct ancestor of the "where to file a bug" footer many modern CLIs
still print.

### 12-Factor CLI Apps (the operational checklist)

[12-Factor CLI Apps](https://jdxcode.medium.com/12-factor-cli-apps-dd3c227a0e46), from the team
behind the Heroku CLI, modeled explicitly on the Twelve-Factor App methodology. Twelve concrete
rules, most still directly relevant:

1. Great help is essential -- multiple triggers (`--help`, `-h`, a `help` subcommand), plus shell
   completion as another form of help.
2. Prefer flags to positional args, except where the argument is self-evident (a filename).
3. Make the version discoverable (`version`, `--version`, `-V`), and include it in any User-Agent
   header the CLI sends, for support/debugging.
4. Mind the streams -- real output to stdout, diagnostics/logs to stderr, so redirection doesn't
   silently drop warnings.
5. Handle things going wrong with structured errors (code, title, description, fix, URL); gate
   debug output behind an env var; keep a persistent, timestamped error log.
6. Be fancy, but detect terminal capability first, and respect `TERM=dumb`, `NO_COLOR`, and
   `--no-color`.
7. Prompt if you can, but every prompted value must also be settable via a flag for automation,
   and destructive operations must be confirmed.
8. Use tables: one record per row, no borders, for parseability; support `--columns`, `--sort`,
   `--filter`, `--no-truncate`, `--no-headers`, and JSON/CSV output modes.
9. Be speedy -- target 100-500ms startup, and use progress indicators to manage perceived speed
   on longer operations.
10. Encourage contributions with clear docs and a code of conduct.
11. Be clear about subcommands -- hierarchical, colon-separated names (`heroku domains:add`)
    visually separate the command path from its arguments.
12. Follow the XDG spec: config in `~/.config/<app>`, data in `~/.local/share/<app>`, cache in
    `~/.cache/<app>` (with platform-appropriate equivalents on macOS/Windows).

### clig.dev -- Command Line Interface Guidelines (the UX judgment layer)

[clig.dev](https://clig.dev/) (created by Aanand Prasad and collaborators, drawing on experience
building Docker Compose and the Heroku CLI; mirrored at the community-maintained
[cli-guidelines/cli-guidelines](https://github.com/cli-guidelines/cli-guidelines)) is probably the
single most useful modern reference for this whole topic. Its seven-principle philosophy:

1. **Human-first design** -- prioritize the person typing, not just machine-to-machine piping.
2. **Simple parts that compose** -- stdin/stdout/stderr, exit codes, and plain text or JSON so
   tools chain together.
3. **Consistency across programs** -- reuse established flag names and behaviors so muscle memory
   transfers.
4. **Balanced information** -- avoid both silent-seeming programs and noisy ones that bury what
   matters.
5. **Discoverability** -- help, examples, and good errors matter as much as raw efficiency.
6. **Conversational interaction** -- expect trial-and-error; design for repeated invocation and
   iterative correction.
7. **Empathy and robustness** -- anticipate failure and edge cases; the details build trust.

Concrete rules worth internalizing directly:

- Help text: concise help on missing/bad args, full help on `-h`/`--help`; lead with common
  examples, not an exhaustive flag dump.
- Output: human-readable by default; machine-readable only behind an explicit flag (`--json`,
  `--plain`); one record per line in plain mode, no table borders.
- Never require a secret via a flag -- accept it via a file or stdin instead.
- Interactivity: only prompt if stdin is a TTY; always provide a `--no-input`-style escape hatch;
  confirm before destructive actions.
- Responsiveness: show *something* within 100ms so the tool feels alive.
- Config precedence, highest to lowest: flags > environment variables > project config > user
  config > system config.
- Subcommands: never silently allow arbitrary abbreviation of a subcommand name (you'll end up
  supporting it forever), and never invent an implicit default subcommand.

The guide explicitly endorses breaking its own rules when doing so is "demonstrably harmful to
productivity or user satisfaction," quoting Jef Raskin -- consistency is the default, not a
straitjacket.

**How the three layers relate**: cite POSIX/GNU when explaining *why* `--` and combinable short
flags behave the way they do; reach for 12-Factor CLI's checklist for mechanical items like XDG
paths and version/help plumbing; reach for clig.dev when making an actual UX judgment call.

## 1.2 Interaction Design for Terminals

**Keyboard navigation.** Vim's `hjkl` convention exists because Bill Joy wrote `vi` on an
ADM-3A terminal whose keyboard had arrows printed on those exact keys; it survives because it
keeps hands on the home row. Modern convention -- consistent across TUI apps and design guides --
is to support both `hjkl` and arrow keys rather than picking one, so vim-literate and
non-vim-literate users are both served.

**Discoverability.** clig.dev's discoverability principle, applied to a full-screen TUI, converges
on a layered pattern:

- A **footer/status bar** always shows the 3-5 most relevant keybindings for the current context,
  updating as the user moves between panes or modes.
- The **`?` key** is a widely adopted convention for opening a full help overlay listing every
  available keybinding, shown on demand rather than by default -- progressive disclosure applied
  specifically to keybindings.
- Help overlays should be **context-aware** (show what's actionable right now, not a global dump
  of every keybinding in the whole app), which keeps the "show me everything" mechanism itself
  from becoming noise.

**Progressive disclosure in a character grid.** The same idea recurs throughout: short help by
default with `--help` for the long form, the footer/`?`-overlay pattern above, and (see 1.5)
confirmation-prompt guidance that explicitly names progressive disclosure as a way to let users
reach more detail without cluttering the default view.

**Information density and hierarchy.** A character grid has no font size and no whitespace-heavy
card layout, so color and bold do the hierarchy work that typography and spacing do elsewhere --
clig.dev frames color/symbols as something to use *intentionally* to increase information
density, not decoratively. Borders and box-drawing can establish grouping the way whitespace does
in GUI design, but see 1.3 for the real accessibility cost of overusing them. And restraint is
itself a hierarchy technique: if everything is highlighted, nothing is.

**Responsive layout and terminal resize.** Terminals emit `SIGWINCH` on resize; a TUI that
ignores it either freezes its old layout or corrupts the screen. Practices worth adopting:

- Register a resize handler and recompute layout rather than assuming a fixed size.
- Use constraint-based layout (percentages, min/max, ratios) instead of hardcoded absolute
  positions, so the same layout logic scales from a small window to a wide one.
- Define and enforce a minimum supported size (80x24 is the conventional floor) and show an
  explicit "terminal too small" message below it, rather than rendering garbled output.
- Test at a few representative sizes (e.g. 80x24, 120x40, 200x60) -- resize bugs are easy to miss
  if you only ever develop at one window size.

**Mouse support: keyboard-first, mouse-optional.** Every feature must be reachable by keyboard;
mouse support (click-to-focus, scroll, drag-select) is additive, never load-bearing. A
mouse-only affordance breaks over SSH sessions without mouse-reporting support, breaks for
keyboard-preferring power users (the primary TUI audience), and is one more thing that can
misbehave across the variance of terminal emulators' mouse-reporting protocols. It's also an
accessibility issue in its own right -- see below.

## 1.3 Accessibility

### NO_COLOR

The [NO_COLOR](https://no-color.org/) informal spec: *"Command-line software which adds ANSI
color to its output by default should check for a `NO_COLOR` environment variable that, when
present and not an empty string (regardless of its value), prevents the addition of ANSI color."*
A few nuances worth preserving:

- Presence and non-emptiness is what matters, not the value.
- It only obligates software that adds color *by default* -- apps that are color-off-by-default
  have nothing to implement.
- An explicit user request for color (`--color=always`) should override `NO_COLOR` -- it's a
  default-behavior hint, not an absolute lock.
- It governs ANSI *color* specifically; bold/underline/italic styling is out of scope.
- It's a hint to the software, not a terminal-level capability switch.

### Detecting a light or dark terminal background

The dominant technique ([dystroy.org: "Adjust your application for a light or dark
terminal"](https://dystroy.org/blog/terminal-light/)) is the OSC 11 "dynamic colors" escape
sequence: query the terminal for its background color, get back an `rgb:RRRR/GGGG/BBBB`
response, compute luminance, and threshold around ~0.6 to decide light vs. dark. It's broadly
compatible across xterm-descended emulators on Unix/macOS but not universally reliable (some
terminals answer incorrectly; Windows support is inconsistent), so the recommended pattern is a
fallback chain: OSC 11 query first, then terminal-reported defaults or an env-var hint, and
ultimately a palette chosen to stay legible against either background rather than guessing wrong.
Charm's `glow` markdown renderer (see [Chapter 3](03-go-frameworks.md)) uses exactly this
technique to auto-pick a light or dark stylesheet.

### Screen readers: a genuinely unsolved problem

This deserves emphasis rather than a footnote: it is not solved, and no framework in this guide
has fully solved it. Per an investigative piece, ["The text mode lie: why modern TUIs are a
nightmare for accessibility"](https://xogium.me/the-text-mode-lie-why-modern-tuis-are-a-nightmare-for-accessibility)
(also syndicated on [OSnews](https://www.osnews.com/story/144892/the-text-mode-lie-why-modern-tuis-are-a-nightmare-for-accessibility/)),
the central problem is architectural: plain, linear-scrolling CLI output (newest content at the
bottom, streamed top to bottom) is exactly what screen readers are built for. Modern
framework-driven TUIs -- the piece names Ink, Bubble Tea, and tcell specifically -- instead treat
the terminal as a 2D grid and repaint it in place, which breaks the screen-reader model entirely.
Concrete mechanisms:

- **Cursor teleporting** -- redrawing spinners/timers/status lines moves the hardware cursor
  constantly; screen readers announce cursor-position changes, turning this into unintelligible
  audio spam.
- **Redraw-driven input lag** -- with large scrollback, a full-screen repaint on every keystroke
  can make input echo lag by seconds, because the framework prioritizes redraw over input
  handling.
- **Crashes on large re-renders** -- pasting a large text block that triggers a massive re-render
  has caused NVDA (a Windows screen reader) to crash outright.

What accessibility-conscious prior art does differently:

- `nano` and classic `vim` let the user disable/hide cursor tracking, avoiding the teleport
  problem.
- `menuconfig`-style UIs restrict cursor movement to a single column/focus target instead of free
  2D movement.
- `irssi` uses real VT100 **scrolling regions** instead of full-screen repaint, so most of the
  screen behaves like ordinary streamed text and only a small status region updates -- a genuine
  architectural mitigation, not just a UI nicety, and one that also happens to reduce bandwidth
  over SSH (see 1.4).
- A community-suggested mitigation: ship a flat, argument-based non-interactive CLI mode alongside
  the TUI, so screen-reader users have a working escape hatch entirely outside the 2D-rendering
  problem.

### Contrast, colorblindness, and color-only signaling

GitHub's own engineering blog, ["Building a more accessible GitHub
CLI"](https://github.blog/engineering/user-experience/building-a-more-accessible-github-cli/),
is a useful concrete case study of a real project addressing this:

- Replaced spinner *animations* with static text progress indicators for interactive prompts,
  because screen readers "do not handle [spinning glyphs] well."
- Rebuilt interactive prompts on Charm's [`huh`](https://github.com/charmbracelet/huh) form
  library specifically so speech-synthesis screen readers can accurately narrate prompts.
- Aligned their color palette to the 4-bit ANSI color set rather than 24-bit/truecolor hex values,
  specifically so users can override colors via their own terminal theme -- 4-bit colors are
  inherently themeable by the user's terminal config; arbitrary RGB is not.
- Fixed markdown-rendering colors that hadn't accounted for the terminal's actual background
  color, which was producing low-contrast text on some themes.
- Shipped a discoverable `gh a11y` entry point (v2.72.0+) as an ongoing feedback channel rather
  than a one-time fix.

General guidance, corroborated across multiple sources: never use color as the *sole* channel for
meaning -- pair it with an icon, label, or symbol (not just a red line, but a red line and a
`FAIL` marker). Avoid red/green, blue/green, and yellow/purple pairings specifically, since these
are the pairs most commonly indistinguishable under common forms of color vision deficiency.

## 1.4 Visual and Styling Conventions

**Box-drawing and icon fonts vs. ASCII fallback.** There is no reliable terminal-capability escape
sequence to detect whether a Nerd Font (a patched font with extra glyphs in the Unicode Private
Use Area) is actually installed and active -- this is a real, unsolved discoverability gap. In
practice, tools either require an explicit opt-in (a config flag) or default to plain ASCII/
standard-Unicode glyphs and treat icon-rich rendering as an explicit upgrade. Given the
accessibility findings above, a plain-ASCII fallback mode is doing double duty: it's both a
terminal-capability fallback and a meaningful accessibility affordance.

**Markdown rendering in the terminal.** [`glow`](https://github.com/charmbracelet/glow) (Charm)
is the clearest example: it renders headers, syntax-highlighted code blocks, tables, and links via
its own styling engine (`glamour`), works both as a one-shot renderer and an interactive
pager/browser TUI, and auto-detects the terminal's background color to pick a light or dark
stylesheet automatically.

**Spinners vs. progress bars vs. "X of Y."** Per Evil Martians' ["CLI UX best practices: 3
patterns for improving progress
displays"](https://evilmartians.com/chronicles/cli-ux-best-practices-3-patterns-for-improving-progress-displays):

- **Spinners** suit short, sequential, unmeasurable work. Their core weakness: a frozen process
  and a working one look identical -- mitigate by only advancing the spinner on real progress
  events, so a stall visibly freezes it, rather than animating on a dumb timer.
- **"X of Y" counters** (e.g. "5 / 10 files") are the article's recommended default: concrete,
  glanceable, allow time estimation, and immediately reveal a stall because the numbers stop
  moving.
- **Progress bars** work well when summarizing multiple simultaneous long operations into one
  visual, but are called out as overkill for many single-operation cases.
- Other rules: clear the indicator on completion; switch status verbs from present-progressive to
  past tense once done ("downloading" becomes "downloaded"); respect `NO_COLOR`/`--no-color`;
  never let a progress indicator leak control characters into piped/non-TTY output.

**Animation risk, including over SSH.** Animation has a real cost: it's the direct mechanism
behind the screen-reader "cursor teleporting" and NVDA-crash problems above, and over
higher-latency SSH links, aggressive full-repaint animation can visibly lag because every frame
is a network round trip's worth of bytes rather than a local paint. The `irssi`-style mitigation
(native terminal scrolling regions instead of full repaints) reduces both the accessibility harm
and the bandwidth/latency cost at once -- one architectural choice, two benefits.

## 1.5 Error Handling, Confirmation, and Mode-Switching

**What makes a good error message.** Converging guidance from clig.dev, 12-Factor CLI, and Lucas
Costa's ["UX patterns for CLI tools"](https://lucasfcosta.com/2022/06/01/ux-patterns-cli-tools.html):
state *what* went wrong in plain language, *why* (the root cause, not just a stack trace), and
*what to do about it* -- ideally with a suggested fix, and for genuinely unexpected errors, a way
to report the bug (debug flag, log path, issue URL). Costa specifically praises Git's "did you
mean...?" typo correction as a low-effort, high-value pattern, and npm's practice of distinguishing
tool-caused failures from environment failures in its error text.

**Confirmation prompts.** Nielsen Norman Group's ["Confirmation Dialogs Can Prevent User Errors
(If Not Overused)"](https://www.nngroup.com/articles/confirmation-dialog/) is written for GUI
dialogs but transfers directly to CLI/TUI prompts, and is the implicit theoretical backing for
clig.dev's "confirm before dangerous actions" rule:

- Reserve confirmation for genuinely serious/irreversible actions only -- overuse trains users to
  reflexively dismiss the prompt.
- Avoid a generic "Are you sure?" -- state the actual consequence.
- Prefer specific action labels over bare Yes/No, or in CLI terms, require the literal object
  name to be retyped for the most catastrophic actions.
- Don't pre-select a default answer for a dangerous action.
- Where feasible, undo beats confirm-then-act: perform the action immediately but make it
  reversible for a window, rather than gatekeeping with a prompt -- less friction, less prompt
  fatigue.

**TTY detection and mode-switching.** Per Jake Zimmerman, ["Improving CLIs with
isatty"](https://blog.jez.io/cli-tty/): check whether *stdin specifically* (not stdout -- they can
differ when only one side is redirected) is connected to a real terminal via `isatty()` (available
in essentially every language's standard library). The concrete failure this prevents: a program
that silently defaults to reading stdin when the user forgot to pass a required argument will
appear to hang forever if stdin happens to be an interactive terminal; detecting `isatty(stdin)`
lets it print an explicit "reading from stdin -- press Ctrl-D to end input" warning instead. This
generalizes (per clig.dev and 12-Factor CLI both) into the standard rich-vs-plain mode switch:
when stdout is not a TTY, disable color, spinners, progress animation, and interactive prompts
(require flags instead), and prefer stable, greppable, line-oriented output; when stdout is a
TTY, the richer mode is safe to use by default. `NO_COLOR` and `--no-color`/`--plain` are the
explicit user-facing overrides layered on top of this automatic default. See
[Chapter 6](06-patterns-and-checklist.md) for a diagram of this decision.

## 1.6 Architecture: The Elm Architecture (TEA)

Many modern TUI frameworks (Bubble Tea in Go, several ratatui-adjacent crates in Rust) use some
form of the Elm Architecture: a **Model** (plain state), an **Update** function (pure-ish:
current model + an incoming message, returns a new model), and a **View** function (pure: model
in, terminal output out, deterministic). A TUI is fundamentally a loop reacting to discrete
external events -- keypresses, resize signals, timer ticks, async I/O completion -- and
projecting the resulting state onto a fixed 2D grid, which is exactly the shape TEA is built for.
Unidirectional data flow avoids the classic MVC-in-a-TUI failure mode where a controller mutates a
model, triggering a view update, triggering another controller, cascading unpredictably: every
state change goes through one visible update step, and every render goes through one pure view
step. It also makes TUI state machines straightforward to unit test, since `update(model, msg) ->
model` and `view(model) -> output` are both pure functions testable without a real terminal. See
[Chapter 3](03-go-frameworks.md) for Bubble Tea's concrete implementation of this pattern.

## 1.7 Testing and Tooling

**Golden-file / snapshot testing.** Run the CLI against a fixed input, capture actual output, and
compare it against a checked-in "golden" reference file. [google/go-cmdtest](https://github.com/google/go-cmdtest/blob/master/README.md)
is a good illustration of the pattern (note: this specific repository is archived as of April
2026 and read-only, so cite it as a historical reference rather than a live recommendation) --
it used a shell-like test-file format (`$ command` lines plus expected output) and supported an
"update mode" that regenerates golden files from actual output for human review via `git diff`
before committing. That update-then-diff-review workflow is the generalizable takeaway regardless
of which specific golden-file library a project uses.

**VHS** ([charmbracelet/vhs](https://github.com/charmbracelet/vhs)). Write a `.tape` file -- a
small DSL for terminal-session actions (typing, keypresses, sleeps, waits, output settings) -- and
render it deterministically to a GIF/MP4/WebM/PNG sequence. Positioned for two distinct uses: (1)
polished demo/documentation output without manual screen recording, and (2) integration testing,
since the same tape can be replayed in CI to check the terminal output hasn't regressed. Charm
publishes a `vhs-action` GitHub Action for re-rendering demo assets automatically when the
underlying CLI changes.

**asciinema** ([asciinema/asciinema](https://github.com/asciinema/asciinema)). Records real
terminal sessions into a lightweight, text-based `.cast` format rather than video --
meaningfully smaller, scriptable/replayable at variable speed, with copyable text in the player.
More suited to human-facing documentation, tutorials, and bug-report sharing than automated
testing, where VHS or golden-file diffing fit better.

**Expect-style scripting.** `expect` (Tcl-based) remains the canonical tool for scripting
interaction with programs that demand a real TTY and interactive input (passwords, y/n prompts,
menus): it spawns a process attached to a pseudo-terminal and waits for specific output patterns
before sending scripted input. `autoexpect` records a human session and generates a script from
it; several languages have lighter-weight reimplementations for teams that don't want a Tcl
dependency. The throughline: anything that checks `isatty()` (see 1.5) needs an expect-style tool
to test correctly, not plain subprocess-with-pipes testing.

## 1.8 Essays and Talks Worth Reading

- Charm, ["The Next Generation of the Command Line"](https://charm.land/blog/the-next-generation/)
  (Christian Rocha, 2023) -- frames the CLI's decades-long track record of simplicity,
  composability, and openness as superior infrastructure to the web's siloed, less composable
  norms, and positions Charm's own stack as bringing contemporary UX thinking to that
  infrastructure without abandoning its Unix-philosophy roots.
- Dolev Hadar, ["The Renaissance of the Command
  Line"](https://www.dlvhdr.me/posts/the-renaissance-of-the-command-line) -- an independent
  argument for *why now*: new terminal emulators finally expose true color, styling, and cursor
  positioning reliably enough to build genuinely rich UIs, and CLIs retain structural advantages
  GUIs lack (composability via pipes, precision, keyboard-driven efficiency).
- ["The text mode lie: why modern TUIs are a nightmare for
  accessibility"](https://xogium.me/the-text-mode-lie-why-modern-tuis-are-a-nightmare-for-accessibility)
  -- doubles as thought leadership, not just a bug list; its central provocation, that "no
  graphics" does not mean "accessible," is a framing device most TUI-boosting essays don't
  grapple with at all.

## References

### Official Documentation

- [Command Line Interface Guidelines (clig.dev)](https://clig.dev/) - the primary modern UX
  reference for this whole guide.
- [cli-guidelines/cli-guidelines (GitHub)](https://github.com/cli-guidelines/cli-guidelines) -
  community-maintained continuation of clig.dev.
- [12 Factor CLI Apps](https://jdxcode.medium.com/12-factor-cli-apps-dd3c227a0e46) - the Heroku
  CLI team's operational checklist.
- [POSIX Base Definitions, Chapter 12: Utility Conventions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html) -
  the formal grammar underneath short-flag behavior.
- [GNU Coding Standards: Command-Line Interfaces](https://www.gnu.org/prep/standards/html_node/Command_002dLine-Interfaces.html) -
  long-option conventions.
- [GNU Coding Standards: --help](https://www.gnu.org/prep/standards/html_node/_002d_002dhelp.html) -
  the `--help`/`--version` convention.
- [NO_COLOR](https://no-color.org/) - the informal spec for disabling ANSI color by default.

### Community and Case Studies

- [Adjust your application for a light or dark terminal (dystroy.org)](https://dystroy.org/blog/terminal-light/) -
  the OSC 11 background-detection technique.
- [The text mode lie: why modern TUIs are a nightmare for accessibility](https://xogium.me/the-text-mode-lie-why-modern-tuis-are-a-nightmare-for-accessibility) -
  primary source on the screen-reader problem.
- [Same article, syndicated on OSnews](https://www.osnews.com/story/144892/the-text-mode-lie-why-modern-tuis-are-a-nightmare-for-accessibility/)
- [Building a more accessible GitHub CLI (GitHub Blog)](https://github.blog/engineering/user-experience/building-a-more-accessible-github-cli/) -
  a real project's accessibility remediation, in detail.
- [UX patterns for CLI tools (Lucas Costa)](https://lucasfcosta.com/2022/06/01/ux-patterns-cli-tools.html)
- [CLI UX best practices: 3 patterns for improving progress displays (Evil Martians)](https://evilmartians.com/chronicles/cli-ux-best-practices-3-patterns-for-improving-progress-displays)
- [Confirmation Dialogs Can Prevent User Errors (If Not Overused) (Nielsen Norman Group)](https://www.nngroup.com/articles/confirmation-dialog/)
- [Improving CLIs with isatty (Jake Zimmerman)](https://blog.jez.io/cli-tty/)
- [The Elm Architecture (TEA) (Ratatui docs)](https://ratatui.rs/concepts/application-patterns/the-elm-architecture/)
- [charmbracelet/vhs (GitHub)](https://github.com/charmbracelet/vhs)
- [asciinema/asciinema (GitHub)](https://github.com/asciinema/asciinema)
- [google/go-cmdtest (GitHub, archived)](https://github.com/google/go-cmdtest/blob/master/README.md)
- [charmbracelet/glow (GitHub)](https://github.com/charmbracelet/glow)
- [The Next Generation of the Command Line (Charm blog)](https://charm.land/blog/the-next-generation/)
- [The Renaissance of the Command Line (Dolev Hadar)](https://www.dlvhdr.me/posts/the-renaissance-of-the-command-line)

### Further Local Reading

- `06-patterns-and-checklist.md` - a practical, cross-language checklist built on this chapter.
