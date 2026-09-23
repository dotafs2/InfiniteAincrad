# Adventure primary-source boundary review — 2026-09-23

This review checks only the setting boundaries needed by `adventure_contract.v1`.
It does not invent a combat formula and it does not authorize installation into the
seq323 world. The contract remains an original compatible extension until the host
chooses and reviews its concrete mechanics.

## Sources and supported boundaries

| Source | What it supports | What it does not establish |
| --- | --- | --- |
| [Official episode 2 story](https://www.swordart-onlineusa.com/aincrad/story/?no=02) | The first floor is a meaningful progression boundary, a boss room can be found, and players can organize a boss raid meeting. | A damage equation, a particular party API, or automatic floor unlock semantics. |
| [Official episode 5 story](https://www.swordart-onlineusa.com/aincrad/story/?no=05) | An Area/town can exclude monsters; ordinary player combat is treated as a separate rule boundary that the incident investigates. | A complete safe-zone, crime, duel, death or revival implementation for this project. |
| [Official episode 7 story](https://www.swordart-online.net/sp/aincrad/story/story07.html) | Blacksmithing, weapon durability and scarce crafting metal are meaningful world concerns. | Numeric durability loss, attack/defense values, loot ownership or a skill-granting profession title. |
| [Official episode 9 story](https://www.swordart-onlineusa.com/aincrad/story/?no=09) | A party may discover a boss room, withdraw after assessing danger, and retreat to a safe area. | Teleportation, an automatic defeat teleport, or a universal retreat route. |

## Contract decisions after review

- `town` remains a non-combat safe-zone boundary, with the exact project reducer
  enforcing it rather than a narrative claim.
- Wilderness, labyrinth and boss access remain explicit physical actions with
  durable receipts. A source reference does not permit model teleportation.
- The v1 hostile-encounter-only target rule and resident-versus-resident refusal
  remain project safety decisions. The sources do not grant permission for player
  damage or a crime system.
- The expression `max(1, attack_power - defense_power)` remains a **test
  placeholder for this original extension**, not a sourced Aincrad rule. A host
  review must either approve it as an original bounded mechanic or replace it
  before live installation.
- World-owned finite loot, no permanent death in v1, and explicit floor-unlock
  receipts remain scope decisions. They are intentionally not presented as canon.

## Gate result

`primary_source_review.status = reviewed_boundaries_only`.

The machine-readable companion is
`docs/validation/adventure-primary-source-review-2026-09-23.json`; both artifacts
must remain paired with the contract hash in the review record.

The sources support the contract's broad boundaries and do not support its
numeric combat formula. The next gate is host review and capability registration;
the canonical seq323 world remains untouched.
