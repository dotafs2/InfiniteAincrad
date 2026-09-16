"""Author three modular floor-1 house shells (cottage / merchant / L-plan corner) for Blender 5.2.

Run:
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup \
    --python Art/Generated/Floor1Modular20260916/build_modular_houses.py -- \
    --house all --out game/assets/floor1/modular_houses_20260916 \
    --renders Art/Generated/Floor1Modular20260916/renders

Geometry rules from the first review pass:
  * the roof is ONE closed triangular prism (eave - ridge - eave, with a bottom face), so no flat slab
    floats above the slopes and the end gables are plain walls under the roof;
  * every facade (front, back, both sides) carries real openings with frames, placed with the facade
    normal - never a front-facing window floated against a side wall;
  * every object gets a normals-consistent pass, so no inside-out triangle can leak a walker through a
    wall.
Authored low-poly replacements derived from the Meshy concept art - not semantic segmentation of a
one-piece generated mesh.
"""
import argparse
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
PALETTE = {"stone": "C8BCA1", "trim": "D7C5A4", "mortar": "AFA58F",
           "canvas": "D9C8AA", "leaf": "799374", "flower": "BF8779",
           "interior": "405453", "plaster": "EEE3CB", "rose": "DBC1B2",
           "oak": "8B694D", "darkwood": "534B3E", "door": "93714D", "shutter": "68877F",
           "blueshutter": "5D7C83", "roof": "B46E5A", "roof_b": "AF6B58", "roof_c": "B8725D",
           "slate": "71898C", "iron": "465454", "glass": "3F6669", "soil": "514A39",
           "sign": "E7DCC0", "ground": "C9C6BE"}
ROUGH = {"glass": 0.15, "iron": 0.45, "stone": 0.85, "trim": 0.8,
         "mortar": 0.9, "canvas": 0.9, "leaf": 0.8, "flower": 0.85,
         "interior": 0.95, "plaster": 0.8, "rose": 0.8,
         "oak": 0.7, "darkwood": 0.7, "door": 0.6, "shutter": 0.65, "blueshutter": 0.65,
         "roof": 0.72, "roof_b": 0.72, "roof_c": 0.72, "slate": 0.7, "soil": 0.95, "sign": 0.7,
         "ground": 0.9}
WALL = 0.26
DOOR_W, DOOR_H = 1.20, 2.20
WIN_W, WIN_H = 1.05, 1.30
WIN_SILL = 0.95


def linear(hex_code):
    values = [int(hex_code[index:index + 2], 16) / 255 for index in (0, 2, 4)]
    return tuple(v / 12.92 if v < 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values)


