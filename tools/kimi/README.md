# Existing Kimi budget implementation

These modules are the existing project implementation copied from `dotafs2/vibeGamingDemo1`, `ThreeHearthsVillage/Plugins/ThreeHearths/Tools`: `kimi_budget.py`, `kimi_gateway.py`, and `kimi_vision.py`. They are included so another machine has the actual code used in the live validation, without requiring an Unreal installation.

Budget and image-validation code are unchanged. The gateway's legacy standalone CLI is disabled because its original fixed paths and initialization profiles belong to the old repository. Import `Gateway`, `KimiProvider`, `BudgetServer` and `handler_type` with explicit private configuration and a verified existing `Ledger`. This directory contains no keys, ledger, default balance or unattended launcher.

`inspect_ledger.py <existing.sqlite3>` reconstructs the immutable policy from the companion guard and verifies the existing accounting without contacting Kimi. New paid runs still require authorized request scope and carried charges; copying files is not budget renewal. See `docs/CONTINUE_ON_ANOTHER_PC.md`.
