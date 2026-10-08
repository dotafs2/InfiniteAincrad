# Close map thumbnails: independent art review

Reviewer: `music_art_review`.
Date: 2026-10-08.
Scope: art direction and independent review of supplied real map screenshots
and rendered selection cards. Root owns capture implementation, assets and
export. This reviewer edits this document only and runs no engine jobs. Real
maps, saves and submitted native build 34 remain outside this cosmetic framing
change.

Current status: **final PASS for capture 03, actual GPU carousel presentation
and the exact focused export**. Earlier survey decisions are preserved below
as review history; final package hashes and verification are at the end.

## Baseline inspection

Read the current roadmap, latest history and conversation continuity guidance.
Directly inspected all four current `assets/map_thumbnails/*.png` images, the
capture script, carousel image layout, authored district/actor placement and
the real Frost conversion and wildlife source. The four 880x620 thumbnails are
real GPU world captures with hidden HUD and holes. Their current orthographic
sizes are City 64, Food 87, Toys 62 and Frost 49.

The user's complaint is supported by the pixels. City contains several complete
blocks and many partial buildings, making pedestrians tiny. Food presents a
large field of pastry towers with almost no immediately recognizable people.
Toys emphasizes widely separated giant castles, while its guards are small
details along the lanes. Frost is already closer, but the visible penguins are
small beside a large glacier and the slab boundary distracts at the lower right.

The revised thumbnail should present one inhabited thematic scene per world:
approximately five or six major architectural/landform masses, with clearly
recognizable existing people or animals in its foreground or middle ground.
Small authentic props and snacks may remain; floors of one tower do not count
as separate buildings. Do not manufacture a five-object arrangement, enlarge
actors or replace the real game environment with a painted concept.

## Capture starting points

These are camera hypotheses for an initial render, not approval or mandatory
constants. Final judgement must use pixels at the actual card size and crop.

| World | Suggested focus and size | Composition priority |
| --- | --- | --- |
| City | Around `(0,4,17)`, orthographic size 30–34 | One six-building frontage with its sidewalk and recognizable pedestrians, rather than several adjacent blocks. |
| Food | Biscuit Old Town around `(-42,4,12)`, size 27–30; Crescent Market around `(1,4,26)` is an alternative | A small variety of pastry buildings beside an inhabited lane; avoid filling the image with dozens of towers. |
| Toys | Around `(25,4,27)`, size 32–36, potentially viewed from negative Z | One inner Mint castle and nearby cottages/turrets, with the guard lane in front instead of hidden behind the castle. |
| Frost | Around `(70,2,-69)`, size 30–34, testing the side that exposes the penguins | A glacier group and its existing penguin cluster; avoid the artificial slab boundary. |

City's authored frontage includes six parcels along z12, with x ranging from
-17.5 to 17.5. Food has existing pedestrians near `(-41.43,7.16)` and
`(-45.10,16.52)` beside Biscuit Old Town's pastry frontage. Toys' Mint castle is
at `(23,41)` in the ground plane, while its guard station is `(23,18)` and the
initial marching unit lies around x36–38/z18. Simply centering the castle could
hide those actors; a view from the lane toward it is preferable. Frost's existing
penguins occupy x66–78/z-73..-68; the current view exposes only a small part of
that group. These source facts guide framing without moving any actor.

Keep an elevated oblique view around 35–45 degrees downward so façades remain
legible and actors are not lost behind them. Aim for a strong middle-ground
landmark, an inhabited foreground lane and a compact supporting skyline. Avoid
cutting the main landmark's roof or hiding all figures along the photo edge.

## Required final visual checks

- Each image is visibly closer than its baseline and contains about five or
  six dominant buildings or glacier forms, rather than an entire neighborhood.
- Existing people or animals have recognizable silhouettes at displayed card
  size. Approximately 12–20 pixels high in a roughly 416-pixel-wide photo is a
  useful target; an actor visible only when zooming the source PNG is insufficient.
- The four themes are immediately distinct: ordinary city frontage, edible
  pastry city, toy/castle town and Arctic glacier wildlife. Frost must remain
  an ice landscape rather than reverting to the inherited toy castle appearance.
- Actual carousel cards preserve the intended subjects after
  `STRETCH_KEEP_ASPECT_COVERED`, including locked-card tint and short/tall
  responsive crops. A good standalone landscape image is insufficient if the
  card removes its figures or landmark.
- The new files remain truthful local-world captures. No altered map geometry,
  actor scale, save/economy state or native publication is implied by framing.

Final art approval requires inspecting supplied new captures and their actual
selection-card presentation. No engine execution, phone performance or browser
interaction is claimed by this reviewer at this stage.

## Survey 01: City candidate selected; other worlds need another framing pass

Directly inspected all twelve real images in
`artifacts/map-thumbnails-close-20261008/survey-01/`: default, tighter and
reverse-angle versions for each world. Read their capture receipt and current
capture source. Existing idle poses are evaluated once and the world is then
frozen; actors are not moved or enlarged. This is a camera survey, not actual
round progression or a staged rare scene.

