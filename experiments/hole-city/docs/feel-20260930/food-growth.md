# Grounded food progression revision

Author status: **2,202 strict growth checks pass**, followed by unchanged density (1,403), perimeter (631), ten-recipe rain/swallowing (80) and train (220) suites. Independent review is required before delivery. No player save, hole growth table, city street route, skin or audio implementation was changed by this unit.

## Cause and layout change

The previous map had seven physical size gates in total, but its directly available ground food was heavily concentrated at the first gate: 1,377 level-one foods and only 19 level-two foods. Within 20 m of the normal `(1, 23)` spawn, there were 145 level-one foods and just one level-two target. Many visible intermediate pieces were supported tower tiers, so they were not independently available until a lower piece fell. Visual size variation alone overstated the player's actual choices.

The deterministic generator reallocates 182 of the original 960 inner-city loose foods. Each of the seven inner districts receives 14 actual level-two, eight level-three and four level-four targets. Their collision footprints are 0.96, 1.35 and 1.9 m respectively. Mesh and collider dimensions change together; admission retains the original 1.08 margin. Full conservative recipe envelopes clear retained food by at least 0.18 m and actual roads/walking corridors by at least 0.30 m. Each intermediate target has a next-size ground target within 16.20 m in the measured final scene.

Three existing heaps at indices 2, 4 and 6 supply an inner-city level-six destination. One center-bottom donut in each heap becomes a real cookie platter with radius 3.4 m. The other 58 pieces stay separate and rest through real support chains above it. The complete heap remains inside its original 3.7 m reserved circle; measured maximum extent is 3.63806 m. Level five cannot admit the platter; level six can. Each heap still contains exactly 59 bodies, and its silhouette gains a broad base without moving any street or neighboring building.

The city retains 160 buildings, 17 heaps, 1,080 loose snacks, 2,922 original non-train bodies and eight sushi train cars. Outer frontage foods, both traffic routes, all roads, pedestrian corridors, tower plans and atlas bytes are unchanged. Recipe meshes and materials are unchanged. The existing 34 shared meshes are reused.

Only the three platter receipts change value: each replacement awards 10 points instead of the former small piece's two. This is smaller than a single later-level score interval and follows one complete physical descent. All 182 resized snacks explicitly retain their original one- or two-point receipts, and other original food values remain unchanged. There is no free score, smaller hidden collider or hole-radius override in gameplay.

## Actual distribution and play evidence

Ground availability excludes pieces whose physical support parent still exists.

| Minimum hole level | Before ground | After ground | Before within 20 m of spawn | After within 20 m |
| --- | ---: | ---: | ---: | ---: |
| 1 | 1,377 | 1,120 | 145 | 74 |
| 2 | 19 | 117 | 1 | 15 |
| 3 | 46 | 102 | 4 | 12 |
| 4 | 87 | 115 | 3 | 7 |
| 5 | 84 | 84 | 2 | 2 |
| 6 | 14 | 17 | 0 | 2 |
| 7 | 8 | 8 | 0 | 0 |

The reduced level-one ground count includes 72 former independent heap roots now supported above the three platters; their bodies and independent collection remain. Seventy-four opening ground foods still provide more than six complete first-upgrade point budgets, before counting their released upper pieces.

A guided solo route uses real player input, movement, admission, gravity and receipts. It selects nearby newly edible foods and keeps moving beneath a partially admitted item, as the ordinary controller does. It does not write score/radius or call `award`. Rain is disabled only for this comparison so it measures the authored map. The baseline runs the preserved delivered v0.10.0 PCK from its isolated directory; the current run uses the revised source.

| Reached level | Prior package time | Revised time |
| --- | ---: | ---: |
| 2 | 5.88 s | 5.88 s |
| 3 | 7.83 s | 10.73 s |
| 4 | 10.30 s | 22.85 s |
| 5 | 13.00 s | 27.13 s |
| 6 | 14.83 s | 28.72 s |
| 7 | 16.37 s | 31.72 s |

The revised route collected six level-two, ten level-three and eleven level-four foods through actual complete falls. On reaching level five, the nearest next-size target was 22.52 m away, with two within 25 m; the prior route's nearest was 59.29 m away. Level-seven food remains an outer-ring exploration objective. Faster arrival is not treated as success: the intended improvement is a sequence of distinct meals and locally available next targets. These scripted times are not a human retention study, and tower cascades can still advance a level quickly under the unchanged score table.

