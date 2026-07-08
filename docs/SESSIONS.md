# Session log

Short ledger of build sessions: what shipped, what didn't work, what's next. Append
one new entry per session; do not edit older entries except to correct factual errors.

Format: `date | what shipped | what didn't work | next 3 safe candidates`

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
