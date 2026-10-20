"""Cut character.png into animatable layers + rig.json.

All geometry below is in full-resolution source pixels (932x1307, origin top-left).
Output is downscaled by EXPORT_SCALE into Assets/Character/.

Run: tools/rig/.venv/bin/python -I tools/rig/cut.py
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "character.png")
OUT = os.path.join(ROOT, "Assets", "Character")
EXPORT_SCALE = 0.5
PAD = 120  # transparent margin so extreme poses stay on the canvas
SEAM = 3   # every layer continues this far under the layers drawn over it

# --- ownership polygons (priority: antenna > heart > head > arm > body) ---

ANTENNA_BALL = ((68, 235), 58)
ANTENNA_STEM = [(72, 266), (108, 250), (146, 282), (148, 326), (120, 338), (86, 306)]

HEART = [(596, 756), (614, 754), (624, 776), (622, 800), (630, 814), (620, 850), (652, 854),
         (656, 882), (632, 892), (592, 890), (546, 888), (530, 900), (492, 899), (478, 882),
         (490, 858), (528, 850), (526, 830), (538, 806), (560, 796), (584, 798), (594, 788)]

# Head's right edge: blue tube (head) vs alien (arm), then face edge vs strap/sleeve.
HEAD_RIGHT_EDGE = [(712, 0), (712, 470), (662, 518), (636, 560), (640, 620), (650, 662)]
NECK_SCAN_X = (280, 652)          # columns where the scarf bottom is detected
NECK_SCAN_FROM_Y = 700
HEAD_LEFT_FLOOR_Y = 900           # left of the robe (x < 300) nothing of the body sits above the legs

# Arm: everything right of the shoulder seam and the head's right edge.
ARM = [(712, 0), (932, 0), (932, 800), (740, 800), (700, 822), (668, 760), (650, 662),
       (640, 620), (636, 560), (662, 518), (712, 470)]

# --- hidden areas to paint in on the layer behind ---

# Robe continuing under the scarf (revealed when the head tilts / drops / turns).
BODY_UNDER_HEAD = [(332, 780), (420, 790), (520, 770), (590, 700), (640, 600), (690, 600),
                   (690, 860), (332, 860)]  # kept inside the robe's outline so it never pokes out
# Sleeve continuing under the body's shoulder seam, and the strap under the face edge.
ARM_UNDER_BODY = [(668, 640), (700, 640), (700, 780), (680, 830), (640, 840), (612, 760)]
ARM_UNDER_HEAD = [(596, 540), (662, 500), (668, 760), (596, 760)]
# Scarf continuing behind the heart (clipped to the scarf's own edge), and the fitting under the antenna stem.
HEAD_UNDER_HEART = [(520, 790), (600, 740), (640, 760), (640, 845), (520, 845)]
HEAD_UNDER_ANTENNA = [(104, 268), (152, 266), (162, 342), (104, 348)]

PIVOTS = {"body": (465, 1120), "arm": (668, 770), "head": (465, 820), "antenna": (135, 310),
          "heart": (575, 840)}
DRAW_ORDER = ["arm", "body", "head", "heart", "antenna"]
PARENTS = {"body": None, "arm": "body", "head": "body", "heart": "body", "antenna": "head"}
FRAMES = {"full": (-100, 40, 1132, 1120), "portrait": (-30, 140, 990, 700)}  # x, y, w, h
LIMITS = {"body": 3, "head": 10, "headTurn": 20, "arm": 15, "antenna": 25}
GLOWS = [
    {"name": "heart", "parent": "heart", "center": (575, 840), "radius": 80, "color": "#FF7A2E", "night": 1.0},
    {"name": "antenna", "parent": "antenna", "center": (68, 235), "radius": 70, "color": "#FF8C3A", "night": 0.9},
    {"name": "blueTube", "parent": "head", "center": (655, 425), "radius": 60, "color": "#3D7BFF", "night": 0.8},
    {"name": "greenTube", "parent": "head", "center": (195, 750), "radius": 55, "color": "#3DFF7A", "night": 0.35},
]

SS = 4  # polygon supersampling for antialiased edges


def poly_mask(size, polys=(), circles=()):
    w, h = size
    im = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon([(x * SS, y * SS) for x, y in p], fill=255)
    for (cx, cy), r in circles:
        d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=255)
    return np.asarray(im.resize((w, h), Image.BOX), dtype=np.float32) / 255.0


def scarf_bottom(rgba, heart):
    """Per-column y of the scarf's lower edge (first warm→cool transition below the face)."""
    r, b, a = rgba[..., 0].astype(int), rgba[..., 2].astype(int), rgba[..., 3]
    warm = ((r - b) > 25) & (a > 128) & (heart < 0.5)
    xs = np.arange(NECK_SCAN_X[0], NECK_SCAN_X[1] + 1)
    ys = []
    for x in xs:
        col = warm[:, x]
        y = NECK_SCAN_FROM_Y
        while y < NECK_SCAN_FROM_Y + 120 and not col[y]:  # hair above the face is cool: skip it
            y += 1
        while y < rgba.shape[0] - 1 and col[y]:
            y += 1
        if a[y, x] < 250:  # the face ends at the silhouette: keep its soft edge, stop at the next solid part
            stop = y + 40
            while y < stop and a[y, x] < 250:
                y += 1
        behind_heart = heart[min(y, rgba.shape[0] - 1), x] > 0.2 or heart[min(y + 2, rgba.shape[0] - 1), x] > 0.2
        ys.append(np.nan if behind_heart else y)
    ys = np.array(ys, dtype=np.float32)
    known = ~np.isnan(ys)  # where the heart hides the scarf's edge, continue the edge in a straight line
    ys = np.interp(xs, xs[known], ys[known]).astype(np.float32)
    k = 9  # median smoothing
    pad = np.pad(ys, k // 2, mode="edge")
    return xs, np.array([np.median(pad[i:i + k]) for i in range(len(ys))])


def head_polygon(xs, ys):
    pts = [(0, 0)] + HEAD_RIGHT_EDGE
    pts += [(int(x), float(y)) for x, y in zip(xs[::-1], ys[::-1])]
    pts += [(xs[0] - 10, HEAD_LEFT_FLOOR_Y), (0, HEAD_LEFT_FLOOR_Y)]
    return pts


def extend(layer_rgb, layer_a, fill):
    """Paint the layer's own content into the `fill` pixels (opaque interior of the original)."""
    fill = fill & (layer_a < 0.99)
    if not fill.any():
        return layer_rgb, layer_a
    unknown = (layer_a < 0.5).astype(np.uint8)
    ys, xs = np.nonzero(fill)
    y0, y1 = max(ys.min() - 80, 0), min(ys.max() + 80, layer_a.shape[0])
    x0, x1 = max(xs.min() - 80, 0), min(xs.max() + 80, layer_a.shape[1])
    win_rgb = np.ascontiguousarray(layer_rgb[y0:y1, x0:x1])
    painted = cv2.inpaint(win_rgb, unknown[y0:y1, x0:x1], 9, cv2.INPAINT_TELEA)
    out_rgb, out_a = layer_rgb.copy(), layer_a.copy()
    sub = fill[y0:y1, x0:x1]
    old_a = out_a[y0:y1, x0:x1][sub][:, None]
    blended = win_rgb[sub] * old_a + painted[sub] * (1 - old_a)
    out_rgb[y0:y1, x0:x1][sub] = blended.astype(np.uint8)
    out_a[y0:y1, x0:x1][sub] = 1.0
    return out_rgb, out_a


def export(rgb, a, path):
    rgba = np.dstack([rgb, (a * 255).round().astype(np.uint8)])
    rgba = np.pad(rgba, ((PAD, PAD), (PAD, PAD), (0, 0)))
    im = Image.fromarray(rgba)
    w, h = im.size
    small = im.convert("RGBa").resize((round(w * EXPORT_SCALE), round(h * EXPORT_SCALE)), Image.LANCZOS)
    small.convert("RGBA").save(path, optimize=True)


def main():
    src = np.array(Image.open(SRC).convert("RGBA"))
    h, w = src.shape[:2]
    rgb, alpha = src[..., :3].copy(), src[..., 3].astype(np.float32) / 255.0
    interior = cv2.erode((alpha > 0.99).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0

    m_antenna = poly_mask((w, h), [ANTENNA_STEM], [ANTENNA_BALL])
    m_heart = poly_mask((w, h), [HEART])
    xs, ys = scarf_bottom(src, m_heart)
    m_head = poly_mask((w, h), [head_polygon(xs, ys)])
    m_arm = poly_mask((w, h), [ARM])

    own = {}
    rest = np.ones((h, w), np.float32)
    for name, m in [("antenna", m_antenna), ("heart", m_heart), ("head", m_head), ("arm", m_arm)]:
        own[name] = np.minimum(m, rest)
        rest = rest - own[name]
    own["body"] = rest

    layers = {n: (rgb.copy(), alpha * own[n]) for n in own}
    # only what is drawn over a layer can hide its extension
    over = {n: sum((own[m] for m in DRAW_ORDER[i + 1:]), np.zeros_like(rest)) for i, n in enumerate(DRAW_ORDER)}
    # 1) larger hidden areas: painted from the layer's own pixels
    head_area = m_head > 0.5
    for back, region, within in [("body", BODY_UNDER_HEAD, interior), ("arm", ARM_UNDER_BODY, interior),
                                 ("arm", ARM_UNDER_HEAD, interior), ("head", HEAD_UNDER_HEART, interior & head_area),
                                 ("head", HEAD_UNDER_ANTENNA, interior)]:
        lr, la = layers[back]
        layers[back] = extend(lr, la, (poly_mask((w, h), [region]) > 0.5) & within & (over[back] > 0.5))
    # 2) a thin band under every seam keeps the original pixels, so the rest pose has no seam lines
    kernel = np.ones((2 * SEAM + 1, 2 * SEAM + 1), np.uint8)
    for back in DRAW_ORDER[:-1]:
        band = (cv2.dilate((own[back] > 0.5).astype(np.uint8), kernel) > 0) & (over[back] > 0.02) & interior
        lr, la = layers[back]
        lr[band], la[band] = rgb[band], 1.0

    os.makedirs(OUT, exist_ok=True)
    for name, (lr, la) in layers.items():
        export(lr, la, os.path.join(OUT, f"{name}.png"))

    s = EXPORT_SCALE
    sc = lambda p: [round((p[0] + PAD) * s, 1), round((p[1] + PAD) * s, 1)]
    rig = {
        "canvas": [round((w + 2 * PAD) * s), round((h + 2 * PAD) * s)],
        "frames": {k: sc(f[:2]) + [round(v * s, 1) for v in f[2:]] for k, f in FRAMES.items()},
        "limits": LIMITS,
        "layers": [{"name": n, "file": f"{n}.png", "parent": PARENTS[n], "pivot": sc(PIVOTS[n])} for n in DRAW_ORDER],
        "glows": [dict(g, center=sc(g["center"]), radius=round(g["radius"] * s, 1)) for g in GLOWS],
    }
    with open(os.path.join(OUT, "rig.json"), "w") as f:
        json.dump(rig, f, indent=2)
    print("wrote", OUT, "canvas", rig["canvas"])


if __name__ == "__main__":
    sys.exit(main())
