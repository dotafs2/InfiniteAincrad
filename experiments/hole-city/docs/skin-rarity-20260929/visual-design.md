# Six cosmetic rarity levels

The 44 existing skin IDs now have six cosmetic rarity levels. Fourteen lower-tier skins intentionally use simple shared geometry; detailed motifs and surface effects distinguish higher tiers. Rarity does not modify swallowing, movement, boost, skill strength, cooldowns or legacy ownership thresholds.

## Public metadata

`fidelity/skin_rarity.gd` provides aligned `ORDER`, `NAMES`, `COLORS`, `BASE_WEIGHTS` and `PROFILES` arrays. `RAINBOW_COLORS` contains six colors for an actual multicolor Prismatic badge; `COLORS[5]` is only its single-color fallback.

| ID | English name | Badge | Base weight / 10,000 | Catalog count | Actual visual treatment |
| --- | --- | --- | ---: | ---: | --- |
| `common` | Common | Gray | 4,500 | 6 | One solid recolored ring, no ornaments or sparks |
| `uncommon` | Uncommon | Green | 2,800 | 8 | A basic ring and fine contrasting trim; a simple moving reflection |
| `rare` | Rare | Blue | 1,600 | 12 | Recognizable sculpted food, animal or object forms |
| `epic` | Epic | Purple | 800 | 12 | Detailed motifs with glints or local animation; existing skill visuals retained |
| `legendary` | Legendary | Orange | 250 | 3 | Core Shell accretion, Tide water and Cinder flame surfaces |
| `prismatic` | Prismatic | Rainbow | 50 | 3 | Orbit's spectral vortex, Prism Vale's rainbow curtains, and Rainbow Bridge's animated rainbow rim |

These are base rarity weights, not unconditional per-skin odds. The economy controller must separately disclose and test how eligibility, no-duplicate rules, completed tiers and pity affect the actual next draw. This visual module does not draw rewards, write saves, or normalize the weights over an owned collection.

- `index_of(rarity_id)` returns the rank, or `-1` for an unknown ID.
- `data(rarity_id)` returns a fresh dictionary with `id`, `name`, `color`, `rank`, `base_weight` and `profile`; invalid IDs return `{}`.
- `for_skin(skin_id)` returns a rarity ID; unknown skin IDs return an empty string.
- `NEW_PLAYER_SKIN` is the existing ID `cocoa_square`, now displayed as **Slate Ring**, with a gray solid surface. New-profile creation and preservation of existing Core Shell/other ownership are the economy controller's responsibility.
- Each `SkinCatalog.DEFS` entry contains its `rarity`. The visual resolves its presentation from the stable skin ID, keeping preview/player surfaces consistent.

## Scope of the visual change

Common skins are Citrus Slice, Melon Munch, Cookie Bite, Pancake Stack, Bacon Curl and Slate Ring. Their six palettes differ, but their actual mesh is deliberately shared. The renamed Slate Ring retains the `cocoa_square` save ID. Uncommon skins are Sunny Side, Sugar Glaze, Berry Crown, Pretzel Twist, Waffle Stack, Frog Pond, Turtle Shell and Clockwork Key. Their descriptions now describe the simple finish rather than promising the removed food/animal ornaments.

The original five ability-bearing skins remain intact and are classified Epic. Core Shell remains blue. Core Shell, Tide and Cinder keep their authored continuous-surface shaders; no simple color swap is substituted for those effects. Rainbow Bridge keeps its arches and now uses the existing animated rainbow surface style. Other non-legacy Epic motifs gain the existing basic crystal-glint style on their ring. No new particle system, external image, shader file or physics node was added.

Visual complexity does not mean a monotonically increasing mesh count: an animated water surface can be visually richer than several static meshes while using fewer draw meshes. Existing bounds remain at most 18 gameplay mesh nodes and 4,500 triangles per skin. Common uses one visible mesh and Uncommon two. Both retain one hidden, reusable boost-feedback ring; including that feedback geometry, their totals are 1,152 and 1,536 triangles respectively. Their reduced rings use 32 rather than 64 segments.

## Compatibility and acceptance

All 44 IDs, collection groups, legacy score thresholds, ability kinds and cooldowns match the preserved pre-change catalog. The dedicated test pins their combined baseline SHA:

```text
1ac110ae13f762658a63741dd75912504aae98fc1caf4f637eccc11bc6663748
```

The [author manifest](../../artifacts/skin-rarity-20260929/author/manifest.json) binds the reviewed source, prior copies, per-field catalog changes and receipts. [Prior files](../../artifacts/skin-rarity-20260929/before/) were preserved before editing. The only changed catalog fields are `rarity`, the relevant cosmetic descriptions, and Slate Ring's display name/colors; no gameplay field changed.

| Focused suite | Checks | Result |
| --- | ---: | --- |
| New `skin_rarity_acceptance.gd` | 556 | Pass |
| Updated `skin_catalog_acceptance.gd` | 842 | Pass |
| Updated `skin_fx_acceptance.gd` | 414 | Pass |
| Unchanged `city_review_skin_catalog.gd` | 202 | Pass |

All runs passed the release tool's strict unexpected-engine-error filter. The initial new-suite run found a test-local inferred-Variant parse error; it was corrected to an explicit boolean, and the failed log was preserved before rerunning. No runtime workaround was required.

The old requirement for 34 unique new geometries and 44 distinct effect families conflicts with the requested simple recolors. Only those uniqueness assertions were updated: the 20 remaining sculpted/effect additions must still have distinct geometry, and the catalog now has 30 individual higher-tier effect families plus two explicitly shared lower-tier families. Per-mesh budget, mouth-clearance, preview parity, triangle orientation, rebuild and animation lifecycle checks remain. The independent geometry suite itself is byte-identical to its preserved original; its lower total comes from the deliberately removed lower-tier meshes, not deleted assertions.

The new suite additionally checks real visible mesh counts, absence of old ornaments/particles on all 14 simple skins, exact shader styles, six distinct Common palettes, high-tier shader preservation, feedback cleanup, safe metadata lookups and the prior gameplay-field baseline. These checks do not certify visual appeal, browser behavior, GPU cost or physical iPhone frame rate. No browser/native capture or gameplay-save access was performed. Independent review and economy/UI integration are separate gates.
