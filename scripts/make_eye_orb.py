"""Generate the cream-white eye-orb glow.

Output: assets/effects/eye_orb.png — 16x16 RGBA. Soft radial falloff:
center is pure cream-white #FFF8E0 at full alpha, mid is warmer
#FFE8C0 at moderate alpha, edge fades to fully transparent. Quadratic
falloff so the glow reads soft rather than ringed.
"""

from __future__ import annotations

import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "effects", "eye_orb.png")

W = 16
H = 16
CENTER_RGB = (255, 248, 224)   # #FFF8E0  cream-white
MID_RGB = (255, 232, 192)      # #FFE8C0  warm white


def lerp_rgb(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(a[0] * (1.0 - t) + b[0] * t),
        int(a[1] * (1.0 - t) + b[1] * t),
        int(a[2] * (1.0 - t) + b[2] * t),
    )


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx = (W - 1) / 2.0
    cy = (H - 1) / 2.0
    radius = (W / 2.0) - 0.5
    for y in range(H):
        for x in range(W):
            dx = x - cx
            dy = y - cy
            t = min(1.0, math.sqrt(dx * dx + dy * dy) / radius)
            # Color: solid cream for the inner core, lerp toward warm
            # white as we approach the edge.
            color_t: float = 0.0 if t <= 0.35 else (t - 0.35) / 0.65
            rgb = lerp_rgb(CENTER_RGB, MID_RGB, color_t)
            # Alpha: quadratic falloff. Inner 35% stays at full alpha,
            # then drops to 0 at the edge.
            if t <= 0.35:
                a_norm = 1.0
            else:
                a_norm = (1.0 - (t - 0.35) / 0.65) ** 2
            img.putpixel((x, y), (rgb[0], rgb[1], rgb[2], int(a_norm * 255)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT} ({W}x{H} RGBA)")


if __name__ == "__main__":
    main()
