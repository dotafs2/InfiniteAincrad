# Independent 200-skin art review

Final status: **qualified visual pass** for the repaired 200-entry catalog and
final delivery sheets. Model, palette and caption findings below were repaired
and reinspected. Representative normal gameplay passes with the stated HUD and
small-effect limitations; this is not native phone performance certification.

Reviewed October 7, 2026. This document separates the proposed grading contract
from acceptance of actual rendered assets. The reviewer owns this document only
and does not implement the production geometry or run the engine.

## Scope and current verdict

The latest user explicitly permits color variants, including simple recolors in
the lowest tier, and asks for exactly 200 playable catalog entries. This
supersedes the earlier prohibition on recolor-only Common skins. Do not describe
200 catalog entries as 200 independently modeled base shapes.

The proposed allocation is internally consistent:

| Tier | Final target | Existing after proposed regrade | Additions required |
| --- | ---: | ---: | ---: |
| Common | 40 | 9 | 31 |
| Uncommon | 60 | 19 | 41 |
| Rare | 48 | 12 | 36 |
| Epic | 28 | 12 | 16 |
| Legendary | 16 | 5 | 11 |
| Prismatic | 8 | 3 | 5 |
| Total | 200 | 60 | 140 |

**Initial verdict: proposed allocation and broad regrading are reasonable;
new entries are not yet visually accepted.** Existing actual Common GPU and
gameplay evidence was reviewed in the preceding batch. The six older polished
assets were checked against the saved exported-mesh comparison. Source review
covers the other legacy motifs and controller paths; it is not a substitute for
their fresh game renders.

## Grade contract

- **Common:** a clean basic ring, trim or restrained material variation is now
  allowed. Distinguish variants by a readily visible body/accent combination.
  Keep a short visible rival response and a clear mouth. Slate Ring may remain
  a more sculpted starter exception.
- **Uncommon:** the existing nineteen authored everyday forms establish the
  floor: recognizable outline, deliberate material regions and a brief themed
  response. Recolors may share these forms without inventing new geometry.
- **Rare:** retain an immediately identifiable character, food or object motif
  with several coordinated large features. A colored basic ring with one tiny
  decoration does not meet the floor. Recolors remain in the same art grade.
- **Epic:** require a coherent multipart silhouette or a visible themed reactive
  action beyond the Rare floor. More tiny pieces and the badge alone do not
  justify this grade. Preserve the legacy functional skins' existing behavior.
- **Legendary:** recognizable animated surface/material identity should remain
  visible at normal player size. Core Shell, Tide and Cinder provide useful
  anchors. Prism Vale and Rainbow Bridge fit here more naturally than alongside
  the stronger weather skins in the highest tier.
- **Prismatic:** use Orbit/Tempest/Rainfall as the current anchors: a clear
  layered silhouette with a coherent animated surface/volume, distinctive entry
  and rival feedback, and restrained visual cost. Merely changing an Epic body
  to a rainbow palette does not qualify.

The rarity badge color describes grade; it does not prescribe the object's body
palette. A blue object can be Common and a neutral object can be Prismatic.

## Existing grade risks

Moving eight simple-trim skins down to Common and nineteen newly modeled forms
up to Uncommon makes the ladder clearer. Keeping the original twelve Rare and
twelve Epic slots is provisionally acceptable, with these specific checks:

- Royal Gate, Carnival Tent and Satellite Dish use comparatively simple stock
  motifs. Their actual Epic render/response should be compared directly against
  the stronger Rare animals. If no visible premium behavior distinguishes them,
  improve that response or regrade the individual skin instead of relying on
  the tier name.
- The previous Common review accepted Mitt and Knit at a minimum stylized art
  level, below their concept illustration detail. Moving them to Uncommon does
  not retroactively make them detailed premium models.
- Royal Gate's metal/body color and Lantern's glow must retain dark structural
  separation; washed-out gold silhouettes can look flatter than a cheaper
  contrasting material.
- Body and rival feedback must survive the existing name/level labels, orange
  boost ring and building cutaway. Prior normal gameplay found these competing
  effects can dominate small skin details.

## Palette acceptance

1. Review siblings from the same base geometry side by side at collection-card
   size and normal gameplay size. Distinct hex strings alone are not evidence
   of a visible variant. Near-identical pinks or two washed-out creams should be
   merged or revised before filling the remaining count.