class Mesh:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.roles = []

    def quad(self, points, role):
        base = len(self.vertices)
        self.vertices.extend(points)
        self.faces.append((base, base + 1, base + 2, base + 3))
        self.roles.append(role)

    def tri(self, points, role):
        base = len(self.vertices)
        self.vertices.extend(points)
        self.faces.append((base, base + 1, base + 2))
        self.roles.append(role)

    def box(self, centre, size, role, yaw=0.0, pitch=0.0, roll=0.0):
        cx, cy, cz = centre
        sx, sy, sz = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
        corners = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
                   (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        cos_r, sin_r = math.cos(roll), math.sin(roll)
        cos_p, sin_p = math.cos(pitch), math.sin(pitch)
        cos_y, sin_y = math.cos(yaw), math.sin(yaw)
        out = []
        for x, y, z in corners:
            x, z = x * cos_r + z * sin_r, -x * sin_r + z * cos_r
            y, z = y * cos_p - z * sin_p, y * sin_p + z * cos_p
            x, y = x * cos_y - y * sin_y, x * sin_y + y * cos_y
            out.append((cx + x, cy + y, cz + z))
        # Every face is authored outward. The old bottom winding faced into the solid;
        # recalculating normals on disconnected per-face vertices could not repair it.
        for face in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.quad([out[index] for index in face], role)

    def prism(self, profile, extrude0, extrude1, role, axis="x"):
        """Closed solid from a convex profile [(a, b), ...] extruded along `axis`."""
        def point(a, b, e):
            if axis == "x":
                return (e, a, b)
            if axis == "y":
                return (a, e, b)
            return (a, b, e)
        count = len(profile)
        for index in range(count):
            first, second = profile[index], profile[(index + 1) % count]
            self.quad([point(first[0], first[1], extrude0), point(second[0], second[1], extrude0),
                       point(second[0], second[1], extrude1), point(first[0], first[1], extrude1)], role)
        for index in range(1, count - 1):
            self.tri([point(profile[0][0], profile[0][1], extrude0),
                      point(profile[index][0], profile[index][1], extrude0),
                      point(profile[index + 1][0], profile[index + 1][1], extrude0)], role)
            self.tri([point(profile[0][0], profile[0][1], extrude1),
                      point(profile[index + 1][0], profile[index + 1][1], extrude1),
                      point(profile[index][0], profile[index][1], extrude1)], role)

    def to_object(self, name, collection):
        if not self.vertices:
            return None
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.validate()
        mesh.update()
        shutter_atlas = name.startswith("Shutter_")
        roles = ["shutter_atlas"] if shutter_atlas else sorted(set(self.roles))
        for role in roles:
            mesh.materials.append(material(role))
        for polygon, role in zip(mesh.polygons, self.roles):
            polygon.material_index = 0 if shutter_atlas else roles.index(role)
            polygon.use_smooth = False
        if shutter_atlas:
            # One opaque surface per movable leaf. Constant UVs per face sample
            # the exact three baseline colors from a shared tiny palette atlas.
            uv = mesh.uv_layers.new(name="UVMap")
            samples = {"shutter": (1.0 / 6.0, 0.5),
                       "blueshutter": (0.5, 0.5), "oak": (5.0 / 6.0, 0.5)}
            for polygon, role in zip(mesh.polygons, self.roles):
                for loop_index in polygon.loop_indices:
                    uv.data[loop_index].uv = samples[role]
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        return obj


_MATERIALS = {}


def material(role):
    if role in _MATERIALS:
        return _MATERIALS[role]
    data = bpy.data.materials.new("Floor1_" + role)
    data.use_nodes = True
    shader = data.node_tree.nodes["Principled BSDF"]
    colour = linear(PALETTE.get(role, "CCCCCC"))
    shader.inputs["Base Color"].default_value = (colour[0], colour[1], colour[2], 1.0)
    shader.inputs["Roughness"].default_value = ROUGH.get(role, 0.8)
    if role == "shutter_atlas":
        image = bpy.data.images.get("Floor1_shutter_palette")
        if image is None:
            image = bpy.data.images.new("Floor1_shutter_palette", width=12, height=4, alpha=True)
            pixels = []
            for _y in range(4):
                for x in range(12):
                    shade = ("shutter", "blueshutter", "oak")[x // 4]
                    code = PALETTE[shade]
                    pixels.extend((*(int(code[i:i + 2], 16) / 255.0 for i in (0, 2, 4)), 1.0))
            image.pixels[:] = pixels
            image.file_format = "PNG"
            image.pack()
        tex = data.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Closest"
        data.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = 0.65
    if role == "glass":
        shader.inputs["Alpha"].default_value = 0.35
        data.blend_method = "BLEND"
    data.diffuse_color = (colour[0], colour[1], colour[2], 1.0)
    _MATERIALS[role] = data
    return data


def fix_normals(obj):
    bpy.context.view_layer.objects.active = obj
    for item in bpy.context.selected_objects:
        item.select_set(False)
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


# ------------------------------------------------------------------ walls ----


def wall(mesh, axis, offset, u0, u1, z0, z1, openings, role, gaps=(), thickness=WALL):
    """Partition a facade in both coordinates; omit the union of all real holes.

    Openings outside this floor's height never influence its wall. The same routine is
    used for stone courses so decoration cannot bridge a door or window aperture.
    """
    if u1 <= u0 or z1 <= z0:
        return
    local = []
    for item in openings:
        a, b = max(u0, item["u0"]), min(u1, item["u1"])
        c, d = max(z0, item["z0"]), min(z1, item["z1"])
        if b - a > 1e-6 and d - c > 1e-6:
            local.append((a, b, c, d))
    for a, b in gaps:
        a, b = max(u0, a), min(u1, b)
        if b - a > 1e-6:
            local.append((a, b, z0, z1))
    us = sorted({u0, u1, *(v for a, b, _, _ in local for v in (a, b))})
    zs = sorted({z0, z1, *(v for _, _, c, d in local for v in (c, d))})
    for ia in range(len(us) - 1):
        ua, ub = us[ia], us[ia + 1]
        for iz in range(len(zs) - 1):
            za, zb = zs[iz], zs[iz + 1]
            um, zm = (ua + ub) * 0.5, (za + zb) * 0.5
            if any(a < um < b and c < zm < d for a, b, c, d in local):
                continue
            _piece(mesh, axis, offset, ua, ub, za, zb, role, thickness)


def _piece(mesh, axis, offset, u0, u1, z0, z1, role, thickness):
    span, height = u1 - u0, z1 - z0
    if span <= 1e-6 or height <= 1e-6:
        return
    if axis == "x":
        mesh.box(((u0 + u1) * 0.5, offset, (z0 + z1) * 0.5), (span, thickness, height), role)
    else:
        mesh.box((offset, (u0 + u1) * 0.5, (z0 + z1) * 0.5), (thickness, span, height), role)


# ------------------------------------------------------- window / door modules ----


def window_local_mesh():
    frame = Mesh()
    jamb = 0.10
    # The frame is an open rectangle: the travelling sash alone seals the wall hole.
    for side in (-1, 1):
        frame.box((side * (WIN_W * 0.5 + jamb * 0.5), 0.0, WIN_H * 0.5 + jamb * 0.5),
                  (jamb, 0.20, WIN_H + jamb), "oak")
    frame.box((0.0, 0.0, WIN_H + jamb * 0.5), (WIN_W + jamb * 2, 0.20, jamb), "oak")
    frame.box((0.0, 0.0, -jamb * 0.5), (WIN_W + jamb * 2, 0.28, jamb), "oak")
    frame.box((0.0, 0.0, WIN_H * 0.5), (0.06, 0.12, WIN_H), "oak")
    frame.box((0.0, 0.0, WIN_H * 0.5), (WIN_W, 0.12, 0.06), "oak")
    return frame


def sash_local_mesh():
    sash = Mesh()
    sash.box((0.0, 0.0, WIN_H * 0.5), (WIN_W - 0.16, 0.06, WIN_H - 0.16), "glass")
    for bar in (-0.30, 0.0, 0.30):
        sash.box((bar * (WIN_W - 0.16), 0.0, WIN_H * 0.5), (0.05, 0.09, WIN_H - 0.14), "oak")
    sash.box((0.0, 0.0, 0.10), (WIN_W - 0.16, 0.09, 0.06), "oak")
    sash.box((0.0, 0.0, WIN_H - 0.14), (WIN_W - 0.16, 0.09, 0.06), "oak")
    return sash


def shutter_local_mesh(side):
    leaf = Mesh()
    # Each hinge is at the *outer* window jamb. At rest the half-leaf extends
    # inward over its own glass, not out across the neighbouring door shoulder.
    # A 100-degree pivot swing then folds it away from the aperture.
    centre_u = -side * 0.28
    leaf.box((centre_u, 0.0, WIN_H * 0.5), (0.53, 0.055, WIN_H - 0.04), "shutter")
    leaf.box((centre_u, 0.0, WIN_H * 0.5), (0.43, 0.075, WIN_H - 0.34), "blueshutter")
    for z in (0.26, 0.65, 1.04):
        leaf.box((centre_u, 0.044, z), (0.42, 0.025, 0.045), "oak")
    return leaf


def facade_frame(axis, outward):
    """Yaw so that a module's local +Y points along the facade outward normal."""
    if axis == "x":
        return math.pi if outward[1] < 0 else 0.0
    return math.pi / 2 if outward[0] < 0 else -math.pi / 2


def world_on_facade(axis, offset, u, yaw, along, depth, up):
    """Map a module-local (along, depth, up) offset into world space on the facade plane."""
    origin_x, origin_y = (u, offset) if axis == "x" else (offset, u)
    return (origin_x + along * math.cos(yaw) - depth * math.sin(yaw),
            origin_y + along * math.sin(yaw) + depth * math.cos(yaw), up)


def place_window(collection, index, axis, offset, u, z_base, outward):
    yaw = facade_frame(axis, outward)
    frame_obj = window_local_mesh().to_object("WindowFrame_%02d" % index, collection)
    frame_obj.location = world_on_facade(axis, offset, u, yaw, 0.0, 0.0, z_base)
    frame_obj.rotation_euler = (0.0, 0.0, yaw)
    sash_obj = sash_local_mesh().to_object("WindowSash_%02d" % index, collection)
    sash_obj.location = world_on_facade(axis, offset, u, yaw, 0.0, 0.0, z_base)
    sash_obj.rotation_euler = (0.0, 0.0, yaw)
    pivots = []
    for side, tag in ((-1, "L"), (1, "R")):
        pivot = bpy.data.objects.new("ShutterPivot_%s_%02d" % (tag, index), None)
        pivot.empty_display_size = 0.12
        collection.objects.link(pivot)
        pivot.location = world_on_facade(axis, offset, u, yaw, side * (WIN_W * 0.5 + 0.06), 0.03, z_base)
        pivot.rotation_euler = (0.0, 0.0, yaw)
        leaf = shutter_local_mesh(side).to_object("Shutter_%s_%02d" % (tag, index), collection)
        leaf.parent = pivot
        pivots.append(pivot)
    unit = bpy.data.objects.new("WindowUnit_%02d" % index, None)
    unit.empty_display_size = 0.10
    collection.objects.link(unit)
    unit.location = frame_obj.location
    unit.rotation_euler = frame_obj.rotation_euler
    for child in [frame_obj, sash_obj]:
        child.parent = unit
        child.location = (0.0, 0.0, 0.0)
        child.rotation_euler = (0.0, 0.0, 0.0)
    for side, pivot in zip((-1, 1), pivots):
        pivot.parent = unit
        pivot.location = (side * (WIN_W * 0.5 + 0.06), 0.03, 0.0)
        pivot.rotation_euler = (0.0, 0.0, 0.0)
    opening = {"kind": "window", "id": "window_%02d" % index,
               "centre": list(world_on_facade(axis, offset, u, yaw, 0.0, 0.0, z_base + WIN_H * 0.5)),
               "size": [WIN_W, WALL, WIN_H], "outward": list(outward),
               "node_window_id": "WindowSash_%02d" % index}
    return frame_obj, sash_obj, pivots, opening


def place_door(collection, axis, offset, u, outward):
    yaw = facade_frame(axis, outward)
    frame = Mesh()
    jamb = 0.12
    for side in (-1, 1):
        frame.box((side * (DOOR_W * 0.5 + jamb * 0.5), 0.0, DOOR_H * 0.5 + jamb * 0.5),
                  (jamb, 0.24, DOOR_H + jamb), "trim")
    frame.box((0.0, 0.0, DOOR_H + jamb * 0.5), (DOOR_W + jamb * 2, 0.24, jamb), "trim")
    frame_obj = frame.to_object("DoorFrame", collection)
    frame_obj.location = world_on_facade(axis, offset, u, yaw, 0.0, 0.0, 0.0)
    frame_obj.rotation_euler = (0.0, 0.0, yaw)
    pivot = bpy.data.objects.new("DoorPivot", None)
    pivot.empty_display_size = 0.22
    collection.objects.link(pivot)
    pivot.location = world_on_facade(axis, offset, u, yaw, -DOOR_W * 0.5 + 0.03, 0.0, 0.0)
    pivot.rotation_euler = (0.0, 0.0, yaw)
    leaf = Mesh()
    leaf_h = DOOR_H - 0.05
    leaf.box((DOOR_W * 0.5, 0.0, leaf_h * 0.5), (DOOR_W - 0.08, 0.09, leaf_h), "door")
    for index in range(3):
        leaf.box((0.26 + index * 0.30, 0.05, leaf_h * 0.5), (0.18, 0.03, leaf_h - 0.36), "darkwood")
    leaf.box((DOOR_W * 0.5, 0.0, leaf_h - 0.45), (DOOR_W - 0.08, 0.07, 0.10), "iron")
    leaf.box((DOOR_W - 0.18, -0.10, leaf_h * 0.46), (0.07, 0.10, 0.26), "iron")
    leaf_obj = leaf.to_object("DoorLeaf", collection)
    leaf_obj.parent = pivot
    # A complete, addressable door unit is anchored at the actual facade
    # opening. Frame, hinge and travelling leaf remain independent children;
    # Godot later adds the moving DoorCollision beneath this same pivot.
    # These local transforms reproduce the previously exported world poses
    # exactly, including every facade yaw. No wall or opening is changed.
    unit = bpy.data.objects.new("DoorUnit", None)
    unit.empty_display_size = 0.18
    collection.objects.link(unit)
    unit.location = frame_obj.location
    unit.rotation_euler = frame_obj.rotation_euler
    frame_obj.parent = unit
    frame_obj.location = (0.0, 0.0, 0.0)
    frame_obj.rotation_euler = (0.0, 0.0, 0.0)
    pivot.parent = unit
    pivot.location = (-DOOR_W * 0.5 + 0.03, 0.0, 0.0)
    pivot.rotation_euler = (0.0, 0.0, 0.0)
    opening = {"kind": "door", "id": "door_main",
               "centre": list(world_on_facade(axis, offset, u, yaw, 0.0, 0.0, DOOR_H * 0.5)),
               "size": [DOOR_W, WALL, DOOR_H], "outward": list(outward),
               "clear_width": DOOR_W, "clear_height": DOOR_H, "node_window_id": None}
    return frame_obj, pivot, leaf_obj, opening


# ------------------------------------------------------------------ roof ----


def roof_pitch(span, rise):
    return math.atan2(rise, span)


def gable_roof(mesh, axis, ridge0, ridge1, perp0, perp1, z_eave, rise, overhang=0.28, verge=0.10):
    """Two thin sloped roof shells, tile rows and ridge caps above a cream end gable."""
    mid = (perp0 + perp1) * 0.5
    length = (ridge1 - ridge0) + verge * 2
    centre = (ridge0 + ridge1) * 0.5
    half = (perp1 - perp0) * 0.5 + overhang
    pitch = roof_pitch(half, rise)
    slope = math.hypot(half, rise)
    # t=0 is the ridge; t=1 is the eave. Every panel and tile shares this slope.
    for side in (-1, 1):
        panel_perp = mid + side * half * 0.5
        panel_z = z_eave + rise * 0.5 + 0.09
        if axis == "x":
            mesh.box((centre, panel_perp, panel_z), (length, slope + 0.05, 0.14),
                     "roof", pitch=-side * pitch)
        else:
            mesh.box((panel_perp, centre, panel_z), (slope + 0.05, length, 0.14),
                     "roof", roll=side * pitch)
        # The dark eave is a slender edge under the tile shell.
        eave = mid + side * half
        if axis == "x":
            mesh.box((centre, eave, z_eave - 0.02), (length, 0.18, 0.16), "darkwood")
        else:
            mesh.box((eave, centre, z_eave - 0.02), (0.18, length, 0.16), "darkwood")
        rows = 9
        columns = max(5, int(length / 0.66))
        for row in range(rows):
            t = (row + 0.5) / rows
            perp = mid + side * half * t
            height = z_eave + rise * (1.0 - t) + 0.18
            tile_length = length / columns
            for col in range(columns):
                role = ("roof", "roof_b", "roof_c")[(row * 7 + col * 5 + (1 if side > 0 else 0)) % 3]
                # Small seams show real tile courses without making floating ribbons.
                offset = -length * 0.5 + (col + 0.5) * tile_length
                if row % 2:
                    offset += min(0.13, tile_length * 0.20)
                offset = min(length * 0.5 - tile_length * 0.5,
                             max(-length * 0.5 + tile_length * 0.5, offset))
                offset += centre
                tile_size = (tile_length - 0.025, slope / rows + 0.035, 0.045)
                if axis == "x":
                    mesh.box((offset, perp, height), tile_size, role, pitch=-side * pitch)
                else:
                    mesh.box((perp, offset, height),
                             (tile_size[1], tile_size[0], tile_size[2]), role,
                             roll=side * pitch)
        # End verge boards follow the same slope rather than filling a red triangle.
        for end in (ridge0 - verge + 0.035, ridge1 + verge - 0.035):
            if axis == "x":
                mesh.box((end, panel_perp, panel_z - 0.025),
                         (0.10, slope + 0.08, 0.15), "darkwood", pitch=-side * pitch)
            else:
                mesh.box((panel_perp, end, panel_z - 0.025),
                         (slope + 0.08, 0.10, 0.15), "darkwood", roll=side * pitch)
    caps = max(3, int(length / 0.75))
    for index in range(caps):
        offset = -length * 0.5 + (index + 0.5) * (length / caps)
        if axis == "x":
            mesh.box((centre + offset, mid, z_eave + rise + 0.20),
                     (length / caps - 0.06, 0.28, 0.13), "roof_b")
        else:
            mesh.box((mid, centre + offset, z_eave + rise + 0.20),
                     (0.28, length / caps - 0.06, 0.13), "roof_b")


def gable_end_wall(mesh, axis, position, perp0, perp1, z_top, rise, role="plaster"):
    profile = [(perp0, z_top), ((perp0 + perp1) * 0.5, z_top + rise), (perp1, z_top)]
    mesh.prism(profile, position, position + WALL if axis == "x" else position + WALL, role, axis=axis)


def cone_roof(mesh, centre, radius, z_base, height, sides=8, role="roof"):
    profile = [(radius * math.cos(2 * math.pi * index / sides), radius * math.sin(2 * math.pi * index / sides))
               for index in range(sides)]
    apex = [(centre[0], centre[1], z_base + height)]
    base = len(mesh.vertices)
    mesh.vertices.extend(apex)
    ring = []
    for point in profile:
        ring.append((centre[0] + point[0], centre[1] + point[1], z_base))
    start = len(mesh.vertices)
    mesh.vertices.extend(ring)
    for index in range(sides):
        mesh.faces.append((base, start + index, start + (index + 1) % sides))
        mesh.roles.append(role)


# ------------------------------------------------------------------ house specs ----


SPECS = {
    "01_hearth_cottage": dict(
        name_zh="暖炉小住宅", target_height=10.0,
        blocks=[dict(name="main", x=(-4.0, 4.0), y=(-3.5, 3.5), floors=2, floor_h=3.0,
                     roof=dict(axis="x", rise=4.0))],
        door=dict(block="main", facade="front", u=0.0),
        dormer=True, porch=True, chimney=("left", 0.55), timber=True, stone_courses=True,
        merchant_bay=False, turret=False),
    "02_market_house": dict(
        name_zh="集市商铺住宅", target_height=11.5,
        blocks=[dict(name="main", x=(-3.1, 3.1), y=(-4.5, 4.5), floors=2, floor_h=3.4,
                     roof=dict(axis="x", rise=4.7))],
        door=dict(block="main", facade="front", u=-0.9),
        dormer=True, chimney=("right", 0.5), timber=True, stone_courses=True,
        merchant_bay=True, turret=False),
    "03_corner_turret": dict(
        name_zh="转角塔楼宅", target_height=12.0,
        blocks=[dict(name="main", x=(-4.5, 4.5), y=(-3.5, 3.5), floors=3, floor_h=3.0,
                     roof=dict(axis="x", rise=3.0)),
                dict(name="wing", x=(-4.5, -1.1), y=(3.5, 7.0), floors=2, floor_h=3.0,
                     roof=dict(axis="y", rise=2.4))],
        door=dict(block="main", facade="front", u=2.2),
        dormer=False, chimney=("left", 0.4), timber=True, stone_courses=True,
        merchant_bay=False, turret=True, balcony=True),
}


def new_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def block_wall_planes(block):
    x0, x1 = block["x"]
    y0, y1 = block["y"]
    return {
        "front": dict(axis="x", offset=y0, u0=x0, u1=x1, outward=(0.0, -1.0, 0.0)),
        "back": dict(axis="x", offset=y1, u0=x0, u1=x1, outward=(0.0, 1.0, 0.0)),
        "left": dict(axis="y", offset=x0, u0=y0, u1=y1, outward=(-1.0, 0.0, 0.0)),
        "right": dict(axis="y", offset=x1, u0=y0, u1=y1, outward=(1.0, 0.0, 0.0)),
    }


def openings_for(spec, block, plane_name):
    """Windows per floor on this facade, plus the door on the front facade."""
    plane = block_wall_planes(block)[plane_name]
    span = plane["u1"] - plane["u0"]
    openings = []
    for level in range(block["floors"]):
        z0 = level * block["floor_h"] + WIN_SILL
        count = 3 if span >= 8.5 else 2
        step = span / (count + 1)
        for index in range(count):
            u = plane["u0"] + step * (index + 1)
            door = spec.get("door")
            if (level == 0 and door and door["block"] == block["name"]
                    and plane_name == door["facade"]
                    and abs(u - door["u"]) < (DOOR_W + WIN_W) * 0.5 + 0.10):
                continue
            openings.append({"u0": u - WIN_W * 0.5, "u1": u + WIN_W * 0.5, "z0": z0, "z1": z0 + WIN_H})
    door = spec.get("door")
    if door and door["block"] == block["name"] and plane_name == door["facade"]:
        openings.append({"u0": door["u"] - DOOR_W * 0.5, "u1": door["u"] + DOOR_W * 0.5,
                         "z0": 0.0, "z1": DOOR_H})
    return openings


def shared_gaps(spec, block, plane_name, z0=0.0, z1=None):
    """Where a block wall is inside a neighbouring block it must not be built at all."""
    plane = block_wall_planes(block)[plane_name]
    gaps = []
    for other in spec["blocks"]:
        if other["name"] == block["name"]:
            continue
        if z0 >= other["floors"] * other["floor_h"] - 1e-5:
            continue
        if plane["axis"] == "x":
            if other["y"][0] - 1e-5 <= plane["offset"] <= other["y"][1] + 1e-5:
                lo, hi = max(plane["u0"], other["x"][0]), min(plane["u1"], other["x"][1])
                if hi - lo > 0.01:
                    gaps.append((lo, hi))
        else:
            if other["x"][0] - 1e-5 <= plane["offset"] <= other["x"][1] + 1e-5:
                lo, hi = max(plane["u0"], other["y"][0]), min(plane["u1"], other["y"][1])
                if hi - lo > 0.01:
                    gaps.append((lo, hi))
    return gaps


def build_shell(collection, spec):
    shell = Mesh()
    for block in spec["blocks"]:
        x0, x1 = block["x"]
        y0, y1 = block["y"]
        for level in range(block["floors"]):
            base = level * block["floor_h"]
            top = base + block["floor_h"]
            role = "stone" if level == 0 else "plaster"
            for name, plane in block_wall_planes(block).items():
                wall(shell, plane["axis"], plane["offset"], plane["u0"], plane["u1"], base, top,
                     openings_for(spec, block, name), role, gaps=shared_gaps(spec, block, name, base, top))
            if level:
                shell.box(((x0 + x1) * 0.5, (y0 + y1) * 0.5, base - 0.12),
                          (x1 - x0 - WALL * 2, y1 - y0 - WALL * 2, 0.24), "darkwood")
        shell.box(((x0 + x1) * 0.5, (y0 + y1) * 0.5, -0.12),
                  (x1 - x0, y1 - y0, 0.24), "stone")
        shell.box(((x0 + x1) * 0.5, (y0 + y1) * 0.5, block["floors"] * block["floor_h"] - 0.12),
                  (x1 - x0 - WALL * 2, y1 - y0 - WALL * 2, 0.24), "darkwood")
        z_top = block["floors"] * block["floor_h"]
        rise = block["roof"]["rise"]
        if block["roof"]["axis"] == "x":
            gable_end_wall(shell, "x", x0, y0, y1, z_top, rise)
            gable_end_wall(shell, "x", x1 - WALL, y0, y1, z_top, rise)
        else:
            gable_end_wall(shell, "y", y0, x0, x1, z_top, rise)
            gable_end_wall(shell, "y", y1 - WALL, x0, x1, z_top, rise)
        if spec.get("stone_courses"):
            # Fine mortar joints sit almost flush with the stone face. All joints use
            # the same two-axis cutter as the wall so none can bridge an aperture.
            for name, plane in block_wall_planes(block).items():
                outward = plane["outward"]
                face_offset = plane["offset"] + 0.138 * (
                    outward[1] if plane["axis"] == "x" else outward[0])
                holes = openings_for(spec, block, name)
                for course in range(1, 6):
                    z = course * 0.50
                    gaps = shared_gaps(spec, block, name, z - 0.010, z + 0.010)
                    wall(shell, plane["axis"], face_offset, plane["u0"], plane["u1"],
                         z - 0.010, z + 0.010, holes, "mortar",
                         gaps=gaps, thickness=0.015)
                span = plane["u1"] - plane["u0"]
                for course in range(6):
                    z0, z1 = course * 0.50 + 0.02, min(3.0, (course + 1) * 0.50 - 0.02)
                    if z1 <= z0:
                        continue
                    stagger = 0.46 if course % 2 else 0.0
                    count = max(1, int(span / 1.25))
                    for joint in range(1, count):
                        u = plane["u0"] + span * joint / count + stagger
                        if u >= plane["u1"] - 0.3:
                            continue
                        wall(shell, plane["axis"], face_offset, u - 0.011, u + 0.011,
                             z0, z1, holes, "mortar",
                             gaps=shared_gaps(spec, block, name, z0, z1), thickness=0.015)
                # Alternating corner quoins have the scale of individual stones.
                for end in (plane["u0"] + 0.24, plane["u1"] - 0.24):
                    for row in range(6):
                        z = 0.25 + row * 0.50
                        wall(shell, plane["axis"], face_offset + 0.009 * (
                             outward[1] if plane["axis"] == "x" else outward[0]),
                             end - 0.22, end + 0.22, z - 0.15, z + 0.15,
                             holes, "trim" if row % 2 == 0 else "stone",
                             gaps=shared_gaps(spec, block, name, z - 0.15, z + 0.15),
                             thickness=0.025)
    return shell


def build_timber(collection, spec):
    timber = Mesh()
    for block in spec["blocks"]:
        x0, x1 = block["x"]
        y0, y1 = block["y"]
        top = block["floors"] * block["floor_h"]
        frames = [(y0 - 0.07, x0, x1), (y1 + 0.07, x0, x1)]
        for level in range(1, block["floors"]):
            for offset, start, end in frames:
                timber.box(((start + end) * 0.5, offset, level * block["floor_h"] - 0.1),
                           (end - start + 0.08, 0.14, 0.20), "oak")
            timber.box((x0 - 0.07, (y0 + y1) * 0.5, level * block["floor_h"] - 0.1),
                       (0.14, y1 - y0 + 0.08, 0.20), "oak")
            timber.box((x1 + 0.07, (y0 + y1) * 0.5, level * block["floor_h"] - 0.1),
                       (0.14, y1 - y0 + 0.08, 0.20), "oak")
        for corner_x in (x0 + 0.35, x1 - 0.35):
            timber.box((corner_x, y0 - 0.07, top * 0.5), (0.18, 0.14, top - 0.5), "oak")
            timber.box((corner_x, y1 + 0.07, top * 0.5), (0.18, 0.14, top - 0.5), "oak")
        for corner_y in (y0 + 0.35, y1 - 0.35):
            timber.box((x0 - 0.07, corner_y, top * 0.5), (0.14, 0.18, top - 0.5), "oak")
            timber.box((x1 + 0.07, corner_y, top * 0.5), (0.14, 0.18, top - 0.5), "oak")
        # corner braces read as diagonal timber on the visible facades
        brace = min(1.6, top * 0.35)
        for level in range(block["floors"]):
            z = level * block["floor_h"] + 0.75
            timber.box((x0 + 0.9, y0 - 0.07, z + brace * 0.4), (brace, 0.12, 0.16), "oak", roll=math.radians(38))
            timber.box((x1 - 0.9, y0 - 0.07, z + brace * 0.4), (brace, 0.12, 0.16), "oak", roll=math.radians(-38))
        # Add measured posts only in genuine solid spans between window/door holes.
        for name, plane in block_wall_planes(block).items():
            outward = plane["outward"]
            face = plane["offset"] + 0.15 * (
                outward[1] if plane["axis"] == "x" else outward[0])
            for level in range(block["floors"]):
                base, top_z = level * block["floor_h"], (level + 1) * block["floor_h"]
                forbidden = [(max(plane["u0"], item["u0"]), min(plane["u1"], item["u1"]))
                             for item in openings_for(spec, block, name)
                             if item["z0"] < top_z and item["z1"] > base]
                forbidden += shared_gaps(spec, block, name, base, top_z)
                boundaries = sorted({plane["u0"], plane["u1"],
                                     *(u for a, b in forbidden for u in (a, b))})
                for a, b in zip(boundaries[:-1], boundaries[1:]):
                    u = (a + b) * 0.5
                    if b - a < 1.1 or any(lo < u < hi for lo, hi in forbidden):
                        continue
                    height = block["floor_h"] - 0.50
                    zpost = base + block["floor_h"] * 0.5
                    if plane["axis"] == "x":
                        timber.box((u, face, zpost), (0.16, 0.15, height), "oak")
                    else:
                        timber.box((face, u, zpost), (0.15, 0.16, height), "oak")
        # A central gable post and paired slope braces break up the bare plaster apex.
        z_eave = block["floors"] * block["floor_h"]
        rise = block["roof"]["rise"]
        axis = block["roof"]["axis"]
        p0, p1 = (y0, y1) if axis == "x" else (x0, x1)
        half = (p1 - p0) * 0.5
        mid = (p0 + p1) * 0.5
        slope_length = math.hypot(half, rise)
        pitch = math.atan2(rise, half)
        for end in ((x0 - 0.08, x1 + 0.08) if axis == "x" else (y0 - 0.08, y1 + 0.08)):
            if axis == "x":
                timber.box((end, mid, z_eave + rise * 0.5),
                           (0.15, 0.17, rise - 0.24), "oak")
            else:
                timber.box((mid, end, z_eave + rise * 0.5),
                           (0.17, 0.15, rise - 0.24), "oak")
            for side in (-1, 1):
                perp = mid + side * half * 0.50
                if axis == "x":
                    timber.box((end, perp, z_eave + rise * 0.5),
                               (0.11, slope_length - 0.24, 0.12), "oak",
                               pitch=-side * pitch)
                else:
                    timber.box((perp, end, z_eave + rise * 0.5),
                               (slope_length - 0.24, 0.11, 0.12), "oak",
                               roll=side * pitch)
                # An inner brace reaches a lower central collar instead of hiding
                # exactly under the roof verge.
                inner_rise = max(0.7, rise * 0.55 - 0.35)
                inner_pitch = math.atan2(inner_rise, half)
                inner_length = math.hypot(half, inner_rise)
                inner_z = z_eave + 0.35 + inner_rise * 0.50
                if axis == "x":
                    timber.box((end, perp, inner_z),
                               (0.12, inner_length - 0.12, 0.12), "oak",
                               pitch=-side * inner_pitch)
                else:
                    timber.box((perp, end, inner_z),
                               (inner_length - 0.12, 0.12, 0.12), "oak",
                               roll=side * inner_pitch)
    return timber


def build_roof(collection, spec):
    roof = Mesh()
    for block in spec["blocks"]:
        x0, x1 = block["x"]
        y0, y1 = block["y"]
        z_eave = block["floors"] * block["floor_h"]
        if block["roof"]["axis"] == "x":
            gable_roof(roof, "x", x0, x1, y0, y1, z_eave, block["roof"]["rise"])
        else:
            gable_roof(roof, "y", y0, y1, x0, x1, z_eave, block["roof"]["rise"])
    if spec.get("chimney"):
        side, factor = spec["chimney"]
        main = spec["blocks"][0]
        x = main["x"][0] + 0.8 if side == "left" else main["x"][1] - 0.8
        base = main["floors"] * main["floor_h"] - 0.6
        top = main["floors"] * main["floor_h"] + main["roof"]["rise"] + 1.2
        chimney_y = main["y"][0] * factor + main["y"][1] * (1.0 - factor)
        roof.box((x, chimney_y, (base + top) * 0.5), (0.66, 0.66, top - base), "stone")
        roof.box((x, chimney_y, top + 0.10), (0.8, 0.8, 0.2), "trim")
    if spec.get("turret"):
        main = spec["blocks"][0]
        wing = next(block for block in spec["blocks"] if block["name"] != main["name"])
        # the turret sits in the concave inner corner of the L, projecting into the courtyard side
        centre = (wing["x"][1] + 0.85, wing["y"][0] + 1.0)
        height = main["floors"] * main["floor_h"] + main["roof"]["rise"] + 0.6
        sides = 8
        profile = [(centre[0] + 1.05 * math.cos(2 * math.pi * index / sides),
                    centre[1] + 1.05 * math.sin(2 * math.pi * index / sides)) for index in range(sides)]
        roof.prism(profile, 0.0, height, "stone", axis="z")
        cone_roof(roof, centre, 1.3, height, 1.6, sides=sides, role="roof")
    if spec.get("dormer"):
        main = spec["blocks"][0]
        rise = main["roof"]["rise"]
        z_eave = main["floors"] * main["floor_h"]
        dormer_z = z_eave + rise * 0.34
        centre_y = (main["y"][0] + main["y"][1]) * 0.5 - (main["y"][1] - main["y"][0]) * 0.22
        # Four sides of a small dormer; the front is an actual inset glazed face.
        for xside in (-0.68, 0.68):
            roof.box((xside, centre_y, dormer_z + 0.55), (0.10, 1.50, 1.10), "plaster")
        roof.box((0.0, centre_y + 0.70, dormer_z + 0.55), (1.38, 0.10, 1.10), "plaster")
        roof.box((0.0, centre_y - 0.68, dormer_z + 0.11), (1.35, 0.14, 0.22), "plaster")
        roof.box((0.0, centre_y - 0.68, dormer_z + 1.00), (1.35, 0.14, 0.20), "plaster")
        roof.box((0.0, centre_y - 0.68, dormer_z + 0.56), (1.02, 0.05, 0.76), "interior")
        roof.box((0.0, centre_y - 0.79, dormer_z + 0.56), (0.87, 0.05, 0.70), "glass")
        for xbar in (-0.48, 0.0, 0.48):
            roof.box((xbar, centre_y - 0.83, dormer_z + 0.56),
                     (0.075, 0.12, 0.88), "oak")
        for zbar in (dormer_z + 0.14, dormer_z + 0.56, dormer_z + 0.98):
            roof.box((0.0, centre_y - 0.83, zbar), (1.02, 0.12, 0.075), "oak")
        # small gable over the dormer, aligned with the main ridge
        gable_roof(roof, "x", -0.85, 0.85, centre_y - 0.85, centre_y + 0.65, dormer_z + 1.06, 0.55, overhang=0.14)
    if spec.get("balcony"):
        main = spec["blocks"][0]
        z = main["floor_h"] + 0.1
        roof.box((main["x"][0] + 1.4, main["y"][0] - 0.55, z), (1.8, 1.0, 0.14), "oak")
        roof.box((main["x"][0] + 1.4, main["y"][0] - 1.0, z + 0.90),
                 (1.8, 0.09, 0.10), "oak")
        for offset in (-0.78, -0.39, 0.0, 0.39, 0.78):
            roof.box((main["x"][0] + 1.4 + offset, main["y"][0] - 1.0, z + 0.49),
                     (0.075, 0.09, 0.75), "oak")
        for yrail in (main["y"][0] - 0.9, main["y"][0] - 0.35):
            for xrail in (main["x"][0] + 0.56, main["x"][0] + 2.24):
                roof.box((xrail, yrail, z + 0.49), (0.075, 0.09, 0.75), "oak")
        for support in (-0.7, 0.7):
            roof.box((main["x"][0] + 1.4 + support, main["y"][0] - 0.55, z - 0.25), (0.12, 0.12, 0.5), "oak")
    return roof


def build_merchant_bay(collection, spec):
    bay = Mesh()
    main = spec["blocks"][0]
    y0, x0, x1 = main["y"][0], main["x"][0], main["x"][1]
    z = 2.6
    bay.box(((x0 + x1) * 0.5, y0 - 0.55, z),
            (x1 - x0 - 0.6, 1.0, 0.075), "canvas", pitch=math.radians(11))
    scallops = 8
    width = x1 - x0 - 0.6
    xstart = (x0 + x1) * 0.5 - width * 0.5
    for scallop in range(scallops):
        for segment in range(4):
            a = xstart + width * (scallop + segment / 4) / scallops
            b = xstart + width * (scallop + (segment + 1) / 4) / scallops
            za = 2.34 - 0.13 * math.sin(math.pi * segment / 4)
            zb = 2.34 - 0.13 * math.sin(math.pi * (segment + 1) / 4)
            bay.quad([(a, y0 - 1.06, 2.44), (b, y0 - 1.06, 2.44),
                      (b, y0 - 1.06, zb), (a, y0 - 1.06, za)], "canvas")
    # The door is at x=-0.9. Land both posts on the solid outer front piers,
    # underneath the canopy edges, rather than across its actual entrance.
    for support_x in (x0 + 0.65, x1 - 0.65):
        bay.box((support_x, y0 - 0.95, z - 0.25), (0.16, 0.16, 0.5), "oak", roll=math.radians(28))
        bay.box((support_x, y0 - 0.25, 1.35), (0.14, 0.5, 2.5), "oak")
    # A compact counter sits to the right; the left-hand doorway remains legible.
    display_x = x1 - 1.25
    bay.box((display_x, y0 - 0.24, 0.45), (2.30, 0.46, 0.85), "darkwood")
    bay.box((display_x, y0 - 0.51, 0.89), (2.42, 0.60, 0.11), "oak")
    for shelf_z in (1.42, 1.88):
        bay.box((display_x, y0 - 0.20, shelf_z), (2.22, 0.18, 0.08), "oak")
    sign_x = x1 - 0.72
    bay.box((sign_x, y0 - 0.85, 3.4), (0.10, 0.10, 1.0), "iron")
    bay.box((sign_x, y0 - 0.85, 2.85), (0.9, 0.08, 0.7), "sign")
    for bar in (-0.28, 0.0, 0.28):
        bay.box((sign_x + bar, y0 - 0.92, 2.85), (0.06, 0.05, 0.5), "oak")
    bay.box((sign_x, y0 - 0.92, 3.05), (0.7, 0.05, 0.12), "roof_b")
    return bay


def build_cottage_porch(collection, spec):
    porch = Mesh()
    main = spec["blocks"][0]
    y0 = main["y"][0]
    porch.box((0.0, y0 - 0.64, 2.57), (2.94, 1.38, 0.12),
              "roof_b", pitch=math.radians(9))
    porch.box((0.0, y0 - 1.30, 2.40), (3.02, 0.14, 0.18), "oak")
    for x in (-1.32, 1.32):
        porch.box((x, y0 - 1.14, 1.21), (0.16, 0.16, 2.42), "oak")
        porch.box((x, y0 - 1.14, 2.38), (0.34, 0.34, 0.14), "trim")
    for x in (-2.15, 2.15):
        porch.box((x, y0 - 0.23, 0.70), (0.95, 0.36, 0.27), "oak")
        porch.box((x, y0 - 0.23, 0.86), (0.82, 0.29, 0.07), "soil")
        for offset in (-0.26, 0.0, 0.26):
            porch.box((x + offset, y0 - 0.25, 1.01), (0.13, 0.13, 0.29), "leaf")
            porch.box((x + offset, y0 - 0.25, 1.17), (0.11, 0.11, 0.10), "flower")
    return porch


def build_variant(variant_id, spec, out_dir, render_dir, render=True):
    reset_scene()
    collection = new_collection("House_" + variant_id)
    shell = build_shell(collection, spec).to_object("BuildingShell", collection)
    roof = build_roof(collection, spec).to_object("Roof", collection)
    timber = build_timber(collection, spec).to_object("TimberFrame", collection)
    door_block = next(block for block in spec["blocks"] if block["name"] == spec["door"]["block"])
    plane = block_wall_planes(door_block)[spec["door"]["facade"]]
    door_frame, door_pivot, door_leaf, door_opening = place_door(
        collection, plane["axis"], plane["offset"], spec["door"]["u"], plane["outward"])
    frames, sashes, shutters, openings = [], [], [], []
    index = 0
    for block in spec["blocks"]:
        for name, wall_plane in block_wall_planes(block).items():
            for opening in openings_for(spec, block, name):
                if opening["z1"] - opening["z0"] > DOOR_H - 0.01 and opening["z0"] <= 0.01:
                    continue  # the doorway is handled by place_door
                u = (opening["u0"] + opening["u1"]) * 0.5
                gaps = shared_gaps(spec, block, name, opening["z0"], opening["z1"])
                if any(start < u < end for start, end in gaps):
                    continue  # this window would sit inside the neighbouring block
                frame_obj, sash, hinge_list, window_opening = place_window(
                    collection, index, wall_plane["axis"], wall_plane["offset"], u, opening["z0"],
                    wall_plane["outward"])
                frames.append(frame_obj); sashes.append(sash); shutters.extend(hinge_list)
                openings.append(window_opening)
                index += 1
    extras = []
    if spec.get("merchant_bay"):
        extras.append(build_merchant_bay(collection, spec).to_object("ShopBay", collection))
    if spec.get("porch"):
        extras.append(build_cottage_porch(collection, spec).to_object("Porch", collection))
    parts = []
    for obj, part_type in ([(shell, "shell"), (roof, "roof"), (timber, "timber_frame"),
                            (door_frame, "door_frame"), (door_leaf, "door_leaf")] +
                           [(item, "window_frame") for item in frames] +
                           [(item, "window_sash") for item in sashes] +
                           [(item, "shutter") for item in shutters] +
                           [(item, "bay") for item in extras if item is not None]):
        if obj is not None:
            parts.append({"id": obj.name, "type": part_type, "node": obj.name})
    triangles = {}
    for obj in collection.objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            triangles[obj.name] = len(obj.data.loop_triangles)
    spaces = []
    for block in spec["blocks"]:
        spaces.append({"id": block["name"], "kind": "interior", "access": "through the main door",
                       "x": list(block["x"]), "y": list(block["y"]), "floors": block["floors"],
                       "floor_height": block["floor_h"]})
    if spec.get("turret"):
        spaces.append({"id": "turret", "kind": "exterior_accessory_tower",
                       "access": "not enterable in this prototype", "footprint": "octagonal, inner corner"})
    entry = {
        "variant_id": variant_id, "name_zh": spec["name_zh"],
        "source_glb": "res://assets/floor1/modular_houses_20260916/%s.glb" % variant_id,
        "coordinates": {"authoring": "blender_z_up", "runtime": "godot_y_up", "front_normal_godot": "+Z"},
        "dimensions_m": {"target_height": spec["target_height"],
                         "blocks": [{"name": block["name"], "width": block["x"][1] - block["x"][0],
                                     "depth": block["y"][1] - block["y"][0], "floors": block["floors"],
                                     "floor_height": block["floor_h"], "roof_rise": block["roof"]["rise"]}
                                    for block in spec["blocks"]]},
        "spaces": spaces, "parts": parts, "door_unit_node": "DoorUnit",
        "pivots": [
            {"id": "DoorPivot", "type": "door", "node": "DoorPivot", "unit_node": "DoorUnit", "axis_gltf": [0, 1, 0],
             "hinge_range_deg": [0, 90], "closed_angle_deg": 0, "open_angle_deg": 88,
             "leaf_node": "DoorLeaf"},
            {"id": "WindowSash", "type": "window", "nodes": [item.name for item in sashes],
             "travel_m": round(WIN_H * 0.55, 4), "axis_gltf": [0, 1, 0]},
            {"id": "Shutters", "type": "shutter", "nodes": [item.name for item in shutters],
             "axis_gltf": [0, 1, 0], "hinge_range_deg": [0, 75], "open_angle_deg": 75},
        ],
        "openings": [door_opening] + openings,
        "collision": [
            {"id": "shell", "node": "BuildingShell", "kind": "trimesh", "source_mesh": "BuildingShell"},
            {"id": "timber", "node": "TimberFrame", "kind": "trimesh", "source_mesh": "TimberFrame"},
            {"id": "roof", "node": "Roof", "kind": "trimesh", "source_mesh": "Roof"},
            {"id": "door_leaf", "node": "DoorLeaf", "kind": "box", "parent_pivot": "DoorPivot",
             "size": [DOOR_W - 0.08, 0.09, DOOR_H - 0.05],
             "centre_local": [DOOR_W * 0.5, 0.0, (DOOR_H - 0.05) * 0.5]},
        ],
        "roof_removable": True, "triangles_by_part": triangles, "triangles_total": sum(triangles.values()),
    }
    if variant_id == "02_market_house":
        main = spec["blocks"][0]
        for side, support_x in zip(("left", "right"),
                                   (main["x"][0] + 0.65, main["x"][1] - 0.65)):
            entry["collision"].append({
                "id": "shop_post_" + side, "node": "ShopBay", "kind": "box",
                "size": [0.14, 0.5, 2.5],
                "centre_local": [support_x, main["y"][0] - 0.25, 1.35],
            })
    out_dir.mkdir(parents=True, exist_ok=True)
    for stray in list(bpy.data.objects):
        if stray.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(stray, do_unlink=True)
    for obj in collection.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out_dir / (variant_id + ".glb")), export_format="GLB",
                              use_selection=True, export_apply=False, export_yup=True)
    entry["render_paths"] = render_views(collection, variant_id, spec, render_dir) if render else {}
    return entry