City's default size-33 capture is the strongest City candidate. Its six
frontage buildings are complete, individually readable and substantially larger
than the original overview. Cars and pedestrians give useful scale. The tighter
image cuts the final building and crowds the edges; the reverse angle increases
occlusion between the taller fronts. **Select default City for actual-card
review**, with final acceptance still depending on the card crop.

None of the three Food images is approved. Although people are more recognizable,
the focus falls on a broad white crossroads, while major foreground cakes and
supporting buildings are cropped. This is a compositional miss in the initial
camera hypothesis, not a reason to alter the map. The stronger follow-up target
is the existing six-building cluster below, with focus around `(-39,4,22)`, size
27–29 and a north-side oblique offset such as `(-30,44,-58)`. Compare the original
positive-X/positive-Z angle at the same new focus if useful.

| Existing Food building | Ground position `(x,z)` |
| --- | --- |
| Wedding-cake landmark | `(-49.578,19.998)` |
| Small cakery | `(-42.939,20.723)` |
| Burger apartments | `(-36.477,19.676)` |
| Cake apartments | `(-30.730,17.520)` |
| Donut apartments | `(-36.375,30.757)` |
| Cake apartments | `(-31.365,27.714)` |

The existing people at `(-45.098,16.516)` and `(-41.427,7.158)` occupy the
north-side lane. Looking from that side may keep them in front of the cluster.
These positions were read from the actual neighborhood plan and source spawn
formula; the suggested resulting image is still an unrendered hypothesis.

Toys' negative-Z images make the guard lane clear but mainly show plain backs of
the buildings. The reverse angle exposes the cheerful timbered fronts, doors,
clock and color variety, which is more appropriate for the selection card, but
some figures hide behind its nearest houses. **Prefer the reverse angle for a
refinement**, moving focus from `(25,4,27)` toward the guard lane around
`(25,4,22)` at size32–34. Avoid losing the main castle or cutting the foreground
clock installation; the actual follow-up must establish both architecture and
figures together.

Frost's default size31 capture retains attractive lit glacier facets and two
clear penguins. Its tighter view crops supporting forms. The reverse view shows
four penguins, but the central glacier becomes a large dark wall and the scene
loses some of its inviting icy color. **Test the proposed east-side offset
`(60,40,-22)` at size30–31** before settling on the default as fallback. More
animals alone do not outweigh poor landform presentation.

The next decision should use these focused follow-ups and actual card crops.
No full four-thumbnail approval is granted at this survey stage.

## Survey 02: Frost candidate selected; Food and Toys recentering required

Read the second camera receipt and directly inspected its default City image
and all nine Food/Toys/Frost variants. City default33 remains the selected
candidate for actual-card review.

**Select the new east-side Frost image** (`survey-02/frost.png`, size31,
offset `(60,40,-22)`) for card review. Its four penguins lie near the center,
where a narrower card crop is more likely to retain them. Several supporting
ice rocks/spires frame the dominant glacier. Although one face is shaded, the
lit snowy ridge and blue facets remain readable; it no longer resembles the
previous reverse view's broad flat dark wall. The added recognizable wildlife
makes this a stronger inhabited scene than the old two-penguin angle. Reject
the tighter Frost variant because it clips the glacier top and supporting forms.

Food's north-side view is much better than the white crossroads, with clear
people along its lower lane, but more than ten prominent stacks still compete.
The tighter view at the same focus crops large buildings rather than selecting
a coherent smaller group. Support a further recentered test around
`(-42,4.5,24)` at size23, retaining the north-side offset. Final acceptance still
requires complete key silhouettes and visible people; reducing size alone is
insufficient.

Toys at the proposed z22 focus does not pass. The recommendation to move toward
the lane exposed too much empty crossing and pushed the central castle toward
the lower-right edge. The more attractive front-facing camera remains the
better angle, but the focus must return to the actual building cluster around
`(24,4,33–35)` at size30–32. This is a correction to the previous framing
hypothesis based on actual pixels. Preserve the nearby visible guard group
without accepting cropped main architecture.

Keep key subjects near the middle 70 percent of the source width until actual
short/tall cards establish the effect of their aspect-cover crop. The final
selection is still incomplete: City and Frost have strong capture candidates;
Food and Toys need the bounded follow-up above.

## Capture 03 and actual carousel: visual PASS

Directly inspected the four installed source PNGs and verified each is
byte-identical to its actual `capture-03/` image. The final camera settings are:

| World | Focus | Orthographic size | Camera offset |
| --- | --- | ---: | --- |
| City | `(0,4,17)` | 33 | `(48,46,58)` |
| Food | `(-42,4.5,24)` | 23 | `(-30,44,-58)` |
| Toys | `(24,4,34)` | 32 | `(-48,42,52)` |
| Frost | `(71,3,-69)` | 31 | `(60,40,-22)` |

