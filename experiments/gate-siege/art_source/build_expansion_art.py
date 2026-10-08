"""Original articulated fantasy creatures and improved hero costumes for Gate Siege."""
import bpy, math, json, sys, struct, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/expansion'; OUT.mkdir(exist_ok=True)
source=Path(__file__).with_name('build_characters.py'); ns={'__file__':str(source)}
exec(compile(source.read_text().split('all_models=')[0],str(source),'exec'),ns)
ball,box,cyl,limb= [ns[k] for k in ['ball','box','cyl','limb']]
M=ns['M']
for name,color,metal,rough in [('emerald',(.045,.39,.28),.25,.38),('jade',(.20,.72,.44),.2,.35),('membrane',(.32,.69,.29),.08,.52),('membrane_amber',(.67,.69,.22),.08,.52),('bone',(.97,.81,.42),.3,.4),('violet',(.31,.15,.43),.35,.4),('iron',(.23,.31,.47),.65,.34),('plate_light',(.46,.58,.68),.6,.31),('brass',(.78,.46,.14),.65,.34),('carapace',(.07,.32,.28),.32,.4),('carapace_light',(.18,.51,.41),.3,.4)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=tuple((c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4) for c in color)+(1,)
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough;M[name]=m

def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);ns['parts']=[];ns['CROWD']=False

def merged(name,objects,pivot=(0,0,0),budget=6000,style="default"):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=objects[0];o.name=name
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 for v in o.data.vertices:v.co=o.matrix_world@v.co-Vector(pivot)
 o.location=pivot;o.rotation_mode='XYZ';o.rotation_euler=(0,0,0);o.scale=(1,1,1)
 tri=sum(len(p.vertices)-2 for p in o.data.polygons)
 if tri>budget:
  dec=o.modifiers.new('bounded silhouette geometry','DECIMATE');dec.ratio=budget/tri;bpy.ops.object.modifier_apply(modifier=dec.name)
 c=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 for p in o.data.polygons:
  color=o.data.materials[p.material_index].diffuse_color
  color=tuple(12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in color[:3])+(1,)
  for li in p.loop_indices:c.data[li].color=color
 o.data.materials.clear();palette='ExpansionPalette' if style=='default' else 'HeroPalette_'+style;mat=bpy.data.materials.get(palette)
 if not mat:
  mat=bpy.data.materials.new(palette);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=0.0 if style=='cloth' else (.38 if style=='hardware' else .22);bs.inputs['Roughness'].default_value=.70 if style=='cloth' else (.40 if style=='hardware' else .39)
  vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
 o.data.materials.append(mat)
 for p in o.data.polygons:p.material_index=0
 return o

def export(name,groups,target_bounds=None):
 objects=[]
 for group in groups:
  g,parts,pivot,budget=group[:4];style=group[4] if len(group)>4 else 'default'
  objects.append(merged(g,parts,pivot,budget,style))
 if target_bounds:
  current_min=[min(v.co[k] for o in objects for v in o.data.vertices) for k in range(3)]
  current_max=[max(v.co[k] for o in objects for v in o.data.vertices) for k in range(3)]
  target_min,target_max=target_bounds
  for o in objects:
   for v in o.data.vertices:
    for k in range(3):v.co[k]=target_min[k]+(v.co[k]-current_min[k])/(current_max[k]-current_min[k])*(target_max[k]-target_min[k])
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_animations=False)
 return {'name':name,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects),'surfaces':len(objects)}

def chunk(fn):
 start=len(ns['parts']);fn();return ns['parts'][start:]

def plate(name, center, size, mat, cut=.17, bevel=.025):
 """An octagonal extruded armor plate, not a rounded cube."""
 x,y,z=center;w,d,h=size;wx=w/2;hz=h/2;c=min(w,h)*cut
 outline=[(-wx+c,-hz),(wx-c,-hz),(wx,-hz+c),(wx,hz-c),(wx-c,hz),(-wx+c,hz),(-wx,hz-c),(-wx,-hz+c)]
 verts=[(a,side*d/2,b) for side in [-1,1] for a,b in outline]
 faces=[tuple(range(8)),tuple(range(15,7,-1))]+[(i,i+8,(i+1)%8+8,(i+1)%8) for i in range(8)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 ob=bpy.data.objects.new(name,mesh);ob.location=center;bpy.context.collection.objects.link(ob);ns['add'](ob,name,mat)
 for polygon in mesh.polygons:polygon.use_smooth=False
 if bevel:
  mod=ob.modifiers.new('small armor edge bevel','BEVEL');mod.width=bevel;mod.segments=1
  bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
 return ob

def jewel(name,loc,size,mat):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc)
 ob=ns['add'](bpy.context.object,name,mat);ob.scale=size
 for polygon in ob.data.polygons:polygon.use_smooth=False
 return ob

