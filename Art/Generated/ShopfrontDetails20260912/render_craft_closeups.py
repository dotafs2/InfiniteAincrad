"""Render true-scale craft emblem closeups from the delivered editable Blend."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
QA=ROOT/'docs/validation/art_parallel_20260912/shopfront'
bpy.ops.wm.open_mainfile(filepath=str(HERE/'ShopfrontDetails20260912.blend'))
sc=bpy.context.scene;sc.render.resolution_x=1400;sc.render.resolution_y=1000;sc.cycles.samples=32
def aim(ob,p):ob.rotation_euler=(Vector(p)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size in [('Key',(-3,-4,6),600,4),('Fill',(4,-2,3),300,3),('Top',(0,2,4),450,3)]:
    ob=bpy.data.objects[name];ob.location=loc;ob.data.energy=power;ob.data.size=size;aim(ob,(0,-.4,.5))
cam=sc.camera;cam.location=(1.4,-7,2.2);aim(cam,(0,-.4,.60));cam.data.ortho_scale=3.0
for ids,name in [(['SF13_Bakery_Pretzel_Emblem','SF14_Apothecary_Mortar_Emblem'],'close_bakery_apothecary'),(['SF15_Tailor_Shears_Emblem','SF16_Barber_Spiral_Emblem'],'close_tailor_barber')]:
    for ob in sc.objects:
        if ob.type in ('MESH','FONT'):ob.hide_render=True
    for i,key in enumerate(ids):
        ob=bpy.data.objects[key];ob.hide_render=False;ob.location=((i-.5)*1.40,0,0)
    sc.render.filepath=str(QA/(name+'.png'));bpy.ops.render.render(write_still=True)
if '--final-revision' in sys.argv:
    # Refresh every image containing the corrected hanging connections.
    bpy.ops.wm.open_mainfile(filepath=str(HERE/'ShopfrontDetails20260912.blend'))
    sc=bpy.context.scene;sc.cycles.samples=16
    sc.render.filepath=str(QA/'overview.png');bpy.ops.render.render(write_still=True)
    ids=['SF13_Bakery_Pretzel_Emblem','SF14_Apothecary_Mortar_Emblem','SF15_Tailor_Shears_Emblem','SF16_Barber_Spiral_Emblem']
    for ob in sc.objects:
        if ob.type in ('MESH','FONT'):ob.hide_render=True
    for i,key in enumerate(ids):
        bpy.data.objects[key].hide_render=False
        bpy.data.objects['DisplayPanel_'+str(i+13)].hide_render=False
    mid=(bpy.data.objects[ids[0]].location+bpy.data.objects[ids[-1]].location)/2+Vector((0,0,1.45))
    cam=sc.camera;cam.location=mid+Vector((2.1,-15,3.3));aim(cam,mid);cam.data.ortho_scale=15.5
    sc.render.resolution_x=1500;sc.render.resolution_y=1250
    sc.render.filepath=str(QA/'detail_craft_emblems.png');bpy.ops.render.render(write_still=True)
