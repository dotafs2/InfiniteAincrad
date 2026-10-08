# Snack-city clear-ground fixture maintenance

**PASS 80 checks** in both author and independent strict native runs. The
city/physics reviewer checked the exact diff and reran all ten unique descent
receipts; `independent-final.{json,log}` and `independent-provenance.json` bind
that result. Runtime files are unchanged; all owned helpers have exited.

The rejected release and an unchanged behavioral diagnostic reproduce two
failures at the old hard-coded rain positions:

| Recipe | Former drop center | Actual support in expanded scene |
| --- | --- | --- |
| Egg | (76, 43) | `food_pizza_2773`, footprint 2.673267, center (76.00584, 44.27203) |
| Berry | (71, 61) | `food_cookie_2817`, footprint 1.285714, center (71.75607, 61.68081) |

Both remained physically supported. The other eight recipes had real terrain
below them. The old test explicitly intended ten open-ground drops, so those
coordinates no longer satisfy its premise after real food fills the perimeter.

Only `tests/snack_city_acceptance.gd` changes. It now searches the actual, complete
scene for ten separated clear columns. A collision-space box query checks a
6×6×24-meter column; downward rays at its center and four corners must all hit
the actual terrain RID. Every actual recipe's bounding-sphere radius must be
below three meters, so its collision envelope fits that measured column under
rotation. No scene object is deleted, moved away or made noncolliding.

The original spawn altitude (12 meters), landing period (240 physics ticks),
settling bounds/speed, 1.5-meter mouth, normal `scan_food`, and 360-tick fall limit
are unchanged. Every original UI, NPC, support-release, material, population and
rain-lifecycle check remains. Each drop additionally proves actual terrain
support after landing and exactly one player receipt only when its entire top
has fallen below -3.5 meters. The ten originally tracked IDs all pass. The new
189-check extension review separately retains rain-on-food/support-chain cases;
this clear-ground test is not used to claim that every drop starts on empty land.

Evidence: `artifacts/world-expansion-20260929/snack-fixture/` contains the original
test, exact `maintenance.diff`, rejected gate receipt/log, support diagnostic,
final `source-final.{json,log}`, and stable before/after `provenance.json`.
The first setup attempt raced the parent's move of the rejected gate directory
and therefore never loaded its diagnostic script; its setup log is retained.
An intermediate added ray loop needed an explicit `Vector2` local type; its
parse log is also retained. No diagnostic whitelist or assertion threshold was
relaxed.
