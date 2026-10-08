# Skin case opening: design and visual review

Reviewer: independent UI/art reviewer (`glacier_art_review`).
Date: 2026-10-08.
Scope: design and review. Root owns runtime implementation and reference research.
This reviewer also authored the explicitly delegated isolated acceptance script
`tests/skin_case_ui_acceptance.gd`; no engine, account, asset or runtime-source
changes are performed here.

## Existing behavior audited

Read `fidelity/ui.gd`, `fidelity/skin_draw.gd`, `fidelity/skin_rarity.gd`, and the
skin offer/unlock functions in `fidelity/game.gd`. Inspected actual collection
captures for Cookie Bite, Phoenix Nest and Aurora Rift in
`artifacts/skin-production-200-20261007/`.

The current button already purchases a random unowned skin. A tier is chosen
first, then an eligible skin in that tier. Empty tiers and active guarantees
change the disclosed odds; the guarantees are Epic+ within five draws,
Legendary+ within ten, and Prismatic within twenty while eligible skins remain.
The transaction is saved before success is returned, and failed saving refunds
the spend. Presentation currently consists of scrolling to the new skin and a
one-second pulse.

Two integration details need attention:

- The odds page still says `ALL 44 SKINS`; use the live catalog count of 200.
- Acquisition currently equips the awarded skin immediately. A new result screen
  must either say EQUIPPED, or deliberately change that behavior so EQUIP is a
  real optional action. It must not pretend an already equipped skin is awaiting
  equip.

## Recommended product structure

Keep one case using the existing 100-coin draw and the same eligible collection.
Do not imply six separate case prices or new pools merely to represent rarity.
The six categories organize the contents and communicate odds; they are not
unimplemented purchase modes.

From HOLES, replace the abrupt random-unlock action with a clear OPEN CASE
entry. A dedicated case surface can use CASE / COLLECTION tabs, or a BACK TO
COLLECTION action, but avoid adding a new bottom navigation destination. Keep
the existing HOME / STORE / HOLES order. STORE remains the currency shop; any
case shortcut there must lead to the same case and price.

## Portrait hierarchy

1. Compact BACK and coin balance at the safe top; ODDS remains an obvious,
   reachable secondary action before spending.
2. `SKIN CASE` title and one short line such as `A new skin every time` when that
   promise matches the eligible pool. Show collection progress unobtrusively.
3. A generous central case/reel area, using the game's own rounded style. The
   visual language may borrow the idea of a horizontal reward reel without
   copying Counter-Strike branding, icons, crate art or sounds.
4. A concise contents treatment: six labeled rarity categories or a content
   preview that can be browsed. Do not squeeze 200 cards, six large explanations
   and the reel onto one screen at once.
5. One prominent `OPEN · 100` coin action near the safe bottom, above the dock.
   Insufficient balance shows the exact shortfall and a clear optional route to
   the existing STORE; never initiate an exchange or purchase automatically.

The reel can occupy roughly 492 design units in width, showing about three
144-unit skin cells and partial neighbors. A fixed center marker must remain
visually distinct from all rarity colors. Keep title/cost outside the moving
region so motion does not obscure what was purchased.

## Reel and reveal behavior

- Use actual skin imagery from the authored models, with each cell showing the
  correct palette variant, concise name and rarity strip. Generic question
  marks or flat color discs are insufficient for the existing collection.
- Start quickly, decelerate smoothly, and stop with the real awarded item
  centered under the marker. Approximately 4–4.5 seconds is enough for a first
  opening; provide SKIP so repeated openings are not compulsory waits.
- Commit exactly one draw before starting presentation. The displayed winner,
  receipt, owned inventory and coin deduction must be the same transaction.
  Skip, navigation, pause or focus loss cannot reroll, double-charge or lose it.
- Neighboring reel cells are presentation, not an undisclosed second lottery.
  Avoid deliberately arranging high-rarity near misses around a common winner
  or implying that repeated taps influence the stop.
- One purchase input starts one opening. During motion suppress another OPEN
  action, ignore repeated taps and retain a safe exit/skip path.
- After the stop, replace the moving strip with one large actual skin preview,
  rarity, full name/palette and a short success label. Show EQUIP only if it
  changes the selection; otherwise show EQUIPPED and CONTINUE. OPEN ANOTHER can
  be secondary with its real cost visible.
- The completed collection shows a clear COLLECTION COMPLETE state with no
  spend action. Failure to save or insufficient funds must not start a success
  animation.

## Rarity hierarchy

Retain the existing Common gray, Uncommon green, Rare blue, Epic violet,
Legendary orange/gold and Prismatic pink/rainbow identities. Use both readable
names and color; the strip alone is not enough. Light gray, green and gold
need dark text or another tested high-contrast treatment rather than relying on
thin white lettering.

