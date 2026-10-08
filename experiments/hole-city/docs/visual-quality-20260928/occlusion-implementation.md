# Camera-to-hole visibility

Implemented on 2026-09-28 by the city agent. Independent review is recorded separately by the skin agent and root shader reviewer. The non-author scene review passed 1,700 assertions; see `docs/mobile-visibility-20260928/visibility-review.md`.

The old building-center proximity alpha switch is removed. Actual fragment positions now project along the gameplay camera ray onto the hole's ground plane. An enlarged capsule covers the hole and a smoothed movement destination. This handles tall facades, wide objects whose centers lie outside the aperture, independent props, skinned pedestrians, static MultiMesh batches, falling buildings and food. No object query, raycast, scene traversal or material adaptation runs per frame.

A stable 4 × 4 Bayer mask removes up to 15 of 16 pixels in the central reveal area. The aperture edge is feathered; activation and movement lookahead use a 0.16-second exponential response. The radius exceeds the hole by at least one world metre (22% for larger holes). Lookahead represents 0.55 seconds of actual velocity with a bounded 2–5 metre extent. The reveal uses the per-ray interval between the camera and the ground plane, rather than an XZ plane through the player: the latter incorrectly rejected roofs directly above the hole and movement away from the camera. The independent review caught those cases before release, and both are now acceptance fixtures.

Ordinary geometry outside the aperture keeps its original appearance. City StandardMaterials are adapted once, cached by original material identity, and retain albedo, vertex-color flags, roughness, metallic, specular, emission color/energy, culling and render priority. Vertex-color conversion follows Godot's BaseMaterial3D generator: the sRGB flag converts only when OUTPUT_IS_SRGB is false. Existing palette and glossy-food shading equations are unchanged outside the mask. Opaque depth behavior avoids whole-object transparent sorting. Supported actual scene material profiles are checked; unknown textured/BRDF configurations produce an explicit diagnostic rather than silently replacing their finish.

The shared include exits during IN_SHADOW_PASS and for any camera with a different position or basis. Existing complete shadow casters therefore remain complete. Ground, city base, water and UI model roots are outside the material binding. Camera guards additionally protect any shared resources displayed in other viewports. Colliders, support relationships, swallow admission and reward logic are unchanged.

Startup and map changes bind edible originals, including the invisible originals retained for later release, plus visible city MultiMeshes. Cached fractures retain palette material; the fallback fracture builder explicitly adapts its new StandardMaterial. New food rain and newly created settled-food batches already share the included glaze shader. Pause freezes the current backdrop aperture. Home, settlement, inactive player, new round and tree exit clear the reveal; a fresh round also resets the radius.

## Evidence

`tests/hole_reveal_acceptance.gd` passes **191 checks** against real source scenes using `--test`. City coverage includes 935 edible meshes, 29 static batches, 64 skinned meshes, 172 distinct source materials and 29 emissive sources. Food coverage includes 2,588 edible meshes, 527 static batches and 48 skinned meshes. Both maps report zero unsupported materials. Tests exercise hidden originals, material properties, both 16-piece fracture paths, new rain, settled rain batching/release, camera/shadow guards, wide/tall blocker geometry, movement away from the camera, 30/60/120 Hz smoothing, lifecycle resets and 600 controller ticks without rebinding.

Artifacts: `artifacts/occlusion-20260928/acceptance.json`, `acceptance.log`, and `source-hashes.json`. Root separately compiled the actual include and sampled 19 shader coverage scenarios plus 12 material midtone cases with a windowless OpenGL harness. That is bounded shader evidence, not a Godot game capture.

The current Mac session is locked. Browser motion, perceptual dither quality and real iPhone 14 GPU/60-fps acceptance are not claimed by the headless scene or isolated shader tests. No full-scene foreground rendering or user save was used.

## Public diagnostics

- `game.update_reveal(delta)` updates the controller after the current camera pose.
- `game.prepare_occluder(node)` adapts newly authored edible geometry once.
- `game.reveal.diagnostics()` reports uniforms, mesh/batch/material counts, unsupported material reasons and update count.
- `game.reveal.sample_mask(world, view_camera, view_back, shadow_pass)` is a CPU mirror for bounded regression only; production visibility is evaluated per fragment in the shared shader include.
