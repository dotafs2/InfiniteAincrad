# Manual continuation after the four-hour window

The current development test candidate is signed 0.12.3 build 6 with official
test IDs and 8,547 fresh native-PCK desktop checks. Retry 02 installed it with
actual phone save bytes preserved before launch and after two physical gameplay
QA rounds. Both maps verify sixty-second play, full portrait frames and
continuous music/feedback output. Normal official-test-ad callbacks remain
unverified and the phone is now locked. Production build 5 is unchanged.
Use the [device handoff](../device-acceptance-20261001-06/README.md).

The latest account-only follow-up verifies user-submitted AdMob payment setup
as AdSense (China). Account verification and store-linked app approval remain
pending. Privacy review and website policy draft are prepared locally, without
publication or a change to 0.12.3 build 5. See the
[monetization handoff](../monetization-20261001/README.md).

## Current interface checkpoint

The user requested one vertically scrolling, low-to-high skin collection.
Source and accepted preview are now 0.12.3. All 44 stable IDs remain, and the
combined draw carries forward the stronger guarantee from each legacy tier.
The 81-suite source/Web-PCK gate passes 65,095 checks per phase; unchanged
source report reuse after two fixture-only repairs is explicitly recorded.
All 18 served files match. Actual browser review preserves level 2, 390 coins
and the owned starter. Fresh 0.12.3 build 5 compiles/links unsigned and passes
8,547 desktop PCK checks, without signing, installation or upload. Build 4
and earlier candidates remain historical evidence. No phone or SDK callback
acceptance is implied. Use the [current collection handoff](../skin-collection-20261001/README.md).
The completed timed automation remains PAUSED.

## Latest release follow-up

The user later resumed AdMob with the replacement Google account. Its existing
publisher console is authenticated; the game and optional rewarded ad unit were
created, and their real identifiers configured in isolated 0.12.2 build 4 at
`build/ios-native-polish-20261001-04/`. The candidate compiles/links unsigned,
includes all 50 official SKAdNetwork buyer IDs and passes 202 focused desktop
PCK checks. All 803 Web inputs remain unchanged; the accepted preview is
preserved. It was not signed, installed, launched or uploaded. Keep build 2 as
the separate official-test-ID device candidate and preserve all earlier output.
The support Site's app-ads.txt was published; Google's store association and
verification remain pending. The English US privacy message is a saved draft,
not published. Payment profile creation requires the user's local submission;
no new financial-account data or legal acceptance was entered. See
[current monetization handoff](../monetization-20261001/README.md). The following
manual-iteration checkpoint remains historical evidence of the prior deferral.

On October 1, 2026 the user deferred AdMob account setup and authorized further
game iteration. This is manual continuation; the completed overnight automation
remains PAUSED. No new timed task, advertising account change, App Review
submission or Git publication is authorized by that steering.

## Current work

Source 0.12.2 adds interruption-safe gameplay. The actual 0.12.1 scene reproduced
continued movement and timer loss after the application's focus-out notification:
a held real touch was still active, the timer lost 0.1833 seconds and the player
travelled 1.1534 meters over twelve unattended physics frames. Music already
stopped independently. This is an engine-notification reproduction, not a
physical iPhone observation.

The new scene pauses a playing round on either focus loss or app suspension,
clears mouse/touch steering and velocity, and freezes physics. Repeated lifecycle
events are idempotent. Focus return and app resume preserve the pause screen;
only an explicit KEEP PLAYING gesture resumes after both independent conditions
have cleared. Menu, intro and results avoid an unreachable pause overlay.
Manual pause and saved audio choices remain independent.

The focused two-map acceptance passes 70 checks using actual touch controls,
real physics frames and both notification orderings. The first fixture did not
release its initial Web audio gesture, and immediate engine exit outran its
audio mixer. Those failures are preserved. The corrected fixture enters through
the actual PLAY button and drains only its test-owned loop before exit. No
assertions or production audio behavior were weakened to obtain a pass.

The complete 80-suite source/PCK gate passes 54,361 checks in each phase under
`artifacts/native-polish-20261001/continuation/web-gate-01/`. All 803 guarded
inputs remain unchanged. All 18 actual served artifacts and isolation/no-store
headers match the receipt. The accepted port-8768 preview is now 0.12.2. Do not
repeat the full gate unless guarded inputs change or a new concern requires it.

Real browser review at 440×956 verifies PLAY, movement, the 01:00 opening,
manual pause, a frozen 00:59 timer across before/after screenshots, explicit
resume and HOME. The visible existing stage 2 / 70 coins remain. The temporary
viewport override was reset. Captures and a scope manifest are under
`artifacts/native-polish-20261001/continuation/browser/`. These are browser
images, not native phone captures. Hidden-tab creation did not establish app
focus loss, and native app selection timed out twice; no visual OS-interruption
acceptance is claimed. The actual-touch engine-notification checks above cover
the lifecycle logic, while physical acceptance remains outstanding.

## Native build and protected evidence

The resumed 0.12.1 build printed BUILD SUCCEEDED, but strict signature verification
failed because its cancelled previous build left a sealed `SinkCity.cstemp`
reference. Preserve that failure rather than treating the success marker as a
signed delivery. A fresh output directory is required for the 0.12.2 candidate.
Existing 0.11.2 baseline and original phone-save backup remain separate.

The fresh `build/ios-native-polish-20261001-02/` snapshot contains 0.12.2 build 2.
It compiles and links arm64 with the existing native adapters. Its exported PCK
passes 413 desktop-engine assertions across feedback/layout, application
lifecycle, music and the complete Shop Theme resources. PCK SHA-256:
`5a00a4c11ec6f9d195afb2ded758ea20b94712e10c3c9877ac62ebc3607ac10a`.
Both original vendor privacy bundles retain their accepted hashes. The receipt
is `artifacts/native-polish-20261001/continuation/native-0122-package.json`.
Native signing again waited for local keychain authorization and was cancelled
with its evidence preserved. The new candidate is unsigned, uninstalled and
not uploaded; native PCK tests do not establish iPhone output or SDK callbacks.

Resume from the same isolated Xcode project with a fresh unused DerivedData
directory so cancelled codesign temporary files cannot enter a later seal:

```sh
xcodebuild -project build/ios-native-polish-20261001-02/xcode/SinkCity.xcodeproj \
  -scheme SinkCity -configuration Release -destination generic/platform=iOS \
  -derivedDataPath build/ios-native-polish-20261001-02/SignedDerivedData-01 \
  -allowProvisioningUpdates build
```

The phone was paired with developer mode enabled, but its connection tunnel was
unavailable at this continuation's first and final connection checks. The user was asked to handle the
local Mac keychain prompt and reconnect/unlock the iPhone 16 Pro Max. Do not
attempt to operate SecurityAgent or enter a password through another mechanism.
Before installation, require a strict valid signature, back up the current
phone save again, install the same bundle without uninstalling, and compare its
bytes before launch. Device/account identifiers and raw saves stay ignored.

AdMob account setup is deferred. Existing native SDK/adapters and official test
identifiers are preserved for device testing; they do not constitute a
production advertising release. Native QA must not initialize those services or
settle real transactions into its disposable wallet. Production monetization,
Apple paid agreements, user bank/tax steps and final disclosures remain separate
release work.

The original closed-window handoff is [CONTINUE.md](CONTINUE.md). Current owned
sessions are recorded in ignored `build/native-polish-20261001/active-work.json`.
All owned test/GUI/signing helpers from this manual turn are stopped. Preserve
the intentional port-8768 preview service and user applications. The final
native receipt and hashes are recoverable without rerunning successful gates.
