"""Bake the glimpse of Realm 2 seen through the Realm 1 gateway.

The gateway at the end of Realm 1 is built out of Realm 2's own assets, and the
passage between its posts shows the far side. The honest way to make that view is
to PHOTOGRAPH Realm 2 rather than mock one up, so:

    R2_SHOT_X=2200 R2_SHOT=r2view_2200.png godot --path . res://scenes/realms/Realm2LiftTest.tscn

...then this crops a slice whose aspect already matches the opening, so nothing is
stretched, from the part of that frame with the most readable content: lit mushroom
caps, stalks, fireflies and depth behind them. Earlier bakes failed for the same
reason — they cropped dark forest floor, which through an opening is just a violet
smudge (r2_forest_peek.png was also a 3.3x downscale of a WIDE frame).

2026-08-02: the view now fills the WHOLE inside of the doorway rather than a small
oval (R2_VIEW_W x R2_VIEW_H = 300x430 door-local, aspect 0.70), so the old tall
280x680 crop was being magnified ~1.9x to cover it and went to mush. This crop is
wide to match, and is left at source resolution so the door DOWNSCALES it. The
right edge is chosen to clear Curiosity herself — she stands at ~x1300-1425,
y865-965 in this frame and a sliver of her cloak in the far realm reads as a bug.

Run:  python tools/bake_gateway_view.py <dir containing r2view_2200.png>
Out:  assets/realms/realm1_door/r2_gateway_view.png
"""
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "realms", "realm1_door", "r2_gateway_view.png")

CROP = (1440, 160, 1920, 848)     # left, top, right, bottom -> 480x688, aspect 0.698
SIZE = (480, 688)                 # source resolution: the door draws it at 300x430
BRIGHT = 1.55                     # seen through an arch in a dark cave, it lifts
SATURATE = 1.22


def main():
	folder = sys.argv[1] if len(sys.argv) > 1 else "."
	src = Image.open(os.path.join(folder, "r2view_2200.png")).convert("RGB")
	out = src.crop(CROP).resize(SIZE)
	out = ImageEnhance.Brightness(out).enhance(BRIGHT)
	out = ImageEnhance.Color(out).enhance(SATURATE)
	out.save(OUT)
	print("wrote", os.path.relpath(OUT, ROOT), out.size)


if __name__ == "__main__":
	main()
