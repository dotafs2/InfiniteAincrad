# Sink City — two playable maps

**v0.11.1** replaces both background tracks with the user-selected CC0
**Shop Theme / Buy Something! by Cleyton Kauffman**. The full 88-second normal
recording is level-matched and compressed; map changes preserve one ongoing
stream instead of restarting the opening. Existing audio preferences, pause,
background handling and player progress remain unchanged. Original synthesized
tracks and their evidence are archived outside the game pack.

Independent music review passes 298 checks and package-content review passes
12. All **77 source and isolated-package suites pass 53,843 checks per phase**,
with **791 stable inputs** and **18 verified HTTP artifacts**. The Web package
now includes accessible credits and redistribution notices. A verified 18.9 MB
Web playtest ZIP and a release plan are prepared; no public deployment or store
submission has occurred. Actual phone listening and sustained iPhone 14 60 FPS
remain unverified. See [music and delivery evidence](docs/shop-theme-20260930/README.md)
and [the release plan](docs/release-20260930/launch-plan.md).

**v0.11.0** replaces the crowded music with two sparse original loops,
adds usable intermediate food sizes in every inner district, and rebuilds six
original skins with rounded forms and lit collection cards. BOOST now provides
55% faster movement for 2.5 seconds. Three cookie-supported heaps retain 177
separately falling, separately scored pieces. A follow-up fixes sleeping rain
that stayed suspended after its actual support moved or disappeared.

All changes received non-author review. All **76 source and package suites**
pass **53,788 source checks and 53,788 package checks**, with **785 stable inputs** and ten
served files verified. The rain limit remains a strict new-wave admission
capacity; existing food can wake and fall again naturally. Failed runs and
reviewed fixture maintenance remain documented. Actual browser appearance,
phone-speaker listening, retention and sustained iPhone 14 60 FPS are unverified.
See [changes, original media and complete QA evidence](docs/feel-20260930/README.md).

**v0.10.0** adds an eight-car Sushi Express to Snack Garden and a four-car
City Tram to Sunny City, using ten original Blender-authored models. Each car
is an independent edible body. Eating a middle section leaves the downstream
cars parked at their current positions while the surviving head follows a
collision-checked passing branch and continues its loop. Parked cars remain
edible and never respawn or rejoin. Track paint belongs to the existing cut
ground, so it cannot bridge a hole. A small HUD pointer helps find the trains.

Independent review caught and verified fixes for disabled imported vertex
colors, an initially rejected bypass that was never retried, retained home
screen resources and stale scene references. Two legacy fixture expectations
were separately reviewed: explicit original-plus-train inventory budgets and
a fixed tolerance for unit-scale rotation roundoff. All **67 source and
isolated-package suites pass 48,255 checks per phase**, with **775 stable
inputs** and **all ten served files verified**. Blender source, model renders,
failed evidence and exact QA receipts are retained. Browser appearance and
sustained iPhone 14 60 FPS remain unverified.
See [train behavior, original assets and delivery evidence](docs/trains-20260929/README.md).

**v0.9.0** adds six skin rarities, visible actual draw odds, duplicate-free
unlocks and per-collection guarantees. Common skins are simple recolored rings;
Core Shell, Tide and Cinder are Legendary. Existing skin ownership and balances
migrate without resetting. Both maps gain connected perimeter districts and
approximately 59.6% more playable area. Every round lasts four minutes; score
targets no longer finish it early, and being swallowed triggers a brief respawn
with score retained. Three additional map cards clearly show Coming Soon.

Optional 2× round-coin and Coin Shop interfaces are present. Real advertising
and payment SDKs are not installed, so those actions truthfully remain
unavailable. All 63 source and isolated-package suites pass 46,356 checks per
phase; all ten served files match the tested release. Independent reviewers
cover the changes and the explicitly documented legacy fixture maintenance.
Browser appearance and sustained iPhone 14 60 FPS remain unverified.
See [rules, independent reviews and delivery evidence](docs/collection-20260929/README.md).

**v0.8.7** fixes black food in the instanced rendering path. Every static-food
and settled-rain batch explicitly initializes its packed instance color to
white, preserving the existing ingredient colors and material finish. The
isolated hotfix passes 53 source and package suites, 35,173 checks per phase,
and all ten served files match. Independent software OpenGL probes confirm the
color correction; browser appearance and phone GPU performance remain open.
See [black-food fix and delivery evidence](docs/black-food-20260929/README.md).

