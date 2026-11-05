#!/usr/bin/env python3
"""Shrink the reference-workflow images for git: every PNG under docs/refs becomes a 1280px-wide JPEG (quality 86) and the PNG
is removed. Run after tools/refshots.sh and after the agents finish. Safe to re-run. Usage: tools/refs_pack.py [dir ...]"""
import os, sys
from PIL import Image
roots = sys.argv[1:] or ["docs/refs"]
n = 0
for root in roots:
    for d, _, files in os.walk(root):
        for f in files:
            if f.endswith(".png"):
                p = os.path.join(d, f)
                im = Image.open(p).convert("RGB")
                if im.width > 1280:
                    im = im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS)
                im.save(p[:-4] + ".jpg", quality=86)
                os.remove(p)
                n += 1
print("packed", n)
