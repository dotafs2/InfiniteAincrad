# Adventure contract v1

This is the first bounded contract for an original adventure extension. It is design input for a disposable live-install decision, not a canonical world feature. The primary-source boundary review is recorded in `docs/validation/adventure-primary-source-review-2026-09-23.md` and its JSON companion; it supports the setting boundaries but does not canonize the damage expression. The host explicitly selected `max(1, attack_power - defense_power)` as the v1 original extension, with closed rejection whenever its inputs are not authoritative.

## Why this scope

The current town already owns physical movement, finite materials, contracts, resident knowledge and save continuity. Adventure should reuse those authorities. The model may choose an offered goal or action; it never supplies steering vectors, hit results, loot, damage or floor access.

The contract defines four zone kinds: a non-combat town, dangerous wilderness, a dangerous labyrinth and a first-floor boss arena. It deliberately uses a bounded original extension. It does not assert official SAO formulas, import D&D classes or magic, add a permanent-death system, or unlock a floor from a narrative statement.

## Required host implementation

1. Add a versioned reducer below the existing world action boundary. It must reject combat in town, reject undefined attack or defense values, bind every result to an idempotent command, and conserve finite equipment and loot.
2. Add collision-aware wilderness and labyrinth routes. `enter_wilderness`, `enter_labyrinth`, `flee` and `challenge_floor_one_boss` must be physical or explicitly host-gated actions.
3. Persist zone, HP, equipment, encounters, loot receipts, defeat status and floor state. A cold restore must compare every field and never replay a paid or completed command.
4. Add resident capabilities and sourced knowledge. A resident may refuse, avoid or defer combat; a profession title does not grant a weapon or combat skill.
5. Run a disposable seq323 migration and a real GM proposal/review/effect-feedback cycle before any canonical installation.

The deterministic damage expression in the JSON is a bounded original extension selected by the host for disposable v1 testing. It is not a claim about official Aincrad mechanics. The reducer refuses the action when its inputs are unknown, and a later balance review may revise it before any canonical installation.

## Review corrections before wiring

The first GM review found four conditions that are now explicit in the contract:

- v1 keeps boss loot world-owned. Resident or party assignment is out of scope until a consent-bound capability exists.
- Entering a danger zone requires physical arrival and no committed job. Defeat stays in place until a separate physical retreat action; it never silently teleports a resident or consumes a committed material.
- v1 targets hostile encounters only. Resident-versus-resident damage is refused pending a separate safety, crime and duel review.
- Every action has a versioned capability ID. The boundary review, detached registration, host effect review and rendered probe are complete enough for a disposable live-install decision; canonical installation and resident adoption remain blocked.
