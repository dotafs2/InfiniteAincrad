# Rainfall skin — local Mac development candidate

## Latest palette and rarity update

Both weather skins now use highest Prismatic Tier6. See the
[shared reviewed handoff](../weather-prismatic-20261007/CONTINUE.md) for the latest
colors, exact current video and independent review. The implementation history
below remains evidence for the preceding structure and behavior changes.


## Current revision: one continuous water entry (2026-10-07)

The user correctly identifies a visual double fall in the preceding video.
Reviewing the encoded video frame by frame shows the original car disappearing,
then a complete second car appearing when collection is credited. That candidate
is rejected even though its scoring and timing tests passed. Its source, video
and decoded failure contact sheet remain recoverable.

The current implementation hands off rendering exactly once at first water
entry. Its initial mesh transforms, scale and original materials match the live
object; the original render is hidden in the same frame. A 0.42-second, downward
rocking entry then follows the moving hole. Collection only emits water feedback
and never creates another mesh. The water atlas is unchanged and the rejected
dither/afterimage shader is removed.

Real physics, admission, gravity, support release, ownership and scoring retain
the ordinary behavior. The original pre-buoyancy rim script differs only by one
cosmetic watch callback; see `physics-preservation.json`. Animation neither awards
points nor delays the real physical settlement. It finishes visually before some
objects finish their normal scoring fall; it does not promise earlier rewards.

Three fixed holders and six reusable mesh views bound the work, with at most six
surfaces, 48 scanned nodes and 12 pending admissions. No live entry is evicted.
Over-budget or unsupported geometry keeps its original physical fall rather than
a truncated copy. Fully submerged bodies cannot be brought back up. Originals
remain hidden until real settlement, and switching skins restores still-live
sources. The skin catalog preview is also safe when parented to a SubViewport.

Ten focused suites / 4,457 checks pass across the final affected-suite reruns and
unchanged successful physics/economy suites. Coverage includes exact handoff,
one rendered original/copy, monotonic descent, no post-score replay, fixed budgets,
complex fallback, pause, skin replacement and moving the hole eight units away.
Actual ordinary/Rainfall timing at 30/60/120 Hz is 23/22, 44/44 and 86/86 physics
ticks, within one tick. Initial duration-fixture and preview-parent type failures
are preserved, with successful affected-suite reruns. No full release gate was run.

Final deliverable: `artifacts/rainfall-single-entry-20261007/Rainfall-single-entry.mp4`
(19 seconds, muted 720x1080 H.264), SHA-256
`e8407cea804af123803dc7bb9330addec332c6c2da3e0b1b5fe94c0156f32c8b`.
The final encoded car, burger/donut and cone/bin sequences were decoded at 10 fps
and visually inspected through collection: each enters once, without resurrection.
Five staged props score once (60 to 74): four use the handoff and one correctly
keeps normal geometry fallback. The subsequent ten-second ordinary-play excerpt
comes from a fourteen-second capture with nine collections (30 to 41). The staged
capture uses scripted movement during entry, actual gravity and real rewards.
All owned capture/test helpers have exited. No new phone/web package was exported.

Evidence: `build/rainfall-single-entry-20261007/`. Final media and decoded-frame
verification are recorded in the completion receipt. GPU timer and phone FPS
remain unmeasured; prior afterimage render-cost measurements are historical and
must not be attributed to this implementation. This remains local Mac development.
User saves, accounts, previous videos and submitted build 34 are preserved.

## Rejected post-collection afterimage (2026-10-07; caused a second drop)

The user rejects the preceding buoyancy because it slows eating and can leave
objects behind when the hole moves. That implementation is withdrawn. The latest
candidate restores `fidelity/rim_body.gd` **byte-for-byte** to the saved pre-buoyancy
source, removes `fidelity/rainfall_float.gd`, and makes the effect presentation-only.

- Normal gravity, collision, size admission, support release, ownership and final
  reward timing run unchanged. `game.collect` awards first, then passes the consumed
  object to the existing skin feedback callback. Other skins ignore that argument.
- Rainfall borrows the collected object's existing mesh resources for a **0.42
  second** water-tinted rocking/sinking afterimage. The original object is already
  consumed and removed. The afterimage has no body, collider, score or collection
  callback, and stays parented to the moving hole. Completion cannot award again.
