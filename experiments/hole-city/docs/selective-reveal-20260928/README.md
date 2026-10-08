# Selective building reveal — v0.8.2

The user rejected v0.8.1 because nearby food, people, traffic and loose pieces
all acquired dithering. Its tests verified the broad shader implementation,
but encoded the wrong gameplay policy. This correction treats ordinary
collectibles as readable gameplay objects and makes reveal an explicit
exception for large, intact building structure.

## Corrected behavior

City architecture must be at least 3 world units high and 2.4 units wide.
Food architecture needs explicit structural-shell membership and a qualifying
building envelope; loose snacks, heaps, rain, vehicles and decorative toppers
are excluded. Standing food tiers retain their original independent physics.

Eligible bodies pass two checks before activating: their oriented box must
overlap the actual mouth in camera projection, and camera-to-mouth segments
must hit their real mesh triangles. A cached triangle BVH confirms the center,
a box-edge witness and bounded radial samples. An empty arch or donut opening
therefore cannot activate solely because its bounding box covers the mouth.
The sampling is finite; it is not a screen-depth-buffer or pixel-perfect
occlusion measurement. BVHs are built once per shared mesh during binding.

Only an already obstructing structure receives the wider feathered shoulder
and movement lookahead. A nearby building that enters only this expanded
region remains opaque. Activation/restoration is smoothed; a structure that
starts falling immediately loses eligibility. Cached facade fragments retain
their original tint and roughness with zero reveal weight.

Ordinary city objects keep their source materials. Food keeps the same
ingredient shader and finish. Static food batches carry a separate weight
per instance; the default food material stays opaque. Batch compaction moves
the retained member's authoritative weight to its new slot and clears the
retired slot. Released pieces, new food rain and settled rain cannot inherit
a neighbor's reveal state. No batch splitting or extra structural draw groups
are introduced. Scene shadows and main 4× MSAA remain enabled.

## Original-code comparison

The preserved original source is the public mbMayer Godot hole template, not
Hole.io's commercial source. Its nine pinned files contain movement, growth,
CSG hole physics and a decorative UV-warp shader, with no building-occlusion
implementation. Our older city implementation targeted buildings only, but
used footprint proximity instead of actual sight-line obstruction. The
v0.8.1 regression came from broadening eligibility to every edible object and
using one unconditional food shader. [Exact files and provenance](source-comparison.md).

## Acceptance policy

The previous all-object reveal tests and receipts remain historical v0.8.1
evidence. The release gate replaces those requirements with selective tests:
ordinary objects at the exact same blocking coordinates must stay opaque,
nonblocking structures must stay opaque, and actual large structural
occluders must reveal. Existing physics, color, shadow, collection and mobile
thumbnail regressions remain in the gate.

- [Independent scene/material/release review](independent-review.md)
- [Independent controller review](../fixes/reviews/selective-controller.md)
- [Actual shader-equation coverage](../../artifacts/selective-reveal-20260928/shader-probe-final/result.json)

The geometry suite passes 75 checks and the independent scene/material review
passes 225 checks, including real city/food membership, a mixed batch,
compaction, release, restart and hollow-mesh cases. A separate non-author
controller review passes 65 checks and caught duplicate binding and freed-node
access during development; both findings were repaired before the final run.

The shader probe now includes actual palette, food-batch and default-material
opt-in paths at identical world coordinates. All ten new selectivity cases
pass in addition to the nineteen aperture and twelve material-color cases.
This is isolated shader execution, not a game screenshot or phone benchmark.
Headless Godot's dummy renderer does not retain MultiMesh GPU buffers; the
scene tests check authoritative per-body weights and dispatch/compaction
behavior and do not claim GPU buffer readback.

## Release verification

All 37 source suites and the same suites against the isolated exported PCK
pass 11,501 checks per phase. The guarded release replaced the local Web
preview with v0.8.2 only after both phases passed. Final verification matches
the current source, all 41 shader cases, twelve CPU traces and the HTTP-served
artifact hashes. Reload the current preview to load the new package.
[Release and delivery receipt](../../artifacts/selective-reveal-20260928/verification.json).

## CPU measurements

Three isolated runs per scenario record 7,200 frame intervals with the reveal
controller active on every measured frame. Median per-run P95 is 7.775 ms for
city opening, 7.524 ms for city grown, 8.276 ms for food opening and 9.830 ms
for food grown. Three intervals exceed 16.667 ms; the maximum across all raw
traces is 38.737 ms. The summary's `worst_ms` is a median of per-run maxima,
not the maximum of the complete recording.

The city binds 48 structural candidates and 48 shared triangle meshes; food
binds 630 structural tiers and 20 shared triangle meshes. Geometry is cached
at bind time. Every frame still iterates registered candidates, but does not
traverse the scene tree or rebuild mesh acceleration structures. These are
headless Mac CPU wall times, not browser/GPU/iPhone measurements or a guarantee
of sustained 60 FPS. [Raw runs and source fingerprints](../../artifacts/selective-reveal-20260928/cpu/summary.json).

The mesh narrow phase uses Godot's documented [TriangleMesh BVH queries](https://docs.godotengine.org/en/stable/classes/class_trianglemesh.html).
The browser tool rejected access to the local game because a saved user
permission blocks that address. No alternate browser surface or indirect UI
access was used to bypass it. Actual browser appearance remains unverified.
Player saves, reference applications and resident worlds were not modified;
no Git publication was requested.
