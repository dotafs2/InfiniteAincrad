# Royal castle runtime review — 2026-10-08

Status: **ACCEPT — current local runtime and exact Web package pass.**

The final frozen candidate satisfies the runtime-review conditions below.
Approval applies to the recorded source hashes and package, with the stated
desktop/fixture limitations; it is not physical-phone or native-build approval.

Independent reviewer: runtime review agent. Scope is runtime geometry, admission,
support, clearance, bounded cost, other-map isolation, and exact artifact evidence.
The root agent owns engine runs. This document does not claim physical iPhone
performance, native build 34 replacement, human playtesting, or audible review.

## Baseline and constraints

The preserved baseline is `build/royal-castle-20261008/baseline`. Its manifest
records the pre-change generator, runtime providers, architecture payloads and
Blender source, map shader, and third-map thumbnail. Earlier accepted release
evidence is historical baseline evidence, not a pass for this candidate.

- `ToyCity._make_toy()` multiplies normalized unit vertices by each placement's
  explicit `size`. `natural_size` is metadata used by the legacy miniature's
  proportion-preserving scale, not by the playable world's body extent. Changing
  source proportions alone therefore does not preserve them at runtime.
- Unit meshes must remain centered in x/z with bottom y=0 and top y=1. Runtime
  compound shapes use `(point.y - .5) * size.y`, while the visual is centered
  using its measured AABB. A different normalization breaks alignment.
- Admission derives from the maximum horizontal radius of **actual visual
  vertices**, multiplied by 1.08. A decorative roof or flag projection can
  change the required level even with identical AABB dimensions. Radius,
  `half_size`, height, mass, bottom rim samples, and whole-body completion all
  depend on measured geometry. Preserve authored points, score rules, and saved
  map IDs; verify any footprint change instead of assuming it is cosmetic.
- Real stack placement rays the compound collider faces at the shared central
  x/z footprint. The intended contact gap is .025 m, and delayed support release
  is .075 s. `block_tower`, `bubble_turret`, and `toy_arch` also participate in
  two-owner court installations. A hollow center or displaced spire must not
  remove the actual support face or leave an upper layer floating.
- Placement bounds plus .08 m clearance must remain outside the road rectangles
  and inside the 192 m square. Ground-level neighboring parcels retain their
  planned separation. Gate beacons use the lower palace's actual half-depth
  plus beacon radius plus .12 m; their center must remain below the 3.15 m
  level-five approach bound and clear other body envelopes and actor corridors.
- Frozen static bodies and shared meshes/shapes must remain bounded. Existing
  agreed budgets are 900 edible bodies, 1,200 mesh instances, 2,000 collision
  parts, 100 scaled-shape cache entries, and at most seven convex parts per
  architectural asset. Triangle ceilings are 12,000 each for toy/grand castle,
  6,000 each for turret/tower, and 2,500 for the open arch. Buildings use unique
  reveal materials and are excluded from ordinary static batching: richer
  geometry is multiplied across the visible city even when draw count stays
  unchanged.

## Critical shared dependency

`FrostCity` extends `ToyCity` and invokes its complete build before replacing
castle visuals with ice. It retains the inherited compound colliders, support
graph, footprint, body extents, and placement plan. Updating shared castle
payloads or `ToyNeighborhoods` changes Frost gameplay unless provider/plan
selection is explicitly isolated. Keeping Frost presentation files unchanged
is not adequate evidence. Freeze the prior geometry/physics provider for Frost
or demonstrate exact parity against the preserved baseline; include court
assemblies that use the shared architectural recipes.

## Required evidence

1. Preserve the strong existing geometry checks: actual indexed vertices and
   normals, unit bounds, nondegenerate closed components, finite convex parts,
   runtime/source hashes, open-arch physical ray, and per-kind budgets. Replace
   old four-course/four-segment/stud-count/coral-frame assertions only where the
   new architectural specification supersedes them. A renamed component role
   is not proof of geometric richness.
