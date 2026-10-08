# Two-map mobile iteration — September 27, 2026

Follow-up: [actor, fracture and rig fixes](actor-fracture-fixes-20260927.md) supersede
the non-edible-resident design and original animation-curve preservation below.

## Scope and working copy

Target hardware is **iPhone 14**. The release goal is sustained 60 FPS without
removing visible geometry, characters, rivals, shadows or skin effects.
This delivery is a candidate implementation, not a physical-device certification
or a verified claim of visual parity with Hole.io.

The writable project is `experiments/hole-city` in the current workspace.
It was copied from the locally synchronized black-hole project at
`7551f6c5288878fbe91bf3852d55edaf7f97c20b`. The sibling `hole-city-local`
checkout was read-only in this session and remains the baseline. No commit,
push, resident-world call, save reset or paid provider call was performed.
The historical Blender source scene was not duplicated; the runtime models
and authoring scripts are included.

## Playable maps

- **Sunny City:** 48 imported buildings, 49 vehicles (eight moving), street
  furniture and parks. All 208 distinct catalog assets remain represented.
  Its 451-body registry includes 64 non-edible residents: 387 objects are edible
  before buildings fracture into additional pieces.
- **Snack Garden:** 72 berries, 68 cookies, 40 donuts, nine burgers, 16 tiered
  cakes and eight moving sushi pieces. These are authored 3D food meshes with
  physical collision, falling, scoring and growth, rather than food labels on
  city meshes. Thirty-two chefs/couriers occupy the sidewalks. The round asks
  for 420 sync plus ten small treats (berries or cookies), four donuts and one
  cake. Small-food stock and round counters reset on replay.

The home screen has two map selectors, a changing 3D preview, saved selection
and touch-sized targets. Existing ten skins and five active/passive field
skills remain available. Game text is English.

## Bugs fixed

1. Moving, hidden CSG cylinders still triggered expensive rebuilds. Production
   now triangulates the union of eight 32-sided mouths; the visual surface and
   physical collider share vertices. Legacy CSG fixtures remain supported.
2. Traffic used coordinates and headings unrelated to the road shader. One
   street definition now drives roads, lanes, headings, visible sidewalk tiling
   and sidewalk boundaries.
   Cars reserve intersections, yield by actual body bounds, and stop near the
   player. Parked rows and building parcels were moved off roads/sidewalks.
3. Citizens spawned on roads and their panic/chase destinations escaped the
   sidewalk. Spawn, wandering and escape destinations now share explicit bounds.
4. Scripted bob/slide animations accumulated offsets indefinitely. They now
   evaluate from immutable authored origins.
5. AI abandoned food as soon as contact started. A short dwell keeps the opening
   beneath the falling target. Physics still owns collection: no early award,
   teleport, horizontal tether or automatic win was added.
6. Round food used a square diagonal as its size gate. Cylindrical food collision
   now matches the round footprint, preventing an early-growth dead end.
7. Runtime JSON actor definitions were missing from the export include filter.
   Web/native export presets now include both catalog and actor-layout JSON.

## Geometry, animation and performance

Static building details and non-moving recipe parts are merged into meshes while
retaining all their triangles and baked vertex colors. Animated parts remain
separate. UI data refreshes at 30 Hz; movement and physics remain 60 Hz.
Collection tones are cached instead of regenerated per object.

Sixteen authored character rigs now have rounded clothing, larger faces, eyes,
shoes and clearer silhouettes. Their original bones, role accessories and
Idle/Walk/Run/role animation accessors remain intact. All citizen, ambient and
recipe animations remain active; there is no distance-based animation freeze.
The 16-file integrity report checks accessor ranges, outward added-face winding
and unchanged original skins/animation data.

## Verification

`artifacts/mobile/regressions.json` records 12 successful suites: **214 assertions**
plus the food-round result. They exercise touch/pause, role animation, 208 unique
models, skins, bounded pull, real rim tipping, building fragments, minute-long
traffic/pedestrian routes, food falls, map reset, overlapping holes and restoration
of ground after a mouth moves away. The runner rejects script errors even when
Godot exits with code zero. The exported Web PCK also passes the same 27-map
checks when loaded directly by the native headless runtime; this checks packaged
resources, not the browser renderer.

Both city and food automated rounds reach the win condition through actual
movement and physics, with seven rivals present and in separate reachability
fixtures. This is deterministic functional evidence, not human playtesting.

```sh
python3 tools/validate_mobile.py --godot /path/to/Godot
Godot --headless --path . --fixed-fps 60 --script tests/mobile_profile.gd -- --test --map=city --report=/tmp/city.json
Godot --headless --path . --fixed-fps 60 --script tests/mobile_profile.gd -- --test --map=food --scenario=grown --report=/tmp/food-stress.json
```

The CPU measurements below use the same Godot 4.7.2 non-.NET binary, 60 Hz fixed
physics, a 60-frame warmup and 600 recorded frames on the same Mac. The opening
trace has the same input sequence before/after, but authored placement, AI and
geometry differ between revisions. GPU rendering is disabled: draw calls are
zero by design. These numbers are neither device FPS nor a pure one-variable
microbenchmark. The earlier uncapped 120 ms diagnostic included catch-up effects
and is not used as the controlled baseline.

| CPU trace | Median ms | P95 ms | P99 ms | Worst ms | Frames >16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| baseline-city | 15.70 | 23.07 | 27.28 | 29.12 | 272 / 600 |
| city-opening | 4.03 | 7.08 | 8.69 | 10.65 | 0 / 600 |
| food-opening | 3.56 | 5.16 | 6.10 | 10.19 | 0 / 600 |
| city-grown | 5.45 | 9.40 | 11.74 | 35.94 | 1 / 600 |
| food-grown | 4.50 | 6.71 | 8.04 | 8.91 | 0 / 600 |

The grown trace starts all eight mouths at level eight, preserves their growth
state, runs physical food collection and disables only the normal match-end gate
so that a quick 420-point win cannot turn the benchmark into idle frames.

## Local deployment and remaining acceptance

A local Web review package is in `build/web`. Use a **non-.NET** Godot 4.7.2
editor to export the Web preset; the project itself is GDScript-only.

```sh
Godot --headless --path . --export-release 'Web Review'
python3 tools/serve_review.py
# Open http://127.0.0.1:8768 in a browser.
```

The server binds only to loopback and supplies the isolation headers needed by
WASM threads. Its owned PID is written to `build/review-server.pid`. Other test
processes terminate. The user's previous game window was not stopped or replaced.

Native desktop capture aborted under the current execution restrictions. The
browser tool then reported that permission to open the local preview was denied.
No alternative browser surface was used to bypass that denial. Therefore the
new visual style, draw-call reduction and GPU cost are **not visually/render
verified** in this session. The installed competitors were not played either.
The art changes need side-by-side review before claiming Hole.io quality.

No usable physical iPhone session was established (device discovery timed out).
[Godot's iOS export instructions](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
require macOS/Xcode, export templates, a real Team ID and bundle identifier.
Signing details were not invented and no signed IPA was produced.

The device gate is a release build on iPhone 14 with default art and effects,
three consecutive 210-second rounds per map (over ten minutes), including large
holes, multiple building collapses, traffic intersections and each skin skill.
Capture CPU/GPU frame times, missed 16.67 ms frames and thermal behavior. Also
review actual character animation, food silhouettes, camera occlusion, text and
touch interaction at the device's native display size. Sustained 60 FPS and
visual parity remain open until those checks pass.
