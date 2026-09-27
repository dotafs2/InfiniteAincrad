"""Generate seeded layouts with the original Epic City Sample Houdini HDAs.

Run with Houdini's Python, not the system Python:

    $env:HOUDINI_MAXTHREADS = '2'
    $env:HOUDINI_OTLSCAN_PATH = 'C:/.../Small_City/houdini/otls;&'
    E:/houdini/bin/hython.exe generate_citysample_layout_gallery.py

The source HIP is loaded read-only in memory.  The script uses the official
City Layout HDA and exports only lightweight JSON geometry for a separate
overview renderer.  It deliberately does not press the City Processor cache
buttons, so the restored reference caches stay untouched.
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import hou


ROOT = Path(__file__).resolve().parents[3]
SOURCE_HIP = ROOT / "tmp" / "citysample-source" / "Small_City" / "Small_City.hip"
HDA_DIR = SOURCE_HIP.parent / "houdini" / "otls"
OUT = ROOT / "tmp" / "citysample-layout-gallery"
SEEDS = (17, 43, 71, 103, 149)


def vec2(point):
    pos = point.position()
    return [round(float(pos[0]), 4), round(float(pos[2]), 4)]


def primitive_points(prim):
    return [vec2(vertex.point()) for vertex in prim.vertices()]


def primitive_value(prim, name, default=None):
    try:
        value = prim.attribValue(name)
        if isinstance(value, (int, float, str, bool)):
            return value
        if hasattr(value, "__iter__"):
            return list(value)
        return value
    except Exception:
        return default


def point_value(point, name, default=None):
    try:
        value = point.attribValue(name)
        if isinstance(value, (int, float, str, bool)):
            return value
        if hasattr(value, "__iter__"):
            return list(value)
        return value
    except Exception:
        return default


def generate_boundary(seed):
    rng = random.Random(seed)
    count = rng.choice((8, 9, 10))
    phase = rng.uniform(-0.16, 0.16)
    aspect_x = rng.uniform(0.86, 1.16)
    aspect_z = rng.uniform(0.82, 1.12)
    center_x = rng.uniform(-110.0, 110.0)
    center_z = rng.uniform(-90.0, 90.0)
    points = []
    for index in range(count):
        angle = 2.0 * math.pi * index / count + phase + rng.uniform(-0.09, 0.09)
        radius = rng.uniform(545.0, 790.0)
        points.append(
            [
                round(center_x + math.cos(angle) * radius * aspect_x, 4),
                round(center_z + math.sin(angle) * radius * aspect_z, 4),
            ]
        )
    return points


def set_source_curve(curve, boundary):
    coords = " ".join(f"{x:g},0,{z:g}" for x, z in boundary) + " "
    curve.parm("coords").set(coords)
    curve.parm("close").set(1)
    curve.parm("reverse").set(0)
    curve.cook(force=True)


def set_layout_parameters(layout, seed):
    rng = random.Random(seed * 31 + 7)
    parameters = {
        "density": rng.choice((80.0, 96.0, 112.0, 128.0, 144.0, 176.0)),
        "road_crea_threshold": round(rng.uniform(0.13, 0.30), 4),
        "max_block_lenght_x": rng.choice((70, 90, 110, 130, 150)),
        "max_block_lenght_z": rng.choice((90, 120, 150, 180, 210)),
        "min_width_close": rng.choice((120.0, 150.0, 180.0)),
        "merging_blocks": round(rng.uniform(0.0, 0.22), 4),
        "merging_block_seed": seed % 10,
        "road_block_size": rng.choice((16, 20, 24, 28)),
    }
    for name, value in parameters.items():
        parm = layout.parm(name)
        if parm is not None:
            parm.set(value)
    return parameters


def serialize_layout(layout, boundary, seed, parameters, freeway):
    preview = layout.geometry(0)
    roads = layout.geometry(1)
    lots = []
    for prim in preview.prims():
        points = primitive_points(prim)
        if len(points) >= 3:
            lots.append(points)
    road_data = []
    for prim in roads.prims():
        points = primitive_points(prim)
        if len(points) < 2:
            continue
        first_point = list(prim.vertices())[0].point()
        road_data.append(
            {
                "points": points,
                "class": primitive_value(prim, "class", 0),
                "width": point_value(first_point, "width", 12.0),
                "name": primitive_value(prim, "name", "Road_A"),
            }
        )
    return {
        "schema": "citysample-layout-gallery-v1",
        "source": "Epic Games City Sample / Small_City / City Layout HDA",
        "source_hip": str(SOURCE_HIP),
        "hda_directory": str(HDA_DIR),
        "seed": seed,
        "parameters": parameters,
        "boundary": boundary,
        "lots": lots,
        "roads": road_data,
        "freeway_curve_attributes": freeway,
        "stats": {"blocks": len(lots), "road_segments": len(road_data)},
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    hou.setUpdateMode(hou.updateMode.AutoUpdate)
    hou.hipFile.load(str(SOURCE_HIP), suppress_save_prompt=True, ignore_load_warnings=True)
    layout = hou.node("/obj/Small_City/layout2")
    curve = hou.node("/obj/Small_City/curve2")
    freeway_node = hou.node("/obj/Small_City/curve_attributes2")
    if not layout or not curve:
        raise RuntimeError("Official Small_City City Layout nodes were not found")
    if layout.type().definition() is None or "City_Layout.hda" not in layout.type().definition().libraryFilePath():
        raise RuntimeError("City_Layout.hda was not loaded; set HOUDINI_OTLSCAN_PATH before running")

    freeway_node.cook(force=True)
    freeway = [vec2(point) for point in freeway_node.geometry().points()] if freeway_node else []
    manifest = []
    for seed in SEEDS:
        boundary = generate_boundary(seed)
        set_source_curve(curve, boundary)
        parameters = set_layout_parameters(layout, seed)
        layout.cook(force=True)
        data = serialize_layout(layout, boundary, seed, parameters, freeway)
        target = OUT / f"citysample_map_{seed:03d}.json"
        target.write_text(json.dumps(data, indent=2), encoding="utf-8")
        manifest.append({"seed": seed, "file": target.name, **data["stats"]})
        print(json.dumps({"seed": seed, **data["stats"]}))
    (OUT / "manifest.json").write_text(
        json.dumps(
            {
                "schema": "citysample-layout-gallery-manifest-v1",
                "source": str(SOURCE_HIP),
                "maps": manifest,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"output": str(OUT), "maps": len(manifest)}))


if __name__ == "__main__":
    main()
