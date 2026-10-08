# Independent review of the ingredient-finish regression assertion

Date: 2026-09-29. Reviewer: `expand_skin_catalog`, independent of the assertion correction author (`root`). Result: **PASS**.

This review covers only the correction to `tests/food_collision_review.gd` after v0.8.5 intentionally removed food dither. The former whole-shader hash required the obsolete dither policy as well as the ingredient finish. The replacement preserves a fixed prior-release baseline for the ingredient finish while excluding six exact legacy reveal statements. No runtime files, test inputs, or release configuration were changed by the reviewer.

## Provenance

The reconstructed prior shader was checked against the shader SHA in the preserved v0.8.4 release manifest, rather than trusting the newly generated expected value alone.

| Evidence | SHA-256 |
| --- | --- |
| Prior food shader, verified against v0.8.4 | `75d79551d9715bf8796490fcb5bfe63cb508622074bcc12b57fc7491893526b2` |
| Current food shader | `54a890cdf065e4613a203e7fc9834d4440dd73d27ab6a47e3179aa27f721e2cc` |
| Normalized prior and current ingredient finish | `b5067e4791261ecf18471418955af77d2b38ab4fa39e468e0d2ed75e19a64a4a` |

Preserved inputs and receipts:

- [Prior release manifest](../../artifacts/map-preview-20260929/release/release.json), specifically `source_sha256["fidelity/food_glaze.gdshader"]`.
- [Prior shader](../../artifacts/building-only-reveal-20260929/author/prior-food-glaze.gdshader).
- [Prior collision test](../../artifacts/building-only-reveal-20260929/author/prior-food-collision-review.gd), also checked against the reviewer's independently captured pre-edit test text.
- [Author's normalization provenance](../../artifacts/building-only-reveal-20260929/author/finish-provenance.json).
- [Corrected test](../../tests/food_collision_review.gd).

## Exact change and normalization boundary

Reversing only the new constants, `finish_digest` helper, and replacement assertion plus its reported metric restored the prior collision test **byte for byte**. All physical assertions and all 41 mesh hash pins remain unchanged.

The helper strips outer whitespace from each line, skips blank lines and full-line `//` comments, and omits only the following six exact statements. It retains the order and content of every other line before hashing their newline-joined UTF-8 text.

```glsl
#include "res://fidelity/hole_reveal.gdshaderinc"
uniform float reveal_occluder = 0.0;
uniform bool reveal_use_instance = false;
varying float food_reveal_weight;
food_reveal_weight = reveal_use_instance ? INSTANCE_CUSTOM.r : reveal_occluder;
if (food_reveal_weight > 0.0 && food_reveal_weight * hole_reveal_mask(food_world_position, INV_VIEW_MATRIX[3].xyz, INV_VIEW_MATRIX[2].xyz, IN_SHADOW_PASS) > hole_reveal_threshold(FRAGCOORD.xy)) { discard; }
```

The exclusion list has six entries and six unique values. It does not remove arbitrary uniforms, assignments, shader includes, alpha operations, or render settings. The expected finish hash is a literal pinned value derived from the verified old source; it is not recomputed from the current shader as the expected result.

## Independent sensitivity checks

The completed read-only audit used an independent Python equivalent of the inspected GDScript normalization. All **19 semantic mutations** produced a different finish hash:

1. Albedo gamma.
2. Albedo transfer threshold.
3. Minimum roughness.
4. Maximum roughness.
5. Specular strength.
6. Glaze strength.
7. Gloss response.
8. Broad-highlight exponent.
9. Reflection direction.
10. Reflection tint.
11. Emission multiplier.
12. Normal transform.
13. Vertex transform.
14. View direction.
15. Render mode.
16. A modified legacy uniform declaration, which no longer matches the exact exclusion.
17. An added albedo operation.
18. An added `ALPHA` output.
19. A foreign shader include.

Deleting each of the **26 retained normalized lines**, one at a time, also changed the hash: **26 of 26 rejected**. Seven positive controls covering the exact permitted legacy statements and harmless blank/full-line-comment treatment preserved the expected hash. The four audited shader/test files were unchanged before and after the audit.

These checks demonstrate sensitivity of the fixed source-program baseline. They do not claim that arbitrary mathematically equivalent shader rewrites will pass, nor that the finish assertion alone enforces the new food-opacity policy. Separate building-only reveal tests and the delivery verifier enforce that policy.

## Engine evidence and limits

The author separately ran the corrected Godot collision suite: **16,168 checks, zero failures**, with `ingredient_finish_sha256` equal to the pinned prior-release finish hash. See [receipt](../../artifacts/building-only-reveal-20260929/author/finish-collision.json) and [log](../../artifacts/building-only-reveal-20260929/author/finish-collision.log). Its strict diagnostic review reported no unexpected engine errors; the log retains the known macOS certificate diagnostic.

The independent mutation audit did not launch Godot, a browser, a native window, or network requests. It does not establish browser appearance, GPU rendering equivalence, or phone frame rate. The author engine run and independent source-mutation audit are separate evidence. The full 49-suite source/PCK gate was still running when this report was recorded, so this report makes no claim about its final outcome. No owned helper processes remained after the review.
