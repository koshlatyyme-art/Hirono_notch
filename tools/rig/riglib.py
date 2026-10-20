"""Load Assets/Character and compose a pose — a Python mirror of the app's renderer, for checks and preview sheets.

Pose keys (normalized, missing = 0): lean, headTilt, headTurn, arm, antenna (-1…1);
bounce, breath, sleep, night, heartGlow, antennaGlow (0…1).
"""
import json
import math
import os

import cv2
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "Assets", "Character")
NIGHT_TINT = np.array([0x4D, 0x55, 0x73], np.float32) / 255.0


def clamp(v, lo=-1.0, hi=1.0):
    return max(lo, min(hi, v))


def load():
    with open(os.path.join(ASSETS, "rig.json")) as f:
        rig = json.load(f)
    images = {}
    for layer in rig["layers"]:
        im = np.asarray(Image.open(os.path.join(ASSETS, layer["file"])).convert("RGBA"), np.float32) / 255.0
        im[..., :3] *= im[..., 3:4]  # premultiply
        images[layer["name"]] = im
    return rig, images


def _about(pivot, m):
    px, py = pivot
    return np.array([[1, 0, px], [0, 1, py], [0, 0, 1]]) @ m @ np.array([[1, 0, -px], [0, 1, -py], [0, 0, 1]])


def _rot(deg):  # clockwise on screen (y down), like SwiftUI rotationEffect
    t = math.radians(deg)
    return np.array([[math.cos(t), -math.sin(t), 0], [math.sin(t), math.cos(t), 0], [0, 0, 1]])


def local_transforms(rig, pose):
    """Mirror of Swift `transforms(for:rig:)`: per-layer rotation/turn/offset/scaleY."""
    lim, h = rig["limits"], rig["canvas"][1]
    g = lambda k: pose.get(k, 0.0)
    t = {layer["name"]: dict(rotation=0.0, turn=0.0, dx=0.0, dy=0.0, scaleY=1.0) for layer in rig["layers"]}
    t["body"].update(rotation=clamp(g("lean")) * lim["body"], scaleY=1 + 0.015 * g("breath"), dy=-g("bounce") * 0.08 * h)
    t["head"].update(rotation=clamp(g("headTilt")) * lim["head"] + g("sleep") * 0.8 * lim["head"],
                     turn=clamp(g("headTurn")) * lim["headTurn"], dy=g("sleep") * 0.03 * h)
    t["arm"].update(rotation=clamp(g("arm")) * lim["arm"])
    t["antenna"].update(rotation=clamp(g("antenna")) * lim["antenna"])
    return t


def world_matrices(rig, pose):
    layers = {layer["name"]: layer for layer in rig["layers"]}
    loc = local_transforms(rig, pose)

    def local_matrix(name):
        p, tr = layers[name]["pivot"], loc[name]
        m = np.diag([1.0, tr["scaleY"], 1.0])
        # rotation3DEffect about Y ≈ horizontal foreshortening around the pivot
        m = np.diag([math.cos(math.radians(tr["turn"])), 1.0, 1.0]) @ m
        m = _rot(tr["rotation"]) @ m
        m = _about(p, m)
        return np.array([[1, 0, tr["dx"]], [0, 1, tr["dy"]], [0, 0, 1]]) @ m

    out = {}
    for name in layers:
        m, cur = np.eye(3), name
        while cur is not None:
            m = local_matrix(cur) @ m
            cur = layers[cur]["parent"]
        out[name] = m
    return out


def compose(rig, images, pose, glows=True):
    """Premultiplied RGBA float image of the posed character on a transparent canvas."""
    w, h = rig["canvas"]
    mats = world_matrices(rig, pose)
    acc = np.zeros((h, w, 4), np.float32)
    for layer in rig["layers"]:
        warped = cv2.warpAffine(images[layer["name"]], mats[layer["name"]][:2], (w, h), flags=cv2.INTER_LINEAR,
                                borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        acc = warped + acc * (1 - warped[..., 3:4])
    night = pose.get("night", 0.0)
    if night > 0:
        acc[..., :3] *= (1 - night) + night * NIGHT_TINT
    if glows:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        flash = {"heart": pose.get("heartGlow", 0.0), "antenna": pose.get("antennaGlow", 0.0)}
        for gl in rig["glows"]:
            k = max(night * gl["night"], flash.get(gl["name"], 0.0))
            if k <= 0:
                continue
            cx, cy, _ = mats[gl["parent"]] @ np.array([gl["center"][0], gl["center"][1], 1.0])
            d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / gl["radius"]
            fall = np.clip(1 - d, 0, 1) ** 2 * k
            color = np.array([int(gl["color"][i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255.0
            acc[..., :3] += fall[..., None] * color * acc[..., 3:4]  # light only lands on the figure
    return np.clip(acc, 0, 1)


def on_background(premul, bg):
    bg = np.array(bg, np.float32) / 255.0
    return premul[..., :3] + bg * (1 - premul[..., 3:4])


def to_image(rgb):
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).round().astype(np.uint8), "RGB")


def crop_frame(img, rig, frame):
    x, y, fw, fh = rig["frames"][frame]
    return img.crop((round(x), round(y), round(x + fw), round(y + fh)))
