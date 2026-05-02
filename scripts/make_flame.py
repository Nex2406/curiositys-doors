"""Generate a soft radial flame texture for Curiosity's lantern interior.

The painted lanterns in the hand-labeled frames have a transparent hole
where the flame should be. This texture sits behind the AnimatedSprite2D
in the scene so the dark navy background doesn't bleed through that hole.

Output: assets/effects/lantern_flame.png — 64x64 RGBA, warm core (yellow-
white) -> warm orange mid -> fully transparent edge, with a smoothstep
falloff so the gradient reads as a glow rather than a hard disc.
"""

from __future__ import annotations

import os
from PIL import Image
import numpy as np


SIZE = 64
OUT = "assets/effects/lantern_flame.png"

CORE = np.array([255, 230, 180], dtype=np.float32)
MID = np.array([255, 175, 100], dtype=np.float32)
EDGE = np.array([200, 110, 50], dtype=np.float32)


def smoothstep(a: np.ndarray) -> np.ndarray:
    a = np.clip(a, 0.0, 1.0)
    return a * a * (3.0 - 2.0 * a)


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx = cy = (SIZE - 1) / 2.0
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / cx

    rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    inner = smoothstep(r / 0.35)
    rgb_inner = CORE * (1.0 - inner)[..., None] + MID * inner[..., None]
    outer = smoothstep((r - 0.35) / 0.65)
    rgb_outer = MID * (1.0 - outer)[..., None] + EDGE * outer[..., None]
    use_outer = (r >= 0.35)[..., None]
    rgb = np.where(use_outer, rgb_outer, rgb_inner)

    alpha = (1.0 - smoothstep(r)) * 255.0

    rgba = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(OUT)
    print(f"wrote {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
