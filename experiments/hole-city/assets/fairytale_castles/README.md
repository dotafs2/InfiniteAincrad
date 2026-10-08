# Original Sunspell royal snap-together castle kit

The project authors and saves this kit in Blender with
`tools/build_fairytale_castles.py`. It uses no third-party models, textures,
image-generated geometry, or copied castle design.

Rosewater Keep (`toy_castle`), Sunspell Palace (`grand_castle`), Starlight
Watchtower (`bubble_turret`), Moonbridge open arch (`toy_arch`) and Gingerbeam
Townhouse (`block_tower`) form one glossy plastic family. A broad low entry
keep, narrower rose upper hall and one dominant tall crown tower establish
three clear height tiers. Unequal flank towers, curved cobalt/teal roofs,
projecting balconies and dark framed windows establish the royal silhouette.
A dark inset gate sits behind a true U-shaped portal, with one half-scale
dormer seated into the upper roof.
Real closed block
courses have staggered joints; stacked turret modules, raised circular studs,
assembled curved roof panels and colorful snap frames reveal construction.

Runtime JSON contains indexed vertices, real Blender corner normals, opaque
RGBA colors, material roles, major compound collider point clouds and actual
component index ranges. Component bounds, structural roles and course/surface
IDs are derived from the authored Blender objects. The unit AABB is centered
on x/z with bottom y=0. `natural_size` preserves all five preceding kit
envelopes exactly; evaluated geometry is physically calibrated before export.
The standalone arch declares a clear ray from `(0, .25, -.8)` to
`(0, .25, .8)` through its opening. Editable source is saved under `source/`,
excluded from game imports by `.gdignore`.

The manifest binds the actual Blender version/binary, generator, editable
`.blend`, each JSON, measured geometry signatures, component counts and
triangle budgets. Royal generation 03 completed successfully under Blender
4.2.13 LTS; generation 01's budget failure remains preserved in
`build/royal-castle-20261008/`. No budget was raised. The primary castles each
have 11,756 triangles, the tower 1,660, open arch 1,892 and townhouse 5,120.
The source Blender SHA-256 is
`f174e03bbbd5c18e4532e817fc125a29fc27e6a30eee361e89774b40a7e09766`.
Only major masses become colliders; windows, balconies, studs, pennants,
parapets and entry steps remain visible decoration. Primary castle normalized
horizontal admission radii stay within 0.7% of their prior values.

Official castle references informed general architectural hierarchy and
material contrast only. This kit contains no third-party asset, emblem,
character or copied building arrangement. Full authoring and measurement
evidence is recorded in `docs/royal-castle-20261008/MODELS.md`.

Topology, runtime physics and
visual acceptance require their own recorded executions. A saved Blender mesh
and budget check alone do not establish gameplay or visual acceptance.
