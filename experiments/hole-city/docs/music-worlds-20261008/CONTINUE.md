# Distinct world music — 2026-10-08

The user requests GPT-6 ultra work and two independent approving reviewers for
distinct map, menu and case music, sourced with free-use licenses or authored
originally. Reviewers `music_art_review` and `music_runtime_review` run on
GPT-6 Astra with ultra effort. The main session model was not changed by a tool.

## Current state

Implementation, recorded review and final exact-package verification are complete.
Both independent reviewers have recorded final PASS verdicts with no blocking fix.
Gate 02 passes 97 suites and 176,645 checks in each source/package phase.
All 1,332 guarded inputs and 18 installed export files match the final receipt.
The new loopback-only preview is <http://127.0.0.1:8792/> (owned server PID 96101,
session 49344); preserve it as a deliverable. Actual browser HOME renders normally
with no observed warning/error console messages; see `browser-startup.png` and
`browser-check.json`. No browser gesture or playback was used for that check.

Baseline files are preserved in `build/music-worlds-20261008/baseline`. Previous
verified case preview at 8791 is retained. No phone, native upload, Apple/AdMob,
real purchase, user-save or Git publication action is included. Build 34 remains
unchanged.

## Six roles

| Role | Composition | Source |
| --- | --- | --- |
| HOME / STORE / HOLES | Buy Something! | Cleyton Kauffman, CC0; unchanged full 88-second menu packet |
| Sunny City | Hometown | Juhani Junkala, CC0; 90 seconds |
| Snack Garden | Sunshine Coast | Juhani Junkala, CC0; 112.3 seconds |
| Bubble Toy Town | Children's March Theme | Cleyton Kauffman, CC0; 64 seconds |
| Frostlight | Through the Snow | Cleyton Kauffman, CC0; author-supplied slowed 34.3-second loop |
| Skin case | A Little Wonder | Original 40-second D-major score; no third-party samples |

Primary author pages, source archives, exact member hashes, modifications and
creator credits are recorded in `assets/audio/music_manifest.json` and
`assets/audio/MUSIC_CREDITS.txt`. The mirrored legal credits are synchronized.
Six unique streaming packets total 5,532,402 bytes. New preparation uses
restrained EQ, constant loudness matching and a 3 ms seam guard; full source
tempo and duration remain. The original case opening is now 4.25 seconds; the
other seven cue WAVs are byte-identical to the baseline.

One streaming player has explicit menu/gameplay/case routing, 200 ms fade-out /
300 ms fade-in, per-track bookmarks, latest-request handling and 7 dB roll duck.
Visible rewarded ads suspend Music/SFX before provider presentation, without
conflating an unclaimed reward receipt with a visible ad. Existing independent
preferences, native start, browser gesture and focus/pause gates remain.

## Evidence so far

- Final eight focused suites pass 1,773 checks with zero failures. The independent
  `world_music` suite passes 190, including actual in-memory native end crossings
  of all four new map streams. Other final receipts are in `focused-02`.
- `tools/build_case_audio.py --check` proves exact deterministic bytes for all
  eight cues. All six music packet hashes and mirrored manifests/credits match.
- `capture-01/music-showcase.mp4` is a 45.35-second actual Mac GPU/mixer recording:
  menu, four map introductions, complete opening and an early skip. These map
  sections are not ordinary gameplay or full-round SFX mixing. The isolated
  fixture makes two 100-coin draws, from 500 to 300, without touching user saves.
- Both reviewers independently verify the stereo 48 kHz captured PCM. There are
  zero clipped samples and peak amplitude 0.1590576. Actual skip-boundary evidence
  is retained; numerical discontinuity checks do not prove subjective quality.
- Video SHA-256: `db9a075de926f87975b08a49642be2d7ea8b91a38eced3d6a1b4c51bd8ee685a`.
- Music manifest SHA-256: `a03739163acb247885c5f0fca7a3532c1ddcbf15ec2abe7665b42664e625b7b4`.
- Gallery: <http://127.0.0.1:8786/music-worlds-20261008/index.html>.
  Six full tracks and the video use manual playback, with no autoplay.

## Preserved failures and limits

The first preparation lacked NumPy in system Python; the bundled runtime fixed
it. An optional CC0 landing-page snapshot returned HTTP 403; all primary author
pages and music archives were retrieved. A case duration assertion retained the
old 0.4-second bound and was corrected to 4.25 seconds. The first legacy music
fixture read menu audio after selecting a map refreshed HOME; explicit gameplay
fixture setup corrected it. All failures and receipts remain. Decoder warnings
from the unchanged old menu file are isolated in reviewer evidence; the five
new recordings decode cleanly.

Signal, score, visual-context and code checks do not constitute subjective
listening, physical-device loudness/performance measurement, or native SDK ad
interruption validation. Host speakers stayed muted during capture. No music
packaging for iPhone, native upload or store update is claimed.

## Delivery and remaining limits

- Local playable preview: <http://127.0.0.1:8792/>.
- Six complete tracks and actual Mac mixer video:
  <http://127.0.0.1:8786/music-worlds-20261008/index.html>.
- Full evidence: `artifacts/music-worlds-20261008/web-gate-02/release.json` and
  `artifacts/music-worlds-20261008/final-verification.json`.
- Final independent reviews: `ART_REVIEW.md` and `RUNTIME_REVIEW.md` in this folder.
- Native build 34 remains unchanged. Any next iPhone release needs a fresh native
  build and physical-output check. No new blocker for this local deliverable is
  recorded; subjective audition remains distinct from the documented review.
- Do not rerun the passing complete gate without a changed guarded input, new
  failure or concrete unresolved concern. The owned gate/test jobs have exited;
  the loopback preview server is intentionally retained.

### Gate 01 teardown failure

All 1,701 coin/skin assertions passed, but strict exit checks rejected four leaked
Ogg objects / one resource. Verbose focused-04 reproduces the exact objects. The
fixture stopped the player, then yielded one frame while a case-to-menu fade was
still pending; the live audio controller could start a new decoder after that
drain. Freeze that fixture-owned audio controller before its existing stop/drain.
No assertion, error filter, production file or player save changes for this fix.
The runtime reviewer independently confirmed the mechanism. Focused-05 verifies
the corrected teardown before a fresh full gate.

The runtime reviewer identifies six other concrete final-teardown pending-route
paths in retention_ui_review, food_growth_review, boost_review,
train_surface_review, train_review and review_ui_collection. Apply the same
terminal-only audio processing stop before their existing decoder drain. Tests
retain all assertions and timings before the final check. Production runtime,
assets and capture hashes remain unchanged. Gate 02 passes all seven corrections
in both source and exact exported package. Gate 01 is preserved, not overwritten.

Gate 02 completes with 97 suites and 176,645 checks in each phase. The installed
Web export matches all 18 recorded file hashes. Native upload remains outside
this task. Initial sandbox loopback binding was denied; the normal approved
local-server launch succeeds and its first failed log is retained.
