# Independent six-skin polish review

Status: **PASS** on the frozen source cutoff below. Non-author suites passed 760 new presentation/geometry checks and all 1,555 rarity/probability checks. A separate actual old/new UI probe passed four checks. All 782 release inputs were identical before and after the final runs. No owned engine helper remains running.

## Defect found and corrected

The real collection card function created `own_world_3d` viewports with only a model and camera. Its environment was independent of the map and of the older hidden large preview. The new sculptures use lit `StandardMaterial3D`; these actual cards had no light or ambient environment. The prior author geometry suite checked camera bounds and material properties, but did not instantiate this real UI path.

The root author added one shadowless directional light per card and a shared ambient resource, with one `WorldEnvironment` node for each isolated world. Cache behavior, dimensions and active-card ownership remain intact. The retained old UI was instantiated against exactly the same current Pizza Party geometry: both versions had six cards and ten sculpted lit parts on that page; the old version had zero lights/environments, the revised version had six of each. This establishes the missing-light cause and its scene-level correction. It is not a rendered-pixel comparison.

Evidence: [actual old/new lighting probe](../../artifacts/skin-polish-20260930/review/lighting-baseline.json), [retained old UI](../../artifacts/skin-polish-20260930/review/ui-before-review.gd), [final independent receipt](../../artifacts/skin-polish-20260930/review/skin_polish_review-final.json).

## Geometry, mobile presentation and unchanged collection

A separate source-only probe constructed all 44 pre-polish forms from the retained old script. The signature includes every real mesh surface array, model-relative transform and visibility flag. Exactly the six requested IDs differ. All other 38 match exactly. These old signatures are embedded in the permanent review test; packaged QA does not need old source text or excluded artifacts.

The permanent suite exercises the actual game collection UI at 375x812 backing pixels and 1170x2532 pixels (the 390-point DPR3 profile). The raster sizes are 144x106 and 313x230; logical controls remain 144x106. Every visible vertex is projected through each real mounted camera at 48 evenly spaced angles over a full rotation. The minimum retained margin is 4.4048 logical pixels, on Bunny Burrow. All six retain the original generic ceiling of 18 mesh nodes and 4,500 triangles, even with the preview's black mouth included.

| Skin | Gameplay meshes / triangles | Actual card triangles including mouth | Minimum logical margin |
| --- | ---: | ---: | ---: |
| `pizza_party` | 12 / 3044 | 3812 | 20.5606 px |
| `frosted_cake` | 11 / 3132 | 3900 | 11.6501 px |
| `fox_den` | 12 / 2668 | 3436 | 4.7728 px |
| `bunny_burrow` | 12 / 2768 | 3536 | 4.4048 px |
| `rocket_port` | 12 / 2928 | 3696 | 5.1544 px |
| `dragon_roost` | 13 / 2880 | 3648 | 6.5695 px |

The actual mounted forms use at least eight opaque per-pixel sculpted parts, three or more ingredient/feature colors, curved normals, bounded roughness and the existing modest clearcoat. No particles or collisions were added. Natural SceneTree frames advance only the selected model. Leaving the collection immediately disables rendering and processing, then frees the card lights with their viewport owners. Currency, owned IDs and equipment remain unchanged. The headless test never unlocks audio or opens a player progress file.

The review also read the author's outward/closed-volume, unit-normal, nondegenerate-triangle and open-mouth checks. The offline comparison sheet was visually inspected: six rounded, distinct silhouettes replace the previous flat pieces. This is an assessment of the exported geometry under Blender's approximate lighting, not a claim about Godot/Web pixels.

## Precisely bounded historical fixture maintenance

`skin_rarity_review.gd` previously required every higher-tier form to match its exact old mesh/effect counts. The intentional six-form redesign conflicts with only that assertion for those IDs. The old `OLD_VISUAL` table remains unchanged. One explicit six-ID `POLISHED_VISUAL` table now supplies the measured fixed new counts, with the same 18-mesh/4,500-triangle generic ceiling. All other higher-tier equality checks and all lower-tier simplification checks remain.

The complete code from `fixture_catalog()` through all probability/pity assertions and reporting is byte-identical. Identity/skills/rarities, the other 38 geometry assertions, and all five-ten-twenty pity and disclosed draw mathematics are preserved. The suite still executes exactly 1,555 checks. See the [exact diff](../../artifacts/skin-polish-20260930/review/rarity-maintenance.diff), [before copy](../../artifacts/skin-polish-20260930/review/skin_rarity_review-before.gd) and [final receipt](../../artifacts/skin-polish-20260930/review/skin_rarity_review-final.json).

## Renderer evidence and limits

The temporary suggestion to remove clearcoat was withdrawn. The official [Godot 4.5 GLES3 Compatibility source](https://github.com/godotengine/godot/blob/4.5-stable/drivers/gles3/shaders/scene.glsl#L1323) contains the clearcoat specular calculation and passes its inputs through directional lighting. This is source-level support evidence; it does not establish identical source revision or exact rendered output for the bundled 4.7.2 binary. The original frozen material is retained. See the author's [source clarification](clearcoat-source-check.md).

Headless QA cannot certify antialiasing, exposure, actual highlight appearance, GPU frame time or iPhone quality. The Blender sheet is explicitly an offline lighting approximation. Browser capture and real device play were not attempted because the saved access restriction remains in force. Final source/PCK release acceptance and deployment are owned by the root task and are separate from this source review.

## Preserved non-product probe failures

The first new review script had a GDScript Variant type-inference parse error; its log is preserved, and the explicit local type correction changed no assertion. The first old-UI diagnostic selected the wrong default collection tab, yielding three cards without Pizza Party; its rejected report is preserved as `lighting-baseline-wrong-page.*`. The corrected diagnostic selects the Classic tab and resolves Pizza Party's actual page by ID. Its four original assertions remain. No runtime change was made to accommodate these test errors.

## Source cutoff

- `fidelity/skin_sculpt.gd`: `1450155da9582b85135d56b39415e0e0bac5a7ec131977d442abd44a10477f37`
- `fidelity/skin_visual.gd`: `f40045b57c687059fee80170ead7eb58a14122c4a6a67fd6780168b520f73f55`
- `fidelity/skin_catalog.gd`: `6b1d4434047703cb2a8ca1dcd5d781f6f2adf7d2568a81a08fe7f4b086d8dd33`
- `fidelity/skin_rarity.gd`: `dc532376060506100c2eb9fa22da7addb43cf696826c271cc54ec8a34a7fc3a7`
- `fidelity/skin_motifs.gd`: `0db569773783e174b088ecf716bf10592b448c432b7508a173af58665f7a637e`
- `fidelity/ui.gd`: `a712da36e7cce8e3124b5fe502e933d440c64baf34ec3b3e29a20a220e63762c`
- `tests/skin_rarity_review.gd`: `2d4caef9a73cf8968218b8d483cdbfb43fbb733548ea6e4c071ea731565e95c4`
- `tests/skin_polish_review.gd`: `e6c8b15864024a45483ccc4f7fb5ad428a8f86600f59cc1d0f1f014e57dc09d6`
- `tests/skin_polish_acceptance.gd`: `33e8e373417959391df5a1987cbd13378363ff0879ba511560552c90bbce55f0`

[Complete hash/evidence manifest](../../artifacts/skin-polish-20260930/review/provenance.json).
