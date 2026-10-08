# TestFlight candidate 0.13.0 (30)

The user explicitly requests uploading the latest accepted castle/economy build
to TestFlight for remote installation. This authorizes the native successor,
official Apple upload and distribution to the account owner's internal tester.
No public external testing link or new App Store submission is inferred.
The accepted 91-suite Web gate is reused without rerunning unchanged tests.
Fresh actual native-PCK acceptance covers 23 suites, including modular assets,
whole-building collection, layout, saved rewards and commerce boundaries.

## What to Test (English draft)

Explore all three worlds: Sunny City, Sushi Express and Bubble Toy Town.
Try the original building-block castles, glossy roofs and royal court characters.
Check swallowing and growth from small objects to whole large castles.
Complete a normal round: the reward should be50coins, enough for one skin draw.
Check full-screen portrait layout, music, gentle item haptics and stronger rival
haptics. Check optional1.5x rewards and the once-per-round30-second continuation.
Please report crashes, missing geometry, stuttering, sound or saved-progress issues.

## Current limits

The planned100-diamond USD1.99 product has not been configured in Apple and is
not advertised as an available paid product. Native and Distribution signatures
and the successful official upload are now verified. Apple processing completion
and internal test-group availability remain unverified. Remote phone
acceptance will be performed by the user after installation through TestFlight.
Existing real user saves and earlier native builds stay untouched during upload.
Passwords, private device IDs and raw account logs remain local.

## Actual native archive acceptance

Development30 is compiled, linked and archived with a strict valid Development
signature and profile. Its exact native PCK passes all23 fresh suites/23,560
checks, zero reuse;838 accepted gameplay inputs and current native adapters
remain unchanged. The native receipt is
`artifacts/testflight-20261004-30/archive-acceptance.json`.
Controlled Distribution export is now running; this is not upload success.

## Latest blocker and recoverable resume

Distribution export session93097 is still running with a600-second bounded
command. Actual owned codesignPID12397 descends from xcodebuildPID11630 and is
waiting for local Distribution-key access; no SecurityAgent interaction occurs.
The user has already allowed the Development-key prompt, which completed30.
The separate Distribution prompt and Apple web reauthentication remain pending.
The browser login iframe loads, but Continue actions become unavailable or time
out; do not bypass this through raw account requests or credential extraction.

Fresh helpers are prepared in `build/testflight-20261004-30/export.py` and
`build/testflight-upload-20261004-30/{bind.py,upload.py,UploadOptions.plist}`.
After a real export succeeds, bind the exact archive/IPA, run--check, then the
user-authorized first--upload. Never run the uploader without actual Distribution
acceptance, or overwrite a failed attempt. Inspect session93097 before another
export; retain its timeout outputs and use a new isolated attempt if it ends.
No TestFlight download availability or new upload is claimed at this checkpoint.

## Actual Distribution export02 and first upload in progress

Earlier export01 really timed out at600s and its exact owned signer was cleaned
up. Export02 starts after the user's local authorization and officially succeeds
with Xcode exit0. Its final receipt initially refers to an archive.log in the
relocated export directory; this bookkeeping failure and earlier setup NameError
are retained. A separate read-only recovery rechecks the existing real IPA's
strict signature, Authority, App Store profile, entitlements, tested PCK and
compiled icon bytes. No native rebuild or second export follows that recovery.

Completed localIPA:40,475,254bytes, SHA256
`6592f9e968bc059b4df11df15df5b160eece23166008529f4d2cb94a56364705`.
The source remains838 exact inputs. Uploader is rebound to this actual export02;
read-only--check passes before the first official--upload. Upload session61376
uses one low-priority Xcode job and a900s bound. It is presently waiting for a
new codesign keychain access prompt. No remote upload success is inferred from
local export success. Actual fresh browser navigation still requires login.

## October 5 continuation — official Organizer attempt

Upload01 ends after its bounded900-second timeout, with no official success
receipt. Its exact owned signer is stopped; failure evidence is unchanged.
The retained official workflow ends at `IDEDistributionCodesignStep`, with no
`IDEDistributionUploadStep` or upload-completion marker. ContentDelivery logs
exist, so no claim is made that no account/network preparation occurred. Remote
build absence is not independently verified. Relevant Gmail search finds no
new30 processing/TestFlight email; email absence is not remote-state proof.

The successful Distribution export02 is retained:40,475,254bytes, SHA256
`6592f9e968bc059b4df11df15df5b160eece23166008529f4d2cb94a56364705`.
Read-only uploader binding recheck passes after opening the archive in Xcode.
No guarded runtime input changes and no repeated gameplay gate are introduced.

The user requests continuation. Browser binding/discovery times out and resets
the Computer Use runtime, but native Xcode is available. The coordinator opens
the exact verified30 archive in Organizer, visibly checks0.13.0(30), bundle and
team, then deliberately starts App Store Connect distribution. The historical
open15 project is not built or run. Organizer currently reads:
`Upload for App Store Connect: Signing SinkCity.app… Processing`.
This is the only active distribution attempt; no parallel CLI upload is started.
The separate attempt state is `build/testflight-ui-upload-20261005-30/ui-state.json`.

Human local keychain authorization is requested if its Distribution prompt is
present. SecurityAgent is never controlled, and credentials are never extracted.
Do not cancel this live UI attempt or start another uploader merely because its
signing state is unchanged. If Apple reports a duplicate build, preserve the
failure and inspect the existing remote build instead of increasing the number.
No upload success, processing completion, internal test availability or new
physical-phone installation is claimed at this checkpoint.

## Current result — successful Apple upload, October 5 at 00:25 Asia/Shanghai

The user completes the local signing prompt. Organizer advances beyond signing
but fails before upload in `IDEDistributionCreateIPAStep`: its Apple rsync sender
starts a version3.4.1 receiver which rejects `--extended-attributes`. The failed
UI attempt is dismissed; its private official logs are retained. This is a local
packaging failure, not an Apple review rejection or game-code failure.

A deliberate second CLI attempt uses the same accepted archive and the reviewed
child-only PATH `/usr/bin:/bin:/usr/sbin:/sbin`. It finishes in191.780seconds with
official Xcode exit0 and explicit `Uploaded SinkCity`, `Upload succeeded.`, and
`Uploaded package is processing.` messages. Apple ContentDelivery separately
records `UPLOAD SUCCEEDED with no errors`. Actual success time is
2026-10-04T16:25:45Z / October5 at00:25:45 Asia/Shanghai. Do not upload30 again.

The original wrapper exits1 because Xcode appends a successful `Distributions`
entry to the archive's Info.plist. This conservative check failure is retained.
Separate read-only verification proves that Info.plist is the sole changed path,
its original metadata is identical, and its new upload event says `success`,
`Uploaded to Apple`, build30. All other archive files, symbols and app bytes are
identical. Strict app signing remains valid;838 guarded inputs and the existing
23native suites/23,560checks are rebound without executing the tests again.

Sanitized exact evidence:
`artifacts/testflight-20261005-30/upload-verified.json`.
Private attempt and original receipts:
`build/testflight-upload-20261005-30-attempt02/`.
All upload processes are complete; no parallel or automatic retry remains.

The active remaining blocker is web access. Both the original and a fresh IAB
tab redirect to Apple's login-failure URL; DOM and screenshot requests time out.
Native Codex window control is explicitly denied by Computer Use and is not
bypassed. The user is asked to sign into the actual TestFlight page. Once access
works, verify Apple processing and add30 to the existing account owner's internal
test group. No new account role or public external testing link is authorized.
No processing completion, test invitation, downloadable TestFlight build, new
phone installation or App Review submission is claimed yet.
