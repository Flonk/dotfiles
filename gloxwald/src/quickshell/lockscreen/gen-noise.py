#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.numpy python3Packages.pillow

"""Generate the two procedural noise textures as PNG files.

random.png      — 512x512 RGBA8, all channels independently random (hash-based).
fractalnoise.png — 512x512 RGBA8, tileable Perlin/FBM noise.
                   R=Perlin, G=4-oct FBM, B=8-oct FBM, A=16-oct FBM.

These match the textures generated at runtime by the Rust lockscreen's noise.rs.
"""

import os
import struct
import numpy as np
from PIL import Image

SIZE = 512
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shaders", "assets")


# ---------- random.png ----------

def mix(x: np.ndarray) -> np.ndarray:
    """Integer hash matching the Rust version (wrapping u32 arithmetic)."""
    M = np.uint32(0xFFFFFFFF)
    x = x.astype(np.uint64)  # avoid overflow during multiply
    x ^= x >> np.uint64(16)
    x = (x * np.uint64(0x7FEB352D)) & np.uint64(M)
    x ^= x >> np.uint64(15)
    x = (x * np.uint64(0x846CA68B)) & np.uint64(M)
    x ^= x >> np.uint64(16)
    return x


def gen_random(seed: int) -> np.ndarray:
    ys = np.arange(SIZE, dtype=np.uint64).reshape(SIZE, 1)
    xs = np.arange(SIZE, dtype=np.uint64).reshape(1, SIZE)
    base = (ys << np.uint64(16)) ^ xs ^ np.uint64(seed)

    r = mix(base ^ np.uint64(0x13579BDF)) & np.uint64(255)
    g = mix(base ^ np.uint64(0x2468ACE0)) & np.uint64(255)
    b = mix(base ^ np.uint64(0xFDB97531)) & np.uint64(255)
    a = mix(base ^ np.uint64(0x0ACE1E55)) & np.uint64(255)

    img = np.stack([r, g, b, a], axis=-1).astype(np.uint8)
    return img


# ---------- fractalnoise.png ----------
# Tileable via 4D torus mapping, matching the Rust noise crate's Perlin impl.

def perlin_grad4(hash_val, x, y, z, w):
    """4D Perlin gradient function (matches noise crate)."""
    # Use lower 5 bits to select gradient
    h = hash_val & 31
    # 4D gradient vectors: pick 3 of 4 coords
    u = np.where(h < 24, x, y)
    v = np.where(h < 16, y, z)
    w2 = np.where(h < 8, z, w)
    return (np.where(h & 1, -u, u) +
            np.where(h & 2, -v, v) +
            np.where(h & 4, -w2, w2))


