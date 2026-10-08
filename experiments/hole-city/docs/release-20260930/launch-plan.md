# Controlled release plan

Current scope: the user authorized a US-only iOS release, adopted Black Hole Feast: Eat & Grow, and subsequently required real ads/IAP before the final privacy publication. The separate no-SDK 0.11.2 build was signed, installed and uploaded. App Review submission/public release have not occurred. Current 0.12.1 source adds SDK integration and the requested device/food corrections; final tests, screenshots, production AdMob configuration and paid-app account requirements remain open.

Use [the current iOS handoff](../ios-release-20260930/README.md). Earlier preparation instructions below are historical context when they conflict with that handoff. No root Git publication is authorized.

## First candidate

Keep the existing two playable maps, current progression and original skins.
Both maps use the selected CC0 Shop Theme. The three future map cards remain
clearly marked Coming Soon. Ads and paid coin packs remain unavailable because
there are no live providers; the playtest must not advertise functioning
payments or rewarded videos. Preserve existing local progress during updates.

The guarded Web export runs every registered source and isolated-PCK suite,
checks unchanged inputs, bundles notices, and atomically replaces the local
preview only after passing. This establishes tested code and delivered bytes;
it does not establish visual polish, musical taste or mobile performance.

## Web playtest preparation

1. Use only the final contents of `build/web/`, including the `notices/` folder
   and `credits.html`. Keep the final release manifest outside the public root
   as an integrity receipt. Do not upload source, test evidence or user saves.
2. Choose a reachable HTTPS host with WebAssembly support. Every game response
   must retain `Cross-Origin-Opener-Policy: same-origin` and
   `Cross-Origin-Embedder-Policy: require-corp`. Serve `.wasm` as
   `application/wasm`, `.js` as JavaScript and `.pck` as binary. The existing
   loopback review server is not the production host.
3. Use immutable version directories, with each launch page referencing scripts,
   PCK, WASM and the QA recorder from that same version, then switch the entry
   page atomically. Disabling cache reuse for the entry page reduces stale
   launches; a flat directory swap plus no-cache alone cannot prevent separate
   requests from straddling an update. HTTP compression is useful for the engine
   and scripts; validate content encodings after configuration.
4. Draft the privacy/support page using the checklist below, configure an actual
   feedback channel, and add accessible links. The credits page is already
   separate from gameplay. Public-facing privacy/support details are pending.
5. Verify every served file against the exact candidate hashes, then cold-load
   it on iPhone Safari. A desktop `localhost` URL is not a phone playtest link.

## iPhone 14 acceptance

Use [the device acceptance procedure](../fixes/device-acceptance.md), with at
least ten active minutes per map and repeated rounds. Test the final candidate,
not an older preview or a Blender render.

| Area | Required observations |
| --- | --- |
| Rendering and input | No missing/black materials; readable shadows and edges; safe areas; independent movement and BOOST input; large-building-only reveal. |
| Physical play | Loose props and NPCs fall independently; food heaps collapse; no unsupported rain remains suspended; both trains support head/middle/tail cuts. |
| Audio | First gesture starts one track; switching maps does not restart it; native speaker/headphone listening is comfortable; mute, pause and background/resume work; full loop boundary sounds acceptable. |
| Performance | Record frame-time percentiles, hitch count, loading and any thermal degradation during rain, large collapses and trains. A 60 Hz device has a 16.67 ms frame budget; report actual results, without equating headless checks to phone FPS. |
| Persistence | Existing coins, skins and settings survive refresh/relaunch; app suspension never grants rewards; QA mode uses an isolated save. |

Use the existing opt-in `?qa=1` recorder and retain its JSON locally alongside
device/OS/build identifiers and visual/audio notes. The recorder has no upload
endpoint. A measured problem must be fixed and independently reviewed before
declaring the device pass. Do not use an average FPS alone to hide long hitches.

## Native beta and store preparation

The audit found Xcode 16.2 selected locally. Current App Store Connect uploads
require Xcode 26 or later and the iOS 26 SDK or later; update the toolchain when
the native route is authorized. The iPhone 14 hardware target is independent
of the minimum deployment version. Prepare matching Godot iOS templates, a
chosen bundle ID and team, signing, a real archive and device installation.
No identifiers or accounts have been invented.

Before external TestFlight: provide an actual contact, beta review notes,
privacy/support URLs and device results. Before an App Store listing: prepare
1024-pixel source icon assets, genuine final-build phone screenshots, an English
description, age-rating answers, distribution regions and accurate disclosures
for the final archive and SDKs. Validate the current checklist in
[the independent readiness audit](readiness.md).

## Privacy and support draft inputs

The current authored runtime stores progress and audio preferences locally and
does not implement account login, analytics upload or microphone capture.
The optional device recorder exports a local report. These are bounded source
findings; they do not describe the future host's access logs or SDKs.

Before publishing a policy, fill in the operator's real name/contact, host and
its actual logging/retention, supported requests and the final SDK inventory.
Explain local storage, save deletion/export support if provided, optional QA
reports and any data the operator actually receives. Re-audit if analytics,
advertising or payments are introduced. Do not publish an unverified “we collect
nothing” statement or placeholder contact details.

This plan and the audit are preparation artifacts. Public deployment and store
submission remain separate actions.
