# Independent music integration review

2026-09-29: **PASS, 118 checks**, with zero unexpected engine diagnostics. The reviewer did not author or edit the runtime, UI, bus layout, or music assets. The test is `tests/music_review.gd`, marker `MUSIC_REVIEW`, minimum 118. Its stdout-only reporting and embedded setup are suitable for isolated package execution. Source execution is verified here; package execution belongs to the final release gate.

## Findings corrected during review

- The original input handler unlocked on button press before the GUI mute action completed. Root moved mouse/touch unlock to deferred release. The independent suite verifies that holding the very first MUSIC ON button does not start music, then its release completes the mute before unlock.
- A separate real keyboard probe found SPACE still started the music while holding the focused MUSIC ON button. Its release only then disabled music. The retained `keyboard-initial.log` records `started=true` during the hold. Root changed keyboard unlock to deferred non-repeat release as well. The permanent review now exercises this exact focused-button sequence and verifies no playback starts.
- Application focus and suspension originally shared one flag. They now remain independent: focus-in cannot clear an outstanding application suspension, and app-resume cannot clear focus loss. The review checks actual notifications and every combination of preference, focus, app suspension and tree pause. Effects mute also respects both background causes.

## Actual integration checks

The review dispatches input through the real viewport and actual home/pause buttons. It verifies mouse, touch and keyboard release, ignores keyboard repeat, preserves the existing playback object through mute/unmute and repeated unlock, avoids restarting the same map, changes to the food track for the other map, and retains exactly one music player across map, pause and return-home transitions. The actual imported Ogg resource loops from offset zero using explicit Stream playback.

The actual collection player and all three actual food impact players target SFX. Both Music and SFX buses send to Master; background and preference changes do not mute the other channel unintentionally. Pause-screen controls remain functional while the SceneTree is paused. Cold settings loading preserves independent preferences, progression and unknown configuration sections, using only one reviewer-owned temporary file that is removed afterward.

The full source gate subsequently caught a real coverage gap: the original 54/60-design-pixel audio controls fell below the project's 44-point mobile touch standard after scaling to a 375-point phone width. Root increased both home and pause heights to 64 design pixels and the home font to 18. The updated independent suite adds 12 checks while preserving all prior 106 assertions. The original success is retained under `before-phone-targets/` and does not certify this revised code.

For both ON and OFF labels, Music now measures `(166, 20, 112, 64)` and SFX `(286, 20, 98, 64)`. Neither covers the level badge `(24, 26, 130, 50)` or wallet `(394, 26, 122, 50)`, and their hit regions remain separate. At the actual 18-pixel font size, Music glyph width is 86/96 pixels and SFX 67/77; minimum sizes and padded glyphs fit. Both pause controls measure 174 by 64 design pixels, with their 21-pixel-font ON/OFF glyphs also fitting. At the actual 375/540 scale, every reviewed home/pause state has a minimum target dimension of 44.444 points. No screenshot or visual rendering claim is inferred from these measurements.

## Independent delivered-file decoding

FFmpeg independently decoded both delivered files to 44.1 kHz stereo float PCM. Neither has clipped samples, excessive DC offset or a silent boundary gap. The two decoded waveforms have subsampled correlation 0.001737, consistent with different recordings; this does not by itself certify compositional originality.

| Track | Duration | RMS dBFS | Sample peak dBFS | Last-to-first step |
|---|---:|---:|---:|---:|
| `sunny_city_loop.ogg` | 32.000000 s | -17.192098 | -3.405347 | 0.002788626 |
| `snack_garden_loop.ogg` | 34.285714 s | -17.878698 | -3.322780 | 0.006241310 |

The seam steps are below 0.01 and below independently sampled interior P99 adjacent steps. These objective measurements do not replace a listening session or prove an inaudible loop. `decoded-audio.json` and `check_audio_files.py` preserve the measurements and method.

## Exit cleanup and Web scope

The first 84-check run passed every logical assertion but strict validation correctly rejected an exit leak. Verbose evidence identified one still-active Ogg playback and its backing resources, with no leaked UI/game nodes. The fixed-FPS fixture stopped its own loop and allowed a bounded 100 ms audio-mixer drain before immediate engine teardown. The unchanged 84 checks then passed strict validation; the final expanded 118 checks also pass. This is test teardown, not weakened error detection or a runtime patch. Initial diagnostic logs remain intact.

