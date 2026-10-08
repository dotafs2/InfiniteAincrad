# Ground and miniature detail filtering

Implementation date: 2026-09-28. Scope: `fidelity/asphalt.gdshader`,
`fidelity/facade.gdshader`, and `assets/food_city/streets.png.import`.

The food street atlas now requests a complete mip chain and the ground shader
uses clamped trilinear sampling. The authored 2048 × 2048 atlas is unchanged.
No anisotropy override was added: trilinear filtering is the bounded initial
correction, and an oblique real-device comparison is required before adding
an additional sampling cost. The RGB chain occupies 16,777,215 bytes, about
4 MiB more than its 12 MiB base image; this is raw inspected image storage,
not a claim about actual driver allocation or total scene memory.

City paving joints, parking stripes, dashed road lines, sidewalk borders,
walking-path borders and park stripes now use pixel-footprint coverage. The
repeated-band helper integrates painted intervals across periodic seams, so a
thin line retains fractional coverage and several repeats within one pixel
approach their area average. Derivatives come from continuous world or UV
coordinates before periodic operations. Broad ground surfaces remain sharp;
there is no whole-frame blur, resolution reduction, new overlay mesh or change
to the physical ground cuts, route coordinates, palette or nominal widths.
The old unused procedural food branch was removed because the authored atlas
already replaced its result on every food frame.

The home miniature's facade applies the same filtering to window openings,
frames, pane shading and crossbars. Per-window hash animation approaches its
mean before cells become subpixel. The wall/glass palette, near-camera window
dimensions, floor/column parameters, roughness endpoints and visibility
contract remain intact. This does not alter imported catalog building art.

## Author verification

- `tests/procedural_filtering_math.py` extracts the actual scalar helper text
  from both shipped shaders, compiles it as C++ float arithmetic and compares
  it with an independent oracle that enumerates physical interval overlaps.
  Each shader passes 616 repeated-band cases, including negative coordinates,
  seams, thin lines and pixel footprints spanning 1–16 whole periods. Asphalt
  also passes 616 finite-band cases. Maximum periodic coverage error is
  0.000550; maximum whole-period phase error is below 0.000001.
  Evidence: `artifacts/visual-quality-20260928/filtering/mask-math.json`.
- `tests/procedural_filtering_acceptance.gd` inspects the actual imported
  Texture2D and verifies all 11 stored mip levels, complete base RGB equality,
  bounded image storage and the shader resource contracts. All 27 source
  checks pass after root's serialized import. The engine log passes the release
  gate's strict diagnostic classifier (only its exact pre-existing macOS CA
  diagnostic is excluded). Evidence: `filtering/resource.json`,
  `filtering/resource.log` and `filtering/verification-summary.json` under the
  artifact directory above. Isolated exported-package verification is left
  to the final coordinated gate.

The native numerical probe is not a GLSL render. Headless resource checks do
not prove shader edge quality or mobile frame time. Root coordinates shader
compilation and a non-author review before release. Actual moving-camera
browser captures and ten active minutes on each map on an iPhone 14-class
device remain required. The locked Mac currently prevents the authorized
browser review; this is not a user-permission refusal.
