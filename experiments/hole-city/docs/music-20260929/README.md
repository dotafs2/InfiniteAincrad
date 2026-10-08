# Original map music and audio controls — v0.8.6

The active fidelity game previously created only collection pings and short
food-impact sounds. It had no background score or music player. The microphone
input setting was unrelated to the missing music.

Sunny City now uses **Sunny Side Streets**, a 32-second mallet/piano groove.
Snack Garden uses **Sugar Stack Stroll**, a separate 34.286-second composition
with a lighter arrangement. Both are original procedural recordings, authored
without downloaded music or samples. Their combined Ogg size is 571,698 bytes.
See [composition, provenance and measured waveform data](../../assets/audio/README.md).

## Runtime behavior

- One persistent streaming `AudioStreamPlayer` plays the selected map's loop.
  Re-entering the same map, pausing, returning home and opening menus retain
  playback. Selecting the other map replaces the one current stream.
- Music starts after the first released mouse/touch/key gesture. The deferred
  decision allows a first click on `MUSIC ON` to switch it off before playback.
  A saved ON preference alone never requests autoplay. Godot's existing Web
  Audio input bridge remains responsible for browser context activation.
- Separate rounded `MUSIC ON/OFF` and `SFX ON/OFF` controls appear on the home
  and pause screens. Preferences use the existing atomic progress save without
  changing coins, skins or unrelated sections; failed writes roll back.
- Music pauses without losing its playhead when muted, the round is paused,
  application focus is lost or the application is suspended. These causes
  remain independent. Background effects also mute until both focus and
  application state allow playback.
- Music uses a dedicated bus at −14 dB; collection and collision effects route
  through a separate SFX bus. Original effect levels are retained. Streaming
  avoids full-track Web Audio sample decoding and runtime music synthesis.

## Independent review

The asset author did not review runtime integration. Two other agents tested
real scene resources, audio playback objects, viewport input dispatch, control
geometry, map/lifecycle changes and isolated saves. The reviewer independently
decoded both delivered files with FFmpeg: no clipped samples, approximately
−17.19/−17.88 dBFS RMS, and bounded file-edge steps of 0.00279/0.00624.

Review exposed and corrected two input/lifecycle bugs before delivery:
focus-in could clear an independent application suspension, and starting on
keyboard press could play music before a focused mute button's release action.
Both now have permanent regression coverage. The first reviewer run also
exposed a test teardown issue: immediate fixed-frame engine exit did not give
the asynchronous audio mixer time to release the last loop. Tests stop their
owned player and drain the mixer before exit; no engine errors are waived.

The full existing UI gate subsequently rejected the initial audio controls:
their design-space heights fell below 44 points at a 375-point phone width.
Both home and pause controls now use 64 design-pixel heights, and the home
captions increase to 18 pixels. Audio-specific tests now enforce the scaled
phone target size as well. The previous seven-control home inventory becomes
nine explicitly; original navigation, no-overlap and cleanup assertions stay.
Existing input-driven tests receive the same explicit mixer teardown, with
before/after copies retained for review. The rejected gate did not publish.

## Evidence and limits

Final acceptance passes **51 suites and 34,009 checks in each of the source
and isolated-PCK phases**. The two dedicated non-author music suites contribute
125 and 118 checks per phase, including a real transition across the Ogg loop
boundary. All ten HTTP-served artifacts match the v0.8.6 release. Independent
review also verifies all eleven test-maintenance diffs without weakening the
original gameplay assertions. Failed and interrupted attempts remain beside
the final receipts.

Final guarded source/PCK counts and static delivery are recorded in
[verification.json](../../artifacts/music-20260929/verification.json) and
[release.json](../../artifacts/music-20260929/release/release.json).
The delivery verifier checks every suite receipt against its engine log, the
current source/generator/asset hashes, the independent decoded-audio receipt,
and every file served by the existing localhost preview.

These are native headless state/input, decoded-waveform and static HTTP checks.
They do not certify browser speaker output, a subjectively balanced mix or
iPhone performance. No browser inspection or indirect UI capture was attempted
under the existing saved browser restriction. Tests use only owned temporary
save files. The user's preview server and actual progress are preserved.

Reload the preview and tap `PLAY` or another control to start music. The browser
still requires a real interaction; merely loading the page remains silent.

For convenient user listening, MP3 transcodes are available for
[Sunny City](../../artifacts/music-20260929/sunny-city-preview.mp3) and
[Snack Garden](../../artifacts/music-20260929/snack-garden-preview.mp3).
These previews use the recording's original loudness; the game applies its
−14 dB Music bus gain. They are separate review artifacts, not additional
shipped music resources or evidence of an actual device listening session.
