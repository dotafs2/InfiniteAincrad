---
name: godot-dev
description: Build, run, and validate this Godot 4.7.2 project (tools/run_godot.py, Run-*.ps1, tools/test_*.py, docs/validation/).
whenToUse: When building, running, testing, or validating the Godot game or its Python toolchain.
---

# Godot project workflow

## Engine & entry points
- Godot 4.7.2. Run through `tools/run_godot.py`; see also `Run-NavigationMvpHouse.ps1`, `Run-SaoTownQuarter.ps1`, `Run-Street.ps1`, `StartDemo.cmd`, `StartLiving.ps1`, `StartLivingAI.cmd`, `Build-WindowsPreview.ps1`.
- Godot script fixtures live under `game/` (e.g. `game/spatial/town_street.gd`).

## Validation & tests
- Python toolchain lives in `tools/` (world_observation, gm_runner, archive_conversation, deepseek_usage, and many `test_*` / `*_test.py` suites).
- Run focused checks with pytest; validation evidence goes in `docs/validation/`.

## Process hygiene
- Record and clean up owned test/helper processes; do not stop user applications.
- Never start/stop a replacement server or kill the running harness unless asked.
