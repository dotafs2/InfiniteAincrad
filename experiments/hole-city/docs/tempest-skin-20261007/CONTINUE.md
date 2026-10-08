# Tempest tornado skin — desktop development candidate

## Latest palette and rarity update

Both weather skins now use highest Prismatic Tier6. See the
[shared reviewed handoff](../weather-prismatic-20261007/CONTINUE.md) for the latest
colors, exact current video and independent review. The implementation history
below remains evidence for the preceding structure and behavior changes.


The user requested an original tornado skin with a visible, non-black swirling
center, different object/rival absorption effects, and an actual gameplay video.
The user then explicitly clarified that development should remain on the Mac;
do not connect to or control their phone for this task.

## Current revision: restored detail and increased translucency

The user finds the simplified storm too sparse and asks to recover the earlier
cloud detail while making the effects more transparent to reveal swallowed props.
The current candidate restores nine varied, vertically staggered cloud billboards
in the existing single MultiMesh. Shared three-scale warped noise, stronger
internal density variation and soft irregular edges restore rolling cloud detail.
The funnel uses broken translucent spiral bands and finer secondary wisps in the
same grey-blue palette. Small vertex motion softens its silhouette. No separate
halo/ribbon meshes or extra lightning branches are added.

Cloud peak opacity is now density-dependent (0.26–0.65 before edge falloff), versus
0.95 previously. The ground cloud centre is 0.20–0.40; a denser feathered shoulder blends the
actual dark ground-cut perimeter into the surrounding clouds. The funnel has a
much lighter 0.08 base plus bounded density/strand terms, versus the previous
0.58 base.
These are per-surface alpha values, not a claim about composite pixel opacity.
The physical hole, collection/combat hooks, reward rules and saves are unchanged.

Five focused suites pass **3,822 checks**. Static geometry is 5 mesh nodes / 1,968
triangles, plus cloud/debris MultiMeshes. The 32-slot particle pool, four-fragment
object burst and twelve-fragment/two-branch rival burst remain bounded. Actual
isolated Mac A/B counters remain 3 idle draws / 6 peak burst draws. Visible idle
primitives increase from 650 to 914 with the additional funnel rows and billboards;
noise work also increases. This deliberately restores detail without restoring
the earlier separate draw calls. GPU timing is unavailable on this backend;
no unchanged GPU cost or phone FPS claim is made.

Current evidence is `build/tempest-detail-20261007/`, including exact before
sources, render counters, focused checks and actual gameplay frames. Current
video: `artifacts/tempest-detail-20261007/Tempest-detail-preview.mp4`. All earlier
revision videos remain available. An initial gameplay capture exposed the dark
ground cut after reducing cloud opacity. Its footage is retained under
`before-rim-blend/`; a denser cloud shoulder now covers the hard edge while the
centre/funnel remain translucent. Ground geometry and physics are unchanged.
No phone, account or publication work occurs.

## Previous revision: unified, simplified thunderstorm

The latest user correction asks for the funnel and clouds to read as one storm,
with fewer lightning details and lower rendering cost. Both shaders now share
one grey-blue palette and two-octave density function. Broad rotating cloud bands
replace the white filaments; upper ribbons and the halo are removed. The cloud
bank uses five seeded billboards in one MultiMesh/material rather than nine
separate materials/draws. Funnel geometry drops from 48x10 to 32x8. Object bursts
use four fragments, rival bursts twelve, with two short lightning branches; the
fixed pool shrinks from 72 to 32. Lightning remains event-driven, not continuous.

Five focused suites pass **3,822 checks**, including actual physics callbacks,
constant allocation under 1,000 triggers, retirement, catalog, shader animation,
rarity and collection UI. Static MeshInstance3D geometry is **5 nodes / 1,712
triangles**, plus the cloud and debris MultiMeshes. These structural counts are
not equivalent to active GPU draws or full-game frame rate.

An actual M1 Pro GL Compatibility A/B render-counter benchmark uses the previous
cloud source and this candidate in the same isolated 540x960 viewport, with 120
warmup and 240 measured frames per phase. Idle draws fall **13 to 3**; busy peak
draws fall **16 to 6**. Idle visible primitives fall 1,874 to 650. GPU timer
queries return zero on this backend, so GPU timing is **unavailable**, not zero
cost. CPU render submission timings are recorded but are not a phone or full-map
FPS claim. No mobile performance measurement is claimed.

Evidence: `build/tempest-storm-20261007/`, including preserved prior source,
`render-benchmark.json`, `performance-summary.json`, focused checks and actual
Mac GPU video frames. Current delivery is
`artifacts/tempest-storm-20261007/Tempest-storm-preview.mp4`; source hashes are
checked unchanged through capture. The first video exposed straight cloud cuts from the opaque collection-preview
mouth disk. A diagnostic capture with that disk hidden isolated the cause; Tempest
now hides it in previews, with a focused regression check. Billboard alpha is
also forced to zero within its quad boundary. Rejected captures and source remain
in `before-edge-fix/` and `before-preview-depth-fix/`. No phone, release or account
operations occur.

## Previous revision: rolling storm-cloud base

