# Session log

Short ledger of build sessions: what shipped, what didn't work, what's next. Append
one new entry per session; do not edit older entries except to correct factual errors.

Format: `date | what shipped | what didn't work | next 3 safe candidates`

---

## 2026-05-11 — Realm 1 fall-through fix

**Shipped**
- Real root cause of Realm 1 fall-through: in `_build_tileset()`, `ts.add_source(src, 0)`
  ran AFTER the per-tile `create_tile + _attach_full_collision` loop. The TileSet had a
  physics layer registered, but the source/tile data weren't members of the TileSet yet,
  so the layer didn't propagate to per-tile `TileData` — every `add_collision_polygon(0)`
  errored with `physics.size()=0` and silently skipped. Result: every solid tile rendered
  but had zero collision, so Curiosity fell through every cell. Fix: move `ts.add_source`
  to immediately after the source is built, before the tile-creation loop. One-line move.
- `T_CEIL_A`/`T_CEIL_B` remapped from `(13,14)`/`(15,14)` (dark-blue cave palette) to
  `(7,26)`/`(9,26)` (brown cave palette) so the overhead ceiling reads as the same rocky
  theme as the floor. Both new coords are 100% solid in `mainlev_build.png`.

**What didn't work / dead ends**
- The stated hypothesis (tile atlas coords no longer point to solid cells, so
  `_cell_is_filled` returns false and `set_cell` no-ops) was empirically false. Density
  audit (`scripts/inspect_tileset.py` → `scripts/_tile_density.json`) confirmed every
  current `GROUND`/`BRICK`/`CEIL` coord is 100% solid; `WOOD_L/M/R` are 15/50/40% which
  still passes the 5% threshold in `_cell_is_filled`. So tiles WERE being created — they
  just weren't getting collision attached. Only running the scene headlessly surfaced the
  real cause (the `physics.size()=0` stderr).
- Tried locating a brown-cave stalactite decor tile to replace `(7,3)` (dark cave) so the
  full theme is consistent. Brown cave region's small peak-down pieces are all >25%-fill
  ceiling-edge tiles, not standalone single-tip stalactites. Kept `(7,3)` for now —
  `CanvasModulate(0.6,0.6,0.7)` at tile_y=1 dims the palette mismatch.

**Next 3 safe candidates**
1. Brown-cave decor stalactite swap — pick from `(7,29)` / `(8,29)` peak-down pieces and
   accept that decor at tile_y=1 will read as continued ceiling rather than free-hanging
   stalactite. Const-only change; same shape as this PR.
2. Realm 1 lore moment (queued spec) — one short lore line on Realm 1 exit before the
   fade. Realm-local, no global framework. Scoped to `Realm1.gd` + one new label node.
3. Floor-top "readable rim" — swap `GROUND_VARIANTS[0]` to a peak-up tile like `(7,20)`
   for just the visible top row, keeping `(7,23)`+ for sub-floor fill. Function-body
   change (split top vs. fill paths), but small and isolated to `_paint_solids`.