2. Run `fairytale_city`, `toy_geometry`, `toy_city`, `toy_court`, and
   `toy_map_integration` against final source and exact exported package.
   Include `frostlight_city`, `frostlight_asset_alignment`, and
   `frostlight_gameplay_parity` for the inherited branch. The toy-city suite
   separately checks support release, measured admission, road clearance, and
   score/size/support planning reachability without court rewards.
3. Verify baseline-to-final Frost body/collider/support signatures, plus other
   maps' relevant source/assets. Unchanged save, economy, purchases, map IDs,
   timing, and native build 34 need exact guarded-input evidence.
4. Inspect actual third-map pixels at the ordinary follow camera, a close
   architectural view, and the map-selection thumbnail. Source mesh changes
   must survive normalized world scaling and gameplay lighting.
5. Obtain at least two disposable-profile ordinary 90-second Toy rounds with
   actual automatic movement and real physics receipts. No position, score,
   radius, or wallet grants may be passed off as ordinary growth. Explicit
   admission fixtures remain useful but distinct evidence. Inspect full logs,
   not only a success marker, for engine errors and teardown leaks.
6. Confirm the frozen source input list, source and PCK acceptance receipts,
   final export file hashes, and actual preview package identity before final
   acceptance. Preserve failed attempts with their causes.

The existing `one_minute_soak.gd` alternates Food and City only. The existing
`toy_visual_capture.gd` contains the relevant real-time Toy phase, but starts a
fresh profile with `selected_map = "toys"` and no explicit in-memory map
entitlement. Its fixture must prove that `_ready()` did not reset selection,
assert actual Toy world metadata, and assert completed-round/receipt outcomes.
Its later overview is an explicitly staged camera, not ordinary play evidence.
Desktop frame intervals and fixed-rate movie capture do not establish phone
GPU performance.

## Review activity

Initial read-only audit covered `toy_city`, `toy_neighborhoods`, `toy_shapes`,
`fairytale_meshes`, `frost_city`, `toy_court`, `toy_preview`, `rim_body`,
`static_batch`, the Blender generator, and related existing acceptance/capture
fixtures. Constraints and the Frost inheritance issue were sent to the root
agent before candidate integration. No engine job or production edit was made
by this reviewer during that initial audit.

## Coordinated Frost isolation implementation

After the initial audit, the root explicitly delegated a minimal Frost-only
physics isolation to this reviewer. Root owns the two ToyCity virtual dispatch
hooks (`_body_mesh` and `_body_collision_parts`). This reviewer added
`frost_legacy_castle_physics.gd`, the corresponding Frost overrides, the frozen
physics-only data, a one-time extraction helper, and focused acceptance checks.
Final review must therefore distinguish this authored implementation from the
independent baseline/data and release evidence checks.

The helper reconstructs the five hash-guarded historical ArrayMeshes and calls
the identical engine `create_convex_shape(true, true)` operation. Root ran the
helper; this reviewer did not run an engine. The result is
`assets/frost_legacy_castle_physics/legacy.json`, 591,431 bytes, SHA-256
`e8896a669b60ce8258fe7387ec305a6ec8840b665abd67505d0b626d0cbc7c84`.
Its renderer-independent data retains exact original compound point lists,
measured AABBs, every distinct original float32 x/z pair, and the original
compact hull point order. Separate Python inspection confirmed all five source
digests, collision lists, x/z sets, AABBs, and stored rim byte digests against
the frozen baseline/extraction. The rim hulls contain 32/32/32/32/28 points;
the compound-part counts remain 5/6/1/3/1 for castle/grand/turret/arch/tower.

The overridden geometry path retains ToyCity's existing extent, mass, radius,
rim, support, and scaled-shape code. A shared temporary cube satisfies the
inherited visual-owner/batch construction without loading redesigned castle
art. Frost's existing synchronous conversion removes those owners and hides
the inherited batches before rendering, then installs the original ice/polar
presentation. The cube is never passed to the physics geometry measurement.
The shared neighborhood plan must remain unchanged; the asset split does not
isolate a future plan edit.

`frost_legacy_physics_acceptance.gd` checks the hash-pinned packaged contract,
cache immutability, all real static and court architecture owners, exact
measured admission and rim/compound points, support ownership/gap, cold-load
isolation, and removal of temporary visuals. Source runs additionally rebuild
the historical visual hull from the preserved baseline. It uses explicit
in-memory QA entitlements and no save path. Engine verification is pending.

