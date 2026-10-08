# Device 16: consent network error and rewarded timeout

Reviewed on October 2, 2026. This is a read-only diagnosis of the ordinary-launch console observations reported by the release coordinator. No SDK requests, phone actions, account changes, source edits, consent resets, or new builds were performed for this review.

## Observed stages and exact SDK meanings

The installed candidate uses Google User Messaging Platform 3.1.0 and Google Mobile Ads 13.11.0. The cached distribution headers and current primary references agree:

| Diagnostic | Exact meaning in its SDK error domain | Interpretation limit |
| --- | --- | --- |
| `consent_update_failed code=3` | `UMPRequestErrorCodeNetwork`: a network error communicating with Funding Choices | This is the UMP request-network category. UMP invalid app ID is 2; misconfiguration is 4. |
| `sdk_started code=0` | The application's success-stage marker after `await MobileAds.shared.start()` | The logger supplies 0 when no Error exists. It is neither a failed SDK start nor a count of zero starts. It does not establish that an ad is ready. |
| `rewarded_load_failed code=5` | `GADErrorTimeout`: the request did not load before the timeout | GMA no fill is 1 and network error is 2. Timeout alone does not identify the underlying cause. |

Cached headers inspected:

- `build/monetization-20261001/dependencies/ump/UserMessagingPlatform.xcframework/ios-arm64/UserMessagingPlatform.framework/Headers/UMPError.h`
- `build/monetization-20261001/dependencies/gma/GoogleMobileAds.xcframework/ios-arm64/GoogleMobileAds.framework/Headers/GADRequestError.h`

Primary references: [UMP request errors](https://developers.google.com/admob/ios/privacy/api/reference/Enums/UMPRequestErrorCode), [GMA request errors](https://developers.google.com/admob/ios/api/reference/Enums/GADErrorCode).

The frozen native implementation logs only the stage and `NSError.code`, with diagnostics restricted to official-test-ID packages. It omits the domain, description, underlying error and response information. The above mappings correspond to the SDKs used at those stages; the existing log cannot conclusively establish a specific DNS, TLS, proxy, VPN, server, or account fault. Google documents additional NSError fields for distinguishing causes: [Ad load errors](https://developers.google.com/admob/ios/ad-load-errors). No private SDK response information or device identifiers were collected for this review.

## Existing recovery behavior

`native/ios/HoleFeastServices.swift` remains frozen at SHA-256 `4796be1bac3627e4bed3f548fa11ab3bc298938756cb8b0091447f397ab5eb08`.

Consent and rewarded loading each retry with a 15, 30, 60, 120, 240, then 300 second delay while the app is active. The foreground observer requests a consent refresh if recovery is pending; otherwise it attempts permitted ad initialization/loading. Existing guards prevent simultaneous loads and do not present privacy forms while the app is in the background.

After a consent error, `canRequestAds` remains authoritative. Prior-session consent can permit ads despite a failed refresh. This follows Google's [UMP integration guidance](https://developers.google.com/admob/ios/privacy). A failed refresh never fabricates consent. Google's reset method is reserved for testing first-install state; resetting is not a network-recovery step and would erase the previous SDK consent state.

## Bounded next check

1. Confirm that the phone's current network route works. Google website access is only a basic connectivity check and does not prove that both SDK service paths are reachable.
2. After any route correction, return the game to the foreground once. Keep it active and observe one bounded retry window; an existing in-flight request may need to finish first. Preserve the current failure logs.
3. Test the diamond video only after `rewarded_ready` and an enabled button. Success requires the SDK's earned callback, dismissal, and the expected durable wallet change; a timeout is not an earned reward.
4. If the same failures persist, retain the current package and consent state. An expanded future test-only diagnostic could record NSError domain and redacted underlying domain/code without response payloads or identifiers. That change is outside this review and has not been made.

These observations do not by themselves justify replacing the verified test identifiers, rebuilding, reinstalling, changing account declarations, or declaring a NoTracking policy. Physical diamond-video acceptance remains pending until the release coordinator receives and verifies that result. The coordinator separately reports 8,948 native-PCK checks passed; those checks do not prove live SDK connectivity.
