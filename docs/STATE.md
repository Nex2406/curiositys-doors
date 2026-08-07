# Current State (auto-narrative — update at end of every session)
_Last updated: 2026-08-07_

## 2026-08-07 (pt. 3) — THE DOORWAY OUT OF REALM 2 IS FINISHED AND WIRED
The Realm 2 → Realm 3 gateway (`Realm3Gateway.gd`) now stands on the island at
the end of the trial, opens onto a real capture of Realm 3, and is walked
through. It is Realm 1's doorway recipe one realm on, and the same three laws
did all the work.
- **THE JAMBS ARE TWO FUNGAL HILLS EACH, NOT A STACK.** Advika: *"replace these
  leaves on the side with [`fungalhill1` and `fungalhill4`] — just shift them
  vertically and attach them."* The vine bundles that were there flipped to
  climb read as tall dark FERNS. Two passes stacked the hills SMALL — nine a
  side at a fixed step, then fourteen with step/width/squeeze/value all
  re-rolled — and both came back a LADDER. They had to: each hill is a
  horizontal arch, so any vertical run of them is rungs and jitter only makes
  the rungs untidy. Two hills a side, blown up to doorpost height and squeezed
  narrow, cannot form a rhythm.
- **THE SEAM GOES DEEP AND THE UPPER PIECE GOES NARROW.** These hills are solid
  for roughly their bottom half (`JAMB_SOLID`). Seated halfway up, the upper
  one's flat base landed in fringe tips and showed as a slab with a ruled edge;
  sized by height alone it came out WIDER than the hill it sits in and poked out
  at the ends. Both fixes generalise — it is the same bug as the crown's bar.
- **`JAMB_TOP`** — the posts stop *inside* the crown row's solid body. Running
  to -371 they finished above it as a separate bush each side, which is the
  *"hedge on the top"* Advika circled.
