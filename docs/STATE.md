# Current State (auto-narrative — update at end of every session)
_Last updated: 2026-06-12_

## Live loop
Hub.tscn ↔ Realm1 (cave traversal) ↔ Hub return. Door 1 wired.
Realm 1 exit plays a one-line lore moment before the fade.
Door 2 / Door 3: stubs.

## Hub — door-selection scene
Reframed to a full-bleed painterly composition (target ref:
`assets/_reference/hub_target_2026-06-09.png`). Screen-anchored gradient `Sky`
CanvasLayer + `Vignette` overlay fill the viewport at any window size (no black
bands), solid violet ground (no void), soft moon glow, dimmed nebula stars.
Camera zoomed out (Hub-only override, zoom 0.45) so the hero reads small (~11%
of viewport) on the floor (~74% down). Three equal-size arch doors spread WIDE
left/mid/right, bases on the floor, each levitating (sine bob ~18px, 3.5s,
phase-offset per door — whole door bobs so label + hitbox ride it). Entry is
**X-proximity** (`Hub.gd`): the door the hero stands beneath highlights + shows
`[Y] Enter` (`Door.set_active()`); interact triggers it. Door art is still the
placeholder arch — ornate door / eyed moon / silhouettes are the next art lift.

## What is wired
- Curiosity locomotion: idle / walk / run / jump / air / land
- Lantern PointLight2D with placeholder gradient + soft flame flicker;
  cast-light energy also breathes (two out-of-phase sines) so the warm pool
  feels alive while idle
- Parallax in Hub + Realm 1
- Tilemap floor + platforms in Realm 1 — warm ember "Crimson Hollow" ambient
  `(0.9, 0.2, 0.2)`: orange-lit rock, cold teal water, lantern as the focal coal
- **Moving platforms in Realm 1** (`Realm1.gd` `_setup_pieces`) — the level is one
  hand-painted static `TileMapLayer`, so each floating piece is found by connected
  components and LIFTED into its own `AnimatableBody2D` (art copy + merged collider)
  animated by a looping tween; `sync_to_physics` carries Curiosity when she rides
  one. The painted floor/terrain stays baked & static. Motion is data-driven per
  piece: `PIECE_MOTION` (side / updown / bob / *_fast / static) + `PIECE_SPEED` /
  `PIECE_DIST` dials + global `MOTION_DURATION_SCALE`; both mirrored halves tuned to
  match. `DEBUG_PIECE_LABELS` (off) floats each piece's index in-game for picking.
