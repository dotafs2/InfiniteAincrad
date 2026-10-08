# Actor falling, original-surface fracture and rig repair

This update addresses the user's four runtime findings after the two-map build.
It supersedes the earlier design in which residents and procedural decorations
were not edible. It does not change the independent resident-world project.

## Runtime changes

- All 64 city citizens and 32 food-map citizens can be swallowed. Route control
  owns a living, frozen body; swallowing or a skill pull releases it to gravity,
  restores ground collision and stops the route/animation code from writing its
  transform. Normal footprint eligibility and below-ground scoring still apply.
- All 100 authored recipe objects, 48 ambient robots/drones and five beacons in
  the city are now registered physical objects. Ground robots, fixed beacons and
  ground props are placed against the pavement; intentionally airborne drones
  retain their hover until released, then fall and score normally. This brings
  the city registry to 604 edible bodies before building fragments are created.
- Objects geometrically inside a building are bound to that building. Its intact
  shell protects them; fracture explicitly releases those actual objects, clears
  their support binding and stops their scripted hovering. They can then fall
  with the building instead of remaining suspended in empty space.
- Building fracture uses 768 pre-baked pieces from the 48 original buildings.
  Triangle clipping preserves the facade, windows, roof details and vertex colors.
  The original palette material is retained and made opaque on fracture. Only
  newly exposed internal cut faces use masonry color. The current catalog is
  vertex-colored; the bug was replacement with generic colored boxes, not a
  missing downloaded image texture. Cutting is done offline, not on a game frame.
- All 16 rigs now use animation curves reconstructed from their actual inverse
  bind matrices. Root/head rocking from generic role curves was removed; leg
  motion alternates, knee/arm swings are bounded, and curves close at the loop.
  Moving people use Walk/Run with rate scaled to displacement. Stationary people
  use role gestures or Idle. All role identities, original meshes and accessories
  remain, but the old animation curves are intentionally replaced. Held props
  follow their forearm instead of separating from the hand during elbow motion.
- Released traffic also relinquishes lane control, including a skill pull before
  the car is claimed by a hole; it cannot snap back onto the road while falling.

## Reproducible asset pipeline

After regenerating the base Blender catalog, run the geometry and animation
postprocessors, import the models, then bake the building surfaces:

```sh
python3 tools/refine_mobile_people.py
python3 tools/repair_people_animation.py
python3 tools/repair_people_accessories.py
Godot --headless --path . --editor --import
Godot --headless --path . --script tools/bake_building_fragments.gd -- --test --bake-fractures
```

All three character postprocessors are idempotent on their own marked output. Runtime
fragment caches live under `assets/fractures/` and must be exported with the game.
The fracture baker uses the same imported buildings and facade dressing as play.

## Verification

Final validation completed on 2026-09-28: 14 acceptance suites, 1,238 assertions
and both food-map round fixtures pass across the full attempt and targeted
verification. `artifacts/actor-fixes/final-validation.json` is the authoritative
summary. The final exported PCK also passes 32 actor/traffic checks and 992
rig/fracture checks. Those exported checks repeat part of the 1,238 total.

The dedicated actor suite exercises citizens, hover drones, ground robots,
authored props, beacons and building contents through actual gravity and scoring.
It also verifies a pulled citizen collides with intact ground and that ground
robots no longer start suspended.

The rig/fracture suite covers all 48 buildings and all 16 characters. It checks
16 real exterior pieces per building, multiple original facade colors, conserved
exterior triangle area, bounded skinned vertex positions over 576 clip poses,
upright pelvis motion, loop continuity and alternating legs. These assertions
validate geometry and motion data; they do not replace visual judgment.

Full results are in `artifacts/actor-fixes/`. Run all regression suites with:

```sh
python3 tools/validate_mobile.py --godot /path/to/Godot
```

The final full attempt passed its first 11 suites, then hit the former
240-second wall-clock limit during the two food-map rounds. That interruption
is retained in `validation-timeout.json`. The runner now preserves completed
results incrementally, records watchdog failures and supports a targeted retry
with a 600-second watchdog. The simulation still uses the shipped 60 Hz step;
the longer watchdog is not a performance pass. The targeted retry passed:
426 points in the contested round and 488 points in the isolated reachability
round, both with phase `complete`.

```sh
python3 tools/validate_mobile.py --godot /path/to/Godot --suite food_round --timeout 600
```

The local Web package is served at `http://127.0.0.1:8768/`. Reload the page to
load the new PCK; an already running browser instance keeps its old in-memory
scene until reload. Exported-pack tests load the actual PCK into the headless
runtime to catch missing scripts, rig resources and fracture meshes.

The user explicitly authorized browser playtesting in this turn. The browser
listed the live tab, but refused its reload because a saved denial still blocks
this origin. No alternate browser surface or workaround was used. Visual review
therefore remains pending removal of that saved block. The current evidence
covers code, physical simulation and mesh/rig validation. Physical iPhone 14
profiling and sustained 60 FPS acceptance remain open.
