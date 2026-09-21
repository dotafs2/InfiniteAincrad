# Town of Beginnings reference and expansion baseline

This document separates source-backed Aincrad facts from adaptation references and
our original production layout. It is a visual and spatial brief, not a claim that
the project has reproduced a licensed map.

## What the references support

The first floor is described as a roughly 10 km diameter circular floor. The Town
of Beginnings is at the southern edge, a walled fortified city with a semicircular
main district of roughly 1 km diameter. The same first-floor reference places a
large central plaza, the Black Iron Palace, a church, a market area, villages,
forest, meadow, wetlands/lake areas, ruins and a northern labyrinth zone on the
floor. The accessible first-floor diagram is a secondary reconstruction, so its
exact angles and distances are not authoritative.

Source map and notes: <https://w.atwiki.jp/saop/pages/13.html> · direct map image:
<https://img.atwiki.jp/saop/attach/13/141/aincrad01_rev4.png>.

The official Aincrad episode pages establish the first-floor setting and the
Beginning City as a story location, including the later visit in episode 12:
<https://www.swordart-online.net/aincrad/story/12.html>.

The official *Hollow Realization* world page is useful as a **game-adaptation
visual study**. It divides its Beginning City into a teleport-gate plaza, a
market street, a lakeside park and a scenic overlook. Its images show paved
surfaces, a fountain, arcades, walls, lamps, planted edges, stalls and a large
amount of open public space:
<https://hr.sao-game.jp/system/world/town.html>. These four zones are not proof of
the original novel's exact street plan.

## Why our current town feels too small

The current scene is a compact living quarter with an orderly road graph. It is a
good resident-life test area, but it reads as one neighbourhood: most destinations
are visible at once, streets have few secondary branches, and the surrounding
first-floor geography is absent. It should remain as the first loaded district,
not be stretched until it pretends to be the whole city.

## Proposed production scale

Use three nested scales so the world becomes larger without making every building
and collision expensive at once:

1. **Floor macro map:** a 10 km-diameter abstract first-floor graph. The southern
   city, western forest/village route, central meadow and wetlands, eastern ruins,
   and northern labyrinth are distinct streamed regions. Distant regions are
   terrain silhouettes and route anchors until entered.
2. **City shell:** a walled, semicircular 1 km reference footprint. The first
   playable build can use a 300–500 m authored core with a convincing wall, gates,
   outer ring and blocked/streamed quarters; the scale declaration must remain
   explicit instead of calling it a full 1 km simulation.
3. **Resident district:** the existing 16-house living quarter becomes one irregular
   residential/workshop district inside the shell. Its NPC contracts, homes and
   food loop remain intact while other quarters are added around it.

## Original city layout for the next PCG pass

The following is our project layout, informed by the references but not presented
as canon:

- **Central Plaza:** circular stone space, transfer gate, bell/clock landmark,
  radial alleys and a large open crowd buffer.
- **Palace approach:** a long, slightly offset ceremonial route from the plaza to
  the domed Black Iron Palace silhouette. Keep the palace visually dominant and
  mostly non-residential.
- **Market and craft belt:** two market streets, covered stalls, inns, smiths,
  storage yards and narrow service lanes. Give each street a different width and
  bend so the graph does not look like a grid.
- **Church and care quarter:** a quieter irregular block with a small yard, school/
  shelter-like interiors and a route back to the market. Treat the child-resident
  material as a source-backed story reference, while our named residents remain
  original.
- **Residential rings:** three density bands with crooked lanes, courtyards,
  gardens, retaining walls and a few unfinished plots. Houses should be grouped
  by block rather than placed as a regular matrix.
- **Wall and gates:** a continuous fortified edge with unequal gate approaches,
  guard towers, loading paths and a visible south-field transition.
- **Outer field anchors:** the city gates point to the macro regions; they do not
  instantly place a resident at a remote destination. The existing fixed route
  executor and arrival receipts remain authoritative.

## PCG and art rules

- Keep the route graph generated from the same authored roads that render the
  streets. Add junctions, alleys, courtyards, service lanes and dead ends as graph
  regions with stable IDs; do not hand-author a second navigation map.
- Use a radial-but-imperfect street grammar: a few plaza spokes, two or three
  offset ring roads, irregular cross-links and cul-de-sacs. Seed the generator and
  persist the seed with the layout.
- Separate visual density from simulation density. Far buildings can be shell
  meshes; only loaded districts receive resident interiors, interaction points and
  collision detail.
- First asset sheet: wall segment/gatehouse/tower, plaza fountain and bell tower,
  palace dome, market awning/stall, inn facade, smith/workshop, church, courtyard
  props, carts, lamps, signs and three house families. Create variants from one
  coherent material palette before adding more professions.
- Treat the reference images as composition and material studies. Do not copy the
  map image or extract licensed game assets into the repository; generate original
  geometry and record provenance for every external asset.

## Acceptance for the next expansion

The next map milestone is complete when a fresh seed produces at least four city
quarters, two unequal gate approaches and one outer-field route; the loaded route
graph reports every rendered road junction; ten residents can still cold-restore
and walk between their current homes and the existing life district; and the
existing food/material/contract reducers pass without changing world history.

This milestone expands spatial and visual variety. It does not claim a precise
licensed map, a complete first-floor simulation, or collision-perfect movement in
the outer regions.
