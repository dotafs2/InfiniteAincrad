# Independent rail corridor feasibility

A read-only actual-scene probe evaluated both existing maps before train
integration. It kept all authored scenery, the existing eight traffic actors
and the current pedestrian positions. It disabled gameplay movement, rain and
holes only while measuring the candidate corridors; no scene objects were
removed. The engine ran with `--test`, without browser access or save edits.

Recommended routes:

- **Sunny Blocks:** a closed rounded square with extent ±84.4 m and 4 m corner
  radius. Candidate bypass center offsets are ±1.6 m. The sampled loop length
  is 668.315 m.
- **Snack Garden:** concatenate the existing outer road polylines for node
  cycle 12 → 13 → 14 → 15 → 16 → 17 → 18 → 19 → 12, preserving their authored
  sampled curvature. Candidate bypass offsets are ±1.35 m. The loop length is
  609.324 m.

Each route was scanned at center and both bypass offsets with at most 0.6 m
between samples. A real physics box query includes layers 1 and 2, excluding
only the ground body's RID. The box includes 0.1 m additional space on every
horizontal side beyond the proposed asset contract: 1.25 × 2.15 m light rail
and 1.05 × 1.55 m sushi. Height is 1.5 m. Separate geometric checks compare
nine points across each oriented box with the actual road predicate and the
full authored pedestrian corridors, rather than just current pedestrian poses.

| Route | Samples per offset | Road footprint points per offset | Scene blockers | Points outside road | Pedestrian-corridor overlaps |
| --- | ---: | ---: | ---: | ---: | ---: |
| City 84.4 / radius 4 | 1,124 | 10,116 | 0 | 0 | 0 |
| Food outer loop | 1,165 | 10,485 | 0 | 0 | 0 |

The original city radius-6 proposal passed center-only checks but its inward
bypass put 36 of 10,224 footprint points outside the road. That result is
preserved. A radius-4.5 alternative also passed, but the final recommendation
uses the parent's requested 84.4 / radius-4 geometry. The city inner loop hits
existing cars and bins; the food main loop hits existing sushi traffic.
Choosing the outer loops avoids removing or rerouting those existing systems.

## Tail parking and bypass requirements

A detached tail should retain its exact world transforms and ordinary collision
bodies. The surviving head and its remaining cars can use a smooth lateral
bypass on their next approach, then return to the primary track. The change
must begin ahead of the head, and followers must replay the head's actual
world-space path rather than abruptly applying the new offset to every car.
Both sides have demonstrated static clearance, but each chosen transition
still needs real scene collision checks.

Same-train collision is a separate requirement: excluding coupled cars from
world queries cannot prove that they do not overlap each other. The city inner
bypass has tighter curvature. With the nominal rail dimensions, a constant
0.30 m gap between adjacent car lengths may cause oriented-box overlap there.
The controller author was notified to check actual imported model bounds and
adjust spacing or curvature. Final independent integration acceptance must
check neighboring and non-neighboring car footprints through those bends.

Rail markings should be part of the ground appearance or noncolliding visuals;
they must not add a support floor across an opened hole. Visible rail marks
also need the same hole cutout so rails do not appear suspended over the mouth.

## Scope and evidence

This is discrete route feasibility, not a continuous swept-volume proof or
future dynamic obstacle guarantee. Rain, newly released food and actors may
subsequently enter the route. The controller must stop or safely avoid actual
occupied space. At this route-only checkpoint, train integration, individual
swallowing, head/middle cuts, return laps, pause/lifecycle behavior and actual
model import awaited separate acceptance. The subsequent
[integrated independent review](independent-review.md) passes 388 checks of
those behaviors using the installed routes and real imported cars.

Evidence is in `artifacts/trains-20260929/`:

- `route_probe.gd`: independent scene query helper.
- `route-probe-final.{json,log}`: final results with strict clean engine output.
- `route-probe-inputs.json`: reviewed map/helper hashes.
- `route-probe-center-only.json` and `route-probe-footprints.json`: earlier
  candidates, including the radius-6 inward-corner discrepancy.

All owned route-probe helpers exited. These results do not claim browser
appearance, phone performance or a recorded gameplay capture.
