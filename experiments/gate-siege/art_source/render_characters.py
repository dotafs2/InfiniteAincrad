import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
names=['infantry','gunner','mech','brute','zombie','gunner_silver']
for i,name in enumerate(names):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models'/(name+'.glb')))
 new=set(bpy.data.objects)-before
 # Import converts back to Z-up, preserving artist orientation.
 for o in new:
  if o.type=='MESH':
   h=max(v.co.z for v in o.data.vertices)-min(v.co.z for v in o.data.vertices)
   s=3.4/h;o.scale=(s,s,s);o.location=(i*2.95-7.375,0,0)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=2100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world.color=(.15,.15,.15)
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.16,.22,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.01));floor=bpy.context.object
mat=bpy.data.materials.new('studio slate');mat.diffuse_color=(.045,.06,.085,1);floor.data.materials.append(mat)
for loc,energy,size in [((-6,4,10),850,8),((7,1,6),650,7),((0,-5,7),900,6)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=energy;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,0,1.5))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1,12,7));cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=18.6
cam.rotation_euler=(Vector((0,0,1.7))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ROOT/'art_source/characters-front.png');bpy.ops.render.render(write_still=True)
cam.location=(1,-12,7);cam.rotation_euler=(Vector((0,0,1.7))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(ROOT/'art_source/characters-rear.png');bpy.ops.render.render(write_still=True)