The first focused run is preserved in
`build/royal-castle-20261008/frost-isolation-01.log`. It failed to parse two
test-local booleans inferred from dynamically typed dictionary members; no
runtime acceptance checks ran. Both declarations now have explicit `bool`
types. The other inferred declarations were inspected. The cache assertion
also now records a separate post-menu/pre-world checkpoint: selected Frost
preview builds ice assets rather than invoking the inherited castle miniature.
This failed attempt is not a successful runtime receipt.

The corrected root-run `frost-isolation-02.log` contains **57 checks, zero
failures**, with all five historical payloads independently reconstructed in
the engine. It verifies 180 real Frost architecture owners (58 townhouse,
42 turret, 10 grand castle, 46 arch, 24 small castle) and 24 supported owners.
All recorded extent, admission, rim, collider, support, and visual issue lists
are empty. This reviewer inspected the complete log: only the engine banner
and acceptance record are present, without an engine error or teardown leak
warning. Exact-package verification remains pending. The package intentionally
omits the large historical visual files under `build/baseline`, so ten
source-only reconstruction/hash checks do not execute there: the expected
package count is 47, with every frozen-data and actual-world assertion still
enabled. The gate minimum must match that count rather than mistake absence
of archived source art for lost runtime coverage.

## Focused candidate source evidence

The root-run `artifacts/royal-castle-20261008/focused-01/summary.json` records
eight suites and **6,424 passing checks**: fairytale geometry 169, toy geometry
131, Frost city 11, Frost legacy isolation 57, glacier frozen review 2,487,
toy city 2,844, map integration 86, and toy court 639. This reviewer read the
results and independently applied the release gate's strict engine-error
scanner to all 16 complete stdout/engine logs; no unexpected issue was found.

The candidate Toy scene has 799 edible bodies, 856 mesh instances, 1,061
compound parts, 85 scaled-shape cache entries, and ten static geometry cache
entries. All remain under the unchanged budgets. The largest measured body
height is 38.0400009 m and largest required radius is 12.1474694 m. The
score/size/support planner admits all 455 static bodies without court rewards
and leaves zero blocked landmarks. This proves planning reachability, not
travel time. The explicit swallow and supported-stack fixtures remain separate
from ordinary play.

At this source-review checkpoint, the shared neighborhood plan, toy surface
shader, and fairytale lighting match the preserved baseline. Root's ToyCity
change consists of the two agreed provider hooks, keeping explicit overrides
and the existing physics arithmetic. The new Toy ground shader decorates the
existing cut slab with courts and inlays; it adds no physics owner, separate
platform, or per-frame CPU controller. Ordinary gameplay, actual GPU views,
exact package receipts, and final guarded-input verification remain pending.

Independent before/after comparison used the accepted prior
`music-worlds-20261008/web-gate-02/source-toy_city.json` and the new focused
Toy receipt. All 55 kind/tier/extent classes retain the same minimum admission
level, instance count, and supported-owner count. Extent labels were rounded
to .0001 m for matching because four new 8.8 m width labels carry a .000001 m
float difference. Required radii are allowed to reflect the real new meshes;
the largest relative change is 1.8491%, and no admission level changes. Bodies
(799), static bodies (455), total points (4,169), and scaled-shape cache entries
(85) are unchanged. Compound parts increase from 1,037 to 1,061 because each
of the 24 small castles adds its sixth major mass.

## Candidate artifact and staged GPU review

The installed candidate manifest hashes to
`675b2b024853733477b10567b0a1e671ed93a1c0221206122b66802c74c3e1af`.
Independent recomputation matches all five asset file hashes and indexed
geometry hashes, declared counts, generator hash
`3937f008ab83908a70cac657a9a0c374406362289d61929e66007d10cdd89707`,
and Blender source hash
`4d09fdecf27c2a52f0286ddc68da4573e4eb880ce290e2b7c845696cd5f214c0`.
Actual triangle counts are 11,860 / 11,860 / 1,660 / 1,892 / 5,120 for
castle / grand / turret / arch / tower respectively.

