# Independent mobile rendering and animation review

Date: 2026-10-08. Reviewer: the reference/mobile-asset worker, independently reviewing the integrated gameplay/HUD and the other worker's articulated boss animation. The production gameplay and HUD files were read but not edited by this reviewer.

## Actual gameplay and GUI evidence

`tools/mobile_visual_review.gd` instantiates the production scene and runs its ordinary physics, automatic fire, damage, enemy movement and upgrades. A declared deterministic steering driver controls lateral aim. It does not override health, waves, hero tier or boss poses. This is actual gameplay simulation with automated steering, not a pose contact sheet or a claim of manual human play.

The run captured low and high quality at approximately 0.3, 5.2, 8.2, 10.8 and 16 seconds. These ordinary gameplay images were recorded **before the lighting normalization** described below; they establish gameplay, LOD and GUI behavior, not the final Low exposure. The run also injected real mouse events through the viewport into the ready and paused menus. A separate `_unhandled_input` observer verified that the quality button consumed those events. All **21 GUI checks pass**, with no engine/script errors or warnings in the final capture log.

- [Low, full crowd](../artifacts/mobile-visual/low-0-3.png) and [High, full crowd](../artifacts/mobile-visual/high-0-3.png).
- [Low, minigunner/boss defeat](../artifacts/mobile-visual/low-10-8.png) and [High, minigunner/boss defeat](../artifacts/mobile-visual/high-10-8.png).
- [320 × 568 ready screen](../artifacts/mobile-visual/ui-ready-320-low.png) and [paused quality control](../artifacts/mobile-visual/ui-paused-after-low.png).
- [Structured checks and frame snapshots](../artifacts/mobile-visual/review.json).

The quality label and button fit at both tested sizes. Ready-screen clicks changed Auto → Low → High. Paused quality clicks kept the game paused, preserved simulation time and aim, and did not start dragging. Battery mode is intentionally an internal automatic fallback rather than an additional button choice.

These two runs are visual comparisons, not deterministic equivalence tests: the first starts through the real Deploy button and the second through restart, producing a small initial steering-timing difference. The separate runtime audit owns exact gameplay equivalence assertions.

## Integrated asset usage and corrected crowd

The actual source game selects the reduced infantry, minigunner and mech from `assets/mobile`, and uses three distinct mobile crowd meshes. All **544 accepted-baseline enemies remain**. Earlier 612-member geometry examples came from an older development snapshot and have been corrected in `mobile-art.md`; the mobile optimization does not reduce the accepted population.

At the first low-quality gameplay capture, the visible crowd has **160 near / 224 mid / 160 far** instances. High has **384 near / 160 mid / 0 far**. At every recorded gameplay frame, the three visible counts sum to the recorded living enemy count. The staged animation test also demonstrates all three LODs in the real scene.

The first integrated attempt showed bright red/green rectangular corruption even though the isolated asset contact sheet was correct. The animation worker's four-way GPU isolation and the implementation owner's fix established an observed Compatibility path issue with custom-only instance data. The accepted runtime explicitly supplies white per-instance RGBA and custom phase in a twenty-float buffer. The fresh normal gameplay captures independently confirm the repair: red caps, pale faces, correct front-facing troops and stable formations, with no green noise or misplaced instance blocks. Both low and high retain the intended palette. No new mobile-asset gamma fault is visible after this correction.

Low quality removes expensive shadows, limits visual effects and renders fewer 3D pixels. Its floor, characters and rails have conspicuous stair-stepping at 486 × 864; labels, target counters and projectiles remain readable. High is visibly sharper and has directional shadows. The minigunner still visibly multiplies cyan volleys, the statue changes color as its countdown falls, and the boss enters an articulated attack and death state during ordinary simulated play.

The full-crowd snapshots show **56 draw calls / 117,961 primitives in Low** and **92 / 195,591 in High**, including their different shadow and UI costs. These are single-frame render counters. They are not frame-time benchmarks, estimates for a phone or replacements for the independent performance investigator's traces. GPU jobs were serialized with the other reviewers to avoid contaminating those separate timing measurements.

## Profile-level rendering discrepancy and verified normalization

The original low and high captures differ in overall 3D brightness as well as resolution. Four sampled empty-floor positions read RGB **[115, 108, 112] in Low** and approximately **[158, 150, 159] in High**; the same difference appears at both 0.3 and 16 seconds. UI brightness stays stable. The material assets are unchanged between modes, so this is a profile/render-path discrepancy rather than a different crowd palette.

