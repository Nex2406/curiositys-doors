"""Print high-zoom thumbnails of specific tile coords so we can verify
exact pixel placement — used to choose between visually similar candidate
coordinates."""

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "realms", "realm1_caves", "mainlev_build.png")
OUT = os.path.join(ROOT, "scripts", "_tile_samples.png")
TILE = 32
SCALE = 8
GAP = 12

# Wood platform candidates and the curated palette in use
COORDS = [
    # Sweep cols 22-31 across rows 0-2 looking for the plank platform pieces
    (22, 0), (23, 0), (24, 0), (25, 0), (26, 0), (27, 0), (28, 0), (29, 0), (30, 0), (31, 0),
    (22, 1), (23, 1), (24, 1), (25, 1), (26, 1), (27, 1), (28, 1), (29, 1), (30, 1), (31, 1),
    (22, 2), (23, 2), (24, 2), (25, 2), (26, 2), (27, 2), (28, 2), (29, 2), (30, 2), (31, 2),
]


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    cell_w = TILE * SCALE
    per_row = 6
    rows = (len(COORDS) + per_row - 1) // per_row
    out_w = per_row * (cell_w + GAP) + GAP
    out_h = rows * (cell_w + GAP + 22) + GAP
    out = Image.new("RGBA", (out_w, out_h), (40, 40, 50, 255))
    draw = ImageDraw.Draw(out)
    for i, (tx, ty) in enumerate(COORDS):
        cell = img.crop((tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE))
        cell = cell.resize((cell_w, cell_w), Image.NEAREST)
        col = i % per_row
        row = i // per_row
        x = GAP + col * (cell_w + GAP)
        y = GAP + row * (cell_w + GAP + 22)
        out.paste(cell, (x, y), cell)
        # Draw a horizontal red line at the cell's top edge to gauge where
        # full-cell collision would sit
        draw.rectangle([x, y, x + cell_w - 1, y + cell_w - 1], outline=(255, 60, 60, 200))
        draw.text((x + 4, y + cell_w + 2), f"{tx},{ty}", fill=(220, 220, 220, 255))
    out.save(OUT)
    print(f"Wrote {OUT} ({len(COORDS)} samples at {SCALE}x)")


if __name__ == "__main__":
    main()
