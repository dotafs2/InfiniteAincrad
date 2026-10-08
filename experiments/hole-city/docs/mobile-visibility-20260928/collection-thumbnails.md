# Visible collection thumbnail quality

Date: 2026-09-28. Author: skin-catalog/UI subagent. Independent review requested after the files were frozen.

The actual visible collection targets previously rendered at 144×106 with default disabled antialiasing. They now use 2× MSAA and increase their backing dimensions with the UI’s displayed pixel density, up to 432×318. The parent scene’s 4× MSAA is unchanged. This targets the active card grid, rather than the hidden large preview.

`skin_card_render_size()` combines the root viewport’s stretch transform and the UI canvas transform. The stretch transform already contains the backing-size/content-scale mapping; no separate browser DPR multiplier is applied. Density is clamped to 1–3, with per-axis rounding up. The minimum retains the original image quality on narrow displays; the upper cap bounds six-card allocation. Pixel rounding can change aspect by a fraction of a percent.

The `TextureRect` keeps its 144×106 logical size and position, ignores the texture’s minimum size, uses linear filtering and ignores pointer input. Higher-resolution raster targets therefore cannot grow into card names, lock captions or neighboring controls. Camera framing and skin geometry are unchanged.

During the collection screen, a constant-size transform check reuses the existing models/targets. Only an actual backing-size change schedules a new frame for cached cards. A stable size never wakes an inactive target or restarts its animation. Exactly one focused card animates and renders continuously. On exit or page rebuild, old targets and model processing stop immediately before deferred deletion. Only the six visible cards exist after the deferred frees finish. The existing home miniature remains 640×560 with 2× MSAA; it already uses aspect-preserving display and is disabled away from Home.

## Author evidence

Strict engine-error checks passed:

- `tests/mobile_thumbnail_acceptance.gd`: 695 checks covering target AA, layout minimum-size isolation, exact IDs, seven backing-size profiles, window content scaling, CanvasLayer scaling, cache lifetime, resize reuse, all 44 forms, repeated page/menu retirement, economy stability and round-entry cleanup.
- Existing `tests/ui_redesign_acceptance.gd`: 1,641 checks, including actual pointer routing, complete geometry framing and repeated navigation.
- Existing independent `tests/review_ui_collection.gd`: 156 checks, including screen touch, page boundaries, focus and progression persistence.

| Synthetic backing configuration | Rendered card target |
| --- | --- |
| 540×960 design window | 144×106 |
| 270×480 narrow window | 144×106 |
| 375×812, representing 375-point DPR1 | 144×106 |
| 750×1624, representing 375-point DPR2 | 200×148 |
| 1170×2532, representing 390-point DPR3 | 313×230 |
| 4320×7680 oversized window | 432×318 cap |
| 1200×600 letterboxed window | 144×106 |

Evidence and frozen hashes: `artifacts/mobile-visibility-20260928/thumbnails/`. The new suite requires `--test`, uses no progress file by default, emits its report to stdout, and accepts only an explicit absolute filesystem report destination. The headless dummy renderer does not consume `UPDATE_ONCE`; the cache test explicitly models that completed-render state before checking that stable frames leave it dormant.

These checks establish settings, backing-size math, input/layout and lifecycle. They do not establish actual GPU edge quality, browser DPR reporting on a physical iPhone, graphics memory totals or sustained 60 fps. A real device image and timing pass remains required. No main-game logic, material, skin definition, project setting, deployment or player data was changed.