def rivet(name,loc,r=.036,mat='silver'):
 x,y,z=loc;cyl(name,(x,y-.022,z),(x,y+.028,z),r,mat,vertices=8)

def tube_chain(name,points,r,mat):
 for i in range(len(points)-1):cyl(name+str(i),points[i],points[i+1],r,mat,vertices=8)

def asset_report(name):
 path=OUT/(name+'.glb');data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length])
 lower=[float('inf')]*3;upper=[-float('inf')]*3
 for node in doc['nodes']:
  if 'mesh' not in node:continue
  t=node.get('translation',[0,0,0])
  for primitive in doc['meshes'][node['mesh']]['primitives']:
   accessor=doc['accessors'][primitive['attributes']['POSITION']]
   for k in range(3):lower[k]=min(lower[k],accessor['min'][k]+t[k]);upper[k]=max(upper[k],accessor['max'][k]+t[k])
 return {'name':name,'triangles':sum(doc['accessors'][pr['indices']]['count']//3 for mesh in doc['meshes'] for pr in mesh['primitives']),'surfaces':sum(len(mesh['primitives']) for mesh in doc['meshes']),'sha256':hashlib.sha256(data).hexdigest(),'bounds_godot':{'min':lower,'max':upper},'bytes':len(data)}

reports=[]
creatures_only='--creatures-only' in sys.argv
heroes_only='--heroes-only' in sys.argv
hero_bounds={}
for kind,height,budget in ([] if creatures_only else [('infantry',1,3800),('gunner',1.8,7400),('mech',3.4,7900)]):
 previous=asset_report(kind)['bounds_godot'];hero_bounds[kind]=previous
 target_bounds=([previous['min'][0],-previous['max'][2],previous['min'][1]],[previous['max'][0],-previous['min'][2],previous['max'][1]])
 clear();ns[kind]()
 if kind=='infantry':
  for side in [-1,1]:
   plate('infantry blue vest back',(side*.048,-.159,.566),(.085,.040,.172),'blue',.13,.008)
   box('vest black vertical seam',(side*.017,-.183,.56),(.011,.013,.157),'navy',.003)
  plate('back vest lower belt',(0,-.14,.443),(.17,.04,.05),'dark_steel',.13,.005)
 if kind=='gunner':
  # Cloth sleeves replace bare, reflective sphere shoulders.
  for o in ns['parts']:
   if 'shoulder' in o.name:
    o.data.materials[0]=M['blue'];o.scale.x*=.87;o.scale.y*=.88
   elif 'upper arm' in o.name:o.data.materials[0]=M['blue']
  for side in [-1,1]:
   plate('blue coat upper back',(side*.165,-.372,1.245),(.32,.145,.49),'blue',.13,.035)
   plate('angular blue shoulder epaulet',(side*.40,-.015,1.44),(.29,.39,.125),'blue_light',.18,.025)
   box('epaulet dark seam',(side*.40,-.22,1.44),(.21,.025,.036),'navy',.006)
   cyl('cloth sleeve cuff',(side*.465,.065,1.015),(side*.465,.065,1.105),.161,'navy',vertices=14)
   flap=plate('split blue coat tail',(side*.19,-.252,.84),(.30,.14,.33),'blue',.16,.025);flap.rotation_euler.y=side*.11
   plate('rear canvas belt pouch',(side*.29,-.32,.82),(.18,.115,.16),'tan',.13,.015)
   rivet('pouch clasp',(side*.29,-.395,.82),.018,'brass')
  plate('rear dark angular hardware panel',(0,-.444,1.195),(.275,.115,.30),'dark_steel',.18,.018)
  plate('back panel inset',(0,-.507,1.19),(.18,.035,.21),'navy',.16,.01)
  for z in [1.13,1.20,1.27]:box('back panel silver cooling slit',(0,-.529,z),(.14,.02,.025),'steel',.004)
  strap=box('diagonal black rear ammunition harness',(0,-.51,1.21),(.13,.057,.85),'navy',.015);strap.rotation_euler.y=math.atan2(.62,-.57)
  for i in range(13):
   t=i/12;x=-.31+.62*t;z=1.49-.57*t
   cyl('individual rear brass cartridge',(x,-.562,z-.058),(x,-.562,z+.058),.028,'brass',vertices=8)
   cyl('rear pointed cartridge',(x,-.562,z+.058),(x,-.562,z+.088),.028,'light_gold',r2=.003,vertices=8)
   box('dark ammunition link',(x,-.536,z-.012),(.049,.020,.031),'dark_steel',.003)
  plate('segmented rear waist belt',(0,-.315,.775),(.61,.12,.10),'black',.11,.015)
  for side in [-1,1]:plate('waist belt metal segment',(side*.21,-.38,.775),(.12,.025,.075),'brass',.12,.009)
 if kind=='mech':
  # Blue armor shell, gold trim and deep joints give each overlapping layer contrast.
  for o in ns['parts']:
   if any(token in o.name for token in ['mech torso','breastplate','huge shoulder armor','shoulder upper rim','forearm plate','shin face','thigh facing']):
    o.data.materials[0]=M['blue_light'] if ('rim' in o.name or 'breastplate' in o.name) else M['blue']
  plate('angular rear armor foundation',(0,-.46,2.03),(.88,.23,.99),'dark_steel',.23,.035)
  for side in [-1,1]:
   plate('rear blue armor wing',(side*.32,-.595,2.22),(.48,.16,.64),'blue',.21,.028)
   for z in [1.59,1.76,1.93]:plate('overlapping rear armor lame',(side*.25,-.56,z),(.40,.145,.19),'steel' if z==1.59 else 'blue_light',.19,.023)
   plate('rear shoulder guard',(side*.72,-.20,2.50),(.49,.25,.26),'blue',.18,.028)
   box('shoulder warning stripe',(side*.72,-.341,2.50),(.30,.025,.050),'gold',.006)
   for z in [2.07,2.23,2.39]:box('shoulder exhaust black louver',(side*.43,-.69,z),(.16,.05,.042),'black',.005)
   for z in [1.40,1.55,1.70]:box('rear thigh vent',(side*.40,-.35,z),(.24,.12,.052),'dark_steel',.012)
   cyl('missile rear reinforcing tube',(side*.47,-.445,2.65),(side*.47,-.445,3.01),.060,'steel',vertices=10)
   for z in [2.74,2.90]:box('missile tube colored band',(side*.47,-.447,z),(.31,.035,.051),'blue_light',.006)
  plate('cockpit rear recess',(0,-.697,2.21),(.36,.09,.55),'black',.23,.016)
  plate('cockpit blue window',(0,-.750,2.25),(.25,.035,.38),'cyan',.24,.012)
  box('cockpit center mullion',(0,-.78,2.25),(.027,.025,.38),'steel',.005)
  plate('reactor lower octagon',(0,-.68,1.80),(.30,.13,.29),'gold',.26,.012)
  plate('reactor luminous core',(0,-.758,1.80),(.16,.026,.15),'cyan',.26,.008)
  for side in [-1,1]:
   for z in [1.92,2.48]:rivet('rear armor screw',(side*.31,-.69,z),.029,'light_gold')
 lo=min((o.matrix_world@v.co).z for o in ns['parts'] for v in o.data.vertices);hi=max((o.matrix_world@v.co).z for o in ns['parts'] for v in o.data.vertices);sc=height/(hi-lo)
 for o in ns['parts']:
  for v in o.data.vertices:
   w=o.matrix_world@v.co;v.co=(w.x*sc,w.y*sc,(w.z-lo)*sc)
  o.location=(0,0,0);o.rotation_mode='XYZ';o.rotation_euler=(0,0,0);o.scale=(1,1,1)
 hardware_names={'steel','dark_steel','silver','gold','light_gold','cyan','brass'}
 hardware=[];cloth=[]
 for o in ns['parts']:
  metal=o.data.materials[0].name in hardware_names or any(token in o.name for token in ['helmet','cap band','cap badge','visor','rifle'])
  if kind=='mech':metal=o.data.materials[0].name not in {'black','navy','skin','skin_light'}
  (hardware if metal else cloth).append(o)
 cloth_budget={'infantry':2300,'gunner':3300,'mech':1700}[kind]
 hardware_budget=budget-cloth_budget
 reports.append(export(kind,[('HeroCloth',cloth,(0,0,0),cloth_budget,'cloth'),('HeroHardware',hardware,(0,0,0),hardware_budget,'hardware')],target_bounds))

if not heroes_only:
 clear();groups=[]
 def dragon_body():
  # The shoulder mass and segmented belly support a long angular head/neck.
  ball('deep dragon rib cage',(0,-.06,1.65),(.70,1.03,.68),'emerald',20,12)
  ball('dragon haunch',(0,-.56,1.44),(.61,.58,.53),'carapace',16,10)
  for i in range(6):
   y=-.57+i*.24;z=1.20+.035*i
   plate('overlapping ventral scale',(0,y,z),(.76+.045*i,.31,.19),'bone',.18,.018)
  limb('sweeping neck base',(0,.52,1.77),(0,1.00,2.25),(.42,.43),'emerald')
  limb('dragon neck upper',(0,.93,2.20),(0,1.34,2.58),(.31,.35),'jade')
  for i in range(4):
   plate('neck throat segment',(0,1.13+i*.10,2.0+i*.14),(.50-i*.025,.15,.17),'bone',.16,.015)
  jewel('angular heavy skull',(0,1.46,2.69),(.52,.63,.42),'emerald')
  plate('broad tapered snout',(0,1.94,2.51),(.81,.75,.31),'jade',.23,.045)
  plate('lower ivory jaw',(0,1.99,2.29),(.68,.64,.16),'bone',.22,.018)
  plate('deep mouth opening',(0,2.025,2.37),(.69,.65,.065),'black',.18,.008)
  plate('forehead arrow plate',(0,1.74,2.89),(.45,.39,.22),'carapace',.25,.02)
  for side in [-1,1]:
   jewel('cheek armor',(side*.40,1.43,2.55),(.25,.36,.26),'carapace_light')
   ball('deep eye socket',(side*.395,1.69,2.74),(.14,.19,.11),'black',12,6)
   ball('amber slit eye',(side*.407,1.77,2.75),(.102,.116,.066),'eye',12,6)
   plate('scowling brow ridge',(side*.405,1.76,2.855),(.26,.34,.11),'emerald',.15,.01)
   ball('dark nostril',(side*.235,2.315,2.585),(.065,.033,.04),'black',10,6)
   cyl('swept crown horn base',(side*.35,1.16,2.90),(side*.58,.69,3.26),.17,'carapace',r2=.11,vertices=12)
   cyl('swept crown horn ivory tip',(side*.58,.69,3.26),(side*.72,.31,3.42),.115,'bone',r2=.007,vertices=12)
   for k in range(4):
    x=side*(.10+k*.073)
    cyl('upper ivory fang',(x,2.21,2.43),(x,2.24,2.25),.042,'ivory',r2=.003,vertices=8)
   for k in range(3):
    cyl('side cheek spike',(side*(.44+k*.045),1.36-k*.22,2.62-k*.025),(side*(.76+k*.055),1.14-k*.24,2.70-k*.055),.10,'bone',r2=.004,vertices=8)
   limb('rear muscular thigh',(side*.44,-.51,1.31),(side*.75,-.20,.75),(.25,.27),'emerald')
   jewel('rear knee plate',(side*.75,-.11,.75),(.24,.25,.20),'jade')
   limb('rear scaled shin',(side*.74,-.17,.77),(side*.59,.20,.40),(.14,.17),'carapace_light')
   ball('rear claw palm',(side*.59,.26,.39),(.22,.27,.11),'emerald',12,8)
   limb('front shoulder',(side*.50,.48,1.94),(side*.70,.80,1.54),(.20,.21),'jade')
   limb('front reaching wrist',(side*.70,.80,1.54),(side*.62,1.20,1.35),(.12,.15),'emerald')
   for k in range(3):
    dx=(k-1)*.12
    cyl('hind curved claw',(side*.59+dx,.30,.40),(side*.59+dx,.65,.30),.066,'ivory',r2=.004,vertices=8)
    cyl('front talon',(side*.62+dx,1.19,1.35),(side*.62+dx,1.45,1.20),.05,'bone',r2=.003,vertices=8)
   for row in range(3):
    for column in range(3):
     y=.35-row*.34;z=1.79+column*.13
     jewel('flank overlapping scale',(side*(.61-column*.07),y,z),(.115,.20,.10),'jade' if (row+column)%2 else 'carapace_light')
  for i in range(7):
   y=.94-i*.35;z=2.38 if i<3 else 2.18-(i-3)*.08
   cyl('armored dorsal crest',(0,y,z),(0,y-.17,z+.42-i*.018),.13,'bone',r2=.004,vertices=10)
 groups.append(('Body',chunk(dragon_body),(0,0,0),5300))
 for side in [-1,1]:
  def wing():
   # Wide scalloped chord remains visible when pitched toward the game camera.
   root=(side*.52,.22,1.97);elbow=(side*1.43,.81,2.65)
   points=[root,elbow,(side*3.50,.38,2.82),(side*3.05,-1.48,1.73),(side*2.56,-1.12,1.88),(side*2.10,-2.08,1.30),(side*1.67,-1.29,1.70),(side*1.05,-1.85,1.37),(side*.52,-.62,1.70)]
   hub=(side*1.20,-.25,2.12)
   for j in range(len(points)):
    tri=[hub,points[j],points[(j+1)%len(points)]]
    mesh=bpy.data.meshes.new('broad scalloped wing panel');mesh.from_pydata(tri,[],[(0,1,2)]);mesh.update()
    ob=bpy.data.objects.new('wing membrane panel',mesh);bpy.context.collection.objects.link(ob)
    ns['add'](ob,'wing membrane panel','membrane_amber' if j in [1,4,6] else 'membrane')
    sol=ob.modifiers.new('two sided membrane thickness','SOLIDIFY');sol.thickness=.025
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=sol.name)
   cyl('muscular leading humerus',root,elbow,.16,'emerald',r2=.12,vertices=12)
   cyl('swept leading spar',elbow,points[2],.105,'jade',r2=.035,vertices=12)
   ball('wing elbow knuckle',elbow,(.17,.17,.17),'bone',12,6)
   for j in [3,5,7,8]:cyl('radiating wing finger',elbow,points[j],.073,'jade',r2=.022,vertices=10)
   for j in [2,3,5,7]:
    a=points[j];cyl('ivory wing tip',a,(a[0]+side*.18,a[1]-.13,a[2]-.17),.058,'bone',r2=.002,vertices=8)
   for j in [3,5,7]:
    a=Vector(elbow).lerp(Vector(points[j]),.30);b=Vector(elbow).lerp(Vector(points[j]),.72)
    cyl('amber membrane vein',a,b,.024,'membrane_amber',r2=.013,vertices=6)
  groups.append(('WingL' if side<0 else 'WingR',chunk(wing),(side*.52,.22,1.97),1450))
 def tail():
  nodes=[(0,-.73,1.49),(0,-1.38,1.25),(.17,-2.05,.98),(.37,-2.73,.84),(.63,-3.23,1.02)]
  radii=[.31,.25,.16,.08]
  for i in range(4):cyl('tapered tail segment',nodes[i],nodes[i+1],radii[i],'emerald' if i%2==0 else 'carapace_light',r2=radii[i]*.62,vertices=12)
  for i in range(5):
   y=-1.08-i*.38;x=max(0,(i-1)*.12);z=1.58-i*.14
   cyl('tail dorsal sail',(x,y,z),(x,y-.12,z+.28),.09,'bone',r2=.003,vertices=8)
  jewel('tail spear',( .64,-3.27,1.03),(.18,.33,.11),'bone')
 groups.append(('Tail',chunk(tail),(0,-.73,1.49),1000))
 reports.append(export('dragon',groups))
 
 clear();groups=[]
 def golem_body():
  plate('tapered iron chest foundation',(0,0,1.75),(1.53,.80,1.46),'dark_steel',.24,.055)
  plate('outer chest armor',(0,.31,1.86),(1.48,.29,1.05),'iron',.22,.045)
  for side in [-1,1]:
   p=plate('angled pectoral shield',(side*.40,.50,2.12),(.66,.22,.42),'plate_light',.24,.03);p.rotation_euler.y=side*.10
   plate('lower rib armor',(side*.49,.43,1.59),(.48,.17,.35),'iron',.23,.025)
   for z in [1.68,1.83,1.98]:box('rib vent',(side*.66,.38,z),(.14,.12,.042),'black',.004)
   cyl('shoulder rotary socket',(side*.60,0,2.18),(side*.95,0,2.18),.28,'dark_steel',vertices=12)
   plate('bastion shoulder plate',(side*.91,.05,2.25),(.68,.95,.46),'iron',.22,.045)
   plate('shoulder raised brow',(side*.92,.38,2.36),(.62,.18,.23),'brass',.21,.025)
   for x in [-.19,.19]:rivet('shoulder rivet',(side*.92+x,.49,2.31),.035)
   tube_chain('rib hydraulic pipe',[(side*.61,-.14,1.30),(side*.82,-.33,1.48),(side*.78,-.34,1.92)],.055,'brass')
  plate('reactor outer octagon',(0,.52,1.87),(.58,.16,.65),'brass',.25,.025)
  plate('reactor dark recess',(0,.62,1.87),(.43,.12,.49),'black',.24,.015)
  plate('reactor glass heart',(0,.692,1.87),(.31,.055,.35),'cyan',.25,.013)
  for side in [-1,1]:
   for z in [1.67,2.07]:rivet('reactor bezel screw',(side*.225,.70,z),.034,'light_gold')
  for i in range(3):plate('articulated abdominal lame',(0,.36,1.21+i*.16),(.67+i*.10,.23,.19),'plate_light' if i==2 else 'iron',.16,.025)
  cyl('dark neck joint',(0,0,2.33),(0,0,2.51),.25,'black',vertices=12)
  plate('faceted armored helmet',(0,.02,2.65),(.70,.65,.67),'iron',.24,.05)
  plate('helmet brow',(0,.35,2.78),(.68,.20,.19),'plate_light',.22,.025)
  plate('visor recess',(0,.37,2.62),(.56,.09,.16),'black',.12,.008)
  box('narrow glowing visor',(0,.429,2.64),(.46,.027,.052),'eye',.009)
  plate('sloped jaw armor',(0,.31,2.43),(.48,.23,.21),'brass',.23,.025)
  for x in [-.12,0,.12]:box('jaw breathing grille',(x,.445,2.46),(.04,.023,.12),'dark_steel',.003)
  plate('back boiler housing',(0,-.51,1.87),(.95,.32,.90),'iron',.2,.04)
  for side in [-1,1]:
   cyl('back exhaust stack',(side*.30,-.54,2.1),(side*.30,-.54,2.60),.11,'brass',vertices=10)
   cyl('exhaust dark mouth',(side*.30,-.54,2.59),(side*.30,-.54,2.62),.078,'black',vertices=10)
  plate('pelvis hinge armor',(0,.07,1.02),(.98,.68,.35),'dark_steel',.20,.03)
  for side in [-1,1]:plate('hip overlapping fauld',(side*.39,.27,1.09),(.42,.35,.37),'brass',.22,.025)
 groups.append(('Body',chunk(golem_body),(0,0,0),3400))
 for side in [-1,1]:
  def arm():
   cyl('upper arm actuator',(side*.87,0,2.08),(side*1.06,.02,1.57),.17,'dark_steel',vertices=12)
   plate('bicep armor',(side*.98,.17,1.83),(.47,.39,.49),'plate_light',.22,.03)
   cyl('elbow rotary hinge',(side*.89,.05,1.52),(side*1.20,.05,1.52),.20,'brass',vertices=12)
   cyl('elbow pin',(side*.87,.05,1.52),(side*1.22,.05,1.52),.087,'silver',vertices=10)
   plate('bracer dark foundation',(side*1.11,.15,1.27),(.62,.58,.68),'dark_steel',.22,.04)
   plate('faceted forearm guard',(side*1.11,.41,1.33),(.63,.23,.67),'iron',.22,.035)
   plate('bracer inset',(side*1.11,.55,1.37),(.43,.075,.42),'navy',.23,.014)
   for z in [1.22,1.35,1.48]:box('bracer cooling louver',(side*1.11,.60,z),(.30,.025,.035),'plate_light',.004)
   for x in [-.23,.23]:
    for z in [1.09,1.58]:rivet('bracer corner rivet',(side*1.11+x,.57,z),.032,'brass')
   plate('gauntlet main knuckles',(side*1.11,.29,.92),(.56,.57,.31),'brass',.19,.035)
   for j in range(4):
    x=side*1.11+(j-1.5)*.125
    plate('individual iron finger',(x,.48,.82),(.10,.22,.28),'plate_light',.20,.015)
    box('finger dark joint',(x,.596,.85),(.08,.02,.035),'dark_steel',.003)
   plate('opposed armored thumb',(side*1.41,.31,.94),(.18,.28,.32),'iron',.24,.02)
   tube_chain('forearm piston hose',[(side*.96,-.19,1.83),(side*1.24,-.29,1.56),(side*1.28,-.18,1.27)],.046,'brass')
  groups.append(('ArmL' if side<0 else 'ArmR',chunk(arm),(side*.75,0,2.0),1900))
  def leg():
   cyl('thigh joint core',(side*.38,0,.97),(side*.40,.01,.52),.15,'dark_steel',vertices=12)
   plate('upper thigh slab',(side*.39,.03,.82),(.50,.53,.51),'iron',.23,.035)
   plate('knee stepped armor',(side*.40,.31,.61),(.54,.25,.34),'brass',.24,.03)
   plate('knee inset plate',(side*.40,.455,.61),(.30,.06,.20),'plate_light',.25,.016)
   plate('tapered greave',(side*.40,.12,.36),(.45,.52,.48),'iron',.24,.035)
   box('greave center ridge',(side*.40,.40,.36),(.12,.12,.37),'plate_light',.025)
   for dx in [-.15,.15]:cyl('lower leg piston',(side*.40+dx,-.16,.57),(side*.40+dx,-.16,.18),.045,'silver',vertices=8)
   plate('wide armored foot',(side*.40,.26,.15),(.61,.89,.29),'dark_steel',.20,.035)
   for j in range(3):plate('separate armored toe',(side*.40+(j-1)*.175,.63,.20),(.155,.30,.23),'plate_light',.18,.017)
  groups.append(('LegL' if side<0 else 'LegR',chunk(leg),(side*.37,0,.95),1350))
 reports.append(export('golem',groups))
 
 clear();groups=[]
 def shell_segment(name,cy,width,length,zbase,height,mat):
  vertices=[]
  for ty in [-.5,0,.5]:
   taper=.80 if ty else 1.0
   for j in range(9):
    angle=j*math.pi/8
    vertices.append((math.cos(angle)*width*taper,cy+ty*length,zbase+math.sin(angle)*height*(.84 if ty else 1.0)))
  faces=[]
  for row in range(2):
   for j in range(8):faces.append((row*9+j,(row+1)*9+j,(row+1)*9+j+1,row*9+j+1))
  faces.extend([tuple(range(9)),tuple(range(26,17,-1))])
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
  ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ns['add'](ob,name,mat)
  for p in mesh.polygons:p.use_smooth=False
  sol=ob.modifiers.new('carapace thickness','SOLIDIFY');sol.thickness=.035
  bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=sol.name)
 
 def bug_body():
  ball('dark segmented abdomen',(0,-.28,.62),(.66,1.04,.41),'black',16,10)
  # Exposed seams and alternating faceted dorsal plates replace two plain ovals.
  for i in range(5):
   y=.20-i*.35;w=.68-.055*abs(i-1);h=.43-.03*abs(i-1)
   shell_segment('overlapping abdominal carapace',y,w,.46,.58,h,'carapace' if i%2 else 'carapace_light')
   plate('violet dorsal ridge',(0,y,.96-.025*abs(i-1)),(.21,.39,.12),'violet',.20,.008)
   for side in [-1,1]:
    cyl('lateral shell thorn',(side*w*.84,y,.79),(side*(w+.27),y-.16,.87),.085,'bone',r2=.003,vertices=8)
    jewel('shell light ridge',(side*w*.54,y+.06,.90),(.11,.16,.065),'jade')
  shell_segment('raised thoracic shield',.56,.64,.52,.52,.54,'violet')
  jewel('insect head underplate',(0,1.02,.57),(.48,.50,.34),'dark_steel')
  plate('angular frontal head',(0,1.17,.65),(.66,.50,.40),'carapace',.25,.035)
  for side in [-1,1]:
   jewel('eye black socket',(side*.29,1.30,.77),(.19,.17,.17),'black')
   jewel('faceted compound eye',(side*.31,1.375,.79),(.15,.105,.135),'eye')
   plate('eyebrow carapace',(side*.30,1.24,.94),(.26,.30,.11),'violet',.22,.015)
   cyl('mandible dark hinge',(side*.27,1.22,.43),(side*.43,1.43,.39),.13,'dark_steel',r2=.115,vertices=10)
   cyl('curved outer mandible',(side*.42,1.41,.39),(side*.60,1.70,.44),.11,'bone',r2=.07,vertices=10)
   cyl('inward serrated pincer',(side*.60,1.70,.44),(side*.25,1.89,.47),.076,'ivory',r2=.004,vertices=10)
   for i in range(2):cyl('mandible tooth',(side*(.46-i*.08),1.79+i*.05,.46),(side*(.40-i*.07),1.66+i*.05,.48),.035,'bone',r2=.001,vertices=6)
   tube_chain('jointed feeler',[(side*.32,1.07,.91),(side*.50,1.27,1.24),(side*.74,1.62,1.43)],.043,'carapace_light')
   jewel('amber feeler sensor',(side*.74,1.62,1.43),(.07,.07,.10),'bone')
  plate('central facial ridge',(0,1.40,.79),(.18,.13,.31),'jade',.25,.013)
  for side in [-1,1]:
   for i in range(4):cyl('abdominal breathing slit',(side*.57,-.13-i*.25,.60),(side*.62,-.13-i*.25,.57),.049,'violet',vertices=8)
 groups.append(('Body',chunk(bug_body),(0,0,0),4600))
 for side in [-1,1]:
  for i in range(3):
   y=.55-i*.68
   def leg():
    a=(side*.54,y,.62);b=(side*1.02,y-.19,.68);k=(side*1.28,y-.06,.46);foot=(side*1.55,y+.23,.09)
    ball('coxa ball hinge',a,(.14,.15,.13),'dark_steel',12,6)
    cyl('upper armored leg',a,b,.12,'carapace_light',r2=.10,vertices=10)
    jewel('upper leg armor ridge',(side*.81,y-.10,.75),(.27,.16,.10),'violet')
    ball('insect knee socket',b,(.14,.14,.14),'brass',12,6)
    cyl('angular middle tibia',b,k,.10,'carapace',r2=.075,vertices=10)
    jewel('pointed knee shield',(side*1.21,y-.06,.59),(.19,.15,.14),'jade')
    cyl('long sharp lower tarsus',k,foot,.078,'iron',r2=.026,vertices=10)
    cyl('hooked ground claw',foot,(side*1.76,y+.40,.025),.045,'bone',r2=.002,vertices=8)
    cyl('tibia defense spine',(side*1.34,y+.02,.33),(side*1.51,y-.13,.35),.045,'bone',r2=.001,vertices=8)
   groups.append((('LegL' if side<0 else 'LegR')+str(i),chunk(leg),(side*.55,y,.64),760))
 reports.append(export('skitter',groups))
all_reports=[asset_report(kind) for kind in ['infantry','gunner','mech','dragon','golem','skitter']]
(OUT/'manifest.json').write_text(json.dumps({'original_authored_assets':True,'models':all_reports,'hero_bounds_before':hero_bounds,'export_selection':'heroes' if heroes_only else ('creatures' if creatures_only else 'all')},indent=2)+'\n')
print('EXPANSION_ART',json.dumps(all_reports))
