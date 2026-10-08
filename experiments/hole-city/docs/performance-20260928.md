# Two-map performance pass — September 28, 2026

Version 0.5.5 optimizes Sunny City and Snack Garden without reducing their model
population, food geometry, shadows, physics rate or independent swallowing.

## Measurement

Each map/scenario runs three times in a separate headless Godot process, with
60 warm-up frames and 600 measured frames per run. The table reports the median
P95 CPU wall time across those three runs. Both phases use the same movement,
seeds, 60 Hz simulation and opening/eight-large-hole fixtures. Batch counters
were added after the measured loop; the measured frame loop is unchanged.

| Map and scenario | Before P95 | After P95 | Reduction |
| --- | ---: | ---: | ---: |
| Sunny City opening | 11.446 ms | 6.473 ms | 43.45% |
| Sunny City grown holes | 10.459 ms | 6.489 ms | 37.96% |
| Snack Garden opening | 5.019 ms | 3.882 ms | 22.65% |
| Snack Garden grown holes | 8.319 ms | 5.910 ms | 28.96% |

The optimized runs contain 7,200 measured frames in total; none exceeds
16.67 ms. The baseline has two over-budget city-opening frames. These are Mac
CPU measurements with rendering disabled. They do not establish WebAssembly,
browser GPU, iPhone 14, sustained FPS or thermal performance. The browser control
interface returned `User unavailable`; no alternate browser or foreground app
was used to bypass that limitation.

## Changes and preserved behavior

- Ground cutting locates a single edge of the convex 32-sided mouth for each
  scanline band, instead of testing every polygon edge repeatedly. It also
  avoids temporary six-element arrays when writing triangles. Mouth sides,
  overlap union, rim depth, collision rate and visual geometry are retained.
  Isolated ground rebuild medians fall from about 1.4–1.85 ms to 0.82–1.06 ms.
- Both maps share a spatial index using actual interaction positions, including
  lamp support anchors. Static cells are queried locally; NPCs, vehicles, falling
  pieces and shifted buildings remain in a live registry. A scan computes each
  moving fixture's rim position once for all holes. Already claimed pieces skip
  needless rim calculations. City scan medians fall from 3.6–4.4 ms to about
  1.0 ms; food grown-hole scanning falls from about 1.0 to 0.65 ms.
- Sunny City shares identical opaque materials and batches repeated stationary
  meshes in bounded cells. The opening scene surface-submission inventory falls
  from 970 to 906; material overrides fall from 612 to 248. Total scene geometry
  is unchanged. Moving, animated and fracturing owners remain independent, and
  released props restore their original mesh/material/transform. Camera-visible
  batch triangles can increase slightly because a batch has a conservative
  combined bounding box; no GPU speedup is inferred from submission counts alone.
- Food batches compact on release instead of retaining zero-scale draw slots.
  The grown fixture ends with 1,632 active slots out of capacity 2,538. Compared
  with submitting that retained capacity in the same end state, 1,469,848 hidden
  triangles no longer enter the vertex stage. Released food still renders and
  falls independently. This is saved geometry submission, not measured GPU time.
- Catalog scenes load on first use. Food gameplay loads its two character
  assets instead of eagerly loading all 208 city assets. A supplementary snapshot
  using the preserved v0.5.4 PCK reports engine static allocation of 205,653,154
  bytes versus 193,221,176 bytes for the optimized source. This single snapshot
  is not total process RSS, GPU memory or a device-memory benchmark.

## Regression evidence

The new 269-check performance suite compares collision triangle topology and
coordinates against the preserved pre-optimization ground implementation across
72 seeded mouth arrangements, including overlaps and map edges. The largest
coordinate difference is 0.00003815 m (0.038 mm), within the 0.3 mm guard.
Exhaustive queries and nearest-edible searches agree with the new spatial index
on both maps. Tests also verify independent compound colliders, released meshes,
compacted owner/slot associations, and batch-resource cleanup on map switches.
The existing complete scene, all street fixtures, full-city collection, food
cascades, both-map movement and skin/UI suites remain in the guarded source/PCK
release gate. Exact final results and input/build hashes are in
`artifacts/performance-20260928/release/release.json`.

The baseline food-opening runs each emitted one native Godot SAT contact-limit
diagnostic. None of the three optimized opening runs reproduces it; this is
recorded as non-reproduction, not an engine-wide collision fix. Final traces
contain no GDScript exceptions. The source/package functional gate remains
separate from the isolated timing runs.

`before/`, `after/`, component reports and `comparison.json` retain raw evidence.
Geometry inventories use authored CPU poses because the headless dummy renderer
does not retain GPU instance transforms; their camera counts exclude UI, shadow
passes and actual driver submissions. The existing preview server is retained.

During full acceptance, a bike-rack fixture completed its fall during a three-frame
await before the test inspected it again. The fixture now checks liveness after
that await and verifies the collection receipt when it has already disappeared.
It still requires each of the 256 approaches to collect successfully. The release
runner now notices GDScript failures while the child is running, terminates that
owned child and preserves the previous preview. An intentional sleeping-error
probe exits in 0.11 seconds instead of waiting for the 600-second timeout.

The final source and exported PCK each pass **4,853 checks**. Preview hashes
match the release manifest, and the runtime files match the profiled source.
Delivered PCK SHA-256: `a1de90524a39415a160a6b0cbba49ce2ef13bdd69bb2cc0d1fbc9b2d6eed092d`.
