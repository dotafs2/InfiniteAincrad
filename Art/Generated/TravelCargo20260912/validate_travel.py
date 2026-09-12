"""Reimport every TravelCargo GLB in fresh Blender, without opening a world."""
import bpy, math, json, time
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
OUT=ROOT/'docs/validation/art_parallel_20260912/travel'
manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
results=[];failures=[]
for record in manifest['assets']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/record['file']))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    points=[];triangles=0;materials=0;invalid_normals=0;tiny=0
    for obj in meshes:
        points += [obj.matrix_world@v.co for v in obj.data.vertices]
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        tiny+=sum(t.area<5e-10 for t in obj.data.loop_triangles)
        materials+=len(obj.data.materials)
        invalid_normals+=sum(not all(math.isfinite(v) for v in n.vector) or n.vector.length<.98 for n in obj.data.corner_normals)
    dims=[max(v[a] for v in points)-min(v[a] for v in points) for a in range(3)] if points else [0,0,0]
    expected=record['dimensions_m']
    errors=[]
    if not points or not all(math.isfinite(n) for p in points for n in p):errors.append('invalid positions')
    if triangles!=record['triangles']:errors.append('triangle mismatch')
    if any(abs(a-b)>.0003 for a,b in zip(dims,expected)):errors.append('dimension mismatch')
    if tiny:errors.append('small-area triangles')
    if invalid_normals:errors.append('invalid corner normals')
    if materials!=record['material_count']:errors.append('material count mismatch')
    item={'id':record['id'],'triangles':triangles,'materials':materials,'dimensions_m':dims,'invalid_corner_normals':invalid_normals,'tiny_triangles':tiny,'errors':errors}
    results.append(item)
    if errors:failures.append(item)
report={'blender_version':bpy.app.version_string,'scope':'Fresh GLB reimport; geometry, scale, materials, and corner normals; no world loaded','tested':len(results),'failures':failures,'results':results}
(OUT/'blender_roundtrip.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('TRAVEL_ROUNDTRIP',len(results),'failures',len(failures),flush=True)
if failures:raise RuntimeError('Travel GLB reimport validation failed')
