# Independent Common concept review

Reviewed October 7, 2026. The reviewer inspected all 20 individual PNGs under
`artifacts/common-concepts-20261007/` against `COMMON.md`. These are generated
static appearance concepts, not rendered game models. The reviewer did not
generate the images or implement the game assets.

## Result

All 20 pass the static concept review. Every image has a large empty dark mouth,
no floor or prop sealing it, and material/form features beyond a base-ring recolor.
No concept requires permanent ambient effects to communicate its theme. Rarity
badge color does not limit the body palette.

| # | Skin | Verdict and defining feature to retain in the game model |
| --- | --- | --- |
| 01 | Cookie Bite | Pass: large bite notch, thick baked edge and distinct chocolate chunks. |
| 02 | Citrus Slice | Pass: separated flesh segments, thick pith and uneven peel; not just an orange ring. |
| 03 | Melon Munch | Pass: raised seeds and layered striped rind distinguish it from Citrus Slice. |
| 04 | Pancake Stack | Pass: three broad layers, butter and sparse syrup; no waffle-grid duplication. |
| 05 | Bacon Curl | Pass: continuous irregular curled strip and raised fat bands create a unique outline. |
| 06 | Slate Ring | Pass: asymmetric beveled stone pieces and visible joins replace the former plain gray ring. |
| 07 | Paper Boat | Pass: angular paper folds, bow and stern, with no deck across the opening. |
| 08 | Toy Tire | Pass: thick tread blocks, rounded rubber body and separate sidewall. |
| 09 | Leaf Cup | Pass: one asymmetric curled leaf, broad veins and an exterior stem. |
| 10 | Wooden Tub | Pass: uneven upright staves and two bands give it a distinct container profile. |
| 11 | Rope Coil | Pass: thick twists, one readable knot and an exterior loose end. |
| 12 | Clay Pot | Pass: bulging squat wall, uneven rolled lip and two small side handles. |
| 13 | Shell Cup | Pass: scalloped outer lip and raised radial ribs; no spiral-shell overlap. |
| 14 | Woven Nest | Pass: large crossed twigs and straw lip, with no eggs, bird or closed nest floor. |
| 15 | Paint Tin | Pass: rolled metal edge, lowered exterior handle, paint drips and blank label. |
| 16 | Denim Pocket | Pass: padded pentagonal shape, seams and frayed corners; not a blue circle. |
| 17 | Catcher's Mitt | Pass: distinct thumb/finger silhouette, padding and large laces, with an open center. |
| 18 | Enamel Basin | Pass: broad shallow oval wall and rolled cobalt lip; simpler than the other containers. |
| 19 | Acorn Cup | Pass: overlapping cap scales, warm interior edge and short exterior stem; no nut blocking the mouth. |
| 20 | Knit Cap | Pass: folded contrasting cuff, cable-knit divisions and a small side pompom; no fabric across the mouth. |

## Conditions for implementation review

- This is approval of the pictured direction, not a claim that the concepts are
  already integrated, affordable to render, animated, or accepted by the user.
- Food pores, citrus pulp microdetail, stone grain, leather pores, denim weave and
  individual fibers belong primarily in baked textures/materials. Preserve the
  large shapes instead of reproducing every strand or stitch as geometry.
- Rope, Leaf, Shell and Denim must not degrade into beige, green, pink and blue
  toruses. Knit Cap needs its cuff/pompom and broad cable rhythm even if fine weave
  is baked. Catcher's Mitt may simplify seams and finger articulation, but must
  retain the thumb and padded glove silhouette.
- Wooden Tub, Clay Pot, Paint Tin and Enamel Basin must retain their distinct
  profiles. Swapping a shared bowl's color/material is insufficient.
- Every final skin still needs actual Mac GPU inspection at normal gameplay
  scale and visible, short, themed rival feedback. These static images contain
  no evidence of that behavior. Standard labels and boost effects must not hide
  the entire rival response.
- Hollow appearance does not establish physical admission correctness. Gameplay
  mouth/collision consistency, scoring speed, no replay, save compatibility and
  performance remain separate checks.

## First actual runtime pass: corrections required

The reviewer subsequently inspected all 40 Godot GPU images in the first
`artifacts/common-runtime-20261007/` capture: one idle and one rival-response image
for each of the 20 IDs. **This first runtime implementation is not accepted yet.**
The concept-image approval above is not an approval of this implementation.

Prioritized findings sent to the root and geometry owner:

1. Pale background shows between the preview's dark opening and many inner rims,
   especially Rope Coil and Denim Pocket. The rim and mouth must read as one
   continuous opening without changing physical mouth size.
2. Catcher's Mitt is a beige segmented ring without a clear glove thumb/finger
   silhouette. Acorn Cup is a largely smooth green torus with sparse tabs. Knit
   Cap is a pink torus missing broad cuff/cable structure. Woven Nest is dominated
   by thin concentric straw loops. Restore their large identifying forms; adding
   microscopic texture cannot repair these silhouette failures.
3. Rope Coil is too thin and separated from the opening. Increase contiguous
   twisted bulk while retaining the knot and end.
4. Melon Munch shows anomalous white vertical strips along the rear inner wall.
   Pancake Stack's syrup reads as detached rectangular plates. Correct overlap
   and attachment before final capture.
5. Secondary improvements: pad Denim's angular border and attach its flap; add
   a clear folded/tapered lobe to Leaf Cup; connect Paper Boat's folded planes;
   reduce Citrus's washed-out yellow so its intended orange identity survives.

