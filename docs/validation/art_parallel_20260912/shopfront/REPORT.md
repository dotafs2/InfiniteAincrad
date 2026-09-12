# Shopfront detail delivery — 2026-09-12

Delivered **16 different static facade attachments**, 158,786 triangles in total and 27,231,200 bytes of self-contained runtime GLB data. The editable Blend, deterministic Blender source, generated packed normal maps, per-asset manifests and seven real renders are present. No external or private asset was read.

The visuals follow the adjacent first-floor street kit: light warm stone, muted oak, sage glazing/paint, clay tiles and restrained cloth. Distinct construction includes a multi-pane shop display, open service hatch, diamond leading, radial oculus, roof dormer, hollow chimney, supported eave, carved corbel, curved scalloped canopy, open portal, closed glazed door, herbal niche and four sculptural trade emblems.

## Validation

- `glb_binary_audit.json`: **16/16 pass** on the actual GLB chunks/accessors. Valid float32 positions, unit NORMAL attributes, tangents/UVs, triangle indices and positive triangle area; standard PBR factors; embedded images; matching SHA-256, triangle counts and dimensions; no unexpected node transform and the attachment bottom at glTF Y=0.
- `glb_roundtrip_validation.json`: **16/16 pass** through Blender’s real glTF importer, checking finite positions, actual split corner shading normals, UVs, triangle area and material assignments.
- Initial review found exposed eave rafters, brick-course ends extending past the chimney boundary and presentation panels intersecting roof backs. The final rebuild moves the rafters below the tiles, uses half-brick ends for staggered courses and moves the non-exported panels clear. The first window is accurately labelled 18 panes.
- The first roundtrip checker incorrectly treated Blender’s derived per-vertex averaged normals as the glTF shading normals. Ten derived averages on the diamond lattice were zero; exported NORMAL attributes and all 15,942 imported split-corner normals were valid. `inspect_import_normals.json` preserves that investigation. The final checker checks actual imported corner normals while retaining the zero-derived-average count as diagnostic information. The initial stderr/exception is preserved; it is not recorded as an initial all-pass run.
- The first Blender invocation had the application’s default exception exit behavior. Subsequent Blender runs use `--python-exit-code 1`; report contents and not exit status alone determine acceptance.

- Closeup inspection also found gaps at emblem hanging connections. The final geometry extends the mounting arms, carries the bakery hanger into the pretzel, adds an apothecary crossbar, and connects the tailor hanger to the shears pivot plus a fine link to the needle eye. All four affected images were regenerated after the final geometry freeze. No further asset expansion or visual micro-adjustment followed.

## Files and scope

Source and Blend: `Art/Generated/ShopfrontDetails20260912/`. Runtime: `game/assets/generated/shopfront_details_20260912/`. Render/check evidence: this directory. `delivery_integrity.json` records source, Blend, texture and render hashes. Each runtime manifest entry records dimensions, triangles, materials, source, origin and its GLB hash.

These are static visual attachments. There is no Godot placement, collision, interaction, animation, navigation, LOD, interior gameplay or maintained-world change. Receiving walls/roofs require appropriate openings and placement. The portal is about 1.99 m clear above the base plinths (about 1.91 m between the plinth feet); no engine traversal is claimed. Glazing is opaque reflective PBR. The hatch is fixed open and the shop door fixed closed.

## Asset catalogue

| Asset | Blender XYZ dimensions (m) | Triangles |
| --- | --- | --- |
| SF01_Mercer_Display_Window | 2.960 × 0.550 × 2.212 | 5,196 |
| SF02_Folding_Service_Hatch | 2.550 × 1.185 × 2.181 | 6,892 |
| SF03_Diamond_Lead_Casement | 1.640 × 0.470 × 2.130 | 5,314 |
| SF04_Radial_Attic_Oculus | 1.230 × 0.273 × 1.230 | 15,756 |
| SF05_Tiled_Gable_Dormer | 1.780 × 1.405 × 2.163 | 9,236 |
| SF06_Open_Flue_Chimney | 1.390 × 1.095 × 1.887 | 17,040 |
| SF07_Clay_Tile_Rain_Eave | 2.650 × 0.945 × 0.800 | 8,604 |
| SF08_Carved_Timber_Corbel | 0.250 × 0.970 × 1.400 | 2,756 |
| SF09_Scalloped_Cloth_Canopy | 2.620 × 1.244 × 0.745 | 26,212 |
| SF10_Stone_Double_Portal | 2.690 × 0.570 × 3.400 | 11,340 |
| SF11_Glazed_Shop_Door | 1.540 × 0.452 × 2.783 | 3,632 |
| SF12_Herbal_Stone_Niche | 1.560 × 0.840 × 2.117 | 7,720 |
| SF13_Bakery_Pretzel_Emblem | 0.860 × 0.890 × 1.140 | 3,768 |
| SF14_Apothecary_Mortar_Emblem | 0.770 × 0.965 × 1.140 | 1,548 |
| SF15_Tailor_Shears_Emblem | 0.660 × 0.890 × 1.140 | 5,448 |
| SF16_Barber_Spiral_Emblem | 0.336 × 0.998 × 1.140 | 28,324 |

## Rendering and cleanup

`overview.png`, `detail_windows.png`, `detail_roofwork.png`, `detail_canopy_portal.png`, `detail_craft_emblems.png`, `close_bakery_apothecary.png` and `close_tailor_barber.png` are actual Cycles renders from the delivered geometry. The whole library stays at metric scale in the overview; the last two images bring the small emblems close to the camera.

All owned Blender and wrapper process records are exited; their PIDs and timings are retained in `process*.json`. No engine, browser, paid model loop, helper or worker was launched by this subtask outside those recorded processes. No shared STATUS/ROADMAP, git index, commit, push or world state was modified.

Usage identity for root incremental accounting: `01a09448-df53-7ed1-baf7-38ccf6795bef`. The root owns the carried usage ledger; this worker did not modify or reset it.
