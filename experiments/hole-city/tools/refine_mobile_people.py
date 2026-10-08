"""Add original rounded, skinned clothing and faces to the authored GLB rigs.
Preserves every original joint, role accessory and animation. Run once on the
7551f6c source catalog; marked outputs are idempotent. Requires only Python.
"""
import json, math, struct, hashlib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SCALES = [1.04,.98,1.18,1.02,1.06,1,.97,1.01,1,1.05,1.08,1,.96,1.12,1.03,1]
SHIRTS = ['367ade','684e85','77a5ad','ff9c47','f26458','fff0d7','4ccbc6','669acb','70c96e','b67edb','ffd260','6cd3d9','4979d0','b079de','ffab68','f47faa']
SKINS = ['f9cda5','c99271','8e5e49','efb990']
def color(h): return tuple(int(h[i:i+2],16)/255 for i in (0,2,4))+(1.0,)
def load(path):
    raw=path.read_bytes(); n=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+n]); off=20+n; size=struct.unpack_from('<I',raw,off)[0]
    return doc,bytearray(raw[off+8:off+8+size])
def read(doc,blob,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    stride=v.get('byteStride',struct.calcsize(fmt)*count)
    off=v.get('byteOffset',0)+a.get('byteOffset',0)
    rows=[struct.unpack_from('<'+fmt*count,blob,off+i*stride) for i in range(a['count'])]
    if a.get('normalized') and fmt!='f':
        maximum={5121:255,5123:65535}[a['componentType']]
        rows=[tuple(x/maximum for x in r) for r in rows]
    return rows
def append(doc,blob,rows,kind,ctype=5126):
    width={'SCALAR':1,'VEC3':3,'VEC4':4}[kind]
    assert all(len(row)==width for row in rows), (kind, {len(row) for row in rows})
    while len(blob)%4:blob.append(0)
    off=len(blob);fmt={5126:'f',5125:'I',5123:'H'}[ctype]
    for row in rows:blob.extend(struct.pack('<'+fmt*len(row),*row))
    vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(blob)-off})
    ai=len(doc['accessors']);doc['accessors'].append({'bufferView':vi,'componentType':ctype,'count':len(rows),'type':kind})
    return ai
def run():
    path=ROOT/'assets/city_kit/manifest.json';manifest=json.loads(path.read_text())
    for role,entry in enumerate(e for e in manifest['assets'] if e['group']=='person'):
        glb=ROOT/entry['path'].removeprefix('res://');doc,blob=load(glb)
        if doc.get('extras',{}).get('rounded_people_v1'):continue
        prim=doc['meshes'][0]['primitives'][0];attr=prim['attributes']
        data={k:read(doc,blob,v) for k,v in attr.items()}
        data['COLOR_0']=[tuple(row)+(1.0,) if len(row)==3 else row for row in data['COLOR_0']]
        indices=read(doc,blob,prim['indices'])
        joints={doc['nodes'][n]['name']:i for i,n in enumerate(doc['skins'][0]['joints'])}
        scale=SCALES[role];shirt=color(SHIRTS[role]);skin=color(SKINS[role%4]);pants=color('33486b')
        def orb(center,radii,tint,bone,segments=12,rings=8):
            base=len(data['POSITION'])
            for y in range(rings+1):
                a=math.pi*y/rings
                for x in range(segments):
                    b=math.tau*x/segments
                    u=(math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b))
                    pos=tuple((center[k]+radii[k]*u[k])*scale for k in range(3))
                    normal=tuple(u[k]/radii[k] for k in range(3));length=math.sqrt(sum(v*v for v in normal));normal=tuple(v/length for v in normal)
                    data['POSITION'].append(pos);data['NORMAL'].append(normal);data['COLOR_0'].append(tint)
                    data['JOINTS_0'].append((joints[bone],0,0,0));data['WEIGHTS_0'].append((1.,0.,0.,0.))
            for y in range(rings):
                for x in range(segments):
                    a=base+y*segments+x;b=base+y*segments+(x+1)%segments;c=a+segments;d=b+segments
                    indices.extend([(a,),(b,),(c,),(b,),(d,),(c,)])
        orb((0,.88,0),(.18,.255,.125),shirt,'root')
        orb((0,1.27,0),(.19,.19,.17),skin,'head',16,10)
        # Faces point along Godot +Z, matching the rig's authored forward.
        for side in [-1,1]:
            orb((side*.065,1.29,.157),(.025,.032,.014),color('243651'),'head',8,6)
            orb((side*.068,1.301,.170),(.007,.009,.005),color('ffffff'),'head',8,4)
            suffix='L' if side<0 else 'R'
            orb((side*.105,.55,0),(.074,.18,.08),pants,'thigh'+suffix)
            orb((side*.105,.245,.016),(.065,.17,.075),pants,'shin'+suffix)
            orb((side*.105,.065,.065),(.085,.060,.13),color('ffffff'),'shin'+suffix)
            orb((side*.18,.905,0),(.079,.145,.085),shirt,'arm'+suffix)
            orb((side*.205,.67,.01),(.064,.135,.065),skin,'forearm'+suffix)
            orb((side*.205,.55,.02),(.071,.075,.073),skin,'forearm'+suffix)
        for k,values in data.items():
            kind='VEC3' if k in ('POSITION','NORMAL') else 'VEC4'
            attr[k]=append(doc,blob,values,kind,5123 if k=='JOINTS_0' else 5126)
        prim['indices']=append(doc,blob,indices,'SCALAR',5125)
        lo=[min(p[i] for p in data['POSITION']) for i in range(3)];hi=[max(p[i] for p in data['POSITION']) for i in range(3)]
        doc['accessors'][attr['POSITION']].update(min=lo,max=hi)
        doc.setdefault('extras',{})['rounded_people_v1']=True;doc['buffers'][0]['byteLength']=len(blob)
        encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);blob+=b'\0'*((-len(blob))%4)
        raw=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
        glb.write_bytes(raw)
        entry.update(size=[hi[i]-lo[i] for i in range(3)],center=[(hi[i]+lo[i])/2 for i in range(3)],triangles=len(indices)//3,geometry_sha256=hashlib.sha256(json.dumps(data['POSITION']).encode()).hexdigest(),file_sha256=hashlib.sha256(raw).hexdigest())
    manifest['mobile_people']='Rounded original clothing and faces; original rigs and role clips retained'
    path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('Refined 16 authored rigs; original animation accessors preserved.')
if __name__=='__main__':run()
