# Independent celebration runtime review — 2026-10-08

## Status and scope

**Final verdict: accept the corrected celebration and exact local Web Review
package, with no blocking runtime finding.** The ribbon error found in capture
02 is corrected; capture 03 and GPU 02 are clean, and focused gate 02 passes
1,123 checks per source/package phase. Its 1,333 inputs and 18 installed exports
independently match. The rejected evidence remains below. The independently
delegated runtime reviewer owns this document and narrowly scoped acceptance
assertions; root owns
production implementation and serial engine/capture execution. This review does
not authorize or perform publication, account actions, phone tests, real-save
changes, or audible desktop output.

The requested addition is a bounded original celebration at the first fresh
NEW SKIN reveal. The existing reel, winner, 100-coin draw, ownership, pity,
pending receipt, explicit equip, music and original cues are the baseline.
The preceding music delivery remains independently accepted at 97 suites and
176,645 checks on both source and exact package; those receipts are preserved,
not reused as proof for this new animation.

## Baseline and review contract

The current roadmap, latest history, conversation continuity guide, completed
case and music handoffs, case UI/audio code, Game/UI routing and the existing
case UI acceptance suite were inspected.

- A normal reel completion and SKIP must call the same reveal boundary. A fresh
  committed case receives one burst, even across repeated reveal/UI callbacks.
- Refresh, equip, odds, restored receipts and reopening a pending result must
  not retrigger a burst or change its winner.
- Enter/reset, hiding the panel, BACK and CONTINUE must end transient work.
  An idle or hidden effect must not schedule continuous redraw or retain
  unbounded particles, nodes, timers or callbacks.
- Focus loss, application suspension and tree pause must prevent advancement.
  Clearing one suspension cause must not override another.
- The effect must use bounded 2D drawing, ignore pointer input and fit the
  responsive safe canvas. It adds no 3D viewport or gameplay map.
- Decorative randomness must not consume the global/economy RNG. No economy,
  price, save, acquisition or equipment function belongs in the effect.
- Tests must retain existing transaction/input/layout assertions, use isolated
  progress and distinguish manual simulation from real-time GPU capture.

## Initial implementation guidance

The existing `reveal()` duplicate-result guard is the correct exactly-once
boundary. Its fresh-versus-restored argument already distinguishes natural
completion/SKIP from `reveal(false)` restoration. Triggering from drawing,
`controls()`, `sync_visibility()` or generic UI refresh would replay the effect.

The existing panel used one `focused` flag for both focus and application
suspension. A new effect must avoid letting RESUMED clear an outstanding focus
loss, or FOCUS_IN clear an outstanding application pause. Independent flags and
the tree pause state provide the necessary combined gate.

## Static candidate review

The first complete candidate uses one reusable `Control` with no child nodes,
textures, lights, emitters or new viewport. It draws at most 36 particle branches
and two 49-point halo outlines. Common through Prismatic have 26–36 particles;
the active duration is 1.60 seconds. The particle array is built once per fresh
reveal, then cleared. Inactive processing is disabled. This establishes a
concrete bounded workload, not a measured phone frame rate or GPU cost.

`CaseOpening.reveal()` starts the effect only after its duplicate-result guard
and only for a fresh reveal. Its existing model and result texture follow the
effect in child order, keeping the celebration behind the skin. `enter()` and
hidden/non-result visibility synchronization clear transient particles. Generic
refresh, equip and odds-return cannot call `start()`.

The effect uses its own `RandomNumberGenerator`, seeded from the already
committed presentation seed with a fixed xor. It does not call the global RNG,
Game, an economy method or a save method. No transaction, price, inventory,
acquisition, music or cue code is changed. It ignores pointer input.

The new controller has independent focus and application-suspension flags plus
a tree-pause check. Its frozen age resumes without replay after all gates clear.
The inherited reel's separate focus handling is unchanged; this review does not
misrepresent it as a newly redesigned lifecycle implementation.

**Static candidate verdict: accept for focused execution.** No blocking runtime
finding is present in this revision.

