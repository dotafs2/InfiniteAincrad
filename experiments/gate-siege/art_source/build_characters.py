"""Original material-colored models for Gate Siege. Blender +Y is Godot -Z."""
import bpy, math, json, sys
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models'
OUT.mkdir(parents=True,exist_ok=True)
P={
 'blue':((.035,.36,.73,1),.14,.29), 'blue_light':((.11,.61,.95,1),.12,.28),
 'navy':((.017,.055,.13,1),.1,.36),'skin':((.82,.57,.39,1),0,.55),
 'skin_light':((1,.76,.56,1),0,.53),'tan':((.57,.54,.39,1),0,.66),
 'steel':((.3,.36,.42,1),.75,.23),'dark_steel':((.045,.065,.09,1),.65,.27),
 'silver':((.58,.64,.70,1),.7,.25),'black':((.018,.024,.035,1),.07,.46),
 'gold':((.95,.57,.055,1),.7,.24),'light_gold':((1,.79,.23,1),.6,.23),
 'red':((.53,.032,.052,1),0,.44),'red_light':((.76,.068,.08,1),0,.47),
 'pink':((.75,.36,.39,1),0,.54),'pink_light':((.91,.49,.46,1),0,.52),
 'boss_skin':((.66,.44,.34,1),0,.62),'boss_skin_light':((.78,.55,.43,1),0,.6),
 'pale':((.58,.64,.52,1),0,.6),'ivory':((.91,.89,.72,1),.1,.4),
 'crowd_skin':((.83,.68,.62,1),0,.65),'crowd_cloth':((.64,.31,.35,1),0,.62),
 'crowd_cap':((.78,.23,.29,1),0,.48),'crowd_cap_rim':((.65,.16,.21,1),0,.5),
 'eye':((1,.31,.08,1),.15,.3),'cyan':((.035,.92,1,1),.3,.19),
}
M={}
for name,(color,metal,rough) in P.items():
 color=tuple((c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4) for c in color[:3])+(1,)
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color;bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 if name in ['cyan','eye']:
  bs.inputs['Emission Color'].default_value=color;bs.inputs['Emission Strength'].default_value=.3
 M[name]=m
parts=[]
CROWD=False
def add(o,name,mat):
 o.name=name;o.data.materials.clear();o.data.materials.append(M[mat]);parts.append(o)
 for p in o.data.polygons:p.use_smooth=True
 return o
def ball(name,loc,size,mat,segments=16,rings=10):
 if CROWD: segments=min(12,segments);rings=min(6,rings)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
 o=add(bpy.context.object,name,mat);o.scale=size;return o
def box(name,loc,size,mat,bevel=.05):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
 o=add(bpy.context.object,name,mat);o.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('soft sculpted edges','BEVEL');mod.width=bevel;mod.segments=2
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def cyl(name,a,b,r,mat,r2=None,vertices=12):
 av,bv=Vector(a),Vector(b);delta=bv-av
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=delta.length,location=(av+bv)/2)
 o=add(bpy.context.object,name,mat);o.rotation_mode='QUATERNION';o.rotation_quaternion=delta.to_track_quat('Z','Y');return o
def limb(name,a,b,radii,mat):
 av,bv=Vector(a),Vector(b);delta=bv-av
 o=ball(name,(av+bv)/2,(radii[0],radii[1],delta.length/2+radii[0]*.35),mat)
 o.rotation_mode='QUATERNION';o.rotation_quaternion=delta.to_track_quat('Z','Y');return o
def torus(name,loc,major,minor,mat,rot=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=16,minor_segments=6,location=loc,rotation=rot)
 return add(bpy.context.object,name,mat)