Reel cells should share a calm neutral background so the actual skin colors
remain identifiable. Let borders/strips carry rarity. The result may use a
restrained tier-colored glow: Common still receives a complete, pleasant reveal;
higher tiers may add a slightly richer accent without a screen-filling flash.
Long base names and palette names must fit as two lines where necessary.

The ODDS view must expose current tier chances, eligible skins per tier and
per-skin chance, with the actual guarantee state. Use the offer shown for the
pending purchase; do not present static base weights as the current guaranteed
draw odds. Category browsing must not silently change those odds.

## Original sound direction

Use a small original audio set: soft case opening, restrained tick, short reveal
accent. Tick timing follows visible cell crossings but is rate-limited so the
fast section does not become a harsh buzz. The rhythm slows with the reel.
Rarity accents can become a little richer, with bounded loudness and no copied
game samples. Avoid a long casino-style fanfare.

Honor the existing SOUND preference and output level. Skipping cancels the
remaining tick sequence and plays at most the one appropriate reveal cue when
sound is enabled. Focus loss, pause, failed purchase and repeat input must not
leave orphaned sounds. Preview captures can remain muted; a separate audio file
or recorded sound evidence should verify the authored cues without surprising
the user with desktop playback.

## Performance and accessibility

Use cached images for the moving reel, not one continuously rendering 3D scene
per cell. Only the selected/result skin needs a live animated preview. Release
or suspend preview resources when leaving the case screen. Respect the established
short/tall responsive canvas and safe-area transform.

Interactive controls should keep at least the existing 64 design-unit touch
target where they are primary. The center marker, result name and status should
remain readable without sound or color. SKIP provides a short path through the
motion; keyboard/back navigation and touch cancellation must not cause another
draw.

## Acceptance checklist for actual review

- [x] Ready case, insufficient funds and completed collection states inspected.
- [x] Actual opening frames show distinct correct skin/palette images, legible
  rarity, clipped reel bounds and a fixed marker.
- [x] A continuous clip was sampled at bounded timestamps and cross-checked
  against its actual capture timeline, establishing progression, deceleration,
  final centering and transition. This is not a full-speed playback review.
- [x] Common and at least one high-tier result inspected, including a long
  variant name and one animated weather/aurora model.
- [x] Opening cost, odds access, current catalog count and guarantee text agree
  with the actual acquisition rules.
- [x] Result action matches actual equip semantics and owned inventory.
- [x] Short phone, tall phone and labeled safe-area fixture show no overlap or
  clipping; future desktop fixtures are not called physical phone tests.
- [x] Repeated tap, skip, navigation/focus loss and save-failure behavior have
  separate functional receipts confirming one transaction and no lost award.
- [ ] Original sounds are bounded, synchronized and suppressed when SOUND is
  off; no uncontrolled stream of ticks on a skipped animation.
- [ ] Existing 200 skins, saved ownership, map unlocks and currency economy are
  preserved unless the user explicitly changes those rules.

## Current verdict

Design direction accepted for implementation. Actual GPU visuals, motion and
sound evidence are pending; no final UI approval is claimed yet.

## First implemented GPU review

Inspected the actual 540 × 1174 Godot images under
`artifacts/case-opening-20261008/capture-01/`: `ready-tall.png`,
`rolling-tall.png`, `result-tall.png`, and `odds-tall.png`.

The implemented direction is visually adequate in these tall-screen states.
The dedicated dark case surface, fixed gold marker, clipped neighboring cards,
actual skin imagery and separate full result form a clear hierarchy. Fox Den's
orange ears and white face remain recognizable against the calm result panel;
the rarity label and explicit EQUIP action are distinct. The six category labels
are readable and the 100-coin primary action is easy to identify. BACK and ODDS
remain available without competing with the primary action. The original
collection dock need not be duplicated inside this dedicated surface because
the return route is obvious.

The odds page now reports the live 200-skin collection, current remaining counts
and guarantee state. Its brighter background differs from the dark opening
surface, but this is not a blocking inconsistency with the established game UI.
There is no clipping or substantive contrast issue in these supplied frames.

This is a provisional visual pass for the supplied states, not final approval.
Static images cannot establish deceleration, exact stop timing, tick rhythm or
skip audio. The continuous movie's recorded dimensions need to match the intended
portrait canvas. Final review still requires actual Common and Prismatic result
images, short-screen and labeled safe-area fixtures, and the separate functional
acceptance receipts. No real-device or audio-listening claim is made here.

## Expanded UI review and isolated acceptance

Inspected `artifacts/case-opening-20261008/ui-02/` captures for Common Plain Loop,
Prismatic Aurora Rift · Solar Rift, ready/result at 375 × 667, the labeled
440 × 956 safe-inset fixture, insufficient balance and completed collection.
The Common reward retains a clean bright rim and a complete reveal treatment.
The Prismatic reward shows the real arcs and floating accents rather than a
generic high-tier badge; its full variant name fits. Both keep EQUIP and CONTINUE
separate and readable. At 375 × 667 the compact ready hierarchy, reel names,
rarity categories and main action remain usable. The safe-inset captures leave
the expected top and bottom breathing room without compressing the preview.
No overlapping controls, cropped result name or substantive visual blocker was
found in these states.