This reviewer inspected the matched `before/toys-crown.png` and
`after-01/toys-crown.png` from actual GPU world captures. The new narrowed
central tower, stepped hall and parapet, unequal flank heights, roof rings,
and ground forecourt are visibly different geometry and composition. This
passes the limited requirement that the change be more than recoloring.
These are staged camera views; they do not establish ordinary camera
readability or gameplay pacing. Both capture manifests contain five records
that explicitly identify the actual Toy world, and both complete `gpu.log`
files pass the strict engine-error scan.

## Garden revision and clean focused result

Art review requested actual edible garden framing at the major gates. Root
added a post-court, pre-query/batch site hook, and Frost overrides that hook
with a no-op. The original neighborhood file remains unchanged. Sixteen
candidate bodies (eight topiary and eight flowerbeds) add 64 available Toy-map
points: this is a bounded map inventory change, not a change to score-to-coin
rules or saves. The candidate has 815 bodies, 471 static bodies, and 87 scaled
shape cache entries. New kinds are explicitly covered by the body acceptance
contract; original ten kinds and all eight neighborhoods remain required.

Placement reads actual built body extents, including the court and previously
added props, with .22 m neighbor clearance, .08 m road clearance, and route
distance beyond actor corridor width plus the prop's conservative radius.
The four lower-palace gate beacons are well outside the crown-garden locations.
The shared plan, Frost body population, and frozen physics inputs stay intact.

`focused-03/toy_city.json` correctly rejects the first garden revision. Two
distinct findings were reported to root: the compound-collision assertion was
accidentally extended to new props supplied with only one hull, and the
flowerbed's **actual collider containment** failed because its physics reused
the simplified global rim hull. The containment test must remain; new prop
physical hulls should use original mesh vertices or explicit component point
groups. A simplified `create_convex_shape(true, true)` hull can overrun the
source AABB. This failed run remains evidence, not a passing gate.

Final acceptance of this revision additionally requires actual final prop
clearance checks and a real whole-body swallow/credit check, followed by the
final ordinary-play and source/package evidence.

Root replaced the new physical hull inputs with `geometry.vertices` and kept
the collider-containment assertion. The compound-only check again targets
the structures that require separate parts. `focused-04` then passed its
garden shape checks and both real swallow fixtures: each original assembly
detaches from batching, falls whole below -3.5 m, disappears, and awards four
points exactly once. However, that run was correctly rejected for engine
TypedArray errors when the test helper revisited already-freed earlier
fixtures. Its full logs are preserved as a failed run. The subsequent
test-local validity guard was visible on source review; a clean rerun is
required before accepting the revision.

That clean rerun is `focused-05`: all eight suites pass **6,527 checks**, and
this reviewer independently scanned all 16 complete stdout/engine logs without
unexpected errors. Both garden types retain the actual small-mouth rejection,
visual/collider containment, real road clearance, planning reachability, and
whole-body swallow/credit tests. The executed construction path additionally
checks all actual existing body AABBs and route distances before accepting each
of the 16 sites. Final scene costs are 815 bodies, 1,077 collision parts, 87
scaled-shape cache entries, 12 static mesh-cache entries, and 17 actor
mesh-cache entries. Available map points are now 4,233, including the explicitly
disclosed 64 points in the new garden props.

The actual GPU `after-02` crown frame shows the revised darker gate, smaller
dormers, and planted groups, with a clean complete GPU log. This reviewer also
inspected the ordinary follow-camera frames at 60 and 89 game seconds from
`play-01`; the rebuilt architecture appears in the actual HUD/reveal view.

## Ordinary-play evidence — two repeated runs

`play-01/capture.json` records a fresh disposable QA profile, actual Toy world,
and normal automatic movement/physics with no score, radius, or position
grants during the ordinary phase. It starts at zero points/level one and ends
at 90.0167 game seconds with **326 points, level seven, and 77 player
collections**, including three actual small castles. The later city overview
is separately labeled as a staged camera after reset. The full GPU log passes
the strict engine-error scan.

