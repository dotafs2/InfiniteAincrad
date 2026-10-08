# A connected food-city street network — September 28, 2026

Version 0.5.4 fixes the retained nine-cell skeleton. Version 0.5.3 curved the
local walks but left two horizontal and two vertical vehicle avenues across
the whole map; its overall composition therefore remained a grid.

The food map now has a continuous curved boulevard, an oblique commercial
street and two branching avenues. Fifteen road segments join twelve actual
nodes, including six branching junctions. Seven unequal polygonal neighborhoods
replace rectangular placement regions. There are no full-map Cartesian trunks;
85.5% of road length has a non-axis-aligned heading.

The same authored plan drives paving, sidewalk boundaries, building frontage
and vehicle motion. Thirty-five sidewalk and market paths stop before live
carriageways. All 48 citizens use those paths for normal and panic movement.
Eight sushi vehicles follow an arc-length lane around the boulevard, retaining
physical footprint separation and continuous movement through its seam. The
branch avenues are connected streets but do not yet carry separate car routes.
Sunny City's established traffic behavior is retained in its own implementation.

The scene contains 136 food buildings, nine height landmarks, 15 independently
collapsing heaps, 960 loose snacks and 2,594 initial physical edibles. The 1,115
upper pieces each retain a separate body and explicit support. Food covers
15.7–17.8% of buildable ground in each polygonal neighborhood. Rounded geometry,
ingredient highlights, food rain and original falling materials remain enabled.
An initial 4,518,564-triangle candidate exceeded the existing 4.5M geometry cap.
Capping ordinary burger housing at five floors reduced the final population to
4,443,584 triangles without removing buildings, heaps, landmarks or loose food.

The network suite verifies connected junctions, road bearings, painted sidewalk
agreement, frontage, full building/heap clearance and full car footprints on
curves. It runs 320 simulated seconds of traffic: 17 completed laps and 6,600 m
of aggregate motion without teleports or overlapping vehicle bounds. A minute
of normal/panic pedestrian movement remains inside pedestrian corridors.
A grown-hole stress run additionally found a released-node access in vehicle
updates. Route records can retain a vehicle after physical collection; checking
validity before the typed assignment fixes it. Regression now physically eats
a sushi car and verifies that the next car continues moving. The network suite
has 237 checks. The density suite checks individual support links, a 59-piece pyramid, four
building recipes, starter cascades and oversized unsupported pieces.

A normal solo round completes at 420 points. The contested demonstration ends
legitimately when an opponent consumes the player at 51 points; it is not
reported as a win. No collection score is injected into either full-round test.

The release gate hashes source inputs before acceptance and checks those hashes
before export and before replacing the preview. Editing a runtime input or test
while QA runs now rejects delivery instead of mixing results from different
revisions. Rebuilding the plan and atlas in a temporary directory reproduces
identical JSON content and PNG bytes. Exact final checks and build hashes are
recorded in `artifacts/food-street-network/release.json`.

`districts.png` and `opening.png` in that evidence directory use actual food
meshes, transforms, the authored atlas and the shipped glaze equations in the
windowless renderer. Final lighting is approximate; NPCs, UI and contact shadows
are omitted. These are not Godot/browser screenshots. Browser visual acceptance
and physical iPhone 14 GPU/thermal measurements remain open.

Final isolated headless Mac CPU traces contain 600 samples each. Opening
P50/P95/worst is 4.326/5.042/7.727 ms; grown is 6.319/8.347/11.141 ms. Neither
trace exceeds 16.67 ms; both are free of GDScript exceptions after the vehicle
fix. GPU work is excluded, so these timings do not prove phone FPS.

The opening trace also records one native Godot SAT contact-limit diagnostic
(`num_points >= max_clip`), retained in `opening-cpu.log`. Its engine-level cause
has not been resolved. The physical collection/collapse acceptance assertions
pass, but this diagnostic remains an explicit follow-up for collision stress QA.

Final source and exported-package acceptance each pass **4,584 checks**.
The delivered PCK SHA-256 is `e45e9e0fbc679b2676e7be0650ca85421bae041897c9e8f45afe313254dbb989`.
