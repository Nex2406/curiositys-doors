"""Audit the cave tileset and emit a labelled debug grid + density JSON.

Outputs (gitignored):
  - scripts/_debug_tile_grid.png  : 4x-zoomed sheet with red 32x32 grid,
                                    yellow (x,y) labels, green fill % on
                                    cells > 70% opaque
  - scripts/_tile_density.json    : { "x,y": fill_fraction } for all cells

Also prints the top-density cells to stdout so a human can pick floor /
platform / wall / ceiling tile coords without opening Godot.
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "realms", "realm1_caves", "mainlev_build.png")
OUT_GRID = os.path.join(ROOT, "scripts", "_debug_tile_grid.png")
OUT_JSON = os.path.join(ROOT, "scripts", "_tile_density.json")
TILE = 32
ZOOM = 4
ALPHA_BIT = 32  # PIL alpha channel: above this = "filled"


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    cols, rows = w // TILE, h // TILE

    densities: dict[str, float] = {}
    for ty in range(rows):
        for tx in range(cols):
            cell = img.crop((tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE))
            ne = sum(1 for p in cell.getdata() if p[3] > ALPHA_BIT)
            densities[f"{tx},{ty}"] = round(ne / float(TILE * TILE), 2)

    zoomed = img.resize((w * ZOOM, h * ZOOM), Image.NEAREST)
    draw = ImageDraw.Draw(zoomed)
    for ty in range(rows):
        for tx in range(cols):
            zx, zy = tx * TILE * ZOOM, ty * TILE * ZOOM
            d = densities[f"{tx},{ty}"]
            grid_color = (255, 60, 60, 90) if d < 0.05 else (255, 60, 60, 200)
            draw.rectangle(
                [zx, zy, zx + TILE * ZOOM - 1, zy + TILE * ZOOM - 1],
                outline=grid_color,
            )
            if d > 0.05:
                draw.text((zx + 2, zy + 2), f"{tx},{ty}", fill=(255, 255, 0, 255))
            if d > 0.7:
                draw.text(
                    (zx + 2, zy + TILE * ZOOM - 14),
                    f"{int(d * 100)}%",
                    fill=(60, 255, 60, 255),
                )
    zoomed.save(OUT_GRID)

    with open(OUT_JSON, "w") as f:
        json.dump(densities, f, indent=2)

    high = [(c, d) for c, d in densities.items() if d > 0.7]
    high.sort(key=lambda kv: -kv[1])
    print(f"Sheet {cols}x{rows}, {len(high)} cells with >70% fill (solid candidates):")
    for coord, d in high[:50]:
        print(f"  {coord:>8s}  {int(d * 100)}%")
    print()
    mid = [(c, d) for c, d in densities.items() if 0.4 < d <= 0.7]
    mid.sort(key=lambda kv: -kv[1])
    print(f"{len(mid)} mid-density cells (40-70%):")
    for coord, d in mid[:30]:
        print(f"  {coord:>8s}  {int(d * 100)}%")


if __name__ == "__main__":
    main()
