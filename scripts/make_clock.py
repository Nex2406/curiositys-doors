"""Generate the Hub's giant ornate clock — face plus two hands.

Outputs:
- assets/scenes/hub/clock_face.png         600x600 RGBA — full dial
- assets/scenes/hub/clock_hand_hour.png     40x180 RGBA — short hand
- assets/scenes/hub/clock_hand_minute.png   30x240 RGBA — long hand

The face is built in painted layers: stone disc, carved concentric rings
on the rim, twelve radial tick marks (cardinals slightly thicker), the
darker dial face, twelve glowing hour dots with a pre-blurred halo, and
a small center boss where the hands attach. The dial is decorative —
no second hand, no actual time-of-day mapping; the AnimationPlayer in
the scene drives the rotations.

Each hand is a tapered stone shape with a warm-purple tip and a soft
glow around the tip so the player's eye reads the leading edge first.
The textures are drawn so the *base* of the hand sits at the bottom
of the texture; the consumer scene offsets the sprite so that base
lands on the clock center while the visible hand extends upward,
which means rotation around the sprite position rotates the hand
around the clock center as expected.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter


CLOCK_SIZE = 600
OUT_FACE = "assets/scenes/hub/clock_face.png"
OUT_HOUR = "assets/scenes/hub/clock_hand_hour.png"
OUT_MINUTE = "assets/scenes/hub/clock_hand_minute.png"

STONE = (0x2A, 0x1A, 0x3A, 255)
STONE_HIGHLIGHT = (0x4A, 0x3A, 0x5A, 255)
STONE_DEEP = (0x14, 0x0A, 0x1C, 255)
FACE = (0x1A, 0x0F, 0x25, 255)
DOT = (0xB8, 0x94, 0xD6, 255)
DOT_HALO = (0xB8, 0x94, 0xD6, 90)
HAND_DARK = (0x2A, 0x1A, 0x3A, 255)
HAND_RIM = (0x4A, 0x3A, 0x5A, 255)
HAND_TIP = (0xB8, 0x94, 0xD6, 255)
HAND_TIP_HALO = (0xB8, 0x94, 0xD6, 110)


def make_face() -> None:
    size = CLOCK_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2
    outer_r = 290
    rim_inner_r = 230

    # Outer disc — the rim stone body.
    draw.ellipse((cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r), fill=STONE)

    # Carved concentric outlines on the rim. Pairs of light/dark rings
    # read as bevelled grooves without us needing per-pixel shading.
    for r, color, w in [
        (outer_r - 4, STONE_HIGHLIGHT, 2),
        (outer_r - 12, STONE_DEEP, 2),
        (outer_r - 22, STONE_HIGHLIGHT, 1),
        (rim_inner_r + 8, STONE_HIGHLIGHT, 1),
        (rim_inner_r + 2, STONE_DEEP, 2),
    ]:
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=w)

    # Roman-numeral suggestion: short radial ticks at hour positions.
    # The cardinals (12 / 3 / 6 / 9) are slightly heavier so a careful
    # eye picks up the orientation.
    tick_r_outer = outer_r - 28
    tick_r_inner = rim_inner_r + 14
    for hour in range(12):
        angle = math.radians(hour * 30 - 90)
        is_cardinal = (hour % 3 == 0)
        thick = 4 if is_cardinal else 2
        x0 = cx + math.cos(angle) * tick_r_outer
        y0 = cy + math.sin(angle) * tick_r_outer
        x1 = cx + math.cos(angle) * tick_r_inner
        y1 = cy + math.sin(angle) * tick_r_inner
        draw.line((x0, y0, x1, y1), fill=STONE_HIGHLIGHT, width=thick)

    # Inner face disc — darker than rim so the hands read against it.
    draw.ellipse(
        (cx - rim_inner_r, cy - rim_inner_r, cx + rim_inner_r, cy + rim_inner_r),
        fill=FACE,
    )

    # Glowing hour markers — pre-render halo on a separate layer, blur
    # heavily, composite under the dot heads. This is what gives the
    # twelve points their lit-from-behind quality.
    halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    halo_draw = ImageDraw.Draw(halo)
    dot_radius_from_center = rim_inner_r - 14
    for hour in range(12):
        angle = math.radians(hour * 30 - 90)
        dx = cx + math.cos(angle) * dot_radius_from_center
        dy = cy + math.sin(angle) * dot_radius_from_center
        halo_draw.ellipse((dx - 20, dy - 20, dx + 20, dy + 20), fill=DOT_HALO)
    halo = halo.filter(ImageFilter.GaussianBlur(radius=10))
    img = Image.alpha_composite(img, halo)

    # Now the crisp dot heads on top of the halo.
    draw = ImageDraw.Draw(img)
    dot_r = 8
    for hour in range(12):
        angle = math.radians(hour * 30 - 90)
        dx = cx + math.cos(angle) * dot_radius_from_center
        dy = cy + math.sin(angle) * dot_radius_from_center
        draw.ellipse((dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r), fill=DOT)

    # Center boss — small stone hub the hands appear to attach to.
    boss_r = 16
    draw.ellipse((cx - boss_r, cy - boss_r, cx + boss_r, cy + boss_r), fill=STONE)
    draw.ellipse(
        (cx - boss_r + 2, cy - boss_r + 2, cx + boss_r - 2, cy + boss_r - 2),
        outline=STONE_HIGHLIGHT,
        width=1,
    )
    draw.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=DOT)

    os.makedirs(os.path.dirname(OUT_FACE), exist_ok=True)
    img.save(OUT_FACE)
    print(f"wrote {OUT_FACE} ({size}x{size})")


def make_hand(out_path: str, w: int, h: int) -> None:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    cx = w / 2.0
    base_y = h - 4
    tip_y = 4
    base_half = w / 2.0 - 2
    tip_half = max(w / 4.0, 3)

    # Halo around the tip first — drawn on a separate layer so we can
    # blur it without bleeding into the body.
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    halo_draw = ImageDraw.Draw(halo)
    halo_draw.ellipse(
        (cx - tip_half - 10, tip_y - 8, cx + tip_half + 10, tip_y + 32),
        fill=HAND_TIP_HALO,
    )
    halo = halo.filter(ImageFilter.GaussianBlur(radius=5))
    img = Image.alpha_composite(img, halo)

    draw = ImageDraw.Draw(img)

    # Body: tapered diamond-on-rectangle. Wider at base, narrower at
    # mid, then a small crisp point at the tip.
    body_points = [
        (cx - base_half, base_y),
        (cx - base_half * 0.85, base_y - 12),
        (cx - tip_half, tip_y + 24),
        (cx, tip_y),
        (cx + tip_half, tip_y + 24),
        (cx + base_half * 0.85, base_y - 12),
        (cx + base_half, base_y),
    ]
    draw.polygon(body_points, fill=HAND_DARK, outline=HAND_RIM)

    # Tip cap — warm purple triangle covering the upper third of the
    # hand. This is the part the eye tracks as it sweeps the dial.
    cap_h = max(int(h * 0.18), 18)
    draw.polygon(
        [
            (cx - tip_half + 1, tip_y + cap_h),
            (cx, tip_y),
            (cx + tip_half - 1, tip_y + cap_h),
        ],
        fill=HAND_TIP,
    )

    # Tiny inset gem near the base for ornamentation.
    gem_y = base_y - 18
    draw.polygon(
        [
            (cx, gem_y - 4),
            (cx + 4, gem_y),
            (cx, gem_y + 4),
            (cx - 4, gem_y),
        ],
        fill=DOT,
    )

    img.save(out_path)
    print(f"wrote {out_path} ({w}x{h})")


def main() -> None:
    make_face()
    make_hand(OUT_HOUR, 40, 180)
    make_hand(OUT_MINUTE, 30, 240)


if __name__ == "__main__":
    main()
