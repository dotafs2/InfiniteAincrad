# Travel and river-trade art

36 distinct original props for the first-floor town: 24 travel/cargo pieces plus 12 river/trail pieces. Warm oak, canvas, muted sage, terracotta, leather and metal match the neighboring market pack.

- `travel_cargo_library.blend`: 24 editable travel/cargo assets, named collections and an independent presentation collection.
- `river_trade_library.blend`: 12 editable river/trail assets.
- `manifest.json`: combined inventory, dimensions, triangle counts, PBR materials, hashes and source library paths.
- Runtime exports: `game/assets/generated/travel_cargo_20260912/*.glb`.
- Render evidence: `docs/validation/art_parallel_20260912/travel/`.

Source units are metres, Z up; GLB exports use Y up. Asset geometry is grounded at local Z=0. The catalog normalizes display sizes; the source collections and GLB files retain actual metric dimensions. Cameras, lighting, labels and display floors are presentation only and are excluded from the individual GLBs.

Rebuild from the repository checkout with Blender 5.2, in this order:

```powershell
blender --background --threads 2 --python Art/Generated/TravelCargo20260912/build_travel_cargo.py
blender --background --threads 2 --python Art/Generated/TravelCargo20260912/build_river_trade.py
blender --background --threads 2 --python Art/Generated/TravelCargo20260912/validate_travel.py
```

The second builder merges the two inventories by asset ID. Rebuilding only the first builder writes its 24-piece inventory; run the second builder to restore the full 36-piece inventory. Generation overwrites this pack's authored outputs.

Geometry and materials are procedural. `geometry.py` adapts the project's original MarketLife20260912 primitive helper; its curve frames were corrected to avoid twisting wheel rims. No external meshes, textures, fonts, character files or private saves are included. All materials use exported constant metallic/roughness PBR values and UV0; these are not texture-baked assets. Project-wide redistribution licensing remains the maintainer's decision.

These are decorative static meshes. No collisions, LOD levels, animation rigs, functional vehicles, usable production equipment, navigation or resident behavior are provided. The empty courier cage contains no animal. Model import validation does not establish gameplay or persistent-world capability.