- **NOT ONE PIECE OF REALM 2 IS LEFT IN IT.** The hem's eight `hang_curl` /
  `hang_beard` / `hang_fern` / `vine_dark` strands are gone (*"remove ... these
  purple leaves"*): they are painted violet, and multiplying violet by teal only
  makes duller violet. Realm 3 fronds at the same anchors and lengths.
- **THE WAY THROUGH.** `Phase.DONE` → `_grow_r3_gateway()`; `Door.gd` maps
  `realm_3`. Three real bugs were in that path: the door `Area2D` sat at z=0
  under a z=14 gateway so the prompt drew *behind* the doorway (z=24 now); the
  trigger box was 230 wide on a 350-wide passage, so a third of the threshold
  was dead ground (it is the passage's own span now); and the `[Y]` check had
  tabs where a line-continuation belonged.
- **THE PROMPT IS NOT A PROXIMITY PROMPT.** Advika: *"it must be there no matter
  where the player is standing."* One doorway, end of the realm — it comes up on
  `Realm3Gateway.assembled` and stays. "Press Y to enter", EB Garamond, no
  outline, in Realm 1's warm gold, which is already `GLOW_WARM`, so the line and
  the glowers in the doorway's base are the same gold. `Door.gd` gained
  `prompt_font` / `prompt_color` / `prompt_outline_size` / `prompt_font_size`,
  all defaulting to the old look, so the hub is untouched.
- **CURIOSITY DRAWS IN FRONT NOW.** `Curiosity.tscn` carries no `z_index` at
  all, so she rendered at 0 — behind the island's moss rows (11/12) and the
  whole gateway. The gateway's own comment claimed it sat "behind the hero"; it
  never did.
- **THE HANDOVER IS A CARD, NOT A CUT** — a `QuoteTransition` carrying
  Curiosity's own four lines, no book credit, into `Realm3FungalTest`.
- **Gates:** `--headless --import` green, Web export green (exit 0), R3 boots
  clean. Verified by screenshot at every step, including the quote card.
- **OPEN:** the black bar across the crown's lintel. One attempt at it grew into
  a crown restructure and was reverted whole on Advika's word (*"i only wanted
  one hedge from the top removed"*). It is the crown row's flat bases lining up;
  the jamb fixes above are the shape of the answer. Realm 3 has no ambient bed,
  so the arrival is silent.

## 2026-08-07 (pt. 2) — REALM 3'S LOOK, REDONE
Advika, both levels open side by side: *"level2 is so maximalist flowy cohesive
looks perfectly built and then level 3 is so subpar"*, plus two rules —
**only the R3 pack** (the R2 moss stays, for the floor only) and **R3 and R2 are
different realms**. So this took Realm 2's CRAFT, not its look: the cavern is
still teal, still roofed, still made of mushrooms.
- **THE VALUE LAW (`_depth`)** is the whole fix. Realm 2 coheres because depth
  is the only thing value means in it. Realm 3 had that exactly backwards — its
  giant background caps wore saturated mint hues and additive auras, so the most
  distant objects were the BRIGHTEST on screen; its ceiling teeth were painted
  near-white and hung down as fangs; its boulders were pale grey; and the near
  layer was flat black. `_depth(t)` is now the only tint source in the
  environment (`SIL_FAR` / `SIL_MID` / `CAP_HUES` deleted), with two named
  off-ramp values — `PLAY_STONE` / `PLAY_GROWTH` — because the layer she is
  standing on has to read and on a pure ramp "here" means black.
- **A THIRD BAND, and it is the loudest.** `_hills_near` at cam*0.32 carries the
  big masses a few metres behind her, with the haze glimpsed between them. R3's
  nearest background used to be 600px away and the same brightness as the sky.
- **EVERY SHAPE CROSSES THE FRAME NOW (`_column`).** R3's background was
  horizontal ellipses stacked on horizontal ellipses — every shape agreed with
  the frame's own direction, which is what makes a background read as wallpaper.
  `fungalfrond` 5-15 are single curving tendrils and at 6-12x they are leaning
  trunks; `fungalhill` 2/5 are radial bursts and one on top is the crown. Built
  from R3's pack, so it reads as giant fungus, not as Realm 2's trees.
- **`_ember`** — this realm's own amber-capped glowers standing at every depth,
  with breathing additive halos. Realm 2 stitches its bands with gold points
  seen near and far; R3 cut its fireflies (07-15) and never replaced what they
  were doing, so its bands had nothing in common but hue. Not insects.
- **SHE WALKS THROUGH THE MOSS NOW, AND THE BUG WAS DEAD CODE.** `_walk_fringe()`
  — the builder whose entire job was drawing growth across her shins, carrying
  three paragraphs of notes about getting exactly that right — **was never called
  from `_ready()`**. That is why she read as standing ON the moss no matter what
  got tuned. Deleted; its job belongs to `_build_foreground`'s front row.
- **The bottom third of the frame was a black rectangle** — floor at y 420, view
  bottom at 770, nothing in between but soil. `BANK_ROWS` is three courses of
  fungal mass measured against her body (her knee is near y 372), the nearest
  crossing her shins and the deepest running off the bottom edge. One builder,
  both problems: the growth she wades in IS the frame's lower mass.
- **The floating black boxes are gone.** `_hang_chunk` / `_rim_platform` were
  `_fill_rect` polygons with pebble strips on four straight edges — they read as
  untextured black slabs, and once rimmed properly, as picture frames (a straight
  run of stone along a straight edge still describes a rectangle). They are piles
  of `fungalstoneb` boulders now (`_rock_course`), no rectangle anywhere.
- **The ceiling was lit backwards** — its deep curtain was the darkest row and
  its nearest hanging row the brightest, so the roof advanced at you and glowed
  along the top of every frame.
- **Gates:** `--headless --import` green, Web export green, `R3_BOOT` and
  `R3_BOSS` both assemble. Verified by screenshot at nine x positions plus a
  roof view, not by argument.
- **OPEN:** density is even end to end — Realm 2 has groves and clearings and
  this still reads the same on every screen. And the drained/boss palette has
  not been re-judged against the new ramp.

### later the same day — the notes that came from playing it
- **THE FLOOR IS A FIELD, NOT ROWS.** The foreground was four bank rows; every
  clump in a row topped out inside the same 45px window, so each row read as a
  ruled stripe and the dead air between one row's bodies and the next row's tops
  was a visible gap. Advika circled three at once. There are no rows now: every
  clump draws its own depth from a continuous range and its top, base, z and
  value all slide with that one number, plus a guaranteed continuous sweep at
  her shins so there is no x where she can read as standing ON the moss.
- **`band_ground.png` IS OUT.** Two tall fuzzy columns she told me to delete
  were not placed by anything — they are PAINTED INTO Realm 2's deep-mass strip.
  Found with `R3_ID=1`, a forensic pass that flat-colours every sprite by art
  family (magenta = Realm 2). The deep mass is R3's own mounds now.
- **THE ROCK MASSES ARE ALL GONE** — two hanging chunks, three floating ledges.
  They broke her own July law (platforms are mushrooms; rock is decor, nothing
  stands on it) and cost three rebuilds. The high path is giant mushrooms.
- **MUSHROOM HUES**, one family: a narrow teal-to-moss arc plus the lit species'
  amber. The first pass gave every species its own colour and she was right that
  a rainbow is the opposite of cohesion. `_hue()` normalises to luminance 1
  before multiplying, so colour never touches the depth ramp.
- **THE LIGHT BUDGET WAS SPENT IN THE FIRST QUARTER.** 24 lights, granted in
  call order, and the zone builders run before the long walk — so everything
  past x 6800 had no lights at all. It is spatial now (~31, x -430..24949).
- **ODDITIES** (`_build_oddities`): arch / fallen giant / cradle / curtain /
  cairn, one every ~3400px, never near a climbing arc. Each is a visible load
  path. `_lean_stalk` plants a leaning sprite by its FOOT — Godot rotates about
  the centre, which is why three earlier attempts left rocks apparently floating.
- **THE BOSS IS HER FRAMES.** `evil_curiosity/` art is out of the fight: it was
  drawn separately, so its jump WAS a different jump and no metadata matching
  could fix that. It plays `curiosity_frames.tres` with a recolour shader.
  Red eyes are FOUND in her art (bright + desaturated); the lantern is crushed
  dark by an 8-tap neighbour test, because its flame keeps a white-hot core as
  neutral as her eyes. No outline — tried, rejected on sight.
- **It walked, not ran.** Her walk_speed is 200 and run_speed 210, and `run` is
  her DASH clip — the boss picked animations off a 168 threshold so it sprinted
  the entire fight. And it now gives ground after every swing (`disengage_time`).
- **CEILING DROPPERS** (`Sporeling.drop_from`): during the boss fight only, they
  grip the roof, fade in, shiver, then fall. Same species, new entrance. Max 3
  alive, ~6s in, every 5-8s. `R3_DROP=0` off.
- **The lantern health HUD is in Realm 3**, and starts full — Curiosity emits
  `health_changed` from her own `_ready`, which `add_child` runs before the
  connection exists, so the one emit that said "full" was always missed.
- **OPEN:** the boss still MIRRORS rather than OBSERVES. Advika's correction —
  it should fight at the player's level and target their blind spots, not copy
  their numbers. `PlayerProfile` already measures the right things; only DECIDE
  uses them that way. Next up: quote cards + audio.


## 2026-08-07 — THE BOSS FIGHTS BACK: it has been reading you all level (UNCOMMITTED)
Realm 3's phase 3. The mirror used to fade in and stand there; it now fights,
and what it fights like is a description of the player. Working tree, import
green, Web export green, nothing committed.
- **`scripts/Mirror.gd`** — it is HER. `evil_curiosity` frames, and its scale,
  collider and movement constants are read off the live hero at spawn
  (`build_from`), so retuning Curiosity retunes the boss and the two can never
  drift apart. No lantern: she stays the only warm thing on screen. A cold rim
  light cuts the charcoal silhouette out of the drained forest, and the red
  eyes FLARE through every windup — the tell is the only red in the level.
- **Three stages, one per third of its health.** **MIMIC**: it fights with the
  player's own numbers — their engagement distance, their swing cadence, their
  jump appetite, their closing speed (a player who never jumps fights something
  that never jumps). **TIME**: it reads her swing as it happens (off her
  animation — her state enum is private), gives ground through it and comes
  back into the recovery. **DECIDE**: the numbers turned around — it steps into
  the side they always break toward, closes when they habitually back off, and
  swings inside their own cadence.
- **THE TAPE IS DELETED.** The first build replayed recorded snippets of the
  player's movement at them. Advika: "it doesnt replay ur recorded movement, it
  basically analyses how u play and attacks u on basis of that." The clip ring
  buffer is gone from `PlayerProfile` entirely; what replaced it is more
  measurement (`air_fraction`, `attacks_per_minute`) and the live swing-read.
- **Found by soak, not by theory:** a boss that honoured a cautious player's
  190px spacing never once came at them — it stood at exactly arm's length for
  two thirds of its health. Their RHYTHM is now the drumbeat (when it comes in)
  and their spacing only says where it waits between beats.
- **The clock stops when the forest drains.** Otherwise a player who spent ten
  honest minutes finding six mushrooms is killed by the timer during the fight
  they earned. It freezes on screen mid-fall rather than disappearing.
- **Killing it gives the forest back** — `realm_drain.gdshader` is run
  BACKWARDS over its body, the front crossing home the other way, each fog
  bank restored to the alpha it was seeded with.
- **Numbers:** 320 hp (8 of her swings), its blow costs her 25 (4 = one eye),
  reach 118px measured against her own. It gloats on a landed hit — the
  `celebrate` frames, unused since import.
- **Rigs:** `scenes/realms/realm3/MirrorTest.tscn` is the fight alone — three
  mushrooms for it to read you by, then the real handoff in miniature. `B`
  skip, `1/2/3` force a stage, `F` wears a FAKED player (rusher / camper /
  spammer) so all three bosses can be seen back to back, `K`/`L` chip it, `TAB`
  the read. `MIRROR_SOAK=<s>` runs the whole fight headless against a player
  who really swings; `R3_BOSS=<x>` boots the handoff inside the real level;
  `R3_BOOT=<s>` now takes a hold time.
- **THE READ SPANS THE WHOLE GAME** (Advika, end of session): not the forest.
  `PlayerProfile` now ATTACHES ITSELF to whatever is in the `player` group in
  any scene, so the cave and the sky-fight are read too and no realm has to be
  wired up. The reset that used to run on entering Realm 3 is gone — it threw
  away two realms of evidence; the only wipe left is `MainMenu` BEGIN, because
  a new run is a new person.
- **She is BIGGER in Realm 3 only** — `HERO_SCALE` 0.33 against the 0.24 every
  other realm uses. Nothing about the platforming moves with it (speed, gravity
  and the 138px jump are world units and do not know her draw scale); her
  collider does, and so do the sporelings, which are pinned to two-thirds of
  her by her own law. The mirror reads its size off her, so they stay identical.
- **OPEN:** the TIME stage's dodge-then-punish is the one thing headless cannot
  judge. And the fight has no ending beat yet beyond the colour returning.

## 2026-08-03 — REALM 3 HAS A CONCEPT: SHE IS THE ENEMY (UNCOMMITTED)
Design + the day's rejections in [`docs/SKETCHBOOK.md`](SKETCHBOOK.md)
(2026-08-03). Everything below is in the working tree, import green, nothing
committed and no Web export run yet.
- **`scripts/Echo.gd`** replaces yesterday's `Follower.gd` (deleted). It is a
  1200-frame ring buffer of her own position/facing/state, replayed `delay`
  seconds late — no AI, no chase. Before there is that much history it waits at
  the oldest sample, so it comes out of the spot she came in at. It cannot take
  her until she has been >500px away once (else it "catches" her on frame one).
- **THE CLOCK AND THE SHADOW ARE ONE.** `LEVEL_SECONDS` 900 (15:00, Advika).
  The same 0→1 drives `Echo.pressure`: delay 12s at the start, **0.4s when the
  clock dies**. Running out of time IS being caught — there is no second fail
  rule to explain. The readout is centre-top, realm teal, and bleeds to the
  sporelings' red with a pulse under 60s. `R3_CLOCK_SECS` shortens it for tests.
- **The echo gate** (`_build_echo_gate`, clear band x 6220–6900): a boulder
  wall — STONE, because her own law says mushrooms are what you stand on and
  rock is what you never can — plus a cold-glowing plate at 6220 and a cap at
  6620 that sinks only while something stands on the plate. `_pressing()` does
  not care whether that is her or the echo. **However long she stood there is
  how long the door stays open.** Geometry is measured, not guessed: she jumps
  138px (356²/2·460), so the cap is 128px up when down and 300px when up.
- **`scripts/Sporeling.gd`** — one species, evenly spaced 760px from x 1250,
  phase stepped in fifths so a stretch ripples. Underground and un-hittable
  until she is within 540px, then it BREAKS GROUND (squash-overshoot tween +
  soil puff) and every hop after that is aimed at whoever is nearest — her or
  the echo, it does not tell them apart. Beady red eyes: a hard bead in a small
  bloom. Group `enemies` + `take_damage` + layer 4, so her existing swing kills
  them. `R3_SPORE=0` off.
- **The meadow's ruled line, fixed** — Advika, playing live: "i can see the
  outline and a clear line where they end." Every clump in `_floor_mat` bottomed
  out inside a 28px band (`FLOOR_Y+6..34`), so thousands of sprite feet landed
  on one horizontal cut. Depth now spans `FLOOR_Y+2..118` plus its own ±jitter.
- **Deleted on her word:** a villain mocked out of `mushroomcap9` (brim = hood,
  lit stem = face). She wants the background mushroom left alone. What survives
  is the read: red eyes in shadow under a brim.
- **Harnesses:** `R3_START_X` boots her straight at whatever is being tested
  (the gate is 6km down the walk), `R3_FOLLOW=0`, `R3_DELAY`, `R3_SPORE=0`,
  `R3_CLOCK_SECS`, plus the existing `R3_SHOT` / `R3_SHOT_X` / `R3_SHOT_CAMY`.
- **NEXT:** the boss — her at full size, no delay, it stops copying and starts
  deciding. Advika draws it in LAYERS, not frames.

## 2026-08-02 (pt. 2) — SOMETHING WALKS BEHIND HER (Realm 3, UNCOMMITTED)
Realm 3 got its first idea that Advika actually likes. She wants the level
**time-bound**; out of eight pitches she took **spore tide** + **someone's
following you**, and loved the shadow on sight. Design + the day's rejections
are in [`docs/SKETCHBOOK.md`](SKETCHBOOK.md) (2026-08-02) — read that first.
- **`scripts/Follower.gd`** (`class_name Follower`) — one rule: IT NEVER RUNS.
  Constant 150px/s walk (she walks 200, so moving gains ground slowly);
  `close_speed` 205 while she stands still, which is the whole feeling — it
  eats the ground you stop giving it. `max_gap` 1400 means it never falls
  further behind than one screen, so it is ALWAYS there — and that catch-up
  only ever happens off camera, so she never witnesses it break its own rule.
  Contact emits `caught` → `_die` (loses an eye, resets it to the edge).
- **Look:** Curiosity's own `curiosity_frames.tres` walk at `speed_scale` 0.72,
  scaled 0.29 against her 0.24 (shaped like her, wrong size). Tint lerps from
  the realm's fog haze at distance to near-black up close, alpha 0.55→1.0, and
  a **cold** PointLight2D (`COLD`, no gold in it) rises 0.30→0.95 as it closes:
  warm lantern is her, cold is not. Placeholder, but the two pale eyes coming
  through the darkened frame read well enough that it may be the answer.
- **Two bugs found by screenshot, not by theory:** the frames are body-centred,
  so at `floor_y` it stood buried to the chest (`body_lift` 52); and a hazed
  dark tint at alpha 0.22 over dark grass was flatly invisible.
- Wired into `Realm3FungalTest.gd` (`_build_follower`, reset in `_die`).
  `R3_FOLLOW=0` A/Bs against the quiet forest, `R3_FOLLOW_GAP` sets the leash.
- **OPEN, answering next session:** she says pure evasion is boring and wants
  the shadow to be a mechanic. Six options pitched, unanswered — my pick was
  **use it as a key** (it walks through terrain, so you let it break a blocked
  path for you) + **hide under glowing caps**.
- **Final boss = new art Advika draws**, in LAYERS not frames (~8 painted
  pieces, code-animated) so it costs one illustration session, not the
  wizard's 96-frame months. What it IS, undecided.
- **The law that now governs R3's ending:** the player has NOT read the book.
  No book vocabulary on screen, ever. The 07-16 "Heart of the Hollow" layer did
  not survive contact — she didn't recognise the name from her own spec.
- Nothing committed. Working tree carries `scripts/Follower.gd` + the R3 edits.

## 2026-08-02 — THE DOORWAY WRITES ITSELF DOWN, AND THE CAVE STOPS BEING SAFE
The Realm 1 → Realm 2 doorway was rebuilt beat by beat against Advika's eye, and the
cave's two oldest cheats were found and closed.
- **The birth is no longer an eruption.** Nothing inflates and nothing climbs out of
  the floor: the doorway WRITES ITSELF DOWNWARD (`_assemble_door`). Every piece appears
  exactly where it belongs, ordered by final Y — crown first, then shoots, posts,
  curtain, and last the rock — each dropping ~45px into place so the sweep has weight.
  An earlier pass had the fragments materialise scattered in the cave air and fly home;
  it was built, shot, and rejected ("instead of the canopy fragments in air let it
  appear from top to bottom in the level").
- **The quake IS the door landing.** Four staged shakes on their own clock never
  matched a continuous sweep. Now every piece kicks the camera as it seats, weighted by
  its own size and how far down the sweep it landed (`_quake_kick` / `_quake_step`, an
  accumulator in `_process` — NOT tweens, which would each stomp the last one's offset
  instead of adding). The floor only breaks when the base actually arrives.
- **The far side is an APERTURE, not an image.** Three attempts failed before the cause
  was measured rather than guessed: `PORTAL_PROBE=1` proved the alpha ramp really did
  run, cleanly, over 3.2s. Alpha was simply the wrong instrument — a rectangle at 20%
  opacity is still a rectangle. The MASK opens instead (`_open_portal`): clipped to a
  small soft chink at the centre of the passage, widening to fill it, with the feather
  blooming from 0.85 down to its real value (it is a FRACTION of radius, so at 12% size
  the normal value was a few pixels and the chink came out as a hard little box). It
  starts only after the doorway has finished landing, and the rim is fbm-warped
  (`edge_noise`) so it never resolves into a perfect rectangle.
- **`portal_window.gdshader`** now carries `boxiness` (0 = the painted arch's ellipse,
  1 = the grown doorway's full opening), `edge_noise` + `noise_scale` for the ragged
  rim, and `uv_pan` so the forest drifts inside a mask that stays put.
- **The gateway capture was re-baked WIDE** (480x688, was 280x680). Filling the whole
  interior meant the old tall crop was being magnified ~1.9x and went to mush.
- **The canopy sways** — pivot-wrapped per piece ("t" for anything that hangs, "b" for
  anything that stands), no two sharing a period, started only once the door locks so
  the sway never fights the assembly's own rotation tween.
- **THE GROUND WAS A REAL BUG, not a look problem.** The near-black backing slab sat at
  `z 0` while the five rows of deep rock sat at `-1..-5`, so the slab painted over
  every one of them — those rows had been built and never once drawn. Fixed the order,
  started the rows above the cobble line (a bare strip showed between), and gave them
  their own ramp (`_deep_mat`): the old one faded to 0.16 over a material already
  capped at 0.175, i.e. ~0.028 — real rock, mathematically black.
- **REALM 1'S DIFFICULTY CHEATS, both closed** (`BoulderGolem.gd`). A ground golem's
  wake test required `_player_on_my_ground()`, so a player who stayed on the platforms
  **never woke a single one in the entire level**. And his life clock only ran while
  hunting, so the encounter was solvable by standing on a ledge and counting to seven.
  Now: he wakes on proximity; he charges whenever she is in range and over his lane;
  the clock runs from the moment he wakes and expiring only sends him home once she has
  LEFT his range. Ceiling golems widened 200→320px and now LEAD her.
- **The wizard falls in 6 strikes** (was 10; the "five" in the 07-27 entry was stale).
- **Found, not fixed:** Realm 1 has a whole painted parallax stack — three fused strips,
  shafts, mist sheets, motes, drips — built every run and switched off since the
  07-22 correction ("re-enabled in step 4" never happened). `R1_BANDS=1` turns it on and
  it is a different cave. Left OFF by Advika's call: it swings the palette olive, and
  that is baked into the strip ART, not the tints (re-tinting warm was tried and did
  almost nothing) — matching today's warm gold means re-cutting the strips.
- Harnesses added: `PLAT_SIT=door` now has on-screen instructions + SPACE to replay
  (and no longer heaps rubble every loop), `GROUND_TINT=1` colours each floor layer,
  `PORTAL_PROBE=1` prints the far side's alpha, `R1_BANDS=1` / `R1_FOG=1`.

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
