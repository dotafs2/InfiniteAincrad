"""Independent-format author checks of exported GLB buffers, without Blender/Godot.
Run from any cwd. Does not touch runtime or import caches.
"""
from pathlib import Path
import json, struct, math, hashlib

ROOT=Path(__file__).resolve().parents[2]
MANIFEST=ROOT/'assets/trains/manifest.json'
COMP={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
COUNTS={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
checks=0;failures=[]
def check(value,label):
 global checks
 checks+=1
 if not value:failures.append(label)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read_glb(path):
 d=path.read_bytes();check(struct.unpack_from('<III',d)==(0x46546c67,2,len(d)),str(path.name)+': glTF2 header')
 n,kind=struct.unpack_from('<II',d,12);check(kind==0x4e4f534a,path.name+': JSON chunk')
 g=json.loads(d[20:20+n]);offset=20+n;bn,bk=struct.unpack_from('<II',d,offset)
 check(bk==0x004e4942 and offset+8+bn==len(d),path.name+': complete internal binary chunk')
 return g,d[offset+8:offset+8+bn]
def acc(g,b,i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];char,nb=COMP[a['componentType']];cnt=COUNTS[a['type']]
 start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',nb*cnt)
 rows=[struct.unpack_from('<'+char*cnt,b,start+j*stride) for j in range(a['count'])]
 if a.get('normalized'):
  scale={5121:255.,5123:65535.,5120:127.,5122:32767.}[a['componentType']]
  rows=[tuple(max(-1,x/scale) for x in r) for r in rows]
 return rows

def cross(a,b):return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def norm(v):return math.sqrt(dot(v,v))

def inspect(row):
 path=ROOT/row['file'].removeprefix('res://');g,b=read_glb(path);key=row['key']
 check(sha(path)==row['sha256'],key+': exact file hash')
 check(path.stat().st_size==row['bytes'],key+': byte budget receipt')
 check(len(g.get('nodes',[]))==1 and g['nodes'][0]=={'mesh':0,'name':key},key+': one mesh node, no hidden transform')
 check(len(g['meshes'])==1 and len(g['meshes'][0]['primitives'])==1,key+': one draw surface')
 check(not g.get('images') and not g.get('textures') and not g.get('skins') and not g.get('animations'),key+': no textures/skinning/animation overhead')
 check(len(g['materials'])==1 and g['materials'][0].get('alphaMode','OPAQUE')=='OPAQUE' and not g['materials'][0].get('doubleSided',False),key+': one opaque culled material')
 check(.25<=g['materials'][0]['pbrMetallicRoughness']['roughnessFactor']<=.4,key+': rounded glaze roughness')
 p=g['meshes'][0]['primitives'][0];atts=p['attributes'];pos=acc(g,b,atts['POSITION']);normal=acc(g,b,atts['NORMAL']);col=acc(g,b,atts['COLOR_0']);ind=[x[0] for x in acc(g,b,p['indices'])]
 check(len(ind)%3==0 and len(ind)//3==row['triangles']<=1500,key+': actual triangle count')
 check(len(pos)==len(normal)==len(col)==row['vertices'],key+': consistent actual vertex attributes')
 check(all(math.isfinite(x) for a in [pos,normal,col] for r in a for x in r),key+': finite geometry/color/normal buffers')
 check(all(0<=i<len(pos) for i in ind),key+': all indices in range')
 check(all(abs(norm(n)-1)<.0001 for n in normal),key+': unit shading normals')
 check(all(0<=x<=1 for c in col for x in c),key+': valid color range')
 unique_colors={tuple(round(x,4) for x in c) for c in col};check(len(unique_colors)>=5,key+': genuine ingredient/body palette')
 lo=[min(v[j] for v in pos) for j in range(3)];hi=[max(v[j] for v in pos) for j in range(3)]
 for label,measured in [('min',lo),('max',hi),('size',[b-a for a,b in zip(lo,hi)])]:
  check(all(abs(x-y)<1e-5 for x,y in zip(measured,row['bounds'][label])),key+': actual buffer '+label+' matches receipt')
 check(abs(lo[1])<1e-5 and abs(lo[0]+hi[0])<1e-5 and abs(lo[2]+hi[2])<1e-5,key+': actual baseY0 and XZ center')
 areas=[];normals_wrong=0
 for i in range(0,len(ind),3):
  ids=ind[i:i+3];a,bb,c=[pos[j] for j in ids];face=cross(sub(bb,a),sub(c,a));areas.append(norm(face)*.5)
  averaged=tuple(sum(normal[k][j] for k in ids)/3 for j in range(3))
  if dot(face,averaged)<-1e-10:normals_wrong+=1
 check(min(areas)>1e-10,key+': no zero-area exported triangles')
 check(normals_wrong==0,key+': exported face winding agrees with smooth normals')
 # Weld by actual geometric positions, then verify closed components have
 # positive volume. Decorative marbling/glazing panels are intentionally open.
 verts=[];lookup={};weld=[]
 for v in pos:
  k=tuple(round(x,6) for x in v)
  if k not in lookup:lookup[k]=len(verts);verts.append(v)
  weld.append(lookup[k])
 tris=[tuple(weld[j] for j in ind[i:i+3]) for i in range(0,len(ind),3)]
 parent=list(range(len(verts)))
 def find(v):
  while parent[v]!=v:parent[v]=parent[parent[v]];v=parent[v]
  return v
 for a,bb,c in tris:
  for v in [bb,c]:parent[find(v)]=find(a)
 groups={}
 for t in tris:groups.setdefault(find(t[0]),[]).append(t)
 closed=0;positive=0
 for ts in groups.values():
  edges={}
  for t in ts:
   for a,bb in zip(t,(t[1],t[2],t[0])):e=tuple(sorted((a,bb)));edges[e]=edges.get(e,0)+1
  if all(n==2 for n in edges.values()):
   closed+=1;vol=sum(dot(verts[a],cross(verts[bb],verts[c]))/6 for a,bb,c in ts)
   if vol>1e-10:positive+=1
 check(closed>=8 and positive==closed,key+': closed solids have outward winding')
 digest=hashlib.sha256(json.dumps([pos,normal,col,ind],separators=(',',':')).encode()).hexdigest()
 return dict(key=key,triangles=len(ind)//3,vertices=len(pos),colors=len(unique_colors),closed_components=closed,positive_volume_components=positive,minimum_triangle_area=min(areas),geometry_content_sha256=digest,bounds={'min':lo,'max':hi})

m=json.loads(MANIFEST.read_text());check(len(m['assets'])==10,'ten standalone vehicles')
check(len({r['key'] for r in m['assets']})==10,'ten stable unique IDs')
check(sha(ROOT/m['generator'])==m['generator_sha256'],'generator hash is current')
check(sha(ROOT/m['source'])==m['source_sha256'],'actual blend source hash is current')
rows=[inspect(r) for r in m['assets']]
check(len({r['geometry_content_sha256'] for r in rows})==10,'ten genuinely different geometry/color buffer sets')
check(m['total_glb_bytes']==sum(r['bytes'] for r in m['assets'])<700000,'all ten GLBs fit 700KB budget')
result=dict(checks=checks,failures=failures,assets=rows,scope='Direct final GLB binary and source hash validation; no runtime physics, browser or mobile FPS claim.')
(ROOT/'art_source/trains/asset-acceptance.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'checks':checks,'failures':failures,'triangles':[r['triangles'] for r in rows]},indent=2))
raise SystemExit(bool(failures))
