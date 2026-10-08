# Pedestrian swallow investigation — 2026-09-28

Result: **PASS, 120 checks across ten actual scene cases**. No reproducible pedestrian swallow defect was found in this targeted sample. This result distinguishes walking residents from AI rival holes; the latter use a different combat path being revised separately.

The unmodified scene built each real map. Two actual imported resident roles per map walked first, then either the stationary opening was positioned under them or the actual player controller chased from three metres away. Both the starter radius (0.85) and score-30 radius (1.65) admitted the residents' 0.26 footing. Tests retained map geometry, query admission, ordinary citizen update, real gravity and terrain collision, collection signal, score accounting and node deletion. Food rain remained enabled. Other holes were inactive only to isolate collection ownership. Walking-window elapsed anchors avoid a legitimate rest period; no NPC position, velocity, collider or claim was fabricated.

Every case observed real route displacement and imported Walk animation before approach, then claim ownership, physics release, downward velocity and exactly one player collection receipt after the complete body crossed y=-3.5. Underfoot capture completed in 47–48 fixed physics frames; the two pursuit cases completed in 81–83 frames. These are controlled simulation frame counts, not device performance timings.

| Case | Radius | Prior walk (m) | Claim frame | Collect frame | Top at collection (m) |
|---|---:|---:|---:|---:|---:|
| city/starter/police/underfoot | 0.85 | 0.387 | 0 | 48 | -3.620 |
| city/starter/thief/underfoot | 0.85 | 0.387 | 0 | 47 | -3.540 |
| city/grown/police/underfoot | 1.65 | 0.387 | 0 | 48 | -3.620 |
| city/grown/thief/underfoot | 1.65 | 0.387 | 0 | 47 | -3.540 |
| city/starter/police/chase | 0.85 | 0.387 | 24 | 83 | -3.572 |
| food/starter/chef/underfoot | 0.85 | 0.659 | 0 | 48 | -3.652 |
| food/starter/delivery/underfoot | 0.85 | 0.533 | 0 | 47 | -3.502 |
| food/grown/chef/underfoot | 1.65 | 0.659 | 0 | 48 | -3.652 |
| food/grown/delivery/underfoot | 1.65 | 0.533 | 0 | 47 | -3.502 |
| food/starter/chef/chase | 0.85 | 0.659 | 23 | 81 | -3.666 |

Evidence: `pedestrian_probe.gd`, `pedestrian-probe.json`, `pedestrian-probe.log` in this directory. The report records all nine relevant runtime input hashes before and after; they matched during this run. The launcher used the release gate's strict error classifier, actual Godot 4.7.2, `--headless --fixed-fps 60 --test`, and an absolute engine-log path. No runtime or pre-existing test was edited; no player save was written. Owned helper completed. No browser, visual, exhaustive population, contested ownership or phone FPS claim is made.