**v0.8.6** adds original looping music for both maps, with separate persistent
music and effects switches on the home and pause screens. Music starts after
a released input gesture; mute, round pause, focus loss and application
suspension preserve the playhead independently. One streamed music voice and
558 KiB of compressed tracks keep the addition bounded. Controls meet 44-point
touch height at a 375-point phone width. Two independent music reviews pass
243 checks; all 51 source and isolated-package suites each pass 34,009 checks,
and all ten HTTP artifacts match v0.8.6. Browser listening and phone performance
remain unverified. Reload the preview and tap PLAY to request music.
See [music behavior, original assets and delivery evidence](docs/music-20260929/README.md).

**v0.8.5** restricts dither to explicitly marked, intact city buildings that
meet individual size thresholds and actually block the hole. All food remains
opaque, including tall edible stacks; small tiers can no longer borrow a whole
tower's dimensions. The food shader has no discard path, while its ingredient
finish matches the prior baseline. Non-author reviews pass; all 49 source and
isolated-package suites each pass 33,734 checks, 45 isolated shader cases pass,
and all ten HTTP artifacts match v0.8.5. Browser appearance and phone performance
remain unverified.
See [building-only policy and evidence](docs/building-only-reveal-20260929/README.md).

**v0.8.4** gives Snack Garden an animated home-screen miniature with 68 food
pieces, three depth/height layers, six irregular stacks and branching chocolate
streets. Both maps rotate on the home screen and stop updating when hidden.
The food miniature uses shared visual meshes without a live physics city.
Natural-frame QA also catches and fixes a freed-player access after returning
home. Non-author reviews pass; 48 source and isolated-package suites each pass
33,349 checks, and all ten HTTP artifacts match v0.8.4. Actual browser appearance
and iPhone frame rate remain unverified.
See [miniature composition, lifecycle and delivery evidence](docs/map-preview-20260929/README.md).

**v0.8.3** removes the level-12 growth-table ceiling and adds deliberate rival
hunting and swallowing. Player-to-AI predation needs a 1.15 radius ratio,
AI-to-AI 1.20, and AI-to-player 1.40, followed by complete-mouth containment.
AI base speed is approximately 24% lower and its rewards are 70% of the prior
value. Larger mouths retain usable camera framing and valid ground openings.
Round-food collision fixes also prevent native contact errors and thin piles
passing through solid terrain while preserving independent falls and rewards.
Non-author reviews pass; 45 source and isolated-package suites each pass
32,070 checks, and all ten HTTP artifacts match the v0.8.3 release. CPU samples
show run-to-run outliers; browser appearance and iPhone 60 FPS remain unverified.
See [growth, rival rules and evidence limits](docs/growth-rivals-20260928/README.md).

**v0.8.2** corrects the overly broad v0.8.1 reveal policy. Only large, intact
building structures can dither, and their actual mesh must obstruct the
camera-to-mouth view. The expanded shoulder and lookahead apply after that
check. Ordinary people, traffic, street props, snacks, rain and released
fragments remain opaque. Food batches carry independent instance weights;
an empty arch or donut opening does not activate from its bounding box alone.
Non-author reviews pass; 37 source and isolated-package suites each pass
11,501 checks, and the served v0.8.2 artifacts match the verified release.
See [selective building reveal and evidence limits](docs/selective-reveal-20260928/README.md).

**v0.8.1** fixes camera occlusion across both maps with a feathered dither
aperture wider than the hole and extended toward movement. Props, skinned
people, traffic, food batches and fractured pieces share the reveal path.
Visible skin cards gain pixel-aware 2× MSAA targets, food roads gain mipmaps,
and procedural paving/windows filter their subpixel detail. Main 4× MSAA and
scene shadows remain enabled. Independent reviewers cover every change;
37 source and isolated-package suites each pass 13,092 checks.
See [mobile clarity, reveal behavior and evidence limits](docs/mobile-visibility-20260928/README.md).

**v0.8.0** addresses the reference audit with independent peer review after
each fix: corrected NPC facing/separation, continuous traffic, four city
districts, sustained food rain, new edible landmark structures and actual
city-destruction objectives. The collection now has 27 Classic and 17 Special
forms with touch paging, ability explanations, focused animation, a virtual
gem/coin store and persistent level progression.

