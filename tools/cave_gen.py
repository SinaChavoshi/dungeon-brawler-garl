"""Generates the cave meshes for Dungeon Brawler Garl.

The caves are signed distance fields (tunnels = squashed capsules, chambers =
ellipsoids, stalactites/stalagmites = cones) roughened with noise, then meshed
with marching cubes. Each cave is written as a .glb (with baked ambient
occlusion in the vertex colors) plus a .json with gameplay data: map cells,
torch spots, spawn points, and so on.

Run:  python tools/cave_gen.py   (needs numpy, scikit-image, trimesh)
"""
import json
import os
import numpy as np
from skimage.measure import marching_cubes
import trimesh

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "cave")
SPACING = 0.33
MAP_CELL = 2.0


# --- Noise -------------------------------------------------------------------

class Noise:
    def __init__(self, seed):
        rng = np.random.default_rng(seed)
        perm = rng.permutation(256)
        self.perm = np.concatenate([perm, perm])
        self.vals = rng.random(256) * 2.0 - 1.0

    def _hash(self, ix, iy, iz):
        p = self.perm
        return self.vals[p[(p[(p[ix & 255] + iy) & 255] + iz) & 255]]

    def value(self, x, y, z):
        xi, yi, zi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
        xf, yf, zf = x - xi, y - yi, z - zi
        u, v, w = (t * t * (3 - 2 * t) for t in (xf, yf, zf))
        out = 0.0
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    weight = (u if dx else 1 - u) * (v if dy else 1 - v) * (w if dz else 1 - w)
                    out = out + weight * self._hash(xi + dx, yi + dy, zi + dz)
        return out

    def fbm(self, x, y, z, octaves=4):
        total, amp, freq = 0.0, 0.5, 1.0
        for _ in range(octaves):
            total = total + amp * self.value(x * freq, y * freq, z * freq)
            amp *= 0.5
            freq *= 2.03
        return total


# --- SDF shapes (negative = open air) -----------------------------------------

def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def tunnel(x, y, z, a, b, half_width, height, center_y=0.6):
    """Squashed capsule along the XZ segment a->b."""
    ax, az = a
    bx, bz = b
    px, pz = x - ax, z - az
    dx, dz = bx - ax, bz - az
    t = np.clip((px * dx + pz * dz) / (dx * dx + dz * dz), 0.0, 1.0)
    hx, hz = px - t * dx, pz - t * dz
    horiz = np.sqrt(hx * hx + hz * hz)
    return (np.sqrt((horiz / half_width) ** 2 + ((y - center_y) / height) ** 2) - 1.0) * half_width


def chamber(x, y, z, center, radii):
    cx, cy, cz = center
    rx, ry, rz = radii
    k = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2)
    return (k - 1.0) * min(rx, rz) * 0.75


def stalagmite(x, y, z, at, radius, tip):
    """Rock cone pointing up from the floor. Positive inside rock, as an SDF of the cone."""
    h = np.sqrt((x - at[0]) ** 2 + (z - at[1]) ** 2)
    allowed = radius * np.clip((tip - y) / tip, 0.0, 1.0)
    return np.maximum(h - allowed, y - tip) * 0.7


def stalactite(x, y, z, at, radius, bottom, top):
    h = np.sqrt((x - at[0]) ** 2 + (z - at[1]) ** 2)
    allowed = radius * np.clip((y - bottom) / (top - bottom), 0.0, 1.0)
    return np.maximum(h - allowed, bottom - y) * 0.7


# --- Cave definitions ------------------------------------------------------------