A separate physical fixture admits each platter with an appropriately grown level-six hole, using ordinary terrain cuts. All 177 original piece IDs produce exactly one complete-descent receipt; each platter emits its single ten-point receipt with its top at approximately -3.59243 m. No collection is awarded when the base first wakes. This physical fixture uses a setup award and is reported separately from the zero-score natural route.

## Preserved failures and limits

The first route helper incorrectly stopped steering as soon as a food acquired a claimant. Actual admission deliberately wakes bodies at partial rim contact, so a medium burger remained legally supported beside the mouth. The helper was corrected to continue ordinary input toward `interaction_position`; neither food physics nor the size gate was changed. Both the early-hold failure and corrected old-package/new-source runs remain recorded. A diagnostic attempt also called `get_colliding_bodies` without enabling contact monitoring; its engine errors are retained and it is not a passing receipt.

The first platter-author run passed every physical check but failed the new test's earlier 100-ground-starter expectation. Moving two nearby heaps' bottom snacks onto platters intentionally reduces that count. The author test now requires at least 60 real opening starter foods plus the intermediate populations, and records the measured 74. This is an explicit refinement of a new author expectation, not a weakening of any pre-existing game acceptance suite. All rejected receipts remain available.

The intermediate version exceeded the old `food_finish` opening-view ceilings; those failures remain recorded. Non-author review measured the final platter content against the original delivered PCK: total geometry decreases from 4,961,996 to 4,961,612 triangles, with all 34 mesh arrays unchanged. The deliberate relocation changes conservative opening submissions to 744,252 triangles/69 cells at radius 0.85 and 1,149,552/124 at radius 7.2. Two explicitly fixed content ceilings now reflect those measurements, with four one-triangle/one-cell overflow counterexamples. The original 4.5M content, 650k extension, 5M total and all eight outer-view ceilings remain unchanged. An exact-diff cross-review confirmed that only the two opening expectations, extracted identical predicate and four negative checks changed. See [non-author growth review](food-growth-review.md) and [budget maintenance review](../../artifacts/feel-20260930/food-review/food-finish-maintenance-independent.json).

The non-author review additionally passed 1,476 checks. Real viewport touch input started from zero points, naturally reached level six at 30.72 seconds, and then walked to all three platters. All 177 heap piece IDs fell completely and scored once; the run reached 820 points by 47.62 seconds. It did not write score, radius or player position or invoke an award setup. These independent route choices differ from the guided author comparison and are reported separately. Conservative batch counts remain geometry estimates, not measured GPU cost. Browser appearance and phone 60 FPS remain unverified.

## Evidence and frozen author cutoff

- `artifacts/feel-20260930/food-before/`: exact prior runtime/generator/plan/atlas copies, source hashes, full actual body distribution and old-package route binding.
- `artifacts/feel-20260930/prototype-placement.json`: initial measured-clear packing proposal.
- `artifacts/feel-20260930/food-after/`: rejected early-hold route, diagnostic errors, intermediate author passes, the first platter failure and unchanged historical opening-budget failures.
- `artifacts/feel-20260930/food-final/`: strict suite reports/logs, source hashes before/after, `ground-histogram.csv`, `comparison.json`, and exact plan preservation/point-value checks.

Frozen authored files:

| File | SHA-256 |
| --- | --- |
| `fidelity/food_city.gd` | `1a4b33a2b4890411fef3304a29e46a3c4b6d1ca38a1e2f81be1f47f2ee430755` |
| `tools/build_food_neighborhoods.py` | `217e2087da9ec5ad6cd5aab98e9e84f8fbccf585e23cb90ca783d8945308e90d` |
| `assets/food_city/neighborhoods.json` | `8c0a6329f65b237279dadaefd047c3c7aca375a3a19f4e2f6fc8d478a27ea784` |
| `tests/food_growth_acceptance.gd` | `5d8868f4fd0a04962fd1663c01bf4b60e90192acf2e754467c333c901783728c` |

The generator reproduces the complete final plan. All owned engine helpers have exited. The separate non-author review is now PASS as linked above; the final source/PCK release gate is owned by the root task.