## Independent test extension

The existing `skin_case_ui_acceptance.gd` retains its transaction, input and
layout checks. Added checks exercise actual normal and SKIP reveal paths,
exactly-once starts, duplicate callbacks, refresh, equip during and after the
effect, odds hide/return, restored receipts, active CONTINUE cleanup, finite
completion and settled idleness. It also checks stacked focus/application
notifications, tree pause, bounded particle/node ownership, pointer behavior
and child drawing order.

A counting test-save override and before/after transaction snapshots detect
additional writes or economic mutation. Comparing the next global RNG output
around actual natural reveal detects decorative consumption of the economy's
RNG. All fixtures retain their empty progress path. Manually advanced and frozen
celebration samples are explicit; GPU observations record effect age, activity,
burst count and particle count. They do not claim real-time motion coverage.

No engine process was started by this reviewer. Root runs the engine jobs
serially; the reviewer independently inspects their files and logs below.

## GPU 01 and capture 02 evidence, before the ribbon correction

`artifacts/case-celebration-20261008/ui-gpu-01/acceptance.json` passes **712
checks**, with empty failures and no warning, error or leak lines in either
inspected log. The actual fresh reveal has one burst; Common and Prismatic
fixtures contain 26 and 36 particles respectively. The restored/equipped result
records zero active particles without increasing the burst count. These receipts
cover the added lifecycle, global RNG and save-count checks, as well as all
retained UI assertions.

This reviewer directly inspected Common and Prismatic peak renders, the short
viewport result and simulated safe-area result. Decorations remain behind the
skin, and text and controls remain clear. The requested 375-pixel desktop
viewport is reported by the engine as 374 by 666; the saved observation retains
that actual size. The safe-area image is a desktop fixture, not a phone image.

The capture script and `capture-02/capture.json` show a full natural Common
opening and an early Prismatic reveal. Each explicitly funded single-item
fixture spends 350 to 250 once. The committed award and balance remain unchanged
through the effect, and both bursts finish with processing disabled. The
10.066667-second H.264 file contains 604 frames at 540 by 960 and 60 frames per
second, with no audio stream. This is controlled rendered motion evidence;
encoded frame cadence does not establish phone performance or measured real-time
frame rate. The capture uses direct case actions; the separate GPU suite covers
actual pointer interactions.

The final visual adjustment increases ribbon/core visibility and uses a hard
`min(MAX_PARTICLES, ...)` bound. It does not change lifecycle, duration,
transaction behavior, save handling, or RNG isolation. The final source was
re-read after that adjustment.

## Focused package 01 and rejected capture

The focused source and exact-package gate each passes four suites and **1,123
checks**: case UI 678, case transaction 133, case audio 122 and world music 190.
The 712-check GPU run includes extra saved-image checks. All inspected focused
logs have no unexpected engine error or ObjectDB/resource leak; no known-platform
error allowance is needed in these runs.

This is a scoped gate for the cosmetic change, **not a rerun of all 97 suites**.
The preceding 97-suite music release is preserved and its referenced manifest
hash matches. Independently comparing all its 1,332 guarded inputs finds only
two existing files changed: the case panel and the independently extended UI
test. The new celebration script is additive; no previous input is missing.
In the new release, all **1,333 guarded inputs and 18 installed export files**
independently match their recorded hashes.

- Focused release receipt:
  `artifacts/case-celebration-20261008/focused-gate-01/release.json`
- Release SHA-256:
  `015b3f06d1c5056f16658db6aa74c032862aa8257069526b340e5e9bfa558761`
- Installed package: `build/case-celebration-20261008/web/index.pck`
- Package SHA-256:
  `06b0a372ffdda5c64578626b8eda907587d607317129ee693d28417ae26c30c9`
- Gate 01 celebration source SHA-256:
  `7ddbceeb91501866ae0f26e4b2218d6de2635961bc094cddd6d03d8f9386fcd2`
