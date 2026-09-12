import bpy,json,math
from pathlib import Path
root=Path(__file__).resolve().parents[4]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'game/assets/generated/shopfront_details_20260912/SF03_Diamond_Lead_Casement.glb'))
res=[]
for ob in bpy.context.scene.objects:
    if ob.type!='MESH':continue
    me=ob.data
    bad=[v for v in me.vertices if v.normal.length<.5]
    corners=[n.vector[:] for n in me.corner_normals]
    res.append({'mesh':ob.name,'bad_vertex_normals':[{'index':v.index,'coord':v.co[:],'normal':v.normal[:],'linked_polygons':[p.index for p in me.polygons if v.index in p.vertices]} for v in bad],'corner_normals_count':len(corners),'bad_corner_normals':sum(1 for n in corners if not all(math.isfinite(x) for x in n) or sum(x*x for x in n)<.9)})
Path(__file__).with_suffix('.json').write_text(json.dumps(res,indent=2),encoding='utf-8')
print(json.dumps(res),flush=True)
