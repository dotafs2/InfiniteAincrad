# Offline NPC dialogue case pack validation

This is a synthetic, fixture-only case pack for structural dialogue checks. It is not production input, does not add world history, and does not claim that a resident's formal ID proves a skill, relationship, ownership, or completed event. The pack uses the ten formal IDs from `game/data/character_dossiers.json` and the bounded envelope in `docs/design/dnd-dialogue-and-measurement-plan.md`.

The JSON contains 30 authored English examples: three for each resident ID. The scenarios cover help, negotiation, refusal, failure, and revisit, with both expected structural acceptance and rejection. Each case provides human-readable visible claims plus an independently authored `parse_context` with the exact module shape `{target_ids, claim_ids, action_ids}`. Rejection cases use an unlisted proposed action, so structural rejection is attributable to the allowlist rather than a claim that the parser understands language semantics. A structurally valid but semantically questionable line would be accepted here and requires separate review.

Structural acceptance means only that the envelope and fixture constraints are satisfied. Human or language evaluation of voice, stakes, agency, consequence, and DND readability is explicitly separate and has no numeric quality score here. No paid API, language judge, production prompt, or authoritative world write was used.

## Reproducible checks

From the delivery root, run the JSON count checks and the real Godot receipt test:

```powershell
$p = 'docs/design/npc-dialogue-cases-20260923.json'
$x = Get-Content -Raw $p | ConvertFrom-Json
if ($x.schema -ne 'fixture.npc_dialogue_cases.v1') { throw 'schema mismatch' }
if ($x.cases.Count -ne 30) { throw "case count: $($x.cases.Count)" }
if (($x.cases.resident_id | Sort-Object -Unique).Count -ne 10) { throw 'resident coverage mismatch' }
if (($x.cases | Where-Object expected_structural -eq 'accept').Count -ne 20) { throw 'accept count mismatch' }
if (($x.cases | Where-Object expected_structural -eq 'reject').Count -ne 10) { throw 'reject count mismatch' }
if (($x.cases | Where-Object voice_evaluation -ne 'separate').Count -ne 0) { throw 'voice evaluation is not separated' }
'JSON parse and bounded count checks passed'
```

```powershell
$godot = 'D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
& $godot --headless --path game --script res://tests/npc_dialogue_cases_acceptance.gd
```

Expected deterministic result: JSON parses; there are 30 cases, ten resident IDs with three cases each, 20 structural accepts, 10 structural rejects with `unsupported_next_action`, and every case marks voice evaluation as `separate`. The Godot suite checks exact parser results, proposal-only execution, private-thought exclusion from public projection, and an unlisted-action mutation for every accepted case. The fixture is offline and fixture-only; it is not evidence of live resident behavior or semantic truth.
