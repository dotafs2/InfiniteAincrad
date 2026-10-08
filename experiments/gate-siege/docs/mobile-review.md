# Independent mobile performance and animation review

Date: 2026-10-08. This review targets the standalone Gate Siege project. The audience-oriented baseline uses low graphics with a 30 FPS cap; no particular Android model or physical phone has been supplied or measured. Desktop timings below are comparative evidence, never a claim of Android 30 FPS.

## Version 0.2.1 grounded player shadows

**Current accepted package:** `build/mobile-web/index.pck`, SHA-256 `684b08d7ccecc2ceee5627993f168b26f4e7a93a458677e52e1470e15fc8c033`. Source and the exact package each pass all **209 checks**: 86 focused shadow checks, the existing 57 lifecycle checks and 66 mobile/animation checks. All final logs are clean and all runs exit 0. The package was loaded with an empty working directory and `--path`; external test scripts resolved all game resources from the PCK without source fallback. A preserved copy is `artifacts/mobile-baseline/comparison/shadow-final.pck`.

The original contact plane was attached below `player_model`, so it inherited the player's vertical bob, the model's steering/recoil tilt and tier-dependent scale. The correction gives the contact and baked directional planes their own game-root anchor at ground level. Tests exercise all four tiers under real production movement/bob/lean, imported silhouette selection, floor normals and heights, pause, all quality choices, three actual recruitment landings and four restarts during flight. Temporary recruitment shadows project along the actual scene light and are freed on landing or restart. Low/battery keep the baked projection with realtime sun shadows disabled; high hides that projection and retains realtime casting plus the contact plane, avoiding duplicate directional shadows.

A real-GPU probe compared each exact scene with its player-shadow rig shown versus hidden, after four settling frames. It repeated all four tiers in low, battery and high; the package and source produce identical counts:

| Quality | Shadow rig contribution, every tier | Full-crowd tier-0 scene | Difference from version 0.2.0 |
| --- | ---: | ---: | ---: |
| Low | 2 draws / 4 primitives | 55 draws / 117,651 primitives | +1 draw / +2 primitives |
| Battery | 2 draws / 4 primitives | 54 draws / 72,339 primitives | +1 draw / +2 primitives |
| High | 1 draw / 2 primitives | 90 draws / 195,327 primitives | Unchanged |

The low/battery increase replaces the former single contact quad with contact plus direction. No phone frame-rate claim follows from this small draw-count comparison. The older full timing matrix and cold/warm traces below describe version 0.2.0; they were not silently relabeled as new timings.

Natural outcomes remain unchanged: lifecycle policy wins at 19.90 seconds, unattended play loses at 67.13 seconds, and all four quality modes have identical 21 snapshots and win at 19.7167 seconds with 1,632 kills and full health. Package logs are `comparison/{shadow_review,runtime_review,mobile_review}-shadow-pck.log`; GPU counts are `comparison/shadow-pck-gpu.json`, with corresponding source logs and counts beside them. Paths are under `artifacts/mobile-baseline`.

| Current file | SHA-256 |
| --- | --- |
| `scripts/game.gd` | `06b582f8b3a464d249d871401dd9f1d6020c498e8d6a1fb38eaab35049c01bb9` |
| `assets/shaders/contact_shadow.gdshader` | `3175b37bc72661db05d3530d8327659005fa9aebaa533637275fd3ffd0f1e312` |
| `tests/shadow_review.gd` | `1bb9e9f85859d25c69b33839c4b0ec4692c5782e86239c0cd63ec6579b4299d4` |

`comparison/shadow-final-manifest.json` records all current source, test, silhouette and package hashes. The final package hash was verified before and after review. All reviewer processes exited and the empty isolated directory was removed.

## Immutable baseline

`artifacts/mobile-baseline/baseline.pck` is the previously accepted Web export, SHA-256 `603c891f2f70431391a45c06d98788ac68379bb12b82ae78062bc29d30adc1e7`. It is copied before production optimization and loaded with `--main-pack` from an empty directory. The external `tools/profile_mobile.gd` observes the package's real game methods without changing production source. Raw JSON, logs and a hash manifest are preserved alongside that PCK.

