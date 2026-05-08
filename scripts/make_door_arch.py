"""Generate the Hub door-arch — carved stone frame around a deep void.

Output: assets/scenes/hub/door_arch.png — 120x180 RGBA.

The previous version was a flat two-tone rectangle that read as a
color block once placed in the scene. This rebuild gives the door
substance:

- 12px stone frame in mottled `#3a2a4a`, with darker crack noise
  scattered through it so it doesn't look like a single uniform
  swatch. The mottle is procedural (gaussian-blurred random fields)
  so each generation is a little different but always feels like
  weathered stone, not pixel art.
- The frame interior is a soft radial void gradient — `#0a0612` at
  the center fading to `#1a0f25` at the edges — replacing the old
  flat fill. This carries the "doorway leads somewhere deeper" feel
  without needing a separate animated overlay.
- A warm-purple inner rim glow (`#6a4a8a`) sits in a thin band
  immediately inside the stone frame, blurred so it reads as light
  bleeding from the void into the stone rather than as a hard line.
- A tiny carved keystone diamond at the apex of the arch (`#7a5a9a`)
  in lighter stone — the kind of detail a player only notices on
  second look but which sells the "this was built" reading.

Same 120x180 silhouette as before so collision shapes and prompt
positions in Hub.tscn don't need to change.
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


WIDTH, HEIGHT = 120, 180
ARCH_RADIUS = 45  # rounded top corners; bottom stays square
FRAME_THICK = 12
OUT = "assets/scenes/hub/door_arch.png"

STONE_BASE = np.array([0x3A, 0x2A, 0x4A], dtype=np.float32)
STONE_DARK = np.array([0x1A, 0x10, 0x22], dtype=np.float32)
STONE_HIGH = np.array([0x52, 0x42, 0x62], dtype=np.float32)
INNER_GLOW = np.array([0x6A, 0x4A, 0x8A], dtype=np.float32)
VOID_CENTER = np.array([0x0A, 0x06, 0x12], dtype=np.float32)
VOID_EDGE = np.array([0x1A, 0x0F, 0x25], dtype=np.float32)
KEYSTONE_COLOR = (0x7A, 0x5A, 0x9A, 255)
KEYSTONE_RIM = (0x4A, 0x3A, 0x5A, 255)

SEED = 0xD003


def _arch_mask(w: int, h: int, radius: int, inset: int = 0) -> np.ndarray:
    """Return an L-mode array (0/255) for the arch silhouette, optionally
    inset by `inset` pixels on every side. Inset shrinks the rounded top
    corner radius the same amount so the inner shape matches."""
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    inner_radius = max(radius - inset, 4)
    d.rounded_rectangle(
        (inset, inset, w - 1 - inset, h - 1 - inset),
        radius=inner_radius,
        fill=255,
    )
    d.rectangle(
        (inset, h - 1 - inset - inner_radius, w - 1 - inset, h - 1 - inset),
        fill=255,
    )
    return np.asarray(img, dtype=np.uint8)


def main() -> None:
    rng = np.random.default_rng(SEED)
    outer_mask = _arch_mask(WIDTH, HEIGHT, ARCH_RADIUS, inset=0)
    inner_mask = _arch_mask(WIDTH, HEIGHT, ARCH_RADIUS, inset=FRAME_THICK)

    stone_region = (outer_mask > 0) & (inner_mask == 0)

    # Stone fill — start from base color and modulate with two noise
    # fields. The fine field gives grain, the coarse field gives larger
    # patches of darker "weathering."
    fine = rng.normal(0.5, 0.15, (HEIGHT, WIDTH)).astype(np.float32).clip(0.0, 1.0)
    fine_img = Image.fromarray((fine * 255).astype(np.uint8))
    fine_img = fine_img.filter(ImageFilter.GaussianBlur(radius=0.6))
    fine = (np.asarray(fine_img, dtype=np.float32) / 255.0 - 0.5) * 0.35

    coarse_raw = rng.random((HEIGHT, WIDTH)).astype(np.float32)
    coarse_img = Image.fromarray((coarse_raw * 255).astype(np.uint8))
    coarse_img = coarse_img.filter(ImageFilter.GaussianBlur(radius=3.0))
    coarse = np.asarray(coarse_img, dtype=np.float32) / 255.0
    crack_strength = ((coarse - 0.62) / 0.38).clip(0.0, 1.0)[..., None] * 0.65

    stone_rgb = STONE_BASE + fine[..., None] * 60.0  # ±~10 luminance
    stone_rgb = stone_rgb * (1.0 - crack_strength) + STONE_DARK * crack_strength

    # Subtle highlight along the top half — sells the bevelled feel of
    # a stone arch lit from above.
    yy = np.linspace(0, 1, HEIGHT, dtype=np.float32)[:, None, None]
    top_lift = (1.0 - yy).clip(0, 1) ** 2 * 0.08
    stone_rgb = stone_rgb * (1 - top_lift) + STONE_HIGH * top_lift

    # Void fill — radial gradient from center.
    yy_v, xx_v = np.mgrid[0:HEIGHT, 0:WIDTH].astype(np.float32)
    cx = (WIDTH - 1) / 2.0
    cy = (HEIGHT - 1) / 2.0
    nx = (xx_v - cx) / cx
    ny = (yy_v - cy) / cy
    radial = np.sqrt(nx * nx + ny * ny).clip(0.0, 1.0)
    void_t = radial[..., None]
    void_rgb = VOID_CENTER * (1.0 - void_t) + VOID_EDGE * void_t

    rgb = np.where(stone_region[..., None], stone_rgb, void_rgb)

    # Inner rim glow — take the inner mask, erode a few pixels, the
    # difference is a thin band hugging the stone-side of the inner
    # boundary. Blur to soften it into a "light bleed" rather than a
    # hard ring.
    inner_pil = Image.fromarray(inner_mask)
    eroded = inner_pil.filter(ImageFilter.MinFilter(7))  # erode ~3px
    rim_band = np.asarray(inner_pil, dtype=np.float32) - np.asarray(eroded, dtype=np.float32)
    rim_band = (rim_band / 255.0).clip(0.0, 1.0)
    rim_img = Image.fromarray((rim_band * 255).astype(np.uint8))
    rim_img = rim_img.filter(ImageFilter.GaussianBlur(radius=2.2))
    rim_band = np.asarray(rim_img, dtype=np.float32) / 255.0
    rim_t = rim_band[..., None] * 0.75
    rgb = rgb * (1.0 - rim_t) + INNER_GLOW * rim_t

    # Compose to RGBA with alpha from outer mask.
    alpha = outer_mask.astype(np.float32)
    rgba = np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")

    # Keystone diamond at the apex — drawn last so it sits on top of
    # the stone texture. Small dark rim around a lighter core; reads as
    # a single carved gem in the keystone position.
    d = ImageDraw.Draw(img)
    cx_int = WIDTH // 2
    ky = 5
    d.polygon(
        [(cx_int, ky), (cx_int + 6, ky + 7), (cx_int, ky + 14), (cx_int - 6, ky + 7)],
        fill=KEYSTONE_RIM,
    )
    d.polygon(
        [(cx_int, ky + 2), (cx_int + 4, ky + 7), (cx_int, ky + 12), (cx_int - 4, ky + 7)],
        fill=KEYSTONE_COLOR,
    )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
