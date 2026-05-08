"""Generate the Hub's far parallax layer — a cosmic nebula band.

We don't have an installed noise library, so we fake multi-octave noise
the way the user's prompt suggested: stacked random-noise images blurred
heavily, then composited at decaying weights. The blurs are what turn
white static into clouds; without them the result reads as TV snow.

Output: assets/scenes/hub/nebula.png — 1920x720 RGBA.

Palette
- Base tint: deep cosmic violet (#1a0e3a) — slightly darker than the
  Hub's existing sky gradient so the nebula reads as *behind* the sky,
  not on top of it.
- Wisp highlights: muted royal violet (#4a2a7a) with rare brighter
  flecks (#6a4aa0) so the eye occasionally catches a "star nursery"
  brightness without anything popping like a UI element.
- Soft luminance vignette top-to-bottom so the band darkens toward the
  horizon and lets the skyline silhouette read against it.

If this output looks like obvious noise rather than clouds: bump
`OCTAVES` blur sigmas, increase `WISP_THRESHOLD` (fewer brighter
peaks), or drop `STAR_DENSITY` to zero entirely.
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter


WIDTH, HEIGHT = 1920, 720
OUT = "assets/scenes/hub/nebula.png"

BASE_TINT = np.array([0x1A, 0x0E, 0x3A], dtype=np.float32)
WISP_TINT = np.array([0x4A, 0x2A, 0x7A], dtype=np.float32)
HOT_TINT = np.array([0x6A, 0x4A, 0xA0], dtype=np.float32)

# Octaves: (downsample, blur_sigma, weight). Lower-frequency octaves
# (heavily downsampled then upscaled) carry the big cloudy shapes;
# higher-frequency octaves add a tiny bit of grain. Blur sigmas are
# generous so nothing reads as "noise."
OCTAVES = [
    (24, 80.0, 1.00),  # huge, soft blobs
    (12, 40.0, 0.55),  # mid-scale wisps
    (6, 18.0, 0.25),   # close-in texture
]

WISP_THRESHOLD = 0.55  # values above this become brighter wisps
HOT_THRESHOLD = 0.82   # values above this become hot star-nursery cores
STAR_DENSITY = 0.00018 # tiny lighter flecks per-pixel; 0 to disable
SEED = 0xC051C0DE


def _octave(rng: np.random.Generator, downsample: int, sigma: float) -> np.ndarray:
    small_w = max(WIDTH // downsample, 4)
    small_h = max(HEIGHT // downsample, 4)
    raw = rng.random((small_h, small_w), dtype=np.float32)
    img = Image.fromarray((raw * 255).astype(np.uint8), mode="L")
    img = img.resize((WIDTH, HEIGHT), Image.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=sigma))
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return arr


def main() -> None:
    rng = np.random.default_rng(SEED)
    field = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
    weight_sum = 0.0
    for downsample, sigma, weight in OCTAVES:
        field += _octave(rng, downsample, sigma) * weight
        weight_sum += weight
    field /= weight_sum
    # Re-normalize to span 0..1 so thresholds stay meaningful even if
    # the random seed produces a low-contrast field.
    field -= field.min()
    if field.max() > 0:
        field /= field.max()

    # Build RGB by interpolating BASE -> WISP -> HOT along the field.
    base_to_wisp = np.clip(field / WISP_THRESHOLD, 0.0, 1.0)[..., None]
    rgb = BASE_TINT * (1.0 - base_to_wisp) + WISP_TINT * base_to_wisp

    hot_mask = (field > HOT_THRESHOLD).astype(np.float32)
    if hot_mask.any():
        hot_strength = ((field - HOT_THRESHOLD) / (1.0 - HOT_THRESHOLD)).clip(0.0, 1.0)
        # Soften the hot peaks so they bloom rather than clip.
        hot_img = Image.fromarray((hot_strength * 255).astype(np.uint8), mode="L")
        hot_img = hot_img.filter(ImageFilter.GaussianBlur(radius=14.0))
        hot_strength = (np.asarray(hot_img, dtype=np.float32) / 255.0)[..., None]
        rgb = rgb * (1.0 - hot_strength) + HOT_TINT * hot_strength

    # Vertical luminance falloff — nebula brightest in the middle, fades
    # toward top (sky meets) and bottom (skyline reads against dark).
    yy = np.linspace(-1.0, 1.0, HEIGHT, dtype=np.float32)
    vfade = (1.0 - yy ** 2 * 0.7).clip(0.0, 1.0)[:, None, None]
    rgb = rgb * (0.6 + 0.4 * vfade)

    # Sparse star flecks — tiny, slightly above the wisp tone. We add
    # them in pixel-space pre-blur so they look like distant stars not
    # like a perfectly clean dot pattern.
    if STAR_DENSITY > 0:
        star_mask = rng.random((HEIGHT, WIDTH)) < STAR_DENSITY
        if star_mask.any():
            star_layer = np.zeros((HEIGHT, WIDTH), dtype=np.float32)
            star_layer[star_mask] = 1.0
            star_img = Image.fromarray((star_layer * 255).astype(np.uint8), mode="L")
            star_img = star_img.filter(ImageFilter.GaussianBlur(radius=0.8))
            star_strength = (np.asarray(star_img, dtype=np.float32) / 255.0)[..., None]
            rgb = rgb + HOT_TINT * star_strength * 0.6

    rgb = np.clip(rgb, 0.0, 255.0)
    alpha = np.full((HEIGHT, WIDTH, 1), 255.0, dtype=np.float32)
    rgba = np.concatenate([rgb, alpha], axis=-1).astype(np.uint8)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT)
    print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
