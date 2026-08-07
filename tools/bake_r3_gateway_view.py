"""Bake the glimpse of Realm 3 seen through the Realm 2 -> Realm 3 gateway.

Same principle as `bake_gateway_view.py`, one realm further on (Advika: "just
like how we made a gateway for r2, the concept is the same"). The doorway at the
top of Realm 2's ascent is built out of REALM 3's own assets, and the passage
between its posts shows the far side — so the honest way to make that view is to
PHOTOGRAPH Realm 3 rather than mock one up:

    R3_SHOT_X=6300 R3_SHOT=r3view_6300.png godot --path . res://scenes/realms/Realm3FungalTest.tscn

...then this crops a slice whose aspect already matches the opening, so nothing
is stretched.

WHAT TO CROP, learned the hard way on the Realm 1 gateway: pick the part of the
frame with the most READABLE content — a lit cap, layered silhouettes, depth
behind them. Two earlier bakes there cropped dark forest floor, which through an
opening this size is just a smudge. Realm 3 is a much darker level than Realm 2,
so it also lifts harder (BRIGHT) — seen through an arch it has to read as a
place, not as a hole.

The crop also has to CLEAR CURIOSITY herself: at R3_SHOT_X she is parked dead
centre (~x 900-1010, y 570-700 in a 1920x1080 frame) and a sliver of her cloak
showing in the far realm reads as a bug. This takes the left-of-centre third.

Run:  python tools/bake_r3_gateway_view.py <dir containing r3view_6300.png>
Out:  assets/realms/realm3_fungal/r3_gateway_view.png
"""
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "realms", "realm3_fungal",
                   "r3_gateway_view.png")

# left, top, right, bottom -> 480x688, aspect 0.698, matching the opening
CROP = (150, 240, 630, 928)
SIZE = (480, 688)                 # source resolution: the door draws it smaller
BRIGHT = 2.05                     # Realm 3 is darker than Realm 2 was
SATURATE = 1.30


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    src = Image.open(os.path.join(folder, "r3view_6300.png")).convert("RGB")
    out = src.crop(CROP).resize(SIZE)
    out = ImageEnhance.Brightness(out).enhance(BRIGHT)
    out = ImageEnhance.Color(out).enhance(SATURATE)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT), out.size)


if __name__ == "__main__":
    main()
