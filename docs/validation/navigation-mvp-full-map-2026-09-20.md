# Full-map NPC Route Acceptance — 2026-09-20

## Scope

This is the first full-map gate before connecting the production resident loop
to the graph-only route contract. It consumes the same
`game/spatial/living_quarter_layout.json` used by the PCG adapter and ignores
physics, collision, clearance, and visual geometry by design.

The fixture creates one disposable NPC and checks both directions between a
root region and every other registered region. It then executes every authored
PCG connector directly in each permitted direction. This covers every region
and every graph edge without running a quadratic all-pairs test on every map
edit.

## Command

```powershell
python -X utf8 tools/run_godot.py --godot `"D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe`" --name full-map-route-graph-v2 --timeout 90 --out private/iteration-20260919/full-map-route-graph-v2 -- --headless --script res://tests/town_route_graph_full_map_acceptance.gd
```

## Result

```text
region_count=189
connector_count=193
successful_routes=762
failed_routes=0
checks=15217
failures=0
elapsed_seconds=2.891
```

The route graph preserves source and target regions, keeps connector order,
executes every edge, and places the test NPC at each requested graph target.
The test does not claim that a real CharacterBody3D can avoid walls or other
actors; those are later physical-navigation concerns outside this MVP.

The earlier quadratic all-pairs draft was stopped by the 90-second test budget;
it was a test-scaling problem, not a route failure. The accepted fixture now
exercises the complete graph with bounded runtime.
