# Bubble UI rebuild — v0.6.0

The user requested a new UI after comparing the current menus with Hole.io and
Hole Em All. This pass changes the shipped interface, including home, the skin
library, both map HUDs, tutorial, pause and results.

## Presentation and behavior

- Home keeps the actual city/food miniature, with a stronger PLAY action and
  two illustrated map cards. Original city and cake-town vector illustrations
  replace text-only map buttons. A check badge marks the active map. The skin
  entry uses an original character-hole icon.
- The skin library gives its five visible model cards more image area and
  reduces the detail panel. Equipped, selected-but-locked and available states
  have distinct outlines, lock/check icons and real unlock requirements.
  Classic/Special counts, best-round progress and PLAY remain functional.
- Food objectives share one cream-colored tray with snack, donut and cake
  illustrations, receipt counts and completion checks. A short icon bounce
  follows actual receipt changes. Both maps retain the score target, timer,
  rival count, pause, boost and applicable skin ability.
- Timers become coral in the last 30 seconds. The tutorial exposes the actual
  goals before movement begins and hides inactive boost controls.
- Pause/results use the same rounded surfaces, soft shadows, highlights and
  Fredoka type. The Web defeat panel offers working replay/home actions;
  unavailable gem revival is removed, and rewarded video is shown only when
  the native ad bridge is present. Ad behavior and providers are unchanged.

All 15 new SVG illustrations are authored by `tools/build_ui_icons.py`.
They are original vectors with gradient highlights; no reference-game artwork,
screenshots or extracted assets are part of the runtime.

## Mobile layout and cost

The 540 × 960 logical layout retains portrait scaling. Every interactive
target is at least 64 logical pixels in its shortest dimension, which is at
least 44 points at a 375-point-wide portrait content area, including iPhone 14's
390-point width. This is layout arithmetic, not a physical-device test.

The main miniature and selected-skin viewports are disabled during play.
Library thumbnails render once and are released when leaving the library.
The taller thumbnail aspect initially exposed a narrow camera framing; a 3.1 m
orthographic size now admits all ten skins' base geometry with a four-pixel
margin. Shader-deformed GPU output still needs browser/device visual review.
Reusable panel styles are cached by appearance instead of allocated per draw.
Food counts reuse the existing receipt data. No world population, scene mesh,
physics, shadow or resolution setting is reduced.

## Verification

The new `ui_redesign_acceptance.gd` suite has 260 checks. It sends actual mouse
motion/down/up events through the viewport for map selection, skin navigation,
locked preview, equipment, PLAY, pause/resume, replay and return home. It also
checks phone-scaled hit targets, non-overlapping controls, thumbnail framing,
packaged icon content, order/victory agreement, preview shutdown and repeated
navigation cleanup. The 30-check title suite also passes.

The guarded Web release includes this suite, the existing skin suites and all
both-map physics/performance regressions, on source and the exported PCK. Final
source and packaged runs each pass **5,114 checks in 15 suites**, with no
failures. The delivered preview hashes match the manifest and the tested source
remains unchanged. Full counts and hashes are in
[`release/release.json`](../artifacts/ui-redesign-20260928/release/release.json).

## Visual evidence and reference scope

The comparison follows the previously inspected references:

- [Hole.io listing](https://play.google.com/store/apps/details?id=io.voodoo.holeio),
  especially the historic skin grid reproduced in the previous comparison.
- [Hole Em All](https://play.google.com/store/apps/details?id=and.brainworks.holeemall),
  especially pictured food goals and clear numeric counters.
- The original [Poki observation ledger](../fidelity/REFERENCE.md) records a
  different UI generation; none of these sources establishes pixel identity
  with the user's currently installed versions.

`artifacts/ui-redesign-20260928/layouts/` contains code-derived 2D layout
reconstructions, not engine/browser screenshots. The exporter runs the current
UI draw code with isolated fixture state and records geometry, text, colors and
real SVG icon rasterizations. Pillow approximates font emboldening, shadows,
button alignment and border rasterization. All 3D scene/preview areas are
explicitly omitted. Result scores are illustrative fixture values; they are not
completed playthrough receipts. Current source hashes accompany every layout.

The browser interface has been unavailable. No alternate browser control or
foreground game window is used. Physical iPhone 14 GPU, thermal and final
on-device appearance acceptance remain open.
