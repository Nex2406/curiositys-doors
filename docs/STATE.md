# Current State (auto-narrative — update at end of every session)
_Last updated: 2026-05-17_

## Live loop
Hub.tscn ↔ Realm1 (cave traversal) ↔ Hub return. Door 1 wired.
Door 2 / Door 3: stubs.

## What is wired
- Curiosity locomotion: idle / walk / run / jump / air / land
- Lantern PointLight2D with placeholder gradient + soft flame flicker
- Parallax in Hub + Realm 1
- Tilemap floor + platforms in Realm 1 (brown-cave palette)
- Door interact (Y key) → scene transition with fade
- Hub respawn at the door Curiosity returned through
- Touch controls scene (mobile / touch-browser)
- GitHub Pages auto-deploy on merge to main

## What exists but is unwired
- Combat / dash / lever / approach / hurt / charged / celebrate animations
  on Curiosity (frames imported, not reachable from state machine)
- Save system, dialogue overlay, puzzle framework (all docs-only)
- Hand-painted lantern falloff (still gradient placeholder)
- Cloak / eye-blink / fog shaders
- Per-realm ambient audio

## Last session
[2026-05-17 — Tighten the agentic loop](SESSIONS.md#2026-05-17--tighten-the-agentic-loop)

## Next 3 safe candidates
1. **Realm 1 lore moment (queued spec)** — one short Curiosity-voice line
   on Realm 1 exit before the fade. Local to the realm, no global dialogue
   framework needed yet.
2. **Realm 1 jade-piece pickups** — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
3. **Polish pass on platform rocks** — `T_PLATFORM_L/M/R` currently reuse
   the solid sub-floor block. A peak-top platform tile (e.g. row-22
   rocky-band coords) would read more as a floating ledge than a chunk
   of detached floor.
