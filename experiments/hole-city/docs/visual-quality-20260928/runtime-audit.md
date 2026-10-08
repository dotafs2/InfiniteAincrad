# Runtime visual quality audit — 2026-09-28

Independent reviewer: city-motion subagent. Scope: read-only source inspection for an iPhone 14-class browser running the current WebGL Compatibility export. No game, shader, project setting, asset, deployment or player save was changed. No rendering or performance run was started. This document identifies implementation gaps and candidate work; it does not certify rendered reference-game parity or sustained mobile 60 FPS.

## Main conclusion

The highest-value runtime improvements are sharper collection thumbnails, filtered procedural detail and road textures, and selective silhouette/material refinement. The main scene already requests **4× MSAA**, and its directional light still casts shadows. The previous offline showcase omitted the engine's multisampling and cast-shadow path; it is not a reliable baseline for those two runtime features. A large post-processing stack is not the first corrective step.

Reference screenshots can establish the desired visible result, but they cannot identify a proprietary game's exact post-processing stack. Recommendations below are for our implementation, not claims about Hole.io's internals.

## Current configuration and concrete gaps

| Area | Current evidence | Assessment |
| --- | --- | --- |
| Main rendering | `project.godot:23–26`: Compatibility on desktop/mobile, `msaa_3d=2`. | The enum value is **4×**, not 2×. Preserve this baseline while measuring actual device cost. |
| Main resolution | `project.godot:12–19`: 540 × 960 design size, `canvas_items`, aspect `keep`. | This is a layout base, not a permanently 540-pixel-wide 3D render target. Inspect actual canvas/backing-store dimensions and device scale before diagnosing undersampling. |
| Home miniature | `fidelity/ui.gd:65–69`: 640 × 560 with 2× MSAA; displayed with aspect preservation at `:96–100`. | Already antialiased. Check actual screen size before increasing its resolution. Its procedural windows still need shader filtering. |
| Large skin preview | `fidelity/ui.gd:105–109`: 360 × 190 with 2× MSAA. | Currently hidden and disabled at `:331–334`. Improving this unused target will not improve the current collection screen. |
| **Visible skin thumbnails** | `fidelity/ui.gd:880–892`: fixed 144 × 106 SubViewport and texture display, no MSAA assignment. | A concrete gap: new Viewports default to disabled MSAA. High-density display scaling can further enlarge these small raster targets. |
| Preview scheduling | `fidelity/ui.gd:255–260` animates only the selected card; `:324–332` releases cards and disables hidden main previews. | Preserve this optimization while increasing thumbnail quality. Do not render all 44 skins continuously. |
| City procedural detail | `fidelity/asphalt.gdshader:34–59` uses hard `step`, `fract`, `mod` and boolean edges for paving, lane marks and paths. | Thin shader-drawn lines can alias within triangles; increasing geometry MSAA alone does not fix this. |
| Home facade detail | `fidelity/facade.gdshader:11–25` uses hard thresholds for window/frame/cross masks; `fidelity/art.gd:256–257` requests 30 columns and up to 26.5 floors on a small miniature. | Fine repeating detail can crawl or disappear as the model rotates or shrinks. This shader affects the procedural home miniature; current catalog buildings instead use the palette material below. |
| **Food street atlas** | `fidelity/asphalt.gdshader:7` explicitly selects `filter_linear`, sampled at `:79`; `assets/food_city/streets.png.import:26` disables mipmap generation. The source PNG is 2048 × 2048. | Bilinear filtering alone does not prefilter large minification. Oblique/distant road detail can shimmer. Both import settings and sampler hint need to change for mipmapped sampling. |
| Main shadows | `fidelity/game.gd:81–85`: one directional sun, energy 0.95, `shadow_enabled=true`; home miniature also enables shadows at `fidelity/ui.gd:84`. | No global shadow-off regression was found. Shadow distance, bias and filtering are not explicitly tuned here; confirm their appearance at opening and grown-hole camera distances before changing them. |
| Batched objects | `fidelity/static_batch.gd:24`; `fidelity/food_city.gd:425,456`; `fidelity/mesh_batch.gd:50–60` construct normal mesh instances without turning casting off. | The batching optimization does not deliberately remove scene-wide shadows. |
| Deliberate shadow exclusions | `fidelity/skin_visual.gd:39` disables cosmetic part casting; `fidelity/food_city.gd:557–564` makes crumb/glaze impact effects unshaded and non-casting. | These are local decorative exclusions, not evidence that building/NPC/food shadows are disabled. |

