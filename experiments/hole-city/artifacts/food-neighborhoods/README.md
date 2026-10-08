# Neighborhood layout QA — v0.5.3

- `release.json`, `source-*.json`, `package-*.json`: delivered source/build hashes
  and physics, layout, materials, navigation and both-map movement acceptance.
- `opening.png`, `districts.png`: windowless previews of actual food geometry
  and the same street atlas used by the game. These are not Godot screenshots.
- `streets.ppm`: the atlas generator's lossless RGB input for the offline probe;
  the runtime loads `assets/food_city/streets.png` made from the same pixels.
- `render-meshes.json`, frame JSON and GLSL: exported real scene geometry and
  the shipped reflection equations, with approximate final scene lighting.
- `opening-cpu.json`, `grown-cpu.json`: isolated headless CPU traces;
  they do not measure phone GPU work or sustained thermal performance.
- `render-evidence.json`, `generator-check.json`: current preview hashes and
  deterministic plan/atlas regeneration evidence.
- `initial-mobile-fixture*`: the earlier failed fixture and diagnosis, superseded
  by the successful final source/package movement reports.

Reproduce the plan, then import its new image before testing:

```sh
python3 tools/build_food_neighborhoods.py
.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import --quit
python3 tools/release_web.py --godot .build/godot-standard/Godot.app/Contents/MacOS/Godot --evidence artifacts/food-neighborhoods
```

Use `tools/export_food_render_fixture.gd -- --test --output=res://artifacts/food-neighborhoods`
and `tools/prepare_food_shader.py --output artifacts/food-neighborhoods` to prepare
the windowless renderer. See the previous food-finish artifact README for its
compile command; pass `opening districts` as the two frame names.
