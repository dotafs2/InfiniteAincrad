# Character art

Seven original Blender character assemblies reproduce the reference's broad toy-military vocabulary: a blue-cap rifle recruit, broad blue minigun soldier, silver recruitable soldier statue, gold armored hero with blue shoulder rockets, pink muscular giant small red crowd enemy and a separate dark-haired first boss in a scarlet leather vest. They are original geometric models, not extracted assets or an exact replica of the unknown source game's sculpting.

Source: `art_source/build_characters.py`. Preview source: `art_source/render_characters.py`. Both run in Blender 4.2.13 LTS. No textures, downloaded models, external add-ons or generated raster images are needed. Front and rear contact sheets in `art_source/` show every model normalized to the same height only for inspection; runtime GLB scales differ.

| Model | Height | Triangles | Material surfaces |
| --- | ---: | ---: | ---: |
| infantry.glb | 1.00 | 3,410 | 1 |
| gunner.glb | 1.80 | 14,308 | 12 |
| gunner_silver.glb | 1.80 | 14,308 | 2 |
| mech.glb | 3.40 | 14,256 | 7 |
| brute.glb | 3.40 | 14,908 | 9 |
| brute_vest.glb | 3.40 | 19,136 | 10 |
| zombie.glb | 0.65 | 1,948 | 1 |

Every GLB contains one mesh node with identity transform, Y-up coordinates, a foot-level origin and Godot -Z forward. Arms hold their weapon forward. The models are rigid posed meshes; the runtime must supply recoil, whole-body sway and death transforms. No skeletal animation is embedded.

Infantry and zombie use a single vertex-colored material for crowd batching. Their `COLOR_0` channels are required. Other characters retain material-separated metal, cloth, skin, eye and emissive reactor surfaces. Model colors are authored in sRGB and converted to linear values for export. All material alpha is opaque.

`python3 art_source/validate_characters.py` verifies all seven actual GLB headers, identity nodes, exact heights, foot origins, absent texture dependencies and one-surface crowd palettes. The output `assets/models/validation.json` records final asset SHA-256 hashes, bounds, triangles and surface counts. The contact sheets are art previews, not evidence of gameplay animation, phone performance or exact reference matching.

The existing Blender executable initializes Metal even in background mode and crashes in the restricted sandbox. Generation and preview rendering used the already installed Blender 4.2 executable with approved escalation. Both owned Blender jobs exit after export/render; no application owned by the user is stopped.

## GPU palette import correction

A Godot 4.7.2 probe found valid vertex colors in both crowd meshes but imported materials with `vertex_color_use_as_albedo=false`, causing white infantry and crowds. `art_source/crowd_import.gd` is now referenced by both models' `.import` files and enables the flag while leaving `vertex_color_is_srgb=false` for the linear GLB palette. The runtime may also apply the same flag defensively.

`art_source/verify_gpu_colors.gd` creates an isolated real GPU scene containing infantry, zombie, vest giant and silver gunner, plus twelve MultiMesh zombie instances. The final `art_source/godot-color-verification.png` visibly verifies colored ordinary infantry/zombie models and the red crowd batch. The final run reports both palette flags enabled, captures 1100×760 pixels on Apple M1 Pro OpenGL/Metal, exits normally and has no engine/script errors. This is an art integration check, not a gameplay test.

The new `brute_vest.glb` retains the 3.4-unit foot-origin contract and adds tan skin, cropped dark hair, a wide red leather back/front, rolled lapels, pockets, metal studs and black gauntlets. `brute.glb` remains the separate pink second boss.

## Crowd silhouette revision

The final crowd GLB replaces the green face and small dark cap with a broad, smoothly rounded crimson helmet, pale pink/tan face and arms, broad muted-red shoulders and simple dark boots. Fine contrasting eye details are reduced so the repeated model reads as scalloped red head shapes at gameplay distance. Height remains 0.65; width is 0.31946 and depth 0.32962 before runtime scaling.

`art_source/verify_crowd_gpu.gd` renders 288 actual MultiMesh instances using 16 columns, 0.36 horizontal spacing, 0.44 row spacing and scale 1.1. `art_source/crowd-gpu-verification.png` and `.log` verify the revised cap field, pale faces, one material surface and enabled vertex palette on the actual Apple M1 Pro GPU. The run exits cleanly. This isolated scene is not a gameplay capture.

Only `zombie.glb` changed in this revision: SHA-256 comparisons confirmed all six other GLBs remained byte-identical. The builder now supports `-- --only zombie`, preserving other models and merging the revised metadata into the existing manifest. The earlier front/rear and mixed-character previews show the previous crowd sculpt; the dedicated crowd GPU preview is authoritative for the final crowd.