def render_views(collection, variant_id, spec, render_dir):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 720
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Punchy"
    except Exception:
        scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.5
    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (0.56, 0.60, 0.66, 1.0)
    background.inputs[1].default_value = 1.05
    scene.world = world
    ground = Mesh()
    ground.box((0.0, 0.0, -0.3), (90.0, 90.0, 0.6), "ground")
    ground.to_object("PreviewGround", collection)
    for name, energy, size, location in (("Key", 2600.0, 12.0, (10.0, -11.0, 12.0)),
                                         ("Fill", 900.0, 14.0, (-11.0, -7.0, 8.0)),
                                         ("Rim", 1200.0, 10.0, (-7.0, 10.0, 10.0))):
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = energy
        data.size = size
        light = bpy.data.objects.new(name, data)
        light.location = location
        bpy.context.scene.collection.objects.link(light)
        constraint = light.constraints.new("TRACK_TO")
        constraint.target = collection.objects["BuildingShell"]
        constraint.track_axis = "TRACK_NEGATIVE_Z"
        constraint.up_axis = "UP_Y"
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.type = "ORTHO"
    span = max(block["x"][1] - block["x"][0] for block in spec["blocks"])
    depth = max(block["y"][1] - block["y"][0] for block in spec["blocks"])
    camera_data.ortho_scale = max(span, depth) * 1.75 + 4.5
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    height = spec["target_height"]
    scene.camera = camera
    render_dir.mkdir(parents=True, exist_ok=True)
    # The L-plan wing is behind the front wall; a higher front-left view lets its
    # roof/turret silhouette read while the front door remains in frame.
    corner = variant_id == "03_corner_turret"
    views = (("front34", -42.0 if corner else 38.0),
             ("back34", 218.0), ("side34", 128.0))
    paths = {}
    for name, azimuth in views:
        _aim(camera, height, azimuth, 29.0 if corner and name == "front34" else 16.0)
        scene.render.filepath = str(render_dir / ("%s-%s-closed.png" % (variant_id, name)))
        bpy.ops.render.render(write_still=True)
        paths[name + "_closed"] = str(scene.render.filepath).replace("\\", "/")
    pivot = collection.objects["DoorPivot"]
    pivot.rotation_euler = (pivot.rotation_euler.x, pivot.rotation_euler.y, pivot.rotation_euler.z + math.radians(-88))
    for obj in collection.objects:
        if obj.name.startswith("WindowSash_"):
            obj.location = (obj.location.x, obj.location.y, obj.location.z + WIN_H * 0.55)
        if obj.name.startswith("ShutterPivot_"):
            swing = math.radians(75.0 if "_L_" in obj.name else -75.0)
            obj.rotation_euler = (obj.rotation_euler.x, obj.rotation_euler.y, obj.rotation_euler.z + swing)
    _aim(camera, height, -42.0 if corner else 38.0, 29.0 if corner else 16.0)
    scene.render.filepath = str(render_dir / ("%s-front34-open.png" % variant_id))
    bpy.ops.render.render(write_still=True)
    paths["front34_open"] = str(scene.render.filepath).replace("\\", "/")
    return paths


