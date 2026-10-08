# Original royal castle model iteration

Current installed candidate: **models-03** (32,184 triangles total). Its source
Blender SHA-256 is `f174e03bbbd5c18e4532e817fc125a29fc27e6a30eee361e89774b40a7e09766`.
The latest 169-check authored geometry suite passes. The independent art
reviewer approved all six after-02 static GPU views. Ordinary gameplay,
swallow and exact-package acceptance remain root-owned. Earlier receipts
below are historical.

Date: 2026-10-08. Model worker owns only the Blender generator, the five
fairytale-castle assets and this document. Root owns runtime materials, map
composition, all engine execution and final acceptance. No real saves or
native/release state are touched.

## Baseline and required envelopes

The prior asset manifest was inspected before editing. Preserve these exact
Godot X/Y/Z sizes by fitting actual evaluated Blender vertices, not by writing
replacement metadata:

| Kind | Natural size | Triangle ceiling |
| --- | --- | --- |
| toy_castle | 5.0952001 × 5.9173999 × 3.7676001 | 12,000 |
| grand_castle | 6.5471997 × 7.79 × 4.4756002 | 12,000 |
| bubble_turret | 2.3232 × 6.0834999 × 2.3232 | 6,000 |
| toy_arch | 3.1500001 × 4.5 × 1.17 | 2,500 |
| block_tower | 2.78 × 5.0679998 × 2.3699999 | 6,000 |

The previous toy/grand silhouettes used one large gabled body with similar
corner cones. The revision uses a broad low entry keep, a narrower upper hall
and a single dominant slender crown tower. Unequal corner towers step around
it. The castle district geometry is original and remains assembled from closed
toy components with real joints and mounted studs.

## Visual study and original translation

