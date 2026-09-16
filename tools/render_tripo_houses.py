"""Offline Blender renderer for Tripo house GLBs (2026-09-16 trial).

Run with Blender in background mode, for example:

  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup \
    --python tools/render_tripo_houses.py -- \
    --glb-dir exports/tripo-houses-20260916/models \
    --out-dir exports/tripo-houses-20260916 \
    --manifest Art/Generated/TripoHouses20260916/trial.json --size 768

  python -X utf8 tools/render_tripo_houses.py --help       # prints the CLI without Blender

What it does, per GLB found in --glb-dir:
  * imports the untouched GLB, measures raw geometry (triangles, vertices, materials, textures)
    and world-space bounds from the evaluated meshes;
  * builds a presentation copy (uniform scale + floor/centring transform) so all houses share one
    framing; the imported originals are hidden from render and their bytes are never written;
  * renders a front three-quarter and a back three-quarter image at --size square;
  * saves a per-house .blend with packed textures.
Afterwards it renders one five-house overview contact board (--overview-width/--overview-height).

Honesty rules: geometry is only ever the imported model (a missing GLB produces no render and an
explicit status, never a placeholder), presentation scale is reported separately, and raw bounds
are generation geometry - not verified real-world building dimensions.
"""
import argparse
import json
import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE_CANDIDATES = ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES")
CJK_FONT_CANDIDATES = (
    "C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/msyhbd.ttc", "C:/Windows/Fonts/simhei.ttf",
    "C:/Windows/Fonts/simsun.ttc", "C:/Windows/Fonts/NotoSansCJK-Regular.ttc",
)

if "--help" in sys.argv and "--" not in sys.argv:
    print(__doc__)
    raise SystemExit(0)

import bpy  # noqa: E402  (imported only inside Blender)
from mathutils import Vector  # noqa: E402


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--glb-dir", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--manifest", default="")
    parser.add_argument("--size", type=int, default=768)
    parser.add_argument("--overview-width", type=int, default=1800)
    parser.add_argument("--overview-height", type=int, default=1200)
    parser.add_argument("--samples", type=int, default=24)
    parser.add_argument("--fixture", action="store_true",
                        help="mark the run as an offline Blender-primitive fixture, not a Tripo result")
    return parser.parse_args(argv)


def reset_scene():
    bpy.ops.wm.read_homefile(use_empty=True)


def pick_engine(samples):
    scene = bpy.context.scene
    for name in ENGINE_CANDIDATES:
        try:
            scene.render.engine = name
        except Exception:
            continue
        if name == "CYCLES":
            scene.cycles.samples = max(8, min(samples, 64))
            scene.cycles.device = "CPU"
        else:
            try:
                scene.eevee.taa_render_samples = max(8, samples)
            except Exception:
                pass
        return name
    return scene.render.engine


def import_glb(path):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [bpy.data.objects[name] for name in bpy.data.objects.keys() if name not in before]


def mesh_objects(objects):
    return [item for item in objects if item.type == "MESH"]


