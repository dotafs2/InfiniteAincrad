"""Diagnostic: print world bounding boxes of the cottage shell/roof parts (no export, no render)."""
import importlib.util
import json
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("modular_builder", HERE / "build_modular_houses.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def bbox(obj):
    from mathutils import Vector
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for corner in obj.bound_box:
        world = obj.matrix_world @ Vector(corner)
        for axis in range(3):
            low[axis] = min(low[axis], world[axis])
            high[axis] = max(high[axis], world[axis])
    return [round(v, 3) for v in low], [round(v, 3) for v in high]


builder.reset_scene()
house = builder.SPECS[sys.argv[-1] if sys.argv[-1] in builder.SPECS else "01_hearth_cottage"]
collection = builder.new_collection("Diag")
shell = builder.build_walls(collection, house)
roof = builder.build_roof(collection, house)
wall_top = house["floors"] * house["floor_h"]
out = {"variant": house["name_zh"], "wall_top": wall_top,
       "expected_ridge_z": wall_top + house["roof_rise"],
       "expected_eave_y": house["depth"] * 0.5}
for obj in collection.objects:
    if obj.type == "MESH":
        low, high = bbox(obj)
        out[obj.name] = {"min": low, "max": high}
print("GEOMETRY_DIAG " + json.dumps(out))
