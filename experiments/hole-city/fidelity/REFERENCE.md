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
| Home | Purple/blue white battle pattern; circular level 1 badge; rotating high-rise city miniature; orange PLAY; three bottom tabs | Same composition; all vector graphics and 3D miniature authored in Godot |
| First launch | Dimmed city with an infinity gesture and DRAG TO MOVE | Tutorial gates movement and timer until input |
| Initial player | Blue hole; LVL 1; Player; 0/10 bar | Same text hierarchy and first 10-point threshold |
| First round | Timer starts at 04:00; target card says 500 PTS; other named holes move independently | Four-minute/500-point loop; local CPU opponents |
| First location | Asphalt parking court; bus, blue car, police car, gray utility vehicle and red cars; sidewalk facades, people, lamps, bins, covers and park | New meshes and procedural first-city layout matching these categories and initial composition |
| Occlusion | Nearby building fades while the hole passes through its footprint | Facade transparency near the player |
| Defeat | EATEN, grave illustration, revive for 100 gems or video, Give Up | Authored grave graphic, offline unavailable controls, functional Give Up |
| Give Up | Returns to the city miniature | Returns to home and rebuilds on PLAY |
| Store | Coin/gem balances; free 5-gem tile; coin packs 320/2000/9600 for 40/200/500 gems | Observed only; no store implementation yet |
| Hole library | CLASSIC 1/27 and SPECIAL 0/17 tabs; three-column grid; Classic Hole, Spinner, Ripley, Black Hole, Raccoon, Spiral, Thunder, Tornado, Heart visible | Observed only; no skin library yet |

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

Seven CPU opponents, 336 edible objects, the exact procedural map coordinates,
post-level-1 thresholds/radii and CPU strategy are authored provisional choices.
They are not reverse-engineered original values. Cars and buildings still need
further silhouette/material/layout matching. Physics retains the conservative
footprint-to-hole size gate, but releases bodies before their complete footprint
is inside the opening. Rim contact and gravity now produce initial tipping.
A bounded central attraction follows moving holes; long objects can receive a
lower-end pull after tilting so they do not remain bridged across the mouth.
Collisions stay active through the ground, and collection uses the rotated
body's vertical bounds. This arcade assistance is authored, and the result is
not an exact reference-physics reproduction.

## Direction review

The first-hour review kept the confirmed live reference as the target. The old
two-minute competition/free-roam design is no longer the default entry point.
This stage prioritizes a playable home-to-first-round-to-defeat/home loop with
visible evidence. It does not claim complete replication or silently substitute
unseen store, skin or level behavior. The next stage must measure original
growth, additional screens and detailed assets before claiming those match.

The old town-development goal and hourly automation remain paused. No paid
provider, quota reset, desktop screenshot, visible game/editor/browser window,
physical mouse movement or focus switch was used for this stage.
