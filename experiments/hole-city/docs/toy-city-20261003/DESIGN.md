# Bubble Toy Town design contract

This is an original toy world for Hole Feast. Rounded inflated castle silhouettes,
soft vinyl highlights and warm pastel neighborhoods define the map. Small toy
balls, ducks, cars, blocks and trains provide the first bites. Bubble turrets,
arches, block towers and complete castles make the middle and late skyline.
Geometry is authored locally and cached; this map does not use another game's
assets, layouts or branding.

Three north/south boulevards at x = -44, 0 and 44 connect cross streets at
z = -36, 18 and 60. A boulevard around +/-84 joins the outer neighborhoods.
Opening toys gather near the player's existing spawn at (1, 0, 23). Distinct
rose, mint, blue and apricot districts create a readable city rather than an
undifferentiated random scatter. Whole rotated footprints must fit inside the
world and leave the main boulevards open.

The toy round lasts 90 seconds. Sunny City retains 90 seconds and Snack Garden
retains 60 seconds. Existing optional 30-second continuation and coin rewards
remain independent of the new map. Toy scores follow actual size progression;
small toys must not inherit the city building's fixed 48-point collapse award.
The world must retain meaningful intermediate and giant targets through an
ordinary run, with enough reachable small food to enter the next tier.

Original whole meshes stay intact when swallowed. Independent toy stack layers
lose their physical support when their base moves; swallowing does not replace
a castle with new cut facade fragments. Measured geometry determines each body's
full footprint and admission radius. A reward is credited only after the whole
object falls below the collection plane.

Whole large castles can opt into the existing whole-building camera reveal.
Independent tower layers and ordinary toys stay opaque. The miniature is a small
visual scene, sharing game meshes without spawning a playable world, physics,
wallet rewards or production network requests. The three home map cards retain
phone-sized touch targets and the existing responsive portrait layout.

Acceptance distinguishes actual desktop GPU pixels, normal physics rounds,
headless CPU/scene checks, packaged web checks and physical iPhone tests. A local
candidate is not a change to the submitted 0.12.7 / build 26. The currently
submitted release, previous previews and all user saves remain preserved.

## Palace life and independent NPC benchmark

The user requested palace guards and NPC complexity no lower than Sunny City.
Build original soft toy guards, sentries, couriers, courtiers, jesters and a royal
parade, with patrol/rest, group formation, changing guard, alarm, pursuit and
flight. Compare living behaviors and activity density against Sunny City separately
from ambient or recipe assembly counts. Frozen scripted actors must yield their
actual whole-body geometry to swallow physics without newly exposed cut faces.
Do not count a repeated static decoration as a different NPC role.