2. Change large material regions deliberately. Preserve mouth darkness and
   silhouette contrast; keep material logic such as light pith against citrus
   flesh, dark tread against a lighter tire sidewall, or a trim distinct from
   painted metal. Avoid uniformly tinting every region into one flat color.
3. Several neutral accents may be shared, but siblings should differ in the
   dominant body color, value pattern or meaningful region placement. Relying
   only on a tiny nose, stitch, gem or particle accent is insufficient.
4. Use coherent families: citrus can span orange, lemon, lime and grapefruit;
   glazed containers can use cobalt/ivory, jade/cream and coral/navy; weather can
   use violet/amber, blue/pearl or teal/silver. These are palette examples, not
   permission to claim different geometry or a higher grade.
5. Extremely dark materials need enough edge light to remain readable on a
   shadowed street. White/pale skins need a stronger edge or contrasting accent
   against snow, pale pavement and the collection background. Keep highlights
   below a fully white flattened patch.
6. Theme the burst colors to the visible skin. Review a rival frame next to its
   idle sibling, especially where the legacy controller hardcodes colors.

## Variant implementation risks to verify in the render

At initial inspection `common_geometry.gd` caches recipes by `skin_id` and uses
literal material colors. `common_skin.gd` also overrides several effect colors
by canonical ID. Catalog tint/accent changes alone therefore cannot establish
that a variant changes the rendered model. Use a stable canonical geometry
relationship with independent variant material state; verify siblings do not
recolor one another through shared materials. Keep prior IDs and owned skins
resolvable after regrading.

Render the complete 200-entry catalog in a stable ID order, with tier and family
labels on review contact sheets. Preserve individual full-resolution frames for
borderline cases. Record the exact source/render set being reviewed. A successful
count or test receipt does not replace inspection of the actual model image.

## Pending final review

- All 200 actual idle/rival appearances and sibling palette separation.
- The eight newly authored form families, including visible mouth continuity.
- Collection ordering, grade presentation and representative gameplay effects.
- Explicit final distinction between catalog entries, base geometries and color
  variants; no claim of native phone performance without device evidence.

## First complete actual render review

All 200 idle renders were inspected through the six tier sheets in
`artifacts/skin-production-200-20261007/`, plus the enlarged eight-new-family
sheet. The reviewer also inspected the full-resolution rival images for Royal
Gate, Satellite Dish, Carnival Tent, Aurora Rift, Phoenix Nest and Pocket Arcade.
These isolated rival callbacks are deliberately triggered render tests, not
ordinary gameplay. Exact inspected sheet/image hashes and per-ID review coverage
are saved locally in `build/skin-production-200-20261007/art-review-capture01.json`.

**Verdict: changes requested before final visual approval.**

Concrete corrections sent to the root:

1. **Snow Owl visibility:** the near-white Owl Hollow variant loses almost its
   entire body rim and both ear tufts on the light background, leaving floating
   eyes and a mouth. Darken an appropriate structural region or add contrast.
2. **Common near duplicates across nominal families:** Golden Berry is very
   close to original Clockwork Key; Dark Rye, Cocoa Icing and Cocoa Waffle are
   similar brown/cream thin rings; Steel Blue and Midnight Shell are similar
   blue/gray thin rings. Several nominal families share the same basic geometry,
   so checking only siblings is insufficient. Revise new variants while keeping
   the original bases intact.
3. **Review presentation:** long base/variant names overlap the next cell in the
   contact sheets. Split the base name and variant onto separate lines and fit
   each within its own cell.
4. **New-family mouth join:** a thin pale gap is visible along parts of the inner
   wall, notably Aurora Rift. The root is already correcting preview mouth
   coverage. Do not change physical admission to conceal a cosmetic gap.

Grade qualifications:

- Royal Gate, Carnival Tent and Satellite Dish show themed rival fragments, but
  their unlit geometry still reads as flat cutouts compared with Pocket Arcade.
  The short burst alone does not close that art-quality gap. Recommend readable
  lit depth on their existing closed geometry, or Rare placement. More polygons
  are not required merely to fix the material presentation.
