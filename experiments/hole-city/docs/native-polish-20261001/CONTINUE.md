# Closed overnight checkpoint

The user subsequently authorized manual continuation and deferred AdMob account
setup, then resumed advertising work and requested a unified skin collection.
Current source is 0.12.3; use [CONTINUATION.md](CONTINUATION.md) and
[the collection handoff](../skin-collection-20261001/README.md) for the latest
81-suite gate and preserved production build 5. Development test build 6 is
now signed; its [device handoff](../device-acceptance-20261001-06/README.md)
records the successful installation, preserved save and two physical gameplay
QA rounds. Normal official-test-ad callbacks remain pending.
The evidence below describes
the original closed four-hour window, not the current manual build.

Deadline: October 1, 2026 at 05:48:17 Asia/Shanghai, or September 30 at
21:48:17 UTC. Scope additions stopped at the deadline. The requested heartbeat
`hole-feast-overnight-fixes` was verified PAUSED at 21:48:32.691 UTC. The final
receipt is `artifacts/native-polish-20261001/window-close.json`. This four-hour
window is closed; an unexpected later wake must not restart iteration.

## Verified work

- Current game: Hole Feast 0.12.1. Store title: Black Hole Feast: Eat & Grow.
- All 79 source and exported Web PCK suites pass 54,291 assertions per phase
  with 802 unchanged inputs. The complete receipt is
  `artifacts/native-polish-20261001/web-gate-05/release.json`.
- Native startup/Playback audio, soft gulp/light haptic receipt routing, saved
  haptic choice, 60-second rounds and expanded safe-area layout are implemented.
- Original food stacks retain the 59-body heap and original geometry budgets.
  Two cake landmarks, renderer-correct ingredient colors, actual dark hole
  interiors and nonembedded rain spawning are verified.
- Twelve normal automatic rounds pass 84 checks. Food rounds end at level 5
  with scores 122–151, 70–71 larger targets and 81–148 currently edible targets
  within 25 meters. City rounds end at levels 3–4. No score, size, position,
  wallet or entitlement is granted to produce this result. This is not human
  retention evidence. The report is `artifacts/native-polish-20261001/one-minute-soak.json`.
- Native PCK desktop-engine checks pass 357 assertions. Actual backed-up phone
  save compatibility passes 27 checks without changing any old value or the
  original backup bytes. This does not establish phone audio/haptic quality.
- Five original editable 1320×2868 store drafts use authentic desktop game/menu
  frames. `store-drafts/manifest.json` records their sources and explicitly marks
  them not ready for upload. Native replacement screenshots remain necessary.
- Actual browser review at 440×956 observes a matching full-screen canvas,
  01:00 start, pause controls and a normal result; no browser warning/error was
  captured. Temporary viewport override was reset. Port 8768 is a preview
  deliverable, not an unfinished test helper.

## Signing and phone boundary

The ignored fresh snapshot is `build/ios-native-polish-20261001-01/`.
An arm64 Release build using signing disabled completed with **BUILD SUCCEEDED**,
without compiler errors. Google Mobile Ads 13.11.0, UMP 3.1.0 and StoreKit 2 link
successfully, with original vendor privacy bundles present. The verification is
`build/native-polish-20261001/native-build-verification.json`.

The development-signing attempt remained blocked on local keychain authorization
until the deadline and was cancelled during deadline cleanup (session exit 75).
No successful build/signature receipt appeared. The final owned-process state is
recorded in the ignored `build/native-polish-20261001/active-work.json` and
`deadline-verification.json`. Computer Use explicitly
refused the SecurityAgent app. Do not bypass it or use another input mechanism
for password entry. The user must handle that prompt on the Mac. The last phone
check also required its passcode. This candidate is not signed, installed,
launched or uploaded. The installed/uploaded baseline remains separate 0.11.2.

When the signing build is resumed after local user authorization, inspect the
full log and verify `codesign --verify --deep --strict` before installation. Back up the
current `Documents/reference-first-level.cfg` again, install the same bundle
without uninstalling, and compare save bytes before any launch. Device IDs,
raw saves, provisioning data and account screenshots stay in ignored build
evidence. Native QA may launch only after the phone unlocks, using
`-- --test --demo --native-qa --qa-map=food` (and separately city). Test mode must
not initialize ads or finish transactions into its disposable wallet.

If a stopped signing build needs resuming, use the same isolated project:

```sh
xcodebuild -project build/ios-native-polish-20261001-01/xcode/SinkCity.xcodeproj \
  -scheme SinkCity -configuration Release -destination generic/platform=iOS \
  -derivedDataPath build/ios-native-polish-20261001-01/DerivedData \
  -allowProvisioningUpdates build
```

This native candidate uses Google's official test ad identifiers. It must not
be uploaded as a production ad-enabled release. AdMob mainland-country signup,
Apple Paid Apps/bank/tax steps, real product prices, native callbacks and accurate
published privacy labels remain unresolved account/release work. No false
Data Not Collected declaration, new legal acceptance or App Review submission.

## Closed window and next manual continuation

The last scheduled wake remained active with waits no longer than 60 seconds
until the deadline. At closure, all 802 guarded inputs still matched the final
gate, the native PCK hash and original phone-backup bytes were unchanged, and
the new development signature was still invalid. No complete gate was rerun.
The blocked owned signing job and temporary awake helper are now stopped; their
logs and all failed acceptance evidence remain preserved. The intentional
preview server remains on http://127.0.0.1:8768/ and user applications were not
stopped. Automation prompt, recurrence and target thread were preserved while
changing status to PAUSED through the app tool.

Next device work requires local Mac keychain authorization and phone unlock,
then successful signature verification, a fresh phone-save backup, same-bundle
installation and byte comparison before launch. Complete physical music/haptic/
safe-area acceptance and replace store draft frames with native captures.
Production monetization and account requirements above remain unresolved.
Do not repeat the full gate without changed guarded inputs, a new failure or an
unresolved concern. No Git publication or subagent delegation is authorized.
