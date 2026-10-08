# Case reveal celebration: independent art review

Reviewer: `music_art_review`.
Date: 2026-10-08.
Scope: independent art direction and review of supplied actual rendering
evidence. Root owns production implementation and engine execution. This
reviewer may edit this document only; no production, asset or test edits,
engine jobs, external account actions or physical-device actions are performed.

Current status: **final PASS for replacement capture 03, GPU 02 and focused
gate 02**. The earlier capture 02 / focused gate 01 approval is superseded by
the rendering error documented below. The latest exact-package hashes and
closure are at the end; prior stage results remain as historical evidence.

## Baseline and intent

Read the current repository roadmap, latest history and conversation continuity
instructions, then inspected `fidelity/case_opening.gd`, the existing rarity
palette in `fidelity/skin_rarity.gd`, and the earlier case UI review. Directly
viewed the actual rolling/result images from
`artifacts/case-opening-20261008/capture-04/` and the result image from
`artifacts/music-worlds-20261008/capture-01/`.

The existing result is a dark navy portrait screen with a large centered live
skin, a restrained tier-colored panel and concentric rings. Its model panel
occupies design-space `(24,221,492,359)`, followed by rarity at y614, the skin
name at y656 and status at y695. The title and subtitle sit above the panel;
EQUIP and CONTINUE sit below. The baseline is readable but changes from the
moving reel to the result without a pronounced celebratory outward motion.

The user's requested effect should make that transition feel rewarding with
visible flying sparks and a short firework-like expansion. The awarded skin
remains the focus. The effect should retain the existing rounded, cheerful game
style and restrained reveal sound, without introducing a separate cinematic
scene or extending the wait to equip the skin.

## Proposed visual direction

- Center the initial expansion around the model at approximately `(270,405)`.
  A brief, low-opacity expanding halo gives the reveal a unified starting point.
  Avoid a full-screen white flash or an opaque circular wash across the model.
- Use approximately 24–32 tapered comet trails with small light cores, a few
  four-point star tips and small trailing sparks. Let the first 0.2 seconds
  expand quickly, followed by decelerating outward/upward travel and a smooth
  fade over approximately 1.5 seconds total. Stagger secondary spark lifetimes
  slightly so the motion ends gracefully instead of all particles vanishing
  together.
- Keep the main trails behind the live skin and let visible sparks frame its
  silhouette. Preserve a clean title/subtitle, readable rarity/name and unchanged
  EQUIP/CONTINUE controls. The effective decorative region should remain below
  the subtitle and above the rarity text, roughly y210–592 at the 540-unit
  reference width. Avoid conspicuous hard clipping at the edges.
- Use the existing rarity colors: silver Common, green Uncommon, blue Rare,
  violet Epic, amber Legendary and pink/rainbow Prismatic. Light cores give
  contrast against navy; Prismatic may use the existing rainbow palette.
  Common should still receive a complete, pleasant celebration. Do not imply a
  higher rarity through an unrelated dominant gold treatment.
- Keep the effect bounded and cosmetic. Repeated redraw, equip, odds return or
  an already saved receipt must not create an endlessly replaying celebration.
  Both a natural reel completion and an explicit SKIP should receive the same
  clear reveal event. No new controls or full-screen interaction layer are needed.

## Required rendered review

Inspect supplied actual GPU frames at onset, peak expansion, fading tail and
settled result, and sample the short muted capture across the transition. Check
one natural full opening and one early skip, and assess both Common and
Prismatic extremes if supplied. A short/tall responsive fixture should establish
that the effect fits the existing transformed reward panel without moving into
the title, name or buttons. Desktop fixtures must remain labelled as such.

At this initial stage, the original bounded 2D direction is accepted for
implementation. Final art approval is pending actual rendered evidence; this
document does not infer beauty, motion quality or performance from code alone.

## First actual render: visual revision required

Directly inspected all ten onset/peak/drift/tail/settled PNGs in
`artifacts/case-celebration-20261008/capture-01/`. These are actual 540x960 Mac
GPU captures. The accompanying receipt identifies a natural Common Plain Loop
opening and an early-skipped Prismatic Aurora Rift / Solar Rift opening in
explicit one-skin isolated pools. They are controlled presentation examples,
not claims of organically drawing those rarities. No video motion or timing
review is inferred from these PNGs.