The shipped Web preset uses threads. The controller explicitly chooses Stream for Ogg rather than the default Web Sample mode. Current exported engine JavaScript already contains AudioContext resume, sample pause/restart, and focus event bridges. Sample playback is not categorically unable to pause; Stream is an explicit choice here for streamed Ogg and consistent engine playback. User interaction remains necessary for browser audio unlock. [Official Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#audio-playback) and [AudioStreamPlayer pause semantics](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html#class-audiostreamplayer-property-stream-paused) support these distinctions.

No browser was opened or controlled, no audio output was captured, and no native or browser listening session occurred. Dummy/headless `playing` and playback-object state do not certify audible output, Safari autoplay permission, subjective mix quality, or phone performance. All owned helpers exited.

## Independent review of existing-test maintenance

A read-only exact comparison of all ten supplied `test-maintenance-before/*.gd` snapshots confirms only the requested changes: nine scripts gain bounded test-owned BGM shutdown, `ui_redesign_acceptance.gd` also changes its exact home-control count from seven to nine for the two separately verified audio controls, and `music_acceptance.gd` strengthens its minimum touch dimension from 44 design pixels to 44 points at a 375-point phone width. Separating adjacent `cold.free()` and `game.free()` statements in one script only permits the drain between them. No existing assertion is removed, and no failure detector or marker is weakened. Every other source byte matches after reversing those exact edits. The before/after hashes, allowed changes and full diff are recorded in `test-maintenance-review.json` and `test-maintenance.diff`. This comparison did not start another engine process.

A subsequent portrait-only fixture correction was reviewed separately after freezing. Adding audio controls invalidated the old `buttons[0]` assumption. The revised test locates actual PLAY, `pause-action`, and KEEP PLAYING controls by name/text, captures existence before callbacks refresh/free buttons, and explicitly fails on a missing control. All original 30 runtime assertions remain; source outside the exact lookup, strengthened existence checks and already reviewed teardown is unchanged. Existing `Input.parse_input_event` touch/drag actions are preserved. Pause/resume still emit real Button `pressed` signals, as they did before; this is not newly added physical click validation. The author's strict 30-check log/JSON agree and bind to current test SHA `fad35b1c658f68ef81d7ce46d2e111bb52caaefdda49d35129d72609fdda0f54`. Prior maintenance review JSON/diff are retained with `.before-portrait` suffixes; current files include this follow-up.

A further Snack Garden fixture had the same positional-control assumption. Exact comparison confirms its only change is finding the actual PLAY text and adding a null guard before the unchanged rounded-style condition (`corner_radius_top_left >= 24`). Every other source byte and every original assertion remains. The reviewer independently reran all 39 checks with strict logs: PASS, 2,588 initial edibles, 136 buildings, 48 NPCs and ten food types. Before/after test/runtime hashes remained identical; evidence is `snack-city-semantic.json/log` and `snack-city-semantic-provenance.json`. The maintenance review now contains eleven files, with its previous ten-file JSON/diff retained as `.before-snack-city`. The unrelated legacy non-gate numeric-index cases were not represented as fixed or newly verified. All owned helpers exited.

## Frozen source and evidence

Before/after hashes remained identical through the final run. Evidence directory: `artifacts/music-20260929/review/`. Final result and strict logs: `integration-phone-targets.json`, `integration-phone-targets.log`, `integration-phone-targets.engine.log`; current hash receipt: `provenance-phone-targets.json`. Original 106-check evidence and its hashes remain separate under `before-phone-targets/`.

| File | SHA-256 |
|---|---|
| `fidelity/audio.gd` | `30775280c6450bc9d3ee3cf4a03da44fe811ae4846dc1bef7b36eea6c2f618e5` |
| `fidelity/audio_bus_layout.tres` | `a8b1b249f22929c4305c60424b0c35a0b1734c1ed5d7b1ab36fa2348d0bf4c56` |
| `fidelity/game.gd` | `8256e56f4e7d602b8c9a962ad0862e7a1e38f48e08bf5e3123f195690e574a88` |
| `fidelity/ui.gd` | `528639a8531eadd50ef46aa76bcf0897c6bc9a64d9b1ad9fb6eca225ab473a91` |
| `fidelity/food_city.gd` | `c5eb2bba5632233f07d618e447061fb06e02637fdde4191f97c71de73c31f4f6` |
| `project.godot` | `845b8a8b57a3c5b7198bcd56b9cf96cb7a49dfa046d076212f4b63552e724906` |
| `tests/music_review.gd` | `7fc7b968ec9026de475a489621e96b2f4e4f858dd688352983fd41d5656dc359` |
| `assets/audio/sunny_city_loop.ogg` | `f606d1f9720ebf512fbe1f1110f70992b416a61c990823ee09955e2546df7177` |
| `assets/audio/snack_garden_loop.ogg` | `10c680b090cdef83e1520893eb41c4157ab8440d3c5b22e27610b167ce22897b` |