- Phoenix Nest's bird, feathers and wings are legible and cute; its static form
  is restrained for Legendary. Confirm its visible wing/feather motion in a short
  actual sample before accepting the grade on animation grounds.
- Aurora Rift's layered arcs/gems and Pocket Arcade's cabinet, joystick and
  angular rival fragments read clearly. Clockwork Orbit and Crystal Crown have
  distinct multi-part silhouettes. Plain Loop and Button Wheel fit their lower
  grades. No further new-family silhouette blocker was found.
- Other within-family palettes are distinguishable in the sheets. Pale Shell
  and Enamel variants have subtler differences than the stronger Cookie, Denim,
  Tire, fire, water and weather variants; this is a quality limitation rather
  than an additional blocking request.

## Repaired render set and final art decision

The reviewer reinspected all six rebuilt tier sheets from `renders-02`, covering
all 200 entries, and the changed full-resolution images. The Snow Owl now has a
visible blue-gray rim and ears. Revised Common palettes separate the flagged
color clusters through olive, deeper cocoa/berry, more saturated blue and a
purple/green contrast, while original bases remain recognizable. Palette
variants are still permitted simple variants, not new modeled silhouettes.

Royal Gate's rounded band and points now show actual lit depth. Carnival Tent's
panel thickness and Satellite Dish's receiver/panel depth are also visible.
They may remain the simpler end of Epic; Pocket Arcade is a stronger visual
anchor for that grade. The corrected Aurora Rift and Pocket Arcade images have
continuous black mouth joins without the former pale inner gap.

The Phoenix motion source frames at 2.0, 5.0 and 5.2 seconds show changing
shoulder-wing poses and a themed outward feather response. This supports a
restrained toy-like Legendary classification. It does not make Phoenix an
elaborate flame/weather effect comparable to the animated shader skins. The
isolated motion demo deliberately invokes object/rival callbacks and is not
evidence of actual swallowing gameplay.

**Final production-art decision: qualified pass for the 200-entry collection.**
There is no remaining blocking model/palette finding in the inspected set. This
is acceptance of a mixed collection with deliberately simple Common recolors,
more structured object/character skins and a smaller premium-effect group. It
does not claim 200 unique modeled base shapes, uniform detail across a grade,
concept-illustration fidelity or native phone performance.

One delivery-only issue remains at this review cutoff: the rebuilt Epic,
Legendary and Prismatic sheets omit their variant subtitle line, displaying the
base name twice for paired colors. Common, Uncommon and Rare sheets correctly
show both lines. The root has been notified to repair the larger-card caption
layout; the issue does not concern in-game skin identity.

## Representative normal-gameplay check

Source frames from the Phoenix Nest and Pocket Arcade 40-second Sunny City
captures were inspected at approximately 15.33, 15.67, 16.33 and 30 seconds. Both
saved receipts report 23 objects, one rival, score 0 to 36 and zero deaths, with
seven normal AI and scripted normal player controls. Those are fixed-simulation
Mac captures; the receipt's 2,400 steps must not be called 2,400 encoded frames.

Both forms remain identifiable at LVL3: Phoenix's bird/wings and Arcade's
cabinet/joystick silhouette survive the normal camera. Tiny themed fragments
appear around each rim after the rival event and are gone in the later sample.
There is no new duplicate response visible in these selected frames, which is
not exhaustive proof about every frame or every skin. At LVL2 the orange boost
ring, player text and building-cutaway dither dominate the finer details. That
existing readability limitation persists; do not market the sampled response as
a large cinematic effect. Only these two new families received this independent
normal-gameplay visual check, not all 200 entries.

### Delivery caption correction verified

The final Epic, Legendary and Prismatic sheets were reinspected after the
delivery-only repair. Base names and variant subtitles now appear on separate
readable lines, including Azure Flame, Silver Mechanism, Solar Core, Frost
Phoenix, Dawn Veil, Opal Bridge, Solar Rift and Cobalt Storm. The earlier missing
subtitle issue is resolved. The exact final sheet hashes and unchanged model
review coverage are saved in
`build/skin-production-200-20261007/art-review-final.json`; the previous receipts
preserve the rejected and intermediate evidence.

The capture catalog contains 200 entries, 68 named base families and 132 palette
variants. Several legacy Common families share the same basic ring geometry, so
68 named families must not be represented as 68 independently modeled shapes.
