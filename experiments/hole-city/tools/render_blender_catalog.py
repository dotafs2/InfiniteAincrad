"""Headless, original-mesh contact sheets; no desktop window or input."""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
out=Path(sys.argv[sys.argv.index('--')+1]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(root/'art_source/city_catalog.blend'))
rows=json.loads((root/'assets/city_kit/manifest.json').read_text())['assets']
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=2240;scene.render.resolution_y=1680;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
sh=scene.display.shading;sh.light='STUDIO';sh.studiolight_rotate_z=.35;sh.color_type='VERTEX'
sh.show_shadows=True;sh.show_cavity=True;sh.cavity_type='BOTH';sh.curvature_ridge_factor=1.2
sh.background_type='WORLD';scene.world.color=(.14,.18,.22)
camdata=bpy.data.cameras.new('CatalogCamera');cam=bpy.data.objects.new('CatalogCamera',camdata);scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO'
for group,spacing in [('building',(9,14)),('vehicle',(3.4,6.4)),('prop',(3.4,5.8)),('plant',(3.2,5.5)),('person',(1.3,2.7))]:
    entries=[r for r in rows if r['group']==group];cols=8;countrows=math.ceil(len(entries)/cols)
    for obj in bpy.data.objects:
        if obj.type in ['MESH','ARMATURE']:obj.hide_render=True
    for i,r in enumerate(entries):
        obj=bpy.data.objects[r['id']];parent=obj.parent or obj
        obj.hide_render=False;parent.hide_render=False
        parent.location=((i%cols-(cols-1)/2)*spacing[0],(i//cols-(countrows-1)/2)*spacing[1],0)
        parent.rotation_euler.z=-.30 if group!='building' else -.12
        if parent.type=='ARMATURE':
            for bone in parent.pose.bones:bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
    cam.location=(0,-120,65 if group=='person' else 120);target=Vector((0,0,1 if group=='building' else .25));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    camdata.ortho_scale=max(cols*spacing[0]+spacing[0],countrows*spacing[1]*1.05/.75)
    scene.render.filepath=str(out/(group+'-catalog.png'));bpy.ops.render.render(write_still=True)
    print('RENDERED',group,flush=True)
