# Sink//Field skin systems handoff

The current source is on branch `hole-city-fidelity-20260924`, with the upload commit described by the parent task after this snapshot. The remote branch is `origin/codex/hole-city-fidelity-20260924`; no merge into `main` is implied.

## Delivered in this handoff

- The portrait game now has ten named skins with score unlocks, guarded selection, cooldown feedback and separate gameplay abilities for Copper Ring, Moss Bloom, Gravitas, Lantern and Shard.
- The skin library and live player share `fidelity/skin_visual.gd`. Each skin has an authored material profile or geometry treatment: void, metal scan, organic wave, gravity thrum, beacon glow, crystal facets, Cinder flame crown, water rings, orbital glints and Prism Vale color facets.
- The selection screen uses a 492x186 live preview, wrapped English skill and play descriptions, unlock progress and cooldown copy. Gameplay shows the selected skin and a vertical cooldown strip for functional forms.
- Pedestrian placement now uses deterministic sidewalk clusters, varied facing and independent rest windows so the city reads as a populated space rather than a single linear row.
- The delayed local progress save retains ordinary fields, validates skin IDs and falls back safely for locked or unknown selections.

## Verification

Short suites passed with zero failures: `TITLE_NAVIGATION_ACCEPTANCE` 17, `SKIN_SKILL_ACCEPTANCE` 22, `SKIN_FX_ACCEPTANCE` 31, `PORTRAIT_ACCEPTANCE` 30, `RESONANCE_ACTION_ACCEPTANCE` 13, `NO_TETHER_ACCEPTANCE` 10, `DESTRUCTION_TRAFFIC_ACCEPTANCE` 10 and `RIM_FALL_ACCEPTANCE` 25.

The isolated persistence fixture passed `roundtrip_seed`, `roundtrip_verify`, `locked` and `unknown` in separate low-priority Godot runs. Its path guard used a dedicated user-data directory; the real player save was not touched. The full `fidelity_acceptance` run, real-player cold restart, and real-device validation remain open.

The latest locally captured evidence is `tmp/mobile-preview/sink-field-skin-switch-20260927-182142.mp4` (H.264, 540x960, 30 fps, 67.03 seconds; SHA-256 `8714f1013005f134b0b2dc0165c4838270bb3605f697db6bf9438a331a1a3337`). It was recorded with actual menu input across all ten forms and decoded successfully. The 12s Cinder frame shows the flame crown, the 28s Prism Vale frame shows the enlarged crystal preview, and the 66s gameplay frame shows Shard's icy facets, pedestrians, skill countdown and cooldown meter.

## Next work

Run the full fidelity suite, validate the real player's save on a disposable profile, test on a portrait device, and complete trademark/licensing and advertising review before any release candidate. The IP review in `docs/design/hole-city-ip-review.md` is an engineering risk record, not legal advice or Apple Guideline 4.1 clearance.

The latest user-visible conversation snapshot is in `conversation.md` and `conversation.json`; `manifest.json` records its source and file hashes. The snapshot cutoff is the last visible message exported before the upload response.