def face(prefix,x,y,z,s,skin='skin',angry=False,helmet=False):
 ball(prefix+' cranium',(x,y,z),(.125*s,.108*s,.153*s),skin,16,10)
 ball(prefix+' lower jaw',(x,y+.04*s,z-.085*s),(.105*s,.091*s,.075*s),skin)
 for side in [-1,1]:
  ball(prefix+' ear',(x+side*.126*s,y,z-.012*s),(.028*s,.024*s,.042*s),skin,10,6)
  ball(prefix+' eye socket',(x+side*.048*s,y+.09*s,z+.009*s),(.04*s,.015*s,.027*s),'black',12,6)
  ball(prefix+' eye',(x+side*.046*s,y+.102*s,z+.012*s),(.024*s,.007*s,.014*s),'ivory',10,6)
  ball(prefix+' pupil',(x+side*.044*s,y+.109*s,z+.01*s),(.008*s,.004*s,.01*s),'black',8,6)
  brow=box(prefix+' brow',(x+side*.047*s,y+.102*s,z+.043*s),(.071*s,.022*s,.021*s),'black',.004*s)
  brow.rotation_euler[1]=side*(.22 if angry else -.04)
 ball(prefix+' nose',(x,y+.118*s,z-.025*s),(.031*s,.029*s,.042*s),skin,12,8)
 box(prefix+' mouth',(x,y+.117*s,z-.081*s),(.067*s,.011*s,.014*s),'black',.004*s)
 if angry:
  box(prefix+' teeth',(x,y+.125*s,z-.078*s),(.049*s,.007*s,.009*s),'ivory',.002*s)
 if helmet:
  ball(prefix+' helmet',(x,y-.004*s,z+.105*s),(.15*s,.14*s,.09*s),'blue_light')
  cyl(prefix+' cap band',(x,y-.004*s,z+.055*s),(x,y-.004*s,z+.098*s),.148*s,'blue',vertices=18)
  ball(prefix+' visor',(x,y+.095*s,z+.068*s),(.139*s,.112*s,.022*s),'blue')
  box(prefix+' cap badge',(x,y+.139*s,z+.108*s),(.034*s,.009*s,.041*s),'gold',.005*s)
def boot(name,x,y,z,s,mat='black'):
 ball(name+' toe',(x,y+.035*s,z+.07*s),(.077*s,.129*s,.073*s),mat)
 cyl(name+' ankle',(x,y,z+.065*s),(x,y,z+.2*s),.067*s,mat,vertices=12)
 box(name+' sole',(x,y+.025*s,z+.025*s),(.15*s,.245*s,.035*s),'dark_steel',.016*s)
def rifle(x,y,z,s=1):
 box('rifle housing',(x,y,z),(.09*s,.29*s,.10*s),'dark_steel',.018*s)
 cyl('rifle barrel',(x,y+.08*s,z+.015*s),(x,y+.38*s,z+.015*s),.025*s,'steel',vertices=10)
 cyl('rifle muzzle',(x,y+.32*s,z+.015*s),(x,y+.40*s,z+.015*s),.038*s,'dark_steel',vertices=10)
 box('rifle magazine',(x,y+.018*s,z-.079*s),(.043*s,.07*s,.11*s),'steel',.01*s)
 box('rifle sight',(x,y+.055*s,z+.07*s),(.025*s,.054*s,.027*s),'black',.004*s)
def minigun(x,y,z,s=1):
 # Barrels have genuine ring separation and dark bores, facing forward.
 cyl('minigun motor',(x,y-.08*s,z),(x,y+.22*s,z),.18*s,'dark_steel',vertices=16)
 cyl('minigun rear cap',(x,y-.13*s,z),(x,y-.085*s,z),.194*s,'steel',vertices=16)
 box('minigun feed',(x-.21*s,y-.005*s,z),(.2*s,.2*s,.23*s),'steel',.026*s)
 for i in range(6):
  t=i*math.tau/6;dx=math.cos(t)*.118*s;dz=math.sin(t)*.118*s
  cyl('rotary barrel',(x+dx,y+.15*s,z+dz),(x+dx,y+.79*s,z+dz),.040*s,'steel',vertices=10)
  cyl('barrel dark bore',(x+dx,y+.79*s,z+dz),(x+dx,y+.798*s,z+dz),.024*s,'black',vertices=10)
 for ty in [.25,.56,.72]:
  cyl('barrel retaining collar',(x,y+ty*s,z),(x,y+(ty+.04)*s,z),.18*s,'dark_steel',vertices=16)
 for side in [-1,1]:
  cyl('carry grip', (x+side*.2*s,y-.01*s,z+.08*s),(x+side*.2*s,y+.12*s,z+.28*s),.025*s,'black')
 box('gun rail',(x,y+.045*s,z+.29*s),(.43*s,.065*s,.052*s),'steel',.01*s)
