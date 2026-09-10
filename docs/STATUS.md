# Current status

Updated 2026-09-10. Stage: repository initialization and migration preparation.

## Present

- Independent repository layout and Godot startup scene.
- One MVP scope, a single-engine direction and bounded acceptance gates.
- Migration register, world-continuity requirements and asset exclusions.
- Contributor and agent entry points.

Verification: on 2026-09-10 the startup scene ran headlessly on Godot 4.7.2 Mono for three frames and exited with code 0 with no stderr output. This checks scene loading, not visual quality, world behavior or an exported release.

## Not present

- Migrated residents, world-rule execution or save migration.
- Market-street assets, characters, movement and real player interaction.
- A model adapter, live Kimi calls, an automated token limiter or an unattended loop.
- A released game build, a fully verified second-model handoff or multiplayer.

Historical achievements in the source project must not be presented as completed capabilities here. The startup screen only demonstrates that the new project can start.

## Blocking real-world migration

The latest complete original save and carried API-cost ledger need private verification and synchronization. Public Git snapshots cannot restore that world. Offline scaffolding can proceed; a live same-world acceptance claim cannot.

Next work: the G0 feasibility and continuity checks in [ROADMAP.md](../ROADMAP.md), within a separately started, measured batch. Repository creation has not started that batch.
