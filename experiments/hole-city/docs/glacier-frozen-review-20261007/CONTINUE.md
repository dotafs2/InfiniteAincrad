# Glacier map independent review and rebuild

## Scope and current status

The user requested inspection of the neighboring glacier-map conversation, two
independent reviewers, iteration until both accept, Frozen reference research,
and original Blender models. Both reviewers now accept the actual desktop
presentation and tested collection lifecycle. The final source/exact-package
regression gate passed: 93 suites and 175,836 checks in each phase, with 881
unchanged guarded inputs. Actual browser startup, selection, launch, movement and countdown were verified.
The initial launch click timed out during loading, but the next actual browser
frame confirmed a successful launch. No console warnings/errors were observed.
The muted preview is left paused; evidence is `browser-gameplay.png`.

Current state: `build/glacier-frozen-review-20261007/active-work.json`.
Baseline copies and hashes: `build/glacier-frozen-review-20261007/baseline/`.
This task does not include native uploads, Apple/AdMob changes, review submission,
Git publication, real-save edits, or changes to the accepted economy and 200 skins.

## Completed implementation

- Replaced two conical Blender exports with six original closed, beveled families:
  calving cliff, windcut ridge, terraced shelf, split serac, ice boulder, and
  pancake floe. Editable source: `art_source/frostlight/frostlight_assets.blend`.
  Generator: `tools/build_frost_blender_assets.py`. Blender Z-up converts to glTF
  Y-up exactly once; runtime alignment uses measured imported bounds.
- Snow follows each summit and belongs to its edible owner. Removed detached
  high snow caps. No blank fracture triangles or floating snow observed.
- Replaced the brick streets with irregular frozen leads and blue-violet snow.
  Added 16 independently edible low shoulders around three landmark regions,
  preserving movement routes and stationary footprints.
- Kept established collider, score and support mechanics. There are 872 bodies
  and 14 identifiable polar/expedition types. Existing actor controllers move
  polar animals, researchers and equipment instead of toy/royal silhouettes.
  The 14 static ecology types are not 14 new AI systems.
- Added one shared opaque ice shader with frost contrast, irregular seams and
  restrained edge sheen. It avoids real-time refraction and transparent sorting.
- Restored static batching and merged multipart polar visuals into cached single
  surfaces. The same initial portrait fixture fell from 958 to 464 draw calls.
  The six authored ice meshes contain 1,064–2,790 triangles each. Phone frame
  rate is unmeasured.
- The home miniature uses the same imported glacier families. Existing
  Frostlight Village map ID and save-compatible selection remain.

## Independent review and evidence

`ART_REVIEW.md` and `PLAY_REVIEW.md` preserve the initial rejections and final
acceptances. Both reviewers rejected the baseline and the first box-like rebuild.
The second Blender revision passed model, ordinary portrait gameplay, reverse
angle and home miniature inspection. Root alone ran the heavy engine jobs.

Actual Mac GPU images: `artifacts/glacier-frozen-review-20261007/render-03/`.
Focused receipt `acceptance-03.json`: 2,487 checks, no failures; 609 imported
edible ice owners across six closed, nondegenerate families; maximum floor error
2.38e-7 world units; zero detached snow caps. Three isolated staged lifecycle
probes select real batched rock, glacier and chip owners. Each retires exactly
one batch handle, removes all its visuals and awards one score receipt. These
probes are not ordinary progression evidence.

Two ordinary 90-second rounds use actual movement and charged boost, normal
rivals, original collisions and no grants, teleports or fake collection:

| Run | Checks | Points / coins | Level | Player collections | Glaciers |
| --- | ---: | ---: | ---: | ---: | ---: |
| Seed 7107 | 16 | 341 / 34 | 7 | 107 | 21 |
| Seed 7727 | 1,364 | 409 / 40 | 8 | 92 | 24 |

The shared world collection count is not the player's count. Larger targets
remain at round end. These fixed-step captures do not benchmark real-time FPS.

The second run produces `glacier-normal-gameplay.mp4`: H.264, 540×1174,
89.933 seconds, 30 fps, no audio stream, 13,205,455 bytes. Its 1,348 source
frames use actual `game.elapsed` timestamps; encoding resamples those timings.
A decoded movie frame was inspected after encoding.
SHA-256: `218b48be6e858d52b930943aa6397be094c53df1691d28ecb66f24287a7ef2cc`.

Gallery: http://127.0.0.1:8786/glacier-frozen-review-20261007/index.html
Verified export preview: http://127.0.0.1:8789/?qa=1
Select MORE MAPS → FROSTLIGHT VILLAGE → PLAY. This fresh local origin is muted.
Original preview ports 8786, 8787 and 8788 remain intact.

## References and original design

Research used Disney Animation's primary
[look and lighting study](https://media.disneyanimation.com/technology/publications/2020/siggraph_2020_showYourself.pdf)
and image search for Ahtohallan/Frozen 2 concept art. Useful cues were glacial
mass, frosted crests, luminous edges, deep crevices and unequal ridges. All
shipped geometry and surfaces are original. No Disney characters, images,
textures, logos or meshes are included. This is stylized Arctic game art;
it does not reproduce the film's offline multiple-scattering renderer.

## Preserved failures and limitations

- Sandbox Blender startup crashed before script execution; log 01 is retained.
  Authorized local graphics execution built all six assets successfully.
- The initial focused harness inferred an unsupported dynamic type; parse
  failure 01 is retained and the declarations were corrected.
- An old city fixture expected 70 detached snow nodes. Its failed receipt stays.
  The revised assertion checks ground dressing and ownership of all 180
  snow-covered glacier assemblies instead.
- Browser reference navigation initially timed out, then recovered. No user
  application was closed to resolve it.
- The world keeps a compact board footprint and its proven circulation plan.
  Polar species are stylized; behavior reuses established controllers.
- Native 0.13.0/build 34, real saves, other maps, accounts, the accepted score
  economy and all 200 skins remain. This local content is not in TestFlight.

## Final package receipt

`web-gate-01/release.json` records 18 exact exported files. All 18 on-disk
hashes match. PCK SHA-256:
`81e4541ae53cb16ec051af3d883378701e715e32634870f48e1d26ffde9f8b99`.

Preview server: PID 62115, owned exec session 51054. Keep it running as the
user-facing deliverable. The gate session 17734 exited successfully.
