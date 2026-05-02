"""Generate the outer halo texture for Curiosity's lantern.

The PointLight2D needs a soft, generous falloff so the warm light bleeds
into the surrounding navy scene without a visible hard edge. The default
internal GradientTexture2D fades linearly with radius, which reads sharp
at large texture_scale. This script bakes a power-curve falloff so the
center stays bright and the outer ring fades into nothing very gradually.

Output: assets/effects/lantern_halo.png — 256x256 RGBA, warm gold center
(255, 200, 120) -> warm orange (255, 130, 50) -> transparent edge.
"""

from __future__ import annotations

import os
from PIL import Image
import numpy as np


SIZE = 256
OUT = "assets/effects/lantern_halo.png"

CORE = np.array([255, 200, 120], dtype=np.float32)
MID = np.array([255, 130, 50], dtype=np.float32)
EDGE = np.array([180, 70, 20], dtype=np.float32)

ALPHA_CURVE = 2.4
COLOR_BLEND_CURVE = 1.6


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    center = (SIZE - 1) / 2.0
    r = np.sqrt((xx - center) ** 2 + (yy - center) ** 2) / center
    r = np.clip(r, 0.0, 1.0)

    t = r ** COLOR_BLEND_CURVE
    inner_mask = (r < 0.4)[..., None]
    inner_t = (r / 0.4)[..., None]
    rgb_inner = CORE * (1.0 - inner_t) + MID * inner_t
    outer_t = ((r - 0.4) / 0.6).clip(0.0, 1.0)[..., None]
    rgb_outer = MID * (1.0 - outer_t) + EDGE * outer_t
    rgb = np.where(inner_mask, rgb_inner, rgb_outer)

    alpha = ((1.0 - r) ** ALPHA_CURVE) * 255.0

    rgba = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(OUT)
    print(f"wrote {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