def _aim(camera, height, azimuth_deg, elevation_deg=16.0):
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    distance = 45.0
    camera.location = (distance * math.cos(elevation) * math.sin(azimuth),
                       -distance * math.cos(elevation) * math.cos(azimuth),
                       height * 0.5 + distance * math.sin(elevation))
    direction = Vector((0.0, 0.0, height * 0.5)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def reset_scene():
    bpy.ops.wm.read_homefile(use_empty=True)
    _MATERIALS.clear()


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--house", default="all")
    parser.add_argument("--out", default="game/assets/floor1/modular_houses_20260916")
    parser.add_argument("--renders", default="Art/Generated/Floor1Modular20260916/renders")
    parser.add_argument("--report", default="Art/Generated/Floor1Modular20260916/build-report.json")
    parser.add_argument("--no-render", action="store_true")
    return parser.parse_args(argv)


def main():
    args = parse_args(list(sys.argv))
    out_dir = ROOT / args.out
    render_dir = ROOT / args.renders
    report_path = ROOT / args.report
    wanted = list(SPECS) if args.house == "all" else [item for item in args.house.split(",") if item]
    manifest = {"generated_at_utc": datetime.now(timezone.utc).isoformat(),
                "blender_version": bpy.app.version_string,
                "authoring": "Art/Generated/Floor1Modular20260916/build_modular_houses.py",
                "note": "authored modular low-poly replacement derived from the Meshy concept art; "
                        "not automatic semantic segmentation of a one-piece generated mesh",
                "palette_source": "repository floor1 role palette (Art/ReferenceScenes/Floor1Residences)",
                "houses": []}
    manifest_path = out_dir / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["houses"] = [house for house in manifest.get("houses", [])
                              if house["variant_id"] not in wanted]
    manifest["generated_at_utc"] = datetime.now(timezone.utc).isoformat()
    manifest["blender_version"] = bpy.app.version_string
    manifest["geometry_revision"] = "v6.1: merchant canopy posts on solid outer piers with matching collision; door, window and detachable unit contract preserved"
    for variant_id in wanted:
        if variant_id not in SPECS:
            raise SystemExit("unknown variant: %s" % variant_id)
        entry = build_variant(variant_id, SPECS[variant_id], out_dir, render_dir, render=not args.no_render)
        manifest["houses"].append(entry)
        print("built %s triangles=%d" % (variant_id, entry["triangles_total"]))
    manifest["houses"].sort(key=lambda item: item["variant_id"])
    manifest["total_triangles"] = sum(house["triangles_total"] for house in manifest["houses"])
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
