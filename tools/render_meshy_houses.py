"""Offline presentation renderer for the generated Meshy house GLBs (2026-09-16).

Two phases, both offline (no provider, no network):

  # 1) render each source GLB on its own (Blender):
  "D:/SteamLibrary/steamapps/common/Blender/blender.exe" --background --factory-startup \
    --python tools/render_meshy_houses.py -- \
    --phase render \
    --trial tmp/meshy-houses-20260916/trial.json \
    --models exports/meshy-houses-20260916/models \
    --out exports/meshy-houses-20260916 \
    --size 1024

  # 2) assemble the contact sheet from those rendered PNGs (plain CPython + Pillow):
  python -X utf8 tools/render_meshy_houses.py --phase compose \
    --trial tmp/meshy-houses-20260916/trial.json \
    --out exports/meshy-houses-20260916 --sheet-width 2160

Useful options: ``--house ID`` (repeatable) renders only the named houses, ``--fixture`` isolates an
explicitly named offline primitive fixture, ``--yaw-json PATH`` applies a per-house presentation
yaw when a generation axis differs, ``--elevation``/``--azimuths`` change the camera set.

Honesty rules: the imported geometry is never repaired, decimated or replaced; a missing GLB is
reported as missing instead of being faked; raw triangle/vertex/material/texture counts and bounds
are measured on the untouched import before any transform; the uniform scale and the yaw used for
framing are reported as *presentation* values, not real building dimensions; every image is a
Blender render of the actual model, clearly labelled as an offline preview and never as game
footage. Source GLB bytes are hashed before and after and must stay identical.
"""
import argparse
import hashlib
import json
import math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TRIAL = ROOT / "tmp" / "meshy-houses-20260916" / "trial.json"
DEFAULT_MODELS = ROOT / "exports" / "meshy-houses-20260916" / "models"
DEFAULT_OUT = ROOT / "exports" / "meshy-houses-20260916"
ENGINE_CANDIDATES = ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES")
CJK_FONTS = ("C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/msyhbd.ttc", "C:/Windows/Fonts/simhei.ttf",
             "C:/Windows/Fonts/simsun.ttc")
VIEW_AZIMUTHS = (("az038", 38.0), ("az128", 128.0), ("az218", 218.0), ("az308", 308.0))
VIEW_ROLES = {"az038": "front", "az128": "right", "az218": "back", "az308": "left"}


