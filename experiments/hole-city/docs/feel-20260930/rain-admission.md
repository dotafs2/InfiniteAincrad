# Rain admission accounting and natural reactivation

The first full release attempt stopped at `food_rain_continuity`. Its old assertion treated 24 as an all-time limit on every rain body marked `!rain_landed`. No package was exported or published by that failed gate. The previous v0.10.0 preview remained intact.

The rain system actually uses 24 as an admission limit: before each wave, count existing airborne classifications, then admit at most six new drops without exceeding 24, also respecting the separate 640 retained-food capacity. Previously landed food remains physical. Collisions and removal of support can wake it or make it fall again between waves. Therefore a correct wave limit does not imply an all-time total-motion limit.

## Reproduction and cause

The identical stationary diagnostic was run for 14,400 real physics frames against the revised source and the preserved v0.10.0 package. The old package ran with its own directory as the working directory and an absolute `--main-pack`, so resource loading did not fall back to the source tree. Both runs used `--test` and did not write player progress.

| Run | Peak `!rain_landed`, every frame | Landed-to-unlanded transitions | Final rain serial |
| --- | ---: | ---: | ---: |
| Preserved v0.10.0 PCK | 22 | 710 | 600 |
| Revised progression layout, before admission diagnostics | 29 | 771 | 598 |

The rejected legacy suite sampled once per simulated second and recorded 26; the every-frame diagnostic found a peak of 29. The first over-limit sample occurred at tick 8,897 (about 148.3 seconds), with 26 classified bodies. The previous wave was tick 8,846: six new drops brought its count from 14 to 20. Fifty-one frames later, without another spawn, previously landed bodies lost contact or were disturbed by other bodies.

This is a layout-dependent exposure of an incorrect global test invariant, not a new-wave over-admission bug. The `rain_landed` classifier also conservatively excludes some supported sliding bodies once their horizontal speed exceeds its existing threshold, and center-ray support can temporarily miss side contacts. Those existing semantics are recorded rather than silently relabeled here. The number 29 is a measured classifier peak, not proof that 29 geometries were simultaneously unsupported.

Evidence: [diagnosis summary](../../artifacts/feel-20260930/rain-budget/diagnosis-summary.json), full [source trace](../../artifacts/feel-20260930/rain-budget/baseline-diagnose.json), [old-package trace](../../artifacts/feel-20260930/rain-budget/old-package-diagnose.json), and retained original gate failure/runtime under `artifacts/feel-20260930/rain-budget/before/`.

## Narrow runtime change

At the initial admission-only cutoff, only `fidelity/food_city.gd` changed. It exposes synchronous `rain_admission_started(snapshot)` and `rain_admission_finished(snapshot)` signals, a monotonic admission serial and one latest completed snapshot. The before snapshot contains event number, actual serial, retained and airborne counts, and requested capacity. The completed snapshot adds actual spawned count and final serial. Zero-capacity attempts also emit a matched pair.

The capacity formula is unchanged except for an explicit nonnegative clamp equivalent to the former early return. Observer dictionaries are copied before emission; a callback cannot modify the production budget by editing its copy. There is no unbounded history, extra per-frame scene scan, new material or new body. At that initial cutoff, `food_body.gd` was byte-identical to the retained original; the independently discovered support-loss follow-up below changes it. Nothing is deleted, frozen, hidden, permanently marked landed, moved or awarded points to satisfy a count.

The admission invariant remains strict: if the pre-wave count is at least 24, admit zero; otherwise admit no more than `min(6, 24 - airborne, 640 - retained)`. Bodies queued for deletion are excluded before accounting. Natural reactivation remains observable independently.

## Author validation and separate review

`tests/rain_admission_acceptance.gd` passes **71** strict checks. Synchronous callbacks independently count the actual live body IDs before spawning and compare the exact newly created IDs afterward. Cases cover empty, 23, 24 and already-26 airborne fixtures; supported-but-awake fixtures; queued deletion; retained capacity 640; disabled rain; title/intro/results; natural paused SceneTree frames; and mutation of observer dictionary copies. The supported-state setup in this short scheduler suite is synthetic and explicitly does not claim physical landing coverage.

