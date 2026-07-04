"""Realm 2 background mock v3 — Maaot-style: backlit luminous core, dense
layered spires, glowing motes, dark foreground frame. Purple palette."""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

P = Path(r"C:\Users\advik\AppData\Local\Temp\claude\C--Users-advik-Curiosity-s-Doors\179b0dee-263b-4524-9844-a926307358df\scratchpad\realm2_assets\_purple")
OUT = P.parent / "realm2_bg_mock.png"
W, H = 1920, 1080
DS = 4

# purple translation of the Maaot teal scheme
GLOW_CORE = (146, 118, 205)   # bright lavender core (their bright teal)
SKY_EDGE = (24, 16, 48)       # dark violet edges
FAR_TINT = (150, 128, 198)    # far spires: light, luminous
MID_TINT = (96, 76, 148)      # mid spires


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


# ---- extract sprite pools ----
deco = components("Mossy - BackgroundDecoration.png")
spires = sorted(deco, key=lambda t: -(t[1][3] - t[1][1]))
pillar1, pillar2 = spires[0][0], spires[1][0]
domes = [im for im, b in deco if (b[2] - b[0]) > (b[3] - b[1])]  # wide mounds
dome = domes[0] if domes else spires[-1][0]

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

# ---- sky: glow radiates from the SKY DOOR, high in frame ----
DOOR_X, DOOR_Y = W * 0.54, H * 0.22
GOLD = (255, 214, 140)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.sqrt(((xx - DOOR_X) / (W * 0.60)) ** 2 + ((yy - DOOR_Y) / (H * 0.95)) ** 2)
d = np.clip(d, 0, 1) ** 1.35
d2 = np.sqrt(((xx - DOOR_X) / (W * 0.16)) ** 2 + ((yy - DOOR_Y) / (H * 0.22)) ** 2)
d2 = np.clip(d2, 0, 1)
sky = np.zeros((H, W, 3), dtype=np.float32)
for c in range(3):
    sky[..., c] = GLOW_CORE[c] * (1 - d) + SKY_EDGE[c] * d
    sky[..., c] += GOLD[c] * (1 - d2) ** 2.4 * 0.9  # warm halo around the door
