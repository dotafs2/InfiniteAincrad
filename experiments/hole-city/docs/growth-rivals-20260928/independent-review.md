# Independent growth, rival and pedestrian review — 2026-09-28

Status: **PASS**. The non-author integration suite passes **291 checks**; the separate actual pedestrian suite passes **120 checks** on the same final game/hole inputs. No additional runtime defect was found.

## Evidence and independence

- `tests/growth_rivals_review.gd`, marker `GROWTH_RIVALS_REVIEW`, minimum 291. Report/log: `artifacts/growth-rivals-20260928/growth-rivals-review.{json,log}`.
- `tests/pedestrian_swallow_review.gd`, marker `PEDESTRIAN_SWALLOW_REVIEW`, minimum 120. Report/log: `artifacts/growth-rivals-20260928/pedestrian-swallow-review.{json,log}`.
- Runtime and suite hashes plus engine identity: `artifacts/growth-rivals-20260928/independent-review-manifest.json`. Before/after records prove the four tracked review inputs did not change during the integration run. The pedestrian report independently hashes nine relevant runtime files before and after.
- Both runs use actual Godot 4.7.2 with `--headless --fixed-fps 60 --test` and the release gate strict diagnostic parser. Only the known exact macOS certificate diagnostic is excluded. The first reviewer-script attempt had a missing explicit Boolean type; that fixture parse error was corrected before the passing run. No runtime edit was made by this reviewer.

## Growth and combat findings

The original twelve thresholds remain unchanged. A separately accumulated increasing-cost recurrence checks eighty post-table levels and the threshold immediately below each. Signed-64-bit score extremes remain finite and correctly enclosed. Actual award calls preserve seventy-percent AI credit across small mixed receipts; negative awards cannot reduce score and repeated extreme player awards cannot overflow. A non-instant camera update immediately after a large award retains the complete mouth, complementing the author-independent world suite’s instant framing cases.

Combat uses three explicit ratios, complete smaller-circle containment, active-body guards and a largest-first snapshot. The player can attack during spawn protection; protection only blocks attacks against the player. Independent fixtures check both sides of thresholds, overlap that is insufficient, reachable complete containment, between-frame contacts, large teleport rejection, and prevention of replaying a protected crossing after expiry. Retirement occurs before reward, so repeat scans do not duplicate a victim or settle a result twice.

Claim, pull, fallback fall credit and delayed food support-release ownership follow an AI retirement and then a second retirement into the player. The normal body completion method is idempotent. A delayed callback naming the original retired owner resolves to the living player, and any callback after results cannot mutate score. This is controlled ownership testing; it does not pretend the fixture’s explicit completion call proves a physical fall.

Both real maps also use the actual player movement controller to approach a rival from three metres away. The player moves 2.698 metres before the first successful capture (fixed-frame indices 22 in City and 21 in Food). Other scene activity is isolated for deterministic boundary review. The combat author’s separate actual enabled-AI 30/60/120 Hz chase tests were read for coverage and are retained as complementary evidence; they were not represented as runs by this reviewer.

## Pedestrian interpretation of NPC

Ten actual scene cases cover City police/thief and Food chef/delivery, starter radius 0.85, larger radius 1.65, and one actual player pursuit per map. Residents first walk under their normal route and imported animation, then normal query/update logic claims them, ground support opens, real gravity moves them downward, the entire body crosses y=-3.5, and exactly one player-owned collection receipt removes the resident. Food rain remains enabled. Other holes are inactive only to isolate attribution. Underfoot cases finish in 47–48 fixed simulation frames; pursuit cases finish in 81–83. No walking-resident runtime fix is justified by these samples. “NPC” may instead refer to rival holes, whose combat path is separate.

## Non-author review of the 250-check world fixture

`tests/large_growth_world_acceptance.gd` and the root-owned `large-growth.json` receipt were inspected. They test both complete maps, real player awards at five scores, three world positions per score, actual ground collider ray queries, bounded geometry, portrait framing, two additional phone viewport shapes, and far clipping. The eight near-limit hole union uses intentional stress-fixture radii, samples nine covered slab positions, then verifies restored solid ground after holes close. This scope is valid as a terrain/camera integration test. It does not demonstrate normal score attainability, organic match pacing, browser pixels or GPU frame rate. Root reported and stored 250 strict passing checks; this reviewer inspected that receipt and test but did not count it as a separately rerun suite.

## Limits

The runtime is still a finite map: levels continue beyond twelve while physical radius approaches the documented 48-metre safety limit. The implementation must not be advertised as literally infinite physical size. Direct boundary fixtures, synthetic high scores, and isolated ownership checks are not a normal full-round balance playtest. Visual/browser acceptance remains unavailable through the current saved browser permission; no alternate access was attempted. iPhone GPU, thermals and sustained 60 FPS remain unverified. No player save, browser, user server or Git publication was changed. Owned helpers have completed.

## Reviewed hashes

- `fidelity/game.gd`: `b4aaaff3146f320cef2fedeaa262d71a51625635bda45894fb8121c8c6dfb68c`
- `fidelity/hole.gd`: `6633da90a596026bcadd87e404235e16c0f6f9d6bb7527f56d92a2965403f117`
- `tests/growth_rivals_review.gd`: `3238a53b8d25520b93c633f9650e22c3489babea8a931263190c2ca281fa256f`
- `tests/pedestrian_swallow_review.gd`: `5f16c2f364f8aec3ac008039ffa343b96c2369be49a5de4e337b74ba6e9def95`
- `tests/large_growth_world_acceptance.gd`: `a906b421974e1ce62c2f9e68df0106fb9ddd4d7b685c0f5a40c1db443d0fcd4f`
- `tests/rival_combat_acceptance.gd`: `18e6630cd56d15689cf50c489518ec58458db344fe28337e3f023492dc2706e4`
- `tests/growth_extension_acceptance.gd`: `8722523a5008ffef4ca8912bd77e91cc0b73c147966a9db0c7e01982a7585574`
