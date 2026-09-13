---
audience: human
created: 2026-08-10
updated: 2026-08-19
---

# Build Guide: Choosing and Customizing Your Own Components

This is a generalized guide to the decisions involved in designing a cyberdeck, organized by
component category, with the tradeoffs that should drive your choice in each one. It
deliberately does not prescribe specific part numbers or brands (those go stale fast, and the
community moves quickly); instead it explains what to weigh so you can pick parts that suit
your budget, your region's availability, and your specific use case. See
[Resources](05-resources.md) for where to research current, specific hardware options once
you know what you're looking for.

## Step Zero: Define Your Use Case Before You Buy Anything

Every experienced builder's advice converges on the same starting point: decide what the deck
is actually for before choosing a single component. A pentesting deck, a ham radio field rig,
a writerdeck, and a display piece all pull component choices in different, sometimes opposite,
directions (a radio deck wants long battery life and antenna ports over raw CPU; a local-LLM
deck wants RAM and compute over battery life; a writerdeck wants a great keyboard and long
battery life over almost everything else). Decide your primary use case, and, separately,
where you want to land on the function-vs-aesthetic spectrum discussed in
[What Is a Cyberdeck](01-what-is-a-cyberdeck.md), before you shop. If you're not sure yet,
build something small and cheap first (see "Iterate Before You Commit" below) rather than
guessing big.

## Compute

The three broad paths, in order of typical cost and complexity:

- **ARM single-board computers** (the Raspberry Pi is the default reference point the community
  measures everything else against, but there are many alternatives). Strengths: low power draw
  (commonly single-digit to low-teens watts under load), passive or near-silent cooling, cheap,
  huge amount of community documentation and pre-built OS images, and generally the best
  power-consumption-per-dollar for anything that has to run on a battery for hours. Weaknesses:
  single- and multi-core CPU performance well behind even a modest x86 chip, and some
  ARM-specific software compatibility friction (fewer prebuilt binaries, occasional container
  image issues).
- **x86 mini-PC boards or modules** (small industrial or consumer x86 boards, sometimes salvaged
  from mini-PCs). Strengths: real desktop-class performance, full mainstream OS and application
  compatibility (including x86 container images, and any software that doesn't ship ARM
  builds), more expansion (M.2/NVMe, sometimes discrete GPU options). Weaknesses: meaningfully
  higher power draw (roughly 2-5x an ARM SBC's under load, with low-power N100-class boards at
  the bottom of that range and anything with discrete graphics at the top), often needs active
  cooling (fan noise, more moving parts to fail), and generally a bigger, heavier build.
- **Repurposed laptop motherboards** ("laptop-in-a-box" builds). Strengths: you get a full,
  proven laptop-grade compute+power+charging subsystem for often very little money (secondhand
  or broken-screen laptops), which can simplify the power design a lot, since the laptop's own
  battery and charging circuitry can sometimes be reused. Weaknesses: bulkier and less flexible
  to physically integrate than a bare SBC, board-specific quirks, and end-of-life or damaged
  parts availability risk.

Match this choice to your use case: field/battery-powered builds (radio, prepping, EDC,
writerdecks) generally favor ARM SBCs; compute-heavy stationary or semi-stationary builds
(local LLM inference, pentesting with heavier tooling, retro-computing emulation of
more demanding systems) more often favor x86.

## Display

Key decisions, roughly in priority order:

- **Resolution and physical size.** A common community rule of thumb is to avoid going below
  roughly 1024x600 for a primary/main-use display; lower resolutions are more tolerable for a
  secondary or status display. Balance size against your enclosure's target footprint and
  weight budget.
- **Touch vs. non-touch.** Touch adds cost and a bit of complexity but can meaningfully reduce
  how much physical input hardware (pointing device) you need to add separately.
- **Outdoor/sunlight readability**, if the deck will be used outside (radio field days,
  off-grid use): a panel with poor peak brightness or a glossy coating will be frustrating to
  read outdoors regardless of resolution.
- **Power draw.** Displays are frequently one of the larger power draws in a small deck; a
  bigger or brighter panel directly costs you runtime.
- **Interface compatibility with your chosen compute board** (HDMI, DSI, or a driver board for a
  bare panel) - confirm this before buying either part, not after.
