"""Measure the TRUE painted top rim of each fused Realm-1 platform texture.

Why: `PLAT_META[pname][0]` in `scripts/Realm1PlatformTest.gd` is the single
source of truth for where a platform's standable surface is — the collider, the
jade, and the rooted plants all hang off it. Hand-typed values drifted per
platform (up to 16px), so Curiosity floated on some platforms and sank into
others. This re-derives them from the art itself.

Method: per column, the first row whose alpha is solid rock (>= THRESH, not the
feathered painted edge). The rim is the widest FLAT run of that profile; the
standable span is where that flat top actually exists (thin lower outcrops and
the middle rubble mound are excluded — the mound is decor, not a step).

Run:  python tools/measure_plat_rims.py
Then paste the printed table into PLAT_META (rim, x0, x1 columns).
"""
import os
import statistics
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOFT = os.path.join(ROOT, "assets", "realms", "realm1_soft")
THRESH = 190      # alpha considered solid rock
FLAT_TOL = 3      # px wobble still counted as the same flat run
MIN_RUN = 20      # px — narrower runs are texture noise, not a surface

# pname -> the origin passed to _fused() (texture pixel that maps to local 0,0)
ORIGINS = {
	"small_a": (180, 150),
	"small_b": (170, 150),
	"medium_a": (250, 170),
	"medium_b": (240, 190),
	"large_b": (250, 220),
}


def top_profile(path, origin):
	"""{local_x: local_y} — the first solid row of every column."""
	img = Image.open(path).convert("RGBA")
	w, h = img.size
	px = img.load()
	ox, oy = origin
	tops = {}
	for tx in range(w):
		for ty in range(h):
			if px[tx, ty][3] >= THRESH:
				tops[tx - ox] = ty - oy
				break
	return tops


def flat_runs(tops):
	xs = sorted(tops)
	runs, cur = [], [xs[0], xs[0], [tops[xs[0]]]]
	for x in xs[1:]:
		t = tops[x]
		if x == cur[1] + 1 and abs(t - statistics.median(cur[2])) <= FLAT_TOL:
			cur[1], _ = x, cur[2].append(t)
		else:
			runs.append(cur)
			cur = [x, x, [t]]
	runs.append(cur)
	return [r for r in runs if r[1] - r[0] >= MIN_RUN]


def main():
	print('   "pname": [rim, x0, x1, ...]')
	for pname, origin in ORIGINS.items():
		tops = top_profile(os.path.join(SOFT, "plat_%s.png" % pname), origin)
		runs = flat_runs(tops)
		# The slab is the WIDEST surface, not the highest one: the highest run is
		# usually the little rubble mound in the middle (decor). Group runs whose
		# levels are within 12px (a slab painted with a slight slope reads as two
		# runs), then take the group with the most total width.
		best, slab = None, None
		for r in runs:
			lvl = statistics.median(r[2])
			grp = [q for q in runs if abs(statistics.median(q[2]) - lvl) <= 12]
			width = sum(q[1] - q[0] for q in grp)
			if best is None or width > best:
				best, slab = width, grp
		wsum = sum(r[1] - r[0] for r in slab)
		rim = sum(statistics.median(r[2]) * (r[1] - r[0]) for r in slab) / wsum
		x0 = min(r[0] for r in slab)
		x1 = max(r[1] for r in slab)
		print('   "%s": [%.0f, %.0f, %.0f, ...]' % (pname, round(rim), x0, x1))
		for r in runs:
			mark = "  <- slab" if r in slab else ""
			print("        run x %+5d..%+5d (%3dpx) top %+.0f%s"
					% (r[0], r[1], r[1] - r[0], statistics.median(r[2]), mark))


if __name__ == "__main__":
	main()
