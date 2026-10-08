# Independent city buildings-only reveal review

2026-09-29: **PASS, 176 checks**, with zero unexpected engine errors. The reviewer authored only `tests/building_only_reveal_review.gd` and these review artifacts/documents, not the runtime implementation. All owned helpers exited. Before/after source hashes are identical.

The test's completion marker is `BUILDING_ONLY_REVEAL_REVIEW`, with minimum 176. Evidence is under `artifacts/building-only-reveal-20260929/city-review/`: `independent.json`, `independent.log`, and `provenance.json`. Its stdout-only reporting and embedded setup require no external artifact files, so the same test can run against an isolated exported package.

## Actual city and materials

All 48 real catalog buildings carry both their catalog provenance and explicit `dither_building` opt-in and are registered. None of the other 608 actual city physics owners has eligibility, registration, or a nonzero dither material. The controller initially has exactly 48 entries.

Five real tall plant assets meet the old numeric dimensions but remain opaque: `159_palm_03`, `160_palm_04`, `164_birch_04`, `168_maple_04`, and `172_oak_04`. Fresh instances of these actual meshes, a sign, a vehicle and a person are enlarged to exceed the dimensions and still retain ordinary StandardMaterial rendering without registration. An oversized real recipe actor is also excluded. Calling registration again admits no oversized prop and duplicates no building.

The prior read-only inventory found no current city tree/car/sign mislabeled as a building; that result is retained in `city-source-audit.md`. The corrected policy closes a semantic weakness rather than proving all ordinary city props previously dithered. The food-map opt-in path was broader, and now food is excluded explicitly.

## Strict individual-size rule

The review checks both defaults (3.0 m height and 2.4 m **maximum** horizontal extent), the exact boundary, just-below cases, independent configurable thresholds, uniform/inherited/reflected scale, and rotation. A thin but explicitly authored building component is allowed by the chosen maximum-extent rule; this is not misrepresented as a minimum width on both horizontal axes.

A generic building category without opt-in cannot reveal. A 20 m tree, sign, vehicle, person, authored actor or fragment remains excluded even with that opt-in. Food-kind, food-building and fragment markers override a spoofed building identity; even an empty food-kind marker is excluded. A thin individual body cannot borrow a large `structure_height`, `structure_width`, or stale `height` field.

A real oversized cake body was additionally given a spoofed building category and opt-in: it stays unregistered, its reveal setter remains zero, and its actual food shader has no discard or reveal-mask path. The independent food review separately covers the full food population and shader output.

## Actual obstruction and lifecycle

An actual row-house mesh placed between the real camera and hole gains a material weight above 0.99 after real triangle-based obstruction selection. Its pose, mass, collision masks, velocity and original tint remain unchanged. Moving that same house laterally or behind the player returns it to full opacity.

Pause preserves its existing reveal backdrop. Release or claim immediately clears the material weight; inactive-player state clears both material and aperture. A real cached fracture produces 16 separately checked opaque pieces, even after deliberately adding the opt-in to each piece. Returning home then leaves the original game process naturally enabled, frees the player, and produces no stale-reference diagnostics.

## Existing 75-check suite review

The revised `selective_reveal_acceptance.gd` explicitly opts its synthetic building fixtures into the newly declared authoring policy. Its former food-floor positive case is correctly replaced by a negative case: the user's current rule excludes food entirely, so a thin cake tier cannot qualify through its parent stack's dimensions. The existing 16 controlled geometry cases and independent ray/slab oracle, 30/60/120 Hz consistency checks, actual shader-weight hookup, color/physics preservation, physical-release opacity and lifecycle assertions remain present. Root's strict 75-check author rerun passes. The reconstructed prior source independently hashes to `5450b115c7b9add252b9c0764af9be4718545307e75998e0daa0c33faa4645c6`, matching the retained v0.8.4 manifest. Exact text comparison confirms only three changes: the fixture opt-in, the food-floor expectation, and its adjacent comment. All other source text, including every geometry/oracle/controller assertion, is byte-identical. Current source SHA-256 is `3324d12355dd3510bbfbc2d9bc80fa55f59373d98cc5a8abe37d151102f50bcb`. The exact diff and comparison record are retained as `city-review/prior75.diff` and `city-review/prior75-diff-review.json`.

## Frozen hashes and limitations

| File | SHA-256 |
|---|---|
| `fidelity/hole_reveal.gd` | `bb763aaae92eed8430e2a76ac878108dd18220175ddb619e856a1136b4005c6d` |
| `fidelity/catalog_city.gd` | `d30c376a5a4ab69baf8b2dd834e9a0f2b3eee7e22161f0124aa1c9cfed5b5eea` |
| `fidelity/food_body.gd` | `acc24c145f8eae9f312c481af8fec9ff482fcf5f34159e56b45d403acc9fd22c` |
| `fidelity/food_glaze.gdshader` | `54a890cdf065e4613a203e7fc9834d4440dd73d27ab6a47e3179aa27f721e2cc` |
| Independent suite | `5d02fa24db37d93ce98fe04219b562f8e2298734e891ddf1f85a1aed8f3142ef` |

This is actual source/scene/material-state evidence and identified synthetic boundary testing. No browser, screenshot, rendered appearance, device frame rate, or phone GPU claim is made. The browser-access restriction was preserved; no alternative UI path was attempted.
