# Frostlight asset inspection files

These files are the local Blender import inspection outputs for the repaired
Frostlight assets. The runtime-authoritative pixel review is in
`../gpu-review-final-01/`, captured from Godot on Apple M1 Pro OpenGL.

- `glacier-solid.png`: imported glacier material render.
- `glacier-wire.png`: imported glacier wireframe/topology view.
- `ice_rock-solid.png`: imported ice-rock material render.
- `ice_rock-wire.png`: imported ice-rock wireframe/topology view.
- `glacier-inspection.blend`: saved Blender inspection scene for the glacier.
- `ice_rock-inspection.blend`: saved Blender inspection scene for the ice rock.

Source authoring and runtime files:

- `../../../../art_source/frostlight/frostlight_assets.blend`
- `../../../../art_source/frostlight/asset-manifest.json`
- `../../../../assets/frost/glacier.glb`
- `../../../../assets/frost/ice_rock.glb`
- `../../../../tools/build_frost_blender_assets.py`
