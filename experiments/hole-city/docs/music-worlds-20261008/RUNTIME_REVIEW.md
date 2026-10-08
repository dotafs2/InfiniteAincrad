# Independent runtime and evidence review — 2026-10-08

Reviewer: the separately delegated runtime reviewer. This reviewer does not
author production audio, assets, or existing tests. The new
`tests/world_music_acceptance.gd` is independently authored here; root executes
engine jobs sequentially and returns exact candidate receipts for inspection.

## Status

**Final verdict: accept the reviewed implementation and exact local Web Review
package.** Static runtime, delivered assets, source rights evidence, focused
integration, captured mixer checks, and the completed source/package gate have
no remaining blocking finding. Gate 02 passes all 97 suites on both sides; this
reviewer independently verifies all 1,332 guarded inputs and 18 installed export
files. This document retains the initial findings, earlier candidate evidence,
and rejected Gate 01. The scope and hardware/listening limits below still apply.

## Baseline inspected

The current root roadmap, latest history entries, conversation continuity guide,
case-opening handoff, `audio.gd`, `case_audio.gd`, `case_opening.gd`, game/UI routes,
`ads_bridge.gd`, music tests, source manifest, credits, bus layout, and export
filters were read. Historical case gate results are context, not evidence for
this candidate. No user save, phone, account, publication, or physical audio
output was used by this review.

The inherited four map entries reference the same Shop Theme stream. Its
single streaming player correctly separates music preference from gesture
unlock and combines focus, application suspension, and game pause. Existing
acceptance tests explicitly expect the same recording across maps, so they
must migrate to the requested six-context behavior while retaining their
preference, save, input-order, and lifecycle checks.

The inherited documentation also says the Music bus is -14 dB, while the actual
bus layout is -10 dB. Final level documentation must use the delivered layout.

## Agreed behavior

- Six distinct recordings: menu, City, Food, Toys, Frost, and case opening.
- `set_map(id)` selects the world without changing a menu/case context.
  `set_context("menu"|"gameplay"|"case")` chooses the effective route.
- HOME, STORE, HOLES, settings, and ordinary odds use menu music. Case and odds
  opened from the case use case music. Intro, play, and round results use the
  selected map music. A rejected locked launch cannot switch the route.
- One `Music` player streams Ogg. A short fade-out/swap/fade-in bounds transitions;
  rapid requests settle on the latest route. Repeated identical requests retain
  the decoder. Returning to a prior route restores its prior valid bookmark.
- Case music follows MUSIC; event cues follow SFX. Rolling ducks music by about
  7 dB, and result/exit restores its normal level. Restored case receipts do not
  automatically replay opening or rarity cues.
- Focus, application suspension, tree pause, preference, and active native ad
  are independent suspension causes. Clearing one cannot clear another.

## Concrete findings sent to root

1. Native rewarded overlays need explicit audio suspension around the active
   presentation, because an overlay is not guaranteed to send app-focus events.
   `AdsBridge.reward_in_flight` reflects this transient lifetime. Persisted
   `reward_video_pending()` is not an audio-lifetime oracle: reconciliation can
   survive a process restart. Earned-before-close must remain suspended.
2. Route changes must be attached to actual game/UI transitions. A selected or
   locked preview cannot start gameplay music. `UI.refresh()` needs to preserve
   case context while its odds page is open.
3. Existing tests contain shared-Shop-Theme assertions. Replace those specific
   routing expectations, not lifecycle or persistence protections.
4. The final asset manifest, credits, and README must agree with encoded files,
   six actual routes, exact output hashes, runtime gain, and bus levels.

## Acceptance gates

1. Inspect all production diffs and final provenance; all six tracks must have
   unique encoded content and reproducible provenance. Downloaded recordings
   require source-specific commercial-use rights. Original synthesis requires
   an inspectable score/generator and an explicit absence of external samples.
