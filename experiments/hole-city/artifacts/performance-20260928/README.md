# Both-map performance evidence — v0.5.5

- `before/` and `after/`: three isolated 600-sample CPU runs per map/scenario,
  plus raw engine logs and source fingerprints. These are headless Mac tests.
- `comparison.json`: median P95 comparisons and explicit GPU/device limitations.
- `*-components.json`: isolated script kernels and conservative mesh inventories.
  The baseline package report identifies preserved v0.5.4; optimized reports
  identify v0.5.5. Headless geometry bounds are reconstructed from owner poses.
- `fail-fast-probe.json`: intentionally failing owned child exited in 0.11 seconds.
  Its log deliberately contains SCRIPT ERROR as the test input.
- `release/`: full source/PCK acceptance logs, 4,853 checks each, and build hashes.
- `verification.json`: deployed preview and profiled source match final inputs.

Owned processes were the profiling runner and its Godot children, component
probes, regression probes, guarded release/export children, and the deliberate
error probe. All finished or were terminated by their owning runner. The prior
preview server was retained. Browser access was unavailable; no GUI/native window,
alternate browser endpoint, provider API or user save was accessed.

Reproduce CPU timing with `python3 tools/profile_maps.py --godot
.build/godot-standard/Godot.app/Contents/MacOS/Godot --output <new-directory>`
from the game root, without running other owned test/render jobs concurrently.