The implementation owner subsequently ran a fixed-scene five-condition GPU isolation. The reviewer read [probe.json](../artifacts/mobile-brightness/probe.json): full and reduced resolution, each with MSAA disabled or 2×, all retained the dark floor. Enabling the sun's shadows at the same reduced scale and without MSAA changed the floor to approximately **[158, 151, 159]**. This isolates the observed brightness change to the shadow-enabled lighting path on this tested renderer; it does not establish a general engine gamma defect or a cross-device guarantee.

The final Low/Battery implementation doubles sun, fill and ambient energy while keeping the sun shadow map disabled. The reviewer inspected the production `_apply_quality` code, the owner's fixed-scene capture script, [normalization.json](../artifacts/mobile-brightness/normalization.json), [normalized Low](../artifacts/mobile-brightness/low-normalized.png) and [High reference](../artifacts/mobile-brightness/high-reference.png). The normalized floor is **[158, 149, 154]**, against High **[158, 150, 159]**, instead of the earlier Low **[115, 108, 112]**. The large brightness gap is resolved visually and numerically. Minor hue, aliasing and shadow differences remain; identical rendering is not claimed.

This correction changes existing light energy values and adds no shadow maps or draw submissions. These before/after images are stationary scene probes with the HUD hidden, not new ordinary gameplay runs or performance measurements. Earlier `mobile-visual` gameplay captures remain labeled as pre-normalization. This addendum does not independently verify final packaged/Web lighting; that is covered by the final package captures. No additional reviewer GPU process was started for this addendum; the owner supplied the isolated GPU evidence, which was independently inspected.

A smaller behavior note: changing quality while paused updates resolution/shadows immediately, but the crowd's LOD membership refreshes when gameplay resumes. The paused screenshot can therefore retain the preceding profile's LOD counts. The menu is usable and the normal play captures show the correct new membership.

## Independent boss animation cross-review

The reviewer inspected the other worker's authored pose evidence, real controller screenshots and the corrected [integration results](../artifacts/mobile-boss/integration-results.json), including [wind-up](../artifacts/mobile-boss/attack-windup.png), [strike](../artifacts/mobile-boss/attack-strike.png), [fall](../artifacts/mobile-boss/death-fall.png) and [settled pose](../artifacts/mobile-boss/death-settled.png). The arms, torso, knees and body orientation change separately: this is articulated skin motion rather than the earlier whole-model wobble.

The [boss controller preview](../artifacts/mobile-boss/boss-controller-preview.mp4) is correctly labeled as a staged controller test. It suppresses automatic shooting, injects fifteen one-point hits and one lethal hit, and exercises walk → hit → walk → attack → walk → death. It must not be presented as ordinary gameplay or as a performance benchmark. The eight final controller assertions pass, including pause pose/time freeze, hit cooldown, full 1.7-second death visibility and a lowered terminal head bone. The terminal non-loop action clears `current_animation` as expected; its retained `assigned_animation` and actual fallen pose correctly establish completion.

Separately, this review's ordinary Low/High runs show the attack state at 5.2 seconds, a natural zero-HP/death state at 10.8 seconds, and the boss removed by 16 seconds. These gameplay images corroborate integration without relying on the staged driver's injected damage.

The death carries the large body partly beyond the left rail. That is visible and may merit aesthetic refinement, but the motion itself is complete and readable. The implementation owner also shortened white-flash duty cycle after the staged preview; this review's normal captures use the later source path, while a single captured white frame alone cannot quantify the flash duty cycle.

## Review outcome

Accepted for the tested scope: actual articulated boss actions, mobile asset use, corrected red/pale crowd rendering across LODs, retained enemy population, readable normal gameplay and working quality controls with input consumption. The subsequent fixed-scene normalization resolves the large Low/High brightness gap. Low still trades shadow detail and edge smoothness for lower rendering cost, and exact reference replication remains outside this acceptance.

No claim is made about weak-phone FPS, thermals, battery drain, browser/device compatibility or audio equivalence. The review ran on an Apple M1 Pro with Godot 4.7.2 Compatibility. Its owned process exited normally, and the GPU was released before subsequent performance traces began.
