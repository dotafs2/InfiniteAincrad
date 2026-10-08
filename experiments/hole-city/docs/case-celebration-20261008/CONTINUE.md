# Case reveal celebration handoff — 2026-10-08

## Delivered

The OPENING → NEW SKIN transition now produces an original 1.6-second canvas
celebration: fast expanding pearly comet trails, small star tips, subtle rings
and a decelerating fade. Silver/green/blue/violet/amber follow the existing
Common through Legendary palette; Prismatic uses the existing rainbow palette.
The live awarded model renders in front of the effect. Text and controls stay
clear and usable immediately. There are 26–36 transient particles, one Canvas
control, no additional viewport, emitter nodes, textures or lights. The effect
releases its particles and disables its own processing when finished.

Fresh natural completion and SKIP each trigger one burst. Duplicate reveal,
refresh, equip, reopening a saved receipt, and returning from odds do not replay
it. Leaving the result or continuing clears it. Separate focus/application/tree
pause gates prevent accidental resumed motion while still suspended. A local
seeded RNG leaves the global economy RNG unchanged; no new save or balance,
ownership, pity, receipt or price mutation is introduced.

## Review and failures preserved

Reuse the two independent GPT-6 Astra / ultra reviewers for art and runtime.
Capture 01 is rejected for dim short sparks resembling pins on the rim. Capture
02 improves the art but the runtime reviewer finds eight invalid-polygon
triangulation errors during continuous motion. Preserve both candidates and
logs. Replace each ribbon's arbitrary polygon with three explicit gradient
triangles, avoiding self-intersection as slow curved trails expire. Capture 03
retains the accepted appearance and has no errors or warnings in either complete
engine or stdout log. Both final reviews accept this corrected candidate:
[art](ART_REVIEW.md), [runtime](RUNTIME_REVIEW.md).

## Verification

- Actual Mac GPU UI: 712 checks, zero failures, in `ui-gpu-02`. Natural/skip,
  transaction state, RNG, duplicate callbacks, save count, hidden/reentry,
  application/focus/tree suspension, completion and short/tall/safe-area layouts.
  The nominal 375 fixture actually renders 374×666; other frames include
  440×956 and 540×1174. No physical-phone claim.
- Focused source and exact exported PCK: four suites, 1,123 checks per phase,
  zero failures. Suites: case UI, transaction, case audio, world music. Final
  manifest `artifacts/case-celebration-20261008/focused-gate-02/release.json` pins
  all 1,333 guarded inputs and all 18 installed export files.
- Exactly three guarded inputs differ from the previous music full gate:
  `case_opening.gd`, new `case_celebration.gd`, and `skin_case_ui_acceptance.gd`.
  This focused cosmetic regression run is not a new 97-suite full release gate.
  The previous full gate and previous previews remain intact.
- Actual 540×960 Mac GPU video: 604 frames, 60 fps, 10.066667 seconds, muted.
  Natural Common and skipped Prismatic use explicitly labeled isolated one-skin
  eligible pools. Both deduct exactly 100 fixture coins, preserve the committed
  award through animation, and finish with effect processing disabled. These
  are not organic rare-roll or real-account purchase claims.
- Final Web HOME boots at 8793 without observed browser warnings/errors.

## Deliverables

- Review gallery: http://127.0.0.1:8786/case-celebration-20261008/index.html
- Playable preview: http://127.0.0.1:8793/
- Final clip: `artifacts/case-celebration-20261008/capture-03/celebration.mp4`
- Isolated capture helper: `tools/capture_case_celebration.gd`.
- Final review manifest: `artifacts/case-celebration-20261008/delivery.json`.
- Ignored continuation state: `build/case-celebration-20261008/active-work.json`.

Keep the owned loopback preview server (PID in `preview-server.pid`) as a
user-facing deliverable; all owned engine/capture/test helpers have exited.
The pre-existing 8786 artifact server is reused. No physical phone, production
ad, purchase, account, native signing/upload or Git publication was used. User
saves and submitted 0.13.0/build 34 remain unchanged. Phone GPU performance is
unmeasured; new native integration/upload is a separate authorized task.
