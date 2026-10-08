# Fairytale city QA

Status: the final assembled-block source cohort passes 3,144 checks after
preserved failures and the documented corrections below. No GPU capture, native, device, purchase or
account operation has been run by this reviewer. The accepted October 3 toy map
remains historical evidence; it does not accept these changes.

## Diagnosis from the starting baseline

The existing toy shader already uses GGX specular, clearcoat and two small
view-dependent painted highlights. Describing it as a purely diffuse shader
would be inaccurate. Its broad clearcoat roughness (0.40), modest coat amount
(0.22), muted toy sun (0.64) and color-only environment provide little reflected
detail for a glazed roof. The reviewed game setup assigns no sky. The painted
highlights cannot reproduce a varied reflected environment.

Godot can source reflected light from a sky while retaining a solid-color
background. Screen-space reflections are unavailable in the project's
Compatibility renderer, so SSR is not an appropriate fix. A small procedural
sky/reflection source, suitable material response and intact directional shadows
are a bounded route to test. These are candidate causes, not a rendered verdict.
See the primary [Environment reference](https://docs.godotengine.org/en/4.6/classes/class_environment.html)
and [environment guide](https://docs.godotengine.org/en/4.5/tutorials/3d/environment_and_post_processing.html).

The current map already has nine edible tiers, varied model heights and genuine
late castles. Its four central districts repeat the same mirrored castle/tower
recipe, and the castle vocabulary contains two main silhouettes stretched to
different scales. A sparse repeated silhouette can read as a flat toy layout
despite a numerically tall skyline. New authored roof forms, street houses and
irregular frontage are needed alongside lighting changes.

## Runtime and package boundaries

- The proposed `FairytaleMeshes` provider replaces five existing architectural
  kind IDs and retains the ToyShapes mesh, material and collider API. Each kind
  must have distinct actual geometry, unit bounds, finite normals and opaque
  colors. Palette variants must share geometry and colliders.
- ToyCity caches its unit geometry by kind and scaled physics shapes by kind and
  size. Different silhouettes must not silently reuse one kind's cache entry.
  A runtime object must use its actual authored mesh and matching colliders;
  metadata alone is insufficient.
- Dynamic JSON payloads in a new folder need explicit inclusion in both Web
  export presets and the generated iOS preset. Existing includes cover the old
  city, actor, train and audio folders only. These includes are now updated.
  The author's saved `.blend` is under `assets/fairytale_castles/source/` with
  `.gdignore`; explicit preset exclusions also preserve that source directory
  outside runtime packages. Ship a compact
  provenance manifest and the geometry payload needed by the runtime loader.
- Preserve the existing map IDs, old saves, the whole-body fall, unique reveal
  materials, 90-second starting Toy round and one 30-second continuation. The new
  economy work is independently owned and must not be accepted using old payouts.

## Focused acceptance

`tests/fairytale_city_acceptance.gd` is the new independent suite. Its output
marker is `FAIRYTALE_CITY_ACCEPTANCE`; its measured minimum is now 169 checks.

Geometry checks inspect all five authored kinds: actual indexed triangles,
closed welded boundaries, nondegenerate faces, normalized finite normals,
normalized bounds, distinct geometry signatures, cache reuse, palette equality,
fresh collider copies and declared provenance. Current proposed triangle budgets
are 12,000 for the regular castle, 12,000 for the grand castle, 2,500 for the arch
and 6,000 for the turret and townhouse. A declared central arch opening must
remain a genuine collision opening, rather than a whole convex hull.

The playable audit measures architectural bodies and their actual geometry. It
checks road/world clearance, grounded contact, measured size admission, readable
low/middle/high skyline groups, nearby opening targets, intermediate castles and
larger retained late targets. It records habitable building density against an
isolated Sunny City build using the same 192-metre square and 24-metre cell grid.
Arches, turrets, NPCs and supported tower layers do not inflate the habitable
count. The comparison uses actual `building` bodies at distinct placements;
recoloring one model does not create a new silhouette.
Root approved habitable count at least Sunny City's actual common-area count
(the current source has 72 buildings) and occupied-cell coverage at least City.
Nearest-building spacing is diagnostic because tall grouped palaces can have
different frontage. The suite measures the actual City construction rather than
trusting the source count alone.

Keep the existing shared ceilings of 900 bodies, 1,200 mesh/batch instances and
2,000 collision parts unless a measured baseline and root explicitly justify a
change. Record triangle payload and cold scene-build time as diagnostics. A
headless construction time is not GPU performance or physical iPhone FPS.

## Render and ordinary-play acceptance

Configuration checks cannot accept gloss. Root must inspect actual Compatibility
renderer pixels at the ordinary gameplay camera and a closer oblique angle.
Inspect roof highlights while the camera moves, soft masonry/roof separation,
rounded profiles, readable windows/finials, contact shadows and silhouettes.
Reject clipped white roofs, metallic-looking stone, unstable sparkle, facade
holes, exposed cut faces and buildings hidden by repeated large foreground
blocks. Compare the new and preserved old view with the same camera and lighting
scope recorded explicitly.

Two isolated ordinary 90-second rounds must retain the real gameplay route and
growth curve, collect an actual whole palace before the deadline and leave a
visible larger target hierarchy. Do not inject size/score, disable rivals, move
targets or use the continuation to manufacture a pacing pass. Record points,
radius, first palace collection, exact collection receipts and remaining targets
at 60/75/89 seconds. Preserve a failed run without calling its later retry a
first-attempt pass. Report cold and steady frame intervals separately and retain
late spikes. These Mac captures do not replace Apple's physical-device review.

## Preserved failures and visual review

The initial five generated payloads declare 8,916/9,536/1,228/780/4,436
triangles for the castle, grand castle, turret, arch and townhouse respectively;
their manifest records Blender 4.2.13 LTS. Those declarations still require
complete independent geometry and scene acceptance.

`build/fairytale-city-20261004/fairytale-01` preserves a fixture parse failure;
an explicit boolean annotation repairs the Variant inference. Attempts 02/03
preserve the initial exact decoded-normal comparison and its diagnostic. On
the first castle, all 13,564 vertices and all indices match exactly, while
ArrayMesh's encoded normal round-trip differs by at most 0.000116674 with minimum
normal dot 0.999999881. Source normals are unit length (maximum error 1.39e-7),
and all source colors are opaque. Root approved a strict 0.0002 vector bound
with independent orientation/unit checks; exact vertices and indices remain
mandatory. Original fixtures, logs and receipts are retained. All three owned
children ended and each attempt's 723 inputs stayed unchanged. Later complete
acceptance validates the strict encoding bound on every kind.

Attempts 04/05 reject the actual skyline: only eight low buildings, compared
with 56 middle and 14 high. Their diagnostics preserve the actual 78-building,
46-cell layout against City's 72/42. Root adjusts the existing short cottages
from 6.2 to 5.6 metres and selected outer houses from 7 to 5.8 metres without
changing their footprint. Attempt 06 passes the revised skyline but rejects
the fixture's nonexistent `top_height()` callback method. The fix uses the
existing `global_position.y + vertical_extent()` API; no runtime change is made
for that fixture error. Original bytes and logs remain in each attempt directory.

Read-only inspection of root's actual `visual-01` Compatibility-renderer palace
and overview images confirms pitched roofs, dormers, round turrets, half-timber
houses and intact closed walls. Curved turret sides show visible highlights.
The same images expose large empty green parcels, a repeated grass checker and
oversized toy blocks under some palace crowns; root is correcting those visual
issues. The capture reports 76 whole habitable buildings, 803 bodies and 1,041
collision parts. Its staged views do not accept normal-round progression, and
these counts still need the independent same-area scene test.

## Preserved acceptance before the assembled-block revision

The following actual owned jobs complete with exit 0, no engine errors and
unchanged 723-input maps during each job. Their common runtime hashes agree.

| Evidence under `build/fairytale-city-20261004/` | Checks | Result |
| --- | ---: | --- |
| `fairytale-07` | 129 | Authored geometry, density, arch collision opening, environment and whole-palace physics pass |
| `toy-geometry-01` | 131 | Existing ten-kind geometry, palette/cache and lightweight preview regression pass |
| `toy-city-01` | 2,844 | Existing actual body/admission/support/reachability and physical collection regression pass |

This earlier scene has 799 independent bodies: 455 static bodies and 344 court
bodies. It has 78 habitable buildings, 856 mesh/batch instances, 1,037 collision
parts and five physical towers. Actual heights span 5–38 metres, with 16 low,
48 middle and 14 high buildings. Common-area building count/cell coverage is
78/46 versus City's 72/42; median nearest spacing is 12.806 versus 14 metres.
There are 68 nearby starter targets, eight approachable bridge palaces and
14 larger late castles. The static one-body admission graph reaches all 455
targets without an invented reward or terminal size deadlock; it does not prove
timed travel. An actual new palace falls with its original model and emits one
22-point receipt only after its top crosses below -3.5 metres (observed -3.70047).

All five earlier Blender payloads pass their triangle limits: castle 9,688, grand
castle 10,356, turret 1,228, arch 780 and townhouse 5,212. Runtime vertices and
indices equal source arrays exactly. The largest decoded-normal vector delta is
0.000117396, inside the independently justified 0.0002 bound.

Root approves the measured earlier fairytale floor of 129 and the existing toy-city
floor of 2,844. The former 2,946 count belongs to the old map population; the
unchanged fixture still inspects every actual body after deliberate replacements
and removal of two giant stacks. No assertions are removed to lower the count.
The release registry also binds `tools/build_fairytale_castles.py` explicitly.

## Final assembled-block source acceptance

Blender generation 06 replaces facade decoration with actual separately closed
brick courses, stacked turret modules, raised studs and plastic frame members.
The source manifest SHA-256 is
`4f001bee02125411c37c284594cb3479898eef3abe871ef39050256bc5ac5bda`.
The five actual triangle totals are 11,220 / 11,972 / 1,484 / 1,028 / 5,476
for castle / grand castle / turret / arch / townhouse. The regular castle's
approved budget increases to 12,000; the other agreed ceilings stay the same.
The five natural dimensions and major collider counts remain unchanged.

Attempt 08 runs all 169 checks and preserves three logical failures from an
incorrect role-name veto. Every declared material role agrees with its actual
indexed vertex roles. The historical `wood` role now exports opaque coral
plastic (`ed7990`), so rejecting its name does not test wooden appearance.
The preserved fixture, report and logs remain in `fairytale-08`. Attempt 09
retains exact role/index agreement and checks every corresponding decoded RGB
sample against the actual coral color, with a maximum permitted error of
1/255 + 0.0001 and opaque alpha. The measured RGB error is zero on all three
affected models; no runtime model or material is changed for this correction.

| Fresh evidence under `build/fairytale-city-20261004/` | Checks | Result |
| --- | ---: | --- |
| `fairytale-09` | 169 | Actual block assemblies, source geometry, density, collision opening and whole-palace physics pass |
| `toy-geometry-02` | 131 | Existing geometry, palette/cache and pure preview regression pass |
| `toy-city-02` | 2,844 | Actual support, admission, reachability and independent collection regression pass |

All three owned jobs finish with exit 0, no engine errors and unchanged
724-input maps during each job. Their common 723 runtime inputs agree. The
cohort receipt is `build/fairytale-city-20261004/focused-cohort-02.json`.
The registry's accepted fairytale minimum is now 169; the unchanged toy-city
fixture still requires 2,844 actual checks.

Castle, grand castle and townhouse each contain 48 actual closed wall bricks
in four vertical courses, with 32 measured joints and 12 staggered adjacent
course pairs. Four castle corner towers and five grand-castle tower groups
each have four real vertically distinct segments; the standalone turret also
has four. All 80 raised studs have real closed geometry and indexed supporting
surfaces (28 / 28 / 4 / 8 / 12 across the five kinds). Component index ranges
partition the complete runtime mesh, and their declared bounds match bounds
recomputed from referenced vertices. These checks reject label-only assemblies.

Scene density, hierarchy and budgets remain 78 buildings / 46 occupied cells,
versus Sunny City's measured 72 / 42, with 799 independent bodies, 856 meshes,
1,037 collision parts, 68 nearby starter targets, eight bridge palaces and
14 late castles. Heights remain 5–38 metres, distributed 16 / 48 / 14 across
the low / middle / high groups. The explicitly positioned physics fixture
retains its original whole palace and produces one 22-point callback only after
the real top crosses below -3.5 metres. That fixture is not ordinary pacing.

Root separately owns actual rendered-pixel review and ordinary 90-second play.
The complete fresh source/PCK gate and physical iPhone acceptance remain
separate; this reviewer claims no current package, device installation, upload,
real purchase or review-submission success.
