# Reviewed dialogue world fixture — 2026-09-23

`reviewed_dialogue_world_acceptance.gd` is a disposable offline TownRuntime/Turns fixture using formal IDs `shared:carpenter`, `shared:smith`, and `seed:axe`. Before any Turns call, it joins the three committed local raw/context cases and rejects each through the reviewed adapter, checking snapshot, command count, disposable-save bytes, and evidence hashes. It then performs the existing skill-notice transaction, finds the actual 2-Col edge offer, and submits authored consistent offer/accept envelopes through the reviewed adapter. The resulting evidence is `offer_code=contract_proposed`, `accept_code=contract_accepted`, owner escrow `2`, cold Smith feedback `axe_contract_accepted`, and `source_unchanged=true` across 22 checks. It does not call a model, execute the saved local raw proposals, or establish live autonomy.

The saved model proposals are reviewed against their original exported contexts as a non-mutating preflight. They are never reworded or rebound to the later test world. Only the explicitly authored counterparts receive a current alias inside the test brain, before their single review. The source world remains untouched; injected fixture resources and co-location are inherited from the existing axe-day fixture helper. Cold reload checks the accepted contract, owner wallet 8 Col and escrow 2 Col; read-only feedback must contain this exact contract's acceptance event.

The [actual final report](reviewed-dialogue-world-20260923.json) was extracted from the managed Mono run at `private/iteration-20260923/reviewed-world-parent/`. Exit code 0, 22 checks, no failures, empty stderr and all three owned processes exited. TownRuntime requires the Mono console; the earlier non-Mono attempt failed dependency loading and is not validation evidence. Use the Mono setup documented in `dialogue-proposal-review-preview-20260923.md`, then run:

```powershell
python tools/run_godot.py --godot $godot --name reviewed-world-check --timeout 35 --out tmp/reviewed-world-check -- --headless --script res://tests/reviewed_dialogue_world_acceptance.gd
```
