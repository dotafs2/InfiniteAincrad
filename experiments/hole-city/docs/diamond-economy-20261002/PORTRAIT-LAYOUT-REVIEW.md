# Portrait layout review

Reviewed on October 2, 2026 after the user reported that the home screen and game controls were compressed into the middle of the iPhone 16 Pro Max screen. New layout work supersedes native test build 16's UI; its original signature, installation, save and ordinary-launch evidence remain preserved. A new physical build has not been verified by this review.

## Distinguishing rendering from control layout

The preserved physical reports `artifacts/device-acceptance-20261001-06/native-qa/city-report.json` and `food-report.json` identify iOS, a 1320×2868 backing window, a 540×1173 expanded root viewport, and safe pixels `(0,186)` with size `(1320,2580)`. Their captured frames render the world across the entire backing frame. These are historical 0.12.3 measurements, not measurements of the newly changed source or a substitute for fresh device acceptance.

The installed build 16's exported `SinkCity-Info.plist` separately has `UIRequiresFullScreen=true`, portrait-only supported orientations, a launch storyboard, and a hidden status bar. Current project settings already use `canvas_items`, `expand`, and portrait. Godot's [multiple resolutions documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) recommends this combination and anchoring controls to use the expanded canvas. No unnecessary native fullscreen flag or engine patch was added.

The additional fixed UI transform caused the reported problem: `ViewportLayout.fit()` scaled a 540×960 sheet uniformly, then vertically centered that sheet inside the safe rectangle. The camera/world could fill a tall screen while every authored HUD/home coordinate remained inside the middle sheet.

Using the preserved safe-pixel dimensions gives these geometric comparisons:

| Logical viewport | Safe top | Previous fixed-sheet top | New canvas top | New authored canvas height |
| --- | ---: | ---: | ---: | ---: |
| 440×956 points | 62 | 100.888889 | 62 | 1055.454545 |
| 1320×2868 backing pixels | 186 | 302.666667 | 186 | 1055.454545 |
| 540×1173 rounded Godot viewport | 76.073222 | 123.677824 | 76.073222 | 1055.209205 |

At the point scale, the old vertical centering added almost 39 points above and below the fixed sheet. Safe top/bottom insets are retained for the Dynamic Island and home indicator. Controls now have additional logical height to distribute between those edges rather than extra blank padding from centering.

## Shared API and implementation scope

`fidelity/viewport_layout.gd` keeps the existing `position`, `scale` and `safe` dictionary keys and adds `size`. Position begins at the safe top; uniform scaling preserves button shape and the authored 540-unit width; `size.y` consumes the actual safe height. Short or wide windows still fit the minimum authored sheet with uniform targets and horizontal centering.

`safe_rect_from_pixels(viewport,pixels,physical)` performs one native-pixel-to-logical conversion, clamps to the viewport, and has a valid whole-viewport fallback for unavailable startup measurements. It does not multiply device pixel ratio again or hardcode one phone's insets. The UI agent owns consuming `layout.size` and sharing the same responsive rectangles between drawing and touch controls. Game and UI source were not edited by this review agent.

## Acceptance boundaries

The new isolated `tests/viewport_layout_acceptance.gd` checks the preserved 16 Pro Max geometry at point, backing-pixel and rounded Godot scales; top/center/bottom input round trips; shape preservation; short/tablet/landscape bounds; and invalid or clipped safe measurements. The allocated focused headless run passes all 41 checks with exit 0, no engine errors, and unchanged project/layout/test hashes before and after. Exact report, engine log and hash receipts are preserved in `artifacts/simple-ui-20261002/viewport-layout-01/`. The owned engine helper is finished and cleaned up.

The release coordinator still needs a new source/package gate after all agents finish, and actual 440×956 silent visual review of the responsive home and HUD. A subsequent signed build must preserve the latest immediate phone save before installation. Only fresh physical screenshots/measurements can confirm the user's current home/game layout complaint is resolved on the phone. No account, financial, production-ad, upload, or phone operation was performed by this agent.
