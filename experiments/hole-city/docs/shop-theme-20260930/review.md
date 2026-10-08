# Shop Theme independent review

Reviewer: Sagan, separate from the runtime/asset author.

**Source status: PASS — 298 strict checks across three audio suites.**
**Actual exported package content: PASS — 12 strict checks in a separate isolated working directory.**
**Actual package runtime music: PASS — all 298 checks and strict logs independently reviewed against the unchanged source inputs and exact published PCK.**

## Selected recording and license provenance

I independently read the creator's [Shop Theme page](https://opengameart.org/content/shop-theme) and the linked [CC0 1.0 deed](https://creativecommons.org/publicdomain/zero/1.0/). The source credits Cleyton Kauffman, declares CC0, and identifies the recording as looped. It provides normal and Radio Edit versions. The selected file is the normal `shop_theme/Buy Something!.ogg`; the download has no separate license-text member, which the shipped credit correctly discloses. The original embedded artist name is Cleyton R. Xavier; the public credit follows the creator's page. No original-composition or creator-endorsement claim is made for this replacement.

Independent ZIP extraction matched the selected member byte for byte. Source archive SHA-256 is `127e5556a7ef9d944e5a44b012ffc6f833fa673c4c2091b71909159b9965c836`; normal member SHA-256 is `fa023f1d2e3d3194136bb8f877925d5547e5489439b24658698fbbb458de5b21`.

## Actual recording and reproducibility

The delivered file is 1,194,690 bytes and retains all 3,880,800 stereo frames at 44.1 kHz: exactly 88 seconds. Independent complete FFmpeg decoding measured RMS −23.7236 dBFS and sample peak 0.42631. Its waveform correlation with the full normal source is 0.997485 after the declared constant −7.1 dB gain and Vorbis quality-3 conversion. The least-squares measured gain is −7.136 dB, including encoding error. No clipping, truncation, extra instruments, arrangement changes, tempo change or edge fade was found.

The decoded wrap boundary sample jump is 0.019625. The original recording's jump is 0.043930, below its ordinary adjacent-sample p99 change of 0.070260. These are objective waveform observations; they do not prove an inaudible seam or a pleasing subjective mix.

The raw FFmpeg PCM muxer reported non-monotonic timestamp messages. A separate decode using only `asetpts=N/SR/TB` produced **byte-identical PCM**, establishing that this measurement-clock adjustment did not alter samples. Both raw diagnostics remain in the independent recording report.

I ran the preparation helper again into an excluded artifact directory. The regenerated Ogg container hash differed because of its serial, as documented. Independently reconstructing all 5,523 Ogg packets found every packet byte-identical; the full decoded PCM was also byte-identical, SHA-256 `da9fee86734574b240b2c101582b8b3e19f60520e57ae679b1c1d59b5f00e57c`. The helper pins both archive and member hashes, validates the full length and bounded output, and writes only the requested output directory. Its source measurement clock change affects diagnostics, not encoded audio.

## Runtime and maintained fixtures

Both map entries now reference the same `SHOP_THEME` resource. `set_map` updates the selected map but skips stream reassignment when the source resource is identical. Gesture release ordering, independent music/SFX preferences, compound focus and suspension handling, pause behavior, save format and the single streaming player remain unchanged. The Music bus is still −14 dB; SFX and Master gains are unchanged.

The 125-check acceptance and 118-check independent UI/lifecycle review each replace exactly two obsolete distinct-track expectations with the explicit shared-recording policy. All remaining assertions, timing, real input events, isolated-save checks and cleanup are unchanged. The map-change assertions additionally require decoder and nonzero playhead preservation. Exact before copies and diffs are retained.

| Strict source suite | Checks | Result |
| --- | ---: | --- |
| Existing music acceptance | 125 | PASS |
| Existing independent music/UI review | 118 | PASS |
| New independent Shop Theme shared-track review | 55 | PASS |

The new review fingerprints the real imported Vorbis packets (`5d0053ae1d9ee3c8627fe9f6cfecd9f0126fc6c9eaae65ad47b01c7049f71fe0`). It checks locked map switches, actual stream and decoder identity, a nonzero playback bookmark through repeated switching, every music/focus/app-suspension combination, SceneTree pause, invalid-map rejection, and one retained player.

A separate native `AudioStreamPlayback` decoder mixed 17,640 actual stereo frames across the encoded end entirely in memory. Its loop count reached 1, playback continued at 0.350544 seconds, samples remained finite and nonzero, and peak was 0.305156. This verifies Godot's actual imported Vorbis loop rather than merely inspecting a metadata flag. The decoder was stopped afterward.

All source helpers used `--headless`, explicit `--audio-driver Dummy` for playback tests, `--test`, and absolute logs. All eight reviewed runtime/asset/helper/test hashes were identical before and after the 298 checks. Sessions 69405 and 40648 exited 0; no owned helper remains.

