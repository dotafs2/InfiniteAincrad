"""Independent GLB audit for house 06; supervisor validation, not asset implementation."""
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

from validate_residences import accessor

ROOT = Path(__file__).resolve().parents[1]


def audit():
    folder = ROOT / 'game/assets/floor1/deepseek_residences'
    manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
    assert len(manifest['assets']) == 1
    entry = manifest['assets'][0]
    raw = (ROOT / entry['file']).read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    assert digest == entry['sha256'], 'Manifest does not describe the actual GLB'
    assert raw[:4] == b'glTF' and struct.unpack_from('<I', raw, 8)[0] == len(raw)
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    binary = memoryview(raw)[28+length:]
    assert len(doc['meshes']) == 3 and len(doc['images']) == 12
    materials = [m for m in doc['materials'] if 'baseColorTexture' in m.get('pbrMetallicRoughness', {})]
    assert len(materials) == 4
    assert all('normalTexture' in m and 'metallicRoughnessTexture' in m['pbrMetallicRoughness'] for m in materials)
    for image in doc['images']:
        assert 'uri' not in image, 'Expected embedded textures'
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        assert bytes(binary[start:start+8]) == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack_from('>II', binary, start+16) == (2048, 2048)
    results = []
    bad_faces = []
    for level, mesh in enumerate(doc['meshes']):
        triangles = degenerates = collapsed_uv = duplicates = 0
        seen = set()
        for surface in mesh['primitives']:
            at = surface['attributes']
            assert all(k in at for k in ('POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0', 'TEXCOORD_1', 'COLOR_0'))
            positions = accessor(doc, binary, at['POSITION'])
            uv = accessor(doc, binary, at['TEXCOORD_1'])
            assert all(math.isfinite(c) for v in positions for c in v)
            assert all(math.isfinite(c) and -.0001 <= c <= 1.0001 for v in uv for c in v)
            indices = [row[0] for row in accessor(doc, binary, surface['indices'])]
            assert len(indices) % 3 == 0 and max(indices) < len(positions)
            triangles += len(indices)//3
            for offset in range(0, len(indices), 3):
                ids = indices[offset:offset+3]
                a, b, c = (positions[i] for i in ids)
                # Cyclic rotations preserve winding; reversed flower backfaces
                # are intentional and are not counted as duplicate triangles.
                key = min((a,b,c), (b,c,a), (c,a,b))
                duplicates += key in seen
                seen.add(key)
                u = [b[i]-a[i] for i in range(3)]
                v = [c[i]-a[i] for i in range(3)]
                cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
                is_degenerate = sum(x*x for x in cross) < 1e-20
                degenerates += is_degenerate
                if is_degenerate and len(bad_faces) < 12:
                    bad_faces.append({'lod':level,'material':doc['materials'][surface['material']].get('name'),
                                      'positions':[list(a),list(b),list(c)]})
                a, b, c = (uv[i] for i in ids)
                collapsed_uv += abs((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])) < 1e-14
        assert triangles == entry['lods'][level]['triangles']
        results.append({'lod': level, 'triangles': triangles, 'degenerate_triangles': degenerates,
                        'collapsed_uv1_triangles': collapsed_uv, 'same_winding_duplicate_triangles': duplicates})
    assert results[0]['triangles'] > results[1]['triangles'] > results[2]['triangles']
    return {'suite': 'house06_independent_glb', 'sha256': digest, 'bytes': len(raw),
            'embedded_2k_images': len(doc['images']), 'pbr_materials': len(materials), 'lods': results,
            'passed': all(r['degenerate_triangles'] == 0 and r['collapsed_uv1_triangles'] == 0 for r in results),
            'bad_faces': bad_faces}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--baseline', type=Path)
    args = parser.parse_args()
    report = audit()
    if args.baseline:
        old = json.loads(args.baseline.read_text(encoding='utf-8'))
        for before, after in zip(old['lods'], report['lods']):
            assert after['same_winding_duplicate_triangles'] <= before['same_winding_duplicate_triangles'], 'New duplicate geometry'
        report['duplicate_comparison_passed'] = True
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))
    if not report['passed']:
        raise SystemExit(1)