class Cave:
    def __init__(self, name, seed, bounds):
        self.name = name
        self.noise = Noise(seed)
        self.bounds = bounds  # (xmin, xmax, ymin, ymax, zmin, zmax)
        self.tunnels = []      # (a, b, half_width, height)
        self.chambers = []     # (center, radii)
        self.mites = []        # stalagmites (at, radius, tip)
        self.tites = []        # stalactites (at, radius, bottom, top)
        self.data = {}

    def sdf(self, x, y, z):
        # Floor: air only above a gently uneven ground plane.
        ground = 0.07 * self.noise.fbm(x * 0.6, 0.0, z * 0.6, 2)
        return np.maximum(self.walls(x, y, z), -(y - ground))

    def walls(self, x, y, z):
        """Distance to the rock walls and ceiling, ignoring the floor."""
        d = np.full(x.shape, 1e3)
        for a, b, w, h in self.tunnels:
            d = smin(d, tunnel(x, y, z, a, b, w, h), 1.2)
        for c, r in self.chambers:
            d = smin(d, chamber(x, y, z, c, r), 2.0)
        # Rough up the walls; keep the floor walkable.
        wall_amp = 0.45 + 0.55 * np.clip(y / 1.6, 0.0, 1.0)
        d = d + wall_amp * 0.85 * self.noise.fbm(x * 0.32, y * 0.32, z * 0.32, 4)
        d = d + 0.18 * self.noise.fbm(x * 1.3 + 31.0, y * 1.3, z * 1.3, 2)
        for at, radius, tip in self.mites:
            d = np.maximum(d, -stalagmite(x, y, z, at, radius, tip))
        for at, radius, bottom, top in self.tites:
            d = np.maximum(d, -stalactite(x, y, z, at, radius, bottom, top))
        return d

    def scatter(self, seed, count, near=(-1.1, -0.25)):
        """Random floor spots close to the walls, for rubble: [x, z, size]."""
        rng = np.random.default_rng(seed)
        x0, x1, _, _, z0, z1 = self.bounds
        spots = []
        for _ in range(count * 60):
            if len(spots) >= count:
                break
            x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)
            d = self.walls(np.array([x]), np.array([0.4]), np.array([z]))[0]
            if near[0] < d < near[1]:
                spots.append([round(float(x), 2), round(float(z), 2), round(float(rng.uniform(0.25, 0.7)), 2)])
        return spots

    def crystal_spots(self, center, angles, y=0.5):
        spots = [self.wall_spot(center, (np.cos(a), np.sin(a)), y=y) for a in angles]
        return [s for s in spots if abs(s["normal"][1]) < 0.7]

    def build(self):
        x0, x1, y0, y1, z0, z1 = self.bounds
        xs = np.arange(x0, x1 + SPACING, SPACING)
        ys = np.arange(y0, y1 + SPACING, SPACING)
        zs = np.arange(z0, z1 + SPACING, SPACING)
        X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
        field = self.sdf(X, Y, Z)
        # Close the volume at the bounds so the mesh is watertight-ish.
        field[0, :, :] = field[-1, :, :] = 1.0
        field[:, -1, :] = 1.0
        field[:, :, 0] = field[:, :, -1] = 1.0
        verts, faces, _normals, _ = marching_cubes(field, level=0.0, spacing=(SPACING,) * 3)
        verts += np.array([x0, y0, z0])

        normals = self._air_normals(verts)
        # Orient each triangle so its front faces the open air.
        tri = verts[faces]
        geo = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        want = normals[faces].sum(axis=1)
        flip = (geo * want).sum(axis=1) < 0
        faces[flip] = faces[flip][:, ::-1]

        # Baked ambient occlusion: how open is the space just off the surface?
        probe = verts + normals * 0.9
        ao = np.clip(-self.sdf(probe[:, 0], probe[:, 1], probe[:, 2]) / 0.9, 0.0, 1.0)
        ao = 0.3 + 0.7 * ao ** 0.8
        tint = 0.5 + 0.5 * self.noise.fbm(verts[:, 0] * 0.15, verts[:, 1] * 0.15, verts[:, 2] * 0.15, 2)
        colors = np.stack([ao, ao, ao, np.clip(tint + 0.5, 0, 1)], axis=1)
        colors = (np.clip(colors, 0, 1) * 255).astype(np.uint8)

        mesh = trimesh.Trimesh(vertices=verts, faces=faces, vertex_normals=normals,
                               vertex_colors=colors, process=False)
        scene = trimesh.Scene()
        scene.add_geometry(mesh, node_name="cave", geom_name="cave")
        os.makedirs(OUT, exist_ok=True)
        scene.export(os.path.join(OUT, self.name + ".glb"))

        self.data["map_cells"] = self._map_cells()
        self.data["bounds"] = [x0, z0, x1 - x0, z1 - z0]
        with open(os.path.join(OUT, self.name + ".json"), "w") as f:
            json.dump(self.data, f, indent=1)
        print(f"{self.name}: {len(verts)} verts, {len(faces)} tris, {len(self.data['map_cells'])} map cells")

    def _air_normals(self, p):
        e = 0.05
        def f(dx, dy, dz):
            return self.sdf(p[:, 0] + dx, p[:, 1] + dy, p[:, 2] + dz)
        g = np.stack([f(e, 0, 0) - f(-e, 0, 0), f(0, e, 0) - f(0, -e, 0), f(0, 0, e) - f(0, 0, -e)], axis=1)
        g = -g  # point into the air
        return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-6)

    def _map_cells(self):
        x0, x1, _, _, z0, z1 = self.bounds
        cells = []
        for cx in range(int(np.floor(x0 / MAP_CELL)), int(np.ceil(x1 / MAP_CELL))):
            for cz in range(int(np.floor(z0 / MAP_CELL)), int(np.ceil(z1 / MAP_CELL))):
                px = np.array([(cx + 0.5) * MAP_CELL])
                pz = np.array([(cz + 0.5) * MAP_CELL])
                if self.sdf(px, np.array([0.8]), pz)[0] < -0.3:
                    cells.append([cx, cz])
        return cells

    def wall_spot(self, origin, direction, y=2.1, max_dist=20.0):
        """March from an open-air point toward a wall; return a spot just off it."""
        o = np.array([origin[0], y, origin[1]], dtype=float)
        d = np.array([direction[0], 0.0, direction[1]], dtype=float)
        d /= np.linalg.norm(d)
        t = 0.0
        while t < max_dist:
            p = o + d * t
            if self.sdf(p[0:1], p[1:2], p[2:3])[0] > 0:
                break
            t += 0.1
        p = o + d * max(t - 0.25, 0.0)
        n = self._air_normals(p[None, :])[0]
        return {"pos": [round(float(v), 3) for v in p], "normal": [round(float(v), 3) for v in n]}


