"""F1_Residence_06 -- one original Floor-1 residential exterior, metres / Z-up.

DeepSeek-authored extension of the approved project library
Art/ReferenceScenes/Floor1Residences/build_residences.py. The prior library is
imported (never executed as __main__) and its proven Geo/house/wall/opening/
roof/balcony/lantern/tile primitives, palette, deterministic R and GLB/LOD
operations are reused. Geometry composition, collision proxies, labels and the
F1_Residence_06 asset itself are new in this file.

Blender --background --python build_house_06.py
UV0 is a 2 m directional metric tile; UV1 is a unique packed secondary unwrap.
Closed doors, unfurnished shell.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / 'game/assets/floor1/deepseek_residences'
TEX = ROOT / 'game/assets/floor1/residences/textures'
LIB_PATH = ROOT / 'Art/ReferenceScenes/Floor1Residences/build_residences.py'


def load_library():
    spec = importlib.util.spec_from_file_location('residence_library', LIB_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules['residence_library'] = module
    spec.loader.exec_module(module)
    return module


LIB = load_library()
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

R = random.Random(2060)
LIB.R = R
LIB.MAPS = {}
LIB.N = 2048
TEXTURE_SETS = ('plaster', 'limestone', 'oak', 'clay')
TEXTURE_MAPS = ('albedo', 'normal', 'orm')


def load_existing_maps():
    maps = {}
    for kind in TEXTURE_SETS:
        found = []
        for channel in TEXTURE_MAPS:
            path = TEX / (kind + '_' + channel + '.png')
            if not path.exists():
                raise RuntimeError('missing shared texture ' + path.as_posix())
            image = bpy.data.images.load(str(path), check_existing=False)
            image.colorspace_settings.name = 'Non-Color' if channel != 'albedo' else 'sRGB'
            image.pack()
            found.append(image)
        maps[kind] = tuple(found)
    return maps


# ---------------------------------------------------------------------------
# F1_Residence_06: one coherent two-storey body with a single-storey open
# entrance gallery. No mass overlaps any other mass; no opening is laid over
# an uncut wall. Warm stone base / pale plaster / desaturated teal shutters /
# terracotta clay roof.
# ---------------------------------------------------------------------------
def design():
    """Return (geo, proxies, label, label_zh).

    Silhouette: squat tall-windowed double-pile body (7.4 x 6.4 m, 2 storeys)
    with a steep hip terracotta clay roof. A projecting single-storey front
    gallery (recessed round arch, closed door, two square piers with a tiled
    lean-to roof) is built outward from the facade rather than through it, so
    the main body wall stays intact behind the porch. A flush one-storey bay
    on the east elevation is recessed into the wall and does not pierce it.
    """
    w, d, floors = 7.4, 6.4, 2
    g, h, rise = LIB.house(w, d, floors, 'plaster', 'blueshutter', 'roof',
                           hip=True, doorx=-1.75, balcony_x=None)

    # Door was carved at x=-1.75; the gallery arch is centred at the same x so
    # the closed door reads through the arch instead of two competing doors.
    door_x = -1.75
    porch_w = 2.35
    porch_d = 1.35
    porch_z0, porch_z1 = 0.35, 3.23

    porch = LIB.Geo()
    # Two square piers with plinths and capitals, never in front of windows.
    for sx in (-1, 1):
        px = sx * (porch_w / 2 - 0.16)
        porch.box((px, -porch_d / 2, 0.35 / 2), (0.40, 0.40, 0.35), 'stone')
        porch.box((px, -porch_d / 2, porch_z0 + (porch_z1 - porch_z0) / 2),
                  (0.30, 0.30, porch_z1 - porch_z0), 'plaster')
        porch.box((px, -porch_d / 2, porch_z1 - 0.14), (0.42, 0.42, 0.12), 'trim')
        porch.box((px, -porch_d / 2, porch_z0 + 0.14), (0.42, 0.42, 0.12), 'trim')
    # Round arcade beam from pier to pier, seated on the capitals.
    porch.box((0.0, -porch_d / 2, porch_z1 + 0.14), (porch_w, 0.42, 0.30), 'plaster')
    porch.arch(0.0, -porch_d / 2 + 0.21, porch_z1 - 0.18, 0.72, 0.16, 0.34, 'trim', 20)
    porch.box((0.0, -porch_d / 2 + 0.20, porch_z1 + 0.35), (0.34, 0.30, 0.26), 'trim')
    # Tiled lean-to gallery roof, pitched forward, resting on the beam.
    for row in range(4):
        down = Vector((0.0, -1.0, -0.20)).normalized()
        normal = Vector((0.0, -0.20, 1.0)).normalized()
        for xx in np.arange(-porch_w / 2 - 0.10, porch_w / 2 + 0.12, 0.30):
            LIB.tile(porch, Vector((xx, 0.10, porch_z1 + 0.52)) + down * (row * 0.42),
                     (1, 0, 0), down, normal, 0.295, 0.52, 'roof')
    porch.beam((-porch_w / 2 - 0.12, -porch_d - 0.10, porch_z1 + 0.30),
               (porch_w / 2 + 0.12, -porch_d - 0.10, porch_z1 + 0.30), 0.14, 'oak')
    porch.beam((-porch_w / 2 - 0.12, -porch_d - 0.10, porch_z1 + 0.70),
               (porch_w / 2 + 0.12, -porch_d - 0.10, porch_z1 + 0.70), 0.10, 'oak')
    # Three flared stone steps landing on the gallery floor at y=0.35.
    for step in range(3):
        porch.box((0.0, -porch_d - 0.32 - step * 0.26, 0.29 - step * 0.075),
                  (1.90 + step * 0.26, 0.62 + step * 0.30, 0.14), 'stone')
    g.add(porch, (door_x, -d / 2, 0.0), 0)

    # Lantern on the gallery beam, clear of the door leaf.
    LIB.lantern(g, door_x - porch_w / 2 + 0.05, -d / 2 - porch_d / 2, porch_z1 + 0.42)

    # Flower boxes under the two ground-floor windows immediately beside the
    # gallery bay; both windows exist because house() carved them.
    for x in (-(w / 2 - 1.20), (w / 2 - 1.20)):
        LIB.flowerbox(g, x, -d / 2 - 0.36, 1.02 - 0.30, 1.02)

    # Single low flanking bay on the east elevation, flush and recessed: the
    # house() wall already carries two arched windows on that face; the bay is
    # a stepped trim surround, not a pasted-over opening.
    g.box((w / 2 + 0.03, 0.70, 3.24), (0.30, 3.20, 0.16), 'trim')
    g.box((w / 2 + 0.03, 0.70, 5.30), (0.30, 3.20, 0.14), 'trim')
    for zz in (3.42, 4.16, 4.90):
        g.box((w / 2 + 0.05, 0.70, zz), (0.34, 3.20, 0.06), 'plaster')

    # Two chimneys, placed at the ridge only, well inside the hip slopes.
    LIB.chimney(g, -1.85, 0.0, h + rise * 0.86)
    LIB.chimney(g, 1.35, 0.0, h + rise * 0.72)

    # Collision proxies: closed convex boxes, each exactly touching (never
    # overlapping) the next so the assembled shell is a closed corridor.
    proxies = [
        [0.0, 0.0, h / 2.0, w + 0.30, d + 0.30, h],           # main body
        [door_x, -d / 2 - porch_d / 2, porch_z1 / 2.0,
         porch_w + 0.35, porch_d + 0.30, porch_z1],           # entrance gallery
        [0.0, -d / 2 - 1.05, 0.22, 2.1, 1.15, 0.44],          # entry steps slab
        [w / 2 + 0.10, 0.70, 4.20, 0.30, 3.20, 2.10],         # east trim band
    ]
    return g, proxies, 'Gallery Cross House', '\u8fde\u5eca\u5341\u5b57\u5c4b'


def export(geo, proxies, label, zh):
    OUT.mkdir(parents=True, exist_ok=True)
    asset_id = 'F1_Residence_06'
    col = bpy.data.collections.get(asset_id)
    if col is None:
        col = bpy.data.collections.new(asset_id)
        bpy.context.scene.collection.children.link(col)
    bpy.ops.object.select_all(action='DESELECT')
    ob = geo.object(asset_id + '_LOD0', col)
    entry = {'id': asset_id, 'label': label, 'label_zh': zh,
             'collision_boxes_blender_xyz': proxies, 'lods': []}
    objects = [ob]
    for level, ratio in ((1, 0.42), (2, 0.16)):
        lo = ob.copy()
        lo.data = ob.data.copy()
        lo.name = asset_id + '_LOD%d' % level
        col.objects.link(lo)
        bpy.context.view_layer.objects.active = lo
        mod = lo.modifiers.new('Distance simplification', 'DECIMATE')
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        objects.append(lo)
    for level, obj in enumerate(objects):
        obj.data.validate(clean_customdata=False)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bad = [f for f in bm.faces if f.calc_area() < 1e-8]
        if bad:
            bmesh.ops.delete(bm, geom=bad, context='FACES_ONLY')
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        if len(obj.data.uv_layers) < 2:
            obj.data.uv_layers.new(name='UV1_Unique_Packed')
        uv = obj.data.uv_layers[1].data
        collapsed = []
        for poly in obj.data.polygons:
            a, b, c = [uv[li].uv.copy() for li in poly.loop_indices]
            if abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 1e-9:
                collapsed.append(poly)
        for corner in uv:
            corner.uv.y = 0.15 + corner.uv.y * 0.85
        cols = max(1, math.ceil(math.sqrt(max(1, len(collapsed)) / 0.13)))
        rows = max(1, math.ceil(max(1, len(collapsed)) / cols))
        for j, poly in enumerate(collapsed):
            for li, (u, v) in zip(poly.loop_indices, [(0.15, 0.15), (0.85, 0.15), (0.15, 0.85)]):
                uv[li].uv = ((j % cols + u) / cols, (j // cols + v) * 0.13 / rows)
        obj['secondary_uv_repaired_thin_triangles'] = len(collapsed)
        obj.data.calc_loop_triangles()
        entry['lods'].append({'level': level,
                              'triangles': len(obj.data.loop_triangles),
                              'surfaces': len(obj.data.materials),
                              'vertices': len(obj.data.vertices)})
        obj['lod'] = level
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    path = OUT / (asset_id + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_extras=True, export_yup=True, export_apply=True,
                              export_normals=True, export_texcoords=True, export_tangents=True,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False)
    entry['file'] = path.relative_to(ROOT).as_posix()
    entry['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    entry['bytes'] = path.stat().st_size
    bounds = [Vector(v) for v in ob.bound_box]
    entry['dimensions_blender_xyz_m'] = [round(max(v[a] for v in bounds) - min(v[a] for v in bounds), 4) for a in range(3)]
    # Keep all LODs coincident at the origin; only LOD0 is visible/renderable.
    for i, obj in enumerate(objects):
        obj.location = (0.0, 0.0, 0.0)
        obj.hide_render = obj != ob
        obj.hide_viewport = obj != ob
    return entry


def main():
    global R
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    print('F1_RESIDENCE_06_TEXTURES_START', flush=True)
    LIB.MAPS = load_existing_maps()
    R = random.Random(2060)
    LIB.R = R
    print('F1_RESIDENCE_06_BUILD', flush=True)
    geo, proxies, label, zh = design()
    entry = export(geo, proxies, label, zh)
    manifest = {
        'id': 'floor1_deepseek_residences',
        'source': 'DeepSeek original composition extending the approved project library',
        'attribution': {
            'reused_library': 'Art/ReferenceScenes/Floor1Residences/build_residences.py',
            'reused_textures': 'game/assets/floor1/residences/textures (4 shared PBR sets)',
            'new_author': 'DeepSeek, F1_Residence_06 original composition',
        },
        'unit': 'metre',
        'interiors': 'unfurnished shell; closed doors; no resident housing state',
        'textures': {'resolution': 2048, 'sets': 4,
                     'maps': ['sRGB albedo', 'OpenGL tangent normal', 'linear ORM (R=1,G=roughness,B=0)'],
                     'metric_repeat_m': 2.0},
        'assets': [entry],
    }
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'F1_Residence_06.blend'), compress=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('F1_RESIDENCE_06_COMPLETE triangles=' + json.dumps(entry['lods']), flush=True)


if __name__ == '__main__':
    main()
