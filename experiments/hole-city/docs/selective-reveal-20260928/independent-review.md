# Independent selective-visibility review

Date: 2026-09-28. Author of implementation: parent agent and food agent. Independent reviewer: skin-catalog/UI agent. Result: **PASS — 225 checks**, with no unexpected engine diagnostics. All twelve guarded source inputs remained unchanged during the final run.

This review follows the user's correction to v0.8.1. Revealing every intervening object made nearby gameplay difficult to read. The previous broad-coverage checks are historical evidence for a superseded requirement; they are not acceptance criteria for this correction. The new criterion is that only sufficiently large, intact architectural shells may reveal. Their projected bounds must intersect the actual mouth, and an actual mesh triangle must also intersect a tested camera-to-mouth segment. Actors, vehicles, street props, loose food and debris remain visible inside the expanded visual aperture.

## What was independently checked

`tests/selective_reveal_review.gd` runs the actual main scene with `--test` and no progress path. Its separate geometry fixtures exercise the production selection controller and actual palette material parameters.

- Sunny City contains 48 qualifying buildings and 608 excluded bodies. All excluded categories retain zero reveal activation: people, vehicles, lamps, signs, signal pylons, ambient/recipe actors and street furniture.
- Snack Garden contains 630 qualifying structural tiers and 1,958 excluded bodies. Roof decorations, loose snacks, heaps, sushi vehicles and NPCs remain excluded. All ten kinds of rain remain excluded while airborne, after batching and after release.
- A nearby building has its nearest projected edge more than 1.2 units from a 0.85-unit mouth. Its surface is demonstrably inside the enlarged shader aperture, but selection and material activation remain zero. Moving toward it does not activate it. This supplies an independent projection bound rather than reproducing the implementation's convex-hull algorithm.
- Positive fixtures cover a large shell over the mouth, a distant building center whose wide edge actually covers the mouth, and a tall structure crossing camera height. Negative fixtures cover ground/background planes, a low wide mass, a narrow tall mass, and oversized objects with nonbuilding categories. Four diagonal follow-camera yaws verify covering shells and unrelated side structures.
- A multipart arch and an actual batched food donut both deliberately have broad bounds covering the mouth while their openings remain clear. For each, 65 independent direct segment/triangle intersections report zero hits and the actual controller/material weight remains zero. Moving the mouth toward a solid pillar or dough produces a real center-ray hit and enables the corresponding shell. The arch's visible side also lies inside the expanded shader aperture, so these tests would catch the unwanted side fading from a bounds-only activation rule.
- A claimed, released or consumed shell immediately loses eligibility. Both cached and fallback building fractures create sixteen visible pieces after an actively revealed parent. Two subsequent frames and another active controller update exercise the freed parent reference.
- A three-member batch deliberately mixes identical structural and loose food meshes. Only the two structural members receive controller/CPU activation. Releasing the first member correctly moves the last member's ownership index, retains the moved member's eligibility, clears the released member and leaves the loose peer at zero. Support loss permanently clears shell metadata even if the debris subsequently freezes.
- The standalone food material uses an explicit zero opt-in. A separate shared static-batch material reads instance data. This prevents a common material from spreading building eligibility to ordinary food.

The reviewer reported the freed-reference-before-typed-assignment risk. The parent added guards before casting and made binding idempotent before final acceptance. A late controller review additionally identified empty arch/donut volume as a bounds-only false positive. The parent added cached per-mesh triangle BVHs; the independent hollow fixtures above then verified the two-stage gate. `blocks_core` remains a broad-bounds debug query; final activation also requires `mesh_blocks_core`. No runtime files were changed by this reviewer.

## Renderer evidence and its boundary

An explicit headless storage probe established that this engine's dummy renderer does not retain native MultiMesh transforms/custom data: nonzero writes read back as an identity transform and `(0,0,0,1)`. An unset shader uniform also reads as null in this mode. The independent suite therefore does not treat those readbacks as proof of rendered opacity or successful GPU compaction. Food eligibility now has authoritative CPU state, which the scene suite checks alongside real membership/index transitions. Native custom-data migration and vacant-slot clearing were inspected in the implementation.

The separate windowless shader receipt at `artifacts/selective-reveal-20260928/shader-probe-final/result.json` matches current shader/harness hashes. The reviewer inspected its ten new same-position opt-in cases alongside the existing nineteen coverage and twelve albedo cases. The shipped vertex/fragment equations retain 100% of ordinary food, released food, default actor/debris and unselected-building pixels. Only selected structural cases retain 6.25% through the ordered cutout. Shadow cases remain solid. The batch case explicitly varies `INSTANCE_CUSTOM.r` while retaining the same shader and world position.

This separates controller selection and instance ownership evidence from shader-equation evidence. The narrow phase samples the center, a bounds witness and three rings; it confirms actual triangle obstruction when enabled, but is not an exhaustive per-pixel occlusion query and can miss a thin obstruction between samples. The tests do not reproduce Godot's full material upload, native GPU buffer transport, lighting, skeletal rendering, browser output or phone performance. Actual visual acceptance and iPhone GPU timing remain separate requirements. The reviewer did not modify deployment or player progress.

## Receipts

- Final strict source run with hollow geometry: `artifacts/selective-reveal-20260928/review/hollow-final.json` and associated logs. The earlier 217-check run is retained as the pre-narrow-phase checkpoint.
- Exact guarded inputs: `artifacts/selective-reveal-20260928/review/hollow-manifest.json`.
- Shader equations: `artifacts/selective-reveal-20260928/shader-probe-final/result.json`.
- Gate-ready script: `tests/selective_reveal_review.gd`; completion marker `SELECTIVE_REVEAL_REVIEW`; final count **225**.

Initial reviewer fixtures exposed dummy-renderer limitations and one invalid use of a freed object as a typed test-call argument. Those fixtures were corrected before the final run; their earlier logs are not claimed as implementation failures.
