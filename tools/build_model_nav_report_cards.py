"""Build the report-video title card, flowchart and summary card.

English-only on-screen text (project documentation language policy). Outputs
1280x720 PNGs into tmp/model-nav-report/ for the ffmpeg assembly step.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp' / 'model-nav-report'
OUT.mkdir(parents=True, exist_ok=True)
W, H = 1280, 720
FONT_DIR = Path('C:/Windows/Fonts')
REGULAR = FONT_DIR / 'segoeui.ttf'
BOLD = FONT_DIR / 'segoeuib.ttf'
MONO = FONT_DIR / 'consola.ttf'

BG = (18, 24, 33)
PANEL = (30, 39, 52)
PANEL_ALT = (38, 50, 66)
ACCENT = (255, 213, 79)
GREEN = (122, 205, 160)
BLUE = (120, 178, 226)
ORANGE = (232, 143, 92)
TEXT = (232, 238, 245)
MUTED = (150, 165, 182)


def font(path, size):
    try:
        return ImageFont.truetype(str(path), size)
    except OSError:
        return ImageFont.truetype(str(REGULAR), size)


def new_canvas():
    image = Image.new('RGB', (W, H), BG)
    draw = ImageDraw.Draw(image)
    for y in range(H):
        shade = int(18 + 16 * (y / H))
        draw.line([(0, y), (W, y)], fill=(shade, shade + 6, shade + 13))
    return image, draw


def box(draw, xy, title, lines, colour, title_size=20, body_size=16, radius=12):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=PANEL, outline=colour, width=2)
    draw.rounded_rectangle((x0, y0, x0 + 6, y1), radius=3, fill=colour)
    draw.text((x0 + 20, y0 + 12), title, font=font(BOLD, title_size), fill=colour)
    offset = y0 + 14 + title_size + 8
    for line in lines:
        draw.text((x0 + 20, offset), line, font=font(REGULAR, body_size), fill=TEXT)
        offset += body_size + 7


def arrow(draw, start, end, colour=MUTED, width=3):
    draw.line([start, end], fill=colour, width=width)
    x, y = end
    if abs(end[0] - start[0]) >= abs(end[1] - start[1]):
        direction = 1 if end[0] > start[0] else -1
        draw.polygon([(x, y), (x - 12 * direction, y - 7), (x - 12 * direction, y + 7)], fill=colour)
    else:
        direction = 1 if end[1] > start[1] else -1
        draw.polygon([(x, y), (x - 7, y - 12 * direction), (x + 7, y - 12 * direction)], fill=colour)


def footer(draw, text):
    draw.text((48, H - 44), text, font=font(REGULAR, 15), fill=MUTED)


def build_title():
    image, draw = new_canvas()
    draw.text((48, 60), 'INFINITE AINCRAD', font=font(BOLD, 22), fill=ACCENT)
    draw.text((48, 96), 'Generated Models + Navigation Test', font=font(BOLD, 46), fill=TEXT)
    draw.text((48, 160), '10 SAO-style textured models · village square · NPC pathfinding', font=font(REGULAR, 22), fill=MUTED)
    draw.line([(48, 208), (W - 48, 208)], fill=(60, 74, 92), width=2)
    facts = [
        ('10', 'models generated'),
        ('2', 'provider APIs'),
        ('23', 'detail assets'),
        ('3', 'villagers active'),
    ]
    x = 48
    for value, label in facts:
        draw.text((x, 244), value, font=font(BOLD, 54), fill=ACCENT)
        draw.text((x, 312), label, font=font(REGULAR, 19), fill=MUTED)
        x += 300
    draw.rounded_rectangle((48, 396, W - 48, 620), radius=14, fill=PANEL)
    draw.text((72, 418), 'What this video shows', font=font(BOLD, 22), fill=GREEN)
    bullets = [
        '1. The pipeline behind the assets (next card)',
        '2. The village square: 10 generated models placed sensibly among existing art',
        '3. Villagers walking the baked navigation mesh, NpcA pathfinding to NpcB',
        '4. Verified numbers from the headless acceptance run',
    ]
    y = 458
    for line in bullets:
        draw.text((72, y), line, font=font(REGULAR, 19), fill=TEXT)
        y += 34
    footer(draw, '2026-09-22 · recorded with Godot 4.7.2 movie writer · no world save touched')
    image.save(OUT / 'title.png')


def build_flowchart():
    image, draw = new_canvas()
    draw.text((40, 30), 'Pipeline · what was done', font=font(BOLD, 32), fill=TEXT)
    draw.line([(40, 78), (W - 40, 78)], fill=(60, 74, 92), width=2)

    box(draw, (40, 96, 400, 176), '1 · REQUEST', [
        '10 SAO-style textured models,',
        'a test scene, NPC pathfinding',
    ], ACCENT, title_size=18, body_size=15)

    box(draw, (440, 96, 800, 176), '2 · GENERATE (once each)', [
        'Tripo API  → 1 market street house',
        'Meshy API  → 9 props (30 credits each)',
    ], BLUE, title_size=18, body_size=15)

    box(draw, (840, 96, 1240, 176), '3 · IMPORT INTO GODOT', [
        'stage GLBs → assets/floor1/',
        'trimesh collision · auto scale · ground snap',
    ], GREEN, title_size=18, body_size=15)

    arrow(draw, (400, 136), (440, 136))
    arrow(draw, (800, 136), (840, 136))

    box(draw, (40, 216, 400, 306), '4 · SCENE ASSEMBLY', [
        'stone plaza + market street',
        '2 buildings facing the square',
        'well, lamps, stalls, planters',
    ], ORANGE, title_size=18, body_size=15)

    box(draw, (440, 216, 800, 306), '5 · NAVIGATION BAKE', [
        'NavigationMesh over static colliders',
        'floor 2 reached via door/stair connectors',
    ], GREEN, title_size=18, body_size=15)

    box(draw, (840, 216, 1240, 306), '6 · NPC ACTIVITY', [
        'NpcA walks in and climbs to NpcB upstairs',
        '3 villagers on their own navmesh loops',
    ], BLUE, title_size=18, body_size=15)

    arrow(draw, (220, 176), (220, 216))
    arrow(draw, (620, 176), (620, 216))
    arrow(draw, (1040, 176), (1040, 216))

    box(draw, (40, 346, 400, 436), '7 · VALIDATION', [
        'headless acceptance run',
        'interior and floor 2 asserted',
    ], ACCENT, title_size=18, body_size=15)

    box(draw, (440, 346, 800, 436), '8 · EVIDENCE', [
        'acceptance.json + 3 renders',
        'cost and hash receipts',
    ], GREEN, title_size=18, body_size=15)

    box(draw, (840, 346, 1240, 436), '9 · THIS REPORT', [
        'screen recording + numbers',
        'no save or model call during capture',
    ], ORANGE, title_size=18, body_size=15)

    arrow(draw, (220, 306), (220, 346))
    arrow(draw, (620, 306), (620, 346))
    arrow(draw, (1040, 306), (1040, 346))

    draw.rounded_rectangle((40, 466, 1240, 560), radius=12, fill=PANEL_ALT)
    draw.text((64, 484), 'COST OF THE GENERATION RUN', font=font(BOLD, 18), fill=ACCENT)
    draw.text((64, 516), 'Tripo 30 credits (balance exactly covered it)  ·  Meshy 270 credits planned = 270 provider-reported, 0 unknown  ·  prorated ≈ ¥2.95',
              font=font(REGULAR, 16), fill=TEXT)
    footer(draw, 'Assets generated once with no appearance reroll · receipts kept locally, no keys in this video')
    image.save(OUT / 'flowchart.png')


def build_summary():
    acceptance = json.loads((ROOT / 'docs' / 'validation' / 'model-nav-20260922' / 'acceptance.json').read_text(encoding='utf-8'))
    data = acceptance['data']
    sim = data['simulation']
    path = data['path']
    image, draw = new_canvas()
    draw.text((48, 44), 'Verified result', font=font(BOLD, 40), fill=TEXT)
    draw.text((48, 100), 'Godot 4.7.2 · headless acceptance run · recorded 2026-09-22', font=font(REGULAR, 19), fill=MUTED)
    draw.line([(48, 140), (W - 48, 140)], fill=(60, 74, 92), width=2)

    cards = [
        (f"{acceptance['checks']} / {acceptance['checks']}", 'acceptance checks passed', GREEN),
        (f"{data['models_loaded']} / {data['models_expected']}", 'generated models loaded', BLUE),
        (f"{data['navigation']['polygons']}", 'navigation polygons baked', ACCENT),
        (f"{data['route_profile']['max_y']:.2f} m", 'route height reached (floor 2)', ORANGE),
        (f"{sim['arrival_distance_m']:.3f} m", 'arrival distance to NpcB upstairs', GREEN),
        (f"{path['total_length_m']:.1f} m", 'walked route length', BLUE),
    ]
    x, y = 48, 172
    for index, (value, label, colour) in enumerate(cards):
        column = index % 3
        row = index // 3
        cx = 48 + column * 400
        cy = 172 + row * 150
        draw.rounded_rectangle((cx, cy, cx + 370, cy + 126), radius=12, fill=PANEL, outline=colour, width=2)
        draw.text((cx + 22, cy + 22), value, font=font(BOLD, 42), fill=colour)
        draw.text((cx + 22, cy + 82), label, font=font(REGULAR, 17), fill=MUTED)

    draw.rounded_rectangle((48, 486, W - 48, 626), radius=12, fill=PANEL_ALT)
    draw.text((72, 504), 'DELIVERABLES', font=font(BOLD, 18), fill=ACCENT)
    lines = [
        'docs/validation/model-nav-20260922.md  ·  acceptance.json  ·  3 renders',
        'game/scenes/model_nav_village.tscn  ·  game/spatial/model_nav_village.gd',
        'game/tests/model_nav_village_acceptance.gd  ·  Run-ModelNavVillage.ps1',
    ]
    ly = 540
    for line in lines:
        draw.text((72, ly), line, font=font(MONO, 15), fill=TEXT)
        ly += 27
    footer(draw, 'Run the scene interactively with .\\Run-ModelNavVillage.ps1  ·  world save and residents untouched')
    image.save(OUT / 'summary.png')


if __name__ == '__main__':
    build_title()
    build_flowchart()
    build_summary()
    print(json.dumps({'outputs': [str(OUT / name) for name in ('title.png', 'flowchart.png', 'summary.png')]}, indent=2))
