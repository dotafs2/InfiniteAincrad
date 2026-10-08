# Rewarded video retry repair — October 7, 2026

## Problem

When a player changed the network route or VPN while Hole Feast remained open,
the native adapter could still be in its bounded retry backoff. The store and
result-page video controls were disabled while the adapter was not ready, so a
player had no way to request a fresh preload. The visible `VIDEO NOT READY`
state was therefore sticky even after connectivity was restored.

## Repair

- Added an optional native `retry_rewarded` bridge method.
- A retry cancels the current retry timers, resets only the transient load and
  consent failure counters, invalidates stale preload callbacks, and requests a
  fresh UMP/GMA consent/preload cycle. It never fabricates consent, readiness,
  an earned callback or a reward.
- On iOS, a supported but not-yet-ready video offer now remains tappable and
  reads `RETRY VIDEO`; the first tap starts the fresh preload. Desktop builds
  and builds without a native provider remain disabled and continue to report
  `VIDEO NOT READY`.
- All rewards still require Google's authenticated earned callback followed by
  the existing close/settlement path.

## Verification

- Native extracted Swift advertising fixture: **48 checks, zero failures**.
- Godot monetization bridge acceptance: **120 checks, zero failures**.
- Godot retention UI review: **8,242 checks, zero failures**.
- Godot collection/store interaction review: **1,905 checks, zero failures**.
- Real iOS arm64 Xcode compile with the repaired Swift and Objective-C++ bridge:
  **BUILD SUCCEEDED**. Unsigned production-configured candidate:
  `build/ad-retry-production-native-20261007/DerivedData/Build/Products/Release-iphoneos/SinkCity.app`.
- A local development-signed archive was then created and verified on disk:
  `build/ad-retry-production-native-20261007/SinkCity.xcarchive`.
  `codesign --verify --deep --strict` passed for the archived app. This is a
  device-test archive, not an App Store distribution upload.

The production candidate contains the existing production identifiers
(`ca-app-pub-1334370957457348~7521880250` and
`ca-app-pub-1334370957457348/9533800076`) with `HoleFeastTestAds=false`. It was
compiled and development-signed but not installed, uploaded, or used to request a live ad.
Live provider no-fill, timeout, consent-network, account, or VPN behavior still
requires a connected device run; this repair gives the player a direct retry
once the route is corrected.

## Source hashes

- `native/ios/HoleFeastServices.swift`: `f802630388ef7ea089de5dea0c034afeb395a4874bd48999e6a4378fd9897888`
- `native/ios/HoleFeastPlugin.mm`: `9f899ef52e3fecaa374c44204b7ca04381045305e1c778604df3670a15f60d91`
- `fidelity/ads_bridge.gd`: `2fae4f1f44b142d89fea42e73b1d5cd6e9fb757457d017c721b7abe84b53e02f`
- `fidelity/game.gd`: `d8a13b20d2ef4bedc29b4cc59c04ab2333548faa3e23d874fc9546cb89c831b2`
- `fidelity/ui.gd`: `0c9c20c2b2426a2cba6f2d5bcc3516a65c1ade8f7819ec6f1a4bf389b93d9770`
- Production arm64 executable before archive: `fcb1c2815757f2a49483516fdffb6197be8208ec5cdc64c4d62982d5f5eb26f8`
- Development-signed archive executable: `58b31289460cea83bb85f693b767600b1cc3b27bbf19b0b5ea2d54fa49aeb28c`

## Packaging correction — October 7, 2026

The first native compile candidates above reused an old 0.12.1/build-1 PCK. A
pack-loaded script inspection found no `retry_rewarded` method. These builds
prove the native adapters compile, **not** that the repaired game/UI were in
the app. They must not be installed as the completed fix.

A corrected local test package uses the frozen 0.13.0/build-31 source plus only
the retry changes, with development build number 32 and Google's test ad IDs.
It excludes the unfinished fourth map. The PCK was regenerated and verified to
contain `retry_rewarded`; pack-loaded fixtures passed 120 monetization and 25
wallet checks. Xcode build and strict deep signing verification succeeded.
Evidence: `build/ad-retry-build31-test-20261007/verified-test-package.json`.
Installation and live callbacks remain unverified because the fresh device
backup failed with a CoreDevice RSD connection error. Do not upload this
Google-test-ad package; a production distribution export is a separate step.


The later cable reconnection resolved installation: development test build 32
was installed and launched. All 74 Documents files matched before/after
installation. The three-world pack UI fixture then passed 8,226 checks; an
initial two-failure log is retained because it used fourth-world expectations.
Live SDK acceptance is still pending the renewed iPhone Mirroring security
prompt. Signing, installation, and source/PCK checks do not establish ad
playback or a successful StoreKit transaction.

## Superseding live acceptance and production export

Physical iPhone 16 Pro Max testing on October 7 at 04:05–04:08 Asia/Shanghai
verified an official Google test rewarded video. The native console recorded
consent completion, SDK start, ready, earned, closed, and next-video ready.
The actual save changed from 15 to 18 diamonds with coins (1,515) and completed
runs (12) unchanged. Evidence is in
`build/ad-retry-build31-test-20261007/device/live-ad-verified.json` and
`device/live-proof/`. No production fill or successful StoreKit transaction
is inferred from this test.

Production-configured 0.13.0/build 33 was separately archived and exported.
Strict distribution signature, App Store profile and matching tested PCK were
verified. The first export's rsync PATH failure is preserved; a system-PATH
retry succeeded. Receipt: `build/ad-retry-production-33-20261007/verified-distribution.json`.
IPA SHA-256: `6ce5a8addffa8e4ae4301d95b8140094b5e82e05be61d794ac22c263e13131c7`.
The production IPA has not been uploaded or installed.

## October 7 production upload and live commerce checkpoint

Production 0.13.0 (33) uploaded successfully at 04:29:35 Shanghai; Apple lists the processed build. Exact receipts are under `build/ad-retry-production-33-20261007/`. The matched development build 32 passed an official Google test video (+3 diamonds), a saved/relaunch-verified Sandbox +100-diamond purchase, and a second recorded +100 purchase plus 100-diamond/250-coin exchange. The paid-feature mirror video and provenance are under `build/review-resubmission-20261007/physical-paid-build32/`. Normal gameplay recording and final review submission remain pending; see the current review continuation document.
