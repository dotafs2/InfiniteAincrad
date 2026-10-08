# Independent timed-run, collection and monetization review

Status: **PASS — 590 source checks plus both full-duration food runs**, strict
engine diagnostics. Source hashes remained stable across the final review and
full-round probe. No runtime file was changed by this reviewer.

## Evidence and method

- `tests/retention_review.gd` emits `RETENTION_REVIEW` and requires `--test`.
  It runs actual game timer, rival combat, replacement-player creation,
  settlement, migration, persistence and UI actions. Native bridges receive
  independently authored, typed test providers through their explicit test
  injection API. No SDK, advertisement, payment or external account is used.
- `artifacts/retention-20260929/review-final-590.{json,log}` retains the result
  and strict native log. `review-before.json` / `review-after.json` bind source
  hashes. The engine is the bundled Godot 4.7.2, official `ed1daf0bf` build.
- All saves are process-owned paths beneath `/tmp/hole-retention-review-*`.
  They are removed at teardown. Streamed audio is stopped and drained before
  freeing the scene. The review never touches player saves or the preview server.

## Independently checked behavior

1. Both maps remain playable at 499, 500, 501 and 10,000 points. Food receipt
   goals being fully complete do not settle the round. A genuine larger rival
   consumes the player through `scan_rivals`; the two-second respawn countdown
   continues the round clock, then replaces only the player actor while retaining
   its score and derived radius. Protection lasts eight seconds and expires at
   its exact boundary. Timer expiry during another respawn settles once.
2. Each of the 44 former skin entitlements individually survives a schema-2 to
   schema-3 save and cold restore with equipment, wallet and unrelated values
   intact. All 44 explicit IDs also survive schema 0, 1, 2 and 3 fixtures even at
   zero historical score. The fresh starter is `cocoa_square` / Slate Ring.
3. Both normalized pity dictionaries round-trip unchanged. A failed guaranteed
   draw restores wallet, ownership, selected skin and both tabs' counters. A
   successful due Prismatic draw resets applicable counters, retains the other
   tab and persists the entire transaction together. The pure draw mathematics
   and lower-tier geometry were separately reviewed in
   `docs/skin-rarity-20260929/independent-review.md` (1,555 checks).
4. Without native SDKs, videos and purchases return unavailable and their actual
   UI controls are disabled. A close callback alone awards nothing. An unknown
   rewarded ID has no effect. An authenticated old-round earned callback grants
   that round's exact 32 coins, even after a different 119-coin round settles;
   it neither doubles the wallet nor marks the new round doubled.
5. Reward request persistence fails before external presentation is invoked.
   Reward-credit write failure rolls back coins and leaves an authenticated
   `reward_due` retry. Once that state can be persisted, a cold restore retries
   it exactly once. The live retry updates the current result receipt.
6. Real bridge signal dispatch handles pending parental approval without coins,
   old same-product approval while a newer presentation is open, duplicate
   transaction IDs, wallet-save failure without acknowledgement, subsequent
   redelivery, acknowledgement failure/retry and cold-restored deduplication.
   Rejected synchronous provider invocations cannot manufacture coins.
7. An independent 12-case permutation oracle covers all orders of earned,
   closed and failed callbacks for accepted/rejected ad invocations. Failure
   before earning disqualifies the reward; closing is neutral; accepted earning
   wins over a later failure. Repeated callbacks cannot revive or duplicate it.
8. The actual RATES control opens disclosure and BACK retains collection tab
   and page. Current unowned odds normalize to one; guarantee and eligibility
   copy fit the portrait text area. Rates and native product actions meet the
   44-point height floor at 375-point width. Native localized price strings are
   passed through exactly. These are layout/contract checks, not pixel captures.

## Preserved failures and fixture correction

The first 331-check review had six failures in the second-death/settlement
portion. The independent fixture had directly enlarged the enemy radius while
leaving its score at zero. Its first kill legitimately called `award`, which
recomputed a small radius; the respawned player then ate that now-small enemy.
The corrected fixture grants the enemy real score with `award(20000)` and
asserts its genuine growth is sufficiently large. No runtime behavior or final
expected score was changed. The failed script and logs are retained as
`retention_review-first.gd` and `review-first.{json,log}`.

