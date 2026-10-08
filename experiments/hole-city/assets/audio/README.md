# Six-context music

HOME, STORE, HOLES and settings retain the 88-second CC0 Shop Theme. Map thumbnail
browsing keeps this menu recording. Actual rounds switch to distinct City 90 s,
Food 112.3404 s, Toys 64 s and Frost 34.2857 s loops. Results retain the round music.
The skin case and its odds page use the 40-second original A Little Wonder loop.

One Music-bus AudioStreamPlayer streams Ogg with max_polyphony 1. A 200 ms fade-out,
silent resource swap and 300 ms fade-in avoid overlapping scores. Each track keeps
its own session bookmark. Rapid navigation settles the latest requested route.
The Music bus remains-10 dB; prepared tracks measure approximately-22 LUFS before
that bus. The case bed ducks 7 dB during rolling. Original SFX accents/ticks use
two separately bounded voices and respect SOUND independently of MUSIC.

Native iOS initializes the saved enabled preference without a browser gesture.
Web waits for a released gesture after GUI callbacks. Music is suspended for
music OFF, lost focus, app suspension, SceneTree pause or a visible rewarded ad.
SFX honors its own preference, focus, app suspension and visible-ad state.
The ad gate is set before invoking the SDK and cleared using its authoritative
in-flight state; an earned callback before close cannot resume game audio.

See MUSIC_CREDITS.txt and music_manifest.json for sources, licenses and exact
measurements. shop_theme_manifest.json preserves the old menu-source provenance.
Rebuild new tracks with tools/prepare_world_music.py using the pinned source ZIPs;
run tools/build_case_audio.py for the original cues. The preparation requires
NumPy and ffmpeg/libvorbis; it never plays audio. Original case score events,
source PCM, generator hash and tool versions are recorded in the manifest.

Signal measurements and headless state tests do not establish subjective hearing
or physical-device loudness. Review samples and real-engine capture are provided
separately under artifacts/music-worlds-20261008. Earlier rejected synthesized
music remains excluded under art_source/music/legacy-v0.11.0.