def ammo_belt(x,y,z,s=1):
 for i in range(15):
  t=i/14
  xx=x+(.34-.68*t)*s;zz=z+(.41-.82*t)*s
  yy=y+(.045*math.sin(t*math.pi))*s
  cyl('brass cartridge',(xx,yy,zz-.056*s),(xx,yy,zz+.056*s),.027*s,'gold',vertices=8)
  cyl('cartridge tip',(xx,yy,zz+.056*s),(xx,yy,zz+.079*s),.027*s,'light_gold',r2=.003*s,vertices=8)
  box('ammo link',(xx,yy-.015*s,zz-.01*s),(.068*s,.035*s,.02*s),'dark_steel',.002*s)
def infantry():
 for side in [-1,1]:
  x=.083*side
  boot('infantry boot',x,0,0,.72)
  limb('trouser calf',(x,0,.13),(x,-.01,.29),(.059,.064),'blue')
  limb('trouser thigh',(x,-.01,.26),(x,0,.43),(.074,.074),'navy')
 ball('trouser seat',(0,-.007,.39),(.16,.09,.105),'blue')
 ball('shirt',(0,0,.54),(.155,.103,.168),'tan')
 box('belt',(0,0,.419),(.29,.185,.035),'black',.011)
 box('belt buckle',(0,.099,.418),(.048,.015,.042),'steel',.005)
 for side in [-1,1]:
  ball('shoulder',(side*.151,0,.627),(.068,.078,.087),'tan')
  limb('upper arm',(side*.16,0,.62),(side*.19,.095,.52),(.049,.052),'tan')
  limb('bare forearm',(side*.19,.095,.52),(side*.075,.22,.54),(.045,.043),'skin_light')
  ball('hand',(side*.072,.219,.54),(.045,.045,.041),'skin_light')
 box('shirt back seam',(0,-.1,.54),(.015,.01,.17),'skin',.002)
 face('soldier',0,0,.815,1,helmet=True)
 rifle(.035,.245,.56,.68)
 # Backpack with rounded canvas pockets gives the rear camera visible detail.
 box('canvas backpack',(0,-.105,.552),(.172,.071,.167),'tan',.022)
 for side in [-1,1]:box('backpack strap',(side*.068,-.146,.558),(.022,.011,.13),'navy',.004)
def gunner():
 for side in [-1,1]:
  x=side*.21
  boot('gunner boot',x,0,0,1.52)
  limb('gunner calf',(x,0,.2),(x,-.028,.55),(.14,.15),'navy')
  ball('knee armor',(x,.107,.48),(.135,.06,.132),'steel')
  limb('gunner thigh',(x,-.02,.48),(side*.18,0,.84),(.181,.172),'blue')
 ball('gunner pelvis',(0,-.012,.76),(.35,.21,.23),'navy')
 ball('gunner barrel torso',(0,0,1.06),(.41,.24,.38),'blue')
 ball('gunner left pec',(-.18,.166,1.2),(.22,.11,.17),'blue_light')
 ball('gunner right pec',(.18,.166,1.2),(.22,.11,.17),'blue_light')
 box('wide belt',(0,.01,.78),(.66,.42,.095),'black',.04)
 box('square buckle',(0,.24,.78),(.13,.032,.12),'steel',.013)
 for side in [-1,1]:
  ball('gunner shoulder',(side*.39,0,1.23),(.215,.226,.245),'blue_light')
  limb('gunner upper arm',(side*.43,0,1.22),(side*.47,.055,.93),(.18,.165),'blue')
  ball('elbow pad',(side*.465,.035,.96),(.175,.19,.145),'dark_steel')
  limb('gunner bare forearm',(side*.46,.09,.96),(side*.255,.34,.99),(.145,.14),'skin')
  ball('gunner glove',(side*.25,.37,.99),(.128,.131,.12),'black')
  for k in range(3):ball('glove knuckle',(side*.245+(k-1)*.042,.457,1.025),(.032,.024,.038),'steel',10,6)
  box('belt pouch',(side*.235,.221,.82),(.14,.065,.14),'tan',.018)
 face('gunner',0,0,1.562,1.7,'skin_light',angry=True,helmet=True)
 ammo_belt(0,.256,1.02,.83)
 # Rear canisters and straps read from the playable camera.
 box('ammo backpack',(0,-.251,1.07),(.45,.21,.47),'dark_steel',.06)
 for side in [-1,1]:
  cyl('rear ammo canister',(side*.153,-.39,.9),(side*.153,-.39,1.24),.07,'steel')
  box('rear harness',(side*.14,-.361,1.07),(.048,.025,.49),'gold',.008)
 minigun(0,.37,.91,.88)
