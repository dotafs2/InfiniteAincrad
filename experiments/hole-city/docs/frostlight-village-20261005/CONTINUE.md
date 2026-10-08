# Frostlight Village iteration

This is the recoverable handoff for the user-authorized three-hour map iteration
started on 2026-10-05. The heartbeat ends at 2026-10-05 07:11:49 UTC / 15:11:49
Asia/Shanghai. Do not extend the window or replace the submitted 0.13.0 / build 31.

## Intended result

Frostlight Village is an original cel-shaded Ice Age expedition field. The
inherited toy parcel colliders remain the edible small-to-giant route, while
their castle meshes are replaced by high-gloss faceted glaciers, layered ice
faces, edible ice rocks, snow shelves, frozen ponds and snow drifts. The visual hierarchy is Arctic
wildlife first, with research outposts and an icebreaker as supporting props.
The map is selectable as `frost`, starts a 90-second round and keeps existing
Sunny City, Snack Garden, Bubble Toy Town, saves and monetization protocols intact.

The second pass adds fourteen polar systems with actual edible bodies and
assembled model parts: polar bears, penguin colony, seals, snow foxes, walruses,
scientists, icebreaker, research stations, igloo observatories, snowmobiles,
cargo sleds, aurora drones, glacier crystals and ice rocks. Individual and grouped targets
use different tiers and scores. Their colliders are inherited real compound
toy bodies; the custom animal and expedition assemblies move and are collected
through the normal gameplay path.

## Evidence

- `artifacts/frostlight-village-20261005/frostlight-city-acceptance-glacial-04.json`
  records 10 passing focused checks. The actual scene has 856 bodies, 145
  snow assemblies, 14 polar systems, 9 ice spires and 3 frozen ponds. All 180
  inherited castle visuals are replaced by faceted glacier silhouettes; the largest
  edible target is 38.04 m high and the body budget remains below 900.
- `artifacts/frostlight-village-20261005/toy-map-integration.json` records 76
  passing checks for map order, audio continuity, pointer selection, isolated
  legacy saves, 90-second timing and the local video continuation protocol.
- `artifacts/frostlight-village-20261005/retention-ui-review.json` records 8,242
  passing UI checks. The chooser now compacts six rows so the new Frostlight
  card stays clear of the persistent bottom dock.
- `artifacts/frostlight-village-20261005/gpu-review-08/` contains actual Apple
  M1 Pro OpenGL frames for the Frostlight home card, six-row chooser, glacier
  overview and a closer polar-life view. The close view shows the penguin
  colony, glacier forms and open ice routes without a castle skyline.
- `artifacts/frostlight-village-20261005/gpu-review-11/` contains the final
  Apple M1 Pro OpenGL frames after the faceted glacier and edible ice-rock pass.
- `artifacts/frostlight-village-20261005/web-gate-02/release.json` records the
  fresh complete source and packaged gate after the Arctic rework: 71,346
  checks in each phase across 91 suites. The local preview is refreshed under
  `build/frostlight-village-20261005/web`.
- `artifacts/frostlight-village-20261005/web-gate-03/release.json` records the
  final source and packaged gate after the glacial facet pass: 71,346 checks in
  each phase across 91 suites.

## Remaining work

### Blender asset rebuild follow-up (2026-10-05)

The original procedural glacier silhouette was rejected during pixel review as
too wall-like. Blender 5.2.2 LTS is now installed at
`/Users/dotafs/Applications/BlenderStandalone.app`; the generator is
`tools/build_frost_blender_assets.py`. It authors an irregular octagonal
faceted glacier, forward snow shelves, mirrored snow mantles, specular ice
materials and separate shard peaks, then exports `assets/frost/glacier.glb`
and `assets/frost/ice_rock.glb`. The source scene is
`art_source/frostlight/frostlight_assets.blend`; the manifest records exact
hashes and the policy that the supplied image only informed broad Arctic cues.

The Godot scene instantiates these GLBs for every edible glacier/rock body and
records their usage in `population_summary().blender_assets`. The earlier
focused receipt `artifacts/frostlight-village-20261005/frostlight-city-acceptance-blender-03.json`
passes 11 checks, including 180 Blender glacier instances and 12 Blender ice
rock instances. The earlier actual Apple M1 Pro OpenGL review is in
`artifacts/frostlight-village-20261005/gpu-review-blender-10/`; it shows the
new faceted ice forms, polar wildlife and the intact open routes. The older
web-gate-03 receipt predates these GLB bytes and must not be presented as the
final gate for this follow-up.

