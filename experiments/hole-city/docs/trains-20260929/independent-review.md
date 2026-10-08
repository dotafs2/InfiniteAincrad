# Independent train integration review

Status: **PASS — 388 strict train checks plus the unchanged 58-check rival combat suite** against frozen runtime, assets and
tests. `tests/train_review.gd` emits `TRAIN_REVIEW`. Every release input hash was
identical before and after the final run. All owned engine helpers exited.
The review changed only its test, artifact probes and documentation. Runtime
fixes were made by their respective authors.

## Defects found and retested

The first independent actual-game run found two defects rather than accepting
the initial author result:

1. All 12 live cars had valid imported `COLOR_0` buffers but their active
   materials did not enable vertex color as albedo. This would lose the authored
   ingredient palette. The loader now explicitly enables the flag on cached
   material copies. The final test checks the live material flag, the exact
   original color buffer, and unchanged imported albedo factor, roughness and
   metallic properties. Material copies are reused after a home/restart cycle.
2. A city train cut near the first corner after a complete lap failed to plan
   its future bypass while the admitted middle car was still a temporary real
   obstacle. The initial failed plan was never retried. On its next circuit,
   the head stopped against parked car 3 at `(80.62414, -84.38531)`; the blocker
   was a real physics query hit, not a stale-frame fixture. The diagnostic
   recorded an empty detour list and `planning_count = 1`. The controller now
   retries unresolved future plans every 0.5 gameplay seconds. It continues
   checking real colliders; it does not move the parked tail or disable its
   collision. The exact original failing circuit/cut scenario now completes
   its return with zero blocked steps.

The full release gate subsequently found a third lifecycle defect in the
unchanged rival-combat regression. That test frees and replaces the city while
the actual game loop continues. A retained controller then tried to write a
freed coupler's visibility. The controller now checks that its original city
is both valid and still the game's current city before automatic `step` or
pose updates. Explicit detachment can still clean up its internal chain, but
checks every body and coupler before access. Typed body assignments occur only
after validity is established.

The final independent suite adds 11 assertions per map: a separately freed
coupler with valid owner; replacement while the old city remains alive; actual
old-city destruction while the game retains its freed reference; explicit
cleanup; and continued real game ticks. Replacement actors, player score and
coin wallet remain unchanged by stale train calls. All 52 static assertion
statements from the earlier 366-check suite remain verbatim. The unmodified
58-check rival-combat suite also passed strict execution. Its real 30/60/120 Hz
AI pursuit was not replaced by a synthetic fixture or disabled game process.

A prior read-only geometry review also identified that length-only coupling
spacing could overlap neighboring rail cars on a tight inward curve. The
controller author added width-aware spacing. The independent actual-map
oriented-box checks subsequently found zero same-train overlaps across full
loops and bypass returns.

All 45 original static assertion statements from the failed independent test
remain. New checks strengthen actual imported geometry, material preservation,
small-mouth rejection, restart material reuse and a second scenario cutting
a train after two complete laps. No failure condition was deleted or weakened.

## Actual scene and physical coverage

The test builds the real `main.tscn` game separately for each map, using its
normal train integration and imported models. Intro, natural playing physics,
tree pause and resume are exercised before controlled loop observations.
During the loop observations, train `step(delta)` receives a bounded 0.15 s
interval and every step is followed by a real physics frame. This accelerates
the control timeline for functional coverage; it is not a frame-time benchmark.
During admitted car falls, the head continues stepping at 1/60 s while real
physics settles the car.

| Actual map | Cars / distinct assets | Car mesh triangles | Car mesh surfaces | Maximum car mesh triangles |
| --- | ---: | ---: | ---: | ---: |
| Sunny Blocks | 4 / 2 | 3,672 | 4 | 956 |
| Snack Garden | 8 / 8 | 8,084 | 8 | 1,228 |

These are actual imported mesh buffer counts. Couplers are separate small
shared box visuals (at most 3 and 7 respectively), not extra edible bodies or
collision support. These counts are a geometry/submission bound, not measured
GPU draw timing or a phone 60 FPS claim.

Each car has its own rigid body, its own collision shape, a single edible
inventory entry and a size gate matching that car's actual model bounds. The
suite checks finite vertex/color/normal/index buffers, nondegenerate clockwise
triangles, matching shading normals, varied opaque ingredient colors and
per-car geometry limits. It rejects accidental whole-train collision bounds.

The physical sequences cover:

- Starting-size rejection without any detachment.
- Ordinary earned growth and normal `game.scan_food()` admission.
- A full circuit followed by a middle-car cut, then more than one return lap.
- A separate restart, two complete circuits, another middle cut and a return.
- Exact downstream world transforms remaining stationary throughout returns.
- Continuous upstream motion with no reattachment, duplicate body, respawned
  eaten middle car, or oriented car collider overlap.
