# Independent collision-fixture maintenance review

Status: **PASS** for the frozen test changes. The independent strict source
rerun passed **156** `FOOD_COLLISION_ACCEPTANCE` checks and **18,276**
`FOOD_COLLISION_REVIEW` checks, with no unexpected engine diagnostics. The
reviewer changed no runtime or test files. All owned engine helpers exited;
all release input hashes were identical before and after these two runs.
The full source/package release gate is separate.

## Exact scope

The perimeter expansion placed real food buildings in previously empty test
coordinates. The preserved contact diagnostic establishes actual contact with
the new pancake tower around the old pile at `(70,24)`. Moving the isolated
contact fixture is justified; it does not imply that tower-on-food collisions
are invalid game behavior. The separate food extension and density suites
continue exercising large authored bodies, stacks and rain support.

The eight ordinary/rain pairs retain their 4 m internal spacing, with a new
explicit minimum 16 m spacing between pair centers. Every specimen receives
an actual empty-air physics query and a real terrain hit before construction.
Both clear-space queries include collision layers 1 and 2 and exclude only
the terrain RID, so frozen food cannot be silently ignored. The six-piece
pile stays at the first clear location, `(0,88)`, throughout the final tests.
Its size, orientations, nonintersecting vertical placement, gravity and release
state are unchanged. The later hole and terrain queries move with the pile.

A static assertion comparison confirms all 19 original assertion statements
in the paired acceptance test are retained. In the independent collision test,
43 of 44 are retained verbatim. The sole replaced assertion is the explicitly
reviewed resting-motion measurement described below. Original mesh and finish
pins, real descent, admission boundaries, unique receipts, neighboring-body
independence, restored-floor behavior and partial-rim support checks remain.
No mouth radius, reward, contact interval or descent deadline was increased.

## Resting-motion measurement is an explicit semantic change

This is not a claim that every original condition is unchanged. The former
single endpoint native velocity limit is replaced by mean **actual horizontal
path speed**, still below 0.3 m/s, over the same final 180 pose samples and
179 physics intervals. Repeated travel counts, even when net displacement is
small. The original maximum displacement below 0.2 m, rotation below 5 degrees
and vertical range below 0.05 m remain. Native endpoint velocity, full 3D path
speed and the entire vertical position profile remain in the receipt.

The reviewer independently recalculated all path metrics from the full numeric
position arrays, rather than from rounded position strings or author summaries.
At `(0,88)`, final source results matched the preserved pre-edit trace:

| Measurement | Maximum |
| --- | ---: |
| Actual horizontal path speed | 0.086751589 m/s |
| Maximum displacement | 0.117692821 m |
| Maximum rotation | 4.215843 degrees |
| Vertical range | 0.038713232 m |
| Native endpoint speed, diagnostic | 0.392203420 m/s |
| Actual full 3D path speed, diagnostic | 0.307655659 m/s |

The old/current comparison at the same clear in-bounds coordinate `(-22,-44)`
had identical initial poses, zero initial velocities and gravity scale 1.
Both versions failed three old combined contact assertions. The old top cookie
also exceeded the unchanged rotation bound at 5.056329 degrees. Full 3D path
speed exceeded 0.3 m/s in both versions, so the proposed 3D-path pass criterion
was rejected. These failures remain recorded; there is no assertion that all
old guards passed or that the old package was perfectly still. The ordinary
pile does not invoke `lose_support`, so name-derived release impulses are not
an explanation for this comparison.

The accepted oracle establishes bounded contact motion and limited sustained
surface travel. It does **not** certify complete sleep, zero visible jitter or
all-axis instantaneous speed below 0.3 m/s. The unchanged vertical envelope
permits small repeated contact oscillation. This scope is appropriate for the
original support-and-independent-swallow regression and is stated explicitly,
not hidden as a passing result under the old definition.

## Actual functional result and provenance

The independent run observed ten rain specimens land, batch and then produce
their own exact collection receipts. All six ordinary pile bodies remained
supported and then independently descended through the real opened ground,
each producing one receipt only after full descent. The restored-ground
anti-pullback and partial-rim release checks also passed.

Frozen test hashes:

- `tests/food_collision_acceptance.gd`:
  `7a65c9ba4e320280167155300f98b3efda14f4ecef158625b883c634795a3a20`
- `tests/food_collision_review.gd`:
  `37b0bd69f6c5e6219137bd674151371844c9fa42a2f6854194c3ddf77164acd2`

Evidence root:
`artifacts/collection-20260929/collision-fixture-maintenance/`

- `before/`: exact original tests.
- `final-author/*.diff`: reviewed final maintenance diffs.
- `same-site/`: old/current comparisons, including the retained failing guards.
- `original-clear-site-trace.json`: original-oracle failure at the selected site.
- `independent-trace-recalculation.json`: independent numeric recomputation and
  source trace hashes.
- `final-independent/assertion-comparison.json`: exact preserved and replaced
  assertion statements.
- `final-independent/{food_collision,food_collision_review}.{json,log}`:
  fresh strict non-author receipts.
- `final-independent/manifest.json`: complete before/after input hashes and
  helper completion.

These are headless native functional checks. No browser access, UI capture,
phone visual assessment or CPU/GPU frame-rate claim is involved.