See the [fix and review matrix](docs/fixes/20260928-summary.md), including exact
source/package evidence and the remaining physical-device acceptance. The
optional `?qa=1` recorder uses isolated test progress and downloads local
frame-cadence evidence; it does not certify phone performance automatically.

Per the user's acceptance rule, every bug fix requires review by a subagent
who did not implement it. Record the reproduction, changed behavior, executed
checks and evidence limits; return failed reviews to the author. Run the
guarded source and isolated-package gate before replacing the local preview.

**v0.7.0** adopts the reference Classic/Special three-column collection and
green coin-based random unlock action. Round earnings, duplicate-free unlocks,
equipment and persistent ownership replace score gates. Existing earned skins
and balances migrate without a reset.
See [coin rules, save migration and QA](docs/coin-skins-20260928.md).

**v0.6.0** rebuilds the bubble UI with illustrated map cards, a larger skin
collection, food-icon goals and matching tutorial/pause/results. Real pointer
navigation, phone-sized hit targets, thumbnail framing and preview cleanup are
covered by a new UI regression suite.
See [UI changes and evidence scope](docs/ui-redesign-20260928.md).

**v0.5.5** optimizes both maps with faster ground cutting, shared spatial
queries, compacted draw batches and lazy catalog loading. Isolated CPU P95
improves by 38–43% in Sunny City and 23–29% in Snack Garden. Models, shadows and
independent falls remain intact. These are headless Mac results, not phone FPS.
See [two-map measurements and regression evidence](docs/performance-20260928.md).

**v0.5.4** removes the food map's nine-cell road skeleton. A curved boulevard,
an oblique commercial street and six branching junctions connect seven unequal
neighborhoods. Buildings face the new streets; traffic and pedestrians follow
its shared plan. See [connected streets and QA](docs/food-street-network-20260928.md).

**v0.5.3** gives Snack Garden curved neighborhood walks, a market square and
street-facing buildings. Low shops, housing and taller landmarks replace equal
rows of towers. Pedestrians use the painted walking paths; rotated piles retain
independent collapse. See [food-city street hierarchy and QA](docs/food-neighborhoods-20260928.md).

**v0.5.2** adds rounded food edges, ingredient-specific glossy/matte finishes
and view-dependent icing highlights. Directional contrast is stronger, and
smaller decoration meshes reduce the total food triangle count by 7.22%.
See [food surface correction and QA](docs/food-finish-20260928.md).

**v0.5.1** rebuilds Snack Garden as twelve dense food blocks with 91 buildings,
15 cascading heaps and 2,639 physical edibles. Four icing palettes, mint streets
and wafer shops replace the sparse exhibition layout. Support-loss physics and
a spatial query grid keep the bigger city playable. See [food downtown and QA](docs/food-downtown-20260928.md).

**v0.5.0** replaces orbiting-sphere skins with water, accretion discs, flames,
aurora and distinct solid silhouettes. Home, skin cards and HUD now use a
clearer casual-game layout. See [skin/UI changes and shader QA](docs/skin-ui-20260928.md).

**v0.4.1** fixes lamp/sign collisions, interrupted-fall ownership, sleeping rim
contacts and interlocked park fences. The guarded Web export now checks every
initial city object and all 64 street-prop variants from multiple approaches.
See [street-prop recovery and full-city QA](docs/street-prop-recovery-20260928.md).

The scene-QA follow-up separates loose luggage, rack plates, food and parcels
into their own physical objects. All 152 objects across the 100 procedural
recipes pass individual collection checks in source and the exported package.
See [independent objects and repeatable QA](docs/scene-qa-20260928.md).

The September 28 update rebuilds **Snack Garden as an edible city**: 38 layered
food buildings, 1,048 food bodies, 48 citizens and ten kinds of physical food
rain. Menus and HUD now use a rounded bubble theme and Fredoka type.
See [Snack City changes and acceptance](docs/snack-city-20260928.md).

The follow-up fixes make **NPCs, drones, robots and building contents edible**,
retain the **original building surfaces on fracture**, and replace sliding role
animations with bounded locomotion. See [fixes and verification](docs/actor-fracture-fixes-20260927.md).


The historical September 27 mobile iteration added **Sunny City** and **Snack Garden**,
shared road/sidewalk geometry, intersection reservations, rounded skinned
people, static mesh batching, and a triangulated physical hole surface.
Its initial rules included an order for ten treats,
four donuts and one cake, plus a 420-point round target. Bacon, eggs, cake,
donuts, burgers, cookies, strawberries, sushi, pancakes and pizza also fall from
the sky, land on physical surfaces and remain edible.

