# Current State (auto-narrative — update at end of every session)
_Last updated: 2026-07-31_

## 2026-07-31 — THE OPENING: a prologue that types, then one card, then the cave
The game now has a front-to-back opening. **There is no hub in the flow any more** —
BEGIN goes menu → prologue → quote card → Realm 1. (Hub.tscn still EXISTS and is
still referenced from `Door.gd:177`, `MainMenu.gd` CONTINUE, `Intro.gd`,
`RealmBase.return_scene`, and the ESC-return in Realm 2 / Realm 3. Nothing deleted.)
- **The prologue** (`scripts/Prologue.gd` + `scenes/prologue/Prologue.tscn`) — five
  stanzas typed onto black, 38.5s measured. It lays over the LIVE menu rather than
  cutting: the painting dissolves (1.6s) with nothing written over it, is freed the
  instant it is covered, then a held beat of black, and only THEN the first character.
  Written for a player who has not read the book: someone was already here → you came
  on a pull you never chose → they put it there on purpose → three doors, one at a
  time, each opens the next → go on. `PRO_TIME=1` prints the depicted length and the
  max characters landed in one frame (must be 1). `PRO_SKIP=1` jumps to the card.
- **It only types.** The old per-line skip is DELETED, not patched: a key pressed
  during a non-skippable wait stayed latched and was spent by the NEXT line the moment
  it began, so a line the player never touched appeared whole. ESC abandons the whole
  prologue; nothing else is listened to.
- **Typing tick** (`tools/make_typing_sfx.py` → `type_tick.wav`) — seeded NOISE, no
  fundamental, 500-1600Hz, 55ms, 6ms attack. Anything with a pitch becomes a drone at
  twenty ticks a second. Four players round-robin, ±9% pitch jitter, 55ms rate cap,
  spaces silent, −21dB.
- **`scripts/Typewriter.gd`** — the float-accumulator cursor, punctuation pauses and
  `{0.5}` pause tokens, shared by the prologue and the card. One implementation.
- **`scripts/QuoteCard.gd`** — THE quote template, and both quotes in the game are now
  literally the same object: Fear's line at the Realm 1 → Realm 2 handover, and the new
  one before Realm 1. Quote / optional speaker / attribution / prompt, Cormorant
  Garamond Italic at Light 300 in `#E8C88A`, 64pt. An empty speaker is NOT BUILT (a
  hidden Label still costs its separation). It owns no pacing and no black —
  `QuoteTransition` still owns the hold, the music cross, the scene change and the
  blink-lift. Measured proof the two cards match: first line 66px tall in both, delta 0.
- **The Realm 1 opening card** is "And before I could argue, / the floor gave way."
  with no speaker. NOT typed — it is a held breath after the prologue, on black.
- **The doorway in Realm 1 is built out of REALM 2's assets** (Advika: "the connecting
  doorway") — two mossy rock piers, trees leaning in to meet as the arch, front-layer
  vines and leaves crossing the posts, loose rock bedding the base, R2 itself seen
  through the passage (`r2_gateway_view.png`, baked by `tools/bake_gateway_view.py`),
  fireflies crossing over. `DOOR_ART=painted` still gets the old arch for A/B.
- **The bug worth remembering**: a `CanvasLayer` nested inside a `CanvasLayer` does NOT
  inherit it — `layer` is a global sort key. The card sat at 0 under the bridge's own
  black at 200 and the first capture came back an entirely empty frame.

## 2026-07-29 — THE GAME HAS A FRONT DOOR: the main menu is built and boots
`run/main_scene` is now `scenes/UI/MainMenu.tscn`. Everything is on exported dials;
`@tool`, so it composes live in the editor. The 2026-07-25 menu was scrapped for
being AI-looking — this one is built on art Advika chose (a painted arched
corridor, an eye-and-filigree frame plate, a painted title).
- **The opener, in order** (`MainMenu.gd`): the border INSCRIBES ITSELF over the
  bare painting (3.5s) → a 0.35s beat → the title is WRITTEN (6.5s) → the entries
  rise in, staggered 0.14s apart. Music (Starfall Dreams) swells from silence over
  4.5s from the top. `R` replays the whole opener in a debug build.
- **The write-on** (`shaders/title_write_on.gdshader` + `tools/make_title_write_order.py`)
  — one shader, two order maps. Each map's R channel says WHEN a pixel appears and
  its G channel how close it is to a stroke, so a warm nib glow can bloom into the
  dark beside the line it is drawing. The title runs left-to-right per line with a
  pause between them; the border runs from the crown eye down BOTH sides at once,
  meeting at the moon on the bottom rule. Baked from connected components, not by
  hand. `tools/make_frame_draw_order.py` does the border.
