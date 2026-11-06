#!/usr/bin/env python3
# Bakes the penrose diagram labels into penrose_labels.png: a 4x2 atlas of
# signed distance fields (cell height = 1 label unit, distances clamped to
# +-RANGE/2 and mapped to [0, 255], inside < 0.5). Script I from rsfs (the
# \mathscr of LaTeX), everything else from Latin Modern Math.
#
# Run: just gen-labels  (fetches the fonts via nix), or by hand:
#      nix-shell -p "python3.withPackages(p: [p.pillow p.numpy p.scipy])" \
#        --run "python3 gen_labels.py <rsfs10.pfb> <latinmodern-math.otf>"

import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt

RSFS, LMMATH = sys.argv[1], sys.argv[2]
CW, CH, COLS, ROWS = 256, 128, 4, 2
UP = 4
RANGE = 0.25
SIZE = 0.5 * CH * UP
SUP = 0.7
RAISE = 0.42

scr = ImageFont.truetype(RSFS, int(SIZE * 1.05))
lm = ImageFont.truetype(LMMATH, int(SIZE))
lms = ImageFont.truetype(LMMATH, int(SIZE * SUP))

IT_I, IT_R, IT_GAMMA, MINUS = "\U0001D456", "\U0001D45F", "\U0001D6FE", "\u2212"

LABELS = [
    [(scr, "I", 0), (lms, "+", 1)],
    [(scr, "I", 0), (lms, MINUS, 1)],
    [(lm, IT_I, 0), (lms, "+", 1)],
    [(lm, IT_I, 0), (lms, MINUS, 1)],
    [(lm, IT_I, 0), (lms, "0", 1)],
    [(lm, IT_R, 0), (lm, " = ", 0), (lm, "0", 0)],
    [(lm, IT_GAMMA, 0)],
]


def render(parts):
    w, h = CW * UP * 2, CH * UP * 2
    img = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(img)
    x, base = w * 0.25, h * 0.6
    for font, text, sup in parts:
        y = base - (RAISE * SIZE if sup else 0)
        if sup:
            x += 0.04 * SIZE
        dr.text((x, y), text, font=font, fill=255, anchor="ls")
        x += font.getlength(text)
    a = np.array(img) > 127
    ys, xs = np.nonzero(a)
    cy, cx = (ys.min() + ys.max()) / 2, (xs.min() + xs.max()) / 2
    out = np.zeros((CH * UP, CW * UP), bool)
    oy, ox = int(round(cy - CH * UP / 2)), int(round(cx - CW * UP / 2))
    out[:] = a[oy:oy + CH * UP, ox:ox + CW * UP]
    return out


atlas = np.full((ROWS * CH, COLS * CW), 255, np.uint8)
for i, parts in enumerate(LABELS):
    m = render(parts)
    d = distance_transform_edt(~m) - distance_transform_edt(m)
    d = d.reshape(CH, UP, CW, UP).mean(axis=(1, 3)) / (CH * UP)
    v = np.round((np.clip(d, -RANGE / 2, RANGE / 2) / RANGE + 0.5) * 255).astype(np.uint8)
    r, c = divmod(i, COLS)
    atlas[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW] = v

Image.fromarray(atlas).convert("RGB").save("../../assets/penrose_labels.png", optimize=True)
Image.fromarray(np.where(atlas < 128, 255, 0).astype(np.uint8)).save("/tmp/penrose_labels_debug.png")