def parse_args(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--phase", choices=["render", "compose"], default="render")
    parser.add_argument("--trial", default=str(DEFAULT_TRIAL))
    parser.add_argument("--models", default=str(DEFAULT_MODELS))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--house", action="append", default=None)
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--azimuths", default=",".join(str(int(a)) for _name, a in VIEW_AZIMUTHS))
    parser.add_argument("--elevation", type=float, default=22.0)
    parser.add_argument("--yaw-json", default="")
    parser.add_argument("--fixture", action="store_true")
    parser.add_argument("--fixture-label", default="fixture-house")
    parser.add_argument("--fixture-glb", default="",
                        help="render exactly this single GLB as an explicitly labelled offline fixture")
    parser.add_argument("--sheet-width", type=int, default=2160)
    parser.add_argument("--report", default="")
    return parser.parse_args(argv)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def now_utc():
    return datetime.now(timezone.utc).isoformat()


def load_trial(path: Path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def resolve(path_value, base=None):
    candidate = Path(path_value)
    if not candidate.is_absolute():
        candidate = (base or ROOT) / candidate
    return candidate


def report_path(args) -> Path:
    if args.report:
        return resolve(args.report)
    name = "render-report-fixture.json" if args.fixture else "render-report.json"
    return resolve(args.out) / name


def load_yaw_overrides(args):
    if not args.yaw_json:
        return {}
    path = resolve(args.yaw_json)
    if not path.exists():
        print(json.dumps({"warning": "yaw json not found", "path": str(path)}))
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def find_model(models_dir: Path, house_id: str):
    direct = models_dir / (house_id + ".glb")
    if direct.exists():
        return direct
    if models_dir.exists():
        for candidate in sorted(models_dir.glob("*.glb")):
            if candidate.stem == house_id or candidate.stem.startswith(house_id) or house_id in candidate.stem:
                return candidate
    return None


def glb_readiness(path: Path):
    """Cheap pre-import check so a still-downloading or broken file is reported, not crashed on."""
    try:
        size = path.stat().st_size
        with Path(path).open("rb") as handle:
            header = handle.read(12)
    except OSError as error:
        return False, "unreadable (%s)" % type(error).__name__, 0
    if len(header) < 12 or header[0:4] != b"glTF":
        return False, "not a GLB (missing magic)", size
    version = int.from_bytes(header[4:8], "little")
    declared = int.from_bytes(header[8:12], "little")
    if version != 2:
        return False, "glTF version %d is not 2" % version, size
    if declared != size:
        return False, "declared length %d differs from file size %d (incomplete download?)" % (declared, size), size
    return True, "", size


def select_houses(args, trial):
    wanted = args.house or [house["id"] for house in trial.get("houses", [])]
    known = {house["id"]: house for house in trial.get("houses", [])}
    selected = []
    unknown = []
    for house_id in wanted:
        if house_id in known:
            selected.append(known[house_id])
        else:
            unknown.append(house_id)
    return selected, unknown


# ---------------------------------------------------------------- render phase (Blender) ----


def _blender():
    import bpy
    return bpy


def reset_scene():
    bpy = _blender()
    bpy.ops.wm.read_homefile(use_empty=True)


def pick_engine(samples=32):
    bpy = _blender()
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
                scene.eevee.taa_render_samples = max(16, samples)
            except Exception:
                pass
        return name
    return scene.render.engine


def import_glb(path: Path):
    bpy = _blender()
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [bpy.data.objects[name] for name in bpy.data.objects.keys() if name not in before]


def mesh_objects(objects):
    return [item for item in objects if item.type == "MESH"]


def measure(objects):
    """Raw metrics of the untouched import: triangles, vertices, materials, textures, bounds."""
    bpy = _blender()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = vertices = 0
    materials = set()
    images = set()
    low = [math.inf] * 3
    high = [-math.inf] * 3
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
                if slot.material.use_nodes and slot.material.node_tree:
                    for node in slot.material.node_tree.nodes:
                        if node.type == "TEX_IMAGE" and node.image:
                            images.add(node.image.name)
    if math.isinf(low[0]):
        low = [0.0, 0.0, 0.0]
        high = [0.0, 0.0, 0.0]
    size = [high[axis] - low[axis] for axis in range(3)]
    return {"triangles": triangles, "vertices": vertices,
            "materials": sorted(materials), "material_count": len(materials),
            "textures": sorted(images), "texture_count": len(images),
            "raw_bounds_min": [round(value, 4) for value in low],
            "raw_bounds_max": [round(value, 4) for value in high],
            "raw_size": [round(value, 4) for value in size],
            "raw_max_dimension": round(max(size), 4)}


def duplicate_tree(source, parent):
    bpy = _blender()
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
    from mathutils import Vector
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


def build_presentation_copy(objects, yaw_deg, target_size=1.0):
    """Uniform scale + floor/centring + optional presentation yaw. Presentation values only."""
    bpy = _blender()
    roots = [item for item in objects if item.parent is None]
    copies = []
    for item in roots:
        copies.extend(duplicate_tree(item, None))
    bpy.context.view_layer.update()
    low, high = world_bounds(mesh_objects(copies))
    biggest = max((high - low).x, (high - low).y, (high - low).z) or 1.0
    scale = target_size / biggest
    holder = bpy.data.objects.new("PresentationTransform", None)
    bpy.context.scene.collection.objects.link(holder)
    for item in copies:
        if item.parent is None:
            item.parent = holder
    holder.scale = (scale, scale, scale)
    holder.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))
    centre = (low + high) * 0.5
    # The centring offset must be rotated with the subject, otherwise a yawed model drifts off centre.
    yaw = math.radians(yaw_deg)
    rotated = (centre.x * scale * math.cos(yaw) - centre.y * scale * math.sin(yaw),
               centre.x * scale * math.sin(yaw) + centre.y * scale * math.cos(yaw))
    holder.location = (-rotated[0], -rotated[1], -low.z * scale)
    for item in mesh_objects(objects):
        item.hide_render = True
        item.hide_viewport = True
    bpy.context.view_layer.update()
    return holder, copies, scale


