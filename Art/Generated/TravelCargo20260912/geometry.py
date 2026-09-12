"""Original first-floor market/craft props. Blender 4.5+, metres, Z-up.

Run: blender --background --threads 4 --python build_market_life.py
All geometry and materials are generated here; no imported assets or textures.
The asset geometry is at a ground-plane origin in every GLB. The editable
library arranges the original full-scale assets into named collections.
"""
import bpy
import math
import random
import json
import hashlib
import os
import sys
import time
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'game/assets/generated/travel_cargo_20260912'
EVIDENCE = ROOT / 'docs/validation/art_parallel_20260912/travel'
OUT.mkdir(parents=True, exist_ok=True)
EVIDENCE.mkdir(parents=True, exist_ok=True)
RNG = random.Random(12092026)
TAU = math.tau
STYLE = 'floor1_travel_cargo_20260912'

PALETTE = {
 'oak':('977344',.72,0), 'oak_light':('B28C58',.73,0),
 'oak_dark':('57432D',.79,0), 'grain':('765334',.85,0),
 'endgrain':('C29E69',.8,0), 'iron':('3C4543',.42,.72),
 'brass':('BB9150',.36,.72), 'canvas':('E8DABD',.92,0),
 'sage':('729477',.93,0), 'rust_cloth':('AC6554',.93,0),
 'blue_cloth':('668890',.88,0), 'thread':('D9C59D',.86,0),
 'terracotta':('AD6850',.75,0), 'clay_light':('C58864',.75,0),
 'glaze':('608F88',.31,0), 'glaze_dark':('416A66',.35,0),
 'bread':('C68C43',.76,0), 'bread_light':('E5BD77',.86,0),
 'bread_score':('8D552B',.86,0), 'red_apple':('B4513D',.48,0),
 'apple_gold':('D1AA4B',.53,0), 'leaf':('527B48',.82,0),
 'leaf_light':('89A461',.83,0), 'cabbage':('ABC28C',.86,0),
 'carrot':('D68B4D',.86,0), 'beet':('874E50',.87,0),
 'stone':('A9A491',.86,0), 'stone_light':('C7C2AC',.85,0),
 'paper':('E3D2A6',.92,0), 'ink':('696452',.86,0),
 'leather':('715541',.85,0), 'wheat':('D8B873',.88,0),
 'water':('78A29A',.21,0), 'black':('252A28',.9,0),
}
MATS={}

def material(key):
    if key in MATS: return MATS[key]
    hx,rough,metal = PALETTE[key]
    def lin(x):
        x=int(x,16)/255
        return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
    rgba=tuple(lin(hx[i:i+2]) for i in (0,2,4))+(1,)
    m=bpy.data.materials.new('TC_'+key)
    m.diffuse_color=rgba; m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=rgba
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    p.inputs['Specular IOR Level'].default_value=.3
    m['surface_recipe']='constant export-safe metallic/roughness PBR; no external files'
    MATS[key]=m
    return m

