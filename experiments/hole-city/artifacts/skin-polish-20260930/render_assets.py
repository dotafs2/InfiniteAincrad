"""Blender CPU asset previews, not Godot/game screenshots.
Meshes and normals are exported verbatim; Standard material roughness/color are
mapped to Blender Principled. The thin procedural base ring is shown using its
base color, not an emulation of Godot's shader/lighting pipeline.
"""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:];source=Path(args[0]);dest=Path(args[1]);dest.mkdir(parents=True,exist_ok=True)
def co(v):return (v[0],-v[2],v[1])
for skin in json.loads(source.read_text()):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24
 scene.cycles.use_denoising=True;scene.render.resolution_x=480;scene.render.resolution_y=400;scene.render.resolution_percentage=100
 scene.render.film_transparent=True;scene.view_settings.view_transform='Standard';scene.view_settings.look='Medium High Contrast';scene.view_settings.exposure=0;scene.view_settings.gamma=1
 scene.world=bpy.data.worlds.new('Preview world');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.77,.86,1,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
 for mi,record in enumerate(skin['meshes']):
  p=record['positions'];ns=record['normals'];vs=[co(p[i:i+3]) for i in range(0,len(p),3)];normals=[co(ns[i:i+3]) for i in range(0,len(ns),3)]
  ix=record['indices'];faces=[(ix[i],ix[i+2],ix[i+1]) for i in range(0,len(ix),3)]
  mesh=bpy.data.meshes.new('actual mesh');mesh.from_pydata(vs,[],faces);mesh.update();obj=bpy.data.objects.new('part'+str(mi),mesh);scene.collection.objects.link(obj)
  for face in mesh.polygons:face.use_smooth=True
  mesh.use_auto_smooth=True;mesh.normals_split_custom_set_from_vertices(normals)
  prm=record['params'];color=prm.get('color',prm.get('base_color',[1,1,1,1]))
  mat=bpy.data.materials.new('Actual finish');mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
  def linear(v):return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
  rgb=[linear(x) for x in color[:3]]+[1]
  if prm.get('unshaded',True):
   emission=nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=rgb;emission.inputs['Strength'].default_value=1;links.new(emission.outputs[0],nodes.get('Material Output').inputs[0])
  else:
   bs.inputs['Base Color'].default_value=rgb;bs.inputs['Roughness'].default_value=prm.get('roughness',.34);bs.inputs['Metallic'].default_value=prm.get('metallic',0);bs.inputs['Specular'].default_value=prm.get('specular',.55);bs.inputs['Clearcoat'].default_value=.22;bs.inputs['Clearcoat Roughness'].default_value=.3
  mesh.materials.append(mat)
 camera_data=bpy.data.cameras.new('Matched orthographic asset camera');camera_data.type='ORTHO';camera_data.ortho_scale=3.6
 camera=bpy.data.objects.new('Camera',camera_data);scene.collection.objects.link(camera);camera.location=(0,-8,6.6);camera.rotation_euler=(Vector((0,0,.14))-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 for name,pos,power,size in [('Key',(-3,-4,7),420,3),('Rim',(4,1,4),180,3)]:
  lamp=bpy.data.lights.new(name,'AREA');lamp.energy=power;lamp.shape='DISK';lamp.size=size;ob=bpy.data.objects.new(name,lamp);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
 scene.render.image_settings.file_format='PNG';scene.render.filepath=str(dest/(skin['id']+'.png'));bpy.ops.render.render(write_still=True)
print('OFFLINE_SKIN_ASSET_RENDER six actual mesh sets; not game screenshots')
