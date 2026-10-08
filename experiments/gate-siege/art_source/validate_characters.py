"""Verify standalone GLB geometry contracts without Blender or Godot."""
import json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
HEIGHTS={'infantry':1.,'gunner':1.8,'gunner_silver':1.8,'mech':3.4,'brute':3.4,'brute_vest':3.4,'zombie':.65}
results=[]
for name,height in HEIGHTS.items():
 path=ROOT/'assets/models'/(name+'.glb');raw=path.read_bytes()
 magic,version,length=struct.unpack_from('<III',raw)
 assert magic==0x46546c67 and version==2 and length==len(raw)
 count,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
 gltf=json.loads(raw[20:20+count]);accessors=gltf['accessors'];low=[];high=[];tris=0
 assert len(gltf['nodes'])==1 and len(gltf['meshes'])==1
 assert not any(k in gltf['nodes'][0] for k in ['rotation','scale','translation','matrix'])
 assert not gltf.get('images') and not gltf.get('textures')
 for prim in gltf['meshes'][0]['primitives']:
  pos=accessors[prim['attributes']['POSITION']];low.append(pos['min']);high.append(pos['max'])
  tris+=accessors[prim['indices']]['count']//3
  if name in ('infantry','zombie'):assert 'COLOR_0' in prim['attributes']
 lo=[min(v[k] for v in low) for k in range(3)];hi=[max(v[k] for v in high) for k in range(3)]
 assert abs(lo[1])<1e-6 and abs(hi[1]-height)<1e-6
 if name in ('infantry','zombie'):assert len(gltf['meshes'][0]['primitives'])==1
 results.append({'name':name,'sha256':hashlib.sha256(raw).hexdigest(),'godot_aabb_min':lo,'godot_aabb_max':hi,'triangles':tris,'surfaces':len(gltf['meshes'][0]['primitives'])})
(ROOT/'assets/models/validation.json').write_text(json.dumps({'verified':results},indent=2)+'\n')
print('PASS: seven GLB binary/header, texture independence, origin, bounds, surface and vertex-palette contracts')
