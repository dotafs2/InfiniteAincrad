# Independent player shadow review

Date: 2026-10-08. Scope: the player's visible grounding in Low/Battery quality, all three hero models, and the recruitment handoff. The reviewer does not edit production gameplay code or author the replacement shadow assets. GPU captures are supplied by the implementation owner to keep profiling runs isolated.

## Baseline finding

The user's objection is supported by the current evidence. In [normalized Low](../artifacts/mobile-brightness/low-normalized.png), the infantry has only a small, faint round patch at its boots. In the earlier [Low minigunner gameplay capture](../artifacts/mobile-visual/low-16-0.png), the wider body and weapon have no directional ground silhouette. The second image predates lighting normalization, but it uses the same contact-only shadow mechanism. The [High reference](../artifacts/mobile-brightness/high-reference.png) has a clearly visible body shadow extending toward the screen's upper-right and connecting to the feet.

The source inspected before the proposed repair explains the difference:

- Low/Battery disables the directional shadow map.
- `_add_blob` supplies one radial plane whose shader peaks at 0.24 alpha. It has no head, body or weapon silhouette.
- The plane is a child of `player_model`, which receives lean and firing rotations, and its parent player bobs vertically. The shadow therefore inherits transformations that should not tilt or lift a floor receiver.
- Infantry and gunner share the same pre-scale contact dimensions despite their different body and weapon widths. The mech receives a different ellipse, but still no directional silhouette.
- The airborne recruitment model has no corresponding projected ground shadow in the inspected baseline. The replacement player model, and its contact patch, only appear at landing.

This is a visible presentation defect. A faint ellipse alone is insufficient for the player's intended grounded appearance at the game's portrait size.

## Acceptance criteria for the repair

| Area | Required visible behavior |
| --- | --- |
| Direction and shape | A readable body/weapon silhouette extends from the feet toward the screen's upper-right, consistent with the existing sun and High reference. A darker compact contact patch anchors the boots. The result must read as a shadow rather than a large circular glow or rectangular image. |
| Three hero models | Infantry, gunner and mech receive distinct silhouettes and sensible footprints at their actual player scales: 1.65, 1.65 and 0.90 respectively. Wider gunner/mech geometry must not be reduced to the infantry's small spot. |
| Ground placement | The shadow stays horizontal at the floor while the player leans, fires, bobs and moves laterally. Feet remain connected to the contact region; no hovering gap, depth flicker, texture rectangle or detached moving patch is acceptable. |
| Recruitment | The projected footprint follows the airborne model's horizontal world position. Its separation, size, softness or opacity conveys height without becoming an opaque giant stain. It returns continuously to the correct upgraded player footprint at landing, with no disappearing frame or double-strength overlap. |
| Stage bounds | The floor shadow does not paint the black void outside the platform or appear on top of a rail merely because its texture plane extends past the playable surface. The elevated recruitment pedestal must not reveal an obviously floating floor plane. |
| Quality switching | Low and Battery retain the grounding cue. High must not accumulate an equally strong baked silhouette on top of its existing dynamic body shadow. Pause/resume and quality changes must not leave a stale shadow or a shadow from the previous hero. |
| Rendering cost | The repair should preserve the mobile profile's absence of a full scene shadow map. Geometry/material/texture costs should be reported by the runtime reviewer; an image alone cannot establish phone performance. |

Useful final evidence is one ordinary portrait capture per hero in Low, lateral movement near both rails, and recruitment frames spanning takeoff, peak height and landing. A High comparison and a Battery capture establish the quality-switch behavior. Staged pose or tier captures must be labeled as staged rather than ordinary gameplay.

## Exported-package visual review

The reviewer independently viewed all ten supplied images under `artifacts/player-shadow/accepted/` and checked their SHA-256 values against [delivery-manifest.json](../artifacts/player-shadow/delivery-manifest.json). Every inspected image matches the manifest for PCK `684b08d7ccecc2ceee5627993f168b26f4e7a93a458677e52e1470e15fc8c033`. These are staged role and recruitment views from the exported package, not human play or phone performance evidence.

