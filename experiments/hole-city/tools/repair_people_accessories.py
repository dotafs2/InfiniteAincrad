"""Keep held props attached to the forearm/hand instead of the upper arm.
Only recolored accessory vertices in the original authored mesh are changed;
new rounded clothing, geometry, inverse binds and animation data are retained.
"""
import ast, hashlib, json, struct
import refine_mobile_people as glb

def run():
    tree=ast.parse((glb.ROOT/'tools/build_blender_catalog.py').read_text())
    colors=next(ast.literal_eval(node.value) for node in tree.body if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='PERSON_COLORS' for t in node.targets))
    path=glb.ROOT/'assets/city_kit/manifest.json';manifest=json.loads(path.read_text());changed={}
    for entry in manifest['assets']:
        if entry['group']!='person':continue
        file=glb.ROOT/entry['path'].removeprefix('res://');doc,blob=glb.load(file)
        if doc.get('extras',{}).get('held_props_v1'):continue
        primitive=doc['meshes'][0]['primitives'][0];attrs=primitive['attributes']
        joints=glb.read(doc,blob,attrs['JOINTS_0']);vertex_colors=glb.read(doc,blob,attrs['COLOR_0'])
        names={doc['nodes'][node]['name']:i for i,node in enumerate(doc['skins'][0]['joints'])}
        remap={names['arm'+side]:names['forearm'+side] for side in ['L','R']}
        original_count=doc['accessors'][0]['count'];count=0
        for i in range(original_count):
            if joints[i][0] not in remap:continue
            if sum((vertex_colors[i][k]-colors[entry['kind']][k])**2 for k in range(3))<1e-5:continue
            joints[i]=(remap[joints[i][0]],*joints[i][1:]);count+=1
        attrs['JOINTS_0']=glb.append(doc,blob,joints,'VEC4',5123)
        doc.setdefault('extras',{})['held_props_v1']=True;doc['buffers'][0]['byteLength']=len(blob)
        encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4);blob+=b'\0'*(-len(blob)%4)
        raw=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
        file.write_bytes(raw);entry['file_sha256']=hashlib.sha256(raw).hexdigest();changed[entry['kind']]=count
    path.write_text(json.dumps(manifest,indent=2)+'\n')
    out=glb.ROOT/'artifacts/actor-fixes/accessory-bindings.json';out.parent.mkdir(parents=True,exist_ok=True)
    if changed:out.write_text(json.dumps(changed,indent=2)+'\n')
    print('Held-prop vertices rebound:',sum(changed.values()))
if __name__=='__main__':run()
