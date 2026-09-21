# Starting City whitebox

This preview is a spatial study for an expanded first-floor settlement. It is deliberately
separate from the production town scene and does not load a resident save, call a model, or write
world state.

## Reading the blockout

- The full study plate is 280 m wide by 310 m deep in project units. North is negative-to-positive
  Z in the camera view; the preview prints a north marker.
- Eight large colour zones make terrain and scale legible: city core, central plaza, south gate,
  outer meadow, Horunka forest, lake/wetland, eastern ruins and the north labyrinth approach.
- The city shell is a low pale wall with a southern gate opening. It is a proportional study, not a
  claim that the project has reconstructed a canon street plan.
- Every house is an intentionally plain white 8 m cube. Ten cubes carry the stable resident IDs;
  eight additional cubes are infill. A coloured 10 m pad and a floating label identify each cube.
- Roads are light-grey strips with yellow centre marks. The four authored neighbourhood roads are
  copied and checked against `spatial/living_quarter_layout.json`; five wider macro connectors join
  the city, forest, wetland, ruins and labyrinth. This keeps the design preview and the current
  PCG/navigation source aligned.

## Files and checks

- Scene: `game/scenes/starting_city_whitebox.tscn`
- Builder: `game/spatial/starting_city_whitebox.gd`
- Layout: `game/spatial/starting_city_whitebox_layout.gd`
- Acceptance: `game/tests/starting_city_whitebox_acceptance.gd`

Run the isolated structural check from the repository root:

```text
godot --headless --path game --script res://tests/starting_city_whitebox_acceptance.gd
```

The current check reports 13/13 assertions, 18 house cubes (10 resident + 8 infill), 4 authored
roads, 5 macro roads, 8 terrain zones, zero model calls and no production-world load.

The source study uses the published first-floor motifs as broad composition guidance (a southern
Town of Beginnings, western forest, eastern water/ruins and a northern labyrinth approach). It is
not an official map and should be replaced by an approved authored map before claiming exact
geography.
