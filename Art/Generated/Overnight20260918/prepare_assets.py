"""Offline reuse/adaptation only. Run in Blender; no model APIs or private saves.

The hearth reuses the existing Meshy asset, crops the tall chimney and caps it.
Bread reuses the project's existing Geo/loaf recipe (AST-selected to avoid its
module-level output-directory side effects). The tied flour sack is new geometry.
"""
import ast
import bpy
import bmesh
import math
import json
import hashlib
import sys
from pathlib import Path
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'game/assets/overnight20260918'
OUT.mkdir(parents=True, exist_ok=True)
records = []
BREAD_ONLY = '--bread-only' in sys.argv
previous_records = json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))['assets'] if BREAD_ONLY else []


def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=.85):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    return m


def box(name, position, dimensions, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    o = bpy.context.object
    o.name = name
    o.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    bevel = o.modifiers.new('Soft stone edges', 'BEVEL')
    bevel.width = .009
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return o


def tube(name, points, radius, material):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = radius
    c.bevel_resolution = 2
    s = c.splines.new('POLY')
    s.points.add(len(points) - 1)
    for p, v in zip(s.points, points):
        p.co = (*v, 1)
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    c.materials.append(material)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    return bpy.context.object


def bounds(objects):
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    return Vector(tuple(min(v[i] for v in points) for i in range(3))), Vector(tuple(max(v[i] for v in points) for i in range(3)))


def export(asset_id, root_name, target, provenance):
    if BREAD_ONLY and asset_id != 'bread_loaf':
        records.append(next(r for r in previous_records if r['id'] == asset_id))
        return
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.context.view_layer.update()
    lo, hi = bounds(objects)
    # target is Godot XYZ (Blender X,-Y,Z); center X/Y, floor Z.
    factors = Vector((target[0]/(hi.x-lo.x), target[2]/(hi.y-lo.y), target[1]/(hi.z-lo.z)))
    center = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
    for o in objects:
        world = o.matrix_world.copy()
        for v in o.data.vertices:
            q = world @ v.co - center
            v.co = Vector(tuple(q[i]*factors[i] for i in range(3)))
        o.matrix_world = Matrix.Identity(4)
        o.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = root_name + 'Visual'
    o.data.calc_loop_triangles()
    path = OUT / (asset_id + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
    tri = len(o.data.loop_triangles)
    bad = sum(1 for t in o.data.loop_triangles if (o.data.vertices[t.vertices[1]].co-o.data.vertices[t.vertices[0]].co).cross(o.data.vertices[t.vertices[2]].co-o.data.vertices[t.vertices[0]].co).length < 1e-12)
    record = dict(id=asset_id, root=root_name, glb=str(path.relative_to(ROOT)).replace('\\','/'), triangles=tri, degenerate_triangles=bad, dimensions_godot_m=target, origin='bottom center', front='+Z', scale=[1,1,1], materials=[m.name for m in o.data.materials], bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), provenance=provenance, collision='none; visual only')
    records.append(record)
    (OUT / (asset_id + '.tscn')).write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="res://assets/overnight20260918/'+asset_id+'.glb" id="1"]\n\n[node name="'+root_name+'" type="Node3D"]\n\n[node name="Visual" parent="." instance=ExtResource("1")]\n', encoding='utf-8')


reset()
source = ROOT / 'game/assets/floor1/living_props_20260916/hearth.glb'
bpy.ops.import_scene.gltf(filepath=str(source))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.context.view_layer.update()
lo, hi = bounds(objects)
floor = lo.z
for o in objects:
    world = o.matrix_world.copy()
    for v in o.data.vertices:
        v.co = world @ v.co
        v.co.z -= floor
    o.matrix_world = Matrix.Identity(4)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces), dist=.00001, plane_co=(0,0,1.31), plane_no=(0,0,1), clear_outer=True, clear_inner=False)
    # The explicit stone coping covers the cut; do not invent new UVs on the source.
    bm.to_mesh(o.data)
    bm.free()
stone = mat('ON_Coping_Limestone', (.49,.455,.35))
box('StoneCoping', ((lo.x+hi.x)/2, (lo.y+hi.y)/2, 1.32), (hi.x-lo.x, hi.y-lo.y, .06), stone)
export('baking_oven', 'BakingOven', [1.0,1.0,.76], {'source':str(source.relative_to(ROOT)).replace('\\','/'), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'adaptation':'Existing Meshy hearth lower 1.31m; chimney removed, limestone coping added, fitted to existing oven volume. Existing texture retained.'})

reset()
# Load only the reusable geometry recipe; skip its output-path mutations.
recipe = ROOT / 'Art/Generated/TravelCargo20260912/geometry.py'
tree = ast.parse(recipe.read_text(encoding='utf-8-sig'))
chosen = []
for node in tree.body:
    if isinstance(node, (ast.ClassDef, ast.FunctionDef)) and node.name in {'Geo','material','loaf'}:
        chosen.append(node)
    elif isinstance(node, ast.Assign) and any(isinstance(t,ast.Name) and t.id in {'PALETTE','MATS'} for t in node.targets):
        chosen.append(node)
