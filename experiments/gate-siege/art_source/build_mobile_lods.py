"""Build isolated mobile meshes. Run with Blender --background --python this_file.

The original GLBs remain read-only inputs. Crowd silhouettes are purpose-built;
hero meshes are reduced from the authored models, then use vertex palettes with
separate soft/metal/emissive surfaces. No gameplay state or hitboxes are edited.
"""
import bpy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models"
OUT = ROOT / "assets/mobile"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE_NAMES = ("zombie", "infantry", "gunner", "mech")
PALETTE = {
    "cap": (0.78, 0.23, 0.29, 1),
    "rim": (0.65, 0.16, 0.21, 1),
    "cloth": (0.64, 0.31, 0.35, 1),
    "face": (0.83, 0.68, 0.62, 1),
    "boot": (0.04, 0.045, 0.065, 1),
    "eye": (0.018, 0.024, 0.035, 1),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_glb(path):
    data = path.read_bytes()
    size, _ = struct.unpack_from("<II", data, 12)
    doc = json.loads(data[20:20 + size])
    primitives = [p for m in doc["meshes"] for p in m["primitives"]]
    pos = [doc["accessors"][p["attributes"]["POSITION"]] for p in primitives]
    return {
        "triangles": sum(doc["accessors"][p["indices"]]["count"] // 3 for p in primitives),
        "surfaces": len(primitives),
        "vertices": sum(p["count"] for p in pos),
        "bounds_godot": {
            "min": [min(p["min"][i] for p in pos) for i in range(3)],
            "max": [max(p["max"][i] for p in pos) for i in range(3)],
        },
        "all_surfaces_vertex_color": all("COLOR_0" in p["attributes"] for p in primitives),
        "material_classes": [m.get("name", "") for m in doc.get("materials", [])],
        "bytes": len(data),
        "sha256": sha(path),
    }


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_original(name):
    clear()
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / (name + ".glb")))
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects)>1:
        bpy.ops.object.join()
    ob = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def bounds(ob):
    return [Vector([f(v.co[i] for v in ob.data.vertices) for i in range(3)]) for f in (min, max)]


def fit_bounds(ob, target):
    lo, hi = bounds(ob)
    for v in ob.data.vertices:
        for i in range(3):
            v.co[i] = target[0][i] + (v.co[i] - lo[i]) * (target[1][i] - target[0][i]) / (hi[i] - lo[i])


def linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def srgb(c):
    return 12.92*c if c <= .0031308 else 1.055*c**(1/2.4)-.055


def plain_material(name, color, metal=0.0, rough=.6):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    col = tuple(linear(c) for c in color[:3]) + (color[3],)
    mat.diffuse_color = col
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = col
    bs.inputs["Metallic"].default_value = metal
    bs.inputs["Roughness"].default_value = rough
    return mat


def palette_material(name, metal, rough, emission=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (1, 1, 1, 1)
    bs.inputs["Metallic"].default_value = metal
    bs.inputs["Roughness"].default_value = rough
    vc = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Color"
    mat.node_tree.links.new(vc.outputs["Color"], bs.inputs["Base Color"])
    if emission:
        bs.inputs["Emission Strength"].default_value = .22
        mat.node_tree.links.new(vc.outputs["Color"], bs.inputs["Emission Color"])
    return mat


def group_palette(ob, crowd=False):
    old = list(ob.data.materials)
    colors = ob.data.color_attributes.get("Color")
    if not colors:
        colors = ob.data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    else:
        # Imported infantry already has vertex colors; preserve them verbatim.
        colors = ob.data.color_attributes.active_color or colors
        colors.name = "Color"
    classes = []
    assignments = []
    for poly in ob.data.polygons:
        mat = old[poly.material_index]
        bs = mat.node_tree.nodes.get("Principled BSDF")
        metallic = bs.inputs["Metallic"].default_value
        is_colored = bs.inputs["Base Color"].is_linked
        color = tuple(bs.inputs["Base Color"].default_value)
        if not crowd and not is_colored:
            # Match the existing Godot Compatibility material-color appearance.
            # Original GLB material factors are linear; the runtime's vertex
            # palette path consumes the corresponding display-space RGB.
            # Already-authored vertex palettes (infantry) are preserved below.
            color = tuple(srgb(c) for c in color[:3]) + (color[3],)
        emit = bs.inputs["Emission Strength"].default_value > 0 or mat.name.startswith("cyan")
        group = "crowd" if crowd else ("emissive" if emit else "metal" if metallic >= .45 else "soft")
        if group not in classes:
            classes.append(group)
        assignments.append(classes.index(group))
        if not is_colored:
            for li in poly.loop_indices:
                colors.data[li].color = color
    ob.data.color_attributes.active_color = colors
    ob.data.materials.clear()
    for group in classes:
        ob.data.materials.append(palette_material(
            "mobile_" + group,
            .68 if group == "metal" else .08,
            .28 if group == "metal" else .55,
            group == "emissive",
        ))
    for poly, assignment in zip(ob.data.polygons, assignments):
        poly.material_index = assignment


PARTS = []
MATS = {}


def attach(ob, name, material, smooth=True):
    ob.name = name
    ob.data.materials.clear()
    ob.data.materials.append(MATS[material])
    for p in ob.data.polygons:
        p.use_smooth = smooth
    PARTS.append(ob)
    return ob


def ball(name, at, size, mat, segments=6, rings=3):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=at)
    ob = attach(bpy.context.object, name, mat)
    ob.scale = size
    return ob


