# Sink City

A standalone Godot arcade game: steer a hole through a colorful city, swallow
small props, grow into cars and buildings, then eat the whole district.

## Play

In the Windows download, extract the entire `SinkCity` folder and run
`SinkCity.exe`. No editor or account is required. The source project also runs
from `project.godot` in Godot 4 (tested with 4.7.2, Compatibility renderer).
`Play.cmd` uses a local Windows build, `GODOT_BIN`, or `godot` on PATH.

| Control | Action |
| --- | --- |
| WASD / arrow keys | Move |
| Hold left mouse button | Follow the pointer |
| Touch and drag | Virtual movement stick |
| Escape | Pause / resume |
| R | Restart the current mode |
| F11 | Toggle full screen |

- **Two-minute round:** score against three explicitly labelled CPU rivals.
  After a ten-second opening grace period, substantially bigger holes can eat
  smaller rivals. Being swallowed ends your round.
- **Free roam:** no timer or rivals. Clear all 316 edible objects, including
  towers and the two garden platforms. Roads, borders and water remain scenery.
- A complete object must fit before it starts falling. Points arrive only after
  its roof has passed below the floor. The hole grows continuously with score.
- Bright dots on the minimap are objects you can currently swallow. The best
  score is stored locally at `user://sink-city.cfg`.

This is a complete small offline game with one procedural district. Opponents
are local CPU logic; there is no online multiplayer, account, shop or ad system.
Desktop keyboard behavior is tested; touch-device behavior has not been tested
on physical mobile hardware.

## Template and source

Based on [mbMayer/Godot-Hole.io](https://github.com/mbMayer/Godot-Hole.io), MIT,
commit `cf75504a150c3cf179bb8e80b93309fb62a7a729`.
The original subtraction scene is copied in `Scenes/hole.tscn`; the movement and
CSG synchronization in `scripts/hole.gd` adapt its controller. Exact source
snapshots and SHA-256 provenance are in `third_party/mbmayer/`.

The city geometry, street/window shaders, interface, CPU behavior, round rules,
footprint checks, growth curve, collection logic and synthesized sounds were
authored for this game. No commercial Hole.io source, maps, models, textures or
branding are included. See [THIRD_PARTY.md](THIRD_PARTY.md).

## Validate without opening a window

```powershell
godot --headless --path . --script res://tests/acceptance.gd -- --test
```

The acceptance suite exercises real input events, CSG collision, falling bodies,
growth, duplicate collection, bounds, pause/resume, restart, rivals, timeout and
an automated full-city run. The whole-city driver uses normal movement and
collection, without granting score, teleporting objects or bypassing size gates.
`--test` prevents reading or writing the player's best score.

## Package Windows without opening a window

Install Python 3 and supply a Godot editor executable plus its matching export
templates archive. The build uses only `--headless` processes and never launches
a graphical game or editor. The exported executable is smoke-tested headlessly.

```powershell
python tools/package_windows.py --godot C:/Tools/Godot/godot.exe --templates C:/Tools/Godot/templates.tpz
```

Outputs: `build/windows/SinkCity.exe`, full engine/license notices, a SHA-256
manifest and `build/SinkCity-Windows-x64.zip`. The pack is embedded in the EXE.
Generated templates and logs stay in ignored `.build/`. For a conventional
editor export, clear the custom release template field and install the matching
Godot export templates through your normal setup.

This project does not access the InfiniteAincrad resident world, model providers
or cost ledgers. Building or playing it does not resume the paused town project.
