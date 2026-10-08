# Selective building reveal: source comparison

Date: 2026-09-28. Read-only investigator: city agent. This report records the behavior before the selective-reveal correction; runtime implementation belongs to root.

## What the local original source actually contains

The available upstream is the MIT **mbMayer/Godot-Hole.io template**, pinned to `cf75504a150c3cf179bb8e80b93309fb62a7a729`. All nine archived files match the SHA-256 values in `third_party/mbmayer/provenance.json`; exact results are in `upstream-verification.json` beside this report. This is a small public template, not Voodoo's proprietary Hole.io source.

- `third_party/mbmayer/Scripts/player.gd:15–46` implements directional movement, hole position synchronization, a size tween, downward rigid-body impulse and collection/deletion. It has no building category, camera obstruction query or building fade.
- `third_party/mbmayer/Scenes/hole.tscn:3–7` is a subtractive CSG cylinder (`operation=2`, radius 1, height 5).
- `third_party/mbmayer/Scenes/player.tscn:40–41` attaches a camera to the player. Lines 51–59 assign the UV-warp shader to the hole torus and a black unshaded material to its interior.
- `third_party/mbmayer/Shaders/holeshader.gdshader:7–25` warps UVs and outputs sampled color/alpha. It does not fade surrounding objects.
- `THIRD_PARTY.md:10–28` records the reused CSG/controller foundation and states that the archival warp shader is not used by our running scene.

The prior observation ledger, `fidelity/REFERENCE.md:21`, records a nearby **building** fading while the hole passes through its footprint. Lines 27–30 explicitly distinguish the observation from extracted commercial code. The ledger is historical visual evidence, not a fresh replay or knowledge of Hole.io's internal implementation.

## Our old behavior and the v0.8.1 regression

The retained early implementation in `fidelity/art.gd:102–110` adds only city houses to its `fading` list. `art.gd:294–299` checks `abs(player.x-building.x)<half_width+2` and the analogous Z condition, then sets the whole facade's alpha to 0.3, otherwise 1. It uses footprint proximity rather than actual camera occlusion.

The pre-v0.8.1 catalog implementation similarly iterated only `building_visuals`, used half-footprint + 2 metres, and set alpha to 0.22 for nearby unclaimed buildings. Collapsing/claimed buildings stayed opaque. Its source checkpoint is recorded in `docs/visual-quality-20260928/runtime-audit.md:38`; it is no longer the active catalog loop. This was narrow in category but inaccurate in deciding whether a building actually blocked the hole.

V0.8.1 improved the fragment geometry test but widened eligibility too far. `fidelity/hole_reveal.gd:60–66` binds every edible body plus every direct MultiMesh. The shared include tests camera-ray projection into the expanded aperture, without a building category. `fidelity/food_glaze.gdshader:26–27` invokes that discard unconditionally. As a result, ordinary snacks, people, cars and street props can lose most pixels merely because they overlap the reveal aperture. Passing the former broad-coverage tests demonstrated the implemented rule; it did not establish that this was the desired visual rule.

Changing only `bind_city` is insufficient for food. `fidelity/food_city.gd:405–408` gives **all** food the same included glaze material, and static/settled-rain batches reuse it at lines 425 and 456. Eligibility must survive the real shared-material, batching and release paths.

## Recommended correction

1. Opt in large structural geometry only. City buildings already have `category=="building"` and `building_visuals`. Food structures have `food_building`, `tower_id` and group envelopes (`food_city.gd:236–246,280–282`). Group size is meaningful for a stack of thin large floors; a generic individual height threshold is not. Keep small toppers, loose snacks/rain, vehicles, people and street furniture opaque. Released pieces should not inherit permanent building eligibility just because of their former owner.
2. Activate reveal only when an eligible structure actually overlaps camera-to-hole visibility. Use a conservative projected-bound broad phase plus a core-hole occlusion test covering multiple points or an equivalent volume/geometry test. One center ray or center-distance check misses wide/tall blockers. A large object near the expanded shoulder alone must not activate. Once genuine core occlusion exists, retain a bounded feathered shoulder to preserve readable space around the hole.
3. Preserve per-fragment cutting within the eligible object so its remainder stays legible. Keep the shadow-pass and gameplay-camera guards, full physical collision, and floor exclusion.
4. Encode eligibility per actual shader material/instance. Split food batch groups by eligibility when using material variants; never toggle the shared food material globally. Test spawn, batching, release and collapse transitions explicitly.

Acceptance should pair a small prop and large wall at the same blocking position: only the large structure reveals. Include a nearby nonblocking large building, a wide edge blocker with distant center, moving away from camera, an intact large food stack beside identical loose food, new rain, released debris and map restart. Geometry tests must assert both positive and negative cases. Final perceptual approval still requires genuine gameplay viewing; this read-only report supplies no new rendered scene or mobile FPS evidence.
