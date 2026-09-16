"""CPU-only coordinate-faithful Floor1 handoff map from accepted world JSON."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
SOURCE = ROOT / "tmp/floor1-art-20260916/world/tour-v3-approved-grove/default-physics.json"
SVG = HERE / "floor1-handoff-map.svg"
PNG = HERE / "floor1-handoff-map-preview.png"
MANIFEST = HERE / "manifest.json"
W, H = 1200, 1160
OX, OY, SCALE = 95.0, 140.0, 1.62
BG, GROUND, NW, TOWN = "#f3efe6", "#d9e4ce", "#c9d9bc", "#eee8db"
ROAD, BRANCH = "#a9a79c", "#bbad91"
INK, BLUE, EXTERIOR, GOLD = "#28363a", "#356f85", "#ae765b", "#d8a64f"


def point(x: float, z: float) -> tuple[float, float]:
    return OX + (x + 210.0) * SCALE, OY + (z + 335.0) * SCALE


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    layout = data["layout"]
    rows = layout["building_layout"]
    interactive = [r for r in rows if r["role"] == "interactive"]
    visual = [r for r in rows if r["role"] == "exterior_lod"]
    rooms = [r for r in interactive if r["district"] == "LaneInner" and r["x"] < 0]
    assert data["failure_count"] == 0 and len(rows) == 44
    assert len(interactive) == 12 and len(visual) == 32 and len(rooms) == 3
    assert layout["ground_union_area_m2"] == 222700 and not layout["ground_union_is_rectangular"]
    assert layout["north_sector_bounds_m"] == {"x": [-210, 85], "z": [-335, -235]}
    assert layout["north_grove_additional_native_t2_oaks"] == 9
    assert layout["approved_courtyard_oak_instances"] == 1

    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
           f'<rect width="{W}" height="{H}" fill="{BG}"/>',
           '<style>text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif;fill:#28363a}</style>']
    im = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(im)
    font_path = "C:/Windows/Fonts/msyh.ttc"
    ftitle = ImageFont.truetype(font_path, 31)
    fsub = ImageFont.truetype(font_path, 16)
    flabel = ImageFont.truetype(font_path, 15)
    fsmall = ImageFont.truetype(font_path, 13)

    def text(x: float, y: float, value: str, size: int = 15, color: str = INK) -> None:
        svg.append(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{color}">{escape(value)}</text>')
        font = ftitle if size >= 27 else (fsub if size >= 16 else (flabel if size >= 15 else fsmall))
        draw.text((x, y - size), value, fill=color, font=font)

    def polygon(coords: list[tuple[float, float]], fill: str, outline: str = INK, width: int = 1) -> None:
        svg.append('<polygon points="' + ' '.join(f'{x:.1f},{y:.1f}' for x, y in coords)
                   + f'" fill="{fill}" stroke="{outline}" stroke-width="{width}"/>')
        draw.polygon(coords, fill=fill)
        draw.line(coords + [coords[0]], fill=outline, width=width)

    def rect(x0: float, y0: float, x1: float, y1: float, fill: str,
             outline: str = "none", width: int = 1) -> None:
        svg.append(f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{x1-x0:.1f}" height="{y1-y0:.1f}" fill="{fill}" stroke="{outline}" stroke-width="{width}"/>')
        draw.rectangle((x0, y0, x1, y1), fill=fill, outline=None if outline == "none" else outline, width=width)

    def circle(x: float, y: float, r: float, fill: str, outline: str = INK, width: int = 1) -> None:
        svg.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}" stroke="{outline}" stroke-width="{width}"/>')
        draw.ellipse((x-r, y-r, x+r, y+r), fill=None if fill == "none" else fill, outline=outline, width=width)

    def line(coords: list[tuple[float, float]], color: str, width: float) -> None:
        svg.append('<polyline points="' + ' '.join(f'{x:.1f},{y:.1f}' for x, y in coords)
                   + f'" fill="none" stroke="{color}" stroke-width="{width:.1f}" stroke-linecap="round" stroke-linejoin="round"/>')
        draw.line(coords, fill=color, width=max(1, round(width)), joint="curve")

    text(95, 56, "第一层 · 原创美术样板导览", 30)
    text(95, 89, "按已验收世界坐标绘制  ·  北在上  ·  单位：米", 16)

    # Actual union: original x[-210,210] z[-235,225] plus only a NW
    # x[-210,85] z[-335,-235] extension. Never imply a 420x560 rectangle.
    union = [point(-210, -335), point(85, -335), point(85, -235),
             point(210, -235), point(210, 225), point(-210, 225)]
    polygon(union, GROUND, "#84977f", 2)
    nw_rect = [point(-210, -335), point(85, -335), point(85, -235), point(-210, -235)]
    polygon(nw_rect, NW, "#a6bc9d", 1)
    x0, y0 = point(-90, -89)
    x1, y1 = point(90, 81)
    rect(x0, y0, x1, y1, TOWN, "#b8b3a4", 1)

    # Exact road centreline/width/endpoints from floor1_expanded_world.gd
    # _ground_and_roads(), lines 557-588. Branch polylines use source nodes.
    line([point(0, -85), point(0, 75)], ROAD, 8*SCALE)
    for x in (-35, 35):
        line([point(x, -70), point(x, 60)], ROAD, 5*SCALE)
    line([point(0, -269), point(0, -85)], BRANCH, 5*SCALE)
    for z in (-70, 70):
        line([point(-35, z), point(35, z)], ROAD, 5*SCALE)
    line([point(2, -123), point(13, -129), point(21, -137), point(27, -141)], BRANCH, 2*SCALE)
    line([point(-2, -180), point(-12, -189), point(-21, -198), point(-28, -208),
          point(-34, -211), point(-40, -214)], BRANCH, 2*SCALE)

    px, py = point(0, 0)
    circle(px, py, 12*SCALE, "#d5bea4", "#9f8a73", 2)
    # Actual fountain basin is offset 7.5m west of the plaza centre.
    fx, fy = point(-7.5, 0)
    circle(fx, fy, 7, "#b8dfe0", "#3f7d8d", 2)
    circle(fx, fy, 2.5, "#5b99a9", "#2e697d", 1)
    text(611, py-14, "广场 / 喷泉", 15)
    gx, gy = point(0, -85)
    rect(gx-16, gy-6, gx+16, gy+6, "#5d6d69", "#354844", 1)
    text(gx+24, gy-13, "北门", 16)

    # Site markers use actual accepted building_layout, not invented
    # rectangles or architectural footprints. Exterior footprint radii vary.
    for r in visual:
        x, y = point(float(r["x"]), float(r["z"]))
        rect(x-4.2, y-4.2, x+4.2, y+4.2, EXTERIOR, "#835842", 1)
    for r in interactive:
        x, y = point(float(r["x"]), float(r["z"]))
        circle(x, y, 6.2, BLUE, "#e5f2ef", 1)
    room_labels = {"01_hearth_cottage": "住宅 · 已布置", "02_market_house": "面包铺 · 已布置",
                   "03_corner_turret": "工坊 · 已布置"}
    for r in sorted(rooms, key=lambda row: -row["z"]):
        x, y = point(float(r["x"]), float(r["z"]))
        circle(x, y, 11.5, "none", GOLD, 3)
        text(104, y+5, room_labels[r["variant"]], 15)

    ox, oy = point(-24.8, 16.8)
    circle(ox, oy, 8, "#3f7554", "#245339", 1)
    text(611, oy-12, "庭院焦点橡树", 15)

    grove = layout["north_grove_bounds_m"]
    a = point(grove["x"][0], grove["z"][0])
    b = point(grove["x"][1], grove["z"][1])
    rect(a[0], a[1], b[0], b[1], "#a7c5a4", "#52805c", 2)
    sites = [(-55, -275), (-60, -281), (-67, -284), (-76, -282), (-86, -288),
             (-61, -292), (-70, -298), (-84, -305), (-58, -305), (-74, -310)]
    for x, z in sites:
        xx, yy = point(x, z)
        circle(xx, yy, 3.1, "#315f42", "#315f42", 1)
    text(point(-110, -323)[0], point(-110, -323)[1], "新林团 · 10株", 15)

    # Sidebar contains the actual counts and the semantic distinction.
    rect(805, 142, 1160, 1010, "#fffaf2", "#c3beb1", 1)
    text(830, 187, "图例与验收范围", 20)
    circle(843, 224, 6.2, BLUE, "#e5f2ef")
    text(865, 230, "12栋可开门模块房", 16)
    rect(839, 255, 848, 264, EXTERIOR, "#835842")
    text(865, 265, "32栋Meshy外观房", 16)
    circle(843, 301, 11, "none", GOLD, 3)
    text(865, 306, "3间已布置一层室内", 16)
    circle(843, 344, 7, "#3f7554", "#245339")
    text(865, 350, "庭院焦点橡树", 16)
    rect(833, 387, 853, 407, "#a7c5a4", "#52805c")
    text(865, 403, "西北新林团 · 10株", 16)
    line([(836, 451), (862, 451)], ROAD, 8)
    text(876, 456, "镇街 / 住宅巷", 15)
    line([(836, 493), (862, 493)], BRANCH, 5)
    text(876, 498, "乡间步道", 15)
    text(830, 557, "场景位置以验收JSON为准", 15)
    text(830, 590, "西北延伸只在左上角", 15)
    text(830, 623, "不是完整矩形新地面", 15)
    text(830, 681, "建筑符号表示位置", 15)
    text(830, 714, "不代表精确墙体轮廓", 15)
    text(830, 765, "原著路线未做精确还原", 15)
    text(830, 798, "迷宫现为视觉剪影", 15)
    text(830, 831, "并非可玩迷宫", 15)
    text(830, 921, "比例尺", 16)
    line([(835, 953), (835+50*SCALE, 953)], INK, 3)
    text(835, 981, "0", 13)
    text(835+50*SCALE-34, 981, "50m", 13)
    text(100, 1091, "原创美术样板  ·  不是原著精确地图  ·  北门z=-85m / 新林团z≈-273…-313m", 15)
    svg.append("</svg>")
    SVG.write_text("\n".join(svg) + "\n", encoding="utf-8")
    im.save(PNG)
    report = {
        "schema": "floor1-coordinate-faithful-handoff-map-v1",
        "source_world_acceptance": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": sha(SOURCE), "source_check_count": data["check_count"],
        "source_failures": data["failure_count"], "building_layout_rows": len(rows),
        "interactive": len(interactive), "exterior_lod": len(visual), "furnished": len(rooms),
        "source_world_scene": "game/spatial/floor1_expanded_world.gd; exact road geometry lines557-588, western inner-lane insert condition lines844-850, L-ground lines1240-1275, focal oak site line772, native grove site lines1320-1330 and1369-1390",
        "ground_union_polygon_world_xz_m": [[-210,-335],[85,-335],[85,-235],[210,-235],[210,225],[-210,225]],
        "ground_union_area_m2": 222700, "ground_union_rectangular": False,
        "plaza_center_world_xz_m": [0, 0], "fountain_center_world_xz_m": [-7.5, 0],
        "north_grove_world_bounds": grove,
        "preview_note": "PNG is drawn from the same coordinates and style data as SVG with Pillow; it is a raster preview, not a new scene render.",
        "svg": SVG.name, "svg_sha256": sha(SVG), "png": PNG.name, "png_sha256": sha(PNG),
        "model_calls": 0, "godot_runs": 0, "gpu_runs": 0,
    }
    MANIFEST.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"source_checks": data["check_count"], "houses": len(rows),
                      "svg": str(SVG), "png": str(PNG)}))


if __name__ == "__main__":
    main()
