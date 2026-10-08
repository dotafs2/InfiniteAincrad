# Snack City, food rain and bubble UI

## Player-visible changes

Snack Garden now starts with 1,096 edible bodies: 1,048 food objects and 48
animated chefs/couriers. There are 38 food buildings made from stacked cake,
burger, pancake and donut floors, edible roof toppings, cookie doors and
chocolate windows. Smaller snacks fill the surrounding streets. The existing
Sunny City remains selectable.

Food rain cycles through ten original shapes: bacon, fried egg, cake, donut,
burger, cookie, strawberry, sushi, pancake and pizza. Six pieces enter near the
player every 2.4 seconds when capacity permits. At most 24 airborne and 96 total
rain objects exist at once. A piece awards points only after a complete fall
into a hole. Unclaimed pieces remain on the ground or physical food roofs.

Buildings are real layered objects. A lower floor protects its upper floors;
swallowing or pulling that support releases the supported stack to gravity.
All original food appearance remains attached while the layers fall.

The home screen, map buttons, pause/results, collection cards and gameplay HUD
use round bubble shapes, a purple-to-cyan backdrop, white rims and soft shadows.
The main action is PLAY. Fredoka supplies rounded lettering, with its OFL notice
included in the export. The food palette uses strawberry red, frosting pink,
egg-yolk yellow, lettuce green and golden pastry. The instanced material decodes
the authored sRGB colors, avoiding the previous washed-out primitive colors;
neutral lighting and moderate highlights replace tinted, matte presentation.

## NPC and collision repair

Pedestrian collision now covers the body rather than a broad box around held
props. A capsule with a 0.23 m radius and a 0.26 m eligibility footprint fits
the initial 0.85 m hole. A pedestrian already above an opening releases to
physics before the route controller can take another fleeing step. The normal
food scan and below-ground scoring stay authoritative.

Thin falling food exposed triangle-surface contact loss despite engine CCD.
Rain uses a 5.5 m/s downward terminal-speed cap and a swept foot ray against the
actual collision world. An actual supporting surface stops penetration; a real
hole returns no support. This adds no attraction toward a hole, no automatic
score and no invisible floor. Ten-kind landing-then-eating acceptance exercises
both sides of that boundary.

## Rendering and performance

Fourteen cached meshes cover the ten foods and four building variants. Static
food uses fourteen MultiMesh batches, while a released object switches to its
individual shared mesh. Moving sushi traffic and active rain keep their real
transforms. Runtime scans remove expired rain handles, and emission is limited
to active play. Restart discards the previous rain population.

The headless Mac traces use 600 measured frames at fixed 60 Hz physics:

| Scenario | P50 CPU ms | P95 CPU ms | Worst CPU ms | Over 16.67 ms |
| --- | ---: | ---: | ---: | ---: |
| Opening, rain active | 4.096 | 11.885 | 12.921 | 0 / 600 |
| Eight grown holes, rain active | 4.670 | 11.497 | 29.723 | 1 / 600 |

These exclude GPU work, browser rendering, thermal behavior and iPhone hardware.
They do not establish sustained iPhone 14 60 FPS. The final grown trace contains
one 29.723 ms outlier; its cause is not isolated by this aggregate trace.

## Acceptance

`artifacts/snack-city/final-validation.json` combines the final scene-level
checks: eight suites and 191 assertions pass. The dedicated 39-check suite validates initial-size NPC swallowing,
protected/released building tiers, ten physical rain landings and subsequent
collection, emission bounds, reset, typeface and rounded button styling. The
same suite also runs against the exported PCK.

Both maps complete actual movement/physics rounds with seven rivals and in
isolated reachability fixtures. In the food map, contested play completes at
420 points in 105.48 simulation seconds; isolated play completes at 422 points
in 87.67 seconds in the packaged runtime, with rain active. No completion points are injected in those
fixtures.

The previously saved browser denial has not been reported cleared. No attempt
was made to bypass it through another browser surface. This turn establishes
runtime, geometry, collision, UI interaction and package evidence; rendered
visual review and physical-device acceptance remain open. Refresh the existing
local page at `http://127.0.0.1:8768/` to load the new package.

## Design references and provenance

The prior Hole.io observation ledger supplies the casual city-game context.
The food-city/food-rain premise follows the user's Cloudy with a Chance of
Meatballs direction. Public [Hole Them All store screenshots, reproduced by
MWM](https://mwm.ai/apps/hole-them-all/6746115965) were consulted for dense food
arrangements and bright color separation. This is a design direction, not a
claim of frame-by-frame visual matching to the user's locally installed games.
All food meshes, rain behavior and UI shapes here are original code-authored
assets. [Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka) is the
only newly bundled third-party visual asset, under SIL OFL 1.1.
