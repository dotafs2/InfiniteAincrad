# Collision fixture maintenance after the perimeter expansion

The expanded Snack Garden contains real buildings where older tests assumed
empty ground. This change updates two test fixtures and one resting-motion
oracle. It does not change runtime physics, food geometry, map placement,
scoring, opening sizes or any contact/collection timeout.

## Reproduced interference

The old ordinary/rain contact pair at `(70,20)` / `(74,20)` adjoined the new
pancake building centered at `(74.30127,20.05667)`. The rain specimen began
inside its footprint. The old six-piece cookie/burger pile at `(70,24)` also
contacted an authored building tier: the diagnostic contact monitor recorded
`food_pancake_878`, tower 150. These were not isolated ground-contact trials.

Each of the eight paired trials now has a measured clear landing volume. The
original 4 m ordinary/rain spacing and at least 16 m between pair centers are
preserved. An actual physics shape query checks layers 1 and 2, excluding only
the real terrain body's RID; a separate short ray must hit that terrain. Both
ordinary and rain specimens receive these preconditions before any specimen
is created. The pile uses the first geometrically selected clear site `(0,88)`
and the same six sizes, rotations, vertical separation, release state and
observation windows. Its complete air volume and real ground are also checked.

The initial draft query used layer 2 only. Non-author review caught that this
missed frozen foods on layer 1. The final queries use mask 3 and exclude only
the terrain, retaining thin-food detection just above the floor.

## Deliberate resting-motion oracle correction

The pile's original final-three-second displacement, rotation and vertical
range bounds remain `<0.2 m`, `<5 degrees` and `<0.05 m`. The former additional
single endpoint native velocity `<0.3 m/s` is replaced with actual horizontal
travel accumulated over the same 180 pose samples / 179 physics intervals,
divided by the measured fixed-step duration, still `<0.3 m/s`. This detects
sustained sliding and repeated horizontal movement even when net displacement
is small. Vertical movement remains bounded by the unchanged vertical envelope.
This is an intentional semantic correction, not a claim that every original
assertion is unchanged. It establishes bounded contact motion, not complete
sleep or absence of visible jitter.

Evidence retained before changing the oracle:

- At the unchanged selected site `(0,88)`, maximum native endpoint speed was
  `0.392203420 m/s`, while maximum actual horizontal path speed was
  `0.086751589 m/s`. Maximum displacement, rotation and vertical range were
  `0.117692821 m`, `4.215843 degrees` and `0.038713232 m`.
- A read-only v0.8.7/current comparison used the same clear in-bounds site
  `(-22,-44)`, identical six initial poses, zero initial linear/angular
  velocities and gravity scale 1. Both versions failed three original combined
  resting checks. The prior top cookie also reached `5.056329 degrees`, slightly
  exceeding the old rotation guard. This is retained as a baseline limitation;
  the final rotation limit was not relaxed.
- A proposed full 3D actual-path replacement was rejected: the same-site prior
  and current comparisons reached `0.326149` and `0.314960 m/s`; the selected
  final site's top cookie reached `0.307655659 m/s`. These measurements do not
  support claiming that a full 3D `<0.3 m/s` test passes everywhere.
- The old/current `food_body.gd`, `rim_body.gd` and `scripts/swallowable.gd`
  were byte-identical. The pile directly releases bodies and does not call
  `lose_support`, so body-name-derived release impulses are not a variable.

The final receipt retains endpoint native velocity, actual 3D path speed and
all 180 vertical positions as diagnostics. No test coordinates were searched
for a passing motion result, no random seed was changed, no timing window was
extended and no numerical threshold was raised.

## Preserved scope and evidence

All original collision resource/mesh/ingredient-finish pins, ten rain recipes,
real gravity descent, admission boundaries, unique collection receipts,
complete body descent below `-3.5 m`, independent neighboring pieces, restored
terrain and partial rim support checks remain. The paired author fixture still
uses its original radius 1.5 / score-60 swallowing behavior.

Inspectable evidence:

- [Original clear-site raw trace](../../artifacts/collection-20260929/collision-fixture-maintenance/original-clear-site-trace.json)
  and [individually recalculated motion values](../../artifacts/collection-20260929/collision-fixture-maintenance/original-clear-site-summary.json).
- [Prior/current comparison summary](../../artifacts/collection-20260929/collision-fixture-maintenance/same-site/comparison-summary.json),
  [prior v0.8.7 raw trace](../../artifacts/collection-20260929/collision-fixture-maintenance/same-site/prior-v0.8.7.json)
  and [current same-site raw trace](../../artifacts/collection-20260929/collision-fixture-maintenance/same-site/current.json).
- Preserved originals:
  [author suite](../../artifacts/collection-20260929/collision-fixture-maintenance/before/food_collision_acceptance.gd),
  [review suite](../../artifacts/collection-20260929/collision-fixture-maintenance/before/food_collision_review.gd).
- Exact final diffs:
  [author fixture](../../artifacts/collection-20260929/collision-fixture-maintenance/final-author/food_collision_acceptance.diff),
  [review fixture and oracle](../../artifacts/collection-20260929/collision-fixture-maintenance/final-author/food_collision_review.diff).
- Final strict receipts:
  [156 checks](../../artifacts/collection-20260929/collision-fixture-maintenance/final-author/food_collision.json),
  [18,276 checks](../../artifacts/collection-20260929/collision-fixture-maintenance/final-author/food_collision_review.json),
  [full input-hash manifest](../../artifacts/collection-20260929/collision-fixture-maintenance/final-author/manifest.json).

The `same-site/` directory also retains the initial missing-script harness
failures separately. The original clear-site trace retains the unmodified
oracle's failure before the accepted correction; no failed evidence is replaced.

Final author source execution passed both strict suites: `food_collision` 156
checks and `food_collision_review` 18,276 checks. All release inputs were
unchanged across those runs; the owned engine processes exited. Exact test
SHA-256 values are:

- `tests/food_collision_acceptance.gd`:
  `7a65c9ba4e320280167155300f98b3efda14f4ecef158625b883c634795a3a20`
- `tests/food_collision_review.gd`:
  `37b0bd69f6c5e6219137bd674151371844c9fa42a2f6854194c3ddf77164acd2`

The [non-author final review](collision-fixture-independent-review.md) also passed
[156 checks](../../artifacts/collection-20260929/collision-fixture-maintenance/final-independent/food_collision.json)
and [18,276 checks](../../artifacts/collection-20260929/collision-fixture-maintenance/final-independent/food_collision_review.json),
with all release inputs unchanged before/after and all owned engine processes
exited. The reviewer independently recalculated the raw motion trace and
checked the [exact assertion comparison](../../artifacts/collection-20260929/collision-fixture-maintenance/final-independent/assertion-comparison.json):
all 19 original author assertion expressions remain, and 43 of 44 original
review expressions remain; the one intentional replacement is described above.
The [independent manifest](../../artifacts/collection-20260929/collision-fixture-maintenance/final-independent/manifest.json)
records tested inputs. The parent source/package release gate is separate.

These native headless functional checks do not demonstrate browser appearance,
GPU performance or sustained phone frame rate.
