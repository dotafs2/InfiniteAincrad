# 200-skin production handoff

## Current scope and result

The user's latest request explicitly permits several color variants of one skin,
asks the agent to grade the collection, and requires exactly 200 playable entries
using the preceding procedural mesh/material workflow. The runtime now contains
200 entries across 68 named base families: 40 Common, 60 Uncommon, 48 Rare,
28 Epic, 16 Legendary and 8 Prismatic. These are 68 named bases plus 132 palette
variants; some lowest-tier bases intentionally share basic ring construction.
This supersedes the earlier 20/40/60/44/24/12 art proposal and its recolor ban.

Eight new base families: Plain Loop, Button Wheel, Pocket Arcade, Sakura Pavilion,
Clockwork Orbit, Phoenix Nest, Crystal Crown and Aurora Rift. Higher-tier pieces
include articulated assemblies or animated surfaces and stronger rival effects.
Phoenix has opposite-phase shoulder wings. Aurora uses one bounded shader ribbon.
Existing weather variants preserve the original entry/reward timing.

## Compatibility and economy

All original 60 IDs, names, order, legacy fields and original skill parameters
remain; rarity reassignment is intentional. Existing ownership migrates without
silently granting 140 additions. New variants are cosmetic. Five original active
abilities are retained. Per-instance palettes do not recolor sibling resources.
Actual models appear in both the collection and player, not image-only stand-ins.

The score/10 coin rule, 100-coin draw, diamond exchange, tier base weights and
5/10/20 guarantee thresholds are unchanged. Tier composition and each individual
skin's eligibility/odds change with regrading and the larger pool. Do not claim
unchanged per-skin probability. One starter plus 199 nonduplicate draws completes
the collection; this does not guarantee one draw for every played round.
`game.gd`, `skin_draw.gd` and `rainfall_intake.gd` match the captured baseline.

## Evidence

- `artifacts/skin-production-200-20261007/index.html`: filterable 200-entry actual
  model gallery, with 400 idle/rival PNGs in `renders-02`, six graded sheets,
  eight-new-family sheet and five real collection UI screenshots.
- `Phoenix_Nest-full-gameplay.mp4` and `Pocket_Arcade-full-gameplay.mp4`: muted
  40-second normal Sunny City captures, each 23 objects and one rival, score0→36,
  seven normal AI and no injected entities/rewards. Fixed simulation timestep and
  scripted legal inputs; these are not native-phone performance measurements.
- `Phoenix-motion-review.mp4`: isolated 10-second GPU detail study, item callback
  at2s and rival at5s; all600 frames check opposite wing phase.
- Real GPU acceptance: 2,996 checks across200 entries, resource isolation, unique
  family palettes, actual shader compilation and retired pooled feedback.
- Focused weather variant test:791 checks, including30/60/120Hz single-entry
  admission equivalence; collection:1,680 checks including199 cold-restored draws;
  UI bounds:71,619 checks. Final geometry suite:3,614 checks.
- Independent final art review passes with qualifications in `ART_REVIEW.md`.
  Every tier sheet was inspected, previous poor palette/seam/lighting/caption
  candidates rejected, and final Phoenix/Arcade normal gameplay sampled.
- Final standard4.7.2 source/package gate03 passes: 92 suites / 173,349 source checks and 92 suites / 173,349 exact-package checks; GPU 2,996 and weather 791 checks; 867 unchanged guarded inputs. Exact source/package GPU rows match. Maximum complete model plus reserved effects is 5,132 triangles. The isolated QA browser starts and renders the 200-entry HOLES collection with no warning/error logs in the inspected flow.
- PCK SHA-256: `2def324ff545d88e8046169a730cf576e743440250336a914354bb392fa9abde`. Exact receipt: ignored `build/skin-production-200-20261007/completion.json`.


## Preserved failures and limits

Ignored build evidence preserves early typing errors, the initial geometry mouth
fit, two over-budget Pavilion previews, 673 actual caption failures, and the first
full gate's outdated10,000-coin full-collection fixture. The fixture now funds all
199 draws plus500 to verify save-write rollback. No runtime reward changed.

Art remains stylized and restrained. Small rival fragments compete with the
normal LVL/name text, boost ring and building dither at early levels. Phoenix is
an articulated toy-like bird, not another storm/flame simulation. Phone frame
rate and this batch on TestFlight have not been tested. Submitted native
0.13.0/build34, accounts, real user saves and Git publication are untouched.

## Recovery and local delivery

Use `build/skin-production-200-20261007/active-work.json` and exact gate receipts.
One engine job at a time. All workers are finished; do not rerun full checks with
unchanged inputs and no new concern. Existing gallery server8786/PID34521 and
prior verified60-skin preview8787/PID41922 are deliverables and should remain.
Verified200 preview: http://127.0.0.1:8788/?qa=1. Preserve its owned server PID50936 as a deliverable. All engine/test helpers completed.

The first extra package weather harness failed because tests are intentionally excluded from the release PCK. A local staged harness resolves only its test superclass by absolute path; all runtime res://fidelity resources still load from the unchanged exact PCK. The corrected package weather run passes791checks; both logs are retained. Browser inspection also reached the highest-tier cards and previewed Cobalt Storm without warning/error logs.
