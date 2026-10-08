# Independent review of the rewritten map music

**Pass within the objective scope below.** The reviewer did not author the new composer, arrangements or assets. Review covered the actual shipped Ogg files, complete authored score, controller/bus boundary and the existing runtime suite. No speaker, browser or other audible playback was used. This cannot establish that the score is pleasant to the user or correctly balanced on phone speakers.

## Composition and signal evidence

The reviewer independently decoded both current files and their preserved originals with FFmpeg. A separate analysis checks the actual sample arrays and authored note events; it does not accept manifest measurements as expected results. An independent invocation of the composer reproduces the exact published source PCM hashes and event list, binding the score analysis to the current encoded artifact provenance.

| Observed metric | Sunny City | Snack Garden |
| --- | ---: | ---: |
| Exact decoded samples per channel | 1,628,308 | 1,568,000 |
| Duration | 36.923084 s | 35.555556 s |
| Tempo / complete 4/4 form | 104 BPM / 16 bars | 108 BPM / 16 bars |
| Decoded RMS | −24.482 dBFS | −24.487 dBFS |
| Prior decoded RMS | −17.192 dBFS | −17.879 dBFS |
| Decoded peak | −10.544 dBFS | −11.130 dBFS |
| Largest seam sample difference | 0.000395 | 0.001911 |
| Ordinary interior increment P99 | 0.011696 | 0.010256 |
| Written lead rest fraction | 55.08% | 55.08% |

Each composition has four instrument parts: 48 individual nylon chord notes, 24 bass notes, 31 lead notes and 28 brush events. Each bar uses one root-based ordinary major/minor triad, with diatonic lead notes in the stated comfortable register, and the final dominant returns to the initial tonic. This is a meaningful reduction in arrangement density, not merely a gain adjustment. The instrument synthesis has no detuned layer, metallic modes, rimshots, high bells or added countermelody. Noise is restricted to the quiet filtered brush.

The score and decoded samples pass **128 independent checks**: file/manifest hashes, format, duration, no clipping/DC, reduced RMS, small boundary jumps without a fade-to-silence gap, deterministic source PCM, all 32 bar harmonies/timings and stable inputs. True-peak and LUFS values remain the author's separate FFmpeg EBU R128 measurements; this independent receipt reports its own sample peaks and RMS rather than relabeling them as loudness or sound-pressure levels.

## Narrow runtime-test maintenance

The existing `tests/music_review.gd` expected Sunny City to last exactly 32 seconds. That was the former composition's length. The new 104 BPM, 16-bar loop lasts `16 × 4 × 60 / 104` seconds; Snack Garden at 108 BPM lasts `16 × 4 × 60 / 108` seconds.

Only that existing compound duration assertion was changed. Both durations are now derived explicitly from their score tempo/form, with the original 0.01-second tolerance. The distinct resource check remains on the same assertion. The other 117 checks are unchanged. The stale failure, original complete test, exact one-line diff and before/after hashes remain in the independent artifact folder. This is an intentional expected-composition update, not an increased tolerance or removal of a failed behavioral requirement.

The maintained **118-check runtime review passed** under Godot headless with Dummy audio and `--test`, using the release runner's strict engine-error filter. It covers real imported streams, first-input unlock, mute/focus/suspension/pause states, stream routing and lifecycle. Relevant source, assets and bus hashes were unchanged across the run. The narrow test maintenance was authorized by the parent; its exact diff is retained for separate inspection. no audio runtime, bus, music preference, SFX or asset was changed by this reviewer.

## Evidence and limits

- [Independent 128-check signal/score receipt](../../artifacts/feel-20260930/audio-independent/analysis.json)
- [Maintained 118-check runtime receipt](../../artifacts/feel-20260930/audio-independent/music_review.json)
- [Runtime provenance](../../artifacts/feel-20260930/audio-independent/runtime-provenance.json)
- [Exact test diff](../../artifacts/feel-20260930/audio-independent/duration-maintenance.diff)
- [Maintenance hashes and scope](../../artifacts/feel-20260930/audio-independent/maintenance.json)
- [Preserved stale-duration failure](../../artifacts/feel-20260930/audio-independent/stale-duration-failure.json)

No relevant implementation defect was found. Objective continuity does not guarantee an inaudible boundary on every decoder; written rests do not imply complete silence because synthesized note tails continue briefly. The existing −14 dB Music bus remains unchanged, and the new assets make music substantially quieter. The user's own audition is still needed to judge musical preference and the music/SFX balance. No phone-performance claim is made. All reviewer-owned engine and decode helpers exited.
