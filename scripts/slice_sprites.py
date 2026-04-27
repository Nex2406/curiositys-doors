"""Auto-slice the hand-drawn locomotion sheet into per-frame PNGs.

The source sheet is NOT a uniform grid: 6 rows of frames, each labeled in the
left margin, frames hand-placed with transparent gaps. The PNG has no alpha
channel — the background is near-white, sprites are dark painterly figures.

Pipeline:
  1. Treat any pixel with max(R,G,B) < CONTENT_DARKNESS_THRESHOLD as "content".
  2. Auto-detect the left margin: scan columns for the tallest contiguous
     content run; the first column whose run exceeds MIN_SPRITE_HEIGHT marks
     the start of the sprite region (text characters can't span 50+ px tall).
  3. Detect row bands by scanning for horizontal gaps in the cropped region.
  4. Within each row, detect frame columns by scanning for vertical gaps.
  5. Per-animation canvas: width = the row's widest bbox; height = the global
     tallest bbox across every row. Each frame is bottom-center anchored so
     feet line up both within an animation and across animations.
  6. Convert to RGBA via a luminance-based alpha matte (white -> transparent).
"""

from __future__ import annotations

import os
import sys
from PIL import Image
import numpy as np


SRC = "assets/characters/hero/sprites_locomotion.png"
OUT_DIR = "assets/characters/hero/frames"

ROW_NAMES = ["idle", "walk", "run", "jump_start", "air", "land"]
EXPECTED_FRAMES = [4, 6, 6, 2, 2, 2]

CONTENT_DARKNESS_THRESHOLD = 200
MIN_SPRITE_HEIGHT = 50
ROW_GAP_TOL = 8
FRAME_GAP_TOL = 12

ALPHA_OPAQUE_BELOW = 220
ALPHA_TRANSPARENT_ABOVE = 245


def runs_of_true(mask: np.ndarray) -> list[tuple[int, int]]:
    runs: list[tuple[int, int]] = []
    in_run = False
    start = 0
    for i, v in enumerate(mask):
        if v and not in_run:
            in_run = True
            start = i
        elif not v and in_run:
            in_run = False
            runs.append((start, i - 1))
    if in_run:
        runs.append((start, len(mask) - 1))
    return runs


def merge_close(runs: list[tuple[int, int]], gap_tol: int) -> list[tuple[int, int]]:
    if not runs:
        return runs
    merged = [runs[0]]
    for s, e in runs[1:]:
        ps, pe = merged[-1]
        if s - pe <= gap_tol:
            merged[-1] = (ps, e)
        else:
            merged.append((s, e))
    return merged


def col_max_runs(content: np.ndarray) -> np.ndarray:
    H, W = content.shape
    out = np.zeros(W, dtype=np.int32)
    for x in range(W):
        col = content[:, x]
        if not col.any():
            continue
        run = 0
        best = 0
        for v in col:
            if v:
                run += 1
                if run > best:
                    best = run
            else:
                run = 0
        out[x] = best
    return out


def matte_alpha(rgb: np.ndarray) -> np.ndarray:
    """RGB -> RGBA. Bright pixels go transparent; dark pixels stay opaque."""
    rgb = rgb.astype(np.uint8)
    h, w, _ = rgb.shape
    lum = rgb.max(axis=2).astype(np.int32)
    alpha = np.full((h, w), 255, dtype=np.int32)
    fully_clear = lum >= ALPHA_TRANSPARENT_ABOVE
    alpha[fully_clear] = 0
    ramp = (lum > ALPHA_OPAQUE_BELOW) & ~fully_clear
    alpha[ramp] = (
        255
        * (ALPHA_TRANSPARENT_ABOVE - lum[ramp])
        // (ALPHA_TRANSPARENT_ABOVE - ALPHA_OPAQUE_BELOW)
    )
    return np.dstack([rgb, alpha.astype(np.uint8)])


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    im = Image.open(SRC).convert("RGB")
    arr = np.array(im)
    H, W, _ = arr.shape
    print(f"loaded {SRC}: {W}x{H}")

    content = arr.max(axis=2) < CONTENT_DARKNESS_THRESHOLD

    runs = col_max_runs(content)
    sprite_cols = runs >= MIN_SPRITE_HEIGHT
    if not sprite_cols.any():
        sys.exit("no columns exceed MIN_SPRITE_HEIGHT; tune threshold")
    left_crop = int(np.argmax(sprite_cols))
    print(f"left_crop = {left_crop} (col-run at boundary = {runs[left_crop]})")

    body = content[:, left_crop:]
    color = arr[:, left_crop:, :]

    row_has = body.any(axis=1)
    bands = runs_of_true(row_has)
    bands = merge_close(bands, ROW_GAP_TOL)
    print(f"detected {len(bands)} row bands: {bands}")
    if len(bands) != len(ROW_NAMES):
        sys.exit(f"expected {len(ROW_NAMES)} rows, got {len(bands)}")

    # First pass: gather every frame's tight bbox so we can compute the global
    # max height (used as the canvas height for every animation, so feet align
    # across animations — not just within a single row).
    per_row: list[tuple[str, int, list[tuple[int, int, int, int]]]] = []
    for row_idx, (y0, y1) in enumerate(bands):
        name = ROW_NAMES[row_idx]
        expected = EXPECTED_FRAMES[row_idx]
        row_band = body[y0 : y1 + 1, :]
        col_has = row_band.any(axis=0)
        frame_runs = runs_of_true(col_has)
        frame_runs = merge_close(frame_runs, FRAME_GAP_TOL)
        if len(frame_runs) != expected:
            print(f"  row '{name}' frame runs: {frame_runs}")
            sys.exit(f"row '{name}': expected {expected} frames, got {len(frame_runs)}")

        bboxes = []
        for x0, x1 in frame_runs:
            sub = body[y0 : y1 + 1, x0 : x1 + 1]
            ys = np.where(sub.any(axis=1))[0]
            xs = np.where(sub.any(axis=0))[0]
            ya, yb = y0 + int(ys[0]), y0 + int(ys[-1])
            xa, xb = x0 + int(xs[0]), x0 + int(xs[-1])
            bboxes.append((xa, ya, xb, yb))
        per_row.append((name, expected, bboxes))

    global_max_h = max(yb - ya + 1 for _, _, bbs in per_row for _, ya, _, yb in bbs)
    print(f"global max frame height = {global_max_h}")

    total_written = 0
    for name, _, bboxes in per_row:
        max_w = max(xb - xa + 1 for xa, _, xb, _ in bboxes)
        canvas_h = global_max_h
        print(f"  row '{name}': {len(bboxes)} frames, canvas {max_w}x{canvas_h}")
        for i, (xa, ya, xb, yb) in enumerate(bboxes, start=1):
            w = xb - xa + 1
            h = yb - ya + 1
            crop = color[ya : yb + 1, xa : xb + 1, :]
            rgba = matte_alpha(crop)
            canvas = np.zeros((canvas_h, max_w, 4), dtype=np.uint8)
            ox = (max_w - w) // 2
            oy = canvas_h - h
            canvas[oy : oy + h, ox : ox + w, :] = rgba
            out_path = f"{OUT_DIR}/{name}_{i:02d}.png"
            Image.fromarray(canvas, "RGBA").save(out_path)
            total_written += 1

    print(f"wrote {total_written} frames to {OUT_DIR}")


if __name__ == "__main__":
    main()
