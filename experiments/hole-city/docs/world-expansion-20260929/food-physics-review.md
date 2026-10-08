# Independent enlarged-food and perimeter-rain review

**PASS — 189 checks**, bundled Godot 4.7.2 with strict diagnostics, `--test`,
fixed 60 Hz physics. No runtime implementation, player save, browser, preview
server or device setting was changed by this reviewer. All owned helpers exited.

The permanent `tests/food_extension_collision_review.gd` emits
`FOOD_EXTENSION_COLLISION_REVIEW`. Final evidence is
`artifacts/world-expansion-20260929/food-physics-review/frozen.{json,log}`;
`provenance.json` records stable before/after runtime, plan, atlas and test hashes.
The final plan is `86decaffa2e1385d118033d2304e1e490727f79d09be51bf7f1c980ebd10eda0`.

## Actual scene evidence

- All 334 extension bodies (including 120 loose foods) are bound to authored
  plot, heap and snack provenance. Visual scales reach 4.2. Every body's physical
  height/half-size matches its real mesh envelope; hulls remain within the
  physical 200-meter terrain. Each root has actual terrain below its hull;
  supported tiers have reciprocal parents with the retained near-contact gap.
- Independent convex polygon intersections of actual collider footprints find
  no penetrations between extension ground foods and other ground food roots.
  This uses transformed hull vertices, not only center distance or visual size.
  Separate map reviews check road/sidewalk packing and density.
- The largest round plaza ingredient (scale 2.830189) is lifted three meters,
  tilted, and physically released. It reaches 8.679 m/s, settles within the
  retained ground-support and speed tolerances, and does not award on contact.
  A starting gray hole fails its size gate. Ordinary `award` growth, without
  equipping a skill or modifying its collider, makes it collectible. A normal
  scene scan releases it; its unique receipt occurs only after the whole body
  is below -3.5 meters (observed top -3.514832).
- Actual enlarged burger and cake towers retain independent support links.
  Removing their base releases their own upper tiers; both visibly represent
  separate physics poses by tilting. All four burger pieces and all three cake
  pieces produce separate, unique player receipts after full descent.

## Expanded-perimeter rain

At all four +/-96 corners and four edge midpoints, 32 candidate samples each
remain supported by actual terrain and within the +/-93 spawn boundary. The
maximum distance from the player is 15.944643 meters. Projecting the same samples
onto the former +/-67 clamp gives a minimum distance of 29.000656 meters. The
latter is a geometric old-formula comparison, not a claimed old-package run.

All ten rain recipes actually fall, contact support and remain collectible near
the expanded corner. Each original body ID has exactly one player receipt with
its full top below -3.5 meters, including neighbors swallowed during another
piece's cascade. Collection uses legal player centers within +/-96 and ordinary
score growth. A subsequent 30-second steady corner run spawns 78 additional
pieces, with a peak of 19 airborne and 77 retained. The original limits of 24
and 640 remain unchanged. Retirement records continue to require settled,
distant, hidden food. Full 240-second rain continuity is covered by its existing
separate suite; this review does not replace that duration.

## Preserved fixture failures

The original probe passed enlarged-food geometry/contact/collapse but could not
collect bacon and cake within its unchanged 240-tick rain window. The exact first
script and receipts remain as `first-test.gd`, `first.{json,log}`. The diagnostic
copy and `rain-diagnostic.{json,log}` establish the causes:

- Bacon rested on a real donut in the existing five-layer heap. A 0.85-radius
  hole could fit the bacon but had not removed its rooted supporting chain.
- Cake had rolled to x=97.37, still on the 100-meter terrain but beyond the legal
  player-center limit of 96. The initial test incorrectly teleported the small
  mouth outside that limit.

The corrected fixture respects the actual support-parent chain, grows through
ordinary score awards to cover its root, clamps the player's center to the legal
range, and includes the target's offset in the required radius. It does not
change runtime physics, enlarge the allowed fall duration, force collection,
remove ground or disable collision. Both formerly failed pieces then physically
fall and score. Large-mouth collection also legitimately eats some neighboring
rain drops early. The intermediate probe had skipped their freed nodes and
therefore fell below the strict check-count floor; the final version explicitly
verifies every original ID and receipt, whether its node is still alive or not.

The author's small final berry-envelope correction reduced new berry scales
without moving streets or towers. The final strict run uses that corrected plan
and stable hashes. Earlier mixed/preliminary files remain for traceability.

## Scope and limitations

The existing broad collision suites inspect all scene colliders but their
purpose-built dynamic contact examples were mostly scale 0.55–0.7. This suite
adds real large extension bodies and reachable outer-world rain. It is still a
bounded deterministic physics sample, not an exhaustive orientation solver,
human progression pacing study, browser screenshot or phone GPU benchmark.
Static triangle budgets and unchanged ingredient finish are independently
covered by `food-budget-maintenance-review.md` and the existing finish suite.
No skin IDs, save schema, score formulas or ability rules were altered here.

## Frozen SHA-256

- `fidelity/food_city.gd`: `633b9e91e5937d811d0869777a9cab2da0e4ab3ab48bfca96b2efc0aba892405`
- `fidelity/food_body.gd`: `acc24c145f8eae9f312c481af8fec9ff482fcf5f34159e56b45d403acc9fd22c`
- `fidelity/food_neighborhoods.gd`: `9cb4b8866f5809426e251f129cf3b04851fb38426555e7880bd7afc3a7bada0f`
- `fidelity/game.gd`: `655ef8c91be52c8e90b6d59f024a251879209991d233977b3d4aaefeaabb92ca`
- `fidelity/hole.gd`: `6633da90a596026bcadd87e404235e16c0f6f9d6bb7527f56d92a2965403f117`
- `assets/food_city/neighborhoods.json`: `86decaffa2e1385d118033d2304e1e490727f79d09be51bf7f1c980ebd10eda0`
- `assets/food_city/streets.png`: `e2b1c3d2f40a777cc5123eed9449a064a31459f8349079ff448094d028db36cb`
- `tests/food_extension_collision_review.gd`: `c564f7a1829d3c2b9e3f06810e93e3575e39de2a3808907d3fa684c3cd3c4467`