At that earlier checkpoint, the remaining local step was one fresh complete
source/PCK gate after the final Blender bytes were accepted. Native signing,
TestFlight and App Store response remain outside this asset pass; build 31 and
user saves stay preserved.
Do not touch Apple, AdMob, legal agreements, production identifiers, bank/tax
forms or Git publication from this handoff.

That earlier fresh gate is complete: `artifacts/frostlight-village-20261005/web-gate-blender-01/release.json`
reports 71,347 source checks and 71,347 packaged checks with no failures, and
the local preview has been refreshed under `build/frostlight-village-20261005/web`.
This is the final evidence for the Blender follow-up; it is separate from the
previous 71,346-check gates because the GLB bytes and scene scale changed.

## Final state after the visible-angle pass (2026-10-05)

The Apple M1 Pro OpenGL pixels in `artifacts/frostlight-village-20261005/gpu-review-blender-10/`
still showed a broad continuous blue face on the largest glacier. The Blender
generator was therefore iterated again rather than compensating in Godot. The
final asset pass narrows the low core, adds three offset faceted peaks, six
stepped snow tongues, separate +X and +Z snow layers, four deep crevasses and
specular ice ribs. It keeps the GLB as presentation geometry; inherited edible
compound bodies and all gameplay state remain unchanged.

- `artifacts/frostlight-village-20261005/frostlight-city-acceptance-blender-05.json`
  records 11/11 focused checks, including 180 Blender glacier instances, 12
  Blender ice-rock instances, 856 bodies, 1,094 collision parts and the intact
  90-second Frostlight round.
- `artifacts/frostlight-village-20261005/gpu-review-blender-14/` contains the
  fresh Apple M1 Pro OpenGL home, chooser, overview and polar-life frames. The
  overview keeps open routes and wildlife readable; the close frame shows the
  separated peaks, visible snow strata, dark fractures and specular highlights.
- `artifacts/frostlight-village-20261005/web-gate-blender-02/release.json`
  records 71,347 source checks and 71,347 packaged checks across 91 suites with
  an empty failure list. Its isolated local preview is
  `build/frostlight-village-20261005/web-blender-02`; prior previews and
  receipts remain preserved.

Final asset hashes are `glacier.glb` SHA-256
`b62528e2fc254b1a937915c96d95eef55070a7644ca8edb845142a27319e63de`,
`ice_rock.glb` SHA-256
`972d4e366adbceb45bfd3518dd10637ae6f7d7fdbbd3a2e19e5a4ba0c8883d10`, and
`art_source/frostlight/frostlight_assets.blend` SHA-256
`9b5013bfa67de7bc86349599b181c573398d9ffcfcec2bbfe3004b1df0212506`.
The synchronized manifest SHA-256 is
`f1ef30ab0633ea8c94548fa2ae44a2e0232ef471df071f76edaffaeec05c7821`, and the
final generator SHA-256 is
`224ea368541243ab1812675f5aa052d8834729bd9f4539603ee9e6247d9c1216`.
Native signing, TestFlight, App Store response, Apple services and Git
publication remain outside this local asset pass; build 31 and user saves stay
preserved.

## Current repaired state (2026-10-06)

The previous Blender asset pass still showed detached-looking plates because the
source generator mixed open-looking presentation sheets with the body, and its
`cone()` helper left Blender's Z-up cone orientation in a Y-up game asset. The
source topology could be closed while the imported object still appeared to be
sideways. The repair in `tools/build_frost_blender_assets.py` now does the
following:

- keeps the glacier body in the blue ice palette; snow is carried by closed
  caps/crests instead of broad white body faces;
- removes the standalone rear/side snow plates that projected as long bars and
  keeps three short closed crevasses embedded near the front surface;
- rotates cones to the game's Y-up axis and bakes each child rotation into its
  mesh vertices before glTF export;
- replaces the detached ice-rock wedges with a closed RockCore/RockShadow pair
  and a seated RockSnowCap;
- leaves the source `.blend` populated with the authored objects instead of
  deleting them after export.