2. Independently exercise imported resources, real four-map starts, title/case
   navigation, rapid requests, bookmarks, loops, preference/focus/app/tree/ad
   interactions, and bounded voice ownership. Keep test progression isolated.
3. Inspect decoded level/seam/noise measurements and actual candidate mix
   evidence. A numerical pass does not prove pleasant timbre or phone balance.
4. Inspect focused and exact-package receipts, with guarded source/asset hashes.
   Preserve actual failures and fixes. Passing an old package is insufficient.
5. State acceptance scope explicitly. No measured phone frame rate, native ad
   interruption, subjective listening, or physical-phone playback claim may be
   inferred from source review or Dummy-driver state tests.

## Static implementation review

The first complete runtime revision was inspected against the task's baseline
copies. The implementation has one streaming player, a 0.20-second outgoing
fade and 0.30-second incoming fade. Reversing a pending transition restores the
current voice smoothly; a newer destination wins before the stream swap.
Bookmarks are bounded by the six valid route keys. Silent route changes commit
before resume, and repeated effective routes do not replace the decoder.

`UI.refresh()` delegates route selection to `Game.sync_audio_context()`. This
covers map intro/play/results, ordinary menu pages, the case, its odds page,
back navigation, and recoverable case results. The case rolling flag changes
the music level independently of the event-cue bus. Code inspection found no
blocking error in this routing or the stacked suspension conditions.

The ad finding is addressed in code: Game sets the audio presentation guard
before calling `AdsBridge.show_rewarded()`, then synchronizes it from the
bridge's authoritative `reward_in_flight`. The bridge clears its active request
before dispatching matching close/failure and keeps it active after an earned
callback. The independent suite uses a typed fake provider to verify these
observable transitions without a real SDK.

All three downloaded source ZIP hashes match the initial production manifest.
The actual towns, march, and snow archives contain CC0 declarations from their
authors; all four saved author pages, including the retained Shop recording,
also declare CC0. No unrelated local documents were inspected. Exact decoded
candidate checks and final documentation review remain pending the final asset
revision; the first candidate's measurements do not approve later encodes.

## Candidate 04 file and focused engine evidence

The final six-role manifest has SHA-256
`a03739163acb247885c5f0fca7a3532c1ddcbf15ec2abe7665b42664e625b7b4`.
Its duplicate in `worlds/manifest.json` is byte-identical. The generator hash
matches the actual script and records NumPy/ffmpeg versions plus original case
PCM provenance. Both music-credit copies, the native credits UI, current README,
export filters, and preserved separate Shop source manifest were inspected.
They now consistently describe the actual six roles and -10 dB Music bus.

Independent ffmpeg/NumPy and WAV decoding is retained in
`build/music-worlds-20261008/reviewer-runtime/candidate-04-signal-review.json`.
All six delivered hashes match the manifest. The files total **5,532,402 bytes**;
each decodes to the declared frame count with finite samples and zero samples
at or above full scale. The actual Music/SFX bus and player gains imply these
conservative simultaneous-peak bounds:

| Combination | Maximum absolute sample bound |
| --- | ---: |
| Opening phrase + tick + ducked case score | 0.2113 |
| Largest reveal + tick + full-level case score | 0.2782 |

These deliberately sum independently occurring maxima. They establish ample
digital headroom for this case mix, not perceived balance, physical loudness,
true-peak certification, or absence of audible clicks on an early skip.

All five new Ogg files decode with empty ffmpeg error output. The retained,
byte-unchanged Shop recording emits eight non-monotonic timestamp warnings when
ffmpeg muxes raw PCM; the exit code is zero and its decoded 3,880,800 frames match
the declared 88 seconds. These inherited diagnostics are preserved separately
in `candidate-04-decoder-diagnostics.json`; they are not silently counted as a
clean log. Actual Godot packet identity and loop checks also pass.

