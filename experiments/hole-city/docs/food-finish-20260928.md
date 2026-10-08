# Food surface and rounded silhouette correction — September 28, 2026

Version 0.5.2 addresses the user's missing highlights and rounded food forms.
The previous pass changed density and color but left hard BoxMesh/CylinderMesh
edges, a single uniform food finish and strong ambient light. The earlier
offline preview also omitted specular lighting entirely. Smooth normals were
already preserved during merging; this was not a normal-loss defect.

Food-sized boxes now have curved corner geometry and discs have rounded rims.
The mesh builder preserves their outer dimensions so the existing collision
contract remains usable. Large buns, yolks and fruit use smoother spheres.
Small seeds and chips use fewer segments: initial food triangle population
falls from 4,839,808 to 4,490,428 before spatial culling, a 7.22% reduction.
The cached mesh count and spatial batch count remain unchanged.

Ingredient roughness is baked into vertex alpha at merge time. A shared opaque
shader reads that channel as finish data: icing, syrup and yolk are glossy;
pastry is more matte. It retains engine lighting and shadows and adds two
view-dependent studio reflection lobes, with no screen-space reflections,
bloom, transparent pass or extra light. The released food uses the same mesh
and material as its static batch. Food-map and food-menu ambient energy fall
from 0.78/0.8 to 0.48; Sunny City's lighting is restored on a map switch.

The shader follows the engine's [spatial shader material interface](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
and explicitly decodes sRGB vertex albedo. Vertex alpha never writes ALPHA,
so ingredient finish cannot accidentally make the food transparent.

Validation:

- 111 geometry/material checks cover preserved bounds, outward winding,
  curved unit normals, ingredient data after merging, shared static/falling
  materials, map-light restoration and bounded triangle counts.
- The existing ten-food landing/NPC suite passes 39 checks. Its old
  StandardMaterial property assertion was replaced with a check of actual
  saturated vertex color because food now uses a ShaderMaterial.
- The guarded export runs the previous physics, city, skin, UI, dense support
  and full-round suites plus the new finish suite on source and PCK. Final
  totals are 4,186 checks each with no failures. Delivered hashes are in
  `artifacts/food-finish/release.json`.
- A windowless OpenGL probe compiles the shipped surface functions and renders
  actual food meshes. Switching only glaze_strength to zero changes 2,412
  pixels by more than 15 summed RGB levels in the six-food preview. This checks
  that the highlight code contributes visible pixels rather than merely
  setting unused material properties.

The preview uses exact food surface/reflection functions but approximate final
scene lighting. It has no UI, characters, contact shadows or full Godot lighting
pipeline. It is not a browser screenshot or iPhone performance result. Actual
browser visual review and iPhone 14 sustained 60 FPS remain unverified.
