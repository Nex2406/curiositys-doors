"""Measure the boulder golem's REAL ground-contact row per animation set.

Why: `OFFSETS` in `scripts/BoulderGolem.gd` assumed every set has a 4px margin
below the body. They don't (idle has 10px, move/spawn ~13), so the golem hovered
a few pixels over the ground. This reads the deepest ink row across EVERY frame
of a set — the row that should rest on the surface.

Sprite is centered, so texture row r sits at local y = (r + 0.5 - h/2) + offset.y.
The body's collider bottom is local +2 (circle r46 at y -44), so the contact row
belongs at +2:  offset.y = 2 - (contact + 0.5 - h/2).

Run:  python tools/measure_golem_contact.py
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "enemies", "golem", "boulder")
COLLIDER_BOTTOM = 2.0    # local y of the body collider's bottom edge
THRESH = 24              # any visible ink counts as body

# anim -> (file stem, first frame, last frame) — mirrors ANIMS in BoulderGolem.gd.
# `ceilingspawn` is deliberately absent: it is a CLING pose that hangs from the
# roof, aligned by its body top, not by a ground contact.
SETS = {
	"spawn": ("golemspawn", 1, 12),
	"idle": ("golemidle", 1, 12),
	"move": ("golemmove", 1, 12),
	"windup": ("golemrollattack", 1, 6),
	"roll": ("golemrollattack", 7, 12),
	"defeat": ("golemdefeat", 1, 5),
}


def ink_bottom(path):
	img = Image.open(path).convert("RGBA")
	w, h = img.size
	px = img.load()
	low = None
	for y in range(h):
		for x in range(w):
			if px[x, y][3] >= THRESH:
				low = y
				break
	return w, h, low


def main():
	for anim, (stem, a, b) in SETS.items():
		lows, size = [], None
		for i in range(a, b + 1):
			p = os.path.join(DIR, "%s%d.png" % (stem, i))
			if os.path.exists(p):
				w, h, low = ink_bottom(p)
				size = (w, h)
				lows.append(low)
		w, h = size
		contact = max(lows)
		off_y = COLLIDER_BOTTOM - (contact + 0.5 - h / 2.0)
		print('   "%s": Vector2(x, %.0f),   # cell %dx%d, contact row %d'
				% (anim, round(off_y), w, h, contact))


if __name__ == "__main__":
	main()
