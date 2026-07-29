"""Bake the title's WRITE ORDER MAP — greyscale, one value per pixel, "when do I appear".

The title is two lines plus a flourish, so a plain left-to-right wipe is wrong: the D of
DOORS sits far left of the S of CURIOSITY'S, and a global sweep would start the second
line before the first was finished. Encoding the order per pixel instead makes the shader
trivial (`reveal = order <= progress`) and the sequencing exact.

Grouping is computable, not hand-painted: the art separates cleanly into connected
components, and each component's centroid y puts it in one of three bands.

    python tools/make_title_write_order.py

Writes TWO files, both the same dimensions as the source art.

assets/ui/menu/title_plate.png — the title with the top flourish and eye divider ERASED.
The menu crops the art to skip those, but the crop line lands 1px above the tallest letter,
which slices the glow flat across the top of the C. Erasing them instead lets the crop open
up and give the light somewhere to go.

assets/ui/menu/title_write_order.png:

    R = reveal time, 0..1. On ink it is that pixel's own time; on the empty pixels around
        the ink it is the NEAREST ink pixel's time, so the nib glow knows where the stroke
        it belongs to is.
    G = nearness to ink, 1 at the stroke falling to 0 at HALO_RADIUS. The title's cream is
        already near-white, so a nib that only brightens the ink is invisible — it clips.
        The glow has to land in the dark AROUND the letters, and this is the mask for it.

Re-run it if the title art is ever recut.
"""

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/ui/menu/title_curiositys_doors_clean.png"
DST = ROOT / "assets/ui/menu/title_write_order.png"
PLATE = ROOT / "assets/ui/menu/title_plate.png"

# Components lying entirely above this y are the top flourish and the eye divider, which
# the menu's crop skips. They are erased from the plate so the crop can be opened upward.
CROP_TOP = 232

ALPHA_CUTOFF = 30
LINE1_MAX_Y = 470.0   # centroid above this -> CURIOSITY'S
LINE2_MAX_Y = 700.0   # ...between the two -> DOORS; below -> the flourish

# Line 1 runs 0.00-0.42, line 2 runs 0.48-0.82, the flourish 0.86-1.00. The 0.42 -> 0.48
# gap is deliberate: it becomes a short pause between the lines, which is what makes the
# reveal feel like a hand lifting rather than a machine scanning.
LINE1 = (0.00, 0.42)
LINE2 = (0.48, 0.34)
FLOURISH = (0.86, 0.14)

# How far light may spread off a stroke, in source pixels. This one field feeds both the
# nib and the letters' resting glow; the shader shapes each with its own exponent, so bake
# it wide (the title draws at 0.55, so 26 here is ~14 screen px) and tighten in the shader.
HALO_RADIUS = 26.0


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    rgba = np.array(img)
    alpha = rgba[:, :, 3]
    mask = alpha > ALPHA_CUTOFF
    labels, n = ndimage.label(mask)
    print(f"{SRC.name}: {img.size[0]}x{img.size[1]}, {n} connected components")

    # --- the plate: drop everything that lives entirely above the crop line -------------
    boxes = ndimage.find_objects(labels)
    above = [i for i, sl in enumerate(boxes, start=1) if sl is not None and sl[0].stop <= CROP_TOP]
    if above:
        drop = np.isin(labels, above)
        plate = rgba.copy()
        plate[drop] = 0
        Image.fromarray(plate, mode="RGBA").save(PLATE)
        print(f"  plate: erased {len(above)} components above y={CROP_TOP} -> {PLATE.name}")
        # everything downstream describes the PLATE, not the source
        rgba = plate
        alpha = rgba[:, :, 3]
        mask = alpha > ALPHA_CUTOFF
        labels, n = ndimage.label(mask)

    centroids = ndimage.center_of_mass(mask, labels, range(1, n + 1))
    # band index per component: 0 = line 1, 1 = line 2, 2 = flourish
    band_of_label = np.zeros(n + 1, dtype=np.int8)
    for i, (cy, _cx) in enumerate(centroids, start=1):
        band_of_label[i] = 0 if cy < LINE1_MAX_Y else (1 if cy <= LINE2_MAX_Y else 2)

    band = band_of_label[labels]           # per pixel, 0 outside the glyphs too
    xs = np.broadcast_to(np.arange(img.size[0]), alpha.shape)

    order = np.ones(alpha.shape, dtype=np.float64)   # transparent pixels never reveal
    for b, (name, start, span) in enumerate(
            [("CURIOSITY'S", *LINE1), ("DOORS", *LINE2), ("flourish", *FLOURISH)]):
        sel = mask & (band == b)
        if not sel.any():
            print(f"  band {b} ({name}): EMPTY")
            continue
        bx = xs[sel]
        xmin, xmax = int(bx.min()), int(bx.max())
        if b < 2:
            # left to right, normalised to this line's OWN extent so each line uses its
            # whole slice of time no matter how wide it is
            t = start + span * (bx - xmin) / max(1, xmax - xmin)
        else:
            # the flourish draws outward from its centre in both directions at once —
            # that is how a symmetrical ornament reads; swept, it looks like it is falling
            centre = (xmin + xmax) * 0.5
            half = max(1.0, (xmax - xmin) * 0.5)
            t = start + span * np.abs(bx - centre) / half
        order[sel] = t
        print(f"  band {b} ({name}): {int(sel.sum()):>7} px  x[{xmin},{xmax}]  "
              f"t {t.min():.3f}-{t.max():.3f}")

    # Spread the times off the ink: every empty pixel adopts its nearest stroke's time, and
    # records how far away that stroke is. One EDT gives both.
    dist, (iy, ix) = ndimage.distance_transform_edt(~mask, return_indices=True)
    spread = np.where(mask, order, order[iy, ix])
    near = np.clip(1.0 - dist / HALO_RADIUS, 0.0, 1.0)
    near[mask] = 1.0
    print(f"  halo: {int((near > 0).sum() - mask.sum()):>7} px of glow room around the ink")

    rgb = np.zeros(alpha.shape + (3,), dtype=np.uint8)
    rgb[:, :, 0] = np.round(spread * 255.0)
    rgb[:, :, 1] = np.round(near * 255.0)
    Image.fromarray(rgb, mode="RGB").save(DST)
    print(f"wrote {DST}")


if __name__ == "__main__":
    main()
