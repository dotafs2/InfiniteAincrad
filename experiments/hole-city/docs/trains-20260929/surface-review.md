# Independent train surface and UI integration review

**PASS: 1,121 strict functional checks**, with no unexpected engine diagnostics
and all reviewed source/test hashes unchanged across the final run.

The reviewer authored the train model assets, but did not author the route,
track-surface, gameplay integration or HUD code assessed here. This review is
independent of those implementation authors. The separate asset/controller
review is performed by another agent.

## Reviewed scope and correction

Read-only inspection covered `train_routes.gd`, `train_track_surface.gd`, the
asphalt shader additions, `game.gd` train creation/stepping/cleanup,
`ui.gd::draw_train_hint`, the palette importer adaptation and
`tests/train_surface_acceptance.gd`. No runtime source was edited by this
reviewer.

One actual integration defect was returned to the author: `back_home()` freed
the world but retained the two train `RefCounted` fields. The controller's
signal connection also retained the track surface. The title screen therefore
kept obsolete actor references, the two 1 MiB CPU masks and the texture until a
new round. The author now clears both fields on return home. The final probe
requires both fields to become null immediately, then uses weak references to
verify that the controller, track-surface object and texture are actually
released after the world is freed. It exercises four consecutive rounds and
returns home after each, rather than only replacing one map with another.

The runtime author's imported-material probe also established that this Godot
importer preserved `COLOR_0` buffers but left the active material's
`vertex_color_use_as_albedo` false. This was a real white-model risk, not a
surface-override lookup mistake. The runtime adapter now enables that flag on
a duplicate of the original PBR material. This reviewer additionally flagged
the first cache's use of transient instance IDs; the author changed it to a
stable resource-path key. The independent final round sequence reports cache
sizes **2, 10, 10, 10**, with no further growth after both asset sets are loaded.
The non-author asset/controller suite covers the actual material adaptation in
more detail.

## What the independent executable establishes

[The review test](../../tests/train_surface_review.gd) loads the real game,
actual imported vehicles, both actual maps and the normal UI, with `--test`
player-save isolation and the Dummy audio driver. It checks:

- Each actual route's reported length against the sum of its closed polyline,
  and 80 independently phased samples per round against the authored road
  geometry. At those positions, the actual CPU mask contains the bed and both
  bright rail offsets. Unrelated central ground has no rail marks.
- The marks are bound to the **exact material on the cut-ground visual**.
  Layer-1 physics rays confirm solid ground before the mouth, no terrain under
  several aperture samples while the mouth is present, and restored terrain
  afterward. The route texture remains unchanged during this operation: the
  actual cut mesh supplies the opening, so no separate rail collider or visual
  floor bridges the hole.
- Normal movement never regenerates the track texture. A real middle-car
  detachment, with physics synchronization between transforms and queries,
  generates a nonempty bypass; actual signal-updated pixels follow its points.
  Clearing the branch list restores the original mask.
- The real CanvasItem draw callbacks produce the distance caption. Actual font
  metrics fit inside the pill's text area and clear its arrow; the pill does
  not overlap current interactive controls, the score panel or notices.
  Native viewport screen-touch and drag events beginning **inside the pill**
  reach the player's movement-input state and release correctly. The pill is
  drawn on an input-ignoring Control, not an invisible button. Nearby trains
  suppress the pill; title redraws do not read freed cars.
- Return-home cleanup is real rather than inferred from assignments, and the
  palette cache remains bounded across repeated map loads.

The fixed 540×960 logical portrait layout fits the caption independently of
physical display scaling. The pill is informational, so it introduces no new
small touch target. Existing phone control scaling remains the responsibility
of the existing portrait/retention UI suites. This run exercises input
routing, not on-device touch hardware.

## Author-suite assessment and test cleanup

The author's surface acceptance is useful and preserves behavioral checks for
map replacement, mask ownership, real ground removal, branch refresh and
whole-game teardown. Its literal route-length values pin the current intended
corridors; they do not alone prove route correctness. This independent probe
therefore checks the actual closed geometry and road membership at a different
sample phase instead of trusting those constants.

The author's added two-physics-frame wait after 60 manually executed movement
steps is a valid fixture synchronization correction. Manually moving kinematic
nodes many times in one frame does not synchronize the physics broad phase as
normal gameplay frames do. The wait changes neither the detachment result nor
its assertions. The independent test instead advances physics between each of
its movement steps, then confirms the nonempty real bypass and painted path.

A first independent run passed all logical assertions but exited before the
Dummy audio thread retired its streamed decoder. Verbose output identified
only `OggPacketSequence`/`AudioStreamPlayback`, not train resources. Final test
cleanup follows the existing music suite: stop the owned player, allow 120 ms
of real time and three frames for decoder retirement, then free the game.
Every train lifetime assertion occurs **before** that cleanup. The final strict
run has no resource-leak diagnostic; no runtime cleanup was bypassed.

## Receipts and limits

- [Final registered test receipt](../../artifacts/trains-20260929/surface-review/registered.json)
  contains the 1,121-check result, cache sizes and exact before/after hashes.
- [Final strict log](../../artifacts/trains-20260929/surface-review/registered.log).
- Earlier `probe.json` / `verbose.log` retain the audio-teardown diagnostic.
- Test SHA-256:
  `893db6b892456ed0f09d52eb35b94f2e34212ed623b370f322f01fc0c42a1ef9`.

The test writes no report from GDScript and reads no loose source files; the
completion marker can be checked against the isolated exported package. Hashes
are recorded by the external runner. All reviewer-owned Godot and Blender
helpers have exited.

This is native headless scene/input/resource evidence. It does not inspect the
browser, prove shader pixels on a phone, certify frame rate or claim the
Blender contact sheet matches the game's lighting. The release source/PCK gate
and performance samples are separate evidence.
