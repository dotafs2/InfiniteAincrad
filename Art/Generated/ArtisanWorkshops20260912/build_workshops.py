"""Original artisan workshop props. Rebuild in Blender, metres, source Z up.
Minimal geometry helpers adapted from the repository-original MarketLife generator.
No external art, texture, private save, or third-party dependency is imported.
"""
import bpy, math, json, hashlib, os, time, sys, struct
from pathlib import Path
from mathutils import Vector, Matrix
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'game/assets/generated/artisan_workshops_20260912'
EVIDENCE=ROOT/'docs/validation/art_parallel_20260912/workshops'
OUT.mkdir(parents=True,exist_ok=True)
EVIDENCE.mkdir(parents=True,exist_ok=True)
TAU=math.tau
STYLE='floor1_artisan_workshops_20260912'
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
    m=bpy.data.materials.new('AW_'+key)
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
            # Transport the cross section continuously. Switching a reference
            # axis mid-curve otherwise twists small vertical rings and ropes.
            u=previous_u-t*previous_u.dot(t) if previous_u is not None else Vector((0,0,0))
            if u.length<1e-6:
                ref=Vector((0,0,1)) if abs(t.z)<.93 else Vector((0,1,0))
                u=t.cross(ref)
            u.normalize();previous_u=u.copy();w=t.cross(u).normalized()
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

def prism(g,points,depth,mat='iron',y=0):
    """Solid shaped silhouette extruded along Y; polygon supplied in X,Z."""
    v=[(x,y+side*depth/2,z) for side in (-1,1) for x,z in points]; n=len(points)
    f=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    f += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    g.mesh(v,f,mat)

def helix(g,p,r,h,turns=10,wire=.011,mat='iron',axis='Z'):
    x,y,z=p; pts=[]
    for i in range(turns*18+1):
        t=i/(turns*18); a=TAU*turns*t
        q=(r*math.cos(a),r*math.sin(a),h*t)
        if axis=='X':q=(q[2],q[1],q[0])
        pts.append((x+q[0],y+q[1],z+q[2]))
    g.tube(pts,wire,mat,6)

def platform(g,w,d,h=.1):
    for i in range(5):plank(g,(0,-d/2+(i+.5)*d/5,h/2),(w,d/5-.008,h),'oak_light')
    for x in (-w*.37,w*.37):g.box((x,0,h+.025),(.08,d,.05),'oak_dark')

def bench(g,w=1,d=.6,h=.85):
    for x in (-w*.4,w*.4):
        for y in (-d*.36,d*.36):
            g.beam((x*1.1,y*1.15,.04),(x,y,h-.08),.075)
        g.box((x,0,.2),(.06,d*.85,.07),'oak_dark')
    g.box((0,0,.22),(w*.82,.07,.07),'oak_dark')
    for i in range(4):plank(g,(0,-d/2+(i+.5)*d/4,h-.045),(w,d/4-.006,.09),'oak_light')
    for y in (-d*.40,d*.4):g.box((0,y,h-.145),(w*.86,.055,.14),'oak')

def vessel(g,p=(0,0,0),r=.13,h=.24,mat='terracotta'):
    g.lathe(p,[(r*.58,0),(r*.74,.015),(r,h*.36),(r*.93,h*.7),(r*.6,h*.9),(r*.6,h),(r*.49,h),(r*.5,h*.86),(r*.82,h*.68),(r*.87,h*.34),(r*.58,.026)],mat,32)
    g.ring((p[0],p[1],p[2]+h*.985),r*.545,.012,'clay_light',n=32,sides=8)

def potters_wheel():
    g=Geo();platform(g,1.05,1.18)
    for x in (-.40,.40):g.box((x,.12,.48),(.09,.63,.76),'oak')
    g.box((0,.13,.88),(1.05,.63,.095),'oak_light',.026)
    g.cyl((0,.05,.16),.36,.075,'oak',48)
    for i in range(8):
        a=i*TAU/8;g.rod((.05*math.cos(a),.05*math.sin(a)+.05,.24),(.31*math.cos(a),.31*math.sin(a)+.05,.24),.018,'oak_light')
    g.cyl((0,.05,.22),.035,.74,'iron',20)
    g.lathe((0,.05,.935),[(.28,0),(.305,.014),(.305,.04),(.285,.058)],'stone_light',48)
    for r in (.12,.21,.275):g.ring((0,.05,.994),r,.0025,'stone',n=48,sides=6)
    vessel(g,(0,.05,.995),.13,.22,'clay_light')
    g.box((.12,-.38,.20),(.21,.53,.045),'oak_dark',.009,Matrix.Rotation(.11,3,'X'))
    g.rod((.12,-.12,.20),(.10,.06,.27),.018,'iron')
    g.rod((-.4,-.25,.38),(.4,-.25,.38),.019,'iron')
    vessel(g,(.35,.17,.934),.07,.09,'glaze')
    for j in range(3):g.rod((-.4+j*.055,.10,.945),(-.4+j*.055,.30,.955),.011,'oak_dark',8)
    return g

