# Physical-device App Review evidence plan — October 3, 2026

Status: preparation only. No recording, phone command, purchase, account change,
App Review reply or upload was performed by this task. Root owns execution.
The user now authorizes completing Guideline 2.1 materials and including the toy
castle map in a subsequent upload. The old submitted 0.12.7/build 26, its rejected
review observation, local IPA and all earlier device evidence stay immutable.

## Evidence boundary

Record the exact accepted native candidate root will upload, including Bubble
Toy Town if that candidate includes it. Record its actual version/build, bundle,
PCK/executable/signature receipt and the real physical device model/OS. A new
candidate demonstration is not a recording of build 26. Update the existing
reply/Notes draft's version and two-map wording to match the actual recording.
The current local old-phone observation is 0.12.4/build 16; current connection is
reported unavailable. None of that establishes current installation or latest OS.

Use a current public OS release appropriate for the phone. Root must verify the
actual installed version and any available required update before describing it
as the latest OS. This plan does not infer an OS version from a device name or
from the Mac SDK. Keep device/account identifiers in ignored evidence only.

## Installed recording capability

On this host, the installed official `xcrun devicectl` help exposes
`device capture screen-record`. It records directly from a device to an MP4;
`--duration` ends and saves automatically, and Ctrl+C also ends and saves. Help
only was run: physical-device availability and successful encoding are unverified.

Root can use a fresh ignored attempt directory and this exact interface, replacing
placeholders with its private known target and absolute paths:

```sh
xcrun devicectl device capture screen-record \
  --device '<private paired target>' \
  --destination '<fresh ignored attempt>/review-launch-flow.mp4' \
  --codec h264 --mask-policy ignored --duration 480 --timeout 510 \
  --json-output '<fresh ignored attempt>/recording-result.json' \
  --log-output '<fresh ignored attempt>/recording.log'
```

This is a command template, not an executed recording or proof of device support.
Use an owned process receipt, a bounded duration and new paths; devicectl overwrites
existing output files. The primary display is selected unless a verified
`--display-unique-id` is supplied. Help documents no audio-selection flag, so
inspect actual audio tracks before making a sound-capture claim. Do not promise
that protected payment/SDK screens will be captured without inspecting the file.

Root should begin recording on the unlocked Home screen, then launch by tapping
the app or by a separately receipted ordinary `device process launch`. Do not use
`--test`, QA wallet arguments, forced score/radius, a StoreKit configuration, or
`--start-stopped`. Avoid `--console` for the ordinary capture: its documented
signals forward to the game and cancellation could terminate it. Recording itself
is separate and should not stop the game.

`device capture screenshot` is also installed for actual PNG stills. It is not
video evidence. `tools/device_qa.js` records browser requestAnimationFrame cadence
only for City/Food; it neither records native video nor establishes native phone
performance. `pymobiledevice3` was not found in current PATH or current Python;
no workspace-wide environment search or package installation was performed.
Inspected devicectl help provides no touch or purchase-sheet interaction command;
its simulate subcommands are biometrics, location and statusBar. Do not use those
to fake paid-flow proof. Human phone interactions or an explicitly supported UI
surface are still needed for the walkthrough and sandbox authentication.

