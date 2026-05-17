# Mechanics

Engineering reference for every system that runs the game. **For the living
snapshot of what's wired *right now*, see `docs/STATE.md` — that's the truth
between sessions. This doc is the longer system spec.**

Update this when systems land, change shape, or move between sections.

---

## Current Implemented Loop

End-to-end thing the player can do today:

1. Start in **Hub.tscn** — Curiosity stands in a painted chamber with a single
   door (Door 1) painted into the scene. Parallax + ambient particles wash the
   background.
2. Walk Curiosity right with `move_left` / `move_right` (arrow keys or A/D),
   run with `Shift`, jump with `jump` (space).
3. Approach Door 1 → a floating `[Y] Enter` prompt fades in.
4. Press `interact` (Y) → the door flashes warm, holds the flash, then
   `Transition` autoload fades-out and loads **Realm1.tscn**.
5. **Realm1 — "The Crimson Hollow"** — a hand-built cave platformer with
   four floor gaps, ten platforms, and an exit door on the right wall.
6. Reach the exit door → same interact pattern → fade back to **Hub.tscn**,
   and Curiosity respawns one step beside the door she came back through.

That is the playable loop. Web build of this loop ships to GitHub Pages on
every push to `main`.

---

## Implemented

Systems that exist in code and are wired into the loop above.

### Curiosity (CharacterBody2D)
- File: `scripts/Curiosity.gd`, `scenes/Curiosity.tscn`
- Side-scrolling movement: walk / run (Shift sprint) / single jump, gravity
  tuned low (~350) for a drifting feel rather than arcade-snap.
- State machine: `IDLE / WALK / RUN / JUMP_START / AIR / LAND`. Animation
  per state via `AnimatedSprite2D`.
- Lantern follow + sway: lantern + flame tween across the body when facing
  flips (`lantern_sway_time = 0.2s`, sine ease-out).
- Source art faces LEFT — `flip_h = true` is right-facing.

### Lantern
- Child of Curiosity (`$Lantern`, `PointLight2D`).
- Texture is still a `GradientTexture2D` radial placeholder. Replace with a
  hand-painted falloff when art lands.
- `$LanternFlame` (`Sprite2D`) overlays the warm flame and gets a soft
  sine-based alpha flicker (amplitude 0.05, period 0.4s) in `_process`.

### Door + Hub interaction
- Files: `scripts/Door.gd`, `scripts/Hub.gd`.
- Reusable `Door` is an `Area2D` with `near_door` / `left_door` signals.
  Each door joins the `doors` group on ready.
- `Hub.gd` owns the single `interact` poll — tracks which door is current
  and calls `trigger()` on press. Prevents N doors all polling input.
- `trigger()` flashes the door glow + swaps prompt text, holds 0.3s for
  visible feedback, then routes through `Transition`.
- Realm-bound trips persist `door_id` via `Transition.last_door_id` so Hub
  can respawn Curiosity at the same door on return.

### Scene Transition (autoload)
- File: `scripts/SceneTransition.gd`, registered as `Transition` autoload.
- Single API: `Transition.transition_to(path)` — fades a Control overlay
  black → loads scene → fades back.
- Exposes `last_door_id` for hub respawn.

### Parallax (Hub + Realm 1)
- Hub uses painted parallax layers (nebula, stone floor backdrops, drifting
  motes).
- Realm 1 uses an 8-layer parallax cave painting set
  (`assets/realms/realm1_caves/parallax/0..7.png`).

### Realm 1 — "The Crimson Hollow"
- File: `scripts/Realm1.gd`, `scenes/realms/Realm1.tscn`.
- TileSet built at runtime from `mainlev_build.png` with a single ground-top
  tile, single ground-fill (4 rows deep), and a 3-tile wood-plank platform
  palette.
- Layout: 80 floor cells, 4 evenly-spaced 4-tile gaps, 10 platforms
  including a y=6/7/8 ascending victory path before the exit door.