def add_floor(size=200.0):
    bpy = _blender()
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0.0, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "PresentationFloor"
    material = bpy.data.materials.new("PresentationFloorMaterial")
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (0.63, 0.60, 0.56, 1.0)
    shader.inputs["Roughness"].default_value = 0.85
    floor.data.materials.append(material)
    return floor


def setup_world_and_lights(target):
    bpy = _blender()
    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (0.52, 0.53, 0.56, 1.0)
    background.inputs[1].default_value = 0.6
    bpy.context.scene.world = world
    lights = []
    for name, energy, size, location in (("KeyArea", 320.0, 4.0, (3.2, -3.4, 3.6)),
                                         ("FillArea", 130.0, 5.0, (-3.8, -2.2, 2.4)),
                                         ("RimArea", 220.0, 4.0, (-2.4, 3.8, 3.2))):
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = energy
        data.size = size
        data.color = (1.0, 0.99, 0.96)
        light = bpy.data.objects.new(name, data)
        light.location = location
        bpy.context.scene.collection.objects.link(light)
        constraint = light.constraints.new("TRACK_TO")
        constraint.target = target
        # Area lights emit along their local -Z; aim that axis at the subject instead of trusting defaults.
        constraint.track_axis = "TRACK_NEGATIVE_Z"
        constraint.up_axis = "UP_Y"
        lights.append(light)
    return lights


def bbox_corners(low, high):
    from mathutils import Vector
    return [Vector((x, y, z)) for x in (low.x, high.x) for y in (low.y, high.y) for z in (low.z, high.z)]


def camera_axes(azimuth_deg, elevation_deg):
    """Camera right/up vectors for the aim used by frame_camera (orthographic)."""
    from mathutils import Vector
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    location = Vector((math.cos(elevation) * math.sin(azimuth),
                       -math.cos(elevation) * math.cos(azimuth),
                       math.sin(elevation)))
    forward = (-location).normalized()
    rotation = forward.to_track_quat("-Z", "Y")
    right = rotation @ Vector((1.0, 0.0, 0.0))
    up = rotation @ Vector((0.0, 1.0, 0.0))
    return right, up


def framing_scale(corners, centre, azimuths, elevation_deg=22.0, margin=0.08):
    """Smallest orthographic width that covers the projected bbox at every angle, with margin."""
    from mathutils import Vector
    required = 0.0
    for azimuth in azimuths:
        right, up = camera_axes(azimuth, elevation_deg)
        widest = 0.0
        for corner in corners:
            offset = Vector(corner) - Vector(centre)
            widest = max(widest, abs(offset.dot(right)), abs(offset.dot(up)))
        required = max(required, 2.0 * widest)
    return required * (1.0 + 2.0 * margin)


def frame_camera(target, azimuth_deg, elevation_deg, ortho_scale, name):
    from mathutils import Vector
    bpy = _blender()
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(camera)
    azimuth = math.radians(azimuth_deg)
    elevation = math.radians(elevation_deg)
    distance = max(ortho_scale, 1.0) * 3.0
    camera.location = (target.x + distance * math.cos(elevation) * math.sin(azimuth),
                       target.y - distance * math.cos(elevation) * math.cos(azimuth),
                       target.z + distance * math.sin(elevation))
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    return camera


def configure_render(size, samples=32):
    bpy = _blender()
    scene = bpy.context.scene
    engine = pick_engine(samples)
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    return engine


def render_to(path: Path):
    bpy = _blender()
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return str(path)


