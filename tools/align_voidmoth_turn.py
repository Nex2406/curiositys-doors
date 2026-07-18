"""Normalize the void-moth sheets (Advika 2026-07-17: sizes drifted frame to
frame — "he gets bigger when he turns... sizing rlly matters"). The AI-drawn
sheets render the moth at wandering scales and centers; everything here is
measured against the fly frames so all sheets read as ONE creature.

- turn 1-6 (the fold; the ping-pong seq in VoidMoth.gd needs only these):
  frame 1's silhouette height anchors to fly_01, the rest mass-match frame 1
- attack 1-9 (voidattack*, the windup-into-comet): mass-matched straight to
  fly_01, and MIRRORED — the comet points right in the source art, but the
  moth family's unflipped base faces LEFT (turn glide, code flip logic)
- every frame's alpha centroid lands on the same canvas point
- strips (_turn_strip.png / _attack_strip.png) for eyeballing before shipping

Repeatable: rerun when source frames in Downloads change.
"""
import math
from PIL import Image, ImageEnhance


def tone(img, sat, val):
    """Pull vivid AI colors toward the realm's muted violet (alpha kept)."""
    a = img.getchannel("A")
    rgb = ImageEnhance.Brightness(
        ImageEnhance.Color(img.convert("RGB")).enhance(sat)).enhance(val)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out

DL = r"C:\Users\advik\Downloads"
PACK = r"C:\Users\advik\Curiosity's-Doors\assets\enemies\void_moth"
ALPHA_T = 24


def measure(img):
    a = img.getchannel("A")
    w, h = img.size
    px = a.load()
    area = 0
    sx = sy = 0.0
    for y in range(h):
        for x in range(w):
            if px[x, y] > ALPHA_T:
                area += 1
                sx += x
                sy += y
    return area, sx / max(area, 1), sy / max(area, 1)


def bbox_of(img):
    return img.getchannel("A").point(lambda v: 255 if v > ALPHA_T else 0).getbbox()


def place(img, scale, cx, cy, canvas, target_cx, target_cy):
    w, h = img.size
    scaled = img.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                        Image.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    out.alpha_composite(scaled, (round(target_cx - cx * scale),
                                 round(target_cy - cy * scale)))
    return out


def strip_of(imgs, canvas, path, ref=None):
    n = len(imgs) + (1 if ref else 0)
    s = Image.new("RGBA", (canvas[0] * n, canvas[1]), (30, 24, 54, 255))
    i = 0
    if ref:
        s.alpha_composite(ref, (0, 0))
        i = 1
    for im in imgs:
        s.alpha_composite(im, (i * canvas[0], 0))
        i += 1
    s.save(path)


fly = Image.open(f"{PACK}\\fly_01.png").convert("RGBA")
fa, fcx, fcy = measure(fly)
fly_h = bbox_of(fly)[3] - bbox_of(fly)[1]
print(f"fly_01: area={fa} bbox_h={fly_h} centroid=({fcx:.0f},{fcy:.0f})")

# ---- turn 1-6: height-anchor frame 1, mass-chain the rest ----
CANVAS_T = (314, 376)
t1 = Image.open(f"{DL}\\voidturn1.png").convert("RGBA")
a1, *_ = measure(t1)
s1 = fly_h / (bbox_of(t1)[3] - bbox_of(t1)[1])
outs = []
for n in range(1, 7):
    img = Image.open(f"{DL}\\voidturn{n}.png").convert("RGBA")
    area, cx, cy = measure(img)
    s = s1 * math.sqrt(a1 / max(area, 1))
    out = place(img, s, cx, cy, CANVAS_T, fcx, fcy)
    out.save(f"{PACK}\\turn_{n:02d}.png")
    outs.append(out)
    print(f"turn{n}: scale {s:.3f}")
strip_of(outs, CANVAS_T, r"C:\Users\advik\Curiosity's-Doors\_turn_strip.png", fly)

# ---- attack 1-9: mass-match to fly, mirrored to the left-facing base ----
CANVAS_A = (460, 376)
outs = []
for n in range(1, 10):
    img = Image.open(f"{DL}\\voidattack{n}.png").convert("RGBA")
    img = img.transpose(Image.FLIP_LEFT_RIGHT)
    img = tone(img, 0.80, 0.93)   # the comet was too candy-bright for the level
    area, cx, cy = measure(img)
    s = math.sqrt(fa / max(area, 1))
    out = place(img, s, cx, cy, CANVAS_A, CANVAS_A[0] / 2, CANVAS_A[1] / 2)
    out.save(f"{PACK}\\attack_{n:02d}.png")
    outs.append(out)
    print(f"attack{n}: scale {s:.3f}")
strip_of(outs, CANVAS_A, r"C:\Users\advik\Curiosity's-Doors\_attack_strip.png")

# ---- death 1-3: ONE uniform scale (frame 1 mass-matched to fly) so the
# dispersal still shrinks naturally; per-frame matching would re-inflate
# the fading motes. (The un-normalized sheet popped BIGGER at the kill.)
CANVAS_D = (380, 420)
d1 = Image.open(f"{DL}\\voidmothdeath1.png").convert("RGBA")
a_d1, *_ = measure(d1)
s_d = math.sqrt(fa / max(a_d1, 1))
outs = []
for n in range(1, 4):
    img = Image.open(f"{DL}\\voidmothdeath{n}.png").convert("RGBA")
    area, cx, cy = measure(img)
    out = place(img, s_d, cx, cy, CANVAS_D, CANVAS_D[0] / 2, CANVAS_D[1] / 2)
    out.save(f"{PACK}\\death_{n:02d}.png")
    outs.append(out)
    print(f"death{n}: scale {s_d:.3f}")
strip_of(outs, CANVAS_D, r"C:\Users\advik\Curiosity's-Doors\_death_strip.png")
print("strips -> _turn_strip.png / _attack_strip.png / _death_strip.png")
