# Independent food growth and geometry review — 2026-09-30

**PASS: 1,476 checks**, using `tests/food_growth_review.gd` against the actual scene. The reviewer changed no product code. The test is self-contained in exported PCKs: it reads actual shipped resources and writes its completion record to stdout, with no `res://artifacts` or source-code-reflection dependency.

## Real physical progression

The total remains 2,930 edible bodies, including the eight-car train; 1,080 are planned loose snacks. All 160 towers, 17 heaps, 34 cached food meshes, eight original sushi vehicles and the train remain. Exactly 182 existing loose foods move into intermediate physical size classes: each of seven inner districts now contains fourteen LVL2, eight LVL3 and four LVL4 targets. Actual smaller mouths reject each object and the appropriate next mouth accepts it. Real collider dimensions agree with the scaled rendered geometry, and per-mesh vertex envelopes leave the authored roads and pedestrian routes clear. The original 1/2-point snack rewards are retained.

Exactly three original 59-piece heaps replace their center-bottom piece with a 3.4m-radius cookie. Each cookie's ten points cannot skip two level thresholds; all 58 upper pieces remain separate rigid bodies with their own colliders and acyclic support/contact relationships. The support root is one real cookie, not one merged collectible for the entire heap.

The independent route uses genuine viewport touch/drag events, with camera-space steering converted from a chosen world target. It does not directly award score, resize the mouth, reposition the player or call `finish_swallow`. Rivals are retired and rain is disabled so target progression is reproducible; ordinary game collection and player physics remain active. Starting at zero score and the original spawn, it reaches LVL6 at 30.72 simulated seconds, then walks through three cookie heaps in order 6 → 2 → 4. All **177 pieces produce one individual receipt each**, after their complete physical descent below y=−3.5. There are 331 total real receipts along the route, reaching 820 points / LVL10 after 47.62 simulated seconds and 194.74m of movement. The train continues to travel. Each changed snack and cookie advances at most one level per receipt; a many-piece cascade can legitimately produce several levels.

The first 1,473-check version passed its single-heap physics assertions but failed strict cleanup because its last touch release deferred the initial audio unlock until after the fixture tried to stop audio. That original evidence is retained. The final fixture drains the release event, then stops and drains the decoder before teardown, and continues the route through all three heaps. No audio runtime change or log exemption was introduced.

## Explicit opening geometry budget maintenance

The independent comparison loads the actual preserved **v0.10.0 PCK** and the final source separately, with a real 390×844 camera and actual batch AABBs. The PCK SHA is `f62eecd2a3f5deb45afca81b948086a5c853048fd40b08e057e35df9b45f364f`. All arrays of the 34 shared meshes have identical fingerprints. Body count is unchanged; total triangles fall from **4,961,996 to 4,961,612** because the three substituted base meshes use 384 fewer triangles. Batch cells remain 24m; no culling algorithm or per-mesh quality change is made.

| Opening radius | Previous submitted triangles / batches | Revised submitted triangles / batches | Individually visible triangles before → after |
| --- | ---: | ---: | ---: |
| 0.85 | 721,252 / 67 | 744,252 / 69 | 211,252 → 215,064 |
| 7.2 | 1,144,048 / 119 | 1,149,552 / 124 | 656,936 → 660,260 |

The revised content raises conservative static submission by 3.19% and 0.48%, respectively. The smaller opening sees 129 individual bodies instead of 123; the larger view sees 369 in both versions. The contributor table in `geometry-comparison.json` records every changed visible batch and separates actual individually visible geometry from batch overdraw. This supports bounded content-budget maintenance rather than an unrelated batching rewrite.

Only these two fixed opening caps change in `food_finish_acceptance.gd`. The original 4.5M original-content cap, 650k extension cap, 5M entire-scene cap, all eight outer-view caps, material checks and mesh-quality checks remain unchanged. Four negative assertions require rejection of even one additional triangle or one additional batch beyond either revised cap. The suite strictly passes **136** checks, formerly 132. The exact old file and maintenance diff are retained alongside the comparison. Root explicitly approved these measured constants; they are not percentage tolerances.

## Scope and evidence

These are headless geometry and real-physics assertions. Simulated route time is not human play time. Mathematical visible geometry bounds are not measured draw calls, GPU duration or proof of 60 FPS on iPhone 14. No browser or foreground capture was attempted.

Evidence: `artifacts/feel-20260930/food-review/summary.json`, `geometry-comparison.json`, `food_growth_review-final.{json,log}`, `acceptance-final-provenance.json`, `food_finish-first.{json,log}`, and `food_finish-maintenance.diff`. All owned helpers exited.

## Frozen hashes

- `fidelity/food_city.gd`: `1a4b33a2b4890411fef3304a29e46a3c4b6d1ca38a1e2f81be1f47f2ee430755`
- `fidelity/food_body.gd`: `acc24c145f8eae9f312c481af8fec9ff482fcf5f34159e56b45d403acc9fd22c`
- `assets/food_city/neighborhoods.json`: `8c0a6329f65b237279dadaefd047c3c7aca375a3a19f4e2f6fc8d478a27ea784`
- `tools/build_food_neighborhoods.py`: `217e2087da9ec5ad6cd5aab98e9e84f8fbccf585e23cb90ca783d8945308e90d`
- `tests/food_growth_review.gd`: `a12c757e09714eac0240f09b51581cbb6cadda87e488156cbf0fda5cae31bc43`
- `tests/food_finish_acceptance.gd`: `b87588fdeeaa8b7bbf217dfbd6f6ee95465007f5cb7ee932373135628e1998e8`