- **The plate**: separable gaussian blur (`menu_blur.gdshader`) under a grade,
  two domain-warped mist sheets, dust in two depths, all five frame eyes breathing
  a fifth of a cycle apart, the corridor light breathing on two out-of-phase sines,
  and the finished title floating 6px on an 8s cycle.
- **Entries**: BEGIN · CONTINUE · SETTINGS · QUIT in Cormorant Infant Italic.
  CONTINUE is always on the plate but disabled until a save exists (M6 lights it);
  QUIT is dropped on web. Selection is a sliding hairline, never a highlight box.
- **Settings** (`scenes/UI/SettingsPanel.tscn`) — Master / Music / Sound volume,
  persisted through SaveManager, applied to the buses on the proper linear→dB
  curve. Its own scene so the pause menu can open the SAME panel later.
- **Menu SFX** synthesised in `tools/make_menu_sfx.py` (no licence): a soft
  inharmonic move tick — inharmonic on purpose, so fast repeats never form a tune —
  and a two-note select chime.
- **`tools/AudioPicker.tscn`** auditions every clip we own, including the unused
  music packs read straight off disk from `Downloads/_audio_library` (266MB
  deliberately NOT imported into the project).
- **Four bugs worth remembering**: (1) Godot rounds Control positions to whole
  pixels, so animating a Control's position makes it stair-step — the title floats
  via a Node2D parent instead. (2) A canvas shader that writes `COLOR` from scratch
  DISCARDS the node's modulate, and reading `COLOR` in `fragment()` to get it back
  is wrong (it is already multiplied by the texture — that squares the art and kills
  any glow); capture it in `vertex()`. (3) `Tween.parallel()` binds to the PREVIOUS
  tweener, so `tween_interval()` then `parallel().tween_property()` runs the
  property DURING the wait. (4) With `stretch/aspect=expand`, a non-16:9 window
  shows more canvas than 1920x1080 — layers pinned to that size leave bare strips.

## 2026-07-27 — REALM 1 IS SHIPPED, END TO END, ON MAIN
The cave is live: **https://nex2406.github.io/curiositys-doors/**. Hub Door 1 →
the rebuilt cave → 17 jade → the portal → Fear's quote card → The Trial. The old
Crimson-Hollow realm and its four abandoned rebuild rigs are DELETED.
- **The level** (`scripts/Realm1PlatformTest.gd`, `scenes/realms/realm1/`):
  26 platforms with colliders measured from the painted art, 17 jade, 3 ground +
  4 ceiling golems, ten parallax depths, churning mist, the eruption door.
