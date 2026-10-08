# Independent weather skin visual review

Reviewed on October 7, 2026 by the delegated visual reviewer. The reviewer did
not implement the shader or catalog changes and ran no engine jobs. The review
uses actual Mac GPU images, not palette descriptions or generated mockups.

## Verdict

**The refined pair is visually better differentiated and the palette revision
passes.** Tempest has the stronger before/after improvement. Rainfall needed a
second color pass: its first green candidate was rejected as a visual regression,
then the cool pearl/teal refinement restored a clean water identity.

This verdict concerns appearance and readability in the inspected images. It is
not evidence of phone performance, ownership/save compatibility, gameplay timing,
or correct highest-tier sorting. Those require the root's separate acceptance
checks. Prismatic labels alone did not count as evidence of better art.

## Material inspected

- Prior actual posters: `artifacts/tempest-detail-20261007/Tempest-detail-poster.png`
  and `artifacts/rainfall-single-entry-20261007/Rainfall-single-entry-poster.png`.
- Matched captures under `build/weather-prismatic-20261007/before/`,
  `candidate/`, and `refined/`, using the same camera, scale, light background and
  navy background. Compared idle, object response and rival response.
- Specifically inspected refined `idle-light.png`, `idle-dark.png`,
  `object-light.png` and `rival-dark.png` against the corresponding prior states.
  Capture code identifies the object/rival events as isolated synthetic cosmetic
  callbacks; they are not presented as actual physical intake.

## Before, candidate and refinement

| Skin | Before | First candidate | Refined result |
| --- | --- | --- | --- |
| Tempest | Grey-blue funnel and clouds share the other weather skin's family; the funnel loses contrast on navy. | Violet clouds and lilac funnel form a unified storm. Sparse amber lightning gives the rival response a distinct focal point. The transparent spiral and cloud texture survive. | Keeps the successful candidate treatment. The rim, clouds and funnel read as one purple storm on both backgrounds. Gold remains an accent rather than filling the tornado. |
| Rainfall | Readable blue water, rain streaks and wave normals, with a dark grey-blue cloud. | Emerald pool and yellow-green cloud separated it from Tempest, but made the liquid feel murky and weakened the clean shallow-water identity. This was not accepted as an improvement. | More blue in the teal water, cool-white cloud highlights, teal-grey undersides and pearl rain remove the muddy cast. The mint/opal accent stays peripheral, and the waves remain legible. |

## Acceptance findings

- The two silhouettes remain recognizable as tornado and rain cloud over water;
  they now separate immediately by color without needing labels.
- Tempest's cloud detail and translucency remain visible. It has not turned into
  an opaque purple cone, and rival lightning is a controlled warm contrast.
- Rainfall's refined cloud remains visible on the pale scene and navy preview.
  The underside supplies depth while highlights read as pearl rather than green.
- The Rainfall pool retains visible shallow-water ripples. Its rival response
  has a brighter expanding ring and droplets; the object response stays smaller.
- Neither inspected rival response obscures the entire mouth. Existing polygonal
  burst rings and simple droplets remain stylistic limitations visible at close
  range; this small palette/motif revision does not claim a new geometry system.

## Encoded gameplay and collection UI review

The reviewer then inspected filmstrips decoded from the final muted 14-second
`artifacts/weather-prismatic-20261007/Prismatic-weather-pair.mp4`:

- `build/weather-prismatic-20261007/encoded-entry-filmstrip.png`, sampled at
  8 frames per second from 5.5 seconds onward, shows each yellow car entering
  once, becoming submerged and disappearing. Rainfall's visible car does not
  return to the water surface after disappearance in this sampled sequence.
  The remaining contact ripple is distinct from an object replay.
- `build/weather-prismatic-20261007/encoded-rival-filmstrip.png`, sampled at
  8 frames per second from 12.15 seconds onward, shows stronger rival feedback:
  brief gold lightning and a purple expanding ring for Tempest; pearl droplets
  and a teal expanding ripple for Rainfall. Both settle back to idle without
  persistent full-mouth obstruction. The two responses remain visually distinct.
- `artifacts/weather-prismatic-20261007/collection-rainfall.png` shows both
  actual collection cards inside the visible `TIER 6 · PRISMATIC` section.
  At thumbnail size the pale rain cloud/teal pool and purple tornado still read
  differently. Names and rarity labels fit. Rainfall's selected description
  does not overlap the unlock control, and the fixed navigation is readable.

**Final visual verdict: pass for the refined pair, including the inspected
gameplay sequence and collection presentation.** The first candidate was not
accepted unchanged; the independent feedback caused a visible Rainfall revision.
This is a modest, coherent palette and response upgrade, not a claim of entirely
new modeling or rendering technology.

## Remaining limits

The video starts with an explicitly isolated cosmetic demonstration. Later
gameplay uses staged initial objects; it is not an unassisted player session.
The root reports five props and one rival per skin, score 60 to 79, and four
Rainfall render handoffs plus one normal fallback. These counts and scoring
timing are not independently derived from these sparse image samples. The
sampled no-replay observation supplements, rather than replaces, the root's
single-entry regression checks. Phone frame rate and input feel remain untested
by this visual reviewer.

## Full-gameplay supplement

The user subsequently requested normal in-game footage rather than the staged
skin demonstration. The reviewer read
`build/weather-gameplay-20261007/capture.gd` and its runner, and followed the
production `start_level`, `begin_play`, input and boost paths. The helper loads
the normal scene and default Sunny City, retains all seven normal AI rivals,
starts at score zero, and supplies scripted direction plus guarded boost calls.
It does not create staged props/rivals, teleport, award points or invoke cosmetic
absorption callbacks. Test mode isolates saves, production ads and purchases.
The controller does use internal food-target helpers, so this is scripted
gameplay, not a human play session.

The reviewer inspected the decoded Tempest gameplay overview, Rainfall rival
sequence, and full-resolution source frames 0, 462, 720 and 1170 for each skin.
They show the full ordinary city, traffic, pedestrians, moving camera and standard
HUD. The opening frame shows 90 seconds and zero points; later frames show
36 points and level 3. Independent `ffprobe` reads confirm both delivered MP4s
are 540 by 1174, 30 fps, 1,200 encoded frames and exactly 40 seconds. This resolves
the helper's hard-coded frame-count evidence caveat for these completed runs.

- Tempest remains visibly purple on pale roads and through normal building-reveal
  dithering. Its actual rival lightning is visible around frame 462.
- Rainfall remains a distinct teal water disk with a pale overhead cloud; the
  level-3 view shows its rings clearly. The sampled ordinary object sequence
  remains continuous, and the rival response expands then clears.
- The standard timer, score and boost controls remain readable. No new skin/UI
  overlap or rendering defect blocks delivery of these gameplay videos.

**Full-gameplay media verdict: pass, with normal-scale limits visible.** At the
small starting size, the Tempest upper funnel and Rainfall fine rain/cloud details
are subtle, and the normal player/level labels partially overlap the elevated
effects. Larger level-3 views read more clearly. The boost ring can temporarily
dominate the small rival effect. These are honest in-game scale/HUD limitations,
not grounds to replace the requested footage with a magnified beauty scene.
No source edits or phone performance measurements were made for this supplement.
