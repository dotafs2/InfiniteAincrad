# Horizontal screenshot map selection and earned world progression

## Scope

The user requests actual recognizable map screenshot cards in one horizontal
swipe row, and sequential unlock conditions. Existing game content, all 200
skins, accepted score/10 economy, production saves and uploaded build 34 remain.
No phone, Apple/AdMob, native upload or Git publication is part of this change.

Read `build/map-carousel-20261008/active-work.json` for live process state.
Baseline source copies/hashes are in its sibling `baseline/` directory.

## Implemented

- Home now shows four large screenshot cards in one clipped horizontal row,
  with neighboring images peeking into view. Swipe, mouse drag, wheel and arrow
  buttons select the focused card. Hidden future maps are not presented as
  completed playable content. The duplicate three-card/vertical chooser is gone.
- Actual Godot screenshots were baked from the verified glacier package for City,
  Food, Toys and Frost. The pictures preserve aspect ratio, use rounded corners,
  and require no per-map live viewport. The obsolete hero viewport remains
  disabled; skin preview ownership is unchanged.
- A locked card can be browsed without changing the playable selected map.
  PLAY follows the focused card, and both selection and world creation validate
  entitlement. A lock icon, one short condition and progress bar explain the goal.
- Progression: City always; finish positive-score City for Food; completed Food
  score at least 200 for Toys; completed Toys score at least 300 for Frost.
  Best *completed* scores are separate from general best scores. Extensions
  may cross a threshold without repeating completion or reward settlement.
- Versioned monotonic map entitlements are stored in the existing atomic config.
  Legacy positive best scores or valid settled receipts retain played worlds
  and all earlier worlds. Selected thumbnail alone is not proof of play.
  Unknown/future IDs remain unavailable; unrelated save sections are preserved.
- A hidden in-flight carousel snap now settles immediately when changing menus.
  A released card may launch while its visual easing finishes; an active drag
  cannot launch. Keyboard Enter uses the same focused-card entitlement guard.
- Consumed pointer releases reach the deferred audio gesture gate, preserving
  first-touch music startup and independent saved mute preferences.

## Review and verification

Both existing reviewers were reused. `UI_REVIEW.md` accepts the actual four
thumbnails and final assembled card UI, including locked and partial-progress
states, short/tall phones and simulated safe insets. `PROGRESSION.md` documents
migration and the completion thresholds, grounded in existing ordinary scores.

The final actual GPU carousel harness passes 561 checks, including the later
hidden-snap, immediate-PLAY, audio-gesture and Enter regressions. Render-03
contains 13 images. Its 440×956 safe-inset image is a
desktop fixture using physical dimensions 1320×2868 and safe rectangle
(0,186,1320,2580), not a real iPhone result. The new isolated unlock suite passes
92 checks, including completion boundaries, continuation, old saves and save
failure/retry. Fresh test mode is still locked.

The release gate explicitly supplies `--qa-unlocked-worlds` to legacy scene
fixtures that must enter already-owned worlds. This flag has effect only with
`--test`; production ignores it. The dedicated map_unlock and map_carousel
suites reject that flag. The obsolete live-miniature rotation gate suites are
replaced by these two meaningful screenshot/progression suites. Legacy skin
migration fixtures now include actual played-world evidence or explicit current
entitlements rather than assuming that selecting a thumbnail implies ownership.

The complete final gate passed: **93 suites and 175,537 checks in each of
the source and exact exported Web package phases**, with **893 unchanged
guarded inputs**. All **18 exported file hashes** match the manifest.
The check runner was serialized; no parallel heavy engine work.
Focused follow-up checks now pass: carousel 548, application lifecycle 70,
economy continuation 173, music 129 and independent music review 120.
Final muted GPU recapture passed. Independent final interaction audit found no
additional actionable issues. The browser at port 8790 visibly loads the actual
exported UI, swipes in both directions, previews locked Food/Toys/Frost, rejects
locked PLAY and Enter, and immediately launches City from its committed card.
A genuine drag starts gameplay and collects a point. The 90-second City timer
then expires naturally; the result is 1 point / 0 coins. Returning Home and
swiping to Food changes its former LOCKED action into READY TO PLAY / PLAY.
This is a minimal interaction/unlock smoke test, not a balance run. No score,
time or access value was injected. Browser warning/error inspection is empty.
Evidence and image hashes are in `artifacts/map-carousel-20261008/browser/`.

## Evidence and preserved failures

- Actual screenshots: `artifacts/map-carousel-20261008/thumbnails-02/`.
- UI GPU evidence: `artifacts/map-carousel-20261008/render-03/`; earlier
  captures remain for comparison. Image hashes: `image-manifest.json` in the
  task artifact directory.
- Gallery: http://127.0.0.1:8786/map-carousel-20261008/index.html
- The initial thumbnail harness needed an explicit String local; its parse log
  is retained as `thumbnails-01.log`.
- The first UI regression batch exposed the hidden unfinished-snap bug. Failed
  receipts in `focused-01` are retained. Runtime, not assertions, was repaired.
- `focused-02` exposed immediate PLAY being blocked by visual easing;
  `focused-03` exposed the new card consuming the audio unlock release. Both
  runtime failures are repaired and their original receipts are retained.
- Requested 1320×2868 desktop window capture was clamped by macOS. Those initial
  render-01 images are not claimed as exact phone framing; render-02 instead
  uses 440×956 points and a labelled safe-area simulation.
- An unrelated historical `fidelity_acceptance.gd` is not in the current release
  gate and still contains obsolete 240-second/terminal-death assumptions.

## Preview and remaining scope

- New playable build: http://127.0.0.1:8790/
- Review gallery: http://127.0.0.1:8786/map-carousel-20261008/index.html
- Gate receipt: `artifacts/map-carousel-20261008/web-gate-01/release.json`.
- Browser receipt: `artifacts/map-carousel-20261008/browser/verification.json`.
- Browser checks use `?qa=1`, a no-save isolated session with native ads and
  purchases disabled. It starts City-only and is muted via the actual settings.
- The server PID is recorded in `build/map-carousel-20261008/preview-server.pid`;
  its terminal session is 60393. Preserve this preview deliverable and previous
  servers on 8786/8787/8788/8789. No heavy test helper remains after gate exit.

Phone rendering, safe-area behavior and frame rate still require a physical
device run; desktop inset fixtures are not real-device evidence. This change
is local and has not changed submitted native build 34 or external accounts.
No further full gate is needed without changed guarded inputs or a new failure.