**Verdict: reject this first visual candidate for final delivery.** The effect
is implemented in the intended region, and every inspected frame retains clear
title, subtitle, rarity, full name, status and buttons. The underlying live skin
remains visible, and the final settled images do not retain stray particles.
Those layout and cleanup qualities are accepted.

The requested beautiful flying-firework quality is not yet achieved. At peak,
the bright heads are very close to the model silhouette. Their short, dim,
gray-edged ribbons resemble pins attached to the rim more than detached comets.
The Common example is particularly subdued. The Prismatic effect is more
colorful, but the skin's existing large gems and arches overpower its thin
near-rim particles. During outward drift there is adequate separation, but
the sparks have already faded substantially. The relatively uniform radial
spacing reinforces the impression of a mechanical ring of spokes.

The requested revision is bounded: keep the existing 26–36 particles,
behind-model layering, preserved controls and approximately 1.6-second limit.
Move the bright expansion farther outward sooner. A useful design-space target
is peak heads approximately 175–205 units horizontally from `(270,400)` within
the early expansion, coasting toward 225–240 while keeping the vertical envelope
above the rarity label. Give peak trails approximately 30–50 units of visible
taper, a brighter pearl core around two pixels, and a soft low-opacity glow
around five to eight pixels. Hold the heads and colored middle of the tails
bright through the outward phase before fading. Increase angle and distance
variation enough to break the uniform spoke ring. These dimensions are art
targets to judge in the next pixels, not mandatory implementation constants.

No larger particle count, whole-panel brightness increase, additional 3D light
or viewport is requested. A revised actual render is required before approval.

## Second actual render: visual candidate accepted

Directly inspected all ten onset/peak/drift/tail/settled PNGs from
`artifacts/case-celebration-20261008/capture-02/`. Independently probed the
corresponding `build/case-celebration-20261008/capture-02.avi`: 540x960,
60 frames per second, 604 frames and 10.066667 seconds. Decoded and inspected
actual video frames at 5.20, 5.65, 8.50 and 9.05 seconds without audible playback
or creating another engine instance. These samples confirm the PNG progression
within the recorded natural Common opening and early-skipped Prismatic opening.
This is sampled-frame progression review, not full-speed subjective playback.

**Verdict: PASS for the revised visual candidate at 540x960.** The earlier
rejection remains recorded above. The longer luminous tails and brighter heads
now give the initial radial expansion enough energy to read as a reveal burst.
The later heads visibly separate from the silhouette and continue outward as
small comets and stars. Common receives a complete silver celebration, while
Prismatic's rainbow trails remain recognizable alongside the model's larger
stationary gems and animated arches. The revised effect is sufficiently distinct
from the rejected near-rim pin-like first pass.

The effect continues to frame the live skin. It does not cover its face, the
title/subtitle, rarity, full variant name, status or action buttons in any
inspected frame. No full-screen flash or broad opaque wash is present. The tail
fades smoothly across the inspected sequence, and both settled states return
to the clean original result layout. No further aesthetic revision is requested.

The current source confirms a single original canvas Control, bounded at 36
particles and 1.60 seconds, with no extra viewport, light, emitter node or texture.
It is inserted before the live result texture. Its natural/skip reveal entry
uses the committed receipt's rarity and presentation seed; restored entry clears
the effect. Source inspection supports the visual interpretation but does not
substitute for lifecycle tests or physical performance measurements.

Accepted evidence SHA-256:

| File | SHA-256 |
| --- | --- |
| `fidelity/case_celebration.gd` | `7ddbceeb91501866ae0f26e4b2218d6de2635961bc094cddd6d03d8f9386fcd2` |
| `fidelity/case_opening.gd` | `7b4b709bbc02cc82f86d2b9125a597138f6dda3220105e1666dcdf439c93e059` |
| `capture-02/capture.json` | `6c7da7c2a13d46ae0917c2979159f3c92175a6bee6d222a9880e6647bb584982` |
| `build/case-celebration-20261008/capture-02.avi` | `ea237fb3fff9a56fee9bf0f62b5484e2494edc9f5015d5d151491205b53576b6` |

The capture receipt reports unchanged awarded receipt/coins during the effect,
completed bursts and stopped effect processing for both examples. These are
root-produced controlled Mac integration receipts, not independently executed
tests by this reviewer. Responsive short/tall fixtures and functional and
exact-package verification remain pending final delivery closure. No subjective
audio listening, browser execution, physical-device performance, actual purchase
or organically obtained rare reward is claimed.

## Responsive and exact-package closure: final PASS