Then directly inspected the actual GPU carousel images in `ui-gpu-01/`: all
four unlocked tall cards, locked Food/Frost, City/Frost at the short and 440-wide
layouts, and the safe-inset Frost fixture. The more square tall-card crop is
materially different from the source landscape image and was judged separately.

**All four final visual candidates are accepted.** City presents a clear compact
frontage of approximately five to six main buildings, with cars, sidewalk
figures and a small park giving it scale and life. The tallest end of the row is
partially cropped on tall cards, but the scene and its individual buildings
remain clear. Food now emphasizes an inhabited pastry corner with readable
cake, burger, doughnut and wafer shapes and people along the lower lane. It
retains secondary background stacks; it must not be described as literally
containing only six buildings. The intended small set of dominant thematic
groups is the useful criterion here, rather than a mechanical object count.

Toys' corrected focus retains its complete main castle, colorful front-facing
houses, clock and recognizable guard group along the upper-left lane. It fixes
the survey 02 crop that pushed the castle into the lower-right edge. Frost's
card keeps all four penguins near the center under the lit glacier ridge, with
surrounding ice forms establishing an Arctic landscape. Its central placement
survives the tall and inset crops.

Locked tint does not erase Food's figures or Frost's animal silhouettes. None
of the new images interferes with card titles, conditions, navigation or PLAY.
At the smallest actual viewport, people and animals naturally lose fine detail;
this approval does not claim legible faces, clothing details or enlarged actors
at that scale. The images are substantially closer and more inhabited than
their prior overview thumbnails. No further art revision is requested.

The root-produced actual GPU receipt contains 574 checks and zero failures.
Independently scanned the complete capture 03 engine/stdout logs and the four
GPU import/acceptance logs for error, warning, script-error, polygon and resource
leak diagnostics; none were found. The capture source SHA-256 is
`ff188877acfd5cf6ae48cdffa3e68f6d1984b7f69b1b6f22745964cbb9e289e4`.

Accepted installed PNG SHA-256 values:

| File | SHA-256 |
| --- | --- |
| `assets/map_thumbnails/city.png` | `7fc099ca1c50df1167ddebfd1b587cca34af00ec12dfd47eee52a6587811f18d` |
| `assets/map_thumbnails/food.png` | `d680ab1d660659efde9824b88e95d3fc5a2aa1b339592e92b55ea0f1cf0bbe4f` |
| `assets/map_thumbnails/toys.png` | `b899b64f3bc03160bf7cd0424bd6d7343bf98887ad5e541229197b03a436feca` |
| `assets/map_thumbnails/frost.png` | `9b89de38f6cfb5d564db54a04b0c8fa51b3f0cc9e331249a20d311f079d80f67` |

This is an art/capture/actual-card approval of those exact files. Final export
verification remains separate. Root ran the engine jobs; this reviewer inspected
images, source, receipts, logs and bytes. No physical phone, browser interaction,
native upload, real progression or player-save modification is claimed here.

## Final exact-export closure: PASS

Independently read the final focused release and all four source/package suite
receipts. The `map_carousel` and `map_unlock` suites total 653 checks with zero
failures in each of source and exact-package phases. This complements the
separately inspected actual Mac GPU card receipt of 574 checks with zero
failures; it does not replace the actual-image review above.

Recomputed all 1,333 guarded source hashes and all 18 installed web export hashes
against the final manifest. Every hash matches. Compared with the accepted
celebration focused-gate-02 baseline, exactly five guarded inputs changed: the
four thumbnail PNGs and `tests/map_thumbnail_capture.gd`. No guarded input was
removed. Runtime/UI source and the map, music, skin, save and economy inputs
retain their baseline hashes. The installed PNGs are the exact visually
accepted images identified in the preceding table.

Scanned the complete contents of all ten focused suite/export log files for
error, warning, script-error, invalid-polygon and resource-leak diagnostics;
none were found. Root executed the engines and export. This reviewer performed
independent read-only receipt, log, source-delta and byte-hash verification.

Final accepted artifacts:

- Release manifest: `artifacts/map-thumbnails-close-20261008/focused-gate-01/release.json`,
  SHA-256 `2b49d1a342d7e83ae098a94cd73502db6d4bfd84f90bdd8565a52d40fcb3a7a4`.
- Installed package: `build/map-thumbnails-close-20261008/web/index.pck`,
  SHA-256 `a1524fba2c2a64e1f256a76bbc0ac950465f39e21970d0871a0bdf87939cea02`.
- Accepted celebration baseline manifest: SHA-256
  `f237a6a57afc0d949aa558a393a15f3df57802e2cabde5e911f7050fa497157e`.

**Final art and exact-artifact verdict: PASS.** No remaining composition,
theme-readability or verified-artifact blocker remains for the four close map
thumbnails. This is focused two-suite acceptance of five changed inputs, not
a newly executed complete release gate. Small-card character-detail limits and
the authentic extra background structures noted above remain explicit. This
review does not certify browser interaction, physical-phone output/performance,
native upload or actual-player progression/save changes.
