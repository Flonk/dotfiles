#!/usr/bin/env python3
# kaliset nebula -> shaders/assets/nebula.png, one texture fetch at runtime.
# Two field layers after Jared Berghold's "Galaxy" shader (itself after
# CBS's "Simplicity Galaxy"); made tileable by half-roll blending. The RAW
# fields are stored (R = layer 1, G = layer 2, both halved) — coloring and
# brightness happen in-shader, so they stay live knobs.
import numpy as np
from PIL import Image

N = 1024
C = (-0.5, -0.4, -1.487)   # kaliset constant


def field(x, y, z, s, iters, th):
    accum = np.full(x.shape, s / 4.0)
    prev = np.zeros(x.shape)
    tw = 0.0
    x, y, z = x.copy(), y.copy(), z.copy()
    for i in range(iters):
        mag = np.maximum(x * x + y * y + z * z, 1e-9)
        x = np.abs(x) / mag + C[0]
        y = np.abs(y) / mag + C[1]
        z = np.abs(z) / mag + C[2]
        w = np.exp(-i / 5.0)
        accum += w * np.exp(-9.025 * np.abs(mag - prev) ** 2.2)
        tw += w
        prev = mag
    return np.maximum(0.0, 5.2 * accum / tw - th)


def make_tileable(img):
    for axis in (0, 1):
        rolled = np.roll(img, N // 2, axis=axis)
        u = (np.arange(N) + 0.5) / N
        shape = [1, 1, 1]
        shape[axis] = N
        w = (0.5 - 0.5 * np.cos(2 * np.pi * u)).reshape(shape)
        img = img * w + rolled * (1 - w)
    return img


u = (np.arange(N) + 0.5) / N * 2 - 1
X, Y = np.meshgrid(u, -u)

t = field(X / 2.5 + 0.8, Y / 2.5 - 1.3, np.zeros_like(X), 0.15, 13, 1.0)
t2 = field(X / 4.2 + 2.0, Y / 4.2 - 1.3, np.full_like(X, 3.0), 0.9, 18, 0.95)

img = np.stack([t / 2.0, t2 / 2.0, np.zeros_like(t)], -1)
img = make_tileable(img)

Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(
    "../../assets/nebula.png", optimize=True)
print("wrote nebula.png; field max", t.max(), t2.max())
