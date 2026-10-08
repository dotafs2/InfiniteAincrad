# Snack Garden visual miniature

`fidelity/food_preview.gd` replaces the two-tower menu sample with a dedicated visual-only district. It exposes the same `preview` pivot and `build_preview()` entry point as the Sunny City miniature and rotates the pivot at 0.10 radians per second. The menu owns the processing and viewport visibility switches; rebuilding does not override a disabled state.

## Composition

The miniature contains 68 individually identifiable food meshes using all ten existing recipes. Its 34 foreground foods form a low cookie heap, a breakfast scatter and a picnic scatter, with loose snacks around the street edges. The 14 middle pieces include independently offset, slightly tilted and tapered pancake, burger and donut stacks plus a small shop. Twenty background pieces form three different rooflines: a tall pink cake, a shorter turquoise cake and lower wafer apartments. Individual layers change position, rotation and size rather than sharing one rigidly tilted tower transform.

Actual mesh bounds put the highest foreground, middle and background points at approximately 1.345, 4.085 and 7.863 units. Their average depth positions are 2.801, −0.253 and −3.042. A bent chocolate avenue and connecting lane separate the front food from the taller district; cream lane marks and a biscuit-and-cream base make the streets legible without external images.

Grounded ingredients use a common bottom height of 0.125 above the biscuit top at 0.12, a five-millimetre visual clearance. Stacked meshes use their transformed extents with a small contact overlap. Cookie-heap toppings follow their actual supporting cookie surfaces. The extra berries on the cake crowns use the central icing surface height rather than the cake's bounding-box maximum, which includes separate decorative berries around the edge. This avoids adding a visible floating gap at the crown center.

## Resource and lifecycle scope

The preview reuses `FoodCity.mesh_for(kind, tower, flavor)` and the existing ingredient-glaze shader, including baked saturated colors and per-ingredient roughness. A temporary builder is attached solely because the existing mesh combiner needs valid global transforms. Its process and physics callbacks are disabled immediately, and it is freed synchronously before `build_preview()` returns. The preview never calls the full city builder, gameplay food factory, tower factory or rain system. Temporary primitive meshes queued by the existing combiner are released at the normal frame cleanup.

Only mesh resources are retained in a bounded static cache. There are 87 mesh instances, 27 unique meshes and one shared opaque glaze material, totalling 123,104 submitted geometry triangles before renderer culling. Repeated previews share these resources. No rigid bodies, collision shapes, collection receipts or live game-city node remain in the miniature. The glaze explicitly disables both reveal opt-in paths, keeping menu food opaque independently of gameplay reveal state.

Calling `build_preview()` again immediately frees the prior pivot. Closing the menu preview frees the entire scene hierarchy. The scene's sole recurring work is rotating its pivot; UI visibility controls suspend that work when hidden.

## Validation

`tests/food_preview_acceptance.gd` passes **483 checks** under headless Godot with `--test`. Coverage includes recipe variety, actual three-layer geometry, six individually staggered stacks and their contact seams, encoded color/roughness data, mesh/material reuse across rebuilds and separate instances, lack of physics nodes, actual process-frame rotation and hidden stopping, and cleanup.

The unchanged hero camera uses a 640×560 viewport, orthographic size 21, position `(19, 24, 26)` and target `(0, 4, 0)`. At 72 rotations across the full circle, every transformed mesh-bounds corner remains inside the camera, with a minimum 44.763-pixel boundary margin. This checks framing without changing the UI layout or camera to make the scene fit.

Final author receipts and source hashes are in `artifacts/map-preview-20260929/food-author/final.json` and `manifest.json`. The initial author-test parse failure was limited to two missing `WeakRef` annotations in the new harness; its logs remain as `parse-failed.*`. The corrected final run has no unexpected engine diagnostics.

These are headless geometry, resource and controller checks. They are not browser screenshots, a final visual appearance judgment or a phone performance claim. Independent review covers the final miniature and the parent agent's UI lifecycle integration separately.