def mech():
 for side in [-1,1]:
  x=side*.36
  box('mech boot sole',(x,.14,.07),(.47,.77,.13),'dark_steel',.075)
  ball('mech boot',(x,.17,.24),(.26,.39,.23),'gold')
  box('toe armor',(x,.44,.22),(.45,.22,.23),'light_gold',.055)
  limb('shin armor',(x,0,.29),(x,-.045,.89),(.23,.23),'gold')
  box('shin face',(x,.19,.59),(.29,.095,.41),'light_gold',.056)
  ball('knee joint',(x,0,.95),(.22,.23,.2),'dark_steel')
  ball('knee shield',(x,.22,.96),(.21,.10,.23),'gold')
  limb('thigh armor',(x,-.04,1.04),(side*.29,-.01,1.51),(.25,.25),'blue')
  ball('thigh facing',(x,.205,1.24),(.2,.12,.27),'gold')
 ball('mech pelvis',(0,0,1.47),(.51,.31,.27),'dark_steel')
 box('codpiece',(0,.31,1.48),(.37,.15,.37),'gold',.1)
 for side in [-1,1]:
  box('hip fauld',(side*.4,.16,1.52),(.34,.30,.37),'gold',.068)
 # Three-layer chest reads as a sculpted armored body.
 ball('mech torso',(0,0,2.03),(.60,.34,.64),'gold')
 for side in [-1,1]:ball('breastplate',(side*.285,.232,2.27),(.345,.17,.29),'light_gold')
 for i in range(3):box('abdomen layered plate',(0,.3,1.77+i*.13),(.46+i*.035,.12,.15),'gold',.045)
 ball('chest reactor socket',(0,.383,2.245),(.135,.05,.135),'dark_steel')
 ball('chest cyan reactor',(0,.425,2.245),(.096,.027,.095),'cyan')
 for side in [-1,1]:
  ball('shoulder joint',(side*.59,0,2.33),(.24,.27,.24),'dark_steel')
  ball('huge shoulder armor',(side*.68,0,2.42),(.33,.34,.29),'gold')
  box('shoulder upper rim',(side*.70,0,2.60),(.55,.52,.13),'light_gold',.07)
  limb('mech bicep',(side*.72,.025,2.31),(side*.79,.10,1.96),(.23,.23),'blue')
  ball('elbow',(side*.78,.10,1.96),(.23,.23,.20),'dark_steel')
  limb('mech forearm',(side*.77,.16,1.93),(side*.64,.34,1.68),(.26,.255),'gold')
  box('forearm plate',(side*.77,.325,1.92),(.32,.16,.38),'light_gold',.055)
  ball('mech armored fist',(side*.64,.36,1.65),(.22,.225,.20),'dark_steel')
  for k in range(4):ball('mech knuckle',(side*.64+(k-1.5)*.079,.546,1.68),(.048,.037,.064),'gold',10,6)
  # Rockets sit behind shoulders, with cyan outer housings and gold noses.
  cyl('shoulder missile tube',(side*.47,-.24,2.51),(side*.47,-.24,3.06),.187,'blue')
  cyl('tube metal ring',(side*.47,-.24,2.98),(side*.47,-.24,3.075),.205,'steel')
  cyl('gold rocket nose',(side*.47,-.24,3.03),(side*.47,-.24,3.39),.15,'gold',r2=.0,vertices=16)
  for sx in [-1,1]:box('rocket tail fin',(side*.47+sx*.165,-.24,2.67),(.06,.27,.28),'dark_steel',.01)
 box('mech back reactor',(0,-.33,2.26),(.63,.20,.57),'blue',.075)
 for i in range(4):box('rear vent',(0,-.445,2.10+i*.09),(.41,.025,.025),'dark_steel',.007)
 cyl('neck',(0,0,2.48),(0,0,2.72),.16,'dark_steel')
 ball('mech helmet',(0,.013,2.875),(.27,.23,.33),'gold')
 box('helmet crest',(0,-.02,3.119),(.15,.29,.085),'light_gold',.025)
 for side in [-1,1]:
  ball('helmet cheek',(side*.195,.127,2.79),(.089,.13,.16),'light_gold')
  brow=box('helmet brow',(side*.103,.206,2.986),(.215,.075,.065),'dark_steel',.02);brow.rotation_euler[1]=side*.16
  box('mech eye',(side*.103,.249,2.947),(.14,.011,.027),'cyan',.008)
 box('angular faceplate',(0,.236,2.828),(.22,.10,.24),'steel',.042)
 for i in [-1,0,1]:box('helmet mouth grille',(i*.05,.291,2.781),(.015,.011,.088),'black',.003)
