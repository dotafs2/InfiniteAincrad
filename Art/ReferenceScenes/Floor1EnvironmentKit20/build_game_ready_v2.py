"""Reauthor the 20 Floor-1 components with botanical topology and three LODs.

Run with Blender --background --python build_game_ready_v2.py.
No downloaded meshes/textures. Vertex colour is the authored palette; UV0 holds
leaf/wood coordinates, UV1 holds wind stiffness and independent leaf phase.
The earlier source and exports remain available for comparison/recovery.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "game/assets/floor1/environment_kit_v2"
R = random.Random(2611)
LOD = 0
TAU = math.tau
Z = Vector((0, 0, 1))
PALETTE = {
    "leaf": "5C843E", "light": "8EAA51", "dark": "355F37", "sage": "608264",
    "grass": "7D9D4B", "grass_tip": "B0B967", "bark": "79654B", "barkdark": "4D4435",
    "birch": "D5D4BE", "wood": "7E674C", "woodlight": "A08862", "stone": "B6B39B",
    "stoneshade": "888D7C", "moss": "728246", "soil": "4B4530", "cream": "EEE3B5",
    "blue": "879CC7", "purple": "9C85BA", "pink": "D69CA5", "gold": "D2AD53",
    "berry": "A35348", "iron": "494C45", "canvas": "E8DDC2", "stripe": "6C9380",
    "water": "63978F", "system": "70C3C7",
}


def rgb(key, shade=1.0):
    h = PALETTE.get(key, key)
    def lin(x):
        x = min(1., max(0., x * shade))
        return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4
    return tuple(lin(int(h[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1.,)


def material(kind):
    name = "F2_" + kind
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get("Principled BSDF")
    vc = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mat.node_tree.links.new(vc.outputs["Color"], bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = .83 if kind != "water" else .24
    bs.inputs["Specular IOR Level"].default_value = .22
    mat.use_backface_culling = kind not in ("foliage", "fabric")
    return mat


class Mesh:
    def __init__(self):
        self.v, self.f, self.col, self.uv, self.wind, self.roles, self.smooth = [], [], [], [], [], [], []
        self.leaf_count = 0

    def add(self, verts, faces, color, kind="solid", uvs=None, winds=None, smooth=False, shades=None):
        start = len(self.v)
        self.v.extend(tuple(v) for v in verts)
        self.f.extend(tuple(start + i for i in face) for face in faces)
        self.roles.extend([kind] * len(faces))
        self.smooth.extend([smooth] * len(faces))
        shade = R.uniform(.93, 1.05)
        self.col.extend(rgb(color, shades[i] if shades else shade) for i in range(len(verts)))
        self.uv.extend(uvs or [(v[0], v[2]) for v in verts])
        self.wind.extend(winds or [(0., 0.)] * len(verts))

    def box(self, p, size, color, rot=None, kind="solid"):
        v = [Vector((x*size[0]/2, y*size[1]/2, z*size[2]/2)) for x,y,z in
             [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        self.add([Vector(p)+(rot@a if rot else a) for a in v],
                 [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], color, kind,
                 [(a.z*2,a.x*.65) if size[0]>size[2] else (a.x*2,a.z*.65) for a in v])

    def beam(self, a, b, width, depth, color):
        a,b=Vector(a),Vector(b)
        self.box((a+b)/2, (width,depth,(b-a).length), color, (b-a).to_track_quat("Z","Y").to_matrix(), "wood")

    def tube(self, points, radii, color="bark", sides=8, stiffness=0., kind="wood"):
        points=[Vector(p) for p in points]
        sides=max(5, sides-LOD*2)
        verts,uvs,winds=[],[],[]
        distance=0.
        phase=R.random()
        for j,p in enumerate(points):
            tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
            ref=Z if abs(tangent.z)<.94 else Vector((1,0,0))
            u=tangent.cross(ref).normalized(); v=tangent.cross(u).normalized()
            if j: distance+=(p-points[j-1]).length
            for i in range(sides):
                angle=TAU*i/sides
                fluting=1.+.08*math.sin(i*3.+j*.5)
                verts.append(p+radii[j]*fluting*(math.cos(angle)*u+math.sin(angle)*v))
                uvs.append((i/sides, distance*.8))
                winds.append((stiffness*(j/(len(points)-1))**1.6, phase))
        faces=[tuple(range(sides-1,-1,-1))]
        for j in range(len(points)-1):
            for i in range(sides):
                a=j*sides+i; b=j*sides+(i+1)%sides
                faces.append((a,b,b+sides,a+sides))
        faces.append(tuple((len(points)-1)*sides+i for i in range(sides)))
        self.add(verts,faces,color,kind,uvs,winds,True)

    def ellipsoid(self,p,scale,color,n=10,rings=5,kind="solid",irregular=.0,wind=0.):
        local_random=random.Random(R.getrandbits(32))
        n=max(6,n-LOD*2); rings=max(3,rings-LOD)
        verts=[Vector(p)+Vector((0,0,scale[2]))]
        for j in range(1,rings):
            a=math.pi*j/rings
            for i in range(n):
                t=TAU*i/n; s=1.+local_random.uniform(-irregular,irregular)
                verts.append(Vector(p)+Vector((math.sin(a)*math.cos(t)*scale[0]*s,math.sin(a)*math.sin(t)*scale[1]*s,math.cos(a)*scale[2]*s)))
        verts.append(Vector(p)-Vector((0,0,scale[2])))
        faces=[(0,1+i,1+(i+1)%n) for i in range(n)]
        for j in range(rings-2):
            for i in range(n):
                a=1+j*n+i;b=1+j*n+(i+1)%n
                faces.append((a,a+n,b+n,b))
        last=1+(rings-2)*n
        faces.extend((last+i,len(verts)-1,last+(i+1)%n) for i in range(n))
        self.add(verts,faces,color,kind,winds=[(wind,0.)]*len(verts),smooth=irregular==0)

    def leaf(self,p,direction,length,width,color="leaf",flex=.5,form="oval",normal=None):
        # A curved centre rib and serrated/lobed margins, no box or sphere foliage.
        p=Vector(p); d=Vector(direction).normalized()
        normal=Vector(normal or (0,0,1)).normalized()
        side=d.cross(normal).normalized()
        if side.length<.1: side=d.cross(Vector((0,1,0))).normalized()
        normal=side.cross(d).normalized()
        steps=4 if LOD==0 else 3 if LOD==1 else 2
        if form in ("oak", "maple", "ivy") and LOD==0: steps=6
        self.leaf_count += 1
        keep=(self.leaf_count*2654435761 % 997)/997 < [1.,.57,.25][LOD]
        length *= [1.,1.13,1.38][LOD]
        width *= [1.,1.13,1.38][LOD]
        vs=[];uv=[];ws=[];shades=[];phase=R.random();shade=R.uniform(.83,1.14)
        for j in range(steps+1):
            t=j/steps
            w=math.sin(math.pi*t)**.78*width*.5
            if form=="maple": w*=1.+.48*math.sin(t*math.pi*4)
            if form=="ivy": w*=1.+.40*math.cos(t*math.pi*5)
            if form=="oak": w*=.85+.30*math.cos(t*math.pi*6)
            center=p+d*(length*t)+normal*(math.sin(t*math.pi)*length*.13-t*t*length*.12)
            for k in (-1,0,1):
                vs.append(center+side*w*k-normal*abs(k)*width*.10)
                uv.append(((k+1)*.5,t))
                ws.append((flex*(.68+.32*t),phase))
                shades.append(shade*(.88+.20*t+(.07 if k==0 else 0)))
        fs=[]
        for j in range(steps):
            for k in range(2):
                a=j*3+k; fs.append((a,a+3,a+4,a+1))
        if keep: self.add(vs,fs,color,"foliage",uv,ws,True,shades)
        else: self.add([],[],color,"foliage")  # Preserve the random stream across LODs.

    def object(self,name,collection,bevel=0.):
        me=bpy.data.meshes.new(name)
        me.from_pydata(self.v,[],self.f);me.update()
        ob=bpy.data.objects.new(name,me);collection.objects.link(ob)
        kinds=list(dict.fromkeys(self.roles))
        for kind in kinds: me.materials.append(material(kind))
        uv=me.uv_layers.new(name="UVMap");wind=me.uv_layers.new(name="Wind")
        col=me.color_attributes.new(name="Col",type="FLOAT_COLOR",domain="CORNER")
        for poly,kind,smooth in zip(me.polygons,self.roles,self.smooth):
            poly.material_index=kinds.index(kind);poly.use_smooth=smooth
            for li in poly.loop_indices:
                vi=me.loops[li].vertex_index
                uv.data[li].uv=self.uv[vi];wind.data[li].uv=self.wind[vi];col.data[li].color=self.col[vi]
        me.color_attributes.active_color=col
        # Weld tip/rib coincidences and remove zero-area faces before engine export.
        bm=bmesh.new();bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=0.000001)
        bm.to_mesh(me);bm.free()
        if bevel:
            bpy.context.view_layer.objects.active=ob
            mod=ob.modifiers.new("Worn edge highlights", "BEVEL")
            group=ob.vertex_groups.new(name="Rigid structure only")
            rigid={v for poly in me.polygons if kinds[poly.material_index] not in ("foliage","fabric","water") for v in poly.vertices}
            group.add(list(rigid),1.0,"REPLACE")
            mod.width=bevel;mod.segments=2 if LOD==0 else 1;mod.limit_method="VGROUP";mod.vertex_group=group.name
            bpy.ops.object.modifier_apply(modifier=mod.name)
        # Bevel can introduce sliver faces even on valid input; audit final triangles.
        bm=bmesh.new();bm.from_mesh(me)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bad=[face for face in bm.faces if face.calc_area()<1e-9]
        if bad:bmesh.ops.delete(bm,geom=bad,context="FACES_ONLY")
        bm.to_mesh(me);bm.free();me.update()
        return ob


def disk_point(radius):
    a=R.random()*TAU;r=math.sqrt(R.random())*radius
    return Vector((math.cos(a)*r,math.sin(a)*r,0))


def twig(g,a,b,leaf_size=.23,color="leaf",form="oval",density=7,flex=.45):
    a,b=Vector(a),Vector(b);d=b-a
    g.tube([a,a+d*.52+Z*.05,b],[.013,.008,.002],"bark",5,flex*.22)
    count=density
    for j in range(count):
        t=.16+.80*j/max(1,count-1);p=a+d*t
        for sign in (-1,1):
            yaw=math.atan2(d.y,d.x)+sign*R.uniform(.6,1.35)
            direction=Vector((math.cos(yaw),math.sin(yaw),R.uniform(-.25,.6)))
            g.leaf(p,direction,leaf_size*R.uniform(.75,1.2),leaf_size*.64,color,flex,form)


def crown(g,center,spread,color="leaf",form="oval",leaf_size=.24,flex=.4):
    center=Vector(center)
    # Radial secondary twigs make porous, irregular volumes with actual leaf edges.
    count=11
    for i in range(count):
        a=i*2.399+R.uniform(-.28,.28);r=R.uniform(.35,1.)
        end=center+Vector((math.cos(a)*spread[0]*r,math.sin(a)*spread[1]*r,R.uniform(-.55,.75)*spread[2]))
        twig(g,center,end,leaf_size*1.18,color if i%4 else "light",form,4,flex)


def deciduous(kind):
    g=Mesh()
    h,radius,reach,color,form={"oak":(7.0,.40,2.5,"leaf","oak"),"apple":(4.3,.25,1.65,"leaf","oval"),"maple":(4.6,.18,1.65,"light","maple")}[kind]
    trunk=[Vector((0,0,0)),Vector((.11,-.05,h*.22)),Vector((-.09,.04,h*.48)),Vector((.13,.1,h*.72)),Vector((.20,.03,h*.96))]
    g.tube(trunk,[radius*1.4,radius,radius*.67,radius*.35,.025],"bark",14)
    for i in range(7):
        a=i*TAU/7
        g.tube([(0,0,.45),(.42*math.cos(a),.42*math.sin(a),.13),(radius*2.5*math.cos(a),radius*2.5*math.sin(a),.015)],[radius*.42,radius*.28,.02],"bark",8)
    for i in range(14):
        a=i*2.399+R.uniform(-.2,.2);z=h*(.34+.034*i);end=Vector((math.cos(a)*reach*R.uniform(.70,1),math.sin(a)*reach*R.uniform(.70,1),z+h*R.uniform(.15,.24)))
        start=Vector((0,0,z));mid=start.lerp(end,.55)-Z*.2
        g.tube([start,mid,end],[radius*.36,radius*.20,.021],"bark",9)
        for fork in (-1,0,1):
            dest=end+Vector((math.cos(a+fork*.85)*.7,math.sin(a+fork*.85)*.7,.20+abs(fork)*.05))
            g.tube([mid,end,dest],[radius*.16,.025,.005],"bark",6)
            crown(g,dest,(.88,.82,.65) if kind=="oak" else (.60,.53,.43),color,form,.32 if kind=="oak" else .22, .32 if kind=="oak" else .44)
            if kind=="oak" and fork==0:
                crown(g,mid+Z*.60,(.75,.70,.54),"dark",form,.31,.32)
            if kind=="apple" and fork!=0:
                fruit=dest-Z*.25
                g.tube([dest,fruit],[.008,.005],"bark",5)
                g.ellipsoid(fruit,(.075,.075,.072),"berry",8,5)
    crown(g,trunk[-1],(.9,.85,.55),color,form,.25,.44)
    return g


def birch():
    g=Mesh()
    for n,(x,y,h) in enumerate([(-.55,.22,6.5),(.56,.17,5.5),(.08,-.5,4.8)]):
        radius=.13 if n else .17
        g.tube([(x,y,0),(x+.09,y,h*.4),(x+.20,y+.08,h)],[radius*1.25,radius,.015],"birch",12)
        for j in range(18):
            z=.25+j*h/18
            a=j*2.399
            p=Vector((x+.20*z/h+math.cos(a)*radius*.94,y+.08*z/h+math.sin(a)*radius*.94,z))
            g.box(p,(.12,.015,R.uniform(.018,.048)),"barkdark",Matrix.Rotation(a+math.pi/2,3,"Z"))
        for j in range(9):
            a=j*2.399+n;z=h*(.35+j*.064)
            end=Vector((x+math.cos(a)*1.05,y+math.sin(a)*1.05,z+.35))
            g.tube([(x+.1,y,z),end, end+Vector((.10,0,-.20))],[.046,.015,.004],"birch",7)
            crown(g,end,(.65,.58,.65),"light","oval",.20,.47)
    return g


def conifer(cypress=False):
    g=Mesh();h=6.6 if cypress else 6.2
    g.tube([(0,0,0),(.04,0,h*.5),(.03,.05,h)],[.22,.12,.008],"barkdark",12)
    levels=22 if cypress else 14
    for j in range(levels):
        z=.7+j*(h-.9)/levels+R.uniform(-.10,.10)
        reach=(.64 if cypress else 2.10)*(1.-j/levels)**.67
        count=6 if cypress else 7
        for i in range(count):
            a=i*TAU/count+j*1.34
            reach_i=reach*R.uniform(.75,1.10)
            end=Vector((math.cos(a)*reach_i,math.sin(a)*reach_i,z+(.55 if cypress else R.uniform(-.20,.12))))
            g.tube([(0,0,z),end],[.034,.004],"bark",6)
            needles=10
            for q in range(needles):
                t=.15+q*.8/needles;p=Vector((0,0,z)).lerp(end,t)
                for sign in (-1,1):
                    d=Vector((math.cos(a+sign*.65),math.sin(a+sign*.65),.90 if cypress else R.uniform(-.25,.65)))
                    g.leaf(p,d,.38 if cypress else .35,.11 if cypress else .13,"dark" if (i+j)%4 else "sage",.3,"maple")
    return g


def blossom(g,p,scale=.075,color="cream",petals=6):
    p=Vector(p)
    for i in range(petals):
        a=i*TAU/petals
        g.leaf(p,(math.cos(a),math.sin(a),.18),scale,scale*.64,color,.72)
    g.ellipsoid(p+Z*.012,(scale*.20,scale*.20,scale*.15),"gold",7,4,kind="foliage",wind=.49)


def shrub(berries=False):
    g=Mesh()
    for i in range(17):
        a=i*2.399;end=Vector((math.cos(a)*R.uniform(.32,.73),math.sin(a)*R.uniform(.32,.73),R.uniform(.50,1.05)))
        mid=end*.53+Z*.12
        g.tube([(0,0,.01),mid,end],[.025,.018,.006],"barkdark",7)
        for j in range(3):
            p=mid.lerp(end,j/3);dest=p+Vector((math.cos(a+j)*.31,math.sin(a+j)*.31,.19))
            twig(g,p,dest,.17,"dark" if berries else "leaf",density=6,flex=.60)
        if berries:
            for j in range(4):
                p=end+Vector((math.cos(j*2.399)*.07,math.sin(j*2.399)*.07,-j*.025))
                g.ellipsoid(p,(.028,.030,.031),"berry",7,4)
        else:
            for j in range(3): blossom(g,end+disk_point(.14)+Z*(j*.025),.07,"cream" if i%3 else "pink",5)
    return g


def fern():
    g=Mesh()
    for plant in range(3):
        center=disk_point(.35)
        for frond in range(9):
            a=frond*TAU/9+plant;d=Vector((math.cos(a),math.sin(a),0));length=R.uniform(.48,.83)
            points=[center+d*(length*t)+Z*(.02+math.sin(t*math.pi*.85)*length*.55) for t in (0,.25,.5,.75,1)]
            g.tube(points,[.009,.008,.006,.004,.001],"grass",5,.65,"foliage")
            count=11
            for j in range(1,count):
                t=j/count;p=center+d*(length*t)+Z*(.02+math.sin(t*math.pi*.85)*length*.55)
                for sign in (-1,1):
                    direction=Vector((math.cos(a+sign*1.02),math.sin(a+sign*1.02),.08))
                    size=length*.29*math.sin(t*math.pi)**.6
                    g.leaf(p,direction,size,.045*(1-t*.6),"leaf" if plant else "light",t*.8)
    return g


def grass(flowers=False):
    g=Mesh()
    for tuft in range(13):
        p=disk_point(.70)
        for i in range(12):
            a=R.random()*TAU;h=R.uniform(.18,.48)
            g.leaf(p+disk_point(.06),(math.cos(a)*.32,math.sin(a)*.32,1),h,.020*R.uniform(.7,1.5),"grass" if i%3 else "grass_tip",.80)
    if flowers:
        for i in range(25):
            p=disk_point(.62);h=R.uniform(.30,.64);end=p+Vector((.035,0,h))
            g.tube([p,p+Z*h*.55,end],[.006,.004,.002],"leaf",5,.72,"foliage")
            for t in (.24,.49):g.leaf(p+Z*h*t,(math.cos(i),math.sin(i),.4),.13,.043,"sage",t)
            blossom(g,end,R.uniform(.043,.067),"cream" if i%4 else "blue",7)
    return g


def ivy():
    g=Mesh()
    for i in range(9):
        x=-1.23+i*.30;h=R.uniform(1.7,3.1)
        pts=[Vector((x+math.sin(j*.9+i)*.15,0,j*h/9)) for j in range(10)]
        g.tube(pts,[.015*(1-j/12) for j in range(10)],"barkdark",5)
        for j in range(20):
            t=j/20;z=.15+t*(h-.15)
            sign=(-1)**j;p=Vector((x+math.sin(t*9*.9+i)*.15,-.025,z))
            g.leaf(p,(sign*.55,-.15,-.7),R.uniform(.19,.29),.20,"dark" if j%3 else "leaf",.15,"ivy",(0,-1,0))
    return g


def reeds():
    g=Mesh()
    for i in range(32):
        p=disk_point(.65);h=R.uniform(1.10,1.85);a=i*2.399
        end=p+Vector((math.cos(a)*.13,math.sin(a)*.13,h))
        g.tube([p,p.lerp(end,.5),end],[.013,.009,.004],"grass",6,.80,"foliage")
        for j in range(3):
            t=.15+j*.21
            g.leaf(p.lerp(end,t),(math.cos(a+j),math.sin(a+j),.85),h*.44,.047,"sage" if j%2 else "grass",t+.2)
        if i%3==0:
            g.tube([end,end+Z*.22],[.043,.030],"barkdark",9,.8,"foliage")
    return g


def moss(g,p,spread,count=40):
    for i in range(count):
        q=Vector(p)+Vector((R.uniform(-spread[0],spread[0]),R.uniform(-spread[1],spread[1]),R.uniform(0,.035)))
        g.leaf(q,(math.cos(i),math.sin(i),.35),R.uniform(.065,.13),.055,"moss",0)


def log():
    g=Mesh()
    pts=[(-1.95,0,.36),(-.8,.02,.39),(.35,-.02,.36),(1.8,.07,.31)]
    g.tube(pts,[.40,.38,.35,.29],"barkdark",16)
    for x,z,r in [(-1.96,.36,.37),(1.81,.31,.27)]:
        # Exposed end grain lies in YZ; concentric rings follow the cut surface.
        for j in range(5):
            rr=r*(1-j*.16)
            coords=[(x-.006*j,math.cos(a*TAU/24)*rr,z+math.sin(a*TAU/24)*rr) for a in range(25)]
            g.tube(coords,[.008]*25,"woodlight" if j%2 else "wood",5)
    for i in range(3):
        x=-1.2+i*1.05;g.tube([(x,0,.52),(x+.22,.28,.76),(x+.39,.35,.89)],[.12,.07,.018],"bark",7)
    moss(g,(0,-.04,.70),(1.7,.18),95)
    return g


def nail(g,p):
    g.ellipsoid(p,(.017,.012,.017),"iron",6,4)


def planter():
    g=Mesh()
    for x in (-1.02,1.02):g.box((x,0,.14),(.18,.75,.28),"wood",kind="wood")
    for j in range(3):
        z=.27+j*.17
        for y in (-.41,.41):
            g.box((0,y,z),(2.45,.09,.155),"wood" if j%2 else "woodlight",kind="wood")
            for x in (-1.08,1.08):nail(g,(x,y+(-.052 if y<0 else .052),z))
        for x in (-1.19,1.19):g.box((x,0,z),(.10,.74,.155),"wood",kind="wood")
    for x in (-1.1,1.1):
        for y in (-.44,.44):g.box((x,y,.46),(.09,.035,.54),"iron")
    g.box((0,0,.55),(2.24,.72,.10),"soil")
    for i in range(28):
        p=Vector((R.uniform(-1.02,1.02),R.uniform(-.29,.29),.59));h=R.uniform(.22,.45)
        g.tube([p,p+Z*h],[.009,.003],"sage",5,.5,"foliage")
        for j in range(4):
            t=.22+j*.18
            for sign in (-1,1):
                a=i*2.399+sign*1.4
                g.leaf(p+Z*h*t,(math.cos(a),math.sin(a),.35),.13,.062,"sage" if i%3 else "light",t*.7)
        if i%3==0:
            for j in range(4):blossom(g,p+Z*(h+j*.025),.027,"purple",4)
    return g


def rocks():
    g=Mesh()
    for p,s in [((-.60,.1,.5),(.94,.73,.64)),((.60,.17,.33),(.70,.55,.43)),((0,-.52,.17),(.48,.4,.27))]:
        g.ellipsoid(p,s,"stoneshade",18,8,irregular=.10)
        moss(g,Vector(p)+Z*s[2]*.89,(s[0]*.53,s[1]*.48),28)
    return g


def milestone():
    g=Mesh()
    g.box((0,0,.12),(.90,.70,.24),"stoneshade")
    g.box((0,0,.94),(.58,.38,1.50),"stone")
    g.box((0,0,1.74),(.70,.49,.16),"stone")
    g.box((0,0,1.87),(.48,.37,.12),"stoneshade")
    g.box((0,-.204,1.16),(.42,.024,.62),"stoneshade")
    for i in range(3):g.box((0,-.223,1.34-i*.17),(.23-i*.035,.012,.028),"system")
    for sign in (-1,1):g.beam((sign*.10,-.23,.92),(0,-.23,1.01),.023,.012,"gold")
    moss(g,(0,0,.26),(.38,.28),30)
    return g


def fence():
    g=Mesh()
    for x in (-2.2,0,2.2):
        g.box((x,0,.83),(.18,.20,1.66),"wood",kind="wood")
        g.box((x,0,1.67),(.24,.26,.10),"woodlight",kind="wood")
    for z in (.48,1.12):
        g.box((0,0,z),(4.6,.13,.16),"woodlight",kind="wood")
        for x in (-2.2,0,2.2):nail(g,(x,-.083,z))
    for x in (-1.1,1.1):g.beam((x-.95,.05,.38),(x+.95,.05,1.23),.10,.10,"wood")
    for i in range(5):
        x=-1.9+i*.90
        pts=[(x+math.sin(j*.9)*.13,-.13,j*.18) for j in range(8)]
        g.tube(pts,[.012]*8,"barkdark",5)
        for j in range(10):
            z=.15+j*(1.15/10)
            g.leaf((x+math.sin(z*5)*.13,-.16,z),((-1)**j*.55,-.2,-.5),.23,.18,"leaf",.12,"ivy",(0,-1,0))
    return g


def trough():
    g=Mesh()
    for x in (-1.12,1.12):g.box((x,0,.12),(.46,1.1,.24),"stoneshade")
    g.box((0,0,.26),(3.2,1.30,.22),"stoneshade")
    for side in (-1,1):
        for i in range(5):g.box((-1.28+i*.64,side*.54,.62),(.625,.23,.62),"stone" if i%2 else "stoneshade")
        g.box((0,side*.54,.95),(3.32,.29,.12),"stone")
        g.box((side*1.51,0,.62),(.24,1.1,.62),"stone")
        g.box((side*1.51,0,.95),(.29,1.08,.12),"stone")
    g.box((0,0,.73),(2.75,.82,.016),"water",kind="water")
    moss(g,(-.95,.56,1.02),(.46,.09),20)
    return g


def shelter():
    g=Mesh()
    for x in (-2.0,2.0):
        for y in (-1.25,1.25):
            g.box((x,y,.15),(.40,.42,.30),"stoneshade")
            g.box((x,y,1.57),(.17,.17,2.9),"wood",kind="wood")
            g.beam((x,y,2.25),(x-math.copysign(.60,x),y,2.94),.10,.10,"woodlight")
    for y in (-1.25,1.25):
        g.beam((-2.12,y,2.99),(2.12,y,2.99),.16,.16,"wood")
        g.beam((-2.2,y,3.0),(0,y,3.85),.13,.13,"woodlight")
        g.beam((0,y,3.85),(2.2,y,3.0),.13,.13,"woodlight")
    g.beam((0,-1.43,3.84),(0,1.43,3.84),.11,.11,"wood")
    for stripe in range(10):
        y0=-1.45+stripe*.29;y1=y0+.29
        verts=[];uv=[]
        for j in range(13):
            x=-2.28+j*4.56/12;z=3.85-abs(x)*.35-.14*math.sin(abs(x)/2.28*math.pi)
            for y in (y0,y1):verts.append((x,y,z));uv.append((x,y))
        fs=[(j*2,j*2+2,j*2+3,j*2+1) for j in range(12)]
        g.add(verts,fs,"stripe" if stripe%2 else "canvas","fabric",uv,smooth=True)
        for x in (-2.28,2.28):
            g.add([(x,y0,3.05),(x,y1,3.05),(x,y1,2.86),(x,(y0+y1)/2,2.79),(x,y0,2.86)],[(0,1,2,3,4)],"stripe" if stripe%2 else "canvas","fabric")
    for z in (.48,.58):g.box((0,.62,z),(3.42,.49,.085),"wood",kind="wood")
    for x in (-1.4,1.4):
        g.box((x,.62,.28),(.14,.40,.50),"wood",kind="wood")
    for j in range(3):g.box((0,.88,.79+j*.14),(3.42,.075,.115),"woodlight",kind="wood")
    return g


ASSETS = [
    ("ancient_oak","古橡树","canopy_trees",lambda:deciduous("oak")),
    ("birch_grove","白桦组三株","canopy_trees",birch),
    ("cypress_column","柱形柏树","canopy_trees",lambda:conifer(True)),
    ("stone_pine","石地松树","canopy_trees",conifer),
    ("orchard_apple","果园苹果树","canopy_trees",lambda:deciduous("apple")),
    ("young_maple","幼枫树","canopy_trees",lambda:deciduous("maple")),
    ("flowering_shrub","开花灌木","shrubs_and_cultivated",shrub),
    ("berry_bush","浆果丛","shrubs_and_cultivated",lambda:shrub(True)),
    ("fern_patch","蕨类地被","groundcovers",fern),
    ("meadow_grass","草甸草簇","groundcovers",grass),
    ("wildflower_patch","野花草簇","groundcovers",lambda:grass(True)),
    ("ivy_wall_panel","常春藤墙面","climbers",ivy),
    ("reed_cluster","芦苇簇","wetland",reeds),
    ("mossy_fallen_log","苔藓倒木","deadwood_and_moss",log),
    ("herb_planter","香草种植箱","shrubs_and_cultivated",planter),
    ("mossy_boulder_cluster","苔石组",None,rocks),
    ("roadside_milestone","道路里程碑",None,milestone),
    ("timber_fence_vine","藤蔓木栅栏",None,fence),
    ("stone_water_trough","石质水槽",None,trough),
    ("canvas_rest_shelter","帆布休憩棚",None,shelter),
]


def main():
    global LOD,R
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True,exist_ok=True)
    source=bpy.context.scene;source.name="Floor1_Environment_V2_Source"
    manifest={"schema":2,"id":"floor1_environment_v2","asset_count":20,"unit":"metre","wind_encoding":"UV2.x flexibility, UV2.y phase; zero on rigid structure","source":"project-authored botanical meshes; no external asset dependency","assets":[]}
    for index,(name,label,group,build) in enumerate(ASSETS):
        entry={"id":"F1_"+name,"label_zh":label,"plant_group":group,"lods":[]}
        for level in range(3):
            LOD=level;R=random.Random(2611+index*101)
            col=bpy.data.collections.new(f"{index+1:02d}_{name}_LOD{level}");source.collection.children.link(col)
            geo=build()
            ob=geo.object(f"F1_{name}_LOD{level}",col,.008 if index>=14 and index not in (15,17) else 0.)
            ob["asset_id"]=entry["id"];ob["lod"]=level;ob["plant_group"]=group or "hardscape"
            ob["wind_mode"]="weighted_vertex";ob["ground_pivot"]=True
            bpy.ops.object.select_all(action="DESELECT");ob.select_set(True)
            path=OUT/f"F1_{name}_LOD{level}.glb"
            bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_extras=True,export_yup=True,export_apply=True,export_normals=True,export_texcoords=True)
            ob.data.calc_loop_triangles()
            bbox=[Vector(p) for p in ob.bound_box];mins=[min(p[i] for p in bbox) for i in range(3)];maxs=[max(p[i] for p in bbox) for i in range(3)]
            entry["lods"].append({"file":path.relative_to(ROOT).as_posix(),"triangles":len(ob.data.loop_triangles),"surfaces":len(ob.data.materials),"dimensions_xyz_blender_m":[round(maxs[i]-mins[i],4) for i in range(3)],"sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
            if level>0:col.hide_viewport=True;col.hide_render=True
            else:ob.location=((index%5)*7,(index//5)*-7,0)
        manifest["assets"].append(entry)
        scene_path=OUT/(entry["id"]+".tscn")
        scene_path.write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://spatial/environment_v2_component.gd" id="1"]\n\n[node name="'+entry["id"]+'" type="Node3D"]\nscript = ExtResource("1")\nasset_id = "'+entry["id"]+'"\n')
        entry["game_scene"]=scene_path.relative_to(ROOT).as_posix()
        print("V2_ASSET "+json.dumps(entry),flush=True)
    source["wind_preview"]="Use Godot floor1_environment_v2_review.tscn; source is rest pose"
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/"Floor1_EnvironmentKit20_V2.blend"),compress=True)
    (OUT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print("V2_COMPLETE "+json.dumps({"assets":20,"glbs":60,"triangles_by_lod":[sum(a["lods"][i]["triangles"] for a in manifest["assets"]) for i in range(3)]}),flush=True)


if __name__=="__main__":main()
