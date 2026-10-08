# Glacier map art review

Reviewer: independent art reviewer (`glacier_art_review`).
Date: 2026-10-07.
Scope: actual Godot image review, supporting source inspection, and later
candidate comparisons. No engine jobs or implementation edits are performed by
this reviewer. Visual acceptance does not establish phone performance.

## Initial verdict: reject

The supplied baseline does not meet the requested Arctic glacier appearance.
It reads as a white city board populated by copies of an opaque teal crystal
cluster. More triangles or higher metallic values alone will not address the
shape, composition, and lighting problems.

### Evidence inspected

- `artifacts/frostlight-village-20261006/gpu-asset-closeup-iteration-02/glacier-hero-closeup.png`
- `artifacts/frostlight-village-20261006/gpu-asset-closeup-iteration-02/ice-rock-hero-closeup.png`
- `artifacts/frostlight-village-20261006/gpu-review-anchor-final-01/frostlight-world-overview.png`
- `artifacts/frostlight-village-20261006/gpu-review-anchor-final-01/frostlight-polar-life.png`
- `tools/build_frost_blender_assets.py`
- `fidelity/frost_city.gd`
- `fidelity/frost_ground.gdshader`

The official visual-development reference is Disney Animation's
[The Look and Lighting of “Show Yourself” in “Frozen 2”](https://media.disneyanimation.com/technology/publications/2020/siggraph_2020_showYourself.pdf).
Its useful direction here is the contrast between frosted and clear ice and
the joint treatment of lighting and material. Its offline multiple-scattering
renderer is not a practical requirement for this mobile game. Use original
Arctic geometry and a cheaper illusion of depth; do not reproduce the film's
architecture, characters, or branded motifs.

### Prioritized defects and fixes

| Priority | Observed problem | Required improvement |
| --- | --- | --- |
| P0 | Tall, almost regular cones dominate both assets. The edible rock looks like a pointed traffic cone with a white collar. | Author a broad calving cliff, an asymmetric stepped ridge, and squat fractured boulder/floe silhouettes. Large glacier faces need shelves and shoulders rather than a central needle. |
| P0 | Every landmark repeats the same peak arrangement, while straight turquoise brick roads divide rectangular parcels. | Retain playable navigation, but replace the paving appearance with irregular frozen leads/snow paths. Compose unequal glacier groups and open snow or ice areas, with one dominant landmark and several subordinate groups. |
| P0 | Ice is flat teal with dark triangular patches. Tiny white triangles appear attached arbitrarily. | Use coherent blue depth gradients, dark narrow crevices, pale edge highlights, and snow caps that follow connected upper surfaces. Avoid per-triangle alternating paint. |
| P1 | The snowfield is nearly clipped white, washing out small pale objects and snow drifts. | Preserve blue-violet shadow information, reduce excessive light/albedo, and establish a darker environmental midtone behind bright snow. |
| P1 | Decorative ridges and ponds are regular rectangular boxes. Spires remain cones. | Use broken irregular outlines and stepped ice lips. Reuse affordable authored meshes and instances rather than adding many unique materials or transparent layers. |
| P1 | Landmarks stand alone in the middle of equal lots; small life is visually peripheral. | Place low rubble/floes at glacier feet, leave readable routes through the scene, and frame animal/camp groups with contrasting ice shapes. The Arctic habitat should be visible without a dedicated close-up. |

### Source corroboration

`bevel()` currently returns the input object without modifying it. Peaks use
six-sided tapered rings; material indices alternate per triangle rather than
following a consistent ice structure. `ice_rock_body()` is built from three
cones. The ground shader explicitly produces brick mortar. These are authored
decisions, so a lighting-only revision is insufficient.

## Visual acceptance criteria

1. Actual imported Godot close-ups show at least three distinct ice silhouettes:
   broad cliff/shelf, offset ridge cluster, and squat rock/floe. A common cone
   scaled to three sizes does not qualify.
2. Large ice has a readable three-part value structure at the ordinary game
   camera: luminous pale crest, blue body, and narrow deeper crevices. Snow
   occupies believable connected upper ledges; no isolated white triangular
   patches or floating collars dominate the result.
3. The map overview reads as a frozen landscape before a city grid. No brick
   mortar or repeated straight turquoise street lattice remains visible. Routes
   may preserve their underlying playable shape, but natural surface treatment
   and offset grouping must soften the parcel pattern.
4. At least one ordinary portrait gameplay frame shows a clear progression in
   scale from small edible debris to a substantial glacier, while the player and
   animals remain readable. Do not satisfy this solely with isolated asset shots.
5. Lit ice shows restrained specular or edge sheen in actual rendered pixels,
   while rough snow and darker ice remain distinguishable. No requirement for
   costly transparency; no uniformly clipped white ground or mirror-metal ice.
6. Ground contact, snow caps and seams are visually clean from the game's normal
   camera and at least one alternate close-up angle. Detached slabs, needles,
   z-fighting and unexplained floating snow fail acceptance.
7. The final review must compare new image files directly with the baseline and
   record remaining limitations. Code counts or headless checks cannot replace
   this visual review. Gameplay/collision/performance approval belongs to the
   second reviewer.

## Candidate 01: reject final approval; retain improvements

All nine PNG files under
`artifacts/glacier-frozen-review-20261007/render-01/` were inspected:
six asset close-ups, `world-overview`, `opening-basin`, and `polar-life`.

The revision removes the brick grid, restores blue shadow contrast, provides
cleaner snow contact, and replaces the cone rock with a squat boulder. The
landscape palette is more coherent. The glacier assets have clear shoulders and
better construction than the baseline. These improvements should remain.

The main remaining problem is manufactured shape language: the new objects
mostly resemble beveled containers with white lids. Their sides are uniformly
vertical and their evenly spaced horizontal stripes read as repeated painted
bands. Six named meshes do not yet produce six distinct geological impressions.
The overview still has separated monumental sculptures around four central
clusters, rather than an asymmetrical glacier field.

Required next pass:

1. Change the largest top profiles into irregular slanted ridges, offset
   shoulders, or broken calving edges. At least three large silhouettes must be
   distinguishable without relying on different body heights. Keep squat floes
   and some broad shelves; not everything should become pointed.
2. Add one or two real narrow deep clefts to a hero landform. A dark cavity
   bordered by pale ice will provide depth more effectively than more decorative
   stripes. Ensure closed geometry and preserve readable collision silhouettes.
3. Reduce the regular wraparound pinstripes. Use sparse discontinuous frost
   seams or unequal strata; the original shape should supply most of the detail.
4. Compose two or three landmark groups with offset low ice shoulders and a
   subordinate mass, making unequal natural clusters while retaining open
   navigation. Do not merely place more identical towers in the empty areas.
5. Provide at least one actual ordinary portrait gameplay image with HUD and
   player visible. The current `opening-basin` capture is useful, but it is a
   wide diagnostic view and does not establish the visual experience on the
   normal phone-shaped viewport.

Current acceptance status: criterion 3 (no brick grid) and much of criterion 5
(palette/contrast) improve; criteria 1, 2, 4 and 6 require the next captures.
No engine or gameplay approval is implied.

## Candidate 02: asset direction accepted; final map review pending

All nine PNG files under
`artifacts/glacier-frozen-review-20261007/render-02/` were inspected directly and
compared with candidate 01 and the original baseline.

The principal geometry rejection is resolved. Sloped summits, deep V-shaped
separations, broad shelves, squat floes and irregular snow edges now form a
coherent stylized glacier set. Uniform lid-like caps and wraparound pinstripes
no longer dominate. The six assets provide useful differences in height and
width; a pointed ridge is distinguishable from a broad shelf or calved boulder.
Actual rendered side values separate pale upper ice, blue bodies and deeper
recesses. The palette remains restrained and readable.

The added low shoulder pieces improve the relation between the large formations
and their surroundings. The overview is still an intentionally compact board
with some repeated central clusters, but it no longer reads primarily as a city
street grid. This is an acceptable compromise for the existing navigation and
growth structure. No further wholesale mesh redesign is requested before the
ordinary gameplay review.

Pending final art acceptance:

- Inspect ordinary portrait gameplay with the HUD, player and small edible
  objects visible near tall ice. The diagnostic overview cannot establish
  practical occlusion/readability on the normal viewport.
- Inspect one alternate close-up angle to confirm that cap edges and clefts
  remain clean, without rear seams, detached facets or floating geometry.
- Inspect the actual map-selection miniature after its glacier update.

Material limitation: this is attractive stylized opaque ice with restrained edge
light. It does not reproduce the cinematic scattering or translucency of
Disney's offline renderer, and should not be described as doing so. This does
not prevent acceptance for the mobile game's existing visual language.

## Ordinary portrait gameplay: visual readability accepted

Inspected all eight gameplay PNGs and the stated capture scope under
`artifacts/glacier-frozen-review-20261007/gameplay-01/`. The captures use the
normal 540 by 1174 portrait viewport, standard HUD, rivals and collisions with
scripted legal movement. This is Mac-rendered gameplay, not a phone recording or
a real-time performance benchmark.

Small ice chips remain visible because their pale caps, blue sides and contact
shadows separate from the ground. Penguin, scientist and cargo colors provide
additional useful visual landmarks. The timer, score, growth label and boost
control remain legible throughout the inspected images.

Large ice partly covers the player's hole at 30 and 45 seconds, but the outer
rim and player label remain identifiable; this is not an art blocker. The
60-second frame is an open cleared route, while the 75-second frame visibly
shows larger multipart ice descending into the grown hole. The sequence does
demonstrate a readable small-to-large visual progression. The wide overview
previously inspected supplies the larger landscape context absent from a single
phone-shaped frame.

Criterion 4 is now satisfied. Final art approval remains pending the alternate
asset view and updated map-selection miniature. No further gameplay-facing art
fix is requested from this evidence. Route efficiency, balance and collision
correctness remain the second reviewer's scope.

## Final art verdict: accepted

Inspected `render-03/calving-cliff-reverse.png`, `render-03/home-preview.png`,
and `render-03/world-chooser.png` under the same artifact directory. The reverse
angle shows closed, grounded ice forms with continuous snow caps and no detached
triangles or floating collars. The home miniature now uses the actual glacier
shape families and a penguin group; the chooser presents Frostlight Village as
the selected Arctic world.

The candidate is accepted for the game's stylized Arctic art direction. This is
a positive visual judgment after two rejected or incomplete stages, based on
actual imported assets, the world view, standard portrait gameplay and UI.

| Criterion | Final result |
| --- | --- |
| Distinct cliff, ridge, shelf and squat ice silhouettes | Pass |
| Connected snow caps, blue mass and deeper recesses | Pass |
| Frozen landscape treatment without brick street lattice | Pass; compact board layout remains intentional |
| Normal portrait progression and small-target readability | Pass |
| Restrained ice highlights and recoverable ground contrast | Pass for stylized opaque ice |
| Grounding, rear seams and snow contact | Pass in inspected front/reverse views |
| Direct baseline/candidate comparison and limitation record | Pass |

The corrected implementation count supplied by root is 16 independently edible
calved shoulder blocks, rather than the initially planned 24; eight placements
were rejected for clearance. This review does not use the intended count as
proof of visual quality. The reviewed screenshots are the visual evidence.

Remaining limits: the arena retains some repeated clusters; scientists and
wildlife are deliberately simple game models; the material approximates ice
without cinematic refraction or scattering. Phone performance is not measured
by this art review, and no release, upload, account or physical-device action is
claimed. None of these limitations blocks acceptance of the requested local
glacier visual improvement. Functional and performance acceptance remain a
separate review.
