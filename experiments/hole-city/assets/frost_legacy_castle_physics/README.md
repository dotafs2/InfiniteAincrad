# Frozen Frost castle physics

`legacy.json` preserves only the five pre-royal-redesign castle inputs used by
Frostlight's inherited bodies. It is 591,431 bytes and contains no render
vertices/indices, normals, colors, textures, or Blender source scene.

Each asset has its original source SHA-256, measured normalized AABB, every
distinct original float32 x/z vertex pair for exact admission under nonuniform
scaling, the exact Godot `create_convex_shape(true, true)` point sequence used
for bottom-rim sampling, and unchanged compound collider point lists. Full
precision JSON preserves the engine float values. Rim samples cannot safely be
replaced by compound-collider vertices: the historical global visual hull also
contained decorative geometry.

The immutable visual inputs are preserved under
`build/royal-castle-20261008/baseline/assets/fairytale_castles` and identified by
the embedded source hashes. `tools/extract_frost_legacy_castle_physics.gd` checks
all five source digests before extraction. It requires an absent output path
and never constructs a game or accesses a player save. The runtime provider
pins the resulting payload SHA-256.

Frost uses one cached temporary cube during the inherited synchronous build;
the normal ice conversion removes those visual owners before rendering. The
cube is never used to measure bodies or construct collision shapes. Court
assemblies use the same frozen provider, while non-architectural actors retain
their existing mesh/physics path. Toy City uses its new castle assets normally.

This isolates mesh revisions, not future parcel-plan edits. A shared
`toy_neighborhoods.gd` change still requires explicit Frost parity review.
