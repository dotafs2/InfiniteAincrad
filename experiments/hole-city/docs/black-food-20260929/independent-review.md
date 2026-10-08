# Independent black-food review

Reviewed by the city/combat agent, not the food fix author. PASS on the frozen food runtime, with the rendering limits below.

The pinned Godot GLES3 instance layout allocates the packed color lane when custom data is enabled. The original 527 food batches left that lane at zero while the scene vertex shader multiplies mesh color by the instance color. Enabling colors and explicitly writing WHITE preserves all four mesh color components, including ingredient finish alpha. The source change only initializes identity multipliers; it does not change the ingredient shader or geometry.

## Evidence

- `tests/food_color_review.gd`: 1,109 strict checks in current source and, with the explicit baseline option, the copied original isolated PCK. The old package reproduces 527 hazardous batches; the new source has zero. All 34 generated mesh-array hashes, 32 ingredient colors and the ingredient shader match exactly. Default test mode is self-contained and suitable for the exported PCK.
- Independent rerun of the source-only setter trace: 1,120 strict checks, 2,678 recorded native setter calls. Every slot in all 527 static allocations and rain capacities 16, 32 and 64 receives WHITE; release, compaction and reuse preserve the original mesh. The wrapper records original arguments then calls the original native setter. This instrumentation is explicitly separate from the permanent package test.
- Independent fresh windowless OpenGL execution: 256 cases / 258 checks, covering every ingredient in original-zero, fixed-WHITE, standalone and nonzero-custom-data modes, for both albedo/roughness and emission/specular outputs. Integer attribute 15 carries packed half colors through the actual vertex multiplication; shipped ingredient fragment equations execute. Fixed instancing matches standalone within one RGBA8 unit, including gloss; old zero lanes produce black. This is Apple Software Renderer execution, not a Godot/browser screenshot or hardware GPU certification.

The headless Dummy renderer returns zero RGB even after a known WHITE write. The initial getter-based failure is retained under `review/dummy-getter-failure`; final assertions do not misrepresent that getter as GPU state. The source-only trace plus actual GL test cover the otherwise unobservable write path. The original author's arbitrary brightness failure for legitimately dark seaweed is also preserved; the independent oracle checks exact authored colors rather than a brightness threshold.

Artifacts are under `artifacts/black-food-20260929/review/`: `source.json`, `old-package.json`, `source-provenance.json`, `setter-trace.json`, `setter-trace-provenance.json`, `gpu/independent-result.json`, and `final-provenance.json`. Strict diagnostics contain no unexpected engine or script errors. All owned helper processes exited successfully. No browser, foreground app, normal save or runtime capture was used.

## Frozen hashes

- `tests/food_color_review.gd`: `f84607af1799ad3c2e99e7ed9a24381b48e4972caf768c608ad8cd7157f298ad`
- `fidelity/food_city.gd`: `4a98288a9d9698829c41010b50f66de87b1d6aeafea2f7b58a48fdcf66f54fd4`
- `fidelity/food_glaze.gdshader`: `54a890cdf065e4613a203e7fc9834d4440dd73d27ab6a47e3179aa27f721e2cc`
- `artifacts/black-food-20260929/review/independent_gpu.py`: `2cb8c5176f53f3938fa160b86b97da5f0c16f9ae179b06c499a474d18b58b1cc`
- `artifacts/black-food-20260929/source_color_write_trace.gd`: `1f748ed27fa8e317bb89c739b43c6ac60ee69eb15781d750bde5ad8d474f6605`
