"""Bake the glimpse of Realm 2 seen through the Realm 1 gateway.

The gateway at the end of Realm 1 is built out of Realm 2's own assets, and the
passage between its posts shows the far side. The honest way to make that view is
to PHOTOGRAPH Realm 2 rather than mock one up, so:

    R2_SHOT_X=2200 R2_SHOT=r2view_2200.png godot --path . res://scenes/realms/Realm2LiftTest.tscn

...then this crops a tall slice whose aspect already matches the passage (350x850
-> 0.41, the passage is ~156x370 -> 0.42, so nothing is stretched) from the part
of that frame with the most readable content: a lit mushroom cap, moss banks,
fireflies and depth behind them. Both earlier bakes failed for the same reason —
they cropped dark forest floor, which through a small opening is just a violet
smudge (r2_forest_peek.png was also a 3.3x downscale of a WIDE frame).

Run:  python tools/bake_gateway_view.py <dir containing r2view_2200.png>
Out:  assets/realms/realm1_door/r2_gateway_view.png
"""
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "realms", "realm1_door", "r2_gateway_view.png")

CROP = (1420, 140, 1770, 990)     # left, top, right, bottom -> 350x850
SIZE = (280, 680)                 # same aspect, sized for the passage
BRIGHT = 1.45                     # seen through a small arch in a dark cave, it lifts
SATURATE = 1.18


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