def render_one_house(house, model_path, args, yaw_deg, report):
    bpy = _blender()
    from mathutils import Vector
    source_sha_before = sha256_file(model_path)
    reset_scene()
    size = 256 if args.fixture else args.size
    engine = configure_render(size)
    imported = import_glb(model_path)
    metrics = measure(imported)
    holder, copies, scale = build_presentation_copy(imported, yaw_deg)
    add_floor()
    target = bpy.data.objects.new("AimTarget", None)
    bpy.context.scene.collection.objects.link(target)
    low, high = world_bounds(mesh_objects(copies))
    centre = (low + high) * 0.5
    target.location = (centre.x, centre.y, centre.z)
    bpy.context.view_layer.update()
    setup_world_and_lights(target)
    renders = {}
    az_requested = [float(value) for value in str(args.azimuths).split(",") if value.strip()]
    azimuths = [(("az%03d" % int(value)), value) for value in az_requested]
    # One shared ortho width that covers the projected bbox at every requested angle.
    ortho_scale = framing_scale(bbox_corners(low, high), (centre.x, centre.y, centre.z),
                                [value for _name, value in azimuths], args.elevation)
    for name, azimuth in azimuths:
        camera = frame_camera(Vector((centre.x, centre.y, centre.z)), azimuth, args.elevation,
                              ortho_scale, "Camera_" + name)
        renders[name] = {"role": VIEW_ROLES.get(name, "custom"), "azimuth_deg": azimuth,
                         "path": render_to(resolve(args.out) / "renders" / ("%s-%s.png" % (house["id"], name)))}
        if name == azimuths[0][0]:
            bpy.context.scene["framed_camera"] = camera.name
    blend_dir = resolve(args.out) / "blend"
    blend_dir.mkdir(parents=True, exist_ok=True)
    # Re-import so the saved .blend really contains the model, floor, lights and the framed camera.
    reset_scene()
    configure_render(size)
    imported = import_glb(model_path)
    holder, copies, scale = build_presentation_copy(imported, yaw_deg)
    add_floor()
    target = bpy.data.objects.new("AimTarget", None)
    bpy.context.scene.collection.objects.link(target)
    low, high = world_bounds(mesh_objects(copies))
    centre = (low + high) * 0.5
    target.location = (centre.x, centre.y, centre.z)
    bpy.context.view_layer.update()
    setup_world_and_lights(target)
    frame_camera(Vector((centre.x, centre.y, centre.z)), azimuths[0][1], args.elevation, ortho_scale,
                 "Camera_%s" % azimuths[0][0])
    bpy.ops.file.pack_all()
    blend_path = blend_dir / ("%s.blend" % house["id"])
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    source_sha_after = sha256_file(model_path)
    report.append({"id": house["id"], "name_zh": house.get("name_zh", ""),
                   "source_glb": str(model_path).replace("\\", "/"),
                   "source_sha256_before": source_sha_before, "source_sha256_after": source_sha_after,
                   "source_unchanged": source_sha_before == source_sha_after,
                   "engine": engine, "resolution": size,
                   "ortho_scale": round(ortho_scale, 4),
                   "presentation_scale": round(scale, 6),
                   "presentation_yaw_deg": yaw_deg,
                   "presentation_bounds_min": [round(value, 4) for value in low],
                   "presentation_bounds_max": [round(value, 4) for value in high],
                   "render_paths": {name: entry["path"] for name, entry in renders.items()},
                   "render_roles": {name: entry["role"] for name, entry in renders.items()},
                   "camera_azimuths": {name: entry["azimuth_deg"] for name, entry in renders.items()},
                   "camera_elevation_deg": args.elevation,
                   "blend_path": str(blend_path).replace("\\", "/"),
                   "raw_metrics": metrics,
                   "note": "raw metrics are measured on the untouched import; scale, yaw and floor "
                           "normalisation are presentation only and are not real building dimensions"})


