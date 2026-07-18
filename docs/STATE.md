# Current State (auto-narrative — update at end of every session)
_Last updated: 2026-07-17_

## ⚠ Working tree holds APPROVED-BUT-UNCOMMITTED work (2026-07-17)
Advika's standing rule since 2026-07-16: **no commits to main without her
explicit say-so.** Approved and waiting: the LAYERED UNDERWORLD
(`scenes/UnderforestTest.tscn` + `scripts/UnderforestTest.gd` — the realm 3
builder rerun per layer, floor gaps drop endlessly deeper), realm3.md
Underhollow edits, SKETCHBOOK entries, session docs. Parked/rejected but
present: `scenes/RearrangeTest.*`, `tools/R3ActMocks.*`,
`_r3_mocks_preview/`. The finale design itself (The Bloom, Consciousness,
the Heart of the Hollow) IS on main in `docs/realms/realm3.md`.

## Realm 3 — the fungal forest, iterated live with Advika (2026-07-15)
`scenes/realms/Realm3FungalTest.tscn` (+`scripts/Realm3FungalTest.gd`) — a
LONG walkable cavern (world -1050..26000, ~27k px, 5-min-walk scale), fully
generated in code with a fixed rng seed. Iterated live with Advika through
~10 rounds; the grammar that survived:
- **Meadow floor** (`_floor_mat`): ONE gradient field — every clump picks
  its own depth (tint slides lit→dark, z follows, height rides two
  overlapped sine waves + jitter). Continuous (she is never in the air,
  she wades IN the growth) but no strip/band anywhere. The old seam-belt
  tuft row and flat walk-mat layers are DEAD — they read as moss strips.
