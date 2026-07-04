"""Hue-shift the mossy pack green -> deep violet, keeping darks dark.

Realm 2 palette: muted deep purples (per docs/ART_DIRECTION.md), low-lit.
Green foliage hue (~90-140deg) -> violet (~270-290deg); slight desaturation
so it stays muted/painterly, value untouched so the black cores survive.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(r"C:\Users\advik\AppData\Local\Temp\claude\C--Users-advik-Curiosity-s-Doors\179b0dee-263b-4524-9844-a926307358df\scratchpad\realm2_assets")
OUT = SRC / "_purple"

HUE_SHIFT = 150 / 360.0   # green (~120) -> violet (~270)
SAT_MUL = 0.82            # mute it a touch (painterly bible: desaturated)
VAL_MUL = 0.92            # sit it slightly darker (low-lit realm)


def shift(path: Path, out_path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    arr = np.asarray(img, dtype=np.float32) / 255.0
    rgb, alpha = arr[..., :3], arr[..., 3:]

    # RGB -> HSV (vectorized)
    maxc = rgb.max(-1)
    minc = rgb.min(-1)
    v = maxc
    delta = maxc - minc
    s = np.where(maxc > 0, delta / np.maximum(maxc, 1e-8), 0)
    # hue
    rc = np.where(delta > 0, (maxc - rgb[..., 0]) / np.maximum(delta, 1e-8), 0)
    gc = np.where(delta > 0, (maxc - rgb[..., 1]) / np.maximum(delta, 1e-8), 0)
    bc = np.where(delta > 0, (maxc - rgb[..., 2]) / np.maximum(delta, 1e-8), 0)
    h = np.select(
        [maxc == rgb[..., 0], maxc == rgb[..., 1]],
        [bc - gc, 2.0 + rc - bc],
        default=4.0 + gc - rc,
    )
    h = (h / 6.0) % 1.0

    h = (h + HUE_SHIFT) % 1.0
    s = np.clip(s * SAT_MUL, 0, 1)
    v = np.clip(v * VAL_MUL, 0, 1)

    # HSV -> RGB
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1.0 - s)
    q = v * (1.0 - s * f)
    t = v * (1.0 - s * (1.0 - f))
    i = i.astype(int) % 6
    conds = [i == k for k in range(6)]
    r = np.select(conds, [v, q, p, p, t, v])
    g = np.select(conds, [t, v, v, q, p, p])
    b = np.select(conds, [p, p, t, v, v, q])
    out = np.concatenate([np.stack([r, g, b], -1), alpha], -1)

    out_img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_img.save(out_path)
    print(f"ok  {path.name}")


if __name__ == "__main__":
    targets = list((SRC / "Mossy Assets" / "Mossy Tileset").glob("*.png"))
    for t in targets:
        shift(t, OUT / t.name)
    print(f"{len(targets)} sheets -> {OUT}")
