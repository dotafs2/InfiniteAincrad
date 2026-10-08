# Independent food geometry-budget maintenance review

Read-only review of `tests/food_finish_acceptance.gd` against the exact retained
`artifacts/world-expansion-20260929/review/food_finish_acceptance-before.gd`.
No engine, renderer or browser was started for this review.

The sole replaced original assertion is the old whole-scene 4.5-million triangle
cap. Its original-content ceiling is retained separately. New content is bound
to actual food bodies by authored extension plot/heap/snack provenance, with
matching tower/pile IDs and loose-food positions. The additional 334 bodies are
limited to 650,000 triangles and the complete scene to under five million.
All prior finite-vertex, unit-normal, outward-winding, rounded-edge, dimensions,
material, release and lighting assertions remain. Added camera-frustum checks
use an actual 390×844 viewport and conservative static batch AABBs; they do not
claim real GPU timing, dynamic-body submission cost, or phone frame rate.

The retained independent old-package/current resource evidence identifies all
34 instantiated mesh arrays as identical, with actual food triangles increasing
from 4,389,184 to 4,961,996 (+572,812 / 13.0505%). This substantiates a scoped new
content allowance rather than a replacement of the old quality checks.

This read-through applies to the pre-density-correction expansion. The upcoming
larger food footprints must retain the same mesh topology and repeat the actual
counts and visibility assertions against their final positions. Ground coverage,
physical overlap and large-piece swallowing are separate checks; this triangle
budget does not certify them.
