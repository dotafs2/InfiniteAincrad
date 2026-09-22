# Axe-day dialogue preview validation

This isolated scene is a visual replay fixture for Rowan (`shared:carpenter`) and Flint (`shared:smith`). It uses the existing primitive `trial_resident.gd` hand sockets and procedural forge-yard meshes. The scene dynamically calls `game/demo/axe_day_demo_runner.gd` once with the bounded interface `await runner.run(host, mode)`, then displays the runner's returned steps. Spoken text, proposed aliases, and result receipts remain separate in the UI.

The screen is labeled `SCRIPTED REPLAY • no live AI • arrival simulated`. `N`, `R`, `S`, and `F` advance, replay, or request the success/refusal fixture modes; replay is manual and finite. On every returned step the axe follows the supplied `custodian_id`, clearing both residents' right hands first; its supplied `edge` controls whether the displayed axe is damaged or repaired. Flint's hammer stays in the left hand. Missing or failed runner output is shown as an error and preserves unknown runner flags rather than inventing success, source preservation, or call counts. The UI exposes `source_unchanged` and `paid_calls` from the returned fixture result.

The integrated structure test passes 26 checks: scene actors, formal IDs, initial damaged axe, actual success report, custody changes with the opposite hand cleared, repaired collection, and refusal custody. The scene has explicit error handling; this suite does not inject a missing runner.

```powershell
$godot = 'D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
& $godot --headless --path game --script res://tests/axe_day_dialogue_preview_acceptance.gd
```

When the runner is present, a compatibility-renderer capture can be made off-screen with the existing Godot wrapper, for example `--rendering-method gl_compatibility --position -2400,-1400 --resolution 1400x900 -- --capture-dir=<absolute-output-dir> --capture-step=8`. The preview selects the requested returned step, waits for `RenderingServer.frame_post_draw`, and writes a screenshot only from a real rendered viewport. It records the runner's actual result dictionary and does not synthesize a screenshot or a successful result in headless mode.

## Verified rendered result

Three off-screen OpenGL captures were produced and visually inspected at 01:44 China time:

- [Interrupted work: Flint holds the axe; 2 Col remains escrowed](axe-day-preview-20260923/work/work_interrupted_step_06.png)
- [Collection: Rowan receives the repaired axe; payment settles](axe-day-preview-20260923/collection/collection_step_09.png)
- [Missing iron: the damaged axe stays with Rowan](axe-day-preview-20260923/refusal/refusal_step_04.png)

Each directory includes the actual runner report in `evidence.json` with
`screenshot_saved: true`. The runner suite passed 7 checks including a deliberately
failed arrival; the preview suite passed 26. All final wrapper-owned engine processes
exited cleanly and final stderr was empty. The parent compared SHA-256 for the active
world selector, immutable genesis, seq266 checkpoint, private current world and two
pre-existing edited user files; all six remained unchanged.

The actors and yard are primitive placeholders. Playback is manual, dialogue and
choices are authored, and arrival uses `host_move`; these images do not demonstrate
model-generated conversation or physical autonomous navigation.

To open from the delivery root using the project's Mono engine:

```powershell
& 'D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe' --path game --rendering-method gl_compatibility res://scenes/axe_day_dialogue_preview.tscn
```
