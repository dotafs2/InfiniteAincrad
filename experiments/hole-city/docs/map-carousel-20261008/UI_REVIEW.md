# Map carousel UI review

Reviewer: independent visual/UI reviewer (`glacier_art_review`).
Date: 2026-10-08.
Implementation ownership: root. This reviewer reads source and actual images;
only this review document is edited. No engine jobs are run by this reviewer.

## Initial direction

Replace the split home selector and separate vertical chooser with one horizontal
row of large screenshot cards on HOME. This addresses the existing mismatch in
which only three maps have direct home buttons while the fourth is hidden behind
MORE MAPS. Keep HOME, STORE and HOLES in their established bottom order.

Source reviewed: `fidelity/ui.gd`, `fidelity/viewport_layout.gd`, and
`fidelity/map_catalog.gd`. The current responsive canvas preserves width and
uses extra safe height on tall phones; the new carousel should retain that
behavior rather than centering a fixed-height sheet.

## Recommended hierarchy

1. Compact wallet and settings near the safe top.
2. A restrained game heading or world-selection heading; the screenshot should
   receive more area than the current large HOLE FEAST title and miniature.
3. One dominant centered screenshot card, with a visible edge of the adjacent
   card. Around 440–448 units of width and 16–20 units of gap on the existing
   540-unit canvas should provide a useful adjacent peek.
4. World name and one short state line. An unlocked map may show duration/best;
   a locked map must show the real prerequisite and current progress. Do not
   display rule paragraphs.
5. Small position indicators followed by one clearly dominant PLAY or LOCKED
   button, above the persistent dock.

Use all four authored maps in progression order. If the two future catalog
entries are retained, label them COMING SOON and keep them outside available
world counts and progression completion. They must not use fictitious gameplay
screenshots. Showing only the four actual worlds is the clearest first release.

## Screenshot requirements

- Capture actual current maps, not the miniature scene or an illustrated
  replacement. Use consistent framing and deliberate aspect-ratio crops.
- Sunny City should contain recognizable streets and substantial buildings.
- Snack Garden should show appetizing food scale and a distinctive arrangement;
  Sushi Express is valuable if it remains readable in the crop.
- Bubble Toy Town should show the authored castle/block silhouettes and varied
  height, not only tiny decorative props.
- Frostlight Village should show the revised broad ice, a ridge/floe contrast,
  and a readable Arctic-life or expedition cue when the crop permits.
- Avoid large captured HUD text beneath live UI labels. Do not stretch screenshots
  vertically when safe height expands. Locked cards should remain attractive
  and recognizable; use a small lock/status treatment rather than flattening
  the entire image into near-black or gray.

## Interaction and layout pitfalls

| Risk | Required behavior |
| --- | --- |
| Browse position differs from the stored selected map | The focused card and primary action must agree. PLAY must never silently launch the previous map while a different or locked card is centered. |
| Drag release activates a card or PLAY | Apply a clear drag threshold and cancel tap activation after a swipe. A canceled touch or viewport resize also cancels the gesture. |
| Endless wrapping hides progression order | Clamp at first/last card. Keep order stable and settle to one focused card after dragging. |
| Only a disabled LOCKED button explains nothing | Show one concrete prerequisite/progress line matching the actual progression rules. Distinguish progression locks from COMING SOON. |
| Preview reveals a map that cannot actually be played | Keep availability, progress locks, selection and launch checks consistent. Preserve existing saves/earned access according to the agreed migration. |
| Tall phones stretch the photo or leave UI in the middle | Anchor wallet to safe top and dock to safe bottom. Let available middle space grow around the screenshot while preserving its crop/aspect. |
| Tiny dots/arrows become mandatory controls | Swiping and tapping a large card remain primary. If arrows are interactive, keep their touch targets at least 64 design units (about 44 points at 375-point width). |
| Selection UI keeps rendering hidden 3D miniatures | Static screenshot cards should not require four continuously updating SubViewports. Disable/remove the old home miniature while it is hidden. |

## Acceptance evidence requested

1. Actual full HOME frames at a short phone layout and a tall phone layout,
   including safe insets, selected first and last cards, a locked state, and
   an all-unlocked/legacy state.
2. All four actual thumbnails at native resolution and in their final card crop.
3. A swipe sequence or browser interaction receipt confirming that drag changes
   the focused card, tap selects the intended card, end bounds work, and a locked
   map cannot launch through the main action.
4. No separate MORE MAPS vertical chooser in the normal flow, no clipped world
   titles/progress, no overlap with wallet or bottom navigation, and no old
   three-map shortcuts competing with the carousel.

## Current verdict

Layout direction accepted for implementation. Actual screenshot and UI review
is pending; no visual acceptance is claimed before those images are inspected.