class Geo:
    def __init__(self): self.v=[]; self.f=[]; self.m=[]; self.s=[]
    def mesh(self,v,f,mat,smooth=False):
        b=len(self.v); self.v.extend([tuple(x) for x in v])
        self.f.extend([tuple(b+i for i in face) for face in f])
        self.m.extend([mat]*len(f)); self.s.extend([smooth]*len(f))
    def box(self,p,d,mat='oak',bevel=.012,rot=None):
        # Eight corners are clipped into three points each. The bevels are
        # authored geometry, so exports do not depend on modifier support.
        h=[a/2 for a in d]; b=min(bevel,min(h)*.45)
        signs=[(x,y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1)]
        v=[]; ids={}
        for s in signs:
            for a in range(3):
                co=[s[k]*(h[k]-(b if k==a else 0)) for k in range(3)]
                ids[s,a]=len(v); v.append(Vector(co))
        f=[]
        # A large face is an octagon, each old box edge is a bevel quad.
        for axis in range(3):
            others=[a for a in range(3) if a!=axis]
            for side in (-1,1):
                face=[]
                for u,w in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                    s=[0,0,0]; s[axis]=side; s[others[0]]=u; s[others[1]]=w
                    s=tuple(s)
                    pair=[ids[s,others[0]],ids[s,others[1]]]
                    # Angular sorting below gives consistent face winding.
                    face.extend(pair)
                center=Vector([side*h[axis] if a==axis else 0 for a in range(3)])
                face.sort(key=lambda i: math.atan2((v[i]-center)[others[1]],(v[i]-center)[others[0]]))
                f.append(tuple(face))
        for axis in range(3):
            others=[a for a in range(3) if a!=axis]
            for u in (-1,1):
                for w in (-1,1):
                    a=[0,0,0]; c=[0,0,0]
                    for ar,val in zip(others,(u,w)): a[ar]=c[ar]=val
                    a[axis]=-1; c[axis]=1; a=tuple(a); c=tuple(c)
                    f.append((ids[a,others[0]],ids[c,others[0]],ids[c,others[1]],ids[a,others[1]]))
        for s in signs: f.append(tuple(ids[s,a] for a in range(3)))
        self.mesh([Vector(p)+(rot@x if rot else x) for x in v],f,mat)
    def beam(self,a,b,w,mat='oak',depth=None):
        a,b=Vector(a),Vector(b); delta=b-a
        self.box((a+b)/2,(w,depth or w,delta.length),mat,min(.01,w*.13),delta.to_track_quat('Z','Y').to_matrix())
    def lathe(self,p,profile,mat,n=32,rot=None,cap=True):
        v=[]; rows=[]
        for r,z in profile:
            row=[]
            for i in range(1 if abs(r)<1e-9 else n):
                q=Vector((r*math.cos(TAU*i/n),r*math.sin(TAU*i/n),z));row.append(len(v))
                v.append(Vector(p)+(rot@q if rot else q))
            rows.append(row)
        f=[]
        for j in range(len(profile)-1):
            lower,upper=rows[j],rows[j+1]
            if len(lower)==len(upper)==1:continue
            for i in range(n):
                if len(lower)==1:f.append((lower[0],upper[(i+1)%n],upper[i]))
                elif len(upper)==1:f.append((lower[i],lower[(i+1)%n],upper[0]))
                else:f.append((lower[i],lower[(i+1)%n],upper[(i+1)%n],upper[i]))
        if cap:
            if len(rows[0])>1:f.append(tuple(reversed(rows[0])))
            if len(rows[-1])>1:f.append(tuple(rows[-1]))
        self.mesh(v,f,mat,True)
    def cyl(self,p,r,h,mat='oak',n=20,rot=None):
        self.lathe(p,[(r,0),(r,h)],mat,n,rot)
    def rod(self,a,b,r,mat='iron',n=12):
        a,b=Vector(a),Vector(b); delta=b-a
        self.cyl(a,r,delta.length,mat,n,delta.to_track_quat('Z','Y').to_matrix())
    def sphere(self,p,s,mat,n=20,rings=12,rot=None):
        v=[Vector((0,0,s[2]))]
        for j in range(1,rings):
            ph=math.pi*j/rings
            for i in range(n):
                t=TAU*i/n
                v.append(Vector((s[0]*math.sin(ph)*math.cos(t),s[1]*math.sin(ph)*math.sin(t),s[2]*math.cos(ph))))
        v.append(Vector((0,0,-s[2]))); f=[]
        for i in range(n): f.append((0,1+i,1+(i+1)%n))
        for j in range(rings-2):
            for i in range(n):
                a=1+j*n+i; b=1+j*n+(i+1)%n
                f.append((a,a+n,b+n,b))
        end=len(v)-1; start=1+(rings-2)*n
        for i in range(n): f.append((end,start+(i+1)%n,start+i))
        self.mesh([Vector(p)+(rot@x if rot else x) for x in v],f,mat,True)
    def tube(self,points,r,mat='iron',sides=8,closed=False):
        points=[Vector(p) for p in points]; v=[]; previous_u=None
        for j,p in enumerate(points):
            before=points[(j-1)%len(points)] if closed or j>0 else points[0]
            after=points[(j+1)%len(points)] if closed or j<len(points)-1 else points[-1]
            t=(after-before).normalized()
            # Carry the cross-section frame along the curve. Switching a global
            # reference at a dot threshold twists circular wheel rims abruptly.
            if previous_u is None:
                ref=min((Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))),key=lambda q:abs(t.dot(q)))
                u=t.cross(ref).normalized()
            else:
                u=previous_u-t*previous_u.dot(t)
                if u.length<1e-7:
                    ref=min((Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1))),key=lambda q:abs(t.dot(q)))
                    u=t.cross(ref)
                u.normalize()
            previous_u=u.copy();w=t.cross(u).normalized()
            for i in range(sides): v.append(p+r*(u*math.cos(TAU*i/sides)+w*math.sin(TAU*i/sides)))
        f=[]
        for j in range(len(points) if closed else len(points)-1):
            for i in range(sides):
                a=j*sides+i; b=j*sides+(i+1)%sides
                c=((j+1)%len(points))*sides
                f.append((a,b,c+(i+1)%sides,c+i))
        if not closed: f.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+i for i in range(sides))])
        self.mesh(v,f,mat,True)
    def ring(self,p,r,t,mat='iron',axis='Z',n=36,sides=8,scale=(1,1)):
        points=[]
        for i in range(n):
            a=TAU*i/n; q=[r*math.cos(a)*scale[0],r*math.sin(a)*scale[1],0]
            if axis=='X': q=[0,q[0],q[1]]
            if axis=='Y': q=[q[0],0,q[1]]
            points.append(Vector(p)+Vector(q))
        self.tube(points,t,mat,sides,True)
    def leaf(self,p,vec,w,mat='leaf'):
        p=Vector(p); vec=Vector(vec); t=vec.normalized()
        u=t.cross(Vector((0,0,1))).normalized()
        if u.length<.1: u=Vector((1,0,0))
        v=[p,p+vec*.28+u*w*.6,p+vec*.65+u*w*.48,p+vec,
           p+vec*.65-u*w*.48,p+vec*.28-u*w*.6,p+vec*.5+Vector((0,0,.02))]
        self.mesh(v,[(i,(i+1)%6,6) for i in range(6)],mat,True)
        self.rod(p,p+vec,.004,'leaf_light',6)
    def finish(self,name,col):
        me=bpy.data.meshes.new(name+'_Mesh'); me.from_pydata(self.v,[],self.f); me.update()
        keys=list(dict.fromkeys(self.m)); look={k:i for i,k in enumerate(keys)}
        for key in keys: me.materials.append(material(key))
        for poly,key,smooth in zip(me.polygons,self.m,self.s):
            poly.material_index=look[key]; poly.use_smooth=smooth
        obj=bpy.data.objects.new(name,me); col.objects.link(obj)
        # Recalculate winding once, covering clipped boxes and all closed forms.
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
        obj.select_set(False)
        uv=me.uv_layers.new(name='UVMap')
        for poly in me.polygons:
            axis=max(range(3),key=lambda k:abs(poly.normal[k])); axes=[k for k in range(3) if k!=axis]
            for li in poly.loop_indices:
                co=me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv=(co[axes[0]],co[axes[1]])
        obj['style_id']=STYLE; obj['units']='metres'; obj['source_axis']='Z up'
        obj['provenance']='Original procedural geometry; no external dependency'
        return obj

