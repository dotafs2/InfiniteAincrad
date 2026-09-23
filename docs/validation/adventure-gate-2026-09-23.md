# Adventure gate status — 2026-09-23

The current seq323 world has a verified playable town surface and persistent resident life. It does not yet have a playable wilderness, combat reducer, labyrinth run, boss encounter or floor-unlock state.

## Evidence boundary

- The seq323 surface audit passes collision-aware town navigation, material production, trade/economy, resident knowledge, controller replacement and exact cold restore.
- The floor-1 geometry and modular-interior fixtures pass, but `floor1_expanded_world.gd` labels its labyrinth as a visual-only silhouette.
- Resident dossiers keep `hp`, `max_hp`, `safe_zone_status`, weapon skills and floor fields `null`; these are unimplemented authority slots, not dormant mechanics.
- No `wilderness`, `combat`, `boss`, `floor_unlock` or equivalent authoritative state exists in the saved world schema.

Therefore the project must not call the current town or floor art a complete first floor.

## Smallest honest implementation order

1. **Freeze `adventure_contract.v1`** as an original compatible extension reviewed against the Aincrad charter: town safe-zone boundary, wilderness entry, finite encounter seed, attack/defend/flee actions, defeat and return rule, loot ownership, and explicit floor unlock. No D&D classes, magic, model steering or invented canon claims.
2. **Implement a pure authoritative reducer** with versioned save/load. Every action produces a durable receipt; HP, equipment, loot, defeat and floor access are world state.
3. **Prove the reducer headlessly** with conservation, agency, safe-zone, defeat, duplicate-command and cold-restore checks before loading it into the live town.
4. **Add a collision-aware wilderness and labyrinth scene** using the existing route/navigation contracts. A resident reaches a target physically; the model may select only an offered goal/action.
5. **Add resident capabilities and sourced knowledge** for entering, avoiding or fighting. Installation does not imply resident awareness or adoption.
6. **Migrate a disposable seq323 copy first**, then run one bounded live resident episode and a restart continuation. Promote only if the canonical save, provider ledger and usage book remain continuous.
7. **Run a real GM proposal/review/effect-feedback cycle** for the adventure scope. Publish only after host tests and same-save observation; otherwise preserve the refusal.

The first contract review is now conditionally accepted by GM-04. The primary-source boundary review is recorded in `adventure-primary-source-review-2026-09-23.md` and its JSON companion: it supports safe-zone, boss-progression, retreat and equipment/material boundaries, but it does not provide a numeric damage rule. Detached capability registration and the host effect review are complete enough for a disposable probe; the probe must preserve the no-inventory-loot boundary and keep canonical seq323 read-only. Until that probe is observed and restored, any canonical combat or floor install would be an unbounded design guess rather than progress toward a trustworthy release.
