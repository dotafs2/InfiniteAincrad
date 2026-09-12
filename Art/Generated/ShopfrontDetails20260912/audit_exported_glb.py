"""Read actual GLB buffers with Python stdlib, independent of Blender meshes."""
import json, struct, math, hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OUT=ROOT/'game/assets/generated/shopfront_details_20260912'
QA=ROOT/'docs/validation/art_parallel_20260912/shopfront'
COMP={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
NUM={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
results=[]
manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
for asset in manifest['assets']:
    path=ROOT/asset['file'];raw=path.read_bytes();magic,ver,total=struct.unpack_from('<III',raw)
    if magic!=0x46546c67 or ver!=2 or total!=len(raw):raise ValueError(path.name+' invalid GLB header')
    off=12;doc=None;buf=None
    while off<len(raw):
        size,kind=struct.unpack_from('<II',raw,off);body=raw[off+8:off+8+size];off+=8+size
        if kind==0x4E4F534A:doc=json.loads(body)
        elif kind==0x004E4942:buf=body
    def accessor(i):
        a=doc['accessors'][i];bv=doc['bufferViews'][a['bufferView']];fmt,s=COMP[a['componentType']];n=NUM[a['type']]
        start=bv.get('byteOffset',0)+a.get('byteOffset',0);stride=bv.get('byteStride',n*s)
        return [struct.unpack_from('<'+fmt*n,buf,start+j*stride) for j in range(a['count'])]
    errors=[];triangles=vertices=0;minarea=float('inf');lo=[float('inf')]*3;hi=[-float('inf')]*3
    for mesh in doc.get('meshes',[]):
        for primitive in mesh['primitives']:
            attr=primitive['attributes'];pos=accessor(attr['POSITION']);vertices+=len(pos)
            for p in pos:
                if not all(math.isfinite(x) for x in p):errors.append('nonfinite position')
                for k in range(3):lo[k]=min(lo[k],p[k]);hi[k]=max(hi[k],p[k])
            for key in ('NORMAL','TEXCOORD_0','TANGENT'):
                if key not in attr:errors.append('missing '+key);continue
                data=accessor(attr[key])
                if not all(math.isfinite(x) for v in data for x in v):errors.append('nonfinite '+key)
                if key=='NORMAL' and any(abs(math.sqrt(sum(x*x for x in v))-1)>.01 for v in data):errors.append('nonunit normal')
            inds=[v[0] for v in accessor(primitive['indices'])]
            if len(inds)%3:errors.append('non-triangle index count')
            if primitive.get('mode',4)!=4:errors.append('non-triangle primitive')
            for j in range(0,len(inds),3):
                if max(inds[j:j+3])>=len(pos):errors.append('index outside positions');continue
                a,b,c=(pos[inds[j+k]] for k in range(3));u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                area=math.sqrt(sum(x*x for x in cross))/2;minarea=min(minarea,area)
                if area<1e-10:errors.append('degenerate triangle')
            triangles+=len(inds)//3
            if primitive.get('material',-1) not in range(len(doc.get('materials',[]))):errors.append('invalid material')
    for m in doc.get('materials',[]):
        pbr=m.get('pbrMetallicRoughness')
        if pbr is None:errors.append('missing metallic/roughness material')
        else:
            vals=pbr.get('baseColorFactor',[1,1,1,1])+[pbr.get('metallicFactor',1),pbr.get('roughnessFactor',1)]
            if not all(math.isfinite(x) and 0<=x<=1 for x in vals):errors.append('invalid PBR factor')
    for im in doc.get('images',[]):
        if 'uri' in im:errors.append('external image URI')
        if 'bufferView' not in im:errors.append('image not embedded')
    digest=hashlib.sha256(raw).hexdigest()
    if digest!=asset['sha256']:errors.append('manifest hash mismatch')
    if triangles!=asset['triangles']:errors.append('manifest triangle mismatch')
    expected=[asset['dimensions_xyz_m'][k] for k in (0,2,1)]
    actual=[hi[k]-lo[k] for k in range(3)]
    if any(abs(actual[k]-expected[k])>.00002 for k in range(3)):errors.append('manifest dimension mismatch after Y-up conversion')
    if abs(lo[1])>.00001:errors.append('attachment base is not glTF Y=0')
    if any(any(k in n for k in ('translation','rotation','scale','matrix')) for n in doc.get('nodes',[])):errors.append('unexpected node transform at attachment origin')
    results.append({'file':path.name,'pass':not errors,'errors':sorted(set(errors)),'triangles':triangles,'exported_vertices_including_seams':vertices,'minimum_triangle_area_m2':minarea,'embedded_images':len(doc.get('images',[])),'materials':len(doc.get('materials',[])),'gltf_dimensions_xyz_m':[hi[k]-lo[k] for k in range(3)],'sha256':digest})
report={'method':'Independent Python stdlib GLB chunk/accessor inspection of exported float32 data','asset_count':len(results),'passed':all(r['pass'] for r in results),'total_triangles':sum(r['triangles'] for r in results),'total_bytes':sum((ROOT/a['file']).stat().st_size for a in manifest['assets']),'assets':results}
QA.mkdir(parents=True,exist_ok=True);(QA/'glb_binary_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='assets'},indent=2))
if not report['passed']:raise SystemExit(1)