- Gate 01 case panel SHA-256:
  `7b4b709bbc02cc82f86d2b9125a597138f6dda3220105e1666dcdf439c93e059`
- Gate 01 independent UI test SHA-256:
  `51f5b67b2364dabbeb4721831658684514f3c990580717595ca90f314ce4905e`
- Independent verification receipt:
  `build/case-celebration-20261008/reviewer-runtime/final-review.json`

### Blocking finding from continuous capture 02

After the focused gate completed, this reviewer separately inspected
`build/case-celebration-20261008/capture-02.engine.log`. It contains **eight**
`Invalid polygon data, triangulation failed` errors at
`case_celebration.gd:94`. Capture 01 has no such errors, but it is the older
visual version. Root confirms capture 02 uses the final five-vertex ribbon
revision. Its successful transaction/completion JSON does not cancel these
render errors, and the clean sampled UI and headless receipts do not establish
that every continuous pose draws successfully.

The curved ribbon can fold or become degenerate as travel slows. Root will
replace arbitrary polygon triangulation with explicit bounded gradient
triangles, then repeat the same natural/skip capture with strict error scanning,
the GPU suite and focused source/package gate. The failed evidence is retained.
No error filter or behavioral assertion is weakened.

**Gate 01 acceptance was held until those corrections and exact candidate
receipts were reviewed.** Fresh normal and skipped results otherwise celebrate once;
navigation, restoration, completion and suspension remain bounded and tested;
the economy, global draw RNG, saves, existing sound and music remain unaffected
by decoration. Physical-phone performance, native signing/upload, browser
rendering and subjective full-speed viewing are outside this runtime verdict.

## Corrected final candidate and approval

The final ribbon uses three explicit three-vertex `draw_primitive` calls with
matching three-color gradients. This removes the arbitrary-polygon
triangulation that failed near expiry, while retaining the same 36-particle
maximum, 1.60-second duration, drawing order, independent RNG and lifecycle.
The reviewer re-read all three primitive calls; no production code or test was
edited by this reviewer in the correction.

**Capture 03 is accepted.** Its engine and stdout logs both contain completed
capture markers and no error, warning or leak diagnostic. The same seeded
natural Common and early Prismatic paths preserve the 350-to-250 transaction,
award and balance and finish with effect processing disabled. The replacement
video remains 604 frames, 10.066667 seconds, 540 by 960, 60 fps, without audio.
The new fading-tail render was inspected directly. Failed capture 02 is retained
with its own rejection receipt; its errors were not filtered out.

**GPU 02 passes 712 checks** and both inspected logs are clean. **Focused gate
02 passes 1,123 source and 1,123 exact-package checks**, retaining the same four
suite counts listed above. All 1,333 guarded source/asset hashes and all 18
installed export hashes are independently recomputed and match. The prior full
97-suite receipt still matches its referenced hash; this scoped change is not
presented as a fresh full regression run.

- Final focused receipt:
  `artifacts/case-celebration-20261008/focused-gate-02/release.json`
- Final release SHA-256:
  `f237a6a57afc0d949aa558a393a15f3df57802e2cabde5e911f7050fa497157e`
- Final installed package SHA-256:
  `00020b5d5c139633bd83b9a912900caa5acdba88a135773d8326bfed2ea9535c`
- Corrected celebration source SHA-256:
  `574f88f7856fdff2c14a249e07673d4fc0cc349e7f773b1032d0d9f2b1753303`
- Replacement video SHA-256:
  `a0697ce4f31c914b54430b7faa0b9f1888b9d6200b5dda159d1b4f8d0f9a4695`
- Final independent verification:
  `build/case-celebration-20261008/reviewer-runtime/final-review.json`

**Final acceptance: yes, with no outstanding blocking fix.** Exactly-once reveal,
restore/navigation cleanup, independent suspension gates, bounded ownership and
work, and unchanged economy/save/global-RNG behavior are supported by the
reviewed code and actual candidate evidence. The physical-phone, native upload,
browser and subjective-viewing limits stated above remain.
