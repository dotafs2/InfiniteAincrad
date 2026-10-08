# Current UI comparison evidence

`our-ui-layouts.png` shows the home screen, Classic skin library, and food-map
HUD from v0.5.5. These are **code-derived 2D layout reconstructions, not Godot
or browser screenshots**. Gray areas and labeled placeholders explicitly omit
the world, city miniature, and skin previews. They do not mean those views are
empty in the game. World-space player labels are also excluded.

`tools/export_ui_layout.gd` mechanically redirects the current `fidelity/ui.gd`
draw commands into JSON. The actual UI code supplies positions, colors, copy,
font sizes, counters, and button styles. `tools/render_ui_layout.py` rasterizes
those commands with the bundled Fredoka font. Shadows, border rasterization,
text emboldening, and button text baseline are approximate. Defaults come from
an isolated `--test` session, not the player's saved progress. No runtime UI
design was changed for this comparison. JSON files contain the UI source hash.

The authorized browser inspection returned `Browsers: Error: User unavailable`.
No replacement browser, foreground game window, or screenshot was used.

Public references shown separately in the conversation:

- Hole.io skin-library store image, a historical interface version, indexed by
  https://mwm.ai/apps/hole-io/1389111413 and served from Apple's image CDN.
- Hole Em All Level 33 promotional screenshot, indexed by
  https://hole-em-all.en.uptodown.com/android .

Reference images were not downloaded or added to game assets. These references
are not captures of the user's installed versions.

Reproduce from the game directory:

```sh
.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/export_ui_layout.gd -- --test
python3 tools/render_ui_layout.py
```

The second command requires Pillow with FreeType variation-font support.