- The preallocated pool contains three holders and six mesh views/materials.
  Concurrent afterimages are limited to three and total mesh surfaces to six.
  Source traversal is capped at 48 nodes. Saturation replaces old echoes;
  unsupported/skinned/over-budget props keep water feedback without rendering
  an incomplete object. No vertices, textures or physics bodies are copied.
- The shallow-water atlas is unchanged. A single reused contact ripple marks the
  confirmed receipt. A depth-writing screen-door fade avoids the first render's
  transparent back-face/wheel bleed. That initial render is retained for evidence.
  Short afterimages are cosmetic and deliberately smaller than the original prop.

Ten focused suites / **4,412 checks** pass. The actual gravity timing comparison
at 30/60/120 Hz has ordinary/Rainfall counts of 23/22, 44/44 and 86/86 ticks,
respectively (within one physics tick; 0.717–0.767 seconds for this small fixture).
Assertions cover reward-before-animation, original-body removal, following a
moving hole, no colliders or synthetic rewards, pause, pool saturation, duplicate
source rejection, complex-model fallback, retirement and skin disposal. Existing
rim, building surfaces, Tempest, catalog, collection/save, skill and economy
checks pass. The earlier physics/buoyancy acceptance is archived as historical
source; the active test now enforces cosmetic timing parity.

Actual isolated M1 Pro rendering at 540x960: **3 idle draws**, up to **11 draws**
with all six afterimage surfaces and the rival splash active. CPU render submission
medians are 0.274 / 0.315 ms; these are not gameplay frame times. This has a small,
bounded additional render cost, not zero overhead. GPU timer queries are unavailable;
whole-map and phone FPS remain unmeasured. No claim of unchanged total rendering
cost should be copied from the older 3/5-draw physical-buoyancy revision.

Current deliverable:
`artifacts/rainfall-cosmetic-20261007/Rainfall-quick-intake.mp4` — 19 seconds,
muted 720x1080 H.264. Nine seconds of staged existing props demonstrate ordinary
physical collection and immediate movement with the already-confirmed echo;
all five score once (60 to 74), with zero skipped echoes. Ten seconds of ordinary
Sunny City scripted movement follow. Its complete 14-second source capture
records nine confirmed objects, versus the slower preceding candidate's six.
The excerpts are real Mac GPU frames; there are no synthetic reward calls.
The video decodes cleanly. Exact SHA-256:
`8dd2ccac4a4ad2a7227f965df2a08f0e43cc10f171a57608cc3fb68733bf351c`.
Poster and media receipt are saved alongside it.

Evidence: `build/rainfall-cosmetic-20261007/`, including restored-physics proof,
per-suite reports, timing samples, transparent first frames, bounded renderer
measurement, capture receipts, exact source hashes and completion. Source hashes
remain identical throughout final capture. All owned helpers have exited.
Prior media and rejected behavior remain recoverable below. Submitted build34,
user saves and accounts are unchanged. Local Mac source/media only; no phone,
release package, upload, review submission or Git publication.

## Superseded physical rocking intake (2026-10-07; rejected by user)

The user subsequently requests visible left/right floating before slow sinking,
with rendering cost kept low. This supersedes the original immediate-gravity
settlement for **Rainfall only** and the earlier subtle-bob intermediate version.

- `fidelity/rainfall_float.gd` adds one bounded controller per admitted Rainfall
  object, including food and whole buildings. Contact begins only when the body
  reaches the water and its footprint is fully inside the physical opening.
- The existing rigid body rocks left/right around its contact orientation for
  1.05 seconds. A damped angular target produces measured approximately -9.4 to
  +9.2 degree lean on the small-box fixture. It fades during descent.
- The whole visible body then sinks over a size-scaled 1.7–3.0 second phase.
  Its target speed grows smoothly; gravity completes the hidden final fall.
  No transforms are teleported, and no horizontal towing, new colliders,
  geometry fragments or early rewards are introduced. Existing admission,
  roof support release, building meshes and final scoring planes remain active.
- A single reused shader ripple marks actual water contact. Ambient water still
  uses the same offline atlas; there is no runtime fluid grid, mesh deformation,
  extra rain batch or extra contact particle system. One bounded active
  controller is the added CPU work per admitted body.
