# Release preparation review

Reviewed October 2, 2026. This review does not execute an engine, build, phone
operation, purchase, ad request, account change, upload or submission. Financial
documents and device identifiers are not included.

## Native preparation

The fresh build-16 and build-17 orchestration scripts parse as Python. Their
hashes match their `prepared-only.json` records. The release registry contains
83 unique suites, all required cached dependencies exist, and the four fresh
export/artifact directories were absent at this inspection. The gate-02 final
receipt was not yet present, so neither helper was runnable at that point.
This is expected fail-closed behavior while the coordinator completes the gate.

No concrete execution-blocking script defect was found in the static review.
The helpers require unchanged accepted inputs, the frozen Swift adapter,
fresh checks of the actual native PCK, distinct test/production identifiers,
strict signatures and eligible profiles. They do not install, launch, upload,
or certify sandbox purchases. Local account/signing credentials and keychain
authorization remain execution prerequisites if Xcode requests them.

Preparation commands, to be run serially by the coordinator after the gate and
normal soak succeed:

```sh
nice -n 15 python3 build/diamond-device-20261002-16/prepare.py
nice -n 15 python3 build/diamond-production-20261002-17/prepare.py
```

## Apple purchase blocker

The coordinator reports the Paid Apps Agreement status is **Pending User Info**.
Apple defines that status as an agreement that is signed but not in effect.
It differs from **Active (Pending User)**, which is in effect.
[Apple agreement statuses](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status).
Reviewed status clause: “it’s not in effect because you haven’t finished
providing required information.”

Apple's current TN3186 identifies an agreement not in effect and incomplete
banking/tax information as reasons product requests can return no products in
the App Store sandbox. Sandbox testing does not require prior App Review
approval of the products. Exact bundle/product IDs, eligible signing, price and
localization still matter. New diamond IDs in the native allowlist are not proof
that the corresponding App Store Connect records exist or can be fetched.
[Apple sandbox availability troubleshooting](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox).
Reviewed TN3186 sections are **Ensure you have a Paid Apps Agreement in effect**
and **Complete all banking and tax information**. They require an effective
agreement and describe financial information as “complete if App Store Connect
shows an `Active` status” in the corresponding banking/tax sections.

The current new consumable IDs are:

- `sink_city.diamonds_60`
- `sink_city.diamonds_360`
- `sink_city.diamonds_1800`

The requested US pricing is $0.99 / $4.99 / $19.99, subject to the actual Apple
catalog configuration. Runtime displays only `Product.displayPrice`. Preserve
the existing legacy coin records and verified unfinished-transaction processing;
do not relabel old coin products as diamonds.

The account holder must complete Apple's outstanding required financial
information, then the coordinator can verify effective agreement status and
exact diamond product metadata. No personal financial content is recorded here.
After product changes, allow for propagation before declaring a missing-product
failure; Apple documents up to one hour. A development-signed device build and
a Sandbox Apple Account can then test the real catalog without charging money.
Confirm the sandbox environment and retain purchase/cancellation, durable
credit, unfinished-delivery and duplicate evidence.
[Apple sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

## Local testing option while account information is pending

StoreKit Testing in Xcode can test before App Store Connect products are ready
and without App Store servers. A local `.storekit` configuration activated in
the Xcode run scheme supplies simulated consumables and localized price values.
This can exercise the real StoreKit adapter's verified-event and finish flow;
it does not verify the Apple sandbox, live catalog, financial agreement or
production price availability.
[Apple local StoreKit setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode).

Use a separate local test configuration and isolated wallet because simulated
transaction identifiers can differ from server transactions. Label results as
Xcode local testing. Do not activate or bundle a local catalog in the production
candidate, and disable the scheme's StoreKit configuration when moving to
App Store sandbox. Neither fresh helper currently activates local StoreKit
testing, and this reviewer did not create or run such a configuration.

## Remaining release evidence

1. Complete gate-02 and the normal soak without changing guarded inputs.
2. Prepare build 16; preserve immediate phone Documents, update the same bundle,
   and compare exact save bytes before an ordinary launch. No uninstall.
   The prepared-only `build/diamond-device-20261002-16/install.py` performs these
   checks and stops before launch. It requires the new signed-candidate receipt,
   current gate and strict actual signature; preserves fresh private attempt
   logs/backups; and never starts a phone console. This reviewer did not run it.
3. Verify 90-second city / 60-second food rounds, one +30-second continuation,
   native earned-video timing, diamonds, exchanges, haptics and full-screen UI
   on the owned device using official test ads.
4. Resolve purchase account/catalog readiness and record real sandbox results.
5. Prepare and verify build 17, then reconcile its aggregate privacy report with
   the effective ad controls and the App Privacy draft. The RTB checkbox is
   currently unverified because account controls are not responding; do not
   publish a presumed setting or generic manifest-derived tracking answer.
6. The coordinator reports public support-site v5 has completed preload and
   diamond wording. Reconcile embedded policy and current store media with the
   final binary, upload the exact signed candidate, and confirm submission
   prerequisites before App Review.

The desktop/headless fixtures and local StoreKit option cannot replace actual
sandbox purchase or physical-device evidence. No item above is claimed complete
unless a new receipt or direct verification establishes it.
