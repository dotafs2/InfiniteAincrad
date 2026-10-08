# Score-based coin rewards — October 5, 2026

The latest user explicitly fixes the conversion at 1,000 points = 100 coins.
This supersedes the October 4 fixed 50-coin completion reward. Use the same
conversion for all three worlds: floor(max(score, 0) / 10), with no minimum,
finish bonus or coin cap. The starting wallet and 50-coin draw price stay intact.
A completed round grants its earned score coins; a continuation grants only the
new difference. A 1.5x video/diamond boost also tops up its additional difference
when the score grows, so using the two offers in either order gives the same
result. Old persisted receipts retain their amounts and pending bonuses.
No original wallet, save, purchase quantity or previous evidence is rewritten.

## Actual user recording

The user imported URPL5380.MP4 to Desktop and disconnected the phone. An identical
private copy is preserved under build/review-resubmission-20261005/
physical-recording-01/original.MP4. It is 163.611667 seconds at 1320 x 2868.
The inspected final Toy Town result shows 963 POINTS and the old +50 COINS.
Under the requested conversion this is 96 coins, or 144 with the optional boost.
The final frame returns to HOME at 1706 coins. Do not alter that original video
or describe it as footage of the new rule. The recording begins at HOME,
shows City then Toy play, and does not contain a Diamond Shop/payment walkthrough.
Do not claim it fully satisfies Apple's requested paid-feature demonstration.
Safe metadata: artifacts/score-coins-20261005/physical-recording-evidence.json.

## Changes and acceptance

Runtime: fidelity/game.gd, ui.gd and release_info.gd. The live HUD previews actual
score coins instead of FINISH +50 COINS. The release/support text explains the
new rule and corrects old one/five-diamond wording to the existing ten-diamond
costs. Focused isolated tests cover rounding, the actual 963-point example,
all maps, boost/extension order, duplicate callbacks, save failures and old
pending reward receipts. Full source and packaged checks are in progress;
record the exact final result below. Earlier failed assertion output is retained.

Build 30 is already uploaded and installed but still contains the old fixed
reward. Never re-upload or relabel it as containing this change. A successor
native build number is required. The user does not want to reconnect the phone;
continue local acceptance and native preparation without device operations.
The original App Review response/submission objective remains open.

Focused run02 passes 11 suites and 11,662 checks using the standard engine.
The earlier mono run fails only an outdated fixed-50 assertion; that failure and
logs are retained. The 963-point example is now a settlement regression case.
The complete new source/Web gate is running once because runtime inputs changed.

## Verified release checkpoint

The complete source and exported Web gate passes91suites and71,320checks in
each phase. All838 guarded inputs and18 served files match independent proof:
artifacts/score-coins-20261005/web-gate-01/verified-result.json. No full rerun
is needed absent changed inputs or a new relevant concern. Four muted actual
Mac GPU captures verify live963points/96coins, result96, boosted144 and the
continued1000-point/150 boosted total. They use an isolated score fixture, not
normal-play or physical-device claims. The local preview is http://127.0.0.1:8779/
and its HTTP isolation headers and exact HTML hash are checked. Preserve it.

Fresh native31 preparation and compilation reach Apple Development codesign.
The owned runner currently waits for local keychain authorization; the human
has been asked. Never operate SecurityAgent or bypass its controls. The runner
has a bounded900-second archive timeout and owned-child cleanup. Its status is
build/score-coins-native-20261005-31/completion-status.json and logs remain there.
No signed31archive, distributionIPA, upload, installation or review is claimed.

An extra old, non-gate food_review_skill_economy fixture reports two stale
expectations: shortage-button disabling (the current UI deliberately permits
feedback) and its old49-coin cold-restore balance. The updated fixture retains
the real no-charge/no-skin assertions and expects9coins. Its initial failure
is retained; run that fixture once after the owned heavy native job settles.
It is outside the91-suite registry and does not change838 accepted inputs.

The extra food/skill fixture finally passes184checks (food-review-04.json).
Its isolated old core_shell-only wallet was legitimately migrated to include
the current cocoa_square starter, causing the stale ownership-count assertion.
The fixture now uses the canonical new-player skin, retains all real debit,
shortfall, ownership and cold-wallet assertions, and expects9remaining coins.
All three earlier failures remain. The accepted838 inputs still match exactly;
this unregistered legacy fixture is not a native packaging input.

## Upload-authorized recovery — October 5, 2026

The user explicitly authorized uploading build31. Attempt01 expired after its
900-second codesign wait; its original logs and failure are preserved. No
build31 upload occurred. Attempt02 reuses the331 byte-bound exported files and
original derived compilation in a fresh archive directory; it verifies the
accepted838 inputs without rerunning the full gate. It started at01:18UTC and
again reached Development codesign. The human was asked to handle a new native
keychain prompt if shown. SecurityAgent is not operated.

