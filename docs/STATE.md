# Current State (auto-narrative — update at end of every session)
_Last updated: 2026-05-17_

## Live loop
Hub.tscn ↔ Realm1 (cave traversal) ↔ Hub return. Door 1 wired.
Realm 1 exit plays a one-line lore moment before the fade.
Door 2 / Door 3: stubs.

## What is wired
- Curiosity locomotion: idle / walk / run / jump / air / land
- Lantern PointLight2D with placeholder gradient + soft flame flicker
- Parallax in Hub + Realm 1
- Tilemap floor + platforms in Realm 1 (brown-cave palette)
- Door interact (Y key) → scene transition with fade
- Hub respawn at the door Curiosity returned through
- **LoreMoment overlay** (`scenes/UI/LoreMoment.tscn` + `scripts/LoreMoment.gd`) —
  reusable single-line lore display: slow fade-in / hold / fade-out, soft
  serif via SystemFont fallback, no box. Wired into `Door.exit_lore_line`
  so any realm exit can set its own beat. Realm 1 exit uses it.
- Touch controls scene (mobile / touch-browser)
- GitHub Pages auto-deploy on merge to main (live build at
  https://nex2406.github.io/curiositys-doors/)

## What exists but is unwired
- Combat / dash / lever / approach / hurt / charged / celebrate animations
  on Curiosity (frames imported, not reachable from state machine)
- Save system, puzzle framework (docs-only)
- Hand-painted lantern falloff (still gradient placeholder)
- Cloak / eye-blink / fog shaders
- Per-realm ambient audio

## Last session
[2026-05-17 — Close the agentic loop](SESSIONS.md#2026-05-17--close-the-agentic-loop)

## Next 3 safe candidates
1. **Realm 2 — design + build (use `realm.md`)** — interview Advika for
   all 5 template fields (theme word, palette refs, puzzle premise, lore
   beat on exit, what player carries forward), then build. Do not invent
   answers.
2. **Realm 1 jade-piece pickups** — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
3. **Hand-painted lantern falloff** — replace the `GradientTexture2D`
   placeholder with a painterly radial falloff. Pure art swap, no
   gameplay change.

---

## See also

- [`CLAUDE.md`](../CLAUDE.md) — repo-wide engineering guide; Quality Gate; Session Start Protocol
- [`docs/SESSIONS.md`](SESSIONS.md) — append-only build log: shipped / didn't / next 3 per session
- [`docs/VISION.md`](VISION.md) — north star: hero, hub, realms, the three bars (visual / technical / narrative)
- [`docs/MECHANICS.md`](MECHANICS.md) — engineering reference: implemented vs planned systems
- [`docs/REALMS.md`](REALMS.md) — per-realm spec: theme, palette, soundscape, puzzle mechanic, lore reveal
- [`docs/ART_DIRECTION.md`](ART_DIRECTION.md) — painterly bible: palette hexes, lighting model, scale rules
- [`docs/STORY.md`](STORY.md) — narrative scaffolding: plot beats, tonal constraints, voice rules
- [`docs/VIBE.md`](VIBE.md) — tone allow/deny lists; sanity check before naming or writing