namespace = dict(bpy=bpy, math=math, Vector=Vector, Matrix=Matrix, TAU=math.tau, STYLE='overnight20260918')
exec(compile(ast.Module(body=chosen,type_ignores=[]),str(recipe),'exec'), namespace)
# Publisher-hosted Progressive 1, Aria section 4 explicitly describes the
# inexpensive NPC bakery bread as dark brown and round. Keep one existing asset
# id and all gameplay semantics; only its visual recipe is aligned here.
namespace['PALETTE']['bread'] = ('59402D', .92, 0)
namespace['PALETTE']['bread_score'] = ('35271C', .94, 0)
namespace['PALETTE']['bread_light'] = ('98774F', .94, 0)
g = namespace['Geo']()
# Adapt the existing sphere-and-scored-crust recipe to a round footprint.
# Restrict each score to the loaf surface; the old oval recipe's outer scores
# otherwise overhang the edge when switched to its four-score round variant.
g.sphere((0,0,.07), (.13,.13,.07), 'bread', 28, 14)
for x in (-.067,-.022,.022,.067):
    span = math.sqrt(.13*.13-x*x)*.72
    points=[]
    for k in range(13):
        y = -span + 2*span*k/12
        z = .07 + .07*math.sqrt(1-(x/.13)**2-(y/.13)**2)
        points.append((x,y,z+.0005))
    g.tube(points,.0035,'bread_score',6)
    g.tube([(x+.003,y,z+.001) for x,y,z in points],.002,'bread_light',6)
g.finish('BreadLoaf', bpy.context.collection)
export('bread_loaf', 'BreadLoaf', [.26,.15,.26], {'source':str(recipe.relative_to(ROOT)).replace('\\','/'), 'adaptation':'Existing project loaf recipe, dark brown round bread aligned to Progressive 1 Aria section 4. No price, cream reward, food inventory or production logic encoded.', 'primary_reference':'https://dengekibunko.jp/novecomi/novel/16817330648099677277/16817330648100108071.html'})

reset()
linen = mat('ON_Linen', (.62,.54,.38))
seam = mat('ON_Stitch', (.37,.28,.16))
rope = mat('ON_HempTie', (.31,.22,.12))
# Slightly creased, gathered cloth silhouette; one watertight lathed bag.
profile = [(0.075,0),(.108,.025),(.116,.075),(.111,.17),(.09,.22),(.044,.255),(.035,.268),(.047,.284),(.041,.294)]
n = 32
verts=[]
for j,(r,z) in enumerate(profile):
    for i in range(n):
        a=math.tau*i/n
        fold = 1 + .035*math.cos(6*a+z*14) + (.08 if j>4 else .012)*math.cos(12*a)
        verts.append((r*fold*math.cos(a), r*fold*math.sin(a)*.90, z))
faces=[tuple(range(n-1,-1,-1))]
for j in range(len(profile)-1):
    for i in range(n):
        faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
faces.append(tuple((len(profile)-1)*n+i for i in range(n)))
me=bpy.data.meshes.new('GatheredLinen')
me.from_pydata(verts,[],faces)
me.update()
o=bpy.data.objects.new('FlourSackCloth',me)
bpy.context.collection.objects.link(o)
me.materials.append(linen)
for p in me.polygons:p.use_smooth=True
for phase in (0,math.pi):
    points=[(r*math.cos(phase)*1.01, r*math.sin(phase)*.91, z) for r,z in profile[:-1]]
    tube('SideSeam', points, .0017, seam)
for z in (.254,.261):
    tube('HempBinding',[(.042*math.cos(math.tau*i/48),.038*math.sin(math.tau*i/48),z) for i in range(49)],.003,rope)
tube('TieEnds',[(0,-.039,.259),(.012,-.052,.251),(.03,-.052,.218)],.003,rope)
# A sewn wheat mark distinguishes flour from a generic crate without text.
tube('WheatStem',[(0,-.102,.072),(0,-.104,.174)],.0018,seam)
for j in range(4):
    z=.09+j*.018
    for sign in (-1,1):tube('WheatGrain',[(0,-.105,z),(.013*sign,-.104,z+.009),(.018*sign,-.102,z+.016)],.0022,seam)
export('flour_sack','FlourSack',[.24,.30,.24],{'source':'Original offline Blender mesh; project linen/hemp palette', 'adaptation':'Tied cloth bag for one displayed flour unit. No stock value encoded in asset.'})

manifest = dict(batch='overnight20260918', assets=records, new_paid_calls=0, actual_new_credits=0, provider_task_ids=[], scope='Three pure visual prefabs, no collision, scripts, stock mutations or main scene edits. Godot preview is an asset gallery, not a live-world adoption claim.')
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':[{k:r[k] for k in ('id','triangles','degenerate_triangles','bytes')} for r in records], 'paid_calls':0}))