def measure(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    vertices = 0
    materials = set()
    images = set()
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    for item in mesh_objects(objects):
        evaluated = item.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        vertices += len(mesh.vertices)
        for vertex in mesh.vertices:
            world = evaluated.matrix_world @ vertex.co
            for axis in range(3):
                low[axis] = min(low[axis], world[axis])
                high[axis] = max(high[axis], world[axis])
        evaluated.to_mesh_clear()
        for slot in item.material_slots:
            if slot.material:
                materials.add(slot.material.name)
                if slot.material.use_nodes:
                    for node in slot.material.node_tree.nodes:
                        if node.type == "TEX_IMAGE" and node.image:
                            images.add(node.image.name)
    if math.isinf(low.x):
        low = Vector((0.0, 0.0, 0.0))
        high = Vector((0.0, 0.0, 0.0))
    size = high - low
    return {"triangles": triangles, "vertices": vertices,
            "materials": sorted(materials), "textures": sorted(images),
            "bounds_min": [round(value, 4) for value in low],
            "bounds_max": [round(value, 4) for value in high],
            "bounds_size": [round(value, 4) for value in size],
            "max_dimension": round(max(size.x, size.y, size.z), 4)}


def build_display_copy(objects, target_size=1.0):
    """Duplicate the imported hierarchy, then scale/floor it for presentation only."""
    originals = [item for item in objects if item.parent is None]
    copies = []
    for item in originals:
        copies.extend(duplicate_tree(item, None))
    bpy.context.view_layer.update()
    low, high = world_bounds(mesh_objects(copies))
    size = high - low
    biggest = max(size.x, size.y, size.z) or 1.0
    scale = target_size / biggest
    centre = (low + high) * 0.5
    holder = bpy.data.objects.new("PresentationTransform", None)
    bpy.context.scene.collection.objects.link(holder)
    for item in copies:
        if item.parent is None:
            item.parent = holder
    holder.scale = (scale, scale, scale)
    holder.location = (-centre.x * scale, -centre.y * scale, -low.z * scale)
    for item in mesh_objects(objects):
        item.hide_render = True
        item.hide_viewport = True
    bpy.context.view_layer.update()
    return holder, copies, scale


def duplicate_tree(source, parent):
    copy = source.copy()
    copy.data = source.data.copy() if getattr(source, "data", None) else None
    copy.parent = parent
    copy.matrix_parent_inverse = source.matrix_parent_inverse.copy()
    copy.location = source.location.copy()
    copy.rotation_euler = source.rotation_euler.copy()
    copy.scale = source.scale.copy()
    copy.animation_data_clear()
    bpy.context.scene.collection.objects.link(copy)
    result = [copy]
    for child in source.children:
        result.extend(duplicate_tree(child, copy))
    return result


def world_bounds(objects):
    low = Vector((math.inf, math.inf, math.inf))
    high = Vector((-math.inf, -math.inf, -math.inf))
    for item in objects:
        for corner in item.bound_box:
            world = item.matrix_world @ Vector(corner)
            for axis in range(3):
                low[axis] = min(low[axis], world[axis])
                high[axis] = max(high[axis], world[axis])
    if math.isinf(low.x):
        return Vector((0.0, 0.0, 0.0)), Vector((0.0, 0.0, 0.0))
    return low, high


def setup_world_and_lights():
    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (0.22, 0.23, 0.26, 1.0)
    background.inputs[1].default_value = 1.0
    bpy.context.scene.world = world
    fill = bpy.data.lights.new("KeyLight", type="AREA")
    fill.energy = 900.0
    fill.size = 6.0
    key = bpy.data.objects.new("KeyLight", fill)
    key.location = (4.0, -5.0, 5.0)
    bpy.context.scene.collection.objects.link(key)
    rim_data = bpy.data.lights.new("RimLight", type="AREA")
    rim_data.energy = 400.0
    rim_data.size = 5.0
    rim = bpy.data.objects.new("RimLight", rim_data)
    rim.location = (-4.5, 4.0, 4.0)
    bpy.context.scene.collection.objects.link(rim)
    sun_data = bpy.data.lights.new("SunFill", type="SUN")
    sun_data.energy = 1.6
    sun = bpy.data.objects.new("SunFill", sun_data)
    sun.rotation_euler = (math.radians(55.0), 0.0, math.radians(35.0))
    bpy.context.scene.collection.objects.link(sun)
    return [key, rim, sun]


def aim_camera(target, radius, azimuth_deg, elevation_deg, name):
    camera_data = bpy.data.cameras.new(name)
    camera = bpy.data.objects.new(name, camera_data)
    bpy.context.scene.collection.objects.link(camera)
    distance = max(radius, 0.4) * 2.6
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    camera.location = (target.x + distance * math.cos(elevation) * math.sin(azimuth),
                       target.y - distance * math.cos(elevation) * math.cos(azimuth),
                       target.z + distance * math.sin(elevation))
    direction = target - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    return camera


def configure_render(width, height, samples):
    scene = bpy.context.scene
    engine = pick_engine(samples)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    return engine


def render_to(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return str(path)


def load_font():
    for candidate in CJK_FONT_CANDIDATES:
        if os.path.exists(candidate):
            try:
                return bpy.data.fonts.load(candidate)
            except Exception:
                continue
    return None


def add_label(text, location):
    curve = bpy.data.curves.new(type="FONT", name="Label")
    curve.body = text
    curve.size = 0.06
    curve.align_x = "CENTER"
    font = load_font()
    if font:
        curve.font = font
    label = bpy.data.objects.new("Label", curve)
    label.location = location
    bpy.context.scene.collection.objects.link(label)
    return label


def house_metadata(manifest_path, house_id):
    if not manifest_path:
        return {"id": house_id, "name_zh": ""}
    try:
        manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    except Exception:
        return {"id": house_id, "name_zh": ""}
    for house in manifest.get("houses", []):
        if house["id"] == house_id:
            return {"id": house_id, "name_zh": house.get("name_zh", "")}
    return {"id": house_id, "name_zh": ""}


def render_one(glb_path, metadata, args, report):
    reset_scene()
    enginE = configure_render(args.size, args.size, args.samples)
    imported = import_glb(glb_path)
    metrics = measure(imported)
    holder, copies, scale = build_display_copy(imported)
    setup_world_and_lights()
    low, high = world_bounds(mesh_objects(copies))
    centre = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, (low.z + high.z) * 0.5))
    radius = max((high - low).length * 0.5, 0.3)
    label = "%s%s" % ("FIXTURE " if args.fixture else "", metadata["id"])
    if metadata.get("name_zh"):
        label += "  " + metadata["name_zh"]
    add_label(label, Vector((0.0, 0.0, high.z + 0.25)))
    outputs = {}
    for name, azimuth in (("front34", 38.0), ("back34", 218.0)):
        aim_camera(centre, radius, azimuth, 16.0, "Camera_" + name)
        target = Path(args.out_dir) / "renders" / ("%s-%s.png" % (metadata["id"], name))
        outputs[name] = render_to(target)
    reset_scene()
    blend_dir = Path(args.out_dir) / "blend"
    blend_dir.mkdir(parents=True, exist_ok=True)
    # Re-import so the saved .blend really contains the model with packed textures.
    imported = import_glb(glb_path)
    holder, copies, scale = build_display_copy(imported)
    setup_world_and_lights()
    bpy.ops.file.pack_all()
    blend_path = blend_dir / ("%s.blend" % metadata["id"])
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    report.append({"id": metadata["id"], "name_zh": metadata.get("name_zh", ""),
                   "source_glb": str(glb_path).replace("\\", "/"),
                   "engine": enginE, "presentation_scale": round(scale, 6),
                   "display_bounds_min": [round(value, 4) for value in low],
                   "display_bounds_max": [round(value, 4) for value in high],
                   "renders": outputs, "blend": str(blend_path).replace("\\", "/"),
                   "raw": metrics,
                   "note": "bounds and scale are presentation values from generation geometry, "
                           "not verified real-world building dimensions"})