If direct recording is unsupported on the connected phone, Apple's documented
fallback is wired QuickTime Player: File > New Movie Recording, select the
connected iPhone as the camera, start before launch and save the movie. A second
fallback is iPhone Control Center screen recording and transfer the original
Photos video. Do not combine iPhone screen recording with mirroring. Root owns
any UI action; no mirroring implementation is reverse-engineered.
[QuickTime connected-device recording](https://support.apple.com/guide/quicktime-player/record-a-movie-qtp356b55534/mac),
[iPhone screen recording](https://support.apple.com/en-us/102653).

## Preserve saves before installation and prove the actual package

1. Obtain a successful immediate complete Documents copy to a new ignored backup,
   including `reference-first-level.cfg`, before replacing or launching the app.
   Verify the command JSON, file inventory and bytes; a folder's existence alone
   is not backup success. A live save must be quiescent or checked for consistency.
2. Root's signed-device helper must verify current accepted gate/source/native/PCK
   bindings, current signature/profile, same bundle and actual installation result.
   Install as an update without uninstalling. Compare exact pre-install and
   post-install save bytes **before** ordinary launch. Abort on unexplained change.
3. Preserve the original backup after gameplay. Normal play and sandbox purchases
   can legitimately add progression/receipts; those changes need their own later
   snapshot, not a false post-play equality claim. Never restore an older backup
   over a successful purchase ledger or clear the real wallet for a clean video.
4. Retain the installed build result and positive ordinary-launch PID. Show the
   actual icon and full safe-area interface; inspect all final recorded frames.

Installed `device copy from` supports `--domain-type appDataContainer`,
`--domain-identifier <bundle>`, `--source Documents` and `--destination <fresh
backup>`. No `copy to`, deletion, uninstall, device query or installation was run
by this task. Existing exact root-owned backup/compare helpers take precedence
where they add required signature or save protections.

## One continuous reviewer walkthrough

Start at physical launch and show normal HOME. Open SETTINGS > PRIVACY & SUPPORT
and return, then show the map chooser and each actual playable map. Demonstrate
ordinary dragging, swallowing, growth, BOOST, timeout/results and return HOME.
For the toy candidate, show Bubble Toy Town and an actual intact palace falling
into the hole. Use real play and preserve any failure; do not cut a staged growth
fixture into the demonstration or label desktop footage as iPhone footage.

Show HOLES scrolling/selection and STORE > DIAMOND SHOP, including Apple's real
localized offers. Demonstrate a genuine sandbox purchase, actual diamond credit
and one applicable diamond use. Show the three products if the catalog returns
all of them. A single successful pack demonstrates the paid flow; separately
record which packs remain untested. Cancel one sheet and verify no grant if time
allows. Rewarded ads are optional: document readiness/network failure truthfully
rather than blocking launch evidence on an unrelated unavailable provider.

Keep passwords, verification codes, sandbox account email and notifications out
of the public attachment. Preserve the original privately; a share derivative
may redact personal details without changing game state, purchase outcome or
failure visibility. Include a time-indexed walkthrough and SHA-256/size/duration/
codec/dimensions in a safe receipt. A video shows visuals, not tactile haptics.

## Genuine Apple sandbox purchase prerequisites

Use a development-signed app or the actual TestFlight candidate, with Xcode local
StoreKit Testing disabled. Apple sandbox uses real App Store Connect product data
and does not process charges. Development-signed apps need a same-team Sandbox
Apple Account; the Sandbox sign-in appears under Settings > Developer after the
first purchase attempt. There is no need to sign out of the user's ordinary Apple
Account for this development route. Confirm the purchase sheet identifies
`Environment: Sandbox`; stop if the sheet indicates production. TestFlight
purchases use sandbox, but changing its test controls has a different account
workflow. Prefer the development route without changing the user's media account.
[Apple sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

Confirm exact explicit bundle/IAP capability, valid signing/profile, membership,
active Paid Apps Agreement and required active bank/tax forms. The last verified
Business snapshot was Active; treat it as a recorded snapshot, not a fresh query.
Product reference name, identifier, localized name and price must exist. Review
approval is not required to sandbox-test; metadata can take up to an hour to
propagate. These are Apple prerequisites, not reasons to recreate completed
products or ask for financial forms again without a concrete new failure.
[Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox).

| Existing product | Amount | Last verified US price |
| --- | ---: | ---: |
| `sink_city.diamonds_60` | 60 diamonds | US$0.99 |
| `sink_city.diamonds_360` | 360 diamonds | US$4.99 |
| `sink_city.diamonds_1800` | 1,800 diamonds | US$19.99 |

The table records prior actual account metadata. Runtime purchase prices must
come from StoreKit's live `displayPrice`; it does not certify today's catalog
response. Use a US sandbox storefront for the recorded US-only availability.
Retain legacy coin IDs and verified unfinished delivery; do not rename them.

## Actual paid-flow proof and bounded recovery

Before purchase, privately snapshot the existing currency and redeemed ledger.
Without a wallet injection, buy an available pack through the actual Sandbox
sheet. Preserve both the visible result and a subsequent Documents snapshot:
that exact product must add its configured amount once and one product-bound
entry to `[rewards] purchases` (`redeemed_transactions` in game code). Cancelled,
pending or failed purchases give no credit. Ordinary relaunch must preserve the
saved balance/receipt without granting it again. Do not publish raw balances,
transaction IDs, sandbox credentials or full saves.

Current Swift accepts only verified, allowed, non-revoked consumable transactions
with quantity one; game code saves currency and the redeemed ledger before native
acknowledgement schedules `Transaction.finish()`. This source inspection is not
an actual sandbox callback, finish or crash-recovery receipt. Native events do
not currently expose the transaction environment or signed payload; a game ledger
alone cannot independently prove the environment. Bind the controlled signed
build/no-local-StoreKit setup and actual Sandbox sheet with the transaction result.

The current three packs are consumables. They are absent from
`currentEntitlements`; `unfinished` exposes an order until `finish()`. Recovery
can redeliver an unfinished verified order, but cannot reconstruct already spent
or finished diamonds across devices. Do not claim a Restore Purchases control or
cross-device wallet that the app does not implement. Deliberate interruption,
save-write faults and native finish/replay verification need an isolated account/
wallet and their own explicit test evidence, not destructive tests in this real
save. A normal successful purchase/relaunch is sufficient for the core reviewer
walkthrough; record those extra recovery checks as pending if not executed.
[Apple currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements),
[Apple unfinished transactions](https://developer.apple.com/documentation/storekit/transaction/unfinished).

## Close the information request truthfully

Root verifies the entire original recording, actual build/OS and paid-flow results,
then inserts the real recording reference and exact tested scope into the reply
and App Review Notes. Update the six written explanations to three playable maps
only after that candidate is accepted and installed. If catalog or sandbox fails,
retain the exact failure and diagnose it; do not substitute the previous
UNAVAILABLE screenshot or headless transaction fixtures as successful paid flow.
Save-before-ack/replay source checks remain separate from physical evidence.
This document authorizes no extra system-security, legal or financial action.
