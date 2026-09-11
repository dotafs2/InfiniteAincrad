"""Audit actual exported residence GLBs, not just generator declarations."""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'game/assets/floor1/residences'


def accessor(doc, binary, index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    record=struct.Struct('<'+fmt*count)
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',record.size)
    return [record.unpack_from(binary,offset+i*stride) for i in range(a['count'])]


def main():
    manifest=json.loads((FOLDER/'manifest.json').read_text());results=[]
    assert len(manifest['assets'])==5
    for entry in manifest['assets']:
        b=(ROOT/entry['file']).read_bytes()
        assert hashlib.sha256(b).hexdigest()==entry['sha256']
        assert b[:4]==b'glTF' and struct.unpack_from('<I',b,8)[0]==len(b)
        length=struct.unpack_from('<I',b,12)[0];doc=json.loads(b[20:20+length]);binary=memoryview(b)[28+length:]
        assert len(doc['meshes'])==3 and len(doc['images'])==12
        textured=[m for m in doc['materials'] if 'baseColorTexture' in m.get('pbrMetallicRoughness',{})]
        assert len(textured)==4
        assert all('normalTexture' in m and 'metallicRoughnessTexture' in m['pbrMetallicRoughness'] for m in textured)
        for image in doc['images']:
            view=doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
            assert bytes(binary[start:start+8])==b'\x89PNG\r\n\x1a\n'
            assert struct.unpack_from('>II',binary,start+16)==(2048,2048)
        for level,mesh in enumerate(doc['meshes']):
            triangles=degenerate=uv_zero=0;palette=set()
            for surface in mesh['primitives']:
                at=surface['attributes']
                assert all(k in at for k in ['POSITION','NORMAL','TEXCOORD_0','TEXCOORD_1','TANGENT','COLOR_0'])
                p=accessor(doc,binary,at['POSITION']);uv=accessor(doc,binary,at['TEXCOORD_1'])
                assert all(math.isfinite(c) for v in p for c in v)
                assert all(math.isfinite(c) and -.0001<=c<=1.0001 for v in uv for c in v)
                colors=accessor(doc,binary,at['COLOR_0']);palette.update(tuple(round(c,3) for c in v) for v in colors[::max(1,len(colors)//1000)])
                indices=[v[0] for v in accessor(doc,binary,surface['indices'])]
                assert len(indices)%3==0 and max(indices)<len(p)
                triangles+=len(indices)//3
                for i in range(0,len(indices),3):
                    a,b,c=(p[j] for j in indices[i:i+3]);u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
                    cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
                    degenerate+=sum(x*x for x in cross)<1e-20
                    a,b,c=(uv[j] for j in indices[i:i+3])
                    uv_zero+=abs((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))<1e-14
            assert len(palette)>12,(entry['id'],level,'missing colour variation')
            assert triangles==entry['lods'][level]['triangles'],(entry['id'],level,triangles)
            assert degenerate==0,(entry['id'],level,'degenerate',degenerate)
            assert uv_zero==0,(entry['id'],level,'collapsed secondary UV',uv_zero)
            results.append({'asset':entry['id'],'lod':level,'triangles':triangles,'degenerate_triangles':degenerate,'secondary_uv_zero_area_triangles':uv_zero,'sampled_palette_colours':len(palette)})
        assert entry['lods'][0]['triangles']>entry['lods'][1]['triangles']>entry['lods'][2]['triangles']
        print(entry['id']+' checked',flush=True)
    report={'suite':'residence_export_audit','assets':5,'lods':15,'pbr_texture_sets':4,'texture_resolution':2048,'results':results}
    if '--output' in sys.argv:
        output=Path(sys.argv[sys.argv.index('--output')+1]);output.parent.mkdir(parents=True,exist_ok=True)
        output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
