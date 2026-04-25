# Art Direction

The painterly bible. Every visual choice answers to this document.

## Core Style
- **Hand-drawn, painterly.** Visible brushwork. Soft edges. Nothing crisp or vector-clean.
- **Rough ink outlines** where outlines exist at all — broken, gestural, never uniform stroke weight.
- **Texture overlay** on every surface: grain, weave, paper-tooth. The world should look like it was painted on damp paper.
- **No pixel art. No flat cartoon. No retro filter.**

## Palette
The base palette is dark and cool. Warm tones are reserved for what the lantern reveals.

### Primary (cool, base world)
- `#0a0e27` — deep blue, near-black; the dominant background tone
- `#2d1b4e` — purple-violet; mid-distance shapes, fog underbelly
- `#1c2a3a` — slate grey-blue; stone, architecture, foreground silhouettes
- `#3a4a5c` — desaturated teal; water, glass, distant fog highlights
- `#6b6f7a` — cool grey; cloak shadow, hub mist

### Warm Accent (used sparingly)
- `#f5b870` — lantern gold; the primary key light, focal points only
- `#c97a4f` — ember orange; flicker highlights, hot rim around lantern
- `#e8d9b0` — bone cream; the eye that blinks on the cloak, the only "skin" tone

### Per-Realm Drift
Each realm shifts the palette without abandoning it. A realm may push toward blue-grey, amber-rust, or grey-violet, but the lantern gold stays gold. Continuity through the lantern.

## Lighting Model
- **Ambient = near-black.** `CanvasModulate` set very dark. The world is underexposed by default.
- **Lantern is the primary key light.** PointLight2D, warm color (`#f5b870`), gentle flicker (random energy modulation in a tight band).
- **Secondary lights are environmental and rare** — a distant window, a brazier, glowing flora. They never overpower the lantern.
- **Shadows are painterly, not technical.** Hand-painted falloff textures, not raycasting.
- **The lantern is the character's companion.** When it dims, the player feels it. Light is emotional, not utilitarian.

## Scale Rules
- **Curiosity is small.** ~1/6 to 1/8 the height of a typical screen. The world is bigger than the hero.
- **Vertical breathing room.** Tall ceilings, distant skies, drifting space above the playfield.
- **Foreground silhouettes** can be larger than Curiosity to crowd the frame and create intimacy.
- **Doors loom.** Door frames are taller than Curiosity by 2x or more. They are reverent objects.

## Animation Principles
- **Slow, weighty, drifting.** Idle should feel almost still. Walk is deliberate, not snappy.
- **Cloak sways like alive.** Bone shader / vertex distortion / sprite-stack — the cloak is its own animation channel, lagging behind body motion.
- **Lantern flickers** with an organic noise pattern — not a sine wave, not a periodic loop. Subtle energy variance, occasional micro-pulses.
- **Eye blink** on the cloak: rare, slow, three-frame. The eye does not track the player; it simply opens, holds, closes.
- **No squash-and-stretch.** No bounce. No anime trail. Restraint.

## Background Construction
- **Parallax painted layers.** At least 3 — far, mid, near. Each is its own painted texture, scrolling at its own rate.
- **Atmospheric fog.** A semi-transparent texture or shader band drifting in the mid-distance. Reduces silhouette contrast at depth.
- **Drifting motes.** GPUParticles2D with a small handful of soft circular sprites. Slow. Sparse. Random vertical drift, slight horizontal sway.
- **Distant shapes** are suggested, not drawn — silhouettes only, no detail. Let the player's eye complete them.

## UI Philosophy
- **No HUD.** Until gameplay strictly requires one.
- **Diegetic feedback** preferred — the lantern dims instead of a damage counter; the cloak settles instead of a "rest" prompt.
- **Text is rare and reverent.** When dialogue or lore appears, it fades in slowly, lingers, fades out. No boxes, no portraits, no ticking text crawl.
- **Fonts:** soft serif or hand-lettered. Never sans-serif system fonts. Never anything that looks like a UI library default.

## What This Looks Like When Done Right
A still frame from any moment in the game should be screenshotable, frameable, and *quiet*. If a screenshot looks like a screenshot, we missed. It should look like a painting that's holding its breath.
