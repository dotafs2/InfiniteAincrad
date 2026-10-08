# Snack Garden offline preview

This is a labeled **offline preview, not a Godot/browser/device recording**.
The current game's own meshes and a real headless physics run supply the scene
and animation. Lighting and presentation are approximate.

Ready media:

- `opening.png`: 540 × 960, original opening food composition.
- `overview.png`: 960 × 960, current connected city and food structures.
- `food-collapse-rain.mp4`: H.264/yuv420p, 540 × 960, 12 fps, 120 frames,
  ten seconds, no audio. Fast-start metadata permits ordinary player playback.
- `collapse-poster.png`: decoded video frame at 2.5 seconds.

The clip shows the real 59-piece authored heap near `(4.608904, 6.901029)`.
A disclosed test fixture pre-grows the mouth to level 5/radius 3.5 and moves it
six metres over 1.5 seconds, starting at t=1. Runtime admission, support release,
gravity, contacts and collection remain unchanged. All 59 pieces are physically
consumed by t=4. Five real rain waves spawn thirty food bodies during the ten
seconds. Score begins at zero and reaches 122 solely through actual collection;
no score is injected. This is a controlled physics showcase, not a normal human
playthrough or evidence of human pacing.

`simulation.json` retains the exact 12 Hz pose-capture timeline from the 60 Hz
physics run. `frame-0000.json` through `frame-0119.json` contain actual geometry
transforms and cuttable-ground geometry; `render-meshes.json` is the current
mesh cache. The headless exporter runs only with `--test` and no progress path.

The two stills use the existing windowless CGL renderer with copied shipped
food shader equations. The full-scene CGL attempt reached its 120-second bound
after producing those stills; its owned process ended. The video therefore uses
a small CPU triangle renderer over the same current meshes and transforms.
It applies the shipped ingredient sRGB and food-reflection equations at mesh
vertices, with approximate studio lighting. It is not a reproduction of the
Godot GPU renderer. No scene appearance has been invented by an image model.

Omitted from this preview: game UI, NPC rigs, decorative hole skin, contact
crumb/ripple presentation, contact shadows/postprocessing and audio. Opponents,
NPC movement and traffic controllers are disabled for the physics fixture.
The real rain controller and individual food rigid bodies remain active.

The permanent media captions identify the approximation. Do not use the clip
as browser, phone, visual-parity, performance or complete-gameplay acceptance.
`manifest.json` records source/helper/media hashes, exact codec metadata,
simulation facts and limitations. All twelve recorded runtime/asset source
hashes match the final v0.8.0 release manifest.

Verification: all 120 H.264 frames decode without error; the dimensions,
12 fps and ten-second duration were checked with ffprobe. Opening, overview,
before-collapse, initial-fall and decoded middle-collapse images were inspected.
The exporter log contains no unexpected engine diagnostic (only the documented
macOS certificate-store message). All owned exporter, CGL, compiler, CPU-renderer
and encoder processes have exited. No runtime source, live preview, player
progress or foreground application was changed.
