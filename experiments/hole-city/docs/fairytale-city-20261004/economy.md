# One completed round, one skin draw

The October 4 correction replaces score-derived coin payouts with one fixed
50-coin reward for a played normal completion. The City, Food and Toy rounds use
the same rule. A zero-score or abandoned/eaten round receives no finish reward;
points never credit coins during play. Every available collection draw costs
50 coins, including the legacy collection entry points.

An optional genuinely earned and dismissed video boosts the settled reward to
75 coins. The alternative costs 10 diamonds for the same 25-coin bonus. The
one-time 30-second continuation also costs 10 diamonds or an earned video and
retains the world, points and original receipt. Its later settlement does not
pay another finish reward or enlarge the fixed reward. Completion count and
stage advance once.

Diamond exchanges are linear: 100 diamonds buy 250 coins, 250 buy 625, and 1,000
buy 2,500. The proposed entry purchase uses a new consumable product ID,
`sink_city.diamonds_100`, granting 100 diamonds. One actual first exchange
therefore yields 250 coins, enough for five 50-coin draws. The planned US price is
$1.99; that price still requires real App Store Connect configuration. The game
shows only StoreKit's localized price and keeps the new product unavailable
until genuine metadata arrives. No hardcoded price or account change is made.

The old 60-, 360- and 1,800-diamond IDs retain their exact fulfilment quantities;
legacy coin products also remain accepted. Existing balances, ownership, pity,
purchase deduplication and round reward receipts are preserved. An unfinished
old 13-coin multiplier still grants its original six-coin bonus. Old extension
video requests without an explicit fallback quantity retain five diamonds when
their original world is lost; new requests persist their ten-diamond fallback
before dispatch. Duplicate callbacks and save failures use the existing durable
retry and rollback paths.

Focused fixtures are prepared for fixed rewards across all three maps, both
ordering choices for continuation and boost, actual entry credit followed by one
exchange and five unique draws, missing product metadata, original product
quantities, failed-save rollback, restart and legacy receipt compatibility.
Current execution evidence will be recorded separately; this document does not
assert a new native build, purchase, installation or store price configuration.

The first serial source-only focused run passes all 14 suites and 12,027 checks
in 74.629 seconds, with all 837 guarded inputs unchanged. The actual fixtures
exercise a failed entry-product commit followed by authenticated redelivery,
one 100-diamond exchange, five unique paid draws and a cold restore, along with
earned/closed callback ordering and the unchanged legacy 13-coin crash retry.
Exact reports and logs are in
`artifacts/fairytale-city-20261004/economy-focused-01/`; independently checked
hashes are in
`build/fairytale-city-20261004/economy-focused-01/verified-result-01.json`.
These are isolated test-provider transactions, not real purchases or ad plays.
The root's fresh App Store Connect check reports an expired login, so configuring
the proposed $1.99 price remains blocked on restored authentication.
