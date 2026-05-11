# Session log

Short ledger of build sessions: what shipped, what didn't work, what's next. Append
one new entry per session; do not edit older entries except to correct factual errors.

Format: `date | what shipped | what didn't work | next 3 safe candidates`

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