- Leaving the opening, losing/changing the owner or switching skin cancels
  buoyancy. Re-entering cannot restart it indefinitely. Pause freezes the
  physical motion and timers. The catalog now describes the timing difference
  instead of promising unchanged swallowing. Other skins keep ordinary gravity.

Latest focused physics acceptance passes **423 checks** with actual 30/60/120 Hz
simulation. Small objects settle exactly once in about 3.48–3.50 seconds from
release; the building plus separately falling roof cargo settle in 6.28 seconds,
with the original 48+2 points. The Rainfall GPU/actual-collection suite passes
**117 checks**, including the three objects and real rival callback. Its bounded
wait is now five seconds to allow the deliberately slower motion. Existing
non-Rainfall rim, building-surface, food collision/impact/continuity, Tempest,
catalog, skill and economy receipts are retained from the immediately preceding
revision because their implementations and active paths did not change.

Actual isolated M1 Pro GL Compatibility counters remain **3 idle / 5 peak burst
draws**, including frequent contact ripple updates. CPU render submission medians
are 0.276 / 0.286 ms for this isolated scene; they are not whole-game frame times.
GPU timer queries remain unavailable. Mobile FPS and a whole-map CPU budget have
not been measured; do not claim that extra buoyancy has zero cost.

Latest deliverable: `artifacts/rainfall-rock-20261007/Rainfall-rock-and-sink.mp4`,
29 seconds, muted 720x1080 H.264. The first 15 seconds use staged existing props
and real physics; all five enter water and fully settle. The following 14 seconds
show ordinary Sunny City with scripted movement: nine contacts and six confirmed
collections before capture ends. No synthetic score/effect calls are used.
Three actual frames were inspected for opposite lean directions and partial
submersion. The video decodes cleanly and every captured game input hash remains
unchanged. SHA-256: `d6970ca31385f246be49e467bd0b74c553075d635c662ca2773cd239ce060e61`.
The poster and exact media receipt are saved alongside the video. All owned
check, render, capture and encoding helpers have exited.

Current evidence: `build/rainfall-rock-20261007/`. Earlier subtle-float evidence,
media and source snapshots remain in `build/rainfall-float-20261007/` and its
matching artifact directory. The original Rainfall video/loop below is also
preserved. The first building test allowed only six seconds and failed because
the released roof item had its own new float/sink sequence; the measured 6.28
seconds now passes a bounded ten-second two-body fixture, with single props still
required to finish within five seconds. Prior fixture-contract errors (`city`
and the isolated impact queue) and the incorrectly timed rain-continuity runner
are preserved; corrections have clean passing receipts. The continuity test
passes all 38 checks over 360 simulated seconds using fixed-fps execution.

Local Mac development only. Submitted build34, native packages, user saves,
accounts and previous skins are preserved. No phone install, release gate,
upload, review submission or Git publication occurs.

## Request and scope

The user requested another rain-themed skin: falling raindrops over a shallow-water
surface in the opening, with the animation baked ahead of time if useful. The
active scope stays local to the Mac. No phone, accounts, upload, App Review or Git
publication is needed or performed. Submitted 0.13.0/build34 is preserved.

## Implemented

- Appended `rainfall` / **Rainfall**, Legendary, as the 46th real skin. The previous
  45 definitions are byte-equivalent at the parsed record level; all existing
  Tempest assembly/shader files retain their recorded hashes. Existing scores,
  ownership, draw prices and gameplay reach are unchanged.
- Seven soft cloud lobes share one MultiMesh. Forty-eight scheduled drops use a
  second MultiMesh and GPU flight animation. Drop coordinates and timing come
  from the same generated data as the water impulses. Cloud drift also loops.
- The physical opening is dressed with a translucent blue shallow-water surface,
  reflected sky bands and ripple normals. No collision body is added. Collection
  feedback strengthens the water response; actual rival containment creates a
  temporary expanding ripple and a fixed 24-slot splash batch. Effects retire.
- Collection framing and player labels accommodate the higher rain canopy. The
  original black collection-preview disk is hidden for this form.

## Real offline shallow-water bake

