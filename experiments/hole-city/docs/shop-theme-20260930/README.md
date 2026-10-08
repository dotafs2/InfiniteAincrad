# Shop Theme replacement — v0.11.1

The user selected **Shop Theme**, by **Cleyton Kauffman**, as the game's
background music. Both Sunny City and Snack Garden now use the normal version
of **Buy Something!**, which the creator's
[source page](https://opengameart.org/content/shop-theme) declares **CC0 1.0**.
This recording is third-party music; the previous original synthesized tracks
and their evidence remain archived outside the game pack.

## Behavior and processing

The full 88-second recording receives constant -7.1 dB gain and Vorbis quality-3
compression, yielding a 1,194,690-byte asset at -22.0 LUFS and -7.4 dBTP before
the unchanged Music bus. No tempo, instrumentation, arrangement, edge fade or
duration change was made. Both maps share one streaming voice. Switching maps,
entering a round and returning home preserve its decoder and playhead.

The existing first-gesture gate, separate Music/SFX preferences, paused and
background behavior and local player progress are preserved. The source ZIP,
member and shipped recording have separately pinned hashes. The author page
provides the license declaration; the ZIP has no separate license-text file.
See [music credits](../../assets/audio/MUSIC_CREDITS.txt),
[measurements and source hashes](../../assets/audio/music_manifest.json) and
[the independent review](review.md).

## Validation

Source independent review passes **298 checks**: the existing 125-check
acceptance, 118-check UI/lifecycle review and new 55-check shared-theme review.
The new suite decodes actual native Vorbis samples across the end of the track
and observes a real loop, rather than testing only the loop flag.

Each of the two existing suites changes exactly two old distinct-track
expectations to the user-selected shared-track policy. Non-author review
confirms all other checks remain intact. A separate rebuild produces identical
encoded packets and decoded PCM; Ogg container serials can differ.

The complete **77-suite source and isolated-PCK gate passes 53,843 checks in
each phase**, with **791 unchanged input hashes** and no failures. A separate
12-check package probe confirms the selected recording and its documentation
are present and both legacy tracks are absent. All 18 actual HTTP artifacts
match the tested export, including seven credited notice/page files and their
manifest. Isolation headers and WebAssembly content type are verified.

PCK SHA-256: `31f638ff480f368d9bdb32462aa279285cf388972277ed2b32ecaf46a212be7e`.
See [the final gate receipt](../../artifacts/shop-theme-20260930/release/release.json)
and [HTTP delivery verification](../../artifacts/shop-theme-20260930/verification.json).
The verifier binds each report to its final log marker and the complete artifact
inventory; old successful receipts are archived before a fresh attempt.

The [verified Web playtest ZIP](../../artifacts/release-20260930/SinkCity-v0.11.1-web-playtest.zip)
is 18,892,166 bytes and contains exactly those 18 files. Every member was read
back and checked against the release hashes. Its
[bundle receipt](../../artifacts/release-20260930/web-bundle.json) binds the final
release and delivery verification. ZIP SHA-256:
`47a865b52b624092286d217c540a6a05b70d8f057d997ac289f162b357a4ce25`.

The existing local preview is updated. Reload `http://127.0.0.1:8768/` and use
PLAY with music enabled to request playback. The loopback address is not a
remote phone URL. All owned build/review helpers exited; the existing server
and player progress were preserved.

No browser, speakers or phone were operated for this task. Headless decoder
tests do not establish subjective listening, browser autoplay, appearance or
sustained iPhone 14 performance.

## Publication preparation

The Web release process now bundles the game's license, third-party notices,
font license, music credit and packaging-engine dependency notices, with a
standalone `credits.html`. Its link is part of the temporary loading overlay
and does not add a gameplay touch blocker. A permanent game-menu entry and
actual privacy/support information remain publication work.

The notice helper's 15 tests cover byte-exact copying, links, repeated installs,
source mutation, malformed/missing input, strict engine diagnostics and rollback.
Non-author review additionally verifies the root gate integration and a real
Godot-generated notice on a copied export, with 17 smoke checks.

The prepared route is a small free Web playtest followed by native iPhone 14
testing and TestFlight. This is a planning assumption; no public deployment,
Git upload, account action or store submission was authorized or performed.
See [the release plan](../release-20260930/launch-plan.md) and
[independent readiness audit](../release-20260930/readiness.md).
