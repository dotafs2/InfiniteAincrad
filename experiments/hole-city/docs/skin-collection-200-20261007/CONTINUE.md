# Common collection implementation handoff

## Current state

Twenty Common concepts and twenty actual in-game models are complete: six
existing Common skins were reworked and fourteen stable IDs were appended.
The local catalog contains sixty skins. Submitted version 0.13.0/build34 and
all real user saves remain unchanged. This task is local development only.

Source gate03 passed all 92 suites / 77,763 checks. Its Web export failed because
root invoked the MONO editor, which does not support Web export. The original
failure log remains. Export resumed with the existing standard Godot editor at
the identical 4.7.2 / ed1daf0bf revision. The resumed export succeeded and all92 package suites pass77,763checks, matching
source. All863 guarded inputs remain unchanged during resumed export/package
acceptance. Exact-PCK GPU acceptance passes725checks with identical model/effect
rows to source. Browser startup, muted settings and HOLES60 render normally;
no warning/error logs were observed in that inspection.

All owned engine/test jobs have completed. All implementation workers are frozen;
the final independent read-only audit confirms preservation of the original46
catalog identities, five protected gameplay/save/economy files and seven final
key source hashes. Do not rerun the full source gate
without a changed guarded input or new failure.

## Implementation

- `fidelity/common_geometry.gd`: twenty cached authored ArrayMesh models;
  broad theme-specific forms and 3–5 material regions.
- `fidelity/common_surface.gdshader`: inexpensive lit material variation.
- `fidelity/common_skin.gd`: cosmetic whole-model bounce and seven themed
  particle profiles. Fixed eight-instance pool; items use two instances for
  0.25s, rivals eight for 0.72s. Item feedback cannot erase an active rival cue.
- `fidelity/skin_visual.gd`: actual player and collection preview dispatch to
  the same cached geometry; independent transforms and feedback controllers.
  Common handles its rival cue once, without a duplicate generic burst.
- `fidelity/skin_catalog.gd` and `skin_rarity.gd`: catalog60/Common20, first46
  stable identity/order preserved, append-only additions. Prices, rarity weights,
  score-to-coins, draw guarantees and all ownership migrations remain unchanged.
- Existing tests were updated for the real catalog and Common feedback path.
  Native polish checks both actual Common and original Copper Ring combat.

`COMMON.md` lists the twenty identities. `PLAN.md` retains the future200 total
allocation. Current implementation is60, with140 further skins remaining.

## Visual evidence

- `artifacts/common-concepts-20261007/`: twenty original concept PNGs and a
  manifest containing exact image-generation prompts, paths and hashes.
- `artifacts/common-runtime-20261007/`: final Capture04, forty idle/rival PNGs,
  `all-20-in-game.png`, two actual collection UI screenshots and interactive
  gallery. The forty isolated pictures manually trigger cosmetic rival feedback;
  they do not claim normal gameplay.
- `artifacts/common-gameplay-20261007/`: Cookie Bite and Rope Coil each have a
  muted forty-second full-map Mac gameplay clip. Each records23objects,1rival,
  zero deaths and score0→36. Ordinary movement and charged boost drive normal
  spawned entities with seven AI; no staged rewards, props or rival callbacks.
  Videos fully decode and contain1200frames at30fps. Fixed simulation and scripted
  movement are not a real-time performance benchmark.
- The independent reviewer rejected earlier mouth gaps, weak Mitt and Acorn
  silhouettes and floating Knit loops. Final Capture04 accepts all twenty as
  stylized Common skins. Concept illustrations still contain richer detail.
  Runtime feedback uses one whole-model bounce and seven pooled profiles; it
  does not animate twenty independent articulated object mechanisms.

Final capture hashes precede the shortening of three description strings for
Acorn Cup, Catcher's Mitt and Knit Cap. Geometry, materials and gameplay are
identical. Do not rewrite the original capture source manifest to hide this
text-only difference. `delivered-source.json` records the final seven key hashes.

## Acceptance and retained failures

All receipts below are under `build/common-skins-20261007/` unless stated otherwise.

- `common-gpu-03.json`:725 checks,20 distinct vertex geometries, preview/runtime
  cache and controller isolation,256 callback stress receipts per skin, pool
  retirement and full triangle capacity. Maximum preview capacity4256, including
  all eight reserved particle slots, below4500. Main models peak3280.
- `rainfall-gpu-01.json`:117 unchanged-weather GPU checks.
- `tail-source-01/`:all16 remaining suites pass, including real UI wrapping10781.
- `web-gate-03/source-*.json` and `package-*.json`:all92 suites pass in each
  phase,77,763checks per phase. `release.json` records the863 guarded inputs and
  published Web artifact hashes. `package-gpu-receipt.json` records725 exact-PCK
  GPU checks with identical source geometry/effect rows.
- `build/common-integration-20261007/final-audit.json`:independent read-only
  catalog/save/economy audit. Existing44identity hash and all46existing metadata
  identities remain; six isolated cold-save fixtures preserve wallets, selection,
  pity and original ownership with14new skins locked.
- Gate01 exposed a stale generic-rival-burst fixture; actual two-path native
  combat acceptance now passes350checks. Gate02 exposed three truly overflowing
  descriptions; they were shortened and the final retention UI check passes.
- MONO export failure is retained at `web-gate-03/export.log`; the successful
  standard editor export is `export-standard-04.log`. The resumed package run
  retains all source receipts and checks the frozen full863-input manifest.
  The original source-start hash dictionary was in process memory; the normal
  source gate verified it before export, but it was not saved after export failed.
  Resume records a fresh full manifest and verifies final source key hashes.
- Initial headless Dummy MultiMesh readbacks are not valid GPU evidence and
  remain as failed checks. Final Common and Rainfall probes use a real GPU.
- Geometry, visual and helper failures remain in named before-* directories,
  earlier captures and logs. They were not deleted or relabeled as successes.

## Deliverables and remaining work

Artifact gallery server exec83140 listens on127.0.0.1:8786 and should remain:

- Actual models: http://127.0.0.1:8786/common-runtime-20261007/index.html
- Concepts: http://127.0.0.1:8786/common-concepts-20261007/index.html

The verified playable preview is http://127.0.0.1:8787/?qa=1 (owned server
exec3610, PID41922). The qa=1 URL uses isolated in-memory test state, so its
1/60collection does not represent the user's save. Browser settings are muted
for this open test session. Ordinary index visits do not enable test mode.
`browser-holes.jpg` is the actual browser screenshot after opening HOLES.
Keep both local preview servers as deliverables; no engine/test helpers remain.

`build/common-skins-20261007/delivery.json` records exact final receipts, browser
scope and server ownership. The PCK SHA-256 is
`fc0a9a044f458abb4177251be437de4fc3b42fbac4b5de20006b95b47c2eee02`.
The artifact delivery manifest links final source hashes to actual images/videos.

No phone, TestFlight/App Review, Apple/AdMob, legal, purchase or Git action was
performed. Current batch is not present in the submittednative34. Native device
performance and the remaining140 planned skin slots are future work, not blockers
to this completed local implementation. Review the Common visuals before choosing
a further tier or requesting a native release package.
