"""Builds Garl's model from the CC0 KayKit Adventurers "Barbarian" rig.

Garl keeps the Barbarian's skeleton and its 76 animations, but gets a new
look: blue alien skin, red polka-dot boxers, one striped sock on his right
foot and a bare left foot. The hat, cape, weapons and mug are hidden in the
game (see scripts/garl_model.gd); antennae are added there too.

How: a new texture atlas is painted, and some parts get their UVs moved to a
different colour cell (the chest strap becomes skin, the boxers get a
wrap-around polka-dot pattern). The edited UVs and the new texture are
written into a copy of the .glb.

    python tools/make_garl.py path/to/Barbarian.glb
"""
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "characters", "garl.glb")
ATLAS = 1024
CW, CH = 128, 256  # one colour cell of the 8 x 4 atlas

SKIN = (70, 150, 235)
SKIN_DARK = (40, 95, 190)
BOXERS = (225, 45, 60)
DOTS = (255, 245, 235)
WAISTBAND = (240, 236, 228)
SOCK = (245, 240, 230)
SOCK_STRIPE = (60, 120, 230)

# Cells (column, row) we paint, and the region used for the polka dots.
SKIN_CELL = (0, 0)
BEARD_CELL = (1, 0)
SOCK_CELL = (3, 2)
DOT_REGION = (2, 3, 6, 1)  # col, row, width in cells, height in cells


def read_glb(path):
    data = open(path, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + jlen])
    bstart = 20 + jlen
    blen = struct.unpack("<I", data[bstart:bstart + 4])[0]
    binary = bytearray(data[bstart + 8:bstart + 8 + blen])
    return gltf, binary


def write_glb(path, gltf, binary):
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    binary = bytes(binary) + b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)


