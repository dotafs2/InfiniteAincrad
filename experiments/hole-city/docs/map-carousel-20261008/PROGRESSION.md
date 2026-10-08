# World access and save compatibility

## Implemented rules

| World | New-player access condition |
| --- | --- |
| Sunny City | Always available |
| Snack Garden | Finish a positive-score Sunny City round |
| Bubble Toy Town | Finish a Snack Garden round with at least 200 points |
| Frostlight Village | Finish a Bubble Toy Town round with at least 300 points |

A positive-score `complete` or `timeout` settlement qualifies. An `eaten` result, an unfinished run or zero-score idle expiry does not. Scores come from successful round settlement, separate from the unrestricted personal best. Coin boosts, skin ownership, purchases and current currency cannot unlock worlds.

These are modest authored thresholds, not retention research. Existing ordinary unboosted captures in `artifacts/coin-balance-20261003/ordinary-rounds-05.json` achieved 269 points in the 60-second food round and 332 points in the 90-second toy round. The historical coin rewards in that evidence have since changed; this choice uses its point totals only. The user's later physical Toy Town recording reaches 963 points. No new gameplay score or currency conversion is introduced here.

## Runtime API

`fidelity/map_progression.gd` owns the ordered IDs, thresholds, saved-data normalization and legacy migration. `fidelity/game.gd` exposes:

- `available_map_ids()`: the four implemented world IDs, including currently locked worlds so their screenshot cards can be shown.
- `unlocked_map_ids`: monotonic earned access in world order.
- `map_unlocked(id)`: authoritative selection/play access; unavailable future IDs never pass.
- `map_unlock_status(id)`: `available`, `unlocked`, `condition`, `progress`, `current`, `target`, `required_map` and `required_name`. Progress for later worlds uses their predecessor's best completed score. UI focus on a locked screenshot must stay local to the carousel.

Both `select_map` and `start_level` enforce the gate. A rejected direct launch restores the valid current-world ID when a world already exists, otherwise City; it does not instantiate the forbidden scene. A failed selection save restores the previous selected map and audio. Scene initialization also sanitizes an inaccessible preselected ID.

## Durable state and migration

New fields under `[progress]` are `map_unlock_schema=1`, `unlocked_map_ids` and `map_completed_best_scores`. They are stored in the existing atomic config transaction alongside the unchanged wallet, skins and reward receipts. Unknown IDs are ignored, duplicate IDs are removed and a known earned later world retains its earlier path. An unknown future schema number is preserved rather than downgraded.

For a pre-feature profile, positive per-map `best_scores` or a valid settled round receipt prove a map was played. Access is retained through the highest such map. A zero-score settled receipt can preserve an already played world, but cannot satisfy a new score gate. Only an explicitly `completion_credited` settled receipt with a positive score seeds a completed best. A previously selected thumbnail, aggregate stage and aggregate completed-run count are not used to invent per-map play or completion history.

Migration keeps the old scores, currencies, selected owned skin, preferences, transactions, reward receipts and unrelated config sections. If the old selection has no played-world evidence and is locked, it falls back to City. Migration marks progress dirty for the existing save retry path; the next successful atomic save records the versioned access. Once versioned, loading does not repeatedly reinterpret general high scores as legacy access. Receipt pruning cannot revoke persisted entitlements.

A thirty-second continuation can cross a score gate when its final positive-score settlement occurs. It updates the same receipt and existing completed-run count only once, while monotonically updating best completed score and access. If the save fails, earned access remains pending in memory through the existing `progress_dirty` retry mechanism; the old disk save is untouched. Retrying the save does not replay the reward or completion.

## Verification ownership and fixture policy

`tests/map_unlock_acceptance.gd` covers new-profile gates, invalid selection/launch, 199/200 and 299/300 boundaries, zero/failed results, real continuation accounting, save-failure recovery, legacy played-map evidence, malformed/future IDs, future schema preservation and receipt pruning. It uses isolated `/tmp` configs and explicit threshold scores; these are progression fixtures, not ordinary-play claims. It does not read or write real player saves.

Existing scene, physics and art suites can explicitly opt in with **both** `--test --qa-unlocked-worlds`. That fixture grants the four playable IDs only inside test mode, before optional `--qa-map` selection. Plain `--test` remains City-only; production ignores the fixture flag. The dedicated map-unlock suite rejects the fixture flag so the progression checks cannot accidentally bypass the feature. Root owns all engine runs and result verification.

Root verified the dedicated map-unlock suite: 92 checks passed. The final source and exact Web package each pass 93 suites / 175,537 checks. See `artifacts/map-carousel-20261008/web-gate-01/release.json` for the exact source and package hashes.

## Final interaction audit

The same reviewer performed a read-only final audit after the root repaired
consumed-release audio startup, immediate PLAY during card easing, and keyboard
Enter routing. No additional actionable issue was found. Locked focus cannot
launch the previously stored map; failed selection persistence cannot fall
through into launch; menu and resize transitions cancel the active pointer and
snap to the committed card. The reviewer ran no engine jobs for this audit.
