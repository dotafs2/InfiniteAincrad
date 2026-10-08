# Independent runtime review

Date: 2026-10-08. Scope: the standalone `experiments/gate-siege` project. No Hole Feast code, real saves, account configuration or publication is part of this review.

The independent reviewer owns `tests/runtime_review.gd` and this report. Production fixes are applied by the root implementer. The reference audit is treated as evidence of visible behavior, not a specification of rules absent from the clip.

## Reproduction

From this project's root:

```sh
godot --headless --path . --log-file /private/tmp/gate-siege-runtime-review.log --script res://tests/runtime_review.gd
```

The test creates the actual game scene and its actual models, then advances the production `_physics_process` manually at a controlled delta. Focused collision cases position existing enemies and real projectile packets to isolate ordering. They are distinguished from the full runs, where only pointer input is supplied and all health, damage, gates, actors and progression remain untouched.

Mouse, touch and keyboard handler checks exercise production InputEvent handling. A separate viewport-routed click activates the real mute Button, allowing the review to detect a UI click leaking into game movement. These are engine input tests, not physical touchscreen or OS automation claims. Long win/loss trials use the production 60 Hz physics delta; no `--demo` driver is used. Rendering and platform performance require the separate visual review.

## Faults found and corrected during review

| Reproduced fault | Consequence | Regression coverage |
| --- | --- | --- |
| Crowd collisions originally ignored each soldier's forward position. | A shot reaching an empty front rank killed distant soldiers; rear soldiers also shielded a nearer boss. | Empty-rank travel, delayed rear-rank collision and exposed-boss fixtures. |
| Crowd always resolved before a boss when both were crossed in a single step. | A soldier behind a boss absorbed the first hit. | Same-step nearest-target fixture. |
| Restart kept held touch ownership and telemetry. | A new touch could be rejected, and displayed review counters combined runs. | Restart while dragging plus clean run counters. |
| A fatal final troop breach also triggered wave completion. | Final wave reported victory at zero health and counted both outcomes. | Final enemy breaches with one health remaining. |
| A viewport-routed mute click also reached game steering. | Muting audio changed the player's aiming position. | Real Button callback plus unchanged aim assertion. |
| A boss killed after the last troop advanced the wave immediately. | Its new death animation disappeared before the next wave or result screen. | Real killing hit preserves the death state, then reaches victory only after the animation. |

The implementation now additionally preserves excess volley damage through actual travel instead of teleporting damage to distant ranks. Recruitment tests cover one unlock per hit sequence, a real airborne transfer, pause during transfer, landing with model replacement, and restart during transfer.

## Current mobile revision (0.2.1)

The final mobile revision passes the same 57-check suite from source and from the isolated `build/mobile-web/index.pck`, SHA-256 `684b08d7ccecc2ceee5627993f168b26f4e7a93a458677e52e1470e15fc8c033`. Both runs exit 0 with clean logs. The boss now uses a real 1.7-second skeleton death animation and contact-timed attack; the full pointer trial wins at 19.90 seconds, while unattended play loses at 67.13 seconds. The death-completion test uses the actual animation timer. All 1,632 troops, three hero tiers, 100 winning health and a peak of 27 volley packets remain consistent.

The independent mobile suite additionally passes 66 checks on source and exact package. The current real-GPU shadow probe matches source/package draw counts across all tiers and quality settings. The earlier complete GPU mobile-suite repeat belongs to version 0.2.0; versioned evidence, quality invariance, physical render-size limits, custom-data precision, shader warmup, profiles, current hashes and remaining device limits are documented in [mobile-review.md](mobile-review.md). The new shadow suite passes 86 additional checks on both source and package, for 209 checks in each. Current lifecycle logs are `artifacts/mobile-baseline/comparison/runtime-shadow-source.log` and `runtime_review-shadow-pck.log`. The older result below is retained as the immutable baseline checkpoint, not the current runtime timing.

## Pre-mobile accepted checkpoint

**Accepted: source and exact exported Web PCK each pass 57 checks, zero failures.** Both final clean Godot 4.7.2 runs exited 0 and contained no engine warnings, script errors or shutdown leaks. Both full 60 Hz pointer-input trials reached third-wave victory at 18.80 seconds, with all 1,632 troops killed, all three heroes unlocked, 100 health remaining and a peak of 27 live projectile packets. Unattended right-side play naturally lost at 67.65 seconds when the boss breached the line. These figures are implementation tests, not measurements of the source video's rules.

This result includes the final faster shot intervals, increased tier damage, wider volleys and 999-point gold armor. The optimized winning policy is very fast after those deliberate tuning changes; a human difficulty assessment remains open. The earlier pre-tuning accepted run took 45.47 seconds and is superseded for current pacing.

The automated winning strategy reads game positions to choose pointer coordinates; it demonstrates reachable normal controls, not human difficulty or an independent blind playthrough. It never assigns health, enemy state, tier, gate health or phase during that full run. Collision and terminal fixtures use explicit arrangements and are reported separately.

Final source, test and PCK hashes, verified unchanged before and after both runs:

| File | SHA-256 |
| --- | --- |
| `scripts/game.gd` | `3d9bdebd95a8c0ed31ce832adc749b5204798fe816c17273dc3b7cada074f9c2` |
| `scripts/hud.gd` | `1469641f283721c9a3251d83c77b2ad7685b2d0837336d42a1c4a28740fa97d4` |
| `tests/runtime_review.gd` | `313af698f5250f96035adbcf885fcb458fdf11c6a99de310176d3a9be93cfac0` |
| `project.godot` | `5cdc0cbc89924fc471f4f709083eeaa4ebcfc92bc61c2c1a0e3e060bc41deba5` |
| `icon.svg` | `da11de07815cfb8df1abe903550b1f786004c3e52343a09480c13ec2d701081f` |
| `build/web/index.pck` | `603c891f2f70431391a45c06d98788ac68379bb12b82ae78062bc29d30adc1e7` |

The complete final logs are `/private/tmp/gate-siege-runtime-source-final.log` and `/private/tmp/gate-siege-runtime-pck-final.log`. The PCK run used a freshly created empty directory for both `--path` and working directory, the exact `--main-pack` above, and the absolute external test script. All `res://` game scripts, models, fonts and scenes resolved from the package; the empty directory had no game source to fall back to. The source and PCK printed identical outcome metrics. The final source includes the render-only boss/flash visibility correction, the Barlow HUD font with ASCII `II` / `SFX` / `OFF` toolbar labels, and the project icon. The complete source and isolated-package suites were repeated after that last UI correction; result metrics remain identical. All reviewer-owned Godot test/import processes exited; an intermediate run against a renamed handler failed and was corrected before acceptance.

## Limits

The visual projectile instances are bounded, while their packet counts carry the full multiplication. A synthetic oversized draw verifies the allocated MultiMesh cap, and a stress emit verifies the spark cap and expiry. This does not certify frame rate on a phone or browser.

Early sandboxed runs reported a macOS system certificate lookup error before the game ran; editor imports also reported restricted IDE socket and editor-settings writes. The final acceptance run used approved execution outside that sandbox and had a clean log. The discovered faults and their regression checks are documented above; failed iterations are not counted as successful runs.

The supplied clip cannot establish exact health, later-wave tuning, the completed times-999 behavior, victory, defeat or all later weapons. Passing runtime tests confirms that this reconstruction is interactive and reaches its own terminal states. It does not support a claim of a completely identical recreation.