- **Aesthetic/period fit**, if that matters to your build: some builders deliberately choose
  e-ink for a low-power, high-contrast "terminal" look, or source and restore an actual small
  CRT for retro builds, accepting the tradeoffs (refresh rate, weight, power draw) that come
  with either choice.

## Input

- **Keyboard.** This is widely considered the single component most likely to make or break how
  much you actually enjoy using the finished deck, so don't treat it as an afterthought.
  Options span salvaged laptop or full-size keyboards (cheap, especially secondhand, but
  physically bulkier and harder to integrate into a tight enclosure), custom mechanical builds
  (best feel and full control over layout, more assembly and firmware work), and
  compact/ortholinear layouts like 40% or 60% boards (fit smaller enclosures well and suit the
  aesthetic, at the cost of a learning curve and fewer dedicated keys). Pick based on how much
  typing the deck's use case actually requires: a writerdeck should prioritize keyboard feel
  above nearly everything else; a display-piece build can prioritize looks over feel.
- **Pointing device**, if needed at all: many single-purpose decks (radio, writerdecks) skip a
  mouse/trackpad entirely and rely on keyboard-driven software. If you need one, small
  trackpads, trackballs, and touchscreens are all common; weigh physical space and power draw
  the same way as any other component.

## Power

Power is the subsystem where a mistake is not just inconvenient but genuinely dangerous, so
treat it with more caution than any other part of the build (see the safety note in
[Modern Usage](03-modern-usage.md)). Three broad approaches, roughly in order of how much you
have to build yourself:

- **Off-the-shelf USB battery banks.** Simplest and safest option: someone else has already
  solved the protection-circuit problem for you, and it's the best starting point for a first
  build. Downsides are bulk-for-capacity and less control over form factor.
- **A laptop-style power brick plus a voltage converter/regulator.** A middle ground: still
  relies on a commercial, pre-protected pack, with a bit more design freedom over form factor
  than a sealed USB bank.
- **A custom lithium cell pack with a dedicated battery-management board (BMS).** Gives you the
  most control over capacity, shape, and physical placement, but you are now responsible for
  getting the protection circuit right. At minimum, a lithium pack you assemble yourself needs
  overvoltage, undervoltage, and overcurrent protection; over-temperature protection is
  strongly recommended too. Never wire lithium cells directly to a load or charger without a
  BMS between them, never short the terminals, and never disassemble a pre-built protected
  pack, doing so removes the exact protection that prevents overheating, venting, or fire.
  If you are not already comfortable with battery-pack assembly, start with one of the two
  simpler options above instead, or buy a pre-assembled protected pack rather than building
  cells up from scratch.

Whichever path you choose, plan real capacity against your actual expected runtime for your
use case (a field radio or prepping deck needs meaningfully more capacity than a desk-bound
display piece), and budget for the display and any radios/SDR hardware, which are often bigger
power draws than the compute board itself.

## Enclosure and Structure

Common materials, with no single "correct" choice, pick based on the tools and skills you
already have or want to learn:

- **3D printing.** The most common modern choice: cheap, iterable, and well-suited to complex
  organic or futuristic shapes; downside is print-bed size limits on large single pieces, and
  print strength/durability depends heavily on material and settings.
- **Hard cases (e.g., waterproof Pelican-style cases).** The "rugged field" default since Jay
  Doscher's original builds; gives you genuine drop/water resistance essentially for free, at
  the cost of a bulkier, less customizable base shape.
- **Sheet metal.** Favored for a stark industrial look and real durability; needs metalworking
  tools/skills (cutting, bending, finishing) most builders don't already have.
- **Wood.** Accessible with common hand/power tools, easy to finish attractively, but heavier
  and less weather-resistant than metal or a purpose-built plastic case.
- **Foam board.** The cheapest and fastest way to mock up a design before committing to a final
  material, genuinely useful as a first-pass prototype even if you plan to rebuild in something
  sturdier.
- **Acrylic/other plastics.** Good for a cleaner, more polished look, or for deliberately
  showing off the internals through a clear or translucent panel.

Use whatever material you're already comfortable working with for a first build; you can always
rebuild the enclosure once you know your internal layout actually works.

## Connectivity

Decide what your use case actually needs before adding radios/ports for their own sake, since
each one costs power, cost, and enclosure space:

- **Wired networking (Ethernet)** matters most for pentesting/security builds and any use case
  needing a reliable, high-bandwidth, hard-to-jam connection.