def render_phase(args):
    bpy = _blender()
    trial = load_trial(resolve(args.trial))
    yaw_overrides = load_yaw_overrides(args)
    models_dir = resolve(args.models)
    out_dir = resolve(args.out)
    selected, unknown = select_houses(args, trial)
    report = {"trial_id": trial.get("trial_id"), "phase": "render",
              "generated_at_utc": now_utc(), "blender_version": bpy.app.version_string,
              "engine_requested": "EEVEE", "size": args.size, "fixture": bool(args.fixture),
              "source": "offline Blender render of generated GLB (Meshy trial)",
              "trial_path": str(resolve(args.trial)).replace("\\", "/"),
              "models_dir": str(models_dir).replace("\\", "/"), "houses": [], "missing": [],
              "unknown_house_ids": unknown}
    if args.fixture:
        report["source"] = "offline Blender render of an explicitly named primitive FIXTURE (not a Meshy result)"
    for house in selected:
        model = find_model(models_dir, house["id"])
        if model is None:
            report["missing"].append({"id": house["id"], "expected": str(models_dir / (house["id"] + ".glb"))})
            continue
        ready, reason, size = glb_readiness(model)
        if not ready:
            report["missing"].append({"id": house["id"], "expected": str(model).replace("\\", "/"),
                                      "bytes": size, "reason": reason})
            continue
        try:
            render_one_house(house, model, args, float(yaw_overrides.get(house["id"], 0.0)), report["houses"])
        except RuntimeError as error:
            report["missing"].append({"id": house["id"], "expected": str(model).replace("\\", "/"),
                                      "bytes": size, "reason": "import_failed: %s" % type(error).__name__})
            continue
    if args.fixture and args.fixture_glb:
        fixture_model = resolve(args.fixture_glb)
        if fixture_model.exists():
            render_one_house({"id": args.fixture_label, "name_zh": ""}, fixture_model, args, 0.0,
                             report["houses"])
            report["missing"] = []
        else:
            report["missing"].append({"id": args.fixture_label, "expected": str(fixture_model)})
    report["rendered_count"] = len(report["houses"])
    report["missing_count"] = len(report["missing"])
    report["disclaimer"] = ("offline presentation preview of the generated model; not game footage. "
                            "Geometry is the untouched import, never repaired or synthesised.")
    destination = report_path(args)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


# --------------------------------------------------------------- compose phase (CPython) ----


