# Curiosity's Doors

## North Star
"Curiosity's Doors" is a 2D side-scrolling atmospheric puzzle game.
- ONE hero: Curiosity — cloaked traveler, glowing lantern, blinking-eye cloak pattern, face hidden.
- The world is a hub of DOORS. Each door leads to a distinct realm with its own emotional/symbolic theme, palette, soundscape, and PUZZLE.
- The hero solves a puzzle in each realm to progress.
- Visual bar: hand-drawn painterly, Hollow Knight-tier polish. Dark, moody, glow-lit, muted palette with warm gold accents.
- Technical bar: complex layered systems — parallax, particles, dynamic lighting, shaders, ambient audio, save/load, scene transitions, dialogue/lore system.
- Narrative bar: layered storylines that reveal across realms. Melancholic, introspective, beautiful but unsettling. Never cute, never loud.
- Quality gate: every merged PR must leave the game MORE visually appealing OR more technically robust OR more narratively rich. Never regressions.

## Quality Gate
Every PR must:
- (a) pass `godot --headless --import` cleanly
- (b) pass `godot --headless --export-release "Web" build/index.html` cleanly
- (c) not regress visuals, performance, or feel — A/B against the prior live build before merging
- (d) reference an issue (`Closes #N`) — no orphan PRs except the meta-workflow PR itself

## Session Start Protocol
At the start of every session, before touching code, do these in order:
1. Read `CLAUDE.md` (this file)
2. Read every file in `docs/` — VISION, ART_DIRECTION, REALMS, MECHANICS, STORY, VIBE
3. Run `gh issue list --state open` to see what's queued
4. Run `gh pr list` to see what's already in flight
Only then propose or accept work.

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
docs/        # Living design docs — read every session
tests/       # GDScript unit/integration tests (future)
.github/workflows/     # CI + deploy
.github/ISSUE_TEMPLATE/ # Issue templates per work type
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

For the full painterly bible, see `docs/ART_DIRECTION.md`. For tone-words allow/deny lists, see `docs/VIBE.md`.

## Current Skeleton Status
- Placeholder `ColorRect` stands in for Curiosity's painted sprite
- `GradientTexture2D` radial placeholder for the lantern light — replace with a hand-drawn falloff when art lands
- No parallax, no fog, no doors, no realms yet — these are the next feature branches
