# Diamond economy interface

The current source revision follows the user's request for a simpler interface
and a full-height iPhone portrait layout. Earlier 0.12.4 gate, GPU frames, native
build16 and partial Store Review V2 captures remain historical evidence. They do
not verify these subsequent changes. No current screenshot upload is claimed.

## Primary flow

Home shows the two wallet balances, two playable map cards, one primary Play
button and three navigation tabs. Audio, haptics, privacy and support remain
available through Settings. The duplicate dock Play button, home audio toggles
and persistent coin-formula footer are removed. Skin Rates remains a secondary
entry in the unified 44-skin collection.

The result shows points, actual earned coins and two compact offer cards:
**1.5× Coins** and **+30 Seconds**. Each eligible card has a Video button and its
diamond price. The coin boost costs one diamond; continuation costs five.
One coin boost and one continuation are independent, available at most once in
the same run. Consumed or ineligible offers disappear. There are no explanatory
economy paragraphs in the result, and no new 2× coin offer.

The 1.5× boost adds the rounded-down half of the actual base coin receipt. If the
player later extends the run, settlement pays only incremental base and boost
coins. The finish bonus is not granted again. Sunny City starts at 90 seconds;
Snack Garden starts at 60. The extra period is 30 seconds in the existing world.

Unavailable Video buttons say **Not Ready** and are disabled. While any rewarded
video is pending, both offer groups, Play Again, Home and store transactions are
disabled. A short pending message and the actual button tooltip retain the
completion-and-dismissal requirement. Neither merely opening an ad nor closing
an unfinished video earns a reward; timer continuation and coin boost wait for
the accepted earned event and actual dismissal. Google determines ad duration;
no 15-second promise is made.

## Wallet and store

Visible currency uses **Diamonds** while existing saves retain the `gems` field
and balances. The optional video grants 3 diamonds, with a persisted 120-second
earned-video cooldown. It is not a free gift per stage. Exchanges cost 50 / 250 /
1,000 diamonds for 250 / 1,500 / 7,000 coins. Unaffordable exchanges are disabled.
The three purchase offers contain 60 / 360 / 1,800 diamonds. Prices come only from
StoreKit metadata; missing providers/products show **Unavailable** and disable
purchases. No invented dollar price, entitlement or completed transaction is
presented. A bounded 250 ms poll updates availability and cooldown state.

## Portrait layout

The safe-area contract returns a 540-unit width, uniform scale, a top origin
inside the safe area and the full available safe canvas height. Status controls
stay near the top, navigation and Boost stay near the bottom, and the middle
opens into additional height. Drawn panels and their touch targets use the same
responsive mapping; fonts and icon shapes retain uniform scale. A 500 ms safe-area
poll handles inset changes that do not emit a viewport-size event.

The collection's clipped window expands with portrait height, while individual
skin cards retain their 144×106 preview footprint. Only intersecting rows own
preview resources, and only the selected visible model animates. Pointer and
wheel routing use the actual expanded window, not the old 960-unit boundary.

## Acceptance scope

The owned `review_ui_collection.gd` and `retention_ui_review.gd` fixtures exercise
actual touch routing, cold wallet restore, tall-portrait anchors, secondary
settings, independent one-time offers and earned-before-closed ordering through
an explicit controlled provider. They observe the real forwarded draw calls.
These updated fixtures are authored but have not been run for this revision.
Root owns sequential focused tests, current Mac GPU review and the changed full
gate. They do not establish physical-phone sensation, production ad playback,
StoreKit purchase acceptance or Apple upload readiness.

## Layout-change review repairs

A layout-only refresh retains the existing Privacy/Support overlay and its
reading position. Other menu/phase refreshes keep the normal close behavior.
A changed fit cancels the current collection pointer and old-transform inertia
before rebuilding controls. The Coming Soon star polygons now receive one
responsive center conversion, matching their actual map-card touch rectangle.

The owned fixtures add real Privacy wheel input followed by a viewport resize,
a real collection drag/flick interrupted by a resize and release, and forwarded
actual star polygons checked inside their responsive touch card on tall screens.
The collection fixture also uses the current Home-to-Play route and explicit
Vector2 types for its pointer coordinates. These newly saved edits require
fresh focused release-info, collection and retention-UI runs; earlier reports
remain previous-source provenance. No engine was run by this worker.

The local release information updates only factual reward and navigation copy:
independent one-time 1.5x coins for one diamond or an earned-and-dismissed video,
and 30 seconds for five diamonds or such a video. Settings and pause keep audio
and haptics; Settings opens Privacy and Support. Data-processing disclosures
remain unchanged.
