# Mobile mesh reduction and GPU art verification

Date: 2026-10-08. Scope: isolated mesh assets for the crowd, recruit, minigunner and rocket hero. Boss articulation is handled separately. This work does not alter enemy counts, collision shapes, damage, movement, wave logic, saves or the original model files.

## Delivered assets

| Asset | Original triangles / surfaces | Mobile triangles / surfaces | Use |
| --- | ---: | ---: | --- |
| `assets/mobile/zombie_near.glb` | 1,948 / 1 | **320 / 1** | Front ranks; rounded cap, face, separate arms, hands, legs and boots |
| `assets/mobile/zombie_mid.glb` | 1,948 / 1 | **144 / 1** | Middle ranks; red cap, pale face, visible eyes and separated limbs |
| `assets/mobile/zombie_far.glb` | 1,948 / 1 | **66 / 1** | Small distant silhouettes; red dome, pale face, dark legs |
| `assets/mobile/infantry.glb` | 3,410 / 1 | **2,199 / 1** | Recruit player |
| `assets/mobile/gunner.glb` | 14,308 / 12 | **3,599 / 2** | Minigunner player and recruitable statue |
| `assets/mobile/mech.glb` | 14,256 / 7 | **3,700 / 3** | Rocket hero player and recruitable statue |

All models retain the original feet origin, Godot −Z forward direction and exact original exported AABB. The crowd height remains 0.65 m; the other heights remain 1.0, 1.8 and 3.4 m. Verification reports zero exported min/max bound difference for all six meshes. The new assets have no textures or external model dependencies.

The crowd meshes are purpose-built geometry, not arbitrary whole-mesh decimation. Their most important colors and silhouette features survive each reduction. Near legs and boots were revised after GPU inspection to retain rounded forms within the requested 350-triangle cap. Mid and far stay within their 160- and 70-triangle caps. The far model is intentionally angular when enlarged; it should only be selected when its projected size is small.

The hero assets are reduced derivatives of the existing authored GLBs. Vertex colors preserve the palette while grouping materials into soft surfaces and metal surfaces; the rocket hero also retains a separate emissive surface. This reduces the minigunner's material surfaces from twelve to two and the rocket hero's from seven to three, while keeping weapons and gold armor visually distinct from skin and clothing. The gunner's barrel bundle, ammunition belt and backpack and the mech's shoulder rockets remain visible in the final GPU comparison.

## Cost reduction without deleting enemies

For the accepted 544-member crowd, geometry totals are:

| Mesh choice for all 544 | Triangles | Reduction against original |
| --- | ---: | ---: |
| Original | 1,059,712 | — |
| Near | 174,080 | 83.6% |
| Mid | 78,336 | 92.6% |
| Far | 35,904 | 96.6% |

A mixed-distance crowd costs the sum of the selected per-instance LOD triangle counts. These are geometry counts, not measured frame-rate improvements. Shadows or other passes can render geometry more than once. Each crowd LOD has one opaque surface and can be drawn in its own MultiMesh batch. This work does not require removing distant enemies or changing their simulation state.

Godot's [MultiMesh guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) supports batching repeated meshes, but notes that visibility is handled for the whole batch rather than each individual instance. The [3D performance documentation](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html) recommends simpler distant geometry, describes manual MultiMesh instancing, and notes that automatic instancing applies to Forward+ rather than Mobile/Compatibility. The runtime owner should therefore select explicit LOD batches and measure their actual cost on target devices.

## Import and material contract

`assets/mobile/mobile_import.gd` is attached to all six `.glb.import` files. It enables `vertex_color_use_as_albedo` and leaves `vertex_color_is_srgb` false on every surface with palette colors. The final GPU validation reads those correct flags immediately after loading the assets; it does not rely on a later gameplay helper to repair the imported palette. Automatic generated LODs and animation import are disabled for these static explicit-LOD assets.

The first contact pass revealed that baking imported hero material factors directly into the runtime vertex-palette path made the heroes visibly too dark. The builder now maps those material colors to the matching display-space RGB for the established Compatibility palette path. Existing infantry vertex colors are preserved. The corrected real GPU comparison shows close palette agreement with the originals, including cyan blue armor and warm gold. These assets should be rechecked if the renderer or color handling changes.

The materials keep soft/metal/emissive distinctions, but several original roughness values are consolidated. This is a deliberate simplification and is visible in close inspection. Runtime silver/gold reveal shaders can still replace the statue materials, as before.

## Evidence and verification

- [Actual Godot GPU contact sheet](../assets/mobile/gpu-contact.png): original/near/mid/far crowd front and rear, original/mobile hero pairs, and two genuine 180-instance MultiMesh groups. All models in individual panels are normalized to the same display height for comparison; their exported runtime heights are unchanged.
- [Geometry, bounds and SHA-256 manifest](../assets/mobile/manifest.json): all six outputs plus original input hashes, triangle counts, surfaces, vertices, sizes and bounds.
- [GPU import validation](../assets/mobile/gpu-validation.json): observed Godot mesh counts, bounds, material classes and import flags.
- [Cross-check results](../assets/mobile/verification.json): output hashes match, all original GLB hashes remain unchanged, budgets pass and GPU import geometry matches the GLBs.

The final contact run used Godot 4.7.2, Compatibility, Apple M1 Pro, at 1536 × 1050. Its owned process exited normally after twelve panels rendered and produced no script/engine errors. This is an art/import verification on a Mac, not a weak-phone FPS measurement. The initial sandboxed Mono editor attempt encountered local OS certificate/socket permissions; the final GPU capture used the project's existing standard self-contained Godot executable. An editor import during parallel gameplay work also logged that file's temporary missing-function errors; the isolated contact script did not instantiate gameplay and its final GPU log was clean.

## Reproduction

Run `art_source/build_mobile_lods.py` with the installed Blender executable's background Python mode. The completed build used Blender 5.2.2 LTS. The builder reads the original four GLBs, writes only `assets/mobile`, asserts each triangle budget and verifies the original hashes have not changed.

Import the project with Godot, then run `res://assets/mobile/verify_mobile.gd` in the Compatibility renderer. That script creates an isolated contact scene, saves the PNG and JSON under `assets/mobile`, and exits. It does not start the game, run a resident world or leave a helper process running.

The runtime integration, quality selection, boss animation, CPU work and real-device measurement remain the implementation owner's separate responsibilities. Asset reductions alone cannot establish a minimum supported phone or guarantee a frame-rate target.
