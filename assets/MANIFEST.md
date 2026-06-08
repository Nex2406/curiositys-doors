# Asset Manifest

What's in each folder. Update when assets land or move.

> Living index. Last updated: 2026-05-17.

---

## `_reference/`
Concept art and visual references. Not used by the game — only read by Claude and Advika to keep on-vibe.

- `hub_concept.png` — earlier hub reference (predates 2026-05-17). Kept for history.
- `hub_concept_2026-05-17.png` — current hub vision. Topsy-turvy, infinite doors, stairs to nowhere, frozen clock, slow sandglass, drifting question marks, deep purple palette. **This is the working reference for HUB.md.**

## `characters/hero/`
Curiosity. The only hero in the game.

- `curiosity.png` — base sprite reference
- `sprites_locomotion.png` — locomotion sheet
- `frames/` — per-animation frames: `idle_*`, `walk_*`, `run_*`, `jump_start_*`, `air_*`, `land_*`, `dash_*`, `approach_*`, `attack1_*`, `attack2_*`, `charged_*`, `hurt_*`, `celebrate_*`, `lever_pull_*`, `lever_hold_*`

## `effects/`
Per-effect art used across realms.

- `lantern_flame.png` — flame sprite for the lantern
- `lantern_halo.png` — soft warm halo for the lantern's glow
- `firefly.png` — drifting motes / fireflies particle sprite

## `scenes/hub/`
Art for the hub scene.

- `nebula.png` — deep-space / void backdrop layer
- `stone_floor.png` — hub floor tile

## `props/`
Interactable props that appear across realms.

- `lever/` — `lever_up.png`, `lever_down.png`

## `scenes/<realm>/`
Per-realm art goes here. Each realm gets its own folder when it lands.

- *Realm 1 ("Crimson Hollow") tileset already in use — see commits a03c895, 197639b, ee9234e for the build history.*
