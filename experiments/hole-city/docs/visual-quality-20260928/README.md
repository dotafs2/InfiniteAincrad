# Visual-quality alignment — 2026-09-28

Follow-up: [v0.8.1 implementation and acceptance](../mobile-visibility-20260928/README.md)
implements the thumbnail and filtering priorities and adds the requested
camera reveal. The research baseline below is retained as historical context.

The user asked how the reference games achieve cleaner edges and a rounded,
polished mobile appearance. Three independent reviews cover reference
evidence, our runtime and official mobile-rendering guidance. This is a
research and implementation-priority report. It does not change the running
v0.8.0 build or certify that it already matches the references.

## Decision

Improve the visible rendering paths in this order: collection thumbnails,
texture/procedural-detail stability, selected model silhouettes and materials,
then lighting balance and small finishing effects. Preserve the main 4× MSAA
and existing scene shadows. A larger post-processing stack is not a substitute
for fixing undersampled detail or coarse geometry.

The earlier offline showcase has no comparable multisample or cast-shadow
pipeline. It must not be used to decide that runtime shadows or antialiasing
are disabled, or to approve the finished art direction.

## Evidence and responsibilities

- [Reference evidence](reference-observations.md): retained observation ledgers,
  installed reference apps and official store listings. Store presentation is
  a visual target, not a device-performance measurement or proof of its shader
  implementation.
- [Independent runtime audit](runtime-audit.md): precise code locations and
  hashes, including visible thumbnail rendering and food texture filtering.
- [Official mobile-rendering research](mobile-rendering-research.md): Unity and
  Godot documentation, renderer constraints and proposed device validation.

The local engine reports `4.7.2.stable.official.ed1daf0bf`. The current game uses
Godot Compatibility; native Unity/URP examples are useful engineering guidance,
not directly transferable project settings. The renewed computer-use inventory
reports a locked Mac and no accessible app/browser. No reference game was
launched or played in this audit.

A read-only metadata check did confirm four installed Unity iPhoneOS builds.
Installed Hole.io 2.53.5 has Unity 6000.3.2f1 data; Hole Em All 2.15.1 has Unity
2022.3.67f2 data. Both package Universal Render Pipeline assemblies. This
establishes the engine and packaged capability, not the selected runtime
pipeline, AA level, shadow quality or post-processing volumes. See the
[metadata record](installed-reference-metadata.json) for paths and hashes.
Their native iPhone delivery also differs from our current browser preview;
neither renderer choice nor engine brand alone guarantees the desired look.

## Concrete gaps and intended corrections

| Desired result | Verified current implementation | Corrective work and acceptance |
| --- | --- | --- |
| Clean skin-selection silhouettes | Visible card targets are 144×106 with no MSAA override. The separate 2× large preview is currently hidden. | Enable AA on the visible cards and size their targets for the actual displayed pixel footprint with a cap. Preserve one active animation, cached inactive cards and release-on-exit. Review every page at real phone size. |
| Stable roads during camera motion | The 2048² food street texture has no mip chain and uses a non-mipmapped linear sampler. | Generate mips and use a matching mipmapped sampler; evaluate selective anisotropy. Compare oblique roads at opening and grown-hole zoom without altering routing or hole cuts. |
| Stable small windows and paving | Procedural miniature windows, city paving and lane details use hard thresholds. | Filter masks using screen-space derivatives of continuous coordinates and reduce detail below pixel size. Test moving footage; more MSAA alone does not filter the inside of a triangle. |
| Rounded, readable hero shapes | Some city/skin primitives have 8–12-sided silhouettes. Food already has rounded boxes, 20-segment large forms and ingredient-specific roughness. | Refine only prominent near-camera silhouettes, preserve shared meshes and existing food detail. AA cannot round a polygonal silhouette. |
| Convincing skin bodies and food highlights | Skin motifs are mostly unshaded and card worlds have no lighting rig. Food has broad stylized reflections and per-ingredient finish. | Prototype lit cosmetic bodies with a consistent preview light; retain unshaded water/fire fields. Compare baked goods and icing separately. Test the suspected food color-space mismatch with identical actual-engine swatches before changing color math. |
| Objects visibly rest on the ground | Main sun and home miniature shadows are enabled. The offline video omits cast shadows. | Evaluate the actual scene's shadow extent, bias, ambient balance and contact contrast. Preserve moving/removable shadows; do not bake edible-object shadows permanently into world ground. |

## What can be learned from other implementations

Official Unity mobile guidance uses a combination of controlled lighting,
simple shaders, batching/instancing and selective reflections. It presents
baked lighting and blob shadows as possible cost reductions; those require
special care here because almost every object can move, collapse or disappear.
We should retain the necessary visible shadows and reduce their cost using
bounded coverage and measured settings. This is our application of the
[Unity mobile-art guidance](https://unity.com/how-to/mobile-game-optimization-tips-part-2),
not a claim that Hole.io uses that exact recipe.

MSAA, texture filtering and shader-detail filtering solve different problems.
Godot documents that MSAA primarily addresses geometry-edge coverage. Our
browser renderer does not gain built-in FXAA/TAA by copying a Unity camera
setting. [Godot antialiasing](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html)
and the [renderer matrix](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
define the available paths.

Reference screenshots from [Hole.io](https://play.google.com/store/apps/details?id=io.voodoo.holeio&hl=en)
and [Hole Em All](https://play.google.com/store/apps/details?id=and.brainworks.holeemall&hl=en)
remain useful composition/color targets. The available screenshot links and
search descriptions do not establish actual runtime antialiasing, shadow
resolution or post-processing settings. No proprietary setting is asserted
without a readable source or runtime measurement.

## Required proof after implementation

Each corrective unit needs an independent reviewer. Collect actual engine
images and motion at the same camera, map state and pixel dimensions. Record
the build, renderer, AA, viewport size and device. Inspect sharp edges, small
patterns, skin pages, food highlights, shadows and the hole boundary.

On an iPhone 14-class device, run both maps and dense rain/collapse cases for
ten active minutes, reporting displayed-frame cadence, stalls, memory and
thermal behavior. Keep CPU simulation timing separate from browser/GPU work.
Resolution reduction is a quality tradeoff and must never be labeled lossless.
The existing Mac headless CPU reports do not certify sustained phone 60 FPS.

No runtime files, deployment, player saves or reference app files were changed
in this research pass. No outside person was contacted.
