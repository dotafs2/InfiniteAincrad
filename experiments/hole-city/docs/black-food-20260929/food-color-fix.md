# Food batch color correction

Author status: implemented and frozen. The [non-author review](independent-review.md) passes 1,109 scene checks, 258 independent GPU checks and the independently rerun 1,120-check source trace. The isolated release is coordinated separately by the root agent. This report does not claim that a browser tab was inspected or that the new build was delivered.

## Reproduced cause

The user's report of black Snack Garden food is consistent with a specific instance-attribute initialization defect. In the preserved v0.8.6 package and pre-fix source, all 527 initial food batches enable `MultiMesh.use_custom_data` while leaving `use_colors` false. The 34 generated mesh recipes themselves retain nonblack ingredient colors on all 47,027 color-bearing vertices. Their original glaze shader is present and identical in source and package. The failure is therefore downstream of the authored material/mesh data.

The bundled native engine reports Godot 4.7.2 revision `ed1daf0bf`. Its matching official Compatibility implementation reserves both packed RGBA color and custom-data lanes whenever either is enabled. Individual setter access initializes the native data cache to zero. The vertex shader always multiplies vertex RGBA by the instance RGBA under instancing. With custom data enabled but no color values written, this multiplies the food RGB to zero and also overwrites its roughness-bearing alpha. The shader's reflection emission can remain, explaining a dark surface with residual highlights rather than missing geometry.

Primary source, copied with hashes in the evidence directory:

- [Compatibility allocation and buffer initialization](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/storage/mesh_storage.cpp#L1590), including `_multimesh_make_local` near line 1676 and attribute setup near line 2300.
- [Instanced vertex color multiplication](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/gles3/shaders/scene.glsl#L651).

The same flags also affected settled-rain batches. The home miniature uses ordinary MeshInstance3D objects, so this particular defect does not establish that the miniature itself was black. No unavailable browser observation is inferred.

## Minimal implementation

Only `fidelity/food_city.gd` changes. Static food and settled-rain MultiMeshes explicitly enable colors before allocation, and each allocated slot receives `Color.WHITE` (including alpha one). Rain initialization, both capacity-growth paths, and reused slots receive the same identity multiplier. Custom data remains zero. Existing compaction retains identity color because every retained and unused slot already has the same white value.

The original shader, food miniature, merged vertices/normals/colors, shapes, collisions, individual fall rules and material ownership remain unchanged. No old finish/geometry baseline pin was relaxed. This fix adds no batch, draw call or geometry. In the matched Compatibility backend, the already-enabled custom channel reserved both lanes: the packed native stride remains 16 floats / 64 bytes per 3D instance with or without `use_colors`. Initialization adds bounded white writes during construction, growth and reuse; it does not add per-frame city scans.

## Evidence

All paths below are relative to `artifacts/black-food-20260929/`.

- `before/package/index.pck`: preserved v0.8.6 package, SHA-256 `27913ff7c5e0455c163090dfbffcecd2a36a83ce2106be599f27a27724b40fab`.
- `before/source-scene.json` and `before/package-scene.json`: actual source and isolated-package inventories. Both have 527 custom-only batches and matching original food data. The package probe ran from its isolated directory, with the source-only release tool absent.
- `after-scene.json`: zero custom-only batches; all original generated mesh arrays and glaze shader match the before inventory.
- `author-gate-source.json`: 55 strict checks for actual batch flags, authored color data, unchanged shader, rain 16→32→64 growth, independent release and compacted-slot reuse. This permanent suite does not require exported GDScript source text or trust dummy-renderer color getters.
- `source_color_write_trace.gd` and `author-final.json`: 1,120 additional source-only checks. A copy of the actual production script wraps only native color-setter calls, recording each supplied batch ID, allocation size, slot and RGBA, then calls the original native setter. All 527 initial batches and both rain reallocations initialize every allocated slot to full white. There are 2,678 observed writes. This instrumentation preserves the exact generated geometry and batch count. It is explicitly supplemental source evidence because exported scripts do not retain source code.
- `packed_color_probe.py` and `gl-packed/result.json`: 96 real windowless CGL cases / 128 assertions using actual integer vertex attribute location 15, packed half-float RGBA and the current food shader equations. All 32 actual ingredient colors produce zero albedo with the old zero lane. Identity white yields exactly the same RGBA8 albedo/roughness as the non-instanced mesh. A local IEEE half decoder substitutes the unpack intrinsic unavailable in the desktop GLSL 1.50 harness. This is a controlled GPU pipeline reproducer, not a Godot scene or browser screenshot.
- `final-provenance.json`: runtime, permanent test, source trace, GPU probe, old package and upstream-source digests. Runtime SHA-256 is `4a98288a9d9698829c41010b50f66de87b1d6aeafea2f7b58a48fdcf66f54fd4`; permanent test SHA-256 is `cb63e24b7d3b1a493e84129c12ec929a37476d59af2da9dd6db86cce07a5bfe5`.

## Preserved unsuccessful probes

`spy_probe.gd` demonstrates that a typed native MultiMesh setter bypasses a GDScript method with the same name; it was rejected as an observation mechanism. No fake CPU color state was added to runtime.

The first source test had a script-resource access parse error, retained in `author-first.*`. The next fixture used visual exposure alone while leaving a rain body settled, so it correctly rebatched that body on the next pass. The final fixture invokes the real `start_fall` transition and preserves the original reuse assertions; the earlier source and receipt remain in `author-before-release-fixture.gd` and `author-second.*`.

The first GPU run's arbitrary brightness floor wrongly rejected the intentionally dark seaweed ingredient. Its complete receipt and script are retained in `gl-packed/first-threshold-failure/`. The final oracle requires exact original-shader RGB (within one 8-bit quantization step), nonzero color, equality to the standalone mesh, and unchanged roughness. No palette or shader was brightened merely to pass.

## Limits

The saved browser restriction remains respected. Headless scene state plus actual isolated GPU attributes establish the material failure mechanism and targeted correction, but do not certify current browser pixels, aesthetic quality or phone frame rate. The food shader's existing unconditional color-space conversion is a separate potential darkening issue; it was deliberately left unchanged in this black-batch hotfix. Independent review, source/PCK release acceptance and HTTP delivery must be reported from their own completed receipts.
