# SAO-Inspired Town Quarter Study — 2026-09-21

## Reference and scope

The layout study uses the public Town of Beginnings map and the first-floor
overview as high-level composition references:

- Project Aincrad's [Town of Beginnings map](https://vierespada.github.io/ProjectAincrad/tob.html)
  shows a circular service town with a central arrival area and named shops.
- The SAO Progressive community's [first-floor map](https://w.atwiki.jp/saop/pages/13.html)
  places the Town of Beginnings at the southern edge of the first floor and
  describes a fortified, semicircular city with a central plaza, market and
  church landmarks.

This repository does not copy either map image, any game texture, or a third-party
model. The deliverable is an original procedural blockout called **South Gate
Quarter**: a circular arrival plaza, eight streets, a southern gate, an outer
fortification, and seven abstract service landmarks.

## Files

- `game/spatial/sao_town_quarter_layout.json` — authored layout and landmark IDs.
- `game/spatial/sao_town_quarter.gd` — procedural geometry, collisions, route marks,
  overview camera and lighting.
- `game/scenes/sao_town_quarter.tscn` — standalone scene.
- `game/tests/sao_town_quarter_acceptance.gd` — offline structure acceptance.
- `Run-SaoTownQuarter.ps1` — interactive launch.

## Navigation boundary

This is a separate visual/navigation study. It does not rewrite the active save,
resident homes, production state or current first-floor layout. The next integration
step is to register the quarter's landmark IDs as a new graph snapshot and connect
one real resident route after the visual proportions are approved.

## Local check

```powershell
python -X utf8 tools/run_godot.py --godot <Godot-4.7.2.exe> --name sao-town-quarter --timeout 45 --out tmp/sao-town-quarter-20260921 -- --headless --script res://tests/sao_town_quarter_acceptance.gd
```
