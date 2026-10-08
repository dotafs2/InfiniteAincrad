# Build 30 App Review continuation

## Superseding October 5 score change

The user subsequently requests 1,000 points = 100 coins and imports the physical
video to Desktop. New source work and the exact inspected 963-point result are
tracked in [score reward continuation](../score-coins-20261005/CONTINUE.md).
Build30 remains the uploaded old fixed-reward build; do not submit its old
50-coin promise as the newly requested behavior. Phone reconnection is not
requested. The actual video lacks Diamond Shop/payment footage.

## Latest checkpoint: user-completed OS update verified

The user's completed update is now independently confirmed by Apple devicectl
and the physical Device Hub view: iPhone 16 Pro Max, iOS 27.2 (24B5089g),
releaseType **Beta**, Developer Mode enabled. The installed game remains
0.13.0/build 30. Do not describe this OS as the latest public/stable release,
repeat the update, downgrade, or restore the phone. Safe receipt:
`artifacts/review-resubmission-20261005/post-user-update-device.json`.

The phone is currently locked: lockState reports passcodeRequired=true and the
actual Device Hub screen shows the lock screen. A new pre-launch Documents copy
timed out after 30 seconds; its output remains in ignored
`build/review-resubmission-20261005/post-user-update-01/`. No game launch or
reinstallation followed this failure. Prior complete 44-file save backups remain
intact. The user has been asked to unlock and keep the physical phone connected.
Use a fresh attempt directory for the next save copy and recording; preserve the
failed attempt. Device Hub's native View Screen now works and may provide normal
physical-device controls after unlock. An ordinary recording still needs to be
made and inspected; none is claimed yet.

The user explicitly selected Chrome after IAB repeatedly timed out. Chrome's
browser connector is unavailable, but native Chrome accessibility works and
shows the actual Apple login page. A dedicated new tab is open at the build30
TestFlight URL and [private developer account] is entered. Existing credential autofill
did not fill the password. The user has been asked to finish Chrome login and
two-factor authentication directly in Apple's page. No credentials were read or
extracted. No Apple product/metadata/review mutation has occurred. Current native
CUA bindings are `releaseChromeApp` and `releaseDevices`; reinitialize normally
if the kernel resets. The older states below are historical, superseded here.

## Previous checkpoint: Mac cleanup after failed system backup

Finder's first authorized OS update attempt failed during full-device backup:
it explicitly reported insufficient Mac space. Root acknowledged the error and
declined optional Apple diagnostic sharing. A subsequent actual devicectl details
query still reports a booted connected phone on26.7.1. Do not claim27.0.1 installed.
The user was offered the official on-phone Software Update route, then requested
Mac junk cleanup. The current Finder window no longer lists the phone; a new OS
update has not been started after cleanup.

Cleanup really reclaims45.525GB, increasing available space from49.120GB to about
94.648GB. Removed only six obsolete Xcode device-symbol caches, inactive C/C++
index data, pip/Homebrew caches, two old Mendeley update caches and the downloaded
Xcode14.2 installer. Active Xcode27, current26.7.1 device symbols, the extracted
old14.2 app, browser data, active VSCode updater, all game artifacts and personal
files remain. Existing device backups and Trash are OS-protected and were not
accessed or deleted. Exact accepted IPA/PCK and all44 original save-backup files
are re-hashed unchanged. See `artifacts/review-resubmission-20261005/cleanup-summary.json`.
All owned scan/cleanup processes have ended. Additional free space does not yet
prove enough capacity for a full phone backup or a successful OS update.

The latest visible Apple URL is now the actual review-detail page, without the
login-failure redirect. However, binding/reading the tab still times out even
after that change; do not keep asking for a new upload or assume web edits worked.
The current native CUA binding is `cleanupFinder`. The preceding download and
preparation descriptions below are historical; this checkpoint supersedes them.

The October 5 user request explicitly resumes completion of Apple's outstanding
information request and release. This is broader than the earlier TestFlight-only
scope. Continue authorized work without asking again about ordinary upload,
review response or submission actions. New legal/security requirements still
require their specified confirmation. Never bypass SecurityAgent or the blocked
native Codex application.

## Completed evidence

- Version 0.13.0 build 30 officially uploaded at 2026-10-04T16:25:45Z. Do not
  upload it again. See `artifacts/testflight-20261005-30/upload-verified.json`.
- No newer Apple feedback was found in the bounded Gmail query. The outstanding
  request is the October 3 rejection of 0.12.7/build 26 under Guideline 2.1.
