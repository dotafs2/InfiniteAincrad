# Guideline2.1 information request — October3,2026

Status: local draft only. No App Review reply, Notes edit, attachment upload or
resubmission has been performed. The physical recording placeholder must be
replaced only with actual verified evidence before sending. This describes frozen
0.12.7/build26; the ongoing0.13.0 toy map is not part of that submitted build.

Apple's12:25 Asia/Shanghai message requests the following seven items in both an
App Review reply and the App Review Information Notes. Current iOS version status
is Rejected; three IAPs are Ready for Review. The exact safe observation receipt
is `artifacts/release-completion-20261003/information-needed-receipt-04.json`.

## Reply and Notes draft

Hello App Review Team,

Thank you for reviewing Black Hole Feast: Eat & Grow, iOS0.12.7/build26, submission09f163eb-1c42-49cf-9643-366c13bb8680.

1. Physical-device demonstration
[REQUIRED BEFORE SENDING: attach or link a verified recording of the submitted build on a physical device running the latest OS. It must start with launch and show normal gameplay and paid-feature access. Insert the actual device, OS and recording reference here.]

2. Purpose and audience
This is a single-player casual arcade game for players who enjoy short collecting-and-growth sessions. Players move a black hole, swallow objects that fit, grow and compete with computer-controlled rivals. Two original worlds, Sunny City and Snack Garden, provide city and food challenges, with local progression and collectible hole skins.

3. Setup and main features
No app account, login credentials or sample files are required. At HOME, choose SUNNY CITY or SNACK GARDEN and tap PLAY. Drag to move; BOOST gives a brief speed increase when charged. City rounds start at90 seconds and food rounds at60 seconds. HOLES opens the scrolling skin collection. HOME -> SETTINGS -> PRIVACY & SUPPORT opens the privacy policy, support and credits. Progress is saved locally.

4. External services
Core gameplay works locally without a developer-operated game server, cloud saves or AI service. Optional rewarded videos use Google AdMob, applicable privacy forms use Google User Messaging Platform, and consumable diamond purchases use Apple StoreKit2. We request non-personalized ads and disable publisher first-party ID/personalization. Google may process device identifiers, approximate location, ad/product interactions and diagnostics; the privacy labels and policy disclose this. Network/provider availability can affect ads and purchase catalog access.

5. Regions
Initial distribution and the three diamond products are configured for the United States. The two maps and core gameplay have no country-specific content branches. Localized purchase prices, available ads and required privacy forms follow the platform/provider configuration.

6. Services and third-party material
The app provides casual entertainment, with no highly regulated service. Its models, UI and skins are original. Licensed components include the MIT Godot engine and template/controller code, the SIL Open Font License Fredoka font and CC0 Shop Theme music by Cleyton Kauffman. Credits and retained license notices are available through PRIVACY & SUPPORT. No proprietary reference-game assets are included.

7. In-App Purchase
HOME -> STORE -> DIAMOND SHOP opens three consumable packs:60,360 and1800 diamonds. Prices come from Apple's product catalog; payment uses Apple's purchase sheet. Verified transactions add diamonds to the local wallet. Diamonds can be exchanged for coins in STORE, spent on a1.5x round coin bonus (1 diamond), or used for one30-second continuation after timeout (5 diamonds). Coins unlock collectible skins. Ordinary play is available without purchasing. Optional rewarded-video alternatives are shown when ready; unavailable offers are disabled.

Best regards,
Chenxi

## Required physical evidence

- Back up the device's current Documents and compare the save before any installation or launch.
- Verify the installed app corresponds to the exact submitted native build and record the actual device and OS. Do not describe old build16 or a Mac video as submitted-build/latest-OS evidence.
- Start recording from launching the app, then show HOME, both playable maps, movement, swallowing/growth, BOOST and result flow.
- Show STORE -> DIAMOND SHOP and actual Apple sandbox purchase/catalog/diamond credit, then a diamond use. Actual sandbox purchase is not yet verified; do not fabricate it or substitute an unavailable-price screenshot.
- Show HOLES and SETTINGS -> PRIVACY & SUPPORT. There is no app login, account creation or user-generated content flow to demonstrate.
- Keep device/account notifications and sensitive payment/account details out of the recording. An existing real-data save must stay intact.
- After inspecting the complete recording, replace item1 with its actual reference. Only then prepare the final reply/Notes update under the user's authorization.

## Source boundaries

The service audit reads exact frozen native source at
`build/ios-food-icon-production-20261003-26/xcode/NativeDependencies/HoleFeastServices.swift`,
matching the production receipt. GoogleMobileAds13.11.0/UMP3.1.0 are pinned;
production identifiers are present, test ads are false, PFID/personalization are
disabled, and rewarded requests carry npa=1. UMP gates canRequestAds. No ATT,
camera, microphone or precise-location permission is present. Do not equate
non-personalized ads with no SDK data collection. Rewarded coin/extension offers
settle after earned plus closed; store diamond rewards credit on earned and
remain busy until close. No live sandbox purchase success has been observed.