Target: **iPhone 14, sustained 60 FPS**. This is a target, not a measured device
result. See [implementation and validation](docs/mobile-iteration-20260927.md).

Local browser build: `python3 tools/serve_review.py`, then open
`http://127.0.0.1:8768`. Open `project.godot` for the native Godot project.
The Web package is a local review build; it does not prove native iPhone speed.
To rebuild the preview with the source-and-package physics QA gate, run
`python3 tools/release_web.py --godot .build/godot-standard/Godot.app/Contents/MacOS/Godot`.


The September 25 build adds **208 original Blender model assets** (including
structural variants): 48 buildings, 32 vehicles, 64 street props, 48 plants and
16 rigged stylized people. All 208 appear in the playable city. Each figure has
Idle/Walk/Run plus one role clip: police/Chase, thief/Sneak, mech/Patrol, fat
person/Eat Fries, firefighter/Hose, chef/Flip, skateboarder/Skate,
photographer/Shoot, jogger/Jog, musician/Strum, construction/Hammer, nurse/Care,
cyclist/Pedal, superhero/Hero Pose, delivery/Carry and dancer/Dance. Sixty-four
pedestrians walk, rest and flee nearby holes; police and thief also chase/escape.
The default viewport is **540 × 960, portrait 9:16**, with a floating one-finger
joystick, release-to-stop and an on-screen pause button.

The historical source scene is `art_source/city_catalog.blend` in the source checkout;
it is not duplicated in this lightweight working copy. Runtime assets and exact geometry
and file hashes: `assets/city_kit/manifest.json`. Reproducible Blender authoring:
`tools/build_blender_catalog.py`; MCP background adapter and batch client:
`tools/headless_blender_bridge.py` and `tools/run_blender_catalog.py`.
The catalog has 208 different geometry hashes, not 208 instances of one mesh.
It contains related variations within asset families, not 208 unrelated themes.
The runtime city also instantiates 100 distinct procedural actor recipes across
10 named districts, alongside 64 animated residents, 48 ambient actors and
five signal pylons. The recipes are stored in `assets/world_actors/recipes.json`
and regenerated by `tools/build_actor_recipes.py`.
Their deterministic radial placement is exported through the locally installed
Houdini HOM bridge with `E:/houdini/bin/hython.exe tools/export_houdini_actor_layout.py`;
the result is kept in `assets/world_actors/houdini_layout.json` and is safe to
consume in headless/mobile runs.

The recovered official Epic City Sample / Matrix Awakens Houdini source is kept
under `tmp/citysample-source/Small_City`. The five-map overview uses the original
`City Layout` HDA and its `Road Network / Blocks` outputs. It does not recache or
overwrite the restored official City Processor caches:

```powershell
$env:HOUDINI_MAXTHREADS=2
$env:HOUDINI_OTLSCAN_PATH='C:/InfiniteAincrad/tmp/citysample-source/Small_City/houdini/otls;&'
E:/houdini/bin/hython.exe tools/generate_citysample_layout_gallery.py
python tools/render_citysample_layout_gallery.py
```

The seeded outputs are written to `../../tmp/citysample-layout-gallery`: each map
has a PNG overview and JSON geometry manifest. The original `Small_City.hip`,
`City_Layout.hda`, `City_Processors.hda`, and reference cache files remain
unchanged.

This Godot project opens the original portrait arcade game **Sink City**.
The reference-ledger work remains archived for comparison, but the shipped
presentation uses a playful bubble theme and authored round tuning.
The previous independently styled prototype remains
available as `res://main.tscn`; the current default is `res://fidelity/main.tscn`.

**This is a first-level reconstruction, not a completed full-game replica.**
All current city models, cars, people, interface graphics and sounds are authored
locally. The original game's models, textures, scripts and audio were not copied.

## Current Web play

Open the local review at `http://127.0.0.1:8768/` and refresh after an update.
Choose Sunny City or Snack Garden, select a collected skin and press PLAY.
Drag to steer; WASD and arrow keys also work. Eat small objects to grow and
admit larger items. Each round lasts 240 seconds, with no score-based early win.
Being swallowed costs two seconds before respawn; score is retained. Pause and
independent Music/SFX controls remain available.