- Seven-item reply and concise Notes are rewritten for build 30 here. They remain
  local drafts with explicit physical recording and catalog verification markers.
  The old draft incorrectly described old reward amounts and old entry products;
  do not send it.
- A fresh read-only device check confirms physical iPhone 16 Pro Max, iOS 26.7.1,
  and installed app 0.13.0/build 27. Do not confuse the user-assigned device name
  with its hardware model. Wired connection and Developer Mode are available.
- Complete current Documents backup succeeded: 44 files, 9,757,314 bytes.
  An additional immediate backup precedes the successful same-bundle build 30
  Development installation at 16:53:55 UTC. All 44 Documents files are identical
  before and after installation; the app has not been launched. Safe receipt:
  `artifacts/review-resubmission-20261005/device30-installed.json`. The initial
  install helper rejected Apple's valid team wildcard profile before any device
  action; its failure is retained. The successor also verifies the exact signed
  app/team identifier and allowed profile before installation. All private
  manifests and original bytes remain in `build/review-resubmission-20261005/`.
- Finder's fresh Check for Update offers iOS 27.0.1; Apple's current release page
  https://support.apple.com/en-us/100100 also confirms it. The user explicitly
  approved the displayed software license and update. The entire 12.32 GB download
  finished. Root clicked Update and confirmed the update-to-27.0.1 dialog. Finder
  requested the phone passcode. After the user confirmed, root clicked Continue.
  Finder now displays "preparing to update". The backup prompt retained the
  existing unencrypted backup setting; no new password or security setting was
  created. No completed installation/restart is claimed.

## Current blockers and next actions

1. The authorized iPhone update is downloaded and preparing to install after
   actual phone confirmation. Keep the connected phone and original game backup
   intact; use the normal update flow, never Restore. The current CUA binding is
   `updateFinder`; re-read its fresh AX state first.
2. App Store Connect tabs still redirect to authResult=FAILED. The purpose-built
   page opener returned queued, so the user may need to switch to this chat for
   the page to appear. A fresh login is requested. Previous DOM and screenshots
   timed out; do not bypass the browser or extract authentication credentials.
3. Verify build 30 processing and the owner's internal TestFlight group once
   access returns. Verify/finish the 100-diamond USD1.99 consumable using
   `docs/fairytale-city-20261004/app-store-entry-product-draft.json`, preserve the
   old 60 SKU, and check current app/product US availability.
4. Build 30 is already installed with identical saves. After the OS update,
   recheck the actual device OS/build, ordinary launch and real Sandbox
   purchase/credit. Do not reinstall unnecessarily or reset the wallet.
5. Capture the physical current-OS walkthrough from launch, including three worlds,
   gameplay and paid-feature access. Preserve private original footage; redact
   account details only in a derivative. Mac captures do not satisfy this request.
6. Replace placeholders in the reply and Notes with actual evidence, attach it,
   select build 30 and current products, submit, and verify the resulting status.
   Availability in the public store still depends on Apple approval.

The accepted game inputs are unchanged. Do not rebuild or rerun the full gate
without a new runtime change or concrete concern. Keep all historical failures,
existing previews, saves and artifacts. No Git publication is authorized.

## Recording scope

Apple expressly requested paid-feature access, not a fabricated completed
purchase. Capture launch, HOME's three world choices, ordinary gameplay, HOLES,
STORE's actual live offers and the real Apple payment interface. Separately
validate Sandbox fulfillment before claiming it works. Distinguish Apple's
specific information request from our own paid-flow acceptance work. Do not
block a truthful reply solely to create an unnecessary claim of an exhaustive
purchase audit; do not ship an unconfigured visible entry product either.

All current helper processes have ended. Build 30 must not be uploaded again.
Prepared store copy here emphasizes switching worlds between rounds, without
unsupported competitor comparisons or in-round switching claims. The final
recording, live catalog, web metadata save and App Review submission remain open.

## Final cleanup checkpoint

A fresh actual app query after cleanup still confirms installed build30. Finder
no longer displays the phone after the failed backup; the user is asked to
reconnect and unlock it so the update UI can resume. No second Finder update
was started. Browser inventory later re-identifies the same task-owned IAB as
id2 rather than3; obtaining the actual review URL still times out after30seconds.
The kernel resets. Reinitialize the documented CUA entry point, and use current
browser inventory, not stale IDs. No Apple metadata write or resubmission has
occurred. Cleanup is complete with no owned scan/delete process remaining.
