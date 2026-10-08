# Native monetization continuation

## Payment completion verified

The user completed payment setup locally. On October 1, the authenticated
Payments overview showed an existing **AdSense (China)** payment account and
the incomplete-payment banner was absent. No payment fields were entered or
submitted by the agent. The fresh Home page states that account verification
is in progress and that the game must be linked to its published app-store
listing for application approval. Payment submission is complete; neither
account approval nor production ad serving is established. A stale overview
tab timed out three times; navigating the working account tab to the observed
overview URL recovered verification without changing submitted information.
Private account captures remain ignored. A fresh device-control listing reports
the physical iPhone 16 Pro Max unavailable; the user has been asked to reconnect
and unlock it before current save backup and native acceptance. See the
[sanitized status receipt](../../artifacts/monetization-20261001/payment-complete/status.json).

The release privacy review now records the exact seven data categories and
union of purposes in the unchanged packaged vendor manifests. The SDK's
device-ID tracking declaration remains an explicit unresolved check against
the actual non-personalized configuration; it was not removed or converted
into a no-tracking assertion. The in-app iOS policy has been extracted as a
website draft, with the website-specific hosting disclosure preserved. Neither
the public baseline policy nor Apple labels nor the US message was published
during this follow-up. See [privacy review](privacy-release-review.md) and
[policy draft](privacy-policy-draft.md). The paragraphs below retain earlier
account and build checkpoints.

## Current game package

The subsequent collection request advances source/preview to 0.12.3 and
replaces the current candidate with isolated build 5 at
`build/ios-skin-collection-20261001-05/`. It retains the verified production
advertising configuration and vendor privacy bundles, compiles/links unsigned
and passes 8,547 focused desktop PCK checks. It is not signed, installed,
launched or uploaded. Earlier build-4 evidence below remains historical.
The new Web gate has 81 suites, 65,095 checks per phase and 804 frozen current
inputs, with explicit reuse of 69 unchanged source reports. Payment, native
SDK/phone acceptance, final disclosures, purchases and App Review remain open.
See the [collection handoff](../skin-collection-20261001/README.md).

## Latest release follow-up

The user resumed AdMob and completed local Google verification for
`chenxi.qu.work@gmail.com`. Its existing publisher profile is accessible and
reports normal account status, but payment setup is incomplete. This follow-up
did not create a new publisher account. The iOS application **Black Hole Feast:
Eat & Grow** was created as not yet listed in a store, followed by **Rewarded -
Double Round Coins**, an optional rewarded ad delivering one round coin bonus.
Console success states and the saved ad-unit row were verified. Exact
identifiers and account screenshots stay in ignored build evidence. No email
instructions were sent. Mainland China remains the user-confirmed residence /
payment country; Asia/Shanghai account time alone does not verify payment
country. The older Hong Kong signup remains unresolved and was not closed.

Fresh isolated 0.12.2 build 4 at `build/ios-native-polish-20261001-04/` compiles
and links with the verified production app and rewarded-unit identifiers, no
sample advertising identifiers in its effective configuration, and all 50
buyer identifiers from Google's current SKAdNetwork integration example. Its
exported PCK passes 202 monetization/device/lifecycle desktop assertions. All
803 guarded Web inputs and both original vendor privacy manifests remain
unchanged. Original test candidates and build-3 evidence are preserved. The
production candidate is unsigned, uninstalled and not uploaded; no production
ad request or physical SDK callback is claimed. See the
[production receipt](../../artifacts/monetization-20261001/account-followup/production-04/production-candidate.json).

The exact Google-provided authorized-seller line was published at the existing
support Site's `/app-ads.txt`, preserving its public audience and existing pages.
Site version 2 deployment succeeded. This does not establish Google crawl /
verification: the game must first be listed and associated with its store, and
the App Store marketing URL must point to this developer website. The current
public privacy policy still describes the separate no-SDK baseline.
The public suffix list includes `chatgpt.site`, so the developer hostname has
one subdomain above its registrable domain. Native publication and the local
archive's exact app-ads line match the pushed source. An independent HTTP read
could not be completed: the Web reader was unavailable, local TLS reads failed,
and browser navigation was blocked by the client. No access restriction was
bypassed. Do not equate this deployment receipt with Google's crawl acceptance.
Local gzip and server-reported saved tar hashes describe separate archive
representations; both are retained in the publication receipt.

**Hole Feast - US Privacy Choices** is saved and visibly listed as an English
(United States) draft, associated with the game and targeting all currently /
future supported US states. It was not published. The app selector initially
failed to load; one retry restored it and the failure capture is preserved.
Before publication, reconcile its default wording with the adapter's disabled
personalization, complete final monetized disclosures, and verify the native
privacy-options entry point. No ATT pre-prompt or European launch was enabled.

