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
two close PCG samples. Resident homes, resident social targets, and public-place
jobs now bind a stable semantic target ID to one graph region; their exact
position can still move within that region for the final leg. Intermediate
waypoint arrival is evaluated in XZ; the last leg uses the world's existing
0.45 m target gate and preserves the target's current height.

## Acceptance

```powershell
python -X utf8 tools/run_godot.py --godot `"D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe`" --name formal-graph-resident-route --timeout 90 --out private/iteration-20260919/formal-graph-resident-route -- --headless --script res://tests/town_graph_resident_route_acceptance.gd
```

Last runtime result: `23` checks, `0` failures. The disposable formal resident
reached all 10 authored home regions. After adding stable target IDs, the
acceptance now has 33 checks (10 additional binding assertions) but has not
been rerun because the Godot 4.7 runtime is unavailable in the current local
checkout. The full-map graph fixture's last runtime result remains 189 regions,
193 connectors, 762 representative executions and 15,217 checks.

This is the first-stage route integration only. It deliberately does not claim
physical collision correctness or dynamic obstacle handling. A Godot 4.7 scene
smoke is still required before publication; the graph-only contract continues
to allow overlap and penetration in this first step.
