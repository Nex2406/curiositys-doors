"""Crop the head region of Curiosity's idle_01.png at 8x zoom and save it
so we can read the eye-socket pixel coordinates by eye.

The cloak pattern has many small painted eyes; only the head's hood-cavity
is what we want to fill with glowing orbs.
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "characters", "hero", "frames", "idle_01.png")
OUT = os.path.join(ROOT, "scripts", "_eye_zoom.png")

img = Image.open(SRC).convert("RGBA")
w, h = img.size
print(f"source: {w}x{h}")

# Crop tightly around the head (visual hood area is roughly x=25..55, y=0..35)
head = img.crop((20, 0, 60, 40))
hw, hh = head.size
zoomed = head.resize((hw * 18, hh * 18), Image.NEAREST)

# overlay grid; labels show ABSOLUTE source coords (cropped from x=20, y=0)
CROP_X0, CROP_Y0, ZOOM = 20, 0, 18
draw = ImageDraw.Draw(zoomed)
for x in range(0, hw + 1):
    draw.line([(x * ZOOM, 0), (x * ZOOM, hh * ZOOM)], fill=(255, 0, 0, 60), width=1)
for y in range(0, hh + 1):
    draw.line([(0, y * ZOOM), (hw * ZOOM, y * ZOOM)], fill=(255, 0, 0, 60), width=1)
for x in range(0, hw + 1, 2):
    sx = x + CROP_X0
    draw.line([(x * ZOOM, 0), (x * ZOOM, hh * ZOOM)], fill=(255, 200, 0, 180), width=1)
    draw.text((x * ZOOM + 2, 2), str(sx), fill=(255, 255, 0, 255))
for y in range(0, hh + 1, 2):
    sy = y + CROP_Y0
    draw.line([(0, y * ZOOM), (hw * ZOOM, y * ZOOM)], fill=(255, 200, 0, 180), width=1)
    draw.text((2, y * ZOOM + 2), str(sy), fill=(255, 255, 0, 255))

zoomed.save(OUT)
print(f"wrote {OUT} ({hw * 10}x{hh * 10}, {hw}x{hh} source pixels)")
