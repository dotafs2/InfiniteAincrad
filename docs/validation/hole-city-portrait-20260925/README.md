# Portrait city kit — September 25, 2026

The user's requested milestone is implemented: original Blender models, animated
stick figures, and portrait one-finger play in the existing Godot reference slice.
The existing rim-contact/gravity behaviour is retained. This is not a completed
pixel-identical reconstruction of the entire Poki game.

## Delivered assets

| Group | Independent GLB assets |
| --- | ---: |
| Buildings | 48 |
| Vehicles | 32 |
| Street furniture | 64 |
| Plants | 48 |
| Rigged stick figures | 16 |
| Total | **208** |

Every GLB has a different geometry hash. Counts include related structural and
proportion variants within 48 model families, not 208 unrelated object themes.
Recolors and repeated scene instances are not counted. All 208 assets are used
in the 443-object city. Sixteen figures have Idle, Walk, Run, and one dedicated
role action each (64 imported clips total). The visible roles are Police/Chase,
Thief/Sneak, Mech/Patrol, Fat Fries/Eat Fries, Firefighter/Hose, Chef/Flip,
Skateboarder/Skate, Photographer/Shoot, Jogger/Jog, Musician/Strum,
Construction/Hammer, Nurse/Care, Cyclist/Pedal, Superhero/Hero Pose,
Delivery/Carry, and Dancer/Dance. Sixty-four pedestrians move, rest and flee
in ordinary gameplay; police pursue the thief and the thief escapes the player.
The kit totals 164,156 authored triangles and roughly 14.0 MB of GLB data.

- [Visual catalog and searchable inventory](catalog.html)
- [Asset audit](asset-audit.json)
- [208 successful Blender MCP authoring command receipts](mcp-batch.json)
- [Godot gameplay excerpt, 540 × 960](portrait-gameplay.mp4)
- [16-role action preview, 540 × 720](role-actions.mp4)
- [Open-source character options reviewed](open-source-options.md)
- [Capture scope and hashes](capture.json)

The Blender source is `experiments/hole-city/art_source/city_catalog.blend`;
the reproducible authoring script is `tools/build_blender_catalog.py` in the
game project. Blender 5.2.2 LTS ran with `--background --factory-startup`.
The official Blender MCP addon rejects its normal server startup in background
mode because GUI timers would not execute. Our adapter uses its unmodified
command handlers through a synchronous loopback transport on the main thread.
It does not claim use of a directly registered Codex Blender MCP tool. The addon
was not installed into the user's preferences, and no existing scene was opened.
No online model generator, paid provider, external model asset or quota reset
was used. The local bridge and all owned browser/helper processes were closed.

## Verification

- [28 portrait checks](portrait_acceptance.json): all 208 assets instantiated,
  actual bone motion, four clips per role, moving/fleeing/resting pedestrians,
  police/thief role behavior,
  one-finger screen-relative movement, second-finger isolation, release-to-stop,
  and on-screen pause/resume.
- [25 rim checks](rim_fall_acceptance.json): real gravity/contact tipping and
  exactly-once collection, including a symmetric straight-fall control.
- [24 first-level checks](fidelity_acceptance.json): normal gameplay at 60 Hz,
  tutorial, input, scoring, growth, results and restart. The final ordinary
  seven-rival regression ended EATEN at 58 points after 42.817 simulated seconds.
  A separate explicitly rivals-retired fixture earned 507 points and completed
  after about 71.9 seconds. Neither is misrepresented as a guaranteed ordinary
  win.
- [27 legacy checks](acceptance.json): the preserved original prototype passes.
- [Windows pack manifest](windows-manifest.json): version 0.3.0, embedded pack,
  actual packaged executable tested with the headless renderer.
- Actual WebGL rendering and browser touch events at 390 × 844 and 540 × 960;
  final inspected sessions had no runtime or script errors. A physical phone
  was not tested. Tall phone screens letterbox the fixed 9:16 play area.

The 42.5-second silent gameplay excerpt is a real automated touch-input match,
not a scripted success animation. Browser capture has variable cadence, with
visible early startup/capture stalls; encoding it at 30 fps is not a claim of
constant 30 fps rendering. The separate 10-second 16-role preview is an
explicit isolated animation fixture, not gameplay.

During implementation, validation found and fixed duplicate geometry variants,
inward sphere winding, mirrored wheel winding, disconnected shoulder/hip bars,
vertex colors missing in the Godot default material, excessive portrait sky,
and access to a freed pedestrian. A private recording copy initially omitted
the shared hole scene; that failed take was discarded and the corrected export
was checked before recording. The first bulk video transfer exhausted the
browser page; final recording uses a bounded direct download. These failures
are not counted as passed checks.

## Remaining scope

Exact map layout, material/shape fidelity, shops, the full skin library, later
levels, rewards and final balancing still require work. Buildings and vehicles
are original low-poly interpretations. The independent town/world simulation,
provider ledgers, paused project goal and hourly automation remain untouched.
All work ran without showing a desktop window or taking mouse/keyboard focus.
