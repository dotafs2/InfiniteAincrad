# v0.6.0 UI rebuild evidence

- `release/release.json`: authoritative source/PCK checks and delivered hashes.
- `ui-redesign.json`: the focused 260-check real-pointer UI suite.
- `title-navigation.json`: initial focused title/skin regression.
- `before-ui.gd.txt`: previous runtime UI, retained as comparison evidence.
- `layouts/*.json`: current draw commands, UI source hash and evidence scope.
- `layouts/*.png`: 2D layout reconstructions, **not Godot screenshots**.
- `layouts/icons/*.png`: the actual SVG assets rasterized by Godot for the
  layout renderer; these are authored icons, not extracted reference art.

The layout images intentionally omit 3D city/skin views and world-space labels.
Gray and labeled areas do not mean the actual game is empty. State and scores
come from an isolated `--test` fixture, not from the user's save or a completed
round. Shadows, font emboldening, button text alignment and border
rasterization are approximate. No browser or phone FPS result is implied.

Browser inspection returned `Browsers: Error: User unavailable` on this turn.
The initial release candidate was stopped before delivery to correct thumbnail
framing. Only the final manifest identifies the installed candidate.

See [the change record](../../docs/ui-redesign-20260928.md).
