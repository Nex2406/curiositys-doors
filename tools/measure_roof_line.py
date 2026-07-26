"""Where can a ceiling golem hang in Realm 1, and how deep?

The cave roof is not level — its painted edge rides between about -334 and -420
across the walk — so burying the clingers by one hand-picked number leaves some
dangling in open air and swallows others whole. This reads the roof's real
silhouette off gallery renders and reports the FLAT stretches (edge varying less
than ~26px across a golem's body width), which are the only spots where a buried
body reads evenly.

Placement rule, calibrated against the approved clinger at x=830:
    node y = (roof edge over +-34px, median) - 1

Producing the renders (they land in your scratch dir; PLAT_NOPLAY keeps the
camera manual and skips the actors):

    for x in 400 2200 4000 5800 7600 9200:
        PLAT_NOPLAY=1 PLAT_CAM_X=$x PLAT_CAM_Y=-120 PLAT_SHOT=roof_$x.png \
            godot --path . res://scenes/realms/realm1/Realm1PlatformTest.tscn

Then:  python tools/measure_roof_line.py <dir with roof_*.png>
Paste the chosen rows into CEIL_GOLEMS in scripts/Realm1PlatformTest.gd.
"""
import os
import statistics
import sys
from PIL import Image

ZOOM = 1.05          # the level camera's zoom
CAM_Y = -120.0       # the y the renders were shot at
CAMS = [400, 2200, 4000, 5800, 7600, 9200]
LIT = 30             # luminance above this is backdrop, below is roof rock
HALF = 34            # half a golem's body width
CALIBRATION = (830, -381)   # the spot Advika approved, and its node y


def roof_profile(folder):
	"""{world x: world y} of the roof's lowest painted edge."""
	prof = {}
	for cx in CAMS:
		path = os.path.join(folder, "roof_%d.png" % cx)
		if not os.path.exists(path):
			continue
		im = Image.open(path).convert("RGB")
		w, h = im.size
		px = im.load()
		for sx in range(w):
			r, g, b = px[sx, 2]
			if 0.3 * r + 0.6 * g + 0.1 * b > LIT:
				continue           # column doesn't start inside the roof
			for sy in range(h):
				r, g, b = px[sx, sy]
				if 0.3 * r + 0.6 * g + 0.1 * b > LIT:
					prof[round(cx + (sx - w / 2) / ZOOM)] = CAM_Y + (sy - h / 2) / ZOOM
					break
	return prof


def main():
	folder = sys.argv[1] if len(sys.argv) > 1 else "."
	prof = roof_profile(folder)
	if not prof:
		print("no roof_*.png renders found in %s" % folder)
		return
	xs = sorted(prof)

	def band(x):
		return [prof[k] for k in xs if abs(k - x) <= HALF]

	cx, cy = CALIBRATION
	if band(cx):
		med = statistics.median(band(cx))
		print("calibration x=%d: roof %+.0f, approved node %+d -> offset %+.0f"
				% (cx, med, cy, cy - med))

	print("\nflat stretches (spread <= 26px), one per neighbourhood:")
	last = -9999
	for x in range(200, 9400, 25):
		b = band(x)
		if len(b) < 40:
			continue
		spread = max(b) - min(b)
		if spread > 26 or x - last < 220:
			continue
		last = x
		print("  Vector2(%d.0, %d.0),   # roof %+.0f, spread %.0f"
				% (x, round(statistics.median(b) - 1), statistics.median(b), spread))


if __name__ == "__main__":
	main()
