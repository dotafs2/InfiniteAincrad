# Poki Hole.io reference ledger — first stage

The user confirmed `https://poki.com/en/g/hole-io` as the reference, requested
close reconstruction and required self-authored art. They also prohibit desktop
windows or focus changes while gaming. Reference interaction and local Godot
WebGL review therefore used an isolated headless Edge process and temporary
profile, with audio muted and software rendering. The two initial in-app hidden
browser attempts timed out and were not used as evidence.

## Observed reference

Observed on September 24, 2026, in the live embedded game at 836 x 470 pixels:

| Screen / behavior | Direct observation | Stage-one implementation |
| --- | --- | --- |
| Home | Purple/blue white battle pattern; circular level 1 badge; rotating high-rise city miniature; orange PLAY; three bottom tabs | High-level scan rhythm only: an authored SINK//FIELD signal dashboard, independent copy, and original Godot miniature |
| First launch | Dimmed city with an infinity gesture and DRAG TO MOVE | Tutorial gates movement and timer until input |
| Initial player | Blue hole; LVL 1; Player; 0/10 bar | Same text hierarchy and first 10-point threshold |
| First round | Timer starts at 04:00; target card says 500 PTS; other named holes move independently | Original 210-second/420-sync loop; local CPU opponents and Resonance skills |
| First location | Asphalt parking court; bus, blue car, police car, gray utility vehicle and red cars; sidewalk facades, people, lamps, bins, covers and park | New meshes and procedural first-city layout matching these categories and initial composition |
| Occlusion | Nearby building fades while the hole passes through its footprint | Facade transparency near the player |
| Defeat | EATEN, grave illustration, revive for 100 gems or video, Give Up | Authored grave graphic, offline unavailable controls, functional Give Up |
| Give Up | Returns to the city miniature | Returns to home and rebuilds on PLAY |
| Store | Coin/gem balances; free 5-gem tile; coin packs 320/2000/9600 for 40/200/500 gems | Observed only; no store implementation yet |
| Hole library | CLASSIC 1/27 and SPECIAL 0/17 tabs; three-column grid; recognizable reference names | Original RIFT FORMS tabs, ten original names, score unlocks, cooldown skills and a live 3D preview |

Reference screenshots remain in ignored `private/hole-city-reference`; they are
visual study records, not game assets. The public validation images are rendered
from our own Godot project. No original mesh, texture, audio file or executable
game code was extracted into the project.

## Unverified and provisional

The first reference run ended by being eaten. A reference victory screen,
timeout screen, all later levels, all 44 displayed skin slots, purchase/revive
effects and reward rules have not been observed end to end. The implemented
win/timeout cards are clearly a temporary authored completion flow. Locked side
tabs are the first-stage boundary, not a claim that the reference's shops stay
locked after play.

Seven CPU opponents, 451 edible objects, the exact procedural map coordinates,
post-level-1 thresholds/radii and CPU strategy are authored provisional choices.
They are not reverse-engineered original values. Exact reference silhouette,
material and layout matching remains open. Physics retains the conservative
footprint-to-hole size gate, but releases bodies before their complete footprint
is inside the opening. Rim contact and gravity now produce initial tipping.
A short-lived central force is used only by the explicit Resonance action and
is sampled at the hole position when that action starts. A claimed body never
tracks a moving hole: after the mouth moves away, the claim is released and
gravity, inertia and ground contact decide the result. Long objects may receive
a vertical load at an already-supported lower end after tilting, but no
horizontal tether is applied. Collisions stay active through the ground, and
collection uses the rotated body's vertical bounds. This arcade assistance is
authored, and the result is not an exact reference-physics reproduction.

Residents are kept as upright animated actors. They are excluded from the
swallow scan and have no rigid-body collision with the player, while vehicles,
props and buildings retain the physical falling path.

Buildings now use six authored facade treatments. A building that fits the hole
is replaced by sixteen colored rigid blocks, each falling and scoring through
the same local mouth path. Eight additional road cars move on bounded lanes,
pause when the player blocks them and wrap at the edge; parked vehicles remain
available as ordinary edible objects.

The city now includes 100 distinct procedural actor recipes in ten districts,
plus 64 imported residents, 48 lightweight ambient actors and five signal
pylons. The recipe catalogue is generated deterministically from
`tools/build_actor_recipes.py`. Their spatial layout is exported through the
installed Houdini HOM bridge (`E:/houdini/bin/hython.exe`) by
`tools/export_houdini_actor_layout.py` and loaded from
`assets/world_actors/houdini_layout.json`. A connected Houdini MCP server is
optional; the local HOM export is the reproducible runtime source used here.

The playable pass now adds an authored Resonance action: collected points fill a
player-only charge ring, and a full ring can release a 0.72-second, ten-object
maximum pull field with a seven-second cooldown. The field only applies damped
rigid-body force; it does not teleport, resize or directly score objects. Five
animated signal pylons and procedural neon facade/asphalt pulses establish a
separate visual identity for this stage.

The portrait library extends that identity with a blue-violet/orange contrast,
a compact three-column card grid and an original live 3D form preview. Selecting
a card changes the preview material and orbit markers immediately. These are
authored additions, not copied reference assets.

## Direction review

The first-hour review kept the confirmed live reference as the target. The old
two-minute competition/free-roam design is no longer the default entry point.
This stage prioritizes a playable home-to-first-round-to-defeat/home loop with
visible evidence. It does not claim complete replication or silently substitute
unseen store, skin or level behavior. The next stage must measure original
growth, additional screens and detailed assets before claiming those match.

The old town-development goal and hourly automation remain paused. No paid
provider, quota reset, desktop screenshot, visible game/editor/browser window,
physical mouse movement or focus switch was used for this stage. The iOS ad
integration remains a native-plugin release task; desktop tests use the explicit
no-ad fallback.
