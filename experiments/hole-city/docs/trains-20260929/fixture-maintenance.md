# Independent review of pre-train fixture maintenance

Status: **PASS — 284 world checks, 631 perimeter checks and 15 bounded negative-fixture checks**. The independent runs used the strict release runner, `--test`, absolute engine logs and unchanged source inputs. All owned helpers exited. This review made no runtime or permanent test edits.

## Why these two expectations changed

The world review previously required every body's decomposed scale to equal `Vector3.ONE` bit for bit. The separate retained diagnostic in `artifacts/trains-20260929/scale-review/result.json` identifies four initial sushi cars whose oblique Y rotations produce X/Z column lengths of `0.999999940395355`. Their basis columns remain orthogonal; train distance is zero, the map basis is identity, and the other 2,926 food-map bodies have exact unit scale. This is a float32 rotation-decomposition discrepancy, not evidence of map or food rescaling.

The updated predicate still visits **every valid edible body, including every train car**, and rejects Euclidean scale error above `1e-6`. The map root still requires exact `Vector3.ONE`. The fresh independent run measured maximum error `8.42936955791629e-8` in Snack Garden and zero in Sunny Blocks. All eight transformed corners of every body still undergo the original terrain-bounds check; this loop was not filtered or changed. The existing world collision-ray, opened-hole, restored-terrain and real-player movement checks are unchanged.

The perimeter review was written for the pre-train inventory of 2,922 edible bodies. It now requires **exactly 2,922 non-train bodies plus exactly eight sushi cars, total 2,930**. The original shared food-mesh cache limit remains 40; actual count is 34. This explicit additional train budget does not remove a body from the world-bounds test or the independent train collision/model/collection review. The perimeter suite's existing building/loose-food geometry, support, street clearance, non-overlap, starter-size admission and height checks are unchanged; its scope was and remains the enlarged authored food perimeter, not all train motion.

## Exact diff and negative cases

The parent reconstructed the before files by reversing only these patches. The reviewer independently hashed both reconstructed files and matched them against the already retained v0.9.0 release input manifest at `artifacts/collection-20260929/release/release.json`. They are authenticated reconstructions, not claimed to be contemporaneous backups.

- World: all 29 static `check(...)` statements remain byte-identical. The collection of bodies failing the scale predicate now has a numerical tolerance, and its maximum error is recorded. The full runtime count remains 284.
- Perimeter: 13 of 14 original static checks remain byte-identical. The one old total-inventory check becomes the two explicit original-plus-train budget checks above. The runtime count rises from 630 to 631.

The artifact-only `counterexamples.gd` copies the actual maintained predicates programmatically. It accepts exact unit scale and the observed one-ULP decomposition, but rejects `1.00001` on each individual axis and `0.99999` on X. It also rejects even a one-ULP non-unit **map-root** scale, an extra or missing ordinary object, an extra or missing train, and food mesh-cache size 41. All 15 assertions passed. These are predicate sensitivity checks, not another physics scene or GPU measurement.

## Evidence and cutoff

Evidence directory: `artifacts/trains-20260929/fixture-maintenance/`.

- `before/` and its provenance record the authenticated reconstructed inputs.
- `*.gd.diff` and `exact-diff-review.json` retain the complete diffs and assertion comparison.
- `world_expansion_review.{json,log}`: strict 284, both maps, no failures.
- `perimeter_frontage.{json,log}`: strict 631; 2,930 bodies, eight trains, 34 cached food meshes, maximum new-building top 15.669542 m.
- `counterexamples.{gd,json,log}`: strict 15, no failures.
- `inputs-before.json`, `inputs-after.json`, `provenance.json`: all 775 guarded inputs identical before and after the two scene runs; the separate counterexample run also left inputs unchanged.

| Reviewed file | SHA-256 |
| --- | --- |
| `tests/world_expansion_review.gd` | `f449bf38c1188f130f0024914d7f9b2ea85a6caa2782f51af7ece6c3a11931c2` |
| `tests/perimeter_frontage_acceptance.gd` | `3a026a98f1a80a8c26ba7d3599f1f4218dbe84addd90218f7c507f9054f61445` |
| `fidelity/edible_train.gd` | `2886758208c9eb7fb5e0d89d448c561bd404f182f4c8e516d0ef706a7a014d3f` |
| `tests/train_review.gd` | `fb8e8b03e2824d9bba500f0d6e2b62114b1086503ab72f24bf13294c95180779` |
| `tools/release_web.py` | `2b6b9d6d3e764d6b1604d1776d10885c986ee8510fc12d25d14597dd6bd96d04` |

The separate [388-check train and unchanged 58-check rival review](independent-review.md) remains the functional lifecycle/cut/return evidence at this unchanged controller hash. It was not needlessly rerun for two unrelated fixture expectations. Parent-owned complete source/PCK acceptance and delivery occur after this cutoff and are not claimed by this report.
