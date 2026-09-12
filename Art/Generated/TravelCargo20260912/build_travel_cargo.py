"""Original travel and cargo props for the first-floor town. Blender 5.2.

Self-contained helper geometry.py is copied from this project's original
MarketLife20260912 primitive geometry, with local output paths. No imported art.
"""
import sys, math, json, hashlib, time, os
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy, bmesh
from mathutils import Vector, Matrix
from geometry import Geo, material, PALETTE, MATS, wheel, plank, crate, basket, pot

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'game/assets/generated/travel_cargo_20260912'
EVIDENCE=ROOT/'docs/validation/art_parallel_20260912/travel'
TAU=math.tau
PALETTE.update({'canvas_dark':('BBA781',.93,0),'rope':('BDA270',.9,0),
 'copper':('AA7356',.4,.68),'glass':('86AAA0',.27,0),'fish':('869C95',.5,.05)})

def strap(g,p,d,mat='leather',axis='X'):
    x,y,z=p;w,h=d
    if axis=='X': pts=[(x,-w/2+y,z),(x,-w/2+y,z+h),(x,w/2+y,z+h),(x,w/2+y,z),(x,-w/2+y,z)]
    else: pts=[(-w/2+x,y,z),(-w/2+x,y,z+h),(w/2+x,y,z+h),(w/2+x,y,z),(-w/2+x,y,z)]
    g.tube(pts,.021,mat,6)