def fade(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def lerp(t, a, b):
    return a + t * (b - a)


class Perlin4D:
    def __init__(self, seed):
        rng = np.random.RandomState(seed)
        self.perm = np.arange(256, dtype=np.int32)
        rng.shuffle(self.perm)
        self.perm = np.tile(self.perm, 4)  # extend for wrapping

    def __call__(self, x, y, z, w):
        xi = np.floor(x).astype(np.int32) & 255
        yi = np.floor(y).astype(np.int32) & 255
        zi = np.floor(z).astype(np.int32) & 255
        wi = np.floor(w).astype(np.int32) & 255

        xf = x - np.floor(x)
        yf = y - np.floor(y)
        zf = z - np.floor(z)
        wf = w - np.floor(w)

        u = fade(xf)
        v = fade(yf)
        t = fade(zf)
        s = fade(wf)

        p = self.perm

        def grad(ix, iy, iz, iw, fx, fy, fz, fw):
            h = p[p[p[p[ix] + iy] + iz] + iw]
            return perlin_grad4(h, fx, fy, fz, fw)

        # 16 gradient lookups for 4D
        g0000 = grad(xi, yi, zi, wi, xf, yf, zf, wf)
        g1000 = grad(xi+1, yi, zi, wi, xf-1, yf, zf, wf)
        g0100 = grad(xi, yi+1, zi, wi, xf, yf-1, zf, wf)
        g1100 = grad(xi+1, yi+1, zi, wi, xf-1, yf-1, zf, wf)
        g0010 = grad(xi, yi, zi+1, wi, xf, yf, zf-1, wf)
        g1010 = grad(xi+1, yi, zi+1, wi, xf-1, yf, zf-1, wf)
        g0110 = grad(xi, yi+1, zi+1, wi, xf, yf-1, zf-1, wf)
        g1110 = grad(xi+1, yi+1, zi+1, wi, xf-1, yf-1, zf-1, wf)
        g0001 = grad(xi, yi, zi, wi+1, xf, yf, zf, wf-1)
        g1001 = grad(xi+1, yi, zi, wi+1, xf-1, yf, zf, wf-1)
        g0101 = grad(xi, yi+1, zi, wi+1, xf, yf-1, zf, wf-1)
        g1101 = grad(xi+1, yi+1, zi, wi+1, xf-1, yf-1, zf, wf-1)
        g0011 = grad(xi, yi, zi+1, wi+1, xf, yf, zf-1, wf-1)
        g1011 = grad(xi+1, yi, zi+1, wi+1, xf-1, yf, zf-1, wf-1)
        g0111 = grad(xi, yi+1, zi+1, wi+1, xf, yf-1, zf-1, wf-1)
        g1111 = grad(xi+1, yi+1, zi+1, wi+1, xf-1, yf-1, zf-1, wf-1)

        l0 = lerp(u, g0000, g1000)
        l1 = lerp(u, g0100, g1100)
        l2 = lerp(u, g0010, g1010)
        l3 = lerp(u, g0110, g1110)
        l4 = lerp(u, g0001, g1001)
        l5 = lerp(u, g0101, g1101)
        l6 = lerp(u, g0011, g1011)
        l7 = lerp(u, g0111, g1111)

        m0 = lerp(v, l0, l1)
        m1 = lerp(v, l2, l3)
        m2 = lerp(v, l4, l5)
        m3 = lerp(v, l6, l7)

        n0 = lerp(t, m0, m1)
        n1 = lerp(t, m2, m3)

        return lerp(s, n0, n1)


def fbm(perlin, x, y, z, w, octaves):
    """Fractal Brownian Motion with the noise crate's default parameters."""
    value = np.zeros_like(x)
    amplitude = 1.0
    frequency = 1.0
    # noise crate defaults: lacunarity=2.0, persistence=0.5
    for _ in range(octaves):
        value += amplitude * perlin(x * frequency, y * frequency,
                                     z * frequency, w * frequency)
        amplitude *= 0.5
        frequency *= 2.0
    return value


def gen_fractal_noise(seed: int) -> np.ndarray:
    perlin = Perlin4D(seed)
    scale = 3.0

    u_coords = np.linspace(0, 1, SIZE, endpoint=False, dtype=np.float64)
    v_coords = np.linspace(0, 1, SIZE, endpoint=False, dtype=np.float64)
    uu, vv = np.meshgrid(u_coords, v_coords)

    tau = 2 * np.pi
    nx = scale * np.cos(tau * uu)
    ny = scale * np.sin(tau * uu)
    nz = scale * np.cos(tau * vv)
    nw = scale * np.sin(tau * vv)

    def to_u8(v):
        return ((v * 0.5 + 0.5).clip(0, 1) * 255).astype(np.uint8)

    r = to_u8(perlin(nx, ny, nz, nw))
    g = to_u8(fbm(perlin, nx, ny, nz, nw, 4))
    b = to_u8(fbm(perlin, nx, ny, nz, nw, 8))
    a = to_u8(fbm(perlin, nx, ny, nz, nw, 16))

    return np.stack([r, g, b, a], axis=-1)


# ---------- main ----------

if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)

    seed = struct.unpack("<I", os.urandom(4))[0]
    print(f"Generating random.png (seed {seed:#010x})...")
    img = Image.fromarray(gen_random(seed), "RGBA")
    img.save(os.path.join(OUT_DIR, "random.png"))
    print("  OK")

    seed = struct.unpack("<I", os.urandom(4))[0]
    print(f"Generating fractalnoise.png (seed {seed:#010x})...")
    img = Image.fromarray(gen_fractal_noise(seed), "RGBA")
    img.save(os.path.join(OUT_DIR, "fractalnoise.png"))
    print("  OK")

    print(f"\nTextures written to {OUT_DIR}/")