def brute():
 for side in [-1,1]:
  x=side*.34
  boot('brute boot',x,0,0,2.6)
  limb('brute calf',(x,0,.37),(x,-.03,.91),(.245,.26),'red')
  limb('brute thigh',(x,-.035,.93),(side*.29,-.025,1.46),(.36,.30),'red')
  box('boot buckle',(x,.214,.34),(.15,.035,.12),'steel',.017)
 ball('brute trouser seat',(0,-.015,1.36),(.56,.36,.33),'red')
 box('brute waist belt',(0,.005,1.49),(.99,.58,.15),'black',.045)
 box('brute buckle',(0,.313,1.47),(.26,.04,.20),'steel',.025)
 ball('brute broad torso',(0,0,2.10),(.65,.365,.68),'pink')
 ball('brute round belly',(0,.225,1.91),(.49,.24,.44),'pink_light')
 # Muscular pectoral lobes, traps and back ridges.
 for side in [-1,1]:
  ball('brute pectoral',(side*.30,.236,2.30),(.39,.24,.32),'pink_light')
  ball('brute back muscle',(side*.30,-.19,2.28),(.39,.25,.42),'pink')
  limb('trapezius',(side*.12,0,2.63),(side*.54,0,2.51),(.23,.24),'pink')
  ball('brute shoulder',(side*.69,0,2.48),(.39,.39,.42),'pink_light')
  limb('brute bicep',(side*.78,.015,2.45),(side*.91,.11,2.06),(.34,.33),'pink')
  ball('bicep front',(side*.85,.20,2.24),(.25,.22,.29),'pink_light')
  limb('brute forearm',(side*.94,.10,2.03),(side*.89,.285,1.70),(.29,.27),'pink')
  limb('black arm bracer',(side*.935,.18,1.92),(side*.895,.267,1.67),(.305,.29),'black')
  for zz in [1.74,1.89]:
   for k in [-1,0,1]:ball('bracer steel rivet',(side*.92+k*.14,.50,zz),(.047,.035,.047),'steel',10,6)
  ball('brute clenched fist',(side*.89,.32,1.58),(.275,.277,.26),'pink')
  for k in range(4):ball('brute knuckle',(side*.89+(k-1.5)*.107,.548,1.61),(.068,.050,.08),'pink_light',10,6)
 # Original ragged sleeveless vest consists of sculpted side panels.
 for side in [-1,1]:
  vest=ball('dark red vest side',(side*.53,-.08,2.02),(.18,.345,.56),'red');vest.rotation_euler[1]=side*.12
  box('vest seam',(side*.445,.255,2.03),(.045,.03,.56),'red_light',.015)
  for zz in [1.80,2.12,2.42]:ball('vest stud',(side*.452,.282,zz),(.038,.018,.038),'steel',10,6)
 cyl('brute thick neck',(0,0,2.52),(0,0,2.87),.24,'pink')
 face('brute',0,.015,3.03,2.18,'pink_light',angry=True)
 # Bald scalp veins and asymmetric ear ring, with a broad forehead.
 for side in [-1,1]:
  ball('brute heavy cheek',(side*.16,.227,2.96),(.116,.055,.083),'pink')
  brow=box('brute heavy brow',(side*.10,.215,3.124),(.18,.05,.07),'pink',.015);brow.rotation_euler[1]=side*.22
 torus('brute ear ring',(-.286,.011,2.94),.051,.012,'gold',rot=(math.pi/2,0,0))
