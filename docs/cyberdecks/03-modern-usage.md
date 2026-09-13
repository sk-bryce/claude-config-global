---
audience: human
created: 2026-08-10
updated: 2026-08-19
---

# Modern Usage

Cyberdecks are built for a wide range of real purposes today, alongside builds where the
purpose is largely the build itself (see [What Is a Cyberdeck](01-what-is-a-cyberdeck.md) on
the function/aesthetic split). This section covers the recognized use-case categories the
community organizes around.

## Security Research and Penetration Testing

The most consistently "practical field tool" branch of the hobby. A pentesting deck is built to
function as a portable, self-contained red-team lab: it typically runs a security-focused Linux
distribution, most commonly **Kali Linux**, which ships with official Raspberry Pi images
maintained by Offensive Security and comes preloaded with hundreds of security tools, and is
built out with hardware to match, external Wi-Fi/Bluetooth antennas, wired Ethernet ports for
direct network access, and sometimes RF hardware for wireless auditing. Purpose-built handheld
pentesting hardware has increasingly blurred into this same space (for example the Flipper One,
unveiled in 2026 and not yet shipping at the time of writing: a pocket Linux computer with dual
Gigabit Ethernet, Wi-Fi 6E, and an M.2 slot for a 5G modem, NVMe drive, or SDR module),
alongside a wide ecosystem of small ESP32-based tools for Wi-Fi, Bluetooth, RFID, and sub-GHz
auditing that get integrated into larger deck builds. As with any
security tooling, use is only appropriate against systems you own or are explicitly authorized
to test.

## Amateur Radio and Software-Defined Radio (SDR)

A large and well-established use case, since ham radio operators already value portable,
self-contained, field-day-ready equipment, which lines up naturally with the cyberdeck form
factor. Typical builds pair an SBC with an SDR dongle (the RTL-SDR is the common entry point)
for receiving and analyzing radio spectrum, and add a telescoping or externally-mounted antenna.
Common uses include general ham radio operation, spectrum monitoring and signal
identification, weather balloon tracking, and RF situational awareness in the field. Notable
community builds in this category (such as "Hamdeck," built into a waterproof Pelican-style
case with a 10-inch screen and roughly 20-hour battery life) emphasize long field endurance
over raw compute power.

## Offline and Local AI / LLM Rigs

A newer and fast-growing category, driven by two trends converging: small on-device language
models becoming genuinely usable, and the broader cyberdeck ethos of "owns and controls its own
data" extending naturally to AI. These builds run local inference engines (Ollama and
llama.cpp are the common runtimes) against locally-stored open-weight models, often paired with
a local vector store (for example Qdrant with an embedding model like nomic-embed-text) to make
locally stored documents, field notes, or reference material searchable without ever touching
the internet. Builds range from lightweight (an Arduino-class board running a small model
purely for basic offline assistance) to serious (a full desktop-class SBC or mini-PC running a
larger model for coding help, troubleshooting, or reference lookup entirely offline).

## Retro Computing and Emulation

Builds in this category use a cyberdeck's compute headroom to run retro operating systems,
console/computer emulators, or period-accurate software, usually paired with an intentionally
retro-styled enclosure (80s-terminal aesthetics, CRT-style displays or actual reclaimed CRTs,
chunky mechanical keyboards). This overlaps heavily with the aesthetic dimension of the hobby:
the build is often as much about recreating the feel of a specific computing era as it is about
running specific old software.

## Prepping, Off-Grid, and Field Computing

Builds oriented around functioning with no external infrastructure: no mains power, no
internet, no cell network. These decks emphasize a self-contained power system with real
capacity (not just a small power bank), ruggedized enclosures, and locally stored reference
material, commonly an offline copy of Wikipedia or another large reference dataset, sometimes
paired with mesh-networking hardware for off-grid communication with other nearby devices, and
increasingly a local LLM (see above) as an offline "ask it anything" fallback. Jay Doscher's
original Raspberry Pi Recovery Kit, built with electromagnetic shielding and framed explicitly
around post-disaster resilience, is the foundational build in this category (see
[History](02-history.md)).

## Writerdecks: Distraction-Free Writing

