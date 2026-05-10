# Mechanics

Every system that runs the game, present or planned. Update this when systems land or change shape.

---

## Current Implemented Loop

The end-to-end thing a player can actually do on the live build, in order:

1. Game launches into `scenes/Hub.tscn` (the project main scene). Curiosity spawns centre-floor; three painted door arches hum at fixed positions; parallax nebula + fog band + drifting fireflies fill the backdrop.
2. Curiosity walks / runs / jumps with WASD or arrow keys; Space, Up, or W for jump; Shift to sprint. Lantern + flame follow her with a sway tween, flame alpha breathes on a sin loop.
3. Walking into a door's overlap zone fades a `[Y] Enter` prompt in above it.
4. Pressing Y on Door 1 routes through the `Transition` autoload — fade to black, change scene to `res://scenes/realms/Realm1.tscn`, fade back in.
5. Realm 1 is a 6144-px cave: 8-layer parallax backdrop, runtime-built TileMap floor with 4 jump gaps + 10 staircased platforms + bookend walls, exit door at the far right.
6. Pressing Y on Realm 1's exit door routes back to Hub. `Transition.last_door_id` carries the entry door id across, and `Hub.gd` snaps Curiosity 90 px beside the matching door on `_ready` before connecting interaction signals.
7. Pressing Y on Door 2 or Door 3 in the Hub flashes the entry pulse but logs `[Door] Realm not yet built` — no transition.

---

## Implemented Systems

### Curiosity (CharacterBody2D)
- Files: `scripts/Curiosity.gd`, `scenes/Curiosity.tscn`
- Hand-painted `AnimatedSprite2D` (the prior `ColorRect` placeholder is gone). `idle`, `walk`, `run`, `jump_start`, `air`, `land` are wired to a state machine.
- Tuning: `walk_speed=200`, `run_speed=320`, `gravity=350`, `jump_velocity=-240` — drifting-traveler feel (low gravity ≈ longer air time at roughly the same reachable height as a normal platformer).
- Sprint = held Shift. Facing flip mirrors lantern + flame x-offset via a sway tween (`lantern_sway_time=0.2s`).
- Combat / dash / lever / celebrate frames are present in `SpriteFrames` but unwired — see Stubs.

### Lantern (PointLight2D + LanternFlame Sprite2D)
- Child of Curiosity. Hand-painted `lantern_halo.png` falloff (the `GradientTexture2D` placeholder is gone).
- Warm key colour, energy 3.8.
- `LanternFlame` Sprite2D breathes on a sin loop — period 0.4s, amplitude 0.05. Replace with a noise-driven flicker when next polished.

### Hub (scenes/Hub.tscn, scripts/Hub.gd)
- Project main scene. Three door arches at hand-authored positions, stone floor strip, parallax nebula, fog band, GPUParticles2D fireflies, `CanvasModulate` dim.
- Single-source interact dispatch: `Hub.gd` polls `interact` once per frame and routes to the active door's `trigger()`. Each `Door` joins the `doors` group on `_ready` and reports near/left via `Area2D` body signals.
- On `_ready`, reads `Transition.last_door_id` and snaps Curiosity 90 px beside the matching door before clearing the state.

### Door (Area2D, scripts/Door.gd)
- Reusable. Body-overlap fades in a `[Y] Enter` Label above the painted arch.
- `trigger()` flashes the glow + swaps the prompt text, then routes through `Transition` based on `target_realm`:
  - `realm_1` → `res://scenes/realms/Realm1.tscn`
  - `hub` → `res://scenes/Hub.tscn`
  - anything else → log `[Door] Realm not yet built: <target>`, stay open for retry.
- Realm-bound trips set `Transition.last_door_id`; Hub-bound trips leave it intact so the entry-door spawn works on return.

### Scene Transition (autoload `Transition`, scripts/SceneTransition.gd)
- Single high-layer (`CanvasLayer.layer = 128`) black `ColorRect` overlay, full-rect, mouse-ignored.
- Async API: `fade_to_black(duration=0.6)`, `fade_from_black(duration=0.6)`, `transition_to(scene_path)` (fade → `change_scene_to_file` → frame yield → fade).
- `last_door_id` field carries spawn-placement state across scene changes.

### Realm 1 (scenes/realms/Realm1.tscn, scripts/Realm1.gd)
- First playable realm. Linear left-to-right cave traversal — no enemies, no puzzle yet.
- 8-layer `ParallaxBackground` (deepest = opaque flat fog tint so no viewport gap; shallower layers add detail). `motion_mirroring=(1280,0)` per layer for horizontal tiling; `motion_scale=(X,1)` so vertical follows camera.
- `TileSet` built at runtime from `mainlev_build.png` — every non-empty 32×32 cell is registered as an atlas tile, but only the curated `SOLID_TILES` palette (rocky-ground variants, brick walls, wood plank L/M/R, ceiling stalactites) carries collision polygons. Decorative tiles ride a separate non-colliding `TileMapLayer`.
- Level: floor at `tile_y=9` (world y=576) with 4 jump gaps; 10 wood platforms staircased across 5 height tiers; bookend brick walls; ceiling row across the top.
- Camera limits 0..6144 horizontal, 0..720 vertical so the camera never drifts past the parallax extent.
- Exit door at the far right uses the shared `Door.gd` with `target_realm="hub"`.