- **Platforms are mushrooms ONLY** (`_shroom_platform`): giant caps with
  one-way colliders on the dome. Low steps = half-buried domes (bury 210);
  higher steps = full mushrooms with stems (bury 40). Climb arcs
  (low→mid→high, ≤130px steps) at hand zones B/C/D + `ARC_XS`; lone hop
  domes every ~800px between them. Rocks are DECOR only (`_boulder_decor`,
  no growth on stone, nothing walkable — Advika's law).
- **Background: composed vignettes, overcrowded then eased** — mid band
  builds rotating set-pieces (cap family / spire grove / cap + thin stalks
  / glow garden) each with one hue glint; backdrop giant behind every 3rd;
  tall thin caps (1/2/5/7/8) thread the gaps; far band has spires, ghost
  mushrooms w/ alternating glints AND a giant cap skyline. Giant caps wear
  LOUD hues (`CAP_HUES` teal/moss/blue) + glow auras (`_cap_aura`).
- **Glow hues** inside the palette: amber gold, pale cyan, moss green
  (GLOW_WARM/COOL/MOSS); purple stays Curiosity's. Fireflies removed
  (Advika); spores + glowers carry the air. MAX_GLOW_LIGHTS 24, rest bloom.
- **Roof**: ONE line (ROOF_Y -380) with hanging band; above it a
  vertex-color gradient fades into near-black — jumping never reveals
  bands/lumps (two bugs fixed there). Camera: zoom 1.0, Y clamped -180.
- **Exit door** at x 25580: Realm 1's exact arch+glow+Door.gd recipe,
  `[Y] Return` → Hub. Hub Door 3 targets realm_3 — **the loop is closed**.
- **Eyes HUD tinted realm-teal** via `eye_tint` (violet art, green-fed
  multiply — no art change, other scenes keep purple).
- **Ref set-pieces, kept RARE (Advika 2026-07-16: variety, not wallpaper)** —
  the target refs' pebble-rimmed-mass grammar inside the teal mood:
  `_hang_chunk` (black roof islands, rimmed sides/belly, lit frond tassel;
  x 820 + 5500), `_rim_platform` (floating framed slabs, walkable one-way;
  a two-slab bridge links B's mushroom to C's dome, one more steps off the
  C stack top). Masses must hang in OPEN AIR: the roof curtain eats ~250px,
  the meadow ~250px — anything inside drowns. `_pebble_row/_pebble_col`
  now tile a span at one uniform fitted scale (no naked ends, no strays).
Harness: R3_SHOT / R3_SHOT_X. R restarts, ESC → Hub. Environment only —
no enemies, no puzzle yet.

## Realm 2 — R2-M1 quake + liftoff SHIPPED (test scene)
`scenes/realms/Realm2LiftTest.tscn` (+`scripts/Realm2LiftTest.gd`,
`scripts/LevitatingIsland.gd`, shared `scripts/Realm2Background.gd`) — the
full setpiece, playable: flat mossy intro → step onto the buried island →
storm builds → the tear → an ENDLESS boss-gated ascent (LevitatingIsland
`endless` mode, cruise ~130px/s): the island keeps climbing until the wizard
falls — R2-M7 wires `stop_levitation()` on the defeat beat. The corridor
dressing recycles seamlessly (wrap-above-view per pass span), so the sides
never thin out no matter how high the ride goes. The embedded island is CAMOUFLAGED (ground-dark tint,
dormant glow, frozen plants) and wakes to full color over the tear — no
pasted-on contrast. Ground is a seamless moss body: staggered big-finger rows
to silhouette depth, crest + mounds skyline, seam belt interlocking the upper
masses, fringe/hedge crop edges dissolved by shader. Falling off (any phase)
plays out past the frame, closes an eye, respawns with Curiosity's invuln
blink; 3 lifelines then scene restart. Harness: R2_SHOT / R2_SHOT_X /
R2_SHOT_LIFT(progress) / R2_SHOT_FALL / R2_TINT (layer forensics).
The ascent corridor is dressed (2026-07-08): vine trunks, moss-overhang
platforms with hanging beards/ferns, perched rocks, sparse near-black
foreground slabs (z13) — all sliced + violet-shifted from the full Mossy
pack by `tools/slice_mossy_pack.gd` (repeatable; thorn arcs + sprouts left
uncommitted until R2-M5/M6). Density tapers so the arrival opens into sky.
Phase ladder: [`docs/realms/realm2.md`](realms/realm2.md) — R2-M0 ✅ R2-M1 ✅;
R2-M2 combat was already shipped by the golem work. **THE WIZARD'S TRIAL IS
LIVE (2026-07-12 pt.2):** 7s into the true climb the wizard flickers in ON
the island and fights — he teleports across the deck (landings scatter, avoid
Curiosity, escape-reflex when she closes in with a 0.6s grace beat per
landing), conjures RUNE ORBS in front of himself (max 2; invulnerable rolling
shove-hazards with real inertia — push, never damage; they overstay 8-14s
then commit to a direction and roll off; kill plane rides 900px under the
climbing island), and FIVE strikes (J/Z, EnemyHealthBar over his head, he
panic-teleports per hit) fell him → `stop_levitation()` → `arrived` → DONE:
"the wizard falls — the storm relents". The boss gate is closed. Her jump is
+15% this level; storm sway sharpens (40px/2.7s) once he's aboard. The intro
forest is fully dressed from the Mossy pack (grounded tree assemblies,
boulder piles, undergrowth carpet every ~150px, edge to edge -1500..3800,
island keeps only its clearing). Trial dials are consts atop
`Realm2LiftTest.gd`; wizard temperament exports on `Wizard.gd`.
Isolation rig: `scenes/RuneOrbTest.tscn` (swaying plank, T trial, K debug
strike). Harness knobs: ORB_SHOT / ORB_TRIAL / ORB_KILL / R2_TRIAL_LOG
(45s economy soak). Rune-orb art palette-shifted by
`tools/tint_runeorb_pack.gd` (repeatable, measured). His art is the BlueWizard
pack palette-shifted in-house by `tools/tint_wizard_pack.gd` (repeatable):
cloak navy→realm violet (measured against `vine_trunk_0`), eye glow
yellow→RED (Advika: evil at a glance). 96 frames in `assets/enemies/wizard/`
(idle/walk/jump + 3 blink variants — teleport-blink pick pending);
`tools/WizardAnimReview.tscn` flips through them live (keys 1-6).
Actor: `scenes/Wizard.tscn` + `scripts/Wizard.gd` — flicker-materialize,
hover bob, `follow()`/`watch()`. The older `Realm2BgTest.tscn` remains as
the background gallery.
Credits: `CREDITS.md` (root) — keep updated per asset, college-portfolio gate.

## Live loop
Hub.tscn ↔ Realm1 (cave traversal) ↔ Hub return. Door 1 wired.
Realm 1 exit plays a one-line lore moment before the fade.
Door 2 (middle) → Realm 2 liftoff setpiece (`Realm2LiftTest.tscn`): no
timer on the arrival — the player stays above the canopy until they leave
via ESC (auto-return removed 2026-07-08, it felt like being kicked out).
Respawn lands under Door2 via `Transition.last_door_id`.
Door 3 → Realm 3 fungal forest (`Realm3FungalTest.tscn`), and its arch
door at the far end returns to the Hub. All three doors live.

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
- Lever / approach / charged / celebrate animations on Curiosity (frames
  imported, not reachable from state machine). Combat IS wired: attack1/2
  combo, dash, hurt, health/invuln, died signal — live in `Curiosity.gd`,
  proven against the golem in Realm 1 and `GolemTest.tscn`.
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
[2026-07-12 (pt. 2) — The wizard's trial](SESSIONS.md#2026-07-12-pt-2--the-wizards-trial-he-conjures-she-hunts-the-island-stops)

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
