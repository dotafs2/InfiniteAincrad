# Original royal castle map — independent art review

Reviewer: independent art reviewer 1 (`music_art_review`). Date: 2026-10-08.

## Scope and current verdict

**ACCEPT — the final current map, models, installed thumbnail/card, sampled
dynamic presentation and exact Web package pass this independent art review.**
The real third map now has layered original castle forms, recessed entries and
localized court gardens; the change is visible during gameplay as well as in
its recaptured thumbnail. The earlier thumbnail-only approval covered framing,
not this architecture work. Earlier holds below are preserved review history;
the final closure section identifies the accepted revision and limitations.

This reviewer owns this document only. Root owns map integration and ground;
the model worker owns the original Blender builder and assets. I have not run an
engine, changed production files, used the phone, or modified saves/build 34.

## Evidence inspected

- Current ROADMAP, latest HISTORY and conversation-history README were read.
- Actual baseline `assets/map_thumbnails/toys.png` (880 × 620), SHA-256
  `b899b64f3bc03160bf7cd0424bd6d7343bf98887ad5e541229197b03a436feca`.
- Read the current Blender builder, `fairytale_meshes.gd`,
  `fairytale_lighting.gd`, `toy_neighborhoods.gd`, and `toy_ground.gdshader`.
- Read the official [Disneyland Paris refurbishment article](https://news.disneylandparis.com/en/chateau-renovation/)
  and directly viewed its [official front photograph](https://news.disneylandparis.com/app/uploads/2021/12/SB_0037-scaled.jpg).
  Temporary research copy SHA-256:
  `7cd8637f38af8fb420713eb8b275ef04f6619a4f71c725958a27eaffc5f2ad99`.
- Read the official [Cinderella Castle attraction page](https://disneyworld.disney.go.com/attractions/magic-kingdom/cinderella-castle/).
  Its accessible page did not expose a useful castle photograph. Read the
  [official Disney Parks refresh article](https://disneyparksblog.com/wdw/meet-the-team-behind-cinderella-castles-sparkling-refresh/)
  instead and directly viewed its [June 2026 photograph](https://disneyparksblog.com/app/uploads/2026/06/Cinderella-Castle-Magic-Kingdom.jpg).
  Temporary research copy SHA-256:
  `753afcbf4d3036a2bdc6e365ad66ef06a18376617d8c0d8c1ecf992c9cdb5a4b`.

Reference photos are research evidence, not game textures or shipped assets.
The target is an original named fantasy design and composition. No Disney
branding, character art, exact facade, or site layout is proposed.

## Visual findings and concrete direction

The baseline is legible as a colorful toy town, but its central large gable,
four similar cones and repeated windows form an oversized house with turrets.
The smooth mushroom towers, equally bright colors and scattered miniatures do
not establish a royal focal point. A green parcel ends abruptly at each wall;
the straight gold road grid has no entrance or garden hierarchy.

The Paris photograph shows a tall visible shaft beneath a fine spire, attached
towers at differing heights, projecting balconies and cornices, grouped dark
windows, and a substantial entrance base. The Florida photograph likewise
separates a low stone gate base, pale middle and high keep, with blue roofs and
fine gold trim. These observed structural principles, rather than their exact
shapes or color placement, inform the following original design direction.

1. **Establish three mass tiers.** Build a broad low gate/front wing, a narrower
   inhabited middle and one dominant tall keep. Step secondary towers to
   different heights and offsets. The central keep should remain recognizable
   when the model is reduced to a silhouette. Do not let five similar tips form
   an even row or a single huge gable swallow the composition.
2. **Show walls below roofs.** Use long readable tower shafts; a roof should
   generally occupy less than half a tower's visible height. Add a real eave
   lip, a restrained shoulder/profile break and a fine cap or finial. Mix round
   or polygonal towers with rectangular wings. The change must be visible from
   the game's elevated camera, not only a Blender close-up.
3. **Make entries and facades three-dimensional.** A deep dark gate within a
   projecting pale portal gives the visitor a destination. Group larger main
   windows and smaller upper windows around believable floor/cornice bands.
   Use visible surrounds, sills and one readable balcony or terrace. Allocate
   geometry to silhouette and shadow-producing relief before tiny decorations.
4. **Use a controlled value hierarchy.** A slightly darker/desaturated base,
   cream or restrained rose middle, deeper blue/teal roof family and fine gold
   accents will separate parts under actual game lighting. Keep roof highlights
   from becoming broad white patches. Current runtime palette replacement can
   override authored roof colors, so model and integration choices must agree.
5. **Build an original royal setting.** Add a gate apron, a narrow approach from
   the existing road and restrained garden borders inside parcel clearance.
   Softer green lawns and quieter warm paving will support the architecture.
   Keep edible miniatures, their growth route and guard ranks legible; do not
   crowd the entrance with hedges or hide people behind decorative walls.
6. **Differentiate the kit.** Grand castle, courtyard castle, watchtower, gate
   and townhouse should have related materials but different profiles. A
   thinner townhouse roof and facade rhythm should support the major keep.
   Repeating the same castle at every scale would preserve the baseline issue.

The model worker reports fixed natural-size envelopes and existing triangle
budgets. This review supports those constraints: richness should come from
better distribution of existing masses and bounded detail. Ground/site work
must retain the physically cut holes and reserved playable lanes.

## Acceptance evidence required

- Actual game renders at normal play distance and a close inspection view,
  including both front and a side/back elevation. Compare to the saved baseline
  under equivalent framing so the form change is attributable to the map.
- Actual guards/royal actors and the hole visible with readable scale and
  path clearance. Gardens should frame the gate rather than cover the play area.
- At least one grand castle and the smaller kit members visibly improved;
  avoid a single showcase model surrounded by the unchanged crude kit.
- Actual swallowing/dynamic use evidence must preserve coherent whole-building
  presentation and not expose glaring intersections or detached trim.
- The regenerated selection image must show the accepted real map. Verify the
  other three maps, their assets, saves and submitted native build remain in
  scope as preserved, with the runtime reviewer supplying relevant checks.
- Final acceptance will bind to exact current asset/source hashes, actual GPU
  evidence and package receipts. Static source inspection alone is insufficient.

No final visual, performance, phone or exact-package acceptance is claimed yet.

## Candidate 02 / actual `after-01` GPU review

**HOLD — material improvements verified; three corrections requested.**

Directly viewed all five `after-01` images (crown front, crown rear,
neighborhood, townhouses and overview), plus the matched baseline crown,
neighborhood and overview. The receipt identifies the real `toys` world,
unchanged actor placement/scale and evaluated Idle pose, with the same camera
definitions as the baseline. These are frozen inspection frames, not timed
gameplay or phone evidence. The candidate asset manifest observed during this
review hashes to
`675b2b024853733477b10567b0a1e671ed93a1c0221206122b66802c74c3e1af`.

The new lower keep, middle hall and central blue crown constitute a real change
in massing. The shaft remains visible above the hall; unequal corner heights,
roof rims and the rear windows improve the silhouette and side/back treatment.
The darker lawn and calmer paving also help. This is substantially better than
a color-only edit.

The remaining visible issues are:

1. **Entrance:** the large flat pink double door dominates the main castle and
   still reads as a sticker or plastic slab. Replace its bright flat fill with
   a deep, desaturated gate color and visible inset under the projecting pale
   arch. Retain narrow hardware rather than a broad gold fill.
2. **Dormers:** the pair below the crown looks like oversized wedges attached
   to the tower. Uniformly reduce the whole assembly by about half and seat
   it in the upper roof. A smaller paired rhythm is preferred to adding more
   detail. The model worker identified that the earlier width parameter did
   not scale the helper's fixed height, and will correct that proportion.
3. **Setting:** the new aprons alone still leave repeated isolated toy parcels.
   Add restrained planted borders or short paired hedge/topiary groups at major
   court approaches, within existing clearance. Preserve guards and collectible
   lanes; do not increase the color count or fill all open lawn.

Broad repeated pink middle bands remain a secondary visual concern, to be
reassessed after the darker entry and subordinate dormers. No additional tower
count or indiscriminate polygon/detail increase is requested. Final map approval
is still pending the corrected real frames and the previously listed gameplay
and package evidence.

## Candidate 03 / actual `after-02` GPU review

**PASS for current static model and scene quality. Final acceptance pending.**

Directly viewed all six current actual GPU frames: crown front, crown rear,
garden close view, neighborhood, townhouses and overview. The new dark gate
has a readable pale portal edge and inset; the single half-size dormer is now
subordinate to the central shaft. Front and rear remain coherent, the smaller
castles share the improved hierarchy, and the deep blue crown ties the pastel
flanks together. The remaining rose bands are compatible with the established
toy-castle style and are not a blocker after the entry correction.

The paired topiary and low flower planters frame the two main crown courts.
Their groups remain visually separate from guards and the avenue in the garden
view. This is localized landscaping at two courts, not a claim that every map
parcel has become a formal garden. It supplies the previously missing setting
while leaving the toy collectibles and approach readable. No further static
art correction is requested; the model worker was advised to freeze the assets.

Observed current SHA-256 identities:

| Item | SHA-256 |
| --- | --- |
| Asset manifest | `f8dba47056b5b233a25c927ad7b907af16798d238e2c267ed7e99d7741180784` |
| Blender generator | `020d213386d20e22c0a2dca51301f172784ab27f264fadd9ec275a4611de5631` |
| Source blend recorded by manifest | `f174e03bbbd5c18e4532e817fc125a29fc27e6a30eee361e89774b40a7e09766` |
| `after-02/capture.json` | `7dc688c9cf4dbccfe1f5243ff41c61a84dcc832272d4bbac45765dae66af8ac3` |

These frozen inspection frames do not establish ordinary play, dynamic
swallowing, phone performance or final export equivalence. Remaining closure
evidence: timed normal gameplay and whole-building swallowing presentation,
the regenerated real-map thumbnail in its actual card, and exact-package
receipts covering the accepted current revision.

## Normal play and thumbnail review

Read both `play-01/capture.json` and `play-02/capture.json`. Both record a
90.0167-second ordinary automatic-collection round, starting at level 1 with
zero score and ending at level 7 with 326 points. The final collection summary
records 77 objects including three `toy_castle` bodies. Directly inspected
`play-02` images at start, 12, 30, 60 and 89 seconds and the result screen.
The actual following camera shows the new kit, people, open lanes and readable
hole; the late foreground castle uses the existing dither reveal. These images
and receipts support integration into ordinary play. They are not a continuous
human-controlled playtest or phone-performance certification.

Thumbnail 01 did not strongly communicate the new royal silhouette. Thumbnail
02 made it larger, but its broad diagonal white pedestal backdrop was a visible
quality blocker. This reviewer rejected it and requested an inward-facing
composition from a southern castle. Thumbnail 03 solved that backdrop but was
wide. **Thumbnail 04 passes raw image review:** the full main castle is dominant,
the dark gate and blue crown read clearly, the town and people remain in the
background, and the perimeter slab is excluded. Root was advised to install it
and capture the actual responsive cards.

Accepted raw thumbnail SHA-256:
`f92a4dcc9937d7db4e66e853cb8812e1c983b559af43ab59c030cdd9ac8e19ec`.
Its `thumbnail-04/capture.json` SHA-256:
`2c67f729548033d5b6be56848fa98f2b3807b7380bfb8e19e2a3380599324af3`.

## Swallow fixture correction still pending

Independently probed `swallow-02/royal.mp4`: 540 × 960, 30 fps, 437 frames,
14.566667 seconds, no audio stream. Directly inspected the hero, 15/35/65 and
completion PNGs and a half-second sampling across the movie. The grand castle
descends as a coherent body in those samples, with no detached roof or trim.
The labels correctly identify a staged late-growth real-physics fixture; the
receipt records one 96-point grand-castle collection.

However, surrounding garden props remained suspended inside the open hole
because the fixture froze non-target bodies. This reviewer raised the visible
limitation. Root confirmed it was a capture-helper flaw and is recording
`swallow-03` using the normal food scan so neighbors can fall naturally. The
earlier movie is diagnostic evidence, not the final dynamic presentation. No
production physics change was requested for this fixture correction.

Final closure still awaits corrected swallow evidence, actual installed cards
and exact-package verification.

## Installed card and corrected sweep review

**Actual installed card review passes.** Directly viewed
`ui-gpu-01/unlocked-toys-tall.png` and `toy-progress-tall.png`. The complete
main crown, gate and side towers remain legible after the real card crop;
background people remain visible, and the photograph does not occlude text or
controls. The installed `assets/map_thumbnails/toys.png` hashes identically to
the accepted thumbnail 04 (`f92a4dcc…`). The GPU report records 574 checks and
no failures. The other size/safe-area cases in that report concern the shared
carousel; this reviewer is not claiming a separate Toy PNG at every size.

The corrected `swallow-04` frame sequence now uses a staged level-12 movement
path and normal food scan. Directly inspected its 35/65/completion images:
the main castle descends and neighboring props clear during the later sweep,
with a neighboring small castle beginning to tilt at the end. The ledger
contains seven collected objects: one grand castle worth 96, four topiary worth
16 together, and two flowerbeds worth 8 together (120 total). Exactly one
target grand-castle receipt is recorded. This resolves the frozen-neighbor
presentation flaw; no new static art/model blocker is observed. The fixture is
explicitly not evidence that an ordinary 90-second round reaches level 12.

The final `swallow-04/royal.mp4` was independently probed and decoded into
half-second samples spanning the clip: 540 × 960, 30 fps, 437 frames,
14.566667 seconds, with no audio stream. **Sampled dynamic presentation passes.**
The original main castle stays coherent as it sinks behind the hole mouth;
the nearby garden objects subsequently clear and the small foreground castle
tilts into the moving mouth. No detached trim or frozen-neighbor condition is
observed in these samples. This is frame-sampled inspection, not a claim of
subjective real-time playback or exhaustive examination of all 437 frames.

Final movie SHA-256:
`5620ab71689952df04754dcff468fdceb8bdb65e897862d718bf69f3f8191f61`.
Corrected sweep receipt SHA-256:
`31062fe24e2bfd7c68de766937e73479408e69c6f93839d3453c550c620d9644`.
GPU carousel report SHA-256:
`c32b99eaddf9467c2c6f43ccfd2bb255b53648d632974f9bb9b8c62093c1a73d`.

Model, static scene, normal-play integration evidence, installed card and sampled
dynamic presentation now pass this art review. Exact-package verification
remains pending for final closure.

## Final exact-package closure

**ACCEPT.** Independently read `web-gate-01/release.json`, recomputed all 1,342
guarded source-file hashes and all 18 installed export hashes, and found zero
mismatches. Summed the individual reports: 98 source suites pass 176,870 checks;
98 exact-PCK suites pass 176,860 checks; both have zero failures. The ten-check
difference is confined to `frost_legacy_physics`: source runs additionally
rebuild five historical visual payloads from the preserved local baseline,
which is intentionally absent from the package. Both phases verify the shipped
frozen-physics resource. The runtime reviewer independently accepts the exact
package and other-map isolation.

The current castle manifest, generator, actual `.blend` file and installed Toy
thumbnail still match the accepted hashes recorded above. The City, Food and
Frost thumbnail hashes match the preceding accepted thumbnail release.

| Final artifact | SHA-256 |
| --- | --- |
| `web-gate-01/release.json` | `e1174c847489eb053141d4604a319b91c23aaa760e893607b9c2562d5d1b0a1d` |
| Installed `index.pck` | `60750bb44a19a1f388449f9a1cb4267eb730e23f5e06b2eaa72142b2aea73297` |

Also directly inspected root's `browser-title.png` and `browser-play.png` from
the QA-only launcher using the same exact PCK. They show the new real Toy card
and playable castle neighborhood with people and a four-point score.
`browser-console.json` is empty. Root performed the browser interaction;
this reviewer inspected the resulting evidence and reconfirmed PCK identity.
The separate QA HTML is not a replacement of the guarded release entry point.

The acceptance is scoped to the current local source and exact Web export,
actual Mac GPU images, the reported ordinary automatic-collection rounds and
frame-sampled staged sweep. No physical-phone performance, submitted native
build replacement, exhaustive continuous-video inspection or subjective audio
audition is claimed. No further art blocker remains for this revision.
