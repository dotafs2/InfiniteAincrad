# Street props, interrupted falls and full-city QA

The follow-up addresses the user's report of another lamp/sign refusing to
fall. The previous recipe suite covered 152 procedural objects, not every
imported street-furniture instance or interrupted fall. Its passing result was
insufficient evidence for the entire city.

## Reproduced causes and changes

1. **Solid boxes around empty space.** Imported lamps, signs, shelters and
   fences used one full-height box. All 64 street-prop assets now use 359
   offline convex hulls derived from their actual connected mesh geometry.
   Beacons and ambient robots also use their separate primitive hulls. Model
   geometry and materials are preserved; a 2 mm collision margin avoids
   inflating narrow posts. Cache hashes are checked against the shipped GLBs.
2. **A deep narrow shaft.** The terrain's collision walls extended three metres
   below the mouth. Long objects could wedge there even after entering. The
   physical rim is now 12 cm deep, with open space beneath it for tipping.
   The visible wall retains its appearance and the ground still has real rim
   contacts. A bounded vertical load on unsupported geometry helps a head or
   roof lip tip; it does not set horizontal velocity or award early points.
3. **Stale ownership and sleep.** A half-entered object remained claimed after
   its hole departed because claim release required its bottom to be above
   the pavement. Partial objects now release that reservation, permit another
   hole to claim them, and wake when their supporting opening changes. Potential
   scoring credit is separate: an already-admitted body cannot fall indefinitely
   below the world without being accounted for. Credit is awarded only after
   the complete body crosses the collection plane, and a new claimant replaces
   the previous potential credit.
4. **Wrong target and size origin.** A partly submerged lamp's visible head is
   not its buried bounding-box center. Interaction uses its geometry near the
   ground plane; standing posts use their actual base. Asymmetric arms are
   measured from that same base, preventing admission into an impossibly small
   mouth. A genuinely oversized object shows **GROW TO LVL …** when approached.
5. **Overlapping scenery.** Public furniture, plants and beacons now avoid
   existing solid footprints. Park fence variants were 1.0–1.27 m wide but
   placed every 1 m, interlocking their bars. Panels now use their real widths
   plus gaps, with end sections along the park edge. All 40 park panels remain.

## Persistent QA gates

`tools/release_web.py` now runs four suites on source and repeats all four on
the exported PCK before replacing the local preview:

| Suite | What it establishes |
| --- | --- |
| `scene_qa` | Recipe ownership, bounds, negative controls and individual receipts for all 152 recipe objects |
| `street_prop_qa --all-props` | All 64 imported props, four approach directions each, cache/model hash agreement and recovery from rim contact |
| `claim_recovery` | A real partly entered sign, departed-owner release, second-hole takeover, exactly-once scoring, sleep wake-up and required-level feedback |
| `full_city_qa` | All 656 initial city instances: 608 individual collection receipts and 48 fractured building shells; focused drops also fail on stalls |

The furniture suite allows a supported overhang to rest briefly on the rim,
then moves away and re-centers the opening on the remaining visible geometry.
It must become claimable and complete a real fall. It does not erase the
object, disable its collisions or directly grant points. The full-city suite
records actual positions, eligible radii, initial blockers and final blockers.
The original 48-direction lamp/sign/light baseline had nine stalls and remains
in `artifacts/street-qa/baseline.json`.

```sh
python3 tools/release_web.py \
  --godot .build/godot-standard/Godot.app/Contents/MacOS/Godot \
  --evidence artifacts/street-qa
```

The latest `release.json` contains source and exported-file hashes. Source and
package reports have explicit `source-` / `package-` prefixes. Diagnostic
files without those prefixes retain intermediate findings; they are not final
acceptance reports. All four suites are also available in `validate_mobile.py`.

## Loading and validation limits

Final source and exported PCK each pass **2,806 checks**: recipe QA 756,
street props 835, claim recovery 10 and full-city traversal 1,205. All 656
initial objects are accounted for (608 collection receipts and 48 fractured
shells); no focused city probe remains stuck. All 256 street-prop direction
cases pass, including three cases that rest on a rim before recovery.

Ten broader suites pass 214 checks plus food-round acceptance. A subsequent
city-round run on the final layout also passes: contested and solo play both
reach 420 points, at 91.62 and 115.65 simulation seconds respectively.

Separate 600-frame CPU traces record opening P95 11.361 ms / worst 12.537 ms
and grown-city P95 10.655 ms / worst 14.657 ms, with no sampled frame above
16.67 ms. Headless timings exclude rendering and do not establish device FPS.
The release gate also has a failing-engine check: a failed run overwrites its
previous success report and refuses release, rather than leaving stale results.

The delivered version is **0.4.1**, displayed at the bottom of the home screen.
Reload and begin a new round to use it; an already-running WebAssembly round
retains the old code. The existing preview server is left running.

These are engine-level geometry, collision and gameplay tests. The previously
saved browser denial has not been bypassed, and no rendered browser playtest
or physical iPhone 14 60 FPS result is claimed. No Git publication, provider
call or resident-world modification occurs in this workflow.
