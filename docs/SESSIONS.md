# Session log

Short ledger of build sessions: what shipped, what didn't work, what's next. Append
one new entry per session; do not edit older entries except to correct factual errors.

Format: `date | what shipped | what didn't work | next 3 safe candidates`

---

## 2026-07-16/17 — The finale finds its shape: The Bloom, the book, the layered underworld

**Shipped (main, pre no-commit rule):** R3 ref set-pieces (PR #170 — hanging
rimmed chunks + slab bridges, kept RARE); The Bloom finale spec
(docs/realms/realm3.md): villain = Consciousness, the sleeper = the Heart
of the Binding Hollow, ritual wake by accident, defiant-tease ending —
all canon-grounded after reading Written by Silence end to end (digest in
assistant memory); finale concept frame mocked from real assets
(assets/_reference/bloom_finale_mock_2026-07-16.png).

**Built, approved, UNCOMMITTED (Advika's new rule: no main commits without
her word):** the LAYERED UNDERWORLD (scenes/UnderforestTest.tscn) — the
realm 3 builder rerun verbatim per layer with a fresh seed; floor gaps are
bottomless throats that drop Curiosity into the next layer, forever.
Five look iterations died before the lesson landed: "exactly like level 3"
means rerun level 3's builder, not invent new grammar.

**Didn't land:** the self-writing/crumbling map rig (mechanic parked, look
rejected), chamber-stack underworld, four static act mocks (motion-first
won).

**Next 3:** 1) commit conversation (review branch of approved pieces);
2) surface floor opens into underworld layer 1; 3) bounce prototype →
M2 combat wiring → the Heart layer.

## 2026-07-15 — Realm 3 becomes a place: the long fungal forest, iterated live

**Shipped** (branch `feat/r3-fungal-shell` → main, closes #166 — one long
live session, ~10 feedback rounds with Advika driving)
- The level grew from a 5k test strip to a ~27k px five-minute walk
  (world -1050..26000). Everything is rhythm-generated from a seeded rng —
  ground, roof, background, dressing, platform arcs — so "make it longer"
  is now a constants change.
- Platform language settled after several rejections: mushrooms ONLY.
  Half-buried giant dome caps as low steps, full stemmed mushrooms higher,
  lone hop domes between arcs, one-way cap colliders. Rocks demoted to
  clean decor (no growth on stone, never walkable).
- Floor became a true meadow (`_floor_mat`): one gradient field, per-clump
  depth/tint/height, two overlapped height waves — she wades IN it, and no
  strip or band survives anywhere (three separate "strip" complaints died
  here: pebble rims, seam belt, flat walk-mat layers).
- Background: composed mid-band vignettes (cap families, spire groves,
  glow gardens) with LOUD hued giant caps + glow auras; far band got a
  giant-cap skyline. Overcrowded on request, then eased ~25% + camera
  zoomed out to 1.0.
