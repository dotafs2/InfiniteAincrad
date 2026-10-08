# Snack Garden: dense food downtown — September 28, 2026

Version 0.5.1 addresses the user's report that the food map still felt sparse,
its color/style missed the references, and stacked food lacked a convincing
collapse. The previous 38 mostly isolated buildings and scattered small items
are replaced by twelve street blocks with **91 buildings, 15 heaps and 2,639
initial edible bodies**. This count includes 48 people and eight moving sushi
vehicles. There are 976 individually supported upper pieces.

## Art and layout

The reference direction remains [Hole Em All](https://apps.apple.com/gb/app/hole-em-all-black-hole-games/id6739246483)
and the user's [Cloudy with a Chance of Meatballs](https://www.sonypicturesanimation.com/projects/films/cloudy-chance-meatballs)
food-city premise. The store-image search shows strong frosting color groups,
repeated food towers and pyramids. This is a visual study, not a claim of exact
matching to the user's installed app version. No proprietary art is bundled.

- Strawberry, blue, grape and pistachio icing alternate across buildings and
  pile layers. Warm pastry, cream and chocolate retain distinct colors.
- Cool mint blocks, cream roads, pink curbs and wafer sidewalks separate the
  food colors from the ground instead of bathing everything in yellow/red.
- Square layer-cake apartments and wafer shops have repeated window fronts;
  burger and donut towers add round silhouettes. Heights span about 6.8–12.4 m.
- Large pyramids contain 59 independent food pieces each, including a central
  crown. Three starter heaps beside the opening use supports that a level-one
  hole can remove without needing to consume an entire neighbouring platform.
- Smooth sixteen-sided pastry cylinders and fourteen-segment small spheres
  improve the larger food silhouettes. Frosting and glossy material remain
  attached to each piece while it falls.

Measured ground-level food coverage in the twelve blocks is approximately
19–32 percent. This excludes the roads and upper layers; it is an occupancy
measure, not a whole-screen pixel-density claim. The map keeps the established
traffic lanes and pedestrian strips clear.

## Collapse behavior

The original support release called the normal swallowing admission method on
upper pieces. An oversized upper piece could therefore remain frozen after its
support disappeared. The new support-loss path always wakes that piece, even
when it cannot yet fit the mouth. It can land on the rim/ground and be eaten
later by a larger hole.

Direct children release after 75 ms, then notify their own children. Gravity,
contacts between food pieces and small fixed angular/lateral release motion
produce a cascade. The lateral release speed is 0.16 m/s and does not follow the
hole. Floor offsets provide uneven contacts. This is bounded arcade assistance,
not a material-fracture simulation. No food is resized, merged, teleported into
the mouth or scored merely for being released. Score requires a complete fall.

## Performance changes

32 cached meshes serve the food population. Static instances are partitioned
into 24 m cells (609 batches in the initial world), allowing ordinary frustum
culling instead of drawing every instance of a food type across the whole map.
609 is the total batch population, not an observed number of visible draw calls.
When a body is released, its batch slot keeps its original location with zero
scale so the batch bounds do not stretch back to the world origin.

An 8 m query grid replaces repeated whole-map swallowing/target scans on this
map. Released food, rain, people and sushi traffic move into a dynamic registry.
Growing-radius target searches retain a whole-map fallback. Acceptance compares
48 spatial queries and 12 nearest-target results with exhaustive searches.

The final CPU traces each contain 600 frames:

| Scenario | P50 | P95 | Worst | Frames above 16.67 ms |
| --- | ---: | ---: | ---: | ---: |
| Opening | 4.126 ms | 4.810 ms | 5.380 ms | 0 |
| Grown | 6.429 ms | 8.318 ms | 10.846 ms | 0 |

The raw traces are in `artifacts/food-downtown/opening-cpu.json` and
`grown-cpu.json`. They are fixed-60-Hz headless Mac traces; GPU work, browser
rendering and iPhone thermal behavior are excluded. iPhone 14 sustained 60 FPS
remains an unverified target.

## Acceptance and reproducibility

- Density/support/index acceptance: 1,069 checks, including all 976 upper-piece
  support links, all twelve block coverages, a real starter cascade, a 59-piece
  pyramid, four building types and an oversized unsupported roof.
- Each tested big-pile/building piece produces exactly one collection receipt.
  The stack visibly changes rigid-body orientation during the actual physics
  test. A lost support never leaves an oversized piece frozen in the air.
- The 39-check food/NPC/rain suite covers all ten rain foods landing and being
  swallowed. Portrait, road/pedestrian and no-tether regressions also pass.
- The guarded Web export now includes these food suites and a real food round
  in addition to the previous independent-object, lamp/sign, full-city,
  skin/navigation and skill suites, on source and on the exported PCK.
  Both pass 4,075 checks. The solo round completes with 427 points; the contested
  round ends eaten with 79 points. Neither round injects collection points.

Run `tools/release_web.py` for the packaged gate. `release.json` in the artifact
directory is authoritative for final source/package assertion totals and hashes.

The optional windowless renderer exports real food meshes and actual physics
poses using `tools/export_food_render_fixture.gd`, then draws them with
`tools/food_scene_offscreen.m`. Its images are layout/pose previews, not Godot or
browser screenshots. It approximates lighting and ground colors, omits NPCs,
UI, shadows and skin effects, and subdivides long ground triangles for the
Apple offline OpenGL rasterizer. The running game geometry is unchanged by
that helper. No blocked browser origin or foreground application is accessed.
