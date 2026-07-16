#!/usr/bin/env python3
# Bakes the and& ampersand SDFs into yamp_sdf.png (R = J piece, G = P piece,
# B = glyph-space coastline fbm for terra mode — summed onto the distances
# in-shader so the wobble is constant in the glyph frame).
# Numpy port of the exact bezier SDF that used to live in shader.glsl
# (iq's quadratic bezier distance + even-odd winding).
#
# Texture covers glyph space [-BOX, BOX]^2, row 0 = y = +BOX (Qt v-down UVs).
# Distances are clamped to +-RANGE/2 and mapped to [0, 255].
#
# Run: nix-shell -p "python3.withPackages(ps: [ps.numpy ps.pillow])" --run "python3 gen_sdf.py"

import numpy as np
from PIL import Image

NJ, NSEG = 41, 76
N = 1024
BOX = 0.75
RANGE = 0.25

AMP = np.loadtxt("amp_curves.txt", delimiter=",")
assert AMP.shape == (NSEG * 3, 2)

xs = (np.arange(N) + 0.5) / N * 2 * BOX - BOX
ys = BOX - (np.arange(N) + 0.5) / N * 2 * BOX
X, Y = np.meshgrid(xs, ys)


def ud_bezier(qa, qb, qc):
    a = qb - qa
    b = qa - 2 * qb + qc
    c = 2 * a
    dx, dy = qa[0] - X, qa[1] - Y
    kk = 1.0 / np.dot(b, b)
    kx = kk * np.dot(a, b)
    ky = kk * (2 * np.dot(a, a) + (dx * b[0] + dy * b[1])) / 3.0
    kz = kk * (dx * a[0] + dy * a[1])
    p = ky - kx * kx
    q = kx * (2 * kx * kx - 3 * ky) + kz
    h = q * q + 4 * p**3

    sh = np.sqrt(np.maximum(h, 0))
    x1, x2 = (sh - q) / 2, (-sh - q) / 2
    uv = np.cbrt(x1) + np.cbrt(x2)
    t = np.clip(uv - kx, 0, 1)
    rx, ry = dx + (c[0] + b[0] * t) * t, dy + (c[1] + b[1] * t) * t
    res_pos = rx * rx + ry * ry

    with np.errstate(divide="ignore", invalid="ignore"):
        z = np.sqrt(np.maximum(-p, 1e-30))
        v = np.arccos(np.clip(q / (p * z * 2), -1, 1)) / 3
    m, n = np.cos(v), np.sin(v) * 1.732050808
    res_neg = np.full_like(res_pos, np.inf)
    for t in (np.clip((m + m) * z - kx, 0, 1), np.clip((-n - m) * z - kx, 0, 1)):
        rx, ry = dx + (c[0] + b[0] * t) * t, dy + (c[1] + b[1] * t) * t
        res_neg = np.minimum(res_neg, rx * rx + ry * ry)

    return np.sqrt(np.where(h >= 0, res_pos, res_neg))


def sd_shape(i0, i1):
    d = np.full((N, N), 1e9)
    inside = np.zeros((N, N), bool)
    for i in range(i0, i1):
        qa, qb, qc = AMP[3 * i], AMP[3 * i + 1], AMP[3 * i + 2]
        d = np.minimum(d, ud_bezier(qa, qb, qc))

        ay = qa[1] - 2 * qb[1] + qc[1]
        by = qb[1] - qa[1]
        cy = qa[1] - Y
        ax = qa[0] - 2 * qb[0] + qc[0]
        bx = qb[0] - qa[0]
        if abs(ay) < 1e-5:
            if abs(by) > 1e-7:
                t = cy / (-2 * by)
                inside ^= (t >= 0) & (t < 1) & (ax * t * t + 2 * bx * t + qa[0] > X)
        else:
            disc = by * by - ay * cy
            ok = disc > 0
            r = np.sqrt(np.maximum(disc, 0)) * (1 if by >= 0 else -1)
            hh = -(by + r)
            with np.errstate(divide="ignore", invalid="ignore"):
                t1 = hh / ay
                t2 = cy / hh
            inside ^= ok & (t1 >= 0) & (t1 < 1) & (ax * t1 * t1 + 2 * bx * t1 + qa[0] > X)
            inside ^= ok & (t2 >= 0) & (t2 < 1) & (ax * t2 * t2 + 2 * bx * t2 + qa[0] > X)
    return np.where(inside, -d, d)


def encode(d):
    return np.round((np.clip(d, -RANGE / 2, RANGE / 2) / RANGE + 0.5) * 255).astype(np.uint8)


def fbm(seed, beta=1.6):
    rng = np.random.default_rng(seed)
    spec = np.fft.fft2(rng.standard_normal((N, N)))
    fx = np.fft.fftfreq(N)[None, :]
    fy = np.fft.fftfreq(N)[:, None]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    img = np.real(np.fft.ifft2(spec / f**beta))
    img -= img.min()
    img /= img.max()
    return img


dj = sd_shape(0, NJ)
dp = sd_shape(NJ, NSEG)

out = np.zeros((N, N, 3), np.uint8)
out[..., 0] = encode(dj)
out[..., 1] = encode(dp)
out[..., 2] = np.round(fbm(7) * 255).astype(np.uint8)
Image.fromarray(out).save("../../assets/yamp_sdf.png", optimize=True)

dbg = np.where(dj < 0, 255, np.where(dp < 0, 160, 20)).astype(np.uint8)
Image.fromarray(dbg).save("/tmp/yamp_sdf_debug.png")
print("wrote yamp_sdf.png; dj range", dj.min(), dj.max(), "dp range", dp.min(), dp.max())
