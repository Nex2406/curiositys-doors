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
- SaveManager exists + persists, but no scene yet *restores* from it on boot
  (no resume-to-hub / resume-into-realm flow); proven via self-test, not yet
  via in-game refresh. That's the next M1 brick (TestRealm save/restore).
- Hand-painted lantern falloff (still gradient placeholder)
- Cloak / eye-blink / fog shaders
- Per-realm ambient audio

## Last session
[2026-05-17 — Close the agentic loop](SESSIONS.md#2026-05-17--close-the-agentic-loop)

## Next 3 safe candidates
_Still inside M1 — Core engine foundations. Keep laying bones before realms._
1. **M1 — Dialogue/textbox system** — generalize the one-line LoreMoment into a
   sequenced multi-line textbox in Curiosity's voice (`DialogueBox.tscn/.gd`
   already exist, half-built — finish + wire). Satisfies the M1 "Curiosity
   speaks a multi-line sequence" done-when.
2. **M1 — Audio manager** — autoload ambient bus + SFX hooks; plays a per-scene
   ambient track on enter, stops on exit. Satisfies the M1 audio done-when.
3. **M1 — RealmBase + TestRealm + save/restore** — realm template (entry/exit/
   lore/audio/save hooks) proven on a throwaway TestRealm that saves on exit and
   restores after a page refresh, exercising the new SaveManager in-game.
   Closes the remaining M1 done-when items.

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
