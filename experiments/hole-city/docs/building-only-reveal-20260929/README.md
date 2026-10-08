# Building-only dither — v0.8.5

The user rejected the remaining broad dither behavior and requested that only
buildings reveal, or that eligibility use an explicit size threshold. This
revision uses building identity first, with size as an additional requirement.
An oversized tree, sign, vehicle or snack cannot qualify from size alone.

## Corrected rule

Only an intact `building` explicitly marked `dither_building` by the catalog's
house creation path can register. Food identity, food-building membership and
building-fragment markers are explicit exclusions. Each building must have a
body-local height of at least 3.0 world units and a maximum local horizontal
span of at least 2.4 world units after applying global scale.
`dither_min_height` and `dither_min_width` in
`fidelity/hole_reveal.gd` configure those thresholds before world registration.
Dimensions come from the individual body's bounds and scale, never the size
of a parent assembly or food stack. A thin wall can qualify only with actual
building identity and the explicit author opt-in.

The existing real camera-to-mouth mesh obstruction check still follows the
identity and size gates. Proximity and the expanded shoulder do not activate
an otherwise nonblocking building. Release, collection and return-home paths
clear reveal state. Shadows retain their complete casters.

## Why the previous food rule was too broad

The old food generator marked every main tier of an edible apartment or
landmark as a structural shell and attached the entire assembly's dimensions.
Individual burger/donut tiers and small gate pillars could therefore qualify
using a tall structure's dimensions. The previous acceptance suite even
treated a 0.6-unit food floor borrowing an 8-unit group height as correct.
Those positive food assertions are changed to explicit negative assertions
under the user's stricter rule; the building geometry and lifecycle checks
remain active.

The same isolated probe against the preserved v0.8.4 package and the new source
reproduces that difference using real meshes at the same blocking camera pose:

| Food tier | Individual height | Old borrowed height | Old reveal weight | New reveal weight |
| --- | ---: | ---: | ---: | ---: |
| Burger base | 1.922 | 9.915 | 1.0 | 0.0 |
| Donut layer | 0.877 | 6.597 | 1.0 | 0.0 |

Both observations have a confirmed mesh obstruction. The changed outcome
comes from the eligibility rule, not moving the object out of the camera ray.
[Old package](../../artifacts/building-only-reveal-20260929/food-review/old-package.json)
and [new source](../../artifacts/building-only-reveal-20260929/food-review/new-source.json).

The city catalog audit did not find ordinary props mislabeled as houses.
Several real trees exceed the numerical thresholds, which is why a size-only
rule would introduce additional false positives. Ordinary heaps, loose food,
rain and sushi traffic already had zero reveal weights; the broad category
was edible towers and landmarks, not a proven all-object material leak.

All food now remains opaque, including edible towers. Its ingredient shader
has no reveal include, pixel-discard path or per-instance reveal varying.
Legacy material parameters remain declared for load compatibility but cannot
affect coverage. Batch material opt-in is disabled, and the body setter clamps
legacy reveal writes to zero. Food-building/support metadata remains available
to physical collapse and objective accounting.

## Verification

Author geometry/lifecycle acceptance passes 75 checks with strict engine-log
validation. The independent building suite passes 176 checks: all 48 actual
catalog houses have explicit identity, while 608 ordinary bodies are excluded.
It exercises real large trees, enlarged props and actors, missing/spoofed
identity, threshold boundaries, global scale, actual house mesh obstruction,
material weights, sixteen released fragments and natural return-home frames.
[Independent building review](city-review.md).

The revised independent scene/material suite passes 434 checks. The actual
food map contains 2,588 opaque objects and registers zero reveal occluders.
All 136 towers are checked, together with representative blocking pieces from
six families, all ten enlarged recipes, stale parameter writes, compaction,
support loss, rain and release. Expected category membership is independently
enumerated rather than derived from the production eligibility predicate.
[Independent food review](food-review.md).

Fresh windowless shader-equation execution passes 45 cases across ten programs.
All nine food cases retain 4,096 of 4,096 pixels, including forced positive
legacy uniforms and instance data. The building cutout positive cases also
pass. This isolated shader harness does not render the game's browser scene.
Its fixed opaque output measures discarded pixels, not alpha blending.
The delivery verifier separately requires the actual food shader source to
contain no `ALPHA` output, include or `discard` instruction. That source guard
and the coverage cases support the opacity conclusion together.
[Shader receipt](../../artifacts/building-only-reveal-20260929/shaders/result.json).

The first full gate rejected a stale whole-shader hash in the existing food
collision review. That assertion required the old food dither code to remain
byte-identical, contradicting this requested change. The rejected run remains
under `artifacts/building-only-reveal-20260929/release-before-finish-assertion/`;
it did not replace the local preview.

The corrected assertion pins the ingredient-finish program from the verified
v0.8.4 shader, omitting only six exact legacy reveal statements plus blank
lines and full-line comments. Color decoding, roughness, specular, gloss,
transforms and render-mode declarations remain in the comparison. The old
shader reconstruction must match the preserved release's SHA-256 before its
finish baseline is accepted. All 41 mesh-array hashes and physical assertions
remain. The corrected collision suite passes 16,168 checks with the expected
finish hash `b5067e4791261ecf18471418955af77d2b38ab4fa39e468e0d2ed75e19a64a4a`.
[Verified finish provenance](../../artifacts/building-only-reveal-20260929/author/finish-provenance.json).
The non-author audit confirms that all nineteen appearance mutations and
deletion of each of the twenty-six retained lines fail the new comparison.
Reversing the assertion/helper changes restores the prior test byte-for-byte.
[Independent finish-test review](finish-test-review.md).

## Delivered build

The final gate passes all 49 source and isolated-package suites, with 33,734
checks per phase and no failures. The existing independent reveal minimum was
raised from 225 to 434; the new building-only review requires 176 checks. The
corrected collision suite retains its 16,168-check minimum. No acceptance
threshold was lowered, and the rejected first run remains available.

Static HTTP verification at 2026-09-28 16:26:10 UTC confirms that all ten files
served from `http://127.0.0.1:8768/` match the tested v0.8.5 export and include
the required COOP/COEP headers. The verifier binds current source, each log's
completion object, release counts, HTML metadata and the complete fresh shader
receipt to the delivered artifacts. Its input/program/scenario completeness
checks and source opacity guard received a separate non-author review.

- PCK SHA-256: `b8b570dff718a472640cdb8bcc7617728513ec4196fd346911fe2b2db32efaf8`
- [Source/package release manifest](../../artifacts/building-only-reveal-20260929/release/release.json)
- [Current-source, shader and HTTP verification](../../artifacts/building-only-reveal-20260929/verification.json)
- [Artifact-scoped verifier](../../artifacts/building-only-reveal-20260929/verify_delivery.py)

Existing open pages need a reload. All owned test helpers exited, and the
user's preview server remains running.

The saved browser permission restriction remains in effect. Native headless
scene checks and isolated shader-equation probes are not browser appearance
or physical iPhone GPU acceptance. No alternate UI surface or indirect capture
is used. No player-save migration, resident-world change or Git publication is
part of this revision.
