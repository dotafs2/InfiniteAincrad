# SAO-Inspired Town Quarter Study — 2026-09-21

## Reference and scope

This revision is traced directly from the same circular map image supplied in
the conversation. The whitebox preserves the visible composition: the outer
wall ring, central circular plaza, two red inner arcs, dense building rings,
left-side dark domes, pale-blue water, and green garden clusters. It is a
visual review fixture only; labels and functions are kept provisional unless
the reference image explicitly identifies them.

The color legend follows the image's visible categories:

- white — perimeter wall, walk surfaces and light structures;
- warm gray — paving and building footprints;
- red — the two inner arc structures;
- pale blue — water footprints and fountain basins;
- green — gardens and tree canopies;
- dark — the large left landmark and its domes.

The repository does not copy the source image, game textures, or third-party
models. All geometry is generated from the manually traced polygons in the
layout JSON. Scale and building heights are temporary blockout assumptions.

## Files

- `game/spatial/sao_town_quarter_layout.json` — manually traced reference polygons,
  colors and visible markers.
- `game/spatial/sao_town_quarter.gd` — procedural geometry, overview cameras,
  labels and lighting.
- `game/scenes/sao_town_quarter.tscn` — standalone scene.
- `game/tests/sao_town_quarter_acceptance.gd` — offline structure acceptance.
- `Run-SaoTownQuarter.ps1` — interactive launch.

## Navigation boundary

This is a separate visual study. It does not rewrite the active save, resident
homes, production state or current first-floor layout. Navigation integration and
semantic building assignments wait for visual approval.

## Local check

```powershell
python -X utf8 tools/run_godot.py --godot <Godot-4.7.2.exe> --name sao-town-quarter --timeout 45 --out tmp/sao-town-quarter-20260921 -- --headless --script res://tests/sao_town_quarter_acceptance.gd
```
