# Mechanics

Every system that runs the game, present or planned. Update this when systems land or change shape.

---

## Existing Systems

### Curiosity (CharacterBody2D)
- File: `scripts/Curiosity.gd`, `scenes/Curiosity.tscn`
- Side-scrolling movement: left/right with `move_left` / `move_right` input actions
- Gravity from project settings
- Single jump on `jump` input action
- Currently a `ColorRect` placeholder — sprite art TBD

### Lantern (PointLight2D)
- Child of Curiosity
- `GradientTexture2D` radial placeholder — replace with hand-painted falloff when art lands
- Warm accent color (`#f5b870`); energy currently static
- Planned: organic flicker via noise-driven energy modulation

### Web Export Pipeline
- Godot 4.6 Forward+ → HTML5 export preset "Web"
- GitHub Actions workflow `.github/workflows/*.yml` builds and publishes to GitHub Pages on every push to `main`
- `.nojekyll` written to allow underscored asset paths

---

## Planned Systems

These are the rails the game is being built on. Each becomes its own issue (or chain of issues) when scheduled.

### Parallax Background Layers
- Three layers minimum: far, mid, near
- ParallaxBackground + ParallaxLayer nodes
- Each layer: a hand-painted texture, scrolling at its own rate, with seam-tolerant tiling
- Per-realm: distinct asset set, distinct color palette, distinct fog density

### Particle Systems
- **Drifting motes:** GPUParticles2D, soft circular sprites, slow vertical drift with subtle horizontal sway
- **Atmospheric fog:** scrolling shader-driven band or large transparent particle quads
- **Embers:** warm particles near the lantern and braziers, occasional, gravity-affected
- **Per-realm overrides:** quantity, color, drift speed shaped by realm theme

### Dynamic Lighting
- `CanvasModulate` set near-black for the base world
- Lantern PointLight2D as the primary key light with organic flicker (noise-modulated energy in a tight band)
- Secondary lights as environmental rarities — a distant window, a brazier, glowing flora
- Shadow casters on foreground silhouettes; painterly hand-authored falloff textures preferred over technical raycasting

### Shaders
- **Cloak shader:** vertex distortion or layered animated mask to simulate fabric sway, lagging behind body motion
- **Eye-blink pattern shader:** UV-driven mask that opens / holds / closes the cloak's eyes on a slow irregular cadence
- **Fog shader:** noise-driven offset on a tinted band, drifting horizontally
- **Painterly post-process (optional, late):** subtle grain + warm/cool split-tone

### Ambient Audio
- Per-realm ambient bed (looping, low headroom)
- Diegetic accent layer (distant bells, wind, footsteps on different surfaces)
- Lantern flicker has a soft sonic correlate
- AudioStreamPlayer2D for positional cues; AudioStreamPlayer for global beds
- Bus structure: Master → Music → Ambient → SFX, with fade-in/out helpers per realm

### Scene Transition System
- A central `Transitions` autoload, single API: `Transitions.go_to(scene_path)`
- Fade-out on a Control overlay (slow black-to-clear, ~1.5s)
- Optional lantern dim on entry, lantern wake on arrival
- Preserves player position relative to door geometry on hub return

### Door Interaction System
- `Door` scene with collision area + interactable prompt zone
- On `interact` input within range: trigger transition to target realm scene
- Doors stay open after first traversal (a returned-from realm reads differently)
- Door state persisted through the save system

### Puzzle Framework
- Abstract `Puzzle` base class: `is_solved()`, `on_solve()`, `on_reset()`
- Each realm subclasses with its own state model
- Puzzle solve event hooks the lore reveal + door-back-to-hub unlock

### Dialogue / Lore Overlay
- A reverent text presenter — slow fade-in, generous holds, slow fade-out
- Soft serif or hand-lettered font (no system sans-serif)
- Single line at a time; no boxes, no portraits, no ticking crawl
- Triggerable by zone, puzzle event, or lantern proximity to a lore object

### Save System
- JSON-serialized save file under user:// — minimal: doors opened, realms completed, lantern state, lore fragments collected
- Auto-save on door transition; no save UI initially
- Robust to schema additions (versioned save format)

### Mobile Touch Controls
- Virtual joystick or tap-zones for left/right
- Tap-anywhere-on-right-half for jump
- Toggleable; auto-detect on touch-capable browsers
- Hidden by default on desktop

### Hub Layout System
- The hub itself is a scene with door slots
- New doors appear (fade-in) as realms become available
- Door positioning is hand-authored, not procedural

### Settings / Pause
- Minimal pause overlay — fade the world, expose only "resume" and "return to hub"
- Settings later: volume sliders, controls remap (mobile / desktop)
