"""Build EVIL CURIOSITY — the mirror boss's sheet — from Curiosity's own frames.

The boss is her, drained. So it is not drawn: it is DERIVED, frame for frame,
from the sheets the player has been watching for three realms. Same filenames,
same dimensions, same alignment, so the two are interchangeable in engine and
the boss inherits her exact animation timing.

Three operations per frame:

  BODY   Luminance is preserved and remapped onto a charcoal ramp. A flat black
         fill was rejected on purpose — it destroys the cloak's folds and the
         silhouette stops reading. This drains her; it does not erase her.

  EYES   Masked by luminance AND NEUTRALITY. Measured on idle1: the eyes are
         791 pixels of RGB(248,248,248) — R-B is exactly 0 — while every
         lantern/spill pixel above the same luminance sits at R-B +50..+180.
         So a plain ">85% luminance" mask (the obvious one) recolours the
         lantern red along with the eyes. Requiring near-neutral grey splits
         them cleanly with no per-frame head box needed.

  LANTERN  Baked into the body art (idle1: x 252-273, y 211-243). Two modes,
         because this is Advika's call and not mine:
           --lantern dead   charcoal body, flame burns RED  (default)
           --lantern strip  cut it out of the frame entirely

Usage:
  python tools/make_evil_curiosity.py            # all anims, dead lantern
  python tools/make_evil_curiosity.py --lantern strip
  python tools/make_evil_curiosity.py --contact  # also write a contact strip
"""

import os
import sys
import glob

from PIL import Image, ImageFilter

SRC_ROOT = "assets/player/curiosity"
DST_ROOT = "assets/player/evil_curiosity"
ANIMS = ["idle", "walk", "run", "jump", "attack", "hurt", "celebrate"]

# ---- the charcoal ramp the body is remapped onto ----
CHAR_DARK = (0x1c, 0x1e, 0x28)
CHAR_LIT = (0x5e, 0x62, 0x76)

# ---- the eyes ----
EYE_CORE = (0xff, 0x2b, 0x3d)
EYE_EDGE = (0x7a, 0x0c, 0x18)
EYE_LUM = 0.85          # measured: the eyes sit far above this
EYE_NEUTRAL = 26        # max |R-B| / |R-G| to count as the white of an eye

# ---- what counts as lantern light rather than cloak ----
WARM_RB = 35            # R-B above this on a lit pixel = flame, not fabric
WARM_LUM = 0.42


def _lum(r, g, b):
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def _ramp(t, lo, hi):
    return tuple(int(round(lo[i] + (hi[i] - lo[i]) * t)) for i in range(3))


def convert(path_in, path_out, lantern_mode):
    im = Image.open(path_in).convert("RGBA")
    w, h = im.size
    src = im.load()

    # pass 1 — classify every pixel, and build the eye mask as an image so it
    # can be eroded for the radial falloff
    eye_mask = Image.new("L", (w, h), 0)
    em = eye_mask.load()
    warm = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a < 24:
                continue
            L = _lum(r, g, b)
            neutral = abs(r - b) <= EYE_NEUTRAL and abs(r - g) <= EYE_NEUTRAL
            if L > EYE_LUM and neutral:
                em[x, y] = 255
            elif L > WARM_LUM and (r - b) > WARM_RB:
                warm[y][x] = True

    # the core of the eye is what survives erosion; the rim is what does not,
    # which gives the falloff from #ff2b3d out to #7a0c18
    core = eye_mask.filter(ImageFilter.MinFilter(5))
    cm = core.load()

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            L = _lum(r, g, b)

            if em[x, y]:
                t = cm[x, y] / 255.0
                cr, cg, cb = _ramp(t, EYE_EDGE, EYE_CORE)
                dst[x, y] = (cr, cg, cb, a)
                continue

            if warm[y][x]:
                if lantern_mode == "strip":
                    dst[x, y] = (0, 0, 0, 0)
                    continue
                # a dead lantern with a red flame: keep the light's own shape
                # and brightness, move it onto the eyes' red
                t = min(1.0, max(0.0, (L - WARM_LUM) / (1.0 - WARM_LUM)))
                cr, cg, cb = _ramp(t, EYE_EDGE, EYE_CORE)
                dst[x, y] = (cr, cg, cb, a)
                continue

            # body: keep the shading, drain the colour
            cr, cg, cb = _ramp(L, CHAR_DARK, CHAR_LIT)
            dst[x, y] = (cr, cg, cb, a)

    os.makedirs(os.path.dirname(path_out), exist_ok=True)
    out.save(path_out)
    return out


def main():
    lantern_mode = "dead"
    if "--lantern" in sys.argv:
        lantern_mode = sys.argv[sys.argv.index("--lantern") + 1]
    want_contact = "--contact" in sys.argv

    made = []
    for anim in ANIMS:
        files = sorted(glob.glob(os.path.join(SRC_ROOT, anim, "*.png")),
                       key=lambda p: (len(p), p))
        for f in files:
            name = os.path.basename(f)
            out = os.path.join(DST_ROOT, anim, name)
            convert(f, out, lantern_mode)
            made.append(out)
        print("%-10s %2d frames" % (anim, len(files)))
    print("total %d frames -> %s (lantern=%s)" % (len(made), DST_ROOT, lantern_mode))

    if want_contact:
        # one strip per animation's first 6 frames, for a look-at-it review
        rows = []
        for anim in ANIMS:
            fs = sorted(glob.glob(os.path.join(DST_ROOT, anim, "*.png")),
                        key=lambda p: (len(p), p))[:6]
            if fs:
                rows.append((anim, fs))
        if rows:
            cw = Image.open(rows[0][1][0]).size[0]
            ch = Image.open(rows[0][1][0]).size[1]
            sheet = Image.new("RGBA", (cw * 6, ch * len(rows)), (18, 20, 24, 255))
            for ri, (anim, fs) in enumerate(rows):
                for ci, f in enumerate(fs):
                    sheet.paste(Image.open(f), (ci * cw, ri * ch))
            sheet.save("evil_contact.png")
            print("contact strip -> evil_contact.png")


if __name__ == "__main__":
    main()
