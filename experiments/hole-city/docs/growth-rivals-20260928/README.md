# Growth and rival swallowing — v0.8.3

The user reported a level-12 size ceiling, rivals that did not eat each other,
an inability to eat NPCs, and opponents that felt too strong. The old growth
table stopped at radius 14, while predation required 1.4 times the victim's
radius. A level-12 hole therefore could never eat a level-11 rival with radius
12. Rival steering also considered scene food only, and a ten-second global
gate disabled all hole predation at the start.

## Growth

The first twelve score thresholds and radii retain their previous values.
Later levels have increasing costs and keep increasing physical size. Level
13 starts at 1,600 points with radius 15.89; 5,000 points reaches level 19
and radius 23.92. The badge shows the actual next-level cost instead of the
former final-level denominator of one.

Physical radius gradually approaches 48 units, appropriate to the 160-unit
map. There is no new nearby gameplay level cap, but this is deliberately not
an infinitely expanding world. Integer score saturation and bounded level
lookup handle artificial extreme scores without negative overflow or millions
of iterations. [Equations and numeric validation](../growth-extension-20260928/README.md).

The camera retains its existing framing until the enlarged mouth needs more
space. It then preserves a margin based on the viewport aspect ratio and
adjusts the far plane, including during camera easing. Growth hints use the
extended level function; an unreachable size requirement reads `TOO LARGE`.

## Rival rules and difficulty

| Hunter → victim | Required radius ratio |
| --- | ---: |
| Player → AI | 1.15 |
| AI → AI | 1.20 |
| AI → player | 1.40 |

Passing the size gate is not enough: the smaller mouth must enter the larger
mouth. Predation runs at the physics step with bounded swept contact to avoid
missing fast crossings. Equal-sized rivals cannot eat each other. The first
ten seconds protect the player from being eaten; they do not prevent the
player or AI rivals from eating eligible AI victims.

Rivals can choose nearby smaller holes as targets while continuing to forage
and wait for released food to fall. AI base movement speed drops from 4.6 to
3.5, approximately 24% slower at equal size. AI score rewards become 70% of
their prior value, with fractional tenths carried between receipts so small
food still contributes. Player speed and rewards retain their existing rules.

Predation resolves largest first using a snapshot of that step's sizes and
scores. A victim becomes inactive before rewards are issued. Claims, pulls,
fall credit and pending food releases transfer to the surviving owner; late
collection callbacks resolve the same ownership chain. Repeated scans cannot
award an already retired victim. Restart clears the combat state. Persistent
stage, coins, skins, saves and the city completion target are unchanged.

## Acceptance scope

The pedestrian investigation uses real map residents, route movement, hole
movement, gravity, full-body descent and collection. Ten cases across both
maps pass 120 checks, including starter-sized holes and actual pursuit. No
pedestrian defect was reproduced, so that runtime was not changed.

The growth author suite passes 1,978 checks; combat author acceptance passes
58 checks, including enabled AI pursuit and swallowing at 30, 60 and 120 Hz.
The independent large-world suite passes 250 checks across both maps, center,
edge and corner positions, extended scores, actual ground raycasts and camera
frusta. An eight-mouth near-limit stress fixture covers the ground and then
verifies restoration. These are explicit fixtures, not natural long-term play
or a phone benchmark. The release gate also retains the prior physics, map,
skin, progression and selective-reveal suites.

Non-author [growth/combat review](independent-review.md) passes 291 checks,
including real player movement into a rival and two-hop ownership transfer.
The separate [camera/ground integration review](integration-review.md) passes
1,606 checks: actual SubViewport aspect changes, first-frame camera easing,
1,156 physics rays checked against an independent mouth-union oracle, and
reachable/unreachable growth hints. The reviewer who authored growth did not
certify that formula; the other reviewer independently checked it.

The first full gate also exposed an outdated goal-accounting fixture: it made
every hole inactive and then expected the retired player to collect food.
The new owner validation correctly rejected those receipts. The fixture now
uses a living player and a living, stationary rival placed out of combat range.
All 34 original goal assertions remain, with two explicit owner preconditions.
The 36-check suite passes; the runtime rejection rule was not weakened. The
failed gate is retained in `release-blocked-inactive-fixture/`.
The non-author reviewer independently passes those 36 checks and a 34-check
two-map receipt probe, including orphaned inactive owners, two-hop successor
ownership and post-result rejection. [Fixture review](../fixes/reviews/food-goals-fixture.md).

## Collision regression found by the final trace

The first final CPU run was rejected because food opening emitted two native
`_generate_contacts_edge_circle` contact-limit errors. A separate replay
reproduced both errors. The failed run remains in `cpu-blocked-cylinder/` and
the diagnostic baseline in `food-collision/`; neither is passing timing
evidence. The error filter was not relaxed.

Round food was the project's only native cylinder collision-shape path. It
now uses shared 16-sided convex prisms keyed by radius and height. Outer
radius, height, admission footprint, mesh and materials are retained; the
maximum radial inset between corners is approximately 1.922%. This changes
the collision calculation, not the visible food model. The same opening
replay then completed without the contact error.

A 32-sided candidate removed the diagnostic but increased persistent rocking
in the thin-food settling fixture. It was rejected. The 16-sided candidate
keeps a complete cap within the inspected solver's sixteen-support limit and
reduces that residual motion without changing friction or damping. The old
cylinder also shows bounded contact motion in this fixture; this is not a
claim that every resting rigid body is perfectly motionless.

