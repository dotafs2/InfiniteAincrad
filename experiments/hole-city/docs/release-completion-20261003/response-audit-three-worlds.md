# Independent audit of the three-world Guideline 2.1 response

Audit date: October 3, 2026. Scope: read-only source, retained package configuration,
license notices and prior account observation receipts. No engine, account,
device, purchase, upload or review action was performed. The scheduled toy-map
iteration is paused; this audit supports only the authorized combined release.

The response is substantially consistent with the current local 0.13.0 source.
It remains an **unsent draft**. Build 27, its installation, latest-OS physical
recording and actual sandbox purchase must be bound to fresh evidence before the
draft describes them as completed.

## Seven requested items

| Item | Source-supported finding | Before sending |
| --- | --- | --- |
| 1. Physical demonstration | The draft correctly leaves an explicit physical-device/latest-OS recording placeholder. A Mac capture, prior build 16 or rejected build 26 cannot establish build 27 acceptance. | Bind the exact submitted package, installed build, device OS and inspected recording. Show launch, typical play and access to paid features. The proposed sandbox purchase demonstration remains unverified. |
| 2. Purpose and audience | Casual single-player collecting/growth with seven computer-controlled rival holes is implemented. `MAPS` and `MapCatalog.DEFS` expose Sunny City, Snack Garden and Bubble Toy Town. All three are available without a map purchase. | No source correction needed. Do not describe multiplayer, an online account or a remote AI service. |
| 3. Setup/features | HOME has three selectable map cards and PLAY. `map_round_seconds()` returns City 90, Food 60 and Toys 90. Drag movement, charged BOOST, HOLES, Settings and local progress are real paths. `select_map()` is restricted to the title/menu phase, with no region or entitlement restriction. | Keep “no app account” wording: Apple may still require its own store authentication for a purchase. Physical demonstration is still separate from source inspection. |
| 4. External services | Local game logic has no developer-operated game backend or cloud-save flow. The native adapter imports GoogleMobileAds, UserMessagingPlatform and StoreKit. Before SDK initialization it disables PFID and publisher personalization; requests use `npa=1` and are gated by UMP `canRequestAds`. | Bind these same adapter/SDK bytes in the new candidate receipt. The draft correctly discloses SDK data processing and does not equate non-personalized ads with no collection or infer a new Tracking decision from a manifest. |
| 5. Regions | Maps have no country-specific branch in the inspected runtime. The retained successful-submission receipt records US-only availability for all three diamond products. Prices come from Apple's catalog, while ad/consent availability follows providers. | Root must confirm the successor app/product availability still matches this account configuration. The old receipt is configuration evidence, not a fresh build 27 account observation. |
| 6. Services/licenses | The retained notices identify MIT Godot/template licensing, Fredoka SIL OFL and Shop Theme CC0 with author credit. `release_info.gd` loads these files into Credits. The city manifest explicitly identifies original Blender geometry; Toy geometry is authored locally. | No concrete asset-license mismatch found in this bounded audit. Original/proprietary-asset statements are supported by local provenance, not a new exhaustive copyright examination. Preserve the notices in the actual exported package. |
| 7. IAP/access | HOME → STORE → DIAMOND SHOP matches current UI. IDs `sink_city.diamonds_60`, `_360`, `_1800` match both the bridge and Swift consumable allowlist. StoreKit supplies prices and verifies transactions; the game saves wallet plus transaction binding before acknowledging, with rollback on failure. Exchanges, a 1-diamond coin boost and a 5-diamond continuation are implemented. | Correct the video-visibility sentence below. Verify live product catalog/purchase/credit on the exact physical candidate; neither source nor an UNAVAILABLE shop image proves that acceptance. |

## Concrete wording correction

Item 7 currently says:

> Optional rewarded-video alternatives are shown when ready; unavailable offers are disabled.

The result video controls remain visible when no ad is ready, displaying
`NOT READY` and remaining disabled. The Store diamond-video offer also remains
visible but disabled. Replace that sentence with:

> Optional rewarded-video buttons are disabled until an ad is ready.

For a precise description of paid-feature use, the following optional replacement
also matches the implementation:

> Diamonds can be exchanged for coins in STORE, spent on one 1.5x round coin bonus
> for one diamond, or used for one 30-second continuation after timeout for five
> diamonds. These two round offers are independent and each is available once;
> fractional bonus coins are rounded down. Coins fund UNLOCK RANDOM in HOLES;
> the RATES screen displays the current probabilities and guarantees.

The original “Coins unlock collectible skins” is broadly true, but the explicit
UNLOCK RANDOM/RATES path gives reviewers a more complete paid-currency flow.

## Reward and wallet boundaries

- Base round coins are `floor(score / 100)`, capped at 30, plus a five-coin
  completion bonus when eligible. A continuation reuses the world and round
  receipt; it does not pay another completion bonus or count another completed run.
- The current 1.5x boost adds `floor(base_coins / 2)` once. If a later continuation
  earns more base coins, settlement adds only the new base and incremental bonus.
  Legacy unfinished 2x requests and legacy verified coin purchases remain payable.
- A rewarded boost or continuation requires an authenticated SDK earned callback
  **and** actual ad closure before applying/resuming. Closing an unearned ad
  creates no reward. Video duration is provider-controlled; do not promise 15 seconds.
- A store diamond video grants three diamonds only from the earned callback,
  starts its 120-second cooldown only after saving, and stays busy until closure.
- If an earned extension cannot resume its original world, the durable fallback
  is five diamonds with an explicit notice; it does not recreate an abandoned run.
- Exchanges are 250 coins/50 diamonds, 1,500/250 and 7,000/1,000. Purchases and
  spending use local persistence and do not create cloud-restorable consumables.

These are source facts, not a new physical or sandbox test result. No changes to
economy, accounts, privacy labels or runtime were made for this audit.

## Bound evidence

The current Swift adapter is byte-identical to the retained production 26 copy.
Its SDK framework metadata reports GoogleMobileAds 13.11.0 and UMP 3.1.0. The
retained production Info.plist has `HoleFeastTestAds=false` and no authored
camera, microphone, location or ATT permission string. These observations do not
replace the new candidate's package receipt or physical launch verification.

| Inspected input | SHA-256 |
| --- | --- |
| `information-needed-three-worlds-20261003.md` | `9c6938e597f935832567727e2b9ce11a8fc80f52ded4dd51e98e14026361ece0` |
| `fidelity/game.gd` | `42e0fc879b3866e7994875defac3829cebbbc8b6d228faf529c1ef36600ee692` |
| `fidelity/ui.gd` | `b567b5786d2637175061db0caa42ddcb27f8cc31f9f5d001faf3dca89f0ec8e9` |
| Current and production-26 `HoleFeastServices.swift` | `4796be1bac3627e4bed3f548fa11ab3bc298938756cb8b0091447f397ab5eb08` |
| `fidelity/toy_court.gd` | `ff8a616cbe9b2413027dc7ed4c838243d7a7ff6aef8640e70f4fe3db2af24058` |
| `fidelity/toy_neighborhoods.gd` | `056df5913b02d2af3e13dd78744d2f1a73b0e3c38bd6d65949d8ed994d4cca1b` |

Supporting account/request observations:
`information-needed-receipt-04.json` supplies Apple's exact seven-item request
and the rejected 0.12.7/build 26 boundary;
`submitted-review-receipt-03.json` supplies the earlier US-only product setup.
Neither receipt proves a subsequent upload or current physical purchase.
