"""Generate the firefly mote texture used by the Hub's GPUParticles2D.

A 32x32 soft radial gradient — small enough to render cheap at 40+
instances, big enough that the center pixel still reads as a glow when
scaled up. Center is a pale lilac (#d8b4f8), midband purple (#9b6dd6),
edge deep violet (#4a2a7a) fading to transparent. The alpha curve is
the punchy bit: a power falloff so the outer ring vanishes smoothly
without a visible disc edge.

Output: assets/effects/firefly.png — 32x32 RGBA.
"""

from __future__ import annotations

import os
from PIL import Image
import numpy as np


SIZE = 32
OUT = "assets/effects/firefly.png"

CORE = np.array([0xD8, 0xB4, 0xF8], dtype=np.float32)
MID = np.array([0x9B, 0x6D, 0xD6], dtype=np.float32)
EDGE = np.array([0x4A, 0x2A, 0x7A], dtype=np.float32)

ALPHA_CURVE = 2.2
MID_RADIUS = 0.4


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    center = (SIZE - 1) / 2.0
    r = np.sqrt((xx - center) ** 2 + (yy - center) ** 2) / center
    r = np.clip(r, 0.0, 1.0)

    inner_mask = (r < MID_RADIUS)[..., None]
    inner_t = (r / MID_RADIUS)[..., None]
    rgb_inner = CORE * (1.0 - inner_t) + MID * inner_t
    outer_t = ((r - MID_RADIUS) / (1.0 - MID_RADIUS)).clip(0.0, 1.0)[..., None]
    rgb_outer = MID * (1.0 - outer_t) + EDGE * outer_t
    rgb = np.where(inner_mask, rgb_inner, rgb_outer)

    alpha = ((1.0 - r) ** ALPHA_CURVE) * 255.0

    rgba = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(OUT)
    print(f"wrote {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
