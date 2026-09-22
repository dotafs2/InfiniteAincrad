# DSH session work log · 2026-09-22

Branch: `ds-test` (a separate publication branch; `main` is untouched).
Author of this session's commits: `dotafs2 <148285081+dotafs2@users.noreply.github.com>`.

This log records what the DeepSeek Harness (DSH) session did to this repository on 2026-09-22: the harness setup, ten generated models, a navigation test scene built on the project's own authored house, and two report videos. It is written to be checkable: every number below comes from a file committed next to it.

## 1. Harness setup

Four repository skills were written for the harness, under `.dsh/skills/`:

| Skill | Purpose |
| --- | --- |
| `git-publish` | this repository's publication protocol: `dotafs2` identity, conversation-archive export, staged-file review, post-push hash verification |
| `world-observation` | `worlds/active.json`, immutable checkpoints, lineage isolation, the English/Chinese language split |
| `usage-accounting` | per-world developer usage ledger rules (totals are never reset; usage metadata never enters NPC prompts) |
| `godot-dev` | Godot 4.7.2 build/run/validate entry points (`tools/run_godot.py`, `Run-*.ps1`, `tools/test_*.py`, `docs/validation/`) |

`.gitignore` also gained `.dsh-home/` and `.dsh-runtime/`, so the harness home (which holds `.credentials.yaml`) and its downloaded Node runtime can never be committed by accident.

## 2. Ten generated models (user's own provider accounts)

| Item | Provider | Credits |
| --- | --- | --- |
| `01_market_street_house` | Tripo `v3.1-20260211` | 30 (balance exactly covered it) |
| `smithy-house`, `street-lantern`, `stone-well`, `wooden-bench`, `notice-board`, `hanging-sign`, `flour-sack`, `wagon-wheel`, `flower-planter` | Meshy 7 | 270 planned = 270 provider-reported, 0 unknown |

Each model was generated **exactly once** with no appearance reroll. Assets live in `game/assets/floor1/model_nav_20260922/` (GLB plus Godot-extracted textures, ~369 MB, tracked through Git LFS). Prompts and manifests are `experiments/meshy-pool/model-nav-20260922.json` and `Art/Generated/TripoNavHouses20260922/trial.json`; raw receipts stay local under `private/` and `tmp/` (both gitignored).

## 3. Navigation test scene: `game/scenes/model_nav_village.tscn`

The building the NPC enters is **not modelled by the agent**. It is the project's own authored modular house `03_corner_turret` (three storeys, 9 × 7 m, 3.0 m floor height) instantiated through the project's own `spatial/modular_house_component.gd`, so the real shell with true wall openings, the authored door and window pivots, the detached door leaf and the real `BuildingShell` trimesh collision all come from the asset. The scene reads the doorway from the component (`door_opening_godot()`) and opens the door with `set_door_open(true)`.

The scene adds only what the authored asset does not contain, and says so in its own evidence:

- one upper-floor slab with a stair opening,
- twelve staircase treads.

Every furnishing is an existing `living_props_20260916` prop (hearth, table, two chairs, workbench, shelf and jugs downstairs; bed, chest and a jug upstairs), plus three interior lamps. **NpcB waits on the second floor**; NpcA walks the market street, enters through the open doorway, crosses the ground floor, climbs to 2.99 m and reaches NpcB, and both turn to face each other.

Headless acceptance (`game/tests/model_nav_village_acceptance.gd`) passes **21 / 21 checks**; the recorded facts are in `docs/validation/model-nav-20260922/acceptance.json`: 10/10 models loaded, the authored house built, navigation baked at 530 polygons, route climbed to **2.9916 m** with 214 sampled positions inside the footprint, arrival **0.432 m** after 6.82 s.

**Honest boundary:** the outdoor leg is engine pathfinding, but the climb is an explicit nine-point connector chain — the authored shell has no walkable slab, and the added treads are 0.3 m deep against roughly 0.45 m of navigation-agent radius erosion, so the bake cannot link floor to upper floor. The repository's own `navigation_mvp_house` fixture uses the same pattern for stairs and ladders. The evidence for the vertical leg is the actor's measured height, not path geometry.

## 4. Videos and the map tour

| File | Contents |
| --- | --- |
| `docs/validation/model-nav-20260922/model-nav-report.mp4` | 33 s report: title, pipeline flowchart, 12 s of scene footage (square, open doorway, staircase, **the second-floor arrival**), summary card |
| `docs/validation/map-tour-20260922/map-tour.mp4` | 1 min 51 s tour of **13 captured segments** of the project's own maps |
| `docs/validation/map-tour-20260922/walk-probe-legs.json` | the quarter walk-probe leg lines, verbatim |

The map tour covers the living quarter, the PCG demo town, the expanded world, the street trial, the SAO town quarter, the residences and environment review scenes, and the navigation MVP house. Eight scenes were captured through their own `--capture-dir` / `--quarter-report` switches; five ship no capture switch and were recorded through `game/tests/map_capture.gd` with a read-only viewer camera.

**Residents moving.** The living quarter segment is recorded while the scene runs its own offline physics walk probe. All three legs completed and every resident reported reaching its target:

```
QUARTER_WALK_LEG enter_home   … "reached":true …
QUARTER_WALK_LEG visit_market … "reached":true …
QUARTER_WALK_LEG return_home  … "reached":true …
```

1560 frames were captured at 6 fps over 260 s, 986 of them distinct.

## 5. How to reproduce

```powershell
# scene acceptance (no window)
python tools\run_godot.py --godot <godot.exe> --name village -- --headless --script res://tests/model_nav_village_acceptance.gd
# stills and report footage, window positioned off-screen
python tools\run_godot.py --godot <godot.exe> --name village-capture -- --position -2400,-1400 --resolution 1280x720 'res://scenes/model_nav_village.tscn' '--' '--movie' '--capture'
python -X utf8 tools\build_model_nav_report_cards.py
python -X utf8 tools\build_model_nav_report_video.py
# project map tour
python -X utf8 tools\capture_map_tour.py
python -X utf8 tools\capture_map_frames.py
python -X utf8 tools\build_map_tour_video.py
```

## 6. Safety boundaries observed

- Every render ran with the window positioned **off-screen**; recording never took over the desktop, and no owned process was left running.
- **No save was written.** The living quarter and the demo town were opened through a *copy* of a saved world with `--town-restore`, which the scene documents as never advancing the world. The maintained world `private/worlds/restart-20260918-01/world.json` was never opened for write.
- **No paid provider call** was made by the map tour. The walk probe is the repository's offline physics diagnostic; the live Kimi path (`StartLivingAI.cmd`, `tools/start_user_living_session.py`) was deliberately not run.

## 7. Known gaps

- The quarter's own `report.json` was not flushed: the walk-leg lines and the captured frames are the evidence, and `01..04` capture PNGs exist in `tmp/map-tour/quarter-walk-motion/report/` (gitignored).
- **No conversation archive is included with this branch.** `tools/archive_conversation.py` parses the Codex session format (`commentary` / `final` phases); this session ran under DSH, whose home is `~/.dsh` rather than the workspace `.dsh-home`, and no DSH-format exporter exists yet. This log is therefore a work log, not a transcript, and it does not claim to be one.
- **Pre-existing uncommitted work was left untouched**: `game/spatial/sao_town_quarter.gd`, `game/spatial/sao_town_quarter_layout.json`, `game/tests/sao_town_quarter_acceptance.gd`, `docs/validation/sao-town-quarter-2026-09-21.md` and `game/addons/simplegrasstextured/default_mesh.tres` were already modified in the working tree before this session and are **not** part of this branch's commit.
