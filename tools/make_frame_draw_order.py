"""Bake the frame's DRAW ORDER MAP — the border inscribes itself instead of fading in.

Same idea and same shader as the title (see make_title_write_order.py): a greyscale field
saying when each pixel appears, so the reveal is exact and the shader stays trivial.

The frame is a loop, not two lines, so the ordering is by PERIMETER DISTANCE FROM THE
CROWN — the eye at top centre. Both directions run at once and meet at the bottom centre,
which is where the moon ornament sits, so the border closes on a feature rather than in the
middle of a blank rule.

Distance is measured along the rectangle's edges, NOT by angle from the centre: an angular
sweep crawls through the corners and races along the top, and you can see it happen.

    python tools/make_frame_draw_order.py

Writes assets/ui/menu/menu_frame_order.png (RGB, same size as the frame art):
    R = draw time 0..1, spread to the empty pixels around each stroke
    G = nearness to a stroke, for the nib glow that appears to be doing the drawing
"""

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/ui/menu/menu_frame_eye.png"
DST = ROOT / "assets/ui/menu/menu_frame_order.png"

ALPHA_CUTOFF = 20
HALO_RADIUS = 10.0


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    alpha = np.array(img)[:, :, 3]
    h, w = alpha.shape
    mask = alpha > ALPHA_CUTOFF
    print(f"{SRC.name}: {w}x{h}, {int(mask.sum())} px of ornament")

    cx, cy = (w - 1) * 0.5, (h - 1) * 0.5
    hw, hh = cx, cy
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    dx, dy = xs - cx, ys - cy

    # push each pixel out along its own direction until it meets the rectangle's edge —
    # that landing point is what gets a position along the perimeter
    with np.errstate(divide="ignore", invalid="ignore"):
        sx = np.where(dx != 0.0, hw / np.abs(dx), np.inf)
        sy = np.where(dy != 0.0, hh / np.abs(dy), np.inf)
    s = np.minimum(sx, sy)
    s[~np.isfinite(s)] = 1.0
    px, py = dx * s, dy * s          # relative to centre, on the boundary

    on_vertical = np.abs(np.abs(px) - hw) < 1e-6      # left or right edge
    # clockwise arc length from top centre, over the full perimeter 4*(hw+hh)
    arc = np.zeros_like(px)
    # top edge (py < 0, horizontal): arc = px  (negative to the left, handled by symmetry)
    top = (~on_vertical) & (py <= 0)
    arc[top] = px[top]
    # right edge: hw + (py + hh)
    right = on_vertical & (px > 0)
    arc[right] = hw + (py[right] + hh)
    # left edge: mirror of right, measured anticlockwise -> stored negative
    left = on_vertical & (px <= 0)
    arc[left] = -(hw + (py[left] + hh))
    # bottom edge, and it has to be SPLIT: the right half continues clockwise, the left half
    # continues anticlockwise. Running one formula across the whole bottom sent the left half
    # past the halfway mark, where it clamped to 1.0 — so that quarter of the border drew all
    # at once at the very end while its mirror had already finished. That is the "one side
    # finishes faster" bug.
    bottom = (~on_vertical) & (py > 0)
    br = bottom & (px >= 0)
    bl = bottom & (px < 0)
    arc[br] = hw + 2.0 * hh + (hw - px[br])
    arc[bl] = -(hw + 2.0 * hh + (hw + px[bl]))

    half = 2.0 * (hw + hh)
    order = np.clip(np.abs(arc) / half, 0.0, 1.0)
    order[~mask] = 1.0

    dist, (iy, ix) = ndimage.distance_transform_edt(~mask, return_indices=True)
    spread = np.where(mask, order, order[iy, ix])
    near = np.clip(1.0 - dist / HALO_RADIUS, 0.0, 1.0)
    near[mask] = 1.0

    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    rgb[:, :, 0] = np.round(spread * 255.0)
    rgb[:, :, 1] = np.round(near * 255.0)
    Image.fromarray(rgb, mode="RGB").save(DST)

    ink = order[mask]
    print(f"  draw times on ink: {ink.min():.3f} - {ink.max():.3f}")
    print(f"  halo: {int((near > 0).sum() - mask.sum())} px of glow room")
    print(f"wrote {DST}")


if __name__ == "__main__":
    main()