Hardware: Apple M1 Pro, 10 logical processors, Godot 4.7.2, OpenGL Compatibility. The owned profiling window is 486 × 864, with vsync disabled. No movie mode, frame capture or fixed engine FPS is used during measurement. Each GPU scene warms for one wall-clock second and samples for 2.5 seconds.

The five stress scenes keep physics frozen to preserve their stated visible geometry, but call the production visual update every rendered frame. They are GPU workload comparisons, not full-game FPS. A separate `active_gameplay` scene runs real 60 Hz physics normally. Headless CPU runs manually execute 120 production steps after a 30-step warmup, and are not GPU or device frame-rate evidence.

| Baseline scene | Draw calls | Rendered primitives | Wall frame mean / p95 | Notes |
| --- | ---: | ---: | ---: | --- |
| Full crowd | 393 | 118,846 | 4.36 / 6.44 ms | All 544 troops visible; no shots. |
| Gunner fans | 428 | 170,884 | 4.77 / 7.13 ms | 36 volley packets, 360 visible shots, 200 sparks. |
| Times 999 | 311 | 230,750 | 5.27 / 7.59 ms | 32 multiplied packets, 1,600 visible shots. |
| Late wave | 261 | 165,866 | 4.90 / 7.30 ms | Third-wave actors and multiplied shots. |
| Paused | 437 | 171,652 | 5.44 / 7.89 ms | Gunner scene with the pause overlay; visual work still repeats. |
| Active gameplay | ~395 | ~121,891 mean | 4.99 / 7.63 ms | Live 60 Hz physics; crowd decreases from 514 to 442 during sampling. |

The crowd is already one MultiMesh batch. The high draw count therefore cannot be solved merely by batching troops again; static rails and the many character/statue/gate parts remain relevant. Rendering-server primitives are the engine's reported primitive count, including its render passes, not an independently counted model triangle total.

Baseline headless mean physics CPU is 0.378 ms for the recruit scene, 2.274 ms for gunner fans, 1.784 ms for times 999 and 1.761 ms for late wave. The paused physics method returns in approximately zero time, yet its repeated visual updates still average 0.233 ms. In the actual GPU live scene, physics CPU averages 0.446 ms (p95 0.651 ms). These measurements include different staged/evolving actor loads; they must not be mixed into a single predicted phone frame time.

## Candidate optimization measurements

The first optimized GPU comparison preserved all 544 troops, reduced default-low full-crowd draw calls 393→54, and reduced the times 999 scene from 230,750→125,986 primitives. Battery mode reached 53 full-crowd draw calls and 75,746 times 999 primitives. High retained higher geometric detail while lowering full-crowd draw calls to 90. These are candidate measurements; the first matrix preceded the explicit-white crowd color correction and is retained as an intermediate record, not final pixel acceptance.

A GPU pixel review caught red/green corruption in the custom-data crowd path. The corrected path explicitly supplies white instance colors and a 20-float transform/color/custom record. New regressions validate the exact packed buffer and phase values. The headless renderer's per-instance getters returned dummy defaults despite valid buffers, so those getters are not used as headless evidence of GPU colors; separate real GPU review checks the pixels.

Headless CPU comparison after that correction measured low-mode mean physics 0.254/1.988/1.567/1.568 ms for recruit/gunner/times 999/late wave. Low times 999 visual upload cost fell 0.466→0.185 ms, while paused visual processing fell 0.233→0.0004 ms. Raw `comparison/*-cpu.json` and logs preserve all distributions rather than only means.

## Real slow-frame investigation

Two 20-second live traces used the normal 60 Hz simulation and the existing demo steering controller: one uncapped, one capped at 30 FPS. No movie recording occurred. Before the fix, the uncapped run had p95 4.235 ms, but two large 357.551 / 230.704 ms frames appeared at simulation 9.7333 / 19.1000 seconds. The capped run repeated the same events at 381.984 / 265.524 ms. Both coincided with first/second hero landing and actor/statue replacement. Last measured game physics was only 1.6–6.5 ms and visual updates 25–47 microseconds. This pointed toward first-use rendering work outside the timed game methods, rather than a proven driver-level cause.

The implementer replaced repeated shader construction with six shared resources, retained model PackedScene resources in a cache, and added two rendered ready-screen warmup frames for the first-use mech, shell and defeat effect. A separate regression verifies that the warmup advances no game time, gameplay RNG or shots, releases its proxy, and keeps repeated model/shader resources shared.