- **Golems** (`BoulderGolem.gd`): no wind-up state — the curl plays while he is
  already charging. Committed charges with a 150px overshoot, 0.75s gather, 7s of
  hunting life then he burrows away, death bursts into grit. He only wakes and
  only launches when Curiosity is on HIS ground; his life clock pauses while he
  waits her out on a platform. His body ignores her entirely (she shares the
  floor's collision layer, which let him stand on her head and be shoved).
- **The door**: erupts when the last jade is gathered AND she reaches the pocket,
  grows out of the floor over 5s with staged quakes and rubble, holds a window
  onto Realm 2 (a real capture of the Trial forest), scattered card-hued aura.
  [Y] only works once it stands. A 40-frame overgrown-door replacement was built
  and scrapped on sight; those frames are parked, untracked, in
  `assets/realms/realm1_door/_new_set_unused/`.
- **The bridge** (`QuoteTransition.gd`): 10s on Fear's line in Cormorant Garamond
  Italic Light on `#E8C88A`, then "Press any key to continue" and it waits. Both
  realms' tracks cross underneath, undicked, and the black lifts as a blink.
- **Haptics** (`Haptics.gd`): `buzz` for impacts, `rumble(s, strength)` for
  sustained beats (Realm 2's liftoff uses it). The screen kick is punctuation —
  13px, gone in 0.3s. NOTE: laptops have no motor; a controller or an Android
  phone browser is the only way to feel the real thing.
- **Measurement tools, all repeatable**: `measure_plat_rims.py`,
  `measure_golem_contact.py`, `measure_roof_line.py`, `clean_cling_frame.py`,
  `make_jade_sfx.py`, `bake_portal_view.py`. Pickers: `FontPicker.tscn`,
  `SfxPicker.tscn`.
- **The bug that mattered**: art loaded with
  `Image.load_from_file(globalize_path(...))` returns null in an exported build,
  so the live cave rendered as a black screen while the editor looked perfect. Use
  `load()`. A green export does NOT catch it.

## 2026-07-22 — R1 BACKGROUND locked-ish (`feat/r1-cave-rebuild`, NOT merged)
Advika's vision (now in docs/realms/realm1.md): dark underground cave,
mysterious aura; parallax + depth + chaos; NOTHING faded. After a brutal
iteration day the pipeline that survived her eye:
- **`tools/recut_slices.gd`** — outline strokes physically removed from 31
  Maaot slices (edge ring shaved, interior strokes inpainted), output
  `assets/realms/realm1_cut/`, fully opaque. HER LAW: never fade/alpha-trick
  an outline away; recut the art. (scene-dressing law #7 in memory.)
- **`tools/compose_band_strips.gd`** — each parallax band pre-composed into
  ONE fused 5200px strip (union-solidified w/ undulating fill line, wrap-
  seamless, near-zero blur), so no per-asset boundaries/lips/seams exist.
- **`shaders/fog_mass_screen.gdshader`** — pieces lit BY the fog: art color ×
  local fog brightness (diagonal spill, calibrated to
  docs/reference/cave_ref_04.png samples — the Maaot promo, saved as canon
  with cave_ref_03). NO luminance gates (they read as translucent slabs).
- **`scenes/realms/realm1/Realm1BgTest.tscn`** — the live rig: 4 band strips
  (far billows / warm spire forest / mid rocks / near-black row + 2 ceiling
  curtains baked in), 3 drifting `cave_mist.gdshader` sheets, ←/→ pan,
  BG_SHOT/BG_CAM_X harness prints render-vs-ref anchor samples.
Verdict: "ok...im not too happy but lets just move on" — good enough to
build on, not sacred. CaveRefRecreate.tscn holds a hand-copy attempt of
ref_04 (paused mid-polish). Contact sheets: tools/AssetContactSheet.tscn.
PlantsAnimated pack staged (3 pieces in assets/realms/realm1_plants/).
PROCESS LAWS from today: ask when confused (don't guess), don't pop Godot
windows over her work, background only until she says otherwise.

## 2026-07-19 — Realm 1 rebuild in progress on `feat/r1-cave-rebuild` (NOT merged)
The old Realm 1 stays live on main. The rebuild uses the Maaot Cave pack as a
DECAL pack (region Sprite2Ds + invisible collision — never a tileset; Advika's
build-spec doc, region atlas + lighting stack, is canon) with the L2 moss pack
restored to its ORIGINAL green for boundary growth. After four rejected
one-shot builds, the working method is the one-screen loop: match ONE frame to
docs/reference/cave_ref_01/02.png, Advika judges, then grow section by section
(her A–G beat spec: landing → widening gaps → chasm mover → descent → phased
vertical movers → lantern-only dark stretch → door). Current frame:
`scenes/realms/realm1/CaveComposition.tscn` — fog core verified at exactly
RGB(134,131,60), moss-wrapped boundaries NOT yet her vision (she draws it next
session). Assets: assets/environment/cave/ (sheets), realm1_cavern/ (slices;
SmallRocks slices are the true teeth — the Floor-sheet "stalactite" atlas
regions are pebble columns), realm1_moss/ (green). Support: moving_platform.gd
(sync_to_physics=false + sine), cave_fog/vignette shaders, Realm1Cave.tscn
skeleton (paused). Realm1CaveTest.tscn holds the three earlier rejected looks
for reference.

## 2026-07-18 — EVERYTHING SHIPPED TO MAIN (Advika's call)
The 07-16 uncommitted-work backlog is CLEARED: the layered Underworld is
committed, and the whole `feat/r2-void-moth` branch merged (#165 closed).
Realm 2 now has: **the VOID MOTH** (Advika's art: turn-fold + comet-attack
sheets, size-normalized by `tools/align_voidmoth_turn.py`; talon-arc dives;
the LIGHT-WALL: held L grows the lantern to ~680px and dives break on it,
4 lit seconds bursts the moth into purple motes — resting flame is
harmless; a landed dive consumes the moth and re-arms the next), **her
painted TAROT TRIAL CARD** (`TarotReading` — flip + glint + typewriter
verses + both threat portraits + reveal chime, ducks the music, gates the
wizard fight; replaced code-drawn TarotCard, deleted), **Moonlight** (first
real music track, AlkaKrab, Realm 2 ambient with duck_music/unduck_music),
**maximized background** (crowned silhouette forests grown into mid+far
parallax bands), **Haptics autoload** (phone/gamepad buzz + screen-kick on
the tear, hits, orb shoves). Rigs: `VoidMothTest` (isolation, live burn
readout + reach ring), `tools/VoidMothAnimReview` (frame-by-frame),
`tools/check_moth_burn.gd` (headless burn proof). Game now BOOTS TO HUB
(prologue unwired, files kept). Still parked/rejected untracked:
`RearrangeTest.*`, `tools/R3ActMocks.*`, `_r3_mocks_preview/`.

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