## Thumbnail set 02: accepted

Inspected the four actual GPU captures under
`artifacts/map-carousel-20261008/thumbnails-02/`: `city.png`, `food.png`,
`toys.png` and `frost.png`. They are full playable scenes captured with a
composition camera and hidden HUD, rather than concepts or miniature models.

| Map | Visual result |
| --- | --- |
| Sunny City | Roads, varied building blocks and traffic make the theme immediately identifiable. The central rows provide a clear crop anchor. |
| Snack Garden | Bright stacked food, large pink-topped pieces and burger-like layers distinguish the world. It is the busiest image; preserve the central large food forms in the card crop and do not zoom out further. |
| Bubble Toy Town | Large castle silhouettes and colored roofs are immediately recognizable. The crop retains differences in height and supporting smaller structures. |
| Frostlight Village | Broad ice, ridges, low calved floes and a nearby penguin group match the revised world. The arena edge is visible but is acceptable in an actual gameplay-scene screenshot. |

No additional capture is required for these four source images. The final
436-unit-wide card crop still needs review, especially if its height changes
on tall phones. Preserve central landmarks with aspect-preserving cropping;
do not stretch these images. There is no claim that a barely visible train or
small character is a readable thumbnail feature. Final assembled UI review
remains pending.

## Assembled carousel render 01: layout accepted, two final checks pending

Inspected the following actual GPU frames in
`artifacts/map-carousel-20261008/render-01/`:

- `fresh-city-tall.png`, `locked-food-tall.png`, `toy-progress-tall.png`
- `unlocked-city-tall.png`, `unlocked-food-tall.png`,
  `unlocked-toys-tall.png`, `unlocked-frost-tall.png`
- `layout-375-city.png`, `layout-375-frost.png`

The hierarchy now works: screenshot first, readable world title and state,
one primary launch action, and a distinct persistent dock. Adjacent cards peek
far enough to communicate horizontal browsing, with arrows and position dots
providing additional orientation. The long Toy Town and Frostlight names fit
without clipping. The aspect-preserving crops keep all four worlds identifiable
at both reviewed sizes.

The locked-state instruction is concise and concrete: finish Sunny City or
reach the stated Snack Garden score, with a visible numerical progress bar.
Unlocked and locked states are visually distinct. No extra vertical map chooser
or old three-map shortcut row remains visible in these frames.

The short 375-point layout retains the primary action and dock without overlap.
Secondary metadata is small but readable; it should not be reduced further.
The tall layout uses the available height for a larger image instead of leaving
the interface compressed in the middle.

One known visual defect remains in the supplied locked-state frames: the
disabled LOCKED action retains a play triangle. Root has already identified
this and is replacing it with a lock. Confirm the corrected pixels, and inspect
the forthcoming 440 by 956 safe-inset capture before final acceptance. Do not
use the macOS-clamped `layout-1320` captures as physical-device viewport proof.

Root reports 503 interaction/layout checks including true swipes and locked-map
launch guards. This reviewer did not run those checks; visual inspection here
does not substitute for their independent functional evidence.

## Final visual verdict: accepted

Inspected these actual GPU images under
`artifacts/map-carousel-20261008/render-02/`:

- `locked-food-tall.png`
- `safe-insets-frost.png`
- `layout-440-city.png`
- `layout-440-frost.png`

The locked primary action now shows a lock rather than a play triangle. Its
disabled styling and the prerequisite/progress line agree. The selected card
remains recognizable and attractive while unavailable.

The safe-inset fixture reserves sufficient room above wallet/settings and below
the dock controls. Screenshot cropping, the long Frostlight title, primary
action and adjacent-card peek all remain clear. The background continues under
the safe-area margins, so the reserved control space does not become an
unrelated black border.

This fixture renders at 440 by 956 desktop pixels and applies the supplied
iPhone 16 Pro Max safe rectangle `(0, 186, 1320, 2580)` in a 1320 by 2868 pixel
screen. It is a desktop layout simulation, not a screenshot or interaction test
from a physical phone.

| Visual requirement | Result |
| --- | --- |
| One coherent horizontal map selector on HOME | Pass |
| Four recognizable actual-map screenshots | Pass |
| Visible adjacent cards and first/last orientation | Pass |
| Long names, state and unlock progress fit | Pass |
| One unambiguous PLAY or LOCKED primary action | Pass |
| Short/tall layouts and safe-area separation | Pass in the reviewed desktop fixtures |
| Persistent HOME / STORE / HOLES navigation | Pass |

No further visual change is required. Root reports 554 GPU/interaction checks
after the final fix, including selection and launch guards; these are separate
functional evidence. Real phone gestures, screen brightness and physical-device
performance remain unmeasured by this review.