The same two real-time traces were repeated after that change and the final low-lighting correction:

| Run | Sampled frames | Mean / p95 | Maximum | Frames over 50 ms |
| --- | ---: | ---: | ---: | ---: |
| Before, uncapped | 9,960 | 2.008 / 4.235 ms | 357.551 ms | 2 |
| After, uncapped | 9,117 | 2.194 / 5.728 ms | 14.497 ms | 0 |
| Before, 30 FPS | 587 | 34.122 / 37.156 ms | 381.984 ms | 2 |
| After, 30 FPS | 601 | 33.328 / 36.992 ms | 48.953 ms | 0 |

The capped upgrade frames specifically fell from 381.984 / 265.524 ms to 46.692 / 37.357 ms at the same two simulation times. The uncapped run had no frame over 30 ms. This verifies removal of those reproducible stalls in these desktop runs; it does not promise zero hitches on every platform. At 30 FPS, ordinary 33.3 ms intervals are expected, so counting all frames over 30 ms would be misleading. Raw before/after files are `comparison/live-cold-{0,30}.json` and `comparison/live-warm-{0,30}.json`, with complete logs beside them.

## Version 0.2.0 source regression result

The final lighting-adjusted source passed both independent suites with the standard Godot 4.7.2 binary: 57 lifecycle/collision checks and 66 animation/mobile checks, no failures and clean logs. Real skeleton transforms move through walk, hit, attack and death; pause freezes their poses and contact clock; restart restores a fresh boss. Close-range damage waits for the punch contact instead of ending during the windup.

High, low, battery and auto produced identical 21 gameplay fingerprints in separate full runs: victory at 19.7167 seconds, all 1,632 troops defeated, tier 3, health 100. These state-aware pointer strategies establish reachable normal controls and quality invariance, not human difficulty. A separate lifecycle strategy won at 19.90 seconds; unattended play naturally lost at 67.13 seconds. The skeleton death duration changes the old baseline's result timing.

The suite additionally covers the physical 3D render budget on a 1080 × 1920 viewport, graphics-only adaptive fallback, bounded bullet/effect instances, actual packed crowd data, all 544 living troops in every LOD mode, same-frame quality switching, pause/recruitment and warmup cache lifetime. Shader color correctness and visible animation also have independent real-GPU evidence from the art reviewer.

Source logs: `comparison/runtime-final-source.log` and `comparison/mobile-final-source.log` under `artifacts/mobile-baseline`.

## Version 0.2.0 exact package acceptance

The isolated final package at `build/mobile-web/index.pck` passes 57 lifecycle checks and 66 animation/mobile checks headlessly. A supplemental real-GPU run also passes all 66 animation/mobile checks, including the rendered warmup path. All final executions exit 0 with clean engine logs. The source and package natural outcomes and quality fingerprints match.

