# Larger connected maps

Both maps now use a physical 200 × 200 m ground slab and a 192 × 192 m player-center movement area, through `fidelity/world_bounds.gd`. The previous dimensions were 160 × 160 and 152 × 152 m. Ground area increases 56.25%; playable area increases approximately 59.6%. Existing objects retain their physical sizes and the map nodes retain unit scale.

## Sunny City

An avenue at ±84 m joins all four existing avenue axes. Its paint and `StreetLayout.on_road` share the same outer-road center and width. Twenty-four additional houses face this avenue across the four sides of the world, accompanied by 128 individually edible bins, cones, bollards, benches and small plants. The total addition is **152 bodies**, below the 200-body budget.

The original 48 building parcels, 208 catalog assets, four pedestrian loops, 64 residents and eight moving vehicles remain. The new houses reuse existing building meshes/materials and fracture resources; new static street objects enter the existing batching/index path. Added frontage is connected to the old street network, rather than being a separate decorative island. The outer avenue does not add a new vehicle fleet or replace the established moving-traffic paths.

Only new outer furniture may use the expanded placement-repair bounds. Original furniture repair remains limited to its previous area. The city foundation beneath the cut slab expands to the shared bounds plus its existing two-metre border.

## Snack Garden

The authored food plan grows from 15 to 27 road sections and from 12 to 20 junction nodes. Eight curved Sugar Promenade sections form the outer loop. Four connectors join it to the original boulevard. Connector paths avoid existing building and heap envelopes; new intersections clip affected walking runs instead of directing pedestrians through the roads or buildings. The resulting 60 walking routes remain clear of traffic and all reserved building/heap envelopes.

The extension adds four named districts, **24 buildings with 96 individual tiers/toppers**, **two heaps with 118 independent foods**, and **120 ground foods**: **334 additional edible bodies**, below the 450-body budget. The full map contains 160 food buildings, 14 large heaps plus the three unchanged opening heaps, 1,080 authored loose foods, and 2,922 initial edible bodies including existing residents and vehicles. The normal builder, support relationships, collision meshes and shared food batches build these additions; no new gameplay food-system implementation is introduced.

The complete release gate rejected the first perimeter layout as genuinely too sparse: its four districts had only 2.52%, 1.54%, 2.48% and 1.84% occupied ground. The unchanged density test requires at least 12% in every district. The final layout corrects the physical content without shrinking district polygons, changing the threshold or adding bodies. The 24 new frontages now use varied 2.667–4.2 scale factors, with corresponding real collider dimensions and separate supported tiers. Their actual highest point is 15.670 m, below the 18 m minimum rain spawn height. The 120 loose foods comprise 64 food-plaza ingredients, 32 medium foods and 24 small starter foods. Each perimeter district retains six foods that the ordinary level-one hole can actually swallow.

New placement uses conservative recipe-specific circular envelopes, including the full bacon/sushi rectangle diagonals and berry leaves, against roads, sidewalks, original food and previously placed new food. Ground-root convex collision footprints were independently checked for interpenetration. Final occupied-ground ratios in the unchanged full district polygons are **16.96%, 23.08%, 19.25% and 28.26%**. The original seven districts continue to pass. All 34 shared mesh recipes and all body/tier counts remain unchanged from the initial expansion, so the denser layout retains 572,812 extension triangles and 4,961,996 total food-scene triangles before culling. These are geometry budgets, not frame-rate measurements.

All original 136 building positions, dimensions, ingredient kinds, layer counts, flavors and families remain. Doors are reoriented toward the retained walking paths. Thirty-four original loose snacks that intersect a new connector/walk corridor are relocated into nearby clear spaces. Both prior traffic routes remain byte-equivalent in the generated plan, with the same eight moving vehicles; the resident count stays at 48. The new road network has approximately 74.0% curved/diagonal segment length under the existing alignment criterion.

The atlas stays **2048 × 2048**, with the same full mip chain and import recipe. Its world-to-texture mapping now covers ±100 m through the shared bounds, so the new area receives actual streets and paths. No food shader, ingredient palette, glaze or cached recipe geometry is changed by this map work. Only newly added perimeter foods receive the larger physical scales described above. The food foundation and perimeter rain's shared-bounds integration are owned separately by the main game integrator.

## Evidence and retained baselines

The [initial expansion manifest](../../artifacts/world-expansion-20260929/author/manifest.json) and [pre-change copies](../../artifacts/world-expansion-20260929/before/) preserve the first implementation and its focused receipts. The [final density-correction manifest](../../artifacts/world-expansion-20260929/density-correction/manifest.json) binds the current generator, plan, atlas and author tests. Its [plan comparison](../../artifacts/world-expansion-20260929/density-correction/plan-validation.json) verifies exact preservation of the first 136 plots, 960 prior loose-food records, all road/walk/traffic paths and all district polygons, plus deterministic regeneration and unchanged extension recipes/tier counts. The rejected sparse layout and the intermediate berry-envelope failure remain recorded separately.

| Focused strict headless suite | Checks | Result |
| --- | ---: | --- |
| Actual expanded terrain and collection | 57 | Pass |
| City districts, building footprints and circulation | 2,718 | Pass |
| Food frontage, route painting, clearance and vehicles | 323 | Pass |
| Imported atlas filtering and mip chain | 27 | Pass |
| Enlarged perimeter footprints, support, clearance and starter accessibility | 630 | Pass |

The final scene test observes 152 city and 237 food edible bodies outside the old ±80 m boundary, distributed across all four quadrants. Those outer bodies begin frozen. It tests physical ground at ±99 m, absence beyond ±101 m, a real outer-mouth cut, production `scan_food` collection with a score receipt, and restoration after the mouth closes on both maps. The first fixture incorrectly selected a supported small rooftop decoration for its loose-ground-food check; the corrected fixture explicitly selects non-tower/non-heap food. The failed receipt is retained, and no runtime support or falling behavior was bypassed.

Independent final-plan checks include the unchanged full density/cascade suite (**1,331 passes**), the geometry/ingredient-finish budget suite (**132 passes**), and [enlarged-food/perimeter-rain physics review](food-physics-review.md) (**189 passes**). The physics review tests actual enlarged food contact, ordinary growth admission, separate falling tiers, unique collection receipts and reachable rain at the new edges; it changes no runtime behavior.

Three old tests receive only requirement-specific updates: the city building total now includes the 24 extra houses; food-atlas pixel queries use the shared world coordinates; the atlas color pin binds the newly generated enlarged map rather than requiring the old map's pixels. All road-clearance, traffic-lap, corner-footprint, facing, mip-count and geometry-budget assertions remain. The new atlas base RGB SHA is:

```text
e8ec9250f323a4206c152b04f489d6a1b2e7e75f4e57e3f734799b9cd55e32ed
```

Its encoded PNG SHA is `e2b1c3d2f40a777cc5123eed9449a064a31459f8349079ff448094d028db36cb`; the generated plan SHA is `86decaffa2e1385d118033d2304e1e490727f79d09be51bf7f1c980ebd10eda0`.

These are functional headless checks, not browser appearance or phone-performance measurements. More populated area adds potential workload even though the added objects are bounded and use existing frozen/batched paths. No claim of sustained iPhone 14 60 FPS is made. Independent review and integration receipts are separate from the complete source/exported-package release gate. The failed first gate remains preserved; the final gate is owned by the main integrator. No browser/native capture, Git publication or preview deployment was performed by this unit.