def bolt(g,p,axis='Y',r=.018):
    rot=Matrix.Rotation(math.pi/2,3,'X') if axis=='Y' else None
    g.cyl(p,r,.012,'iron',8,rot)

def plank(g,p,d,mat='oak',grain=True):
    g.box(p,d,mat,.009)
    if grain and d[0]>.15:
        for j in range(2):
            y=p[1]+(j-.5)*d[1]*.32
            pts=[(p[0]-d[0]*.41+k*d[0]*.16,y+math.sin(k*1.9+j)*.004,p[2]+d[2]/2+.0008) for k in range(6)]
            g.tube(pts,.0015,'grain',5)

def crate(g,p=(0,0,0),w=.8,d=.58,h=.5):
    x,y,z=p
    for i in range(5): plank(g,(x,y-d/2+(i+.5)*d/5,z+.035),(w-.07,d/5-.008,.065),'oak_light')
    for i in range(3):
        zz=z+.14+i*(h-.18)/2
        for sy in (-1,1):
            g.box((x,y+sy*d/2,zz),(w,.048,.092),'oak_light')
            for sx in (-1,1): bolt(g,(x+sx*(w/2-.08),y+sy*(d/2+.026),zz))
        for sx in (-1,1): g.box((x+sx*w/2,y,zz),(.048,d,.092),'oak')
    for sx in (-1,1):
        for sy in (-1,1): g.box((x+sx*(w/2-.05),y+sy*(d/2-.05),z+h/2),(.07,.07,h),'oak_dark')
    # Contrasting framed hand holes in end rails: two short handle shoulders.
    for sx in (-1,1):
        for sy in (-1,1):g.box((x+sx*w/2,y+sy*d*.35,z+h),(.065,d*.24,.1),'oak_light')
        g.box((x+sx*w/2,y,z+h+.048),(.065,d*.85,.035),'oak_light')

def apple(g,p,mat='red_apple',r=.083):
    g.sphere(p,(r,r,r*.9),mat,20,10)
    g.rod(Vector(p)+Vector((0,0,r*.75)),Vector(p)+Vector((.012,0,r*1.18)),.009,'oak_dark',8)
    g.leaf(Vector(p)+Vector((.008,0,r)),(.062,.01,.018),.025)

