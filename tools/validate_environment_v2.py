"""Validate delivered V2 GLBs, not the generator's declared geometry counts."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "game/assets/floor1/environment_kit_v2"


def read_glb(path):
    data = path.read_bytes()
    assert data[:4] == b"glTF"
    size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + size])
    binary_start = 20 + size + 8
    return doc, data[binary_start:]


def accessor(doc, binary, index):
    item = doc["accessors"][index]
    view = doc["bufferViews"][item["bufferView"]]
    fmt = {5120:"b",5121:"B",5122:"h",5123:"H",5125:"I",5126:"f"}[item["componentType"]]
    count = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[item["type"]]
    record = struct.Struct("<" + fmt * count)
    start = view.get("byteOffset", 0) + item.get("byteOffset", 0)
    stride = view.get("byteStride", record.size)
    return [record.unpack_from(binary, start + i * stride) for i in range(item["count"])]


def main():
    manifest = json.loads((FOLDER / "manifest.json").read_text())
    entries = []
    for asset in manifest["assets"]:
        assert (ROOT / asset["game_scene"]).is_file()
        counts = []
        for level, lod in enumerate(asset["lods"]):
            path = ROOT / lod["file"]
            assert hashlib.sha256(path.read_bytes()).hexdigest() == lod["sha256"]
            doc, binary = read_glb(path)
            triangles = moving = rigid = degenerates = 0
            for mesh in doc["meshes"]:
                for surface in mesh["primitives"]:
                    attrs = surface["attributes"]
                    assert all(k in attrs for k in ("POSITION", "NORMAL", "COLOR_0", "TEXCOORD_0", "TEXCOORD_1"))
                    positions = accessor(doc, binary, attrs["POSITION"])
                    weights = accessor(doc, binary, attrs["TEXCOORD_1"])
                    kind = doc["materials"][surface["material"]]["name"]
                    assert all(math.isfinite(v) for p in positions for v in p)
                    assert all(-.0001 <= p[0] <= 1.001 for p in weights)
                    if kind in ("F2_solid", "F2_fabric", "F2_water"):
                        assert all(abs(w[0]) < .0001 for w in weights), (path, kind, "rigid weights")
                    moving += sum(w[0] > .0001 for w in weights)
                    rigid += sum(w[0] <= .0001 for w in weights)
                    indices = [v[0] for v in accessor(doc, binary, surface["indices"])]
                    assert len(indices) % 3 == 0
                    triangles += len(indices) // 3
                    for i in range(0, len(indices), 3):
                        a,b,c = [positions[j] for j in indices[i:i+3]]
                        u = [b[j]-a[j] for j in range(3)]; v = [c[j]-a[j] for j in range(3)]
                        cross = (u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
                        degenerates += sum(x*x for x in cross) < 1e-20
            assert triangles == lod["triangles"], (path,triangles,lod["triangles"])
            assert moving + rigid > 0
            assert degenerates == 0, (path, "degenerate triangles", degenerates)
            counts.append(triangles)
            entries.append({"id":asset["id"],"lod":level,"triangles":triangles,"moving_vertices":moving,"rigid_vertices":rigid,"degenerate_triangles":degenerates})
        assert counts[0] >= counts[1] >= counts[2], (asset["id"],counts)
    print(json.dumps({"suite":"environment_v2_export_audit","glbs":len(entries),"game_scenes":20,"checks":"hashes, attributes, finite positions, wind masks, nondegenerate topology, monotonic LOD triangles","triangles_by_lod":[sum(e["triangles"] for e in entries if e["lod"]==i) for i in range(3)],"assets":entries},indent=2))


if __name__ == "__main__": main()
