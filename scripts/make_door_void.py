"""Generate the door-portal interior — a slow swirling void texture.

Output: assets/scenes/hub/door_void.png — 80x140 RGBA.

Sits inside each Hub door's arch interior. Animated by an
AnimationPlayer rotation in the scene. Looks best when the rotation
is slow enough that the player only registers motion peripherally.

Construction: low-frequency blurred noise tinted toward `#0a0612` with
faint `#3a2a5a` wisps. A radial alpha falloff fades the corners so the
texture sits comfortably inside the rounded arch interior without
showing a visible square edge against the door rim.

Fallback: if procedural noise looks cheap, the consumer scene can
simply hide the Sprite2D — the underlying door interior reads as a
solid dark color and the loss is graceful.
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter


WIDTH, HEIGHT = 80, 140
OUT = "assets/scenes/hub/door_void.png"

BASE = np.array([0x0A, 0x06, 0x12], dtype=np.float32)
WISP = np.array([0x3A, 0x2A, 0x5A], dtype=np.float32)

# Two octaves are plenty at this resolution; more would stack into mush.
OCTAVES = [
    (8, 12.0, 1.0),
    (4, 6.0, 0.4),
]

SEED = 0xD007


def _octave(rng: np.random.Generator, downsample: int, sigma: float) -> np.ndarray:
    small_w = max(WIDTH // downsample, 4)
    small_h = max(HEIGHT // downsample, 4)
    raw = rng.random((small_h, small_w), dtype=np.float32)
    img = Image.fromarray((raw * 255).astype(np.uint8), mode="L")
    img = img.resize((WIDTH, HEIGHT), Image.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=sigma))
    return np.asarray(img, dtype=np.float32) / 255.0


def main() -> None:
    rng = np.random.default_rng(SEED)
    field = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
    weight_sum = 0.0
    for downsample, sigma, weight in OCTAVES:
        field += _octave(rng, downsample, sigma) * weight
        weight_sum += weight
    field /= weight_sum
    field -= field.min()
    if field.max() > 0:
        field /= field.max()

    # Lift the wisps softly — most of the texture should remain near
    # base, with rare brighter ribbons.
    field = field ** 1.6
    t = field[..., None]
    rgb = BASE * (1.0 - t * 0.85) + WISP * (t * 0.85)

    # Radial alpha falloff so the corners blend out gently. Bias the
    # ellipse toward vertical (matches the door aspect ratio) and keep
    # a generous interior at full opacity.
    yy, xx = np.mgrid[0:HEIGHT, 0:WIDTH].astype(np.float32)
    cx = (WIDTH - 1) / 2.0
    cy = (HEIGHT - 1) / 2.0
    nx = (xx - cx) / cx
    ny = (yy - cy) / cy
    r = np.sqrt(nx * nx + ny * ny)
    # Full alpha to ~0.7 of the radius, then fade to 0 by 1.05.
    alpha = np.clip(1.0 - (r - 0.7) / 0.35, 0.0, 1.0) * 255.0

    rgba = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT)
    print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
