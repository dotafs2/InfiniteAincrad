# Original map music

Two short instrumental scores were authored for Sink City on 2026-09-29. The melody, harmony, arrangement, synthesizer and percussion are defined in [the generator](../../tools/build_music.py). No third-party music, samples, recordings, downloads or cloud generation were used.

| Map / asset | Composition | Duration | File size |
| --- | --- | --- | --- |
| Sunny City — `sunny_city_loop.ogg` | **Sunny Side Streets**: 120 BPM, C major, rounded wooden mallets, electric-piano chords, plucked answers, bass and a light shuffled rhythm | 32.000 s | 290,770 bytes |
| Snack Garden — `snack_garden_loop.ogg` | **Sugar Stack Stroll**: 112 BPM, F major, softer glass/wood lead, brighter register, lighter percussion and more space between phrases | 34.286 s | 280,928 bytes |

Both scores have 16 authored melody bars in 4/4 over an eight-bar chord progression, repeated with melodic variation. The intended character is cheerful and gentle. The second track uses a different key, melody, chord sequence, lead timbre and percussion density; it is not a pitch-shifted copy of the first.

## Ownership and reuse

The two generated recordings and their authored composition are offered under **CC0-1.0**, to the extent any copyright or related rights apply. They can be used, edited, distributed and included in this game without attribution. The generator contains the complete authored source and uses no third-party musical content. NumPy and FFmpeg are build tools, not sampled content in the recordings. Their own licenses continue to apply to those tools.

## Rebuild

Requirements: Python 3 with NumPy, plus `ffmpeg` and `ffprobe` with `libvorbis`. No network access or installation is performed by the generator.

```sh
python3 tools/build_music.py
```

Use `--output /absolute/directory` to produce a separate verification copy. The default output is this folder. Temporary encoding files are removed automatically. The manifest records the exact generator SHA, NumPy and FFmpeg versions, PCM SHA, encoded SHA, musical structure, instrument event counts, and decoded-file measurements. Byte reproducibility is checked on the recorded local toolchain; different codec/library versions may produce different encoded bytes.

The synthesis uses wrapped note tails, periodic room reflections and periodic master filtering. A 2.5 ms raised-cosine guard at each file edge limits independent Vorbis boundary-window error. This is shorter than the lead attack; there is no bar-long fade-out or silent loop padding. The final bar resolves musically into the first bar. Metadata contains `LOOPSTART=0` and the exact sample count in `LOOPEND`.

## Integration

The resources are stereo Ogg Vorbis at 44.1 kHz, encoded at libvorbis quality 3. Total compressed size is 571,698 bytes (558.3 KiB); each asset is below the 500 KiB generator budget. The project exports all resources, so imported Ogg assets are compatible with its current resource export policy.

Set the loaded `AudioStreamOggVorbis.loop` to `true` and `loop_offset` to `0.0` explicitly. Embedded loop tags alone are not a replacement for the Godot playback configuration. Use the engine's streaming playback path and one active music player. Runtime startup, first-user-gesture handling, mute/volume persistence and map transitions belong to the music controller rather than the asset generator.

An initial player gain of approximately **−14 dB** is suggested as a conservative starting mix. This is not a listening-approved balance: the existing collection effects are quiet, and music/effects should be balanced together during an authorized listening session. Do not normalize again automatically merely because the music uses headroom.

## Decoded audio checks

These measurements are from the delivered Ogg files after decoding, not only from the input PCM. LUFS and true peak use FFmpeg's EBU R128 analysis.

| Metric | Sunny City | Snack Garden |
| --- | ---: | ---: |
| Samples per channel | 1,411,200 | 1,512,000 |
| RMS | −17.192 dBFS | −17.879 dBFS |
| Integrated loudness | −15.3 LUFS | −15.8 LUFS |
| True peak | −3.4 dBTP | −3.3 dBTP |
| Clipped samples | 0 | 0 |
| Largest last-to-first sample step | 0.002789 | 0.006241 |
| Interior adjacent-sample step, P99 | 0.031943 | 0.034532 |
| RMS across the 20 ms boundary window | −19.667 dBFS | −20.900 dBFS |
| Maximum absolute DC offset | 0.0000358 | 0.0000401 |

Each track passes ten generator checks: exact decoded sample count, format, duration, file budget, clipping/headroom, RMS range, small boundary step, DC offset, absence of a silent boundary gap, and finite samples. The seam step is both below 0.01 and below 1.5 times the interior P99 step. These are objective safeguards against an obvious discontinuity; they do not prove a listener cannot hear the loop.

[music_manifest.json](music_manifest.json) contains the full precision measurements and source binding. No native playback, browser audition, speaker capture, subjective listening acceptance or mobile CPU/GPU performance test was performed while authoring these assets.