def level1():
    """The Tunnel (winding, narrow) opening into the Training Room chamber."""
    cave = Cave("level1", seed=7, bounds=(-17.0, 17.0, -0.6, 8.5, -24.0, 27.0))
    path = [(0.0, 24.5), (1.4, 18.0), (-1.2, 12.0), (0.8, 6.0), (0.0, -2.0)]
    for a, b in zip(path, path[1:]):
        cave.tunnels.append((a, b, 2.4, 3.5))
    cave.chambers.append(((0.0, 0.2, -10.5), (14.0, 7.5, 10.5)))
    cave.chambers.append(((-9.5, 0.2, -16.0), (5.0, 4.5, 4.5)))   # side alcove
    cave.chambers.append(((10.0, 0.2, -4.5), (4.5, 4.0, 4.0)))    # side alcove
    for at, r, tip in [((-11.0, -6.0), 1.1, 3.2), ((11.5, -14.0), 1.3, 3.8), ((-5.0, -19.0), 0.9, 2.2),
                       ((7.0, -18.5), 1.0, 2.6), ((-12.0, -12.5), 0.8, 1.8), ((2.0, 21.5), 0.5, 0.9)]:
        cave.mites.append((at, r, tip))
    for at, r, bottom, top in [((-4.0, -6.0), 0.8, 4.6, 9.0), ((5.0, -13.0), 1.0, 4.2, 9.0),
                               ((-7.5, -14.0), 0.7, 4.8, 9.0), ((0.5, -16.0), 0.9, 5.0, 9.0),
                               ((0.0, 15.0), 0.45, 2.8, 5.0), ((-0.5, 8.5), 0.4, 3.0, 5.0)]:
        cave.tites.append((at, r, bottom, top))
    torches = []
    for i, (a, b) in enumerate(zip(path, path[1:])):
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        dx, dz = b[0] - a[0], b[1] - a[1]
        side = (dz, -dx) if i % 2 == 0 else (-dz, dx)
        torches.append(cave.wall_spot(mid, side))
    for angle in np.linspace(0, 2 * np.pi, 8, endpoint=False):
        if abs(angle - np.pi / 2) < 0.3:  # skip where the tunnel enters (south)
            continue
        torches.append(cave.wall_spot((0.0, -10.5), (np.cos(angle), np.sin(angle)), y=2.4))
    crystals = cave.crystal_spots((0.0, -10.5), np.linspace(0, 2 * np.pi, 6, endpoint=False) + 0.45)
    crystals.append(cave.wall_spot((-1.2, 12.0), (1.0, 0.0), y=0.5))
    cave.data.update({
        "spawn": [0.0, 22.0],
        "torches": torches,
        "crystals": crystals,
        "rubble": cave.scatter(70, 90),
    })
    cave.build()