The `ui-02/report.json` GPU receipt records 589 checks and zero failures, covering
actual pointer actions, committed-award restoration, explicit equip, skip,
duplicate callbacks, focus loss, failed-save rollback and suspended previews.
The single-item Common/Prismatic screenshots use disclosed isolated eligible
pools; they are not evidence of naturally rolled rare rewards. These are Mac
GPU renders and a desktop safe-area fixture, not physical iPhone validation.

One presentation refinement was necessary: the earlier ready/shortfall/sold-out
frames used generic example cards even when those cards were already owned.
Root has changed ready examples to eligible unowned skins only, centers the sole
remaining reward, and clears the completed-collection reel. Targeted assertions
for all three behaviors have been added to the assigned acceptance script; the
final root run will verify them. That change does not require new map or skin art.

Verdict: static layout and reward-model presentation approved, subject to the
final eligible-preview capture and continuous animation review. No further UI
redesign is requested. Motion and sound approval remain separate evidence.

## Final UI and sampled-animation verdict

**Approved for this implementation's UI/art scope.** No blocking visual change
is requested. The final `ui-03/report.json` records **641 checks, zero failures**
on the macOS display server. The revised ready safe-inset image shows only the
remaining Aurora Rift variant centered under the marker; the shortfall image
shows only the eligible Plain Loop; the completed collection has a blank reel
and disabled COLLECTION COMPLETE action. These resolve the misleading generic
examples noted above. All earlier result and responsive-layout findings remain
valid.

Reviewed `capture-03/case-opening.mp4` through ten bounded frame extractions at
0.5, 1.2, 2.0, 3.0, 4.0, 4.7, 4.95, 5.1, 5.3 and 6.0 seconds, cross-checked with
`tools/capture_skin_case.gd` and the existing functional stop-position checks.
The clip is an actual Godot recording: H.264, 540 × 960, 60 fps, 565 frames,
9.416667 seconds, with a 48 kHz stereo AAC audio stream. No aspect or lower-screen
crop issue appears in the extracted frames.

The frame at 0.5 seconds shows the free ready state with 1000 coins. Opening
frames show 900 coins and SKIP while the cards progress under a stationary gold
marker. Fox Den approaches the center by 4.0 seconds and is centered in the
4.7/4.95-second samples, consistent with the implemented deceleration. By 5.1
seconds the same Fox Den becomes the large Rare result with EQUIP SKIN. At 6.0
seconds it says EQUIPPED following the separate equip call in the capture
timeline. Thus the recording supports one spend, a coherent reel-to-result
transition and a distinct equip step; exact receipt/center semantics are also
covered by the functional UI acceptance rather than inferred from pixels alone.

Review limits: these are sampled frames from a continuous clip, not human
full-speed playback or an audible listening test. Audio-stream metadata confirms
the recording contains audio but does not establish its subjective quality.
The separate audio acceptance owns those functional checks. No iPhone frame-rate,
real account, native install or production purchase claim is made. The root's
complete regression gate and final package evidence remain outside this review.

## Reopened interaction guard review

Root identified a further interaction boundary after the visual approval:
CONTINUE overlaps the next ready state's OPEN action. A quick second tap after
a long opening could therefore initiate another purchase. The previous duplicate
input checks covered rolling and pending results, but did not cover this new
ready-state transition. This reopens functional acceptance for that boundary;
the approved visual hierarchy does not require redesign.

Root added an 800 ms acquisition guard after successful receipt acknowledgement,
with OPEN disabled during that interval. The assigned UI test now records the
actual CONTINUE global center, acknowledges the result, repeats a real pointer
tap at that same position, and calls OPEN directly. Both paths must retain the
acknowledged ready state, wallet, inventory and receipt. After an isolated 820 ms
wall-clock wait and a UI process update, OPEN must become enabled without any
automatic spend. Existing subsequent single-item fixtures still exercise normal
new purchases and explicitly reset their isolated acquisition clock.

The fresh `artifacts/case-opening-20261008/ui-04/report.json` GPU receipt records
**647 checks, zero failures**, including the repeated CONTINUE-position pointer,
direct OPEN callback, disabled state and 820 ms re-enable assertions. The
acknowledgement-transition boundary is therefore resolved by the tested guard.
The earlier 641-check receipt remains historical evidence and does not cover
that guard.

**Final verdict: UI/art and the focused interaction acceptance are approved.**
No further visual or interaction change is requested by this reviewer. The
refreshed `capture-04` movie and root's final complete package gate are separate
deliverables; this update does not claim to have reviewed an unfinished clip or
to have completed that gate. No engine or runtime source was changed by this
reviewer.
