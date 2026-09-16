"""Build a separate, selectable 2K PBR GLB tier from the preserved 4K LOD GLBs.

Run with repository Python 3.11, Pillow and NumPy from the repository root:

    python Art/Generated/MeshyHouseLods20260916/build_texture2k_tier.py

Each source GLB remains untouched. Geometry, UV accessors, mesh nodes and the
single shared glTF material are copied exactly; only its three embedded PNG
buffer views are replaced with independently derived 2048² images. Tangent
normal vectors are renormalized after area/BOX resampling. This is an asset
derivative, not a source repair or a claim that live GPU memory was measured.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import struct
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
ASSET_ROOT = ROOT / "game/assets/floor1/meshy_houses_lod"
EVIDENCE_ROOT = ROOT / "Art/Generated/MeshyHouseLods20260916"
HOUSE_IDS = ("01_hearth_cottage", "02_market_house", "03_corner_turret")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_glb(path: Path) -> tuple[dict, bytes]:
    with path.open("rb") as handle:
        magic, version, total = struct.unpack("<4sII", handle.read(12))
        if magic != b"glTF" or version != 2 or total != path.stat().st_size:
            raise AssertionError(f"invalid/incomplete source GLB: {path}")
        json_length, json_type = struct.unpack("<I4s", handle.read(8))
        if json_type != b"JSON":
            raise AssertionError("expected JSON chunk first")
        doc = json.loads(handle.read(json_length))
        bin_length, bin_type = struct.unpack("<I4s", handle.read(8))
        if bin_type != b"BIN\x00":
            raise AssertionError("expected binary chunk second")
        payload = handle.read(bin_length)
        if len(payload) != bin_length or handle.read(1):
            raise AssertionError("invalid binary chunk length")
    return doc, payload


def derive_image(source_png: bytes, semantic: str) -> bytes:
    with Image.open(io.BytesIO(source_png)) as src:
        if src.size != (4096, 4096) or src.mode not in ("RGB", "RGBA"):
            raise AssertionError(f"expected 4096² PBR source, got {src.size}/{src.mode}")
        box_filter = semantic in ("normal", "texture_0_metallic_roughness")
        filt = Image.Resampling.BOX if box_filter else Image.Resampling.LANCZOS
        img = src.convert("RGB").resize((2048, 2048), filt)
        if semantic == "normal":
            pixels = np.asarray(img, dtype=np.float32)
            vectors = pixels / 127.5 - 1.0
            vectors /= np.maximum(np.linalg.norm(vectors, axis=2, keepdims=True), 1e-7)
            img = Image.fromarray(
                np.clip(np.rint((vectors + 1.0) * 127.5), 0, 255).astype(np.uint8),
                mode="RGB",
            )
        target = io.BytesIO()
        img.save(target, format="PNG", optimize=True, compress_level=6)
        return target.getvalue()


def build_one(house_id: str, write_assets: bool) -> dict:
    src = ASSET_ROOT / f"{house_id}_lod.glb"
    dest = ASSET_ROOT / f"{house_id}_lod_2k.glb"
    source_hash = sha(src.read_bytes())
    doc, old_bin = parse_glb(src)
    images = doc.get("images", [])
    if len(images) != 3 or len(doc.get("materials", [])) != 1:
        raise AssertionError("expected exactly three embedded PBR images and one material")
    mesh_nodes = sorted(node.get("name") for node in doc.get("nodes", []) if "mesh" in node)
    material_refs = [p.get("material") for m in doc["meshes"] for p in m["primitives"]]
    if mesh_nodes != ["LOD0", "LOD1", "LOD2"] or material_refs != [0, 0, 0]:
        raise AssertionError("unexpected LOD/material sharing contract")
    image_views = {image["bufferView"] for image in images}
    if len(image_views) != 3:
        raise AssertionError("image buffer views are not independent")
    view_rows = doc["bufferViews"]
    # Blender's export places LOD1/LOD2 geometry *after* the three PNGs.
    # Rebuffer all views in their original order, carrying every nonimage
    # view's bytes exactly while updating its glTF byteOffset.
    source_views = [(view.get("byteOffset", 0), view["byteLength"]) for view in view_rows]
    ordered_views = sorted(range(len(view_rows)), key=lambda index: source_views[index][0])
    last_end = 0
    for index in ordered_views:
        start, length = source_views[index]
        if start < last_end or start + length > len(old_bin):
            raise AssertionError("overlapping/out-of-range GLB buffer views")
        last_end = start + length
    new_bin = bytearray()
    image_rows = []
    replacement_by_view = {}
    for image in images:
        if image.get("mimeType") != "image/png":
            raise AssertionError("expected PNG image buffer view")
        semantic = image.get("name", "")
        if semantic not in ("normal", "texture_0", "texture_0_metallic_roughness"):
            raise AssertionError(f"unknown PBR texture role: {semantic}")
        start, length = source_views[image["bufferView"]]
        source_png = old_bin[start:start + length]
        derived_png = derive_image(source_png, semantic)
        replacement_by_view[image["bufferView"]] = derived_png
        image_rows.append({
            "semantic": semantic,
            "original_encoded_bytes": len(source_png),
            "derived_encoded_bytes": len(derived_png),
            "derived_sha256": sha(derived_png),
            "dimensions_px": [2048, 2048],
            "resampling": "BOX + tangent normal renormalization" if semantic == "normal" else
                ("BOX channel average" if semantic == "texture_0_metallic_roughness" else "LANCZOS RGB"),
        })
    geometry_sha = hashlib.sha256()
    candidate_geometry_sha = hashlib.sha256()
    for index in ordered_views:
        start, length = source_views[index]
        payload = replacement_by_view.get(index, old_bin[start:start + length])
        new_bin.extend(b"\x00" * ((-len(new_bin)) % 4))
        view_rows[index]["byteOffset"] = len(new_bin)
        view_rows[index]["byteLength"] = len(payload)
        new_bin.extend(payload)
        if index not in image_views:
            geometry_sha.update(struct.pack("<I", index))
            geometry_sha.update(old_bin[start:start + length])
            candidate_geometry_sha.update(struct.pack("<I", index))
            candidate_geometry_sha.update(payload)
    new_bin.extend(b"\x00" * ((-len(new_bin)) % 4))
    doc["buffers"][0]["byteLength"] = len(new_bin)
    json_chunk = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    total = 12 + 8 + len(json_chunk) + 8 + len(new_bin)
    output = (struct.pack("<4sII", b"glTF", 2, total) +
              struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk +
              struct.pack("<I4s", len(new_bin), b"BIN\x00") + new_bin)
    if len(output) != total:
        raise AssertionError("GLB output byte count mismatch")
    if write_assets:
        if not dest.resolve().is_relative_to(ASSET_ROOT.resolve()):
            raise AssertionError("2K output outside owned asset directory")
        with tempfile.NamedTemporaryFile(dir=dest.parent, prefix=dest.stem + ".", suffix=".tmp", delete=False) as temp:
            temporary = Path(temp.name)
            temp.write(output)
        try:
            candidate_doc, candidate_bin = parse_glb(temporary)
            if candidate_doc["meshes"] != doc["meshes"] or candidate_doc["accessors"] != doc["accessors"]:
                raise AssertionError("mesh/UV accessor changed")
            for index in ordered_views:
                if index in image_views:
                    continue
                start, length = source_views[index]
                updated = candidate_doc["bufferViews"][index]
                if candidate_bin[updated["byteOffset"]:updated["byteOffset"] + updated["byteLength"]] != old_bin[start:start + length]:
                    raise AssertionError(f"geometry buffer view {index} changed")
            for image in candidate_doc["images"]:
                view = candidate_doc["bufferViews"][image["bufferView"]]
                with Image.open(io.BytesIO(candidate_bin[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])) as check:
                    if check.size != (2048, 2048) or check.mode != "RGB":
                        raise AssertionError("bad derived image dimensions/mode")
            os.replace(temporary, dest)
        finally:
            temporary.unlink(missing_ok=True)
    if sha(src.read_bytes()) != source_hash:
        raise AssertionError("immutable 4K source changed")
    return {
        "id": house_id,
        "source_4k_glb": str(src.relative_to(ROOT)).replace("\\", "/"),
        "source_4k_sha256_before_after": source_hash,
        "source_4k_bytes": src.stat().st_size,
        "derived_2k_glb": str(dest.relative_to(ROOT)).replace("\\", "/"),
        "derived_2k_sha256": sha(output),
        "derived_2k_bytes": len(output),
        "source_geometry_buffer_views_sha256": geometry_sha.hexdigest(),
        "derived_geometry_buffer_views_sha256": candidate_geometry_sha.hexdigest(),
        "mesh_nodes": mesh_nodes,
        "material_refs": material_refs,
        "material_count": 1,
        "embedded_image_count": 3,
        "images": image_rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--house", choices=HOUSE_IDS, action="append")
    parser.add_argument("--dry-run", action="store_true", help="derive and validate bytes without writing game assets")
    args = parser.parse_args()
    rows = [build_one(house_id, not args.dry_run) for house_id in (args.house or HOUSE_IDS)]
    report = {
        "schema": "meshy-house-selectable-2k-glb-tier-v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "builder": "Art/Generated/MeshyHouseLods20260916/build_texture2k_tier.py",
        "state": "dry-run candidate only" if args.dry_run else "separate 2K GLBs built; 4K sources preserved",
        "houses": rows,
        "runtime_selection_note": "Texture tier is selected per house by the LOD adapter; do not load both 4K and 2K GLBs per house concurrently if seeking memory savings.",
        "gpu_vram_note": "Encoded GLB bytes and uncompressed image dimensions are measured, not live GPU allocation.",
    }
    path = EVIDENCE_ROOT / ("texture-tier-2k-dry-run.json" if args.dry_run else "texture-tier-2k-manifest.json")
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"state": report["state"], "houses": len(rows), "source_4k_bytes": sum(row["source_4k_bytes"] for row in rows), "derived_2k_bytes": sum(row["derived_2k_bytes"] for row in rows)}))


if __name__ == "__main__":
    main()
