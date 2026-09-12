# Shopfront details — 2026-09-12

Sixteen original, static shopfront attachments for the first-floor starting town. Warm light stone, muted oak, sage paint, terracotta and subdued cloth follow the adjacent street kit. Geometry is authored in metres with real bevels, framing, hardware, tiled roof overlaps and thickness. No external asset, photograph, font file, anime frame, character or private state is used.

The kit contains an 18-pane shop window, open folding service hatch, diamond lead casement, radial attic oculus, gable dormer, open-flue capped chimney, clay tile rain eave, carved timber corbel, curved scalloped cloth canopy, stone arched double portal, glazed shop door, herbal amphora wall niche and four sculptural craft emblems: bakery, apothecary, tailor and barber. These use different construction and silhouettes, rather than colour variants.

`ShopfrontDetails20260912.blend` is the editable metric asset library and presentation scene. Each named asset collection contains its complete mesh; presentation panels, cameras, lights and labels are separate and are excluded from the individual GLBs. `build_shopfront_details.py` and the small local `geometry_helpers.py` reproduce the geometry and seeded 512px normal maps. The helper is adapted from the repository's original `StreetStructures20260912` library; it does not import or execute that other batch. Packed normal maps and standard metallic/roughness PBR materials are embedded in the runtime GLBs.

The runtime GLBs and duplicate manifest are in `game/assets/generated/shopfront_details_20260912`. In Blender, +X is right, -Y faces the street and +Z is up. The origin is at the asset's bottom centre on wall plane Y=0. Roof attachments use their bottom base. Standard glTF conversion maps this to Y-up. Each manifest entry records bounds, size, origin, triangle count, materials, source and SHA-256.

All pieces are **static visual assets**. The hatch is a fixed open display pose; the shop door is closed. Glass is deliberately opaque, muted reflective PBR glazing. There is no animation, interaction, collision, navigation, LOD, interior gameplay or maintained-world placement. Doors, recesses, dormers and the niche require a matching opening in the receiving building. The chimney has an open brick shaft beneath a supported tiled hood; roof flashing is not provided. The portal's clear width is about 1.99 m. Corbels and small trade emblems are human-scale accents, not whole buildings.

Rebuild from the repository root with Blender 5.2 on `PATH`:

```powershell
blender --background --threads 2 --python-exit-code 1 --python Art/Generated/ShopfrontDetails20260912/build_shopfront_details.py
```

The script and its local `geometry_helpers.py` are self-contained in this directory; no date-bound wrapper, other art pack or network access is required. Optional script arguments after a `--` separator are `--no-render` or `--validate-only`.

Real Blender renders and `glb_roundtrip_validation.json` are under `docs/validation/art_parallel_20260912/shopfront`. The validation imports each actual exported GLB and checks finite positions, normals and UVs, triangle area, material assignments and dimensions. It does not establish engine collision or gameplay behavior.
