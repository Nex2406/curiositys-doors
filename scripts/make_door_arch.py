"""Generate the Hub door-arch placeholder texture.

Output: assets/scenes/hub/door_arch.png — 120x180 RGBA. Stone archway
silhouette: lighter rim (#4a3a5a) framing a darker interior body
(#2a1f3a), top corners gently rounded (radius 45) and bottom corners
square so it reads as a doorway rather than a tombstone. Same texture
is used by all three placeholder doors until per-realm art lands.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw


WIDTH, HEIGHT = 120, 180
INTERIOR = (0x2A, 0x1F, 0x3A, 0xFF)
OUTLINE = (0x4A, 0x3A, 0x5A, 0xFF)
TRANSPARENT = (0, 0, 0, 0)
ARCH_RADIUS = 45  # gentle arch on the top corners
RIM = 6
OUT = "assets/scenes/hub/door_arch.png"


def main() -> None:
    img = Image.new("RGBA", (WIDTH, HEIGHT), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    # Outer silhouette: rounded top corners, square bottom corners.
    # PIL's rounded_rectangle rounds all four corners, so we overpaint
    # the bottom band to square the bottom two.
    draw.rounded_rectangle(
        (0, 0, WIDTH - 1, HEIGHT - 1), radius=ARCH_RADIUS, fill=OUTLINE,
    )
    draw.rectangle((0, HEIGHT - ARCH_RADIUS, WIDTH - 1, HEIGHT - 1), fill=OUTLINE)

    # Interior body — inset by RIM on all sides so the lighter rim frames it.
    inner_radius = max(ARCH_RADIUS - RIM, 1)
    draw.rounded_rectangle(
        (RIM, RIM, WIDTH - 1 - RIM, HEIGHT - 1 - RIM),
        radius=inner_radius,
        fill=INTERIOR,
    )
    draw.rectangle(
        (RIM, HEIGHT - ARCH_RADIUS, WIDTH - 1 - RIM, HEIGHT - 1 - RIM),
        fill=INTERIOR,
    )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
