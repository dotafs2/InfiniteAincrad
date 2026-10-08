# Original case-opening audio

This local candidate provides eight original synthesized cosmetic sounds. No
third-party recordings, melodies, samples or game audio are used. The generator
uses only Python standard-library math, seeded noise and PCM WAV encoding.
It makes no network requests, imports no synthesizer dependencies and never
plays sound on the Mac.

## Runtime contract

Add one `preload("res://fidelity/case_audio.gd").new()` instance as a child of the
persistent UI/game audio owner, then call:

- `play_open()` for the one explicitly initiated case-opening animation.
- `play_tick()` on actual card crossings; requests closer than40ms are dropped.
- `play_reveal(rarity:String)` once when the committed reward is visually revealed.
  Valid keys are `common`, `uncommon`, `rare`, `epic`, `legendary`, `prismatic`.
  Unknown keys do nothing.
- `stop_all()` when the case UI is dismissed or cancelled.

The helper never starts audio in `_ready`, after loading saved ownership, or on
focus restoration. It creates exactly two persistent AudioStreamPlayers:
`tick_voice` and `accent_voice`, each with `max_polyphony=1`. Opening/reveal
replace the accent; revealing stops the tick. The28ms tick is shorter than its
40ms rate limit. Repeated ticks never allocate new players or streams.

Both voices route through the existing `SFX` bus. `audio.gd` continues to own
saved SFX preferences, focus and application-suspension bus muting. The helper
never unmutes a bus or changes a user preference. Missing/muted SFX or muted
Master suppress new events; focus loss/application pause and muted buses stop
existing tails. Returning to the app does not replay those tails. The helper
has no currency, RNG, entitlement, reward or game-physics responsibility.

Accent gain is-5dB and tick gain is-9dB relative to the measured files. The maximum
single reveal peak after its voice gain is approximately-17.40dBFS, opening is
-18.15dBFS, and the tick is-27.42dBFS, before any downstream bus adjustment.
Even overlapping the two voices has ample digital headroom. These measurements
are electrical levels, not an assertion about perceived loudness on a phone.

## Composition

The opening combines two soft wooden latch transients and a low-pass air sweep.
The tick is a short, rounded330Hz felt sound. Reveal phrases share a warm
D-centered harmonic family and progress from two notes to five sparsely spaced
notes, with sixth/ninth chord colors for later tiers. The loudest file peak is
identical for all rarities; rarity adds phrasing and resolution rather than a
louder crash. Reveal fundamentals remain146.83–440Hz, with a quiet second
harmonic. The longest two add a faint filtered breath. Every file is non-looping
and has zero first/last samples.

## Generated files and measurements

All shipping files are mono,32000Hz,16-bit PCM. Values below are measured from
quantized output, not inferred from synthesis amplitudes. The manifest records
SHA-256, sample count, peak, RMS, DC offset, clipping count and event notes.

| File | Seconds | Peak dBFS | RMS dBFS | Bytes |
| --- | ---: | ---: | ---: | ---: |
| open.wav | 0.4 | -13.151 | -25.991 | 25644 |
| tick.wav | 0.028 | -18.416 | -29.286 | 1836 |
| reveal_common.wav | 0.46 | -12.396 | -23.834 | 29484 |
| reveal_uncommon.wav | 0.6 | -12.396 | -23.637 | 38444 |
| reveal_rare.wav | 0.74 | -12.396 | -24.082 | 47404 |
| reveal_epic.wav | 0.9 | -12.396 | -23.646 | 57644 |
| reveal_legendary.wav | 1.08 | -12.396 | -23.695 | 69164 |
| reveal_prismatic.wav | 1.24 | -12.396 | -24.003 | 79404 |

Total shipping WAV size:349,024bytes. All eight outputs contain zero clipped
samples and pass an absolute DC-offset limit of0.0002.

Reproduce or verify from the game directory:

```sh
python3 tools/build_case_audio.py --demo
python3 tools/build_case_audio.py --check --demo
```

`--check` verifies exact regenerated WAV/manifest/demo bytes and writes nothing.
The optional16-second sequence is
`artifacts/case-opening-20261008/case-audio-demo.wav`; its companion JSON labels
each of six tier segments. It combines opening, five restrained ticks and a
reveal with the same helper attenuation. It is an audio-only synthesis review,
not gameplay capture. Creating it does not play it.

## Verification and limitations

Generation and a separate deterministic verification pass complete successfully
for all eight WAVs, the measured manifest and demo. An independent WAV-header
read confirms the declared format, duration, no clipped samples and zero file
endpoints. The helper exposes the requested four-method API, preloads the eight
fixed streams, and contains no autoplay path.

The first generator run failed the retained DC-offset assertion: the initial
short tick had mean-0.00040812 after boundary fading. The generator now subtracts
the residual with the same smooth boundary window, preserving exact zero
endpoints. The original0.0002 threshold was kept; the regenerated output passes.

This audio worker has not launched Godot, imported the WAVs, played the files,
modified UI, or tested a physical phone. Root owns engine import, lifecycle
acceptance and in-game audio/visual integration. Mac speakers remain silent
during this work. Perceived balance with the music still needs listening review
at an appropriate time; the numerical checks do not substitute for that.