The repaired source contains 15 objects, 13 meshes and five materials. Every
source mesh has `boundary_edges=0` and `overused_edges=0`; all mesh modifiers
are zero. The focused Frostlight receipt
`artifacts/frostlight-village-20261006/frostlight-city-acceptance-final-01.json`
passes 11/11 checks, including 180 Blender glacier instances and 12 Blender
ice-rock instances. The actual Apple M1 Pro capture is
`artifacts/frostlight-village-20261006/gpu-review-final-01/capture.json`; its
runtime reports `OpenGL API 4.1 Metal - 91.7 - Compatibility - Using Device:
Apple - Apple M1 Pro`. The close and overview frames are in the same directory.

The fresh complete Web Review gate is
`artifacts/frostlight-village-20261006/web-gate-final-02/release.json`: it
reports 71,347 source checks and 71,347 packaged checks with an empty failure
list. Its isolated local preview is
`build/frostlight-village-20261006/web-final-02`. The first complete source/PCK
attempt reached the end of its suites but failed before receipt publication
because the requested preview parent did not exist; its exact failure evidence
is preserved at
`artifacts/frostlight-village-20261006/web-gate-final-01-publish-parent-missing/`.

The generated asset inspection files are preserved at
`artifacts/frostlight-village-20261006/asset-inspection-final-03/`:
`glacier-solid.png`, `glacier-wire.png`, `ice_rock-solid.png`,
`ice_rock-wire.png`, `glacier-inspection.blend`, and
`ice_rock-inspection.blend`. The source and runtime asset files are
`art_source/frostlight/frostlight_assets.blend`,
`art_source/frostlight/asset-manifest.json`, `assets/frost/glacier.glb`,
`assets/frost/ice_rock.glb`, and their Godot import outputs under
`.godot/imported/`.

Current hashes:

- `assets/frost/glacier.glb`: `9478760b5d160fa58fc5539851697be89fa787404118e996a064dec510f82858`
- `assets/frost/ice_rock.glb`: `78624fef40dcec99e3a22ac638d2d21ce570d963e0f0c841000f48875b7bdd0e`
- `art_source/frostlight/frostlight_assets.blend`:
  `1d29c8f9700b15cbd7526996a552962b86957ad7d98e2d64aa903e203e7e5d79`
- `art_source/frostlight/asset-manifest.json`:
  `d934484ce583d49df92ed75b6b4de8ce75d4252298948a462c135cad0ad8ed78`
- `tools/build_frost_blender_assets.py`:
  `6e34a5bbcc7b2c0130f19ea13d8c00a79cf10ae2155c93f47dc0a05743dbab90`

Evidence receipt hashes for this repair are
`frostlight-city-acceptance-final-01.json`
`e87e134b66f444784b916b9727e9ef096f72b3bf19acae3ec85bbefb2c48de69`,
`gpu-review-final-01/capture.json`
`1996cef1c14084c70703022b385f12b1aa03c3d06d2ced873642ceeabe46ef8b`, and
`web-gate-final-02/release.json`
`c1bed38288a67e0aebaa9745da370ff3393e607eb8acd9470eb011aa3b9edd17`.
The first gate attempt's preserved `export.log` hash is
`d27eb102c4376f70efb81c1296eb960151cb849d8c73e4a05c86116c36ac0045`.

All earlier previews, receipts, user saves, Sunny City, Snack Garden,
Bubble Toy Town, Toy Town, version 0.13.0/build 31, and the existing economy
remain preserved. Native signing, TestFlight, App Store response, Apple
services and Git publication remain outside this local asset pass.

## Anchor and normal repair after the visual review (2026-10-06)

The remaining broken-looking triangles were traced to the Frostlight-only GLB
boundary, not to the shared ToyCity renderer. The hand-built Y-up glacier body
and peaks used inward side winding, so Godot's double-sided material lit most
facets from the back. In addition, the GLB pivot was at local ground Y=0 while
`ToyBody` is centred at `height/2`; every imported glacier was therefore
suspended in the collider's upper half. The first runtime scale also mapped a
large castle collider directly to one monolithic GLB, exaggerating the wall
silhouette.

The Blender generator now reverses the body/peak winding, keeps the closed
snow ledges and embedded crevasses, exports the authored game-Y coordinates
with `export_yup=False`, and uses Blender 5.2.2 LTS. The runtime importer in
`fidelity/frost_city.gd` uses the Godot-imported aggregate bounds to centre the
asset in X/Z, aligns its true local `min_y` to the edible collider floor, and
keeps visual height at 62% for glaciers and 90% for ice rocks so the inherited
collider remains the gameplay envelope. Points, support graphs, growth, coins
and saves remain on the shared body path.

