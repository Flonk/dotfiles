#!/usr/bin/env python3
# Bakes the oscilloscope beam path into scope_path.png: the visible and&
# outline (J, and P minus the padded J, as drawn by sdJ/sdP) traced from
# yamp_sdf.png, resampled by arc length into N points. Column i is point i:
# row 0 = x, row 1 = y, as 16 bit (R hi, G lo) over [-BOX, BOX]; B = 255
# where the beam is lit on the way to the next point, 0 on a retrace jump.
#
# Run: just gen-scope, or by hand:
#      nix-shell -p "python3.withPackages(p: [p.pillow p.numpy p.scikit-image])" \
#        --run "python3 gen_scope.py"

import numpy as np
from PIL import Image
from skimage.measure import find_contours

N = 1024
BOX = 0.75
RANGE = 0.25
PAD = 0.0464
JUMP = 6

sdf = np.asarray(Image.open("../../assets/yamp_sdf.png").convert("RGB")).astype(float)
dj = (sdf[..., 0] / 255 - 0.5) * RANGE
dp = np.maximum((sdf[..., 1] / 255 - 0.5) * RANGE, PAD - dj)
res = sdf.shape[0]


def to_glyph(c):
    x = (c[:, 1] + 0.5) / res * 2 * BOX - BOX
    y = BOX - (c[:, 0] + 0.5) / res * 2 * BOX
    return np.stack([x, y], 1)


loops = []
for d in (dj, dp):
    for c in find_contours(d, 0.0):
        g = to_glyph(c)
        if len(g) < 20:
            continue
        if np.linalg.norm(g[0] - g[-1]) > 1e-3:
            g = np.vstack([g, g[:1]])
        k = np.ones(5) / 5
        g = np.stack([np.convolve(np.pad(g[:-1, i], 2, mode="wrap"), k, "valid") for i in range(2)], 1)
        g = np.vstack([g, g[:1]])
        loops.append(g)

loops.sort(key=lambda g: g[:, 0].min())
lengths = [np.sum(np.linalg.norm(np.diff(g, axis=0), axis=1)) for g in loops]
budget = N - JUMP * len(loops)
counts = [int(round(budget * l / sum(lengths))) for l in lengths]
counts[-1] += budget - sum(counts)


def resample(g, n):
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(g, axis=0), axis=1))])
    t = np.linspace(0, s[-1], n)
    return np.stack([np.interp(t, s, g[:, i]) for i in range(2)], 1)


pts, lit = [], []
for i, (g, n) in enumerate(zip(loops, counts)):
    r = resample(g, n)
    pts.append(r)
    lit += [1] * (n - 1) + [0]
    nxt = resample(loops[(i + 1) % len(loops)], 2)[0]
    j = np.linspace(r[-1], nxt, JUMP + 2)[1:-1]
    pts.append(j)
    lit += [0] * JUMP
pts = np.vstack(pts)
assert len(pts) == N

v = np.round((pts + BOX) / (2 * BOX) * 65535).astype(np.uint32)
img = np.zeros((2, N, 3), np.uint8)
for row in range(2):
    img[row, :, 0] = v[:, row] >> 8
    img[row, :, 1] = v[:, row] & 255
    img[row, :, 2] = np.array(lit) * 255
Image.fromarray(img).save("../../assets/scope_path.png")
print("loops", len(loops), "lengths", np.round(lengths, 3), "points", counts)