A nonempty timed finish earns floor(score / 10) + 20 coins. Quitting to home
does not settle a round. Spend coins in the 44-skin Classic/Special collection;
RATES explains current eligible odds and guarantees. Existing ownership and
balances persist. Optional video doubling and cash purchases require compatible
native providers; this local Web build reports them unavailable. Animal Kingdom,
Star Voyage and Toy Factory are non-playable Coming Soon cards.

## Historical initial Windows/prototype checkpoint

The following instructions and ten-form matrix describe the initial prototype
and retained Windows package. They are historical evidence, not the current
Web release's rules or collection. This task does not rebuild that Windows
package. Current Web behavior is described in the version notes above.

### Play the historical stage

Extract the Windows package and run `SinkCity.exe`, or open `project.godot` in
Godot 4.7.2. `Play.cmd` prefers the current `build/reference-windows` package;
otherwise it uses `GODOT_BIN` or `godot` on PATH.

- Click **PLAY**, then drag or press WASD / an arrow key to start the tutorial.
- Hold and drag the mouse relative to its starting position to steer. Touch drag
  uses the same relative movement control. Desktop keyboard/mouse are validated;
  no physical mobile-device test is claimed.
- Reach **420 sync within 210 seconds**. Eat small objects and grow through
  sectors; larger signal bodies can swallow smaller opponents.
- Collecting objects charges the **Pulse** ring. When full, press Space or
  the lower-right action card to release a short, bounded pull field; objects
  still fall, collide and score through the normal rigid-body swallow path.
- The top-right pause button or Escape pauses and resumes. **RETURN TO DOCK**
  leaves a collapsed run.
- The city has 656 edible bodies including 64 animated residents and 152 physical
  objects from the 100 procedural recipes, with seven CPU rivals. Eight
  road cars follow bounded lanes, pause near the player and wrap at the city edge.
  Exact original object counts, rival counts and post-level-1 growth numbers
  have not been established from the reference.

### Initial reference alignment

The current menu uses a purple-to-cyan bubble backdrop, rounded type,
white-edged soft cards, a food-city miniature and a large orange **PLAY** action.
The library uses a compact three-column card grid with a live 3D form preview;
the preview changes its rim material, shader profile and orbiting motes as soon
as a card is selected. Void, flame, wave, metal, gravity, beacon and prism
profiles are authored for the ten forms and are reused by the live player.
This keeps the reference's fast scan rhythm while adding an original
field-role preview and avoiding copied art, names or result language.
The level uses a parking court, authored city facades, cars, pedestrians and
street props. The drag tutorial, 210-second timer, 420 sync target, sector/name/
progress tags, joystick and collapse-to-dock flow are implemented.

The **HOLE COLLECTION** library ships ten authored forms: five chroma-only
**FOUNDATION** shells and five cooldown-based **RESONANCE** shells. Every card
shows its sync unlock, skill description and play note. The first skill pass
includes Copper Draw, the periodic Moss Bloom catch, Gravitas' bounded building
thrum, Lantern's short speed step and Shard Sweep; Core Shell, Cinder, Tide,
Orbit and Prism Vale are visual forms with no gameplay bonus. Unlock progress is
tracked from the best sync reached and saved locally at 0/25/70/120/180/240/
300/340/380/420. The selected form is saved with that progress; `--test` runs
stay isolated and never write a player save. The store is still a locked
boundary; there is no real purchase flow. The iOS MVP ad boundary is documented in
`docs/design/hole-city-ios-mvp.md`: desktop and unconfigured exports report
unavailable video, while a future native AdMob plugin can grant the opt-in
rewarded revive only after a completed ad. Additional maps beyond the two current choices, rewards, final
win/timeout styling, exact map geometry and exact growth/balance remain pending.
The win/timeout panels use **DELICIOUS WIN!** and **TIME IS UP!** with the same
rounded theme as home, pause, map selection and the HUD.

The form effect matrix is intentionally authored and readable in the library:

| Form | Visual profile | Play identity |
| --- | --- | --- |
| Core Shell | Void rings and signal anchors | Learn the field |
| Copper Ring | Metal scan and copper band | Five-object draw, 8s cooldown |
| Moss Bloom | Organic wave and leaf motes | Automatic catch, 12s cycle |
| Gravitas | Gravity thrum and weighted blocks | Building nudge, 12s cooldown |
| Lantern | Beacon glow and lantern motes | Speed step, 9s cooldown |
| Shard | Prism facets and sweep motes | Wider pull, 11s cooldown |
| Cinder | Flame tongues and ember motes | Chroma-only visual |
| Tide | Layered wave rings and cyan motes | Chroma-only visual |
| Orbit | Satellite prism and orbital motes | Chroma-only visual |
| Prism Vale | Rainbow prism field and motes | Full-sync visual reward |