Current native status: build/score-coins-native-20261005-31-attempt02/
completion-status.json. The original prepared export and compiled objects are
under build/ios-score-coins-20261005-31. Fresh recovery archive output and logs
remain isolated. Distribution export is prepared separately at
build/score-coins-distribution-20261005-31/export.py and must run only after
actual strict archive verification and23 fresh exact-PCK suites pass.

Chrome readback confirms the100-diamond product exists, is Ready to Submit,
has one selected storefront, English name100 Diamonds and description
100 diamonds for boosts, time or250coins. Product6819063987 remains unsent.
Current TestFlight availability is not verified yet. The existing user video
still lacks the payment walkthrough; no App Review completion is claimed.

Chrome TestFlight now confirms a new internal Owner Testing group
(c2d3a485-18f7-495f-b889-4aeca471587c), manual distribution, and the existing
account holder [private developer account] as its sole tester. It currently has zero
builds and explicitly shows No Builds Available. Do not claim a working
invitation or build31 download. Add31 only after verified upload and processing.
The upload helper is prepared at build/score-coins-upload-20261005-31/upload.py
but has no frozen static-readiness.json yet and has not executed. Freeze its
actual candidate/IPA/archive/options/exporter hashes only after verified
Distribution export. It permits only Xcode's append-only Distributions metadata
after upload; all app/symbols and original archive metadata must stay identical.
The first attempt's timeout must not be overwritten or relabelled successful.

## Latest continuation — October5 at03:14UTC

The user replied OK after attempt02 had already expired at01:33UTC. All previous
failed logs remain. Fresh attempt03 starts from the same331 byte-bound exported
files/derived compilation and now uses a3600-second signing bound. It reached
codesign and the human was asked to handle this current system prompt. Never
operate SecurityAgent. Native status/logs are now under
build/score-coins-native-20261005-31-attempt03.

A normal task-owned sequential continuation is already running at
build/score-coins-upload-20261005-31-attempt03/continue_upload.py. Read its
pipeline-status.json before doing anything: do NOT start a duplicate export
or upload. Once attempt03 finishes Development signature verification and23
actual native-PCK checks, it runs the prepared controlled Distribution export
from build/score-coins-distribution-20261005-31-attempt03/export.py, freezes
actual IPA/archive/receipt/options hashes, executes the one-shot preflight and
then official xcodebuild upload. It has no automatic retry and does no device,
account, SecurityAgent or App Review action. Distribution signing also has a
one-hour bound; official upload retains its900-second bound. Check its exact
result before any retry because a successful server upload can outlive a local
wrapper failure. App processing and adding31 to Owner Testing require separate
verified Apple UI actions after successful upload. This is a current release
command, not a new recurring automation; the old automations stay paused.

## Authoritative build31 upload result — October5 at03:52:53UTC

User confirmation succeeded. Attempt03 completes strict Development signature
and23 fresh exact native-PCK suites totaling23,574checks. Controlled Distribution
export succeeds, verifies Apple Distribution/App Store profile, unchanged PCK
and icon assets, and produces a40,472,623-byte IPA. Local IPA SHA256:
52d3ed6843b2c8ae3c021628004284bba68352044d34ec0c312f795eb8e13f37.
Native PCK SHA256:
5e0ccfe6eb3c5d219cc40c05751da0a0eef478fbcdc7050a92f08822ab9c5cc3.
The838 accepted gameplay inputs remain unchanged; no full suite rerun occurs.

Xcode officially uploads version0.13.0/build31 at03:52:53UTC (11:52:53Shanghai).
Its command exits0, reports Upload succeeded and Uploaded package is processing,
and appends a successful App Store upload event for31 without errors/warnings.
The local wrapper incorrectly requires an UPLOAD SUCCEEDED banner, while this
Xcode uses EXPORT SUCCEEDED even for destination=upload. Its original failure
is preserved. Independent read-only reconciliation verifies upload options,
actual metadata, original archive/app/symbol bytes, signature and all frozen
gate/native evidence. A first reconciliation helper had a date-string formatting
error; its failed source is retained, and corrected verify_upload02.py passes.
No duplicate upload occurs. All owned signing/export/upload commands have ended.

Authoritative safe receipt:
artifacts/score-coins-testflight-20261005-31/upload-verified.json.
Private original upload evidence/logs and reconciled-status.json are under
build/score-coins-upload-20261005-31-attempt03.
DO NOT use its original stopped pipeline-status.json as a reason to upload31
again. That status records a local success-parser issue, not a server rejection.

Chrome's Apple web session expired and now requires [private developer account] password.
The user was asked to sign in directly there; no credential is available to the
agent and no passwords/security dialogs are accessed. Existing Owner Testing
group c2d3a485-18f7-495f-b889-4aeca471587c contains only the account holder, with
zero builds. After login, verify31processing completion, save its test notes
(build/score-coins-upload-20261005-31-attempt03/what-to-test.txt), and add31 to
this existing group. Do not create a duplicate group or claim it is downloadable
until actual group/tester readback confirms availability. No phone is required.
Apple2.1 paid-flow video evidence, sandbox fulfillment, current store media/Notes
and eventual App Review submission remain separate unfinished release work.
