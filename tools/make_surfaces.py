#!/usr/bin/env python3
"""Hand-painted-style tileable surface textures for the ground shader.

Each PNG stores shading in RGB (neutral grey, tinted in-game by the pastel
palette) and a mask in alpha (1 = stone/plank/tile, 0 = mortar/gaps).
Shading is lit from the top-left using a height map so stones look rounded.
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "textures")
N = 512
rng = np.random.default_rng(7)
YY, XX = np.mgrid[0:N, 0:N].astype(np.float32) / N  # 0..1, tileable domain


def smooth(t):
    return t * t * (3 - 2 * t)


def vnoise(freq, seed=None):
    """Periodic value noise with `freq` cells across the tile."""
    g = (np.random.default_rng(seed) if seed is not None else rng).random((freq, freq)).astype(np.float32)
    x = XX * freq
    y = YY * freq
    x0 = np.floor(x).astype(int) % freq
    y0 = np.floor(y).astype(int) % freq
    x1 = (x0 + 1) % freq
    y1 = (y0 + 1) % freq
    fx = smooth(x - np.floor(x))
    fy = smooth(y - np.floor(y))
    a = g[y0, x0] * (1 - fx) + g[y0, x1] * fx
    b = g[y1, x0] * (1 - fx) + g[y1, x1] * fx
    return a * (1 - fy) + b * fy


def fbm(base, octaves=4, gain=0.5):
    t = np.zeros((N, N), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        t += vnoise(base * 2 ** o) * amp
        tot += amp
        amp *= gain
    return t / tot


def voronoi(points):
    """Periodic Voronoi: nearest distance, second distance, nearest index."""
    d1 = np.full((N, N), 9.0, np.float32)
    d2 = np.full((N, N), 9.0, np.float32)
    idx = np.zeros((N, N), np.int32)
    for i, (px, py) in enumerate(points):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.hypot(XX - (px + ox), YY - (py + oy))
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                idx = np.where(closer, i, idx)
                d1 = np.where(closer, d, d1)
    return d1, d2, idx


def relaxed_points(n, iters=2):
    pts = rng.random((n, 2))
    for _ in range(iters):  # a little Lloyd relaxation for even stones
        _, _, idx = voronoi(pts)
        for i in range(n):
            m = idx == i
            if m.any():
                # circular mean handles wrap-around
                ax = np.angle(np.exp(2j * np.pi * XX[m]).mean()) / (2 * np.pi) % 1.0
                ay = np.angle(np.exp(2j * np.pi * YY[m]).mean()) / (2 * np.pi) % 1.0
                pts[i] = (ax, ay)
    return pts


def light(height, strength=6.0):
    """Lambert shading from a height map, light from the top-left."""
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
    nx, ny, nz = -gx, -gy, np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    L = np.array([-0.45, -0.55, 0.7])
    L = L / np.linalg.norm(L)
    return np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / ln, 0, 1)


def save(name, shade, mask=None):
    shade = np.clip(shade, 0.0, 1.25) / 1.25
    rgb = (np.stack([shade] * 3, -1) * 255).astype(np.uint8)
    a = np.ones((N, N), np.float32) if mask is None else np.clip(mask, 0, 1)
    img = np.dstack([rgb, (a * 255).astype(np.uint8)])
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, "surf_%s.png" % name), optimize=True)
    print("  surf_%s.png  mean %.2f" % (name, shade.mean() * 1.25))


def stones(n, gap, bump=1.0, crack=0.0):
    pts = relaxed_points(n)
    d1, d2, idx = voronoi(pts)
    edge = d2 - d1
    mask = np.clip((edge - gap) / (gap * 0.9), 0, 1)
    height = smooth(np.clip(edge / (gap * 5.0), 0, 1)) * bump
    height += fbm(24, 3) * 0.06
    tone = np.random.default_rng(3).uniform(0.86, 1.08, len(pts))[idx]
    shade = (0.55 + 0.6 * light(height)) * tone
    shade *= 0.92 + 0.16 * fbm(48, 3)
    if crack > 0:
        c = np.abs(fbm(10, 4) - 0.5) < crack
        shade = np.where(c, shade * 0.8, shade)
    return shade, mask


print("Surfaces:")
# Cobblestones for sidewalks and plazas.
s, m = stones(46, 0.012)
save("cobble", s, m)

# Big flagstones for the rooftop.
s, m = stones(14, 0.008, bump=0.7, crack=0.012)
save("flagstone", s, m)

# Asphalt: fine speckle, soft patches and a few hairline cracks.
s = 0.82 + 0.14 * (fbm(6, 3) - 0.5) + 0.22 * (vnoise(200) - 0.5) + 0.12 * (vnoise(90) - 0.5)
cr = np.abs(fbm(5, 5) - 0.5) < 0.0035
s = np.where(cr, s * 0.86, s)
save("asphalt", s)

# Dirt paths: sandy noise with pebbles.
s = 0.84 + 0.18 * (fbm(8, 4) - 0.5) + 0.1 * (vnoise(160) - 0.5)
d1, d2, _ = voronoi(rng.random((110, 2)))
peb = smooth(np.clip(1 - d1 / 0.016, 0, 1))
s = s * (1 - 0.12 * (peb > 0)) + 0.35 * (light(peb * 0.8, 8.0) - 0.6) * (peb > 0)
save("dirt", s)

# Grass: soft clumps plus short painted blade strokes.
s = 0.8 + 0.22 * (fbm(6, 4) - 0.5)
img = Image.fromarray(((np.clip(s, 0, 1.25) / 1.25) * 255).astype(np.uint8), "L")
from PIL import ImageDraw  # noqa: E402

d = ImageDraw.Draw(img)
for _ in range(5200):
    x, y = rng.random() * N, rng.random() * N
    ln = rng.uniform(6, 16)
    ang = math.radians(rng.uniform(-110, -70))
    v = int(np.clip(rng.normal(0.8, 0.12) / 1.25 * 255, 60, 255))
    for ox in (-N, 0, N):
        for oy in (-N, 0, N):
            d.line([(x + ox, y + oy), (x + ox + math.cos(ang) * ln, y + oy + math.sin(ang) * ln)], fill=v, width=2)
s = np.asarray(img, np.float32) / 255 * 1.25
s = s * (0.94 + 0.12 * vnoise(40))
save("grass", s)

# Wood planks: five boards, staggered joints, grain and the odd knot.
boards = 5
bx = XX * boards
bi = np.floor(bx).astype(int)
fx = bx - bi
offs = np.random.default_rng(5).random(boards)
by = (YY + offs[bi]) % 1.0
joint = (np.abs(by - 0.5) < 0.004)
seam = np.clip(np.minimum(fx, 1 - fx) / 0.03, 0, 1) * np.where(joint, 0.0, 1.0)
grain = np.sin((YY * 40 + fbm(4, 3) * 6 + bi * 1.7) * math.pi * 2) * 0.5 + 0.5
tone = np.random.default_rng(9).uniform(0.88, 1.08, boards)[bi]
s = (0.78 + 0.1 * grain + 0.1 * (vnoise(64) - 0.5)) * tone
kd1, _, _ = voronoi(rng.random((6, 2)))
knot = np.clip(1 - kd1 / 0.02, 0, 1)
s = s * (1 - 0.35 * knot)
height = seam * 0.6
s = s * (0.75 + 0.35 * light(height, 3.0))
save("planks", s, seam)

# Floor tiles: 4x4 bevelled squares.
t = 4
fx = (XX * t) % 1.0
fy = (YY * t) % 1.0
ti = (np.floor(XX * t) + np.floor(YY * t) * t).astype(int)
edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
mask = np.clip((edge - 0.02) / 0.015, 0, 1)
height = smooth(np.clip(edge / 0.12, 0, 1))
tone = np.random.default_rng(11).uniform(0.92, 1.06, t * t)[ti]
s = (0.6 + 0.5 * light(height, 4.0)) * tone * (0.95 + 0.08 * fbm(32, 3))
save("tiles", s, mask)

# Brick walls.
rows, cols = 8, 4
ry = YY * rows
ri = np.floor(ry).astype(int)
rx = XX * cols + (ri % 2) * 0.5
ci = np.floor(rx).astype(int) % cols
fx = rx % 1.0
fy = ry % 1.0
edge = np.minimum(np.minimum(fx, 1 - fx) * 2.0, np.minimum(fy, 1 - fy))
mask = np.clip((edge - 0.05) / 0.04, 0, 1)
height = smooth(np.clip(edge / 0.25, 0, 1))
tone = np.random.default_rng(13).uniform(0.88, 1.08, (rows, cols))[ri % rows, ci]
s = (0.6 + 0.5 * light(height, 4.0)) * tone * (0.92 + 0.14 * fbm(40, 3))
save("brick", s, mask)

# Plaster walls: soft trowel marks.
s = 0.86 + 0.12 * (fbm(5, 4) - 0.5) + 0.06 * (vnoise(120) - 0.5)
save("plaster", s)

# Woven fabric for rugs and carpet.
w = 48
wx = np.sin(XX * w * math.pi * 2)
wy = np.sin(YY * w * math.pi * 2)
weave = np.where((np.floor(XX * w) + np.floor(YY * w)) % 2 == 0, wx, wy) * 0.5 + 0.5
s = 0.8 + 0.12 * (weave - 0.5) + 0.08 * (fbm(12, 3) - 0.5)
save("fabric", s)

# Scalloped roof shingles: overlapping fish-scale rows, each row hanging
# over the one below it (6 x 12 rows in a square tile).
cols, rows, S, R = 6, 12, 0.5, 0.62
X = XX * cols
Y = YY * rows * S
k0 = np.floor(Y / S).astype(int)
best_h = np.zeros((N, N), np.float32)
best_m = np.zeros((N, N), np.float32)
best_id = np.zeros((N, N), np.int32)
found = np.zeros((N, N), bool)
for dk in (-2, -1, 0):  # upper rows overlap the tops of the rows below
    k = k0 + dk
    off = (k % 2) * 0.5
    dx = ((X - off) % 1.0) - 0.5
    dy = Y - k * S
    d = np.sqrt(dx * dx + dy * dy)
    ok = (d < R) & (dy >= 0) & ~found
    best_h = np.where(ok, 1 - d / R, best_h)
    best_m = np.where(ok, np.clip((R - d) / 0.05, 0, 1), best_m)
    best_id = np.where(ok, (k % rows) * cols + np.floor(X - off).astype(int) % cols, best_id)
    found |= ok
tone = np.random.default_rng(17).uniform(0.88, 1.08, rows * cols)[best_id]
s = (0.6 + 0.5 * light(smooth(best_h) * 0.8, 3.0)) * tone * (0.94 + 0.1 * fbm(30, 3))
save("shingles", s, best_m)
