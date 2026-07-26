"""
Step 3 mist assets.

1. Bakes a SEAMLESS tiling fractal-noise texture as a PNG. Built in the Fourier
   domain (inverse FFT of a 1/f^b-shaped spectrum), which is inherently periodic
   -> tiles with no seam. Baked rather than generated at runtime so it is
   byte-identical under every GL backend (the Compatibility-renderer seamless-
   noise inconsistency the brief warns about simply can't bite us).

2. Samples the painting's own violet haze so the mist layers are tinted to it
   rather than to a guess.

Run: python tools/gen_mist_assets.py
"""
import numpy as np
from PIL import Image

OUT = "assets/ui/main_menu/mist_noise.png"
N = 512

# --- seamless fractal noise via shaped-spectrum inverse FFT ---
rng = np.random.default_rng(7)
white = rng.standard_normal((N, N))
F = np.fft.fft2(white)
fy = np.fft.fftfreq(N)[:, None]
fx = np.fft.fftfreq(N)[None, :]
freq = np.sqrt(fx ** 2 + fy ** 2)
freq[0, 0] = 1.0
F *= 1.0 / (freq ** 1.85)          # fractal (cloud-like) falloff
img = np.fft.ifft2(F).real
img = (img - img.min()) / (img.max() - img.min())
# mild s-curve so it has soft billows with clear gaps
img = np.clip((img - 0.5) * 1.15 + 0.5, 0, 1)
Image.fromarray((img * 255).astype(np.uint8), "L").save(OUT)
print("saved", OUT, "%dx%d seamless noise" % (N, N))

# --- sample the painting's violet haze for the mist tint ---
# take the central region, drop deep shadow AND bright glows/text, and average
# the MID band — that's the lit violet mist itself, not the black it sits on.
p = np.asarray(Image.open("assets/ui/main_menu/main_menu_bg.png").convert("RGB"),
               dtype=np.float32)
H, W, _ = p.shape
reg = p[int(0.15 * H):int(0.80 * H), int(0.20 * W):int(0.80 * W)].reshape(-1, 3)
lum = reg @ np.array([0.30, 0.59, 0.11])
lo, hi = np.percentile(lum, 55), np.percentile(lum, 85)
haze = reg[(lum >= lo) & (lum <= hi)].mean(axis=0)
tint = np.clip(haze, 0, 255)
print("mist tint (violet haze)  rgb = (%.0f, %.0f, %.0f)  = (%0.3f, %0.3f, %0.3f)"
      % (tint[0], tint[1], tint[2], tint[0] / 255, tint[1] / 255, tint[2] / 255))
print("mist tint  hex = #%02x%02x%02x" % (int(tint[0]), int(tint[1]), int(tint[2])))
