# Adventure disposable migration probe — 2026-09-23

The exact seq323 save was loaded through the production validator and copied into
an isolated `adventure_contract.v1` sidecar. All ten stable resident IDs migrated.
The migration preserved combat authority as `undefined_until_host_seed`; it did
not invent HP, attack, defense, equipment, encounters or loot.

The probe exercised committed-job rejection, explicit wilderness and labyrinth
receipts, closed refusal of an undefined encounter, a physical return receipt and
an exact cold reload. It passed 16 checks. The maintained seq323 file remained byte
identical before and after the run.

The sidecar is evidence for the next GM effect review, not a live feature. It is
not installed into `TownActions`, and no resident has adopted an adventure action.