def arena(name, seed):
    """Floors 2+: a big chamber with a couple of alcoves and a dead-end tunnel."""
    rng = np.random.default_rng(seed)
    cave = Cave(name, seed=seed, bounds=(-19.0, 19.0, -0.6, 9.0, -19.0, 21.0))
    cave.chambers.append(((0.0, 0.2, 0.0), (rng.uniform(11, 13.5), 7.0, rng.uniform(11, 13.5))))
    for _ in range(3):
        ang = rng.uniform(0, 2 * np.pi)
        dist = rng.uniform(9, 12)
        cave.chambers.append(((np.cos(ang) * dist, 0.2, np.sin(ang) * dist * 0.9),
                              (rng.uniform(3.5, 5.5), rng.uniform(3.5, 5), rng.uniform(3.5, 5.5))))
    cave.tunnels.append(((0.0, 10.0), (rng.uniform(-3, 3), 18.5), 2.4, 3.4))
    for _ in range(5):
        ang = rng.uniform(0, 2 * np.pi)
        dist = rng.uniform(4, 9)
        cave.mites.append(((np.cos(ang) * dist, np.sin(ang) * dist), rng.uniform(0.6, 1.2), rng.uniform(1.4, 3.5)))
    for _ in range(6):
        ang = rng.uniform(0, 2 * np.pi)
        dist = rng.uniform(2, 9)
        cave.tites.append(((np.cos(ang) * dist, np.sin(ang) * dist), rng.uniform(0.5, 1.0), rng.uniform(4.5, 5.5), 9.0))
    torches = [cave.wall_spot((0.0, 0.0), (np.cos(a), np.sin(a)), y=2.4)
               for a in np.linspace(0, 2 * np.pi, 7, endpoint=False) + 0.3]
    torches.append(cave.wall_spot((0.0, 14.0), (1.0, 0.0)))
    cave.data.update({
        "spawn": [0.0, 16.0],
        "torches": torches,
        "crystals": cave.crystal_spots((0.0, 0.0), np.linspace(0, 2 * np.pi, 5, endpoint=False) + rng.uniform(0, 1)),
        "rubble": cave.scatter(seed + 1, 80),
    })
    cave.build()
    # Gameplay spots, only where there's open floor well away from walls.
    open_spots = []
    for _ in range(400):
        p = rng.uniform(-14, 14, size=2)
        # Sample above the floor plane (which would cap the distance at y).
        d = cave.sdf(np.array([p[0]]), np.array([1.7]), np.array([p[1]]))[0]
        if d < -1.4:
            open_spots.append([round(float(p[0]), 2), round(float(p[1]), 2)])
    cave.data["open_spots"] = open_spots
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(cave.data, f, indent=1)


if __name__ == "__main__":
    level1()
    for i, seed in enumerate([11, 23, 42]):
        arena(f"arena_{i}", seed)