Root executed this reviewer's unchanged independent suite with the actual
engine: **174 checks, zero failures** in
`artifacts/music-worlds-20261008/focused-01/world_music.json`. The receipt records
six unique imported packet hashes, 5,745,068 serialized packet bytes, an actual
loop position of 0.06578 seconds after crossing the end, and exactly -7 dB case
ducking. All four real map intros, play phases, results and HOME returns pass;
case/odds/receipt restoration, early reveal, independent preference controls,
fade/bookmark/latest-route behavior, and fake-provider ad callback ordering pass.
The engine log contains only the existing specifically allowlisted macOS CA
certificate error; there is no music/script error in this run.

The earlier legacy `music` suite failed because its resource fixture selected a
gameplay context before `Game.select_map()` refreshed the title UI back to menu.
Its corrected `focused-02` receipt passes 129 checks. The migration diff is
limited to routing expectations; existing input, save, preference and lifecycle
protections remain. Focused review 120, retained Shop 55, case audio 122,
application lifecycle 70, native polish 1,050, and credits 37 also pass. The
independent real map-route checks above were already passing. The earlier failed
run is preserved and is not counted as a successful candidate.

Reviewed runtime hashes at this point:

- `audio.gd`: `31fb19271252d35ce7fb1d690cb114ac45976634a278a85b0b3181dfada6793b`
- `game.gd`: `94809ca047ecc4918e2a5a167bb8b2b431f4a245c6c950141fb54cc37c0b71b9`
- `ui.gd`: `5836a174c59cbcd9d9afe3eed7101efd9abe9a0008cc95ddef3981ec756efc49`
- Independent suite: `aa13cc96985c4bc937508400b6bfbbfd5e6e297e2d27dabf97273daf46956c75`

## Actual mixer and skip review

The actual Mac MovieWriter capture is
`artifacts/music-worlds-20261008/capture-01/`. Its map sections are six-second
**intro-scene** samples, not ordinary gameplay or full-round SFX demonstrations.
The case section contains one complete roll, a second opening, and an actual
early reveal after 1.5 seconds. The isolated fixture spends exactly two 100-coin
draws, from 500 to 300, without a player save or real SDK.

Independent analysis of `mixer.wav` confirms 45.35 seconds of stereo 48 kHz PCM,
a peak of **0.1590576**, and zero clipped samples. The 200 ms window centered on
the early skip has peak 0.1542358 and maximum adjacent-sample change 0.0053711.
Root's narrower 160 ms window reports a compatible smaller step. These are
objective capture results; neither reviewer listening nor speaker balance is
inferred. The video contains matching 45.35-second AAC audio and 540 by 960 H.264
video. Independent receipt:
`build/music-worlds-20261008/reviewer-runtime/capture-01-independent-review.json`.
The captured PCM hash is
`911333e6d292766f0222487cc314a1d26d011c6dff9b2d5c3434c848c3041143`.

The independent suite now adds four bounded in-memory native decoder checks per
new map, covering samples, actual end crossing, continued playback and release.
This closes the distinct-new-file loop-boundary gap. The inspected
`focused-03/world_music.json` receipt passes **190 checks, zero failures**. Each
map's actual native decoder returns 17,640 frames, records one loop, continues
about 0.3505 seconds into the next phrase, and stops explicitly. Peaks across
those decoded windows range from 0.1921 to 0.3951. The suite's final SHA-256 is
`243594d9074662aed3bb343e0a7fe1c66b9272929223dd0e8a53c38c0df35858`.
No production change resulted from this final test addition. Test/runtime inputs
are now frozen for the full source and package gate.

**Input readiness verdict at that checkpoint: accept.** No further production fix
was requested. Exact-package evidence was still pending. No physical-phone performance,
native ad SDK interruption, subjective audition, or complete gameplay mix
certification is included in this verdict.

## Gate 01 rejection and teardown diagnosis

