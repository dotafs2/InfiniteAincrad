# Black-food hotfix delivery — v0.8.7

The urgent fix was released before the collection/expansion feature branch was
ready. Its immutable source snapshot is `build/black-food-hotfix-source`: the
verified v0.8.6 release inputs plus only the instance-color fix, its two QA suites,
a version bump and a more complete release dependency inventory. The live main
source was already being developed toward v0.9.0 and is not claimed identical.

Every static-food and settled-rain MultiMesh explicitly enables color data and
initializes each native instance color to WHITE. The previous custom-data-only
buffer zeroed the shared packed color lane, multiplying actual mesh colors by
black. Materials, palettes, meshes, gloss and collision shapes were unchanged.

- Author: 55 permanent scene checks, 1,120 source-only setter-trace checks and
  96 actual shader/palette cases.
- Independent review: 1,109 permanent scene checks, an independently rerun
  setter trace and 256 windowless OpenGL cases / 258 checks.
- All 53 original-plus-hotfix suites passed both source and isolated PCK phases:
  35,173 checks each.
- The ten served HTTP artifacts matched the tested release hashes after an
  atomic preview-directory switch. PCK SHA-256:
  `fce614575d1a8914496318283c9365f4eca891e971803f8dd1628d17e39b4c63`.

The earlier release input inventory omitted the referenced Scenes/ and shaders/
directories. An initial snapshot import correctly failed rather than exporting a
partial build. Those unchanged dependencies were copied with supplemental
hashes, and both release gates now include these directories. Failed import and
gate evidence remains in `artifacts/black-food-20260929/`.

See [author diagnosis](food-color-fix.md), [independent review](independent-review.md)
and `artifacts/black-food-20260929/delivery.json` for exact provenance. The OpenGL
renderer was Apple's software renderer. These are actual shader pixel tests,
not browser screenshots or an iPhone GPU/frame-rate certification. No existing
browser tab was reloaded or captured, no player save was changed and no Git
publication was performed.