The intermediate expanded run actually passed 589 checks with a clean log but
its temporary runner minimum was mistakenly 590. That receipt is retained as
`review-expanded.{json,log}`. The final suite additionally verifies RATES BACK
preserves tab/page, legitimately totaling 590; the strict final runner uses 590.

## Intentional legacy-test maintenance

Original files, hashes and exact diffs are retained under
`artifacts/retention-20260929/test-maintenance-before/` and the neighboring
`maintenance-manifest.json` / `*.diff` files. No old check call was removed.

| Suite | Checks | Deliberate specification update |
| --- | ---: | --- |
| `coin_skins_acceptance.gd` | 403 | New Slate Ring starter; schema-3 fallback; timed finish adds 20 coins; derived wallet/shortage totals adjusted |
| `progression_acceptance.gd` | 15 | Positive-score timed completion advances once and adds finish bonus; legacy eaten result still pays score only |
| `city_review_progression.gd` | 10 | Same timeout semantics and consequent later-stage values; actual late physical receipt and disk-retry checks retained |
| `store_acceptance.gd` | 17 | Unchanged byte-for-byte; gem exchange and gift accounting still pass |
| `review_food_goals.gd` | 37 | All prior threshold/ownership/duplicate/late-receipt/guide checks retained; satisfied optional goals leave play active, actual timer expiry settles |
| `food_round_acceptance.gd` | 2 | Both contested and solo actual autoplay must have positive score and settle at 240–241 simulated seconds; optional goals no longer end the round |

## Limits

This certifies source behavior and the adapter contract, not a live payment or
advertising integration. No native SDK is bundled, and no real product price,
receipt verification service, consent flow or provider callback was exercised.
A native store adapter must independently verify transactions before emitting
its trusted signal. An authenticated reward still only held in memory during
an unwritable-save period cannot be guaranteed after process destruction;
persisted `reward_due` recovery is what this review demonstrates.

Browser appearance, actual audio playback, device GPU performance, subjective
rarity appeal and first/second earned-unlock pacing remain separate acceptance
items. No browser, native screen capture, offline imitation or performance
profiling was used for this review.

## Full-round result and final identity

`artifacts/retention-20260929/food_round-final.{json,log}` records both actual
food autoplay runs completing at 240.000000000083 simulated seconds:

- Contested: 3,347 points; 41 buildings, 1 landmark and 4 heaps received.
- Solo: 9,556 points; 134 buildings, 9 landmarks and 11 heaps received.

Both runs also consumed actual pedestrians (15 and 38 receipts respectively).
This is one seeded runtime sample per mode, not a claim about average human
progression or iPhone speed. All owned helpers have exited.

Final source SHA-256:

- `fidelity/game.gd`: `655ef8c91be52c8e90b6d59f024a251879209991d233977b3d4aaefeaabb92ca`
- `fidelity/ui.gd`: `1786f50f5f9725d793e2aae87ce76e9480c72b55542ba0cf9570aca385ca3c24`
- `fidelity/ads_bridge.gd`: `d0aa5658ddf026403064a3b5dd22802b4c5718ba077967e6ce1344335d37ad76`
- `fidelity/commerce_bridge.gd`: `db3f3e1b414b17230d2a7c2b3694271e868d3746f552b9c93a2396d84162af3a`
- `fidelity/skin_rarity.gd`: `dc532376060506100c2eb9fa22da7addb43cf696826c271cc54ec8a34a7fc3a7`
- `fidelity/skin_draw.gd`: `d652e572d417a9f3e3f926576b568f4157a84b9234eea82781c062dee520a2e6`
- `fidelity/skin_catalog.gd`: `b32ac45522b7924eb2173a75d5f055a5f5c297cf6bfa99f933fd2b5fd63d8b8b`
- `tests/retention_review.gd`: `9c13895f3b9aa3694078515ccd15b08b4f6a71288b3807a5df18b7b79e3f982b`
