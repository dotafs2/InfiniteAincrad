# City reveal eligibility: independent pre-fix source audit

2026-09-29. Read-only source inspection; no engine, browser, rendering, or runtime/test edits. The analyzed reveal controller has SHA-256 `add22f020b110425f6bb5002f4b58c324ba9a387c448b354f560ffa7f22ddd6a`; this report describes that pre-revision policy.

## Actual city classification

No current ordinary city prop was found misclassified as a building. All 48 `group=building` catalog assets are six variants each of row house, corner shop, brick apartment, office, warehouse, townhouse, hotel and civic hall. Their smallest axis dimensions are 4.325 m in X, 4.47 m in Y and 6.35 m in Z. The old 3 m height / 2.4 m maximum horizontal extent threshold therefore admits every authored city building.

`catalog_city.gd:339` copies the catalog group to the body's category; lines 340–341 map props to their specific kind and plants to `tree`. Source provenance is retained as `asset_id` and `catalog_group` at lines 380–381. At lines 388–391 all imported non-buildings receive the shared ordinary `StandardMaterial3D`. Only the building branch at lines 392–405 creates a per-building Palette shader material, combines its trim with its own geometry, and registers it in `building_visuals`. `static_batch.gd:11` explicitly excludes buildings while ordinary props retain their ordinary material in batches.

Thus this inspected source does not substantiate a claim that actual city signs, cars or trees are currently all connected to dither. This is a code-path finding, not a denial of the user's visual observation or a browser-build verification.

## Policy weaknesses and concrete negative cases

`hole_reveal.gd:73–76` trusts a generic `category == "building"` string and dimensions; it does not validate the preserved catalog provenance or an explicit reveal-only building identity. The alternative food branch trusts aggregate assembly metadata, a separate path needing food-map review. Also, taking the **maximum** horizontal dimension admits an arbitrarily thin but long object if it gets the broad building label. Those are concrete weaknesses in the predicate, not proof of an existing mislabeled catalog asset.

A size-only replacement would introduce five real city false positives: `159_palm_03`, `160_palm_04`, `164_birch_04`, `168_maple_04`, and `172_oak_04` meet the old numerical dimensions but are plants. Their catalog records begin at manifest lines 3325, 3346, 3430, 3514 and 3598. They currently remain ineligible through the `tree` category and retain ordinary materials.

Recommended policy: require an explicit legitimate building identity **and** a declared size threshold, then retain real mouth occlusion and intact-state gates. If the width limit means a substantial footprint, test both horizontal axes or an explicit area/depth condition; do not describe a maximum-axis limit as a minimum footprint width. A size threshold must never independently grant ordinary props eligibility.

## Material isolation and release

`hole_reveal.gd:81–103` registers only admitted bodies, and lines 109–117 write only that building's shader weights. `palette.gdshader:6,11` defaults the per-material weight to zero and requires a positive value before discarding any fragment. No all-object global enable replaces this material-level opt-in. Actual mouth silhouette plus triangle intersections at reveal lines 128 and 135 onward prevent empty arch/bounding-box interiors from qualifying by proximity alone.

Building decoration merged by `catalog_city.gd:400–401` deliberately shares its parent building's material and identity. It is not independently classified as a loose prop. For fractures, `swallowable.gd:28–30` resets the shared Palette weight, line 53 changes the category to `building_fragment`, and line 74 tags the piece as a fragment; the controller's intact-state gate rejects released or claimed buildings.

## Meaningful post-fix repro cases

1. Place an actual catalog building and each of the five tall plants at the same verified camera-to-mouth blocking location. Only the legitimate building may gain a weight; plants must retain their original material and remain unregistered.
2. Use an oversized ordinary sign, vehicle and actor, including one accidentally carrying a broad `building` category but with conflicting catalog provenance. A generic category or size alone must not admit them under the new explicit policy.
3. Test exactly below and at each declared dimension threshold, and a long thin 8×4×0.2 m object, distinguishing policy dimensions from the hole's radius and aperture size.
4. Confirm genuine qualifying buildings still reveal on an edge-only mesh hit; behind-player buildings, empty arch openings and mere expanded-aperture proximity remain opaque.
5. Confirm independent cached/fallback fracture pieces and ordinary batches stay opaque even beside a currently revealing building. Preserve pause, return-home, map-switch and inactive-player state clearing.

Raw catalog counts, dimensions and file hashes are in `artifacts/building-only-reveal-20260929/city-audit/static-catalog.json`. These suggestions are ready for non-author execution after the implementation freezes; they are not claimed executed here.