def compose_phase(args):
    report_file = report_path(args)
    if not report_file.exists():
        print(json.dumps({"phase": "compose", "error": "render report not found; run the render phase first",
                          "expected": str(report_file)}, indent=2, ensure_ascii=False))
        return 0
    report = json.loads(report_file.read_text(encoding="utf-8"))
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print(json.dumps({"phase": "compose", "error": "Pillow is not available; no sheet was written"},
                         indent=2, ensure_ascii=False))
        return 0
    cells = []
    for house in report.get("houses", []):
        paths = house.get("render_paths", {})
        front = paths.get("az038")
        back = paths.get("az218")
        if front and back and Path(front).exists() and Path(back).exists():
            cells.append({"id": house["id"], "name_zh": house.get("name_zh", ""), "front": front, "back": back})
    if not cells:
        print(json.dumps({"phase": "compose", "error": "no rendered front/back images found; nothing was composed",
                          "rendered_count": report.get("rendered_count", 0)}, indent=2, ensure_ascii=False))
        return 0
    font_card = _load_font(30)
    font_angle = _load_font(26)
    font_english = _load_font(20)
    font_header = _load_font(38)
    font_subtitle = _load_font(24)
    font_small = _load_font(20)
    sheet_width = max(1800, min(2400, int(args.sheet_width)))
    margin = 80
    gutter = 28
    columns = 3
    cell = (sheet_width - 2 * margin - (columns - 1) * gutter) // columns
    caption = 96
    header = 122
    footer = 46
    def fitted(draw, text, font, limit):
        """Return text unchanged when it fits, else trim to the last word that fits."""
        if not text:
            return ""
        box = draw.textbbox((0, 0), text, font=font)
        if box[2] - box[0] <= limit:
            return text
        words = text.split(" ")
        while len(words) > 1:
            words.pop()
            candidate = " ".join(words) + "..."
            box = draw.textbbox((0, 0), candidate, font=font)
            if box[2] - box[0] <= limit:
                return candidate
        return ""

    def short_index(house_id):
        digits = "".join(ch for ch in house_id.split("_")[0] if ch.isdigit())
        return digits or house_id.split("_")[0]

    def english_hint(house_id):
        parts = house_id.split("_")[1:]
        return " ".join(parts)

    sheets = []
    for start in range(0, len(cells), columns):
        chunk = cells[start:start + columns]
        height = margin * 2 + header + 2 * (cell + caption) + gutter + footer
        sheet = Image.new("RGB", (sheet_width, height), (247, 245, 241))
        draw = ImageDraw.Draw(sheet)
        title = "%d栋城镇住宅 · Meshy 7 实际模型" % len(cells)
        subtitle = "上排：正面斜视 / 下排：背面斜视 · Blender 离线渲染"
        if args.fixture:
            title = "离线夹具渲染 · 非 Meshy 结果"
            subtitle = "primitive fixture / Blender offline render"
        draw.text((margin, margin - 28), fitted(draw, title, font_header, sheet_width - 2 * margin),
                  fill=(38, 36, 34), font=font_header)
        draw.text((margin, margin + 34), fitted(draw, subtitle, font_subtitle, sheet_width - 2 * margin),
                  fill=(104, 100, 96), font=font_subtitle)
        for index, cell_data in enumerate(chunk):
            left = margin + index * (cell + gutter)
            inner = cell - 12
            for row, key in enumerate(("front", "back")):
                top = margin + header + row * (cell + caption + gutter)
                image = Image.open(cell_data[key]).convert("RGB")
                image = image.resize((cell, cell), Image.LANCZOS)
                sheet.paste(image, (left, top))
                draw.rectangle([left, top, left + cell - 1, top + cell - 1], outline=(214, 210, 204))
                if cell_data["name_zh"] and not args.fixture:
                    headline = "%s  %s" % (short_index(cell_data["id"]), cell_data["name_zh"])
                else:
                    headline = cell_data["id"]
                draw.text((left + 6, top + cell + 10),
                          fitted(draw, headline, font_card, inner), fill=(44, 42, 40), font=font_card)
                draw.text((left + 6, top + cell + 46),
                          "正面" if key == "front" else "背面", fill=(88, 84, 80), font=font_angle)
                hint = "" if args.fixture else english_hint(cell_data["id"])
                if hint:
                    draw.text((left + 78, top + cell + 52),
                              fitted(draw, hint, font_english, inner - 78), fill=(150, 146, 142),
                              font=font_english)
        footer_text = "离线渲染预览 · 非游戏画面" if not args.fixture else "offline fixture · not a Meshy result"
        draw.text((margin, height - margin + 6), footer_text, fill=(140, 136, 132), font=font_small)
        suffix = "" if start == 0 else "-%d" % (start // columns + 1)
        name = ("fixture-contact-sheet%s.png" % suffix) if args.fixture else ("contact-sheet%s.png" % suffix)
        destination = resolve(args.out) / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(destination)
        sheets.append({"path": str(destination).replace("\\", "/"), "size": list(sheet.size),
                       "cells": [cell_data["id"] for cell_data in chunk]})
    print(json.dumps({"phase": "compose", "sheets": sheets, "houses_placed": len(cells),
                      "note": "assembled from actual rendered PNGs; no image generation or editing"},
                     indent=2, ensure_ascii=False))
    return 0


def _load_font(size):
    from PIL import ImageFont
    for candidate in CJK_FONTS:
        if os.path.exists(candidate):
            try:
                return ImageFont.truetype(candidate, size)
            except Exception:
                continue
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except Exception:
        return ImageFont.load_default()


def main():
    args = parse_args()
    if args.phase == "render":
        return render_phase(args)
    return compose_phase(args)


if __name__ == "__main__":
    if "--help" in sys.argv and "--" not in sys.argv:
        print(__doc__)
        raise SystemExit(0)
    sys.exit(main())
