# Hole Feast app icon

`app-icon.png` is the current original iOS / App Store launcher artwork: a
black hole swallowing salmon sushi, with a croissant and strawberry falling in.
The master is an opaque, square RGB8 PNG at1024×1024, without baked round corners.
`manifest.json` binds its bytes and original generated source. No competitor
artwork was used as an image reference.

The iOS preparation helper selects this master, verifies its dimensions,
transparency and manifest, and copies it unchanged to `native/icon.png` before
exporting all16 AppIcon catalog entries. Its source and derived bytes are bound
separately from the accepted gameplay gate. `.gdignore` keeps branding out of
ordinary gameplay imports. The legacy root SVG remains the historical desktop /
Web launcher icon; it is not the selected native icon.

The unsigned build24 export verifies all16 catalog entries and the exact
1024-square master. This does not establish signing, installation or upload.
See `docs/app-icon-food-20261002/CONTINUE.md` for current evidence and handoff.