def accessor_view(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
    dtype = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[acc["componentType"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0)
    count = acc["count"]
    item = np.dtype(dtype).itemsize * comps
    if stride and stride != item:
        raise ValueError("interleaved buffers not supported")
    arr = np.frombuffer(binary, dtype=dtype, count=count * comps, offset=start).reshape(count, comps)
    return arr.copy(), start


def cell_of(uv):
    return (int(np.clip(uv[0], 0, 0.9999) * 8), int(np.clip(uv[1], 0, 0.9999) * 4))


def move_to_cell(uv, cell):
    """Keep the position inside the old cell but move it into another one."""
    local = np.mod(uv * [8, 4], 1.0)
    return (np.array(cell) + local) / [8, 4]


def components(faces, face_cells):
    """Connected groups of faces that share vertices and colour cell."""
    parent = list(range(len(faces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    first = {}
    for fi, f in enumerate(faces):
        for v in f:
            key = (v, face_cells[fi])
            if key in first:
                parent[find(fi)] = find(first[key])
            else:
                first[key] = fi
    groups = {}
    for fi in range(len(faces)):
        groups.setdefault(find(fi), []).append(fi)
    return list(groups.values())


def paint_atlas(src):
    img = Image.open(src).convert("RGB").resize((ATLAS, ATLAS))
    px = np.asarray(img).astype(np.float32)

    def recolor(cell, rgb, keep_shading=0.6):
        c, r = cell
        block = px[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW]
        lum = block.mean(axis=2, keepdims=True)
        shade = lum / max(lum.mean(), 1.0)
        shade = 1.0 + (shade - 1.0) * keep_shading
        px[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW] = np.clip(np.array(rgb) * shade, 0, 255)

    for cell in [SKIN_CELL, (0, 1), (1, 1), (7, 0), (7, 2)]:
        recolor(cell, SKIN)
    recolor(BEARD_CELL, SKIN_DARK)
    recolor((6, 0), WAISTBAND, 0.3)
    recolor((2, 1), WAISTBAND, 0.3)
    out = Image.fromarray(px.astype(np.uint8))

    # Striped sock.
    draw = ImageDraw.Draw(out)
    c, r = SOCK_CELL
    draw.rectangle([c * CW, r * CH, (c + 1) * CW - 1, (r + 1) * CH - 1], fill=SOCK)
    for y in range(r * CH + 20, (r + 1) * CH, 64):
        draw.rectangle([c * CW, y, (c + 1) * CW - 1, y + 18], fill=SOCK_STRIPE)

    # Polka-dot boxers fabric.
    c, r, w, h = DOT_REGION
    x0, y0, x1, y1 = c * CW, r * CH, (c + w) * CW, (r + h) * CH
    draw.rectangle([x0, y0, x1 - 1, y1 - 1], fill=BOXERS)
    rng = np.random.default_rng(3)
    step = 48
    for row, y in enumerate(range(y0 + step // 2, y1, step)):
        for x in range(x0 + (step // 2 if row % 2 else 0), x1, step):
            jx, jy = rng.integers(-3, 4, size=2)
            draw.ellipse([x + jx - 11, y + jy - 11, x + jx + 11, y + jy + 11], fill=DOTS)
    return out


def main(barbarian):
    gltf, binary = read_glb(barbarian)
    names = {i: n.get("name") for i, n in enumerate(gltf["nodes"])}
    mesh_owner = {n["mesh"]: n.get("name") for n in gltf["nodes"] if "mesh" in n}

    for mi, mesh in enumerate(gltf["meshes"]):
        owner = mesh_owner.get(mi, "")
        if not owner.startswith("Barbarian_") or owner in ("Barbarian_Hat", "Barbarian_Cape", "Barbarian_Round_Shield"):
            continue
        for prim in mesh["primitives"]:
            uv, uv_start = accessor_view(gltf, binary, prim["attributes"]["TEXCOORD_0"])
            pos, _ = accessor_view(gltf, binary, prim["attributes"]["POSITION"])
            faces, _ = accessor_view(gltf, binary, prim["indices"])
            faces = faces.reshape(-1, 3)
            face_cells = [cell_of(uv[f].mean(axis=0)) for f in faces]
            new_uv = uv.copy()
            for group in components(faces, face_cells):
                cell = face_cells[group[0]]
                verts = np.unique(faces[group].ravel())
                centre = pos[verts].mean(axis=0)
                target = None
                belt = owner == "Barbarian_Body" and (
                    (cell == (6, 0) and centre[1] <= 0.72) or cell == (3, 0) or (cell == (2, 1) and centre[1] < 0.62))
                if cell == (7, 1) or belt:
                    # Boxers: wrap a dot pattern around the hips and thighs.
                    c, r, w, h = DOT_REGION
                    p = pos[verts]
                    angle = np.arctan2(p[:, 0], p[:, 2]) / (2 * np.pi) + 0.5
                    u = (c + 0.05 * w + angle * 0.9 * w) / 8
                    v = (r + 0.05 + (0.9 - np.clip((p[:, 1] - 0.15) / 0.7, 0, 1) * 0.9)) / 4
                    new_uv[verts] = np.stack([u, v], axis=1)
                    continue
                if owner in ("Barbarian_ArmLeft", "Barbarian_ArmRight") and cell in ((6, 0), (2, 1), (3, 0)):
                    target = SKIN_CELL  # no bracers or cuffs
                elif owner == "Barbarian_Body" and cell == (6, 0):
                    target = SKIN_CELL  # the chest strap goes
                elif owner == "Barbarian_LegLeft" and cell in ((3, 2), (2, 1), (6, 0)):
                    target = SKIN_CELL  # bare alien foot
                elif owner == "Barbarian_LegRight" and cell in ((2, 1), (6, 0)):
                    target = SOCK_CELL  # the one sock
                if target is not None:
                    new_uv[verts] = move_to_cell(uv[verts], target)
            binary[uv_start:uv_start + new_uv.nbytes] = new_uv.astype(np.float32).tobytes()

    # Swap in the new texture: rebuild the binary with the new image bytes.
    atlas = paint_atlas(io.BytesIO(bytes(binary[_view_slice(gltf, gltf["images"][0]["bufferView"])])))
    buf = io.BytesIO()
    atlas.save(buf, "PNG", optimize=True)
    image_view = gltf["images"][0]["bufferView"]
    gltf["images"][0]["name"] = "garl_texture"
    gltf["materials"][0]["name"] = "garl"
    pieces = []
    offset = 0
    for vi, view in enumerate(gltf["bufferViews"]):
        chunk = buf.getvalue() if vi == image_view else bytes(binary[_view_slice(gltf, vi)])
        pad = -offset % 4
        pieces.append(b"\0" * pad)
        offset += pad
        view["byteOffset"] = offset
        view["byteLength"] = len(chunk)
        pieces.append(chunk)
        offset += len(chunk)
    gltf["buffers"][0]["byteLength"] = offset
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    write_glb(OUT, gltf, b"".join(pieces))
    print("wrote", os.path.abspath(OUT), [names[i] for i in range(3)])


def _view_slice(gltf, index):
    view = gltf["bufferViews"][index]
    start = view.get("byteOffset", 0)
    return slice(start, start + view["byteLength"])


if __name__ == "__main__":
    main(sys.argv[1])
