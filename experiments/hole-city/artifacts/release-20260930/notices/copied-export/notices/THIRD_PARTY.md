# Third-party notices

## Fredoka font

The unmodified variable Fredoka font is bundled in `assets/fonts/Fredoka.ttf`.
Copyright 2016 The Fredoka Project Authors. Licensed under SIL Open Font License
1.1, retained in `assets/fonts/OFL.txt` and included in exported packages.
Source: [Google Fonts Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka).

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
Windows packages include `GODOT_LICENSES.txt`; the guarded Web export includes
`notices/GODOT_LICENSES.txt` and `credits.html`. These are generated from the
packaging engine's license text, dependency copyright notices and dependency
license texts. The Web notice manifest records that engine's hash and version.
Retain these notices when redistributing a build.

## Shader and UI visual studies (v0.5.0)

The new water, accretion, aurora and solid-skin shaders are original code.
ShaderToy/author pages and Hole.io were studied as visual references, not
bundled sources or assets. See [reference links and implementation limits](docs/skin-ui-20260928.md).

## Shop Theme background music (v0.11.1)

"Buy Something!" from "Shop Theme", by Cleyton Kauffman, is used in both maps.
The author page https://opengameart.org/content/shop-theme declares CC0 1.0:
https://creativecommons.org/publicdomain/zero/1.0/.
The full normal Ogg version (not the Radio Edit) was attenuated by 7.1 dB and
re-encoded for mobile download size; tempo, duration and arrangement are unchanged.
See `assets/audio/MUSIC_CREDITS.txt` and `assets/audio/music_manifest.json` for
source archive/member hashes and processing measurements. CC0 applies to this
recording independently of the game's MIT license. Credit is retained voluntarily.
The ZIP contains no separate license file; the creator's page is the license evidence.

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
The city, UI, icon and street/window shaders are original. Earlier synthesized
music is archived outside the game pack; current background music is credited above.
Hole.io is referenced only to identify the gameplay/template inspiration; this
project is not affiliated with its publisher and contains no proprietary game
assets or extracted commercial code.
