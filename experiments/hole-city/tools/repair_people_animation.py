"""Rebuild bounded local-pose curves from the GLB bind matrices (no Blender needed).
Keeps meshes, skin joints, inverse binds and all four public clip names.
"""
import math, json, struct, hashlib
import refine_mobile_people as glb

def mul(a,b): return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def inverse(a):
    x=[list(row)+[float(i==j) for j in range(4)] for i,row in enumerate(a)]
    for i in range(4):
        pivot=max(range(i,4),key=lambda k:abs(x[k][i]));x[i],x[pivot]=x[pivot],x[i]
        f=x[i][i];assert abs(f)>1e-10;x[i]=[v/f for v in x[i]]
        for j in range(4):
            if j!=i:
                f=x[j][i];x[j]=[x[j][k]-f*x[i][k] for k in range(8)]
    return [row[4:] for row in x]
def quat(m):
    trace=sum(m[i][i] for i in range(3))
    if trace>0:
        s=math.sqrt(trace+1)*2;q=((m[2][1]-m[1][2])/s,(m[0][2]-m[2][0])/s,(m[1][0]-m[0][1])/s,s/4)
    else:
        i=max(range(3),key=lambda k:m[k][k]);j=(i+1)%3;k=(j+1)%3;s=math.sqrt(1+m[i][i]-m[j][j]-m[k][k])*2
        v=[0.,0.,0.];v[i]=s/4;v[j]=(m[j][i]+m[i][j])/s;v[k]=(m[k][i]+m[i][k])/s;q=(*v,(m[k][j]-m[j][k])/s)
    norm=math.sqrt(sum(v*v for v in q));return tuple(v/norm for v in q)
def qmul(a,b):
    x,y,z,w=a;X,Y,Z,W=b
    return (w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z)
def axis(angle,which=0):
    v=[0.,0.,0.,math.cos(angle/2)];v[which]=math.sin(angle/2);return v

def motion(clip,name,phase):
    side=1 if name.endswith('L') else -1
    wave=math.sin(phase)*side
    running=clip in ('Run','Chase','Jog');walking=clip in ('Walk','Skate','Pedal','Sneak','Patrol')
    if running or walking:
        amount=.48 if running else .30
        if name.startswith('thigh'):return axis(wave*amount)
        if name.startswith('shin'):return axis(max(0.,wave)*(.72 if running else .38))
        if name.startswith('arm'):return axis(-wave*amount*.72)
        if name.startswith('forearm'):return axis((-.65 if running else -.16)+math.cos(phase)*.035)
        return axis(0)
    # Stationary role actions affect arms, not the pelvis/head/knees together.
    a=0.
    if clip=='Idle':
        if name.startswith('forearm'):a=-.12
        if name=='head':return axis(math.sin(phase)*.025,1)
    elif clip=='Eat_Fries':
        if name=='forearmR':a=-.65-.18*math.sin(phase)
        if name=='armR':a=-.15
    elif clip in ('Hose','Shoot','Carry','Hero_Pose'):
        if name.startswith('arm'):a=-.32+math.sin(phase)*.025
        if name.startswith('forearm'):a=-.38
    elif clip in ('Flip','Hammer'):
        if name=='armR':a=-.15
        if name=='forearmR':a=-.35+math.sin(phase)*.28
    elif clip=='Strum':
        if name=='armL':a=-.25
        if name=='forearmR':a=-.2+math.sin(phase*2)*.15
    elif clip=='Care':
        if name.startswith('arm'):a=-.18+math.sin(phase)*.08
    elif clip=='Dance':
        if name.startswith('arm'):return axis(side*(.25+math.sin(phase)*.15),2)
        if name.startswith('thigh'):a=wave*.12
        if name.startswith('shin'):a=max(0.,wave)*.18
    return axis(a)

def run():
    path=glb.ROOT/'assets/city_kit/manifest.json';manifest=json.loads(path.read_text());report=[]
    for entry in manifest['assets']:
        if entry['group']!='person':continue
        file=glb.ROOT/entry['path'].removeprefix('res://');doc,blob=glb.load(file)
        if doc.get('extras',{}).get('bounded_animation_v2'):continue
        skin=doc['skins'][0];access=doc['accessors'][skin['inverseBindMatrices']];view=doc['bufferViews'][access['bufferView']]
        offset=view.get('byteOffset',0)+access.get('byteOffset',0);world={}
        for i,node in enumerate(skin['joints']):
            values=struct.unpack_from('<16f',blob,offset+i*64)
            world[node]=inverse([[values[col*4+row] for col in range(4)] for row in range(4)])
        parents={child:i for i,n in enumerate(doc['nodes']) for child in n.get('children',[])};rest={}
        for node in skin['joints']:
            local=mul(inverse(world[parents[node]]),world[node]) if parents.get(node) in world else world[node]
            rest[node]=(quat(local),tuple(local[i][3] for i in range(3)))
            doc['nodes'][node].update(rotation=rest[node][0],translation=rest[node][1],scale=[1,1,1])
        animations=[]
        for clip in entry['animations']:
            duration=1.25 if clip=='Walk' else .65 if clip=='Run' else 2.
            times=[(i*duration/32,) for i in range(33)];time_index=glb.append(doc,blob,times,'SCALAR');doc['accessors'][time_index].update(min=[0],max=[duration])
            animation={'name':clip,'channels':[],'samplers':[]}
            def channel(node,prop,values,kind):
                sample=len(animation['samplers']);animation['samplers'].append({'input':time_index,'output':glb.append(doc,blob,values,kind),'interpolation':'LINEAR'});animation['channels'].append({'sampler':sample,'target':{'node':node,'path':prop}})
            for node in skin['joints']:
                name=doc['nodes'][node]['name'];q,t=rest[node]
                values=[qmul(q,motion(clip,name,math.tau*i/32)) for i in range(33)]
                channel(node,'rotation',values,'VEC4')
                if name=='root':
                    lift=.006 if clip in ('Walk','Run','Jog','Chase','Dance') else .002
                    channel(node,'translation',[(t[0],t[1]+lift*(1-math.cos(math.tau*i/16)),t[2]) for i in range(33)],'VEC3')
            animations.append(animation)
        doc['animations']=animations;doc.setdefault('extras',{})['bounded_animation_v2']=True;doc['buffers'][0]['byteLength']=len(blob)
        encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4);blob+=b'\0'*(-len(blob)%4)
        raw=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
        file.write_bytes(raw);entry['file_sha256']=hashlib.sha256(raw).hexdigest();report.append(entry['id'])
    manifest['mobile_people']='Rounded original geometry with bind-rest-based bounded locomotion and stationary gestures'
    path.write_text(json.dumps(manifest,indent=2)+'\n');print('Repaired animation curves:',len(report))
if __name__=='__main__':run()