- Swallowing the surviving head, which stops the remaining chain.
- Collecting every original car independently through real gravity and the
  existing opened terrain, with exactly one player receipt per body.
- Return home and restart creating one fresh train without old bodies or a
  growing palette-material cache; no direct persistent coin-wallet change.

Both maps completed every full-loop and cut-return scenario with **zero**
blocked steps, car-collider overlaps and parked-tail pose changes in the final
run. All four city receipts were emitted with car tops at approximately
−3.66717 m. The eight sushi receipt tops ranged from −3.68765 to −3.50385 m,
strictly below the existing −3.5 m complete-descent threshold. Each receipt
awarded exactly that car's configured ordinary points.

## Route, rail and visual assessment

The independent [route feasibility report](route-review.md) retains actual
scene collision, road-footprint and pedestrian-corridor evidence for the two
outer loops. Existing traffic is preserved. Its rejected city radius-6 corner
candidate is retained instead of being relabeled as successful.

Read-only review confirms that final tracks are painted into the existing cut
ground with a mipmapped R8 mask. They introduce no new collision floor over a
hole. The ground-mask, branch signal, lifecycle and HUD route hint have an
additional non-author 1,121-check review by the asset agent; that separate
review is not counted as part of these 388 checks.

The reviewer inspected `art_source/trains/contact-sheet.png`: gunkan, salmon,
tuna, shrimp, eel, tamago, roe and mackerel are visually distinguishable, with
rounded food masses, colored toppings and separate rail cab/car designs. This
is the author's Blender Cycles contact sheet, not a screenshot of the running
Web game. The final Godot material/buffer checks establish the runtime palette
configuration; actual browser appearance remains unverified under the saved
browser access restriction.

## Evidence and exact source binding

Evidence root: `artifacts/trains-20260929/review/`.

- `preliminary.{json,log}` and hash-verified `train_review-preliminary.gd` retain
  the original material and return-path failures.
- `city-return-diagnostic.{gd,json,log}` and `city-block.json` retain the actual
  first blocking collider, parked pose and missing plan.
- `assertion-preservation.json` lists all 45 retained original assertion lines
  and the added checks.
- `registration-change/` retains a 366-check functional pass that was rejected
  by the outer input guard because the parent edited the release registry
  during that run. It was not certified as final stable acceptance.
- `final.{json,log}`, `final-inputs-before.json`, `final-inputs-after.json` and
  `provenance.json` record the earlier strict 366-check pass. This is the
  pre-lifecycle-fix cutoff, not the final controller hash.
- `../release-rejected-city-lifecycle/source-rival_combat.log` preserves the
  full-gate lifecycle error.
- `../lifecycle-review/train_review-before.gd` and `assertion-preservation.json`
  preserve the 366-check test and all 52 unchanged static assertion statements.
- `../lifecycle-review/{train_review,rival_combat}.{json,log}` and
  `provenance.json` record the final strict **388 + 58** pass. This final run
  binds controller hash `28867582…`, all current runtime/assets/tests/registry,
  and identical complete input hashes before and after execution. Subsequent
  parent release work is beyond this review's recorded cutoff.

Key frozen SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `tests/train_review.gd` | `fb8e8b03e2824d9bba500f0d6e2b62114b1086503ab72f24bf13294c95180779` |
| `fidelity/edible_train.gd` | `2886758208c9eb7fb5e0d89d448c561bd404f182f4c8e516d0ef706a7a014d3f` |
| `tests/rival_combat_acceptance.gd` | `2335724850ab9a6b267c3ba9121045082bfedd4b73732bb7d4ec673c069a0b1c` |
| `fidelity/train_car.gd` | `28a0de04cb3222c1c9e15df60ab8313defc8bbbe2572ad82115120282155ce86` |
| `fidelity/train_assets.gd` | `1d95b9acece92c32ec9e75c43e3db617d8a0bb4a525fc640204d503eb43159da` |
| `fidelity/train_routes.gd` | `d65e6bce78c0fa4b0b81eb7bfe810412c1a56bff7af04343f331dd9d5e0129d8` |
| `assets/trains/manifest.json` | `6735dc304eca5ec1cd1c2e18f0cd99e82dcd6e38a8994aa7b44f50a5a0516f7b` |

The complete manifest additionally binds game/UI/ground-shader integration,
track painting, import recipes, all exported model files and the release
registry. Parent-owned package acceptance and deployment remain separate;
this source review does not claim that an export has already been delivered.
