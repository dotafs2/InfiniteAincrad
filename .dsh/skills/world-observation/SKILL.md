---
name: world-observation
description: World/simulation checkpoint and lineage protocol (worlds/active.json, tools/world_observation.py, immutable checkpoints, language policy).
whenToUse: When working with the resident/GM simulation world state, checkpoints, lineage, or resident observation reports.
---

# World state & lineage

## Current world
- Read `worlds/active.json` for the active world id and paths. The active lineage is `shared:restart-20260918-01`.
- Read the current section of `ROADMAP.md`, the latest entries in `HISTORY.md`, and `docs/history/conversations/README.md` before continuing. Historical checkpoints are not current world state.

## Checkpoints & lineage
- Carry every life sequence and complete reply archive through immutable checkpoints with `tools/world_observation.py` (or the live launcher `--checkpoint-dir` flag).
- Never overwrite the original world or merge world lineages by sequence number. The original seq450 world and GM state remain on another computer; the fresh restart world is a separate lineage.
- Preserve unknown results/fees and existing unrelated files.

## Language policy
- Game names, dialogue, UI, authored model inputs, Kimi/GM natural-language outputs, new project documents, and the roadmap/flowchart are English.
- Conversation with the user stays Chinese; the explicitly requested resident observation report is also Chinese.
- Game/runtime evidence and project documentation remain English.
- Preserve original conversation archives and canonical historical evidence; use English presentation aliases for legacy names without changing resident IDs or rewriting saves.
