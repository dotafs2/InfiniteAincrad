# Independent food collision review

Final status (2026-09-28): **PASS, 16,168 checks**, with zero unexpected engine diagnostics. The reviewer did not author or modify the runtime collision/support changes. All owned helper and Godot processes exited. Runtime and test hashes remained unchanged through the final run.

| File | SHA-256 |
|---|---|
| `fidelity/food_city.gd` | `4d9523a275990adbbbaa8cd2f2efccfebe747bda119003276a89b06af4a1e84b` |
| `fidelity/food_body.gd` | `32ecd84b84f782d522b6de58286409b4f81e4a5e7dab7a3772dab47712edc029` |
| `tests/food_collision_review.gd` | `953be2fdf70baf4f1b335b9d953e105fbbef78f6bcce151321d5223606b6a82d` |

Final evidence: `artifacts/food-collision-20260929/independent-source.{json,log}` and `independent-provenance.json`. The existing evidence directory name is retained; it does not imply a later execution date. Gate marker: `FOOD_COLLISION_REVIEW`; minimum: `16168`.

## Geometry and actual material hookup

The complete initial food inventory plus fresh kind/tower/flavor variants exercises 1,984 round and 616 rectangular bodies, including 287 round and 401 rectangular structural pieces. Checks cover original extents and admission footprints, shared shape identity, 467 distinct round dimensions, finite hull coordinates, complete caps within the SAT 16-point support budget, and maximum measured radial inset of 1.921481%. There are no native cylinder colliders remaining in the actual food scene. Each round body receives the same convex hull coordinates used by its physical collider for terrain support; rectangular ingredients retain their prior contact path.

## Physical regression results

- All ten differently tilted rain ingredients actually descend, land, sleep, enter settled batches, and subsequently fall through real openings. Each original target instance ID produces exactly one complete-fall collection receipt.
- A six-piece, initially separated, tilted cookie/burger pile remains supported after upper-body impacts. Its envelopes are constructed from actual rotated collider points, with a 0.16 m initial gap rather than intersecting shapes.
- Opening the actual collision ground under that pile releases all six pieces independently. None is frozen, all six original IDs collect exactly once, and every receipt is delayed until the whole piece is below -3.5 m.
- Moving the hole away after an ordinary cookie has fully entered does not pull the piece back onto restored ground. It continues its legitimate fall and collects once.
- A thin pizza initially bridges the rim: a real terrain ray misses below its center and hits below its outer edge. It remains free to tip, and moving the mouth to cover it produces actual downward motion and one complete-fall receipt. The new support guard does not hold it across an open mouth.

These are actual headless physics checks using the real game scene and cut-ground collider. They do not certify a rendered image, browser behavior, iPhone performance, or complete physical stillness.

## Appearance resource baseline

A read-only external script loaded the preserved prior v0.8.2 exported package with no project path or render capture. Its 41 generated food mesh resources were fingerprinted over all surface arrays, including vertices, indices, normals and colors. The shared ingredient shader source was fingerprinted separately. All current fingerprints match the prior package byte for byte.

- Prior package SHA-256: `0f706b9a4f0825b5fd3bfe643893905b01af1aefc86b92a1f8d4907eeb1da3ed`.
- Prior and current shader SHA-256: `75d79551d9715bf8796490fcb5bfe63cb508622074bcc12b57fc7491893526b2`.
- Baseline evidence: `artifacts/food-collision-20260929/visual-baseline.json` and `baseline-package.log`.
- Expected hashes are embedded directly in the gate suite. It has no dependency on `res://artifacts`, a working directory, or continued availability of the old package, and prints its report to stdout for source and isolated-PCK execution.

## Failed reviews retained and corrected

The original fixture accidentally overlapped tilted ingredients because it used fixed tier spacing. That failed test and its exact script remain as `independent-overlap-fixture.*` and `review-overlap-fixture.gd`. Correcting the starting geometry did not eliminate the bottom cookie's ground penetration; the corrected failure remains as `independent-separated-pile.*` and `review-separated-pile.gd`.

A separate controlled comparison reproduced that existing penetration in both source and the prior v0.8.2 cylinder package. After nine seconds, the bottom stacked cookie reached y=-334.14 in the first prism implementation and y=-322.05 in the old cylinder version; isolated cookies stayed supported. Both traces had zero unexpected engine diagnostics. The reviewer escalated the real defect, the parent authorized its correction, and the food author added the bounded terrain support guard. The independent suite retained its failing ground-support assertions until that fix passed. Exact initial geometry and 30-frame traces are in `contact_probe.gd` and `{current,old-package}-contact.json` under the evidence directory.

One later review rejected three cookies on an added instantaneous angular-speed threshold of 0.5 rad/s, despite intact ground support. The retained `independent-instantaneous-angular.*` and `stability-window.*` evidence shows why that proxy was replaced: over the final three seconds, the actual maximum orientation change from the window's starting pose is 3.168 degrees, maximum center displacement is 0.1534 m, and maximum vertical range is 0.0411 m. A solver can alternate small positive/negative angular velocities without continuous visible rotation. The final test preserves the original linear-speed limit below 0.3 m/s and checks the actual window: orientation change below 5 degrees, displacement below 0.2 m, and vertical range below 0.05 m. These bounds allow limited contact slop and settling; they do not claim motionless piles. No native engine error was suppressed or added to an allowlist.
