# Rain admission and support-loss review

Status: independent source review PASS, 392 checks across five strict suites. The original quota failure exposed a separate real support-loss defect, which is now fixed and independently reproduced as passing.

## Admission contract

The runtime admits at most six new foods in a wave and never admits more than the remaining slots below 24 currently airborne foods or 640 retained foods. Previously landed food can bounce or lose support between waves. Those existing bodies remain physical, visible, and edible; the admission limit cannot truthfully be an all-time airborne population invariant.

The unchanged release fixture failed its old all-time 24 assertion. The author retained the old failure and traced a legitimate 14-to-20 admission followed 51 physics ticks later by old food reactivating without another spawn. The trace reached 29 airborne bodies; the prior package reached 22 under its different layout. Neither observation licenses raising the admission threshold.

The maintained continuity fixture observes both sides of every actual production wave synchronously, reads the real body IDs and landed states independently, rejects deleted old bodies, and verifies the new-body count against both remaining capacities. All other old assertions remain. It now records the airborne maximum every physics tick and adds four rejection cases plus one boundary admission case. Its fixed 24/640 limits are unchanged.

## Independently reproduced unsupported sleep

The initial physical review released six real cookie rain bodies from 9 m above an empty physical column. They naturally settled and batched above an actual platform with a top at 6.25 m. All six reported zero native contacts while asleep. Their actual convex hull bottoms were 2.996–4.081 cm above the support, even though the old enclosing-box estimate appeared only 8 mm above it.

After deleting the real platform, five bodies remained asleep, landed, and batched at the former height for at least 6.5 seconds. Independent downward queries then hit only terrain at y = 0. This is a genuine missing wake relationship, not a reason to manually wake the test bodies or weaken the gravity assertions. The retained first run has 74 checks and 15 failures covering motion, batch release, and eventual landing.

Evidence: `artifacts/feel-20260930/rain-review/unsupported-sleep-before.json`, `support-diagnostic-v2.log`, and `rain_admission_review-first.json`. The author owns the runtime correction; this review owns only its independent test and the narrow continuity-fixture maintenance.

## Final runtime review and verification

The permanent independent test passed its actual edible FoodBody support case: rain lands and batches on it, only the supporting food begins ordinary swallowing, the unclaimed rain must wake and move under real gravity without explicit child linkage, and every piece must later receive exactly one receipt after its full top passes below -3.5 m. Source and isolated-package execution use no source reflection or artifact resources.

The final runtime change records a weak reference to the actual collider found by the existing support ray and its transform. An already sleeping, landed rain body wakes if that owner disappears, leaves the tree, is queued for deletion, moves, or no longer collides with the rain layer mask. It exposes its existing individual mesh and resumes the existing gravity path. It does not add another ray, change resting poses, manufacture a body or receipt, or disable sleeping. A trial that moved food to exact hull contact was rejected because it introduced contact instability; it is not in the delivered runtime.

The independent 101-check suite retained the original 74 checks and added actual edible-support swallowing, a still-live sideways-moving platform, a still-live collision-layer-disabled platform, and unchanged-support stability. It proves a physical relaunch can produce 30 airborne bodies, followed by zero new admissions at both 24 and 30. Original bodies remain present and unfrozen. Collection callbacks record each original body ID and require exactly one receipt with its full top below -3.5 m.

| Strict source suite | Checks | Result |
| --- | ---: | --- |
| Independent rain admission / real support-loss review | 101 | PASS |
| Maintained 240 s stationary + 120 s traveling continuity | 38 | PASS |
| Existing ten-recipe snack descent and collection | 80 | PASS |
| Author admission lifecycle and capacity regression, independently rerun | 71 | PASS |
| Author ten-recipe rotated deleted/moved-support regression, independently rerun | 102 | PASS |

The complete continuity run independently observed 100 stationary and 50 traveling admission events. With every physics tick sampled, stationary rain reached a real airborne maximum of 30, spawned 583 foods, retained 581 at 240 seconds, and had 511 foods batched. Traveling rain reached a maximum of 21, spawned 300, retained 57 at 120 seconds, and retired 128 distant hidden settled foods. Every observed new wave respected remaining capacity below 24 airborne and 640 retained. The naturally reawakened population is deliberately reported, not hidden behind a raised limit.

The fixture-maintenance diff preserves every original assertion statement except the incorrect all-time-airborne assertion. That one is replaced with a stricter synchronous admission measurement using independently read live body IDs. Five added boundary checks reject over-admission and state misreporting. A first-run fixture parse error from an untyped dynamic body ID was retained and corrected only by declaring that ID as `int`; no assertion changed for that repair.

Evidence and exact input bindings: `artifacts/feel-20260930/rain-review/final-provenance.json`, each `*-final.json` / `*-final.log`, `continuity-maintenance.diff`, and `continuity-maintenance-summary.json`. The intermediate failed/type-repair attempt remains under `first-final-attempt/`. The same seven runtime/test files hashed identically before and after all five final suites. Session 17235 exited 0; all owned helpers exited. The permanent suites are source/PCK portable and use no `res://artifacts` or GDScript source reflection. Root controls the separate complete source/package release gate.

This review does not operate a browser, capture a render, certify mobile frame rate, or alter saved progress.

## Reviewed source hashes

- `fidelity/food_city.gd`: `a8591b3b5b43e10440018e5b365411c64bf9d20e5addedcd97a9aaa97128b999`
- `fidelity/food_body.gd`: `5b6e749279f4b5b213bad72cc5c51ddb7ae63d0b6a3ae81945ce2b8da56726f9`
- `tests/food_rain_continuity_acceptance.gd`: `26bc20ab882f8329f9612e80b06189de17a4da709b9dfe09123525e57051bf8d`
- `tests/rain_admission_review.gd`: `b0cc59efc2f1b618454f5f9f01e1be8185ed48ea318d8a71444b9fc4bee1674d`
- `tests/snack_city_acceptance.gd`: `5db4c8485fb6b6974593549f3497deb9513cc350d86a32ffe02cdbaa08b529e8`
- `tests/rain_admission_acceptance.gd`: `d2a7e8e6796c190d4ec5e39390e8c3a0e9e0853644c1a0c49949c6f284bfb316`
- `tests/rain_support_acceptance.gd`: `4f1e54e9d806e078f6fe99319cf4ef20d201437b0ed621852cc5551434a4af7d`

## Fixture maintenance peer review

Hypatia separately reviewed the exact continuity-fixture maintenance and the independent physical cases, and reported no weakening to root at 02:51. Root relayed that review after the final runs and also inspected the maintained code. The original duration, replenishment, retained-food, batching, spawn-distance, and hidden-retirement checks remain. This is a read-only diff review, not a second claimed long-run execution; its receipt is `continuity-maintenance-peer-review.json`.
