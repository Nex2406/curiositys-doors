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
[2026-05-17 — Realm 1 lore moment + LoreMoment scene](SESSIONS.md#2026-05-17--realm-1-lore-moment--loremoment-scene)

## Next 3 safe candidates
1. **Realm 1 jade-piece pickups** — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
2. **Polish pass on platform rocks** — `T_PLATFORM_L/M/R` currently reuse
   the solid sub-floor block. A peak-top platform tile (e.g. row-22
   rocky-band coords) would read more as a floating ledge than a chunk
   of detached floor.
3. **Hand-painted lantern falloff** — replace the `GradientTexture2D`
   placeholder with a painterly radial falloff. Pure art swap, no
   gameplay change.
