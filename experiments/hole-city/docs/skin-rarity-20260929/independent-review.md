# Independent rarity and draw review

Status: **PASS — 1,555 independent resource/probability checks, plus 202 checks from the unchanged prior independent geometry suite.** No runtime change was made by this reviewer. The new permanent test is `tests/skin_rarity_review.gd`, marker `SKIN_RARITY_REVIEW`, minimum 1,555. Every owned native helper exited.

## Preserved identities and real visual differences

The pre-rarity catalog and visual script were independently compared with the restored v0.8.6 hotfix source, not accepted solely from the implementation author's summary hash. Both baseline files match exactly. The reviewer instantiated the actual older visual builder and recorded its geometry/parts/motes for all 44 identities before comparing the new models. Definition changes affecting tint and descriptive text do not affect that old geometry measurement.

All 44 saved IDs, group membership, legacy ownership thresholds, skill kinds and cooldowns remain. Every original field of the five active-skill definitions remains identical, with the sole addition of their Epic rarity. Slate Ring deliberately keeps the saved ID `cocoa_square`; its new display name and gray palette do not create a replacement ownership ID.

The six Common forms now have one visible ring, and the eight Uncommon forms two visible meshes (ring plus trim). Their actual mesh counts and triangle counts are lower than the corresponding delivered v0.8.6 models. They contain no concealed old motif, motes, local animated parts or retained ornament children. Their actual ring mesh uses 32 segments and their material selects static recolor or basic sheen. A single hidden reusable feedback ring remains. The other thirty skins preserve their old geometry, part counts and mote counts exactly; complexity is not inferred from rarity labels alone.

Core Shell, Tide and Cinder are Legendary. Orbit, Prism Vale and Rainbow Bridge are Prismatic. The review explicitly checks Orbit's spectral material and Rainbow Bridge's animated rainbow shader branch. Preview/player mouth clearance, closed motif geometry, outward faces and lifecycle remain covered by the unchanged independent geometry suite, which was rerun successfully.

## Pure draw mathematics

`skin_draw.gd` is tested without loading the game, changing ownership, opening a save or instantiating UI.

- Exhaustive midpoint selection across 10,000 equally sized tickets returns exactly 4,500 / 2,800 / 1,600 / 800 / 250 / 50 outcomes in a complete six-tier synthetic pool.
- Each tier separately receives 1,200 item-roll samples over three unowned items, producing exactly 400 selections of each item. The two-stage tier-then-item design is therefore uniform within a tier, not uniform across the whole catalog.
- All 64 possible available-tier masks are checked under five counter states: no pity due, Epic due, Legendary due, Prismatic due, and all due. The independent oracle verifies eligible IDs, integer weights, normalization, empty-pool behavior and endpoint rolls. The highest eligible due guarantee wins.
- Actual Classic and Special collections are drained using adversarial low tier rolls, obtaining all 27 and 17 skins exactly once. Guaranteed Epic-or-higher on draw five, Legendary-or-higher on draw ten and Prismatic on draw twenty apply when a qualifying unowned reward remains.
- Awarding a higher rarity resets every satisfied lower guarantee; unsatisfied higher counters advance to their next-draw threshold. Negative and overlarge restored counters are bounded. Helpers do not mutate the caller's counter dictionary.

The disclosed probabilities are the **current normalized eligible-pool probabilities**. Base percentages are not an unconditional next-draw promise: for example, the Classic collection has no Epic skins, and exhausted tiers and an active guarantee change normalization. UI disclosure, transactional ownership changes, charging, save rollback and pity persistence remain separate integration acceptance; this pure helper result does not certify them.

## Existing-test maintenance audit

The preserved and current versions of `skin_catalog_acceptance.gd` differ only where deliberate Common/Uncommon recolors conflict with former universal-uniqueness requirements. Higher tiers still require distinct families and the twenty remaining sculpted/effect additions still require different geometry. `skin_fx_acceptance.gd` changes only the expected total from 44 distinct families to thirty individual forms plus two explicitly shared low-tier families. Geometry budgets, bounds, shader clocks, mouth restrictions, actual movement effects and feedback retirement remain.

`city_review_skin_catalog.gd` is byte-identical to its pre-rarity baseline (SHA-256 `fe43f99ce68ca48f4905725d49a30ed8dfde1b5aaa37b225e85461061cc4659b`). Its count falls to 202 because removed low-tier extruded motif meshes no longer enter per-motif checks; no assertion was deleted. The author suite's saved-field pin was also checked against the independent original catalog comparison.

## Provenance and limits

Evidence is under `artifacts/rarity-review-20260929/`: final strict logs/receipts, independently measured `old-visual.json`, per-field catalog comparison, complete before/current test diffs and `provenance.json` with stable before/after hashes.

| File | Reviewed SHA-256 |
| --- | --- |
| `fidelity/skin_rarity.gd` | `dc532376060506100c2eb9fa22da7addb43cf696826c271cc54ec8a34a7fc3a7` |
| `fidelity/skin_catalog.gd` | `b32ac45522b7924eb2173a75d5f055a5f5c297cf6bfa99f933fd2b5fd63d8b8b` |
| `fidelity/skin_visual.gd` | `32e0ca8f804402ea0e29bba61357f429156869b63af827b6e1743e2502b8b3ef` |
| `fidelity/skin_draw.gd` | `d652e572d417a9f3e3f926576b568f4157a84b9234eea82781c062dee520a2e6` |
| `tests/skin_rarity_review.gd` | `e98bcfc57160f41f694c3cb3607a83e0ab068de9de207b4d34f40af7bcacce7e` |

No concrete defect was found in this frozen rarity implementation or pure draw helper. Source modules were loaded directly while the parent continued game integration; `game.gd` was not preloaded. These results establish real resource/geometry changes and deterministic probability behavior, not GPU appearance, subjective visual quality, browser behavior, mobile frame rate or economy integration.
