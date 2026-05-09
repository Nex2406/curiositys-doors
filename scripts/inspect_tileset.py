"""One-shot inspection helper. Reads mainlev_build.png, prints which 32x32
cells contain art, and saves a debug grid so we can choose tile coords for
the level layout.
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "realms", "realm1_caves", "mainlev_build.png")
OUT_JSON = os.path.join(ROOT, "scripts", "_realm1_filled_cells.json")
OUT_PNG = os.path.join(ROOT, "scripts", "_realm1_grid_debug.png")
TILE = 32
ALPHA_THRESHOLD = 32
FILL_THRESHOLD = 0.05  # at least 5% non-transparent pixels


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    cols, rows = w // TILE, h // TILE

    filled: list[dict] = []
    for ty in range(rows):
        for tx in range(cols):
            box = (tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE)
            cell = img.crop(box)
            ne = sum(1 for p in cell.getdata() if p[3] > ALPHA_THRESHOLD)
            if ne > TILE * TILE * FILL_THRESHOLD:
                filled.append({"x": tx, "y": ty, "alpha_count": ne})

    with open(OUT_JSON, "w") as f:
        json.dump({"cols": cols, "rows": rows, "filled": filled}, f, indent=2)

    # Debug overlay: outline every filled cell so a human can eyeball ranges.
    debug = img.copy()
    draw = ImageDraw.Draw(debug)
    for cell in filled:
        x, y = cell["x"] * TILE, cell["y"] * TILE
        draw.rectangle([x, y, x + TILE - 1, y + TILE - 1], outline=(255, 0, 0, 255))
        draw.text((x + 1, y + 1), f"{cell['x']},{cell['y']}", fill=(255, 255, 0, 255))
    debug.save(OUT_PNG)

    print(f"Sheet {cols}x{rows} cells, {len(filled)} filled")
    # Print compact grid: 1 char per cell, '#' filled, '.' empty
    grid = [["." for _ in range(cols)] for _ in range(rows)]
    for c in filled:
        grid[c["y"]][c["x"]] = "#"
    for row in grid:
        print("".join(row))


if __name__ == "__main__":
    main()
