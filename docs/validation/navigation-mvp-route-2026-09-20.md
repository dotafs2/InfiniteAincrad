# Navigation MVP Route Validation — 2026-09-20

## Scope

This validation covers the first loaded-world route-graph slice. It does not
claim collision correctness, physical ladder movement, runtime component
mutation, or full-world reachability.

## Runtime

- Godot: `4.7.2.stable.mono.official.ed1daf0bf`
- Mode: headless, no model calls
- Project: `game/`

## Results

### Pure route graph acceptance

Command:

```powershell
godot --headless --path game --script res://tests/town_route_graph_acceptance.gd
```

Result: `13` checks, `0` failures.

The fixture proves a route from `street` through a door, a ladder, and an upper
door to `target_room`; it also proves reverse traversal and stable target ID
`resident_B`.

### Visual house scene acceptance

Command:

```powershell
godot --headless --path game --script res://tests/navigation_mvp_house_acceptance.gd
```

Result: `8` checks, `0` failures.

The scene fixture loads the existing Meshy cottage asset, creates the two-floor
visual shell and ladder, registers three connectors, and executes the same
graph-only route to the upper target.

The fixture now includes a third-person camera attached to `ResidentA`. The
preview follows the route automatically, shows every ordinary and connector
segment as short emissive yellow marks, and supports `Space` pause/resume, `R`
reset, and `C` camera toggle.

Interactive launch:

```powershell
./Run-NavigationMvpHouse.ps1
```

## Route walkthrough video

Godot Movie Maker recorded the desktop OpenGL preview at 30 FPS for 240 frames
(8 seconds). The camera follows `ResidentA`; the route crosses the front door,
the ladder, the upper door, and ends at `ResidentB`.

```powershell
godot --display-driver windows --rendering-method gl_compatibility --fixed-fps 30 \
  --write-movie docs/validation/navigation-mvp-route-2026-09-20/navigation_mvp_route_desktop.avi --quit-after 240 \
  --path game res://scenes/navigation_mvp_house.tscn
```

Output: `navigation_mvp_route_desktop.avi` (10,674,386 bytes).

### Existing navigation bake acceptance

Command:

```powershell
godot --headless --path game --script res://tests/town_navigation_bake_acceptance.gd
```

Result: `10` checks, `0` failures. The two expected reference radius warnings
remain limited to the intentionally old-radius comparison bake.

### Production navigation API bridge acceptance

Command:

```powershell
godot --headless --path game --script res://tests/town_navigation_route_api_acceptance.gd
```

Result: `9` checks, `0` failures. The existing `TownNavigation` object now
resolves both loaded resident IDs and the static connector graph through one
API surface.

### Canonical PCG layout adapter acceptance

Command:

```powershell
godot --headless --path game --script res://tests/town_route_graph_pcg_acceptance.gd
```

Result: `27` checks, `0` failures. The production adapter samples the four
authored roads into `189` regions and `193` connectors, and joins the ends of
the canonical road graph. The ten resident house entries remain present in the
same layout. `living_town.gd` registers this static graph during navigation
setup; the resident job loop still uses the existing collision-aware planner.

## Boundaries

The new route graph is registered by `living_town.gd` through
`town_navigation.gd`, but is not yet selected by the production resident job
loop. The current collision-aware street route therefore remains unchanged. The
next integration step is to map a real loaded resident destination to a graph
region and let the route executor own connector segments while preserving the
existing world save and job gates.
