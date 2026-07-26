"""Bake a debris-free CLING frame for the ceiling golem.

The ceiling-drop sheet's first frame draws the golem plus a scatter of loose
rubble that has already broken away from the roof. That is right for the drop —
but while he is CLINGING, buried in the rock, those specks hang in open air under
him with nothing holding them up (Advika 2026-07-26, and the scene-dressing law:
nothing floats). This keeps only the body — the largest connected blob of ink —
and writes it as its own frame at the SAME canvas size, so the cling pose and the
drop's first frame line up pixel for pixel and the detach doesn't jump.

Run:  python tools/clean_cling_frame.py
Out:  assets/enemies/golem/boulder/golemceilingcling1.png
"""
import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "enemies", "golem", "boulder")
SRC = os.path.join(DIR, "golemceilingspawn1.png")
OUT = os.path.join(DIR, "golemceilingcling1.png")
THRESH = 24        # alpha at or above this counts as ink


def main():
	img = Image.open(SRC).convert("RGBA")
	w, h = img.size
	px = img.load()
	seen = [[False] * h for _ in range(w)]
	best = []
	for sx in range(w):
		for sy in range(h):
			if seen[sx][sy] or px[sx, sy][3] < THRESH:
				continue
			# flood fill this blob (4-connected is enough; the body is solid)
			blob = []
			q = deque([(sx, sy)])
			seen[sx][sy] = True
			while q:
				x, y = q.popleft()
				blob.append((x, y))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny] \
							and px[nx, ny][3] >= THRESH:
						seen[nx][ny] = True
						q.append((nx, ny))
			if len(blob) > len(best):
				best = blob

	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	op = out.load()
	for x, y in best:
		op[x, y] = px[x, y]
	out.save(OUT)
	total = sum(1 for x in range(w) for y in range(h) if px[x, y][3] >= THRESH)
	print("body %d px of %d ink px kept (%d dropped as loose debris)"
			% (len(best), total, total - len(best)))
	print("wrote", OUT)


if __name__ == "__main__":
	main()