Godot documents the MSAA enum, its disabled Viewport default and the limits of MSAA on shader aliasing in the [Viewport reference](https://docs.godotengine.org/en/stable/classes/class_viewport.html). Its [resolution guide](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) distinguishes `canvas_items` from low-resolution `viewport` stretching.

## Rounded form and material findings

City primitives still have deliberately coarse silhouettes: spheres use 10 radial segments and 5 rings (`fidelity/art.gd:12–17`); inherited cylinders use 8 segments (`scripts/city.gd:65–70`). The two cylindrical home towers use that helper (`fidelity/art.gd:251`). Skin motif cylinders/capsules use 12 segments (`fidelity/skin_motifs.gd:9–16`). Their visible polygon corners are geometry, not missing antialiasing. Flat box/extruded edges in `skin_motifs.gd:6–7,18–37` also remain hard.

**Food geometry is already more refined.** `fidelity/food_city.gd:56–72` substitutes rounded boxes, 20-segment rounded discs and 20-segment/8-ring large spheres; small garnish remains cheaper. `fidelity/food_surface.gd:15` documents 300 triangles per rounded box, and `:35–55` implements the beveled disc. Donuts use 24 × 10 torus segments (`fidelity/food_shapes.gd:46`). Increasing every food primitive globally would multiply a substantial existing geometry budget. Prioritize large, near-camera buns, yolks, cakes and selected preview ornaments only after comparing equal-size crops.

Skin motifs are primarily **unshaded**, because `fidelity/skin_motifs.gd:59–64` uses `flat_material`, implemented at `fidelity/skin_visual.gd:30–34`. Their rounded normals cannot produce ordinary lit highlights with that material. Collection card worlds (`fidelity/ui.gd:880–890`) currently contain a model and camera but no light/environment; merely changing motifs to lit materials could make cards dark. A lit cosmetic-body variant therefore needs a consistent preview lighting setup, while water/fire/plasma fields and the dark swallowing opening keep their intended unshaded behavior. Keep geometry outside the swallowing disk and preserve all collision/admission behavior.

City props use a shared roughness of 0.78 (`fidelity/catalog_city.gd:388–391`); buildings use roughness 0.82 (`fidelity/palette.gdshader:8`). This supports a matte appearance but reduces differentiation between painted, plastic and glass surfaces. The current building material also fades to 0.22 alpha near the player (`fidelity/catalog_city.gd:763–765`), so replacing it with a purely opaque material would break visibility behavior. Prefer a small material palette or encoded per-part finish over a separate unique material for every prop, and keep fractured pieces consistent with the parent building.

Food already has ingredient-specific finish: icing/yolk/syrup roughness 0.20, selected moist ingredients 0.27 and baked bread 0.58 (`fidelity/food_surface.gd:57–62`). `fidelity/food_glaze.gdshader:27–32` decodes vertex color, uses roughness 0.18–0.70 and adds view-dependent broad reflections. These reflection contributions use `EMISSION`, so they are a stylized highlight and do not disappear in a light's shadow. Tune strength and width against actual frames before adding bloom or sharper specular; tiny highlights can themselves shimmer.

Ambient intensity is 0.78 for the city and 0.48 for food (`fidelity/game.gd:78,114`). This may affect contact contrast, but flatness cannot be diagnosed conclusively from the offline render, whose lighting differs. The runtime environment does not explicitly enable or tune glow, SSAO or color adjustments in this setup. Absence of those settings is not by itself a defect or proof that the reference uses them.

## Safe priority order

1. **Establish a real comparable baseline.** Capture the same camera, zoom, screen pixel size and game state for city opening, grown-hole city, food opening/collapse, home miniature and the collection grid. Record actual canvas dimensions, active AA and backend. Keep offline reconstructions visibly labeled; they cannot approve shadows or device smoothness.
2. **Fix the visible collection path first.** Trial 2× MSAA on the 144 × 106 card Viewports and a capped resolution multiplier based on their displayed pixel footprint. Compare against 4× on those small targets only if needed. Retain render-once inactive cards, one animated selected card and release on exit. Do not spend work on the currently hidden large preview. Validate page flips and menu memory as well as visual edges.
3. **Filter detail at its source.** Make city paving/window/lane masks derivative-aware: use pixel-width transitions derived from unwrapped world/UV coordinates, and reduce/fade details below a pixel. Do not apply derivatives to a discontinuous `fract` value without handling its seam. Generate food atlas mipmaps and use a mipmapped linear sampler; evaluate low-cost anisotropic filtering for oblique roads if available. Keep world layout, colors, hole cuts and street routing unchanged.
4. **Improve selected silhouettes and previews.** Raise the most visible 8–12-sided city/skin forms to a bounded 16–24-segment trial, and add small bevels only where they materially change a near-camera edge. Preserve mesh sharing, instances, collision outer bounds and the current higher-detail food overrides. Separately prototype lit cosmetic bodies with matching card lighting; retain unshaded energy effects.
5. **Tune material and contact readability with the existing sun.** Compare city ambient/roughness against the reference, retain food ingredient finish, and inspect shadow bias/distance under the actual follow camera. Keep one principal shadow light and avoid adding many shadowed point lights. If baked local occlusion is used, attach it to the object's own geometry; world-painted dark patches under edible objects would remain after they fall and should not be introduced.
6. **Add a small finishing pass only after the above.** Evaluate restrained color adjustment or glow against clipped whites and food-color readability. Treat each effect as an optional measured change. No full-scene blur, global supersampling or new renderer migration should be assumed necessary for a clean rounded style.

The official [AA guide](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html) supports MSAA for geometry edges in all renderers, but its built-in FXAA/SMAA are not Compatibility options; TAA/FSR2 require Forward+. It also describes supersampling's substantially higher cost. The [current renderer matrix](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) identifies Compatibility as the web renderer. Feature support changes across engine versions: its current table lists Compatibility glow/SSAO support, so do not repeat an older blanket claim that both are unavailable. Their existence is not a reason to enable them by default; confirm the installed export's feature behavior and measured cost.

## Acceptance for iPhone 14-class web use

- Visual: same-size before/after images plus camera motion; stable paving/window details, readable 44-skin collection at actual phone scale, rounded hero silhouettes, retained shadow contacts, unclipped icing highlights, and no new halo across the black-hole opening.
- Functional: preserve independent falling pieces, walking/traffic routes, batch wake-up, fracture materials and menu selection behavior. Independently review each implemented unit, as requested by the user.
- Performance: measure the actual WebGL build on an iPhone 14-class phone for a full sustained session on both maps, including food rain and grown-hole collapse. Report frame distribution, missed-frame rate, render size, thermal trend and memory, not only a mean FPS. A 60 FPS target provides 16.67 ms per displayed frame; the previous Mac headless CPU samples do not establish the browser/GPU result.

## Reviewed source fingerprints

| File | SHA-256 |
| --- | --- |
| `project.godot` | `3631c0759174bfb002e6761d75653476007023ce99803f9129f4d022f7d4b1ea` |
| `fidelity/ui.gd` | `f0d132f9b12acd57c8bb773b37ada57edb41b733ce1e144631e73680769b4cd4` |
| `fidelity/game.gd` | `3721eb4de3f20ee9db0f12cd42feb807b7d7efb65cd53832d6c40314d267b2eb` |
| `fidelity/asphalt.gdshader` | `8d0f5a10604165908dda7f68d6f0d602ea065d987f70f4f670f2f3396db964a3` |
| `fidelity/facade.gdshader` | `cb0124fa77535788e65ac35bc4e7b5ce0d36338fe83e1948da7bc11570588159` |
| `fidelity/food_glaze.gdshader` | `24359cbb82e77823f6ea5e6f3410a29dc11c685188d424c23d4111d9b45bba36` |
| `fidelity/food_surface.gd` | `86fecdfb022611d5a03d9b7938abca41e55083498aa5d703ebb898a878fb2a5b` |
| `fidelity/food_city.gd` | `8c17ec4f719f1943f39c8e3131131b255e3bc4112cd2bad74bb8dc8c595edc25` |
| `fidelity/skin_visual.gd` | `06a90d95ad2364d63cc206525c3a5556cc0947471d1439d46627236103a2163c` |
| `fidelity/skin_motifs.gd` | `0db569773783e174b088ecf716bf10592b448c432b7508a173af58665f7a637e` |
| `assets/food_city/streets.png.import` | `b51b237453551e851a82cad32d3b7b740cf45e9186528fff7d47a4baae70c083` |

No runtime modification or deployment is included in this audit.