- **Wi-Fi/Bluetooth**, built into most SBCs already, is enough for most general-purpose and
  writerdeck-style builds.
- **Dedicated radio hardware** (SDR dongles, GPS modules, LoRa/mesh-networking radios,
  cellular modems) is specific to radio, off-grid/mesh, and some security builds; confirm your
  compute board has the USB, GPIO, or M.2 interfaces the specific module needs before buying it.
- **GPIO/expansion headers** matter if you plan to add your own sensors, indicator lights,
  physical switches, or other custom hardware controlled directly by the compute board rather
  than through a standard peripheral interface.

## Operating System and Software Stack

Match the OS to your compute platform and use case rather than defaulting to whatever's
best-documented:

- **Full-featured general Linux distributions** (a mainstream Pi OS release, or a standard
  desktop Linux distribution on x86) are the right default for general-purpose builds, and give
  you the broadest hardware and software compatibility while you're still learning what your
  deck needs.
- **Minimal/stripped-down distributions** (lightweight, SBC-optimized Debian derivatives are a
  common choice) trade some hardware-compatibility convenience and a smaller support/tutorial
  base for meaningfully lower RAM/disk footprint and faster boot, worth it once you know
  exactly what your deck needs to run and want to reclaim the resources a full desktop
  environment would otherwise use.
- **Purpose-built distributions** exist for specific use cases (a security distribution
  preloaded with penetration-testing tools; a minimal writerdeck OS that boots straight into a
  text editor with no other applications available) and are worth adopting wholesale when your
  use case matches one closely, rather than assembling the equivalent yourself from a general
  distribution.

## Assembly, Wiring, and Safety

- Bench-test every component (compute board, display, keyboard, power system) connected loosely
  on a desk before committing to final wiring inside the enclosure; it is far easier to debug a
  bad connection or a dead part before it's buried in a case.
- Confirm your OS boots and your peripherals are recognized before you do any permanent
  mounting or wiring.
- Keep the power subsystem's wiring visually distinct and physically separated from signal
  wiring where practical. Before first power-on, double-check polarity and confirm the supply's
  actual output voltage with a multimeter rather than trusting its label; a reversed or
  over-voltage rail is one of the most common ways to kill a board on the first try.
- Handle bare boards with basic ESD precautions: a grounded wrist strap or mat, or at minimum
  discharging yourself on something grounded before picking a board up.
- Revisit the battery/power safety guidance above before finalizing any custom power wiring;
  this is the one area of the build where "it mostly works" is not good enough.

## Iterate Before You Commit

Prototype your internal layout, ideally with cheap materials like foam board or a rough,
loosely-fitted 3D print, before building or buying your final enclosure. It is much cheaper to
discover a layout problem (a cable that's too short, a component that runs hotter than
expected, a keyboard angle that turns out to be uncomfortable) before it's epoxied or
permanently fastened into a finished case than after.

## References

- [Cyberdeck Build Guide - THE CYBERDECK CAFE](https://cyberdeck.cafe/build)
- [How to Build a Cyberdeck (2026): Parts, Software & Builds - Vapor95](https://vapor95.com/blogs/darknet/how-to-build-a-cyberdeck-the-complete-2026-guide-parts-software-and-iconic-builds)
- [Single Board Computer Comparison 2026: 14 Boards Tested - raspberry.tips](https://raspberry.tips/en/raspberrypi-tutorials/raspberry-pi-alternatives-sbc)
- [You're Better Off Buying A Cheap Mini PC For These 4 Raspberry Pi Projects - SlashGear](https://www.slashgear.com/2190844/raspberry-pi-projects-mini-pc-runs-better/)
- [DietPi vs Raspberry Pi OS: Which is Better for Your Pi? - SingleBoardBytes](https://singleboardbytes.com/3299/dietpi-vs-raspberry-pi-os-which-is-the-better-choice-for-your-pi.htm)
- [What Is DietPi, And Should You Install It On Your Raspberry Pi? - SlashGear](https://www.slashgear.com/1484447/what-is-dietpi-raspberry-pi-explained/)
- [Protection Circuit Modules for Custom Lithium Battery Packs - Epectec](https://www.epectec.com/batteries/protection-circuit-modules.html)
- [Lithium Battery Packs: Choosing the Protection Board Best for You - Epectec](https://blog.epectec.com/lithium-battery-packs-choosing-the-protection-board-best-for-you)
