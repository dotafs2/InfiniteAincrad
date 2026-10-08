# Timed collection update — v0.9.0

The release combines six cosmetic rarity tiers, transparent duplicate-free
draws, four-minute coin runs, larger connected maps and optional monetization
entry points. [Design and exact rules](design.md) distinguish the implemented
gameplay from future native SDK integration.

## Player-facing changes

- Common, Uncommon, Rare, Epic, Legendary and Prismatic use gray, green, blue,
  purple, orange and rainbow accents. Common skins use a single recolored ring;
  Core Shell, Tide and Cinder are Legendary. The 44 stable skin IDs remain.
- Base weights are 45%, 28%, 16%, 8%, 2.5% and 0.5%. Each collection excludes
  owned skins, normalizes eligible weights and shows actual next-draw odds.
  Five-, ten- and twenty-draw guarantees apply to remaining Epic+, Legendary+
  and Prismatic skins. Existing ownership, equipment and balances migrate.
- Each run lasts 240 seconds. Score and food objectives cannot finish it early.
  Being swallowed triggers a two-second respawn with score retained. A nonempty
  timed finish earns floor(score / 10) + 20 coins; quitting to home earns nothing.
- Sunny City and Snack Garden gain connected perimeter districts: playable
  area increases approximately 59.6%. Food content now includes 160 buildings
  and 2,922 initial edible bodies, with individual layers and collapse physics.
- Animal Kingdom, Star Voyage and Toy Factory appear as non-playable Coming
  Soon entries. Only the two implemented map IDs can be selected or saved.
- The results panel exposes optional 2× round coins; the Coin Shop exposes
  320-, 2,000- and 9,600-coin products. Missing native providers show unavailable
  or Coming Soon. No live ad, real purchase or invented price is shipped.

## Black-food correction already delivered separately

The urgent v0.8.7 hotfix was released before the broader changes. Packed instance
color lanes were initialized to white for both static food and settled rain;
zero color data had multiplied the existing ingredient colors to black. The
palette, shader finish and cached recipes were retained. The isolated hotfix
passed all 53 source and packaged suites (35,173 checks in each phase), and ten
served files matched the tested export. Software OpenGL probes independently
exercised the packed color path. See the
[hotfix report](../black-food-20260929/README.md) and its separate source snapshot.
The main v0.9.0 source includes that correction plus enlarged ground/rain bounds.

## Review and failed-gate recovery

| Area | Implementation and independent evidence |
| --- | --- |
| Rarity, real low-tier visuals and draw probabilities | [Visual design](../skin-rarity-20260929/visual-design.md), [independent review](../skin-rarity-20260929/independent-review.md) |
| Countdown, score-preserving respawn, migration and reward receipts | [Independent economy review](../retention-20260929/independent-review.md) |
| Rewarded-ad and native purchase contracts | [Bridge protocol](../monetization-20260929/bridges.md) |
| Actual UI navigation, odds, availability and touch targets | [Independent UI review](../retention-ui-20260929/review.md) |
| World extent, streets, density and geometry budget | [Author report](../world-expansion-20260929/README.md), [independent review](../world-expansion-20260929/independent-review.md) |
| Enlarged food contact, separate falls and reachable edge rain | [Independent physics review](../world-expansion-20260929/food-physics-review.md) |

The first main release gate rejected the new perimeter's sparse layout. The
unchanged density threshold remains 12% of each district's ground area. The
revised layout reaches 16.96%–28.26% while retaining the same body count, shared
recipes and triangle budget. The measured initial portrait-view geometry stays
unchanged; new perimeter views remain below the prior visible-geometry limit.
This is a geometry/culling result, not measured phone GPU performance.

A subsequent gate exposed old food-rain and impact tests' assumption that fixed
coordinates were empty ground. Real scene queries now establish their intended
clear-ground preconditions. The ten rain recipes retain the original mouth size
and fall windows, and each must produce one receipt after complete descent.
[Cross-review](../world-expansion-20260929/physics-fixture-maintenance.md) records
the 80-check snack and 256-check impact results. Failed runs remain in
`artifacts/collection-20260929/release-rejected-*`; neither replaced the preview.

The legacy collision fixtures also overlapped new perimeter food. Their clear
space and real terrain are now explicit physics preconditions. A six-piece
pile comparison found that both old and current runtimes could fail the old
single-frame solver-speed assertion. The reviewed measurement correction uses
the original three-second displacement, rotation and vertical-range bounds,
plus actual horizontal path speed across the same window. Native endpoint and
full 3D path speeds remain diagnostic. This is an intentional oracle correction,
not a claim that all prior assertions were unchanged or every body was motionless.
The [full comparison and exact maintenance](collision-fixture-maintenance.md)
retain the rejected total-path proposal, old boundary failures and raw traces.

## Final delivery

The complete gate passed **63 source suites and 63 isolated-package suites,
46,356 checks in each phase**, with no failures or unexpected engine errors.
All **741 tested input hashes** remained unchanged. The guarded switch replaced
the local preview with v0.9.0 only after both phases passed. Independent static
HTTP verification matched all **ten served files** at `127.0.0.1:8768` to the
tested export on September 29, 2026, local time.

- [Complete release manifest](../../artifacts/collection-20260929/release/release.json)
- [Input, engine-log and HTTP verification](../../artifacts/collection-20260929/verification.json)
- [Source full-duration runs](../../artifacts/collection-20260929/release/source-food_round.json)
- [Packaged full-duration runs](../../artifacts/collection-20260929/release/package-food_round.json)

Final PCK SHA-256:

```text
ecf42e7dfc5ff6c4534493555f8468dbff338bb3ea2477433f1783de19b00b22
```

Both final automated food runs complete at 240 seconds. The source samples earn
5,471 points with rivals and 8,204 points solo, with actual building, heap and
pedestrian receipts. These seeded automation samples establish timed completion;
they do not measure human progression speed or player retention. Owned helpers
have exited, and the existing preview server remains available.

## Limits

Headless scene tests and windowless software OpenGL probes do not establish
browser appearance, actual mobile audio or sustained iPhone 14 60 FPS. No
browser inspection was performed under the saved access restriction. Native
ad/payment SDKs, production configuration and store sandbox acceptance remain
unimplemented. Initial draw weights have not been validated by player retention
experiments. Tests use isolated progress and owned temporary files. User saves,
the existing preview server and unrelated resident worlds are preserved. No
Git commit or publication was requested.