The extra GPU run first exposed a test precision assumption: custom MultiMesh channels are stored as float16 by Godot's Compatibility renderer, while headless buffers preserve float32. The revised test compares the exact `encode_half` / `decode_half` representation on real Compatibility GPUs and keeps the original strict float32 comparison headlessly. It does not relax white modulation, layout, zero channels or gameplay assertions. Observed example: source 5.8386507077, expected float16 5.8359375, GPU readback 5.8359375; largest observed truncation was 0.0038978313. This matches Godot's documented [MultiMesh custom-data precision](https://docs.godotengine.org/en/stable/classes/class_multimesh.html#class-multimesh-method-set-instance-custom-data). The failed initial precision run remains as `comparison/mobile-final-pck-gpu.log`; the corrected clean run is `comparison/mobile-final-pck-gpu-half.log`.

The final package was loaded from a newly created empty working directory, also supplied as `--path`, with an absolute `--main-pack` path and external test/profiler scripts. No game scripts or assets existed in that directory, so `res://` resources came from the package without source fallback. The reviewed package is also preserved as `comparison/final.pck`.

| File | SHA-256 |
| --- | --- |
| `build/mobile-web/index.pck` | `8152cae2d2879f3da8cb3d509ebe60c2bb1536a0fb2189a37ae30a9e5d31aa7c` |
| `scripts/game.gd` | `cc0351dd8c0d8f51e06b7c5e84acba9eefff0c06f1353d792a78f240e910047c` |
| `scripts/hud.gd` | `eae1d26cbdb7c10b0c1c0d645d607ea74ccdc76199557aa7b4fb0831f1a41f64` |
| `tests/runtime_review.gd` | `c0d2c86dd1aaa62d239573833cef7518760c34b87aa6887c5da75a9ccb1abb88` |
| `tests/mobile_review.gd` | `715200278341b709c6287ac20513195fa40bde0bc4e77fcc1c97ed71651b6d5a` |
| `tools/profile_mobile.gd` | `4c5ad7d8c3655780b7a9e7cb8bb65b23e778d67a3a9850df64c384bc6ec508ad` |

`comparison/final-manifest.json` additionally records project/shader hashes, package size and verification counts. The PCK hash stayed unchanged throughout all checks and GPU measurements.

## Version 0.2.0 package graphics matrix

The same six scenarios were repeated against the exact package on the actual M1 Pro GPU. All three modes retained every one of the 544 living troops in the five frozen stress scenes. Cells below are **draw calls / rendered primitives**; the active row is the sampled mean, since combat changes the crowd.

| Scene | Previous baseline | Final high | Final low | Final battery |
| --- | ---: | ---: | ---: | ---: |
| Full crowd | 393 / 118,846 | 90 / 195,327 | 54 / 117,649 | 53 / 72,337 |
| Gunner fans | 428 / 170,884 | 95 / 208,647 | 57 / 127,833 | 56 / 81,561 |
| Times 999 | 311 / 230,750 | 94 / 227,518 | 56 / 125,986 | 55 / 76,066 |
| Late wave | 261 / 165,866 | 86 / 213,126 | 52 / 118,792 | 51 / 68,872 |
| Paused | 437 / 171,652 | 106 / 209,761 | 68 / 128,945 | 67 / 82,681 |
| Active gameplay | ~395 / 121,891 | 92.1 / 171,275 | 56.1 / 94,774 | 55.1 / 62,043 |

Default low reduces full-crowd draw calls by 86.3% and times-999 primitives by 45.4% relative to the preserved baseline. High keeps greater detail and shadows; its full-crowd primitive count is higher than the old game, so it is not the low-end target. Low/battery 3D scales are 0.740741 / 0.555556 in the 486 × 864 profiling window, corresponding to 640 / 480-pixel long axes. A separate 1080 × 1920 viewport test confirms that the low cap uses the physical render size. GUI rendering remains separate.

Final low mean / p95 frame intervals were 1.668 / 3.240 ms (full crowd), 1.675 / 3.133 ms (gunner), 1.675 / 3.245 ms (times 999), 1.643 / 3.435 ms (late wave), 1.671 / 2.930 ms (paused), and 1.749 / 3.296 ms (active gameplay). The matrix is uncapped for cost comparison, not the shipping 30 FPS setting. No sampled matrix frame exceeded 30 ms. Full distributions for every quality and scenario are in `comparison/final-{high,low,battery}-gpu.json`; the longer warmup traces above cover the upgrade transitions that a short scene sample misses.

The exact package's low headless mean physics costs were 0.257 / 1.987 / 1.608 / 1.580 ms for recruit/gunner/times-999/late-wave scenarios. Times-999 visual updates averaged 0.190 ms versus the baseline's 0.466 ms; paused visual processing averaged 0.000392 ms versus 0.233 ms. These are the actual production methods under controlled staged inputs, not a synthetic mobile FPS estimate. Raw data is `comparison/final-low-cpu.json`.

## Remaining limits

This review demonstrates bounded rendering workloads, pause behavior, real joint animation, quality-independent gameplay and removal of the reproduced desktop upgrade stalls. It does not measure Android hardware, a browser GPU, thermal throttling, memory pressure or battery draw, and therefore does not certify a particular phone's sustained 30 FPS. The GPU matrix is a single controlled comparison on this Mac rather than a cross-device benchmark. The supplied video also cannot establish exact hidden damage, complete later levels or all terminal rules; runtime acceptance is not a claim of a completely identical game.

All reviewer-owned test and profiling processes exited. No user application was stopped. Source production files were not modified by this reviewer.
