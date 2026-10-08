# Offline skin showcase assets

These are explicitly labeled **offline asset previews**, not game screenshots, gameplay recordings or device performance measurements.

- `<skin_id>.png`: 44 current forms as 540 × 540 straight-alpha RGBA PNGs. Preserve aspect ratio when compositing.
- `catalog.json`: exact current IDs, names, collection groups, colors, geometry counts, bounds and image hashes.
- `contact-sheet.png`: labeled overview, 1320 × 2170.
- `animation/frame-000.png` through `frame-047.png`: 960 × 410 labeled strip showing current blue accretion, water and flame shader equations at 24 fps for two seconds. Shader time changes; mesh poses remain at 0.5 seconds.
- `manifest.json`: source hashes, exported fixture hash and rendering scope. `animation/manifest.json` records the sequence hashes.

Only this artifact directory was changed. The headless export is guarded by `--test`, instantiates visual models without the game scene, and uses an explicit absolute engine log path. No gameplay or player progress was loaded. Helpers use an offscreen CGL context and never create a desktop window.

Rebuild by running the supplied `export_current_skins.gd` with headless Godot and `--test`, preparing GLSL with `prepare_shaders.py`, compiling `render_skins.m` using Foundation/OpenGL, rendering at time 0.5, and running `finish_previews.py` with Pillow/NumPy available. The optional motion helper uses the three-record fixture in `animation/`, followed by `finish_animation.py`. Temporary raw RGBA outputs are intentionally removed after successful encoding; rebuild the CGL step before re-running conversion.

The original runtime is unshaded for these models. This renderer does not invent material highlights or engine lighting. Shader equations and actual exported mesh geometry are retained, but Godot tone mapping, billboarding and compositor behavior are not reproduced. This limit is visible in the delivered video assets.
