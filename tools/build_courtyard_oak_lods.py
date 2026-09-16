"""Build isolated, texture-preserving courtyard oak collapse LOD trials.

Run from the repository root with Blender 5.2:
  blender --background --factory-startup --python tools/build_courtyard_oak_lods.py -- --target 100000
  blender --background --factory-startup --python tools/build_courtyard_oak_lods.py -- --target 60000

The 4.78M-triangle source is read-only. Each target imports it anew, collapses
its original topology rather than a 31K remesh, and exports one GLB outside the
game. Leaf-cluster deletion is intentionally not automated: the actual four-angle
render comparison determines whether a disconnected piece is debris or foliage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "exports/floor1-art-20260916/courtyard-oak/raw/F1_courtyard_oak_raw.glb"
DEST = ROOT / "Art/Generated/CourtyardOak20260916/models"
RECEIPTS = ROOT / "tmp/floor1-art-20260916/oak-lods"
TARGETS = (100000, 60000)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=int, choices=TARGETS, required=True)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--out", type=Path, default=DEST)
    parser.add_argument("--receipt-dir", type=Path, default=RECEIPTS)
    return parser.parse_args(argv)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def glb_document(path: Path):
    with path.open("rb") as stream:
        magic, version, declared_size = struct.unpack("<4sII", stream.read(12))
        assert magic == b"glTF" and version == 2 and declared_size == path.stat().st_size
        json_size, json_type = struct.unpack("<I4s", stream.read(8))
        assert json_type == b"JSON"
        doc = json.loads(stream.read(json_size))
        binary_size, binary_type = struct.unpack("<I4s", stream.read(8))
        assert binary_type == b"BIN\0"
        binary = stream.read(binary_size)
    return doc, binary


def glb_metrics(path: Path) -> dict:
    doc, binary = glb_document(path)
    surfaces = []
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            assert primitive.get("mode", 4) == 4
            assert "TEXCOORD_0" in primitive["attributes"], "Oak UV vanished"
            count = doc["accessors"][primitive["indices"]]["count"]
            assert count % 3 == 0
            surfaces.append({"triangles": count // 3,
                             "vertices": doc["accessors"][primitive["attributes"]["POSITION"]]["count"],
                             "material": primitive.get("material")})
    images = []
    for image in doc.get("images", []):
        view = doc["bufferViews"][image["bufferView"]]
        offset = view.get("byteOffset", 0)
        payload = binary[offset:offset + view["byteLength"]]
        assert len(payload) == view["byteLength"]
        images.append({"mime": image.get("mimeType"), "bytes": len(payload),
                       "sha256": hashlib.sha256(payload).hexdigest()})
    return {"triangles": sum(row["triangles"] for row in surfaces),
            "surfaces": surfaces, "mesh_count": len(doc.get("meshes", [])),
            "node_count": len(doc.get("nodes", [])),
            "material_count": len(doc.get("materials", [])),
            "texture_count": len(doc.get("textures", [])), "images": images,
            "all_images_embedded": len(images) == len(doc.get("images", [])),
            "bytes": path.stat().st_size}


def blender_metrics(obj) -> dict:
    mesh = obj.data
    bounds = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    low = [min(point[axis] for point in bounds) for axis in range(3)]
    high = [max(point[axis] for point in bounds) for axis in range(3)]
    uv = mesh.uv_layers.active
    samples = []
    if uv:
        n = len(uv.data)
        sample_ids = [0, 1, n // 4, n // 2, 3 * n // 4, n - 2, n - 1]
        samples = [tuple(uv.data[index].uv) for index in sample_ids if 0 <= index < n]
    return {"triangles": len(mesh.polygons), "vertices": len(mesh.vertices),
            "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
            "uv_layers": len(mesh.uv_layers), "uv_loops": len(uv.data) if uv else 0,
            "sampled_uv_finite": all(math.isfinite(value) for sample in samples for value in sample),
            "bounds_min_blender_xyz": [round(value, 6) for value in low],
            "bounds_max_blender_xyz": [round(value, 6) for value in high]}


def active_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def collapse(obj, target: int):
    before = len(obj.data.polygons)
    assert before > target
    modifier = obj.modifiers.new("OriginalTopologyCollapse", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = target / before
    modifier.use_collapse_triangulate = True
    active_only(obj)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    after = len(obj.data.polygons)
    # The modifier can retain protected boundaries; a second bounded pass
    # calibrates the target without assuming the first ratio is exact.
    if after > target * 1.10:
        modifier = obj.modifiers.new("TargetCalibrationCollapse", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = target / after
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return len(obj.data.polygons)


def run():
    args = parse_args()
    source = args.source.resolve()
    assert source == SOURCE.resolve(), "Only the reviewed immutable oak source is accepted"
    before_sha = sha(source)
    assert before_sha == "deb14d907284e94e8e126509e1b7094b0d5576676b8a6aa96613af88e918ee5a"
    raw_glb = glb_metrics(source)
    assert raw_glb["triangles"] == 4775932 and len(raw_glb["images"]) == 3
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    assert len(meshes) == 1, "Unexpected oak decomposition; do not collapse unknown pieces"
    obj = meshes[0]
    raw_blender = blender_metrics(obj)
    assert raw_blender["triangles"] == raw_glb["triangles"]
    assert raw_blender["uv_layers"] >= 1 and raw_blender["sampled_uv_finite"]
    reached = collapse(obj, args.target)
    candidate_blender = blender_metrics(obj)
    assert args.target * 0.80 <= reached <= args.target * 1.12, reached
    assert candidate_blender["uv_layers"] >= 1 and candidate_blender["sampled_uv_finite"]
    raw_size = [raw_blender["bounds_max_blender_xyz"][i] - raw_blender["bounds_min_blender_xyz"][i]
                for i in range(3)]
    bounds_delta = max(abs(candidate_blender["bounds_min_blender_xyz"][i] -
                           raw_blender["bounds_min_blender_xyz"][i]) /
                       max(raw_size[i], 1e-4) for i in range(3))
    bounds_delta = max(bounds_delta, max(abs(candidate_blender["bounds_max_blender_xyz"][i] -
                                          raw_blender["bounds_max_blender_xyz"][i]) /
                                      max(raw_size[i], 1e-4) for i in range(3)))
    args.out.mkdir(parents=True, exist_ok=True)
    args.receipt_dir.mkdir(parents=True, exist_ok=True)
    output = args.out / f"F1_courtyard_oak_originalcollapse_{args.target // 1000}k.glb"
    active_only(obj)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                              use_selection=True, export_texcoords=True,
                              export_materials="EXPORT")
    result_glb = glb_metrics(output)
    assert args.target * 0.80 <= result_glb["triangles"] <= args.target * 1.12
    assert len(result_glb["images"]) == 3 and result_glb["all_images_embedded"]
    assert result_glb["material_count"] == raw_glb["material_count"]
    assert sha(source) == before_sha, "Source GLB changed during trial"
    receipt = {"revision": "isolated-courtyard-oak-original-collapse-v1",
               "generated_at_utc": datetime.now(timezone.utc).isoformat(),
               "source": str(source).replace("\\", "/"), "source_sha256_before_after": before_sha,
               "target_triangles": args.target, "actual_triangles": result_glb["triangles"],
               "output": str(output).replace("\\", "/"), "output_sha256": sha(output),
               "raw_glb": raw_glb, "candidate_glb": result_glb,
               "raw_blender": raw_blender, "candidate_blender": candidate_blender,
               "max_relative_bounds_endpoint_change": round(bounds_delta, 6),
               "visual_acceptance_pending": "Compare original and both actual four-angle renders; do not delete leaf islands solely by component size."}
    path = args.receipt_dir / f"oak-originalcollapse-{args.target // 1000}k.json"
    path.write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print(json.dumps({"target": args.target, "actual": result_glb["triangles"],
                      "source_sha256": before_sha, "output_sha256": sha(output),
                      "output_bytes": result_glb["bytes"], "bounds_delta": bounds_delta,
                      "receipt": str(path).replace("\\", "/")}))


if __name__ == "__main__":
    run()
