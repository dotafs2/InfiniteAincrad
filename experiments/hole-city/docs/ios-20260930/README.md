# Local iOS project preparation — September 30, 2026

Current continuation: [signed upload and new device/monetization work](../ios-release-20260930/README.md). The project-preparation state below is a historical checkpoint.

The user completed Xcode account sign-in. The paid team was confirmed through
Xcode's team selector and its refreshed, noncredential team metadata. The
previously cached free personal team was not used. Account email addresses,
account UUIDs, raw preferences and credentials are not copied into this document.

An unsigned, uncompiled Xcode project is ready locally:

- Project: `build/ios-preparation-20260930-03/xcode/SinkCity.xcodeproj`.
- Reproducible snapshot and local identity settings:
  `build/ios-preparation-20260930-03/source/`.
- Preparation receipt: `build/ios-preparation-20260930-03/preparation.json`.
- Local draft Bundle ID: `io.github.dotafs2.sinkcity`; not registered with Apple.
- Version/build: `0.11.1` / `1`; iPhone, portrait, minimum iOS 15.0.
- No signing identity, provisioning profile, App ID or App Store app was created.
  No compilation, archive, IPA, installation or TestFlight upload is claimed.

## What was verified

The isolated copy contains 752 runtime source files. Only its project settings
gain mobile ETC2/ASTC texture imports; its separate iOS preset enables
project-only export. The original Web project, export presets, game resources
and all 791 release input hashes remain unchanged.

Godot exported 47 native project/resource files. `xcodebuild -list -json` reads
the actual project successfully and finds the SinkCity target/scheme with Debug
and Release configurations. This is a project parse check, not a build.

The generated privacy manifest is valid XML/plist and included in the Xcode
Resources phase. It declares no tracking and the engine's local file-time,
boot-time and disk-space reasons. Store privacy answers and SDK behavior must
still be reviewed before submission, especially if advertising or IAP SDKs are
added. The 16 app icon PNGs are opaque RGB, including the 1024-pixel icon; they
derive from the existing original SVG. The iPhone arm64 engine library is
present and its actual archive architecture is arm64.

Independent review found an upstream template limitation: its simulator
Info.plist advertises both arm64 and x86_64, but the actual simulator engine
archive contains only x86_64. Apple Silicon arm64 simulator support is therefore
unverified and cannot be claimed. Keep this discrepancy visible; use a corrected
official template or a matching source build before native simulator acceptance.
No metadata was altered to conceal it. The intended physical iPhone target has
the correct arm64 library, but native linking and execution still need validation.

The native PCK is 10,555,176 bytes, SHA-256
`cee0c5f49200859f4fc023b5d966111894e81219aade2f1d52b15e4784f7e2c6`.
Its platform-specific imports make it a different artifact from the verified
Web PCK. Web test results do not prove native rendering, signing, device support
or sustained iPhone 14 60 FPS.

## Template and failed attempts

The standard Godot 4.7.2 iOS template was retrieved from the
[official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
Its SHA-256 is
`fd3280d10dc75356dded006f6f8813f40a5aebd32d128592b781256d8ffbdff4`.
The template member and all inner ZIP member CRCs were verified. Only that
member was downloaded using HTTPS byte ranges; the complete template archive's
published SHA-256 was **not** verified. The pre-existing Mono template differs
and was neither substituted nor overwritten. Provenance is in
`artifacts/ios-20260930/template-provenance.json`.

The same standard ZIP was installed in this game's isolated portable editor:
`.build/godot-standard/editor_data/export_templates/4.7.2.stable/ios.zip`.
It does not change the user's global Mono installation.

Two failed attempts remain intact for diagnosis:

1. `build/ios-preparation-20260930`: Godot reports the missing installed standard
   template even though custom template paths point at the verified file.
2. `build/ios-preparation-20260930-02`: the iOS exporter rejects missing mobile
   texture imports with an empty configuration error. The corresponding upstream
   validation branch was checked. Enabling ETC2/ASTC in the isolated snapshot
   fixes it without modifying the original Web project.

The third attempt succeeded; error handling was retained. The helper
`tools/prepare_ios_project.py` refuses an existing destination, verifies the
template/version, rejects runtime symlinks and checks original release inputs
before and after export. To reproduce, supply the actual team ID and a new
output directory below `build/`; retain project-only mode.

## Mac toolchain continuation

After the user confirmed restart completion, `sw_vers` verified macOS 27.0.1
(26A434). The official App Store update replaced Xcode 16.2:
`xcodebuild -version` now reports Xcode 27.0 (27A266a), and the new application
launches successfully. Its first launch is paused at the Xcode and Apple SDKs
Agreement (EA2002, June 8, 2026), awaiting the user's explicit confirmation.
`xcodebuild -showsdks` exits 69 because the license is not accepted, and
`xcodebuild -checkFirstLaunchStatus` also exits 69. SDK/component readiness and
native compilation remain unverified. All 791 Web source inputs and 47 native
export files were independently rehashed unchanged after restart.

The earlier host had macOS 14.5, Xcode 16.2 and iOS SDK 18.2. Apple requires
Xcode 26 or later and iOS SDK 26 or later for App Store Connect uploads since
April 28, 2026. See Apple's
[upload requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)
and [Xcode system requirements](https://developer.apple.com/xcode/system-requirements/).

The user subsequently explicitly approved the system update. At approximately
03:09 UTC on September 30, Upgrade Now was pressed for macOS 27.0.1 (14.8 GB)
and its installation license was accepted. The complete 14.80 GB download then
finished. At the latest pre-restart observation, the actual Software Update UI
showed "Preparing macOS 27.0.1", with about 30 minutes remaining. That earlier
checkpoint did not yet verify installation or restart; the post-restart check
above now confirms completion. Any administrator authentication
must be entered locally by the user. After the approved system upgrade, verify
the installed OS version, install a supported stable Xcode and iOS platform SDK,
and recheck the selected command-line developer directory.

The user also requested automatic reopening after the update. Both Clash Verge
and Codex were added through System Settings > General > Login Items and verified
in the actual Open at Login list. Codex is installed as
`/Applications/ChatGPT.app`, with bundle identifier `com.openai.codex`; that exact
application was selected. The existing Steam entry and background permissions
were retained. These are login items: they run after normal user login, do not
bypass system authentication, and do not establish a guaranteed launch order or
automatic continuation of an interrupted agent turn. No proxy settings changed.

Then confirm the final Bundle ID, configure signing, compile and run both maps
on iPhone 14, and prepare a TestFlight build. The browser's existing developer
website account differs from the account verified in Xcode; switch to the paid
account before App Store Connect setup. Do not enroll or pay again.

The existing [publication plan](../release-20260930/launch-plan.md) still applies:
permanent in-game credits, public privacy/support details, real native device
acceptance and accurate store metadata remain required release work. No Git
commit/push or public submission occurred.
