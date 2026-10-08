# Release readiness audit — 2026-09-30

Sink City has a reproducible local Web build suitable for preparing a controlled
playtest. It is **not yet ready for App Store submission**. The recommended
sequence is a small Web test, then native iPhone testing through TestFlight;
this is a recommendation, not a selected publication platform.

This independent audit reads the delivered **v0.11.0 baseline** while the parent
task replaces the music with Shop Theme. It does not approve the pending music
build. No game/browser, device, publishing service, account, or signing identity
was accessed. No product files were changed.

## Verified starting point

`project.godot` starts `fidelity/main.tscn`, uses Compatibility rendering and a
540 × 960 portrait canvas. There are only **Web Review and Windows Desktop**
export presets. There is no iOS preset, bundle identifier, or team configuration
in these presets. The Windows preset is unsigned and still has 0.3.0.0 resource
versions; it needs separate packaging maintenance if that route is selected.

The previous delivery receipt records 76 suites and 53,788 checks in each of
the source and isolated-package phases. This audit independently confirms that
the **ten local Web files still match that receipt**, totaling 48,887,065 bytes
(46.62 MiB uncompressed). It did not repeat the tests or make HTTP requests.
These results do not establish browser rendering, audio quality, or phone FPS.
See [the delivery receipt](../../artifacts/feel-20260930/verification.json) and
[this audit's hashes, scans, inventory and toolchain output](../../artifacts/release-20260930/readiness/evidence.json).

## Concrete release gaps

| Priority and route | Observed gap | Work needed before that release |
| --- | --- | --- |
| Before public Web distribution | The active `fidelity/ui.gd` has no Credits/Privacy entry. The ten served files contain no companion license notices; the Web export excludes `third_party/*`. The old `scripts/hud.gd` Credits screen is not the active UI. | Make the project's MIT notice, font notice, exact engine/dependency notices and music credit accessible with the distributed game. Add a privacy/support entry. The Windows notice generator is reusable, but the Web release does not currently call it. |
| Before phone Web testing | `serve_review.py` binds only `127.0.0.1`. The export enables WebAssembly threads; no public secure host is configured in the inspected files. | Select a reachable HTTPS host that preserves the isolation headers, relative artifact paths and correct content types. Test a cold load on iPhone Safari, including the current desktop-only texture-compression setting. Measure delivery size/loading before promising quick mobile startup. |
| Before a performance or polish claim | No current real-iPhone acceptance receipt establishes sustained 60 FPS, audio comfort, touch response or thermal behavior. | Run the exact final build on iPhone 14 at 60 Hz, on both maps, with collapse/rain/train load and repeated rounds. Review visuals and actual listening, not just counters. |
| Before TestFlight/App Store upload | The selected developer directory is `/Applications/Xcode.app/Contents/Developer`, running **Xcode 16.2 (16C5032a)**. No iOS export is configured. | Use the currently required toolchain, matching Godot templates, a selected bundle ID, team/signing and an actual iOS archive. Account availability was not inspected. |
| Before a store listing | Existing identity is Sink City with a 128 × 128 SVG source icon. No completed iOS listing package was identified in the inspected release documentation. | Prepare validated app icons, genuine final-build screenshots, description, support/privacy URLs, age-rating answers and beta review notes. Check name availability and distribution regions once the route is chosen. Offline Blender previews are not gameplay screenshots. |

Godot's threaded Web export requires a secure context and COOP/COEP isolation.
Its documentation recommends considering single-threaded export for broader
Web/iOS compatibility. That is an option to evaluate, **not an automatic change**:
this game uses streamed music, and changing the export mode requires audio and
performance regression tests. [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

Apple currently requires App Store Connect uploads to use **Xcode 26 or later
and the iOS 26 SDK or later**. The installed selected Xcode therefore cannot
produce an eligible current upload. The SDK requirement is distinct from the
deployment target and the user's **iPhone 14 hardware** target.
[Apple upload requirements](https://developer.apple.com/news/upcoming-requirements/).
Godot's native route exports an Xcode project and requires the team and bundle
identity. [Godot iOS export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

## Assets and notices

The repository retains the mbMayer template's MIT license and pinned source
provenance. Fredoka carries SIL OFL 1.1, with `OFL.txt` explicitly included by the
export filter. City and train asset manifests record original Blender authoring
and hashes; the reviewed skin work records original geometry and reference
limits. This is provenance evidence, not a comprehensive trademark clearance.
Keep the distributable's notices accessible; a notice in an unshipped source
directory is insufficient evidence of delivery.
[Godot license guidance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).

The selected **Shop Theme by Cleyton Kauffman** is explicitly listed as **CC0**
by its author. Retain the source URL, original/download and shipped-file hashes,
any transformations, and the author's requested credit. The current baseline's
“generated audio is original” wording must be updated for this external track;
historical original-music receipts should remain historical.
[Official asset and license page](https://opengameart.org/content/shop-theme).
The replacement still needs its own decode/loop and playback regression receipt.

## Privacy and monetization scope

The bounded runtime scan found no authored HTTP client, WebSocket, analytics
upload or account flow. Progress and settings use local `user://` storage.
Microphone input is disabled. The optional `?qa=1` recorder uses an isolated test
save and exports a local JSON file containing frame intervals, user-entered
device model, browser/display details and build hashes; its inspected code has
no upload path. Static game downloads are still network requests. Future host
access logs and native SDK behavior were not inspected, so this is **not** a
blanket “no data collected” certification.

Before a native release, inspect the final archive and SDKs for privacy-manifest
and required-reason API declarations; source-only review cannot certify them.
The public policy should explain local progress, QA exports and any actual
hosting/SDK data practices. Apple requires an accessible privacy-policy link
both in the app and its store metadata, and disclosures must account for third
parties. [App Review privacy rules](https://developer.apple.com/app-store/review/guidelines/)
and [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).

Ads and paid coin packs are **integration contracts, not live services**. The
Web route explicitly cannot bind their native adapters; current UI disables
unavailable purchases/rewarded ads and invents neither prices nor earned
rewards. There is no verified production SDK/product setup in the repository.
A free beta can proceed without adding monetization. For a public beta, simplify
or clearly retain the unavailable controls; do not advertise functioning ads or
purchases. Enabling them later requires real platform verification, consent and
sandbox testing. Paid randomized skin draws also require pre-purchase odds
disclosure. [Existing bridge scope](../monetization-20260929/bridges.md) and
[Apple purchase rules](https://developer.apple.com/app-store/review/guidelines/).

## Smallest useful next validation

Finish the selected music integration and its independent review, then produce
one immutable Web candidate with accessible notices/privacy information. After
the user selects a hosting route, validate the served hashes and play that exact
candidate on iPhone. The existing [device procedure](../fixes/device-acceptance.md)
calls for ten active minutes per map, including cold load, simultaneous movement
and skill input, save/reload, background/resume, safe areas and large collapses.
The recorder measures presentation cadence, not GPU time; visual/audio and
thermal observations remain separate. Its UI currently suggests five minutes,
so use the longer documented ten-minute procedure for this release evaluation.

If iOS is selected next, resolve the toolchain/identity gaps and submit a native
beta with feedback contact and testing notes; first external TestFlight builds
require beta review. [Apple TestFlight workflow](https://developer.apple.com/testflight/).
No publication, paid service, SDK installation or account connection is part of
this audit.

## Independent launch-plan review — 2026-09-30

Reviewed [the controlled release plan](launch-plan.md), initially SHA-256
`d175f2760286b6a6a0f8f71db287d6a0857a87588e9c79f9dbd0c70c084f8e88`,
against the baseline findings and official sources cited above. This appendix
does not revise or relabel the preceding v0.11.0 audit.

The plan correctly treats Web followed by TestFlight as a planning assumption,
not a user-selected platform or authorization to publish. It invents no account,
operator, host, signing identity, revenue, or device result. The Xcode/SDK
requirements match the checked Apple guidance; the privacy and support material
remains a draft until actual operator and hosting practices are known. Device
criteria distinguish headless checks from observed visuals, audio and sustained
phone behavior.

One correction was requested: disabling caches plus replacing a deployment
atomically does not guarantee that separate HTML, JavaScript, WASM and PCK
requests cannot straddle the replacement. Cache controls reduce stale reuse;
an external deployment should pin each launch to an immutable versioned asset
directory, retain it for active sessions, and switch the entry point separately.
This is a deployment-plan issue, not a newly observed game failure.

The author corrected step 3. The revised plan, SHA-256
`209979a0f71176f715a0949c31a6e0cfcfd54373f05de2572473d831c80176ff`,
now requires immutable version directories and explicitly rejects the flat
directory/no-cache guarantee. Independent rereading confirms the correction.
No further blocking error was found in the plan. Versioned public hosting is
planned, not implemented or validated by this review; the local preview swap
remains a separate delivery mechanism.

At review cutoff the parent reports the **77-suite source/package gate is still
running**. New Web notices, credits and the Shop Theme integration therefore
remain pending final delivery verification here; the old 76-suite receipt is
not evidence for them. A credits file/loading-page link can address Web notice
access after delivery is verified, but does not itself supply a real privacy
policy, support contact, or an in-game/native privacy entry. Those remain
separate work before their respective public release routes.

This review ran no engine, browser, network probe, performance test or release
helper. Only this documentation appendix was changed; all short read-only CLI
processes exited.

## Final local delivery — root receipt

The pending v0.11.1 candidate subsequently passed all 77 source and isolated-PCK
suites: 53,843 checks per phase, 791 stable inputs and 18 matching served files.
The independent reviewer separately verified 298 package audio checks and
12 package-content checks. Credits and complete notices are now delivered at
`credits.html` and `notices/`; the old baseline's missing companion-file issue
is resolved. The link appears during loading, not as a permanent game-menu
entry. Actual privacy/support details and the native in-game entry remain open.

The verified 18,892,166-byte Web playtest ZIP is prepared locally. No external
hosting or store submission took place. These delivery receipts do not resolve
the real-device, public-host, iOS-toolchain, signing or store-material gaps above.
See [final music and delivery evidence](../shop-theme-20260930/README.md) and
[the bundle receipt](../../artifacts/release-20260930/web-bundle.json).
