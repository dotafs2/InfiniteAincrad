# Sink City v0.8.0 offline showcase

The 133-second portrait MP4 shows 24 current UI states, all 44 skin assets, Sunny City geometry and NPC poses, Snack Garden geometry, and a controlled ten-second food-collapse/rain replay. It has no audio.

This is explicitly an **offline preview, not a Godot/browser/device recording**. The computer UI was unavailable while locked and the owned Godot MovieMaker probe exited before initialization. UI pixels are reconstructed from current draw commands. Offline rendering approximates lighting, rasterization and shadows. The recorded food physics poses come from current source in an isolated test: a pre-grown 3.5 m hole consumes 59 independent pile pieces while five rain waves generate 30 bodies. Scores are changed by real collection; the final test score is 122. NPC motion, opponents, decorative hole skin and game UI are omitted from that replay. UI result and skill panels use fixture state. None of these sequences constitutes a normal full-match playthrough or a phone FPS benchmark.

Every video frame carries the offline-preview disclosure. Runtime game files, the served package, user progress and the existing preview server were not changed. No code was committed or published.

## Chapters

- 00:00 Scope and version
- 00:05 Both home/map-selection screens
- 00:13 Shop and gem gift
- 00:19 All 27 Classic skins
- 00:39 All 17 Special skins
- 00:51 Locked skin, coin unlock and insufficient coins
- 01:00 Three shader-motion examples
- 01:06 Skill prompts
- 01:12 City intro and HUD
- 01:18 City opening, overview and street detail
- 01:33 Food HUD, opening and overview
- 01:46 Food-collapse and rain physics replay
- 01:56 Pause and three result states
- 02:08 Preview limits

## Verification

H.264/yuv420p, 720×1440, 24 encoded frames per second, 3,192 frames, 133 seconds, fast-start MP4. The food replay uses 12 source pose samples per second, repeated to 24 encoded frames; this does not measure game performance. Full-file FFmpeg decoding passed. All 44 unique skin IDs are asserted against the current catalog. Independent review checked UI coverage, shader crops and disclosures and corrected the gem-gift chapter caption.

See `showcase.json`, `validation.json`, each component manifest, and `chapter-contact-sheet.jpg` for provenance and inspection.
