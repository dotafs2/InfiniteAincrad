# Independent food-opacity and building-reveal review

Status: **PASS — 434 source scene assertions, 6 old-package observations, 6 matching new-source observations, and 45 isolated shader cases**. Runtime implementation belongs to the root agent. This reviewer changed the independent suite and isolated shader harness, not runtime files. Source/package release acceptance is a separate gate.

## Confirmed cause and policy correction

Ordinary street snacks, the twelve large heaps, three starter heaps, sushi traffic and rain already defaulted to nonstructural. The overbroad path was food assembled by `build_tower()` or the landmark builder: each main piece received `food_building` and `structural_shell`, then borrowed the assembled structure's height and width. Visually ordinary burgers, donuts, cake tiers or small architectural food pieces could therefore receive reveal despite their own small dimensions.

The new policy explicitly excludes **all food**, including apartment-like stacks, shops and landmarks. Only city objects with the `building` category, an explicit `dither_building` opt-in, and sufficient dimensions of their own may enter the reveal controller. The runtime additionally rejects food/fragment metadata and uses the body's actual scaled dimensions. Food's legacy aggregate metadata remains available for gameplay but no longer grants reveal eligibility.

Food was not using alpha blending: `COLOR.a` stores ingredient roughness. The unwanted disappearance came from the food shader's Bayer `discard` branch. The new food shader removes that branch, its reveal include and its weight varying entirely. Compatibility uniforms remain accepted but unused. Static food batches disable the old instance flag, and the deprecated body setter clamps reveal state to zero. Ingredient albedo, roughness and reflection calculations remain in the shader.

## Same-object before/after reproduction

The artifact-local `policy_baseline.gd` was run against the preserved v0.8.4 package from an isolated temporary working directory, then unchanged against current source. Both runs used `--headless --fixed-fps 60 --test` and strict log validation. They positioned the camera over a real horizontal mesh face and independently confirmed a triangle intersection along the camera-to-mouth segment; this did not rely solely on a collider or bounding box.

| Actual food tier | Own height | Old aggregate height | Old candidate / weight | New candidate / weight |
| --- | ---: | ---: | --- | --- |
| Burger apartment base at `(-17.91, 28.48)` | 1.922 | 9.915 | true / 1.0 | false / 0.0 |
| Donut apartment tier at `(-25.01, 15.79)` | 0.877 | 6.597 | true / 1.0 | false / 0.0 |

Both actual meshes block the controlled ray in both versions. Each run passes six assertions for its explicitly selected old/new expectation. This establishes a runtime behavior change, rather than only renaming or reclassifying a test expectation.

The old package remained byte-identical, SHA-256 `d68b368fa1f77bd4b5a12771673a64c0855bd41b01412c76b9627f67a84cb20d`. Evidence: [`food-review/old-package.json`](../../artifacts/building-only-reveal-20260929/food-review/old-package.json), [`new-source.json`](../../artifacts/building-only-reveal-20260929/food-review/new-source.json), the matching strict logs, helper script, and `baseline-provenance.json` in the same directory.

## Independent scene acceptance

The existing `tests/selective_reveal_review.gd` now passes **434 assertions**, marker `SELECTIVE_REVEAL_REVIEW`.

The former positive food-reveal expectations were deliberately replaced with the user's new all-food-opaque policy. Their hollow-center, solid-dough, real-batch ownership, compaction, release and support-loss fixtures remain exercised. Unrelated true-building positives, actual camera-to-mouth mesh tests, side-building negatives, claimed/released/consumed transitions, cached and fallback sixteen-piece fracture checks, and freed-parent lifecycle checks remain in the suite. A before-copy of the original review is retained in the evidence directory.

The actual-map oracle no longer uses `is_structural_candidate()` to decide which objects should be protected. It independently expects every food-map object to be opaque and applies the explicit city-building identity and own-size rule to actual city bodies, then compares production behavior with that expectation.

