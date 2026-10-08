# Animated Snack Garden miniature — v0.8.4

The user reported that the Snack Garden home-screen miniature did not move
like Sunny City and lacked a layered, irregular food-stack composition.

## Reproduction and implementation

An independent native, headless probe loaded the preserved v0.8.3 PCK in an
isolated working directory. During thirty natural process-frame observations,
Sunny City's real preview pivot advanced 0.048333 radians. Snack Garden had no
valid pivot and processing was disabled. Its twenty-six visible mesh nodes
also carried twenty-five unnecessary rigid bodies and collision shapes.
[Old-package baseline](../../artifacts/map-preview-20260929/baseline/README.md).

Both home miniatures now use the same visibility/process lifecycle. Their
preview pivots turn at 0.10 radians per second on the home screen. Opening the
skin collection, store, gameplay, pause or results stops miniature processing
and rendering. Returning home resumes it. Map replacement stops and releases
the previous model. Initial lighting is created before building the first
preview, so a saved food selection receives the same 0.48 ambient fill as a
later selection; Sunny City retains 0.8.

Snack Garden uses a dedicated visual-only scene, reusing the existing rounded
food meshes, saturated vertex colors and ingredient-gloss shader. It contains
68 food pieces across all ten recipes, in 14 clusters. Low foreground meals,
middle stacks and background cake/wafer buildings reach approximately 1.35,
4.08 and 7.86 units respectively. Six stacks vary individual layer offsets,
tilt and size. A biscuit-and-cream base and bent chocolate streets retain
open space between piles. Contact positions use mesh bounds or the actual
ingredient surface rather than an arbitrary gap above a decoration.

There are 87 mesh instances, 27 shared meshes and one shared material, totaling
123,104 triangles. The short-lived mesh builder is freed before a frame can
run. No gameplay city, rigid bodies, colliders, food rain, collection or reward
system remains in the miniature. This inventory is a bounded scene description,
not a measured GPU frame-rate result.
[Composition and resource evidence](food-miniature.md).

## Return-to-home defect caught by natural-frame QA

The first lifecycle run passed all 79 functional assertions but failed strict
engine-log validation. After leaving a round, `game.update_reveal()` still
passed a previously freed player into a typed `Node3D` argument, even with
reveal disabled. The argument conversion failed before the callee's guard ran.
Inactive phases now reset reveal and return before passing that stale object.
The active and paused paths retain their existing behavior.

The failed run is preserved under
`artifacts/map-preview-20260929/author/map-preview-before-return-guard.*`.
A non-author review passes thirty natural lifecycle checks and the unchanged
75-check selective-reveal suite. It leaves the real game `_process` running
after freeing the world, so it cannot hide the error by stopping updates.
[Independent lifecycle review](reveal-lifecycle-review.md).

## Verification scope

The author lifecycle suite passes 79 checks and the food geometry/resource
suite passes 483. The separate non-author miniature review passes 716 checks.
It checks natural SceneTree frames, cold food startup, home/collection/store/
play/pause/results transitions, hidden map replacement, twenty repeated map
switches, resource cleanup and an unchanged home-screen reward ledger.
[Independent miniature review](independent-review.md).

Both models are projected through the actual preview camera at 72 angles.
All mesh AABB corners stay inside a 2.5-percent safety boundary; the minimum
food margin is 44.76 pixels in the 640-by-560 preview viewport. This is
geometry/framing verification, not pixel-based aesthetic acceptance. The
existing 2× MSAA preview target and shadows remain enabled.

The mobile-map regression now expects the new lightweight preview type while
explicitly confirming that starting food gameplay still creates the complete
physical FoodCity. All prior movement, food-fall and goal assertions remain.

The previously saved browser permission restriction remains in effect. No
alternate browser, indirect capture or UI bypass was used. These headless
checks do not establish actual browser appearance, subjective visual quality
or iPhone frame rate. Player saves, map gameplay content and unrelated worlds
are preserved. No Git publication was requested.

## Delivered build

The final gate passes all 48 suites against both source and the isolated
exported PCK, with 33,349 checks per phase and no failures. The device recorder
self-test passes its twelve checks. No acceptance threshold was lowered.
The mobile-map suite adds a full-gameplay FoodCity assertion while retaining
its existing movement, physical-fall and objective checks.

Static HTTP verification at 2026-09-28 15:46:18 UTC confirms that all ten files
served from `http://127.0.0.1:8768/` match the tested v0.8.4 export, with the
required COOP/COEP headers. The verifier checks current source hashes before
and after, binds each receipt to its log's completion object, and validates
the HTML's version and package metadata. An independent read-only review
caught stale-success-report and log-binding gaps in that verifier; both were
corrected and reviewed before it ran successfully.

- PCK SHA-256: `d68b368fa1f77bd4b5a12771673a64c0855bd41b01412c76b9627f67a84cb20d`
- [Source/package release manifest](../../artifacts/map-preview-20260929/release/release.json)
- [Current-source and HTTP delivery verification](../../artifacts/map-preview-20260929/verification.json)
- [Artifact-scoped verification script](../../artifacts/map-preview-20260929/verify_delivery.py)

The preview was replaced only after both gate phases passed. Existing open
pages need a reload. All owned test helpers exited; the user's preview server
remains running. The browser and physical-device limitations above still apply.
