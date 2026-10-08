# Close map thumbnail handoff — 2026-10-08

## Delivered

The user requests closer, more thematic map-selection screenshots, ideally
about five or six major structures with inhabitants. Replace all four distant
world overviews with actual GPU close-ups. Only the capture helper and four
880×620 PNGs change among guarded inputs; game/UI code, import settings,
lighting, geometry, actor positions, progression and saves remain unchanged.

| Map | Final focus | Orthographic size | Camera offset | Main composition |
| --- | --- | --- | --- | --- |
| City | (0,4,17) | 33 | (48,46,58) | Six streetfront buildings, cars and pedestrians |
| Food | (-42,4.5,24) | 23 | (-30,44,-58) | Central cake/burger/pastry stacks and people along the near lane |
| Toys | (24,4,34) | 32 | (-48,42,52) | Colorful castle/cottage fronts, a main castle and guard lane |
| Frost | (71,3,-69) | 31 | (60,40,-22) | Faceted snow-covered ice, supporting rocks and four visible penguins |

Food retains secondary stacks; do not claim exactly six total objects. The
change prioritizes a few dominant thematic groups. Small-card inhabitants are
recognizable silhouettes, not a promise of visible facial detail.

## Capture and review

Use `tests/map_thumbnail_capture.gd` with the project Godot, actual GPU,
`--audio-driver Dummy --resolution 880x620 --fixed-fps 60`, then
`-- --test --capture-dir=<absolute path>`. `--survey` records alternative camera
framing; `--only-map=<id>` narrows an adaptive capture. The helper explicitly
grants isolated in-memory map entitlements before `_ready`, verifies requested,
selected and constructed map IDs, and rejects non-test/headless/save-file use.
Existing Idle animations are evaluated once, the unchanged world is frozen,
holes hidden and inactive, ground cuts/reveal reset, and all sound muted. No
people, geometry or props are moved, rescaled or generated for the screenshot.

Preserve survey01/survey02 as rejected or intermediate compositions. Initial
food crossroads were too empty and crowded at the edges, toy backs hid the
cheerful fronts, and the first reversed glacier view was too dark. Final
capture03 recenters the pastry/castle blocks and selects the east-side glacier
view. All four final PNGs match the installed assets byte-for-byte.

The two reused independent reviewers accept final raw screenshots and actual
locked/unlocked, short/tall and simulated safe-area carousel cards:
[art review](ART_REVIEW.md), [runtime review](RUNTIME_REVIEW.md).

## Verification

- Existing real GPU map-carousel suite: 574 checks, zero failures, 13 actual
  card/layout images in `artifacts/map-thumbnails-close-20261008/ui-gpu-01`.
- Focused source and exact exported PCK: map-carousel 561 + map-unlock 92 =
  653 checks per phase, zero failures. No tests added for this static art edit.
- `focused-gate-01/release.json` pins 1,333 guarded source inputs and all 18
  installed export files. Exactly five intended deltas from the accepted
  celebration baseline: four PNGs and the capture helper. No missing input,
  runtime or import-setting change. This is not a new full 97-suite gate.
- Complete capture/import/GPU/export/source/package logs are clean.
- Actual Web HOME at 8794 visibly uses the new City close-up and has no observed
  browser warning/error logs. Gallery old/new controls were exercised and left
  displaying new images. Browser evidence is alongside the final gallery.

## Deliverables and recovery

- Updated game: http://127.0.0.1:8794/
- Four-image comparison: http://127.0.0.1:8786/map-thumbnails-close-20261008/index.html
- Final rendered PNGs: `artifacts/map-thumbnails-close-20261008/capture-03/`.
- Overview: `artifacts/map-thumbnails-close-20261008/overview.png`.
- Manifest: `artifacts/map-thumbnails-close-20261008/delivery.json`.
- Baseline copies and process state: `build/map-thumbnails-close-20261008/`.

Retain the new loopback server (PID in `preview-server.pid`) and previous
previews as deliverables. All owned heavy capture/import/export/test helpers
have exited. Preserve submitted 0.13.0/build 34 and all real saves. There was no
phone, account, production ad/purchase, native signing/upload or Git action.
Physical-phone performance and a new native package remain outside this change.