### Mobile Touch Controls (scenes/TouchControls.tscn)
- Instanced into both Hub and Realm 1. Hidden by default on desktop.

### Web Export Pipeline
- Godot 4.6 Forward+ → HTML5 export preset "Web".
- `.github/workflows/deploy.yml` runs `--headless --import` (twice on cold cache) + `--export-release "Web"`, writes `.nojekyll`, publishes to Pages on every push to `main`.

---

## Known Stubs / Out of Scope (not built yet)

- **Doors 2 + 3** — entry pulse fires but they log `Realm not yet built` and don't transition. Will wire when those realms exist.
- **Combat / dash / lever / celebrate animations** — frames live in `Curiosity.tscn`'s `SpriteFrames` (`attack1`, `attack2`, `charged`, `dash`, `hurt`, `approach`, `lever_pull`, `lever_hold`, `celebrate`) but no state, input, or system consumes them.
- **Realms 2 + 3** — drafted in `docs/REALMS.md` (Forgotten Names, Quiet Hunger, Folded Hour) but not built. Realm 1 in code is a technical traversal cave, not yet a themed/narrative realm.
- **Save system** — no persistence. Hub starts fresh each session.
- **Puzzle framework** — no `Puzzle` base class; Realm 1 is pure traversal.
- **Dialogue / lore overlay** — no text presenter; story beats live only in `docs/STORY.md`.
- **Enemies / hazards** — none. Realm 1 is no-stakes.
- **Ambient audio** — no buses, no beds, no SFX. Silent build.
- **Shaders** — no cloak distortion, eye-blink, fog, or painterly post. `CanvasModulate` dim is the only environmental shader.
- **Settings / pause overlay** — none.
- **`move_down` input action** — registered (S + Down arrow) but unconsumed.
- **Lantern noise flicker** — current sin-wave alpha breath. The organic noise-driven energy modulation per the design bible isn't wired yet.

---

## Next Safe Feature Candidates

Small, additive, low-risk PRs that don't touch existing gameplay:

1. **Audio bus scaffold + Hub ambient bed** — Master / Music / Ambient / SFX buses + one looping low-volume Hub drone. Touches no existing systems.
2. **Lantern noise flicker** — swap the sin-wave alpha breath for `FastNoiseLite`-driven energy modulation on the lantern `PointLight2D`. One function in `Curiosity.gd`.
3. **Pause overlay** — minimal Esc-to-pause `Control` with "resume" + "return to hub". One scene + one autoload toggle, no gameplay edits.
4. **Save scaffolding (no consumer yet)** — JSON `doors_opened` set under `user://`, written on door transition. Read path can land later; this just lays the file format.
5. **Realm 1 ambient bed** — distant drip + low cave drone. Establishes the per-realm audio pattern future realms inherit.
6. **Hub firefly density tune** — particle count / lifetime / scale-curve pass. Pure visual.
7. **Door prompt typography** — swap the default Label font for a soft serif once one is in `assets/`.

Each is one issue, one branch, one PR.

---

## Planned Systems (multi-PR work, not yet started)

These are the rails the game is being built on. Each becomes its own issue (or chain of issues) when scheduled.

### Particle Systems (extensions)
- Embers near lantern + braziers, gravity-affected
- Per-realm overrides (quantity, colour, drift speed) — Hub fireflies + Realm 1 lack the override abstraction

### Dynamic Lighting (extensions)
- Lantern noise flicker (see Next Safe Candidates)
- Secondary environmental lights — distant windows, braziers, glowing flora
- Painterly hand-authored shadow falloff textures vs raycasting

### Shaders
- **Cloak shader** — vertex distortion / animated mask for fabric sway lagging body motion
- **Eye-blink pattern shader** — UV-driven mask opening / holding / closing the cloak's eyes
- **Fog shader** — noise-driven offset on a tinted band, drifting horizontally
- **Painterly post-process** — subtle grain + warm/cool split-tone (late polish)

### Ambient Audio
- Per-realm beds (looping, low headroom)
- Diegetic accents (distant bells, wind, footstep surface variation)
- Lantern flicker → soft sonic correlate
- `AudioStreamPlayer2D` for positional, `AudioStreamPlayer` for global beds
- Bus structure: Master → Music → Ambient → SFX, with fade-in/out helpers per realm

### Puzzle Framework
- Abstract `Puzzle` base: `is_solved()`, `on_solve()`, `on_reset()`
- Each realm subclasses with its own state model
- Puzzle solve hooks lore reveal + door-back-to-hub unlock

### Dialogue / Lore Overlay
- Reverent text presenter — slow fade-in, generous holds, slow fade-out
- Soft serif / hand-lettered font (no system sans-serif)
- Single line at a time; no boxes, no portraits, no ticking crawl
- Triggerable by zone, puzzle event, or lantern proximity

### Save System
- Versioned JSON under `user://` — doors opened, realms completed, lantern state, lore fragments
- Auto-save on door transition; no save UI initially
- Robust to schema additions

### Hub Layout (extensions)
- New doors fade in as realms become available
- Door state persisted through the save system

### Settings / Pause (beyond the minimal overlay above)
- Volume sliders, controls remap (mobile / desktop)
