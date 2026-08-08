"""Find the places in Realm 3 that READ AS A HOLE, in world coordinates.

Run the level's lit scan first, then this over the frames it wrote:

    R3_HOLES=<dir> godot --headless res://scenes/realms/Realm3FungalTest.tscn
    python tools/find_holes.py <dir> --zoom 0.78

WHY THIS EXISTS, and why the thing it replaces was wrong.

`R3_GAPS` renders a coverage mask -- every sprite flat white -- and asks "is
anything drawn here". It reported ZERO holes on a floor Advika had just circled
twice. It was not lying. Everything she circled is drawn: the sprite is there
and renders at rgb8 (0,2,2), while the moss a few pixels to its left renders at
(9,9,11) with real texture in it. A coverage test cannot tell those apart,
because to a coverage test they are both "covered".

What the eye is actually asking is whether a region has any LIGHT and any
TEXTURE. Dark is fine -- this is a dark game. Flat is fine -- a silhouette is
flat. Dark AND flat AND large is a hole, because a painterly floor always has
some of both and a hole has neither.

CALIBRATION. The two thresholds below were not picked by taste. They were swept
against the two screenshots Advika circled (2026-08-08) until the detector
flagged what she flagged; at lum<0.030 / std<0.008 it covers both of her loops
and finds four more instances of the same defect in the same frames that she
did not bother to circle. Re-calibrate the same way if the grade ever moves --
against her marks, not against a number that feels right.
"""
import argparse
import glob
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

# calibrated against Advika's circled screenshots -- see the module docstring
LUM_MAX = 0.030      # local mean luminance below which there is no light
STD_MAX = 0.008      # local standard deviation below which there is no texture
WIN = 15             # px, the neighbourhood both are measured over
MIN_AREA = 6000      # px, smaller than this is a shadow between fronds
BAND_LO = 0.55       # only look below this fraction of frame height: the floor

# FLAT IS ENOUGH, EVEN WHEN IT IS NOT DARK. Added 2026-08-08 after this detector
# missed the gap Advika had circled three times: a strip of bare soil between two
# moss courses, measuring lum 0.033 against the 0.030 cutoff above. Dark AND flat
# was too strict a rule -- it described the holes I had already found rather than
# the thing the eye objects to, which is a SMOOTH FILL. In a painterly floor a
# large untextured region reads as missing at any value, so flatness alone flags
# it, up to a ceiling where the region is bright enough to be a lit surface.
FLAT_LUM_MAX = 0.060   # above this a flat region is a lit mushroom cap, not a hole
FLAT_STD_MAX = 0.006   # tighter than STD_MAX: a brighter hole must be flatter


def luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def dead_mask(rgb, lum_max=LUM_MAX, std_max=STD_MAX, win=WIN,
              min_area=MIN_AREA, band_lo=BAND_LO):
    """Boolean mask of regions with neither light nor texture in them."""
    y = luma(rgb)
    mean = ndimage.uniform_filter(y, win)
    sq = ndimage.uniform_filter(y * y, win)
    std = np.sqrt(np.maximum(sq - mean * mean, 0.0))
    # either it has no light and no texture, or it is simply a flat fill
    dead = ((mean < lum_max) & (std < std_max)) \
        | ((mean < FLAT_LUM_MAX) & (std < FLAT_STD_MAX))
    # a one-pixel crack between two fronds is not a hole
    dead = ndimage.binary_opening(dead, np.ones((9, 9), bool))
    dead[:int(dead.shape[0] * band_lo)] = False
    lab, n = ndimage.label(dead)
    keep = np.zeros_like(dead)
    regions = []
    for i in range(1, n + 1):
        m = lab == i
        a = int(m.sum())
        if a < min_area:
            continue
        keep |= m
        ys, xs = np.nonzero(m)
        regions.append((a, int(xs.min()), int(xs.max()),
                        int(ys.min()), int(ys.max())))
    regions.sort(reverse=True)
    return keep, regions


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", help="directory of lit_###_x######.png frames")
    ap.add_argument("--zoom", type=float, required=True,
                    help="camera zoom the scan ran at (printed by GAPSCAN)")
    ap.add_argument("--cam-y", type=float, default=380.0,
                    help="camera world y the scan ran at (FLOOR_Y - 40)")
    ap.add_argument("--overlay", default="",
                    help="write annotated frames here for eyeballing")
    ap.add_argument("--lum", type=float, default=LUM_MAX)
    ap.add_argument("--std", type=float, default=STD_MAX)
    a = ap.parse_args()

    frames = sorted(glob.glob(os.path.join(a.dir, "lit_*_x*.png")))
    if not frames:
        frames = sorted(glob.glob(os.path.join(a.dir, "*.png")))
    if not frames:
        print("no frames in %s" % a.dir)
        return 1
    if a.overlay:
        os.makedirs(a.overlay, exist_ok=True)

    total_px = 0
    total_regions = 0
    worst = []
    for f in frames:
        m = re.search(r"x(-?\d+)", os.path.basename(f))
        wx0 = int(m.group(1)) if m else 0
        rgb = np.asarray(Image.open(f).convert("RGB"), dtype=np.float32) / 255.0
        keep, regions = dead_mask(rgb, a.lum, a.std)
        h, w = rgb.shape[:2]
        for area, x0, x1, y0, y1 in regions:
            # frame px -> world px: the frame is `w` px wide showing w/zoom
            # world px starting at wx0; y is centred on the camera
            wx = wx0 + x0 / a.zoom
            wxe = wx0 + x1 / a.zoom
            wy = a.cam_y + (y0 - h * 0.5) / a.zoom
            wye = a.cam_y + (y1 - h * 0.5) / a.zoom
            worst.append((area, wx, wxe, wy, wye, os.path.basename(f)))
        total_px += int(keep.sum())
        total_regions += len(regions)
        if a.overlay:
            vis = np.clip(rgb * 2.2, 0, 1)
            edge = keep & ~ndimage.binary_erosion(keep, np.ones((7, 7), bool))
            vis[keep] = vis[keep] * 0.55 + np.array([0.0, 0.55, 0.65]) * 0.45
            vis[edge] = np.array([0.0, 1.0, 1.0])
            Image.fromarray((vis * 255).astype(np.uint8)).save(
                os.path.join(a.overlay, os.path.basename(f)))

    worst.sort(reverse=True)
    print("HOLES: %d frames, %d regions, %d px of dead floor"
          % (len(frames), total_regions, total_px))
    print("       thresholds lum<%.3f std<%.3f, min area %d px"
          % (a.lum, a.std, MIN_AREA))
    for area, wx, wxe, wy, wye, f in worst[:25]:
        print("  %7d px   world x %8.0f..%-8.0f y %6.0f..%-6.0f   %s"
              % (area, wx, wxe, wy, wye, f))
    if total_regions == 0:
        print("       clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
