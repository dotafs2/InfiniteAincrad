# Expansion rendering and combat implementation

The second clip is evidence for additive cards and whole-squad class conversion; the original multiplier layout is retained as an intentional hybrid. Eight waves,36 soldiers, five weapon choices and fantasy enemies are authored extensions. Review is split between a reference/rendering auditor and a mechanics/performance auditor. An auditor who repairs an asset or balance value is not treated as the sole independent acceptance authority for that change.

## Shared work and bounded workload

Every soldier owns an ID, shot clock and muzzle position. Followers share one MultiMesh per imported hero surface, two ground-shadow batches and a bounded36-ring upgrade batch. Same-class recruitment reuses existing mesh buffers. Quality changes affect rendering budgets; all soldiers,544 troops and configured elites remain logical.

The user explicitly permits fake bullets for performance. [Coverage combat](coverage-combat.md) merges firing energy into32 lateral cells at10Hz and resolves only crossed depth layers. Deterministic partial-area weights replace individual bullet collision. Every member contributes, while weapon budgets, gates, armor, class-on-landing and recruitment remain explicit. Rocket/Arc secondary effects are grouped once per field; rail has six contacts per cell.

A bounded MultiMesh now renders decorative camera-facing quads with analytic GPU movement. Only emission writes slot transforms; rendering changes a simulation-clock uniform. Split integer/fractional birth time avoids half-float precision loss in multi-minute Compatibility runs. Alpha blending and a narrow white core retain cyan/pink/violet color under dense fire. New streaks grow forward from their muzzles, expire at the selected cosmetic endpoint and cannot trail behind boots. Gate crossings emit a bounded multiplied fan. Graphics density has no authority over damage. This is an intentional2.5D area approximation rather than volumetric bullet physics.

Red warning discs share a mesh and a preloaded shader. The actual material is drawn in the menu warmup before combat. This addresses the independently reproduced first-warning GPU stall; measurement of the repaired version is recorded separately. Warnings and the cyan core use the same ground coordinate and radius contract. The cyan core is placed ahead of the front row so its shared-health hurtbox remains visible. It is deliberately possible to steer the full36 formation out of a warning.

## Art and composition

Original Blender assets provide detailed hero uniforms/hardware and articulated dragon, golem and skitter parts. Wings expose broad double-sided scalloped membranes and change poses during normal gameplay. Tail/limb/wing transforms share simulation time, including pause and death. Dragon attack warnings, shield mitigation and fast skitter movement are gameplay behavior, not preview-only animation.

The foreground keeps neutral road contrast, warm metal, cool uniforms and strong grounded shadows; lighter blue city materials and restrained fog give distance separation. Low/Auto/Battery preserve a1280px long-axis3D budget at portrait9:16, with MSAA2× and native UI. High allows1600px and real sun shadows. Fresh staged captures are720×1280, with a new game instance for each creature scenario; staged images cannot establish natural pacing. An uninterrupted normal-input movie and browser checks serve that separate purpose.

## Evidence boundaries

The deterministic controller supplies pointer/weapon input and reads visible warnings. It never injects campaign damage, members, health or wave progression. Its simulations are reachability/balance evidence, not human play or device FPS. GPU stress runs use wall-clock frame timing without movie mode. All desktop results belong to Apple M1 Pro. The intended Android audience floor still needs physical-phone30-FPS/thermal/touch testing.
