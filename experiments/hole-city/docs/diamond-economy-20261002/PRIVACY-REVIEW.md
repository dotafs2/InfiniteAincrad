# Device ID disclosure review

Reviewed October 2, 2026 for frozen Hole Feast 0.12.4 source. This is a local
research decision record, not a published declaration. No account controls,
source inputs, SDK requests or device state were changed.

## Decision

The source provides concrete evidence of restricted advertising, but the
available evidence does not yet establish a final **No Tracking** answer across
all enabled demand paths. The remaining step is specific: reconcile AdMob's
effective RTB demand, creative-consent controls and optional first-party/IDFV
sharing. Do not infer tracking from the SDK's generic manifest alone, and do not
add ATT merely to match that manifest.

## Frozen configuration

`native/ios/HoleFeastServices.swift` has SHA-256
`4796be1bac3627e4bed3f548fa11ab3bc298938756cb8b0091447f397ab5eb08`.
It sets the following before initializing Mobile Ads:

- `setPublisherFirstPartyIDEnabled(false)`.
- `publisherPrivacyPersonalizationState = .disabled`.
- `maxAdContentRating = .general`.
- Every rewarded request supplies `npa=1`.
- UMP's `canRequestAds` gates SDK startup and loading.
- The app does not request ATT or define `NSUserTrackingUsageDescription`.
- There is no Firebase Analytics or additional mediation SDK in the prepared
  adapter. This does not prove that all auction demand is Google demand.