def brute_vest():
 brute()
 # First encounter: tan-skinned giant in an open scarlet leather vest.
 for o in parts:
  role=o.data.materials[0].name
  if role=='pink':o.data.materials[0]=M['boss_skin']
  if role=='pink_light':o.data.materials[0]=M['boss_skin_light']
  if o.name.startswith(('brute back muscle','brute broad torso')):o.data.materials[0]=M['red']
  if o.name.startswith('brute pectoral'):o.scale*=.9
 # Broad back panel is visible when the giant turns.
 ball('scarlet leather back',(0,-.255,2.07),(.59,.16,.57),'red')
 for side in [-1,1]:
  coords=[(.14,1.57),(.56,1.57),(.66,2.38),(.47,2.65),(.19,2.57),(.235,2.20)]
  verts=[(side*x,y,z) for y in [.245,.45] for x,z in coords]
  n=len(coords);faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
  for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
  me=bpy.data.meshes.new('leather vest panel');me.from_pydata(verts,[],faces);me.update()
  ob=bpy.data.objects.new('scarlet vest front',me);bpy.context.collection.objects.link(ob);add(ob,'scarlet vest front','red')
  bpy.context.view_layer.objects.active=ob
  mod=ob.modifiers.new('rounded leather edge','BEVEL');mod.width=.045;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  # Rolled inner lapel, stitching, metallic studs and side pockets.
  lapel=box('vest rolled lapel',(side*.245,.469,2.28),(.095,.07,.61),'red_light',.026);lapel.rotation_euler[1]=-side*.15
  box('vest pocket',(side*.42,.47,1.86),(.22,.04,.19),'red_light',.022)
  for zz in [1.68,1.92,2.17,2.44]:ball('vest silver stud',(side*.225,.505,zz),(.026,.013,.026),'silver',10,6)
  # Reference-inspired heavy black gauntlets, with silver cuffs and studs.
  ball('leather gauntlet hand',(side*.89,.35,1.59),(.29,.275,.28),'black')
  for k in range(4):ball('gauntlet knuckle',(side*.89+(k-1.5)*.11,.59,1.64),(.070,.035,.068),'dark_steel',10,6)
 # Low dark hairline and rough angular tufts preserve the first-boss silhouette.
 ball('cropped dark hair',(0,-.01,3.217),(.29,.23,.115),'black')
 for x in [-.22,-.11,0,.11,.22]:
  t=box('short hair tuft',(x,.201,3.17-abs(x)*.15),(.095,.08,.11),'black',.025);t.rotation_euler[1]=x*.9