The upstream [edge/circle contact helper](https://raw.githubusercontent.com/godotengine/godot/master/modules/godot_physics_3d/godot_collision_solver_3d_sat.cpp)
has a bounded contact buffer. The runtime diagnostic identifies that path;
the inspected upstream revision is not claimed identical to the installed
binary. This application workaround avoids that cylinder contact path; it
does not claim to repair every collision case inside the engine.

Independent pile testing then reproduced a thin bottom cookie passing through
solid ground in both the old package and the replacement. Ordinary round food
now checks its shared hull only while awake near the terrain. A deep-penetration
fallback requires actual current ground beneath both its center and lowest
point; entering a real opening disables that correction, so moving the hole
away cannot pull falling food back up. Normal contact torque remains under the
physics solver. Meshes, materials, friction and mass are unchanged.

The collision author passes 96 checks and the non-author review passes 16,168.
The review compares all 41 food meshes and their shader with the previous PCK,
verifies the complete collider population, and exercises ten rain ingredients,
a six-piece impact pile, a moving opening and partial rim support. Every target
piece needs its own full-descent collection receipt. Three seconds of measured
pose changes distinguish bounded contact jitter from continuous rotation;
the result is not a claim that every body becomes completely motionless.
[Collision implementation and rejected fixtures](food-collision.md).

## CPU sampling and remaining limits

All functional helper processes stopped before timing. One final 600-interval
trace per standard scenario covers 2,400 measured intervals with the reveal
controller active throughout and no native contact diagnostics. This is a
bounded regression sample, not a repeated statistical comparison with v0.8.2.

| Standard scenario | P95 CPU interval | Maximum | Intervals over 16.667 ms |
| --- | ---: | ---: | ---: |
| City opening | 8.345 ms | 35.257 ms | 3 / 600 |
| City grown | 7.976 ms | 9.914 ms | 0 / 600 |
| Food opening | 9.458 ms | 10.568 ms | 0 / 600 |
| Food grown | 11.757 ms | 15.075 ms | 0 / 600 |

The standard grown fixture isolates an existing enlarged scene and does not
keep the full ordinary game physics loop active. A separate stress probe
therefore starts the player through an actual 5,000-point award at level 19,
with seven active level-eight rivals. It suppresses only the normal food-goal
completion check so the sample can continue. Movement, combat, admission,
falling, food rain, collection, ground, camera and reveal remain active.

| Large-growth scenario | P95 CPU interval | Maximum | Intervals over 16.667 ms |
| --- | ---: | ---: | ---: |
| City | 7.590 ms | 9.139 ms | 0 / 600 |
| Food | 13.069 ms | 16.218 ms | 0 / 600 |

The measured food stress interval observes up to 205 dynamic bodies and 182
falling bodies at admission-scan cadence. It records 706 physical collections,
including 133 for the player, and one rival swallow. The player naturally
reaches level 20 during the run. The City sample records 350 collections,
including 50 for the player. An earlier completed sample of the same runtime
had materially larger outliers: food stress P95 18.134 ms, maximum 95.528 ms,
and 33/600 intervals above budget; City stress had five. Its standard City
opening also had 12/600 over budget and a maximum of 121.491 ms. Those results
remain in `cpu-before-goal-fixture/` and
`large-growth-probe/before-goal-fixture/`. Only the goal fixture and its gate
minimum changed between these samples. The second sample binds the final
test inputs, and is not evidence of a new runtime optimization. This observed
variation prevents a consistent-60-FPS claim. Instrumentation overhead is
included, while rendering and phone
thermal behavior are excluded. Raw ordered intervals, workload receipts,
source/engine hashes and limitations are retained in the
[large-growth probe](../../artifacts/growth-rivals-20260928/large-growth-probe/final/README.md)
and the standard `artifacts/growth-rivals-20260928/cpu/` reports.

## Final local delivery — 2026-09-29

All 45 suites pass against source and the isolated exported PCK, with 32,070
checks in each phase. No unexpected engine errors were accepted. The final
verifier binds the current source, final 2,400-interval standard CPU sample,
all ten HTTP-served files and WebAssembly isolation headers to version 0.8.3.
The separate 1,200-interval large-growth workload and both earlier timing sets
remain available with raw measurements and exact source manifests.

Shader files were unchanged. The 41-case, ten-program v0.8.2 isolated-shader
receipt was reused only after all eight shader/tool input hashes matched;
`shader-probe-final/reuse.json` records that this was not a new shader run.
The failed cylinder profile, rejected physical prototypes, failed goal fixture
and subsequent independent reviews are preserved beside the successful gate.

The local preview now serves v0.8.3. Existing tabs need a reload and a new
round. PCK SHA-256:
`8d7146294219af06ad467873181533d52ccb2e4ee3031588a60071f4550ad847`.
The final receipt is
[verification.json](../../artifacts/growth-rivals-20260928/verification.json).
All owned test/helper processes have exited; the user's preview server remains
running. No Git commit or push was performed.

The browser's previously saved permission setting blocks the local preview.
No alternate browser surface or indirect capture was used. Headless checks
do not establish browser appearance, iPhone GPU performance or sustained
60 FPS. Player saves, unrelated resident worlds and reference applications
remain untouched; no Git publication was requested.
