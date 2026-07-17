"""One-off importer for the Fungal tileset (Realm 3 — Advika's pack).

Two jobs, one pass, per the 2026-07-14 spec:
1. DOWNSCALE: every sheet lands at <= 2048 px on its longest side (LANCZOS,
   alpha preserved). This is a web build — the 4096 originals never ship.
2. SLICE: alpha connected-components on the downscaled sheet (same approach
   as tools/slice_mossy_pack.gd: coarse cell grid, BFS labeling, near-rect
   merging), each piece saved as its own PNG. Fragments under 24 px on both
   sides are discarded. Final names carry NO underscores (fungalground1,
   stalagmite3, mushroomglow2, ...) per the project's asset naming ask.

Usage:
    python tools/prep_fungal_pack.py "<src dir with 'Assets Fungal'>" \
        assets/realms/realm3_fungal

Prints a manifest of every written asset (goes into the PR description).
"""

import sys
from pathlib import Path

from PIL import Image

MAX_SIDE = 2048
CELL = 4            # mask downsample factor (finer than the mossy pack's 8 —
                    # this pack's pieces sit much closer together)
ALPHA_MIN = 40      # a pixel counts as "occupied" above this alpha
CELL_OCCUPANCY = 22 # BOX-averaged alpha a cell needs — kills the faint
                    # bridges that glued whole sheets into one mega-piece
MERGE_GAP = 2       # cells — merge rects closer than this (split elements)
PAD = 2             # cells of padding around each crop (applied last)
MIN_PIECE = 24      # px — discard fragments smaller than this on BOTH sides

# per-sheet occupancy overrides (soft shadows bridging gaps)
OCCUPANCY_OVERRIDE = {}

# The TileSet sheet is 89% OPAQUE: its inter-piece channels and platform
# interiors are solid near-black, so alpha-CC saw one giant component. Key
# near-black out first — the platform interiors then read as the level's
# own dark backdrop in-game, which is exactly the reference look, and the
# rock rims slice cleanly. Value = max RGB below which an opaque pixel is
# treated as background.
KEY_OUT_BLACK = {
    "Fungal - TileSet.png": 14,
}

# sheet file -> asset name prefix (descriptive, no underscores)
SHEETS = {
    "Fungal - TileSet.png": "fungalground",
    "Fungal - StoneSprites.png": "fungalstone",
    "Fungal - StoneSpritesB.png": "fungalstoneb",
    "Fungal - StalagmitesA.png": "stalagmite",
    "Fungal - StalagmitesB.png": "stalagmiteb",
    "Fungal - HillsFungal.png": "fungalhill",
    "Fungal - DecorationsA.png": "fungalfrond",
    "Fungal - DecorationsB.png": "mushroomglow",
    "Fungal - DecorationsC.png": "mushroomcap",
}


def downscale(img: Image.Image) -> Image.Image:
    longest = max(img.size)
    if longest <= MAX_SIDE:
        return img
    k = MAX_SIDE / longest
    return img.resize((round(img.width * k), round(img.height * k)),
                      Image.Resampling.LANCZOS)


def cell_mask(img: Image.Image, occupancy: int) -> list[list[bool]]:
    """Coarse occupancy grid of the alpha channel (CELL x CELL blocks)."""
    a = img.getchannel("A")
    w, h = img.size
    gw, gh = (w + CELL - 1) // CELL, (h + CELL - 1) // CELL
    # downsample alpha with a max-ish filter: resize to grid using NEAREST is
    # lossy; use reduce() which averages, then threshold low — a cell counts
    # if even a fraction of it is occupied
    grid = a.resize((gw, gh), Image.Resampling.BOX)
    px = grid.load()
    return [[px[x, y] > occupancy for x in range(gw)] for y in range(gh)]


def label_components(mask: list[list[bool]]) -> list[tuple[int, int, int, int]]:
    """BFS over the cell grid -> list of (x0, y0, x1, y1) cell rects."""
    gh, gw = len(mask), len(mask[0])
    seen = [[False] * gw for _ in range(gh)]
    rects = []
    for sy in range(gh):
        for sx in range(gw):
            if not mask[sy][sx] or seen[sy][sx]:
                continue
            stack = [(sx, sy)]
            seen[sy][sx] = True
            x0 = x1 = sx
            y0 = y1 = sy
            while stack:
                x, y = stack.pop()
                x0, x1 = min(x0, x), max(x1, x)
                y0, y1 = min(y0, y), max(y1, y)
                for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1),
                               (x-1, y-1), (x+1, y-1), (x-1, y+1), (x+1, y+1)):
                    if 0 <= nx < gw and 0 <= ny < gh \
                            and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            rects.append((x0, y0, x1, y1))
    return rects


def merge_rects(rects: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    """Merge rects that sit within MERGE_GAP cells of each other."""
    rects = list(rects)
    merged = True
    while merged:
        merged = False
        out = []
        while rects:
            r = rects.pop()
            for i, o in enumerate(out):
                if (r[0] - MERGE_GAP <= o[2] and o[0] - MERGE_GAP <= r[2]
                        and r[1] - MERGE_GAP <= o[3] and o[1] - MERGE_GAP <= r[3]):
                    out[i] = (min(r[0], o[0]), min(r[1], o[1]),
                              max(r[2], o[2]), max(r[3], o[3]))
                    merged = True
                    break
            else:
                out.append(r)
        rects = out if merged else []
        if not merged:
            return out
    return out


def main() -> None:
    src = Path(sys.argv[1]) / "Assets Fungal"
    dst = Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    manifest = []
    for sheet_name, prefix in SHEETS.items():
        img = Image.open(src / sheet_name).convert("RGBA")
        img = downscale(img)
        if sheet_name in KEY_OUT_BLACK:
            thresh = KEY_OUT_BLACK[sheet_name]
            px = img.load()
            for y in range(img.height):
                for x in range(img.width):
                    r, g, b, a = px[x, y]
                    if a > 0 and max(r, g, b) < thresh:
                        px[x, y] = (r, g, b, 0)
        occupancy = OCCUPANCY_OVERRIDE.get(sheet_name, CELL_OCCUPANCY)
        rects = merge_rects(label_components(cell_mask(img, occupancy)))
        n = 0
        for (cx0, cy0, cx1, cy1) in sorted(rects, key=lambda r: (r[1], r[0])):
            x0 = max(0, (cx0 - PAD) * CELL)
            y0 = max(0, (cy0 - PAD) * CELL)
            x1 = min(img.width, (cx1 + 1 + PAD) * CELL)
            y1 = min(img.height, (cy1 + 1 + PAD) * CELL)
            piece = img.crop((x0, y0, x1, y1))
            bbox = piece.getbbox()
            if bbox is None:
                continue
            piece = piece.crop(bbox)
            if piece.width < MIN_PIECE and piece.height < MIN_PIECE:
                continue
            n += 1
            path = dst / f"{prefix}{n}.png"
            piece.save(path)
            manifest.append(f"{path.as_posix()}  ({piece.width}x{piece.height})")
        print(f"[fungal] {sheet_name}: {n} pieces -> {prefix}1..{prefix}{n}")
    print(f"[fungal] MANIFEST ({len(manifest)} assets):")
    for line in manifest:
        print("  " + line)


if __name__ == "__main__":
    main()