def loaf(g,p,size=(.25,.13,.105),round=False):
    g.sphere(p,size,'bread',28,14)
    sx,sy,sz=size
    for j in range(3 if not round else 4):
        x=(j-(1 if not round else 1.5))*sx*.47
        pts=[]
        for k in range(9):
            y=(-.72+k*.18)*sy; xx=x+y*.35
            zz=sz*math.sqrt(max(.03,1-(xx/sx)**2-(y/sy)**2))
            pts.append((p[0]+xx,p[1]+y,p[2]+zz+.001))
        g.tube(pts,.007,'bread_score',6)
        g.tube([(x,y+.009,z+.006) for x,y,z in pts],.005,'bread_light',6)

def basket(g,p=(0,0,0),r=.3,h=.31,oval=1):
    x,y,z=p
    g.lathe(p,[(r*.72,0),(r*.95,h*.83),(r,h),(r-.023,h),(r*.95-.023,h*.83),(r*.72-.023,.024)],'thread',32)
    for j in range(12):
        zz=h*(j+.5)/12; rr=r*(.72+.28*zz/h)
        g.ring((x,y,z+zz),rr,.012,'oak_light',n=40,sides=6,scale=(oval,1))
    for i in range(24):
        a=TAU*i/24
        pts=[]
        for j in range(17):
            zz=h*j/16; rr=r*(.72+.28*j/16)+.007*math.sin(j*math.pi*1.5+i*math.pi)
            pts.append((x+rr*math.cos(a)*oval,y+rr*math.sin(a),z+zz))
        g.tube(pts,.012,'oak',6)
    g.ring((x,y,z+h),r,.022,'oak_light',scale=(oval,1))

def wheel(g,p,r=.45,axis='X',spokes=12):
    g.ring(p,r,.041,'iron',axis,n=48)
    g.ring(p,r-.06,.04,'oak_light',axis,n=48)
    for i in range(spokes):
        a=TAU*i/spokes
        q=(0,(r-.065)*math.cos(a),(r-.065)*math.sin(a)) if axis=='X' else ((r-.065)*math.cos(a),0,(r-.065)*math.sin(a))
        g.beam(p,Vector(p)+Vector(q),.033,'oak_light')
    rot=Matrix.Rotation(math.pi/2,3,'Y' if axis=='X' else 'X')
    offset=Vector((-.065,0,0) if axis=='X' else (0,.065,0))
    g.cyl(Vector(p)+offset,.085,.13,'oak_dark',20,rot)
    g.cyl(Vector(p)+offset*.8,.042,.14,'iron',12,rot)

def table(g,w=1.3,d=.64,h=.8):
    for i in range(5): plank(g,(0,-d/2+(i+.5)*d/5,h-.055),(w,d/5-.006,.11),'oak_light')
    for sx in (-1,1):
        for sy in (-1,1):g.box((sx*(w/2-.12),sy*(d/2-.10),(h-.12)/2),(.105,.105,h-.12),'oak')
        g.box((sx*(w/2-.12),0,.23),(.08,d-.10,.09),'oak_dark')
    g.box((0,0,.23),(w-.18,.085,.09),'oak')
    for sy in (-1,1):g.box((0,sy*(d/2-.07),h-.18),(w-.06,.075,.15),'oak')

def pot(g,p=(0,0,0),r=.23,h=.56,mat='terracotta',handle=False):
    profile=[(r*.53,0),(r*.57,.025*h),(r*.82,.12*h),(r,.42*h),(r*.94,.64*h),(r*.61,.82*h),(r*.48,.86*h),(r*.48,.96*h),(r*.56,.98*h),(r*.57,h),(r*.45,h),(r*.4,.95*h),(r*.42,.87*h),(r*.57,.81*h),(r*.82,.63*h),(r*.87,.42*h),(r*.68,.16*h),(0,.1*h)]
    g.lathe(p,profile,mat,48)
    for frac in (.13,.19,.63,.69):g.ring(Vector(p)+Vector((0,0,h*frac)),r*(.83 if frac<.2 else .93),.009,'clay_light',n=48,sides=6)
    if handle:
        for sign in (-1,1):
            pts=[Vector(p)+Vector((sign*(r*.55+r*.59*math.sin(math.pi*i/16)),0,h*(.85-.44*i/16))) for i in range(17)]
            g.tube(pts,.029,mat,10)
