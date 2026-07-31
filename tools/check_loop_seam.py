"""Does an animation loop cleanly, or does it pop at the wrap?

Compares every consecutive pair of frames and then the wrap pair (last -> first).
If the wrap difference is in line with the others the loop is seamless; if it is
much larger, that jump is what the eye reads as a pop.

Run:  python tools/check_loop_seam.py <dir> <prefix>
e.g.  python tools/check_loop_seam.py assets/ui/hub_bg gameui
"""
import glob
import os
import sys

import numpy as np
from PIL import Image


def frames(folder, prefix):
	fs = glob.glob(os.path.join(folder, prefix + "*.png"))
	fs = [f for f in fs if not f.endswith(".import")]
	return sorted(fs, key=lambda p: int("".join(c for c in os.path.basename(p)
			if c.isdigit())))


def main():
	folder = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/hub_bg"
	prefix = sys.argv[2] if len(sys.argv) > 2 else "gameui"
	fs = frames(folder, prefix)
	if len(fs) < 2:
		print("need at least two frames")
		return
	imgs = [np.asarray(Image.open(f).convert("RGB"), dtype=np.float32) for f in fs]
	diffs = []
	for i in range(len(imgs)):
		j = (i + 1) % len(imgs)
		d = float(np.mean(np.abs(imgs[i] - imgs[j])))
		diffs.append(d)
		tag = "  <- WRAP" if j == 0 else ""
		print("%2d -> %-2d  mean abs diff %6.2f%s" % (i + 1, j + 1, d, tag))
	body = diffs[:-1]
	wrap = diffs[-1]
	avg = sum(body) / len(body)
	worst = max(body)
	print("\nconsecutive: avg %.2f, worst %.2f" % (avg, worst))
	print("wrap:        %.2f  (%.2fx the average, %.2fx the worst)"
			% (wrap, wrap / avg if avg else 0, wrap / worst if worst else 0))
	if wrap <= worst * 1.15:
		print("VERDICT: seamless — the wrap is no bigger a step than the loop's own.")
	elif wrap <= worst * 1.6:
		print("VERDICT: slight pop — visible on a still A/B, probably not in motion.")
	else:
		print("VERDICT: POPS — the wrap is a much bigger jump than any real step.")


if __name__ == "__main__":
	main()