The current generated files are:

- `tools/build_frost_blender_assets.py`
- `art_source/frostlight/frostlight_assets.blend`
- `art_source/frostlight/asset-manifest.json`
- `assets/frost/glacier.glb`
- `assets/frost/ice_rock.glb`
- `fidelity/frost_city.gd`
- `tests/frostlight_asset_closeup_capture.gd`
- `tests/frostlight_asset_alignment_acceptance.gd`
- `tests/frostlight_gameplay_parity.gd`

The dedicated close-ups are
`artifacts/frostlight-village-20261006/gpu-asset-closeup-iteration-02/`; the
latest actual Apple M1 Pro OpenGL map pixels are
`artifacts/frostlight-village-20261006/gpu-review-anchor-final-01/`. The
overview shows separated, grounded multi-peak icebergs across the snow field;
the polar-life frame shows the full central glacier, penguins and ice edge
without the old floating-wall presentation. The renderer receipt identifies
`OpenGL API 4.1 Metal - 91.7 - Compatibility - Using Device: Apple - Apple M1 Pro`.

Focused evidence for this state:

- `frostlight-city-acceptance-anchor-02/report.json`: 11/11 checks, 856 bodies,
  180 glacier instances, 12 ice rocks, 1,094 collision parts and the 90-second
  round.
- `frostlight-asset-alignment-04/report.json`: 769 checks, all 192 Blender
  instances checked; worst floor error `1.4341354e-8`, worst centre error
  `1.984066e-8`.
- `frostlight-gameplay-parity-08/report.json`: 12/12 checks; an actual ice-rock
  swallow awards `6` points and an actual glacier swallow awards `96` points,
  each with an exact score delta and one eaten increment; coins use the shared
  score-to-coin formula.
- `web-gate-anchor-final-01/release.json`: 71,347 source checks and 71,347
  packaged checks with an empty failure list; the local preview is
  `build/frostlight-village-20261006/web-anchor-final-01`.

Current asset and evidence hashes:

- `assets/frost/glacier.glb`: `47821f19dc950ca1892288513130ef8716610da17f26f0904908157424c7af57`
- `assets/frost/ice_rock.glb`: `c2d52ff5989ccf5addc8051e1c1bc762b91c5dafe4012360bb1b4c599f186a6c`
- `art_source/frostlight/frostlight_assets.blend`: `6c6fc3e31f71290a41265a684d6aeb6e34088e61e969c63c62ac3c14489a91e4`
- `art_source/frostlight/asset-manifest.json`: `785533842425ea6984ae2f0a00fbfaeec68c52c601e1e95901b2dbd55e4ae26c`
- `tools/build_frost_blender_assets.py`: `ca547dd5d4e8ea066d2a8083bcd9783a02b59df7d9ceae6f6b9f760130aa4204`
- `fidelity/frost_city.gd`: `0dca29e5eccedc792e6b7f3405da14105024340c5b81cb754e95ea95589a3fd1`
- `tests/frostlight_asset_alignment_acceptance.gd`: `71b85ca5bdd8af28cee67524c8081751008771c995a5c2633f62518823606e13`
- `tests/frostlight_gameplay_parity.gd`: `89bdf3a48f0d7aabe7c4e1571690f00dfb896d247a383a3a925a4d39d95d5cda`
- `frostlight-city-acceptance-anchor-02/report.json`: `b4467c336be6a2484a2a7c481239fc084f86b86c2d8b0ab35301a4a60edaa719`
- `frostlight-asset-alignment-04/report.json`: `d888de101df6a48709dce1c4681c4cec5b546fd2b89c98b1ba165c5da7945cb1`
- `frostlight-gameplay-parity-08/report.json`: `b216422b0a3e58f8f56fd59ce729b92eab10c662f26bcbf157fc625c6ce7862c`
- `gpu-review-anchor-final-01/capture.json`: `1996cef1c14084c70703022b385f12b1aa03c3d06d2ced873642ceeabe46ef8b`
- `web-gate-anchor-final-01/release.json`: `06cbd6813d7c66944999777591f6bf11e460b615cffa9c92adec190476614210`

All previous inspection directories, GPU captures, failed gate evidence,
previews, user saves, preserved maps, version 0.13.0/build 31 and the existing
economy remain untouched. No Apple, AdMob, tax, banking, TestFlight, App
Review, upload or Git publication action was performed.