canvas = Image.fromarray(sky.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")

rng = np.random.default_rng(7)

# ---- far band: light hazy spires across the width ----
for x, hgt, flip in [(-60, 640, 0), (270, 460, 1), (620, 720, 0), (1000, 520, 1),
                     (1300, 680, 0), (1650, 560, 1), (1840, 700, 0)]:
    p = pillar1 if hgt > 600 else pillar2
    if flip:
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.alpha_composite(tint_to(scale_h(p, hgt), FAR_TINT, 0.78), (x, H - hgt))
canvas.alpha_composite(tint_to(scale_h(dome, 300), FAR_TINT, 0.8), (700, 170))

# ---- mid band: medium spires + boulder domes ----
for x, hgt, flip in [(120, 520, 1), (480, 380, 0), (1120, 600, 0), (1560, 430, 1)]:
    p = pillar2 if flip else pillar1
    if flip:
        p = p.transpose(Image.FLIP_LEFT_RIGHT)
    canvas.alpha_composite(tint_to(scale_h(p, hgt), MID_TINT, 0.52), (x, H - hgt))
canvas.alpha_composite(tint_to(scale_h(dome, 260), MID_TINT, 0.5), (620, 200))
canvas.alpha_composite(tint_to(scale_h(dome.transpose(Image.FLIP_LEFT_RIGHT), 220),
                               MID_TINT, 0.55), (1240, 330))

# ---- distant lightning vein, behind mid spires ----
bolt = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(bolt)
pts = [(280, 130)]
for _ in range(7):
    px, py = pts[-1]
    pts.append((px + int(rng.integers(-46, 60)), py + int(rng.integers(40, 80))))
bd.line(pts, fill=(235, 222, 255, 210), width=4)
fx, fy = pts[3]
bd.line([pts[3], (fx - 70, fy + 90), (fx - 95, fy + 160)],
        fill=(235, 222, 255, 160), width=3)
canvas.alpha_composite(bolt.filter(ImageFilter.GaussianBlur(3)))

# ---- THE SKY DOOR: small glowing arch, the destination ----
door = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dd = ImageDraw.Draw(door)
dw, dh = 46, 84
dx0, dy0 = int(DOOR_X - dw / 2), int(DOOR_Y - dh / 2)
dd.rounded_rectangle([dx0, dy0, dx0 + dw, dy0 + dh], radius=dw // 2,
                     fill=(255, 240, 205, 235))
for k, al in [(2.1, 46), (3.6, 24)]:
    dd.rounded_rectangle(
        [DOOR_X - dw * k / 2, DOOR_Y - dh * k / 2, DOOR_X + dw * k / 2, DOOR_Y + dh * k / 2],
        radius=int(dw * k / 2), fill=(255, 214, 140, al))
# faint god-rays falling from the door — whisper-subtle
for ang_dx, ln in [(-180, 560), (170, 520)]:
    dd.polygon([(DOOR_X - 8, DOOR_Y), (DOOR_X + 8, DOOR_Y),
                (DOOR_X + ang_dx + 26, DOOR_Y + ln), (DOOR_X + ang_dx - 26, DOOR_Y + ln)],
               fill=(255, 224, 160, 6))
canvas.alpha_composite(door.filter(ImageFilter.GaussianBlur(3)))

# ---- wind-streaked spores (storm motion) + gold fireflies ----
motes = Image.new("RGBA", (W, H), (0, 0, 0, 0))
md = ImageDraw.Draw(motes)
for _ in range(34):
    mx, my = int(rng.integers(40, W - 40)), int(rng.integers(60, H - 120))
    ln = int(rng.integers(16, 38))
    md.line([mx, my, mx + ln, my + ln // 3], fill=(214, 198, 255, 165), width=3)
for _ in range(10):
    fx, fy = int(rng.integers(120, W - 120)), int(rng.integers(H // 2, H - 100))
    md.ellipse([fx - 4, fy - 4, fx + 4, fy + 4], fill=(255, 208, 118, 240))
    md.ellipse([fx - 12, fy - 12, fx + 12, fy + 12], fill=(255, 190, 90, 64))
canvas.alpha_composite(motes.filter(ImageFilter.GaussianBlur(2)))

# ---- near band: dark spires at edges + the floating platform mid-frame ----
canvas.alpha_composite(tint_to(scale_h(pillar1, 780), (30, 20, 55), 0.25, 0.55), (-90, H - 780))
canvas.alpha_composite(
    tint_to(scale_h(pillar2.transpose(Image.FLIP_LEFT_RIGHT), 660), (30, 20, 55), 0.28, 0.5),
    (1700, H - 660))

plat = tint_to(scale_h(platform, 240), (26, 18, 50), 0.12, 0.75)
px, py = (W - plat.width) // 2 - 80, 620
casc = tint_to(scale_h(cascade, 260), (26, 18, 50), 0.1, 0.6)
canvas.alpha_composite(casc, (px + plat.width // 2 - casc.width // 2, py + plat.height - 55))
canvas.alpha_composite(plat, (px, py))

# ---- dark mossy ground masses, bottom corners ----
g1 = tint_to(scale_h(hill, 360), (18, 12, 38), 0.15, 0.42)
canvas.alpha_composite(g1, (-200, H - 260))
g2 = tint_to(scale_h(hill.transpose(Image.FLIP_LEFT_RIGHT), 320), (18, 12, 38), 0.15, 0.38)
canvas.alpha_composite(g2, (1150, H - 220))

# ---- foreground: near-black hanging plants, top frame ----
canvas.alpha_composite(tint_to(scale_h(vine, 560), (10, 6, 24), 0.2, 0.3), (60, -20))
canvas.alpha_composite(tint_to(scale_h(cascade, 480), (10, 6, 24), 0.2, 0.3), (420, -30))
fgR = tint_to(scale_h(vine.transpose(Image.FLIP_LEFT_RIGHT), 620), (10, 6, 24), 0.2, 0.28)
canvas.alpha_composite(fgR, (W - fgR.width - 40, -25))

# ---- bloom pass: blur brights, add back ----
arr = np.asarray(canvas.convert("RGB"), dtype=np.float32)
lum = arr.mean(-1, keepdims=True)
bright = np.where(lum > 150, arr, 0)
bloom = Image.fromarray(bright.astype(np.uint8)).filter(ImageFilter.GaussianBlur(18))
arr = np.clip(arr + np.asarray(bloom, dtype=np.float32) * 0.45, 0, 255)
canvas = Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")

# ---- vignette ----
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).ellipse([-W * 0.22, -H * 0.3, W * 1.22, H * 1.3], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(170))
canvas = Image.composite(canvas, Image.new("RGBA", (W, H), (8, 5, 20, 255)), vig)

canvas.convert("RGB").save(OUT, quality=95)
print("mock v3 ->", OUT)
