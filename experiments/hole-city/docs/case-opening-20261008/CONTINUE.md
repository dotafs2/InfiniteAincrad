# Case opening handoff — 2026-10-08

## Completed local delivery

The final `web-gate-03` succeeds: source and exact exported PCK each pass
96 suites / 176,455 checks, zero failures. All 1,318 guarded input hashes and
18 exported file hashes match after completion. `final-verification.json`
contains the exact release/PCK/video hashes. Do not rerun this unchanged gate.

Preview: http://127.0.0.1:8791/ (HOLES → OPEN CASE).
Review: http://127.0.0.1:8786/case-opening-20261008/index.html.
Delivery video: `artifacts/case-opening-20261008/capture-04/case-opening.mp4`.
Mac GPU UI acceptance passes647, transaction133, audio122 and thumbnail bake2,005.
The actual final browser package boots into HOME; its console has no observed
warnings/errors. `browser-home.png` and `browser-review.png` preserve the visible
results. Browser verification uses no-save QA mode and does not spend currency.
The focused GPU tests, not browser spending, establish the case interaction path.

The full gate process exited0. Preview server PID85568 / exec session32194 is
retained deliberately, with its PID file in the ignored build directory. Earlier
preview and artifact servers remain. No case capture/test process is left running.

This is a local Web/desktop delivery. No new iPhone build, native performance
measurement, TestFlight/App Review change or Git publication is included. Actual
player saves remain untouched. Currency recharge/exchange and the accepted
100-coin draw / score-based earnings remain. The case has200 total skins, one
unowned award per opening, existing disclosed odds/guarantees, and explicit equip.
Original art/audio are used; no third-party game assets or recordings are shipped.

The sections below preserve intermediate findings and failed/superseded attempts;
they are historical, not the current completion state.

## Authorized scope
Replace visible skin acquisition with one random case-opening flow: real skin reel, rarity colors, original sounds and result/equip. Preserve all existing ownership, map progression and the 100-coin/no-duplicate economy. Currency recharge/exchange remain available; no account, legal, native upload or Git publication action is included in this local UI iteration.

## Current implementation
- Game commits debit, awarded skin, pity counters and pending case receipt atomically before presentation. Reentry restores the same award; EQUIP is explicit. Legacy API remains only for compatible callers/tests and rejects a pending case.
- `fidelity/case_opening.gd` owns one cached-image reel and a single live result model. Four-and-a-quarter-second deceleration, fixed center marker, SKIP and persistent result recovery.
- Six existing tiers remain Common, Uncommon, Rare, Epic, Legendary and Prismatic. Existing changing odds remain visible before purchase.
- Original synthesized sound helper and eight bounded WAVs are complete. Two voices, SFX preference and focus muting.
- 200 actual-model transparent256px thumbnails baked on the Mac GPU: 2,005 checks, zero failures; exact manifest in assets/skin_thumbnails/manifest.json.

## Evidence and pending validation
Baseline and exact input hashes: build/case-opening-20261008/baseline/manifest.json. Previous verified carousel preview remains available on8790.
First transaction execution was invalid because the new case UI had one GDScript type inference error and a transaction fixture assigned an untyped array to a typed property. Its output is preserved; a zero-failure marker in that run is not treated as success. Corrections are in progress, followed by clean engine parsing, focused transaction/UI/economy tests and real GPU review.
No physical-device or Store publication claim. No user save has been opened or modified by these tests.

## Reference boundary
The official Counter-Strike Revolution case presentation informed the horizontal reward hierarchy, item pool and fixed outcome marker. Hole Feast retains its own skin geometry, names, six-tier palette and original audio, without external branding/assets/samples.
Primary reference: https://www.csgo.com.cn/article/details/20230210/225529.html
Apple randomized virtual-item rules reference: https://developer.apple.com/app-store/review/guidelines/ — current probabilities must remain accessible before a draw.

## Focused acceptance complete
Final GPU UI acceptance `ui-03`: 641 checks, zero failures. The headless equivalent before final eligible-preview assertions passed555. Transaction133 and audio122 pass with strict engine-log checks. Coin/economy pointer suite passes1,701 checks; title navigation37. Empty legacy pity dictionaries were made safe after `ui-01` exposed their missing-key assumption; all failures are preserved.

The verified continuous clip is `artifacts/case-opening-20261008/capture-03/case-opening.mp4`, 540x960 at60fps. Its isolated1000-coin fixture opens exactly once to900 and explicitly equips Fox Den. Earlier captures01/02 requested taller screenshots while the movie writer retained540x960; they are diagnostic evidence and are not the delivery video. Tall screenshots,375px short screens and16 Pro Max safe-area desktop fixtures are in `ui-03/`.

Full96-suite source/packaged gate is running in `artifacts/case-opening-20261008/web-gate-01`. Do not modify guarded inputs during it. Separate target preview: `build/case-opening-20261008/web`, planned loopback8791. Previous8790 preview remains untouched. Review gallery: `http://127.0.0.1:8786/case-opening-20261008/index.html`.

## Full gate01 stopped — legacy resource-count assertion
Source ui_redesign completed7,557 checks and reported that it still expected exactly two permanent preview viewports. The new case owns a third reusable result viewport, which is disabled outside the result. The old count assertions are being updated to the new exact bound plus explicit disabled-render checks outside the case; no leak or active extra renderer was observed.19 preceding suites passed; do not claim the failed gate as a release. Full gate02 will run after the bounded test migration.

## Gate02 source complete; package validation running
All96 source suites pass176,449 checks. Guarded inputs remained unchanged through source completion and Web export. The exact exported PCK is now undergoing the same96 suites. Do not claim package completion before release.json exists. The final independent UI reviewer accepts the641-check GPU images and bounded samples from the565-frame video; no full-speed playback, audible-listening or physical-phone claim is made.

## Concrete late review correction: CONTINUE double-tap
Root identified overlapping CONTINUE/next OPEN targets: a fast queued second pointer after the old4.25s reel could initiate another draw. Gate02 was intentionally interrupted using its confirmed owned Python PID, whose cleanup handler terminated its child; prior reports remain. Successful result acknowledgement now reuses the existing800ms acquisition debounce. READY disables OPEN only during this brief guard, with a one-shot re-enable check rather than repeated catalog scans every frame. The UI acceptance now sends a real repeated pointer at the prior CONTINUE location and a direct callback, then waits820ms and confirms normal readiness without spending. GPU run04, fresh clip04 and full gate03 are required before final delivery.

## Final guarded candidate
GPU run04 passes647 checks, including real pointer replay at the previous CONTINUE position, direct callback rejection during800ms and normal re-enable after820ms without spending. Reviewer accepts this boundary. Final refreshed video is `capture-04/case-opening.mp4`: 540x960,60fps,565frames, one actual isolated1000-to900 draw and explicit Fox Den equip. Capture03 remains older diagnostic evidence. Source/tests are frozen; `web-gate-03` is the final full gate, exec session61332, stdout `build/case-opening-20261008/web-gate-03.stdout`. Do not stop or rerun without a new failure. Native uploads and user saves remain untouched.