Directly viewed the following actual Mac GPU images from
`artifacts/case-celebration-20261008/ui-gpu-01/` and cross-checked their PNG
dimensions against the observation receipt:

| Image | Actual pixels | Effect age / particles |
| --- | --- | --- |
| `result-375.png` | 374x666 | 0.30 s / 26 |
| `result-440.png` | 440x956 | 0.30 s / 26 |
| `result-common-tall.png` | 540x1174 | 0.25 s / 26 |
| `result-prismatic-tall.png` | 540x1174 | 0.25 s / 36 |
| `result-safe-insets.png` | 440x956 | 0.30 s / 36 |

The `375` filename denotes the requested fixture width; the native viewport and
saved pixels are 374x666, as the receipt explicitly records. The inset example
uses the production safe-area transform with a labelled desktop fixture. None
of these images is a phone screenshot.

All five images retain a clear celebration around the skin and adequate space
between the sparks and the title/subtitle, rarity/name, status and action
buttons. The short image keeps the complete content and both actions visible.
The tall examples preserve the reward panel's hierarchy without excessive
particle spread. The inset example retains the full long Prismatic variant
name and both controls. Common silver remains legible against navy, while the
Prismatic rainbow complements its moving arches. These responsive images are
accepted without further art changes.

The root-produced real Mac GPU receipt reports 712 checks and zero failures.
Read the relevant added lifecycle checks: natural completion and SKIP start one
burst; repeated reveal/refresh and EQUIP do not replay it; focus, application
suspension and tree pause freeze it independently; failed transactions and
restored receipts do not celebrate; BACK, ODDS, CONTINUE and natural expiry
clear it. The fixture checks that decorative progression leaves ownership,
currency, transaction save count and the economy's global RNG unchanged. These
are receipt/source reviews, not independently rerun engine tests by this
reviewer.

The final focused export gate contains four suites—case UI, transaction, audio
and world music—with 1,123 checks and zero failures in each of source and
exact-package phases. This reviewer independently read all eight suite receipts,
recomputed every one of the 1,333 guarded input hashes and all 18 installed web
export hashes, and found no mismatch. The two production source hashes still
match the visually accepted second render above.

Compared with the previously accepted complete music gate, exactly three guarded
inputs changed: `fidelity/case_celebration.gd`, `fidelity/case_opening.gd` and
`tests/skin_case_ui_acceptance.gd`. No guarded input was removed. This is focused
regression acceptance of that bounded addition, **not a newly executed complete
97-suite gate**.

Final accepted release:

- Manifest: `artifacts/case-celebration-20261008/focused-gate-01/release.json`,
  SHA-256 `015b3f06d1c5056f16658db6aa74c032862aa8257069526b340e5e9bfa558761`.
- Installed package: `build/case-celebration-20261008/web/index.pck`,
  SHA-256 `06b0a372ffdda5c64578626b8eda907587d607317129ee693d28417ae26c30c9`.
- Prior complete baseline manifest: SHA-256
  `f632d1b896a8d0a3d9327967a14123538d9550a7c8f0456f4794d63015aabace`.

**Final art verdict: PASS for this exact local candidate and export.** The
requested reveal now has a visible outward celebration, retains the original
skin and UI hierarchy, settles cleanly and fits the inspected responsive
layouts. No art or exact-artifact blocker remains. The preserved first-pass
rejection explains the visual revision that was necessary.

Scope remains bounded to actual Mac frames, sampled muted video, source review,
root-executed test receipts and independently verified file hashes. No
full-speed human viewing, audible listening, browser execution, physical-phone
performance, native upload or actual purchase is certified by this reviewer.

## Late rendering failure and replacement capture 03

The independent runtime reviewer subsequently read the complete capture 02
engine log and found eight `Invalid polygon data, triangulation failed` errors
from the ribbon's five-vertex polygon. This reviewer independently confirmed
all eight messages in the preserved 37-line log. The earlier stills and focused
suite results did not expose this error. The previous exact-candidate approval
is therefore superseded; the positive art assessment alone does not qualify
that version for delivery.

Root replaced the ribbon polygon with three explicit gradient triangles. The
source retains the same trajectory, rarity colors, lifetime, particle count,
behind-model layering and glow/star design. The replacement effect source is
`fidelity/case_celebration.gd`, SHA-256
`574f88f7856fdff2c14a249e07673d4fc0cc349e7f773b1032d0d9f2b1753303`.
The case-opening integration hash remains
`7b4b709bbc02cc82f86d2b9125a597138f6dda3220105e1666dcdf439c93e059`.

