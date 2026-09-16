"""Offline Blender LOD build for the three immutable Meshy 7 house trials.

Run from the repository root:
  D:/SteamLibrary/steamapps/common/Blender/blender.exe --background --factory-startup \
    --python tools/build_meshy_house_lods.py -- --house 01_hearth_cottage

Without --house, builds all three. --preview-house selects the one source/LOD0
pair rendered from the same camera (default cottage); --no-preview skips it.
The exported GLB has three named mesh nodes and one shared imported material.
All file hashes, mesh counts, UV checks, bounds and GLB structure are measured
from actual data. The source files are read only and rehashed after export.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE_MANIFEST = ROOT / "Art/Generated/MeshyHouses20260916/manifest.json"
REMESH_REPORT = ROOT / "exports/floor1-art-20260916/remesh-preview/render-report.json"
REMESH_RECEIPTS = ROOT / "tmp/floor1-art-20260916/remesh"
DEST = ROOT / "game/assets/floor1/meshy_houses_lod"
EVIDENCE = ROOT / "Art/Generated/MeshyHouseLods20260916"
TMP = ROOT / "tmp/floor1-art-20260916/lod"
TARGETS = (40000, 12000, 3000)
HEIGHTS = {"01_hearth_cottage": 10.0, "02_market_house": 11.5, "03_corner_turret": 12.0}
YAW = {"01_hearth_cottage": 0.0, "02_market_house": 0.0, "03_corner_turret": 90.0}


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--house", action="append", choices=list(HEIGHTS))
    parser.add_argument("--preview-house", choices=list(HEIGHTS), default="01_hearth_cottage")
    parser.add_argument("--no-preview", action="store_true")
    parser.add_argument("--preview-size", type=int, default=640)
    parser.add_argument("--source-dir", default="exports/meshy-houses-20260916/models")
    parser.add_argument("--source-kind", choices=["raw-highpoly", "meshy-quad-remesh"], default="raw-highpoly")
    return parser.parse_args(argv)


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_glb(path: Path) -> dict:
    with path.open("rb") as stream:
        magic, version, total = struct.unpack("<4sII", stream.read(12))
        assert magic == b"glTF" and version == 2 and total == path.stat().st_size
        size, chunk_type = struct.unpack("<I4s", stream.read(8))
        assert chunk_type == b"JSON"
        return json.loads(stream.read(size))


def inspect_glb(path: Path) -> dict:
    doc = read_glb(path)
    nodes = doc.get("nodes", [])
    mesh_rows = []
    for node in nodes:
        if "mesh" not in node:
            continue
        gltf_mesh = doc["meshes"][node["mesh"]]
        count = 0
        verts = 0
        for primitive in gltf_mesh["primitives"]:
            assert primitive.get("mode", 4) == 4, "Expected triangles"
            accessor = doc["accessors"][primitive["indices"]]
            assert accessor["count"] % 3 == 0
            count += accessor["count"] // 3
            verts += doc["accessors"][primitive["attributes"]["POSITION"]]["count"]
            assert "TEXCOORD_0" in primitive["attributes"], "UV missing"
        mesh_rows.append({"node": node.get("name", ""), "triangles": count,
                          "vertices": verts, "surfaces": len(gltf_mesh["primitives"])})
    return {"mesh_nodes": mesh_rows, "material_count": len(doc.get("materials", [])),
            "image_count": len(doc.get("images", [])),
            "texture_count": len(doc.get("textures", [])),
            "all_images_embedded": all("bufferView" in image for image in doc.get("images", [])),
            "bytes": path.stat().st_size}


def reset_scene():
    bpy.ops.wm.read_homefile(use_empty=True)


def mesh_metrics(obj) -> dict:
    mesh = obj.data
    mesh.calc_loop_triangles()
    uv = mesh.uv_layers.active
    uv_pairs = [tuple(loop.uv) for loop in uv.data] if uv else []
    finite = all(math.isfinite(value) for pair in uv_pairs for value in pair)
    vertices = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    low = [min(point[axis] for point in vertices) for axis in range(3)]
    high = [max(point[axis] for point in vertices) for axis in range(3)]
    images = set()
    materials = set()
    for material in mesh.materials:
        if not material:
            continue
        materials.add(material.name)
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    images.add(node.image.name)
    return {"triangles": len(mesh.loop_triangles), "vertices": len(mesh.vertices),
            "faces": len(mesh.polygons), "surfaces": len(mesh.materials),
            "material_count": len(materials), "image_count": len(images),
            "uv_layer_count": len(mesh.uv_layers), "uv_loop_count": len(uv_pairs),
            "uv_finite": finite,
            "uv_min": [min(pair[axis] for pair in uv_pairs) for axis in range(2)] if uv_pairs else [],
            "uv_max": [max(pair[axis] for pair in uv_pairs) for axis in range(2)] if uv_pairs else [],
            "bounds_min_blender_xyz": [round(value, 5) for value in low],
            "bounds_max_blender_xyz": [round(value, 5) for value in high],
            "size_blender_xyz": [round(high[axis] - low[axis], 5) for axis in range(3)]}


def decimate(obj, target: int):
    before = mesh_metrics(obj)["triangles"]
    assert before > target
    modifier = obj.modifiers.new("MeshyTriangleReduction", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = min(1.0, target / before)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    after = mesh_metrics(obj)["triangles"]
    assert after <= round(target * 1.1), (obj.name, target, after)
    assert after >= target * 0.75, (obj.name, target, after)


def normalized_matrix(raw: dict, height: float, yaw_deg: float) -> Matrix:
    low = raw["bounds_min_blender_xyz"]
    high = raw["bounds_max_blender_xyz"]
    centre = ((low[0] + high[0]) / 2, (low[1] + high[1]) / 2)
    scale = height / (high[2] - low[2])
    return (Matrix.Rotation(math.radians(yaw_deg), 4, "Z") @
            Matrix.Scale(scale, 4) @
            Matrix.Translation(Vector((-centre[0], -centre[1], -low[2]))))


def prepare_render(size: int):
    scene = bpy.context.scene
    # Blender 5.2 calls this engine BLENDER_EEVEE.
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 16
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("LODComparisonWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.61, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=100)
    floor = bpy.context.object
    floor.name = "LODComparisonFloor"
    floor.hide_select = True
    material = bpy.data.materials.new("LODComparisonFloorColor")
    material.diffuse_color = (0.53, 0.51, 0.46, 1)
    floor.data.materials.append(material)
    for name, position, energy in (("Key", (18, -16, 22), 4200),
                                   ("Fill", (-18, -8, 16), 2400)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = 18
        lamp = bpy.data.objects.new(name, data)
        lamp.location = position
        bpy.context.scene.collection.objects.link(lamp)
        lamp.rotation_euler = (-lamp.location).to_track_quat("-Z", "Y").to_euler()
    camera_data = bpy.data.cameras.new("LODComparisonCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 16.5
    camera = bpy.data.objects.new("LODComparisonCamera", camera_data)
    camera.location = (14, -18, 12)
    target = Vector((0, 0, 5))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(camera)
    scene.camera = camera


def render_pair(obj, normalization: Matrix, destination: Path, source: bool):
    saved = obj.matrix_world.copy()
    if source:
        obj.matrix_world = normalization @ saved
    for other in bpy.data.objects:
        if other.type == "MESH" and other != obj and other.name in ("LOD0", "LOD1", "LOD2"):
            other.hide_render = True
    bpy.context.view_layer.update()
    destination.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(destination)
    bpy.ops.render.render(write_still=True)
    obj.matrix_world = saved
    return str(destination.relative_to(ROOT)).replace("\\", "/")


def one_house(house: dict, args) -> dict:
    house_id = house["id"]
    source_dir = Path(args.source_dir)
    if not source_dir.is_absolute():
        source_dir = ROOT / source_dir
    source = source_dir / (house_id + ".glb")
    dest = DEST / (house_id + "_lod.glb")
    original_hash = sha(source)
    lineage = {"original_highpoly_source_sha256": house["source_sha256"],
               "original_highpoly_source_triangles": house["triangles"]}
    if args.source_kind == "raw-highpoly":
        assert original_hash == house["source_sha256"]
    else:
        remesh = json.loads(REMESH_REPORT.read_text(encoding="utf-8"))
        entry = next(row for row in remesh["houses"] if row["id"] == house_id)
        assert original_hash == entry["source_sha256_before"] == entry["source_sha256_after"]
        receipt = json.loads((REMESH_RECEIPTS / (house_id + "-receipt.json")).read_text(encoding="utf-8"))
        lineage.update({"remesh_source_sha256": original_hash,
                        "remesh_task_id": receipt["structuredContent"]["task_id"],
                        "remesh_receipt": str((REMESH_RECEIPTS / (house_id + "-receipt.json")).relative_to(ROOT)).replace("\\", "/"),
                        "remesh_method": "Meshy quad remesh with rebaked textures; distinct from immutable raw high-poly source"})
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    assert len(meshes) == 1, (house_id, len(meshes))
    base = meshes[0]
    original_transform = base.matrix_world.copy()
    raw = mesh_metrics(base)
    if args.source_kind == "raw-highpoly":
        assert raw["triangles"] == house["triangles"]
    else:
        assert raw["triangles"] == entry["raw_metrics"]["triangles"] <= 44000
    assert raw["material_count"] == 1 and raw["uv_layer_count"] >= 1 and raw["uv_finite"]
    norm = normalized_matrix(raw, HEIGHTS[house_id], YAW[house_id])
    preview = not args.no_preview and args.preview_house == house_id
    images = {}
    if preview:
        prepare_render(args.preview_size)
        images["source"] = render_pair(base, norm, EVIDENCE / (house_id + "_source.png"), True)
    # Keep the original material/UV data. Make progressively smaller mesh copies.
    base.name = "LOD0"
    if args.source_kind == "raw-highpoly":
        decimate(base, TARGETS[0])
    level1 = base.copy()
    level1.data = base.data.copy()
    level1.name = "LOD1"
    bpy.context.scene.collection.objects.link(level1)
    decimate(level1, TARGETS[1])
    # Start the distant silhouette from LOD0 rather than stacking two severe
    # reductions. This keeps roof/door outlines more stable at 3k triangles.
    level2 = base.copy()
    level2.data = base.data.copy()
    level2.name = "LOD2"
    bpy.context.scene.collection.objects.link(level2)
    decimate(level2, TARGETS[2])
    levels = [base, level1, level2]
    for level_index, obj in enumerate(levels):
        obj.data.transform(norm @ original_transform)
        obj.matrix_world = Matrix.Identity(4)
        obj.hide_render = False
        # Collapse decimation can place a few vertices beyond the source roof
        # and ground. Bound only the vertical span to the artist's display box;
        # UVs/materials and the original source vertices remain untouched.
        if args.source_kind == "raw-highpoly" or level_index > 0:
            for vertex in obj.data.vertices:
                vertex.co.z = max(0.0, min(HEIGHTS[house_id], vertex.co.z))
            obj.data.update()
    bpy.context.view_layer.update()
    measured = [mesh_metrics(obj) for obj in levels]
    print(json.dumps({"house": house_id, "raw_min": raw["bounds_min_blender_xyz"],
                      "level_bounds": [{"min": m["bounds_min_blender_xyz"],
                                        "size": m["size_blender_xyz"], "triangles": m["triangles"]}
                                       for m in measured]}), flush=True)
    effective_targets = [44000 if args.source_kind == "meshy-quad-remesh" else 40000, 12000, 3000]
    for metric, target in zip(measured, effective_targets):
        assert metric["triangles"] <= target * 1.1
        assert metric["uv_finite"] and metric["uv_layer_count"] >= 1
        assert min(metric["uv_min"]) >= -0.01 and max(metric["uv_max"]) <= 1.01
        assert abs(metric["bounds_min_blender_xyz"][2]) <= 0.25
        assert abs(metric["size_blender_xyz"][2] - HEIGHTS[house_id]) <= 0.4
    if preview:
        images["lod0"] = render_pair(base, Matrix.Identity(4), EVIDENCE / (house_id + "_lod0.png"), False)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in levels:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = base
    dest.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format="GLB", use_selection=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    glb = inspect_glb(dest)
    glb_levels = {row["node"]: row for row in glb["mesh_nodes"]}
    assert sorted(glb_levels) == ["LOD0", "LOD1", "LOD2"], glb_levels
    assert glb["material_count"] == 1 and glb["all_images_embedded"]
    assert glb["image_count"] == 3, glb["image_count"]
    for index, metric in enumerate(measured):
        assert glb_levels[f"LOD{index}"]["triangles"] == metric["triangles"]
    assert sha(source) == original_hash, "Immutable source bytes changed"
    return {"id": house_id, "source": str(source.relative_to(ROOT)).replace("\\", "/"),
            "source_kind": args.source_kind, "source_lineage": lineage,
            "source_sha256": original_hash, "source_bytes": source.stat().st_size,
            "source_metrics": raw, "output": str(dest.relative_to(ROOT)).replace("\\", "/"),
            "output_sha256": sha(dest), "output_metrics": glb,
            "lod_metrics_blender": measured, "target_triangles": effective_targets,
            "intended_display_height_m": HEIGHTS[house_id],
            "presentation_yaw_deg": YAW[house_id],
            "normalized_scale": round(HEIGHTS[house_id] / raw["size_blender_xyz"][2], 6),
            "source_to_lod0_triangle_reduction_pct": round(100 * (1 - measured[0]["triangles"] / raw["triangles"]), 4),
            "source_to_lod0_byte_reduction_pct": round(100 * (1 - dest.stat().st_size / source.stat().st_size), 4),
            "comparison_images": images, "source_unchanged_after_build": True}


def main():
    args = arguments()
    manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    selected = [house for house in manifest["houses"] if not args.house or house["id"] in args.house]
    assert selected
    DEST.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    TMP.mkdir(parents=True, exist_ok=True)
    rows = []
    for house in selected:
        print("Building", house["id"], flush=True)
        row = one_house(house, args)
        rows.append(row)
        print(json.dumps({"house": row["id"], "source_triangles": row["source_metrics"]["triangles"],
                          "lod_triangles": [m["triangles"] for m in row["lod_metrics_blender"]],
                          "output_bytes": row["output_metrics"]["bytes"]}), flush=True)
    report = {"schema": "meshy-house-lod-build-v2", "generated_at_utc": datetime.now(timezone.utc).isoformat(),
              "builder": "tools/build_meshy_house_lods.py", "blender_version": bpy.app.version_string,
              "source_kind": args.source_kind,
              "method": ("Meshy quad remesh retained as near LOD0; Blender collapse decimate from that 12k/3k; rebaked remesh UVs and PBR retained" if args.source_kind == "meshy-quad-remesh" else
                         "Blender collapse decimate; successive 40k/12k/3k targets; original UVs and PBR material retained"),
              "asset_role": "exterior appearance LOD only; intended heights are display authoring, not source true-scale measurement",
              "known_visual_limitations": ([] if args.source_kind == "meshy-quad-remesh" else [
                  "At 40k triangles the cottage comparison render shows visible roof-tile and window-edge breakup; this is a measured collapse-decimate baseline, not an approved near-camera hero mesh.",
                  "The 12k and 3k levels preserve source textures but their smaller silhouettes require in-engine distance review before art approval."]),
              "godot_import_note": "Godot 4.7 may extract one JPG set per house from its embedded GLB images as import sidecars; the three LOD nodes in each GLB share one material/image set.",
              "sources_immutable": True, "houses": rows}
    for path in (DEST / "manifest.json", EVIDENCE / "manifest.json", TMP / "result.json"):
        path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"report": str((TMP / "result.json").relative_to(ROOT)), "houses": len(rows)}), flush=True)


if __name__ == "__main__":
    try:
        main()
    except BaseException:
        traceback.print_exc()
        sys.stderr.flush()
        sys.stdout.flush()
        # Blender returns process exit 0 for uncaught --python exceptions.
        # Preserve a real failure status for the owned batch wrapper.
        import os
        os._exit(1)
