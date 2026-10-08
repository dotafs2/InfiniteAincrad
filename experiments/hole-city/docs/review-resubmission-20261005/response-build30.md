# Guideline 2.1 response — version 0.13.0, build 30

Status: prepared locally, not sent. This supersedes the old build 26/29 response
for the next submission. The official build 30 upload succeeded on October 4 at
16:25:45 UTC. Apple processing, the new product's configuration and the recording
below still require positive evidence. Do not send unresolved placeholders.

## Proposed App Review reply

Hello App Review Team,

Thank you for your Guideline 2.1 information request for Black Hole Feast: Eat &
Grow, submission 09f163eb-1c42-49cf-9643-366c13bb8680. We have uploaded version
0.13.0, build 30, which includes three freely selectable worlds. Below are the
requested details for this version.

1. Physical-device demonstration

[REQUIRED: insert the inspected recording attachment or accessible link, actual
device/OS/build, and timestamps for launch, gameplay and paid-feature access.
Record build 30 on the current public iOS release. Do not substitute Mac footage,
older build 27 footage or a staged test-provider purchase.]

2. Purpose, audience and value

This is a single-player casual arcade game for people who enjoy short collecting
and growth sessions. The player moves a black hole, swallows objects that fit,
grows and competes against computer-controlled rival holes. Sunny City, Snack
Garden and Bubble Toy Town offer distinct city, food and glossy block-castle
worlds. Players can freely choose a different world on HOME between rounds,
without a world-unlock purchase. The food world includes a Sushi Express train.
Progress and collectible hole skins are stored locally.

3. Setup and feature access

No app account, login credentials or sample files are required. At HOME, select
SUNNY CITY, SNACK GARDEN or BUBBLE TOY TOWN and tap PLAY. Drag to move the hole;
BOOST provides a short speed increase when charged. City and Toy Town start at
90 seconds; Snack Garden starts at 60 seconds. HOLES opens the scrolling skin
collection. SETTINGS > PRIVACY & SUPPORT opens support, privacy information and
credits. Core gameplay does not require a purchase.

4. External services

Game logic and progress run locally, without a developer-operated game server,
cloud-save service or AI service. Optional rewarded ads use Google AdMob; Google
User Messaging Platform supplies applicable privacy forms. Consumable diamond
purchases use Apple StoreKit 2 and Apple's purchase sheet. Ad requests use the
non-personalized option, with publisher first-party ID and publisher
personalization disabled. Google SDK data processing is disclosed in the privacy
policy and App Privacy information; non-personalized ads do not mean no data
collection. Network and provider availability may affect ads and store offers.

5. Regional differences

The intended initial release is United States only. The three worlds and core
gameplay have no country-specific content branches. Purchase prices come from
Apple's live catalog; ad availability and applicable privacy forms depend on the
provider and region. [CONFIRM the app and all current products are configured for
the United States before sending; replace this marker with the verified scope.]

6. Regulated services and third-party material

The app provides casual entertainment and does not offer a regulated service.
Its game models, UI and skins are original, including the Blender-authored block
castle buildings. We do not include proprietary assets from reference games.
Retained licenses and credits cover the MIT-licensed Godot engine and template
code, the Fredoka font under the SIL Open Font License, and CC0 Shop Theme music
by Cleyton Kauffman. Credits are accessible in PRIVACY & SUPPORT.

7. In-App Purchase and paid-feature navigation

HOME > STORE > DIAMOND SHOP displays consumable packs of 100, 360 and 1,800
diamonds. Prices are obtained from StoreKit; purchases use Apple's payment
interface. Verified transactions credit the corresponding diamond quantity to
the local wallet. [REQUIRED: configure sink_city.diamonds_100, confirm all three
products return real metadata, and insert the actual Sandbox purchase result.]

In STORE, 100 diamonds exchange for 250 coins, 250 for 625, and 1,000 for 2,500.
In HOLES, UNLOCK RANDOM costs 50 coins; RATES displays the probabilities and
guarantees before spending. One normally completed round with a positive score
awards exactly 50 coins. On eligible result screens, 10 diamonds can increase
the round reward to 1.5x (75 coins) or continue the same round for 30 seconds.
Each option is available once; continuing does not grant a second finish reward.
Optional rewarded videos provide alternatives to these two offers. STORE also
has an optional rewarded video for 3 diamonds. Video controls remain disabled
until an ad is ready, and video length is controlled by the ad provider.

Diamonds and coins have no cash value, are not transferable, and do not represent
real-money winnings. Consumable currency is saved locally; we do not claim a
cross-device wallet restoration feature.

Best regards,
Chenxi

## Evidence and submission conditions

- Successful upload: `artifacts/testflight-20261005-30/upload-verified.json`.
- Accepted native package: `artifacts/testflight-20261004-30/archive-acceptance.json`.
- Current economy: `docs/fairytale-city-20261004/economy.md` and frozen game code.
- Current phone was build 27 on iOS 26.7.1 at the initial read-only check. Its
  complete Documents backup succeeded (44 files, 9,757,314 bytes). Build 30 was
  subsequently installed as an update; another immediate before/after copy proves
  all 44 Documents files identical. See the actual installation receipt at
  `artifacts/review-resubmission-20261005/device30-installed.json`. There is no
  current-OS recording or ordinary-launch receipt yet.
- The user explicitly authorized the current iOS update agreement and update.
  iOS 27.0.1 finished downloading, and Finder now waits for the passcode entered
  on the physical phone. System installation/restart remains unverified.
- Create the genuine 100-diamond consumable at the user-approved target of
  USD 1.99; preserve the legacy 60-diamond SKU and receipts. Existing products
  are not proof that the new SKU is configured or purchasable.
- Verify the paid flow in the real Apple Sandbox and preserve the user's wallet.
  Test-provider fixtures and unavailable offer screenshots are not purchase proof.
- Put the completed seven-item response in both the review reply and App Review
  Information Notes. Inspect the saved text and submission receipt afterwards.
- No App Review reply, resubmission, website metadata change or Git publication
  has occurred during this preparation.
