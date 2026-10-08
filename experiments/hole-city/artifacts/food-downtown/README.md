# Dense food-city QA — v0.5.1

- `release.json`: exact delivered Web build and source hashes; source/PCK totals.
- `source-*.json` and `package-*.json`: guarded physical and functional acceptance.
- `regressions.json`: portrait, no-tether, traffic/people, food rain and density tests.
- `opening-cpu.json`, `grown-cpu.json`: headless CPU samples; not phone/GPU results.
- `opening.png`, `districts.png`: isolated food-mesh layout previews.
- `collapse-before.png`, `collapse-04.png`, `collapse-10.png`, `collapse-22.png`:
  the same camera observing exported physical poses at 0, 0.4, 1.0 and 2.2 seconds.
- `render-meshes.json`, named frame JSON and `offscreen-render.log`: render inputs
  and actual helper output. These are not Godot/browser screenshots. Lighting
  is approximated, and NPCs, UI, shadows and player skin decoration are omitted.
- `render-evidence.json`: source, helper and preview hashes with rendering limits.
- `initial-snack-diagnostic.json`, `pre-index-cascade.json`,
  `preliminary-rounds.json`, `preliminary-layout.json`: intermediate diagnostic
  evidence, superseded by the final source/package acceptance reports.

Reproduce the isolated image check on macOS:

```sh
.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/export_food_render_fixture.gd --fixed-fps 60 -- --test
xcrun clang tools/food_scene_offscreen.m -framework Foundation -framework OpenGL -o /tmp/hole-food-scene-render -Wno-deprecated-declarations -Wno-incompatible-pointer-types
/tmp/hole-food-scene-render artifacts/food-downtown opening districts collapse-before collapse-04 collapse-10 collapse-22
```

The helper subdivides the preview's long planar ground triangles for the offline
OpenGL rasterizer. It does not modify any running-game geometry or access a
browser. See `docs/food-downtown-20260928.md` for the full validation scope.
