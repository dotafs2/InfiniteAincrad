# Larger connected maps

Both maps now use a physical 200 × 200 m ground slab and a 192 × 192 m player-center movement area, through `fidelity/world_bounds.gd`. The previous dimensions were 160 × 160 and 152 × 152 m. Ground area increases 56.25%; playable area increases approximately 59.6%. Existing objects retain their physical sizes and the map nodes retain unit scale.

## Sunny City

An avenue at ±84 m joins all four existing avenue axes. Its paint and `StreetLayout.on_road` share the same outer-road center and width. Twenty-four additional houses face this avenue across the four sides of the world, accompanied by 128 individually edible bins, cones, bollards, benches and small plants. The total addition is **152 bodies**, below the 200-body budget.

The original 48 building parcels, 208 catalog assets, four pedestrian loops, 64 residents and eight moving vehicles remain. The new houses reuse existing building meshes/materials and fracture resources; new static street objects enter the existing batching/index path. Added frontage is connected to the old street network, rather than being a separate decorative island. The outer avenue does not add a new vehicle fleet or replace the established moving-traffic paths.

Only new outer furniture may use the expanded placement-repair bounds. Original furniture repair remains limited to its previous area. The city foundation beneath the cut slab expands to the shared bounds plus its existing two-metre border.

## Snack Garden

The authored food plan grows from 15 to 27 road sections and from 12 to 20 junction nodes. Eight curved Sugar Promenade sections form the outer loop. Four connectors join it to the original boulevard. Connector paths avoid existing building and heap envelopes; new intersections clip affected walking runs instead of directing pedestrians through the roads or buildings. The resulting 60 walking routes remain clear of traffic and all reserved building/heap envelopes.

The extension adds four named districts, **24 buildings with 96 individual tiers/toppers**, **two heaps with 118 independent foods**, and **120 small ground foods**: **334 additional edible bodies**, below the 450-body budget. The full map contains 160 food buildings, 14 large heaps plus the three unchanged opening heaps, 1,080 authored loose foods, and 2,922 initial edible bodies including existing residents and vehicles. The normal builder, support relationships, collision meshes and shared food batches build these additions; no new gameplay food-system implementation is introduced.

All original 136 building positions, dimensions, ingredient kinds, layer counts, flavors and families remain. Doors are reoriented toward the retained walking paths. Thirty-four original loose snacks that intersect a new connector/walk corridor are relocated into nearby clear spaces. Both prior traffic routes remain byte-equivalent in the generated plan, with the same eight moving vehicles; the resident count stays at 48. The new road network has approximately 74.0% curved/diagonal segment length under the existing alignment criterion.

The atlas stays **2048 × 2048**, with the same full mip chain and import recipe. Its world-to-texture mapping now covers ±100 m through the shared bounds, so the new area receives actual streets and paths. No food shader, ingredient palette, glaze or model size is changed by this map work. The food foundation's shared-bounds integration is owned separately by the main game integrator.

## Evidence and retained baselines

The [input manifest](../../artifacts/world-expansion-20260929/author/manifest.json) records the owned source/asset/test hashes and test receipts. [Pre-change copies](../../artifacts/world-expansion-20260929/before/) retain all 13 modified existing map, generator, atlas and test inputs. [Plan validation](../../artifacts/world-expansion-20260929/author/plan-validation.json) checks deterministic generation, connected junctions, clear road/walk envelopes, preserved traffic, original building dimensions, and the new-object budget.

| Focused strict headless suite | Checks | Result |
| --- | ---: | --- |
| Actual expanded terrain and collection | 57 | Pass |
| City districts, building footprints and circulation | 2,718 | Pass |
| Food frontage, route painting, clearance and vehicles | 323 | Pass |
| Imported atlas filtering and mip chain | 27 | Pass |

The new scene test observes 152 city and 267 food edible bodies outside the old ±80 m boundary, distributed across all four quadrants. Those outer bodies begin frozen. It tests physical ground at ±99 m, absence beyond ±101 m, a real outer-mouth cut, production `scan_food` collection with a score receipt, and restoration after the mouth closes on both maps. The first fixture incorrectly selected a supported small rooftop decoration for its loose-ground-food check; the corrected fixture explicitly selects non-tower/non-heap food. The failed receipt is retained, and no runtime support or falling behavior was bypassed.

Three old tests receive only requirement-specific updates: the city building total now includes the 24 extra houses; food-atlas pixel queries use the shared world coordinates; the atlas color pin binds the newly generated enlarged map rather than requiring the old map's pixels. All road-clearance, traffic-lap, corner-footprint, facing, mip-count and geometry-budget assertions remain. The new atlas base RGB SHA is:

```text
eb8e2ad7928dc0d98ed4a26d23ca1f3416f32e04f5aae5851281afc9760212ae
```

Its encoded PNG SHA is `075391fb1757802e8b8432c293eff55a8d5825f8c33204913df74593d09b0668`; the generated plan SHA is `fe423b06124614186db021691322b43f3765e9f399c285016ffca631d0d1c9b7`.

These are functional headless checks, not browser appearance or phone-performance measurements. More populated area adds potential workload even though the added objects are bounded and use existing frozen/batched paths. No claim of sustained iPhone 14 60 FPS is made. Independent review, integration checks and the complete source/exported-package release gate remain separate. No browser/native capture, Git publication or preview deployment was performed by this unit.
