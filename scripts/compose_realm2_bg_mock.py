"""Realm 2 background mock v7 — the INTIMATE cut.

v1's mood (dark, close, enclosed canopy, one warm pocket of light) with v6's
craft (clean alpha-extracted sprites, post-bloom amber fireflies, no artifacts).
Dense foliage presses in; the only brightness is the lantern-gold pocket where
Curiosity would stand on the chunk, plus fireflies.
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

P = Path(r"C:\Users\advik\AppData\Local\Temp\claude\C--Users-advik-Curiosity-s-Doors\179b0dee-263b-4524-9844-a926307358df\scratchpad\realm2_assets\_purple")
OUT = P.parent / "realm2_bg_mock_intimate.png"
W, H = 1920, 1080
DS = 4

# dark, close palette — v1 mood
SKY_TOP = (11, 8, 24)
SKY_MID = (26, 18, 50)
SKY_BOT = (44, 32, 74)
FAR_TINT = (64, 52, 104)   # far spires: dim violet, NOT luminous
MID_TINT = (38, 28, 68)
GOLD = (255, 196, 100)


def components(sheet, min_area_ds=400):
    img = Image.open(P / sheet).convert("RGBA")
    a = np.asarray(img)[..., 3]
    small = a[::DS, ::DS] > 16
    h, w = small.shape
    seen = np.zeros_like(small, dtype=bool)
    out = []
    for sy in range(h):
        for sx in range(w):
            if small[sy, sx] and not seen[sy, sx]:
                q = deque([(sy, sx)])
                seen[sy, sx] = True
                x0 = x1 = sx
                y0 = y1 = sy
                area = 0
                while q:
                    cy, cx = q.popleft()
                    area += 1
                    x0, x1 = min(x0, cx), max(x1, cx)
                    y0, y1 = min(y0, cy), max(y1, cy)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and small[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                q.append((ny, nx))
                if area >= min_area_ds:
                    pad = DS * 2
                    out.append(((max(0, x0 * DS - pad), max(0, y0 * DS - pad),
                                 min(img.width, (x1 + 1) * DS + pad),
                                 min(img.height, (y1 + 1) * DS + pad)), area))
    out.sort(key=lambda t: -t[1])
    src = Image.open(P / sheet).convert("RGBA")
    return [(src.crop(b), b) for b, _ in out]


def scale_h(img, th):
    return img.resize((max(1, int(img.width * th / img.height)), th), Image.LANCZOS)


def tint_to(img, color, amount, mul=1.0):
    arr = np.asarray(img, dtype=np.float32)
    rgb, a = arr[..., :3] * mul, arr[..., 3:]
    rgb = rgb * (1 - amount) + np.array(color, dtype=np.float32) * amount
    return Image.fromarray(np.concatenate([rgb, a], -1).clip(0, 255).astype(np.uint8), "RGBA")


# ---- sprite pools ----
deco = components("Mossy - BackgroundDecoration.png")
spires = sorted(deco, key=lambda t: -(t[1][3] - t[1][1]))
pillar1, pillar2 = spires[0][0], spires[1][0]

hills = components("Mossy - MossyHills.png")
hill = max((im for im, _ in hills), key=lambda i: i.width)
chunk_img = next((im for im, b in hills
                  if (b[2] - b[0]) / max(1, b[3] - b[1]) < 2.6 and (b[2] - b[0]) > 1200),
                 hills[0][0])

hang = components("Mossy - Hanging Plants.png")
lower = [im for im, b in hang if (b[1] + b[3]) / 2 > 1400 and im.width > 300]
cascade = lower[0] if lower else hang[0][0]
vines = [im for im, b in hang if (b[1] + b[3]) / 2 <= 1400 and im.height > 700]
vine = vines[0] if vines else hang[-1][0]

plats = components("Mossy - FloatingPlatforms.png")
platform = max((im for im, _ in plats), key=lambda i: i.width)

# ---- dark vertical gradient sky ----
sky = np.zeros((H, W, 3), dtype=np.float32)
ys = np.linspace(0, 1, H)[:, None]
for c in range(3):
    t, m, b = SKY_TOP[c], SKY_MID[c], SKY_BOT[c]
    sky[..., c] = np.where(ys < 0.5, t + (m - t) * (ys / 0.5),
                           m + (b - m) * ((ys - 0.5) / 0.5))
canvas = Image.fromarray(sky.astype(np.uint8), "RGB").convert("RGBA")

rng = np.random.default_rng(11)

# ---- small moon off to the side, glimpsed through the canopy ----
MX, MY, MR = int(W * 0.16), int(H * 0.19), 58
moon = Image.new("RGBA", (W, H), (0, 0, 0, 0))
mn = ImageDraw.Draw(moon)
for k, al in [(3.2, 16), (2.1, 30), (1.45, 52)]:
    mn.ellipse([MX - MR * k, MY - MR * k, MX + MR * k, MY + MR * k],
               fill=(196, 182, 235, al))
mn.ellipse([MX - MR, MY - MR, MX + MR, MY + MR], fill=(226, 216, 250, 255))
canvas.alpha_composite(moon.filter(ImageFilter.GaussianBlur(4)))

# ---- far band: dim spires, tightly packed (dense canopy, no open sky) ----
for x, hgt, flip in [(-80, 700, 0), (170, 540, 1), (430, 760, 0), (700, 500, 1),
                     (940, 660, 0), (1200, 560, 1), (1440, 720, 0), (1700, 600, 1)]:
    p = pillar1 if hgt > 620 else pillar2
    if flip:
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.alpha_composite(tint_to(scale_h(p, hgt), FAR_TINT, 0.6), (x, H - hgt))

# ---- mid band: darker, closer ----
for x, hgt, flip in [(60, 640, 1), (380, 480, 0), (760, 560, 1), (1080, 700, 0),
                     (1420, 520, 1), (1680, 680, 0)]:
    p = pillar1 if hgt > 600 else pillar2
    if flip:
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.alpha_composite(tint_to(scale_h(p, hgt), MID_TINT, 0.42), (x, H - hgt))

# ---- drifting spores, sparse and dim ----
motes = Image.new("RGBA", (W, H), (0, 0, 0, 0))
md = ImageDraw.Draw(motes)
for _ in range(18):
    mx, my = int(rng.integers(40, W - 40)), int(rng.integers(80, H - 140))
    ln = int(rng.integers(12, 26))
    md.line([mx, my, mx + ln, my + ln // 3], fill=(150, 132, 205, 110), width=2)
canvas.alpha_composite(motes.filter(ImageFilter.GaussianBlur(2)))

# ---- THE CHUNK: big, central, close — the heart of the frame ----
plat = tint_to(scale_h(platform, 300), (30, 22, 58), 0.1, 0.85)
px, py = (W - plat.width) // 2, 560
for fx, hh in [(0.2, 380), (0.48, 470), (0.7, 330)]:
    c = tint_to(scale_h(cascade, hh), (20, 14, 42), 0.12, 0.6)
    canvas.alpha_composite(c, (px + int(plat.width * fx), py + plat.height - 70))

# warm lantern pocket ON the chunk — the one light in the dark (pre-placement
# so the platform fringe partly cups it)
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gx, gy = W // 2, py + 40
for r, al in [(210, 22), (130, 40), (66, 78), (30, 130)]:
    gd.ellipse([gx - r, gy - r * 0.78, gx + r, gy + r * 0.78], fill=GOLD + (al,))
canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(22)))
canvas.alpha_composite(plat, (px, py))

# ---- near band: near-black spires hugging the edges ----
canvas.alpha_composite(tint_to(scale_h(pillar1, 880), (16, 11, 34), 0.2, 0.4), (-120, H - 880))
canvas.alpha_composite(
    tint_to(scale_h(pillar2.transpose(Image.FLIP_LEFT_RIGHT), 760), (16, 11, 34), 0.22, 0.38),
    (1660, H - 760))

# ---- ground masses: close, dark, pressing up ----
g1 = tint_to(scale_h(hill, 430), (13, 9, 30), 0.12, 0.32)
canvas.alpha_composite(g1, (-220, H - 300))
g2 = tint_to(scale_h(hill.transpose(Image.FLIP_LEFT_RIGHT), 390), (13, 9, 30), 0.12, 0.3)
canvas.alpha_composite(g2, (1050, H - 260))
g3 = tint_to(scale_h(hill, 300), (11, 7, 26), 0.1, 0.26)
canvas.alpha_composite(g3, (420, H - 190))

# ---- foreground canopy: heavy, pressing in from above ----
canvas.alpha_composite(tint_to(scale_h(vine, 700), (8, 5, 20), 0.15, 0.24), (30, -30))
canvas.alpha_composite(tint_to(scale_h(cascade, 560), (8, 5, 20), 0.15, 0.24), (400, -40))
canvas.alpha_composite(tint_to(scale_h(cascade.transpose(Image.FLIP_LEFT_RIGHT), 480),
                               (8, 5, 20), 0.15, 0.22), (900, -30))
fgR = tint_to(scale_h(vine.transpose(Image.FLIP_LEFT_RIGHT), 740), (8, 5, 20), 0.15, 0.22)
canvas.alpha_composite(fgR, (W - fgR.width - 20, -25))
fgM = tint_to(scale_h(vine, 460), (8, 5, 20), 0.15, 0.2)
canvas.alpha_composite(fgM, (1280, -20))

# ---- soft bloom on the warm pocket ----
arr = np.asarray(canvas.convert("RGB"), dtype=np.float32)
lum = arr.mean(-1, keepdims=True)
bright = np.where(lum > 110, arr, 0)
bloom = Image.fromarray(bright.astype(np.uint8)).filter(ImageFilter.GaussianBlur(20))
arr = np.clip(arr + np.asarray(bloom, dtype=np.float32) * 0.4, 0, 255)
canvas = Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")

# ---- strong vignette: the dark hugs you ----
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).ellipse([-W * 0.18, -H * 0.24, W * 1.18, H * 1.24], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(150))
canvas = Image.composite(canvas, Image.new("RGBA", (W, H), (5, 3, 14, 255)), vig)

# ---- amber fireflies LAST, clustered toward the warm pocket ----
ff = Image.new("RGBA", (W, H), (0, 0, 0, 0))
fd2 = ImageDraw.Draw(ff)
for _ in range(11):
    ang = rng.uniform(0, 6.283)
    rad = abs(rng.normal(0, 330)) + 60
    fx = int(np.clip(W / 2 + np.cos(ang) * rad * 1.5, 90, W - 90))
    fy = int(np.clip(py + 30 + np.sin(ang) * rad, 140, H - 90))
    fd2.ellipse([fx - 13, fy - 13, fx + 13, fy + 13], fill=(255, 148, 40, 66))
    fd2.ellipse([fx - 6, fy - 6, fx + 6, fy + 6], fill=(255, 176, 56, 165))
    fd2.ellipse([fx - 2, fy - 2, fx + 2, fy + 2], fill=(255, 216, 130, 255))
canvas.alpha_composite(ff.filter(ImageFilter.GaussianBlur(2)))

canvas.convert("RGB").save(OUT, quality=95)
print("intimate v7 ->", OUT)
