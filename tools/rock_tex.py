"""Generates tileable rock textures for the cave shader (original, CC0).

Writes assets/textures/rock_height.png (grayscale detail, also used as albedo
variation) and rock_normal.png (tangent-space normal map, OpenGL style).

    python tools/rock_tex.py
"""
import os

import numpy as np
from PIL import Image

SIZE = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")


def periodic_value_noise(rng, size, cells):
    grid = rng.random((cells, cells))
    t = np.arange(size) / size * cells
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = grid[i0][:, i0]
    b = grid[i0][:, i1]
    c = grid[i1][:, i0]
    d = grid[i1][:, i1]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(rng, size, base, octaves):
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * periodic_value_noise(rng, size, base * 2 ** o)
        norm += amp
        amp *= 0.5
    return total / norm


def voronoi_cracks(rng, size, count, wobble):
    pts = rng.random((count, 2))
    ys, xs = np.mgrid[0:size, 0:size] / size
    # Domain warp so the cracks wander instead of running straight.
    xs = (xs + (fbm(rng, size, 3, 4) - 0.5) * wobble) % 1.0
    ys = (ys + (fbm(rng, size, 3, 4) - 0.5) * wobble) % 1.0
    f1 = np.full((size, size), 9.0)
    f2 = np.full((size, size), 9.0)
    for px, py in pts:
        dx = np.abs(xs - px)
        dy = np.abs(ys - py)
        dx = np.minimum(dx, 1 - dx)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    edge = f2 - f1
    return np.clip(edge / 0.035, 0, 1) ** 0.6


def main():
    rng = np.random.default_rng(1234)
    warp = fbm(rng, SIZE, 4, 5)
    cracks = voronoi_cracks(rng, SIZE, 14, 0.35)
    cracks_small = voronoi_cracks(rng, SIZE, 40, 0.25)
    height = 0.7 * warp + 0.2 * cracks + 0.1 * cracks_small
    height += 0.08 * fbm(rng, SIZE, 32, 3)
    height = (height - height.min()) / (height.max() - height.min())

    # Normal map from the height gradient (wraps around, so it tiles).
    strength = 6.0
    gx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    gy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    n = np.stack([-gx, gy, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)

    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((height * 255).astype(np.uint8), "L").save(os.path.join(OUT, "rock_height.png"))
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "rock_normal.png"))
    print("wrote rock textures to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
