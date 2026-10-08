# Monetized release privacy review

Status: prepared locally on October 1, 2026 for source 0.12.3, unsigned iOS build 5. No Apple privacy answer, AdMob message or public support page was published. Account/payment completion does not certify this material or native behavior.

## Evidence from the actual candidate

Both original packaged vendor privacy bundles match the hashes in the accepted native receipt. The following table is their union. It preserves linkage, tracking and every declared purpose, including DeveloperAdvertising. It is not a promise that every declared capability is used by the configured application, nor a finalized App Store label.

| Packaged category | Linked | Tracking | Purposes declared by vendor(s) | Provider |
| --- | --- | --- | --- | --- |
| AdvertisingData | true | false | Analytics, DeveloperAdvertising, ThirdPartyAdvertising | GoogleMobileAds |
| CoarseLocation | true | false | Analytics, AppFunctionality, DeveloperAdvertising, ThirdPartyAdvertising | GoogleMobileAds, UserMessagingPlatform |
| CrashData | false | false | Analytics | GoogleMobileAds |
| DeviceID | true | true | Analytics, DeveloperAdvertising, ThirdPartyAdvertising | GoogleMobileAds |
| OtherDiagnosticData | false | false | Analytics, DeveloperAdvertising, ThirdPartyAdvertising | GoogleMobileAds |
| PerformanceData | false | false | Analytics, AppFunctionality, DeveloperAdvertising, ThirdPartyAdvertising | GoogleMobileAds, UserMessagingPlatform |
| ProductInteraction | true | false | Analytics, AppFunctionality, DeveloperAdvertising, ThirdPartyAdvertising | GoogleMobileAds, UserMessagingPlatform |

The exact original declarations are retained in [vendor-privacy-review.json](../../artifacts/monetization-20261001/payment-complete/vendor-privacy-review.json). Do not edit SDK manifests to change their reported behavior.

## Configuration and unresolved declarations

The native adapter disables Google's publisher first-party ID and personalization, sets the general ad-content cap, and sends npa=1. UMP updates consent and presents required forms before canRequestAds allows SDK initialization. The app never requests ATT. Native privacy options are exposed when UMP requires them. These facts are source evidence; device callbacks, actual consent forms and identifiers sent in requests have not been accepted on a physical phone.

The device-ID tracking flag in the vendor declaration requires reconciliation with the effective SDK configuration and Apple's tracking definition. Neither a generic manifest flag alone nor NPA alone proves the application's final tracking answer. Do not silently declare No Tracking or add ATT merely to accommodate a generic SDK flag. Check the final native privacy report, provider guidance and device behavior before approving the declaration. [Apple's privacy guidance](https://developer.apple.com/app-store/app-privacy-details/) requires accounting for integrated partners and defines collection and tracking.

The planned label cannot be Data Not Collected. [Google's disclosure guide](https://developers.google.com/admob/ios/privacy/data-disclosure) identifies SDK processing of network, advertising, interaction and diagnostic information. The packaged manifests above are the exact category/purpose evidence for this candidate.

NPA and US restricted data processing are separate controls. The saved US message must be reviewed against the intended non-personalized configuration and verified opt-out behavior. UMP writes GPP choices; Google documents separate RDP/GPP support. No RDP signal or completed compliance test is inferred from npa=1. [Google's US guidance](https://developers.google.com/admob/ios/privacy/us-states).

## First-party and purchase information

Wallet, skins, audio preferences and redeemed transaction IDs are on-device. No app server or cloud-save account receives them. StoreKit handles payment; the app uses verified transaction/product information for durable coin delivery and duplicate prevention without receiving payment-card details or Apple credentials. Review any later off-device transaction reporting separately. Optional email support and website hosting are explained in the policy draft; they must not be confused with an app payment-card collection flow.

The [website policy draft](privacy-policy-draft.md) is based on the existing in-app iOS policy, retaining website hosting disclosure and adding a clarification about rewarded-ad preloading. After consent permits requests, loading happens before the player chooses to watch, so choosing not to watch is not a switch that disables SDK processing. Synchronize that clarification in native policy before the final package/public policy acceptance. The public no-SDK baseline page remains intact until the replacement is approved and verified.

## Remaining acceptance

1. Obtain local keychain authorization, prepare a signed current test-ID device candidate and preserve the phone save before installation. Use official test ads; do not request or click live production ads for testing.
2. Verify UMP initial/no-consent/error/return paths and AD PRIVACY CHOICES, rewarded earning/dismissal/failure, and privacy signals on the phone. Reconcile the tracking declaration and US message without changing vendor manifests.
3. Finalize the accurate category/purpose/linkage/tracking answers, publish the matching public policy, and obtain approval at Apple's Publish accuracy statement. Replace the old Data Not Collected draft.
4. Finish Apple purchase agreements/products and sandbox receipt/replay QA, capture native store images, upload the signed production package, and seek explicit App Review submission authorization.
5. After the app listing is public, link the store in AdMob and verify account/app approval and app-ads.txt crawling. Payment setup alone does not unlock production serving.

The previous full game gate is unchanged and was not repeated for this documentation/account-only review. SDK callbacks and production serving remain unverified.
