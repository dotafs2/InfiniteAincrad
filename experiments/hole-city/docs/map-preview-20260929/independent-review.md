# Independent map preview review

Status: **PASS — 716 checks on the final frozen source**, with strict engine diagnostics and unchanged before/after source hashes. The reviewer changed only its new test and report artifacts, not runtime implementation.

## Findings and implementation review

The previous food miniature created a full `FoodCity` object, built two towers plus a few props, and explicitly disabled processing. UI refresh only enabled the city model. The new `FoodPreview` has a dedicated rotating `preview` pivot, three composition layers and visual-only mesh instances. Its short-lived food mesh builder is attached synchronously, disabled, used only for `mesh_for()`, then freed before return; it never builds gameplay, rain, foods or collision bodies. Actual game recipe meshes and the existing ingredient-gloss shader are reused. Food visuals share one opaque material with both reveal options disabled.

The UI now applies one visibility/process/render-target policy to both maps. Replacement stops the old model before detaching and deferred deletion. Initial miniature creation runs after environment, light, camera and texture creation, so a cold food selection receives its intended ambient energy immediately. The existing portrait texture bounds, viewport size and AA configuration remain intact.

The root author test was read independently: it waits for real `SceneTree.process_frame` signals and compares measured turn with the advancing UI clock; it does not call the miniature's process function manually. The updated mobile-map test explicitly distinguishes a lightweight menu `FoodPreview` from full physical `FoodCity` gameplay. Its traffic, pedestrian, independent physical fall, objective, restart and ground-opening checks remain present. This review does not claim a separate execution of those full mobile-map checks; the release gate handles them.

The author's natural-frame run also exposed an existing freed-player argument after returning home. The root corrected the inactive `update_reveal()` path, and another reviewer covered that change. This test keeps the real `game._process` enabled through both maps and home returns, so the stale-reference path is not masked by disabling the main process loop.

## Independent execution

`tests/map_preview_review.gd` passed **716 assertions** under `--headless --fixed-fps 60 --test`, using the current strict `release_web.acceptance()` runner. Marker: `MAP_PREVIEW_REVIEW`; minimum: `716`.

- Both actual miniatures advance approximately **0.020 radians over 12 natural process frames**. Collection, store, intro, gameplay, pause and each result state disable rendering and processing; observed angles remain unchanged. Returning home resumes rotation. Replacing a map while the store is open also leaves it dormant.
- Twenty alternating map changes immediately detach the old model, free it after deferred cleanup, retain one live miniature, and return to the same per-map UI node count.
- Cold food start and preview navigation create no gameplay world or holes. Economy, skin ownership, round counters, food receipts and dirty-save state remain unchanged. `--test` exposes no player save path.
- Every preview descendant is checked for physical bodies, areas, collision shapes, collection completion methods and rain methods. No temporary food builder remains. During actual entry/pause/results/home UI routing, the gameplay world is deliberately frozen to isolate UI lifecycle; the main game process remains active.
- Every actual mesh AABB corner is projected through the real miniature camera at **72 yaw angles spanning a full turn**, with a required 2.5% margin on each axis. No point is behind the camera or outside that safe rectangle.

| Map | Mesh instances | Projected AABB corners | Minimum viewport-edge distance |
| --- | ---: | ---: | ---: |
| Sunny City | 64 | 36,864 | 43.94 px |
| Snack Garden | 87 | 50,112 | 44.76 px |

Food composition is checked against actual transformed geometry as well as metadata: **68 food instances, all 10 recipes, 14 clusters, 6 staggered multi-tier stacks, 54 tilted pieces, 20 shared food meshes and one shared food material**. The remaining 19 meshes form the base and streets.

| Layer | Food instances | Highest actual bound | Mean depth |
| --- | ---: | ---: | ---: |
| Foreground | 34 | 1.345 | 2.801 |
| Midground | 14 | 4.085 | -0.253 |
| Background | 20 | 7.863 | -3.042 |

These measurements establish separated depths, descending rooflines and several laterally offset stacks. They do not establish aesthetic preference or rendered visual parity with a reference game.

## Provenance and limits

Final receipts, isolated logs, exact command, engine SHA and before/after hashes are retained in [`artifacts/map-preview-20260929/independent`](../../artifacts/map-preview-20260929/independent/): `final-source.json`, `final-source.log`, `final-source.engine.log`, and `final-provenance.json`. The passing first run is also retained; the author subsequently restored the biscuit filling's intended thickness, and the reviewer reran the complete suite against the final file.

| Reviewed file | Final SHA-256 |
| --- | --- |
| `fidelity/food_preview.gd` | `ffeb9e939e03de4b0aaeb1ea11a7f2a3fc645c4b6bc66fa022b14bad7f69df9b` |
| `fidelity/ui.gd` | `f2cee1d72640d5cdadd596e23c7efb0920cb829292ed3119a03d2832e551ad8f` |
| `fidelity/game.gd` | `a62c354d94b4dd0d27a5b590c4a7d2fd649d22e6814df2603cfab6245446c9ef` |
| `tests/map_preview_review.gd` | `1426053dcfaf35fae23b9f8fc5038c9fe750ef98e3403d318209d3a6f3d6a5b9` |

No browser was opened and no alternative capture path was used under the existing saved permission restriction. Headless geometry and lifecycle checks do not render final pixels, measure GPU work, certify iPhone frame rate or prove contact shadows/highlights look correct. All reviewer-owned Godot helpers exited and were waited on. No user server, player save or gameplay recipe was changed by the review.