Read the official [Paris castle refurbishment article](https://news.disneylandparis.com/en/chateau-renovation/)
and [Cinderella Castle attraction page](https://disneyworld.disney.go.com/attractions/magic-kingdom/cinderella-castle/).
The independent art reviewer also inspected the official Paris photograph.
Use architectural hierarchy, pale surrounds/dark windows, visible wall shafts,
curved roofs and restrained gilded tips as general visual principles. No third
party image, mesh, emblem, character or exact building arrangement is included.

Authored changes:

- A low four-course assembled foundation and pale parapet sit below a smaller
  rose hall, projecting balcony and high crown tower. Central shafts remain
  visibly exposed above the upper roof: authored grand/toy shaft heights are
  3.00/2.30 with smaller 1.45/1.14 roofs before fitting the preserved envelope.
- Four corner shafts keep genuine modular segments but have unequal heights,
  with a stronger rear flank and a lower front entry silhouette.
- Curved blue/teal roofs have an eave lip, a second physical shoulder ring and
  a slender gold finial. Roofs occupy less of the visible tower silhouette.
- A pale framed entrance encloses a shaded recess and paired rose doors;
  original diamond heraldry, broad buttresses, balconies and separate dormers
  provide readable secondary form.
- Closed arched window assemblies face all four tower elevations, both keep
  sides and the rear court. Ornament does not replace the main mass hierarchy.
- The standalone tower adds a sentry balcony; the through gate gains colored
  piers, reverse pennants and paired cap roofs; the townhouse gains a gallery
  and two capped chimney stacks.

The historical `wood` role remains the exact coral `ed7990` alias used by
existing runtime checks. New `roof_cobalt` / `roof_blue_trim` colors provide
stable blue accents; `roof` / `roof_dark` retain existing palette hooks.
Runtime palette overrides belong to root's integration review.

## Geometry and provenance contract

Each primitive is a closed solid with real recalculated corner normals. The
runtime still receives one opaque indexed vertex-color mesh per kind, actual
component index spans, structural roles and at most seven major compound
collision point clouds. The standalone arch retains its real clear opening.

The generator now bakes evaluated geometry for all five kinds, fits actual
vertices to the preserved envelope and asserts that exported measured
`natural_size` exactly equals the preceding dimensions. Arch collision split
coordinates are transformed along with the geometry. Existing tests are not
changed to approve geometry. A fresh output directory is required, preserving
previous generations and failures.

## Execution handoff

Builder edits are ready for root's single owned heavy job:

```sh
nice -n 15 .build/blender-trains/extracted/Blender/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_fairytale_castles.py -- --out build/royal-castle-20261008/models-01
```

Run from `experiments/hole-city`; confirm the configured executable path on
the host. If the Blender binary resides under the repository root, use that
absolute binary path with the same working directory and arguments.

Only Python AST parsing and whitespace checks have been performed by this
worker at this handoff. Blender export, triangle/envelope/topology acceptance,
real GPU views and ordinary gameplay are still pending. Do not treat a prepared
generator as an accepted asset or replace the shipped assets until the fresh
generation and evidence are inspected.

## First generation correction

`models-01` stopped correctly at the existing 12,000-triangle limit: the first
`toy_castle` measured 12,244 triangles and six collision masses. The failure log
is preserved; no asset was installed. For generation 02, tiny connector studs
use eight rather than ten radial sides, fully enclosed wall cores lose their
invisible bevels, and narrow parapet coping bars use closed un-bevelled boxes.
No window, tower, gate, balcony, wall course or silhouette tier was removed.
The grand and small castles share the same component topology, so the measured
small-castle failure also identifies the same overrun risk in the grand castle.
Both budgets remain unchanged. Actual generation 02 counts are pending.

## Generation 02 receipt

Root ran the serialized Blender process successfully under Blender 4.2.13 LTS.
The complete output is `build/royal-castle-20261008/models-02/`, with the failed
generation 01 log preserved separately. Actual JSON measurements:

| Kind | Triangles | Major hull groups | New normalized horizontal hull radius | Previous radius |
| --- | ---: | ---: | ---: | ---: |
| toy_castle | 11,860 | 6 | 0.6454523 | 0.6465869 |
| grand_castle | 11,860 | 6 | 0.6439783 | 0.6482075 |
| bubble_turret | 1,660 | 1 | 0.5000000 | 0.5000000 |
| toy_arch | 1,892 | 3 | 0.5767173 | 0.5767173 |
| block_tower | 5,120 | 1 | 0.7045616 | 0.7045616 |

All five measured natural sizes equal the baseline values above exactly.
The two primary castles each retain 48 closed block-course pieces, 28 mounted
connector studs and five distinct four-part shaft assemblies. Decorations are
excluded from major collision masses. The slight castle radius reduction is
under 0.7%; no rectangular foundation admission increase was introduced.

Total authored triangles: **32,392**. Editable source Blender SHA-256:
`4d09fdecf27c2a52f0286ddc68da4573e4eb880ce290e2b7c845696cd5f214c0`.
This receipt confirms generation, envelopes and budget only. Actual engine
topology, grounded assembly, rendered composition and gameplay checks remain
required before final acceptance.

## Candidate installation and focused evidence

Root authorized installing generation 02 after baseline capture and Frost
physics extraction. Eight generated files were copied and byte-verified:
five JSONs, the manifest, source `.blend` and source `.gdignore`. README was
updated separately. The failed output and original assets remain in the
ignored baseline/evidence directories.

Root's `artifacts/royal-castle-20261008/focused-01/` reports all eight focused
suites passing: authored fairytale geometry/physics (169 checks), toy geometry
(131), toy court (639), toy map integration (86), toy city (2,844), Frostlight
city (11), frozen Frost physics (57) and glacier review (2,487). The through
arch's center probe remains clear and its roof probe hits real collision.
These are desktop fixture results, not a phone-performance claim.

The model worker directly inspected the same-camera before/after crown PNGs.
Generation 02 exposes three main mass tiers, asymmetric tower heights, the
central shaft, terrace parapet and balcony. The old huge blank roof no longer
dominates the skyline. Independent art approval and ordinary gameplay remain
root's final decision; the self-review notes the broad pink entrance door and
prominent central dormers as possible polish areas rather than asserting the
geometry is visually perfect.

Independent read-only review of the Frost isolation found no source blocker:
static parcels and court assemblies use the same virtual providers; measured
AABB, original x/z admission pairs, exact historical rim-hull points and
compound collider arrays remain frozen. Temporary meshes are removed or
hidden during the same synchronous build. The shared parcel plan SHA still
matches the extracted baseline. The new standalone Toy tower balcony expands
its all-visual horizontal admission radius by 6.15% (0.5307703 vs 0.5); its
major hull radius remains 0.5. Root has been informed. This affects the Toy
map only; the frozen Frost provider preserves its original admission.

The runtime review subsequently resolved the normalized turret-radius concern
against actual world placements: all 55 kind/tier/extent classes retain their
original minimum admission level, body count and supported-owner count.
Nonuniform world scales make the largest actual relative radius change
1.8491%, with 799 bodies and 4,169 total points unchanged. No model rebuild
solely for the unit-space balcony radius is recommended.

## Required art correction for generation 03

The independent art reviewer accepted the changed silhouette direction but
held approval for the broad plain pink door and oversized paired dormers.
Root authorized the bounded correction before final acceptance.

- The main entrance now uses a closed U-shaped projecting pale portal. A
  fixed dark blue-brown door and deeper dark surround sit physically behind
  the portal face; narrow gold hardware remains legible. The new gate roles
  are not affected by the existing roof-palette override.
- Root selected one half-size attached dormer. The helper now scales the
  entire assembly uniformly, including height and depth, rather than merely
  narrowing a fixed-height dormer. Its base intersects the actual sloping
  roof, leaving a small subordinate roof feature beside the crown.
- Garden objects remain root's separate Toy-only runtime work. No sixth
  Blender asset kind, external asset or new dependency is added.

Builder syntax/whitespace checks pass. Root will generate into a fresh
`build/royal-castle-20261008/models-03` directory; source 02 assets remain
installed until the new files are measured and installed explicitly.

## Generation 03 installed receipt

The next serialized Blender generation completed successfully and all eight
generated files were installed with byte-for-byte comparison to models-03.
Primary castle triangles decreased to **11,756 each**; tower/arch/townhouse
remain 1,660 / 1,892 / 5,120. Total is **32,184**. All five measured natural
envelopes and collision-mass counts remain unchanged. Current source Blender
SHA-256 is
`f174e03bbbd5c18e4532e817fc125a29fc27e6a30eee361e89774b40a7e09766`.
The generator SHA matches the current builder and every manifest asset digest
was independently recomputed before installation. README is current; earlier
generation receipts remain historical evidence rather than current hashes.

Source/assets are frozen for root's renewed topology and GPU review. The new
portal and dormer are not visually accepted merely because export succeeded.

## Final static model approval

The independent art reviewer directly inspected all six current `after-02` GPU
images and accepted the static model assets. The dark recessed U-portal,
subordinate single half-size dormer, readable central shaft, coherent front
and rear silhouettes and deep blue crown resolve the requested corrections.
The model worker also inspected the real crown view and found no remaining
blocking geometry issue. Generator and installed models-03 assets are frozen.

This is static model approval only. It does not claim ordinary-gameplay timing,
swallow presentation, native-device performance or exact-package acceptance;
root coordinates those separate receipts and the overall release handoff.