All 20 enlarged rival captures do show an exterior burst while keeping the mouth
clear. Four reused effect families are visible: chunks, droplets, flat fragments
and thread-like pieces. Bounded family reuse is acceptable at Common tier, but
these isolated large images do not establish visibility under normal gameplay
labels and boost effects. Actual gameplay and corrected GPU images remain needed.

## Second actual runtime pass: 18 silhouettes pass, two need revision

All 20 idle and all 20 rival images from Capture02 were inspected. The mouth-to-rim
background gaps are closed. Melon's white inner strips are gone, and Pancake's
syrup no longer presents as large detached rectangular plates. Rope has contiguous
twisted bulk; Nest now has substantial crossed twigs; Acorn has overlapping cap
scales. These are visible structural improvements rather than palette changes.

Eighteen skins meet the minimum stylized Common appearance contract in these
enlarged GPU captures. That is a silhouette/material review, subject to separate
topology, gameplay and performance checks. Two do not yet pass:

- **Catcher's Mitt:** four isolated round tan bumps read as buns or caramels on a
  ring. Replace them with elongated, flattened, connected finger pads and one
  broader side thumb. Sink the pads into the shared leather body; use dark seams
  and short laces between adjacent pads. More leather microtexture will not fix
  this large-form problem.
- **Knit Cap:** the small angular X ornaments read as attached bows. Replace them
  with three or four broad curved cable crossings spanning the pink rim, with
  ends tucked into the contrasting cuff. Preserve the open mouth and pompom.

The Capture02 rival stills retain visible exterior fragments without filling the
mouth. Their four reused effect families remain acceptable for Common. These
large static bursts do not prove animation timing or visibility at normal player
size under the HUD, and are not a substitute for ordinary gameplay evidence.

## Third actual runtime pass: Mitt passes; Knit remains the weak model

The changed Catcher's Mitt, Knit Cap and Pancake Stack idle/rival images were
inspected from Capture03. Mitt now has connected elongated pads, a side thumb,
dark seams and connecting laces. It passes the minimum stylized Common silhouette
contract, with intentionally angular rather than concept-render leather forms.
Pancake's lower syrup remains attached; its layered food identity passes.

Knit's four smoother curves improve on the former six angular X ornaments, but
the visible result still resembles loose straps or handles on a pink torus.
Half of each intended crossing disappears into the surface. This is the one
remaining requested appearance correction: flatten the cables against the rim,
show both interlaced strands continuously across its width, and tuck only their
endpoints into the cuff. More strands or microscopic stitches are unnecessary.
All three rival stills retain exterior fragments and an unobstructed mouth.

Current visual verdict: **19 minimum Common silhouette passes, one pending Knit
revision**. This does not claim parity with the generated concept renders or
establish ordinary-gameplay feedback/performance.

## Fourth actual runtime pass: isolated appearance review passes

Knit Cap's final Capture04 idle and rival images were inspected. Both cable
strands now remain visible continuously and lie against the curved rim; the
raised-handle appearance and half-submerged crossings are gone. Along with the
woven surface, contrasting folded cuff and side pompom, this meets the minimum
Common appearance contract. It remains one of the simpler concept
interpretations and should not be presented as concept-render fidelity.

**Final isolated appearance verdict: all 20 designs pass.** This follows the full
Capture02 inspection and targeted reinspection of every subsequently changed
shape, rather than assuming a pass from source-code changes. All retain a clear
open mouth, recognizable material/shape differences beyond recoloring, and
visible exterior rival fragments in the enlarged stills. Ordinary gameplay at
normal size, temporal behavior, physical admission, save compatibility and
performance remain separate acceptance areas.

## Normal gameplay readability supplement

The reviewer inspected the encoded `item`, `rival`, `rival-late` and `after`
frames for both Cookie Bite and Rope Coil, plus their saved media/gameplay
receipts in `artifacts/common-gameplay-20261007/`. Each video is 40.000 seconds,
540 by 1174, 30 encoded frames per second and 1,200 encoded frames. The receipt's
2,400 simulation frames are not the encoded frame count. Both runs report
23 objects, one rival, score 0 to 36 and zero deaths in the ordinary Sunny City
scene. These are muted Mac captures using scripted normal controls and a fixed
simulation timestep, not a measurement of phone performance.

Cookie's bite shape and chocolate chunks remain identifiable at normal LVL1/2
size. Rope retains a visibly twisted border, knot and loose end, although its
bright strands become less distinct where the existing building-cutaway dither
overlays the scene. Both mouths remain readable. Rival fragments are visible
outside each rim in the sampled response frames and clear in the after frame.
The samples are consistent with one brief response; four stills per run cannot
establish that no replay occurs anywhere in the complete video. The event
receipts record one rival and a single corresponding reward progression.

No new appearance blocker was found. The normal orange boost ring and the
LVL/name/progress labels dominate these small Common effects, so the feedback
should be described as modest rather than spectacular. These two samples cover
the chunk and thread families; they are not a visual gameplay test of every
skin, every effect family or every device.

Media identifiers recorded in the inspected receipts:

- `Cookie_Bite-full-gameplay.mp4`: SHA-256
  `92b6d7aaceefc02aae58d6e1bec0dc47b6a07b6849c293453d3e0e2ebeca310a`.
- `Rope_Coil-full-gameplay.mp4`: SHA-256
  `c2e42fe28c2154ddd2e33bd87cff5f8e9a9c859589cb066685126646296a9bc0`.
