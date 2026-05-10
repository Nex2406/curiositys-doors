"""Find Curiosity's painted eye-socket centroids by cluster detection.

Strategy: in the head region of idle_01.png, locate every fully-transparent
pixel that has at least one *opaque* neighbour within radius 3. Those are
"holes inside the figure" — eye sockets, not the empty space surrounding
the character. Flood-fill into clusters; the largest two clusters are the
left and right eye holes.

Outputs a debug overlay (assets/_debug/eye_detection.png) with cyan dots
on every detected hole pixel and red crosshairs on the two cluster
centroids, so the picks can be verified by eye.
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "characters", "hero", "frames", "idle_01.png")
OUT = os.path.join(ROOT, "assets", "_debug", "eye_detection.png")

HEAD_REGION = (20, 0, 60, 40)  # (x0, y0, x1, y1) — covers the hooded head
NEIGHBOUR_RADIUS = 3
OPAQUE_THRESHOLD = 32           # alpha values above this count as opaque


def has_opaque_neighbour(img: Image.Image, x: int, y: int) -> bool:
    w, h = img.size
    for dy in range(-NEIGHBOUR_RADIUS, NEIGHBOUR_RADIUS + 1):
        for dx in range(-NEIGHBOUR_RADIUS, NEIGHBOUR_RADIUS + 1):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                if img.getpixel((nx, ny))[3] > OPAQUE_THRESHOLD:
                    return True
    return False


def flood_fill(start: tuple[int, int], pixels: set[tuple[int, int]]) -> list[tuple[int, int]]:
    cluster: list[tuple[int, int]] = []
    stack: list[tuple[int, int]] = [start]
    while stack:
        p = stack.pop()
        if p not in pixels:
            continue
        pixels.discard(p)
        cluster.append(p)
        x, y = p
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return cluster


def main() -> None:
    img = Image.open(SRC).convert("RGBA")

    holes: set[tuple[int, int]] = set()
    x0, y0, x1, y1 = HEAD_REGION
    for y in range(y0, y1):
        for x in range(x0, x1):
            if img.getpixel((x, y))[3] == 0 and has_opaque_neighbour(img, x, y):
                holes.add((x, y))

    clusters: list[list[tuple[int, int]]] = []
    remaining = set(holes)
    while remaining:
        seed = next(iter(remaining))
        c = flood_fill(seed, remaining)
        if c:
            clusters.append(c)
    clusters.sort(key=len, reverse=True)

    print(f"Found {len(clusters)} interior-hole clusters in head region")
    for i, c in enumerate(clusters[:6]):
        cx = sum(p[0] for p in c) / len(c)
        cy = sum(p[1] for p in c) / len(c)
        minx = min(p[0] for p in c)
        miny = min(p[1] for p in c)
        maxx = max(p[0] for p in c)
        maxy = max(p[1] for p in c)
        print(
            f"  cluster {i}: size={len(c):3d}  "
            f"centroid=({cx:5.2f}, {cy:5.2f})  "
            f"bbox=({minx},{miny})-({maxx},{maxy})  "
            f"size={maxx - minx + 1}x{maxy - miny + 1}px"
        )

    # Build the debug overlay
    overlay = img.crop(HEAD_REGION).resize(
        ((x1 - x0) * 16, (y1 - y0) * 16), Image.NEAREST
    )
    draw = ImageDraw.Draw(overlay)
    # All hole pixels: cyan
    for (px, py) in holes:
        sx, sy = (px - x0) * 16, (py - y0) * 16
        draw.rectangle([sx, sy, sx + 15, sy + 15], fill=(0, 200, 255, 120))
    # Top two clusters: red centroid crosshair
    for c in clusters[:2]:
        cx = sum(p[0] for p in c) / len(c)
        cy = sum(p[1] for p in c) / len(c)
        sx = (cx - x0) * 16 + 8
        sy = (cy - y0) * 16 + 8
        draw.line([(sx - 24, sy), (sx + 24, sy)], fill=(255, 40, 40, 255), width=2)
        draw.line([(sx, sy - 24), (sx, sy + 24)], fill=(255, 40, 40, 255), width=2)
        draw.text((sx + 6, sy + 6), f"({cx:.1f},{cy:.1f})", fill=(255, 220, 80, 255))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    overlay.save(OUT)
    print(f"\nwrote debug overlay -> {OUT}")


if __name__ == "__main__":
    main()
