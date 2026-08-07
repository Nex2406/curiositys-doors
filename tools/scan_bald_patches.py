# -*- coding: utf-8 -*-
"""Find bald patches in Realm 3 the way Advika finds them: by looking.

Run:  python tools/scan_bald_patches.py [--clean]

Advika, after circling the fourth patch in a row: "i dont wanna hand point these
patches to u, u should know and remove all of them at once." She is right, and
this is how. It shoots the level at 22 positions, tiles the lower frame, and
reports every tile with essentially no local contrast — because the eye reads
"flat" as "hole" no matter how dark it is.

It has already earned itself twice: it found that the soil shader was sampling
a degenerate `UV` on an untextured Polygon2D and producing a mathematically
constant colour (tiles with std EXACTLY 0), and it took the level from 1267
flat tiles to ~300, of which most are real shadow pockets between moss clumps
rather than holes. Re-run it after any change to the floor.

A patch is a region of the lower frame with almost no local detail — the eye
reads "flat" as "hole" regardless of how dark it is. So: tile the region below
the walk line, measure local contrast in each tile, and report the tiles that
are essentially featureless. Zero is the pass condition.
"""
import os, subprocess, sys, glob
import numpy as np
from PIL import Image

GODOT = r"C:\Users\advik\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64.exe"
PROJ = r"C:\Users\advik\Curiosity's-Doors"
OUT = r"C:\Users\advik\AppData\Local\Temp\claude\C--Users-advik-Curiosity-s-Doors\35e56128-e1f9-4ca7-8d78-c863f244de24\scratchpad\scan"
os.makedirs(OUT, exist_ok=True)

XS = list(range(400, 25400, 1150))          # the whole walk
TILE = 56
Y0, Y1 = 640, 1080                          # below the walk line, to the edge
FLAT = 0.0055                               # std-dev below this = featureless

def shoot(x):
    p = os.path.join(OUT, "s%d.png" % x)
    if os.path.exists(p):
        return p
    env = dict(os.environ, R3_SHOT=p, R3_SHOT_X=str(x))
    subprocess.run([GODOT, "--path", PROJ,
                    "res://scenes/realms/Realm3FungalTest.tscn"],
                   env=env, capture_output=True, timeout=180)
    return p if os.path.exists(p) else None

def scan(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114])
    bad = []
    for ty in range(Y0, min(Y1, lum.shape[0]) - TILE, TILE):
        for tx in range(0, lum.shape[1] - TILE, TILE):
            t = lum[ty:ty + TILE, tx:tx + TILE]
            if t.std() < FLAT:
                bad.append((tx, ty, float(t.std())))
    return bad

if __name__ == "__main__":
    if "--clean" in sys.argv:
        for f in glob.glob(os.path.join(OUT, "*.png")):
            os.remove(f)
    total, worst = 0, []
    for x in XS:
        p = shoot(x)
        if p is None:
            print("x=%-6d SHOT FAILED" % x); continue
        bad = scan(p)
        total += len(bad)
        if bad:
            worst.append((x, len(bad), bad[:3]))
        print("x=%-6d flat tiles: %d" % (x, len(bad)))
    print("\nTOTAL FLAT TILES: %d across %d frames" % (total, len(XS)))
    for x, n, sample in worst[:8]:
        print("  x=%-6d n=%-3d e.g. %s" % (x, n, sample))