def cloth_panel(g,points,mat='canvas',thickness=.012):
    n=len(points);v=[Vector(p) for p in points];normal=(v[1]-v[0]).cross(v[2]-v[0]).normalized()*thickness
    g.mesh(v+[p+normal for p in v],[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)

def base_cart(g,w=1.55,d=2.45):
    for i in range(9):plank(g,((i-4)*w/9,0,.79),(w/9-.007,d,.085),'oak_light')
    for x in (-w*.38,w*.38):g.box((x,0,.65),(.12,d+.16,.16),'oak_dark')
    for y in (-d*.31,d*.31):
        g.rod((-w*.64,y,.49),(w*.64,y,.49),.065,'iron',12)
        for x in (-w*.64,w*.64):wheel(g,(x,y,.49),.47,'X',10)
    for x in (-w*.32,w*.32):g.beam((x,-d/2,.68),(x,-d/2-1.35,.45),.075,'oak')
    g.rod((-w*.32,-d/2-1.34,.45),(w*.32,-d/2-1.34,.45),.06,'oak_dark')

def caravan():
    g=Geo();base_cart(g)
    for x in (-.77,.77):
        for j in range(3):g.box((x,0,.96+j*.13),(.07,2.5,.112),'oak_light')
        for y in (-1.16,0,1.16):g.box((x,y,1.08),(.1,.1,.63),'oak_dark')
    # Three dimensional barrel-vault canvas, with open entrances and wooden ribs.
    for j in range(5):
        y=-1.12+j*.56
        pts=[(.78*math.cos(math.pi*i/24),y,1.28+.83*math.sin(math.pi*i/24)) for i in range(25)]
        g.tube(pts,.028,'oak_light',8)
    for j in range(16):
        a=math.pi*j/16;b=math.pi*(j+1)/16
        cloth_panel(g,[(.82*math.cos(a),-1.22,1.28+.88*math.sin(a)),(.82*math.cos(b),-1.22,1.28+.88*math.sin(b)),(.82*math.cos(b),1.22,1.28+.88*math.sin(b)),(.82*math.cos(a),1.22,1.28+.88*math.sin(a))], 'sage' if j%4==0 else 'canvas')
    for y in (-1.24,1.24):g.tube([(.83*math.cos(math.pi*i/32),y,1.28+.89*math.sin(math.pi*i/32)) for i in range(33)],.014,'thread',8)
    for side in (-1,1):
        for j in range(6):g.tube([(side*.79,-1.1+j*.44,1.28),(side*.81,-1.1+j*.44,.92)],.008,'rope',6)
    g.box((0,-1.26,.81),(1.25,.12,.13),'oak_dark')
    for z,y in ((.3,-1.52),(.52,-1.39)):g.box((0,y,z),(.75,.24,.09),'oak_light')
    return g

def water_cart():
    g=Geo();base_cart(g,1.2,1.8)
    rot=Matrix.Rotation(math.pi/2,3,'X')
    # Horizontal barrel with stave seam bands and cradle.
    for j in range(24):
        a=TAU*j/24
        g.beam((.46*math.cos(a),-.72,1.32+.46*math.sin(a)),(.46*math.cos(a),.72,1.32+.46*math.sin(a)),.108,'oak_light' if j%3 else 'oak')
    for y in (-.74,.74):g.cyl((0,y,1.32),.475,.025,'oak',32,rot)
    for y in (-.55,.05,.58):g.ring((0,y,1.32),.5,.028,'iron','Y',48)
    for y in (-.55,.55):
        for x in (-.4,.4):g.beam((x,y,.82),(x*.7,y,1.02),.12,'oak_dark')
    g.rod((0,-.75,1.14),(0,-.94,1.14),.035,'brass',14)
    g.rod((0,-.91,1.14),(0,-.91,1.03),.03,'brass',14)
    g.rod((-.1,-.82,1.22),(.1,-.82,1.22),.016,'brass',10)
    return g

def luggage_trolley():
    g=Geo()
    for x in (-.31,.31):
        g.beam((x,.18,.19),(x,.48,1.31),.06,'oak')
        wheel(g,(x*1.25,.25,.23),.22,'X',8)
    for z,y in ((.23,.18),(.72,.32),(1.18,.44)):g.beam((-.34,y,z),(.34,y,z),.06,'oak_light')
    for x in (-.31,.31):g.box((x,-.08,.18),(.06,.72,.07),'iron')
    g.box((0,-.08,.18),(.68,.64,.065),'oak_light')
    g.box((0,-.06,.5),(.55,.44,.5),'canvas_dark',.04)
    for x in (-.18,.18):strap(g,(x,-.06,.25),(.47,.51),'leather')
    g.ring((0,.44,1.28),.16,.026,'leather','Y',28,8,scale=(1.5,.55))
    return g

def pack_saddle():
    g=Geo()
    for y in (-.35,.35):
        g.beam((-.48,y,.12),(-.18,y,.55),.105,'oak')
        g.beam((.48,y,.12),(.18,y,.55),.105,'oak')
        g.box((0,y,.53),(.57,.1,.12),'oak_light')
    for x in (-.31,.31):g.box((x,0,.31),(.18,.94,.1),'leather',.03)
    for y in (-.25,.25):
        g.tube([(-.48,y,.16),(-.53,y,.08),(0,y,0),(.53,y,.08),(.48,y,.16)],.025,'leather',8)
    for x in (-.4,.4):g.ring((x,-.29,.4),.055,.011,'brass','Y',24)
    return g

def panniers():
    g=Geo()
    for x in (-.4,.4):
        g.box((x,0,.32),(.51,.57,.62),'leather',.055)
        g.box((x,-.01,.62),(.55,.62,.09),'oak_dark',.045)
        for y in (-.17,.17):
            strap(g,(x,y,.02),(.56,.66),'canvas_dark','Y')
        for yy in (-.15,.15):g.box((x-.271,yy,.45),(.025,.066,.08),'brass',.006)
    for y in (-.19,.19):g.tube([(-.42,y,.64),(-.18,y,.76),(.18,y,.76),(.42,y,.64)],.032,'leather',8)
    return g

def tent():
    g=Geo()
    for y in (-1.0,1.0):
        g.rod((0,y,0),(0,y,1.87),.04,'oak',14)
    g.rod((0,-1.15,1.8),(0,1.15,1.8),.033,'oak_dark')
    for side in (-1,1):
        cloth_panel(g,[(0,-1.08,1.8),(side*1.12,-1.08,.035),(side*1.12,1.08,.035),(0,1.08,1.8)],'canvas')
        for y in (-1.08,0,1.08):g.tube([(0,y,1.815),(side*1.12,y,.05)],.009,'canvas_dark',6)
        for y in (-1.02,1.02):
            g.rod((side*1.35,y*1.2,0),(side*1.35,y*1.2,.2),.023,'oak_dark',8)
            g.tube([(side*.74,y,.61),(side*1.35,y*1.2,.13)],.009,'rope',6)
    # Rear wall and tied entrance flaps preserve a visible opening.
    cloth_panel(g,[(-1.1,1.075,.04),(1.1,1.075,.04),(0,1.075,1.79)],'canvas_dark')
    for s in (-1,1):
        cloth_panel(g,[(s*1.09,-1.09,.04),(s*.79,-1.105,.26),(s*.28,-1.105,1.14),(0,-1.09,1.79)],'sage')
        g.ring((s*.72,-1.12,.55),.06,.009,'rope','Y',20)
    g.box((0,.1,.035),(1.45,1.65,.038),'rust_cloth',.015)
    return g

def tent_bundle():
    g=Geo();rot=Matrix.Rotation(math.pi/2,3,'Y')
    g.cyl((-.56,0,.22),.21,1.12,'canvas',32,rot)
    for x in (-.37,.37):g.ring((x,0,.22),.218,.025,'leather','X',32)
    for y in (-.12,.08):g.rod((-.78,y,.11),(.77,y,.11),.025,'oak_light',12)
    for x in (-.56,.56):
        g.ring((x,0,.22),.15,.009,'canvas_dark','X',32)
        g.ring((x,0,.22),.09,.009,'canvas_dark','X',28)
    g.tube([(-.34,0,.46),(-.25,0,.63),(.25,0,.63),(.34,0,.46)],.022,'leather',8)
    return g

def field_stool():
    g=Geo()
    for y in (-.2,.2):
        g.beam((-.25,y,.025),(.25,y,.51),.047,'oak')
        g.beam((.25,y,.025),(-.25,y,.51),.047,'oak_light')
        g.cyl((0,y-.015,.265),.03,.03,'brass',12,Matrix.Rotation(math.pi/2,3,'X'))
    for x in (-.25,.25):g.rod((x,-.24,.51),(x,.24,.51),.028,'oak_dark')
    for i in range(8):
        x=-.25+i*.5/8;xx=x+.5/8
        cloth_panel(g,[(x,-.25,.48+.035*(x/.25)**2),(xx,-.25,.48+.035*(xx/.25)**2),(xx,.25,.48+.035*(xx/.25)**2),(x,.25,.48+.035*(x/.25)**2)],'sage')
    return g

def scroll_case():
    g=Geo();rot=Matrix.Rotation(math.pi/2,3,'Y')
    g.lathe((-.34,0,.095),[(.078,0),(.082,.035),(.074,.62),(.085,.65),(.085,.7)],'leather',24,rot)
    for x in (-.29,.29):g.ring((x,0,.095),.089,.013,'brass','X',24)
    g.tube([(-.28,0,.17),(-.16,-.04,.35),(.15,-.04,.36),(.3,0,.18)],.018,'leather',8)
    for x in (-.1,.1):g.box((x,-.085,.095),(.07,.016,.052),'brass',.005)
    return g

def waterskin():
    g=Geo()
    g.sphere((0,0,.24),(.17,.082,.22),'leather',28,16)
    g.lathe((0,0,.37),[(.08,0),(.045,.09),(.035,.15)],'leather',20)
    g.cyl((0,0,.52),.035,.04,'oak_light',16)
    g.tube([(.12,-.025,.39),(.26,-.025,.57),(.31,-.025,.2),(.18,-.025,.09)],.016,'rope',8)
    g.tube([(.173*math.sin(math.pi*i/20),-.007,.24+.222*math.cos(math.pi*i/20)) for i in range(21)],.006,'thread',6)
    return g

def ration_case():
    g=Geo()
    g.box((0,0,.075),(.47,.31,.15),'oak_light',.025)
    for y in (-.155,.155):g.box((0,y,.09),(.5,.025,.15),'oak')
    # Flipped lid rests behind; food is modeled as travel provisions.
    g.box((0,.27,.038),(.49,.2,.05),'oak_light',.02)
    for x in (-.15,.15):g.box((x,.16,.08),(.035,.035,.035),'brass',.006)
    for j in range(3):g.sphere((-.14+j*.13,-.015,.17),(.055,.105,.045),'bread',20,10)
    g.box((.11,.085,.17),(.15,.07,.09),'wheat',.015)
    return g

def rope_coil():
    g=Geo()
    # One continuous spiral, plus loose end: no stack of intersecting tori.
    points=[]
    for i in range(601):
        a=TAU*7*i/600;r=.07+.3*i/600
        points.append((r*math.cos(a),r*math.sin(a),.027))
    g.tube(points,.020,'rope',8)
    g.tube([( .37,0,.027),(.49,.02,.027),(.58,.12,.027),(.6,.22,.027),(.52,.3,.027)],.02,'rope',8)
    return g

def pulley_block():
    g=Geo()
    for y in (-.075,.075):
        g.sphere((0,y,.26),(.14,.026,.21),'oak',24,16)
    g.cyl((0,.045,.23),.1,.09,'brass',24,Matrix.Rotation(math.pi/2,3,'X'))
    g.ring((0,0,.23),.117,.015,'rope','Y',40)
    g.ring((0,0,.485),.075,.018,'iron','Y',28)
    g.rod((0,-.13,.24),(0,.13,.24),.027,'iron',12)
    g.tube([(-.105,0,.23),(-.1,0,.02)],.015,'rope',6)
    return g

def mooring_cleat():
    g=Geo();g.box((0,0,.055),(.7,.3,.11),'oak_dark')
    for x in (-.18,.18):g.rod((x,0,.09),(x,0,.3),.05,'iron',12)
    g.tube([(-.36,0,.34),(-.2,0,.3),(.2,0,.3),(.36,0,.34)],.047,'iron',12)
    g.tube([(-.2,-.07,.23),(.2,.07,.27),(.25,-.05,.27),(-.2,.07,.23),(-.27,-.02,.23),(-.2,-.07,.23)],.02,'rope',8)
    return g

def fishing_rods():
    g=Geo()
    for x in (-.36,.36):g.beam((x,.2,0),(x,.2,1.1),.055,'oak')
    for z in (.08,.85):g.box((0,.2,z),(.86,.09,.09),'oak_light')
    for x in (-.36,.36):g.box((x,0,.025),(.095,.6,.05),'oak_dark')
    for j in range(4):
        x=-.27+j*.18
        points=[(x,-.12,.1),(x,.0,.6),(x+.025,.09,1.1),(x+.06,.14,1.55),(x+.1,.2,1.92)]
        g.tube(points,.012,'oak_light',10)
        for z in (.18,.24,.3,.36):g.ring((x,-.1+z*.2,z),.016,.005,'leather','Z',16,6)
        g.tube([(x+.1,.2,1.92),(x+.04,-.05,.45)],.0025,'thread',5)
        g.sphere((x+.04,-.05,.45),(.025,.025,.052),'rust_cloth',12,8)
    return g

def creel():
    g=Geo();basket(g,(0,0,0),.26,.32)
    g.lathe((0,0,.33),[(.25,0),(.26,.02),(.22,.055),(.10,.055),(.095,.02)],'oak_light',36,cap=False)
    g.ring((0,0,.382),.098,.017,'oak_dark',32)
    g.tube([(-.24,0,.25),(-.31,0,.61),(.26,0,.61),(.25,0,.28)],.022,'leather',8)
    return g

def fish_rack():
    g=Geo()
    for x in (-.6,.6):
        for y in (-.24,.24):g.beam((x,y,0),(x,0,1.18),.045,'oak')
    g.rod((-.72,0,1.13),(.72,0,1.13),.035,'oak_dark',12)
    for j in range(6):
        x=-.49+j*.195;z=.80+(j%2)*.06
        g.tube([(x,0,1.13),(x,0,z+.17)],.006,'rope',6)
        g.sphere((x,0,z),(.064,.036,.17),'fish',20,12)
        cloth_panel(g,[(x,0,z-.15),(x-.07,0,z-.26),(x+.07,0,z-.26)],'fish')
        g.sphere((x,-.034,z+.085),(.009,.005,.009),'black',10,6)
    return g

def cargo_net():
    g=Geo()
    g.box((0,0,.24),(.98,.86,.46),'canvas_dark',.045)
    g.box((0,0,.62),(.49,.45,.30),'canvas',.035)
    for a in range(7):
        v=-.49+a*.98/6
        center_z=.79 if abs(v)<.25 else .48
        points=[(v,-.448,.025),(v,-.446,.45),(v,-.235,.49),(v,-.225,center_z),(v,.225,center_z),(v,.235,.49),(v,.446,.45),(v,.448,.025)]
        g.tube(points,.009,'rope',6)
        g.tube([(y*1.095,x*.88,z) for x,y,z in points],.009,'rope',6)
    for side in (-1,1):g.rod((side*.18,0,.79),(0,0,.86),.012,'rope',6)
    g.ring((0,0,.90),.047,.013,'rope','Y',24)
    return g

def pallet():
    g=Geo()
    for level in range(3):
        z=level*.135
        for y in (-.38,0,.38):g.box((0,y,z+.05),(1.12,.08,.1),'oak_dark')
        for j in range(6):plank(g,(-.49+j*.196,0,z+.115),(.17,.93,.06),'oak_light')
    return g

def ceramic_crate():
    g=Geo();crate(g,(0,0,0),1,.72,.5)
    for x in (-.3,0,.3):
        for y in (-.16,.16):
            pot(g,(x,y,.07),.105,.38,'terracotta',True)
    for x in (-.15,.15):g.box((x,0,.24),(.018,.64,.31),'canvas_dark',.004)
    g.box((0,0,.24),(.94,.015,.31),'canvas_dark',.004)
    return g

def cloth_bale():
    g=Geo();g.box((0,0,.28),(.94,.63,.55),'canvas',.07)
    for x in (-.31,0,.31):strap(g,(x,0,.01),(.65,.54),'rope')
    for y in (-.2,.2):strap(g,(0,y,.01),(.96,.54),'rope','Y')
    for i in range(5):g.box((0,-.322,.075+i*.09),(.68,.008,.018),'canvas_dark',.004)
    g.box((.27,-.335,.36),(.17,.012,.11),'paper',.005)
    return g

def barrel_sling():
    g=Geo()
    g.lathe((0,0,0),[(.26,0),(.3,.07),(.34,.32),(.3,.58),(.26,.65)],'oak',32)
    for z,r in ((.08,.309),(.31,.35),(.56,.315)):g.ring((0,0,z),r,.026,'iron',40)
    for a in range(12):
        t=TAU*a/12
        g.tube([((r+.001)*math.cos(t),(r+.001)*math.sin(t),z) for z,r in [(0,.26),(.08,.3),(.32,.34),(.58,.3),(.65,.26)]],.003,'grain',5)
    for x in (-.24,.24):g.tube([(x,0,.02),(x*1.35,0,.3),(x,0,.68),(0,0,.99)],.023,'rope',8)
    g.ring((0,0,1.04),.07,.02,'iron','Y',24)
    return g

def route_marker():
    g=Geo();g.lathe((0,0,0),[(.29,0),(.25,.12),(.21,.66),(.17,.75)],'stone',8)
    g.box((0,-.199,.4),(.25,.027,.26),'stone_light',.025)
    g.beam((-.08,-.22,.4),(.08,-.22,.4),.022,'ink')
    g.beam((.08,-.22,.4),(.025,-.22,.47),.022,'ink')
    g.beam((.08,-.22,.4),(.025,-.22,.33),.022,'ink')
    g.ring((0,0,.75),.12,.016,'sage','Z',24)
    return g

def lantern_case():
    g=Geo();g.box((0,0,.045),(.29,.25,.09),'iron',.015)
    for x in (-.12,.12):
        for y in (-.1,.1):g.rod((x,y,.06),(x,y,.4),.012,'iron',10)
    g.box((0,0,.18),(.17,.15,.19),'glass',.005)
    g.cyl((0,0,.09),.05,.09,'canvas',20)
    g.lathe((0,0,.39),[(.17,0),(.11,.05),(.07,.085),(.04,.09)],'copper',4)
    g.ring((0,0,.57),.075,.013,'iron','Y',28)
    for side in (-1,1):g.beam((side*.12,-.11,.08),(-side*.12,-.11,.4),.013,'iron')
    return g

ASSETS=[
 ('covered_caravan_wagon','帆篷四轮旅行车',caravan),('water_delivery_cart','横桶送水车',water_cart),
 ('porters_luggage_trolley','搬运双轮行李架',luggage_trolley),('timber_pack_saddle','木制驮架',pack_saddle),
 ('paired_leather_panniers','双侧皮革驮袋',panniers),('open_traveller_tent','敞口旅行帐篷',tent),
 ('strapped_tent_bundle','绑扎帐篷与营杆',tent_bundle),('folding_field_stool','交叉折叠营凳',field_stool),
 ('leather_scroll_case','皮革地图筒',scroll_case),('stitched_waterskin','缝线皮水囊',waterskin),
 ('open_travel_ration_case','开盖旅行食盒',ration_case),('coiled_hemp_rope','连续盘绕麻绳',rope_coil),
 ('wooden_pulley_block','木壳吊运滑轮',pulley_block),('iron_mooring_cleat','铁制系缆座',mooring_cleat),
 ('fishing_rod_stand','渔竿与浮标架',fishing_rods),('woven_fishing_creel','开口编织鱼篓',creel),
 ('air_drying_fish_rack','悬挂风干鱼架',fish_rack),('netted_cargo_bundle','绳网货物包',cargo_net),
 ('stacked_timber_pallets','叠放木货板',pallet),('partitioned_ceramic_crate','陶器分格运输箱',ceramic_crate),
 ('rope_bound_cloth_bale','麻绳布料包',cloth_bale),('hoist_barrel_sling','吊桶绳套',barrel_sling),
 ('carved_route_waystone','刻箭头路石',route_marker),('caged_travel_lantern','护笼旅行提灯',lantern_case)]

def clean_mesh(obj):
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bad=[f for f in bm.faces if f.calc_area()<1e-10]
    if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    return len(bad)

def camera(location,target,scale):
    d=bpy.data.cameras.new('CatalogCamera');o=bpy.data.objects.new('CatalogCamera',d)
    bpy.context.scene.collection.objects.link(o);o.location=location
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO';d.ortho_scale=scale;bpy.context.scene.camera=o;return o

def area(name,location,power,size,target):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=size
    o=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(o);o.location=location
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();return o

def main():
    start=time.time();OUT.mkdir(parents=True,exist_ok=True);EVIDENCE.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene;s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=True
    s.render.threads_mode='FIXED';s.render.threads=2;s.view_settings.view_transform='AgX'
    s.render.resolution_x=2200;s.render.resolution_y=1550;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.world.color=(.28,.28,.28)
    manifest={'pack':'travel_cargo_20260912','asset_count':len(ASSETS),'units':'metres','source_up':'Z','glb_up':'Y',
      'source':'Original procedural geometry. Primitive helper adapted from project MarketLife20260912.',
      'scope':'Decorative art only; no rig, interaction, collision, or resident behavior.',
      'license':'Project-wide license remains maintainer-controlled; no new third-party rights granted.',
      'external_dependencies':[],'blender_version':bpy.app.version_string,'assets':[]}
    objects=[]
    for index,(key,label,builder) in enumerate(ASSETS):
        g=builder();c=bpy.data.collections.new('TC_'+key);s.collection.children.link(c)
        obj=g.finish('TC_'+key,c);cleaned=clean_mesh(obj)
        low=min(v.co.z for v in obj.data.vertices)
        for v in obj.data.vertices:v.co.z-=low
        obj.asset_mark();obj.asset_data.description=label+' | Original travel/cargo prop'
        obj.data.calc_loop_triangles();vs=[v.co for v in obj.data.vertices]
        lo=[min(v[a] for v in vs) for a in range(3)];hi=[max(v[a] for v in vs) for a in range(3)]
        assert all(math.isfinite(n) for v in vs for n in v)
        assert all(t.area>=1e-10 for t in obj.data.loop_triangles)
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        p=OUT/(key+'.glb');bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
        obj.select_set(False)
        manifest['assets'].append({'id':key,'label_zh':label,'file':p.relative_to(ROOT).as_posix(),
          'triangles':len(obj.data.loop_triangles),'vertices':len(vs),'dimensions_m':[round(hi[a]-lo[a],5) for a in range(3)],
          'bounds_min_m':lo,'bounds_max_m':hi,'ground_origin':True,'material_count':len(obj.data.materials),
          'materials':[m.name for m in obj.data.materials],'removed_small_faces':cleaned,
          'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
        obj.location=((index%6)*4,(index//6)*4,0);objects.append(obj)
        print('ASSET_COMPLETE',key,flush=True)
    manifest['total_triangles']=sum(a['triangles'] for a in manifest['assets'])
    for p in (OUT/'manifest.json',HERE/'manifest.json',EVIDENCE/'manifest.json'):p.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    for obj in objects:obj.hide_render=True;obj.hide_set(True)
    presentation=bpy.data.collections.new('PRESENTATION_ONLY');s.collection.children.link(presentation)
    display=[]
    for i,source in enumerate(objects):
        d=manifest['assets'][i]['dimensions_m'];scale=2.4/max(d)
        obj=bpy.data.objects.new('DISPLAY_'+source.name,source.data);presentation.objects.link(obj)
        obj.scale=(scale,)*3;obj.location=((i%6)*3.35,(3-i//6)*3.55,.025);display.append(obj)
        font=bpy.data.curves.new('Index','FONT');font.body='%02d %s'%(i+1,ASSETS[i][0].replace('_',' '));font.size=.145;font.align_x='CENTER'
        label=bpy.data.objects.new('Label',font);presentation.objects.link(label);label.location=(obj.location.x,obj.location.y-1.25,.008);font.materials.append(material('ink'))
    floor=Geo();floor.box((8.4,5.3,-.08),(21.5,16,.15),'canvas',.04)
    ground=floor.finish('PresentationFloor',presentation)
    cam=camera((24,-26,34),(8.4,5.3,.6),24.5)
    lights=[area('Key',(2,-8,18),3000,10,(8,5,0)),area('Fill',(17,11,13),2100,9,(8,5,0))]
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'travel_cargo_library.blend'))
    s.render.filepath=str(EVIDENCE/'travel_contact_sheet.png');bpy.ops.render.render(write_still=True)
    for obj in presentation.objects:obj.hide_render=True
    ground.hide_render=False;ground.location=(-8.4,-5.3,0)
    groups=[('caravan_camp_detail',[0,5,6,7,9,23],[(0,.6,0),(3.1,.5,0),(1,-2,0),(3,-1.8,0),(2.2,-1.7,0),(3.7,-1.8,0)],(11,-14,10),(1.8,-.1,.9),8.0),
      ('cargo_detail',[1,2,3,4,17,19,20,21],[(0,1.3,0),(2,1.6,0),(3.2,1.7,0),(4.1,.4,0),(2,.1,0),(0,-1.1,0),(1.3,-1.3,0),(3.4,-1,0)],(10,-12,12),(2,.2,.8),8.2),
      ('fishing_travel_detail',[8,10,11,12,13,14,15,16,22],[(0,0,0),(.8,0,0),(1.6,0,0),(2.5,0,0),(3.3,0,0),(0,1.4,0),(1.1,1.3,0),(2.3,1.4,0),(3.5,1.2,0)],(8,-10,10),(1.7,.7,.55),5.7)]
    s.render.resolution_x=1800;s.render.resolution_y=1300;s.cycles.samples=32
    for light,pos in zip(lights,[(1,-5,11),(7,7,10)]):light.location=pos
    for name,ids,positions,eye,target,scale in groups:
        for obj in display:obj.hide_render=True
        for i,p in zip(ids,positions):display[i].hide_render=False;display[i].location=p;display[i].scale=(1,1,1)
        cam.location=eye;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        s.render.filepath=str(EVIDENCE/(name+'.png'));bpy.ops.render.render(write_still=True)
    (EVIDENCE/'run_complete.json').write_text(json.dumps({'assets':len(ASSETS),'pid':os.getpid(),'seconds':time.time()-start,'renders':['travel_contact_sheet.png']+[g[0]+'.png' for g in groups]},indent=2),encoding='utf-8')
    print('TRAVEL_CARGO_COMPLETE',len(ASSETS),flush=True)

if __name__=='__main__':main()
