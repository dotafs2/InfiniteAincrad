# Independent review: sustained food rain

Reviewer: city-motion subagent, independent of the food implementation author.
Date: September 28, 2026. Verdict: **PASS for the tested scope**.

Reviewed and exercised:

- `fidelity/food_city.gd`: `8c17ec4f719f1943f39c8e3131131b255e3bc4112cd2bad74bb8dc8c595edc25`
- `fidelity/food_body.gd`: `f1efeff87c1526f3e03466e35366f7f9ecacf3cd22343a45b7eae12cc74adc9c`

Independent `tests/city_review_food_rain.gd` passed 9 checks using actual physics
at fixed 60 Hz in an isolated test process. Fresh rain totals at 20/40/60 seconds
were 54/102/150, exceeding the old 24-object stop. More than 20 real landed
foods joined shared batches. A landed batched food detached its exact batch
slot, exposed its current individual model, fell into the player's hole and
awarded points. The review moved the camera separately from the player to prove
distant visible food remains present and the same object retires only when
hidden and settled. Evidence: `artifacts/audit-fixes-20260928/food-rain-independent.json`.

The first attempted run caught an unrelated concurrent landmark build error
(`Array` assigned to `Array[Vector2]`). The food author repaired that error;
this verdict applies to the subsequent clean run, not the interrupted build.
The same independent nine checks were rerun successfully after the visibility
guard changed from sampled points to a conservative sphere against all camera
frustum planes, preserving food that only partly intersects a screen corner.

Code inspection confirms contact against actual collision geometry determines
landing; sleeping is only required for batching. Waking unbatches food before
continuing physics. The author's longer 240/120-second stationary/travel tests
provide separate sustained and capacity evidence. This review did not run a
phone GPU, capture a browser screenshot, or verify subjective visual quality.
No actual saved progress was read or changed.