| Evidence | Independent visual finding |
| --- | --- |
| [Low infantry](../artifacts/player-shadow/accepted/low-tier-0.png) | Clear head/body silhouette toward the upper-right, connected to the boots by a compact darker contact region. The previous barely visible patch has been corrected. |
| [Low gunner](../artifacts/player-shadow/accepted/low-tier-1.png) | Wider upper-body/weapon outline fits the larger actor, with visible floor anchoring and no rectangular texture edge. Its strength is sufficient at portrait viewing size. |
| [Low mech](../artifacts/player-shadow/accepted/low-tier-2.png) | Broad mechanical silhouette and compact foot contact fit the hero. The outline is distinct from infantry and gunner. |
| [Battery mech](../artifacts/player-shadow/accepted/battery-mech.png) | Grounding survives the coarser rendering. The image is more aliased, but the shadow remains clear. |
| [High mech](../artifacts/player-shadow/accepted/high-mech.png) | Dynamic shadow agrees with the Low projection direction and extent. No doubled body-shadow outline is visible. Source inspection confirms the baked directional plane is hidden in High. |
| [Right rail](../artifacts/player-shadow/accepted/low-right-rail.png) | Directional shadow clips at the receiving road boundary instead of painting the black void. The remaining foot contact still grounds the actor. No texture rectangle or detached dark patch is visible. |
| [Recruit takeoff](../artifacts/player-shadow/accepted/flight-takeoff.png) | The existing infantry remains grounded. The recruit's floor-plane shadow is not visible on top of the raised pedestal; it lies below that receiver. This is a remaining limitation of the simplified receiver scheme. |
| [Recruit peak](../artifacts/player-shadow/accepted/flight-peak.png) and [approach](../artifacts/player-shadow/accepted/flight-approach.png) | The separated, softer floor footprint follows the airborne recruit and conveys height. It stays on the runway without a hard rectangular border. This flight footprint is deliberately an ellipse, not the full model silhouette used after landing. |
| [Completed landing](../artifacts/player-shadow/accepted/flight-landed.png) | The replacement gunner now has its full wider body silhouette, connected to its boots and matching the standalone gunner view. The former infantry patch and airborne ellipse do not remain as visible duplicate shadows. [Capture state](../artifacts/player-shadow/accepted/capture-state.json) records `flight_finished: true`, tier 1 and the actual `gunner.png` shadow texture. |

The independent review caught a boundary error in the first landing capture: the driver's `0.425 + 0.35 + 0.075` can sum to `0.8499999999999999`, just below the 0.85-second completion threshold. The owner corrected only the capture driver by advancing an additional 1/60 second and asserting completion plus the selected texture. The reviewer inspected the refreshed landed image and state JSON, and verified the new image SHA-256 `28f73b2bf9cff26f5780059bda7d46358adc584a9372cb3b5be4ad298b6881bc` against the refreshed manifest. The production PCK hash is unchanged. This closes the landing evidence concern; it was not a production gameplay defect.

The production source now parents the player shadow separately from the bobbing, leaning model, updates only its ground position and selects the proper role texture/scale. The shader clips the quad to the runway. These changes address the identified structural causes without introducing a scene shadow map in Low/Battery. Static images cannot prove absence of flicker throughout continuous movement; the right-side image is the only final boundary view supplied, and the left boundary and mech recruitment were not independently captured in this review.

The implementation owner's manifest reports 209 regression assertions and a default Low cost increase of one draw call and two triangles. Those are attributed implementation/runtime results, not benchmarks rerun by this visual reviewer. No phone FPS claim is made.

## Status

Accepted for the tested three-role grounding, projection direction, Low/Battery readability, High shadow separation, supplied right-boundary view and completed gunner landing handoff. The airborne footprint is visibly useful, with the elevated pedestal limitation stated above. This acceptance is based on staged exported-package views and read-only source review, with the uncaptured cases explicitly bounded above. No GPU job was started by this reviewer.