The current visual pass adds five animated signal pylons with distinct cyan,
violet, mint, amber and rose beacons, plus deterministic neon window pulses and
subtle damp patches in the procedural facade and asphalt shaders. These are
original runtime style elements, not copied reference assets.

Portrait pedestrians are seeded into loose sidewalk clusters rather than a
single repeated row. Each has a small bounded wander target and an independent
rest cycle. Locomotion follows actual travel speed, stationary gestures retain
the role identity, and swallowing releases the body to physics.

## Building collapse, traffic and falling

Buildings use six authored facade styles layered over the imported silhouettes.
When a building fits the hole, its body collapses into sixteen rigid pieces
retaining the original facade, windows and roof, with separate score events;
the pieces keep gravity, angular motion and
the ground and fragment collisions, so the player sees a delayed, staggered
heap fall into the opening instead of a mesh disappearing. Eight extra street
cars travel on four lanes, pause
when the player blocks their path and wrap at the bounded city edge.

Objects now wake when their center enters the opening, while their outer edge
can still touch the rim. Ground contact and gravity produce the initial tip;
collisions remain active until the rotated body clears the ground's underside.
There is no scripted initial spin or forced downward velocity. A bounded inward
force exists only for the explicit Resonance action and is sampled at activation.
Claimed bodies release when the mouth moves away; they do not track the hole.
Tall objects that start to bridge the opening can receive a vertical load at the
supported lower end, producing physical torque instead of rotating or shrinking
the mesh directly. This is an arcade physics model, not an assertion of an exact
match to the original game.

Living residents follow bounded sidewalk routes. Swallowing or a field pull
hands their transform to rigid-body physics and stops the route controller.
Procedural robots, drones and other authored props follow the same release path.
Building contents release when their enclosing building fractures.
Edible bodies use a rough, medium-high friction material. Friction affects
contacts after the ground release; it is not used as a substitute for a global
hole tether.

## Verification

```sh
python3 tools/release_web.py --godot /absolute/path/to/godot --evidence artifacts/release
```

The current suite registry and minimum check counts live in
`tools/release_web.py`. The gate runs each registered suite against source and
again against an isolated exported package, rejects engine errors and changed
inputs, and only then replaces the local preview. It covers actual input,
collection and falling bodies, both maps, mobile layout, save migration,
coin-based skins, abilities, progression and selective building reveal.
Growth and rival-combat regression suites exercise the extended size rules,
physical pursuit, predation, ownership transfer and ordinary pedestrians.

The test flag disables normal player-save writes; tests that exercise saves
must select their own temporary file. Headless scene checks establish logic
and physics behavior, not browser pixels or phone GPU performance. Actual
visual/device evidence must be recorded separately with available permission.
Older individual scripts, including `fidelity_acceptance.gd`, retain historical
balance and menu assumptions and are not the release gate. The earlier
prototype also retains `tests/acceptance.gd` and [archived notes](LEGACY_PROTOTYPE.md).

## Package without opening windows

## Mobile preview recording

Before a local run or test, record a short self-play preview and convert it to
a phone-friendly H.264 MP4:

```powershell
powershell -ExecutionPolicy Bypass -File tools/record_mobile_preview.ps1
```

The default capture is a 60-second 540 × 960 portrait run. It uses Godot Movie
Writer and the local `imageio-ffmpeg` binary when a system `ffmpeg` is not on
`PATH`; pass `-Seconds`, `-Godot` or `-Ffmpeg` to override them. The source AVI
is removed after the MP4 passes a decode check, leaving the mobile preview in
`tmp/mobile-preview`.

The skin-switch recording uses `tests/skin_library_capture.gd` with `--test`.
It starts at the real home screen and sends pointer events through the shipped
buttons to open Rift Forms, preview and equip all ten forms, return to the dock,
and start a round with the selected form. It also checks the runtime mesh tint
and the skin action button. The capture seeds all unlocks in an isolated local
session; it does not demonstrate earned progress or write a player save. Its
optional `--report=<path>` records each input and the resulting equipment state.

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
