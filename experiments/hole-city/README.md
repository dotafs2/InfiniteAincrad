# Sink City — Poki reference reconstruction, step 1

This Godot project now opens the first reconstruction stage of the game inside
[Poki's Hole.io page](https://poki.com/en/g/hole-io). The reference was actually
played in a separate headless browser on September 24, 2026. The previous
independently styled prototype remains available as `res://main.tscn`; the new
default is `res://fidelity/main.tscn`.

**This is a first-level reconstruction, not a completed full-game replica.**
All current city models, cars, people, interface graphics and sounds are authored
locally. The original game's models, textures, scripts and audio were not copied.

## Play this stage

Extract the Windows package and run `SinkCity.exe`, or open `project.godot` in
Godot 4.7.2. `Play.cmd` prefers the current `build/reference-windows` package;
otherwise it uses `GODOT_BIN` or `godot` on PATH.

- Click **PLAY**, then drag or press WASD / an arrow key to start the tutorial.
- Hold and drag the mouse relative to its starting position to steer. Touch drag
  uses the same relative movement control. Desktop keyboard/mouse are validated;
  no physical mobile-device test is claimed.
- Reach **500 points within four minutes**. Eat small objects and grow through
  levels; bigger holes can swallow smaller opponents.
- Escape pauses and resumes. **Give Up** on the EATEN screen returns home.
- The 336-object city and seven CPU rivals are this stage's authored setup.
  Exact original object counts, rival counts and post-level-1 growth numbers
  have not been established from the reference.

## What is aligned so far

The first menu has the purple/blue tiled battle motif, top level badge, a rotating
city miniature, orange PLAY action and lower navigation strip. The first level
uses a parking court, older city facades, cars, pedestrians and street props.
The observed drag tutorial, top timer and 500-point target, player level/name/
progress tags, joystick and EATEN-to-home flow are implemented.

The shop and hole-library screens were inspected but are **not implemented** in
this stage; the side tabs retain their initial locked presentation. There is no
ad provider, real purchase flow or working revive purchase. Revive controls report
unavailable video/insufficient gems. Other levels, all skins, rewards, final
win/timeout styling, exact map geometry and exact growth/balance remain pending.
The first-stage win/timeout panels are temporary authored summaries, not claims
about unseen reference screens.

## Verification

```powershell
godot --headless --path . --script res://tests/fidelity_acceptance.gd -- --test
```

This checks the actual scene, PLAY action, tutorial gate, four-minute clock,
input-driven movement, size gates, rigid-body collection, first level threshold,
pause/resume, reset, timeout, defeat, return home and target completion. A live
seven-rival automated round verifies earned growth and a valid terminal result;
winning is not forced. A separate reachability fixture retires rivals and checks
that normal movement and falling objects can reach 500 without score grants.
`--test` isolates local saved settings. The earlier prototype has its separate
`tests/acceptance.gd` suite and [archived notes](LEGACY_PROTOTYPE.md).

## Package without opening windows

```powershell
python tools/package_windows.py --godot C:/Tools/Godot/godot.exe --templates C:/Tools/Godot/templates.tpz --out build/reference-windows
```

Supply an editor and its matching export templates. The helper performs only
headless import, notices extraction, export and exported-binary startup. It does
not open the game. Output includes the EXE with an embedded pack, full engine and
dependency notices, the MIT game/template license and a SHA-256 manifest.

For graphical QA without opening a desktop window, the `Web Review` preset uses
`res://.build/web_release.zip` extracted from the matching **standard** Godot
export-templates archive. Export with the non-.NET editor, serve `build/web` with
COOP/COEP headers, and load it in a separate headless WebGL browser. The stage was
reviewed this way at 1280 by 720. This is a QA export, not a public web deployment.

## Reused foundation

The CSG hole/controller foundation comes from
[mbMayer/Godot-Hole.io](https://github.com/mbMayer/Godot-Hole.io), MIT,
commit `cf75504a150c3cf179bb8e80b93309fb62a7a729`. Exact source snapshots, hashes
and notices remain in `third_party/mbmayer`. See `THIRD_PARTY.md` and `LICENSE`.
The game never accesses the maintained resident world, model providers or cost
ledgers. The paused InfiniteAincrad project and its hourly automation stay paused.