The `.disabled` value turns **personalization** off using PPT; it does not turn
the privacy-treatment API off. Google documents this exact Swift setting and
requires configuration before SDK initialization. [Google iOS targeting](https://developers.google.com/admob/ios/targeting).
The separate first-party-ID call is Google's documented disable mechanism.
[Google iOS privacy strategies](https://developers.google.com/admob/ios/privacy/strategies).

The prior GUI observation recorded an enabled account-level first-party-ID
control, with analytics connection and surveys disabled. This agent did not
re-read or alter those controls. SDK disabling is positive source evidence;
the observation does not independently settle all optional IDFV sharing.

## What the current primary sources establish

Apple's tracking definition covers joining app data with other companies' data
for advertising targeting **or measurement**, and sharing with a data broker.
IDFV may support analytics across the same provider's apps, but cannot be
combined for cross-company tracking. Alternative identifiers do not avoid ATT.
Developers remain responsible for integrated SDK behavior. Quote: “Developers
are responsible for all code included in their apps.” [Apple privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/).

Google documents that NPA uses contextual selection while identifiers may
still support frequency limits and aggregate reports. NPA therefore does not
mean no data collection. [Google personalized and non-personalized ads](https://support.google.com/admob/answer/7676680?hl=en).

PPT alone allows third-party ad-serving/tracking vendors. With simultaneous
signals, Google states: “the most restrictive signal will take precedence.”
NPA restricts those vendors for Google demand; non-Google RTB restrictions
depend on the **Check RTB partner creatives for ad partner consent** control.
Thus PPT's permissive behavior must not be treated as overriding the explicit
NPA request, but NPA also does not resolve an unknown RTB configuration.
[Google PPT treatment rules](https://support.google.com/admob/answer/14323214?hl=en).
The regional scope of the associated consent control is qualified below;
this paragraph does not establish global US coverage.

Publisher first-party IDs are scoped to the publisher's apps, with documented
limits on linking to third-party apps. Google's guide separately describes
optional sharing of other first-party IDs, including IDFV, with RTB buyers and
provides account/demand controls. The source's PFID disable call is not an
independent audit of those other effective controls.
[Google first-party identifiers and data](https://support.google.com/admob/answer/14199649?hl=en).

Google says ads can be requested without IDFA when ATT is denied. That confirms
IDFA absence is compatible with ad serving; it does not establish how every
other collected field is used. [Google IDFA guidance](https://developers.google.com/admob/ios/privacy/idfa).

## App Privacy working draft

Collection must be **Yes**. Google documents SDK processing of approximate
location from IP, identifiers, ad/product interactions and diagnostics.
[Google iOS data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure).
The original packaged SDK union below is retained from
[the existing evidence](../../artifacts/monetization-20261001/payment-complete/vendor-privacy-review.json).
It is the basis of the working draft, not proof that every capability is active.

| Data type | Linked | Working purposes | Tracking draft |
| --- | --- | --- | --- |
| Coarse Location | Yes | Analytics; App Functionality; Developer Advertising; Third-Party Advertising | No, subject to effective-use reconciliation |
| Advertising Data | Yes | Analytics; Developer Advertising; Third-Party Advertising | No, subject to effective-use reconciliation |
| Product Interaction | Yes | Analytics; App Functionality; Developer Advertising; Third-Party Advertising | No, subject to effective-use reconciliation |
| Crash Data | No | Analytics | No |
| Performance Data | No | Analytics; App Functionality; Developer Advertising; Third-Party Advertising | No, subject to effective-use reconciliation |
| Other Diagnostic Data | No | Analytics; Developer Advertising; Third-Party Advertising | No, subject to effective-use reconciliation |
| Device ID | Yes | Analytics; Developer Advertising; Third-Party Advertising | **Unresolved; do not publish either answer by inference** |

If the effective demand/identifier audit establishes no cross-company use,
the proposed final Device ID answer is **linked Yes / tracking No**, retaining
the evidenced purposes. A positive tracking finding would require resolving
permission-gated behavior before submission; selecting Yes alone does not make
the current no-ATT implementation compliant.

Local coins, diamonds, skins, preferences and redeemed transaction IDs are not
sent to an app server or to the advertising adapter. No payment-card data is
received. Apple distinguishes on-device processing from collection and excludes
payment details never accessible to the developer. SDK partner collection
still counts, and unlinked answers require real de-identification protections.
[Apple App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).

## Concrete completion steps

1. Inspect the actual app/ad-unit demand paths and RTB creative-consent setting;
   record whether optional IDFV/first-party sharing is enabled for each path.
   Inspection is sufficient now; no production ad request is required.
2. Generate the final signed archive's aggregate privacy report and retain the
   unmodified vendor manifests. The report summarizes declarations; it cannot
   establish server-side uses or effective account settings by itself.
3. Validate the documented configuration with official test ads and privacy
   signals when an owned device check is available. Traffic/domain or zero-IDFA
   observations alone cannot prove a provider never joins server-side data.
   Resolve any remaining use ambiguity with specific provider guidance.
4. Reconcile all categories/purposes with those findings, then obtain accuracy
   confirmation for the concrete App Store Connect Publish action. Do not
   publish the old Data Not Collected answer.
5. The coordinator reports support-site v5 now includes the diamond economy
   and consent-permitted ad preloading before a player opts to watch. Keep that
   completed public wording in the final record. Embedded policy wording must
   still be reconciled with the exact submitted build; frozen source was not
   changed during this review.

The device/SDK/privacy-manifest findings of prior packages remain historical
evidence. This review does not certify a new binary, production serving, final
privacy publication or App Review readiness.

## Account-scope follow-up

The coordinator's read-only account observations reported 53,897 listed
sources, zero blocked sources, automatic admission of newly certified sources
enabled, and 334 selected US-state ad partners. These observations do not prove
that any particular buyer received Hole Feast traffic. No control was changed
as part of this research.

The RTB consent checkbox is at **Privacy & messaging → European regulations
card → Settings → Check creatives for consent**. Its full label is **Check RTB
(real-time bidding) partner creatives for ad partner consent**. The detailed
current article describes GDPR/LGPD vendor filtering and additional coverage
for EEA, UK, Switzerland and Brazil requests on Authorized Buyers and bidding
demand. Additional regional coverage does **not** mean US requests are excluded.
The PPT article's NPA/RDP rule describes restricting non-Google vendor usage
when the checkbox is enabled without stating a US exclusion. These documents
are not proven contradictory: checkbox plus NPA is a documented restriction
path, though it does not establish Google-only demand or flawless detection.
The actual checkbox is currently **unverified**, and the coordinator reports
that account input clicks are blocked/no-effect. Do not invent a saved account
change or mislabel US requests as GDPR traffic.
[Google RTB consent checking](https://support.google.com/admob/answer/10285218?hl=en).

US-state partner selection controls third-party buyers for eligible users in
applicable states. Selecting only Google there is useful within its documented
scope, but does not prove a restriction for every US state or worldwide
request. Google separately documents that an RDP signal can apply globally;
this is not equivalent to confirming every enabled buyer's data use.
[Google US-state privacy controls](https://support.google.com/admob/answer/9561022?hl=en).

For optional identifier sharing, the first-party guide identifies **Bidding
sources** for per-partner controls and **Publisher data** for account-wide use
and sharing controls. The public guide does not provide an exact IDFV-specific
switch label or explicitly state that the SDK's PFID disable call disables
every optional IDFV route. A live read-only control inventory must establish
the current interface and resulting scope before claiming that sharing is off.
[Google first-party identifiers](https://support.google.com/admob/answer/14199649?hl=en).
The 2025 release archive described RTB IDFV forwarding as conditional on
personalization being permitted, which supports the intended restrictions.
That page explicitly warns that archived features may have changed; it is
historical corroboration, not a substitute for current effective-control
evidence. [Google 2025 IDFV release note](https://support.google.com/admob/answer/16368266?hl=en).

Account-wide ad-network controls are documented at **Blocking controls →
Manage ad networks**. Networks are allowed by default; the automatic-admission
switch concerns future certifications. Turning that switch off does not
retroactively block existing networks.
[Google network blocking](https://support.google.com/admob/answer/6067448?hl=en).
For bidding sources, ad filtering can be configured at **Mediation → Bidding
sources → selected source → Settings**. Disabling filtering also relaxes
network and other blocking controls for matching mediation-group requests;
not all sources expose the control. EU/US regulatory settings are distinct.
[Google bidding-source filtering](https://support.google.com/admob/answer/10931097?hl=en).

**Conditional configuration target, inferred from those controls:** retain
the frozen native restrictions; disable account-wide optional first-party
sharing and any independent IDFV sharing; prevent automatic admission of new
non-Google sources; allow only Google demand across the actual global network
and mediation paths if the account supports an effective restriction. Verify
each active bidder and exceptions rather than assuming a US partner subset or
the absence of mediation SDKs establishes this target. Record the exact saved
controls and their coverage. Narrowing demand can reduce advertising revenue.
The alternative is specific provider confirmation of US NPA RTB vendor/IDFV
behavior. Neither target has been applied or verified by this agent; Device ID
tracking remains unresolved until that evidence is reconciled.

## Achievable control routes and current limit

Global network blocking is the relevant official control for a Google-only
target on standard AdMob units. The documented procedure is to block each
non-Google network and prevent admission of future networks. Public help does
not specify a bulk block-all/re-allow-Google control. The coordinator currently
cannot open the source-management dialog because UI input is unresponsive, so
the actual bulk capability and exact Google rows remain unverified. The
reported source count is an inventory observation, not proof of executed
blocks or traffic. [Google network blocking](https://support.google.com/admob/answer/6067448?hl=en).

Removing manually configured non-Google mediation sources alone is insufficient:
Google currently documents automatically bidding sources inside the AdMob
Network that require no setup and are not added to mediation groups.
[Google bidding-source types](https://support.google.com/admob/answer/11555701?hl=en).
Partner-bidding units access Google demand through supported external mediation
platforms, but are not interchangeable with this app's standard AdMob unit.
Changing an identifier to that unit type without the required integration is
not an available settings-only fix.
[Google ad-unit serving types](https://support.google.com/admob/answer/12436136?hl=en).

For the current integration, a bounded restriction route is to verify and
enable the RTB consent checkbox while retaining per-request NPA, and verify
account-wide first-party sharing is disabled. This follows Google's treatment
rules without claiming only Google can bid. Per-partner identifier controls
remain relevant if they expose an independent IDFV opt-in. Do not infer such
sharing is active from its mere availability or from the absence of IDFA.
The source positively disables PFID before Mobile Ads initialization and does
not send a wallet, user identifier or custom first-party identifier to the SDK.
It does not independently expose or audit the SDK's IDFV collection/forwarding.
No actual checkbox or identifier-account change has been verified yet.