The user rejected the regular disk and requested dark cloud shapes with layered
noise. That local revision replaces the luminous radial bands with a
three-scale, domain-warped cloud field, a feathered edge, and nine overlapping
density lobes. The lobes use camera-facing, softly shaded quads and stable seeded
noise, so they have neither faceted stone silhouettes nor texture swimming when
the player moves. Slow collective rotation and local density drift provide motion.
The small central eye stays blue. Collection and rival callbacks are unchanged.

That assembly has **16 mesh nodes / 3,254 triangles**, plus the unchanged
72-slot debris pool, within the existing 18-node / 4,500-triangle budget. Five
focused suites pass **3,843 checks** after the cloud changes, including real object
settlement/rival callbacks, catalog bounds, shader clocks, rarity, and collection
UI. The original 12-suite result below belongs to the earlier tornado revision.

Earlier evidence is in `build/tempest-cloud-20261007/`; prior source and rejected
flat/solid-lobe render iterations are retained. Its video is
`artifacts/tempest-cloud-20261007/Tempest-cloud-preview.mp4`. Actual muted Mac GPU
capture and encoding use the same controlled gameplay fixture as the original.
No phone or publishing operation occurs.

## Implemented

- Appended `tempest` / **Tempest**, the 45th real skin, in Legendary. Existing
  44 definitions are unchanged. Collection, purchase/save restore and rarity
  ordering include the new definition. The default and all economic values stay.
- Original polar-flow shader and curved funnel mesh with broad storm bands,
  a unified grey-blue cloud bank and a softly visible center.
  The original ground aperture and size gates still own physics.
- Successful admission briefly intensifies the wind. Confirmed physical object
  collection sends four short-lived fragments spiraling inward. Rival containment
  sends twelve larger fragments outward, expands the funnel/ring and flashes two
  pale-blue lightning branches. Other skins retain their existing rival bursts.
- One fixed 32-instance debris pool; no per-collection emitter/node creation.
  Effects retire and clear on skin changes. Existing haptics/audio remain.
- Tempest-specific collection framing and raised player labels accommodate its
  height. Existing skins retain their original framing and label positions.

## Original tornado revision evidence

Evidence root: `build/tempest-skin-20261007/` (ignored, local).

- Final focused gate: **12 suites / 7,271 checks**, all pass. See
  `checks/summary.json`. Covers catalog, shader clocks, mesh budget, legacy identity,
  rarity odds, collection purchases/cold saves, UI, skills, original polish,
  synthetic future economy, combat, and the new physical-event fixture.
- `tempest_skin_acceptance.gd` settles three real falling bodies and one actual
  rival-containment event; checks no premature/double reward, no false larger-rival
  swallowing, 1,000 cosmetic triggers with constant node/pool counts, retirement,
  and rebuilding. It uses test mode without the real save or network commerce.
- Actual Mac M1 Pro / Godot GL Compatibility GPU captures: object segment records
  nine collections; rival segment records one moving rival swallowed and one
  object. Input is scripted and the rival start is staged; scoring, gravity and
  contact callbacks are real. The clip is development evidence, not phone footage
  or an ordinary player performance claim. Beauty footage uses the same skin.
- `source-manifest.json` records exact runtime hashes and verifies original 44
  catalog definitions plus the frozen build34 catalog remain unchanged.
- Failures are retained: initial GDScript type inference, a shader `TAU` built-in
  redefinition, clipped thumbnail framing, old 44-skin expectation failures, and
  insufficient lightning contrast. Corrected code passes the final gate and GPU
  captures. Initial logs/frames and `checks-first/` remain available.

## Delivery and limits

`artifacts/tempest-detail-20261007/Tempest-detail-preview.mp4` is the current muted
portrait review video, with a labeled half-speed replay from the same actual
combat footage. Its `video-receipt.json` records codec, duration and SHA-256.
Previous tornado and cloud-base videos remain in their own artifact directories.

This uses original Godot shader/procedural mesh work; Blender MCP was not available
or used. No external visual assets were copied. No full all-map export gate, Web
package, native build, phone installation, mobile performance measurement, account
changes or Git publication is claimed. The frozen submitted 0.13.0/build34 remains
in its prior release state. This candidate is for a subsequent update after review.

No phone, mirror, signing, account or remote-device steps are needed to review
this video. Continue locally unless the user explicitly requests deployment.

## Previous simplified-storm delivery receipt

- Current video: 720x1080 H.264, 25.833 seconds, no audio stream.
- SHA-256: `3f95c1c5c755d46aacb18bb14bb92914ec7e64f27688334ea07bd7f86891ee27`.
- Final source hashes remained unchanged throughout capture and final verification.
- Actual scripted gameplay records nine object collections in the object segment;
  the rival segment records one swallowed rival and one additional object.
- Video decoding completes without errors; all owned capture/check helpers exit.

## Current detailed-cloud delivery receipt

- Video: 720x1080 H.264, 25.833 seconds, no audio stream.
- SHA-256: `60f7e85e1c6939f7af162d2625d37aea803625b7b0dd57283cad90a80a31a934`.
- Final source hashes are unchanged through actual GPU capture and verification.
- Nine collected objects in the object clip; one swallowed rival and one additional
  object in the rival clip. Controller input and rival placement are staged;
  collection/combat callbacks and scoring are real.
- Final video decodes without errors. Five suites / 3,822 checks pass.
- All owned capture/check/benchmark processes exit; no phone or release operation.