- Collision attached per-tile (the bug fix in PR #54: `add_source` must come
  *before* the per-tile `create_tile + attach_full_collision` loop or the
  physics layer doesn't propagate and every tile silently has zero collision).

### Touch Controls
- File: `scripts/TouchControls.gd`, `scenes/TouchControls.tscn`.
- Virtual joystick-style controls for touch browsers. Hidden by default on
  desktop, surfaced on touch-capable web.

### LoreMoment overlay (single-line, awaitable)
- Files: `scripts/LoreMoment.gd`, `scenes/UI/LoreMoment.tscn`.
- Reusable single-line lore display: CanvasLayer at layer=100, centered
  Label, soft serif via `SystemFont` fallback chain, no box, no portrait,
  no ticking crawl.
- Lifecycle: fade-in (1.0s, sine ease-out) → hold (3.0s) → fade-out (1.0s,
  sine ease-in) → `queue_free`. Awaitable: `await lore.play_line(text)`.
- Wired via `Door.exit_lore_line` (`@export_multiline String`). If set,
  `Door.trigger()` plays the line between its flash-feedback hold and the
  `Transition.transition_to()` fade. Empty value = no behavior change.
- Realm 1's exit door uses it to land one beat before returning to Hub.

### Web Export Pipeline
- Godot 4.6 Forward+ → HTML5 export preset "Web".
- GitHub Actions workflow in `.github/workflows/*.yml` builds and publishes
  to GitHub Pages on every push to `main`.
- `.nojekyll` written so underscored asset paths serve.

---

## Known Stubs / Out of Scope

Things that exist as assets, comments, or partial code but are NOT currently
wired into the playable loop. Listed here so future sessions don't think
they're real.

### Unwired Curiosity animations
SpriteFrames includes `attack1`, `attack2`, `charged`, `dash`, `hurt`,
`approach`, `lever_pull`, `lever_hold`, `celebrate`. None of these are
reachable from the state machine. See the `# TODO` at the top of
`scripts/Curiosity.gd` — wiring lands when enemies and lever puzzles exist.

### Stub doors
Hub may paint Door 2 / Door 3 into the scene visually, but `_resolve_scene_path`
in `Door.gd` only knows `realm_1` and `hub`. Any other `target_realm` value
prints `[Door] Realm not yet built: ...` and stays open for retry. They are
intentional stubs.

### Docs-only systems
The following are described in this file's **Planned** section and elsewhere
but **have no Godot implementation yet**:
- Save / load
- Multi-line dialogue overlay with positional triggers (the single-line
  lore case is shipped — see "LoreMoment overlay" in Implemented)
- Puzzle framework (abstract `Puzzle` base class)
- Hub layout system (currently hand-authored doors only)
- Settings / pause overlay
- Per-realm ambient audio bus structure
- Hand-painted lantern falloff (still gradient placeholder)
- Cloak shader / eye-blink shader / fog shader

---

## Planned

Rails the game is being built on. Each becomes its own issue when scheduled.

### Particle Systems
- **Drifting motes:** GPUParticles2D, soft circular sprites, slow vertical
  drift with subtle horizontal sway. (Already wired in Hub; per-realm
  overrides not yet implemented.)
- **Atmospheric fog:** scrolling shader-driven band or large transparent
  particle quads.
- **Embers:** warm particles near the lantern and braziers.

### Shaders
- **Cloak shader:** vertex distortion or layered animated mask to simulate
  fabric sway, lagging behind body motion.
- **Eye-blink pattern shader:** UV-driven mask that opens / holds / closes
  the cloak's eyes on a slow irregular cadence.
- **Fog shader:** noise-driven offset on a tinted band, drifting horizontally.
- **Painterly post-process (optional, late):** subtle grain + warm/cool split-tone.

### Ambient Audio
- Per-realm ambient bed (looping, low headroom).
- Diegetic accent layer (distant bells, wind, footsteps on different surfaces).
- Lantern flicker has a soft sonic correlate.
- Bus structure: Master → Music → Ambient → SFX with fade helpers per realm.

### Dialogue / Lore Overlay (extensions beyond LoreMoment)
- LoreMoment ships the single-line variant for door-exit beats. The
  larger system still planned:
  - Multi-line passages with paced reveal between lines.
  - In-realm triggers (proximity zones, puzzle-solve events, lantern-on-
    lore-object detection) rather than only door-bound playback.
  - Optional Curiosity-voice register vs. environmental-narration
    register — same overlay, different cadence/font weight.
  - Bundled painterly serif `.ttf` to replace the `SystemFont` fallback
    chain.
- **Curiosity speaks through this system** — see `docs/VOICE.md` for tone.

### Puzzle Framework
- Abstract `Puzzle` base class: `is_solved()`, `on_solve()`, `on_reset()`.
- Each realm subclasses with its own state model.
- Puzzle solve event hooks the lore reveal + door-back-to-hub unlock.

### Save System
- JSON under `user://` — doors opened, realms completed, lantern state,
  lore fragments collected, collectibles (jade pieces, etc.).
- Auto-save on door transition; no save UI initially.
- Versioned save format for robustness to schema additions.

### Hub Layout System
- Hub as a scene with door slots; new doors fade in as realms become
  available. Door positioning hand-authored, not procedural.
- Forward goal: topsy-turvy, multi-angle door arrangement per the
  2026-05-17 hub concept (see `docs/HUB.md`).

### Realm 1 collectibles
- **Jade crystal pieces.** Curiosity gathers them through the realm; on
  return to Hub, they're forged into the jade key that unlocks Door 2.
  This loop is Realm-1-specific; later realms have their own concepts.

### Settings / Pause
- Minimal pause overlay — fade the world, expose only "resume" and "return
  to hub". Volume / controls remap later.

---

## Next Safe Feature Candidates

Small, scoped, low-risk next steps. Pick from here when starting a session;
none of these require designing a new system from scratch.

1. **Realm 1 jade-piece pickups** — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
2. **Polish pass on platform rocks** — `T_PLATFORM_L/M/R` currently reuse
   the solid sub-floor block. A peak-top platform tile (e.g. row-22 rocky-
   band coords) would read more as a floating ledge than a chunk of
   detached floor.
3. **Audit the parallax cave painting against the brown-cave foreground** —
   the deepest layer is still a cool blue-grey while the tiles are warm
   brown. The tonal split shows when there's an exposed gap.
4. **Hand-painted lantern falloff** — replace the `GradientTexture2D`
   placeholder with a painterly radial falloff. Pure art swap, no
   gameplay change.
5. **Painterly serif `.ttf` for LoreMoment** — bundle a free-license
   serif so the lore overlay stops depending on host-system fonts.
