# Independent opening-visibility review

Date: 2026-09-28. Implementation author: city/motion agent. Reviewer: skin-catalog/UI agent. Result: **PASS — 1,700 independent checks**, with no unexpected engine errors. Runtime files were not edited by the reviewer.

The previous implementation faded only nearby building bodies according to a world-axis bounding box. It omitted props, skinned pedestrians, traffic, recipe actors, food and food batches. Claimed buildings became opaque, and the old check did not establish whether a building was between the camera and the opening.

The replacement uses one bounded, movement-directed aperture and evaluates each surface fragment's camera ray. Initial material binding includes edible originals and static batches. Moving food, settled rain and cached fractures keep their existing shared shader. Fallback fractures explicitly bind their new material. Per-frame updates change four global shader vectors; they do not scan scene objects or rewrite every material.

## Findings corrected before acceptance

- An additional world-XZ foreground plane incorrectly excluded roofs directly above the hole and the destination when moving away from the camera. The implementation now establishes foreground along the projected camera ray. Independent fixtures include camera `(10,18,14)` and fragment `(0,1,0)`, as well as away-direction destinations.
- Reset originally retained a large previous-round radius. Reset now restores the starting radius before the next map begins. A real large-hole-to-fresh-round transition is covered.
- The first StandardMaterial adapter unconditionally decoded vertex RGB. The author replaced it with Godot's generated-material rule: apply the source sRGB flag only in a non-sRGB-output renderer. Emissive color and energy are also separate inputs. The reviewer checked copied material inputs; the separate windowless shader probe checks the Compatibility albedo equation.

## Independent evidence

`tests/visibility_review.gd` runs against the actual main scene with `--test` and no progress path. Strict `release_web.acceptance` process/error handling was used, with an in-memory marker mapping for `VISIBILITY_REVIEW`; the shared release gate was not changed by the reviewer.

- Every effective material on 935 city edible mesh surfaces and 2,588 food-map surfaces includes the reveal path. This includes 64 city and 48 food skinned pedestrian meshes, vehicles, lamps, signs, emissive signal actors and recipe assemblies. Initial city/food static batches number 29/527 respectively.
- All ten rain kinds retain the shared food shader while airborne, after settling into a batch, and after independent release. The resulting 537 food batch materials pass the same coverage inspection. A real city prop also leaves its static batch without changing its mesh/material.
- Both cached and fallback building paths produce sixteen independent pieces with reveal support. Cached pieces retain the original palette material object.
- Four camera yaws, three hole radii and three movement vectors generate known ground endpoints. Samples at three heights along each camera ray check the mouth and destination. Ground, below-ground, behind-camera and unrelated side geometry remain unaffected. Actual menu cameras, changed camera direction and shadow-pass cases are excluded.
- Pause freezes state; results, Home and an inactive player disable it. A map restart restores its own radius and bindings. Player skins, ground, pedestal/water and cosmetic impact flecks remain outside the adaptation path.
- Body transforms, freeze/collision flags, score values and masses remain unchanged during aperture updates. Material culling, shadow-caster mode, tint, roughness, metalness, specular, vertex-color flags and emission inputs survive adaptation. Unsupported alpha/normal-map paths are rejected by preflight.
- Repeated updates retain material/binding counts. Static inspection of the actual `tick` body confirms no per-object loop, scene traversal or per-material parameter write.

Receipts, category counts, raw logs and exact before/after hashes are in `artifacts/mobile-visibility-20260928/reveal-review/`. All twelve guarded inputs remained unchanged during the final run. The later parent-only `project.godot` version bump from 0.8.0 to 0.8.1 occurred after this run; its pre-bump hash is retained honestly rather than replaced.

## Shader-probe cross-check and limits

The reviewer inspected `tools/validate_mobile_visual_shaders.py` and `tools/visual_shader_probe.m`, then verified the recorded hashes against current files in `artifacts/mobile-visibility-20260928/shader-probe-final/result.json`. Five shipped fragment bodies compile in the windowless GL wrapper. The actual shared reveal include passes nineteen cases: foreground samples retain 6.25% of pixels through the stable Bayer pattern, while excluded samples retain 100%. Twelve midtone swatches exercise the shipped adapter's vertex-color transform with both vertex-color and sRGB-flag values.

The headless suite tests the controller's CPU geometry mirror, real scene/material wiring and lifecycle. The separate GL probe executes the shipped shader equations, but does not reproduce Godot's complete lighting, source-color uniform upload conversion, skeletal deformation or interpolated mesh rendering. Neither receipt establishes browser appearance, final shadow-map pixels, phone GPU cost, graphics memory consumption or sustained iPhone 14 frame rate. Those require actual engine/browser and device acceptance.
