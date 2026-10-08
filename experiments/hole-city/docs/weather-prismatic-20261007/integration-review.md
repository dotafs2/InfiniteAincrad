# Weather skin integration review — 2026-10-07

Reviewer: delegated integration reviewer, independent of runtime/shader author.
Scope: compare the candidate with exact local files under
`build/weather-prismatic-20261007/before/fidelity`, inspect rarity, save and draw
routing, and inspect the matched Mac GPU rival-response images. No engine,
phone, account, export or publication jobs were started by this reviewer.

## Decision

No blocking integration defect found in the refined candidate. The two existing skins
move to the actual highest tier, Prismatic / Tier 6, and their visible palettes
are substantially easier to distinguish than the preceding shared blue-gray
palette. Runtime rival effects match each theme: violet storm/gold lightning and
clear jade water/pearl-and-jade splashes. The first candidate's excessive green
cloud/water cast was rejected by the visual review. The refinement restores
cool-white cloud highlights and shifts the pool toward clearer turquoise jade;
its actual `refined/rival-light.png` was also inspected and is preferable to the
initial `candidate/rival-light.png`. This judgment covers the matched render
and code review; it is not a device-performance or release sign-off.

## Verified preservation

- The catalog still contains 46 records. The first 44 parsed records are exactly
  equal to the saved baseline. Only `tint`, `accent`, `skill_desc` and `rarity`
  change in the `tempest` and `rainfall` records. IDs, names, group, migration
  threshold, cosmetic kind and zero cooldown are unchanged.
- Both `skin_catalog.gd` and `skin_rarity.gd` agree on Prismatic. The existing
  collection sorter reads these ranks and places them in Tier 6 without adding
  another inventory item or a separate selection category. Tier totals become
  Common 6, Uncommon 8, Rare 12, Epic 12, Legendary 3 and Prismatic 5.
- `rainfall_intake.gd`, `rim_body.gd` and `skin_visual.gd` are byte-identical to
  the immediate pre-palette baseline. The recent single-entry render handoff,
  scoring/physics behavior and stable-ID effect routing are therefore retained.
- Save ownership and equipment are keyed by skin ID, not rarity. Promotion does
  not require a schema migration, entitlement replacement or save reset. Draw
  eligibility automatically uses the existing highest-tier pool and its
  20-draw guarantee. The price, disclosed tier weights, guarantee thresholds,
  commerce amounts and gameplay power are not changed by this candidate.

Verified unchanged SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `fidelity/rim_body.gd` | `e3d5bd2041d9e8e6ab390fd954a24bdbe6987c34c156d4a0ff4d0fb957e49c4a` |
| `fidelity/rainfall_intake.gd` | `f644ffda35cfd516d011c3a2b1416e7858dbada4293b9869db1e75b55081e412` |
| `fidelity/skin_visual.gd` | `11ca7a1d05d8c4220b878aeb9fc6cc54a53c8a8d8288bb3ffe0d17e9478b5c11` |

## Effect and performance review

Tempest retains nine cloud lobes, 32 debris slots, four object fragments and
twelve rival fragments with two lightning branches. The slightly stronger funnel
bend changes vertex positions rather than topology. Violet/gold changes cover
the common storm shader, fine strands, particle colors and the colors rewritten
each frame for shock/lightning. Alpha and lifetime behavior are unchanged.

Rainfall retains seven cloud lobes, 48 scheduled drops, 24 splash slots and the
same water atlas. Per-instance splash color is enabled before allocating the
MultiMesh instances, and the white material correctly allows the instance colors
to determine appearance. The new color data is initialized once, not recreated
at every collection. Water, cloud, drop and runtime shock colors all agree with
the jade/pearl theme. No new particle nodes, surfaces or collision bodies are
added. The shader adds bounded color arithmetic and a sine, so unchanged draw
counts must not be described as zero added GPU cost.

The author's matched Mac capture receipts report identical combined counters
before and after: idle 6 draws / 1,992 primitives; object response 7 / 2,248;
rival response 11 / 3,120. These are two isolated skin assemblies with synthetic
cosmetic callbacks, not ordinary gameplay or phone frame-rate measurements.
The actual `before/rival-light.png`, `candidate/rival-light.png` and
`refined/rival-light.png` were inspected independently and support the final
palette/readability improvement.

## Test edits supplied to the coordinator

The reviewer updated only these acceptance files:

- `tempest_skin_acceptance.gd` and `rainfall_skin_acceptance.gd`: expect the
  requested Prismatic classification while preserving the existing real
  collection, rival and lifecycle checks.
- `skin_rarity_acceptance.gd`: update the expected tier totals; add four checks
  proving both catalog/runtime highest rank and unchanged cosmetic/migration
  fields. The subsequent null-mesh harness correction adds six checks that the
  unused Rainfall render-pool views remain hidden.
- `skin_collection_acceptance.gd`: add sixteen isolated-file checks, covering
  each weather skin selected with both owned, cold-loaded ownership/equipment,
  exact wallet/map/stage/pity preservation, owned-skin exclusion from the highest
  guarantee pool, the unchanged 100-coin charge, and no file rewrite on read or
  offer inspection.

No Rainfall single-entry test was changed. The coordinator ran the focused
engine suites sequentially. The reviewer read `checks/summary.json` and
`rarity-final.json`: all eight suites now pass, totaling **3,466 checks**.

| Suite | Passing checks |
| --- | ---: |
| Tempest physical events/lifecycle | 16 |
| Rainfall physical events, data and lifecycle | 117 |
| Rainfall single-entry and timing | 585 |
| Rarity, actual resources and lifecycle | 586 |
| Catalog geometry and preview bounds | 925 |
| Collection, charges and isolated cold saves | 406 |
| Existing skin polish review | 760 |
| Future collection/economy contract | 71 |

The original rarity run remains recorded as failed even though its process
returned zero and its assertion list was empty: six script errors came from
the old triangle helper dereferencing the legitimately empty pooled meshes.
The test-only correction counts a null mesh as zero geometry and additionally
fails if any empty view is visible, rather than masking missing visible art.
The coordinator's rerun reports 586 checks with no failures or script errors;
its `rarity-final.json` replaces only that failed suite for the total above.
The original log and summary remain untouched. No full release gate, phone
performance, native package or publication is covered by this result.

## Resolved loop caveat

The first candidate used `fx_time * 0.45` for the added opal edge, which broke
the existing three-second ambient period. The reviewer reported this and the
coordinator changed it to `fx_time * TAU / 3.0`. Current source readback confirms
that the new phase now agrees with the water/drop/cloud loop. Exact new rendered
pixel equality still requires a fresh capture; the historical result is not
silently treated as new evidence.

## Test audio audit

Both `tempest_skin_acceptance.gd` and `rainfall_skin_acceptance.gd` initially
created the main game without muting Master. `--test` prevents normal save use,
but does not disable the game's audio subsystem. The sequential runner uses a
real rendering window for Rainfall, so it must mute before game creation or
select the Dummy audio driver. The issue was reported before the coordinator
ran those suites. Both now call `AudioServer.set_bus_mute(0, true)` before
instantiating the main game, and the sequential runner explicitly selects
`--audio-driver Dummy` as a second protection while retaining real GPU rendering
for Rainfall's data checks. `rainfall_float_acceptance.gd` and the isolated review
capture already mute Master. Source readback confirms these are harness changes;
the playable game's music settings were not disabled.
