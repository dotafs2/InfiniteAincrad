"""Build twenty original Floor-1 environment components in Blender 5.2 LTS.

The kit extends the existing warm stone / dark timber / terracotta art direction.
It is a reusable environment library, not a copied anime set and not a claim that
the complete first floor has been authored.

Run:
  blender --background --python build_floor1_environment_kit_20.py -- --seed 1120
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


HERE = Path(__file__).resolve().parent
REFERENCE_ROOT = HERE.parent
PROJECT = REFERENCE_ROOT.parents[1]
EXPORT = PROJECT / "game" / "assets" / "floor1" / "environment_kit_20"
VALIDATION = PROJECT / "docs" / "validation" / "floor1_environment_kit_20_2026-09-11"
STYLE = "floor1_environment_kit_20_v1"
sys.path.insert(0, str(REFERENCE_ROOT))

import build_reference_scenes as base  # noqa: E402
import build_reference_scenes_hq as hq  # noqa: E402


G = hq.G
RNG = random.Random(1120)
base.STYLE = STYLE
hq.STYLE = STYLE
base.PALETTE.update(
    {
        "floor_stone": "BEB69D",
        "floor_stone_light": "DED4B8",
        "floor_stone_dark": "817D70",
        "timber_warm": "74583B",
        "timber_dark": "3C382E",
        "roof_terracotta": "9E5E52",
        "system_blue": "57BFD0",
        "bark": "665540",
        "bark_light": "8A7253",
        "bark_dark": "413A30",
        "bark_birch": "C9C5AF",
        "leaf": "5F8445",
        "leaf_light": "8CAA58",
        "leaf_dark": "3E6338",
        "leaf_warm": "A9A85A",
        "leaf_cool": "527B5F",
        "grass": "718F50",
        "grass_light": "9CB66A",
        "grass_dark": "4E713E",
        "moss": "637A46",
        "moss_light": "8D9E5A",
        "soil": "695B45",
        "flower_cream": "E5D6A4",
        "flower_blue": "6F92A2",
        "flower_rose": "B97872",
        "fruit_red": "B45D45",
        "fruit_yellow": "D0A959",
        "water": "6FA6A2",
        "iron": "454A45",
        "canvas_cream": "E8DFC2",
        "canvas_green": "789878",
    }
)


def args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=1120)
    parser.add_argument("--render", action=argparse.BooleanOptionalAction, default=True)
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(values)


def asset_collection(scene: bpy.types.Scene, asset_id: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(asset_id)
    scene.collection.children.link(collection)
    collection["asset_id"] = asset_id
    collection["style_id"] = STYLE
    collection["original_project_asset"] = True
    return collection


def emit(geo: G, collection: bpy.types.Collection, name: str, collision: bool = False, bevel: float = 0.012) -> bpy.types.Object:
    obj = geo.obj(name, collection, 0.0 if collision else bevel, collision)
    obj["asset_id"] = collection.name
    obj["style_id"] = STYLE
    obj["original_project_asset"] = True
    obj["collision_enabled"] = collision
    obj.hide_render = collision
    return obj


def branch(geo: G, points: list[tuple[float, float, float]], start: float, end: float, role: str = "bark", sides: int = 10) -> None:
    radii = [start + (end - start) * index / (len(points) - 1) for index in range(len(points))]
    geo.tube(points, radii, role, sides)


def leaf_cloud(geo: G, point: Vector, scale: tuple[float, float, float], role: str, count: int = 4) -> None:
    for index in range(count):
        angle = index * math.tau / count + RNG.uniform(-0.22, 0.22)
        offset = Vector((math.cos(angle) * scale[0] * 0.28, math.sin(angle) * scale[1] * 0.28, RNG.uniform(-0.12, 0.18)))
        size = (
            scale[0] * RNG.uniform(0.55, 0.78),
            scale[1] * RNG.uniform(0.55, 0.78),
            scale[2] * RNG.uniform(0.68, 0.94),
        )
        geo.rounded_sphere(point + offset, size, role if index % 3 else "leaf_light", 10, 6)


def blade(geo: G, point: Vector, height: float, width: float, yaw: float, role: str, bend: float = 0.16) -> None:
    direction = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    side = Vector((-direction.y, direction.x, 0.0))
    p0 = point - side * width
    p1 = point + side * width
    mid = point + direction * bend * 0.35 + Vector((0, 0, height * 0.54))
    top = point + direction * bend + Vector((0, 0, height))
    verts = [p0, p1, mid + side * width * 0.55, mid - side * width * 0.55, top]
    geo.mesh(verts, [(0, 1, 2, 3), (3, 2, 4), (3, 4, 2), (3, 2, 1, 0)], role)


def small_leaf(geo: G, point: Vector, size: float, yaw: float, role: str = "leaf") -> None:
    rot = Matrix.Rotation(yaw, 3, "Z")
    geo.box(point, (size * 1.6, size * 0.7, max(0.025, size * 0.12)), role, rot)


def tree_geometry(kind: str) -> tuple[G, G]:
    g, c = G(), G()
    specs = {
        "oak": (0.62, 7.8, "bark", "leaf", 7),
        "apple": (0.34, 4.8, "bark", "leaf", 6),
        "maple": (0.25, 4.2, "bark_light", "leaf_warm", 5),
    }
    radius, height, bark_role, leaf_role, crowns = specs[kind]
    trunk = [
        (0, 0, 0),
        (0.08, -0.05, height * 0.30),
        (-0.12, 0.10, height * 0.62),
        (0.04, 0.02, height * 0.83),
    ]
    branch(g, trunk, radius, radius * 0.28, bark_role, 14)
    for root_index in range(8):
        angle = root_index * math.tau / 8 + RNG.uniform(-0.12, 0.12)
        end = Vector((math.cos(angle) * radius * 2.4, math.sin(angle) * radius * 2.4, 0.03))
        branch(g, [(0, 0, 0.23), tuple(end * 0.55 + Vector((0, 0, 0.02))), tuple(end)], radius * 0.22, 0.035, "bark_dark", 8)
    for index in range(crowns):
        angle = index * math.tau / crowns + RNG.uniform(-0.22, 0.22)
        base_z = height * RNG.uniform(0.46, 0.72)
        length = (2.5 if kind == "oak" else 1.55) * RNG.uniform(0.78, 1.15)
        end = Vector((math.cos(angle) * length, math.sin(angle) * length, height * RNG.uniform(0.78, 1.0)))
        mid = Vector((math.cos(angle) * length * 0.48, math.sin(angle) * length * 0.48, base_z + 0.55))
        branch(g, [(0, 0, base_z), tuple(mid), tuple(end)], radius * 0.23, 0.045, bark_role, 9)
        leaf_cloud(g, end, (1.45 if kind == "oak" else 0.92, 1.25 if kind == "oak" else 0.82, 1.0 if kind == "oak" else 0.72), leaf_role, 4)
    leaf_cloud(g, Vector((0.0, 0.0, height * 0.91)), (1.8 if kind == "oak" else 1.05, 1.65 if kind == "oak" else 1.0, 1.2 if kind == "oak" else 0.8), leaf_role, 5)
    if kind == "apple":
        for index in range(22):
            angle = RNG.random() * math.tau
            radial = RNG.uniform(0.55, 1.8)
            g.rounded_sphere((math.cos(angle) * radial, math.sin(angle) * radial, RNG.uniform(2.8, 4.7)), (0.085, 0.085, 0.085), "fruit_red" if index % 4 else "fruit_yellow", 8, 5)
    c.cylinder((0, 0, 0), radius * 0.82, height * 0.68, "bark", 10)
    return g, c


def ancient_oak() -> tuple[G, G]:
    return tree_geometry("oak")


def orchard_apple() -> tuple[G, G]:
    return tree_geometry("apple")


def young_maple() -> tuple[G, G]:
    return tree_geometry("maple")


def birch_grove() -> tuple[G, G]:
    g, c = G(), G()
    for tree_index, (x, y, h, r) in enumerate([(-0.65, 0.15, 6.6, 0.20), (0.55, 0.35, 5.7, 0.17), (0.12, -0.55, 4.9, 0.15)]):
        branch(g, [(x, y, 0), (x + 0.05, y, h * 0.5), (x - 0.04, y + 0.05, h)], r, r * 0.42, "bark_birch", 12)
        for band in range(6):
            z = 0.55 + band * (h - 1.0) / 6 + RNG.uniform(-0.12, 0.12)
            g.rings((x, y, z), [(r * 1.015, 0), (r * 1.015, 0.045)], "bark_dark", 12)
        for branch_index in range(5):
            angle = branch_index * 2.35 + tree_index
            z = h * (0.48 + branch_index * 0.09)
            end = Vector((x + math.cos(angle) * 0.9, y + math.sin(angle) * 0.9, z + 0.7))
            branch(g, [(x, y, z), tuple(end)], r * 0.18, 0.025, "bark_birch", 7)
            leaf_cloud(g, end, (0.68, 0.58, 0.70), "leaf_light" if tree_index == 1 else "leaf", 3)
        c.cylinder((x, y, 0), r * 0.85, h * 0.70, "bark", 8)
    return g, c


def cypress_column() -> tuple[G, G]:
    g, c = G(), G()
    branch(g, [(0, 0, 0), (0.02, 0, 7.2)], 0.27, 0.10, "bark_dark", 12)
    for index in range(14):
        z = 0.55 + index * 0.43
        taper = 1.0 - index / 18
        g.rounded_sphere((RNG.uniform(-0.12, 0.12), RNG.uniform(-0.10, 0.10), z), (0.72 * taper, 0.65 * taper, 0.70), "leaf_dark" if index % 3 else "leaf_cool", 10, 7)
    g.rounded_sphere((0, 0, 6.75), (0.30, 0.28, 0.75), "leaf_cool", 10, 7)
    c.cylinder((0, 0, 0), 0.30, 6.4, "bark", 8)
    return g, c


def stone_pine() -> tuple[G, G]:
    g, c = G(), G()
    branch(g, [(0, 0, 0), (0.12, -0.05, 3.1), (-0.08, 0.06, 6.3)], 0.36, 0.12, "bark_dark", 12)
    for ring in range(7):
        z = 2.0 + ring * 0.60
        count = 5 if ring < 4 else 4
        reach = 2.25 * (1.0 - ring * 0.09)
        for index in range(count):
            angle = index * math.tau / count + ring * 0.47
            end = Vector((math.cos(angle) * reach, math.sin(angle) * reach, z + RNG.uniform(0.15, 0.45)))
            branch(g, [(0, 0, z), tuple(end * Vector((0.56, 0.56, 1.0))), tuple(end)], 0.105, 0.025, "bark", 7)
            leaf_cloud(g, end, (0.68, 0.48, 0.42), "leaf_dark", 3)
    leaf_cloud(g, Vector((0, 0, 6.35)), (0.75, 0.68, 0.72), "leaf_cool", 4)
    c.cylinder((0, 0, 0), 0.29, 5.5, "bark", 8)
    return g, c


def flowering_shrub() -> tuple[G, G]:
    g, c = G(), G()
    for stem in range(15):
        angle = stem * 2.399
        end = Vector((math.cos(angle) * RNG.uniform(0.45, 0.95), math.sin(angle) * RNG.uniform(0.45, 0.95), RNG.uniform(0.9, 1.55)))
        branch(g, [(0, 0, 0.08), tuple(end * Vector((0.55, 0.55, 0.64))), tuple(end)], 0.045, 0.012, "bark", 6)
        leaf_cloud(g, end, (0.34, 0.30, 0.25), "leaf_light" if stem % 3 == 0 else "leaf", 2)
        for petal in range(5):
            a = petal * math.tau / 5
            g.rounded_sphere(end + Vector((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.07)), (0.09, 0.055, 0.035), "flower_rose" if stem % 2 else "flower_cream", 7, 4)
    c.rounded_sphere((0, 0, 0.7), (0.72, 0.68, 0.72), "leaf", 8, 5)
    return g, c


def berry_bush() -> tuple[G, G]:
    g, c = G(), G()
    for stem in range(12):
        angle = stem * math.tau / 12
        end = Vector((math.cos(angle) * RNG.uniform(0.45, 0.85), math.sin(angle) * RNG.uniform(0.45, 0.85), RNG.uniform(0.65, 1.25)))
        branch(g, [(0, 0, 0.05), tuple(end)], 0.035, 0.012, "bark_dark", 6)
        for leaf_index in range(3):
            p = end * (0.58 + leaf_index * 0.18)
            small_leaf(g, p, 0.16, angle + leaf_index * 1.1, "leaf_dark" if leaf_index == 0 else "leaf")
        for berry in range(3):
            p = end + Vector((RNG.uniform(-0.16, 0.16), RNG.uniform(-0.16, 0.16), RNG.uniform(-0.12, 0.12)))
            g.rounded_sphere(p, (0.045, 0.045, 0.05), "fruit_red", 7, 4)
    c.rounded_sphere((0, 0, 0.55), (0.60, 0.60, 0.55), "leaf", 8, 5)
    return g, c


def fern_patch() -> tuple[G, G]:
    g, c = G(), G()
    for plant in range(5):
        center = Vector((RNG.uniform(-0.45, 0.45), RNG.uniform(-0.35, 0.35), 0))
        for frond in range(7):
            angle = frond * math.tau / 7 + RNG.uniform(-0.15, 0.15)
            length = RNG.uniform(0.55, 0.92)
            end = center + Vector((math.cos(angle) * length, math.sin(angle) * length, RNG.uniform(0.28, 0.58)))
            branch(g, [tuple(center + Vector((0, 0, 0.04))), tuple((center + end) * 0.5 + Vector((0, 0, 0.18))), tuple(end)], 0.018, 0.006, "grass_dark", 5)
            for leaflet in range(4):
                t = 0.30 + leaflet * 0.15
                p = center.lerp(end, t) + Vector((0, 0, 0.10 * math.sin(t * math.pi)))
                for sign in (-1, 1):
                    small_leaf(g, p + Vector((-math.sin(angle), math.cos(angle), 0)) * sign * 0.055, 0.095 * (1.15 - t), angle + sign * 0.65, "grass" if leaflet % 2 else "grass_light")
    return g, c


def meadow_grass() -> tuple[G, G]:
    g, c = G(), G()
    for index in range(95):
        radius = math.sqrt(RNG.random()) * 0.78
        angle = RNG.random() * math.tau
        point = Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0.01))
        blade(g, point, RNG.uniform(0.28, 0.82), RNG.uniform(0.015, 0.032), angle + RNG.uniform(-1.0, 1.0), ["grass", "grass_light", "grass_dark"][index % 3], RNG.uniform(0.06, 0.22))
    return g, c


def wildflower_patch() -> tuple[G, G]:
    g, c = meadow_grass()
    for index in range(34):
        radius = math.sqrt(RNG.random()) * 0.72
        angle = RNG.random() * math.tau
        height = RNG.uniform(0.35, 0.78)
        point = Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0.02))
        top = point + Vector((RNG.uniform(-0.08, 0.08), RNG.uniform(-0.08, 0.08), height))
        branch(g, [tuple(point), tuple(top)], 0.010, 0.006, "grass_dark", 5)
        role = ["flower_cream", "flower_blue", "flower_rose"][index % 3]
        for petal in range(5):
            a = petal * math.tau / 5
            g.rounded_sphere(top + Vector((math.cos(a) * 0.055, math.sin(a) * 0.055, 0)), (0.055, 0.035, 0.018), role, 6, 3)
        g.rounded_sphere(top + Vector((0, 0, 0.012)), (0.026, 0.026, 0.022), "fruit_yellow", 6, 3)
    return g, c


def ivy_wall_panel() -> tuple[G, G]:
    g, c = G(), G()
    for vine in range(11):
        x = -1.35 + vine * 0.27
        points = []
        for step in range(7):
            z = step * 0.48
            points.append((x + math.sin(step * 1.15 + vine) * 0.12, RNG.uniform(-0.015, 0.015), z))
        branch(g, points, 0.022, 0.009, "bark_dark", 6)
        for step, p in enumerate(points[1:]):
            for sign in (-1, 1):
                small_leaf(g, Vector(p) + Vector((sign * 0.09, -0.02, 0.02)), 0.13 + 0.02 * (step % 2), sign * 0.45, "leaf" if (step + vine) % 3 else "leaf_light")
    return g, c


def reed_cluster() -> tuple[G, G]:
    g, c = G(), G()
    for index in range(42):
        radius = math.sqrt(RNG.random()) * 0.75
        angle = RNG.random() * math.tau
        p = Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0))
        height = RNG.uniform(1.1, 2.2)
        branch(g, [tuple(p), tuple(p + Vector((RNG.uniform(-0.12, 0.12), RNG.uniform(-0.12, 0.12), height)))], 0.018, 0.009, "grass", 6)
        if index % 4 == 0:
            g.rounded_sphere(p + Vector((0, 0, height + 0.08)), (0.055, 0.055, 0.22), "bark_dark", 8, 5)
        if index % 3 == 0:
            blade(g, p + Vector((0, 0, height * 0.35)), height * 0.42, 0.025, angle + 0.7, "grass_light", 0.25)
    return g, c


def mossy_fallen_log() -> tuple[G, G]:
    g, c = G(), G()
    points = [(-2.1, 0, 0.40), (-1.1, 0.08, 0.48), (0.1, -0.05, 0.44), (1.25, 0.06, 0.38), (2.15, 0, 0.32)]
    branch(g, points, 0.48, 0.34, "bark_dark", 14)
    for index in range(9):
        x = -1.75 + index * 0.42
        g.rounded_sphere((x, -0.05, 0.68 + RNG.uniform(-0.03, 0.09)), (0.30, 0.22, 0.12), "moss" if index % 3 else "moss_light", 9, 5)
    for end_x, radius in [(-2.12, 0.49), (2.17, 0.35)]:
        g.rounded_sphere((end_x, 0, 0.40 if end_x < 0 else 0.32), (0.055, radius, radius), "bark_light", 12, 7)
        for ring in (0.15, 0.26, 0.36):
            g.tube([(end_x - 0.058, 0, 0.40), (end_x - 0.062, 0, 0.40 + ring * 0.3)], [ring, ring * 0.25], "bark_dark", 8)
    c.box((0, 0, 0.40), (4.3, 0.78, 0.72), "bark")
    return g, c


def herb_planter() -> tuple[G, G]:
    g, c = G(), G()
    g.box((0, 0, 0.28), (2.5, 0.92, 0.18), "timber_dark")
    for y in (-0.46, 0.46):
        g.box((0, y, 0.52), (2.6, 0.12, 0.62), "timber_warm")
    for x in (-1.25, 1.25):
        g.box((x, 0, 0.52), (0.12, 0.92, 0.62), "timber_warm")
    g.box((0, 0, 0.55), (2.30, 0.72, 0.18), "soil")
    for index in range(26):
        x, y = RNG.uniform(-1.05, 1.05), RNG.uniform(-0.28, 0.28)
        height = RNG.uniform(0.26, 0.62)
        branch(g, [(x, y, 0.61), (x + RNG.uniform(-0.06, 0.06), y, 0.61 + height)], 0.012, 0.006, "grass_dark", 5)
        small_leaf(g, Vector((x, y, 0.72 + height * 0.35)), 0.10, RNG.random() * math.tau, "leaf_light" if index % 4 == 0 else "leaf")
        small_leaf(g, Vector((x, y, 0.80 + height * 0.55)), 0.085, RNG.random() * math.tau, "leaf")
    c.box((0, 0, 0.34), (2.6, 0.96, 0.68), "timber_warm")
    return g, c


def mossy_boulders() -> tuple[G, G]:
    g, c = G(), G()
    specs = [((-0.8, 0.05, 0.62), (1.05, 0.85, 0.72)), ((0.58, 0.12, 0.45), (0.82, 0.66, 0.52)), ((0.05, -0.62, 0.26), (0.58, 0.46, 0.34))]
    for index, (point, scale) in enumerate(specs):
        g.ellipsoid(point, scale, "floor_stone" if index != 1 else "floor_stone_dark", 11, 7, 0.10)
        g.rounded_sphere(Vector(point) + Vector((0, -0.05, scale[2] * 0.72)), (scale[0] * 0.58, scale[1] * 0.52, 0.10), "moss" if index else "moss_light", 9, 5)
        c.ellipsoid(point, tuple(value * 0.86 for value in scale), "floor_stone", 8, 5)
    return g, c


def milestone() -> tuple[G, G]:
    g, c = G(), G()
    g.curved((0, 0, 0), [(0.72, 0), (0.78, 0.18), (0.64, 1.75), (0.40, 2.15), (0.05, 2.38)], "floor_stone", 16)
    g.box((0, -0.66, 1.20), (0.92, 0.12, 0.58), "floor_stone_light")
    for index in range(3):
        z = 1.02 + index * 0.18
        g.box((0, -0.735, z), (0.48 - index * 0.07, 0.035, 0.045), "system_blue")
    for index in range(9):
        angle = index * math.tau / 9
        g.rounded_sphere((math.cos(angle) * 0.45, math.sin(angle) * 0.45, 0.14), (0.11, 0.11, 0.07), "moss" if index % 2 else "floor_stone_dark", 8, 4)
    c.cylinder((0, 0, 0), 0.68, 2.2, "floor_stone", 10)
    return g, c


def timber_fence() -> tuple[G, G]:
    g, c = G(), G()
    for x in (-2.4, 0, 2.4):
        g.box((x, 0, 1.05), (0.26, 0.26, 2.1), "timber_dark")
        g.curved((x, 0, 2.10), [(0.19, 0), (0.18, 0.18), (0.04, 0.42)], "timber_warm", 8)
    for z in (0.62, 1.45):
        branch(g, [(-2.5, 0, z), (-0.85, 0.04, z + 0.10), (0.85, -0.03, z - 0.03), (2.5, 0, z + 0.05)], 0.12, 0.11, "timber_warm", 8)
    for index in range(8):
        x = -2.25 + index * 0.62
        branch(g, [(x, -0.10, 0.08), (x + math.sin(index) * 0.18, -0.14, 1.65)], 0.018, 0.007, "bark_dark", 5)
        for leaf_index in range(4):
            small_leaf(g, Vector((x + math.sin(index) * 0.08, -0.17, 0.42 + leaf_index * 0.31)), 0.11, 0.5 + leaf_index, "leaf" if index % 3 else "leaf_light")
    for x in (-2.4, 0, 2.4):
        c.box((x, 0, 1.0), (0.32, 0.32, 2.0), "timber_warm")
    return g, c


def stone_trough() -> tuple[G, G]:
    g, c = G(), G()
    g.box((0, 0.0, 0.24), (3.5, 1.45, 0.28), "floor_stone_dark")
    for y in (-0.62, 0.62):
        g.box((0, y, 0.67), (3.7, 0.26, 0.86), "floor_stone")
    for x in (-1.72, 1.72):
        g.box((x, 0, 0.67), (0.26, 1.45, 0.86), "floor_stone")
    g.box((0, 0, 0.67), (3.12, 0.98, 0.12), "water")
    for index in range(12):
        x = -1.45 + index * 0.26
        g.box((x, -0.01, 0.742), (0.15, 0.02, 0.012), "flower_blue")
    for x in (-1.72, 1.72):
        c.box((x, 0, 0.67), (0.30, 1.5, 0.90), "floor_stone")
    for y in (-0.62, 0.62):
        c.box((0, y, 0.67), (3.7, 0.30, 0.90), "floor_stone")
    return g, c


def rest_shelter() -> tuple[G, G]:
    g, c = G(), G()
    for x in (-2.2, 2.2):
        for y in (-1.45, 1.45):
            g.box((x, y, 1.75), (0.20, 0.20, 3.5), "timber_dark")
            g.box((x, y, 0.16), (0.48, 0.48, 0.32), "floor_stone")
            c.box((x, y, 1.6), (0.26, 0.26, 3.2), "timber_dark")
    for y in (-1.45, 1.45):
        branch(g, [(-2.35, y, 3.42), (0, y, 4.16), (2.35, y, 3.42)], 0.13, 0.13, "timber_warm", 9)
    for stripe in range(10):
        x0 = -2.45 + stripe * 0.49
        x1 = x0 + 0.475
        verts = [(x0, -1.62, 3.40), (x1, -1.62, 3.40), (x1, 0, 4.18), (x0, 0, 4.18), (x0, 1.62, 3.40), (x1, 1.62, 3.40)]
        g.mesh(verts, [(0, 1, 2, 3), (3, 2, 5, 4)], "canvas_green" if stripe % 2 else "canvas_cream")
    g.box((0, 0.72, 0.82), (3.8, 0.56, 0.18), "timber_warm")
    g.box((0, 1.02, 1.16), (3.8, 0.18, 0.95), "timber_dark")
    for x in (-1.62, 1.62):
        for y in (0.55, 0.92):
            g.box((x, y, 0.42), (0.18, 0.18, 0.72), "timber_dark")
    return g, c


def configure_materials() -> None:
    texture_root = REFERENCE_ROOT / "MarketCraftV5" / "textures"
    images = {
        "stone": bpy.data.images.load(str(texture_root / "stone_normal.png"), check_existing=True),
        "wood": bpy.data.images.load(str(texture_root / "wood_normal.png"), check_existing=True),
    }
    for image in images.values():
        image.colorspace_settings.name = "Non-Color"
        image.pack()
    for key, material in base.MATS.items():
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is None:
            continue
        principled.inputs["Roughness"].default_value = 0.36 if key == "water" else 0.72
        if key == "iron":
            principled.inputs["Metallic"].default_value = 0.68
        if key == "system_blue":
            emission_name = "Emission Color" if "Emission Color" in principled.inputs else "Emission"
            principled.inputs[emission_name].default_value = principled.inputs["Base Color"].default_value
            principled.inputs["Emission Strength"].default_value = 2.2
        surface = "wood" if key.startswith("bark") or key.startswith("timber") else "stone" if key.startswith("floor_stone") else ""
        if surface:
            image_node = material.node_tree.nodes.new("ShaderNodeTexImage")
            image_node.image = images[surface]
            image_node.extension = "REPEAT"
            normal = material.node_tree.nodes.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = 0.16
            material.node_tree.links.new(image_node.outputs["Color"], normal.inputs["Color"])
            material.node_tree.links.new(normal.outputs["Normal"], principled.inputs["Normal"])


ASSETS = [
    ("F1_ancient_oak", "古橡树", "tree", (5.8, 5.5, 8.2), ancient_oak),
    ("F1_birch_grove", "白桦组三株", "tree", (3.2, 3.0, 6.8), birch_grove),
    ("F1_cypress_column", "柱形柏树", "tree", (1.7, 1.7, 7.5), cypress_column),
    ("F1_stone_pine", "石地松树", "tree", (5.2, 5.0, 6.8), stone_pine),
    ("F1_orchard_apple", "果园苹果树", "tree", (3.8, 3.8, 5.2), orchard_apple),
    ("F1_young_maple", "幼枫树", "tree", (3.1, 3.1, 4.6), young_maple),
    ("F1_flowering_shrub", "开花灌木", "shrub", (2.0, 2.0, 1.8), flowering_shrub),
    ("F1_berry_bush", "浆果丛", "shrub", (1.8, 1.8, 1.4), berry_bush),
    ("F1_fern_patch", "蕨类地被", "groundcover", (2.0, 1.8, 0.9), fern_patch),
    ("F1_meadow_grass", "草甸草簇", "groundcover", (1.8, 1.8, 0.9), meadow_grass),
    ("F1_wildflower_patch", "野花草簇", "groundcover", (1.8, 1.8, 0.9), wildflower_patch),
    ("F1_ivy_wall_panel", "常春藤墙面", "climber", (3.2, 0.4, 3.2), ivy_wall_panel),
    ("F1_reed_cluster", "芦苇簇", "waterside", (1.8, 1.8, 2.5), reed_cluster),
    ("F1_mossy_fallen_log", "苔藓倒木", "natural_prop", (4.6, 1.2, 1.0), mossy_fallen_log),
    ("F1_herb_planter", "香草种植箱", "cultivated", (2.7, 1.1, 1.3), herb_planter),
    ("F1_mossy_boulder_cluster", "苔石组", "natural_prop", (3.0, 2.2, 1.6), mossy_boulders),
    ("F1_roadside_milestone", "道路里程碑", "street_prop", (1.6, 1.6, 2.5), milestone),
    ("F1_timber_fence_vine", "藤蔓木栅栏", "boundary", (5.2, 0.7, 2.6), timber_fence),
    ("F1_stone_water_trough", "石质水槽", "street_prop", (3.9, 1.7, 1.2), stone_trough),
    ("F1_canvas_rest_shelter", "帆布休憩棚", "large_component", (5.2, 3.6, 4.4), rest_shelter),
]

PLANT_GROUPS = {
    "canopy_trees": {
        "label_zh": "乔木冠层",
        "asset_ids": ["F1_ancient_oak", "F1_birch_grove", "F1_cypress_column", "F1_stone_pine", "F1_orchard_apple", "F1_young_maple"],
        "wind_profile": "tree_gentle",
    },
    "shrubs_and_cultivated": {
        "label_zh": "灌木与栽培",
        "asset_ids": ["F1_flowering_shrub", "F1_berry_bush", "F1_herb_planter"],
        "wind_profile": "shrub_soft",
    },
    "groundcovers": {
        "label_zh": "地被植物",
        "asset_ids": ["F1_fern_patch", "F1_meadow_grass", "F1_wildflower_patch"],
        "wind_profile": "ground_breeze",
    },
    "climbers": {
        "label_zh": "攀援植物",
        "asset_ids": ["F1_ivy_wall_panel"],
        "wind_profile": "climber_subtle",
    },
    "wetland": {
        "label_zh": "湿地植物",
        "asset_ids": ["F1_reed_cluster"],
        "wind_profile": "reed_sway",
    },
    "deadwood_and_moss": {
        "label_zh": "枯木与苔藓",
        "asset_ids": ["F1_mossy_fallen_log"],
        "wind_profile": "static",
    },
}

WIND_OVERRIDES = {"F1_herb_planter": "static_container"}


def plant_group_for(asset_id: str) -> str | None:
    for group_id, group in PLANT_GROUPS.items():
        if asset_id in group["asset_ids"]:
            return group_id
    return None


def wind_profile_for(asset_id: str) -> str:
    if asset_id in WIND_OVERRIDES:
        return WIND_OVERRIDES[asset_id]
    group_id = plant_group_for(asset_id)
    return PLANT_GROUPS[group_id]["wind_profile"] if group_id else "static"


def triangles(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def export_asset(record: dict) -> dict:
    bpy.ops.object.select_all(action="DESELECT")
    record["visual"].select_set(True)
    collision_triangles = triangles(record["collision"])
    if collision_triangles > 0:
        record["collision"].select_set(True)
    path = EXPORT / f"{record['id']}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        use_active_scene=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_apply=True,
    )
    return {
        "id": record["id"],
        "label_zh": record["label_zh"],
        "category": record["category"],
        "dimensions_m": list(record["dimensions"]),
        "file": path.relative_to(PROJECT).as_posix(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "visual_triangles": triangles(record["visual"]),
        "collision_triangles": collision_triangles,
        "collision_proxy": collision_triangles > 0,
        "origin": "ground_center",
        "plant_group": plant_group_for(record["id"]),
        "wind_profile": wind_profile_for(record["id"]),
    }


def setup_showcase(source_scene: bpy.types.Scene, records: list[dict]) -> tuple[bpy.types.Scene, list[bpy.types.Object]]:
    scene = bpy.data.scenes.new("Floor1_EnvironmentKit20_Showcase")
    bpy.context.window.scene = scene
    collection = bpy.data.collections.new("SHOWCASE_environment_kit_20")
    scene.collection.children.link(collection)
    display_objects = []
    positions = [
        (-18, 7, 0), (-9, 7, 0), (0, 7, 0), (9, 7, 0), (18, 7, 0),
        (-18, -2, 0), (-9, -2, 0), (0, -2, 0), (9, -2, 0), (18, -2, 0),
        (-18, -10, 0), (-9, -10, 0), (0, -10, 0), (9, -10, 0), (18, -10, 0),
        (-18, -17, 0), (-9, -17, 0), (0, -17, 0), (9, -17, 0), (18, -17, 0),
    ]
    for index, (record, position) in enumerate(zip(records, positions)):
        sources = [record["visual"]]
        if triangles(record["collision"]) > 0:
            sources.append(record["collision"])
        for source in sources:
            duplicate = source.copy()
            duplicate.data = source.data
            duplicate.location = Vector(position)
            duplicate["source_asset_id"] = record["id"]
            duplicate.hide_render = source.name.startswith("COL_")
            collection.objects.link(duplicate)
            display_objects.append(duplicate)
        plaque = G()
        plaque.box((position[0], position[1] - 2.15, 0.10), (4.9, 0.62, 0.18), "floor_stone_dark")
        plaque_obj = emit(plaque, collection, f"SHOWCASE_plaque_{index + 1:02d}", False, 0.02)
        plaque_obj["source_asset_id"] = record["id"]
        text_data = bpy.data.curves.new(f"SHOWCASE_label_{index + 1:02d}", "FONT")
        text_data.body = f"{index + 1:02d}  {record['id'].removeprefix('F1_').replace('_', ' ')}"
        text_data.align_x = "CENTER"
        text_data.align_y = "CENTER"
        text_data.size = 0.33
        text_data.extrude = 0.008
        text_obj = bpy.data.objects.new(text_data.name, text_data)
        text_obj.location = Vector((position[0], position[1] - 2.48, 0.24))
        text_obj.rotation_euler.x = math.radians(68)
        text_obj.data.materials.append(base.material("flower_cream"))
        text_obj["source_asset_id"] = record["id"]
        collection.objects.link(text_obj)
    ground = G()
    ground.box((0, -4.8, -0.14), (46, 30, 0.28), "floor_stone")
    for x in range(-22, 23, 2):
        ground.box((x, -4.8, 0.008), (0.022, 30, 0.012), "floor_stone_light")
    for y in range(-19, 10, 2):
        ground.box((0, y, 0.010), (46, 0.022, 0.012), "floor_stone_light")
    emit(ground, collection, "SHOWCASE_ground", False, 0.0)

    world = bpy.data.worlds.new("Floor1_EnvironmentKit20_world")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.055, 0.095, 0.15, 1)
    bg.inputs[1].default_value = 0.34
    scene.world = world
    sun_data = bpy.data.lights.new("SHOWCASE_sun", "SUN")
    sun_data.energy = 2.2
    sun_data.color = (1.0, 0.72, 0.48)
    sun_data.angle = math.radians(5)
    sun = bpy.data.objects.new("SHOWCASE_sun", sun_data)
    sun.rotation_euler = (math.radians(42), 0, math.radians(-28))
    collection.objects.link(sun)
    area_data = bpy.data.lights.new("SHOWCASE_sky_fill", "AREA")
    area_data.energy = 1300
    area_data.color = (0.52, 0.70, 1.0)
    area_data.shape = "DISK"
    area_data.size = 18
    area = bpy.data.objects.new("SHOWCASE_sky_fill", area_data)
    area.location = (0, -3, 18)
    collection.objects.link(area)

    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 18
    scene.view_settings.look = "AgX - Medium High Contrast"
    hq.camera(scene, "SHOWCASE_camera", Vector((31, -40, 24)), Vector((0, -4, 3.0)), 58)
    return scene, display_objects


def render_showcase(scene: bpy.types.Scene, records: list[dict]) -> list[str]:
    camera = scene.camera
    output_paths = []
    vegetation_ids = {record["id"] for record in records[:15]}
    component_ids = {record["id"] for record in records[15:]}

    def show_only(asset_ids: set[str]) -> None:
        for obj in scene.objects:
            source_id = obj.get("source_asset_id")
            if source_id:
                obj.hide_render = source_id not in asset_ids or obj.name.startswith("COL_")

    show_only(vegetation_ids)
    vegetation = VALIDATION / "environment_kit_20_vegetation.png"
    scene.render.filepath = str(vegetation)
    camera.location = Vector((25, -43, 24))
    camera.rotation_euler = (Vector((0, -1.3, 3.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    output_paths.append(vegetation.relative_to(PROJECT).as_posix())

    show_only(component_ids)
    components = VALIDATION / "environment_kit_20_components.png"
    scene.render.filepath = str(components)
    camera.location = Vector((0, -66, 15.5))
    camera.rotation_euler = (Vector((0, -17.0, 1.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    output_paths.append(components.relative_to(PROJECT).as_posix())
    show_only({record["id"] for record in records})
    return output_paths


def export_showcase(scene: bpy.types.Scene, display_objects: list[bpy.types.Object]) -> tuple[Path, str]:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in display_objects:
        obj.select_set(True)
    path = EXPORT / "Floor1_EnvironmentKit20_Showcase.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        use_active_scene=True,
        export_extras=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_apply=True,
    )
    return path, hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    global RNG
    options = args()
    RNG = random.Random(options.seed)
    base.RNG = random.Random(options.seed)
    EXPORT.mkdir(parents=True, exist_ok=True)
    VALIDATION.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source_scene = bpy.context.scene
    source_scene.name = "Floor1_EnvironmentKit20_Source"
    source_scene["style_id"] = STYLE
    source_scene["copyright_boundary"] = "original broad-setting environment components; no traced frames or restricted assets"
    records = []
    for asset_id, label_zh, category, dimensions, builder in ASSETS:
        collection = asset_collection(source_scene, asset_id)
        visual_geo, collision_geo = builder()
        visual = emit(visual_geo, collection, asset_id, False, 0.010)
        collision = emit(collision_geo, collection, f"COL_{asset_id}", True, 0.0)
        group_id = plant_group_for(asset_id)
        if group_id:
            collection["plant_group"] = group_id
            visual["plant_group"] = group_id
        visual["wind_profile"] = wind_profile_for(asset_id)
        records.append(
            {
                "id": asset_id,
                "label_zh": label_zh,
                "category": category,
                "dimensions": dimensions,
                "visual": visual,
                "collision": collision,
            }
        )
    configure_materials()
    exported = [export_asset(record) for record in records]
    showcase, display_objects = setup_showcase(source_scene, records)
    showcase_path, showcase_sha = export_showcase(showcase, display_objects)
    renders = render_showcase(showcase, records) if options.render else []
    bpy.ops.object.select_all(action="DESELECT")
    if showcase.camera:
        showcase.camera.select_set(True)
        bpy.context.view_layer.objects.active = showcase.camera
    blend_path = HERE / "Floor1_EnvironmentKit20.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
    manifest = {
        "schema": 1,
        "id": "Floor1_EnvironmentKit20",
        "style_id": STYLE,
        "seed": options.seed,
        "blender_version": bpy.app.version_string,
        "source": "project-authored Codex-assisted Blender Python",
        "copyright_boundary": "original broad-setting environment components; no traced frames or restricted source/private assets",
        "asset_count": len(exported),
        "vegetation_and_natural_asset_count": 15,
        "plant_groups": PLANT_GROUPS,
        "wind_overrides": WIND_OVERRIDES,
        "showcase": {
            "file": showcase_path.relative_to(PROJECT).as_posix(),
            "sha256": showcase_sha,
            "purpose": "catalogue preview only; use individual GLBs for placement",
        },
        "renders": renders,
        "assets": exported,
        "limits": [
            "first authored variation per component; not biome-scale variation",
            "individual LOD tiers and vertex or branch-level wind deformation are not included",
            "Godot provides category-tuned visual-root sway while collision stays static",
            "collision proxies are conservative and require gameplay review after placement",
            "visual approval remains pending",
        ],
        "visual_approval": False,
        "first_version_complete": False,
    }
    for path in [HERE / "floor1_environment_kit_20_manifest.json", EXPORT / "manifest.json", VALIDATION / "manifest.json"]:
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"stage": "complete", "asset_count": len(exported), "showcase_sha256": showcase_sha}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
