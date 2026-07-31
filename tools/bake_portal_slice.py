"""Re-bake the Realm 2 glimpse that sits inside the Realm 1 portal.

The problem with r2_forest_peek.png: it is a 480x729 grab of a WIDE forest shot,
displayed at 0.30 scale inside a ~90x234 opening. That is a 3.3x downscale of an
already-wide frame, so every element — trunks, fireflies, flower clusters — lands
2-4px across and the whole thing reads as a murky smudge.

Cropping is zooming. This takes a tall slice whose aspect already matches the
opening (200x520 -> 0.385, same as 90/234) centred on the readable content: the pale
trunk, the firefly cluster, and one glowing flower mass. Displayed at 0.45 it is only
a 2.2x downscale of a region that fills the frame, so the content actually reads.

Out: assets/realms/realm1_door/r2_forest_slice.png
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "realms", "realm1_door", "r2_forest_peek.png")
OUT = os.path.join(ROOT, "assets", "realms", "realm1_door", "r2_forest_slice.png")

# opening is ~90x234 -> 0.3846. The crop matches it so nothing is stretched.
CROP = (150, 40, 350, 560)          # left, top, right, bottom -> 200x520

src = Image.open(SRC).convert("RGBA")
assert src.size == (480, 729), src.size
out = src.crop(CROP)
assert out.size == (200, 520), out.size
print("slice %s  aspect %.4f  (opening 90/234 = %.4f)"
      % (out.size, out.width / out.height, 90 / 234))
out.save(OUT)
print("wrote", OUT)
