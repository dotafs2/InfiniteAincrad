# Signed development candidate — 0.12.3 build 6

## Current installed and physical-gameplay checkpoint

After the user kept the phone connected, attempt 02 took another actual save
backup and successfully installed signed build 6 into the same bundle without
uninstalling. The installed-app receipt confirms 0.12.3 build 6. Save bytes were
equal immediately after installation, before launch, and again after both
isolated physical QA rounds. See
[installation receipt](../../artifacts/device-acceptance-20261001-06/installed-test-candidate.json).

Both maps finish at 60.0167 physics seconds (one 60 Hz step after sixty), with
five native 1320×2868 viewport captures each. The reported safe area is
`[P: (0, 186), S: (1320, 2580)]`. All 65 food and 64 city music samples are
playing, unpaused and unmuted; peak output reaches -19.36/-17.77 dB. Food records
56 swallow receipts including one rival, and city records 39 item receipts.
All report the enabled haptic path. Mean process-frame cadence is 16.66/16.77 ms;
P95 is 23.62/23.15 ms. These values are not direct GPU timing, a sustained-FPS
certificate, subjective listening or felt-haptic acceptance. Current native
captures visibly show the portrait game filling the viewport and real food
growth through level 5 with larger remaining stacks. A separate native device
screen capture also shows full-screen city gameplay. See
[native QA acceptance](../../artifacts/device-acceptance-20261001-06/native-qa/acceptance.json).

The user tried the video action during this isolated QA mode. It intentionally
never initializes advertising or commerce, so unavailable video in that mode
is expected. Normal mode was subsequently launched with the official test-ID
package and the actual user progress; UMP startup is observed in the local
console, but no test-ad ready/earned callback has been verified. Read-only
debugger attempts failed without returning consent values. The normal process
later ended with signal 9, whose cause is not established. A relaunch was
explicitly denied because the phone is locked. Preserve all diagnostic logs;
do not infer that production account approval explains an official test-ad
failure or that SDK callbacks have passed. The user is asked to retry the
video in ordinary play. Device/account/normal screenshots remain ignored;
one notification-containing screenshot must never become store/public evidence.

The earlier connection failure below is preserved as historical evidence;
installation is now complete. Native screenshot composition, current skin/train
frames and real SDK callback acceptance remain open. No upload/App Review,
production serving, new agreement, financial submission or Git publication
occurred. Owned diagnostic sessions completed; no blocked helper is retained.

The user reported finishing the connection step. The first device-control
listing confirmed the physical iPhone 16 Pro Max connected. Its installed
application is still 0.11.2 build 1. The actual app Documents directory was
copied to ignored evidence before any update; the save is 1,118 bytes with
SHA-256 `138bddb386464f964ff77b1093d2cf2256a64147ca83cc2a409a32565675a7ed`.
This new backup preserves subsequent user play, separate from the earlier
baseline backup. No raw save/device identifiers enter public documentation.

## Verified package

Fresh isolated `build/ios-device-acceptance-20261001-06/` contains accepted
0.12.3 source and build number 6 with Google's official test app/rewarded IDs.
The unchanged Web gate still has 804 frozen inputs and was not repeated.
The current production build 5 and every earlier candidate remain intact.
Build 6 is a device-test package, not an App Store production release.

The app compiles/links and completes development signing without automation
of a keychain prompt. `codesign --verify --deep --strict` succeeds. The exact
signed app entitlement, developer team, valid development provisioning grant,
registered test phone and profile expiry are verified. The first verifier
incorrectly expected an explicit identifier in Apple's valid wildcard profile.
Its failure and original script are retained. The corrected verifier accepts
that specific team wildcard only alongside an exact signed app entitlement,
matching team, registered device, development access and valid expiry. An
initial read used codesign's default textual entitlement format; its raw output
and parse failure are retained. A separate XML export fixes the format issue.
No signature check or device eligibility requirement was dropped.

The new exported PCK differs from build 5, so all seven relevant native-PCK
desktop suites were freshly executed: monetization, native polish, lifecycle,
collection transactions, collection touch review, UI layout and mobile preview.
All 8,547 checks pass with zero reused assertions. The PCK is 10,680,792 bytes,
SHA-256 `a1f03985ee891eed6dce60fc4a29b9d57fc7290cc5f0cb17d271d7e6aa1b0552`.
All 50 buyer IDs and both unchanged original vendor privacy bundles remain.
See [signed-test-candidate.json](../../artifacts/device-acceptance-20261001-06/signed-test-candidate.json).
Desktop PCK tests do not exercise the physical SDK callbacks.

## Phone boundary and next step

Immediately before installation, a second fresh save-backup request failed
because the device could not assert trusted connectivity/services. The current
device listing then changed to unavailable. Installation was not reached;
no application was launched, uninstalled, uploaded or submitted. The first
backup and all exact native/signing/connection logs remain ignored. No user
application or unrelated process was stopped. The owned build/verifier helpers
completed, and the local preview remains available.

The user has been asked to reconnect/unlock the phone and keep it connected.
When it becomes usable, take another current save backup, recheck the signed
package, install the same bundle without uninstalling and compare the save
bytes before launch. Record an actual install receipt and the installed
version. Then run isolated native QA with
`-- --test --demo --native-qa --qa-map=food`, and separately city. Its disposable
wallet must not initialize ads or commerce. Capture/review native reports and
images; frame/audio-output state does not prove subjective sound or haptic
quality. SDK tests must use official test ads, with no production ad clicks or
real purchases. Replace the obsolete skin screenshot draft with the current
native collection when a genuine frame is available.

Local receipt-shape compatibility must be checked against current devicectl
JSON before treating installation as accepted. Preserve failed attempts and
never overwrite prior backup/output directories. The signed candidate is ready,
but native gameplay, SDK and store-image acceptance are still pending.

The [checkpoint](../../artifacts/device-acceptance-20261001-06/checkpoint.json)
records the current connection limit. AdMob user-submitted payment setup is
complete, account/app approval is pending, and final privacy/purchases remain
separate release work. No new financial submission, legal agreement, Git
publication or automation occurred. The completed overnight heartbeat stays
PAUSED. See [monetization status](../monetization-20261001/README.md).
