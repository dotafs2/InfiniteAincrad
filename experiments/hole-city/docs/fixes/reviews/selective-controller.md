# Independent review: structural occlusion controller

Reviewer: food implementation agent, separate from the root controller/shader
author. Date: 2026-09-28. **PASS after lifecycle corrections and actual-triangle
confirmation**, with the sampling limitation below. Food-body and food-batch implementation
are this reviewer's own work and are excluded from this independent approval;
the UI agent reviews those separately.

Reviewed root-owned `hole_reveal.gd`, its shared include and material flags,
`fidelity/swallowable.gd`, and the game registration/activation hooks. A small
synthetic scene instantiates the actual controller without building either
full game map. The final run passes 65 assertions and strict engine diagnostic
classification. Only the exact existing macOS system-CA message is excluded.

The initial probe found two real problems: calling `bind_city` twice created
duplicate entries, and freeing an active registered building caused a typed
assignment of an invalid instance during the next update. Godot still exited
zero after printing this script error, demonstrating why checking exit status
alone is insufficient. Root added an instance-ID registration guard and checks
the dictionary's body reference before assigning it to a typed variable. The
final probe covers free → tick → reset, and direct free → reset while the
cached eligibility was still active. Both paths are clean.

The controller admits only explicit large building categories or opted-in
structural food shells above the height/width thresholds. Ordinary person,
vehicle, fragment, lamp, loose-food and ambient-actor categories cannot qualify
merely because their bounds are large. Claimed, released, consumed or queued
bodies are excluded. Physics release clears the weight immediately; intact
structures activate and restore with a short bounded smoothing interval.
Reset clears eligibility and the global aperture. Cached city fragments reset
their shared facade material's reveal flag before being instantiated; fallback
fragments keep their original StandardMaterial. Dynamic preparation is a no-op.
The legacy generic material-adapter methods have no active game-path caller.

Selection tests the actual hole-core circle, independently of the larger shader
shoulder and movement lookahead. Explicit fixtures reject shoulder-only and
lookahead-only intersections, boxes past the camera, boxes above the camera
and geometry below ground. Tall boxes crossing the camera plane and a wide
building whose center is far away but whose edge covers the core are selected.
An independent local-space ray/box slab oracle exercised 180 random oriented
solid boxes: 34 positive ray cases and 146 negative cases, with no mismatches
or ambiguous grazing cases in this sample. This oracle does not reuse the
controller's projected convex hull.

The initial geometric predicate used only an oriented bounding box, allowing
hollow arches, donut gaps or concave roofs to qualify through empty box volume.
Root addressed this finding with a second stage: shared meshes generate a
cached TriangleMesh BVH at registration, and only a real camera-to-core segment
hit can activate the weight. It tests the center, a broad-phase witness and
three rings of sixteen points. Food originals retain their actual mesh and
transform even while their static batch is displayed; loose/freed bodies remain
excluded before triangle queries. Cache allocation is shared by mesh identity
and released on a full scene reset. The reviewer reran the lifecycle fixture
with an actual BoxMesh sized to match its stub bounds and verified both cache
creation and release. The 180-case box oracle continues to test broad phase
only; the UI reviewer separately verifies hollow-arch rejection and side hits.

The triangle confirmation closes the empty-volume false-positive issue. It is
finite sampling, so a very thin obstruction between samples may remain opaque.
It is not a depth-buffer query, exact per-pixel visibility test or rendered
appearance acceptance. The bias in an unsampled case preserves readability.

CPU work now includes one pass over the registered structural candidates on
every active update. The world-space broad phase avoids convex-hull allocation
for distant candidates, and only broad-phase hits trigger the cached BVH
queries. A potential optimization is to compute part inverse transforms once
per candidate instead of per sampled ray; root retained the current version
pending actual profiling. There is no per-frame scene-tree traversal or material
adaptation, but the reported zero `per_frame_scene_scans` must not be interpreted
as zero selection work. Fresh isolated profiling is required after this change;
these concurrent correctness probes make no timing claim.

Evidence: `artifacts/selective-reveal-20260928/review-controller/` contains the
reproducible `controller_review.gd`, `run.log`, engine log and `result.json` with
all reviewed runtime/shader hashes. Reviewed controller SHA-256:
`add22f020b110425f6bb5002f4b58c324ba9a387c448b354f560ffa7f22ddd6a`.
The earlier 63-check review
covered the pre-BVH controller and is superseded by this 65-check checkpoint.
No root runtime, real player save, browser or live deployment was changed by
the reviewer. No helper process remains.