The first full gate correctly rejects `source-coin_skins`: its 1,701 behavior
assertions pass, but engine exit retains four Ogg-related objects and one
resource. The strict resource-error check was not suppressed. Verbose focused
reproduction 04 identifies `OggPacketSequence`, `AudioStreamOggVorbis`,
`AudioStreamPlaybackOggVorbis`, and `OggPacketSequencePlayback`, all associated
with the retained menu recording.

Root and this reviewer independently identify the same fixture race: the test
starts a case-to-menu transition, stops the audio player and drains the mixer,
then awaits a frame with the controller still processing. Completing the
pending route in that frame creates another decoder immediately before free
and process exit. The old single-recording implementation had no such pending
route swap. This is not evidence of a transaction or save failure.

The narrow correction disables processing only on the test-owned audio
controller after every behavioral assertion and before the existing stop/drain.
The production code, transaction assertions and strict exit check remain.
Inspected `focused-05/coin_skins` passes 1,701 checks; the verbose output no longer
has an ObjectDB leak or resource-in-use error. Six additional test endings with
an explicit recent map/menu transition followed by stop-and-await were reported
to root for the same terminal cleanup review. No blanket assertion weakening,
runtime workaround, or dismissal of the failed first gate is accepted.

The six corresponding terminal edits are now inspected and accepted in
`retention_ui_review`, `food_growth_review`, `boost_review`,
`train_surface_review`, `train_review`, and `review_ui_collection`. Each freezes
only its own controller after the final behavioral assertion and before the
existing drain/free. In `train_review`, each subsequent map creates a fresh
game/controller. All seven corrections leave production code and tested behavior
unchanged. Gate 02 is the required replacement full gate; Gate 01 remains failed.

## Final exact-package acceptance

Gate 02 completes **97 source suites and 97 exact-package suites**, with
**176,645 checks and zero failures on each side**. The independently authored
`world_music` suite passes all 190 checks in the exported package. The migrated
music suites pass 129, 120 and 55 checks; case audio passes 122; lifecycle passes
70; native polish passes 1,050; release information passes 37. The seven narrowly
corrected cleanup fixtures also pass the strict exported-package gate. An
independent scan of all source/package logs finds no ObjectDB leak,
resource-in-use message, script error, parse error, or failed resource load.

This reviewer separately hashes every guarded input and installed artifact,
rather than relying only on root's verification summary. All **1,332 source and
asset files** and **18 export files** match the release manifest. Native,
source-audio and exported Web music credits are byte-identical. The final
assets manifest remains unchanged from the accepted audio candidate.

- Release receipt: `artifacts/music-worlds-20261008/web-gate-02/release.json`
- Release receipt SHA-256:
  `f632d1b896a8d0a3d9327967a14123538d9550a7c8f0456f4794d63015aabace`
- Installed package: `build/music-worlds-20261008/web/index.pck`
- Package SHA-256:
  `93cb5584e3b618c5779a5f5eecaaf3dea32495888c1be05fb5cc112587d759af`
- WebAssembly SHA-256:
  `f6090f055e16765bcef5dc3a031f68ab40c151d9e7f0541d9d7eb61e92dc5051`
- Music manifest SHA-256:
  `a03739163acb247885c5f0fca7a3532c1ddcbf15ec2abe7665b42664e625b7b4`
- Independent final receipt:
  `build/music-worlds-20261008/reviewer-runtime/final-package-review.json`

**Acceptance: yes, with no outstanding blocking fix.** This covers six distinct
music routes and their provenance, one-voice transitions and bookmarks,
preference/focus/pause/ad-protocol behavior, bounded compressed assets, case
cue/duck interaction, measured Mac mixer output, and the exact exported game
under the native headless engine. The movie's map sections remain intro-scene
evidence. This acceptance does not certify subjective audition, ordinary
full-round mix, browser audio execution, physical-phone performance or speaker
balance, or a real native advertising SDK. Those limits are not silently
converted into successful test claims. No engine or production input was changed
to write this final review.
