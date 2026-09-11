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
# entrance gallery. The library house() already carves the front door, its
# three front steps, the upper-floor flowerboxes and ONE chimney; this file
# adds only the open gallery, the two lower flowerboxes under the real lower
# windows, and the collision proxies. Load-bearing members intentionally
# intersect and seat on one another (plinths into landing, capitals into
# lintel, rafters into beams and wall) as normal masonry/timber construction.
# Warm stone base / pale plaster / desaturated teal shutters / terracotta
# clay roof.
#
# Scoped suppression: the inherited upper-front flowerbox at local front-face
# x=-2.4666667, y=-.36, z=3.62 (width 1.04) would occupy the new porch roof
# plane near z=3.798 and sprout through the tiles. It is suppressed ONLY for
# this house by a temporary wrapper around LIB.flowerbox during the
# LIB.house() call; the original is restored in finally and other houses are
# unaffected. The unaffected upper-right flowerbox and both valid lower-front
# flowerboxes remain.
# ---------------------------------------------------------------------------
def design():
    """Return (geo, proxies, label, label_zh, params).

    Silhouette: squat tall-windowed double-pile body (7.4 x 6.4 m, 2 storeys)
    with a steep hip terracotta clay roof. A projecting single-storey front
    gallery (recessed round arch, closed door, two square piers with a tiled
    lean-to roof) is built outward from the facade rather than through it, so
    the main body wall stays intact behind the porch. The gallery is open and
    traversable up to the closed front door. The library already provides the
    three front steps at x=-1.75; this file adds three broad ground-seated
    exterior treads continuing forward from the landing so the approach is
    physically coherent, and buries the library steps inside that solid
    approach volume without editing the shared library.
    """
    w, d, floors = 7.4, 6.4, 2

    # Scoped suppression of the inherited upper-front flowerbox that would
    # conflict with the porch roof. Condition is in the library's local
    # front-face coordinates: x near -2.4666667, y near -0.36, z near 3.62.
    _orig_flowerbox = LIB.flowerbox

    def _suppressed_flowerbox(g, x, y, z, ww):
        if abs(x - (-2.4666667)) < 0.05 and abs(y - (-0.36)) < 0.05 and abs(z - 3.62) < 0.05:
            return
        return _orig_flowerbox(g, x, y, z, ww)

    LIB.flowerbox = _suppressed_flowerbox
    try:
        g, h, rise = LIB.house(w, d, floors, 'plaster', 'blueshutter', 'roof',
                               hip=True, doorx=-1.75, balcony_x=None)
    finally:
        LIB.flowerbox = _orig_flowerbox

    # Door was carved at x=-1.75; the gallery arch is centred at the same x so
    # the closed door reads through the arch instead of two competing doors.
    door_x = -1.75
    porch_w = 2.35
    porch_d = 1.35
    # Front face of the main body is y=-3.2; the gallery sits in front of it.
    front_y = -d / 2.0
    # Landing sits on top of the library steps; the library steps are buried
    # inside the new solid approach volume and do not poke out as treads.
    landing_z = 0.35
    landing_y0 = front_y - porch_d
    landing_y1 = front_y

    # Coherent vertical stack: landing -> plinth -> pier -> capital -> lintel
    # -> rafters -> deck -> tile surface. Arch springs from the piers at 2.30
    # with small impost blocks; its outer crown stays below the tile surface.
    plinth_h = 0.36
    capital_h = 0.12
    lintel_h = 0.30
    lintel_z0 = landing_z + plinth_h + (3.23 - landing_z - plinth_h - capital_h) + capital_h
    # lintel_z0 = 3.23 (top of capital), lintel spans 3.23..3.53
    lintel_z1 = lintel_z0 + lintel_h
    # Arch: spring at 2.30, inner radius 0.72, outer radius 0.88.
    arch_spring = 2.30
    arch_r_inner = 0.72
    arch_r_outer = 0.88
    arch_crown_outer = arch_spring + arch_r_outer
    # ONE roof plane: z_at_y = roof_origin_z + roof_slope * (y - roof_origin_y).
    # Origin is the wall-side high edge; slope is positive going forward
    # (y decreases), so the plane descends toward the front piers.
    roof_origin_y = front_y - 0.05
    roof_origin_z = 3.86
    roof_slope = 0.20
    # Front pier y and the plane height there.
    pier_y = landing_y0 + 0.20
    roof_z_at_pier = roof_origin_z + roof_slope * (pier_y - roof_origin_y)
    # Cross-beam centres at plane-0.13: a .14 m cross-beam top becomes
    # plane-0.06, fitting below the deck and lapping/supporting the rafters
    # without punching through tiles.
    front_beam_z = roof_z_at_pier - 0.13
    wall_beam_z = roof_origin_z - 0.13
    # Rafter centreline sits under the tile plane by half the rafter thickness
    # plus the tile base offset, so timber never punches through tiles.
    rafter_thickness = 0.10
    rafter_under_offset = 0.06 + rafter_thickness / 2.0
    # Solid timber roof deck between rafters and tiles, derived from the same
    # roof plane. Deck thickness fills the gap between rafter tops and the
    # tile underside; deck top sits just below the tile base.
    deck_thickness = 0.06

    # Tile geometry: rows run FORWARD from the wall-side origin along the
    # down-vector. Derive the actual tile eave from row geometry so deck and
    # rafters extend to the real tile edge.
    tile_len = 0.52
    row_pitch = 0.42
    rows = 4
    tile_width = 0.295
    down = Vector((0.0, -1.0, -roof_slope)).normalized()
    normal = Vector((0.0, -roof_slope, 1.0)).normalized()
    # Furthest down-vector offset of the last row's tile tip.
    tile_eave_offset = (rows - 1) * row_pitch + tile_len
    tile_eave_y = roof_origin_y + down.y * tile_eave_offset
    tile_eave_z = roof_origin_z + down.z * tile_eave_offset
    # Deck ends approximately .02-.03 m inboard of the exact tile eave.
    deck_inboard = 0.025
    deck_y_eave = tile_eave_y + deck_inboard
    deck_z_eave_top = roof_origin_z + roof_slope * (deck_y_eave - roof_origin_y)
    deck_y_wall = roof_origin_y
    deck_z_wall_top = roof_origin_z
    # Actual tile X centres: build the list once and use it BOTH for placing
    # tiles and for calculating min/max coverage. Deck is 2 cm inboard of the
    # actual first/last tile edges.
    tile_x_centres = list(np.arange(door_x - porch_w / 2.0 - 0.10,
                                    door_x + porch_w / 2.0 + 0.12, 0.30))
    tile_x_min = min(tile_x_centres) - tile_width / 2.0
    tile_x_max = max(tile_x_centres) + tile_width / 2.0
    deck_x_min = tile_x_min + 0.02
    deck_x_max = tile_x_max - 0.02
    assert deck_x_min > min(tile_x_centres) - tile_width / 2.0
    assert deck_x_max < max(tile_x_centres) + tile_width / 2.0
    assert deck_x_max - deck_x_min > 0.0

    porch = LIB.Geo()
    # Real landing slab seated on the library steps, spanning the gallery bay.
    porch.box((door_x, (landing_y0 + landing_y1) / 2.0, landing_z / 2.0),
              (porch_w + 0.30, porch_d, landing_z), 'stone')
    # Two square piers with plinths and capitals, seated on the landing and
    # clear of the full entrance approach width (door clear opening x=[-2.42,-1.08]).
    pier_x = (door_x - porch_w / 2.0 + 0.16, door_x + porch_w / 2.0 - 0.16)
    for px in pier_x:
        # Plinth seated into the landing.
        porch.box((px, pier_y, landing_z + plinth_h / 2.0),
                  (0.40, 0.40, plinth_h), 'stone')
        # Shaft from plinth top to capital bottom.
        shaft_z0 = landing_z + plinth_h
        shaft_z1 = lintel_z0 - capital_h
        porch.box((px, pier_y, (shaft_z0 + shaft_z1) / 2.0),
                  (0.30, 0.30, shaft_z1 - shaft_z0), 'plaster')
        # Capital seated under the lintel.
        porch.box((px, pier_y, shaft_z1 + capital_h / 2.0),
                  (0.42, 0.42, capital_h), 'trim')
    # Lintel/arch beam seated on the capitals, spanning pier to pier.
    porch.box((door_x, pier_y, lintel_z0 + lintel_h / 2.0),
              (porch_w, 0.42, lintel_h), 'plaster')
    # Small impost blocks at the arch springing, seated on the pier shafts.
    for px in pier_x:
        porch.box((px, pier_y + 0.21, arch_spring - 0.06),
                  (0.34, 0.34, 0.12), 'trim')
    # Round arch springing from the impost blocks at 2.30, crown below tiles.
    porch.arch(door_x, pier_y + 0.21, arch_spring, arch_r_inner, 0.16, 0.34, 'trim', 20)
    # Front structural beam under the tile surface, seated on the lintel.
    porch.beam((door_x - porch_w / 2.0 - 0.12, pier_y, front_beam_z),
               (door_x + porch_w / 2.0 + 0.12, pier_y, front_beam_z), 0.14, 'oak')
    # Wall-side connection beam, seated into the wall.
    porch.beam((door_x - porch_w / 2.0 - 0.12, roof_origin_y, wall_beam_z),
               (door_x + porch_w / 2.0 + 0.12, roof_origin_y, wall_beam_z), 0.14, 'oak')
    # Sloped rafters between front and rear supports, under the deck, extended
    # to the actual tile eave so the deck is continuously supported.
    rafter_count = 7
    for i in range(rafter_count):
        rx = door_x - porch_w / 2.0 + (i + 0.5) * porch_w / rafter_count
        rz_front = roof_z_at_pier - rafter_under_offset
        rz_wall = roof_origin_z - rafter_under_offset
        rz_eave = deck_z_eave_top - rafter_under_offset
        porch.beam((rx, pier_y, rz_front),
                   (rx, roof_origin_y, rz_wall), rafter_thickness, 'oak')
        porch.beam((rx, pier_y, rz_front),
                   (rx, deck_y_eave, rz_eave), rafter_thickness, 'oak')
    # Solid timber roof deck between rafters and tiles, derived from the same
    # roof plane. Built as an explicit 8-vertex closed sloped hexahedral slab
    # with 4 upper corners on the z_at_y plane and 4 lower corners exactly
    # deck_thickness below them. All six faces wound outward; a local
    # cross-product assertion validates outward normals against the slab
    # centre before the deck is added.
    deck_verts = [
        (deck_x_min, deck_y_wall, deck_z_wall_top),
        (deck_x_max, deck_y_wall, deck_z_wall_top),
        (deck_x_max, deck_y_eave, deck_z_eave_top),
        (deck_x_min, deck_y_eave, deck_z_eave_top),
        (deck_x_min, deck_y_wall, deck_z_wall_top - deck_thickness),
        (deck_x_max, deck_y_wall, deck_z_wall_top - deck_thickness),
        (deck_x_max, deck_y_eave, deck_z_eave_top - deck_thickness),
        (deck_x_min, deck_y_eave, deck_z_eave_top - deck_thickness),
    ]
    deck_faces = [
        (0, 3, 2, 1),   # top, outward +Z
        (4, 5, 6, 7),   # bottom, outward -Z
        (0, 1, 5, 4),   # wall side
        (1, 2, 6, 5),   # +X side
        (2, 3, 7, 6),   # eave side
        (3, 0, 4, 7),   # -X side
    ]
    slab_center = Vector((
        sum(v[0] for v in deck_verts) / 8.0,
        sum(v[1] for v in deck_verts) / 8.0,
        sum(v[2] for v in deck_verts) / 8.0,
    ))
    for face in deck_faces:
        p0 = Vector(deck_verts[face[0]])
        p1 = Vector(deck_verts[face[1]])
        p2 = Vector(deck_verts[face[2]])
        face_center = (p0 + p1 + p2 + Vector(deck_verts[face[3]])) / 4.0
        face_normal = (p1 - p0).cross(p2 - p0)
        assert face_normal.dot(face_center - slab_center) > 0.0, 'deck face winding not outward'
    porch.mesh(deck_verts, deck_faces, 'oak')
    # Tiled lean-to gallery roof: origin at the WALL-side high edge, rows run
    # FORWARD over the actual gallery to the front piers. Tile length 0.52,
    # so the full tile extent covers from the wall edge forward past the piers.
    for row in range(rows):
        for xx in tile_x_centres:
            LIB.tile(porch,
                     Vector((xx, roof_origin_y, roof_origin_z)) + down * (row * row_pitch),
                     (1, 0, 0), down, normal, tile_width, tile_len, 'roof')

    # Three broad ground-seated exterior treads continuing forward from the
    # landing at x=-1.75, with gradual rises up to landing_z=0.35. Walking
    # FROM the street TOWARD the landing must rise 0 -> .0875 -> .175 ->
    # .2625 -> .35, so the tread nearest the landing is the highest and the
    # farthest tread is the lowest. The library steps are buried inside this
    # solid approach volume and do not poke out as treads.
    tread_rises = (0.0875, 0.175, 0.2625)
    tread_depth = 0.30
    tread_width = 1.86
    treads = []
    for i, rz in enumerate(tread_rises):
        # i=0 is the farthest tread (lowest), i=2 is nearest the landing
        # (highest). y decreases going away from the landing.
        ty = landing_y0 - (len(tread_rises) - i - 0.5) * tread_depth
        treads.append((door_x, ty, rz / 2.0, tread_width, tread_depth, rz))
        porch.box((door_x, ty, rz / 2.0), (tread_width, tread_depth, rz), 'stone')

    # Add the entire porch (piers, lintel, arch, beams, rafters, deck, tiles,
    # treads) to the main geometry EXACTLY ONCE.
    g.add(porch, (0.0, 0.0, 0.0), 0)

    # Lower flowerboxes only below the two real lower windows at x=0 and
    # x=2.4666667; the bay at x=-2.5 is the door and gets no flowerbox.
    # The library door-side wall lantern is preserved; no extra porch lantern
    # is added because it would sit on/poke above the roof edge.
    for x in (0.0, 2.4666667):
        LIB.flowerbox(g, x, front_y - 0.36, 1.02 - 0.30, 1.02)

    # No east facade bands: the library already carries the real upper and
    # right-side window cut holes, and decorative bands would cross them.

    # Keep only the ONE library chimney; no gratuitous new chimneys.

    # Collision proxies: constituent piers, landing, treads and overhead
    # elements instead of a solid full-porch slab. The main body collider
    # remains solid. Each support collider is derived from the actual landing
    # or tread box geometry, so downward-ray support agrees with the visible
    # support height. No raised slab covers several differing tread heights.
    proxies = [
        [0.0, 0.0, h / 2.0, w + 0.30, d + 0.30, h],           # main body
        # Landing slab under the gallery, seated on the library steps.
        [door_x, (landing_y0 + landing_y1) / 2.0, landing_z / 2.0,
         porch_w + 0.30, porch_d, landing_z],
        # Two piers.
        [pier_x[0], pier_y, landing_z + (lintel_z0 - landing_z) / 2.0,
         0.42, 0.42, lintel_z0 - landing_z],
        [pier_x[1], pier_y, landing_z + (lintel_z0 - landing_z) / 2.0,
         0.42, 0.42, lintel_z0 - landing_z],
        # Lintel/arch beam overhead.
        [door_x, pier_y, lintel_z0 + lintel_h / 2.0, porch_w, 0.42, lintel_h],
    ]
    # Exact tread colliders derived from the actual tread boxes.
    for tx, ty, tz, tw, td, th in treads:
        proxies.append([tx, ty, tz, tw, td, th])
    return g, proxies, 'Gallery House', '\u8fde\u5eca\u5c4b', {
        'door_x': door_x,
        'porch_width': porch_w,
        'porch_depth': porch_d,
        'landing_z': landing_z,
        'landing_y0': landing_y0,
        'landing_y1': landing_y1,
        'pier_count': 2,
        'pier_y': pier_y,
        'arch_spring_z': arch_spring,
        'arch_inner_radius': arch_r_inner,
        'arch_outer_radius': arch_r_outer,
        'arch_crown_outer_z': arch_crown_outer,
        'lintel_z0': lintel_z0,
        'lintel_z1': lintel_z1,
        'roof_origin_y': roof_origin_y,
        'roof_origin_z': roof_origin_z,
        'roof_slope': roof_slope,
        'roof_z_at_pier': roof_z_at_pier,
        'front_beam_z': front_beam_z,
        'wall_beam_z': wall_beam_z,
        'deck_thickness': deck_thickness,
        'tile_eave_y': tile_eave_y,
        'tile_eave_z': tile_eave_z,
        'deck_y_wall': deck_y_wall,
        'deck_y_eave': deck_y_eave,
        'deck_z_wall_top': deck_z_wall_top,
        'deck_z_eave_top': deck_z_eave_top,
        'deck_x_min': deck_x_min,
        'deck_x_max': deck_x_max,
        'tile_x_min': tile_x_min,
        'tile_x_max': tile_x_max,
        'tile_len': tile_len,
        'tile_width': tile_width,
        'row_pitch': row_pitch,
        'rows': rows,
        'tread_rises': list(tread_rises),
        'tread_depth': tread_depth,
        'tread_width': tread_width,
        'suppressed_inherited_upper_front_flowerbox': True,
    }


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
    # Robust pre-export cleanup: reject triangulated faces whose stored mesh
    # coordinates contain a near-coincident edge (micron-scale threshold) or
    # whose cross-product area is below a robust threshold, in addition to the
    # existing calc_area check. This removes numerical slivers without welding
    # or mutating valid geometry.
    EDGE_EPS = 1e-6
    AREA_EPS = 1e-10
    for level, obj in enumerate(objects):
        obj.data.validate(clean_customdata=False)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bad = []
        for f in bm.faces:
            if f.calc_area() < 1e-8:
                bad.append(f)
                continue
            vs = [v.co for v in f.verts]
            if len(vs) < 3:
                bad.append(f)
                continue
            degenerate = False
            for i in range(len(vs)):
                a = vs[i]
                b = vs[(i + 1) % len(vs)]
                if (a - b).length < EDGE_EPS:
                    degenerate = True
                    break
            if not degenerate:
                cross = (vs[1] - vs[0]).cross(vs[2] - vs[0])
                if cross.length < AREA_EPS:
                    degenerate = True
            if degenerate:
                bad.append(f)
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
    geo, proxies, label, zh, params = design()
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
        'porch_design': {
            'type': 'open entrance gallery',
            'door_x': params['door_x'],
            'porch_width': params['porch_width'],
            'porch_depth': params['porch_depth'],
            'landing_z': params['landing_z'],
            'landing_y0': params['landing_y0'],
            'landing_y1': params['landing_y1'],
            'pier_count': params['pier_count'],
            'pier_y': params['pier_y'],
            'arch_spring_z': params['arch_spring_z'],
            'arch_inner_radius': params['arch_inner_radius'],
            'arch_outer_radius': params['arch_outer_radius'],
            'arch_crown_outer_z': params['arch_crown_outer_z'],
            'lintel_z0': params['lintel_z0'],
            'lintel_z1': params['lintel_z1'],
            'roof_origin_y': params['roof_origin_y'],
            'roof_origin_z': params['roof_origin_z'],
            'roof_slope': params['roof_slope'],
            'roof_z_at_pier': params['roof_z_at_pier'],
            'front_beam_z': params['front_beam_z'],
            'wall_beam_z': params['wall_beam_z'],
            'deck_thickness': params['deck_thickness'],
            'tile_eave_y': params['tile_eave_y'],
            'tile_eave_z': params['tile_eave_z'],
            'deck_y_wall': params['deck_y_wall'],
            'deck_y_eave': params['deck_y_eave'],
            'deck_z_wall_top': params['deck_z_wall_top'],
            'deck_z_eave_top': params['deck_z_eave_top'],
            'deck_x_min': params['deck_x_min'],
            'deck_x_max': params['deck_x_max'],
            'tile_x_min': params['tile_x_min'],
            'tile_x_max': params['tile_x_max'],
            'tile_len': params['tile_len'],
            'tile_width': params['tile_width'],
            'row_pitch': params['row_pitch'],
            'rows': params['rows'],
            'tread_rises': params['tread_rises'],
            'tread_depth': params['tread_depth'],
            'tread_width': params['tread_width'],
            'entry_steps': 'three broad ground-seated exterior treads continuing forward from the landing at x=-1.75; library steps buried inside this solid approach volume',
            'suppressed_inherited_upper_front_flowerbox': params['suppressed_inherited_upper_front_flowerbox'],
        },
        'element_roles': {
            'main_body': 'closed two-storey exterior shell',
            'porch': 'open traversable entrance gallery',
            'flowerboxes': 'lower flowerboxes under real lower windows only; inherited upper-front flowerbox suppressed to avoid roof conflict',
            'chimney': 'one library chimney only',
            'lantern': 'library door-side wall lantern only; no extra porch lantern',
            'roof_deck': 'solid sloped timber deck between rafters and tiles, extended to the actual tile eave',
        },
        'assets': [entry],
    }
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'F1_Residence_06.blend'), compress=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('F1_RESIDENCE_06_COMPLETE triangles=' + json.dumps(entry['lods']), flush=True)


if __name__ == '__main__':
    main()
