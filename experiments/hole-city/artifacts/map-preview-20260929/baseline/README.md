# Preserved v0.8.3 home-preview baseline

Independent read-only reproduction on 2026-09-29. An external headless script loaded the absolute preserved `build/web/index.pck` with the engine working directory `/private/tmp`, an absolute engine log path, and `--test`. It used normal `select_map()` home-menu transitions and observed 30 natural frame checkpoints per map. No `_process()` method was called manually. The expected inactive food preview is recorded as a baseline finding, not reported as an engine error.

| Observed old-package state | Sunny City | Snack Garden |
|---|---:|---:|
| Menu / phase | home / title | home / title |
| Preview model script | `fidelity/art.gd` | `fidelity/food_city.gd` |
| Model `is_processing()` before and after | true | false |
| Valid `preview` node | yes | no; property exists but is null |
| Valid `pivot` node | no property | no property |
| Actual preview Y-angle change | +0.0483333208 radians | no preview node |
| Root Y-angle change | 0 | 0 |
| MeshInstance3D nodes | 64 | 26 |
| MultiMeshInstance3D nodes | 0 | 0 |
| RigidBody3D nodes | 0 | 25 |
| CollisionShape3D nodes | 0 | 25 |

The measured city increment is reported directly, rather than inferred from a nominal 30/60-second interval. The observations establish that Sunny City's child preview turns while the old food preview does not run processing and has no animated preview/pivot node. They do not establish visual composition or appearance: there was no rendering, screenshot, browser access, foreground interaction, performance timing, or normal save modification.

The preserved package remained unchanged, SHA-256 `8d7146294219af06ad467873181533d52ccb2e4ee3031588a60071f4550ad847`, and independently reported version `0.8.3`. The engine exited zero; the strict release diagnostic checker reported zero unexpected errors. Its existing macOS certificate warning exception was the only allowed diagnostic. All owned processes exited.

- Full observations and before/after package hashes: `baseline.json`.
- Engine stdout and engine log: `baseline.log`, `baseline.engine.log`.
- External helper: `map_preview_baseline.gd`, SHA-256 `ab3d18cb08bcdb220a0fe4df65a280b7b42e8eef1a8cb624ec8e20cad8e68a6b`.

## Read-only test boundary recommendation

In the revised source, `tests/mobile_maps_acceptance.gd` correctly uses `hero_models is FoodPreview` for selecting Snack Garden on the home screen. Retain the separate `FoodMap` preload: the real playable food scene and its `Neighborhoods.lane_sample()` traffic assertions must still refer to `food_city.gd`. A corresponding explicit `game.city is FoodMap` assertion immediately after starting the food level would guard against accidentally substituting the lightweight miniature for gameplay. The existing real-map population, lane, independent physical fall, order, and restart assertions should remain unchanged. This review did not edit that test or any runtime file.
