# Floor-1 residential exteriors 01–05

Original project geometry, palette, UVs and procedural PBR maps, authored locally
with Blender 5.2.1 LTS. No downloaded house, texture pack, anime frame, restricted
character or private world data is used. This is an independent fan-inspired
starting-town architectural interpretation, not a reconstruction of five
canonically specified SAO buildings. A project-wide reuse license has not been
selected; this record does not grant one.

## Contents and use

- `F1_Residence_01.tscn`: Linden Court / 菩提庭院宅; balcony and twin dormers.
- `F1_Residence_02.tscn`: Copper Gable / 铜檐窄街宅; narrow three-storey house and oriel.
- `F1_Residence_03.tscn`: Rose Courtyard / 蔷薇花院宅; attached perpendicular wing and open arcade.
- `F1_Residence_04.tscn`: Sage Gallery / 鼠尾草长廊宅; hipped roof and covered long balcony.
- `F1_Residence_05.tscn`: Azure Corner / 青瓷转角宅; taller corner volume and blue-grey roof.

Drag a `.tscn` into Godot. The shared component script attaches materials,
32 / 70 m LOD ranges and optional closed-exterior collision. `force_lod = 0`
locks the high-detail mesh for close art review. Every corresponding GLB is
self-contained, with all three named LOD meshes and embedded textures. A raw
GLB imported into a different tool displays all three LODs until two are hidden;
the Godot wrapper performs that selection automatically.

`Art/ReferenceScenes/Floor1Residences/Floor1_Residences_5.blend` contains all five
houses, packed textures and named LODs. Rebuild using the adjacent
`build_residences.py`; its only non-standard Python dependencies are Blender's
bundled `bpy`, `bmesh`, `mathutils` and NumPy. Blender serialization is not
promised byte-identical across runs; the delivered manifest pins actual hashes.

## Surface workflow

Four shared material sets: limestone, lime plaster, oak and fired clay. Each has
a 2048² sRGB albedo, OpenGL tangent-space normal and linear ORM texture. ORM's
R is neutral white (no baked AO), G is roughness and B is zero metallic; metal
hardware has its own metallic material. The shared neutral textures multiply
the authored per-corner palette. Godot shares the external source maps among
the five wrappers and enables anisotropic mip filtering. Godot may also extract
embedded GLB images alongside each GLB; those are import dependencies, not new
authored texture sets.

UV0 repeats every 2 m (nominal 1024 texels/metre) and follows local timber axes.
Overlapping/repeated UV0 islands intentionally reuse tiling surfaces. UV1 is a
separate packed 0–1 unwrap; tiny collapsed triangles are moved to a reserved
atlas strip. It is not a baked lightmap or a supplied unique painted facade map.
Actual exported UV bounds and zero-area UV triangles are checked independently;
the geometry/UV validation does not certify a production light bake or every
possible island overlap. A runtime checker view is included for inspection.

## Scope and limitations

These are detailed residential **exteriors** with fixed closed doors and
unfurnished shells. There is no enterable furnished interior, functioning door,
resident home assignment, resource creation or save migration. The art-review
street is isolated from the maintained town. Thirteen static proxy boxes cover
main closed volumes and porch posts; route placement, roof access, balconies,
navigation and interior collisions need a dedicated gameplay pass. LODs are
discrete decimated meshes, not HLOD/impostors; a dense district still needs a
separate memory, streaming and frame-budget review.
