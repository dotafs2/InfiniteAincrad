# Editable market art

The V5 market is project-authored source from `dotafs2/vibeGamingDemo1`, `Prototypes/StartingTownWalkthrough/Art/ReferenceScenes`. The existing publication inventory permits these environment sources. `source_manifest.json` records their original hashes. Project-wide licensing remains undecided; this copy grants no new third-party rights.

Open `ReferenceScenes/MarketCraftV5/StartingTown_Market_CraftV5.blend` in Blender to edit the complete market. The three procedural normal maps are included under `textures/`; the runtime GLB embeds them. Godot uses `game/assets/market/StartingTown_Market_CraftV5.glb`.

The V5 builder and its Python helper dependencies are included. Export destinations in the V5 builder/base/HQ helpers have been adapted to the formal repository. With Blender 5.2 and its bundled Python/NumPy:

```powershell
blender --background --python Art/ReferenceScenes/MarketCraftV5/build_market.py
```

This rebuilds and overwrites the V5 `.blend`, GLB and manifest; use it only when intentionally revising the art. It was not rerun for this upload. Do not run the historical HQ helper as a standalone full-scene builder: that unrelated entry point references old character assets, which this project does not require or distribute. The V5 entry point uses only its geometry helpers.

## 2026-09-12 parallel art library

70 original static assets — shopfront attachments (16), artisan workshop equipment (18) and travel/river-trade cargo (36) — with four editable Blender source libraries and their runtime GLBs. See [docs/validation/art_parallel_20260912](../docs/validation/art_parallel_20260912/README.md) for the render atlas, per-asset SHA-256 and the binary/Godot validation reports. These are static decorative assets only: no collision, interaction, navigation, LOD or maintained-world integration.
