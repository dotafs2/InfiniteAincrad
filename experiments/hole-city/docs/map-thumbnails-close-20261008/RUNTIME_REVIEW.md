# Independent close-thumbnail runtime review — 2026-10-08

## Status and scope

**Final verdict: accept the four close thumbnails and exact local Web Review
package, with no blocking runtime finding.** Root owns the capture script and
four baked PNGs; this reviewer makes no production or test-source edits and runs
no engine jobs. The requested change is closer
composition around approximately five or six thematic buildings or landforms,
with existing people or animals visible. It does not authorize changes to the
world geometry, gameplay, prices, unlock progression, saves or live UI behavior.

The current roadmap, latest history, conversation continuity guide, previous
map-selection handoff, capture script, carousel implementation and acceptance
suite were read. Related Game initialization, world construction, people/actor
animation and hole/reveal behavior were inspected where needed to assess the
capture fixture.

## Initial capture findings

1. The inherited capture assigns `selected_map` before the Game enters the tree.
   Game initialization resets locked selections to City unless the isolated
   fixture explicitly grants access. A filename alone is not proof of the world
   actually rendered. The capture must establish test-only entitlements and
   verify both the selected map and the constructed world's `map_id`.
2. Require test mode, an empty progress path, real GPU rendering and actual
   880-by-620 pixels. All four maps must use their production world builders and
   existing assets. Record actual world identity and camera parameters.
3. Catalog people queue their existing Idle animation during construction.
   Disabling the world before its first animation update can preserve an import
   pose. Evaluate the existing animation once before freezing, without starting
   ordinary gameplay or moving/spawning actors for the composition.
4. If any world warm-up is used, deactivate hidden holes, synchronize the ground
   and reset player-driven building reveal. Merely hiding a hole mesh does not
   remove its active opening. Frozen geometry, a composition camera and hidden
   HUD should be the only presentation changes in the final image.
5. Keep all four texture dimensions, import settings, resource paths and card
   aspect behavior unchanged. A closer baked photo requires no extra live
   viewport, node, animation or runtime world construction.

## Smallest relevant validation

The existing `map_carousel_acceptance.gd` already checks all four screenshot
resources and dimensions, aspect-preserving crops, non-intercepting images,
actual swipe/arrow/PLAY routing, locked previews, short/tall safe layouts and
bounded viewport ownership. Run that existing suite against source and the exact
export, with one actual GPU carousel run to inspect the new photos in cards.
It must retain plain test mode; this suite intentionally rejects the all-worlds
unlocked flag and constructs its own entitled profile later.

No new mirrored test suite is warranted for this cosmetic edit. Hash comparison
against the preceding accepted celebration release should show only the capture
script and four PNGs among guarded inputs. Inspect the complete capture/export
logs, not just completion JSON. Preserve rejected framing and any failed runs.
Verify final PNG dimensions, hashes, unchanged imports, exact package artifacts
and actual card renders before acceptance.

An image's closer framing does not establish phone performance, and desktop
safe-area fixtures are not physical-device evidence. This review performs no
account, native upload, Git publication or real-save action.

## Revised capture source review

The revised script addresses the identified fixture risks. It grants only the
in-memory test instance's map access before Game initialization, checks requested
selection against the constructed world's identity, asserts test mode and an
empty progress path, requires a GPU display, and verifies 880-by-620 pixels.
It evaluates existing AnimationPlayers once, disables world processing, hides
and deactivates holes, synchronizes the ground and resets player-driven reveal.
Music/SFX and audio-controller processing are disabled. Each instance is freed
after its captures. No gameplay is started to move actors for a staged scene.

Each record identifies requested/resolved/world map, camera focus/offset/size,
file path and pose policy. Optional survey/one-map captures are composition
tools; final delivery must still identify four selected images with matching
source hashes. No geometry, material, actor placement or production runtime
change is introduced by this capture revision.

**Static capture correctness: accepted.** Final image/package acceptance remains
pending. Important subjects must also survive the real card crop: tall carousel
photos become more square and use `KEEP_ASPECT_COVERED`, trimming more of the
source's left and right edges. Raw PNG composition alone is insufficient evidence
that the requested buildings and people remain readable in the delivered UI.

## Selected source images and actual carousel evidence

Both 12-image surveys identify the correct requested/resolved/constructed world
for every image and have no engine error, warning or leak diagnostic. The final
four images come from `artifacts/map-thumbnails-close-20261008/capture-03/`.
Its complete log is also clean. Recorded orthographic sizes are City 33, Food
23, Toys 32 and Frost 31; each uses only a camera composition over its original
world, evaluated Idle poses and frozen geometry.

All four delivered `assets/map_thumbnails/*.png` files are independently hashed
and byte-identical to their selected capture-03 originals. They remain 880 by
620 and total 1,658,032 PNG bytes. Each existing `.png.import` file is unchanged.
Comparing all 1,333 guarded inputs with the preceding accepted celebration
release finds exactly five changed files: `tests/map_thumbnail_capture.gd` and
the four PNGs. No previous file is missing. Runtime, carousel test, import
recipes, world assets, economy, unlock logic and save code match that baseline.

The existing GPU carousel suite passes **574 checks** with empty failures and
13 recorded views. Its stdout and engine logs contain no error, warning or leak
diagnostic. This reviewer directly viewed assembled City, Food and Toys tall
cards and the short Frost card. The new actual-world images remain inside their
rounded card regions, with the labels, wallet and navigation controls clear.
The existing tests also retain locked-preview/PLAY behavior and safe layouts.
No new or mirrored test was authored for this change.

**Source and GPU integration verdict: accept.** Final exact-package verification
is recorded below.

## Final package verification

The scoped gate passes **653 source and 653 exact-package checks**: the existing
carousel suite passes 561 and map-unlock suite passes 92 in each phase. It is a
focused acceptance of this static-thumbnail edit, not a new full 97-suite run.
The earlier accepted celebration baseline and its referenced hash are preserved.

This reviewer independently recomputes all **1,333 guarded input hashes** and
all **18 installed export hashes**. They match the final release receipt. Its
input key set is unchanged, and the only five changed guarded files are exactly
the capture helper and four selected PNGs. The source/capture image matches and
unchanged import recipes are also reconfirmed. All 21 available capture, import,
GPU, source/package and export logs were scanned completely: no unexpected
engine error, warning or ObjectDB/resource leak was found.

- Release receipt:
  `artifacts/map-thumbnails-close-20261008/focused-gate-01/release.json`
- Release SHA-256:
  `2b49d1a342d7e83ae098a94cd73502db6d4bfd84f90bdd8565a52d40fcb3a7a4`
- Installed package: `build/map-thumbnails-close-20261008/web/index.pck`
- Package SHA-256:
  `a1524fba2c2a64e1f256a76bbc0ac950465f39e21970d0871a0bdf87939cea02`
- Final capture source SHA-256:
  `ff188877acfd5cf6ae48cdffa3e68f6d1984b7f69b1b6f22745964cbb9e289e4`
- Independent verification, including all four image hashes:
  `build/map-thumbnails-close-20261008/reviewer-runtime/final-review.json`

**Acceptance: yes, no further runtime fix requested.** Actual world identity,
pose/freeze correctness, original asset use, unchanged runtime and imports,
existing input/unlock behavior, assembled cards and exact package bytes are
supported by the inspected evidence. Visual scene selection is separately
accepted in `ART_REVIEW.md`; its Food view includes secondary background stacks
and is not described as literally containing only six objects. No physical-phone
performance, native upload, real-save access or new full regression run is claimed.
