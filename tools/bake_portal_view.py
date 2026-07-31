"""Bake the portal's glimpse of Realm 2 from a real capture of the Trial scene.

The door's inner arch shows a WINDOW into the next realm, and the honest way to
do that is to photograph the realm rather than mock one up. Capture:

    R2_SHOT_X=1500 R2_SHOT=r2view.png godot --path . res://scenes/realms/Realm2LiftTest.tscn

Then this crops a portrait slice of the forest — clear of the eye HUD and the
debug banner — and writes it as the texture the arch overlay samples.

Run:  python tools/bake_portal_view.py <dir containing r2view.png>
Out:  assets/realms/realm1_door/r2_portal_view.png
"""
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "realms", "realm1_door", "r2_portal_view.png")


def main():
	folder = sys.argv[1] if len(sys.argv) > 1 else "."
	src = Image.open(os.path.join(folder, "r2view.png")).convert("RGB")
	w, h = src.size
	# a tall slice from the middle-right: dense canopy, fireflies, no HUD
	box = (int(w * 0.46), int(h * 0.06), int(w * 0.46) + 520, h - int(h * 0.02))
	crop = src.crop(box)
	crop = crop.resize((420, int(crop.height * 420 / crop.width)))
	# lifted a little: seen through an arch in a dark cave it needs to read
	crop = ImageEnhance.Brightness(crop).enhance(1.35)
	crop = ImageEnhance.Color(crop).enhance(1.15)
	crop.save(OUT)
	print("wrote", os.path.relpath(OUT, ROOT), crop.size)


if __name__ == "__main__":
	main()
