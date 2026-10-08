# Physical fixture maintenance after perimeter infill

The denser perimeter occupied coordinates that earlier tests assumed were empty.
Runtime behavior was not changed to satisfy these tests. Original failures and
contact diagnostics remain under `artifacts/world-expansion-20260929/`.

## Independent Snack Garden review

Hypatia changed only `tests/snack_city_acceptance.gd`. Sagan reviewed the exact
before/after diff and independently ran the strict release acceptance helper:
**80 checks passed**, with no unexpected engine diagnostics. The old 39 checks
remain, including all ten rain types, a 12 m fall, 240 natural physics frames,
the same landing height/speed limits, normal scanning with a 1.5 m hole and a
360-frame descent deadline. The existing no-collection assertion is stronger:
it also rejects a real emitted collection receipt.

The fixture now proves a 6 × 6 × 24 m clear column and five actual-terrain ray
hits before dropping each object. Each rotated collision envelope fits within
that column. After landing, a ray confirms terrain rather than another food.
Every instance produced exactly one player collection only after its top fell
below −3.5 m. UI, citizens, food foundations, rain limits and restart checks are
unchanged. Evidence and exact hashes are in
`snack-fixture/independent-review.json`, `independent-provenance.json`, and
`independent-final.{json,log}`. All reviewer helpers exited.

## Food impact fixture repair

The old cake drop at (71, 54) struck `food_berry_2769` at y = 5.7934 m and
correctly emitted its thud at y = 5.8284 m. A cookie touched an adjacent raised
food at y = 2.2009 m before later reaching terrain. The test incorrectly required
all these legitimate food-on-food contacts to occur at ground height.

Sagan changed only the first three drop locations in
`tests/food_impact_acceptance.gd` to sites selected through actual 4 × 12 × 4 m
air-clearance queries and five terrain rays, within the unchanged feedback
admission distance. The fixture validates the full rotational body envelope.
The original 8 m height, 5-frame airborne check, 300-frame settling interval,
ground y bounds, three feedback/sound styles, waveform differences, 30-object
burst, 240-frame budget checks and 180-frame expiry check remain. The old
x-only distance check now checks full XZ distance to a selected drop site.

Author strict acceptance and Hypatia's independent exact-diff review and
strict rerun each passed **256 checks**, with three distinct ground contact
styles and a maximum of 12 simultaneous feedback bursts. The independent
review found no weakened conditions. Its report is
`impact-fixture-independent-review.md`; exact hashes and output are retained
in `impact-fixture/independent-provenance.json` and `independent-final.{json,log}`.
Evidence is in `impact-fixture/` (`diagnose`, `maintenance.diff`, `source-final`,
and `provenance`). The preserved original test and failed preflight are linked
by their exact hashes. No runtime/material/physics resource changed.

## Later physical suite preflight

Unmodified suites passed: sustained rain 33, food-city revision 135, rain review
9, food revision review 11, mobile maps 29 and portrait 30. The sustained-rain
script simulates 21,600 frames; the initial preflight incorrectly capped the
engine at 18,000 frames. That incomplete run is preserved. Its complete rerun
used a 30,000-frame ceiling and passed all 33 checks (600 stationary and 300
traveling spawns). Final results are in
`preflight-later-physics/summary-after-fixture-maintenance.json`.

These checks exercise actual headless physics and lifecycle, not browser
rendering or phone frame-rate performance. The full source and isolated-package
release gate remains the parent's separate responsibility.
