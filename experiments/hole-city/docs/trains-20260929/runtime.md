# Edible train runtime

The shared controller adds an eight-section sushi train and a four-section city
light-rail train. Map integration supplies the existing perimeter roads and
keeps all eight previous traffic actors in each map. Each section uses its own
imported model bounds, rigid body, size-admission gate and ordinary point value.
There is no whole-train collider, aggregate size gate or synthetic collection.

## Ownership and public interface

`fidelity/edible_train.gd` is a RefCounted controller. Map code owns its lifetime
and calls `build(game, city, route: Array[Vector2], specs: Array[Dictionary],
speed)` and `step(delta)`. Specs contain `asset`, `category` and `points`; explicit
`mesh` fixtures are supported for isolated tests. Build appends each body to
`city.foods` and registers it with the current food-query mechanism.

`cars`, `attached_count`, `detach_events` and `diagnostics()` expose bounded
state. `planned_branches()` returns actual sampled bypass curves as
`Array[PackedVector2Array]`; `route_changed(plans)` emits that same data after a
new plan. Map integration paints those curves into the existing cut-ground
material. The controller adds no track collider, joint or floor over holes.

Each `train_car.gd` inherits the existing RimBody solver. Successful
`begin_swallow` or `begin_pull` cuts the chain before releasing scripted motion.
Rejected size admission does not disconnect anything. The affected car enters
normal gravity/pull/claim recovery; all later cars retain their exact world
transforms as stationary, individually edible bodies. Neither a lost claim nor
a later route lap can reattach, teleport or respawn them. The original common
solver remains responsible for complete physical descent and one collection.
Ten shared-mesh visual couplers across the two maps disappear at cut links;
they have no physics ownership.

## Continuous movement and stopped-tail avoidance

The head samples a closed polyline by distance. Actual traveled world positions
are recorded in a short history; coupled sections follow that history at
width-aware spacing, including through curves and bypasses. This avoids a
route change snapping the whole remaining train sideways. Intro, title,
results and pause stop routing. Movement does not modify a released body's
transform or velocities.

Stopped cars create local bypass intervals with smooth 7 m transitions. The
city permits a 1.6 m lateral offset, and the food road permits 1.35 m. Both
candidates are checked against actual scene collision shapes before use. The
head also probes ahead for other obstacles; visually occupied layer-zero
pedestrians participate through the scene's dynamic food query. Every moving
section is checked at substeps of at most 0.12 m. A genuinely blocked corridor
stops movement until space is available; collision is never disabled to pass
through the tail. Independent road review supplies the corridor clearance
proof. Multiple parked cuts can legitimately occupy both lanes.

An independent review caught a real lifecycle bug: during the first planning
attempt, the section being swallowed can still temporarily obstruct a candidate
curve. A failed future plan now retries every 0.5 seconds of active game time,
well before the next encounter. This preserves real collision checks and avoids
leaving the head permanently on a blocked centerline. The original failed
review and its collider diagnostic remain under `review/preliminary*` and
`review/city-block.json`.

## Scene lifetime

The first full release gate caught a stale-owner case in the existing rival
combat fixture: it destroys and replaces `game.city` but retains the game's
train controller while continuing natural game physics. The controller now
requires both a valid city and identity with `game.city` before stepping or
applying poses. A still-live former city is likewise inert after replacement.
Explicit chain cleanup tolerates freed car/link entries and may update only
its internal disconnected state. Individually destroyed visual couplers are
skipped without stopping otherwise valid car motion.

Eleven added author checks cover replacement before destruction, destruction
followed by natural game physics, explicit stale-controller operations and
independent car/coupler destruction. All original 209 train checks remain, and
the existing rival-combat test was not edited; it passes all 58 checks. Earlier
release failure logs remain intact. This lifecycle fix is being independently
reviewed before the release gate restarts.

## Imported palette handling

All ten GLBs retain authored COLOR_0 arrays, but this engine imported their
active StandardMaterial3D resources with vertex-color albedo disabled. The
actual material probe reproduced white albedo, no texture and no override.
`train_assets.gd` now duplicates only a BaseMaterial3D attached to a real color
array and explicitly enables that flag. Authored roughness, albedo and linear
vertex-color setting remain unchanged. A stable resource-path cache shares the
adapted materials across rounds rather than accumulating transient object IDs.
The mesh and original imported material resources are not rewritten.

## Evidence and limits

Author `tests/train_acceptance.gd` passes **220 checks**, with strict engine-log
validation. It covers size rejection, head/middle/tail cuts, ordinary player and
AI receipts, pull/reclaim, repeated cuts, phase/pause guards, 30/60/120 Hz motion,
seam continuity, tight-turn OBB separation, world obstruction and recovery,
all ten actual imported models, material retention and cache bounds. Both real
maps run a full initial lap, swallow a real middle section while the head
continues, then complete more than two further laps with the parked tail at its
original transforms. Author evidence is `artifacts/trains-20260929/author/final`
and `provenance.json`; initial failed evidence is preserved separately. The
latest lifecycle rerun and exact hashes are under
`artifacts/trains-20260929/lifecycle/`, including the unmodified 58-check rival-combat suite.

Hypatia's final independent gameplay suite passed **366 checks** with stable
release inputs, including the originally failing city corner cut, repeated-lap
returns, all twelve real car receipts and zero overlapping car colliders.
Erdos's independent surface/lifetime/input suite passed **1,121 checks**, including
palette-cache counts `[2, 10, 10, 10]` across repeated city/food round teardown.
Their separate reports retain the original failures and final input hashes.

## Isolated added-controller timing

The following samples predate the final scene-owner guard (controller SHA
`b9457560e12648f82a021aae087ce2d190bf3650e00bc9a209e343eb22c3cc32`).
They are preserved historical added-logic measurements and are not claimed to
cover the later lifecycle source hash. After all other owned engine helpers
exited, an isolated native Mac headless run retained 2,400 elapsed-time samples around `controller.step(1/60)`. The four
600-sample cases passed 16 movement/admission/fall checks. Full release input
hashes were unchanged across the run; raw durations, engine/helper hashes and
strict logs are under `artifacts/trains-20260929/cpu/`.

| Map and state | Median | P95 | P99 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| City, four coupled sections | 0.630 ms | 1.239 ms | 1.430 ms | 1.569 ms |
| City, middle cut including first planning | 0.301 ms | 0.939 ms | 1.028 ms | 10.960 ms |
| Food, eight coupled sections | 0.527 ms | 0.732 ms | 0.798 ms | 0.846 ms |
| Food, middle cut including first planning | 0.129 ms | 0.332 ms | 0.374 ms | 8.758 ms |

The maximums retain the one-time bypass planning and ground-track update spikes;
they are not discarded from the distribution. These are elapsed method timings
including scene queries and branch-change callbacks, excluding the remaining
game frame, the physics solver outside the call, rendering and GPU work. They
are neither a total frame budget nor an iPhone 14 60 FPS certification. Full
source/export release acceptance is a separate gate. All author, reviewer and
profiling helpers had exited before that gate was authorized to start.
