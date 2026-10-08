# Hole Feast — Store Review V1

The user authorized Mac screenshots while Apple login restoration is deferred,
requested a complete first version for review, and added two videos showing
food or objects falling into the black hole. Review V1 is prepared from the
actual 0.12.3 game. No store upload or new App Review submission is claimed.

## Deliverables

The review page is http://127.0.0.1:8774/. The existing game preview at port 8768
is preserved. `artifacts/store-review-20261001-v1/` contains:

- Five opaque 1320×2868 PNGs, editable SVGs and a contact sheet, ordered as
  black-hole food city, falling stacks/growth, Sushi Express, Sunny City
  swallowing, and the unified 44-skin collection.
- Two 20-second portrait MP4s at 886×1920/30 fps with actual background music
  and gentle game sounds. Selected food intervals contain 46 item-swallow
  receipts; city contains 22. Full ordinary captured rounds record 82/52.
- Posters, final-export frame contacts, English store copy and a ZIP containing
  the review page, five PNGs/SVGs, two MP4s and safe media evidence. Raw masters,
  build outputs, credentials, device IDs, personal saves and unrelated files
  are excluded from the ZIP.

All pixels are from the actual Mac renderer with the shipped following camera
and ordinary movement/collision/scoring/progression. No score, size, position,
wallet, entitlement, prop or drop effect is added. Whole viewports are uniformly
scaled into original decorative frames. Video cuts remain chronological and
normal speed: food 11–17, 46–53 and 53–60 seconds; city 14–20, 30–37 and 53–60.
Test sessions isolate saves and do not initialize advertising or purchases.
Manifests explicitly distinguish Mac capture from physical-iPhone capture.

## Verification and preserved failures

All five images have exact opaque export dimensions. Both videos pass H.264
High/Level 4.0, limited-range YUV420p/BT.709, stereo 48 kHz AAC, 20-second
duration, 30 fps and full-decode checks. Final audio measures −33.3 dB mean /
−17.2 dB peak for food and −33.4 / −17.6 for city. Every five-second capture
state reports music playing. These are media checks, not phone sensory claims.
Actual in-app browser review verifies both silent playback flows, pausing the
other video, all five image loads and full-size train screenshot opening/closing.
The review page defaults to muted playback; Sound on requires a user action.

An initial window-only resolution override produced a 540×960 master; the
isolated capture project's viewport-only override corrected it. First full
masters had swallow sounds without music because Mac audio awaits a released
gesture. A synthetic event alone did not reach the audio node; final capture
uses the same public `unlock_from_gesture()` entry as ordinary input. The failed
helper, partial recording, SFX-only exports and initial full-range encode stay
preserved in ignored `build/store-review-20261001-v1/`. Initial still city frames
reached results early and are excluded from the selected five compositions.

The user requested silence while watching another video. Only the owned audible
city recorder was stopped (exit 143), preserving its partial master. The final
city recorder uses Godot's Dummy output driver, suppressing speakers while
MovieWriter retains complete game audio. System volume, user applications and
game audio preferences were not changed.

All 804 guarded game/Web inputs still exactly match accepted 0.12.3 evidence;
the unchanged full gate was not repeated. No game source, real save, native
package, Apple login or store configuration was changed. Owned capture/encode
helpers finish; both preview servers are retained. The overnight automation
stays PAUSED. No subagent or root Git publication is performed.

## Continue

Preserve V1 if another review version is requested. Final material selection
and upload await user review and the existing account/native prerequisites in
[the release handoff](../app-store-release-20261001/README.md). Review approval
does not imply a signed/uploaded/submitted build. Production build 9 remains
the compiled/linked, unsigned native candidate. Composition is reproducible
with `tools/compose_store_review.cjs` and bundled Node/Sharp; capture/encoding
helpers, exact masters and failure history stay in the ignored build folder.
Public receipts and `media-acceptance.json` retain hashes and swallow intervals.

Apple primary references: [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/),
[preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
and [review guidelines](https://developer.apple.com/app-store/review/guidelines/).
V1 contains no competitor assets or branding.
