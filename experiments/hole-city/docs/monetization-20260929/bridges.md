# Optional monetization boundaries

Current continuation: [native SDK integration and external requirements](../monetization-20261001/README.md). The unavailable-provider state below describes the earlier Web/no-SDK baseline.

The repository does not contain an advertising SDK, StoreKit/Play Billing plugin, configured app-store products, or a purchase-verification service. These bridges expose an explicit integration contract. The current Web and desktop builds report unavailable, contain no invented localized prices, and never simulate earned ads or payments. Deterministic providers exist only inside tests and require the explicit `--test` injection path.

## Rewarded advertising

`AdsBridge` discovers `GoogleMobileAds` only outside Web. That singleton name alone is insufficient: the provider must implement protocol version 1 with the exact typed methods and signals below. This is a project-specific adapter contract, not a claim that an arbitrary existing Godot AdMob plugin already implements it.

Methods:

- `sink_city_rewarded_protocol_version() -> int`: return 1.
- `initialize() -> void`: initialize consent and SDK state; idempotent from the bridge.
- `rewarded_available() -> bool`: true only when consent permits requesting ads and an actual rewarded ad is loaded.
- `show_rewarded(request_id: String) -> bool`: begin the user-selected presentation, echoing its unchanged ID in every callback. A false return rejects the request.

Signals:

- `rewarded_earned(request_id: String)`
- `rewarded_closed(request_id: String)`
- `rewarded_failed(request_id: String, message: String)`
- `availability_changed()`

Public game signals are `rewarded_completed(id)`, `rewarded_closed(id)` and `rewarded_failed(id, message)`. The game calls `validated_reward_available()` and `show_rewarded(id)`. Each accepted ID earns at most once. Closing does not imply earning or permanently erase the ID: mediated networks may close before delivering their earned callback. Old callbacks cannot close or credit a newer request. Synchronous callbacks are buffered until the provider has returned a real boolean acceptance; rejected requests cannot manufacture rewards. A reward does not close an on-screen ad. The game owns the round binding and durable reward ledger.

Google documents that Google ads earn before dismissal, while mediation ordering depends on the third-party network: [rewarded ads](https://developers.google.com/admob/ios/rewarded). Only the earned callback supplies entitlement; no timer or close callback is a substitute.

## Coin purchases

`CommerceBridge` discovers `SinkCityCommerce` only outside Web. The fixed catalog is:

| Product ID | Coins |
| --- | ---: |
| `sink_city.coins_320` | 320 |
| `sink_city.coins_2000` | 2,000 |
| `sink_city.coins_9600` | 9,600 |

These are proposed integration identifiers, not proof of registered store products. A future adapter must return localized prices for those actual registered products. `product_info(id)` exposes a defensive copy containing only `product_id`, the fixed `coins` count, and SDK-provided `localized_price`. Missing, malformed or conflicting duplicate product data is unavailable rather than assigned a fallback cash price.

Native methods:

- `sink_city_commerce_protocol_version() -> int`: return 1.
- `initialize() -> void`
- `purchases_available() -> bool`
- `request_products(ids: PackedStringArray) -> void`
- `purchase(product_id: String, request_id: String) -> bool`
- `acknowledge(transaction_id: String) -> bool`

Native signals:

- `products_received(products: Array)`: authoritative product dictionaries with `product_id` and `localized_price`.
- `purchase_verified(transaction_id: String, product_id: String, request_id: String)`: only after platform receipt/signature verification. Echo the initiating request ID when known; use an empty ID for restored or unfinished transactions with no current request.
- `purchase_failed(request_id: String, message: String)`
- `purchase_pending(request_id: String)`: approval pending; no entitlement.
- `availability_changed()`

Public signals are `products_changed()`, `verified_purchase(transaction_id, product_id)`, `purchase_failed(request_id, message)`, and `purchase_pending(request_id)`. Public methods are `purchase_available(id)`, `product_info(id)`, `purchase(product_id, request_id)`, `active_request_id()`, and `acknowledge(transaction_id)`.

The request ID prevents a delayed approval for the same product from closing a newer purchase UI. Verified unfinished transactions can arrive without a live request. Verified receipts are intentionally redeliverable until acknowledgement succeeds, allowing the wallet to retry failed disk writes. The game must atomically persist both coin balance and the transaction ID before acknowledging. In-memory bridge deduplication is not the durable payment ledger. Failed acknowledgement remains retryable; an unseen transaction cannot be acknowledged. The adapter, not GDScript naming conventions, must provide actual cryptographic/platform verification before emitting a verified receipt.

StoreKit distinguishes verified success from pending approval and cancellation: [PurchaseResult](https://developer.apple.com/documentation/StoreKit/Product/PurchaseResult), [VerificationResult](https://developer.apple.com/documentation/storekit/verificationresult). Transactions should be finished after delivering and recording the entitlement: [finish](https://developer.apple.com/documentation/storekit/transaction/finish%28%29).

## Validation and limits

`tests/monetization_bridges_acceptance.gd` passed 84 strict assertions, including unavailable paths, protocol rejection, synchronous callbacks, duplicate and stale IDs, close-before-earned, pending same-product approval, verified receipt redelivery, acknowledgement failure/retry and malformed product/receipt rejection. Evidence and exact frozen hashes are in `artifacts/monetization-20260929/bridge-author-final.json` and `bridge-provenance.json`. Tests neither contact a service nor make a payment. All owned helpers exited.

The complete game economy, wallet persistence, live SDK installation, consent flow, store sandbox purchases and browser interactions are outside this bridge-author result. An independent reviewer is assigned before release.
