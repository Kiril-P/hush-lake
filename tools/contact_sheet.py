#!/usr/bin/env python3
"""Build before | reference | after contact sheets.
Usage: tools/contact_sheet.py BEFORE_DIR GEN_DIR AFTER_DIR OUT_DIR [variant]
BEFORE/AFTER hold NN_name.png from tools/refshots.sh, GEN holds NN_name/<variant>.png (default v3_lowpoly)."""
import sys, os
from PIL import Image, ImageDraw
before, gen, after, out = sys.argv[1:5]
variant = sys.argv[5] if len(sys.argv) > 5 else "v3_lowpoly"
os.makedirs(out, exist_ok=True)
W = 640
for f in sorted(os.listdir(before)):
    if not f.endswith((".png", ".jpg")): continue
    name = f[:-4]
    def find(d, stem):
        for ext in (".jpg", ".png"):
            if os.path.exists(os.path.join(d, stem + ext)): return os.path.join(d, stem + ext)
        return ""
    imgs = [("before", os.path.join(before, f)), ("reference", find(os.path.join(gen, name), variant)), ("after", find(after, name))]
    tiles = []
    for label, p in imgs:
        if not p or not os.path.exists(p): continue
        im = Image.open(p).convert("RGB")
        im = im.resize((W, int(W * 9 / 16)))
        ImageDraw.Draw(im).text((8, 6), label, fill=(255, 255, 255))
        tiles.append(im)
    if len(tiles) < 2: continue
    sheet = Image.new("RGB", (W * len(tiles), tiles[0].height))
    for i, t in enumerate(tiles): sheet.paste(t, (i * W, 0))
    sheet.save(os.path.join(out, name + ".png"))
    print("sheet", name)