Reported desktop harness frame intervals after the first three game seconds
have p95 14.37 ms and maximum 29.699 ms; full-run maximum is 140.954 ms and
scene build is 2,753.243 ms. These are measured local capture intervals with
capture-write pauses excluded, not physical-phone FPS or a wall-clock
90-second performance guarantee.

`play-02` independently repeats the same automatic route with a different
disposable profile and another strict-clean full GPU log. It also ends at
90.0167 game seconds with 326 points, level seven, 77 player collections, and
three small castles. In both runs, the actual player receipt points sum to
the final 326-point score, every recorded collection is whole-body, and the
latest collection occurs at 85.45 game seconds. This is reproducibility of a
deterministic route, not diverse-seed coverage or human playtesting. The second
run's steady p95 is 14.481 ms, steady maximum 31.937 ms, full maximum
143.284 ms, and build time 2,740.456 ms. Final frozen source/package
verification remains the outstanding runtime-review closure condition.

## Final models and explicit landmark swallow

The current installed `models-03` manifest is SHA-256
`f8dba47056b5b233a25c927ad7b907af16798d238e2c267ed7e99d7741180784`.
This reviewer independently recomputed the five complete JSON digests and the
indexed geometry digests from their actual vertex/index arrays. All match.
The generator digest is
`020d213386d20e22c0a2dca51301f172784ab27f264fadd9ec275a4611de5631`,
and the editable Blender source digest is
`f174e03bbbd5c18e4532e817fc125a29fc27e6a30eee361e89774b40a7e09766`.
The current triangle counts are 11,756 / 11,756 / 1,660 / 1,892 / 5,120,
totaling 32,184. Measured natural envelopes and collision-part counts match
the manifest. The frozen Frost data digest remains exactly the one recorded
above. Earlier model hashes in this document are preserved candidate history.

The before/after admission comparison was repeated against final
`focused-05/toy_city.json`. All original 55 kind/tier/measured-size classes
still retain their instance count, supported count, and minimum admission
level; maximum relative radius change remains 1.8491%. The only additional
classes are eight topiary admitted at level two and eight flowerbeds admitted
at level four. Their actual measured extents, rather than nominal recipe
boxes, appear in the final receipt.

`swallow-01` explicitly sets a level-12 hole beneath the actual grand castle
after a staged camera orbit. The helper leaves the real swallowing physics
and reward path active, asserts admission, waits for the original body to be
freed, and requires one player receipt worth 96 points. The actual receipt
contains exactly that entry. The full GPU log passes the strict error scan
and has no teardown-leak warning. This is a late-growth admission fixture,
separate from the two ordinary rounds; it cannot show that the largest castle
is reached during a normal 90-second route.

The art reviewer subsequently rejected `swallow-02` as final presentation
because the isolated-target helper left nearby garden bodies suspended over
the cutout. That earlier fixture remains valid narrow target/reward evidence,
but it is not the final dynamic demonstration. Root corrected the capture
helper, without changing production physics, to call the real `game.scan_food()`
each frame. `swallow-03` records one 96-point target receipt and two additional
four-point topiary receipts. This reviewer inspected the corrected helper,
complete strict-clean GPU log, and 35-frame/completion images. Normal measured
footprint admission now controls nearby objects as well as the target; bodies
overlapping the hole edge are not automatically considered fully admitted.
The staged level, fixed position, and disabled ordinary game controller remain
explicit limitations of this fixture.

The final `swallow-04` helper extends that explicitly staged path by six meters
while retaining the normal intake scan. Its clean actual receipt contains
seven unique player awards: one grand castle (96), four topiary (16 total),
and two flowerbeds (eight total), for 120 points. The target is still checked
for exactly one receipt. This resolves the presentation fixture while keeping
its movement/granted-level limitations explicit. The full GPU log is clean;
this is the selected dynamic evidence, with earlier captures preserved.

## Installed thumbnail and actual card

Root installed the art-approved `thumbnail-04/toys.png`. This reviewer
independently matched its raw and installed SHA-256:
`f92a4dcc9937d7db4e66e853cb8812e1c983b559af43ab59c030cdd9ac8e19ec`.
Its capture receipt identifies the actual Toy world, original evaluated Idle
poses, and a camera-only composition. The full capture log is clean.

