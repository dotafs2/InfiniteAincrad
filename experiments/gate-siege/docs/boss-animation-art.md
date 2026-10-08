# Articulated mobile boss assets

The original static bosses remain unchanged. Two new GLBs add a 13-bone skin and four authored clips while reducing each boss to one material surface and 6,398 triangles. The vest boss drops from 19,136 triangles and ten surfaces; the pink boss drops from 14,908 triangles and nine surfaces. Each vertex uses at most two bone influences. These are asset-budget reductions, not measured weak-phone frame-rate results.

| Asset | Bytes | Triangles | Bones | Surfaces |
| --- | ---: | ---: | ---: | ---: |
| `assets/models/brute_vest_animated.glb` | 389,816 | 6,398 | 13 | 1 |
| `assets/models/brute_animated.glb` | 378,360 | 6,398 | 13 | 1 |

Both retain the 3.4-unit standing envelope, foot origin, Godot Y-up and -Z forward. The skeleton contains pelvis, spine, head, left/right upper arm, forearm, thigh, shin and foot. Individual limbs are weighted to their actual bones; shoulder and waist seams blend between two bones. Walk, attack and death visibly change limb articulation rather than moving the complete mesh as one rigid object.

## Runtime contract

Godot 4.7.2 imports the exact hierarchy:

- `AnimationPlayer` — direct child of the instantiated scene root.
- `BossRig/Skeleton3D` — thirteen imported bones.
- `BossRig/Skeleton3D/BossBody` — one skinned mesh surface.

```gdscript
var player: AnimationPlayer = boss_model.get_node("AnimationPlayer")
var body: MeshInstance3D = boss_model.get_node("BossRig/Skeleton3D/BossBody")
var palette: BaseMaterial3D = body.get_active_material(0)
palette.vertex_color_use_as_albedo = true
palette.vertex_color_is_srgb = false
player.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
for clip in ["attack", "hit", "death"]:
    player.get_animation(clip).loop_mode = Animation.LOOP_NONE
player.play("walk")
```

Standard glTF does not carry a portable looping flag. Explicitly configure only `walk` to loop after import. Its first and last skin transforms match within 0.0001. The three other clips should finish once, and the gameplay controller should decide the following state. Clips contain no external forward root motion; the existing controller can advance the boss while the skeleton walks in place. Remove the former rigid whole-body walk wobble from these variants.

| Clip | Imported duration | Authored behavior |
| --- | ---: | --- |
| `walk` | 1.2 seconds | Alternating thigh/knee flexion, planted stance foot, raised swing foot, opposing arm swing and lateral weight shift |
| `attack` | 1.0 second | Raise both fists, hold the wind-up, strike forward/down near 0.64 seconds, recover |
| `hit` | 0.3 seconds | Brief spine/head recoil and asymmetric arm response |
| `death` | 1.7 seconds | Knees buckle, torso bends, body falls to its side and settles |

Keep the death mesh visible for its full clip if the complete fall should be seen. Clip ground placement is baked into pelvis translation by measuring the posed skin's lowest vertex during authoring, so runtime IK and per-frame collision queries are unnecessary.

## Palette and generation

`art_source/build_boss_animations.py` reads the existing geometry builder only up to its explicit export entry point and does not execute that builder's export loop. It constructs new meshes, assigns anatomical skin weights, reduces geometry, validates and repairs duplicate degenerate faces left by reduction, collapses the material palette and exports four actions. A hash guard proves all seven static GLBs remain byte-identical after generation.

The one-surface material uses roughness 0.57 and metallic 0.10 across the full model. Individual metal/skin roughness is intentionally simplified. Vertex colors are baked for the project's Compatibility renderer so the original tan, red leather and pink appearance is preserved. The real GPU comparison rejected the first dark/red linear-color pass and accepted the corrected palette. The `vertex_color_is_srgb` toggle is not effective in Compatibility; if switching to Forward+ or Mobile, use sRGB vertex interpretation and recheck appearance. See [Godot BaseMaterial3D color-space behavior](https://docs.godotengine.org/en/4.5/classes/class_basematerial3d.html).

## Verified evidence

An isolated project at `/private/tmp/gate-boss-animation-probe` imports copies of the final GLBs without modifying the gameplay scripts. Its actual Apple M1 Pro OpenGL/Metal run samples eight poses of both models: walk at 0, 0.3 and 0.9 seconds; attack at 0.3 and 0.64; hit at 0.075; death at 0.55 and 1.7. GPU images are in its `captures/` directory, and `gpu.log` records bone names, AnimationPlayer paths, exact durations, surface/skin presence and changing foot, forearm and head coordinates. The final GPU run exits normally without engine or script errors.

Binary validation confirms one surface, thirteen joints, `COLOR_0`, normalized skin weights, at most two influences per vertex, correct bounds, all four clips and a closed walk loop. `validation.json` in the isolated project records these checks. These files are temporary verification evidence; the primary agent may copy selected evidence into the task's artifact directory.

Final SHA-256 values:

- `brute_vest_animated.glb`: `fe791d5defa462433442f90525f3be35606b3432114225e48fda210cd2ca3a58`
- `brute_animated.glb`: `c1756b6f8bf5d5c259a3e1f527f9a5413b1d3f03fd30e4adaafc1e8c7393676c`

All owned Blender and Godot helper processes completed. No user application was stopped. Actual weak-phone performance remains a runtime integration measurement.
