# Independent music acceptance

Status: PASS, 125 checks, `MUSIC_ACCEPTANCE`, strict release runner. Final test and runtime/resource hashes are in `acceptance-provenance.json`; receipts are `music-phone-target.json` and `music-phone-target.log`. All owned helpers exited.

The test instantiates the real game and UI, retaining natural UI/game processing. Round physics is disabled for this audio-specific fixture; neither gameplay performance nor sound quality is inferred. All persistent tests use owned temporary configuration files and remove them afterward. The player's progress path is explicitly empty in default `--test` mode.

- Actual imported Ogg packets differ: city is 32.0 seconds, food is 34.285713 seconds. Both are streamed and loop-enabled. The food stream was additionally seeked to 30 ms before its encoded end; after 150 ms wall time it remained playing at 0.158662 seconds, demonstrating an actual decoder loop in this native headless session.
- A real touch press leaves music locked; release enables the sole BGM voice. Map selection and preference/focus restoration cannot bypass the initial gesture gate.
- Real Home and Pause music/SFX controls receive input, fit the portrait viewport, have separate rounded targets of at least 44 physical points after scaling the 540-wide design to a 375-point phone, and remain actionable while paused.
- Five menu cycles, same-map selection, and both maps' round entry/return preserve the existing player, stream, decoder and nonzero playback bookmark. Switching maps changes the song without adding a music player.
- Pause, lost focus and preference mute combine without unintended restoration. SFX remains independently controlled and muted in the background. Actual collection and food-impact players are on the SFX bus.
- Four independent preference combinations survive cold config reload without changing coins, gems, stage, ownership, equipped skin, progress or map. Unknown future config sections survive. Save failure rolls back flags/applied state and preserves the valid file bytes. Legacy saves default both audio preferences on. A cold real game creates exactly one player, restores disabled preferences and establishes a fresh gesture gate.

## Preserved initial failure and fixture correction

`acceptance-first.*` retains seven no-restart failures. The test captured an `AudioStreamPlayback` object before its own explicit `seek()` call. Godot creates a replacement decoder for this intentional seek: observed IDs changed from -9223371961256637234 to -9223371961139196946 while playback position was 3.002903 seconds. The corrected fixture establishes its identity oracle after its own seek. All menu/start/home identity and nonzero-position assertions remain; no runtime change was made for this test correction. The actual loop check raises the count from 124 to 125.

Strict diagnostics passed with only the release runner's existing exact macOS CA-certificate exception. Tests stop music and give the audio thread 120 ms to release its stream before teardown. No decoder/resource leak exception was added.

This is native headless resource/state/input verification. It does not establish audible mix quality, browser user-gesture compatibility, mobile audio interruptions, or phone performance. Those remain separate listening/device acceptance.

## Phone-target and existing-test follow-up

The full gate rejected the first home/pause audio sizes at the existing 375-point touch standard. The runtime author increased the audio targets to 64 design pixels (44.444 physical points at that width), moved the home row to y=20, and used the smaller home-label font. This review's touch assertion now tests both dimensions using `size * 375 / 540 >= 44`; it no longer accepts merely 44 design pixels. The full UI geometry suite passes 1,673 checks, covering safe margins and non-overlapping controls on home, pause, collection and results. Music retains all 125 checks.

Actual input now starts a streaming decoder in older tests. Ten files were copied before maintenance to `test-maintenance-before/`. Eight additional real-fidelity input tests received only a final music-stop/120 ms decoder-drain before their existing cleanup; no runtime or log whitelist was changed. `ui_redesign_acceptance.gd` also explicitly changes the home count from seven to nine for the two new controls. The old-main `tests/acceptance.gd` does not instantiate the new audio game and was not changed. `music_review.gd` remains owned by its independent author.

The portrait follow-up identified three old positional button references. The paused first button is now MUSIC, so emitting its signal could not resume the round and the subsequent walking tests remained paused. The final fixture locates PLAY, pause-action and KEEP PLAYING by their semantic identity. Because refresh legitimately frees the previous controls, existence is captured before emit rather than tested on a stale reference after frames. All original thirty checks remain; natural Walk/Run/Idle observations pass. Both failed attempts and intermediate source files are preserved. No runtime UI ordering was changed to accommodate a fixture.

Focused strict runs pass music 125, UI redesign 1,673, coin skins 403, skin skill 130, portrait 30, and independent UI collection 156. Four non-gate historical helpers received parse-only checks; these are not claimed functionally current (the old full fidelity helper has other historical positional assumptions outside this task). No capture helper was executed. Final before/after hashes, complete maintenance diff, and scope are in `test-maintenance-*` files. External review of the maintenance diff belongs to root/Sagan. All owned helpers exited.
