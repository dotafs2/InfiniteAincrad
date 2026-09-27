"""Export the actor point layout with the local Houdini Python runtime.

This is deliberately a point-only bridge: Houdini owns deterministic district
placement and attributes, while Godot owns the lightweight runtime geometry and
physics. It does not modify the user's open Houdini scene.
"""
import json
import math
from pathlib import Path

import hou


ROOT = Path(r"C:\InfiniteAincrad")
PROJECT = ROOT / "experiments" / "hole-city"
RECIPES = PROJECT / "assets" / "world_actors" / "recipes.json"
OUT_JSON = PROJECT / "assets" / "world_actors" / "houdini_layout.json"
OUT_BGEO = ROOT / "tmp" / "houdini-initial-city" / "hole_city_actor_layout.bgeo.sc"

try:
    hou.setMaxThreads(2)
except Exception:
    pass

data = json.loads(RECIPES.read_text(encoding="utf-8"))
actors = data["actors"]
districts = {item["id"]: index for index, item in enumerate(data["districts"])}
geo = hou.Geometry()
actor_id_attrib = geo.addAttrib(hou.attribType.Point, "actor_id", "")
actor_type_attrib = geo.addAttrib(hou.attribType.Point, "actor_type", "")
district_attrib = geo.addAttrib(hou.attribType.Point, "district", "")
recipe_hash_attrib = geo.addAttrib(hou.attribType.Point, "recipe_sha256", "")
seed_attrib = geo.addAttrib(hou.attribType.Point, "seed", int(data["seed"]))

layout = []
for index, actor in enumerate(actors):
    district_index = districts[actor["district"]]
    angle = math.tau * district_index / len(data["districts"])
    center_radius = 42.0 + (district_index % 3) * 3.5
    center_x = math.cos(angle) * center_radius
    center_z = math.sin(angle) * center_radius
    local_x = (index % 5 - 2) * 2.15
    local_z = (index % 2 - 0.5) * 3.4
    x = center_x + local_x * math.cos(angle) - local_z * math.sin(angle)
    z = center_z + local_x * math.sin(angle) + local_z * math.cos(angle)
    point = geo.createPoint()
    point.setPosition((x, 0.0, z))
    point.setAttribValue(actor_id_attrib, actor["id"])
    point.setAttribValue(actor_type_attrib, actor["name"])
    point.setAttribValue(district_attrib, actor["district"])
    point.setAttribValue(recipe_hash_attrib, actor["geometry_recipe_sha256"])
    point.setAttribValue(seed_attrib, int(data["seed"]))
    layout.append({
        "id": actor["id"],
        "type": actor["name"],
        "district": actor["district"],
        "position": [round(x, 4), round(z, 4)],
        "recipe_sha256": actor["geometry_recipe_sha256"],
        "pcg_class": "actor",
        "seed": int(data["seed"]),
    })

OUT_JSON.write_text(json.dumps({
    "schema": "hole-city-houdini-actor-layout-v1",
    "generator": "Houdini HOM / hython",
    "seed": int(data["seed"]),
    "district_count": len(data["districts"]),
    "actor_count": len(layout),
    "actors": layout,
}, indent=2) + "\n", encoding="utf-8")
OUT_BGEO.parent.mkdir(parents=True, exist_ok=True)
geo.saveToFile(str(OUT_BGEO))
print(json.dumps({"output": str(OUT_JSON), "bgeo": str(OUT_BGEO), "actors": len(layout), "districts": len(data["districts"]) }))
