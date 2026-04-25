# Curiosity's Doors

*A side-scrolling atmospheric puzzle game about a cloaked traveler and the doors that remember them.*

**Play:** https://nex2406.github.io/curiositys-doors/

---

## Vision

Curiosity is one figure: hooded, faceless, lantern in hand. The world is a hub of doors — each opening into a distinct realm with its own palette, soundscape, and puzzle. To pass through a realm, the traveler must understand it. The visual bar is Hollow Knight-tier painterly polish; the narrative bar is layered, melancholic, and quietly unsettling.

For the full picture see [`docs/VISION.md`](docs/VISION.md). For the painterly bible, [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md). For the tone reminder, [`docs/VIBE.md`](docs/VIBE.md).

## How this is built

A solo designer + Claude Code in an agentic loop, with GitHub as the spec and the publisher.

- **Issues are the spec.** Every change starts as a templated issue (`feat`, `bug`, `story`, `art`, `research`).
- **Claude Code executes against issues** on feature branches, opens PRs against `main`.
- **GitHub Actions exports** the Godot 4.6 Web build and publishes to GitHub Pages on every merge to `main`.
- **`main` must always deploy green** — see the Golden Rule in [`CLAUDE.md`](CLAUDE.md).

## Tech

- Godot 4.6 (Forward+, GDScript only)
- HTML5 / WebAssembly export
- GitHub Pages hosting via Actions
- Issue templates, label taxonomy, and PR template under [`.github/`](.github/)

## Status

In active development. Updated continuously. Expect the live build to change between any two visits.
