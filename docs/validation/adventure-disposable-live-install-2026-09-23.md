# Adventure disposable live install — 2026-09-23

This gate exercised the reviewed adventure capability registration path against a disposable copy of the seq323 town save. It did not write the maintained world, its checkpoint lineage, the source sidecar, or the Kimi/developer ledgers.

## Result

- 14 checks passed; 0 failed.
- The bridge loaded the 36 host definitions and 10 adventure definitions into one registry (46 total, no collision).
- `shared:baker` entered wilderness, an unknown encounter was rejected as `encounter_missing`, and the resident physically returned to town with `fled_to_safe_zone`.
- The manifest cold-loaded with the same adventure snapshot and all 46 definitions.
- The disposable town copy and adventure source sidecar were byte-identical before and after the run.
- `canonical_mutation_allowed=false`; no resident adoption, combat authority, loot, or floor progression occurred.

Evidence is recorded in [`adventure-disposable-live-install-2026-09-23.json`](C:/InfiniteAincrad/docs/validation/adventure-disposable-live-install-2026-09-23.json). The executable bridge is [`adventure_live_bridge.gd`](C:/InfiniteAincrad/game/core/adventure_live_bridge.gd), and the acceptance runner is [`adventure_disposable_live_install_acceptance.gd`](C:/InfiniteAincrad/game/tests/adventure_disposable_live_install_acceptance.gd).

GM-04 accepted the effect receipt (`feedback-20260923T111114Z-a6b9e1`, decision `accept`). The review explicitly keeps `resident_adoption=false`; this gate does not authorize canonical integration or claim that the baker learned or chose these capabilities.
