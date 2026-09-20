# Formal Resident Graph Navigation — 2026-09-20

The first graph-only route mode is now connected to the loaded first-floor
resident loop behind `TownNavigation.graph_only_routes`. `living_town.gd` enables
it after registering the same PCG road layout used by the route graph.

In this mode the graph owns the long route. The body moves directly along graph
waypoints and deliberately bypasses collision resolution and penetration. Local
social steering is only allowed inside its existing bounded final-leg radius;
long trips cannot silently fall back to a straight push.

The route cache keeps the source region captured when a command starts. It does
not re-select the nearest sample every frame, which avoids oscillating between
two close PCG samples. Intermediate waypoint arrival is evaluated in XZ; the
last leg uses the world's existing 0.45 m target gate and preserves the target's
current height.

## Acceptance

```powershell
python -X utf8 tools/run_godot.py --godot `"D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe`" --name formal-graph-resident-route --timeout 90 --out private/iteration-20260919/formal-graph-resident-route -- --headless --script res://tests/town_graph_resident_route_acceptance.gd
```

Result: `23` checks, `0` failures. The disposable formal resident reached all
10 authored home regions. The full-map graph fixture still passes with 189
regions, 193 connectors, 762 representative executions and 15,217 checks.

This is the first-stage route integration only. It does not claim physical
collision correctness, dynamic obstacle handling, or stable target identity for
arbitrary overlapping social targets; those require a later route-target API.
