# Diamond economy and timed continuation

This contract follows the user's October 2 request. It supersedes the universal
one-minute timer and generous score payout. It does not reset any existing wallet,
owned skin, draw guarantee or verified transaction ledger.

- Sunny City starts at 90 seconds; Snack Garden starts at 60 seconds.
- A timed result offers one additional 30 seconds, on either map. The existing
  world, score, consumed objects, rivals and round receipt remain in place.
- Continuation costs 5 diamonds, or an optional genuinely rewarded video. The
  advertising provider controls video duration. No fixed 15-second promise is
  made, and closing an unearned video never grants time or currency.
- Score coins are `min(30, floor(score / 100))`. A nonempty timed completion earns
  one additional 5 coins. Continuation pays only the additional score component;
  it cannot repeat the bonus, advance a second stage or count a second run.
- New wallets start with 10 diamonds. The existing saved `gems` key retains its
  value and is presented as diamonds. Previously earned currency is not removed.
- A rewarded video in the store earns 3 diamonds and starts a persisted 120-second
  cooldown after the reward commits successfully. The former free stage gift
  now routes to this real video offer.
- Diamond exchanges are 50 for 250 coins, 250 for 1,500 coins, and 1,000 for
  7,000 coins. The wallet debit and credit commit atomically.
- Completed or failed standalone diamond-video bindings retain at most 32
  terminal records. Active videos, authenticated earned work and possible late
  earned callbacks remain bound; legacy round reward records are unaffected.
- Existing coin products remain valid for unfinished verified transactions. New
  diamond products credit the diamond balance. Every transaction stays bound to
  its original product ID, and acknowledgement follows durable wallet storage.

## Earned reward lifecycle

The application first saves the accepted offer before opening the native SDK.
Only the bridge's authenticated earned callback can mark `reward_due`; that marker
is saved before committing currency or time. Storage failure leaves earned work
pending and rolls back wallet changes. A durable marker can replay after restart,
while loading, failed and merely closed requests cannot manufacture rewards.

For time rewards, both earned and actual SDK close are required. Either callback
order works. The clock remains stopped while the video is visible. If the original
world no longer exists, the authenticated earned reward becomes a one-time
5-diamond credit with the notice “Your +30s reward became 5 diamonds”. A lost world
is never silently recreated. Restarted, persisted earned work uses the same safe
fallback.

The save contract cannot promise recovery of a callback if storage fails before
any authenticated marker can be written and the process is then terminated.
During a live process the pending work retries; after a successful marker write it
is recoverable on restart.

## Acceptance evidence

The focused economy suite passed 72 checks in
`artifacts/diamond-economy-20261002/economy-focused-03.json`. It exercises real
same-world continuation, two callback orders, abandoned-world and restart reward
recovery, failed persistence, old-wallet compatibility, cross-product transaction
conflicts, both currency types and all exchanges. Earlier failed compilation and
superseded passing receipts remain preserved. A final pending-state refinement
keeps an earned but still-visible video pending until actual close; the root's
integrated gate must bind and test this final source.

These are isolated headless application checks with an explicitly injected SDK
provider. They do not prove new products are configured in App Store Connect,
Apple sandbox purchase acceptance, actual provider video duration or the final
native package. The root task owns that acceptance and publication work.
