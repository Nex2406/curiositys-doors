"""
Procedural depth map for the main-menu painting (Step 1).

White = near to camera, black = far. Built from a handful of broad gradients
and soft radial blobs, then heavily blurred so every boundary is a gradual
atmospheric falloff (hard edges would stair-step tear under the parallax
shader). This does NOT trace the painting's shapes — it approximates the
depth INTENT and lets everything blend.

Depth intent, far -> near:
  nebula / star field / great eye (upper)      far    (darkest)
  valley mist between the cliffs               mid-far
  the three doors + cliff faces                mid   (left door slightly nearer)
  Curiosity + lantern + stone ledge (low-left) near
  edge vegetation frame (L / R / top) + floor  nearest (brightest)

Output: assets/ui/main_menu/main_menu_depth.png  (grayscale, lossless)
Run:    python tools/gen_menu_depth.py
"""
import numpy as np
from PIL import Image, ImageFilter

W, H = 1672, 941
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
X = xx / W
Y = yy / H


def blob(cx, cy, rx, ry):
    """Soft gaussian bump, 1.0 at (cx,cy) falling off over (rx,ry)."""
    return np.exp(-(((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2))


def edge(axis_val, width):
    """Gaussian ridge hugging an edge (axis_val is 0 at that edge)."""
    return np.exp(-((axis_val / width) ** 2))


# --- base: FLAT mid-far. No vertical gradient — depth in this painting is a
#     frame-vs-centre relationship, not top-vs-bottom (a vertical ramp read as
#     horizontal stripes and killed the window feel). Step 1b. ---
depth = np.full((H, W), 0.20, np.float32)

# --- reverse-vignette CORE: the interior falls away to far in the middle,
#     rising smoothly toward every edge ---
depth -= 0.10 * blob(0.50, 0.48, 0.58, 0.58)

# --- FAR: nebula band across the top, and the great eye within it ---
depth -= 0.11 * blob(0.55, 0.00, 1.0, 0.34)
depth -= 0.05 * blob(0.72, 0.18, 0.20, 0.15)

# --- MID-FAR: the valley / chasm mist pooling in the centre (applied BEFORE
#     the doors so the door blobs override it where the cliffs stand) ---
depth -= 0.15 * blob(0.50, 0.66, 0.34, 0.20)

# --- MID: cliff shelves + doors (left door reads slightly nearer). The right
#     shelf keeps the centre-right cliff + descending stairs at mid, so they
#     DON'T parallax as fast as Curiosity. ---
depth = np.maximum(depth, 0.42 * blob(0.30, 0.46, 0.22, 0.22))   # left cliff shelf
depth = np.maximum(depth, 0.42 * blob(0.69, 0.57, 0.25, 0.21))   # right cliff shelf
depth = np.maximum(depth, 0.60 * blob(0.19, 0.37, 0.15, 0.19))   # left door (nearer)
depth = np.maximum(depth, 0.55 * blob(0.62, 0.50, 0.16, 0.18))   # centre door
depth = np.maximum(depth, 0.52 * blob(0.85, 0.57, 0.16, 0.18))   # right door

# --- NEAREST FRAME (the Step-1b fix). The L/R vegetation is the heaviest near
#     element and runs the WHOLE height of both edges; the top branches are only
#     in the corners; Curiosity is a separate near ISLAND, not a bottom band. ---
depth = np.maximum(depth, 0.97 * edge(X, 0.14))                 # LEFT veg, full height
depth = np.maximum(depth, 0.97 * edge(1.0 - X, 0.13))          # RIGHT veg, full height
depth = np.maximum(depth, 0.95 * blob(0.05, 0.02, 0.17, 0.14))  # top-LEFT branches
depth = np.maximum(depth, 0.95 * blob(0.96, 0.04, 0.17, 0.15))  # top-RIGHT branches
depth = np.maximum(depth, 0.95 * blob(0.13, 0.85, 0.15, 0.15))  # Curiosity + ledge

# --- heavy blur so nothing has a crisp boundary ---
depth = np.clip(depth, 0.0, 1.0)
img = Image.fromarray((depth * 255).astype(np.uint8), mode="L")
img = img.filter(ImageFilter.GaussianBlur(radius=48))

img.save("assets/ui/main_menu/main_menu_depth.png")
print("saved assets/ui/main_menu/main_menu_depth.png", img.size, img.mode)
