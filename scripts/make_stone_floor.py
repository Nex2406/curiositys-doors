"""Generate the Hub stone floor tile.

Output: assets/scenes/hub/stone_floor.png — 256x64 RGB, mottled grey
palette (#1f1822 -> #2c2030) with subtly darker vertical cracks every
32px so the tile loops cleanly when wrapped horizontally.

Procedural placeholder — Wave 1 of the Hub rebuild. Replaced by hand-
painted floor art in a later wave.
"""

from __future__ import annotations

import os
import random

from PIL import Image


WIDTH, HEIGHT = 256, 64
CRACK_SPACING = 32  # divisor of WIDTH so the tile seams cleanly when tiled
DARK = (0x1F, 0x18, 0x22)
LIGHT = (0x2C, 0x20, 0x30)
CRACK = (0x10, 0x0C, 0x16)
OUT = "assets/scenes/hub/stone_floor.png"


def _lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main() -> None:
    random.seed(2406)
    img = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = img.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            t = random.random()
            color = _lerp(DARK, LIGHT, t)
            crack_dx = x % CRACK_SPACING
            if 0 < crack_dx <= 1 and random.random() < 0.7:
                color = _lerp(color, CRACK, 0.55)
            pixels[x, y] = color
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