## Evidence and limits

Evidence resides in `artifacts/shop-theme-20260930/review/`: `source-provenance.json`, three `*-source.json` and strict logs, `source-independent.json`, `recording-independent.json`, `helper-rebuild-independent.json`, and the two maintenance diffs. The actual exported package includes the recording manifest, README and music credit, byte-identical to the reviewed source; its independent package receipt is described below.

No browser or native UI was operated, no user speakers were used, and no subjective audition or phone performance measurement is claimed. Headless engine state does not certify browser autoplay or audible device output. The full source/PCK release gate is root-owned.

## Reviewed source hashes

- `fidelity/audio.gd`: `bea6a9936b26ea6569348b24882b8ec687b61205c652bcf86194bcb9ab988620`
- `fidelity/audio_bus_layout.tres`: `a8b1b249f22929c4305c60424b0c35a0b1734c1ed5d7b1ab36fa2348d0bf4c56`
- `assets/audio/shop_theme_loop.ogg`: `0e5af2a8c1ea6969bfcadbd727e33a4c7f87379aa211b465322f98f026538b02`
- `assets/audio/music_manifest.json`: `21cd9b52c6835674db60c2304744b314cd14e8556e31e5e2cda86d04317ac087`
- `tools/prepare_shop_theme.py`: `d20373677ef42390bcc55c652dbb816fbbd2e4f2e57b9e8044682968578d340f`
- `tests/music_acceptance.gd`: `9d3bdb3998bbe2f6fde080ce144d3dc0303111505d84cb82208bad4cc2ace02d`
- `tests/music_review.gd`: `332fd6dbabed0774e82367cb37fe7a3cb51244bf726298516797a58e488faf52`
- `tests/shop_theme_review.gd`: `b12adc3eb783f5b049c0064a1ebf1713e1938510fa80f2c4ade3a0d8787bc688`

## Actual exported package contents

The independent content probe loaded only the actual candidate `build/qa-candidate-f_00f11j/index.pck` through an absolute `--main-pack` argument, with no source-project `--path`, from a fresh isolated `/private/tmp/shop-package-review-*` working directory. That directory was removed afterward. The PCK SHA-256 was `31f638ff480f368d9bdb32462aa279285cf388972277ed2b32ecaf46a212be7e` both before and after the probe.

All 12 strict checks passed. The package has exported `project.binary` without the source `project.godot`. Its actual Ogg resource retains the same 88-second length and independently pinned Vorbis packet fingerprint. `MUSIC_CREDITS.txt`, `music_manifest.json` and `README.md` are present and match their reviewed source bytes. Both old synthesized-track resource paths and the excluded `art_source/music/legacy-v0.11.0` directory are absent.

The first artifact probe had one instrumentation failure: it expected `OS.get_cmdline_args()` to expose the already-consumed `--main-pack` engine option. All 11 audio/content assertions passed in that first attempt. The failed receipt and exact original probe remain under `package-first-argument-probe/`. Only that identity assertion was replaced with the exported-binary-project check; no audio or content assertion was weakened. The external runner separately binds its exact absolute package command, isolated working-directory construction, and before/after PCK hash. Root reviewed and authorized this instrumentation correction.

Evidence: `package-content.json`, `package-content.log`, and `package-content-provenance.json` under the review artifact directory. The helper exited 0 and left no owned process. At the initial content-probe cutoff the root-owned package gate was still running. Its three completed music-suite reports and logs have now been independently verified as described below; the original intermediate receipt remains unchanged as a historical record.

## Final package runtime receipt review

All three actual package music suites passed: `package-music` **125**, `package-music_review` **118**, and `package-shop_theme_review` **55**. I read each JSON report and complete log, required its single exact completion marker to equal the JSON, checked its exact expected count and empty failures, and ran the release helper's strict error detector. All three logs had no unexpected engine errors. Their exact log/report hashes are retained in `package-runtime-receipts-independent.json`.

The exported native-decoder result matches source: 17,640 mixed frames, one completed loop, position 0.350544 seconds, finite nonzero samples with peak 0.305156, and the same encoded packet fingerprint. No additional engine run was needed to repeat completed root-owned tests.

While the read-only receipt review started, the full gate completed local publication and removed its temporary candidate directory. I therefore hashed `build/web/index.pck`: it is byte-identical to the previously independently probed candidate, SHA-256 `31f638ff480f368d9bdb32462aa279285cf388972277ed2b32ecaf46a212be7e`. The completed release manifest records that same PCK hash. All eight audio/asset/helper/test inputs still match both the original independent source receipt and the release manifest's frozen input inventory.

The completed root-owned release manifest reports 53,843 source and 53,843 package checks, with no failures. This narrow independent review verifies the three music suites and the 12 package-content checks; it does not claim to have separately re-reviewed every unrelated scene suite. No engine or other helper was started during this final receipt review. All owned helpers remain stopped.
