# Overnight device and food-city iteration

User scope: restore native music; light haptics and subtle sounds on item/rival swallowing; exactly 60 seconds per round; fill the portrait screen; create an original appetizing food city with small-to-large targets and tall varied stacks. The requested four-hour thread heartbeat ended on October 1, 2026 at 05:48:17 Asia/Shanghai and is now verified PAUSED. Notifications were limited to meaningful changes or required user action.

## Verified source implementation

The project now expands its viewport instead of letterboxing. The 3D world fills the physical screen, while authored UI controls keep their proportions and fit within the native safe area. Screen input, joystick display and projected feedback convert through that UI transform.

Native iOS starts music when the saved preference is enabled, without the Web autoplay gate. The audio session uses Playback, allowing game audio in the silent-switch case, and mixes with other audio. Music is modestly louder. Stream restart recovery is restricted to iOS so dummy/headless playback cannot replay the intro. User mute preferences remain preserved.

A short downward-pitch gulp uses real PCM with a soft attack/release. Player item receipts and actual rival kills route to feedback; AI receipts do not. Item feedback is throttled to avoid continuous noise/vibration from falling piles. Haptics use brief low-amplitude pulses and have an independently saved pause-menu switch.

Rounds start at 60 seconds; intro and timer copy use the new duration. Existing timed reward receipts still settle only when the round expires.

Large food heaps now have six independently simulated dessert courses rather than only tiny pieces. The 59-piece budget is retained with separate edible topping rings; the roots span real intermediate size gates. Two existing two-course inner shops become original tiered-cake landmarks roughly 21 meters from spawn. Obstructing snacks are relocated with their count, reward and growth district preserved, using full road/walk/object clearance checks. Geometry, ingredient recipes and palette remain our own. The reference is the genre's progression and readable food hierarchy, not copied All in Hole artwork or layout.

## Verification status

The final complete gate under `web-gate-05` passes all 79 suites, with 54,291
source and 54,291 packaged assertions. All 802 guarded inputs remained unchanged.
The local preview was atomically updated only after both phases passed. Earlier
failed runs remain preserved. A focused haptic-preference review adds 14 passing
actual-touch, cold-restore, independent-choice and failed-save rollback checks.

Earlier iterations exposed an overly broad audio restart in dummy playback,
GDScript type inference failures and several fixtures that still assumed the
superseded 240-second timer or absolute UI coordinates. Only those obsolete
expectations and the intentionally verified shader/atlas fingerprints changed.
Stage, wallet, duplicate receipt, geometry budget, collision and physical fall
checks remain intact. Normal timed rounds settle near 60.017 simulated seconds.
Exit code zero alone is insufficient: the gate also rejects script/compiler/
engine errors and inspects complete assertion reports.

The atlas generator initially retained a historical evidence destination. Its historical PPM was reconstructed from the hash-verified baseline PNG using the exact original P6 encoding; the new atlas and restoration receipt are separate. Future atlas evidence writes to this dated iteration directory.

Physical-device audibility, subjective haptic feel, safe-area pixels, new food playability and signed delivery remain pending after the closed window. Previous builds and private account data are preserved. Do not claim sustained iPhone 14/16 Pro Max frame rate without a real capture.

## Rendered color correction

Actual renderer capture exposed a double sRGB conversion in the food ingredient shader. The Compatibility engine already converts fragment albedo before lighting; the food shader now preserves sRGB albedo for Compatibility and decodes only for Forward+/Mobile. A real Apple M1 Pro OpenGL framebuffer comparison against StandardMaterial passes all six colors with zero maximum channel difference, without gloss. The two shader hash fixtures were intentionally updated to this approved revision; collision and material-opacity assertions remain intact. The unchanged original shader is retained under `artifacts/native-polish-20261001/color/`.

Real desktop-rendered 540×1173 captures show the expanded world and full menu wallpaper. They are gameplay evidence, not physical iPhone screenshots or a device-performance claim. An explicit native QA mode captures local frames, stream/output-bus state, feedback events and frame intervals. It uses a disposable test wallet and does not initialize native ads or commerce, so diagnostic play cannot finish a user's pending purchase into that wallet.

## Geometry-budget iteration

The first complete gate rejected the new heaps at 5,054,236 total food triangles and slightly excessive opening submission. The existing 5M global and fixed opening-view limits were retained. Tiny garnish rings now share one biscuit recipe per heap; the large courses retain their shape/frosting variety. A focused recheck passes all 136 assertions: total geometry is 4,821,324 triangles, and both opening views stay inside the original triangle and 69/124 batch limits. Failed first-gate evidence remains under `web-gate-01`; the next complete gate uses a new directory.

## Visible hole interior

Normal rendered gameplay revealed a brown disc where the dark hole should be.
The production cut slab's vertical walls inherited the street/food atlas and
were culled from the cavity side. The existing slab shader now renders both
sides and shades vertical faces dark; the bottom disc slightly overlaps the
three-meter visual wall to close an oblique-view gap. No collision geometry,
food-admission threshold or collection receipt changes. An actual GPU fixture
reproduces the prior failure and passes 144 interior-pixel checks across three
radii and two camera angles after correction. Failed intermediate frames are
preserved alongside `cavity/after-03/result.json`. Normal-play `visual-03`
captures use no injected radius or score and show the corrected mouth.

The paired phone currently reports a required passcode. Device installation
and launching are separate outcomes; do not infer a launch or tactile/listening
acceptance from a successful signed build.

## Store layout preparation