def box(name, at, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = attach(bpy.context.object, name, mat, False)
    ob.scale = size
    return ob


def rod(name, a, b, radius, mat, sides=4):
    a, b = Vector(a), Vector(b)
    delta = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=radius, depth=delta.length, location=(a+b)/2)
    ob = attach(bpy.context.object, name, mat)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return ob


def custom(name, vertices, faces, mat, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    return attach(ob, name, mat, smooth)


def far_cap():
    ring = [(.147*math.cos(i*math.tau/6), -.005+.134*math.sin(i*math.tau/6), .583) for i in range(6)]
    custom("six-sided red cap dome", ring+[(0,-.006,.676)], [tuple(reversed(range(6)))]+[(i,(i+1)%6,6) for i in range(6)], "cap", True)


def build_crowd(lod, target):
    global PARTS, MATS
    clear()
    PARTS = []
    MATS = {k:plain_material("crowd_"+k, v) for k,v in PALETTE.items()}
    if lod == "far":
        box("jacket", (0,0,.365), (.239,.16,.245), "cloth")
        for side in (-1,1):
            box("leg", (side*.062,0,.14), (.095,.125,.28), "boot")
            x = side*.13
            custom("arm silhouette", [(x,-.04,.425),(x,.17,.365),(x+side*.055,.03,.31),(x+side*.026,-.05,.36)], [(0,1,2),(0,3,1),(0,2,3),(1,3,2)], "cloth")
        box("pale face", (0,.014,.52), (.18,.147,.13), "face")
        far_cap()
    else:
        near = lod == "near"
        ball("rounded jacket", (0,0,.36), (.128,.092,.145), "cloth", 8 if near else 6, 3)
        for side in (-1,1):
            x=side*.063
            rod("separate rounded leg", (x,0,.04), (x,0,.283), .052, "cloth", 6 if near else 5)
            if near:
                ball("black rounded boot", (x,.03,.045), (.055,.084,.045), "boot", 6,3)
                rod("upper sleeve", (side*.11,.005,.413), (side*.137,.076,.348), .046, "cloth")
                rod("bare forearm", (side*.137,.076,.348), (side*.1,.169,.372), .033, "face")
                ball("hand", (side*.1,.172,.372), (.037,.044,.035), "face", 4,2)
            else:
                rod("single arm", (side*.115,0,.405), (side*.11,.166,.36), .045, "cloth")
        ball("pale head", (0,.016,.533), (.11,.092,.109), "face", 8 if near else 6, 3)
        ball("red helmet dome", (0,-.002,.617), (.148,.136,.091), "cap", 8 if near else 6, 3)
        if near:
            rod("red cap rim", (0,-.002,.582), (0,-.002,.602), .137, "rim", 8)
            box("black belt", (0,.003,.275), (.223,.153,.024), "rim")
        box("helmet visor", (0,.094,.59), (.234,.126,.023), "cap")
        for side in (-1,1):
            x=side*.036
            custom("dark eye", [(x-.012,.109,.551),(x+.012,.109,.551),(x+.012,.109,.535),(x-.012,.109,.535)], [(0,1,2,3)], "eye")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    ob=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    fit_bounds(ob,target)
    group_palette(ob,True)
    return ob


def export(ob, name, budget):
    ob.name = name
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active=ob
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_materials="EXPORT", export_animations=False,
        export_texcoords=False, export_attributes=False)
    stats=read_glb(OUT/(name+".glb"))
    assert stats["triangles"] <= budget, (name, stats["triangles"], budget)
    assert stats["all_surfaces_vertex_color"], name
    stats.update({"name":name,"triangle_budget":budget,"facing_godot":"-Z","origin":"feet","textures":0})
    print("MOBILE_ASSET",json.dumps(stats))
    return stats


before={n:sha(SOURCE/(n+".glb")) for n in SOURCE_NAMES}
models=[]
crowd_source=import_original("zombie")
crowd_bounds=bounds(crowd_source)
for lod,budget in (("near",350),("mid",160),("far",70)):
    models.append(export(build_crowd(lod,crowd_bounds),"zombie_"+lod,budget))
for name,target_count in (("infantry",2200),("gunner",3600),("mech",3700)):
    ob=import_original(name)
    target_bounds=bounds(ob)
    before_tri=sum(len(p.vertices)-2 for p in ob.data.polygons)
    dec=ob.modifiers.new("mobile silhouette reduction","DECIMATE")
    dec.ratio=target_count/before_tri
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.modifier_apply(modifier=dec.name)
    fit_bounds(ob,target_bounds)
    group_palette(ob)
    models.append(export(ob,name,4000))
after={n:sha(SOURCE/(n+".glb")) for n in SOURCE_NAMES}
assert before==after,"Original GLBs changed during mobile build"
manifest={
    "authoring":"Original purpose-built crowd LODs and reduced derivatives of Gate Siege's authored hero meshes.",
    "builder":"art_source/build_mobile_lods.py",
    "blender_version":bpy.app.version_string,
    "source_glbs_unchanged":True,
    "source_models":{n:read_glb(SOURCE/(n+".glb")) for n in SOURCE_NAMES},
    "models":models,
    "scope":"Mesh substitution only; no enemy deletion, collision, wave, damage, save or hitbox edits.",
}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
