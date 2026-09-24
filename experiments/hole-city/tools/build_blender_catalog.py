"""Original city kit. Run in Blender 5.2; coordinates are Blender Z-up metres.

The headless MCP runner calls build_one once per asset, then finish. Geometry
changes with every variant; material-only duplicates are never counted.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/city_kit'
SOURCE = ROOT / 'art_source'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
PALETTE = [(0.59,.28,.19),(.69,.61,.46),(.38,.44,.43),(.73,.68,.56),(.39,.35,.32),(.52,.58,.61)]
GLASS=(.10,.22,.28); TRIM=(.78,.76,.67); DARK=(.08,.105,.12); METAL=(.29,.34,.34)
WOOD=(.39,.23,.11); GREEN=(.19,.43,.08); WHITE=(.89,.88,.77)
BUILDINGS=['row_house','corner_shop','brick_apartment','office','warehouse','townhouse','hotel','civic_hall']
VEHICLES=['sedan','hatchback','pickup','police','school_bus','delivery_van','taxi','fire_truck']
PROPS=['bin','cone','lamp','bench','bollard','hydrant','mailbox','bus_stop','kiosk','barrier','planter','bike_rack','traffic_light','sign','dumpster','fence']
PLANTS=['round_tree','pine','cypress','palm','birch','maple','oak','shrub','hedge','flowerbed','sapling','topiary']
PEOPLE=['slim','short','tall','broad']
RECORDS=[]

def catalog():
    rows=[]
    for group,names,variants in [('building',BUILDINGS,6),('vehicle',VEHICLES,4),('prop',PROPS,4),('plant',PLANTS,4),('person',PEOPLE,4)]:
        for kind in names:
            for v in range(variants):rows.append((group,kind,v))
    return rows

def setup():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for d in list(bpy.data.materials):bpy.data.materials.remove(d)
    mat=bpy.data.materials.new('City_Vertex_Palette'); mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.78
    vc=mat.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name='Color'
    mat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    bpy.context.scene.render.fps=24
    return mat

class Mesh:
    def __init__(self):self.v=[];self.f=[];self.c=[];self.weights={}
    def poly(self,verts,faces,color,bone=None):
        n=len(self.v);self.v.extend(verts)
        for face in faces:self.f.append(tuple(n+i for i in face));self.c.append(color)
        if bone:self.weights.setdefault(bone,[]).extend(range(n,len(self.v)))
    def box(self,p,s,c,bone=None):
        x,y,z=p; a,b,d=[v/2 for v in s]
        self.poly([(x+i*a,y+j*b,z+k*d) for i,j,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],c,bone)
    def cyl(self,p,r,h,c,r2=None,n=10,bone=None,axis='Z'):
        r2=r if r2 is None else r2
        verts=[]
        for z,rad in [(-h/2,r),(h/2,r2)]:
            for i in range(n):
                a=i*math.tau/n; q=(math.cos(a)*rad,math.sin(a)*rad,z)
                if axis=='X':q=(q[2],q[1],-q[0])
                verts.append(tuple(p[j]+q[j] for j in range(3)))
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.poly(verts,faces,c,bone)
    def ball(self,p,s,c,bone=None,n=12,rings=6):
        vs=[]
        for j in range(rings+1):
            a=math.pi*j/rings
            for i in range(n):
                b=math.tau*i/n;vs.append((p[0]+s[0]*math.sin(a)*math.cos(b),p[1]+s[1]*math.sin(a)*math.sin(b),p[2]+s[2]*math.cos(a)))
        fs=[(j*n+i,(j+1)*n+i,(j+1)*n+(i+1)%n,j*n+(i+1)%n) for j in range(rings) for i in range(n)]
        self.poly(vs,fs,c,bone)
    def beam(self,a,b,r,c,bone=None):
        av,bv=Vector(a),Vector(b);axis=(bv-av).normalized(); u=axis.cross(Vector((0,1,0))).normalized()
        if u.length<.1:u=axis.cross(Vector((1,0,0))).normalized()
        v=axis.cross(u);vs=[];n=8
        for p in [av,bv]:
            for i in range(n):vs.append(tuple(p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))))
        self.poly(vs,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],c,bone)
    def object(self,name,mat):
        me=bpy.data.meshes.new(name);me.from_pydata(self.v,[],self.f);me.update()
        colors=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        for poly,c in zip(me.polygons,self.c):
            for li in poly.loop_indices:colors.data[li].color=(*c,1)
        obj=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(obj);me.materials.append(mat)
        for bone,indices in self.weights.items():obj.vertex_groups.new(name=bone).add(indices,1,'REPLACE')
        return obj

def building(m,k,v):
    idx=BUILDINGS.index(k); w=4.1+.21*v;d=5.8+.24*(v%3);h=5.2+1.13*v
    if k=='warehouse':h=3.8+.24*v;w=6+.24*v;d=7.3
    if k=='office':h=8+1.1*v
    wall=PALETTE[(idx+v)%len(PALETTE)]
    m.box((0,0,h/2),(w,d,h),wall)
    for z in [.16,2.15,h-.12]:m.box((0,0,z),(w+.22,d+.22,.19),TRIM)
    cols=3+v%2;floors=max(1,int((h-2.2)/1.3))
    for side in [-1,1]:
        for row in range(floors):
            z=2.95+row*1.25
            for col in range(cols):
                x=(col-(cols-1)/2)*(w-.65)/cols
                m.box((x,side*(d/2+.025),z),(.77,.10,.98),TRIM)
                m.box((x,side*(d/2+.085),z),(.61,.035,.81),GLASS)
                m.box((x,side*(d/2+.11),z),(.045,.035,.86),wall)
                m.box((x,side*(d/2+.14),z-.52),(.88,.27,.09),TRIM)
        for y in [-d*.26,d*.26]:
            for row in range(floors):
                z=2.95+row*1.25;m.box((side*(w/2+.045),y,z),(.09,.81,.97),TRIM);m.box((side*(w/2+.095),y,z),(.035,.63,.79),GLASS)
    m.box((0,-d/2-.08,.99),(1.05,.16,1.98),DARK)
    m.box((0,-d/2-.18,1.31),(.83,.04,1.12),GLASS)
    m.box((.31,-d/2-.23,.91),(.07,.06,.23),TRIM)
    if k in ['row_house','townhouse','civic_hall']:
        a=w/2+.25;b=d/2+.25;t=1.1+.12*v
        m.poly([(-a,-b,h),(a,-b,h),(a,b,h),(-a,b,h),(0,-b,h+t),(0,b,h+t)],[(0,4,1),(3,2,5),(0,3,5,4),(4,5,2,1)],(.23,.26,.25))
        m.box((-w*.28,d*.24,h+.7),(.43,.52,1.4),wall)
        if v%2:m.box((0,-d/2-.42,2.25),(1.6,.92,.18),TRIM)
    else:
        m.box((0,0,h+.06),(w+.2,d+.2,.20),(.25,.28,.28))
        for side in [-1,1]:m.box((side*w/2,0,h+.26),(.14,d,.40),TRIM)
        for i in range(1+v%3):
            m.box((-w*.25+i*.91,d*.14,h+.38),(.73,.93,.5),METAL)
            m.cyl((-w*.25+i*.91,d*.14,h+.65),.23,.04,DARK)
    if k in ['corner_shop','hotel','warehouse']:
        for side in [-1,1]:
            m.box((side*w*.3,-d/2-.09,1.09),(w*.26,.13,1.62),GLASS)
            m.box((side*w*.3,-d/2-.36,2.08),(w*.32,.83,.18),(.66,.22+.03*v,.13))
        m.box((0,-d/2-.12,2.5),(w*.74,.22,.40),(.24,.41,.39))
    if k=='brick_apartment':
        for z in [3.1,4.4]:
            m.box((0,-d/2-.36,z-.62),(w*.70,.83,.12),TRIM)
            for x in [-w*.3,0,w*.3]:m.box((x,-d/2-.76,z-.31),(.06,.06,.60),DARK)
    if k=='civic_hall':
        for x in [-w*.33,w*.33]:m.cyl((x,-d/2-.35,1.1),.16,2.2,TRIM)
    if k=='townhouse':
        for i in range(3):m.box((0,-d/2-.25-i*.22,.10+(2-i)*.12),(1.45,.32,.20+(2-i)*.24),TRIM)
        m.box((w*.29,-d/2-.26,3.2),(1.12,.60,1.31),wall)
        m.box((w*.29,-d/2-.57,3.2),(.87,.03,1.06),GLASS)
    if k=='hotel':
        m.box((-w*.42,-d/2-.46,h*.64),(.42,.66,2.1),(.64,.15,.08))
        for z in range(4):m.box((-w*.42,-d/2-.80,h*.64-.72+z*.46),(.24,.025,.24),WHITE)
        m.box((0,-d/2-.65,2.07),(2.5,1.4,.18),TRIM)

def vehicle(m,k,v):
    color=[(.72,.055,.035),(.035,.24,.68),(.70,.71,.65),(.18,.26,.20)][v]
    w=1.48+.07*v;l=3.25+.16*v;h=.57
    if k in ['school_bus','fire_truck']:w=1.88;l=4.5+.18*v
    if k=='hatchback':l*=.82
    if k=='school_bus':color=(.92,.63,.10)
    if k=='taxi':color=(.93,.69,.06)
    if k=='police':color=(.88,.88,.81)
    if k=='fire_truck':color=(.75,.055,.04)
    hull=[(-l*.5,.27),(-l*.49,.51),(-l*.29,.67),(l*.31,.67),(l*.49,.50),(l*.5,.27)]
    vs=[(x,y,z) for x in [-w*.5,w*.5] for y,z in hull]
    m.poly(vs,[tuple(range(6)),tuple(reversed(range(6,12)))]+[(i,i+6,(i+1)%6+6,(i+1)%6) for i in range(6)],color)
    # Sloping hood, roof and windscreen profile, unlike the former box cars.
    if k in ['sedan','hatchback','police','taxi']:
        profile=[(-l*.29,.68),(-l*.15,1.17+.025*v),(l*.13,1.17+.025*v),(l*.32,.69)]
        vs=[(x,y,z) for x in [-w*.43,w*.43] for y,z in profile]
        m.poly(vs,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3)],color)
        for side in [-1,1]:
            x=side*w*.436;top=1.14+.025*v
            # Sloped quarter windows, separate B pillar and inset door handles.
            for ys in [[(-l*.264,.73),(-l*.147,top),(-.035,top),(-.035,.73)],[(.035,.73),(.035,top),(l*.125,top),(l*.28,.73)]]:
                face=tuple(range(4)) if side<0 else tuple(reversed(range(4)))
                m.poly([(x,y,z) for y,z in ys],[face],GLASS)
            for y in [-.34,.59]:m.box((side*w*.506,y,.62),(.015,.16,.025),METAL)
            m.box((side*w*.54,-.53,.83),(.17,.22,.12),color)
        m.poly([(-w*.38,-l*.28,.72),(w*.38,-l*.28,.72),(w*.38,-l*.152,1.15),(-w*.38,-l*.152,1.15)],[(0,1,2,3)],GLASS)
        m.poly([(-w*.38,l*.30,.72),(-w*.38,l*.135,1.145),(w*.38,l*.135,1.145),(w*.38,l*.30,.72)],[(0,1,2,3)],GLASS)
    elif k=='pickup':
        m.box((0,-l*.22,.94),(w*.89,l*.39,.80),color);m.box((0,-l*.419,1.03),(w*.72,.03,.37),GLASS)
        m.box((0,l*.24,.73),(w*.78,l*.4,.07),DARK)
        for side in [-1,1]:m.box((side*w*.44,l*.23,.84),(.12,l*.44,.30),color)
    else:
        ch=1.58 if k=='school_bus' else 1.38
        m.box((0,0,ch),(w*.94,l*.84,1.56),color)
        m.box((0,-l*.423,ch+.06),(w*.79,.035,.72),GLASS)
        for side in [-1,1]:
            for i in range(4+v%2):m.box((side*w*.475,-l*.29+i*l*.145,ch+.1),(.028,l*.115,.57),GLASS)
        if k=='fire_truck':
            for x in [-.42,.42]:m.box((x,0,2.42),(.06,l*.77,.08),TRIM)
            for i in range(9):m.box((0,-l*.34+i*l*.085,2.42),(.9,.06,.07),TRIM)
    for x in [-w/2,w/2]:
        for y in [-l*.31,l*.31]:
            m.cyl((x,y,.30),.29,.20,DARK,n=14,axis='X');m.cyl((x*1.07,y,.30),.16,.23,METAL,n=12,axis='X')
    for y in [-l/2,l/2]:
        m.box((0,y,.38),(w*.93,.10,.12),METAL)
        for x in [-w*.31,w*.31]:m.box((x,y*1.013,.57),(.33,.06,.17),WHITE if y<0 else (.75,.015,.02))
    m.box((0,-l*.505,.49),(.54,.035,.16),DARK)
    for x in [-.18,-.06,.06,.18]:m.box((x,-l*.513,.49),(.025,.016,.12),METAL)
    m.box((0,l*.52,.40),(.36,.02,.12),WHITE)
    if k in ['taxi','police']:
        m.box((0,0,1.33),(.7,.29,.17),WHITE)
        if k=='police':
            for x,c in [(-.23,(.02,.2,.95)),(.23,(.95,.02,.02))]:m.box((x,0,1.39),(.25,.29,.14),c)

def prop(m,k,v):
    s=1+.09*v;c=[METAL,(.16,.30,.24),(.43,.18,.12),(.23,.30,.43)][v]
    if k=='bin':
        m.cyl((0,0,.39),.25*s,.78,c,n=8+2*v);m.cyl((0,0,.80),.28*s,.07,DARK)
        for i in range(8):
            a=i*math.tau/8;m.box((math.cos(a)*.251*s,math.sin(a)*.251*s,.4),(.025,.025,.58),DARK)
    elif k=='cone':
        m.box((0,0,.04),(.39*s,.39*s,.08),(.69,.22,.02));m.cyl((0,0,.34),.16*s,.59, (.94,.35,.025),.025,n=8+v*2);m.cyl((0,0,.34),.105*s,.11,WHITE,.082*s)
    elif k=='lamp':
        ht=3.1+.21*v;m.cyl((0,0,ht/2),.052,ht,c);m.cyl((0,0,.12),.13,.24,c)
        for side in ([-1,1] if v%2 else [1]):
            m.beam((0,0,ht-.05),(side*.65,0,ht+.12),.05,c);m.box((side*.65,0,ht+.06),(.42,.24,.14),c);m.box((side*.65,0,ht-.02),(.34,.18,.03),WHITE)
    elif k=='bench':
        for y in [-.19,0,.19]:m.box((0,y,.47),(1.5*s,.16,.07),WOOD)
        for z in [.69,.87]:m.box((0,.27,z),(1.5*s,.065,.14),WOOD)
        for x in [-.59*s,.59*s]:
            for y in [-.2,.23]:m.box((x,y,.25),(.08,.08,.5),DARK)
            m.box((x,.28,.63),(.06,.06,.65),DARK)
    elif k=='bollard':
        m.cyl((0,0,.43*s),.10,.86*s,c);m.ball((0,0,.87*s),(.11,.11,.10),c);m.cyl((0,0,.65*s),.106,.11,WHITE)
    elif k=='hydrant':
        m.cyl((0,0,.38),.15*s,.67,(.66,.095,.025));m.ball((0,0,.73),(.17*s,.17*s,.14),(.66,.095,.025));m.cyl((0,0,.46),.09,.54*s,TRIM,axis='X');m.cyl((0,0,.07),.22,.1,METAL)
    elif k=='mailbox':
        m.box((0,0,.38),(.12,.12,.75),c);m.box((0,0,.91),(.5*s,.43,.46),c);m.box((0,-.223,1.02),(.36,.025,.045),DARK)
    elif k=='bus_stop':
        for x in [-.9*s,.9*s]:m.box((x,0,1.17),(.08,.08,2.34),c)
        m.box((0,0,2.35),(2.2*s,1.1,.15),c);m.box((0,.31,1.22),(1.75*s,.06,1.77),GLASS);m.box((0,-.09,.46),(1.65*s,.45,.09),WOOD)
    elif k=='kiosk':
        m.box((0,0,.93),(1.7*s,1.45,1.85),c);m.box((0,-.75,1.11),(1.4*s,.055,.69),GLASS);m.box((0,-.84,.71),(1.9*s,.47,.10),TRIM);m.box((0,0,1.94),(2*s,1.85,.20),(.73,.27,.11))
    elif k=='barrier':
        for x in [-.62*s,.62*s]:m.box((x,0,.39),(.08,.10,.78),METAL);m.box((x,0,.06),(.18,.55,.12),METAL)
        m.box((0,0,.67),(1.5*s,.13,.27),(.89,.44,.04))
        for x in [-.5,0,.5]:m.box((x*s,-.072,.67),(.22,.02,.24),WHITE)
    elif k=='planter':
        m.cyl((0,0,.22),.28*s,.44,(.60,.28,.13),.40*s,n=8+v*2);m.ball((0,0,.53),(.40*s,.40*s,.29),GREEN)
    elif k=='bike_rack':
        m.box((0,0,.05),(1.45*s,.55,.1),METAL)
        for i in range(3+v):
            x=-.6*s+i*1.2*s/(2+v)
            for y in [-.2,.2]:m.beam((x,y,.07),(x,y,.7),.024,METAL)
            m.beam((x,-.2,.7),(x,.2,.7),.024,METAL)
    elif k=='traffic_light':
        m.cyl((0,0,1.55),.06,3.1,c);m.box((0,-.08,2.75),(.33,.28,.92),DARK)
        for z,col in [(2.48,(.02,.70,.13)),(2.75,(.95,.61,.02)),(3.02,(.8,.025,.01))]:m.ball((0,-.235,z),(.105,.035,.105),col)
        if v>0:m.box((.30,0,1.5+v*.1),(.26,.25,.39),DARK)
        if v>1:m.beam((0,0,3.1),(.8+.2*v,0,3.1),.04,c);m.box((.8+.2*v,0,2.9),(.30,.24,.45),DARK)
    elif k=='sign':
        m.cyl((0,0,1.03),.034,2.06,METAL);m.box((0,0,1.82),(.63+.1*v,.07,.51),(.065,.35,.60));m.box((0,-.044,1.82),(.43,.015,.06),WHITE)
    elif k=='dumpster':
        m.box((0,0,.58),(1.48*s,.89,1.07),c);m.box((0,0,1.16),(1.6*s,.97,.10),DARK)
        for x in [-.58*s,.58*s]:
            for y in [-.31,.31]:m.cyl((x,y,.11),.10,.09,DARK,axis='X')
    elif k=='fence':
        for x in [-.46*s,.46*s]:m.box((x,0,.46),(.065,.07,.92),c)
        for z in [.3,.78]:m.box((0,0,z),(1*s,.05,.045),c)
        for i in range(4+v):m.box((-.36*s+i*.72*s/(3+v),0,.52),(.032,.04,.64),c)

def plant(m,k,v):
    ht=2.35+.23*v;r=.67+.065*v;green=(.18+.022*v,.38+.025*v,.06+.015*v)
    if k=='cypress':ht*=1.3;r*=.48
    if k in ['shrub','hedge','flowerbed']:
        length=.95+.31*v
        if k=='flowerbed':
            m.box((0,0,.12),(length, .73,.24),TRIM)
            for i in range(5+v):
                x=(i/(4+v)-.5)*length*.87;m.beam((x,0,.22),(x,0,.58),.026,GREEN);m.ball((x,0,.6),(.12,.12,.08),(.86,.33+.06*v,.06))
        elif k=='hedge':m.box((0,0,.48),(length,.68,.96),green)
        else:
            for i in range(3):m.ball(((i-1)*.28,0,.38),(.42,.36,.42+v*.03),green)
        return
    m.cyl((0,0,ht*.43),.075+.007*v,ht*.86,WOOD,.045)
    if k in ['pine','cypress']:
        for i in range(3+v%2):m.cyl((0,0,ht*.43+i*.39),r*(1-i*.19),1.15,green,.015,n=10)
    elif k=='palm':
        for i in range(6+v):
            a=i*math.tau/(6+v);end=(math.cos(a)*1.2,math.sin(a)*1.2,ht*.79)
            m.poly([(0,0,ht),(end[0]-.16*math.sin(a),end[1]+.16*math.cos(a),ht+.20),end,(end[0]+.16*math.sin(a),end[1]-.16*math.cos(a),ht+.20)],[(0,1,2),(0,2,3)],green)
    elif k=='topiary':
        for i in range(2+v%2):m.ball((0,0,1+i*.63),(r*(1-i*.2),r*(1-i*.2),.43),green)
    elif k=='sapling':m.ball((0,0,ht*.78),(r*.60,r*.60,ht*.34),green)
    else:
        count={'round_tree':1,'birch':3,'maple':5,'oak':4}[k]
        for i in range(count):
            a=i*2.4;off=0 if count==1 else .39
            x=math.cos(a)*off;y=math.sin(a)*off;z=ht*.77+(i%2)*.31
            m.beam((0,0,ht*.51),(x,y,z),.047,WOOD);m.ball((x,y,z),(r,r,r*(1.08 if k!='birch' else 1.45)),green,n=10+v*2)

def person(m,k,v):
    scale={'slim':1,'short':.84,'tall':1.15,'broad':1.03}[k];th=.046 if k!='broad' else .065
    c=[(.07,.12,.16),(.18,.34,.44),(.58,.20,.12),(.38,.20,.49)][v]
    bones={'root':((0,0,.71),(0,0,1.09),None),'head':((0,0,1.09),(0,0,1.36),'root')}
    m.beam((0,0,.68),(0,0,1.09),th*1.55,c,'root');m.ball((0,0,1.26),(.145,.135,.155),c,'head')
    m.beam((-.16,0,1.03),(.16,0,1.03),th,c,'root')
    m.beam((-.105,0,.71),(.105,0,.71),th,c,'root')
    m.beam((0,0,1.06),(0,0,1.17),th,c,'head')
    for side,sign in [('L',-1),('R',1)]:
        x=sign*.105
        bones['thigh'+side]=((x,0,.71),(x,0,.39),'root');bones['shin'+side]=((x,0,.39),(x,-.035,.07),'thigh'+side)
        bones['arm'+side]=((sign*.16,0,1.03),(sign*.205,0,.78),'root');bones['forearm'+side]=((sign*.205,0,.78),(sign*.205,-.02,.55),'arm'+side)
        for part in ['thigh','shin','arm','forearm']:
            a,b,_=bones[part+side];m.beam(a,b,th,c,part+side);m.ball(a,(th,th,th),c,part+side,n=8,rings=4)
        m.box((x,-.055,.055),(.10,.19,.075),c,'shin'+side)
    if v==1:
        m.cyl((0,0,1.405),.16,.055,(.78,.40,.09),bone='head');m.box((0,-.11,1.39),(.20,.18,.035),(.78,.40,.09),'head')
    elif v==2:m.box((0,.12,.94),(.23,.17,.30),(.31,.42,.20),'root')
    elif v==3:m.ball((0,0,1.37),(.163,.143,.10),(.91,.66,.06),'head')
    m.v=[tuple(scale*c for c in p) for p in m.v]
    bones={name:(tuple(scale*x for x in a),tuple(scale*x for x in b),parent) for name,(a,b,parent) in bones.items()}
    return bones

def rig(obj,bones,name):
    data=bpy.data.armatures.new(name+'_Rig'); arm=bpy.data.objects.new(name+'_Rig',data);bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active=arm;arm.select_set(True);obj.select_set(False);bpy.ops.object.mode_set(mode='EDIT')
    for name,(a,b,parent) in bones.items():
        bone=data.edit_bones.new(name);bone.head=a;bone.tail=b
        if parent:bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');obj.parent=arm;mod=obj.modifiers.new('Stick_Rig','ARMATURE');mod.object=arm
    arm.animation_data_create()
    for clip,amplitude,frames in [('Idle',.04,49),('Walk',.52,33),('Run',.95,21)]:
        action=bpy.data.actions.new(clip);action.use_fake_user=True;arm.animation_data.action=action
        for frame in range(1,frames+1,2):
            phase=(frame-1)/(frames-1)*math.tau
            for bone in arm.pose.bones:
                bone.rotation_mode='XYZ';angle=0
                if bone.name.startswith(('thigh','arm')):
                    sign=-1 if bone.name.endswith('L') else 1
                    angle=math.sin(phase)*amplitude*sign*(-.72 if bone.name.startswith('arm') else 1)
                elif bone.name.startswith('shin'):angle=max(0,math.sin(phase+(0 if bone.name.endswith('L') else math.pi)))*amplitude*1.2
                elif bone.name.startswith('forearm'):angle=-.28 if clip!='Run' else -1.05
                bone.rotation_euler=(angle,0,0);bone.keyframe_insert('rotation_euler',frame=frame,group=bone.name)
            root=arm.pose.bones['root'];root.location=(0,0,abs(math.sin(phase))*(.025 if clip=='Walk' else .055 if clip=='Run' else .007));root.keyframe_insert('location',frame=frame)
        track=arm.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action)
    arm.animation_data.action=None
    for t in arm.animation_data.nla_tracks:t.mute=True
    return arm

def build_one(index):
    group,kind,v=catalog()[index];name=f'{index+1:03d}_{kind}_{v+1:02d}'
    mat=bpy.data.materials.get('City_Vertex_Palette') or setup();m=Mesh();bones=None
    if group=='building':building(m,kind,v)
    elif group=='vehicle':vehicle(m,kind,v)
    elif group=='prop':prop(m,kind,v)
    elif group=='plant':plant(m,kind,v)
    else:bones=person(m,kind,v)
    obj=m.object(name,mat);arm=rig(obj,bones,name) if bones else None
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    if arm:arm.select_set(True)
    bpy.context.view_layer.objects.active=obj
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=bool(arm),export_animation_mode='NLA_TRACKS',export_materials='EXPORT',export_yup=True)
    coords=m.v;lo=[min(p[i] for p in coords) for i in range(3)];hi=[max(p[i] for p in coords) for i in range(3)]
    size=[hi[i]-lo[i] for i in range(3)];center=[(lo[i]+hi[i])/2 for i in range(3)]
    rec={'id':name,'group':group,'kind':kind,'variant':v+1,'path':'res://assets/city_kit/'+path.name,'size':[size[0],size[2],size[1]],'center':[center[0],center[2],-center[1]],'triangles':sum(len(f)-2 for f in m.f),'geometry_sha256':hashlib.sha256(json.dumps([m.v,m.f],separators=(',',':')).encode()).hexdigest(),'file_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'animations':['Idle','Walk','Run'] if arm else []}
    RECORDS.append(rec)
    # Source scene is a labelled catalog; each exported GLB retains local origin.
    root=arm or obj;root.location=((index%16)*11,(index//16)*13,0)
    print(json.dumps({'built':name,'triangles':rec['triangles']}))
    return rec

def finish():
    assert len(RECORDS)==208
    groups={}
    for r in RECORDS:groups.setdefault(r['geometry_sha256'],[]).append(r['id'])
    assert len(groups)==208, [ids for ids in groups.values() if len(ids)>1]
    (OUT/'manifest.json').write_text(json.dumps({'schema':1,'authoring':'Original Blender geometry via Blender MCP command handlers','count':len(RECORDS),'assets':RECORDS},indent=2)+'\n',encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'city_catalog.blend'),compress=True)
    print('CATALOG_COMPLETE',len(RECORDS))

if __name__=='__main__':
    setup()
    for i in range(len(catalog())):build_one(i)
    finish()
