# Player directional footprints

These three 256 × 256 RGBA textures are orthographic triangle-union projections
of the actual `assets/mobile/infantry.glb`, `gunner.glb`, and `mech.glb` meshes.
They preserve the body, head, arms and weapon silhouettes. No model is changed.

Regenerate with `python3 art_source/bake_player_shadows.py` from the project
directory, using a Python installation with Pillow. The generator writes the
textures, audit manifest and `footprints.gd` together. Model SHA-256 values link
the silhouettes to their precise inputs.

Load `preload("res://assets/mobile/shadows/footprints.gd").DATA[kind]`. Each
entry contains `texture`, native `size: Vector2(X, Z)` and native
`center: Vector2(X, Z)`. For displayed uniform model scale `s`:

```gdscript
plane.size = entry.size * s
shadow.position = Vector3(
    actor_ground_x + entry.center.x * s,
    ground_y + 0.02,
    actor_ground_z + entry.center.y * s
)
```

Keep the plane horizontal and unrotated, anchored to the actor's ground
position. It must not inherit the actor's animated tilt, height or nonuniform
scale. Current scales are 1.65 for infantry and gunner and 0.90 for mech.

The baked sun uses Godot YXZ Euler rotation `(-53, -32, 0)` degrees. Its rays
travel `(0.318913, -0.798636, -0.510368)`; each unit of vertex height projects
`(+0.399322824, -0.639050082)` in ground XZ. This matches the real light's
direction. `PlaneMesh` UVs increase with X and Z; PNG top means min Z. Do not
flip either axis.

RGB is white. Alpha contains normalized coverage with opaque interior and
transparent background. The runtime supplies the shadow color and final
opacity. Linear filtering is appropriate. A modest blur of 0.012 × native
model height has four-sigma padding; every outer pixel has zero alpha. The
textures have no baked rectangular ground background.

This is a fixed-sun projection of the static grounded pose. Flying and rotating
recruits use the runtime's separate projected oval. Changing sun direction or
the mobile mesh requires regenerating these assets.

CPU visual evidence: `artifacts/mobile-shadows/baked-footprints-contact.png`.
The Godot headless direction/UV probe and numerical bake results are beside it.
This evidence verifies geometry, direction and texture bounds; live placement
and performance are verified separately by the integration reviewers.