def zombie():
 # Crowd reads first as a continuous field of rounded crimson caps, then pale faces.
 for side in [-1,1]:
  x=side*.065
  ball('simple crowd boot',(x,.027,.048),(.052,.080,.047),'black',10,6)
  limb('crowd trouser',(x,0,.095),(side*.058,0,.279),(.051,.049),'crowd_cloth')
 ball('rounded crowd jacket',(0,0,.357),(.126,.089,.142),'crowd_cloth',12,8)
 box('crowd narrow belt',(0,.002,.278),(.218,.149,.025),'red',.005)
 for side in [-1,1]:
  ball('rounded red shoulder',(side*.112,.006,.418),(.061,.068,.066),'crowd_cloth',12,8)
  limb('crowd short sleeve',(side*.115,.015,.414),(side*.136,.081,.351),(.045,.049),'crowd_cloth')
  limb('crowd reaching forearm',(side*.134,.085,.351),(side*.102,.166,.372),(.034,.034),'crowd_skin')
  ball('crowd hand',(side*.102,.172,.372),(.036,.047,.032),'crowd_skin',10,6)
 ball('pale crowd head',(0,.015,.534),(.109,.09,.106),'crowd_skin',12,8)
 ball('pale crowd chin',(0,.041,.491),(.081,.072,.060),'crowd_skin',12,8)
 for side in [-1,1]:
  ball('crowd ear',(side*.109,.022,.526),(.020,.021,.031),'crowd_skin',10,6)
  ball('small crowd eye',(side*.037,.104,.545),(.011,.005,.010),'black',8,6)
 ball('small crowd nose',(0,.109,.519),(.021,.021,.027),'crowd_skin',10,6)
 box('crowd mouth',(0,.105,.484),(.035,.007,.008),'red',.002)
 # A wide, smooth domed cap dominates the overhead view and hides fine face noise.
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,location=(0,-.001,.614))
 cap=add(bpy.context.object,'broad rounded crimson cap','crowd_cap');cap.scale=(.147,.134,.091)
 cyl('crimson helmet rim',(0,-.001,.582),(0,-.001,.604),.137,'crowd_cap_rim',vertices=20)
 ball('rounded cap peak',(0,.092,.59),(.123,.085,.018),'crowd_cap',12,6)

def export(name,height,build,statue=False):
 global parts,CROWD
 CROWD=name in ['infantry','zombie']
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);parts=[]
 build()
 if statue:
  for o in parts:
   old=o.data.materials[0].name
   o.data.materials[0]=M['dark_steel' if old=='black' else 'silver']
 # Join each character to one object while retaining a small fixed material palette.
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
 obj=parts[0];obj.name=name
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 vs=[obj.matrix_world@v.co for v in obj.data.vertices]
 lo=Vector([min(v[i] for v in vs) for i in range(3)]);hi=Vector([max(v[i] for v in vs) for i in range(3)])
 scale=height/(hi.z-lo.z)
 # Bake uniform final size and centered foot origin into mesh.
 inv=obj.matrix_world.inverted()
 for v in obj.data.vertices:
  w=obj.matrix_world@v.co;w.x*=scale;w.y*=scale;w.z=(w.z-lo.z)*scale;v.co=w
 obj.location=(0,0,0);obj.rotation_euler=(0,0,0);obj.rotation_mode='XYZ';obj.scale=(1,1,1)
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 if CROWD:
  # Collapse crowd models to a single colored surface for efficient MultiMesh batching.
  dec=obj.modifiers.new('crowd reduction','DECIMATE');dec.ratio=.66
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=dec.name)
  colors=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
  for poly in obj.data.polygons:
   c=obj.data.materials[poly.material_index].diffuse_color
   for li in poly.loop_indices:colors.data[li].color=c
  crowd=bpy.data.materials.new(name+'_vertex_palette');crowd.use_nodes=True
  bs=crowd.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.43;bs.inputs['Metallic'].default_value=.1
  vc=crowd.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';crowd.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
  obj.data.materials.clear();obj.data.materials.append(crowd)
  for poly in obj.data.polygons:poly.material_index=0
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_animations=False)
 triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
 bounds=[list(v) for v in [lo*scale,hi*scale]]
 info={'name':name,'height_m':height,'triangles':triangles,'materials':len(obj.data.materials),'facing_godot':'-Z','origin':'feet'}
 print('ASSET',json.dumps(info));return info
all_models=[('infantry',1.0,infantry),('gunner',1.8,gunner),('mech',3.4,mech),('brute',3.4,brute),('brute_vest',3.4,brute_vest),('zombie',.65,zombie),('gunner_silver',1.8,gunner,True)]
cli=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
only=cli[cli.index('--only')+1] if '--only' in cli else None
existing=json.loads((OUT/'manifest.json').read_text())['models'] if only and (OUT/'manifest.json').exists() else []
model_map={m['name']:m for m in existing}
for args in all_models:
 if only and args[0]!=only:continue
 model_map[args[0]]=export(*args)
models=[model_map[args[0]] for args in all_models if args[0] in model_map]
(OUT/'manifest.json').write_text(json.dumps({'authoring':'Original geometric character sculptures authored for Gate Siege; no external textures or model dependencies.','models':models},indent=2)+'\n')