- Sunny City retains **48 eligible buildings** while **608 independently excluded objects** remain opaque.
- Snack Garden has **2,588 protected scene objects** and **zero registered reveal occluders**. All 136 food towers are checked tier-by-tier within each tower assertion; representative real geometry from all six families is positioned on a confirmed blocking ray and remains opaque.
- Every one of the ten real food recipes is tested at enlarged scale, with old aggregate dimensions set to 99, legacy structural tags, and even a forged `dither_building` flag. None enters the controller.
- Positive legacy setter calls are rejected. Directly injected stale CPU weight, positive material uniforms, and `(1,1,1,1)` instance data do not produce an effective food reveal path. This includes independently exposed pieces and a three-member batch after compact removal.
- Airborne, settled/batched and released rain remains opaque for all ten recipes. Small crowns and all ordinary scene props remain protected.
- The true-building hollow arch retains its independent 65-ray clear-opening negative and solid-pillar positive. The real donut similarly retains a clear center and confirmed solid-dough obstruction, but both states remain opaque under the new policy.

Evidence: [`food-review/source.json`](../../artifacts/building-only-reveal-20260929/food-review/source.json), strict logs, `source-before.json`, `source-after.json`, and `final-provenance.json`.

## Isolated shader execution

`tools/validate_mobile_visual_shaders.py` compiled ten programs and passed **45 cases** in its existing windowless CGL harness. Existing building, camera aperture, shadow-pass and adapter-albedo cases were retained. Food's former structural-cut case now expects solid coverage, and four explicit stale-state cases were added.

All **nine food cases preserve 4,096 of 4,096 pixels**, including positive standalone uniforms, instance mode with every custom channel set to one, a very large aperture, released tiers, and low ingredient roughness in vertex alpha. Real building shader cases still produce the expected cut coverage. The harness executes translated shipped vertex and fragment equations at controlled sample positions; it does not render a game scene or prove native Godot MultiMesh upload behavior.

The wrapper writes fixed opaque output, so these coverage cases measure discarded pixels rather than alpha blending. The food shader's absence of any `ALPHA` output provides the separate opacity constraint. Final delivery verification enforces that constraint directly on the comment-stripped, hash-matched source, along with the absence of includes and discard instructions; it also checks the complete input/program/scenario inventory.

Fresh receipt: [`shaders/result.json`](../../artifacts/building-only-reveal-20260929/shaders/result.json). The fixture, generated shaders, compiler/probe logs and exact input hashes are retained beside it. No reference-game images, UI capture or browser were involved.

## Final source provenance and limits

The scene review's before/after hashes are identical. `final-provenance.json` binds those inputs, the scene receipt and the fresh shader receipt.

| File | SHA-256 |
| --- | --- |
| `fidelity/hole_reveal.gd` | `bb763aaae92eed8430e2a76ac878108dd18220175ddb619e856a1136b4005c6d` |
| `fidelity/catalog_city.gd` | `d30c376a5a4ab69baf8b2dd834e9a0f2b3eee7e22161f0124aa1c9cfed5b5eea` |
| `fidelity/food_city.gd` | `0d9303ec16ef78b9cc46bd339d6e8a7b8a1ebb33beab5bf10951a0b8a9223967` |
| `fidelity/food_body.gd` | `acc24c145f8eae9f312c481af8fec9ff482fcf5f34159e56b45d403acc9fd22c` |
| `fidelity/food_glaze.gdshader` | `54a890cdf065e4613a203e7fc9834d4440dd73d27ab6a47e3179aa27f721e2cc` |
| `tests/selective_reveal_review.gd` | `5cca07142cf0f525dcebd29c87dd1d725e7a54ed88f2527b32fab467c92ee3e7` |
| `tools/validate_mobile_visual_shaders.py` | `15f72a06181ee4d2a39bd272b24cad08b331a42dcd1983549eafea95931deea4` |

The headless dummy renderer does not retain native MultiMesh data for reliable getter-based verification. The scene checks therefore cover authoritative control state, ownership and the material graph, while the separate shader probe executes the shader equations. Neither result certifies actual browser appearance, normal gameplay visual quality, iPhone GPU speed or sustained frame rate. The saved browser permission restriction was respected; no alternate capture path was used.

All reviewer-owned Godot, compiler and CGL processes exited and were waited on. No player save, running preview server or gameplay recipe was modified by this review. Runtime, tests and harness were frozen before the parent began the full release gate.
