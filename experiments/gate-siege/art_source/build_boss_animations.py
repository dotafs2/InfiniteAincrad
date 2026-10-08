"""Build two original 13-bone, one-surface animated mobile boss variants.

Blender 4.2: --background --factory-startup --python this_file.py
The existing static builder is parsed up to its explicit export entry point;
its asset-writing loop is never executed. Existing static GLBs are hash-guarded.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models'
source=Path(__file__).with_name('build_characters.py')
ns={'__file__':str(source),'__name__':'boss_geometry_library'}
exec(compile(source.read_text().split('all_models=')[0],str(source),'exec'),ns)
STATIC={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.glb') if not p.name.endswith('_animated.glb')}
FPS=30
CLIPS={'walk':1.2,'attack':1.0,'hit':.30,'death':1.7}
BONES=[('pelvis',(0,0,1.38),(0,0,1.67),None),('spine',(0,0,1.67),(0,0,2.64),'pelvis'),('head',(0,0,2.64),(0,0,3.31),'spine')]
for side in [-1,1]:
 s='L' if side<0 else 'R'
 BONES.extend([(s+'_upperarm',(side*.66,0,2.46),(side*.93,.10,2.04),'spine'),(s+'_forearm',(side*.93,.10,2.04),(side*.89,.32,1.58),s+'_upperarm'),(s+'_thigh',(side*.30,-.02,1.40),(side*.34,-.03,.92),'pelvis'),(s+'_shin',(side*.34,-.03,.92),(side*.34,0,.30),s+'_thigh'),(s+'_foot',(side*.34,0,.30),(side*.34,.32,.10),s+'_shin')])

def smoothstep(a,b,t):
 v=max(0,min(1,(t-a)/(b-a)));return v*v*(3-2*v)
def classify(o):
 n=o.name
 center=o.matrix_world.translation
 side='L' if center.x<0 else 'R'
 if any(x in n for x in ['boot','sole']):return side+'_foot'
 if 'calf' in n:return side+'_shin'
 if 'thigh' in n:return side+'_thigh'
 if any(x in n for x in ['forearm','arm bracer','bracer steel','clenched fist','knuckle','gauntlet']):return side+'_forearm'
 if any(x in n for x in ['shoulder','bicep']):return side+'_upperarm'
 if any(x in n for x in ['cranium','lower jaw','ear','eye','pupil','brow','nose','mouth','teeth','cheek','hair']):return 'head'
 if any(x in n for x in ['trouser seat','waist belt','brute buckle']):return 'pelvis'
 return 'spine'
def weights_for(o,role,v):
 z=(o.matrix_world@v.co).z
 if role=='spine':
  t=smoothstep(1.44,1.83,z);return {'pelvis':1-t,'spine':t}
 if role=='head':return {'head':1.}
 if role.endswith('_thigh'):
  parent='pelvis';t=smoothstep(1.32,1.55,z)*.40;return {role:1-t,parent:t}
 if role.endswith('_upperarm'):
  # Shoulder skin bridges the chest, while the bicep is fully arm-driven.
  if 'shoulder' in o.name:return {role:.78,'spine':.22}
 return {role:1.}

def make_geometry(kind):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
 ns['parts']=[];ns['CROWD']=False;ns[kind]()
 parts=ns['parts']
 # Preserve named per-part articulation before geometry is combined.
 for o in parts:
  role=classify(o)
  groups={name:o.vertex_groups.new(name=name) for name,_,_,_ in BONES}
  for v in o.data.vertices:
   for name,w in weights_for(o,role,v).items():
    if w>.0001:groups[name].add([v.index],w,'REPLACE')
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts:o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();obj=parts[0]
 obj.name='BossBody';bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 world=[obj.matrix_world@v.co for v in obj.data.vertices]
 low=min(v.z for v in world);high=max(v.z for v in world);scale=3.4/(high-low)
 for v in obj.data.vertices:
  w=obj.matrix_world@v.co;v.co=(w.x*scale,w.y*scale,(w.z-low)*scale)
 obj.location=(0,0,0);obj.rotation_mode='XYZ';obj.rotation_euler=(0,0,0);obj.scale=(1,1,1)
 # 6.4k triangles for both silhouettes; retain vertex groups during decimation.
 tris=sum(len(p.vertices)-2 for p in obj.data.polygons)
 dec=obj.modifiers.new('mobile polygon budget','DECIMATE');dec.ratio=min(1,6400/tris)
 bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=dec.name)
 fixed=obj.data.validate(verbose=False,clean_customdata=False);obj.data.update()
 assert not obj.data.validate(verbose=False,clean_customdata=False)
 print('MESH_VALIDATED',kind,'corrected_degenerate_faces',fixed)
 colors=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 for poly in obj.data.polygons:
  linear=obj.data.materials[poly.material_index].diffuse_color
  # Compatibility renders vertex palette channels in sRGB; this keeps the
  # simplified material visually aligned with the original albedo colors.
  c=tuple(12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in linear[:3])+(1,)
  for li in poly.loop_indices:colors.data[li].color=c
 mat=bpy.data.materials.new(kind+'_mobile_vertex_palette');mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.57;bs.inputs['Metallic'].default_value=.10
 vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
 obj.data.materials.clear();obj.data.materials.append(mat)
 for p in obj.data.polygons:p.material_index=0
 return obj,scale,low

def make_rig(obj,scale,low):
 data=bpy.data.armatures.new('BossSkeleton');rig=bpy.data.objects.new('BossRig',data);bpy.context.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);obj.select_set(False);bpy.ops.object.mode_set(mode='EDIT')
 for name,head,tail,parent in BONES:
  b=data.edit_bones.new(name);b.head=(head[0]*scale,head[1]*scale,(head[2]-low)*scale);b.tail=(tail[0]*scale,tail[1]*scale,(tail[2]-low)*scale)
  if parent:b.parent=data.edit_bones[parent]
  b.use_connect=False
 bpy.ops.object.mode_set(mode='OBJECT')
 mod=obj.modifiers.new('13 bone skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=False
 obj.parent=rig
 rig.animation_data_create()
 return rig

def quat_for(rig,name,angles):
 # Pose channels are bone-local; artist angles are around model-space axes.
 q=Quaternion((1,0,0),angles[0])@Quaternion((0,1,0),angles[1])@Quaternion((0,0,1),angles[2])
 basis=rig.data.bones[name].matrix_local.to_quaternion();return basis.inverted()@q@basis

def pose_keys(rig,frame,angles,translation=(0,0,0)):
 bpy.context.scene.frame_set(frame)
 for b in rig.pose.bones:
  b.rotation_mode='QUATERNION';b.rotation_quaternion=quat_for(rig,b.name,angles.get(b.name,(0,0,0)))
  b.location=(0,0,0);b.scale=(1,1,1)
  if b.name=='pelvis':
   basis=b.bone.matrix_local.to_quaternion();b.location=basis.inverted()@Vector(translation)
 # Plant the lowest skinned vertex on the floor in every pose. This is baked
 # into pelvis translation, so runtime needs no IK or collision query.
 bpy.context.view_layer.update()
 body=next(o for o in rig.children if o.type=='MESH')
 evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
 mesh=evaluated.to_mesh();bottom=min((evaluated.matrix_world@v.co).z for v in mesh.vertices);evaluated.to_mesh_clear()
 pelvis=rig.pose.bones['pelvis'];basis=pelvis.bone.matrix_local.to_quaternion();pelvis.location+=basis.inverted()@Vector((0,0,-bottom))
 bpy.context.view_layer.update()
 for b in rig.pose.bones:
  b.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=b.name)
  b.keyframe_insert(data_path='location',frame=frame,group=b.name)

def interp_keys(keys,t):
 for i in range(len(keys)-1):
  a,b=keys[i],keys[i+1]
  if a[0]<=t<=b[0]:
   f=smoothstep(a[0],b[0],t);return [a[j]+(b[j]-a[j])*f for j in range(1,len(a))]
 return list(keys[-1][1:])
def animate(rig):
 for name,duration in CLIPS.items():
  action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
  count=round(duration*FPS)
  for f in range(count+1):
   t=f/FPS;p=t/duration;ang={};loc=(0,0,0)
   if name=='walk':
    s=math.sin(p*math.tau);c=math.cos(p*math.tau)
    loc=(.055*s,0,-.080*abs(s))
    ang={'spine':(.02,.025*s,.045*s),'head':(-.02,-.025*s,-.027*s)}
    for side,sign in [('L',1),('R',-1)]:
     v=s*sign
     ang[side+'_thigh']=(.39*v,0,0)
     ang[side+'_shin']=(-1.15*max(0,v),0,0)
     ang[side+'_foot']=(-.39*v+1.15*max(0,v),0,0)
     ang[side+'_upperarm']=(-.30*v,0,sign*.015)
     ang[side+'_forearm']=(-.09-.11*max(0,-v),0,0)
   elif name=='attack':
    # Two-arm wind-up, overhead suspension, fast forward strike and recovery.
    shoulder,elbow,bend,drop=interp_keys([(0,0,0,0,0),(.28,2.30,-.70,-.17,.09),(.46,2.45,-.56,-.18,.09),(.64,.94,.08,.64,-.16),(.78,.75,-.02,.42,-.08),(1.,0,0,0,0)],p)
    ang={'spine':(-bend,0,0),'head':(bend*.45,0,0),'L_upperarm':(shoulder,-.08,-.09),'R_upperarm':(shoulder,.08,.09),'L_forearm':(elbow,0,0),'R_forearm':(elbow,0,0),'L_thigh':(.10,0,0),'R_thigh':(.10,0,0),'L_shin':(-.16,0,0),'R_shin':(-.16,0,0)}
    loc=(0,0,drop)
   elif name=='hit':
    strength=interp_keys([(0,0),(.2,1),(.5,.5),(1,0)],p)[0]
    ang={'spine':(.23*strength,.06*strength,0),'head':(.13*strength,0,.08*strength),'L_upperarm':(-.16*strength,0,-.09*strength),'R_upperarm':(-.11*strength,0,.09*strength)}
    loc=(0,-.065*strength,-.035*strength)
   else:
    # Visible knee buckle, then a heavy sideways-forward fall into a settled pose.
    knee,hip,bend,fall,drop=interp_keys([(0,0,0,0,0,0),(.22,-1.12,.63,.21,0,-.36),(.43,-1.24,.68,.54,.32,-.65),(.70,-.76,.25,.32,1.38,-1.02),(.82,-.52,.09,.12,1.48,-1.04),(1.,-.52,.09,.12,1.48,-1.04)],p)
    ang={'pelvis':(.25*fall,fall,0),'spine':(-bend,0,0),'head':(.19,0,-.17),'L_thigh':(hip,0,-.09),'R_thigh':(hip*.8,0,.09),'L_shin':(knee,0,0),'R_shin':(knee*.9,0,0),'L_foot':(-hip-knee,0,0),'R_foot':(-hip*.8-knee*.9,0,0),'L_upperarm':(.65*fall,0,-.36),'R_upperarm':(.53*fall,0,.24),'L_forearm':(-.29,0,0),'R_forearm':(-.34,0,0)}
    loc=(.48*fall,.17*fall,drop)
   pose_keys(rig,f,ang,loc)
  for fc in action.fcurves:
   for k in fc.keyframe_points:k.interpolation='LINEAR'
  track=rig.animation_data.nla_tracks.new();track.name=name
  strip=track.strips.new(name,0,action);strip.name=name
 rig.animation_data.action=None
 for track in rig.animation_data.nla_tracks:track.mute=False

reports=[]
for kind in ['brute_vest','brute']:
 obj,scale,low=make_geometry(kind);rig=make_rig(obj,scale,low);animate(rig)
 bpy.context.scene.render.fps=FPS;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=51;bpy.context.scene.frame_set(0)
 # Rest pose must be exported, independent of summed NLA preview state.
 for track in rig.animation_data.nla_tracks:track.mute=True
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
 args=dict(filepath=str(OUT/(kind+'_animated.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_materials='EXPORT',export_animations=True,export_skins=True,export_all_influences=False,export_frame_range=False,export_force_sampling=True)
 props=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
 if 'export_animation_mode' in props:args['export_animation_mode']='ACTIONS'
 if 'export_nla_strips' in props:args['export_nla_strips']=True
 if 'export_anim_single_armature' in props:args['export_anim_single_armature']=True
 bpy.ops.export_scene.gltf(**args)
 report={'asset':kind+'_animated.glb','triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'bones':len(rig.data.bones),'surfaces':len(obj.data.materials),'height':3.4,'clips':CLIPS,'sha256':hashlib.sha256((OUT/(kind+'_animated.glb')).read_bytes()).hexdigest()};reports.append(report);print('BOSS_ASSET',json.dumps(report))
for name,digest in STATIC.items():assert hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest,'Static asset changed: '+name
print('STATIC_HASH_GUARD_PASS',len(STATIC))
print('ANIMATED_BOSS_REPORT',json.dumps(reports))