Five original 1320×2868 SVG/PNG layout drafts use unchanged `visual-03` and
`store-gallery` gameplay/menu frames, with source/output hashes under
`store-drafts/manifest.json`. Navy and
cream framing, short large titles and a consistent food/growth hierarchy make
the category readable. Each includes a visible desktop-draft label and is marked
`ready_for_upload: false`. No competitor artwork or invented gameplay appears.
Accepted native captures must replace these images before upload. The real
Sushi Express, city and original skin collection now have composed layout cards.
The gallery follows the train with actual movement; score, radius, position,
wallet and skin ownership are never granted for marketing captures.

The earlier fourth complete source/PCK gate used `web-gate-04`. The third gate found
that the collection review injected obsolete absolute screen coordinates.
Its swipe helper now transforms authored card coordinates to actual screen
coordinates, matching its existing button-tap helper. Two additional tall-screen
up/down paging assertions pass; all 190 collection review assertions pass.

## Remaining-suite acceptance

The thumbnail fixture now exercises the production expanded viewport and checks
the real card's backing-pixel demand after proportional UI fitting, instead of
assuming an independent content-scale multiplier. All 695 assertions pass.
The intentionally changed skyline footprints affect 23,656 atlas pixels
(0.564%); an independent Sharp RGB decode reproduces both the old pinned hash
and the new imported hash. Mipmap and filtering checks remain unchanged.

The collision finish fingerprint still pins its original roughness, gloss and
transform lines. Only the exact GPU-verified renderer-dependent albedo decode
is normalized to the original line for that comparison. All other mesh/color
arrays and physical assertions remain intact; the full new shader SHA has its
own color acceptance. Failed logs remain recoverable.

The new tall heaps exposed a real low-altitude rain spawn embedded inside a
dessert. New rain uses one actual-world collider query per spawn to start above
the support surface with a half-meter margin. There are no additional ongoing
contact queries. All ten perimeter recipes now settle and yield unique full-fall
receipts; the enlarged-food review passes 199 assertions, including ten new
nonpenetrating spawn checks. The first patch's fixture indentation error is
retained and corrected. The actual high-portrait BOOST fixture passes all 55
checks and measures approximately 1.55× travel at radii 0.85, 6 and 14.

## Native package and delivery boundary

A fresh 0.12.1 build 1 snapshot is exported under the ignored
`build/ios-native-polish-20261001-01/`. Its arm64 executable, AdMob 13.11.0,
UMP 3.1.0 and StoreKit 2 adapter compile and link successfully with signing
disabled. No compiler errors occur; the upstream template/header warnings are
retained in the build log. Google's official test IDs are used, so this is a
device-test candidate, not a production advertising configuration.

Both full vendor privacy manifests are packaged with their original hashes.
The native PCK is 10,677,736 bytes, SHA-256
`d60ca036a0d873975f8a728d14f3650708fbdb8d3edbe23a4b90c26ce0e44144`.
Five focused fixtures execute that exported PCK in the desktop engine and pass
357 checks for music resources/decoding, feedback, safe layout and actual haptic
settings controls. This tests native package contents, not native iOS output.
The actual phone profile backup passes 27 isolated load/save compatibility
checks; every preexisting value and the original backup bytes are preserved.

Development signing remained blocked on local keychain authorization and was
cancelled during deadline cleanup, with its log preserved. Computer Use
explicitly refuses access to the SecurityAgent app; do not bypass that restriction
or enter a password through another mechanism. The user must authorize it on
the Mac. This candidate is not yet signed, installed, launched or uploaded.
The phone also currently requires its passcode. Do not infer tactile, listening
or native screenshot acceptance from an unsigned build.

Real browser review at 440×956 confirms a matching full-size canvas, full-screen
menu/food world, a 01:00 opening timer and visible separate Music/SFX/Haptic
pause controls. Browser error/warning logs are empty. The saved screenshot is
browser evidence, not an iPhone capture. The owned local review service uses
port 8768 and is an intentional preview deliverable.

## Normal-play soak

Twelve complete one-minute rounds, alternating six food and six city runs,
pass 84 checks using ordinary automatic movement and actual physics receipts.
No score, radius, position, wallet or ownership is granted. Food finishes at
level 5 with 122–151 points and 70–71 larger future targets; 81–148 edible
targets remain within 25 meters. City finishes at levels 3–4. The final report
is `artifacts/native-polish-20261001/one-minute-soak.json`. These are pacing/
continuity observations from automation, not human retention measurements.

The first helper incorrectly named the body size property, and the second used
the command-line demo startup before map selection. Those helper sources/logs
are retained; neither is accepted evidence. The corrected helper uses the
actual footprint and admission method, selects through the real map chooser,
asserts the selected map, then enables ordinary automatic movement. No runtime
or guarded release input changed for these fixture repairs.

## Window closure

The last scheduled wake stayed active until the actual 21:48:17 UTC deadline,
using bounded waits. The app tool paused the existing automation at
21:48:32.691 UTC without changing its prompt, recurrence or target thread.
All 802 guarded inputs, the native PCK and original phone-backup bytes still
match their acceptance evidence. The new candidate remains unsigned and
uninstalled. The blocked owned signing job and temporary awake helper are
stopped; the preview server remains available on http://127.0.0.1:8768/.
No user application was stopped, and no App Review submission or Git publication
occurred. The public receipt is `artifacts/native-polish-20261001/window-close.json`;
private process/signature details remain in ignored build evidence.

The [current continuation](CONTINUE.md) records the recoverable signing command,
device-save protection and remaining release boundaries.