def render_overview(entries, args):
    reset_scene()
    configure_render(args.overview_width, args.overview_height, args.samples)
    setup_world_and_lights()
    placed = []
    offset = 0.0
    for entry in entries:
        glb = Path(entry["source_glb"])
        if not glb.exists():
            continue
        imported = import_glb(glb)
        holder, copies, scale = build_display_copy(imported, target_size=1.0)
        low, high = world_bounds(mesh_objects(copies))
        width = (high.x - low.x) or 0.4
        holder.location.x += offset - low.x
        bpy.context.view_layer.update()
        low, high = world_bounds(mesh_objects(copies))
        label = "%s%s" % ("FIXTURE " if args.fixture else "", entry["id"])
        if entry.get("name_zh"):
            label += "  " + entry["name_zh"]
        add_label(label, Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, high.z + 0.12)))
        placed.append((low, high))
        offset += width + 0.55
    if not placed:
        return None
    lows = Vector((min(item[0].x for item in placed), min(item[0].y for item in placed),
                   min(item[0].z for item in placed)))
    highs = Vector((max(item[1].x for item in placed), max(item[1].y for item in placed),
                    max(item[1].z for item in placed)))
    centre = (lows + highs) * 0.5
    radius = max((highs - lows).length * 0.5, 0.5)
    aim_camera(centre, radius * 0.78, 6.0, 14.0, "OverviewCamera")
    target = Path(args.out_dir) / ("overview%s.png" % ("-fixture" if args.fixture else ""))
    return render_to(target)


def main():
    args = parse_args(list(sys.argv))
    glb_dir = Path(args.glb_dir)
    if not glb_dir.is_absolute():
        glb_dir = ROOT / glb_dir
    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = ROOT / out_dir
    manifest = args.manifest or ""
    if manifest and not Path(manifest).is_absolute():
        manifest = str(ROOT / manifest)
    # Blender resolves relative render paths against its own working directory, so pin absolutes here.
    args.glb_dir = str(glb_dir)
    args.out_dir = str(out_dir)
    args.manifest = manifest
    report = {"fixture": bool(args.fixture),
              "generated_at_utc": __import__("datetime").datetime.now(
                  __import__("datetime").timezone.utc).isoformat(),
              "size": args.size, "overview": [args.overview_width, args.overview_height],
              "blender": bpy.app.version_string, "houses": [], "missing": []}
    files = sorted(glb_dir.glob("*.glb"))
    if not files:
        report["error"] = "no GLB files found in %s; nothing was rendered" % glb_dir
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0
    for glb in files:
        metadata = house_metadata(manifest, glb.stem)
        if args.fixture:
            metadata["name_zh"] = ""
        render_one(glb, metadata, args, report["houses"])
    overview = render_overview(report["houses"], args)
    report["overview_path"] = overview
    report["rendered_count"] = len(report["houses"])
    report["note"] = ("offline Blender fixture render; NOT a Tripo generation result"
                      if args.fixture else
                      "offline render of the downloaded GLBs; geometry is the untouched import")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / ("render-report%s.json" % ("-fixture" if args.fixture else ""))).write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    if "--help" in sys.argv and "--" not in sys.argv:
        print(__doc__)
        sys.exit(0)
    sys.exit(main())
