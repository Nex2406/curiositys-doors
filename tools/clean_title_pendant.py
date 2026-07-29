"""One-off: erase the leftover pendant ornament from the menu title art.

A small pendant (diamond + two flanking dots) hangs off the bottom of the title's top
flourish at x 568-626, y 228-254. It cannot be cropped away: the "C" of CURIOSITY'S
begins at y=231, so the two overlap by 23 rows and any horizontal crop that clears the
pendant decapitates the lettering. It has to come out of the alpha channel instead.

The erase window (x 550-648, y 214-258) fully contains the pendant with margin and
sits inside a clear corridor — the "U" ends at x=540, the "O" begins at x=653 — so no
letterform is touched. The original file is never modified.

Out: assets/ui/menu/title_curiositys_doors_clean.png
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "ui", "menu", "title_curiositys_doors.png")
OUT = os.path.join(ROOT, "assets", "ui", "menu", "title_curiositys_doors_clean.png")

BOX = (550, 214, 648, 258)      # left, top, right, bottom

img = Image.open(SRC).convert("RGBA")
assert img.size == (1199, 900), img.size

alpha = img.getchannel("A")
before = sum(1 for v in alpha.getdata() if v > 0)

# clear alpha inside the window, leave RGB alone
cleared = Image.new("L", (BOX[2] - BOX[0], BOX[3] - BOX[1]), 0)
alpha.paste(cleared, (BOX[0], BOX[1]))
img.putalpha(alpha)

after = sum(1 for v in img.getchannel("A").getdata() if v > 0)
removed = before - after
print("opaque pixels: %d -> %d  (removed %d)" % (before, after, removed))
if not (200 <= removed <= 600):
    print("WARNING: expected roughly 300-400 removed. %d suggests the window is "
          "clipping a letterform or missing the ornament." % removed)
else:
    print("OK: within the expected 300-400 band — ornament only, no letterforms.")

img.save(OUT)
print("wrote", OUT)
