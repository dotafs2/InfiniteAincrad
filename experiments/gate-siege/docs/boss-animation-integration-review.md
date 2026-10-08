# Boss animation and mobile art integration review

The final staged GPU integration run accepts the actual walk, hit, attack and death transitions, including pause/resume. It also found and helped repair a serious runtime crowd-color defect. The mobile LOD models were not the cause of that defect.

## Checked build and evidence

The accepted run records `scripts/game.gd` SHA-256 `352839a01fe22b0a851f75dfa0cc5fdb21e1c3bbcbb0e1bc740d0c99c81381a6` in [integration-results.json](../artifacts/mobile-boss/integration-results.json). It uses the real gameplay scene, camera, low-quality renderer, shaders, LOD meshes and controller functions. Automatic shooting is suppressed only in this review driver; fifteen one-point boss hits and one lethal hit are injected. This is a staged controller test, not ordinary play, a win demonstration or a phone performance result.

[The 9.933-second preview](../artifacts/mobile-boss/boss-controller-preview.mp4) contains 149 actual GPU frames encoded at 15 fps, at 486×864 pixels. The on-screen label identifies it as staged. The [GPU log](../artifacts/mobile-boss/integration-gpu.log) exits normally with no engine/script errors. Selected actual frames show [attack wind-up](../artifacts/mobile-boss/attack-windup.png), [attack strike](../artifacts/mobile-boss/attack-strike.png), [death fall](../artifacts/mobile-boss/death-fall.png) and [settled death](../artifacts/mobile-boss/death-settled.png).

All eight final checks pass:

1. The AnimationPlayer uses manual advancement controlled by gameplay.
2. The model has thirteen actual skin bones.
3. The boss body uses one material surface.
4. Pause freezes both animation time and the sampled foot-bone pose; resume continues.
5. The complete 1.7-second death interval remains visible before the boss is hidden.
6. Fifteen repeated damage calls produce only two hit-animation starts, demonstrating the cooldown avoids restarting on every hit.
7. The terminal pose retains the assigned death action and a lowered head bone at Y=1.06942, confirming articulated collapse.
8. The old white-flash marker has no mesh children; it does not substitute a rigid duplicate for the skinned boss.

Observed controller order is walk → hit → walk → hit → walk → timed attack → walk → death. The attack starts at approximately 5.03 seconds and returns to walk at 6.07. The lethal event starts death at 7.27 seconds. The initial probe incorrectly checked `current_animation` after a non-looping clip had finished; Godot correctly clears that field, while `assigned_animation` remains `death`. The corrected check inspects the retained action, terminal bone pose and visible fall. That original result and its footage remain in `artifacts/mobile-boss/rejected-custom-only/`.

## Crowd corruption found and fixed

The first integrated run showed bright red/green rectangular crowd corruption, despite correct colors in the separate LOD contact sheet. A four-way actual GPU experiment compared instance setter APIs against a bulk buffer, each with both StandardMaterial3D and the production custom shader.

With `use_custom_data=true` and `use_colors=false`, API-set instances became black and the bulk sixteen-float layout produced red/green corruption. Both material paths failed, excluding the custom fragment shader and model palette as the primary cause. [Rejected control image](../artifacts/mobile-boss/crowd-isolation.png).

Enabling per-instance colors, explicitly supplying white RGBA and placing custom phase after it fixes all four controls. The buffer is twelve transform floats, four white color floats and four custom floats, for twenty floats per instance. Root applied this change to the runtime without abandoning batching. [Accepted control image](../artifacts/mobile-boss/crowd-isolation-white-color.png). The fresh integrated GPU run verifies correctly colored red caps and pale faces, with 544 enemies retained across 240 near, 224 mid and 80 far instances at the sampled final time.

This is an observed Compatibility-renderer integration failure on the tested Apple M1 Pro setup. It is not a claim that sixteen-float transform/custom buffers are universally invalid; the [official MultiMesh implementation](https://github.com/godotengine/godot/blob/master/scene/resources/multimesh.cpp) computes four floats for each enabled color/custom field. The explicit white-color path is supported by the independent rendered controls and the fresh real-scene capture.

## Remaining visual notes

The peer mobile contact sheet preserves the essential blue infantry, silver gunner, gold/blue mech and red-cap crowd silhouettes. Near/mid/far crowd meshes trade facial and body detail for 320/144/66 triangles, while gameplay retains enemy count. The corrected real-scene crowd stays recognizably red and pale at low quality. This review does not establish physical-phone frame rate or thermal behavior.

The death motion carries the giant partly beyond the left railing but keeps its articulated body visible until removal. This is a presentation choice, not a missing death animation. The review found that continuous high-rate damage could keep resetting the original 0.065-second white-flash timer. Root subsequently changed it to a 0.055-second flash with a separate 0.14-second cooldown so material colors have a visible interval between flashes. That final small change was inspected in source; this reviewer did not run another GPU capture because the performance investigator owned the next exclusive GPU window. The accepted preview therefore predates the flash-cooldown refinement. The hit-animation cooldown itself behaves correctly.

No gameplay/HUD source was edited by this reviewer. Owned helper processes completed, and rejected evidence was preserved.
