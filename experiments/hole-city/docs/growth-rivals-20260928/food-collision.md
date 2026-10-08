# Food collision correction — 2026-09-28

Status: **PASS**. The author suite passes **96 checks** with strict engine
diagnostics, and the [non-author review](../fixes/reviews/food-collision.md)
passes **16,168 checks** against stable final inputs. The final CPU sampling and
source/exported-package gate remain separate release requirements.

## Reproduced failure and scope

The final Food opening CPU trace emitted the native Godot diagnostic
`num_points >= max_clip` twice from `_generate_contacts_edge_circle`. The strict
profiler correctly refused that run. The failed original CPU evidence remains in
`artifacts/growth-rivals-20260928/cpu-blocked-cylinder/`. A separate short
660-frame functional replay reproduced the same two errors before this fix.

The project had one native-cylinder construction path: round recipes in
`food_city.gd`. The replacement changes collision geometry only. Bacon, sushi,
rectangular cake/wafer floors, render meshes, shader materials, points, mass,
friction, admission footprint and original body bounds retain their previous
rules. Donuts already used solid cylindrical collision; this change does not
silently introduce a different hollow-donut mechanic.

Godot's current official SAT source uses a two-contact buffer in its analytic
edge/circle path, with guards at intersection insertion. Its convex support
path has a sixteen-point face budget. These observations explain which paths
the workaround avoids; the online `master` lines differ from the bundled
4.7.2 diagnostic, and the exact installed engine revision was not rebuilt or
proved byte-identical to that online source. This is a game collision workaround,
not an engine-wide fix. Sources: [SAT contact generation](https://raw.githubusercontent.com/godotengine/godot/master/modules/godot_physics_3d/godot_collision_solver_3d_sat.cpp)
and [convex support selection](https://raw.githubusercontent.com/godotengine/godot/master/modules/godot_physics_3d/godot_shape_3d.cpp).

## Shared rounded replacement

`FoodCity.round_food_shape(radius, height)` caches a regular convex prism by
the exact dimension pair. The final shape has sixteen vertices on each cap,
preserves the old outer radius and height, and uses the polygon contact path.
Its authored maximum radial inset is 1.9215%; actual physics ray queries measure
1.9387–1.9397%, including about 0.1 mm of engine plane-intersection tolerance.
The runtime admission footprint remains the original circle radius. This is
well inside the existing eight-percent fit allowance and is not a box proxy.

The initial scene contains 1,942 rounded food bodies sharing 454 shape resources,
plus 598 rectangular food bodies whose box geometry is unchanged. The meshes
and materials are untouched; rendered visual parity still requires ordinary
browser/device observation rather than these physics checks.

A 32-sided candidate removed the native diagnostic but failed the original
six-second contact-speed guard. A twelve-second physical comparison recorded
persistent pizza rocking with approximately 0.1104 J kinetic energy and
0.3873 m/s speed. The sixteen-sided candidate reduced those to approximately
0.0518 J and 0.2630 m/s; the old native-cylinder package also had nonzero residual
contact motion. Full raw states and rejected-candidate source/logs are retained.
The result does not claim to eliminate all numerical contact motion.

## Existing thin-food penetration uncovered by independent review

The independent reviewer constructed a six-piece cookie/burger pile, removed
initial collider overlaps, and still observed the bottom cookie pass through
solid terrain. The same fixture reproduced the defect in the old native-cylinder
package as well as the replacement. A single isolated cookie remained supported.
This was an existing impact/terrain defect, not evidence that circles should be
replaced with boxes or that errors should be whitelisted.

Round foods now receive their shared convex support points. Only awake,
non-rain pieces near the terrain inspect those points. A fallback uses the
previous body pose and actual physics-world rays to detect missed deep terrain
contact. Both the current center and actual lowest hull point must hit the
current cut-ground body. It corrects only penetration deeper than 4.5 cm, to an
8 mm contact depth that allows the normal solver to produce torque. Horizontal
velocity, angular velocity, friction, mass and all collection rules are intact.

An earlier predictive prototype was rejected because stopping ordinary food
above the contact plane prevented natural tipping. That failure is retained in
`food-collision-swept.json`. The final guard leaves normal contacts and their
penetration tolerance to the engine. A piece that crosses an actual opening
disables this fallback until it physically returns wholly above the surface;
moving the mouth away cannot lift an already-descending piece back onto land.
No correction is based only on a hard-coded ground height, and the code never
freezes a body in the air.

## Evidence

All author evidence is under
`artifacts/growth-rivals-20260928/food-collision/`:

- `baseline-functional-trace.*` and `baseline-diagnostics.json`: two reproduced
  native errors from the original cylinder implementation.
- `after-functional-trace.*`: rejected 32-sided candidate's clean opening replay.
- `convex16-opening-functional.*` and `convex16-opening-diagnostics.json`: clean
  sixteen-sided replay before the final penetration guard. These runs are
  diagnostic evidence, not isolated CPU measurements.
- `{cylinder-pack,convex32-source,convex16-source}-settle.*`: twelve-second
  controlled traces, sampled every half-second, with actual inverse-inertia
  kinetic energy, pose, speed, support depth and sleep state. These comparisons
  precede the final ordinary-food guard.
- `comparison-manifest.json`: variant summaries, source/test/helper hashes and
  preserved old-package hash.
- `six-second-contact-failure.*`: the rejected 32-sided candidate's original
  contact failure. The speed guard was not relaxed.
- `food-collision-penetration-guard.{json,log}`: final author **96-check PASS**,
  covering full-city shape/resource inventory, eight recipe types, 512 actual
  support rays, original admission boundaries, tilted ordinary/rain landings,
  and independently credited complete physical falls.

`tests/food_collision_acceptance.gd` emits `FOOD_COLLISION_ACCEPTANCE`; the
release minimum is 96. The independent reviewer owns
`tests/food_collision_review.gd`, marker `FOOD_COLLISION_REVIEW`, minimum 16,168,
and `artifacts/food-collision-20260929/independent-source.{json,log}`. That review
confirms the initially separated six-piece stack remains supported, all six
original body IDs independently fall and score after opening real holes, a
partially supported pizza releases when the mouth moves underneath it, and
restoring ground after a piece entered the hole never lifts it back. All ten
rain ingredients retain their own valid collection receipts. The prior package's
41 complete render-mesh fingerprints and ingredient shader fingerprint match.
The last three seconds of stacked-contact observation remain bounded: maximum
pose change 3.168 degrees, displacement 0.1534 m and vertical range 0.0411 m.
The reviewer retains the original linear-speed bound and uses a pose window to
distinguish numerical back-and-forth contact motion from sustained rotation;
this is not a claim of perfectly motionless contacts.

Final runtime hashes:

- `fidelity/food_city.gd`:
  `4d9523a275990adbbbaa8cd2f2efccfebe747bda119003276a89b06af4a1e84b`.
- `fidelity/food_body.gd`:
  `32ecd84b84f782d522b6de58286409b4f81e4a5e7dab7a3772dab47712edc029`.

All author runs use
`--test`; no player save, user server, browser or Git publication was changed.
The only ignored diagnostic is the existing exact macOS certificate diagnostic;
native collision errors remain release-blocking.
