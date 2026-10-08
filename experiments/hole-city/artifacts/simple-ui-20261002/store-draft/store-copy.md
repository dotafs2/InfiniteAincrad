# English (US) 0.12.5 listing draft

Draft only. Not saved to App Store Connect by this audit. Existing screenshot
and preview media are historical 0.12.3 assets. Partial 0.12.4 V2 capture is
also preserved and superseded; current 0.12.5 media still needs recapture.
Availability: United States. Download price: Free. Release option: Manual.

Name: Black Hole Feast: Eat & Grow

Subtitle: Swallow Cities & Tasty Treats

Keywords: food,world,collect,skins,physics,donut,cake,sushi,offline,relaxing,arcade

Promotional text:

Swallow towering food stacks, chase the Sushi Express, and grow through Sunny City. Two worlds, original skins, and one hungry black hole.

Description:

Guide a hungry black hole, swallow what fits, and grow into your next feast.
Start with little bites and work toward bigger targets in two colorful worlds.

FEAST ON TWO WORLDS
Snack Garden is an edible city of donuts, pancakes, burgers, cakes and sushi.
Work your way toward towering stacks and watch them tumble into your hole.
In Sunny City, devour street objects, vehicles and larger city targets as you grow.

CHASE THE SUSHI EXPRESS
Find the moving sushi train and swallow its separate cars when your hole is
large enough. Sunny City has its own City Tram to chase.

MAKE EVERY SECOND COUNT
Sunny City starts with 90 seconds. Snack Garden starts with 60 seconds.
When the timer ends, you can continue the same run once for 30 extra seconds
by spending five diamonds or watching an available optional rewarded video.
After a run, you can also boost your coin reward to 1.5x once using one diamond
or an available rewarded video; fractional coins are rounded down. The coin
boost and extra time are independent. A video reward requires completion and
dismissal; ad availability and video length are determined by the ad provider.

GROW AND BOOST
Score points, earn coins through ordinary play, compete with computer-controlled
rival holes, and use BOOST for a short burst of speed.

FIND YOUR LOOK
Browse 44 original hole skins in one scrolling collection, ordered from Common
to Prismatic. Skin unlocks use in-game coins, with current draw rates and
guarantees shown in the collection. Diamonds can be exchanged for coins or used
to extend a round. The iOS version offers optional diamond purchases and
rewarded videos when available; neither is required to play.

PLAY YOUR WAY
Adjust music, sound effects and haptics in Settings. Coins, diamonds, your
collection and preferences stay on your device. No sign-in or cloud account is required.

Support: https://black-hole-feast-support.dotafs.chatgpt.site/support.html
Privacy: https://black-hole-feast-support.dotafs.chatgpt.site/privacy.html

## Current review-note draft

No sign-in is required. Sunny City and Snack Garden are the two playable maps;
three additional map cards are labeled Coming Soon. Rival holes are
computer-controlled. Sunny City's base round is 90 seconds and Snack Garden's
is 60 seconds. Drag to move, and use the visible BOOST button when charged.

After a timed round, the game offers one continuation in the same world for
30 seconds. The player can spend five diamonds or watch an available optional
rewarded video. The game requires Google's accepted earned callback and ad
dismissal before resuming the timer. A second timeout does not offer another
continuation. Separately, a settled round with an eligible reward offers one
1.5x coin boost for one diamond or an available optional rewarded video. The
boost adds floor(base coins / 2) and is independent of the continuation. If the
player boosts first and then extends the run, settlement only adds the remaining
base and boost difference; the finish bonus is not granted again. Both video
rewards wait for the accepted earned event and actual dismissal. Merely opening
or closing an unfinished video earns no reward.

From HOME, STORE opens the wallet and diamond-to-coin exchanges. Its optional
diamond video awards three diamonds after accepted completion and has a
120-second earned-video cooldown. DIAMOND SHOP opens the 60 / 360 / 1,800
diamond consumable products: `sink_city.diamonds_60`,
`sink_city.diamonds_360`, and `sink_city.diamonds_1800`. Displayed prices come
from StoreKit; unavailable products are disabled. Apple-verified transactions
are durably credited once before acknowledgment. The legacy coin-product
handlers exist for compatible previously redeemed transactions but are not new
purchase offers in the current storefront.

HOLES opens the unified scrolling skin collection. RATES explains current
random unlock probabilities and guarantees. Privacy and Support are
accessible from HOME through SETTINGS > PRIVACY & SUPPORT. Music, sound and
haptic controls are in SETTINGS and the pause panel. Ad privacy options appear
when Google UMP requires them. Progress and redeemed transaction records are local, with no
cloud account.

These notes describe the current implementation. Before submission, verify
the new diamond products, purchase agreements and physical Apple sandbox
purchase/cancel/replay flows. This draft does not claim those steps have passed.
