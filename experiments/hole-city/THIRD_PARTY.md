# Third-party notices

## Godot-Hole.io template

- Author: mbMayer, copyright 2024.
- Repository: https://github.com/mbMayer/Godot-Hole.io
- Pinned commit: `cf75504a150c3cf179bb8e80b93309fb62a7a729`.
- License: MIT; full text retained in `LICENSE` and
  `third_party/mbmayer/LICENSE`.
- Reused: `Scenes/hole.tscn` and the controller/CSG-subtraction approach adapted
  in `scripts/hole.gd`. The original source snapshots are excluded from Godot
  import by `.gdignore`; `project.godot` is stored as `project.godot.upstream`.
- `third_party/mbmayer/provenance.json` records each snapshot's byte hash.

## Slipgate Texture Warp shader (archival source only)

The upstream project includes `Shaders/holeshader.gdshader`, attributed by its
README to [Creatorbyte's Slipgate Texture Warp shader](https://godotshaders.com/shader/slipgate-texture-warp/).
That source page states MIT. The original snapshot is retained for provenance;
Sink City's running scenes do not use it and it is excluded from the game pack.

## Godot Engine and bundled dependencies

Godot is copyright its contributors and distributed under MIT. See
https://godotengine.org/license/ and
https://docs.godotengine.org/en/stable/about/complying_with_licenses.html.
Windows packages include `GODOT_LICENSES.txt`, generated from the exact engine
build's license text, dependency copyright notices and dependency license texts.
Retain these notices when redistributing a build.

## Sink City additions

The portrait city kit is original mesh authoring in Blender 5.2.2 LTS, exported
as GLB. No external model-library or reference-game asset was incorporated.
The local authoring process used the official
[Blender MCP addon command handlers](https://github.com/ahujasid/blender-mcp/blob/a9769e413da276ef3e0867404aaa4b941a32202d/addon.py)
through the project's synchronous background adapter. Upstream's GUI server
rejects background Blender, so its GUI timer/socket startup was not used. The
upstream addon is a local tool dependency and is not embedded in the game.
Its exact SHA-256 is recorded in the portrait validation asset audit.

Copyright 2026 InfiniteAincrad contributors. MIT; see `LICENSE`.
The city, UI, icon, street/window shaders and generated audio are original.
Hole.io is referenced only to identify the gameplay/template inspiration; this
project is not affiliated with its publisher and contains no proprietary game
assets or extracted commercial code.
