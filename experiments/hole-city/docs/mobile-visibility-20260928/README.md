# Mobile clarity and camera visibility — v0.8.1

The gameplay camera now reveals the hole and the ground ahead through
intervening buildings, props, people, traffic and food. Previously, only some
building centers were tested against the hole's footprint; a tall or wide
occluder could cover the player without triggering the fade.

## Changes

The shared opaque-material shader projects each visible fragment along its
camera ray onto the hole plane. A feathered aperture extends beyond the hole
by at least one world unit and grows with its radius. Smoothed movement adds a
bounded forward extension, including movement away from the camera. Stable
ordered dithering reveals the route without alpha-sorting dependencies.

The controller updates four shared vectors per frame. It binds scene
materials once and binds new fallback debris when created. It does not scan
objects, create materials or change physical bodies during movement. Food
rain, settled batches, released props, skinned NPCs and both cached and
uncached fracture paths retain reveal support. Ground, player skins and menu
preview cameras are excluded; shadow passes retain complete casters. Pause
freezes the current aperture, and results, titles and a new world clear it.

Visible collection thumbnails now request 2× MSAA and use the actual canvas
pixel density, capped at 3×. The page still creates at most six thumbnails and
continuously animates only the selected one. Main-scene 4× MSAA and shadows
remain enabled. Food roads now have stored mipmaps and matching trilinear
sampling. Procedural paving, lane marks and miniature windows filter their
subpixel detail while retaining nominal dimensions and palette.

## Independent acceptance

| Unit | Author validation | Non-author validation |
| --- | --- | --- |
| Collection thumbnails | 695 checks | Separate agent rerun plus backing-size geometry oracle and cache/lifecycle inspection |
| Texture and procedural filtering | 27 resource checks and 1,848 scalar cases | Separate agent rerun, original-color hash and exact area-composition review |
| Camera reveal | 191 checks | Separate agent's 1,700-check scene/material/physics/lifecycle suite |
| Shader equations | Current source compiled in windowless CGL | Reviewed by the reveal reviewer; 19 coverage cases and 12 material-midpoint cases |

The independent reveal tests inspect 935 city and 2,588 food surfaces,
29/527 initial batches and 112 skinned NPCs. They cover ten rain kinds,
static-to-independent release, sixteen-piece cached and fallback fractures,
and 36 camera/radius/movement combinations. Review caught two real initial
failures: a roof directly above the hole and the lookahead region away from
the camera were incorrectly excluded by an extra world-space half-plane.
The failed shader receipt is retained beside the corrected result.

- [Collection implementation](collection-thumbnails.md)
- [Independent visibility review](visibility-review.md)
- [Reveal implementation](../visual-quality-20260928/occlusion-implementation.md)
- [Independent thumbnail review](../fixes/reviews/mobile-thumbnails.md)
- [Independent filtering review](../fixes/reviews/procedural-filtering.md)
- [Initial failed shader coverage](../../artifacts/mobile-visibility-20260928/shader-probe-initial/result.json)
- [Corrected shader coverage and material equations](../../artifacts/mobile-visibility-20260928/shader-probe-final/result.json)

## Evidence boundaries

The guarded release passes all 37 suites in both source and an isolated
exported PCK: 13,092 checks per phase. It then replaces the local Web preview
atomically. Authored import recipes are now fingerprinted alongside scene,
script and shader inputs, so a mip-import change cannot silently escape the
release guard. The release helper's refusal/rollback regression passes 36
checks. See [release receipts](../../artifacts/mobile-visibility-20260928/release/release.json)
and [independent release/profile-tool review](../fixes/reviews/visual-gate-profiling.md).

Three separate native headless runs per scenario measured 600 intervals each
after warmup. Every measured interval includes a reveal update; all source,
asset/import, helper and engine fingerprints match before and after the runs.
The table reports the median of the three run-specific P95 values.

| Scenario | CPU P95 | Measured intervals | Intervals above 16.67 ms |
| --- | ---: | ---: | ---: |
| Sunny City opening | 6.971 ms | 1,800 | 0 |
| Sunny City grown hole | 7.130 ms | 1,800 | 0 |
| Snack Garden opening | 5.032 ms | 1,800 | 0 |
| Snack Garden grown hole | 6.880 ms | 1,800 | 0 |

The CPU trace does not include rasterization, discard/dither cost, MSAA,
texture sampling, browser scheduling or phone thermals. It supports no
observed CPU frame-budget violation in these traces, not an iPhone FPS claim
or a controlled comparison against the previous version. Full raw intervals
and fingerprints are in the [CPU receipt](../../artifacts/mobile-visibility-20260928/cpu/summary.json).

Final [delivery verification](../../artifacts/mobile-visibility-20260928/verification.json)
checks all source/package suite receipts, current shader hashes and all 31
shader cases, all twelve raw CPU traces, recomputed summaries and every
HTTP-served artifact against the release. All ten artifacts match and retain
the WebAssembly isolation headers. The verifier rejects incomplete receipts;
its independent fault suite passes 76 checks. All owned test/helper processes
have ended; the existing local preview server remains running.

Scene tests use the native headless engine. The isolated shader probe executes
the shipped reveal equations and adapter color transform in windowless
OpenGL, reporting Apple Software Renderer. It is not a Godot viewport or a
browser screenshot; it does not validate engine uniform color conversion,
skinning, complete lighting, moving derivative interpolation or device cost.

The authorized computer-use inventory still reports a locked Mac and
unavailable browser. Actual browser appearance, iPhone 14 GPU/thermal results
and reference visual parity remain unverified. Selected silhouette/material
polish and lighting balance from the earlier research remain later visual
work. No player save, reference application or resident world was changed.
No Git publication was requested or performed.