def kiln():
    g=Geo();g.box((0,0,.085),(1.48,1.39,.17),'stone',.035)
    # Open front chamber: side/rear masonry plus radial arch blocks.
    for level in range(5):
        z=.25+level*.18
        for x in (-.55,.55):
            for j in range(4):g.box((x,-.43+j*.28,z),(.25,.27,.17),'terracotta' if (j+level)%3 else 'clay_light',.018)
        for j in range(3):g.box((-.32+j*.32,.55,z),(.31,.22,.17),'terracotta',.017)
    for j in range(9):
        a=math.pi*j/8;g.box((.47*math.cos(a),-.50,.75+.47*math.sin(a)),(.20,.31,.19),'clay_light',.012,Matrix.Rotation(-a,3,'Y'))
    # Corbelled roof bricks behind the front arch, recognizable chimney.
    for level in range(4):
        z=1.05+level*.115; width=1.17-level*.17
        g.box((0,.12,z),(width,.98,.13),'terracotta',.04)
    for lev in range(4):
        for x in (-.14,.14):g.box((x,.30,1.48+lev*.15),(.12,.34,.14),'clay_light',.012)
        for y in (.16,.44):g.box((0,y,1.48+lev*.15),(.19,.09,.14),'terracotta',.01)
    g.box((0,.30,2.03),(.44,.44,.09),'stone_light',.02)
    g.box((0,.30,2.082),(.25,.25,.006),'black',.001)
    g.box((0,-.04,.22),(.84,1.0,.12),'stone',.02)
    for i in range(3):vessel(g,(-.24+i*.24,-.07,.29),.09,.20)
    for x in (-.24,0,.24):g.rod((x,-.57,.11),(x+.03,-.28,.11),.035,'oak_dark',10)
    g.box((0,-.61,.17),(.75,.12,.09),'iron',.01)
    return g

def drying_rack():
    g=Geo()
    for x in (-.63,.63):
        for y in (-.25,.25):g.box((x,y,.87),(.075,.075,1.74),'oak')
        g.beam((x,-.30,.05),(x,.30,1.65),.042,'oak_dark')
    for lev,z in enumerate((.20,.67,1.14,1.61)):
        for k in range(4):plank(g,(0,-.3+(k+.5)*.15,z),(1.38,.143,.055),'oak_light')
        if lev<3:
            for k in range(4):vessel(g,(-.48+k*.32,.035*(k%2),z+.03),.115 if lev==0 else .092,.26 if lev==0 else .23,'clay_light' if (k+lev)%2 else 'terracotta')
    for z in (.43,.9,1.38):
        for x in (-.636,.636):bolt(g,(x,-.291,z),r=.013)
    # Sage protective cover, thick mesh with a lightly undulating front edge.
    for k in range(10):
        x=-.67+k*.145;g.box((x,.02,1.655),(.146,.64,.012),'sage',.002)
    g.box((0,-.295,1.56),(1.4,.025,.18),'sage',.006)
    return g

def anvil_stump():
    g=Geo();g.lathe((0,0,0),[(.29,0),(.33,.05),(.30,.24),(.285,.55),(.30,.60)],'oak',20)
    g.cyl((0,0,.603),.279,.018,'endgrain',40)
    for r in (.11,.19,.265):g.ring((0,0,.624),r,.003,'grain',n=36,sides=6)
    for a in range(12):
        t=TAU*a/12;g.tube([(.305*math.cos(t),.305*math.sin(t),.04),(.278*math.cos(t+.035),.278*math.sin(t+.035),.52)],.008,'oak_dark',6)
    for z in (.13,.46):g.ring((0,0,z),.30-z*.025,.019,'iron',n=32)
    prism(g,[(-.22,.64),(-.24,.69),(-.14,.73),(-.13,.84),(-.29,.91),(-.31,1.01),(.29,1.01),(.31,.91),(.13,.84),(.14,.73),(.24,.69),(.22,.64)],.23)
    # Tapered asymmetric horn with a rounded, visible tip.
    g.lathe((.29,0,.972),[(.086,0),(.066,.12),(.031,.27),(.008,.36)],'iron',20,Matrix.Rotation(math.pi/2,3,'Y'))
    g.box((-.16,0,1.018),(.18,.24,.018),'stone',.012)
    g.box((-.235,-.003,1.029),(.035,.042,.003),'black',.001)
    for x in (-.19,.19):
        g.rod((x,-.17,.68),(x,-.17,.60),.018,'iron');g.box((x,-.14,.67),(.035,.085,.035),'iron')
    g.rod((-.38,-.2,.12),(-.40,-.2,.66),.023,'oak_light');g.box((-.40,-.2,.69),(.17,.085,.085),'iron',.009)
    return g

