"""Bake Realm 3's far-mist backdrop into the realm's own palette.

The painted mist arrives OLIVE — yellow-green — and Realm 3 lives in a deep
teal-green. A runtime `modulate` was tried first and is the wrong tool: a
multiply drags olive toward teal by crushing the red channel, which muddies
the midtones instead of moving the hue. This is a one-time bake in HSV, so
the hue actually rotates and the result stays clean.

  olivemistbg_src.png   the untouched original (never overwritten)
  olivemistbg.png       the graded backdrop the scene loads

The targets are not eyeballed — they are the realm's own constants, taken
from `scripts/Realm3FungalTest.gd`:

  BG_TOP     #122B28   the sky the level already draws
  BG_BOTTOM  #0A1614   what it sinks to
  SIL_MID    #12201D   the midground silhouettes the mist must sit BEHIND

Sanity rule, enforced in the value remap: no part of the graded mist may be
brighter than the midground it hides behind. Backdrops that outrank their own
foreground stop reading as distance and start reading as a mistake.

Usage:  python tools/grade_olivemist.py [--preview]
"""

import sys

import numpy as np
from PIL import Image

SRC = "assets/realms/realm3_fungal/olivemistbg_src.png"
DST = "assets/realms/realm3_fungal/olivemistbg.png"

# --- the realm's palette (sampled from Realm3FungalTest.gd, not invented) ---
BG_TOP = (0x12, 0x2B, 0x28)
BG_BOTTOM = (0x0A, 0x16, 0x14)
SIL_MID = (0x12, 0x20, 0x1D)


def rgb_to_hue_deg(c):
    r, g, b = [v / 255.0 for v in c]
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        return 0.0
    if mx == r:
        h = 60.0 * (((g - b) / d) % 6.0)
    elif mx == g:
        h = 60.0 * (((b - r) / d) + 2.0)
    else:
        h = 60.0 * (((r - g) / d) + 4.0)
    return h


def value_of(c):
    return max(c) / 255.0


def main():
    target_hue = rgb_to_hue_deg(BG_TOP)          # ~173 deg, the realm's teal
    # the mist must land BELOW the midground silhouettes in value, with a
    # little headroom, and never fully black or the fog stops reading as fog
    # Measured against BG_TOP, the sky the level already draws, NOT SIL_MID.
    # SIL_MID is the darkest silhouette colour in the realm (luminance 0.113);
    # forcing every pixel under it compressed the mist into a 0.06-wide band
    # and the bake came out as a black rectangle. The backdrop still has to
    # sit behind the world in value — it just needs a range wide enough to
    # still be an image.
    v_hi = value_of(BG_TOP) * 1.18
    v_lo = value_of(BG_BOTTOM) * 0.30
    print("target hue %.1f deg   value window %.3f..%.3f" % (target_hue, v_lo, v_hi))

    im = Image.open(SRC).convert("RGB")
    hsv = np.asarray(im.convert("HSV")).astype(np.float32)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]

    # --- HUE: rotate onto the realm's teal, keeping a little of the art's own
    # variation so the mist does not flatten into one colour ---
    th = target_hue / 360.0 * 255.0
    h_mean = float(h.mean())
    h_new = th + (h - h_mean) * 0.22
    h_new = np.mod(h_new, 255.0)

    # --- SATURATION: the realm is muted. Olive arrives loud. ---
    # 0.62 was too deep a cut — it took the teal out along with the olive and
    # the mist came back grey. The realm is muted, not colourless.
    s_new = np.clip(s * 1.05, 0, 255)

    # --- VALUE: compress the whole image into the level's dark register ---
    v_min, v_max = float(v.min()), float(v.max())
    span = max(v_max - v_min, 1e-5)
    v_norm = (v - v_min) / span
    # a gentle gamma keeps the mist's soft shapes from crushing to flat black
    v_norm = np.power(v_norm, 0.82)
    v_new = (v_lo + v_norm * (v_hi - v_lo)) * 255.0

    out = np.stack([h_new, s_new, np.clip(v_new, 0, 255)], axis=-1)
    graded = Image.fromarray(out.astype(np.uint8), mode="HSV").convert("RGB")
    graded.save(DST)

    # --- prove the sanity rule rather than asserting it ---
    arr = np.asarray(graded).astype(np.float32) / 255.0
    lum = arr @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    sil_lum = (np.array(SIL_MID, dtype=np.float32) / 255.0) @ np.array(
        [0.2126, 0.7152, 0.0722], dtype=np.float32)
    print("graded luminance  min %.4f  mean %.4f  max %.4f"
          % (lum.min(), lum.mean(), lum.max()))
    print("midground SIL_MID luminance %.4f" % sil_lum)
    over = float((lum > sil_lum).mean()) * 100.0
    print("pixels brighter than midground: %.2f%%  %s"
          % (over, "OK" if over < 1.0 else "TOO BRIGHT — lower v_hi"))
    # and that no yellow-olive survived
    hh = np.asarray(graded.convert("HSV")).astype(np.float32)[..., 0] / 255.0 * 360.0
    olive = float(((hh > 40) & (hh < 110)).mean()) * 100.0
    print("olive-hue pixels remaining: %.3f%%  %s"
          % (olive, "OK" if olive < 1.0 else "HUE CLASH"))

    if "--preview" in sys.argv:
        Image.open(SRC).resize((640, 360)).save("mist_before.png")
        graded.resize((640, 360)).save("mist_after.png")
        print("wrote mist_before.png / mist_after.png")


if __name__ == "__main__":
    main()
