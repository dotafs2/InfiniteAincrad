"""Render the JSON exported by generate_citysample_layout_gallery.py."""

from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "tmp" / "citysample-layout-gallery"
WIDTH, HEIGHT = 1500, 980
MAP_BOX = (48, 80, 1010, 918)


def font(size, bold=False):
    candidates = [
        r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_text(draw, xy, text, fill, size=20, bold=False):
    draw.text(xy, text, fill=fill, font=font(size, bold))


def transform_factory(data):
    all_points = []
    all_points.extend(data["boundary"])
    for polygon in data["lots"]:
        all_points.extend(polygon)
    for road in data["roads"]:
        all_points.extend(road["points"])
    all_points.extend(data.get("freeway_curve_attributes", []))
    min_x = min(point[0] for point in all_points)
    max_x = max(point[0] for point in all_points)
    min_z = min(point[1] for point in all_points)
    max_z = max(point[1] for point in all_points)
    pad = 34.0
    x0, y0, x1, y1 = MAP_BOX
    scale = min((x1 - x0 - 2 * pad) / max(1.0, max_x - min_x), (y1 - y0 - 2 * pad) / max(1.0, max_z - min_z))
    used_w = (max_x - min_x) * scale
    used_h = (max_z - min_z) * scale
    origin_x = x0 + ((x1 - x0) - used_w) * 0.5
    origin_y = y0 + ((y1 - y0) - used_h) * 0.5

    def convert(point):
        return (origin_x + (point[0] - min_x) * scale, y1 - ((point[1] - min_z) * scale + (origin_y - y0)))

    return convert, scale


def gradient_background():
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()
    for y in range(HEIGHT):
        t = y / max(1, HEIGHT - 1)
        color = (9 + int(7 * t), 15 + int(8 * t), 29 + int(17 * t))
        for x in range(WIDTH):
            pixels[x, y] = color
    return image


def draw_map(data):
    image = gradient_background()
    draw = ImageDraw.Draw(image)
    seed = int(data["seed"])
    convert, scale = transform_factory(data)
    x0, y0, x1, y1 = MAP_BOX
    draw.rounded_rectangle(MAP_BOX, radius=26, fill=(13, 23, 40), outline=(43, 65, 89), width=2)

    # The original City Layout output exposes road segments and block preview
    # polygons. Roads are rendered first so the block geometry reads cleanly.
    for road in data["roads"]:
        points = [convert(point) for point in road["points"]]
        try:
            width_value = float(road.get("width", 12.0))
        except (TypeError, ValueError):
            width_value = 12.0
        road_width = max(2, min(12, int(width_value * scale * 0.22)))
        road_class = int(road.get("class", 0) or 0)
        color = (49, 70, 89) if road_class % 3 else (65, 89, 110)
        draw.line(points, fill=color, width=road_width, joint="curve")
        draw.line(points, fill=(96, 122, 141), width=max(1, road_width // 3), joint="curve")

    palette = [(190, 82, 50), (167, 72, 58), (206, 108, 46), (118, 73, 91), (148, 91, 59)]
    rng = random.Random(seed * 997)
    for index, polygon in enumerate(data["lots"]):
        points = [convert(point) for point in polygon]
        if len(points) < 3:
            continue
        base = palette[(index + rng.randrange(len(palette))) % len(palette)]
        fill = tuple(min(255, int(channel * 0.82)) for channel in base)
        draw.polygon(points, fill=fill)
        draw.line(points + [points[0]], fill=(226, 153, 91), width=1, joint="curve")

    boundary = [convert(point) for point in data["boundary"]]
    draw.line(boundary + [boundary[0]], fill=(244, 196, 109), width=4, joint="curve")

    freeway = data.get("freeway_curve_attributes", [])
    if freeway:
        rng = random.Random(seed * 47)
        angle = rng.uniform(-0.38, 0.38)
        scale_factor = rng.uniform(0.82, 1.12)
        cx = sum(point[0] for point in data["boundary"]) / len(data["boundary"])
        cz = sum(point[1] for point in data["boundary"]) / len(data["boundary"])
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        transformed = []
        for x, z in freeway:
            dx, dz = x - cx, z - cz
            transformed.append((cx + (dx * cos_a - dz * sin_a) * scale_factor, cz + (dx * sin_a + dz * cos_a) * scale_factor))
        freeway_points = [convert(point) for point in transformed]
        draw.line(freeway_points, fill=(43, 176, 201), width=8, joint="curve")
        draw.line(freeway_points, fill=(137, 237, 233), width=2, joint="curve")

    draw_text(draw, (72, 104), "CITY SAMPLE / SMALL_CITY", (221, 234, 244), 26, True)
    draw_text(draw, (72, 140), "City Layout HDA  →  Road Network  →  Blocks", (120, 185, 202), 17)
    draw_text(draw, (72, 168), f"seed {seed:03d}  ·  official Houdini graph preview", (139, 152, 169), 15)

    # Side panel keeps the provenance visible in every overview image.
    panel = (1050, 80, 1452, 918)
    draw.rounded_rectangle(panel, radius=26, fill=(14, 24, 39), outline=(43, 65, 89), width=2)
    draw_text(draw, (1084, 116), f"MAP {seed:03d}", (244, 196, 109), 31, True)
    draw_text(draw, (1084, 164), "Official City Sample source", (184, 207, 219), 19, True)
    draw_text(draw, (1084, 196), "Small_City / City_Layout.hda", (114, 176, 194), 16)
    draw_text(draw, (1084, 246), "GENERATED STAGES", (110, 132, 151), 14, True)
    stages = [
        ("01", "Manual boundary curve", (244, 196, 109)),
        ("02", "City Layout HDA", (225, 153, 91)),
        ("03", "Road network / blocks", (96, 170, 191)),
        ("04", "Freeway Curve Attributes", (137, 237, 233)),
    ]
    y = 282
    for index, label, color in stages:
        draw.ellipse((1086, y + 3, 1102, y + 19), fill=color)
        draw_text(draw, (1118, y), f"{index}  {label}", (214, 225, 232), 17)
        y += 42
    draw_text(draw, (1084, 476), "LAYOUT PARAMETERS", (110, 132, 151), 14, True)
    y = 512
    for key in ("density", "road_crea_threshold", "max_block_lenght_x", "max_block_lenght_z", "merging_blocks"):
        value = data["parameters"].get(key)
        draw_text(draw, (1084, y), key.replace("_", " "), (139, 152, 169), 15)
        draw_text(draw, (1370, y), str(value), (226, 235, 240), 15, True)
        y += 31
    draw_text(draw, (1084, 704), "OUTPUT", (110, 132, 151), 14, True)
    draw_text(draw, (1084, 740), f"{data['stats']['blocks']} block polygons", (225, 153, 91), 18, True)
    draw_text(draw, (1084, 774), f"{data['stats']['road_segments']} road segments", (137, 237, 233), 18, True)
    draw_text(draw, (1084, 842), "Reference caches are kept untouched.", (129, 147, 162), 14)
    draw_text(draw, (1084, 868), "Overview only · no City Processor recache", (129, 147, 162), 14)
    return image


def main():
    for path in sorted(OUT.glob("citysample_map_*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        image = draw_map(data)
        output = path.with_suffix(".png")
        image.save(output, optimize=True)
        print(output)


if __name__ == "__main__":
    main()
