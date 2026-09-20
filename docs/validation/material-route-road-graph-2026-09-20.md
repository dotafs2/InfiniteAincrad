# H127 measured street-graph fallback

H126 left the live Carpenter body 0.715 m from the exhausted iron source with only 5.6833 of 60 work seconds. The source was already exhausted, so no new material request or paid observation was valid.

The scene now sends `recover_material` through `PlaceSteering.direction_to_point`, which follows the measured public-road graph and the existing bounded capsule-sweep helper. It clears the material helper cache before the route starts. The destination remains the source center; the world still decides the 0.45 m arrival gate, collision resolution, work duration, stock and receipt. The fallback does not create stock, bypass a collider or retry a command.

Owned Godot 4.7.2 checks, all with zero paid calls, passed:

- `town_materials_acceptance.gd`: 60 checks, 0 failures.
- `town_material_blocked_state_acceptance.gd`: 278 checks, 0 failures.
- `town_baking_route_acceptance.gd`: 63 checks, 0 failures.
- `town_places_route_acceptance.gd`: 18 checks, 0 failures; 87.45 m measured graph route, 1.35 m/s maximum, one receipt after restart.

The older standalone material fixture probe was attempted from the current fixture base but stopped at its submit precondition. That does not replace H125's accepted physical replay (0.29 m approach, 60 seconds, one recovered unit); it is recorded as a test-environment limitation. The canonical live save was not opened or rewritten during H127.