Google's current [signup instructions](https://support.google.com/admob/answer/7356219?hl=en)
require the actual country of residence and any existing publisher account to
be used appropriately. Its [signup-error guidance](https://support.google.com/admob/answer/7356424?hl=en)
does not permit duplicate AdMob accounts. Check the effective publisher state
before completing signup; closure of a financial account must be handed off to
the user. Any new legal acceptance also requires confirmation at that action.
The payment-profile form is retained for the user. Address fields were empty
when opened. The user asked the agent to fill a previously known address, but
the current handoff has no complete address, and submission of a financial
account requires user handoff under the Computer Use policy. No payment data
was entered or submitted and no new legal terms were accepted. Credential
values and authenticated URL query strings are absent from these documents.
Native signing/phone acceptance, Apple purchases, final privacy declarations,
screenshots and App Review remain outstanding.

## Earlier manual iteration

On October 1 the user deferred AdMob account setup and resumed game iteration.
The latest 0.12.2 device-test snapshot preserves the existing adapters and
official test IDs; its native PCK passes 413 desktop-engine checks, but signing
and physical callbacks remain unverified. No advertising account changes,
production configuration or privacy publication occurred during this turn.
See [current manual iteration](../native-polish-20261001/CONTINUATION.md).

The public support contact has not changed. The later release follow-up above
supersedes the earlier account-setup deferral without changing historical test
evidence or production identifiers.

The user authorized adding real Google ads and Apple consumable purchases before publishing privacy disclosures. The existing 0.11.2 upload is a separate no-SDK baseline; it is not a monetized release.

The new native adapter uses the official Google Mobile Ads 13.11.0 and User Messaging Platform 3.1.0 SDKs and StoreKit 2. SDK archive checksums match the official Google Swift-package manifests. The Objective-C++ singleton bridges drain native events on the Godot thread. Consent is updated before ad requests; rewarded coins require the SDK earned callback. StoreKit verified transactions are deduplicated and saved atomically with the wallet before acknowledgment and finishing. Observer-first purchase completion received an additional regression check.

An isolated link-only prototype successfully compiled and linked both SDKs and StoreKit using the preserved 0.11.2 PCK. It was not installed, uploaded or released. The guarded 0.12.0 Web baseline passed 53,903 source and packaged checks in 78 suites, with 798 unchanged inputs. Web tests do not exercise native SDK callbacks.

The current 0.12.1 source includes the requested device fixes and food-map
iteration. Its 79-suite Web gate passes 54,291 source and packaged assertions
with 802 unchanged inputs. A fresh arm64 candidate compiles and links both
Google SDKs and StoreKit 2; development signing remained blocked on the user's
local keychain authorization and was cancelled at the overnight deadline.
The four-hour automation is now PAUSED; this candidate is not installed or uploaded.
The native configurator rejects test identifiers in production mode. This
candidate uses Google's official test app and rewarded-unit IDs only.

## External requirements

AdMob signup was initially set to Hong Kong from the user's answer. The user subsequently confirmed actual residence and payment address in mainland China. The signup now requests a matching Hong Kong phone and exposes no region-edit control. No phone verification, production app ID or rewarded-unit ID has been completed. Resolve this through Google's official account-country guidance; do not use an invented Hong Kong address, borrowed verification number or duplicate AdSense account.

Apple's Free Apps Agreement is active. The Paid Apps Agreement remains New and asks for legal-entity review first. The legal-entity address editor was opened for the user. No new Paid Apps Agreement acceptance, bank information or tax filing was performed. Those account steps need the user's truthful information and any required agreement authorization.

The 320 Coins consumable draft exists with product ID `sink_city.coins_320`, English localization and US-only availability saved. A USD 0.99 price attempt failed with an Apple server error and was not saved. The other two products, pricing, review screenshots, sandbox purchases and transaction replay on a physical phone remain open.

The App Store Data Not Collected draft was not published after the user requested monetization. Reconcile the final SDK configuration and Google's current disclosure guidance, update advertising/age information and review notes, and publish only an accurate declaration. The current public policy describes the separate no-SDK 0.11.2 baseline; update it for the verified monetized candidate before release.

## Evidence

The unchanged arm64 SDK privacy manifests were audited. Google Mobile Ads
declares coarse location, device identifiers, advertising data, product
interaction, crash, performance and other diagnostic data; its device-ID entry
is marked linked and used for tracking. UMP declares coarse location,
performance and product interaction for app functionality. The original vendor
files must remain packaged; do not remove their declarations to obtain a
no-collection label. Their SHA-256 values are
`69fb112582fc23fc06c635c961d262a3f7b4b5654d284787491de3000dadf9d2`
and `45b7adb99fcd2d962a1c800fbfcc1325b57a7fa4165f416182323bb5ffe9c900`.

The adapter disables publisher first-party ID and personalization, requests
nonpersonalized ads and never requests ATT access. These configuration choices
do not establish zero SDK collection. Before publishing App Store labels,
reconcile the effective configuration with the final native privacy report and
[Google's disclosure guidance](https://developers.google.com/admob/ios/privacy/data-disclosure).
No tracking declaration was silently changed. Production app/unit identifiers,
consent-message account setup and native callback acceptance remain outstanding.

Local ignored build evidence is under `build/monetization-20261001/`, including dependency checksums, the failed first prototype and the successful second link. Public regression evidence is under `artifacts/monetization-20261001/web-gate/`. Account screenshots and private legal/device information stay in ignored build directories.
