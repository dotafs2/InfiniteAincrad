"""Build an original, modular Floor-1 starting-town hero kit.

The design language is intentionally broad: ancient-European stonework, warm
timber commerce, fortified arches and restrained blue system-light accents.
It does not trace anime frames or import source-project/private assets.

Run with Blender 5.2 LTS:
  blender --background --python build_floor1_hero_kit.py -- --seed 101
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
EXPORT = PROJECT / "game" / "assets" / "floor1"
VALIDATION = PROJECT / "docs" / "validation" / "floor1_art_2026-09-11"
sys.path.insert(0, str(REFERENCE_ROOT))

import build_reference_scenes as base  # noqa: E402
import build_reference_scenes_hq as hq  # noqa: E402


STYLE = "floor1_starting_town_hero_kit_v1"
G = hq.G
RNG = random.Random(101)
CREATED: list[bpy.types.Object] = []

base.STYLE = STYLE
hq.STYLE = STYLE
base.PALETTE.update(
    {
        "floor_stone": "BEB69D",
        "floor_stone_light": "DED4B8",
        "floor_stone_dark": "817D70",
        "plaster_warm": "E7D6B6",
        "plaster_rose": "D8B5A4",
        "timber_warm": "74583B",
        "timber_dark": "3C382E",
        "roof_terracotta": "9E5E52",
        "roof_highlight": "C37C65",
        "system_blue": "57BFD0",
        "window_warm": "F3BC6B",
        "forge_coal": "E85D32",
        "banner_blue": "426B82",
        "banner_gold": "D6AE62",
        "verdigris": "54766D",
        "paper": "D9C99E",
    }
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=101)
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--render", action="store_true", default=True)
    values = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(values)


def emit(
    geo: G,
    collection: bpy.types.Collection,
    name: str,
    bevel: float = 0.012,
    collision: bool = False,
    transform: Matrix | None = None,
) -> bpy.types.Object:
    obj = geo.obj(name, collection, bevel, collision)
    obj["asset_kit"] = STYLE
    obj["original_project_asset"] = True
    obj["collision_enabled"] = collision
    if transform is not None:
        obj.matrix_world = transform
    CREATED.append(obj)
    return obj


def tweak_materials() -> None:
    """Give authored materials useful PBR separation in Blend and GLB."""
    texture_root = REFERENCE_ROOT / "MarketCraftV5" / "textures"
    normal_images = {
        "stone": bpy.data.images.load(str(texture_root / "stone_normal.png"), check_existing=True),
        "wood": bpy.data.images.load(str(texture_root / "wood_normal.png"), check_existing=True),
        "plaster": bpy.data.images.load(str(texture_root / "plaster_normal.png"), check_existing=True),
    }
    for image in normal_images.values():
        image.colorspace_settings.name = "Non-Color"
        image.pack()
    for key, mat in base.MATS.items():
        principled = mat.node_tree.nodes.get("Principled BSDF")
        if principled is None:
            continue
        principled.inputs["Roughness"].default_value = {
            "glass": 0.18,
            "window_warm": 0.23,
            "system_blue": 0.22,
            "iron": 0.36,
            "brass": 0.31,
            "verdigris": 0.44,
        }.get(key, 0.68 if "roof" in key else 0.76)
        if key in {"iron", "brass", "verdigris"}:
            principled.inputs["Metallic"].default_value = 0.72
        if key in {"window_warm", "system_blue", "forge_coal"}:
            color = principled.inputs["Base Color"].default_value
            emission_name = "Emission Color" if "Emission Color" in principled.inputs else "Emission"
            principled.inputs[emission_name].default_value = color
            principled.inputs["Emission Strength"].default_value = {
                "window_warm": 1.15,
                "system_blue": 2.4,
                "forge_coal": 3.3,
            }[key]
        surface = (
            "wood"
            if key in {"wood", "wood_light", "wood_dark", "timber_warm", "timber_dark"}
            else "plaster"
            if key.startswith("plaster")
            else "stone"
            if key in {"limestone", "stone_light", "stone_shade", "floor_stone", "floor_stone_light", "floor_stone_dark", "paving", "paving_light"}
            else ""
        )
        if surface:
            image_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
            image_node.name = "Project-authored micro normal"
            image_node.image = normal_images[surface]
            image_node.extension = "REPEAT"
            normal_node = mat.node_tree.nodes.new("ShaderNodeNormalMap")
            normal_node.inputs["Strength"].default_value = 0.20 if surface == "stone" else 0.14
            mat.node_tree.links.new(image_node.outputs["Color"], normal_node.inputs["Color"])
            mat.node_tree.links.new(normal_node.outputs["Normal"], principled.inputs["Normal"])


def add_stone_courses(geo: G, x: float, y: float, w: float, h: float, front: float = -0.04) -> None:
    """Sparse dressed courses: enough parallax without procedural visual noise."""
    row_h = 0.38
    block_w = 0.88
    for row in range(math.ceil(h / row_h)):
        offset = -block_w * 0.5 if row % 2 else 0.0
        count = math.ceil(w / block_w) + 2
        for col in range(count):
            left = x - w * 0.5 + col * block_w + offset
            right = min(x + w * 0.5, left + block_w - 0.025)
            left = max(x - w * 0.5, left)
            if right - left < 0.12:
                continue
            z = 0.08 + row * row_h
            geo.box(
                ((left + right) * 0.5, y + front - RNG.uniform(0.0, 0.015), z + row_h * 0.46),
                (right - left, 0.08, row_h * 0.86),
                RNG.choice(["floor_stone", "floor_stone", "floor_stone_light", "floor_stone_dark"]),
            )


def battlement(geo: G, center: Vector, width: float, depth: float, z: float) -> None:
    geo.box((center.x, center.y, z), (width, depth, 0.32), "floor_stone_light")
    merlon = 0.62
    slots = max(3, round(width / 1.05))
    for index in range(slots):
        x = center.x - width * 0.5 + (index + 0.5) * width / slots
        for y in (center.y - depth * 0.5 + 0.25, center.y + depth * 0.5 - 0.25):
            geo.box((x, y, z + 0.48), (merlon, 0.48, 0.72), "floor_stone_light")
    side_slots = max(2, round(depth / 1.05))
    for index in range(side_slots):
        y = center.y - depth * 0.5 + (index + 0.5) * depth / side_slots
        for x in (center.x - width * 0.5 + 0.25, center.x + width * 0.5 - 0.25):
            geo.box((x, y, z + 0.48), (0.48, merlon, 0.72), "floor_stone_light")


def gatehouse(collection: bpy.types.Collection, origin: Vector) -> dict:
    masonry = G()
    details = G()
    collision = G()
    opening = 4.8
    spring = 4.2
    arch_r = opening * 0.5
    total_w = 15.8
    depth = 4.8
    wall_h = 8.25

    # True traversable opening: separate piers and top mass, never a black decal.
    pier_w = (total_w - opening) * 0.5
    for side in (-1, 1):
        x = side * (opening * 0.5 + pier_w * 0.5)
        masonry.box((x, 0, wall_h * 0.5), (pier_w, depth, wall_h), "floor_stone")
        collision.box((x, 0, wall_h * 0.5), (pier_w, depth, wall_h))
        add_stone_courses(details, x, -depth * 0.5, pier_w - 0.18, wall_h)
    masonry.box((0, 0, 7.15), (opening, depth, 2.2), "floor_stone")
    collision.box((0, 0, 7.15), (opening, depth, 2.2))

    for face_y in (-depth * 0.5 - 0.08, depth * 0.5 + 0.08):
        details.arch(0, face_y, spring, arch_r, 0.38, 0.34, "floor_stone_light", 28)
        details.arch(0, face_y - (0.12 if face_y < 0 else -0.12), spring, arch_r + 0.46, 0.12, 0.42, "floor_stone_dark", 30)
        for side in (-1, 1):
            details.box((side * (opening * 0.5 + 0.19), face_y, spring * 0.5), (0.38, 0.38, spring), "floor_stone_light")
            details.box((side * (opening * 0.5 + 0.34), face_y, 0.18), (0.82, 0.62, 0.34), "floor_stone_light")

    # Twin watch towers and warm tiled caps.
    for side in (-1, 1):
        x = side * 6.15
        tower = G()
        tower.box((x, 0, 4.9), (3.9, 5.65, 9.8), "floor_stone")
        for level in (0.45, 3.25, 6.55, 9.45):
            tower.box((x, 0, level), (4.18, 5.94, 0.28), "floor_stone_light")
        # Deep slit windows and articulated surrounds.
        for z in (3.5, 6.55):
            tower.box((x, -2.91, z), (0.48, 0.16, 1.15), "floor_stone_dark")
            tower.arch(x, -3.01, z + 0.91, 0.24, 0.13, 0.18, "floor_stone_light", 10)
            for sx in (-0.31, 0.31):
                tower.box((x + sx, -3.01, z + 0.38), (0.13, 0.22, 1.06), "floor_stone_light")
        battlement(tower, Vector((x, 0, 0)), 4.18, 5.94, 9.82)
        roof = G()
        hq.hip_roof(roof, 3.35, 4.85, 10.66, 2.15)
        tower.add(roof, (x, -4.85 * 0.5, 0.0))
        for sx in (-1, 1):
            for sy in (-1, 1):
                tower.box((x + sx * 1.38, sy * 2.08, 10.25), (0.16, 0.16, 0.95), "timber_dark")
                tower.beam((x + sx * 1.38, sy * 2.08, 10.16), (x + sx * 1.02, sy * 1.72, 10.68), 0.10, "timber_warm")
        tower.box((x, 0, 10.62), (3.55, 5.05, 0.14), "timber_dark")
        emit(tower, collection, f"F1_gate_watchtower_{'east' if side > 0 else 'west'}", 0.012, False, Matrix.Translation(origin))
        collision.box((x, 0, 4.9), (3.9, 5.65, 9.8))

    # Crest is original geometric heraldry, not a copied series emblem.
    crest = G()
    crest.curved((0, -2.74, 8.05), [(1.02, 0), (1.14, 0.13), (1.09, 0.24), (0.76, 0.31)], "verdigris", 40)
    crest.curved((0, -2.92, 8.05), [(0.62, 0), (0.72, 0.09), (0.67, 0.16), (0.18, 0.19)], "system_blue", 36)
    crest.beam((-0.48, -3.02, 7.68), (0.48, -3.02, 8.42), 0.075, "banner_gold")
    crest.beam((0.48, -3.03, 7.68), (-0.48, -3.03, 8.42), 0.075, "banner_gold")
    emit(crest, collection, "F1_gate_original_wayfarer_crest", 0.006, False, Matrix.Translation(origin))

    banners = G()
    for side in (-1, 1):
        x = side * 6.15
        vertices = [(x - 0.52, -2.91, 8.25), (x + 0.52, -2.91, 8.25), (x + 0.52, -2.91, 6.35), (x, -2.94, 5.87), (x - 0.52, -2.91, 6.35)]
        banners.mesh(vertices, [(0, 1, 2, 3, 4)], "banner_blue")
        banners.box((x, -2.97, 8.29), (1.28, 0.08, 0.10), "banner_gold")
        banners.beam((x - 0.28, -2.98, 6.56), (x + 0.28, -2.98, 7.36), 0.055, "banner_gold")
        banners.beam((x + 0.28, -2.98, 6.56), (x - 0.28, -2.98, 7.36), 0.055, "banner_gold")
    emit(banners, collection, "F1_gate_wayfarer_banners", 0.003, False, Matrix.Translation(origin))

    # Raised timber gate leaves, chains and hinge hardware.
    gate = G()
    for side in (-1, 1):
        leaf_x = side * 1.28
        for index in range(7):
            x = leaf_x + side * (index - 3) * 0.17
            gate.box((x, -2.28, 5.35), (0.14, 0.18, 3.6), "timber_dark")
        for z in (3.8, 5.2, 6.7):
            gate.box((leaf_x, -2.39, z), (2.45, 0.12, 0.16), "iron")
        gate.tube([(side * 0.2, -2.48, 7.5), (side * 1.1, -2.48, 6.6), (side * 1.6, -2.48, 5.8)], [0.055] * 3, "iron", 10)
    emit(gate, collection, "F1_gate_raised_oak_leaves", 0.008, False, Matrix.Translation(origin))

    transform = Matrix.Translation(origin)
    emit(masonry, collection, "F1_gatehouse_masonry", 0.014, False, transform)
    emit(details, collection, "F1_gatehouse_dressed_stone", 0.006, False, transform)
    emit(collision, collection, "COL_F1_gatehouse", 0.0, True, transform)
    return {"id": "gatehouse", "dimensions_m": [total_w, depth, 12.8], "walkable_opening_m": [opening, spring + arch_r]}


def timber_shop(
    collection: bpy.types.Collection,
    name: str,
    position: Vector,
    yaw: float,
    plaster: str,
    awning: str,
    seed_offset: int,
) -> dict:
    local_rng = random.Random(RNG.randint(0, 10_000) + seed_offset)
    w, d, h = 8.6 + local_rng.uniform(-0.35, 0.35), 6.5, 7.4 + local_rng.uniform(-0.25, 0.35)
    openings = [
        (-w * 0.31, 3.95, 1.02, 1.82, True, True),
        (0.0, 4.12, 1.12, 1.92, True, True),
        (w * 0.31, 3.95, 1.02, 1.82, True, True),
    ]
    hq.facade(name, collection, w, d, h, openings, position, yaw, False, plaster, "gable", -w * 0.25, True, False)
    hq.draped_awning(name + "_awning", collection, position, yaw, w * 0.54, 1.85, 3.12, awning, 0.22)

    # Exterior structural timber, balcony and readable shop silhouette.
    g = G()
    for x in (-w * 0.5 + 0.35, -w * 0.17, w * 0.17, w * 0.5 - 0.35):
        g.box((x, -0.23, 5.15), (0.16, 0.20, 3.45), "timber_dark")
    for z in (3.55, 6.72):
        g.box((0, -0.24, z), (w - 0.25, 0.20, 0.17), "timber_dark")
    for x in (-w * 0.32, 0.0, w * 0.32):
        g.beam((x - 0.72, -0.245, 3.68), (x + 0.72, -0.245, 6.54), 0.11, "timber_warm")
        g.beam((x + 0.72, -0.255, 3.68), (x - 0.72, -0.255, 6.54), 0.11, "timber_warm")
    g.box((w * 0.26, -0.82, 3.72), (w * 0.42, 1.05, 0.14), "timber_warm")
    for x in (w * 0.08, w * 0.22, w * 0.36, w * 0.44):
        g.box((x, -1.26, 4.18), (0.075, 0.075, 0.92), "timber_dark")
    g.box((w * 0.26, -1.27, 4.62), (w * 0.39, 0.08, 0.09), "timber_dark")
    transform = Matrix.Translation(position) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    emit(g, collection, name + "_timber_balcony", 0.007, False, transform)
    return {"id": name, "dimensions_m": [round(w, 3), d, round(h, 3)], "variant_seed": seed_offset}


def forge(collection: bpy.types.Collection, position: Vector, yaw: float) -> dict:
    w, d, h = 8.2, 6.8, 6.65
    openings = [(-2.2, 3.72, 0.95, 1.72, True, False), (1.9, 3.72, 0.95, 1.72, True, True)]
    hq.facade("F1_forge", collection, w, d, h, openings, position, yaw, True, "plaster_warm", "hip", 2.5, True, False)
    hq.draped_awning("F1_forge_heavy_awning", collection, position, yaw, 4.7, 2.05, 3.15, "canvas_red", 0.16)
    g = G()
    # Forge hearth, chimney courses, anvil, quench barrel and tool rack.
    g.box((-1.45, -0.55, 0.62), (2.4, 1.25, 1.22), "floor_stone_dark")
    g.box((-1.45, -1.18, 0.92), (1.58, 0.16, 0.52), "forge_coal")
    g.box((-1.45, -0.42, 4.4), (1.35, 1.2, 8.8), "floor_stone")
    for z in [0.55 + i * 0.42 for i in range(20)]:
        g.box((-1.45, -1.04, z), (1.43, 0.07, 0.09), "floor_stone_light")
    g.box((0.55, -1.25, 0.68), (1.12, 0.42, 0.22), "iron")
    g.box((0.22, -1.25, 0.95), (0.45, 0.34, 0.36), "iron")
    g.box((0.55, -1.25, 0.35), (0.22, 0.22, 0.58), "timber_dark")
    hq.barrel(g, (1.8, -1.25, 0.0), 0.82, True)
    g.box((3.25, -0.38, 1.35), (0.16, 0.18, 2.7), "timber_dark")
    for z in (0.52, 1.1, 1.68, 2.26):
        g.box((3.02, -0.54, z), (0.62, 0.12, 0.10), "timber_warm")
        g.beam((2.88, -0.64, z - 0.18), (3.18, -0.64, z + 0.26), 0.055, "iron")
    transform = Matrix.Translation(position) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    emit(g, collection, "F1_forge_working_set", 0.008, False, transform)
    return {"id": "forge", "dimensions_m": [w, d, h + 4.15], "interactive_props": ["hearth", "anvil", "quench_barrel", "tool_rack"]}


def street_props(collection: bpy.types.Collection) -> list[dict]:
    records: list[dict] = []
    # A notice board sized for future in-world contracts rather than decorative text.
    board = G()
    for x in (-1.28, 1.28):
        board.box((x, 0, 1.34), (0.16, 0.22, 2.68), "timber_dark")
        board.box((x, 0, 0.16), (0.46, 0.54, 0.20), "floor_stone_light")
    board.box((0, 0, 1.65), (2.8, 0.24, 1.7), "timber_warm")
    board.box((0, -0.14, 1.65), (2.48, 0.05, 1.38), "timber_dark")
    for px, pz, pw, ph, angle in [(-0.72, 1.82, 0.72, 0.64, -4), (0.2, 1.48, 0.82, 0.72, 3), (0.83, 1.92, 0.64, 0.52, -2)]:
        board.box((px, -0.184, pz), (pw, 0.018, ph), "paper", Matrix.Rotation(math.radians(angle), 3, "Y"))
        for corner_x in (-pw * 0.43, pw * 0.43):
            board.rounded_sphere((px + corner_x, -0.204, pz + ph * 0.4), (0.035, 0.025, 0.035), "brass", 10, 5)
    hq.curved_roof(board, 3.4, 0.72, 2.62, 0.62)
    emit(board, collection, "F1_contract_notice_board", 0.008, False, Matrix.Translation(Vector((-3.75, 12.4, 0.0))))
    records.append({"id": "contract_notice_board", "future_state_surface": True})

    # Four restrained lanterns: warm life against cool system accents.
    lamps = G()
    for x, y in [(-4.9, 2.5), (4.9, 7.8), (-4.9, 18.0), (4.9, 22.3)]:
        lamps.tube([(x, y, 0.0), (x, y, 3.65), (x * 0.93, y, 3.95)], [0.09, 0.075, 0.055], "verdigris", 14)
        lamps.box((x * 0.93, y, 3.55), (0.42, 0.42, 0.72), "window_warm")
        for sx in (-0.24, 0.24):
            for sy in (-0.24, 0.24):
                lamps.box((x * 0.93 + sx, y + sy, 3.55), (0.045, 0.045, 0.82), "iron")
        lamps.curved((x * 0.93, y, 3.96), [(0.34, 0.0), (0.14, 0.28), (0.04, 0.34)], "verdigris", 18)
    emit(lamps, collection, "F1_street_lantern_set", 0.005)
    records.append({"id": "street_lantern", "instances": 4})

    # Merchant handcart with individually modeled wheel spokes and cargo.
    cart = G()
    cart.box((0, 0, 0.72), (2.65, 1.42, 0.20), "timber_warm")
    for x in (-1.27, 1.27):
        cart.box((x, 0, 1.13), (0.16, 1.42, 0.84), "timber_dark")
    for y in (-0.82, 0.82):
        wheel_path = [(0.72 * math.cos(index * math.tau / 32), y, 0.85 + 0.72 * math.sin(index * math.tau / 32)) for index in range(33)]
        cart.tube(wheel_path, [0.075] * len(wheel_path), "timber_dark", 10)
        for spoke in range(10):
            angle = spoke * math.tau / 10
            cart.beam((0, y, 0.85), (0.62 * math.cos(angle), y, 0.85 + 0.62 * math.sin(angle)), 0.045, "timber_warm")
        cart.beam((0, y - 0.18, 0.85), (0, y + 0.18, 0.85), 0.18, "iron")
    cart.beam((1.25, -0.42, 0.62), (3.55, -0.42, 0.28), 0.12, "timber_dark")
    cart.beam((1.25, 0.42, 0.62), (3.55, 0.42, 0.28), 0.12, "timber_dark")
    for x, y, z, role in [(-0.75, -0.36, 1.05, "canvas_gold"), (0.1, 0.28, 1.02, "canvas_green"), (0.75, -0.1, 1.12, "canvas_red")]:
        cart.rounded_sphere((x, y, z), (0.48, 0.42, 0.38), role, 14, 8)
        cart.tube([(x - 0.25, y, z + 0.16), (x + 0.25, y, z + 0.18)], [0.025, 0.025], "rope" if "rope" in base.PALETTE else "timber_dark", 8)
    transform = Matrix.Translation(Vector((3.15, 15.6, 0.0))) @ Matrix.Rotation(math.radians(19), 4, "Z")
    emit(cart, collection, "F1_merchant_handcart", 0.007, False, transform)
    records.append({"id": "merchant_handcart", "wheel_spokes": 20})
    return records


def plaza(collection: bpy.types.Collection) -> dict:
    paving = G()
    # Irregular but deterministic fitted stones; central lane remains flat and navigable.
    for row in range(60):
        y = -4.0 + row * 0.56
        cols = 21
        for col in range(cols):
            x = -5.8 + col * 0.58 + (0.28 if row % 2 else 0.0)
            if abs(x) > 6.0:
                continue
            shade = RNG.choice(["paving", "paving", "floor_stone", "paving_light"])
            paving.box((x, y, -0.015 - RNG.uniform(0, 0.012)), (0.54, 0.52, 0.09), shade)
    paving.box((0, 12.5, -0.16), (16.0, 39.0, 0.28), "floor_stone_dark")
    for side in (-1, 1):
        paving.box((side * 6.35, 12.5, 0.11), (0.34, 39.0, 0.32), "floor_stone_light")
    emit(paving, collection, "F1_plaza_fitted_paving", 0.004)
    col = G()
    col.box((0, 12.5, -0.11), (16.0, 39.0, 0.24))
    emit(col, collection, "COL_F1_plaza", 0.0, True)

    # Original arrival waystone: an architectural accent, not a copied teleport plaza.
    stone = G()
    stone.curved((0, 7.6, 0.0), [(1.95, 0.0), (2.02, 0.16), (1.78, 0.31), (1.28, 0.44)], "floor_stone_light", 56)
    stone.curved((0, 7.6, 0.42), [(1.22, 0.0), (1.34, 0.15), (0.46, 0.22)], "floor_stone", 48)
    for index in range(12):
        angle = index * math.tau / 12
        x, y = 0.83 * math.cos(angle), 7.6 + 0.83 * math.sin(angle)
        stone.box((x, y, 0.61), (0.16, 0.16, 0.06), "system_blue", Matrix.Rotation(angle, 3, "Z"))
    emit(stone, collection, "F1_arrival_waystone", 0.006)
    return {"id": "plaza", "walkable_width_m": 12.0, "waystone_is_original": True}


def add_rendering(scene: bpy.types.Scene, samples: int) -> None:
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(VALIDATION / "floor1_hero.png")
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 18
    scene.render.resolution_percentage = 100
    scene.view_settings.look = "AgX - Medium High Contrast"

    # Golden late-afternoon key plus cool fill mirrors the current warm/cool palette.
    sun_data = bpy.data.lights.get(scene.name + "_sun")
    if sun_data is not None:
        sun_data.energy = 2.25
        sun_data.color = (1.0, 0.73, 0.49)
        sun_data.angle = math.radians(4.0)
    world_bg = scene.world.node_tree.nodes.get("Background")
    if world_bg:
        world_bg.inputs[0].default_value = (0.12, 0.22, 0.36, 1.0)
        world_bg.inputs[1].default_value = 0.42

    area_data = bpy.data.lights.new("F1_plaza_sky_fill", "AREA")
    area_data.energy = 920
    area_data.shape = "DISK"
    area_data.size = 9.0
    area_data.color = (0.56, 0.72, 1.0)
    area = bpy.data.objects.new("F1_plaza_sky_fill", area_data)
    scene.collection.objects.link(area)
    area.location = (0.0, 5.5, 12.0)
    area.rotation_euler = (0.0, 0.0, 0.0)

    for index, location in enumerate([(-4.6, 4.0, 3.3), (4.6, 9.5, 3.3), (-4.6, 18.0, 3.3)]):
        data = bpy.data.lights.new(f"F1_warm_practical_{index}", "POINT")
        data.energy = 210
        data.color = (1.0, 0.52, 0.23)
        data.shadow_soft_size = 1.25
        obj = bpy.data.objects.new(data.name, data)
        scene.collection.objects.link(obj)
        obj.location = location

    hq.camera(scene, "F1_hero_camera", Vector((3.6, -12.5, 5.7)), Vector((0.0, 17.2, 4.9)), 60)


def export_glb(scene: bpy.types.Scene) -> tuple[str, int, int, int]:
    bpy.ops.object.select_all(action="DESELECT")
    visual_triangles = 0
    collision_triangles = 0
    mesh_count = 0
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        obj.select_set(True)
        mesh_count += 1
        obj.data.calc_loop_triangles()
        triangles = len(obj.data.loop_triangles)
        if obj.name.startswith("COL_"):
            collision_triangles += triangles
            obj.hide_render = True
        else:
            visual_triangles += triangles
    path = EXPORT / "StartingTown_Floor1_HeroKit.glb"
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
    return hashlib.sha256(path.read_bytes()).hexdigest(), visual_triangles, collision_triangles, mesh_count


def render_views(scene: bpy.types.Scene) -> list[str]:
    camera = scene.camera
    hero_location = camera.location.copy()
    hero_rotation = camera.rotation_euler.copy()
    outputs = [VALIDATION / "floor1_hero.png"]
    scene.render.filepath = str(outputs[0])
    bpy.ops.render.render(write_still=True)

    camera.location = Vector((-4.4, 9.2, 5.0))
    camera.rotation_euler = (Vector((0.0, 27.6, 6.3)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    outputs.append(VALIDATION / "floor1_gate_detail.png")
    scene.render.filepath = str(outputs[-1])
    bpy.ops.render.render(write_still=True)

    camera.location = hero_location
    camera.rotation_euler = hero_rotation
    scene.render.filepath = str(outputs[0])
    return [path.relative_to(PROJECT).as_posix() for path in outputs]


def main() -> None:
    global RNG
    args = parse_args()
    RNG = random.Random(args.seed)
    EXPORT.mkdir(parents=True, exist_ok=True)
    VALIDATION.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = hq.scene("StartingTown_Floor1_HeroKit")
    scene["asset_kit"] = STYLE
    scene["authoring_note"] = "Original project geometry; no traced frames, private state, or restricted character assets"
    collection = scene.collection

    records = [plaza(collection)]
    records.append(gatehouse(collection, Vector((0.0, 29.0, 0.0))))
    records.append(timber_shop(collection, "F1_wayfarer_inn", Vector((-6.55, 1.4, 0.0)), 90, "plaster_warm", "canvas_gold", 11))
    records.append(timber_shop(collection, "F1_supply_shop", Vector((6.55, 13.7, 0.0)), -90, "plaster_rose", "canvas_green", 29))
    records.append(forge(collection, Vector((6.55, 1.2, 0.0)), -90))
    props = street_props(collection)
    tweak_materials()
    add_rendering(scene, args.samples)

    sha256, visual_triangles, collision_triangles, mesh_count = export_glb(scene)
    blend_path = HERE / "StartingTown_Floor1_HeroKit.blend"
    renders = render_views(scene) if args.render else []
    bpy.ops.object.select_all(action="DESELECT")
    if scene.camera is not None:
        scene.camera.select_set(True)
        bpy.context.view_layer.objects.active = scene.camera
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)

    manifest = {
        "schema": 1,
        "id": "StartingTown_Floor1_HeroKit",
        "style_id": STYLE,
        "seed": args.seed,
        "blender_version": bpy.app.version_string,
        "source": "project-authored Codex-assisted Blender Python",
        "copyright_boundary": "original broad setting language; no traced frames or restricted source assets",
        "design_basis": [
            "ancient-European fortified starting-city language",
            "warm stone/timber commerce",
            "walkable gate and readable resident-scale props",
            "restrained blue system-light accents",
        ],
        "embedded_project_texture_sha256": {
            name: hashlib.sha256((REFERENCE_ROOT / "MarketCraftV5" / "textures" / name).read_bytes()).hexdigest()
            for name in ["stone_normal.png", "wood_normal.png", "plaster_normal.png"]
        },
        "glb": "StartingTown_Floor1_HeroKit.glb",
        "sha256": sha256,
        "visual_triangles": visual_triangles,
        "collision_triangles": collision_triangles,
        "mesh_objects": mesh_count,
        "renders": renders,
        "modules": records,
        "props": props,
        "visual_approval": False,
        "first_version_complete": False,
    }
    for path in [HERE / "floor1_hero_kit_manifest.json", EXPORT / "floor1_hero_kit_manifest.json", VALIDATION / "manifest.json"]:
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"stage": "complete", "manifest": manifest, "render": scene.render.filepath}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
