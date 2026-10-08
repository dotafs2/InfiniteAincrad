# Timed runs, cosmetic collection and larger worlds

## Gameplay

Both playable maps use a 240-second run. Score, food orders and city collection
milestones do not end the timer. Being swallowed costs two seconds, then the
player respawns at the clearest of five candidate positions with their score
retained and eight seconds of protection. AI size gates and the existing 70%
AI reward rate remain in force. Empty runs earn no coins. A completed run with
points earns floor(score / 10) + 20 coins. Leaving for home does not settle a run.
Map best scores and completed runs persist; the next gem gift becomes available
on completing another nonempty timed run.

The two playable worlds expand from a 160-meter ground slab and 152-meter travel
width to 200 and 192 meters respectively: 56.25% more ground and about 59.6% more
playable area. New populated perimeter districts connect to the existing center.
The existing traffic routes and actor counts stay bounded. Details and measured
object inventories live in the world-expansion author and independent reports.

The map chooser exposes Sunny City and Snack Garden, plus three non-playable
Coming Soon entries: Animal Kingdom, Star Voyage and Toy Factory. Placeholder
IDs never enter the saved playable-map field.

## Collection rules

| Tier | UI color | Base weight | Presentation |
| --- | --- | ---: | --- |
| Common | Gray | 45% | Simple solid recolor, one visible ring mesh |
| Uncommon | Green | 28% | Ring plus a simple trim, two visible meshes |
| Rare | Blue | 16% | Sculpted decorative motif |
| Epic | Purple | 8% | Detailed motif; existing functional skins retain their skills |
| Legendary | Orange | 2.5% | Core Shell, Tide and Cinder signature effects |
| Prismatic | Rainbow accent | 0.5% | Orbit, Prism Vale and Rainbow Bridge |

These are initial design weights, not measured retention-optimal probabilities.
Every draw grants an unowned skin. Empty tiers leave the pool; eligible weights
are normalized before drawing a tier, then an unowned skin is chosen uniformly
within that tier. RATES shows the actual next-draw tier probability and per-skin
probability, including current ownership and any due guarantee.

Classic and Special have independent counters. At most five draws yield an
Epic-or-higher skin, ten a Legendary-or-higher skin and twenty a Prismatic skin,
while a qualifying unowned skin remains. Higher awards reset all lower qualifying
counters. The highest due guarantee restricts the pool; exhausted qualifying
pools do not block remaining lower-tier collection. There are no duplicate
purchases or duplicate-compensation currency. Coin prices retain the existing
50, 70, 90, 110 and capped 140 progression in each collection.

New players receive the gray Slate Ring under the stable `cocoa_square` ID.
Existing saves retain their old Core Shell entitlement, all known explicit owned
IDs, equipment, balance and unknown configuration sections. Pre-coin threshold
unlocks migrate additively. Schema 3 stores ownership independently from score,
plus the per-tab guarantee counters.

## Optional monetization boundary

The result panel offers an optional rewarded video for one additional copy of
that run's base coin award. It never doubles the entire wallet. A durable request
ID binds the SDK callback to its original round receipt. Closing an ad does not
grant a reward; a verified earned callback may arrive after close or during the
next run. Duplicate and late callbacks cannot pay the same round twice. Failed
local saves roll back the visible balance and retry an already verified reward.

The Coin Shop offers fixed 320, 2,000 and 9,600 coin products. Product prices must
come from a compatible native app-store adapter. Only a verified transaction can
grant coins; its unique transaction ID and wallet update are saved atomically
before acknowledging the native transaction. Pending approval, cancellation,
missing products and missing SDKs grant nothing. Replayed unfinished transactions
can retry after a save failure without paying twice.

No ad SDK, native purchase SDK, production ad-unit configuration or app-store
products are installed in this Web build. The buttons truthfully show unavailable
or Coming Soon. Native adapters must implement the documented versioned protocol,
consent/loading and platform receipt verification; these are future integration
requirements, not shipped payment capability. See ../monetization-20260929/bridges.md.

## Evidence boundaries

Release manifests distinguish source scene tests, isolated packaged scene tests,
windowless software OpenGL color tests and static HTTP delivery checks. They do
not establish browser appearance, audible behavior, live billing, live ads,
actual player retention or sustained iPhone 14 frame rate. No player save or
unrelated resident world is used by QA; fixtures use --test and owned temporary
files. No Git publication is part of this task.