- Palette-hued glows (amber/cyan/moss — purple stays Curiosity's),
  fireflies removed, LivesHUD eyes tinted realm-teal via `eye_tint`.
- Jump-view bugs fixed twice: roof now fades into near-black via a
  vertex-color gradient polygon, no bands/boulder-lumps above the fringe.
- Exit arch door at the far end (`[Y] Return` → Hub) using Realm 1's exact
  recipe; Hub Door 3 already targeted realm_3 — the three-door loop is
  closed for the first time.
- Gates green locally: `--headless --import` exit 0, Web export exit 0.

**Didn't work / lessons**
- Fringe rows at constant scale/tint ALWAYS read as strips at this zoom —
  any repeated element needs scale + height + VALUE jitter, or a gradient.
- Boulder-mound platforms with growth on the crown = "moss on rocks", dead
  on arrival. Advika's law: decor and walkable are different vocabularies.
- Value-step between stacked flat layers reads as a painted line even when
  heights vary — the fix is per-sprite continuous depth, not more layers.

**Next 3 safe candidates**
1. Play the deployed Pages build in a browser end-to-end (perf check — this
   scene draws far more sprites than anything else; watch web FPS).
2. R3 puzzle + enemies per `docs/REALMS.md` (environment shell is done).
3. Realm-local exit lore line for R3's arch door (`exit_lore_line` is
   already plumbed, just needs Advika's words).

## 2026-07-14 — Realm 3 rebuilt to Advika's reference images (the pack's grammar)

**Shipped** (branch `feat/r3-fungal-shell`, closes #166)
- Advika supplied THREE reference images made from the exact fungal pack
  (saved: `assets/_reference/realm3_target_{wide,platforms,cavern}_2026-07-14.png`)
  and the shell was rebuilt to their construction grammar: near-black navy
  FILL BODIES rimmed with the pack's pebble frames/strips, dense frond
  fringe on every surface (up from floors/platform tops, hanging from
  ceilings/undersides), grouped prop assemblies (pots + boulders + gold
  spore stalks / white glowers on the platform stack / flat-cap family on
  a stone shelf), luminous-mist background with pale spire + mushroom-ghost
  silhouettes, darkest fore silhouettes, corner vignette.
- Three zones matching the three refs: A cavern mouth (ref 3) → B pot-strewn
  floor under a hanging pebble-rimmed chunk (ref 1) → C overgrown platform
  stack beneath a fully fringed ceiling (ref 2). Enclosed cavern: pebbled
  end walls, jump-feasible platform ladder (≤115px steps).
- Contact-sheet study of all 162 pack slices (9 families) — fungalground
  turned out to be pebble FRAMES/strips, fungalfrond holds the pots; that
  discovery drove the whole rebuild.

**What didn't work / dead ends**
- Pebble tilers that check only the tile CENTER against the span end throw
  strays half a tile past edges (the floating strip right of the chunk);
  whole-tile-must-fit is the rule now.
- PowerShell `Get-Content`/`Set-Content` round-trip mojibake'd the script's
  UTF-8 — repaired via cp1252 re-decode; use the Edit tool for source files.

**Next 3 safe candidates**
1. Realm 3 door wiring: Door 3 → Realm3FungalTest (Door 2's pattern).
2. Void moth enemy (frames already in Downloads) — but R2-M3 Enemy base
   first, per the milestone order.
3. Realm 3 puzzle spec chat with Advika (docs/REALMS.md realm 3 section).

## 2026-07-12 (pt. 2) — The wizard's trial: he conjures, she hunts, the island stops

**Shipped** (PR: `feat/r2-runeorb-hazard`, closes #155 — one long live
playtest loop with Advika steering every dial)
- **Rune-orb hazard chain**: OrbConjure ground-ring → orb_ready → RuneOrb.
  Invulnerable (own layer 16, not "enemies", no damage path — structural),
  rolling with real inertia, shoves via `Curiosity.shove()` (new: velocity
  like hurt()'s knockback, no flinch/damage/invuln), rides moving planks
  like the hero, rolls off edges, overstays 8-14s then commits + leaves.
  Palette-shifted onto the realm violet (`tools/tint_runeorb_pack.gd`).
- **The wizard is THE conjurer** (Advika's law): orbs are born in front of
  him, max 2, wherever he teleport-lands. Landings scatter (240px+ hops),
  avoid Curiosity (380px+), escape-reflex with per-landing grace. FIVE
  strikes fell him (tuned 1→5→3→5 live); each hit = panic-teleport.
- **The boss gate CLOSED**: died → stop_levitation() → arrived → DONE.
  First full Realm 2 loop: walk → tear → endless climb → trial → the storm
  relents. Difficulty cranked per "make it HARD" (storm sway 40px, orbs
  240px/s + 540 shove, jump +15% for fairness).
- **Forest dressed to the max**: grounded tree assemblies (trunk + canopy +
  no-twin hangers + rocks + breathing plants), boulder piles, undergrowth
  carpet every ~150px, edge to edge -1500..3800.
- Wizard entrance timing settled at 7s airborne (#154, #156 earlier today).

**What didn't work / dead ends**
- Orbs rolling off the island LANDED on the intro ground far below and
  squatted in the hazards group forever → the max-2 cap wedged ("he only
  spawns 2 then stops"). Kill plane now rides 900px under the island and
  is checked floor-or-no-floor. R2_TRIAL_LOG (45s soak) is the regression
  guard.
- Uniform-random teleports read as "not random" (kept landing on her);
  snap velocity reversals read weightless. Both fixed with constraints
  (avoid-her re-roll) and inertia, not more randomness.
- Twin hang-ferns on one canopy (circled by Advika) — hangers now draw
  without replacement; same law applied to the ascent corridor.

**Next 3 safe candidates**
1. The intro beat: wizard dialogue (DialogueCard vs existing DialogueBox —
   Advika's call) + instructions window gating start_trial().
2. R2-M3 slimes — or fold them into the trial as the wizard's second
   conjuration; the ladder should be revisited now the trial exists.
3. Realm 1 leftovers (standing): jade motivation, real hub art, sound,
   shorter prologue, custom text-box anim.

---

## 2026-07-12 — The wizard shows himself

**Shipped** (PR: `feat/r2-wizard-actor`, closes #151)
- **The wizard's look is settled**: BlueWizard pack (Maaot, Downloads)
  palette-shifted in-house — cloak navy→realm violet (measured 219°→248°
  against `vine_trunk_0`, same measured-not-guessed method as the Mossy
  slicer), eye glow yellow→**red** (Advika: the player reads evil at a
  glance). Repeatable tool: `tools/tint_wizard_pack.gd`. 96 frames in
  `assets/enemies/wizard/` (idle/walk/jump + 3 blink variants).
- **The apparition beat** (Advika's design): ~2.5s after the island is
  truly airborne (RISING, not the pre-tear shake) the wizard flickers into
  existence standing ON the island's far end — planted in the moss, riding
  the climb, red eyes on Curiosity. Flicker-in reuses the Golem-flicker /
  respawn-blink visual language.
- **Wizard actor**: `scenes/Wizard.tscn` + `scripts/Wizard.gd` — presence
  only (materialize / follow / watch); BossBase, storm bolts, teleports
  land with R2-M7 proper.
- **Anim review window**: `tools/WizardAnimReview.tscn` — keys 1-6 flip
  through every set live; how Advika reviewed the purple + red-eye pass.

**What didn't work / dead ends**
- First hover post floated him beside the island — Advika: he spawns ON
  the platform. Second post clipped his robe into the right hedge's dark
  mass (silhouette law); final post is the open moss stretch at +255.

**Next 3 safe candidates**
1. R2-M3 — Enemy base + the first slime (waves teach the combat verbs the
   boss later tests; wizard conjuring them is the candidate spawn fiction).
2. Advika picks the teleport-blink variant (A smear / B / C readable blur)
   in the review window — unblocks the boss's reposition move.
3. Realm 1 leftovers (standing reminder): jade motivation, real hub art,
   sound, shorter prologue, custom text-box anim.

---

## 2026-07-08 — The middle door opens, the climb never ends

**Shipped** (PRs #140, #142, #144, #146, #147, #149, #150 — all deploy green)
- **Door 2 wired**: Hub middle door → Realm 2 liftoff, ESC returns to the
  Hub, respawn under Door2. The live link plays Realm 2 end to end.
- **Ascent corridor dressed from the FULL Mossy pack** (Advika: "use the
  pack to its fullest") — new `tools/slice_mossy_pack.gd` slices any sheet
  into elements and hue-shifts green→violet by MEASURING the delta from
  shipped assets. 22 new elements committed; thorn arcs + sprouts staged
  for R2-M5/M6.
- **The corridor lives**: grouped overhang assemblies (slab + hangers +
  rock + plant + vine as ONE bobbing node), storm-responsive hanger sway,
  animated pack plants, whole vine trunks grown through slabs.
- **Endless boss-gated rise** (Advika's design): the island climbs until
  the wizard falls — `LevitatingIsland.endless` + `stop_levitation()` for
  the R2-M7 defeat beat. Corridor recycles seamlessly (wrap-above-view).
  Both arbitrary timers (8s auto-return, 24s rise stop) are dead.
- **Artifact extermination** (five annotated screenshots): bark gaps (vine
  tiling removed), sky slivers (assemblies interlock 70px+), inverted
  leaves (flip_v banned), black corner blobs (z13 foreground pass cut).
  Law recorded in memory: nothing floats, everything is rooted.
- **Wizard = R2-M7 boss** (BlueWizard pack — dark mirror of Curiosity;
  caster, storm = his weapon); ladder renumbered (door M8, polish M9).
- **Enemy audition rig** (`tests/EnemyAttackPreview.tscn`): drop any pack
  folder into `assets/enemies/preview/` → attack cycle beside Curiosity at
  in-game treatment. First verdict: FlyingForestEnemies REJECTED (pixel
  art clash); slimes stay the R2-M3 creature.
- LivesHUD eyes brightened.

**Didn't work / lessons**
- First dressing pass decorated for the ride camera only — orphaned leaves,
  gaps, and blob artifacts from every other viewpoint. Cost four fix
  rounds and real frustration; the grouped-assembly law now prevents the
  class, and screenshots must cover every camera the player actually has.
- FlyingForestEnemies free pack: wrong style family, rejected in minutes
  by the audition rig (that speed is the rig's whole point).

**Next 3 safe candidates**
1. **R2-M3 — reusable `Enemy` base + first slime** (confirm with Advika:
   wizard conjures slimes from the storm?)
2. **R2-M4 — wave director** against the open-ended ascent
3. **R2-M5 — storm hazards** (thorn arcs are already sliced + violet)

**Shipped**
- **R2-M1 merged to main (PR #138 / issue #137, deploy green)** — the quake +
  liftoff is playable end to end in `Realm2LiftTest.tscn`: flat mossy intro →
  step onto the buried island → storm builds → the tear → 24s seamless ascent
  with Curiosity riding → arrival above the canopy. Reusable
  `LevitatingIsland` (shake/debris/ascent/hover, drives the camera,
  sync_to_physics riders).
- **Island camouflage + wake** (Advika's call, the session's best idea): the
  embedded island wears the ground's dark violet — proportionally darker tint
  (its art is ~3x brighter), gold glow banked to a still ember, plants frozen
  — then everything wakes to full color over the 7s of the tear. Kills the
  "pasted-on chunk" read completely.
- **The Great Line Hunt**: Advika kept circling straight lines in the ground;
  five suspects were dissolved/fixed in turn, and the real killer (island
  fringe overlay's region-crop edge, drawn over EVERYTHING) was caught with a
  new `R2_TINT` forensics mode that flat-colors every ground layer. Ground is
  now one seamless moss body: staggered big-finger rows down to silhouette
  black, organic crest + tuft mounds skyline, seam belt interlocking the
  upper masses, shader-dissolved crop edges, per-tile height wobble.
- **Fall death beat**: fall off anywhere (mid-ascent or at the top) → the fall
  plays out past the frame bottom → an eye closes → Curiosity blinks back in
  on the island (mercy invuln); 3 lifelines then scene restart. Proven via
  `R2_SHOT_FALL` harness.
- **Canopy**: right half of the level was bald (strand loop stopped short of
  the parallax-shifted frame edge — fixed), ground tufts now hang among the
  leaves, and the canopy fade completes before any cut-off strand top can
  enter the frame during ascent.
- **Docs truth pass**: Realm 2 phase ladder written (`docs/realms/realm2.md`,
  R2-M0..M8) — and discovered **R2-M2 (combat) was already shipped** by the
  golem sessions while STATE.md still claimed combat was unwired. STATE
  synced.

**What didn't work / dead ends**
- Four line-fix attempts (hedge dissolve, plug-top lowering, mat/hedge
  re-layering) barely moved the pixels — the lesson: stop theorizing about
  layers, tint them all and LOOK (`R2_TINT` now permanent kit).
- Screenshot-harness fall test needed its window widened past the ride guard
  before it could prove anything.

**Next 3 safe candidates**
1. **R2-M3 — Enemy base + the first slime** (forces: how do slimes reach a
   flying island — fly, climb, drop from the storm?)
2. **Wire Realm 2 into the game** — which hub door, how it unlocks (jade key
   opens Door 2 — is this behind it?). The lift scene ships unreachable today.
3. **R2-M4 — wave director** (forces: continuous rise vs rise-between-waves).

---

## 2026-07-04 — Realm 2's stage is standing (and it breathes)

**Shipped**
- **Realm 2 concept locked in chat**: storm-lifted chunk ascent — flat mossy
  ground intro → storm tears the middle chunk loose → ride it up fighting
  waves (slimes), brewing a potion orb, dodging lightning → sky door.
  Palette: violet, low-lit, kin to Curiosity. All in SKETCHBOOK.
- **Background target locked by iteration**: 7 mock versions with Advika
  (open luminous cut rejected as HK-ripoff → the INTIMATE cut won: dense
  dark canopy, one warm gold pocket, side moon).
  `assets/_reference/realm2_bg_target_2026-07-04.png` + compose recipe in
  `scripts/compose_realm2_bg_mock.py` + `scripts/purple_shift.py` (Maaot
  pack green→violet).
- **`Realm2BgTest.tscn`** — the target wired live, everything MOVING:
  3 parallax spire bands, randomized swinging canopy (pendulum + shear
  sway, fresh roll per launch), mid-depth strands behind the chunk,
  bobbing chunk w/ Maaot's animated wind plants, breathing gold pocket,
  amber fireflies, spore drift, crawling fog, twinkling stars, storm
  wisps, finger-moss floor hedge, clean soft moon. Self-screenshot via
  `R2_SHOT` env var for A/B against the target.
- **`CREDITS.md`** — per-piece attributions (Szadi art / Maaot / Advika /
  AI-assisted programming), college-portfolio ready, update rule in place.
- College portfolio gap analysis + action plan PDFs → Advika's Downloads.

**What didn't work / dead ends**
- Static painted lightning + god-rays in the mock (read as squiggle +
  triangle) — cut; lightning will be an animated in-engine flash.
- Stepped-ellipse moon halo (rings) and un-windowed halo (square edge) —
  both replaced by smooth per-pixel falloff.
- First open/luminous background direction — beautiful but read as Hollow
  Knight; the intimate cut is ours.

**Next 3 safe candidates**
1. **R2-M1: quake + liftoff** — flat-ground intro on the mossy tileset,
   storm arrives (shake, wind ramps), chunk tears free and rises.
2. **R2-M2: wave combat on the chunk** — slime enemies (Maaot frames)
   board during ascent; reuse Golem's enemy brain.
3. **Realm 1 leftovers** (Advika's parked list): jade motivation beat,
   real hub, sound, shorter prologue, custom text-box animation.

## 2026-05-17 — Close the agentic loop

**Shipped**
- `docs/SESSION_PROMPT.md` — the durable single-paste session opener.
  Names the protocol, the queue, the template choice, the acceptance
  bar, and the 3-line end-of-session report. From now on, one paste
  starts every session.
- `CLAUDE.md` carries a one-line banner directly under the title
  pointing at `SESSION_PROMPT.md`. The brain points at itself.
- **Self-referential docs**: `## See also` footer added to each of
  `CLAUDE.md`, `docs/STATE.md`, `docs/SESSIONS.md`, `docs/VISION.md`,
  `docs/MECHANICS.md`, `docs/REALMS.md`, `docs/ART_DIRECTION.md`,
  `docs/STORY.md`, `docs/VIBE.md`. Each footer lists the other 8 with
  one-line roles. Open any doc → see the whole map.
- `.github/PULL_REQUEST_TEMPLATE.md` + every issue template
  (feat / bug / art / story / research / realm) now require two new
  checkboxes in Acceptance: `docs/STATE.md updated this session` and
  `docs/SESSIONS.md entry appended this session`. The discipline is in
  the templates, not in someone's head.
- `bug.md` gained an Acceptance section it never had — root-cause +
  import/export green + live verification + the two new STATE/SESSIONS
  checkboxes.
- `docs/STATE.md` Next 3 re-ranked: item 1 is now
  **"Realm 2 — design + build (use realm.md)"**.
- For SESSIONS.md specifically: a note explains that new entries are
  inserted *above* the See also footer so the footer stays permanent.

**What didn't work / dead ends**
- None this session — pure docs / scaffolding work, no code paths
  exercised. The Phase 2 lore-moment PR was the live-build test for
  the new loop and it landed green.

**Next 3 safe candidates**
1. Realm 2 — design + build (use realm.md). Interview Advika for all
   5 template fields (theme word, palette refs, puzzle premise, lore
   beat on exit, what player carries forward), then build. Do not
   invent answers.
2. Realm 1 jade-piece pickups — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
3. Hand-painted lantern falloff — replace the `GradientTexture2D`
   placeholder with a painterly radial falloff. Pure art swap, no
   gameplay change.

---

## 2026-05-17 — Realm 1 lore moment + LoreMoment scene

**Shipped**
- New reusable `LoreMoment` overlay (`scenes/UI/LoreMoment.tscn` +
  `scripts/LoreMoment.gd`) — single-line lore display: slow fade-in /
  hold / fade-out, soft serif via `SystemFont` fallback chain (Georgia →
  Times New Roman → DejaVu Serif → Liberation Serif → serif), centered,
  no box, no portrait, no ticking crawl. Self-frees after the fade-out.
  Awaitable from any caller: `await lore.play_line(text)`.
- `Door.gd` extended with an `exit_lore_line` `@export_multiline` field.
  When non-empty, `trigger()` spawns a LoreMoment under the current
  scene, awaits its full ~5s cycle, then continues into the existing
  `Transition.transition_to(path)` fade. Empty value = no behavior
  change, so existing doors stay exactly as they were.
- Realm 1's `ExitDoor/DoorArea` now sets:
  `exit_lore_line = "The dark grew careful where her lantern had been."`
  — lantern-anchored imagery from the book, "grew careful" implies the
  cave reacted without narrating that it did. Past tense gives
  after-presence.
- `docs/STATE.md` updated: LoreMoment moved to "What is wired,"
  dialogue-overlay removed from "unwired," Live loop reflects the lore
  step before the fade.
- Closes #66.

**What didn't work / dead ends**
- No bundled `.ttf` serif font available — relied on `SystemFont` with a
  Georgia → Times → DejaVu Serif → Liberation Serif → serif fallback
  chain. On the live web build this should resolve to a real serif on
  Windows / macOS / Android browsers; Linux without DejaVu falls back to
  Godot's default sans. Bundling a free-license painterly serif is the
  obvious polish follow-up but didn't make this PR.
- Couldn't run `godot --headless --import` locally (Godot not on PATH on
  the working machine). Relied on careful code review + post-merge CI as
  the Quality Gate.

**Next 3 safe candidates**
1. Realm 1 jade-piece pickups — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
2. Polish pass on platform rocks — peak-top platform tile so they read
   as floating ledges, not chunks of detached floor.
3. Hand-painted lantern falloff — replace the `GradientTexture2D`
   placeholder with a painterly radial falloff. Pure art swap, no
   gameplay change.

---

## 2026-05-17 — Tighten the agentic loop

**Shipped**
- `docs/STATE.md` introduced as the single living snapshot of what's wired
  vs. unwired right now. Updated at the end of every session. Becomes the
  primary boot-up read alongside `CLAUDE.md`.
- `CLAUDE.md` reality-synced: deleted the stale "Current Skeleton Status"
  block (was still claiming `ColorRect` placeholder + no parallax + no doors),
  replaced the "Session Start Protocol" with a leaner four-step version
  that reads `STATE.md` + the issue + ONE relevant design doc, instead of
  the full `docs/` tree.
- `docs/MECHANICS.md` reality-synced against current code: split into
  **Current Implemented Loop / Implemented / Known Stubs / Planned / Next
  Safe Feature Candidates**. Removed `ColorRect` / `GradientTexture2D` lies,
  documented the Door + Hub + Transition wiring as shipped, listed the
  un-wired Curiosity animations as explicit stubs. Closes #57.
- `.github/ISSUE_TEMPLATE/feat.md` + `art.md` now have a **Kill criteria**
  section right after Acceptance — forces the "what would make me pull
  this back?" question up front instead of post-merge.
- `.github/ISSUE_TEMPLATE/realm.md` added — new template for queuing
  realms. Fields: Theme word, Palette refs (3 colors min), Puzzle premise
  (one sentence), Lore beat on exit (one line), What player carries
  forward into the hub. Acceptance copied from `feat.md`, Kill criteria
  required.
- Bundled the `Chat protocol — how the brain evolves` section that was
  added to `CLAUDE.md` during the 2026-05-17 design session — same theme
  (cheap session boot), rolling it forward into `main`.

**What didn't work / dead ends**
- None this session — pure docs / meta work, no code paths exercised.

**Next 3 safe candidates**
1. Realm 1 lore moment (queued spec) — one short Curiosity-voice line on
   Realm 1 exit before the fade. Local to the realm, no global dialogue
   framework needed yet.
2. Realm 1 jade-piece pickups — scattered collectible nodes, counter
   tracked in a global singleton, hub-side "forge the key" moment on
   return. Foundation for the Realm 1 → Door 2 unlock loop.
3. Polish pass on platform rocks — `T_PLATFORM_L/M/R` currently reuse the
   solid sub-floor block. A peak-top platform tile (e.g. row-22 rocky-band
   coords) would read more as a floating ledge than a chunk of detached
   floor.

---

## 2026-05-11 — Realm 1 full geometry rebuild (classic platformer)

**Shipped**
- Complete rebuild of Realm 1 level geometry against the same `mainlev_build.png`.
  The collision + palette fix earlier in the day kept the level playable but the
  layout was still chaotic. This rebuild restructures it as a classic 2D platformer:
    - **One** ground-top tile `(4, 20)` across all 80 floor cells. No more 5-variant
      mixing within row 9.
    - **One** ground-interior tile `(7, 23)` filling rows 10-13 (SUBFLOOR_DEPTH=4)
      for 4 rows of visible floor thickness.
    - **One** 3-tile platform palette — `(24, 1) / (25, 1) / (28, 1)` wood-plank L /
      M / R with the X-brace metal joint in the middle. Used uniformly across 10
      floating platforms.
    - 4 floor gaps, 4 tiles each, evenly distributed (cols 16-19, 36-39, 56-59,
      76-79). Five floor sections of 16 cols between.
    - 10 platforms total: y=8 bridges over each gap + y=8 step-ups + one y=7
      chain-up challenge (out of direct floor reach, requires plat 3 as
      intermediate) + a y=8/7/6 ascending victory path before the exit door.
    - Ceiling row at y=0 and decor stalactites at y=1 removed entirely — the
      parallax cave painting provides the overhead naturally.
- Verified locally via headless capture tour (spawn + col 25 + col 45 + col 65 +
  col 87): `on_floor=true` at floor positions, layout reads as the intended
  ground/gap/platforms pattern, wood planks distinct from rocky floor.

**What didn't work / dead ends**
- Considered using brick `(26, 16)` for ground top (user-authorized fallback for
  "clean horizontal top"). Rejected: bricks are orange-red and 100% solid across
  large areas, breaks the cave tone. Stuck with peak-up rocky `(4, 20)` even
  though it's 50% density and leaves a small transparent strip between the rim
  and the sub-floor — the dark cave parallax behind makes the strip read as
  shadow rather than a seam.
- Tried using brown rocky chunks `(7,23)(8,23)(9,23)` for floating platforms.
  Rejected: same material as ground interior, platforms didn't read as distinct
  layer. Wood planks give the contrast.

## 2026-05-11 — Realm 1 fall-through + full tile rework

**Shipped**
- Real root cause of Realm 1 fall-through: in `_build_tileset()`, `ts.add_source(src, 0)`
  ran AFTER the per-tile `create_tile + _attach_full_collision` loop. The TileSet had a
  physics layer registered, but the source/tile data weren't members of the TileSet yet,
  so the layer didn't propagate to per-tile `TileData` — every `add_collision_polygon(0)`
  errored with `physics.size()=0` and silently skipped. Result: every solid tile rendered
  but had zero collision. Fix: move `ts.add_source` to immediately after the source is
  built, before the tile-creation loop. Confirmed via headless capture: 90 frames of
  `on_floor=true`, `feet_y=576.0` matching `floor_top=576.0` exactly.
- Full palette redo so Realm 1 reads as a single brown-cave theme instead of three clashing
  palettes (brown floor + dark-blue ceiling + orange-red bricks + lava-glow gems). Specifics:
    - Split `GROUND_VARIANTS` into `GROUND_TOP_VARIANTS` (peak-up rocky rim, row 20) and
      `GROUND_FILL_VARIANTS` (solid blocks, rows 23-24) — floor surface now has a readable
      rocky top edge instead of looking like a flat slab.
    - `T_WOOD_L/M/R` (wood planks) replaced with `T_PLATFORM_L/M/R` (brown rocky chunks
      from rows 23). Old wood planks at 15/50/40% density rendered as fragmented dark
      strips; rocky platforms read as solid floating ledges.
    - `T_CEIL_A/B` moved from `(13,14)/(15,14)` (dark-blue) → first attempt `(7,26)/(9,26)`
      (brown solid, but too flat) → final `(7,29)/(8,29)` (peak-down rocky tips). Overhead
      now reads as a stalactite-tipped cave roof.
    - Dropped `BRICK_*` consts and `WALLS` const entirely — bookend brick walls were
      orange-red against a brown cave. Walls were "optional" per the task brief; no brick
      row that visually fits the cave exists in the sheet.
    - Dropped `T_DECOR_GEM_*` and `DECOR_GEM_X` — the (20,24)/(20,25) tile is a red-glow
      fire pit, which reads as lava, not a cave gem. Wrong tonal register for Curiosity's
      cool cave.
- Local capture pre-merge confirmed the visual is cohesive: brown rocky terrain, peak-down
  stalactite ceiling, rocky platform chunks, all from one sheet band.

**What didn't work / dead ends**
- The original hypothesis (atlas coords gone stale → `_cell_is_filled` returns false →
  `set_cell` no-ops) was empirically false. Density audit confirmed every old coord was
  populated. Tiles WERE being created; the problem was collision attachment order. Only
  running the scene headlessly surfaced the `physics.size()=0` stderr that pointed to the
  real cause.
- First-pass fix (just move `ts.add_source` + swap ceiling to `(7,26)/(9,26)`) made the
  collision work but the visual was still a mess: orange bricks clashed, wood planks were
  unreadable thin strips, red gem fire pit looked like lava. User flagged "tile map is
  FUCKED" — needed full palette rework, not the const-only patch I shipped first.

**Next 3 safe candidates**
1. Realm 1 lore moment (queued spec) — one short lore line on exit before the fade.
2. Polish pass on platform rocks — `T_PLATFORM_L/M/R` currently reuse the solid sub-floor
   block. A peak-top platform tile (e.g. row-22 rocky-band coords) would read more as a
   floating ledge than a chunk of detached floor.
3. Audit the parallax cave painting against the brown-cave foreground — the deepest layer
   is still a cool blue-grey while the tiles are warm brown. Subtle but the tonal split
   shows when there's an exposed gap.

---

> **Note for future appenders:** new session entries are inserted **above** the See also
> footer (between the most recent entry and the footer), keeping the footer permanently at
> the bottom of the file.

## See also

- [`CLAUDE.md`](../CLAUDE.md) — repo-wide engineering guide; Quality Gate; Session Start Protocol
- [`docs/STATE.md`](STATE.md) — single living snapshot of what's wired right now; updated every session
- [`docs/VISION.md`](VISION.md) — north star: hero, hub, realms, the three bars (visual / technical / narrative)
- [`docs/MECHANICS.md`](MECHANICS.md) — engineering reference: implemented vs planned systems
- [`docs/REALMS.md`](REALMS.md) — per-realm spec: theme, palette, soundscape, puzzle mechanic, lore reveal
- [`docs/ART_DIRECTION.md`](ART_DIRECTION.md) — painterly bible: palette hexes, lighting model, scale rules
- [`docs/STORY.md`](STORY.md) — narrative scaffolding: plot beats, tonal constraints, voice rules
- [`docs/VIBE.md`](VIBE.md) — tone allow/deny lists; sanity check before naming or writing