The actual GPU carousel run in `ui-gpu-01` passes 574 checks with zero failures
and a strict-clean complete log. This reviewer inspected the installed Toy
card in both unlocked and locked/progress states: the same new castle image
is visible within the real UI, and locked status preserves the active City
selection. The other responsive/safe-area records are present in the report;
this is desktop layout evidence, not physical-phone validation.

Root has now frozen the candidate for the complete 98-suite source/package
gate. The current guarded set contains 1,342 inputs, including the final
dynamic capture helper. Both Windows and Web presets visible in the main
export file explicitly include the new raw Frost physics JSON. Actual package
availability and unchanged frozen inputs will be checked from the completed
gate, rather than inferred from this configuration edit.

## Final frozen release verification

This reviewer independently verified
`artifacts/royal-castle-20261008/web-gate-01/release.json`, SHA-256
`e1174c847489eb053141d4604a319b91c23aaa760e893607b9c2562d5d1b0a1d`.
All **1,342 current guarded input hashes** exactly match its frozen input map.
All **18 exported file hashes** match the installed preview at
`build/royal-castle-20261008/web`; there were no additional files at this
verification checkpoint. The tested and installed `index.pck` hashes to
`60750bb44a19a1f388449f9a1cb4267eb730e23f5e06b2eaa72142b2aea73297`.

Both phases contain exactly the current 98-suite set, with every minimum
satisfied and no failure entries:

| Phase | Suites | Passing checks | Complete stdout/engine logs |
| --- | ---: | ---: | ---: |
| Source | 98 | 176,870 | 196 |
| Exact exported PCK | 98 | 176,860 | 196 |

The only per-suite count difference is the expected Frost legacy test:
57 source checks versus 47 package checks. Its ten historical-source checks
require the deliberately unshipped baseline; every actual packaged-data and
world check remains enabled. The package verifies all 180 architecture owners
and 24 supported owners with empty extent, admission, rim, collider, support,
and visual issue lists. This demonstrates that the new raw physics JSON is
actually present and usable in the PCK, not merely listed in export settings.

All 392 complete suite logs pass an independent strict error scan with the
existing exact intentional `coin_skins` broken-config exception. A separate
scan finds no ObjectDB-instance or retained-resource leak markers. Both
complete export logs are clean. Auxiliary logs independently report 246 train
asset checks, 12 synthetic device-recorder checks, and 15 notice-packaging
tests passing. The recorder checks explicitly do not measure a real device.

Compared with the earlier accepted thumbnail release's guarded input map,
there are 26 differences: 17 changed entries and nine newly guarded entries,
with none removed. They are confined to the original castle assets/builder,
Toy ground/gardens and provider hooks, frozen Frost data/provider, Toy
thumbnail, export data inclusion, relevant fixtures, and release guarding.
An entry newly included in this guard set is not necessarily a newly created
file. The shared neighborhood plan, other-map art, game/save/economy rules,
UI logic, audio, purchases, and other existing guarded inputs remain
byte-identical. This does not hide the intentional 64-point increase in
available Toy garden inventory documented above.

Final package metrics remain bounded: 815 bodies, 876 mesh instances, 1,077
collision parts, 87 scaled-shape cache entries, 12 static mesh-cache entries,
and 17 actor mesh-cache entries. All 471 static bodies are reachable in the
score/admission planner, with zero blocked landmarks; ordinary-play evidence
remains the two separate 90-second runs, not that planner. No runtime blocker
remains for this local candidate.

This acceptance combines source review, independently checked asset/baseline
data, actual desktop GPU captures, normal automatic play, explicit swallow
fixtures, and exact-package evidence. It does not claim human playtesting,
varied-seed coverage, ordinary acquisition of the level-12 landmark, browser
or physical-phone frame performance, a replacement native build 34, or
changes to real user saves. Root's subsequent isolated browser smoke check is
separate evidence and must use this same PCK; a new production/source/package
change would require renewed review.
