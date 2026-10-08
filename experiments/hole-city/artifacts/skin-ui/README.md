# Skin and UI validation, v0.5.0

- `release.json`: authoritative delivered Web files and source hashes, source
  and packaged assertion totals. Seven suites run before replacing the preview.
- `source-*.json`, `package-*.json`: physics, skin structure, menu navigation,
  and real skin-skill acceptance results; adjacent logs preserve failures.
- `portrait.json`: 30 touch, pause, locomotion and asset checks.
- `offscreen-shader-check.json`: compiler/renderer scope, shader hashes and
  two-time image differences for the standalone CGL probe.
- `shader-frame-0.5.png`, `shader-frame-1.5.png`: isolated shader/mesh previews.
  Top row: Core Shell, Copper Ring, Moss Bloom, Gravitas, Lantern.
  Bottom row: Shard, Cinder, Tide, Orbit, Prism Vale.
  These are not Godot/browser captures or device benchmarks.
- `render-inputs.json`, `glsl/`: the exported real meshes/material parameters
  and mechanically wrapped shader equations used by the probe.

Reproduce the shader probe on macOS, without an application window:

```sh
python3 tools/validate_skin_shaders.py --godot .build/godot-standard/Godot.app/Contents/MacOS/Godot
```

Browser review is blocked by the previously saved origin denial, and iPhone 14
GPU/thermal performance is not measured. See the implementation and reference
notes in `docs/skin-ui-20260928.md`.
