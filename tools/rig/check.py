"""Rig checks: (a) rest pose reproduces the original; (b) extreme poses open no tears.

Run: tools/rig/.venv/bin/python -I tools/rig/check.py
"""
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut  # noqa: E402
import riglib  # noqa: E402

EXTREMES = {
    "head-": {"headTilt": -1}, "head+": {"headTilt": 1},
    "turn-": {"headTurn": -1}, "turn+": {"headTurn": 1},
    "arm-": {"arm": -1}, "arm+": {"arm": 1},
    "antenna-": {"antenna": -1}, "antenna+": {"antenna": 1},
    "body-": {"lean": -1}, "body+": {"lean": 1},
    "sleep": {"sleep": 1},
    "head+arm-": {"headTilt": 1, "headTurn": 1, "arm": -1},
    "head-arm+": {"headTilt": -1, "headTurn": -1, "arm": 1},
}
JOINT_RADIUS = {"head": 60, "arm": 25, "antenna": 15}  # export pixels around each pivot; the armpit opens legitimately beyond 25
MIN_HOLE = 4


def psnr_rest(rig, images):
    src = np.pad(np.asarray(Image.open(cut.SRC).convert("RGBA")), ((cut.PAD, cut.PAD), (cut.PAD, cut.PAD), (0, 0)))
    small = Image.fromarray(src).convert("RGBa").resize(tuple(rig["canvas"]), Image.LANCZOS)
    ref = np.asarray(small.convert("RGBA"), np.float32) / 255
    ref[..., :3] *= ref[..., 3:4]
    got = riglib.compose(rig, images, {}, glows=False)
    mask = (ref[..., 3] > 0) | (got[..., 3] > 0)
    gray = (128, 128, 128)
    diff = riglib.on_background(got, gray) - riglib.on_background(ref, gray)
    mse = float(np.mean(diff[mask] ** 2))
    return 10 * math.log10(1 / mse) if mse > 0 else float("inf")


def enclosed_transparent(alpha):
    clear = (alpha < 0.5).astype(np.uint8)
    n, labels = cv2.connectedComponents(clear, connectivity=4)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    return np.isin(labels, [i for i in range(1, n) if i not in border])


def tears(rig, images, pose, natural, rest_core):
    """Transparent pixels that open up inside the figure: new enclosed holes, or gaps at a joint
    (the joint's neighbourhood is carried along by the parent, so only relative motion counts)."""
    a = riglib.compose(rig, images, pose, glows=False)[..., 3]
    holes = enclosed_transparent(a) & rest_core & ~natural
    joints = np.zeros_like(holes)
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    mats = riglib.world_matrices(rig, pose)
    for layer in rig["layers"]:
        r = JOINT_RADIUS.get(layer["name"])
        if r and layer["parent"]:
            px, py = layer["pivot"]
            region = (((xx - px) ** 2 + (yy - py) ** 2 <= r * r) & rest_core).astype(np.uint8)
            moved = cv2.warpAffine(region, mats[layer["parent"]][:2], (w, h), flags=cv2.INTER_NEAREST) > 0
            joints |= moved & (a < 0.5)
    bad = (holes | joints).astype(np.uint8)
    n, _, stats, _ = cv2.connectedComponentsWithStats(bad, connectivity=8)
    return [tuple(stats[i, :4]) for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] >= MIN_HOLE]


def main():
    rig, images = riglib.load()
    p = psnr_rest(rig, images)
    ok_p = p >= 40
    print(f"rest PSNR: {p:.1f} dB {'OK' if ok_p else 'FAIL'}")

    rest_a = riglib.compose(rig, images, {}, glows=False)[..., 3]
    natural = cv2.dilate(enclosed_transparent(rest_a).astype(np.uint8), np.ones((51, 51), np.uint8)) > 0
    rest_core = cv2.erode((rest_a > 0.5).astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
    bad_poses = 0
    for name, pose in EXTREMES.items():
        found = tears(rig, images, pose, natural, rest_core)
        if found:
            bad_poses += 1
            print(f"  {name}: {len(found)} tear(s) at (x, y, w, h) {found[:5]}")
    print(f"holes: {bad_poses} in {len(EXTREMES)} poses {'OK' if bad_poses == 0 else 'FAIL'}")
    return 0 if ok_p and bad_poses == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