`tools/bake_rainfall_water.py` implements damped linear shallow-water equations
on a staggered C-grid: `eta_t = -H div(v) + rain`,
`v_t = -g grad(eta) - drag*v`. It uses small zero-mean localized impacts, a
symplectic step, reflecting box boundaries and an absorbing outer sponge beyond
the visible pool. The [Cornell numerical-method reference](https://www.cs.cornell.edu/courses/cs5220/2024fa/hw/proj3.html)
provides the linear equations/grid context; code and all visual assets are original.
This is a linear small-amplitude model, not nonlinear CFD. Runtime reflection and
normal strength are deliberately amplified for readability.

The reproducible bake uses a 128x128 grid, 0.00625-second time steps and 48 frames
at 16 fps over three seconds. The 2-D Courant value is 0.2155. After eight warmup
cycles, same-phase height residual is 1.76e-14. Encoded RG stores slope, B height,
and A crest information. A lossless 1584x528 atlas includes two-pixel gutters and
has no mipmaps, alpha-border modification or lossy normal-map compression.
The PNG is 997,566 bytes; base uncompressed RGBA texture storage is 3,345,408 bytes.
Runtime interpolates adjacent frames and does not run a fluid solver. Swallowing
adds bounded analytic transients rather than recomputing the baked PDE.

Generated assets/data:
- `assets/skins/rainfall/shallow_water_atlas.png` and its explicit import settings.
- `assets/skins/rainfall/bake-manifest.json` with solver parameters, residuals,
  forcing schedule and exact atlas hash.
- `fidelity/rainfall_bake.gd` with matching runtime drop positions/phases.

## Acceptance and exact artifacts

Eleven focused suites pass **5,877 checks**. This includes real falling-body and
rival-contact receipts, fixed allocation after 1,000 effect triggers, exact
lossless texture import, all 48 GPU drop positions/phases, collection purchases,
cold-save restore, legacy skin identities/geometry, rarity, skills, collection UI,
future economy planning and Tempest regression. GPU instance data is quantized
by Compatibility rendering; phase alignment is required within 2 ms, below one
simulation substep and much less than a baked frame. The rendering-dependent
Rainfall suite runs on the actual Mac GPU, not the dummy headless backend.

Actual fixed-camera Mac images at 0 and 3 seconds are **pixel-identical**, including
rain, cloud drift and water. The standalone 3-second loop encodes 90 frames at
30 fps. Actual scripted gameplay records nine collected objects in the object
segment and one swallowed rival plus one additional object in the rival segment.
Controller inputs and rival starts are staged; scoring, gravity and callbacks
are real. Full-source hashes stay unchanged throughout capture and verification.

Measured isolated Mac M1 Pro GL Compatibility counters: **3 idle draws / 5 peak
burst draws**. Static MeshInstance3D metrics are 3 nodes / 2,112 triangles, plus
three fixed MultiMeshes. These counters are not a whole-map or phone FPS claim.
GPU timer queries are unavailable on this backend. No mobile benchmark is claimed.

Evidence root: `build/rainfall-skin-20261007/` (ignored), including first failures,
checks, render-counter receipts, loop comparison, source manifest and completion.
The first water render was too flat and its image is preserved. Initial headless
MultiMesh readback returned dummy values; actual GPU readback exposed normal
reduced-precision instance data. Tests now use the real GPU and a documented
substep tolerance. Old catalog-count failures were corrected for the one appended
skin while retaining immutable historical hashes.

Current artifacts:
- `artifacts/rainfall-skin-20261007/Rainfall-preview.mp4`: 26.833 seconds, muted,
  720x1080 H.264, actual Mac capture with a labelled half-speed rival replay.
- `artifacts/rainfall-skin-20261007/Rainfall-loop.mp4`: 3 seconds, muted, fixed camera.
- `Rainfall-poster.png`, `video-receipt.json`, `loop-receipt.json` in that directory.

Preview SHA-256: `7d298c98f7210582b752a208f73c403306ac02ad64bcbfceba4fe11a1c35ef7e`.

Loop SHA-256: `0d3844bdcb1ee7c28f77016d9e585fc6a000ff7d038fb8803aa2039d242eccbb`.

Both videos decode without errors. All owned bake/check/render/encoding processes
have completed. No full all-map release export, native package, phone install,
account operation, purchase or publication is claimed. Review these local media
before any separately requested deployment.
