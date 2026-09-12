# Artisan workshops — 2026-09-12

18 original static decorative props for a warm first-floor town. Source dimensions are metres; source meshes are Z-up and GLBs use the standard Y-up conversion. All sources remain independent and editable in the Blender library.

## Contents

- `build_workshops.py`: standalone procedural builder; does not import or run another batch.
- `artisan_workshops_library.blend`: full-scale named source collections plus a separate presentation collection.
- `manifest.json`: individual dimensions, triangle counts, PBR material names, file sizes and SHA-256.
- Runtime assets: `game/assets/generated/artisan_workshops_20260912/*.glb`.
- Actual Blender renders and validation: `docs/validation/art_parallel_20260912/workshops/`.

## Rebuild

From the repository root, using the installed Blender executable:

```powershell
& "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" --background --threads 2 --python Art/Generated/ArtisanWorkshops20260912/build_workshops.py
```

The builder exports every prop at its own ground-plane origin, performs real GLB reimport validation, saves the metric library and renders four review images. No image textures or external resources are required. The source collections are hidden for the catalog; unhide an `AW_...` collection to edit full-scale geometry. `PRESENTATION_ONLY` contains scaled duplicates and labels that are not included in GLB files.

## Verified scope

All 18 exports passed an actual Blender GLB round trip, source/import triangle count comparison, finite-coordinate and non-degenerate-triangle checks, valid metallic/roughness/base-color checks, ground contact and dimension comparison, and a GLB JSON check for external URIs. The comparison tolerance is 0.0001 m. The rendering log may contain Blender 5 material API deprecation warnings; these are not mesh validation failures.

These are decorative props. They do not implement production, resource generation, NPC knowledge or profession abilities, collision, animation, LOD, or persistence. No game scene or world state was modified.

## Authorship and dependencies

The workshop silhouettes and assemblies are original procedural work created by GPT-6 Astra for the explicitly authorized art batch. Minimal generic mesh/PBR helpers were copied from the repository-original `Art/Generated/MarketLife20260912/build_market_life.py`; that script was only read, and none of its builders were executed. No third-party models, images, source character files, or private saves were imported. This delivery does not choose a project-wide redistribution license.

The final generator uses a continuously transported tube cross section to avoid reference-axis twists on vertical rings and curved ropes. The earlier render attempt was stopped only to apply this geometric fix; `process_verified.json` identifies the final run.

## Asset inventory

| Asset | Dimensions X × Y × Z (m) | Triangles |
| --- | --- | ---: |
| treadle_potters_wheel | 1.050 × 1.236 × 1.224 | 6628 |
| arched_pottery_kiln | 1.480 × 1.390 × 2.085 | 9796 |
| clay_drying_shelves | 1.451 × 0.660 × 1.740 | 18748 |
| horn_anvil_stump | 1.135 × 0.660 × 1.058 | 3584 |
| forge_with_bellows | 2.080 × 0.925 × 2.400 | 3392 |
| smith_tong_rack | 1.280 × 0.650 × 1.580 | 3720 |
| sage_dye_vat | 1.400 × 1.080 × 1.528 | 6032 |
| laced_leather_frame | 1.520 × 0.720 × 1.940 | 3832 |
| jewelers_drawbench | 1.380 × 0.654 × 1.329 | 5968 |
| candle_mold_rack | 0.910 × 0.526 × 1.502 | 5076 |
| screw_book_press | 0.990 × 0.740 × 1.360 | 5892 |
| coopers_stave_jig | 1.054 × 0.830 × 0.895 | 13016 |
| bowyers_shaping_form | 1.440 × 0.640 × 1.407 | 4120 |
| rope_winding_winch | 1.300 × 0.890 × 1.160 | 8032 |
| grain_hand_quern | 0.826 × 0.947 × 1.112 | 4164 |
| honey_basket_press | 1.100 × 1.035 × 1.744 | 9200 |
| bakers_oven_peel_rack | 1.180 × 0.610 × 1.913 | 2632 |
| treadle_shaving_horse | 1.480 × 0.607 × 1.099 | 2220 |

Total: 116,052 triangles, 5,139,688 GLB bytes.
