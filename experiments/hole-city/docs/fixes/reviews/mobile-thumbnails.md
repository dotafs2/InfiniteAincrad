# Independent review: mobile collection thumbnails

Reviewer: food/filtering agent, not the UI implementation author.
Date: 2026-09-28. Status: **PASS for source behavior and resource configuration**.
This is not a rendered edge-quality or physical-device performance acceptance.

Reviewed `fidelity/ui.gd` and `tests/mobile_thumbnail_acceptance.gd`. Independently
reran the latter with Godot 4.7.2, `--headless --fixed-fps 60 --test`. All 695
checks pass; the completed log passes the same strict error classifier as the
release gate. Only the exact pre-existing macOS system-CA diagnostic is
excluded. No runtime source was edited by this reviewer.

The backing-size calculation combines the viewport stretch and CanvasItem
transform once. It does not multiply browser DPR, window scale, or display
scale a second time. An independent geometric calculation from the seven
reported backing sizes agrees within one pixel of floating-point rounding:
the 1170 × 2532 portrait profile uses 313 × 230, and the cap is 432 × 318.
The unchanged logical texture rectangle is 144 × 106. `EXPAND_IGNORE_SIZE`
prevents a larger raster from changing its layout or minimum size; linear
filtering applies only to the texture presentation. Mouse-ignore behavior
preserves the existing overlay buttons and swipe handling.

The 2× MSAA setting is applied to the visible card SubViewports. Main-scene
4× MSAA, the home miniature's existing dimensions, camera framing and card
layout stay unchanged. Source review and runtime assertions cover all 44
skin IDs over bounded pages, one animated model and one `UPDATE_ALWAYS`
target, reuse on resize, and no repeated invalidation of a stable inactive
cache. Changed density schedules inactive cards for one redraw. Refresh or
exit immediately disables old targets and stops model processing before
queued deletion; five repeated exit/re-entry cycles leave no retired owners.
Round entry releases collection cards. Coin balance, ownership and equipped
skin remain unchanged by resize and pagination, and test saves are isolated.

Evidence and exact reviewed hashes:

- `artifacts/visual-quality-20260928/filtering/thumbnail-independent.json`
- `artifacts/visual-quality-20260928/filtering/thumbnail-independent.log`
- `artifacts/visual-quality-20260928/filtering/verification-summary.json`

Headless rendering does not consume `UPDATE_ONCE`; the author test explicitly
models an already-rendered inactive cache instead of misreporting the dummy
renderer as a real frame. The tests establish requested AA, backing-pixel
dimensions, layout and lifecycle. Browser GPU output, actual DPR reporting,
AA appearance and sustained device cost remain open. The Mac is currently
locked, so the already-authorized browser cannot be inspected through the
available computer-use tool.
