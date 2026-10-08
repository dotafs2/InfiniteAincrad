# Mobile audience and performance target

Updated 2026-10-08. The user delegated the minimum device decision to an audience assessment and asked for stable30 FPS for that audience.

## Audience assessment

The one-finger steering, automatic fire, immediate multiplication rewards and short rounds suggest a casual action game acquired through short video or playable advertising. This is a product inference from the supplied game, not measured audience demographics. Age, gender, geography and device share cannot be established from one clip. Treat broad access and consistent response as more valuable than detailed distant geometry.

AppsFlyer's gaming-market research supports considering casual/mobile-ad acquisition at scale, but it does not establish the audience of this unlaunched game: https://www.appsflyer.com/resources/reports/gaming-app-marketing/ . No demographic percentage is inferred from this report.

## Proposed acceptance floor

- Android: Snapdragon665 / Adreno610 or HelioG80 / Mali-G52 class devices, including3–4GB RAM configurations. These are representative engineering targets, not a claim of a measured audience median. Relevant vendor specifications: https://www.qualcomm.com/smartphones/products/6-series/snapdragon-665-mobile-platform and https://www.mediatek.com/products/smartphones/mediatek-helio-g80 .
- iOS: older A11/A13 class phones as a secondary validation group. Current engine/browser and operating-system support must be checked on the actual delivery path.
- Target: stable30 FPS in ordinary and maximum-fan combat, including after thermal warm-up. A native device build and browser build need separate verification because browser overhead and WebGL support differ.
- Do not advertise support for every low-end phone. No target Android/iPhone is attached to this task for measurement; the Mac measurements establish workload reduction only.

## Implemented graphics policy

AUTO starts with LOW at30 FPS, no real-time shadow map, no MSAA, and at most640 pixels on the long 3D axis (360×640 at9:16). The2D interface stays at display resolution. Small contact shadows keep major actors grounded. A sustained slow-frame accumulator can reduce AUTO to BATTERY, with a480-pixel long axis and lower cosmetic budgets. Short loading spikes do not trigger a downgrade. The game never changes enemy counts, damage, firing rates or progression to meet a graphics budget.

| Mode | Frame limit | 3D long axis | Visible shots | Shots per packet | Sparks | Death silhouettes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| High | 60 | 960 | 1600 | 50 | 384 | 128 |
| Low / initial Auto | 30 | 640 | 512 | 18 | 96 | 32 |
| Battery / adaptive Auto | 30 | 480 | 320 | 12 | 48 | 16 |

All modes use the compact hero assets and13-bone animated bosses. Crowd selection changes among explicit near/mid/far meshes. Formation motion updates three batch nodes; living-instance buffers refresh when needed, and small crowd movement is animated in the vertex shader with simulation time. Cosmetics use a separate random generator so lower effect counts cannot alter later enemy layouts.

Rails, supports and gate frame boxes are batched by material under their moving parents. Gold gate plates share one batch. The static noise calculation on the road was removed. Paused frames skip projectile and effect buffer reconstruction; skeletons use manual simulation-time advancement. Shader resources are shared across actor replacements; hero scenes stay cached, and later hero/effect variants are warmed beneath the floor during the start menu to avoid first-use compilation during recruitment.

Godot documents resolution scaling and MultiMesh batching here: https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html and https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html . The limits above are this game's choices, not performance guarantees from Godot.

## Phone acceptance still required

Run at least15 minutes on representative devices, including full crowds, recruitment, ×999 fans, all bosses and repeated restarts. Record p50/p95/p99 frame time, frames above40/50ms, memory, thermal behavior and browser/native versions. A30 FPS cap alone does not prove sustained30 FPS. Check touch latency and readability at reduced resolution. Only device results may convert the proposed floor into a supported-device claim.

See mobile-review.md for reproducible desktop workload and regression evidence, and mobile-visual-review.md for independent in-game visual findings.
