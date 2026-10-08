# Food goal receipt fixture: independent review

Status: **PASS**, 36 corrected goal checks and 34 targeted owner-receipt checks. Runtime was not changed. Both sequential Godot helpers exited and were waited on before the root agent resumed exclusive performance sampling.

## Cause and correction

The old `tests/review_food_goals.gd` fixture disabled every hole's `active` flag, including the player, then invoked the real `finish_swallow()` receipt path. The combat update deliberately resolves receipts through `game.active_rival_owner()`: an inactive hole can only credit a living successor. With no successor, rejecting the receipt is correct. Disabling movement does not require making its owner inactive.

The author restored the player and one test rival to active, kept their movement and physics callbacks disabled, moved the rival far from the player, reset the combat history, and added two assertions proving both owners resolve to themselves. Restoring the rival as well as the player is material: the existing assertion that rival collection does not advance the player's food goals must exercise an **accepted rival receipt**, rather than an invalid receipt rejected before attribution.

The exact independent diff contains only these fixture additions. All 30 original static check statements are byte-preserved; loop expansion retains all 34 original run-time checks. Two new precondition checks bring the run to 36. No thresholds, original assertions, receipt methods, objectives, or runtime files were changed for this correction.

## Independent execution

The corrected goal suite passed **36 checks** through the current `release_web.acceptance()` strict diagnostic runner. A short artifact-local script extends the already accepted `tests/growth_rivals_review.gd` and calls its unchanged `ownership_chain()` function. It adds targeted cases and passed **34 checks across both actual map scenes**:

- A living player's actual `finish_swallow()` credits score, collection count, and an owner-attributed receipt.
- A living rival's actual completion receives its existing 70% growth reward, emits the rival's receipt, and does not advance the player's score or food objective ledger.
- An inactive rival without a successor cannot credit score, count, accepted receipts, or player food objectives.
- The reused ownership review covers two consecutive retirements; claim, pull, fall, and supported-release ownership transfer; idempotent physical completion; and a late callback to the original retired owner resolving to the surviving player.
- Both direct late callbacks and actual `finish_swallow()` on the results page leave score and accepted receipt counts unchanged.

These are controlled accounting checks using real runtime methods. They do not claim a physical fall, ordinary gameplay, browser presentation, device frame rate, or a fresh full run of the 291-check suite. Existing pedestrian and collision reviews cover physical falls separately. All calls used `--headless --fixed-fps 60 --test`; no player save was modified.

## Evidence and hashes

Evidence is in [`artifacts/growth-rivals-20260928/food-goals-fixture-review`](../../../artifacts/growth-rivals-20260928/food-goals-fixture-review/): `food-goals-before.gd`, `assertion-diff.json`, the independent script, both strict `.json`/`.log` receipts, and `provenance.json`. The author's preserved failure and correction evidence is in [`artifacts/food-goals-fixture-20260928`](../../../artifacts/food-goals-fixture-20260928/).

Before/after execution hashes were equal:

| File | SHA-256 |
| --- | --- |
| `fidelity/game.gd` | `b4aaaff3146f320cef2fedeaa262d71a51625635bda45894fb8121c8c6dfb68c` |
| `tests/review_food_goals.gd` | `104efa04422cbc6dfbd2fef92b8740e133e6d2ced443f25a0174e26a50caaf43` |
| Reused `tests/growth_rivals_review.gd` | `3238a53b8d25520b93c633f9650e22c3489babea8a931263190c2ca281fa256f` |
| Artifact-local `owner_receipt_review.gd` | `6094255350fc8014326605ff2219d44b0fa9b4e7d451a671e0fd64ab9acade36` |

The provenance also records stable hole and food runtime hashes. The correction does not conceal a legitimate active-owner scoring regression in the exercised paths; it restores the fixture's intended precondition while preserving the deliberate inactive-owner and result-phase rejection rules.
