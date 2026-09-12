"""Structural GLB audit, limited to this art batch's generated directories."""
from __future__ import annotations
import argparse, hashlib, json, math, struct, datetime
from pathlib import Path
P=argparse.ArgumentParser();P.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[3]);a=P.parse_args()
root=a.root.resolve();out=root/'docs/validation/art_parallel_20260912';out.mkdir(parents=True,exist_ok=True)
component={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
files=[]
for folder in [root/'game/assets/generated'/name for name in ('travel_cargo_20260912','shopfront_details_20260912','artisan_workshops_20260912')]:
    if folder.is_dir():
        files.extend(sorted(folder.glob('*.glb')))
report={'at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'New batch GLBs only; structural and numerical verification, not gameplay or artistic acceptance','files':[],'errors':[]}
for p in files:
    try:
        raw=p.read_bytes();magic,ver,n=struct.unpack_from('<4sII',raw);assert magic==b'glTF' and ver==2 and n==len(raw),'Invalid GLB header'
        pos=12;doc=None;binary=b''
        while pos<len(raw):
            size,kind=struct.unpack_from('<II',raw,pos);chunk=raw[pos+8:pos+8+size];assert len(chunk)==size,'Truncated chunk'
            if kind==0x4e4f534a:doc=json.loads(chunk)
            elif kind==0x004e4942:binary=chunk
            pos+=size+8
        assert doc and binary,'Missing GLB JSON or BIN chunk'
        for buffer in doc.get('buffers',[]):assert 'uri' not in buffer,'External buffer dependency'
        for image in doc.get('images',[]):assert 'bufferView' in image or image.get('uri','').startswith('data:'),'External texture dependency'
        def accessor(index):
            acc=doc['accessors'][index];assert 'sparse' not in acc,'Unexpected sparse accessor'
            bv=doc['bufferViews'][acc['bufferView']];fmt,size=component[acc['componentType']];num=width[acc['type']];stride=bv.get('byteStride',size*num);start=bv.get('byteOffset',0)+acc.get('byteOffset',0)
            assert stride>=num*size and start+(acc['count']-1)*stride+num*size<=len(binary),'Accessor outside binary bounds'
            return [struct.unpack_from('<'+fmt*num,binary,start+i*stride) for i in range(acc['count'])]
        count=0;verts=0;degenerate=0;color=True;uv=True
        for mesh in doc.get('meshes',[]):
            for prim in mesh['primitives']:
                assert prim.get('mode',4)==4,'Unexpected non-triangle primitive'
                pts=accessor(prim['attributes']['POSITION']);verts+=len(pts)
                assert all(math.isfinite(v) for pnt in pts for v in pnt),'Nonfinite position'
                assert 'NORMAL' in prim['attributes'],'Missing normals'
                normals=accessor(prim['attributes']['NORMAL'])
                assert len(normals)==len(pts),'Normal count mismatch'
                assert all(all(math.isfinite(v) for v in q) and .98<sum(v*v for v in q)<1.02 for q in normals),'Invalid normal'
                if 'TEXCOORD_0' in prim['attributes']:
                    assert all(math.isfinite(v) for q in accessor(prim['attributes']['TEXCOORD_0']) for v in q),'Nonfinite UV'
                assert 'material' in prim and 0<=prim['material']<len(doc.get('materials',[])),'Missing material'
                color=color and 'COLOR_0' in prim['attributes'];uv=uv and 'TEXCOORD_0' in prim['attributes']
                ids=[q[0] for q in accessor(prim['indices'])] if 'indices' in prim else list(range(len(pts)))
                assert len(ids)%3==0 and all(0<=v<len(pts) for v in ids),'Invalid indices'
                count+=len(ids)//3
                for j in range(0,len(ids),3):
                    aa,bb,cc=[pts[k] for k in ids[j:j+3]];u=[bb[k]-aa[k] for k in range(3)];v=[cc[k]-aa[k] for k in range(3)]
                    cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                    if sum(c*c for c in cross)<1e-18:degenerate+=1
        assert count>0,'Empty model'
        report['files'].append({'file':p.relative_to(root).as_posix(),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'triangles':count,'exported_vertices':verts,'degenerate_triangles_below_area_5e_minus10':degenerate,'meshes':len(doc.get('meshes',[])),'materials':len(doc.get('materials',[])),'embedded_images':len(doc.get('images',[])),'all_primitives_have_vertex_color':color,'all_primitives_have_uv0':uv,'external_dependencies':0})
    except Exception as e:report['errors'].append({'file':str(p.relative_to(root)),'error':str(e)})
report['glb_count']=len(files);report['passed_count']=len(report['files']);report['total_triangles_including_lods']=sum(x['triangles'] for x in report['files']);report['degenerate_triangles']=sum(x['degenerate_triangles_below_area_5e_minus10'] for x in report['files'])
(out/'glb_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ('files',)}));raise SystemExit(1 if report['errors'] else 0)
