# Independent growth integration review

**Result: PASS, 1606 focused checks.** The reviewer authored the hole growth controller, but did not author the camera integration, food-hint integration, or `large_growth_world_acceptance.gd` under review. This review does not independently certify the reviewer's own growth formulas; a separate reviewer covers those.

## Scope and resolved finding

The reviewed integration changes are `game.gd:update_camera` and `game.gd:scan_food`, together with the existing ground union and the root agent's 250-check scene suite. The latter receipt covers both maps, real score awards through one billion points, center and boundary placements, enlarged physical openings, camera containment, and recovery after large overlapping mouths.

One source-level issue was reported to the implementation author before testing: an unreachable footprint produced `KEEP GROWING`, even though the physical radius has a safety limit. The author changed that fallback to `TOO LARGE`. Reachable objects still display their first fitting level. The focused review exercised the corrected behavior; no runtime file was edited by the reviewer.

## Additional independent coverage

The new `tests/growth_integration_review.gd` uses an actual `SubViewport` for each camera shape, so these checks cannot pass merely because the main window letterboxes a fixed portrait canvas. Seven viewport sizes cover actual aspect ratios from 0.375 to 2.164, including 270×480, 390×844, 375×812, 360×960, 540×960, 844×390 and 1920×1080.

There are 105 camera cases: three real awards, five easing deltas including zero and 0.001 seconds, and seven viewport sizes. Each case verifies 96 points around the enlarged mouth immediately after the first non-instant camera update, then during twelve further updates while the player moves. Both the camera frustum and projected pixel bounds must contain the circle. The far plane must include the current eased offset and radius. A zero-length initial offset also exercises the finite fallback direction. This extends the root suite, which predominantly uses instant camera updates.

Ground cleanup is tested with 1156 real collision rays across four successive states: eight, four, one and zero active mouths. Expected coverage comes from independent regular-polygon membership and union checks, rather than the ground triangulator. The fully covered arrangement removes every sampled top-surface point; retiring holes restores the ground, including the original center. Remaining collision vertices are finite and bounded. The check concerns open top-surface collision, not an assertion that every boundary-wall triangle must disappear.

The real `scan_food` path is exercised with controlled object fixtures around old and extended level boundaries, including immediately below and above radius 14, a level-13 radius boundary, radius 24.88, a near-limit reachable footprint, and unreachable footprints of 48 and 60. It verifies first-fitting level text, the corrected unreachable fallback, successful admission clearing an old hint, and suppression of hints for supported or distant objects.

## Evidence and limits

- Focused receipt: `artifacts/growth-rivals-20260928/integration-review/review.json`.
- Strict engine logs and source hashes: the same directory, including `manifest.json`.
- Root integration receipt: `artifacts/growth-rivals-20260928/large-growth.json`, 250 checks without failures; its logs contain no unexpected engine errors under the release filter.
- The tested game source matches the author's announced frozen SHA-256 `b4aaaff3146f320cef2fedeaa262d71a51625635bda45894fb8121c8c6dfb68c`.

The focused helper exited normally and retained no process. All execution used headless Godot with `--test`; the probe did not write player progress. These are camera, controller-integration and physical-collision checks. They do not establish actual browser rendering, HUD readability on every device, phone GPU performance, or sustained 60 FPS. No browser was opened.