A separate non-author review owns real settling, reactivation after an upward impulse/removal of support, continued visibility and independent consumption. That review subsequently discovered the genuine support-loss defect described below. It also owns the narrowly justified legacy continuity assertion maintenance: retain the 240/120-second runs, all retained-food and near-player continuity requirements, and report the actual per-frame total, while verifying 24 at every admission. This review must reject even one extra spawned body and incorrect use of sleep as a substitute for support. Its final report and packaged release result are separate from this author cutoff.

The runtime SHA is `a8591b3b5b43e10440018e5b365411c64bf9d20e5addedcd97a9aaa97128b999`. Exact test and old-PCK hashes are in the diagnosis summary. All author helpers have exited. No browser capture, device frame-time or all-active-bodies-at-most-24 claim is made.


## Real support-loss defect found by the independent review

The non-author physical suite found a genuine existing bug beyond the admission assertion: after six rain cookies naturally settled and batched on an elevated real collider, deleting the platform left five asleep at their previous height. The exact failure remains in `artifacts/feel-20260930/rain-review/rain_admission_review-first.*`. A diagnostic observed zero native contacts before removal and actual round-hull gaps of approximately 0.030–0.041 m: the old ray correction used an enclosing-box extent plus 0.008 m and then explicitly allowed sleeping. No runtime reference ensured wake-up when this support vanished.

A first prototype used actual hull support height, -0.008 m contact slop and a same-support native-contact requirement before manual sleep. This produced four contact points per body, but still left four asleep after platform removal, and two other cookies kept rocking longer than before. Both code and rejected reports are retained under `rain-budget/food-body-contact-prototype.gd` and `support-prototype-*`. This prototype was fully withdrawn. The final change does not alter slop, extents, friction, damping or sleep thresholds.

The final `food_body.gd` stores a weak reference and transform for the actual collider returned by its existing support ray. The already-enabled rain physics callback checks this reference only while the rain body is landed and sleeping. If that collider is deleted, leaves the tree, moves or rotates, or no longer has a collision layer compatible with the food, the food clears its old landed/contact state, wakes, and releases its old batch slot immediately. Normal gravity moves the existing body. An unchanged live support leaves its sleeping body alone.

This adds no extra ray casts, no new body, no support plane and no permanent sleep disabling. Weak references do not keep consumed support bodies alive. Ordinary mouth admission continues to wake foods when the terrain opening changes. The change does not award collection, freeze other bodies or move the food itself.

The frozen author `RAIN_SUPPORT_ACCEPTANCE` suite passes **102** checks across all ten recipes. Each food starts rotated, falls onto a real elevated platform, naturally sleeps and joins its batch, then wakes without a test-set wake flag when the platform is deleted or translated away. All original IDs visibly fall and reach real terrain; no score or collection event occurs from the wake alone. Its first version referenced a nonexistent receipt property after the physical checks; that rejected log remains. The final fixture instead observes the actual `item_collected` signal, retaining all physical assertions.

The separate reviewer has extended the permanent review to actual edible FoodBody support being swallowed, platform deletion, support movement, collision-layer removal, ordinary complete descent and single collection receipts. This independent review and the full source/PCK gate are still required after the author cutoff; the initial accounting result alone is insufficient to approve the support fix.

Final authored runtime hashes:

- `fidelity/food_city.gd`: `a8591b3b5b43e10440018e5b365411c64bf9d20e5addedcd97a9aaa97128b999`
- `fidelity/food_body.gd`: `5b6e749279f4b5b213bad72cc5c51ddb7ae63d0b6a3ae81945ce2b8da56726f9`

[Final author support provenance](../../artifacts/feel-20260930/rain-budget/support-final-provenance.json), [102-check receipt](../../artifacts/feel-20260930/rain-budget/support-author-second.json) and [exact support-owner diff](../../artifacts/feel-20260930/rain-budget/food-body-support-final.diff). All author helpers have exited.

## Subsequent independent acceptance

The later independent review completed **392 strict source checks** across the 101-check physical review, 38-check continuity suite, 80-check ten-recipe snack suite, and independently rerun author suites (71 admission and 102 support checks). Deletion, movement, layer removal and actual edible-support swallowing all pass without test-side wakeups. The corresponding 76-suite source/isolated-package release subsequently passed 53,788 checks per phase; see the [independent review](rain-admission-review.md) and [release summary](README.md). The pending statements above describe the earlier author cutoff, not the final disposition.
