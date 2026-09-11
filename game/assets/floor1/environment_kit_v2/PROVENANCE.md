# Floor-1 environment components V2

Twenty reauthored components, three geometry LODs each. Editable source:
`Art/ReferenceScenes/Floor1EnvironmentKit20/Floor1_EnvironmentKit20_V2.blend`.
Rebuild using the adjacent `build_game_ready_v2.py` with Blender 5.2.1 LTS.

All mesh geometry, vertex palettes, UV layout and procedural shader detail were
authored for this project. There are no downloaded model/texture dependencies.
The existing market's warm limestone, muted timber, sage foliage and small blue
accents define the local style. The project is an independent fan-inspired work.
The [official SAOIF site](https://sao-if.bn-ent.net/) is setting context, not a
source of copied geometry, texture images, or a claim that these plant species
are canonically specified for Floor 1. Publication licensing remains separate.

## Use in Godot

Drag an `F1_*.tscn` into a level to include the shader, LOD ranges and optional
static collision proxy. A raw `_LOD0.glb` contains geometry and vertex colour,
but requires `game/spatial/environment_v2.gd` to get runtime shading and wind.
The 20 component scenes run the same factory in the editor and game. Turn off
`collision_enabled` on a scene instance for nonblocking visual dressing.

Tree LOD boundaries: 22 / 48 m. Small-component boundaries: 12 / 28 m. All
three levels share one AABB and exact adjacent ranges without hysteresis gaps.
Geometry and leaves differ at each level, while seeded
primary branch placement stays consistent. These are discrete transitions;
they still need route-specific visual review for production camera distances.

`COLOR_0` carries linear vertex colour. `TEXCOORD_0` carries surface coordinates;
`TEXCOORD_1.x` carries flexibility and `.y` carries independent leaf phase.
Rigid structures have zero weight. The shared shader applies spatially coherent
breeze and leaf flutter. This is vertex deformation with static physics; it
does not simulate branch elasticity, weather, or resource-bearing plants.

The runtime factory gives trunks and hard props simple cylinder/box proxies;
small foliage remains pass-through. Proxy dimensions and LOD thresholds can be
tuned in `game/spatial/environment_v2.gd` without editing the mesh. Demo
placements remain visual-only until their exact routes are reviewed.

The `manifest.json` pins the delivered 60 GLBs and measured triangle counts.
Run `python3 tools/validate_environment_v2.py` to inspect the exported binary
geometry, hashes, attributes, wind masks and degenerate triangles independently.
The previous V1 files remain available for comparison and recovery.