A recognized cyberdeck sub-category built around a single job: getting words written without
the rest of a general-purpose computer's distractions. A writerdeck typically boots directly
into a text editor (with no browser, no notifications, and often no other applications
installed at all), favors a comfortable, standalone keyboard, and prioritizes battery life and
a legible display over raw performance. Purpose-built writerdeck operating systems exist for
exactly this (for example, distributions that boot straight into a minimal editor like Tilde),
and the category has its own small community and reference site distinct from the general
cyberdeck communities.

## Art, Cosplay, and Prop-Making

Builds made primarily as functional or non-functional art objects: faithful recreations of
fictional decks from cyberpunk media, cosplay props, or pieces built around a specific visual
theme (post-apocalyptic salvage, a particular film or game's aesthetic, or the newer
craft-influenced styles using natural materials, macrame, embroidery, and decorative work
around exposed electronics). See [History](02-history.md) for how this branch grew alongside
the hobby's rapid recent growth on short-form video platforms.

## Everyday Carry (EDC) and General Field Computers

Smaller, pocketable or bag-portable builds meant for regular daily use rather than a single
specialized task: note-taking, light coding, terminal/SSH access to other machines, or general
field reference. These tend to prioritize size and battery life over the expandability that a
larger deck (like a pentesting or radio rig) needs.

## A Note on Safety for Field/Practical Builds

Any deck built for real field use, and especially prepping, radio, or long-duration builds,
depends on its power system behaving safely, not just working. Cyberdeck builders very
commonly assemble their own lithium battery packs, and the community's own build guidance is
explicit about this being the one place in a build where a mistake is not just inconvenient but
dangerous: lithium cells require dedicated protection circuitry (a BMS providing overvoltage,
undervoltage, overcurrent, and ideally over-temperature protection) rather than being wired
directly to a load, since overcharging, over-discharging, too-fast discharge, physical damage,
or a short circuit between terminals can all lead to thermal runaway (overheating, venting,
fire, or rupture). See [Build Guide](04-build-guide.md) for what to actually look for in a
battery/power subsystem.

## References

- [How to Build a Cyberdeck (2026): Parts, Software & Builds - Vapor95](https://vapor95.com/blogs/darknet/how-to-build-a-cyberdeck-the-complete-2026-guide-parts-software-and-iconic-builds)
- [Building the Ultimate Cyberdeck: Custom Hardware Hacking Platforms - Eclypsium](https://eclypsium.com/blog/build-the-ultimate-cyberdeck-hackberry-pi/)
- [Hamdeck Is a Rugged Cyberdeck Optimized for Amateur Radio - Hackster.io](https://www.hackster.io/news/hamdeck-is-a-rugged-cyberdeck-optimized-for-amateur-radio-26c38636a94b)
- [2023 Cyberdeck Challenge: A Ham Radio Cyberdeck - Hackaday](https://hackaday.com/2023/08/15/2023-cyberdeck-challenge-a-ham-radio-cyberdeck/)
- [Raspberry Pi based SDR Cyberdeck - Technojunkyard](https://technojunkyard.net/2022/11/raspberry-pi-based-sdr-cyberdeck/)
- [Bare Metal and Neural Nets: Crafting a Purpose-Driven AI Cyberdeck - DEV Community](https://dev.to/numbpill3d/bare-metal-and-neural-nets-crafting-a-purpose-driven-ai-cyberdeck-3pff)
- [Doomsday-Cyberdeck - GitHub](https://github.com/EzioDEVio/Doomsday-Cyberdeck)
- [The Tinker WriterDeck OS - Hackster.io](https://www.hackster.io/news/the-tinker-writerdeck-os-turns-any-amd64-laptop-desktop-into-a-distraction-free-writing-tool-d7ee306dbf35)
- [Looking for a distraction-free writing tool? You need a writerDeck - How-To Geek](https://www.howtogeek.com/looking-for-a-distraction-free-writing-tool-you-need-a-writerdeck/)
- [writerDeck.org](http://www.writerdeck.org/)
- [Jay Doscher's Raspberry Pi Recovery Kit - Hackster.io](https://www.hackster.io/news/jay-doscher-s-raspberry-pi-recovery-kit-is-an-all-in-one-off-grid-cyberdeck-0437d643fea5)
- [Cyberdeck Build Guide - THE CYBERDECK CAFE](https://cyberdeck.cafe/build)
- [Protection Circuit Modules for Custom Lithium Battery Packs - Epectec](https://www.epectec.com/batteries/protection-circuit-modules.html)
