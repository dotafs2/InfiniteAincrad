# Food finish QA — v0.5.2

`release.json` and `source-*.json` / `package-*.json` describe the delivered
build and guarded checks. `offscreen-check.json` records the independent
highlight probe and its exact scope. `opening.png` shows the revised layout
geometry and finish. `ingredients.png` isolates six actual cached food meshes;
`ingredients-no-glaze.ppm` is the same camera/material with studio reflection
strength set to zero. These are windowless CGL renders, not Godot screenshots.

Reproduce the preview inputs and shader check from the standalone project:

```sh
.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/export_food_render_fixture.gd --fixed-fps 60 -- --test --output=res://artifacts/food-finish
python3 tools/prepare_food_shader.py --output artifacts/food-finish
xcrun clang tools/food_scene_offscreen.m -framework Foundation -framework OpenGL -o /tmp/hole-food-finish-render -Wno-deprecated-declarations -Wno-incompatible-pointer-types
/tmp/hole-food-finish-render artifacts/food-finish opening ingredients ingredients-no-glaze
sips -s format png artifacts/food-finish/opening.ppm --out artifacts/food-finish/opening.png
sips -s format png artifacts/food-finish/ingredients.ppm --out artifacts/food-finish/ingredients.png
```

The exported collapse JSON frames retain actual physics poses. Only the opening
and six-food material swatch were rendered for this pass. Scene lighting is
approximated; full renderer, browser and physical-phone acceptance remain open.
