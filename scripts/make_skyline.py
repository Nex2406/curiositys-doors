"""Generate the Hub's mid parallax layer — distant cosmic spires.

Painted as solid silhouette (#0f0820) on a transparent canvas. The
prompt is firm: not mountains, not natural — these are the *suggestion*
of distant towers/spires belonging to the Hub itself. Built as a row
of overlapping vertical rectangles with triangular caps and a sparse
sprinkle of single-pixel "windows" at varying brightnesses so a
careful eye picks them up but they never read as decoration.

Output: assets/scenes/hub/skyline.png — 1920x300 RGBA.
"""

from __future__ import annotations

import os
import random

from PIL import Image, ImageDraw


WIDTH, HEIGHT = 1920, 300
SILHOUETTE = (0x0F, 0x08, 0x20, 0xFF)
TRANSPARENT = (0, 0, 0, 0)
OUT = "assets/scenes/hub/skyline.png"

WINDOW_COLORS = [
    (0x4A, 0x3A, 0x6A, 0xC0),
    (0x6A, 0x4A, 0x90, 0xC0),
    (0x3A, 0x2A, 0x5A, 0xC0),
]

SEED = 0x70C2EE


def main() -> None:
    rng = random.Random(SEED)
    img = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    # Walk the skyline left to right placing towers of varying widths
    # and heights. Allow some overlap so the silhouette never reads as
    # discrete buildings — it should feel like a continuous distant
    # cityscape that fades in and out of legibility.
    x = -40
    while x < WIDTH + 40:
        tower_width = rng.randint(40, 140)
        tower_height = rng.randint(120, 270)
        top_y = HEIGHT - tower_height
        # Body
        draw.rectangle(
            (x, top_y, x + tower_width, HEIGHT),
            fill=SILHOUETTE,
        )
        # Cap variant — flat, small spire, or wider crown.
        cap_kind = rng.random()
        if cap_kind < 0.35:
            spire_w = max(tower_width // 4, 6)
            spire_h = rng.randint(24, 80)
            cx = x + tower_width // 2
            draw.polygon(
                [
                    (cx - spire_w, top_y),
                    (cx + spire_w, top_y),
                    (cx, top_y - spire_h),
                ],
                fill=SILHOUETTE,
            )
        elif cap_kind < 0.6:
            crown_h = rng.randint(8, 22)
            crown_inset = rng.randint(4, 14)
            draw.rectangle(
                (
                    x - crown_inset,
                    top_y - crown_h,
                    x + tower_width + crown_inset,
                    top_y,
                ),
                fill=SILHOUETTE,
            )
        # else: flat top, do nothing.

        # Windows — sparse, single pixels at varying values. Skip the
        # bottom 10% of the tower because that vanishes behind the fog
        # band anyway.
        usable_top = top_y + 10
        usable_bottom = HEIGHT - tower_height // 10 - 5
        if usable_bottom > usable_top + 5:
            window_count = rng.randint(0, max(2, tower_height // 30))
            for _ in range(window_count):
                wx = rng.randint(x + 4, x + tower_width - 4)
                wy = rng.randint(usable_top, usable_bottom)
                color = rng.choice(WINDOW_COLORS)
                # 1-pixel window most of the time, occasional 2-px tall.
                if rng.random() < 0.25:
                    draw.rectangle((wx, wy, wx, wy + 1), fill=color)
                else:
                    draw.point((wx, wy), fill=color)

        # Step forward by less than tower_width so adjacent towers
        # overlap slightly — this is what kills the "rhythm of obvious
        # rectangles" tell.
        x += rng.randint(max(tower_width - 30, 12), tower_width + 10)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
