# Migration preparation

Source repository: [dotafs2/vibeGamingDemo1](https://github.com/dotafs2/vibeGamingDemo1), branch `codex/organic-village-20260907`, inspected commit `66ba98916b266dea0014a2d06b870c6d154acdf3`.

The current goal and stop thresholds are newly restated in this repository. The source history remains available; no wholesale copy or history rewrite is planned. Its latest local planning edits were not included in that inspected commit.

## Selective migration register

| Source | Purpose here | Current state |
| --- | --- | --- |
| `ThreeHearthsVillage/Plugins/ThreeHearths/Source/ThreeHearths/Private/HearthAincradLife.cpp` and relevant resident runtime actions | Preserve the exact rules for a bounded repair/delivery/payment/use event | Not copied or ported |
| `HearthAincradIntent.cpp`, `HearthAincradSurvival.cpp`, `HearthAincradForaging.cpp` in that module | Preserve only facts and rules needed for the selected event and continuity | Not copied or ported |
| `Prototypes/StartingTownWalkthrough/Art/ReferenceScenes` | Select a small authored market-street asset subset after dependency and redistribution review | No assets copied |
| `Prototypes/StartingTownWalkthrough/Art/Asset_Publication.md` | Asset provenance and exclusions | Referenced, not a blanket license |
| `ThreeHearthsVillage/Docs/Validation/SAO_Overnight_2026-09-10` | Historical event and cold-resume evidence for parity checks | Reference only; not rerun in this project |
| Private full save and carried fee ledger | Same-world continuity and budget preservation | Latest complete pair not yet verified locally; never committed |

The source prototype has 13 persistent identities, with three active residents. The last selected remote evidence reaches event sequence 37; the previously inspected local full save is older, at sequence 3. Public snapshots are not complete restore data. Before live migration, privately obtain and verify the latest source state and the carried fee ledger; do not promote the old local file or reset the ledger to claim continuity.

## First implementation step

1. Identify the exact current source state and valid unfinished need; record hashes and provenance privately.
2. Choose one existing supported interaction. Foraging currently provides food, not wood; using a tool can process existing wood. Do not assume desired capabilities already exist.
3. Migrate only the rules for that interaction, preserving identities and unsupported source state; validate against a clearly labeled fixture first.
4. Compare the candidate with the real source, then run the real interaction only when source state and budget prerequisites pass.
5. Show its result in the street, perform a cold restart, and verify that the following decision receives the actual experience.

The personal-intent journal's 128-entry ceiling is not the authoritative transaction deduplication ledger. Treat actual continuity failures locally; do not use it to justify a wholesale state-platform rewrite.

Old UE experiments, unrelated websites, repeated capture outputs, local tool paths, temporary helpers, paid-run controllers, API keys, private configuration, operational ledgers and Saved directories remain outside this project. The source Kirito asset and its derived files are not approved for redistribution and are excluded.