Directly inspected all ten new Common/Prismatic onset, peak, drift, tail and
settled PNGs in `artifacts/case-celebration-20261008/capture-03/`. Independently
decoded its `celebration.mp4` at 5.20, 5.65, 8.50 and 9.05 seconds. The video is
again 540x960, 60 frames per second, 604 frames and 10.066667 seconds. It retains
the same explicitly isolated natural Common and skipped Prismatic scenarios.
The revised triangles preserve the accepted visible outward comet/star burst,
the unobscured model and UI, and the clean fade and settled states. No art
regression or additional aesthetic change is identified.

Read both complete replacement capture logs, rather than only the success JSON.
`capture-03.engine.log` has five lines and `capture-03.stdout.log` has twelve;
neither contains an error, warning, polygon failure or leak diagnostic. Root ran
the engine, while this reviewer independently inspected the output. These logs
and images establish this specific recording's result; they do not certify
physical-phone performance or every possible presentation seed.

| Replacement evidence | SHA-256 |
| --- | --- |
| `capture-03/celebration.mp4` | `a0697ce4f31c914b54430b7faa0b9f1888b9d6200b5dda159d1b4f8d0f9a4695` |
| `capture-03/capture.json` | `6c7da7c2a13d46ae0917c2979159f3c92175a6bee6d222a9880e6647bb584982` |
| `build/case-celebration-20261008/capture-03.engine.log` | `24499a1767b89fa94db5508dcdf3b8aefe56dfee8643bfd526db1467d407e6cf` |
| `build/case-celebration-20261008/capture-03.stdout.log` | `d07ad3246bcfa70604d4ca10b9f3acee885224cd354b003809f4b2ed79bff548` |

**Replacement capture 03 visual verdict: PASS.** Matching refreshed responsive
GPU evidence and focused exact-package verification remain pending. The old
capture 02 and its failure log are retained as diagnostic history.

## Replacement GPU 02 and focused gate 02: final closure

Directly inspected all five refreshed responsive result images in
`artifacts/case-celebration-20261008/ui-gpu-02/`: short `result-375.png` at
374x666, `result-440.png` at 440x956, Common and Prismatic tall examples at
540x1174, and the safe-inset Prismatic example at 440x956. The explicit-triangle
revision preserves the accepted effect and clear skin/text/control hierarchy
in each layout. No new visual clipping or overlap is apparent. The real Mac GPU
receipt reports 712 checks and zero failures.

Independently read the eight updated source/package suite receipts in
`focused-gate-02/`. Four suites total 1,123 checks with zero failures in each
phase. Recomputed all 1,333 current guarded input hashes and all 18 installed
web export hashes against the new release manifest: every hash matches. Only
the same three guarded inputs differ from the previous complete music gate,
with no removal. The effect source hash is the replacement triangle version
`574f88f7856fdff2c14a249e07673d4fc0cc349e7f773b1032d0d9f2b1753303`.

Also scanned the complete contents of all 20 refreshed GPU, source/package
suite and export log files for error, warning, script-error, polygon-failure
and leak diagnostics; there were no matches. This supplements the separately
inspected clean capture 03 logs and avoids relying solely on success receipts.
All engine execution was performed by root; this reviewer performed read-only
artifact and byte verification.

The final accepted release manifest is
`artifacts/case-celebration-20261008/focused-gate-02/release.json`, SHA-256
`f237a6a57afc0d949aa558a393a15f3df57802e2cabde5e911f7050fa497157e`.
Its installed package is `build/case-celebration-20261008/web/index.pck`,
SHA-256
`00020b5d5c139633bd83b9a912900caa5acdba88a135773d8326bfed2ea9535c`.
The accepted visual recording remains capture 03's MP4, SHA-256
`a0697ce4f31c914b54430b7faa0b9f1888b9d6200b5dda159d1b4f8d0f9a4695`.

**Final verdict: PASS for this repaired exact local candidate and export.**
The visual revision and rendering fix are both accepted. No art or verified
artifact blocker remains. This is a focused four-suite regression gate against
the prior complete 97-suite baseline, not a new complete gate. The preserved
capture 02 failure is historical and must not be presented as a clean capture.
Sampled video, muted host, isolated eligible pools and desktop safe-area
limitations remain unchanged; no subjective audio, physical-phone performance,
browser execution, native upload or real purchase is certified here.
