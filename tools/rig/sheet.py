"""Pose sheet for visual review → build/rig-sheet.png (and build/rig-sheet-portrait.png).

Run: tools/rig/.venv/bin/python -I tools/rig/sheet.py [--bg R,G,B] [pose names…]
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import riglib  # noqa: E402

POSES = {
    "rest": {},
    "head L": {"headTilt": -1}, "head R": {"headTilt": 1},
    "turn L": {"headTurn": -1}, "turn R": {"headTurn": 1},
    "arm up": {"arm": -1}, "arm down": {"arm": 1},
    "antenna L": {"antenna": -1}, "antenna R": {"antenna": 1},
    "lean L": {"lean": -1, "headTurn": -1}, "lean R": {"lean": 1, "headTurn": 1},
    "jump": {"bounce": 1, "arm": -0.8, "heartGlow": 1},
    "sleep": {"sleep": 1},
    "night": {"night": 1},
    "night+sleep": {"night": 1, "sleep": 1},
}


def tile(img, height, label):
    w = round(img.width * height / img.height)
    t = img.resize((w, height), Image.LANCZOS)
    out = Image.new("RGB", (w, height + 16), (40, 40, 40))
    out.paste(t, (0, 16))
    ImageDraw.Draw(out).text((4, 2), label, fill=(230, 230, 230))
    return out


def grid(tiles, cols, gap=6, bg=(40, 40, 40)):
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    cw = max(t.width for t in tiles)
    ch = max(t.height for t in tiles)
    out = Image.new("RGB", (cols * (cw + gap) + gap, len(rows) * (ch + gap) + gap), bg)
    for r, row in enumerate(rows):
        for c, t in enumerate(row):
            out.paste(t, (gap + c * (cw + gap), gap + r * (ch + gap)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bg", default="0,0,0")
    ap.add_argument("--height", type=int, default=300)
    ap.add_argument("--cols", type=int, default=5)
    ap.add_argument("--out", default=os.path.join(riglib.ROOT, "build", "rig-sheet.png"))
    ap.add_argument("poses", nargs="*")
    args = ap.parse_args()
    bg = tuple(int(v) for v in args.bg.split(","))
    names = args.poses or list(POSES)

    rig, images = riglib.load()
    full, portrait = [], []
    for name in names:
        img = riglib.to_image(riglib.on_background(riglib.compose(rig, images, POSES[name]), bg))
        full.append(tile(riglib.crop_frame(img, rig, "full"), args.height, name))
        portrait.append(tile(riglib.crop_frame(img, rig, "portrait"), 60, name))
        portrait.append(tile(riglib.crop_frame(img, rig, "portrait"), 120, name))
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    grid(full, args.cols).save(args.out)
    grid(portrait, 6).save(args.out.replace(".png", "-portrait.png"))
    print("wrote", args.out)


if __name__ == "__main__":
    sys.exit(main())
