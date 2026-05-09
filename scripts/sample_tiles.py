"""Print thumbnails of specific tile coords side-by-side so I can pick
floor/wall/platform/ladder/brick atlases by eye."""

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "realms", "realm1_caves", "mainlev_build.png")
OUT = os.path.join(ROOT, "scripts", "_tile_samples.png")
TILE = 32
SCALE = 4
GAP = 8

# Sample sweep: a row from each major region
COORDS = [
    # cave wall body rows (3-7) — looking for full solid blocks
    (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3),
    (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6), (7, 6),
    (1, 7), (2, 7), (4, 7), (5, 7), (8, 7),
    # row 9-12 (deeper cave blocks)
    (4, 9), (5, 9), (6, 9), (7, 9), (8, 9), (9, 9),
    (6, 11), (7, 11), (8, 11), (9, 11), (10, 11), (11, 11), (12, 11), (13, 11),
    (6, 12), (7, 12), (8, 12), (9, 12), (10, 12),
    # row 14-15 (full blocks — likely floor pieces)
    (4, 14), (5, 14), (6, 14), (7, 14), (4, 15), (5, 15), (6, 15), (7, 15),
    # right column structural — bricks, ladders, walls
    (26, 8), (26, 9), (26, 10), (26, 11), (26, 12), (26, 13), (26, 14),
    (29, 0), (29, 1), (28, 0), (28, 1),  # wooden plank platforms
]


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    cell_w = TILE * SCALE
    per_row = 12
    rows = (len(COORDS) + per_row - 1) // per_row
    out_w = per_row * (cell_w + GAP) + GAP
    out_h = rows * (cell_w + GAP + 16) + GAP
    out = Image.new("RGBA", (out_w, out_h), (40, 40, 50, 255))
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(out)
    for i, (tx, ty) in enumerate(COORDS):
        cell = img.crop((tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE))
        cell = cell.resize((cell_w, cell_w), Image.NEAREST)
        col = i % per_row
        row = i // per_row
        x = GAP + col * (cell_w + GAP)
        y = GAP + row * (cell_w + GAP + 16)
        out.paste(cell, (x, y), cell)
        draw.text((x, y + cell_w), f"{tx},{ty}", fill=(220, 220, 220, 255))
    out.save(OUT)
    print(f"Wrote {OUT} ({len(COORDS)} samples)")


if __name__ == "__main__":
    main()
