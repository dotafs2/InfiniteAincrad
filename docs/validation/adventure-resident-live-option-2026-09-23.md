# Adventure resident boundary — 2026-09-23

## Result

The disposable scene reaches the wilderness gate through real collision-aware body movement: **1,005 frames and 22.568 m**, with floor collision observed. The host then exposes `ability:adventure.enter_wilderness` only after that receipt.

Two bounded real Kimi turns saw the host-gated choice. In the first copy Wren (Baker) had no food reserve and chose `life:harvest_ration`; in the second copy her food and energy were non-urgent and she chose `ability:talk:shared:innkeeper`. Both turns settled as valid ordinary actions. Neither entered the wilderness, so `resident_adoption=false` and neither disposable copy was promoted.

The two disposable requests settled the external ledger **376 → 378**, CNY **7.6118814 → 7.6599309**. Both runs had no current provider error, reserved request or unknown charge. The canonical seq323 world remains SHA-256 `2d80c92778c34dc7de1434d48a6203faa1bd3638aef5830cf63936e68656774e` and the exact public checkpoint remains byte-identical.

## Offline action proof

The fixture boundary still passes **15/15**: the measured gate receipt exposes the option, the resident controller selects it, the sidecar records wilderness, the host life event is written, and both town and sidecar cold restore preserve the command lineage. This is fixture evidence, not a claim about autonomous model choice.

## Next gate

The model-facing boundary is now proven without coercion: the option is visible after physical arrival, while the resident may choose another valid action. A deliberate real-model adoption sample or a host-approved progression policy is still required before any canonical TownActions wiring, combat authority or floor progression.

Machine-readable details are in [`adventure-resident-live-option-2026-09-23.json`](adventure-resident-live-option-2026-09-23.json).
