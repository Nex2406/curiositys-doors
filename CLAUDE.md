# Curiosity's Doors

## Purpose & Vibe
A 2D side-scrolling atmospheric game about a cloaked traveler named **Curiosity** who wanders between surreal realms linked by doors, guided only by the warm glow of a handheld lantern. The tone is melancholic, exploratory, and quietly reverent — more Hollow Knight-on-a-dream-diary than action platformer. Every scene should feel painted, still, and a little haunted.

## Tech
- **Engine:** Godot 4.6 (GDScript, Forward+ renderer)
- **Target:** HTML5 / WebAssembly build
- **Hosting:** GitHub Pages, deployed via GitHub Actions on every push to `main`
- **Language:** GDScript only for now (no C# / GDExtension)

## Folder Conventions
```
scenes/      # .tscn files (PascalCase, one per scene)
scripts/     # .gd files (PascalCase, matching the scene or class it drives)
assets/
  <category>/<name>/   # e.g. assets/characters/hero/, assets/environments/forest/
tests/       # GDScript unit/integration tests (future)
.github/workflows/     # CI + deploy
build/       # Web export output — gitignored
```

## Naming
- **Scenes & scripts:** `PascalCase` (e.g. `Curiosity.tscn`, `Curiosity.gd`, `ForestRealm.tscn`)
- **Assets:** `snake_case` (e.g. `lantern_glow.png`, `cloak_idle_01.png`)
- **Input actions:** `snake_case` (`move_left`, `move_right`, `jump`)
- **Exported script vars:** `snake_case`

## Verify Commands (PowerShell)
Run these from the project root before pushing anything significant:

```powershell
# Re-import all assets headlessly (safe to run anytime)
godot --headless --import

# Full web export (matches what CI produces)
godot --headless --export-release "Web" build/index.html
```

If `godot` isn't on PATH, substitute the full path to `Godot_v4.6.*_win64.exe`.

## Commit Format — Conventional Commits
- `feat: add drifting fog particles to forest realm`
- `fix: lantern light no longer culls at edge of viewport`
- `chore: bump Godot action to 4.6.3`
- `docs: sketch door-transition design`
- `refactor: extract RealmBase common logic`
- `test: cover jump buffering edge cases`

Scope tags (`feat(hero):`, `fix(ci):`) are welcome when they clarify.

## Golden Rule
**`main` must always deploy green.** If a push to `main` breaks the Pages build, revert first and diagnose on a branch. All experimental art, shaders, new realms, and mechanic prototypes live on feature branches until they import cleanly AND export to Web cleanly.

## Art Direction (keep future prompts on vibe)
- **Style:** hand-drawn, painterly, visible brush texture, soft edges
- **Palette:** muted deep blues, purples, greys, desaturated teals — with a single warm accent (lantern gold, ember orange) for focal points
- **Lighting:** always dark base + `CanvasModulate` dimming + PointLight2D glow. Light is the character's companion, not ambient fill.
- **Silhouettes:** Curiosity reads as a tall, narrow hooded shape — the cloak is the costume, the eye is the signature
- **Motion:** slow, weighty, drifting. No zippy arcade feel. Lantern sway and cloak flutter sell the atmosphere more than footstep speed.
- **UI:** near-zero. No HUD until gameplay requires one. Let the world speak.
- **Backgrounds:** parallax painted layers, thick atmospheric fog, distant shapes, drifting motes/particles

## Current Skeleton Status
- Placeholder `ColorRect` stands in for Curiosity's painted sprite
- `GradientTexture2D` radial placeholder for the lantern light — replace with a hand-drawn falloff when art lands
- No parallax, no fog, no doors, no realms yet — these are the next feature branches
