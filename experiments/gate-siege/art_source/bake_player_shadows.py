"""Bake directional player silhouettes from the actual mobile GLB triangles.

Requires Pillow. No renderer, Blender, source model changes, or GPU work.
Run from any directory: python3 art_source/bake_player_shadows.py
"""

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, default=ROOT / "assets/mobile")
parser.add_argument("--out", type=Path)
args = parser.parse_args()
SOURCE = args.source.resolve()
OUT = args.out.resolve() if args.out else SOURCE / "shadows"
KINDS = ("infantry", "gunner", "mech")
RESOLUTION = 256
SUPERSAMPLE = 4
SUN_DEGREES = (-53.0, -32.0, 0.0)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb_triangles(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
    chunks = {}
    offset = 12
    while offset < length:
        size, kind = struct.unpack_from("<II", data, offset)
        chunks[kind] = data[offset + 8:offset + 8 + size]
        offset += 8 + size
    doc = json.loads(chunks[0x4E4F534A])
    binary = chunks[0x004E4942]
    formats = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
    counts = {"SCALAR": 1, "VEC3": 3}

    def accessor(index):
        access = doc["accessors"][index]
        assert "sparse" not in access
        view = doc["bufferViews"][access["bufferView"]]
        assert view.get("buffer", 0) == 0
        fmt = "<" + formats[access["componentType"]] * counts[access["type"]]
        step = view.get("byteStride", struct.calcsize(fmt))
        start = view.get("byteOffset", 0) + access.get("byteOffset", 0)
        return [struct.unpack_from(fmt, binary, start + i * step)
                for i in range(access["count"])]

    triangles = []
    bounds_points = []
    # The mobile builder exports one joined mesh at the feet with applied TRS.
    # Reject a changed coordinate contract instead of silently baking it wrong.
    for node in doc["nodes"]:
        assert not any(key in node for key in ("matrix", "translation", "rotation", "scale", "skin"))
        if "mesh" not in node:
            continue
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            assert primitive.get("mode", 4) == 4
            vertices = accessor(primitive["attributes"]["POSITION"])
            indices = [value[0] for value in accessor(primitive["indices"])]
            assert len(indices) % 3 == 0
            triangles.extend(tuple(vertices[index] for index in indices[i:i + 3])
                             for i in range(0, len(indices), 3))
            bounds_points.extend(vertices)
    bounds = {
        "min": [min(point[i] for point in bounds_points) for i in range(3)],
        "max": [max(point[i] for point in bounds_points) for i in range(3)],
    }
    return triangles, bounds


def bake(kind, projection):
    source_path = SOURCE / (kind + ".glb")
    source_hash = sha(source_path)
    triangles, bounds = glb_triangles(source_path)
    height = bounds["max"][1]
    assert abs(bounds["min"][1]) < 0.001, "Feet must remain within one millimeter of the ground origin"
    projected = [tuple((x + projection[0] * y, z + projection[1] * y)
                       for x, y, z in triangle) for triangle in triangles]
    lo = [min(point[i] for tri in projected for point in tri) for i in range(2)]
    hi = [max(point[i] for tri in projected for point in tri) for i in range(2)]
    blur_world = height * 0.012
    pad = 4.0 * blur_world + max(hi[i] - lo[i] for i in range(2)) * 2.0 / RESOLUTION
    plane_min = [value - pad for value in lo]
    plane_max = [value + pad for value in hi]
    size = [plane_max[i] - plane_min[i] for i in range(2)]
    center = [(plane_max[i] + plane_min[i]) * 0.5 for i in range(2)]
    # Godot PlaneMesh maps +X to +U and +Z to +V. Image top is V=0.
    # Use square world pixels before resizing into the 256x256 asset so the
    # penumbra remains the same width along both world axes.
    density = RESOLUTION * SUPERSAMPLE / max(size)
    high_size = tuple(max(1, round(extent * density)) for extent in size)
    mask = Image.new("L", high_size)
    draw = ImageDraw.Draw(mask)
    for triangle in projected:
        draw.polygon([((x - plane_min[0]) / size[0] * (high_size[0] - 1),
                       (z - plane_min[1]) / size[1] * (high_size[1] - 1))
                      for x, z in triangle], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(blur_world * density))
    mask = mask.resize((RESOLUTION, RESOLUTION), Image.Resampling.LANCZOS)
    # Four-sigma padding leaves a fully transparent border after filtering.
    border_max = max(mask.crop((0, 0, RESOLUTION, 1)).getextrema()[1],
                     mask.crop((0, RESOLUTION - 1, RESOLUTION, RESOLUTION)).getextrema()[1],
                     mask.crop((0, 0, 1, RESOLUTION)).getextrema()[1],
                     mask.crop((RESOLUTION - 1, 0, RESOLUTION, RESOLUTION)).getextrema()[1])
    assert border_max == 0, (kind, border_max)
    assert mask.getextrema() == (0, 255)
    image = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    image.putalpha(mask)
    path = OUT / (kind + ".png")
    image.save(path, optimize=True)
    assert sha(source_path) == source_hash
    entry = {
        "texture": "res://" + path.relative_to(ROOT).as_posix(),
        "source": "res://" + source_path.relative_to(ROOT).as_posix(),
        "source_sha256": source_hash,
        "texture_sha256": sha(path),
        "source_triangles": len(triangles),
        "source_bounds": bounds,
        "projected_bounds_xz": {"min": lo, "max": hi},
        "plane_bounds_xz": {"min": plane_min, "max": plane_max},
        "size": size,
        "center": center,
        "blur_sigma_native_units": blur_world,
        "padding_native_units": pad,
        "alpha_range": [0, 255],
        "border_alpha_max": border_max,
        "texture_size": [RESOLUTION, RESOLUTION],
        "opaque_coverage_fraction": sum(mask.histogram()[128:]) / (RESOLUTION ** 2),
        "current_player_uniform_scale": (0.9 if kind == "mech" else 1.65) if SOURCE == ROOT / "assets/mobile" else "Runtime-dependent squad scale; see scripts/squad.gd",
    }
    return entry


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pitch, yaw, roll = (math.radians(value) for value in SUN_DEGREES)
    assert roll == 0.0
    # Godot DirectionalLight3D sends rays along -Basis.z (Euler order YXZ).
    ray = [-math.sin(yaw) * math.cos(pitch), math.sin(pitch),
           -math.cos(yaw) * math.cos(pitch)]
    projection = [-ray[0] / ray[1], -ray[2] / ray[1]]
    assert projection[0] > 0 and projection[1] < 0
    entries = {kind: bake(kind, projection) for kind in KINDS}
    manifest = {
        "builder": "art_source/bake_player_shadows.py",
        "kind": "Directional triangle-union shadows, static grounded hero pose",
        "sun_rotation_degrees": list(SUN_DEGREES),
        "godot_euler_order": "YXZ",
        "sun_ray_direction": ray,
        "projection_xz_per_height": projection,
        "projection_equation": "ground_xz = vertex_xz + projection_xz_per_height * vertex_y",
        "coordinates": "Godot Y-up, model faces -Z, native model feet at (0,0,0)",
        "uv_convention": "PlaneMesh horizontal: U=0 at min X, V=0 at min Z; PNG top row is V=0",
        "rgba": "RGB white, alpha 0..1 silhouette coverage; runtime shader supplies tint and opacity",
        "placement": "Unrotated horizontal PlaneMesh. Size = size * uniform_model_scale. Center XZ = actor_ground_xz + center * uniform_model_scale. Ground Y + a small offset. Do not inherit animated tilt or height.",
        "limitations": "Static grounded pose, fixed sun and -Z hero orientation; flying rotating heroes require their separate projected oval.",
        "models": entries,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    lines = ["# Generated by art_source/bake_player_shadows.py; native GLB feet-origin units.",
             "# PlaneMesh U increases with X; V increases with Z. Scale center and size together.",
             "extends RefCounted", "", "const DATA := {"]
    for kind, entry in entries.items():
        lines.extend([
            f'    "{kind}": {{',
            f'        "texture": preload("{entry["texture"]}"),',
            f'        "size": Vector2({entry["size"][0]:.9f}, {entry["size"][1]:.9f}),',
            f'        "center": Vector2({entry["center"][0]:.9f}, {entry["center"][1]:.9f}),',
            "    },",
        ])
    lines.extend(["}", ""])
    (OUT / "footprints.gd").write_text("\n".join(lines))
    print(json.dumps({kind: {key: entry[key] for key in
                           ("size", "center", "source_triangles", "alpha_range", "border_alpha_max")}
                      for kind, entry in entries.items()}, indent=2))


if __name__ == "__main__":
    main()