- **Realm 1 depth + camera pass** (`Realm1.gd` `_setup_atmosphere` / `_drive_camera`)
  — pushing toward a Hollow-Knight read. Value separation across the 4 parallax
  bands (`BAND_TINTS`: far = light/cool/hazy → near = dark) + a shader **vignette**;
  widened parallax speed spread (`PARALLAX_X`, far crawls / near rushes) for
  receding space; ambient lifted (`AMBIENT_LIGHT`) after it read too dark. Camera
  zoom 1.6 → 2.0 (Curiosity at a believable scale). **Camera is hand-driven**
  (`_drive_camera`): follows X always, follows height only while grounded (holds
  during a jump so hops don't bob), eased by `CAM_LERP`. A foreground silhouette
  frame was tried and rejected (procedural shapes looked crude — revisit with
  painted art).
- Door interact (Y key) → scene transition with fade
- Hub respawn at the door Curiosity returned through
- **SaveManager autoload** (`scripts/SaveManager.gd`) — M1 foundation, the single
  source of persistent game state: doors-opened set, inventory counts, named
  flags, in one versioned JSON store at `user://` (IndexedDB-backed on web, so
  saves survive a page refresh). API: `save_game`/`load_game`/`reset`/`has_save`,
  `mark_door_opened`/`is_door_opened`, `add_item`/`item_count`,
  `set_flag`/`get_flag`. Accessors auto-persist; `load_game` merges over a
  complete default (forward-compatible). First real consumer: `Door.trigger()`
  records a door opened on entry. Headless round-trip self-test in
  `tests/test_save_manager.gd` (9/9 pass).
- **Dialogue service** (`scripts/Dialogue.gd` autoload, wraps existing
  `DialogueBox.tscn/.gd`) — M1 foundation. Any scene can run a multi-line
  sequence with `await Dialogue.say([...lines...], speaker)`, which resolves
  once the player dismisses the last line. One dialogue at a time;
  `is_active()` + `started`/`closed` signals. The DialogueBox itself (typewriter,
  [Y]/space/click advance, snap-to-complete, blink indicator) was already built
  for the Intro; this just makes it callable from anywhere. No canonical lines
  authored yet — Advika writes them; content is the caller's. Headless test
  `tests/test_dialogue.gd` (8/8 pass).
- **AudioManager** (`scripts/AudioManager.gd` autoload) — M1 foundation. Ambient
  + SFX buses created at runtime (routed to Master); two ambient players
  crossfade when a scene requests a new track and no-op on re-request.
  `play_ambient(stream, name)` / `play_placeholder(name)` / `stop_ambient` /
  `play_sfx`. Placeholder ambience is a soft seamless-looping low drone
  synthesized in code (no committed/licensed audio) — real per-scene tracks
  (hub, prologue, each realm; Advika sources them) drop in with a one-line swap.
  Hub + Realm 1 play the placeholder on enter. Test `tests/test_audio_manager.gd`
  (16/16 pass).
- **RealmBase** (`scripts/RealmBase.gd`, `class_name RealmBase`) — M1 foundation,
  the template future realms inherit. On enter: play ambient, set visited flag,
  restore saved realm state; hooks `_on_realm_ready` / `capture_state` /
  `apply_state` for subclasses; `exit_to_hub()` saves → optional exit lore →
  transitions home. Realm state persists via SaveManager's per-realm namespace
  (`set_realm_state`/`get_realm_state`). **Realm 1 is NOT on RealmBase yet** —
  that retrofit is M3. Proven by `TestRealm` (throwaway, not shipped/reachable):
  `scenes/realms/TestRealm.tscn` — [Y] collects a token (persisted), [S]/↓ exits;
  relaunch restores the count (in-realm save/restore proof).
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
- Puzzle framework (docs-only)
- No "continue / resume on boot" flow yet — the game always starts at the Intro.
  SaveManager persists and RealmBase restores per-realm state on *re-entry*, but
  there's no title-screen "continue" that boots you back into your last realm.
  That's a front-end concern (M6), not an engine gap.
- Realm 1 still predates RealmBase (its own bespoke Node2D). Retrofit is M3.
- Hand-painted lantern falloff (still gradient placeholder)
- Cloak / eye-blink / fog shaders
- Per-realm ambient audio

## Last session
[2026-05-17 — Close the agentic loop](SESSIONS.md#2026-05-17--close-the-agentic-loop)

## Next 3 safe candidates
_**M1 — Core engine foundations is COMPLETE** (SaveManager · Dialogue ·
AudioManager · RealmBase, all shipped + green). Active milestone is now **M2 —
Combat & enemy/boss framework**._
1. **M2 — wire Curiosity's combat animations** — the attack / hurt / dash /
   charged frames are imported but unreachable; bring them into the state
   machine. First combat brick, no enemies yet.
2. **M2 — reusable `Enemy` base** — patrol / detect / attack / take damage / die,
   proven on a placeholder enemy in a test arena (reuse RealmBase / TestRealm).
3. **M2 — reusable `Boss` base** — health bar, ≥2 phases, telegraphed attacks,
   defeat beat. The shared spine every realm boss inherits.

_Content waiting on Advika (drops into the finished engine anytime): real
ambient tracks per scene; Curiosity's dialogue lines for a real in-game moment._

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
