# Migration preparation

Source repository: [dotafs2/vibeGamingDemo1](https://github.com/dotafs2/vibeGamingDemo1), branch `codex/organic-village-20260907`, inspected commit `66ba98916b266dea0014a2d06b870c6d154acdf3`.

The current goal and stop thresholds are newly restated in this repository. The source history remains available; no wholesale copy or history rewrite is planned. Its latest local planning edits were not included in that inspected commit.

## Selective migration register

| Source | Purpose here | Current state |
| --- | --- | --- |
| `ThreeHearthsVillage/Plugins/ThreeHearths/Source/ThreeHearths/Private/HearthAincradLife.cpp` and relevant resident runtime actions | Preserve the exact rules for a bounded repair/delivery/payment/use event | Not copied or ported |
| `HearthAincradIntent.cpp`, `HearthAincradSurvival.cpp`, `HearthAincradForaging.cpp` in that module | Preserve only facts and rules needed for the selected event and continuity | Eat/rest/forage and live-time depletion/growth ported into `game/core/town_life.gd`; intent/runtime history retained, execution not yet ported |
| `Prototypes/StartingTownWalkthrough/Art/ReferenceScenes` | Select a small authored market-street asset subset after dependency and redistribution review | V5 market and editable Blender source obtained and hash verified |
| `Prototypes/StartingTownWalkthrough/Art/Asset_Publication.md` | Asset provenance and exclusions | Referenced, not a blanket license |
| `ThreeHearthsVillage/Docs/Validation/SAO_Overnight_2026-09-10` | Historical event and cold-resume evidence for parity checks | Reference only; not rerun in this project |
| Private full save and carried fee ledger | Same-world continuity and budget preservation | Latest complete pair not yet verified locally; never committed |

The source prototype has 13 persistent identities, with three active residents. The migration validation used a complete checkpoint from `D:/Dev/vibeGamingDemo1/ThreeHearthsVillage/Saved/ThreeHearths/AincradLevel0/world.json` at sequence 37, dated 2026-09-10 08:30:40. SHA256: `baaab67073a91b9db0b44691c05b4734f235898037074fc835d674d17ae63650`. This supersedes the earlier sequence-3 availability finding. The old UE world has since advanced to sequence 58; this document does not claim that newer checkpoint has been migrated or that the source path still has the sequence-37 bytes. Preserve the exact private baseline used for each comparison. The carried fee ledger for this Godot migration remains a separate unresolved prerequisite; no paid loop has been resumed here.

`python tools/migrate_town.py --source <full-source-world.json> --output <new-private-directory>` preserves the source bytes and every original JSON field, including unknown fields, and adds a Godot continuation section in a separate file. Outputs must stay outside `game/`; the output directory must not already exist. The explicit three-workplace mapping is a new Godot layout, not a conversion of UE geometry. Old UE runtime, unfinished operations, camera observations and billing receipts remain historical data and are never executed automatically. The copy is **migration validation**, not a promoted maintained world or a complete migration claim.

Launch that copy with `./Run-Street.ps1 -Town -SavePath <output/world.json>`. It starts paused. Space resumes offline local rules; ordinary time does not advance while closed. The same atomic-save/writer-lock base is reused. Original residents receive only their own recorded events and accounts; historical UE runtime and billing fields are excluded from their decision views.

## First implementation step

1. Identify the exact current source state and valid unfinished need; record hashes and provenance privately.
2. Choose one existing supported interaction. Foraging currently provides food, not wood; using a tool can process existing wood. Do not assume desired capabilities already exist.
3. Migrate only the rules for that interaction, preserving identities and unsupported source state; validate against a clearly labeled fixture first.
4. Compare the candidate with the real source, then run the real interaction only when source state and budget prerequisites pass.
5. Show its result in the street, perform a cold restart, and verify that the following decision receives the actual experience.

The personal-intent journal's 128-entry ceiling is not the authoritative transaction deduplication ledger. Treat actual continuity failures locally; do not use it to justify a wholesale state-platform rewrite.

Old UE experiments, unrelated websites, repeated capture outputs, local tool paths, temporary helpers, paid-run controllers, API keys, private configuration, operational ledgers and Saved directories remain outside this project. The source Kirito asset and its derived files are not approved for redistribution and are excluded.