def forge_bellows():
    g=Geo()
    for x in (-.40,.40):
        for y in (-.3,.3):g.box((x,y,.38),(.19,.20,.76),'stone',.023)
    for level in range(3):
        for j in range(4):g.box((-.38+j*.25,.37,.79+level*.16),(.245,.17,.15),'stone' if j%2 else 'terracotta',.015)
    g.box((0,0,.77),(1.07,.85,.13),'stone_light',.025)
    g.box((0,-.03,.845),(.78,.58,.04),'black',.014)
    for j in range(9):g.rod((-.35+j*.085,-.29,.88),(-.35+j*.085,.23,.88),.012,'iron',8)
    for j in range(8):g.sphere((-.3+(j%4)*.18,-.12+(j//4)*.23,.907),(.072,.07,.043),'black',12,6)
    # Tapered hood mesh, open underneath, riveted chimney.
    vs=[(-.55,-.28,1.47),(.55,-.28,1.47),(.55,.5,1.47),(-.55,.5,1.47),(-.19,.10,1.99),(.19,.10,1.99),(.19,.45,1.99),(-.19,.45,1.99)]
    g.mesh(vs,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'iron')
    g.box((0,.28,2.19),(.38,.35,.42),'iron',.022)
    for x in (-.5,.5):g.box((x,.35,1.21),(.045,.045,.69),'iron')
    for x in (-.4,-.2,0,.2,.4):bolt(g,(x,-.291,1.49),r=.012)
    # Bellows on its own support; layered leather pleats do not masquerade as fire.
    for x in (.75,1.15):g.box((x,.08,.34),(.08,.49,.68),'oak')
    for z in (.65,.91):
        prism(g,[(.53,z),(.73,z+.045),(1.29,z+.045),(1.37,z), (1.29,z-.045),(.73,z-.045)],.44,'oak_dark',.08)
    for k in range(5):
        z=.69+k*.044
        g.box((1.0,.08,z),(.65,.40 if k%2==0 else .34,.05),'leather',.07)
    g.rod((.55,.08,.77),(.32,.08,.84),.04,'iron')
    g.rod((1.18,.08,.955),(1.52,.08,1.10),.026,'oak_light')
    return g

def tong_rack():
    g=Geo()
    for x in (-.52,.52):
        g.box((x,0,.79),(.085,.095,1.58),'oak');g.box((x,0,.055),(.24,.65,.11),'oak_dark')
    for z in (.22,1.46):g.box((0,0,z),(1.15,.085,.085),'oak')
    for i in range(5):
        x=-.4+i*.2;z=1.39
        g.rod((x,0,z),(x,-.14,z),.014,'iron')
        g.ring((x,-.145,z-.045),.044,.009,'iron','Y',24)
        for s in (-1,1):
            pts=[(x+s*.05,-.14,z-.15),(x+s*.045,-.14,z-.34),(x-s*.036,-.14,z-.49),(x-s*.037,-.14,z-.60-i*.03),(x-s*.065,-.14,z-.65-i*.03)]
            g.tube(pts,.012,'iron',8)
        bolt(g,(x,-.159,z-.415),r=.02)
    g.box((0,-.12,.29),(1.04,.29,.055),'oak_light')
    for j in range(3):g.box((-.3+j*.28,-.1,.34),(.19,.055,.07),'iron',.006)
    return g

def dye_vat():
    g=Geo()
    g.lathe((0,0,.1),[(.41,0),(.43,.04),(.49,.71),(.49,.75),(.451,.75),(.45,.69),(.38,.06)],'oak',48)
    for i in range(20):
        a=TAU*i/20;g.beam((.429*math.cos(a),.429*math.sin(a),.14),(.486*math.cos(a),.486*math.sin(a),.82),.008,'oak_dark')
    for z,r in ((.2,.442),(.67,.478),(.83,.491)):g.ring((0,0,z),r,.022,'iron',n=48)
    g.cyl((0,0,.745),.445,.012,'glaze_dark',48)
    for x in (-.6,.6):g.box((x,0,.76),(.07,.07,1.52),'oak_dark')
    g.rod((-.7,0,1.5),(.7,0,1.5),.028,'oak_light')
    # Draped cloth hangs into the colored surface; double-sided thick quilt strip.
    pts=[]
    for j in range(18):
        t=j/17;y=-.32+.63*t;z=1.5-.76*abs(2*t-1)**1.2;pts.append((y,z))
    # Continuous fabric with thickness and soft longitudinal folds.
    vv=[];ff=[];nr=len(pts);nc=17
    for side in (-1,1):
        for i in range(nc):
            x=-.26+i*.52/(nc-1)
            for y,z in pts:vv.append((x,y,z+.013*math.sin(i*.9)+side*.004))
    count=nc*nr
    for side in range(2):
        off=side*count
        for i in range(nc-1):
            for j in range(nr-1):
                a=off+i*nr+j;ff.append((a,a+1,a+nr+1,a+nr) if side else (a,a+nr,a+nr+1,a+1))
    for i in range(nc-1):
        for j in (0,nr-1):
            a=i*nr+j;b=(i+1)*nr+j;ff.append((a,b,b+count,a+count))
    for i in (0,nc-1):
        for j in range(nr-1):
            a=i*nr+j;ff.append((a,a+count,a+count+1,a+1))
    g.mesh(vv,ff,'sage',True)
    g.rod((.22,-.25,.39),(.62,-.42,1.16),.02,'oak_light')
    g.box((0,0,.05),(1.08,1.08,.10),'stone',.04)
    return g

def leather_frame():
    g=Geo()
    for x in (-.65,.65):
        g.box((x,0,.97),(.085,.10,1.94),'oak');g.box((x,0,.055),(.22,.72,.11),'oak_dark')
    for z in (.27,1.79):g.box((0,0,z),(1.43,.085,.075),'oak_light')
    # Irregular animal-free cut leather panel with scalloped outline.
    outline=[(-.36,.43),(-.49,.61),(-.40,.87),(-.5,1.16),(-.40,1.50),(-.20,1.62),(0,1.56),(.22,1.64),(.44,1.48),(.49,1.2),(.39,.91),(.5,.64),(.31,.43),(0,.50)]
    prism(g,outline,.017,'leather',-.045)
    for i,(x,z) in enumerate(outline):
        target=(math.copysign(.635,x),-.03,z) if abs(x)>.27 else (x,-.03,1.79 if z>1 else .27)
        g.rod((x,-.06,z),target,.008,'thread',8)
        g.ring((x,-.060,z),.017,.004,'brass','Y',16,6)
    for x in (-.64,.64):
        for z in (.30,1.77):bolt(g,(x,-.06,z),r=.015)
    g.box((0,-.07,.33),(.8,.13,.035),'oak_dark')
    g.rod((-.30,-.1,.355),(.28,-.1,.355),.012,'iron');g.box((-.36,-.1,.355),(.12,.04,.04),'oak_light')
    return g

def jewel_drawbench():
    g=Geo();bench(g,1.38,.66,.88)
    # Raised draw plate and winding handle distinguish this from joinery bench.
    for x in (-.45,.46):g.box((x,.10,1.04),(.09,.16,.31),'oak_dark')
    g.box((-.45,.10,1.19),(.06,.30,.24),'iron',.012)
    for j in range(5):
        r=.008+j*.003;g.cyl((-.486,.025+j*.045,1.20),r,.002,'black',16,Matrix.Rotation(-math.pi/2,3,'Y'))
        g.ring((-.488,.025+j*.045,1.20),r+.004,.002,'brass','X',16,6)
    g.cyl((.46,-.02,1.16),.066,.25,'oak',24,Matrix.Rotation(-math.pi/2,3,'X'))
    g.rod((.46,-.18,1.16),(.46,-.18,1.35),.013,'iron');g.rod((.46,-.18,1.35),(.46,-.29,1.35),.016,'oak_light')
    g.rod((-.42,.12,1.19),(.46,.12,1.19),.004,'brass',8)
    g.box((-.22,-.16,.917),(.40,.23,.04),'oak_dark')
    for i in range(3):
        for j in range(3):g.ring((-.36+i*.12,-.22+j*.065,.945),.019+j*.003,.004,'brass',n=20,sides=6)
    g.box((.27,-.18,.929),(.17,.17,.06),'stone_light')
    g.rod((.20,-.16,.97),(.35,-.17,1.03),.009,'oak_light');g.box((.36,-.17,1.034),(.045,.035,.025),'iron',.003)
    g.ring((-.57,-.11,1.05),.059,.008,'brass','Y',32)
    g.rod((-.57,-.1,1.0),(-.57,-.1,.88),.01,'brass')
    return g

def candle_molds():
    g=Geo();bench(g,.91,.51,.76)
    for x in (-.4,.4):g.box((x,0,1.14),(.06,.07,.75),'oak')
    g.box((0,0,1.50),(.9,.07,.06),'oak_light')
    for i in range(6):
        x=-.30+i*.12
        g.lathe((x,-.08,.77),[(.043,0),(.051,.014),(.049,.35),(.060,.39),(.044,.40),(.038,.35),(.034,.022)],'iron',24)
        g.rod((x,-.08,1.05),(x,-.08,1.50),.003,'thread',6)
        g.box((x,0,1.53),(.074,.14,.018),'oak_dark',.003)
    g.box((0,.17,.80),(.72,.18,.036),'oak_dark')
    for i in range(5):
        g.lathe((-.27+i*.135,.17,.82),[(.036,0),(.036,.23),(.031,.245)],'canvas',20)
        g.rod((-.27+i*.135,.17,1.06),(-.27+i*.135,.17,1.09),.003,'black',6)
    g.box((0,-.02,.29),(.75,.32,.05),'oak_light')
    for i in range(3):g.box((-.24+i*.24,-.02,.34),(.18,.17,.07),'wheat',.012)
    return g

def book_press():
    g=Geo();platform(g,.92,.74,.1)
    for x in (-.35,.35):g.box((x,0,.61),(.12,.19,1.1),'oak_dark')
    g.box((0,0,1.13),(.99,.25,.15),'oak_light',.014)
    g.box((0,0,.29),(.75,.59,.10),'oak_light')
    for j in range(3):
        z=.365+j*.064
        g.box((0,-.005,z),(.48,.39,.048),'paper',.004)
        for dz in (-.027,.027):g.box((0,-.007,z+dz),(.50,.41,.006),'leather',.002)
        g.box((-.247,-.007,z),(.013,.41,.055),'leather',.004)
    g.box((0,0,.62),(.71,.54,.12),'oak',.012)
    g.cyl((0,0,.68),.034,.60,'iron',24);helix(g,(0,0,.70),.041,.53,13,.009)
    g.lathe((0,0,1.26),[(.075,0),(.075,.045),(.048,.067),(.048,.1)],'oak_dark',24)
    g.rod((-.35,0,1.32),(.35,0,1.32),.024,'oak_light')
    for x in (-.34,.34):g.sphere((x,0,1.32),(.045,.037,.037),'oak_dark',16,8)
    for x in (-.35,.35):
        for z in (.2,1.1):bolt(g,(x,-.106,z),r=.019)
    return g

def cooper_jig():
    g=Geo();platform(g,1.05,.83,.10)
    for x in (-.42,.42):
        g.box((x,0,.49),(.085,.12,.81),'oak_dark');g.box((x,0,.86),(.15,.22,.07),'oak_light')
    # Curved, intentionally open set of staves in a cooper's shaping fixture.
    for i in range(14):
        a=TAU*i/16
        points=[]
        for j in range(9):
            t=j/8;r=.22+.065*math.sin(math.pi*t);points.append((r*math.cos(a),r*math.sin(a),.2+t*.69))
        for j in range(8):g.beam(points[j],points[j+1],.084,'oak_light' if i%3 else 'oak',depth=.032)
    for z,r in ((.28,.243),(.77,.256)):
        g.ring((0,0,z),r+.022,.015,'iron',n=48)
    g.ring((0,0,.21),.22,.02,'oak_dark',n=48)
    g.rod((-.49,-.26,.56),(.48,-.26,.56),.018,'iron')
    helix(g,(.30,-.26,.56),.022,.18,7,.005,axis='X')
    g.rod((.51,-.26,.45),(.51,-.26,.70),.019,'oak_dark')
    g.box((.36,-.15,.66),(.10,.13,.10),'oak')
    g.rod((-.40,.24,.13),(-.23,.24,.49),.019,'oak_dark');g.box((-.22,.24,.51),(.14,.085,.08),'oak_light')
    return g

def bow_shaping_form():
    g=Geo()
    for x in (-.61,.61):
        g.box((x,0,.70),(.09,.10,1.4),'oak');g.box((x,0,.055),(.22,.64,.11),'oak_dark')
    for z in (.31,1.36):g.box((0,0,z),(1.4,.12,.095),'oak_light')
    g.box((0,.06,.77),(1.27,.07,.08),'oak_dark')
    # Distinct horizontal bow held on a wide curved former by brass pegs.
    pts=[(-.64+i*.04,-.115,1.08-.25*(1-((-.64+i*.04)/.64)**2)) for i in range(33)]
    g.tube(pts,.021,'oak_light',10)
    g.tube([(x,y-.015,z-.006) for x,y,z in pts],.006,'grain',8)
    g.rod((-.64,-.115,1.08),(.64,-.115,1.08),.003,'thread',6)
    for x in (-.53,-.32,0,.32,.53):
        z=1.08-.25*(1-(x/.64)**2)
        g.rod((x,.02,z-.028),(x,-.15,z-.028),.025,'brass',16)
        g.box((x,.01,z+.12),(.065,.085,.1),'oak_dark')
    for i in range(8):g.ring((0,-.115,.805+i*.007),.024,.003,'leather',axis='Z',n=16,sides=6)
    g.box((0,-.03,.35),(.97,.27,.045),'oak')
    for x in (-.32,-.2,-.08):g.rod((x,-.06,.39),(x+.37,-.06,.42),.007,'oak_light')
    g.box((.40,-.04,.405),(.19,.12,.07),'leather',.012)
    return g

def rope_winch():
    g=Geo();platform(g,1.05,.89,.10)
    for x in (-.38,.38):
        g.box((x,0,.61),(.11,.26,1.10),'oak');g.beam((x,-.30,.12),(x,0,.77),.072,'oak_dark')
    g.rod((-.54,0,.83),(.53,0,.83),.035,'iron')
    g.cyl((-.31,0,.83),.14,.62,'oak',32,Matrix.Rotation(math.pi/2,3,'Y'))
    for x in (-.32,.32):g.cyl((x,0,.83),.21,.028,'oak_light',36,Matrix.Rotation(math.pi/2,3,'Y'))
    helix(g,(-.29,0,.83),.158,.58,20,.014,'thread','X')
    g.tube([(.26,-.1,.70),(.26,-.20,.58),(.20,-.28,.20),(.04,-.33,.13),(-.18,-.3,.135)],.014,'thread',8)
    for r in (.09,.13,.17):g.ring((-.20,-.23,.132),r,.014,'thread',n=36)
    g.rod((.54,0,.83),(.54,-.23,.60),.021,'iron');g.rod((.54,-.23,.60),(.76,-.23,.60),.028,'oak_light')
    for x in (-.39,.39):bolt(g,(x,-.141,.84),r=.035)
    return g

def hand_quern():
    g=Geo();bench(g,.82,.74,.64)
    g.lathe((0,0,.64),[(.34,0),(.355,.026),(.355,.12),(.34,.14)],'stone',48)
    g.lathe((0,0,.78),[(.34,0),(.34,.04),(.30,.17),(.095,.20),(.066,.19),(.067,.12)],'stone_light',48)
    for j in range(12):
        a=TAU*j/12
        g.tube([(.12*math.cos(a),.12*math.sin(a),.97),(.22*math.cos(a+.20),.22*math.sin(a+.20),.929),(.298*math.cos(a+.32),.298*math.sin(a+.32),.831)],.0025,'stone',6)
    g.cyl((.23,0,.925),.019,.20,'oak_dark',16);g.cyl((.23,0,1.10),.027,.048,'oak_light',20)
    g.box((0,-.347,.724),(.105,.14,.032),'oak_light',.006)
    g.lathe((0,-.36,.26),[(.13,0),(.20,.08),(.22,.15),(.203,.15),(.18,.085),(.11,.02)],'terracotta',32)
    g.cyl((0,-.36,.36),.17,.01,'wheat',32)
    for j in range(6):g.sphere((-.055+j*.02,.01,.961),(.007,.01,.005),'wheat',12,6)
    g.box((0,0,.19),(.66,.52,.04),'oak_light')
    return g

def honey_press():
    g=Geo();platform(g,1.1,.93,.10)
    for x in (-.42,.42):g.box((x,0,.86),(.12,.15,1.55),'oak_dark')
    g.box((0,0,1.61),(1.10,.22,.16),'oak_light',.012)
    g.box((0,0,.42),(.94,.70,.09),'oak_light')
    # Slatted cylindrical basket, small drain, catch crock and separate press head.
    for i in range(20):
        a=TAU*i/20;x=.25*math.cos(a);y=.25*math.sin(a)
        g.box((x,y,.75),(.069,.035,.54),'oak_light',.006,Matrix.Rotation(a+math.pi/2,3,'Z'))
    for z in (.51,.95):g.ring((0,0,z),.272,.018,'iron',n=48)
    g.cyl((0,0,1.02),.265,.07,'oak',48)
    g.cyl((0,0,1.08),.033,.63,'iron',24);helix(g,(0,0,1.10),.041,.59,14,.009)
    g.rod((-.34,0,1.72),(.34,0,1.72),.024,'oak_light')
    g.box((0,-.37,.417),(.12,.20,.035),'oak_dark')
    vessel(g,(0,-.40,.10),.17,.24,'glaze')
    # A small geometric comb fragment stays in its tray, no invented yield.
    g.box((.36,.28,.478),(.17,.17,.025),'oak_dark')
    for i in range(3):
        for j in range(3):g.cyl((.31+i*.043,.23+j*.043,.495),.022,.035,'wheat',6)
    for x in (-.42,.42):
        for z in (.47,1.61):bolt(g,(x,-.087,z),r=.021)
    return g

def bakers_peel_rack():
    g=Geo()
    for x in (-.48,.48):
        g.box((x,0,.92),(.08,.10,1.84),'oak');g.box((x,0,.045),(.22,.61,.09),'oak_dark')
    for z in (.2,1.17,1.72):g.box((0,0,z),(1.05,.075,.07),'oak_light')
    # Three distinctly shaped oven peels, modeled paddle blades and long shafts.
    for j in range(3):
        x=-.32+j*.32;z=.50+j*.055
        g.rod((x,-.075,z+.1),(x,-.075,1.91-j*.1),.020,'oak_light')
        if j==0:
            prism(g,[(x-.115,z-.22),(x-.15,z-.15),(x-.15,z+.05),(x-.10,z+.15),(x+.10,z+.15),(x+.15,z+.05),(x+.15,z-.15),(x+.115,z-.22)],.025,'oak_light',-.08)
        elif j==1:
            g.sphere((x,-.08,z-.035),(.14,.014,.19),'oak_light',28,12)
        else:
            prism(g,[(x-.13,z-.21),(x-.145,z+.11),(x+.145,z+.11),(x+.13,z-.21)],.013,'iron',-.08)
        g.ring((x,-.08,1.88-j*.1),.027,.006,'leather','Y',20)
        g.rod((x,0,1.62),(x,-.14,1.62),.012,'iron')
    g.box((0,-.02,.28),(.84,.25,.04),'oak')
    g.box((.24,-.09,.345),(.22,.16,.08),'thread',.005)
    for j in range(7):g.rod((.15+j*.03,-.17,.34),(.15+j*.03,-.17,.42),.003,'oak_dark',6)
    return g

def shaving_horse():
    g=Geo()
    for x in (-.47,.47):
        for y in (-.18,.18):g.beam((x*1.17,y*1.4,.03),(x,y,.60),.075)
    for j in range(3):plank(g,(0,-.225+(j+.5)*.15,.62),(1.48,.145,.095),'oak_light')
    # Sloping shaving bed and treadle-operated clamp, different from a sawhorse.
    rot=Matrix.Rotation(-.23,3,'Y')
    g.box((.30,0,.81),(.71,.28,.065),'oak',.012,rot)
    for y in (-.13,.13):g.beam((.20,y,.20),(.40,y,1.08),.060,'oak_dark')
    g.box((.40,0,1.08),(.14,.36,.085),'oak_light')
    g.box((.18,0,.23),(.13,.55,.055),'oak_light')
    g.rod((.28,-.28,.58),(.28,.28,.58),.023,'iron')
    for y in (-.285,.285):bolt(g,(.28,y,.58),r=.033)
    g.rod((-.02,0,.805),(.60,0,.95),.042,'endgrain',16)
    g.rod((-.50,-.14,.679),(-.50,.14,.679),.011,'iron')
    for y in (-.17,.17):g.box((-.50,y,.68),(.075,.07,.045),'oak_dark',.008)
    for i in range(7):
        a=i*.9;g.tube([(-.16+math.cos(a+k*.45)*.05,.05+math.sin(a+k*.45)*.04,.686+k*.001) for k in range(9)],.006,'endgrain',6)
    return g

ASSETS=[
 ('treadle_potters_wheel','Treadle pottery wheel',potters_wheel),
 ('arched_pottery_kiln','Arched pottery kiln',kiln),
 ('clay_drying_shelves','Clay drying shelves',drying_rack),
 ('horn_anvil_stump','Horn anvil on banded stump',anvil_stump),
 ('forge_with_bellows','Hooded forge with bellows',forge_bellows),
 ('smith_tong_rack','Smith tong and iron rack',tong_rack),
 ('sage_dye_vat','Sage cloth dye vat',dye_vat),
 ('laced_leather_frame','Laced leather stretching frame',leather_frame),
 ('jewelers_drawbench','Jeweler drawplate and winding bench',jewel_drawbench),
 ('candle_mold_rack','Six candle molds and curing rack',candle_molds),
 ('screw_book_press','Threaded bookbinding press',book_press),
 ('coopers_stave_jig','Cooper stave shaping jig',cooper_jig),
 ('bowyers_shaping_form','Bowyer pegged shaping form',bow_shaping_form),
 ('rope_winding_winch','Rope winding winch',rope_winch),
 ('grain_hand_quern','Grain hand quern and catch bowl',hand_quern),
 ('honey_basket_press','Honey basket press and catch crock',honey_press),
 ('bakers_oven_peel_rack','Baker oven peel and brush rack',bakers_peel_rack),
 ('treadle_shaving_horse','Treadle shaving horse with drawknife',shaving_horse),
]

def camera(location,target,ortho):
    data=bpy.data.cameras.new('CatalogCamera');ob=bpy.data.objects.new('CatalogCamera',data);bpy.context.scene.collection.objects.link(ob)
    ob.location=location;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=ortho
    bpy.context.scene.camera=ob;return ob

def area(name,p,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    ob=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(ob);ob.location=p;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def validate_object(ob):
    me=ob.data;me.calc_loop_triangles();coords=[ob.matrix_world@v.co for v in me.vertices]
    invalid=sum(not all(math.isfinite(v) for v in co) for co in coords)
    degenerate=sum((coords[t.vertices[1]]-coords[t.vertices[0]]).cross(coords[t.vertices[2]]-coords[t.vertices[0]]).length*.5<1e-12 for t in me.loop_triangles)
    return {'vertices':len(coords),'triangles':len(me.loop_triangles),'nonfinite_vertices':invalid,'degenerate_triangles':degenerate,'material_slots':len(me.materials),'bounds_min_m':[min(v[a] for v in coords) for a in range(3)],'bounds_max_m':[max(v[a] for v in coords) for a in range(3)]}

def main():
    started=time.time();bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=20;scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED';scene.render.threads=2
    scene.render.resolution_x=1900;scene.render.resolution_y=1600;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.world.color=(.28,.28,.28)
    sources=[];manifest={'style_id':STYLE,'units':'metres','source_up':'Z','gltf_up':'Y via official Blender exporter','generator':str(Path(__file__).relative_to(ROOT)).replace('\\','/'),'blender_version':bpy.app.version_string,'asset_count':len(ASSETS),'source_provenance':'Original procedural workshop designs by GPT-6 Astra under user art authorization. Minimal repository-original mesh/PBR helpers copied from MarketLife20260912/build_market_life.py; its builders were neither imported nor run.','external_dependencies':[],'third_party_assets':[],'rights_note':'No imported images, source characters or private world state. Project-wide redistribution license is not selected by this delivery.','scope':'Decorative static props only. No working production logic, collision, resident skill, LOD, rig or save behavior claimed.','assets':[]}
    for index,(key,title,builder) in enumerate(ASSETS):
        g=builder();col=bpy.data.collections.new('AW_'+key);scene.collection.children.link(col)
        ob=g.finish('AW_'+key,col)
        low=min(v.co.z for v in ob.data.vertices)
        for v in ob.data.vertices:v.co.z-=low
        ob.asset_mark();ob.asset_data.description=title+' | Original decorative artisan prop'
        check=validate_object(ob)
        if check['nonfinite_vertices'] or check['degenerate_triangles']:raise RuntimeError(key+' invalid source: '+str(check))
        ob.select_set(True);bpy.context.view_layer.objects.active=ob;dest=OUT/(key+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
        ob.select_set(False)
        entry={'id':key,'name':title,'file':str(dest.relative_to(ROOT)).replace('\\','/'),'triangles':check['triangles'],'vertices':check['vertices'],'dimensions_m':[round(check['bounds_max_m'][a]-check['bounds_min_m'][a],6) for a in range(3)],'bounds_min_m':[round(v,6) for v in check['bounds_min_m']],'bounds_max_m':[round(v,6) for v in check['bounds_max_m']],'materials':[m.name for m in ob.data.materials],'glb_bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'origin':'ground centered; source Z=0','external_dependencies':[],'source_validation':check}
        manifest['assets'].append(entry);sources.append(ob)
        print('ASSET_EXPORTED',key,check['triangles'],flush=True)
    # Real independent GLB import, source comparisons, finite coordinates/PBR check.
    validation=[]
    for entry in manifest['assets']:
        glb=(ROOT/entry['file']).read_bytes();json_len=struct.unpack_from('<I',glb,12)[0];payload=json.loads(glb[20:20+json_len]);external_uris=[part['uri'] for key in ('buffers','images') for part in payload.get(key,[]) if 'uri' in part and not part['uri'].startswith('data:')]
        before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/entry['file']))
        imported=[o for o in bpy.data.objects if o not in before];meshobs=[o for o in imported if o.type=='MESH'];checks=[validate_object(o) for o in meshobs]
        mats={m for o in meshobs for m in o.data.materials if m};bad_materials=[]
        for m in mats:
            p=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
            if not p:bad_materials.append(m.name)
            elif not all(math.isfinite(v) and 0<=v<=1 for v in (*p.inputs['Base Color'].default_value,p.inputs['Roughness'].default_value,p.inputs['Metallic'].default_value)):bad_materials.append(m.name)
        lo=[min(c['bounds_min_m'][a] for c in checks) for a in range(3)];hi=[max(c['bounds_max_m'][a] for c in checks) for a in range(3)];dims=[hi[a]-lo[a] for a in range(3)]
        derror=max(abs(dims[a]-entry['dimensions_m'][a]) for a in range(3))
        rec={'id':entry['id'],'actual_glb_import':True,'imported_meshes':len(meshobs),'triangles':sum(c['triangles'] for c in checks),'nonfinite_vertices':sum(c['nonfinite_vertices'] for c in checks),'degenerate_triangles':sum(c['degenerate_triangles'] for c in checks),'invalid_pbr_materials':bad_materials,'external_uris':external_uris,'gltf_material_count':len(payload.get('materials',[])),'max_dimension_error_m':derror,'ground_error_m':abs(lo[2])}
        rec['passed']=bool(meshobs) and not rec['nonfinite_vertices'] and not rec['degenerate_triangles'] and not bad_materials and not external_uris and derror<1e-4 and rec['ground_error_m']<1e-4 and rec['triangles']==entry['triangles']
        validation.append(rec)
        for ob in imported:bpy.data.objects.remove(ob,do_unlink=True)
        if not rec['passed']:raise RuntimeError('GLB validation failed: '+str(rec))
    (EVIDENCE/'glb_validation.json').write_text(json.dumps({'all_passed':all(r['passed'] for r in validation),'asset_count':len(validation),'checks':validation},indent=2),encoding='utf-8')
    manifest['total_triangles']=sum(e['triangles'] for e in manifest['assets'])
    for dest in (HERE/'manifest.json',EVIDENCE/'manifest.json'):dest.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    # Full-scale editable source library, independently scaled catalog duplicates.
    for i,ob in enumerate(sources):
        ob.location=((i%4)*3.1,(i//4)*3.1,0)
        for col in ob.users_collection:col.hide_render=True;col.hide_viewport=True
    preview=bpy.data.collections.new('PRESENTATION_ONLY');scene.collection.children.link(preview);displays=[]
    rows=math.ceil(len(ASSETS)/4)
    for i,source in enumerate(sources):
        ob=bpy.data.objects.new('DISPLAY_'+source.name,source.data);preview.objects.link(ob);scale=2.0/max(source.dimensions);ob.scale=(scale,)*3;ob.location=((i%4)*3.0,(rows-1-i//4)*3.0,.03);displays.append(ob)
        font=bpy.data.curves.new('Label%02d'%(i+1),'FONT');font.body='%02d  %s'%(i+1,ASSETS[i][0].replace('_',' '));font.align_x='CENTER';font.size=.12;font.materials.append(material('ink'))
        label=bpy.data.objects.new(font.name,font);preview.objects.link(label);label.location=(ob.location.x,ob.location.y-1.18,.018)
    g=Geo();g.box((4.5,(rows-1)*1.5,-.075),(13.4,rows*3.2+.5,.15),'canvas',.03);ground=g.finish('CatalogGround',preview)
    target=(4.5,(rows-1)*1.5,.3);cam=camera((17,-20,29),target,max(16,rows*3.4+2))
    lights=[area('Key',(-3,-5,15),2300,9,target),area('Fill',(12,8,13),1900,8,target)]
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'artisan_workshops_library.blend'))
    scene.render.filepath=str(EVIDENCE/'workshops_overview.png');bpy.ops.render.render(write_still=True)
    if '--no-closeups' not in sys.argv:
        for ob in preview.objects:ob.hide_render=True
        ground.hide_render=False;ground.location=(-4.5,-(rows-1)*1.5,0)
        shots=[('pottery_and_forge_detail',[0,1,3,4],[(0,0,0),(1.8,.35,0),(.1,-1.65,0),(3.5,-.1,0)],(8,-11,7),(1.9,0,.65),6.1),('fine_crafts_detail',[6,7,8,10],[(0,0,0),(1.6,.5,0),(3.1,.1,0),(1.8,-1.5,0)],(7,-10,8),(1.7,.1,.65),5.7),('rural_workshop_detail',[12,13,14,15,16,17],[(0,1,0),(1.7,1,0),(3.15,1,0),(3.0,-.7,0),(-.35,-1,0),(1.25,-.75,0)],(8,-10,8),(1.45,.1,.65),6.6)]
        for name,ids,positions,eye,target,ortho in shots:
            for ob in displays:ob.hide_render=True
            for idx,p in zip(ids,positions):ob=displays[idx];ob.hide_render=False;ob.scale=(1,1,1);ob.location=p
            cam.location=eye;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=ortho
            lights[0].location=(0,-5,10);lights[0].data.energy=1500;lights[1].location=(7,5,10);lights[1].data.energy=1300
            scene.render.resolution_x=1700;scene.render.resolution_y=1200;scene.cycles.samples=24
            scene.render.filepath=str(EVIDENCE/(name+'.png'));bpy.ops.render.render(write_still=True)
    (EVIDENCE/'run_complete.json').write_text(json.dumps({'pid':os.getpid(),'seconds':round(time.time()-started,2),'asset_count':len(ASSETS),'total_triangles':manifest['total_triangles'],'glb_roundtrip_all_passed':True},indent=2),encoding='utf-8')
    print('WORKSHOPS_COMPLETE',len(ASSETS),manifest['total_triangles'],time.time()-started,flush=True)

if __name__=='__main__':main()
