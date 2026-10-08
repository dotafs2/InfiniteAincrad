# Independent retention UI review

Result: **PASS, 2,443 checks**, with no unexpected engine diagnostics. The
reviewer changed no runtime code. The review script is
[`tests/retention_ui_review.gd`](../../tests/retention_ui_review.gd).

## Issues found and corrected by the UI author

1. The map chooser read `tagline`, but map definitions expose `description`.
   The author corrected the field access. Every real map name and description
   now reaches the drawing callback.
2. The map chooser marked Home as the active screen, which disabled the Home
   button there. The author gave the chooser its own navigation state. A
   viewport touch now returns to Home without selecting or starting a map.
3. Rates used the collection's initial-entry callback for Back, which reset
   the current tab/page to the equipped skin. The author added a return path
   preserving the browsed tab/page. Special page three now survives Rates
   entry and Back while a Common Classic skin is equipped.

## Independent checks

- Actual `InputEventScreenTouch` press/release events travel through the root
  viewport, configured to a 375 × 667 window with 540 × 960 logical canvas.
  Every control remains inside portrait margins, has a minimum 44-point hit
  target at 375-point width, and does not overlap another control. Transparent
  hotspots have corresponding drawn panels. Circular gameplay controls retain
  their deliberate finger padding; the visible circle occupies at least 60%
  of its hit rectangle and stays inside it.
- Five map rows expose exactly two playable selections and three disabled,
  visibly labeled Coming Soon entries. Disabled entries cannot change maps or
  start play. Both playable selections restore the matching home preview.
  Both map-specific best-score labels are drawn.
- All 44 real collection cards show their catalog rarity, and all six rarity
  labels are observed. A fresh profile owns only the Common starter. Existing
  focused-preview, page and skill behavior remains covered by the legacy
  suites below.
- An independent oracle reconstructs unowned pools and integer tier weights
  directly from the catalog and ownership. The actual rendered text matches
  tier probabilities, per-skin probabilities and remaining counts for both
  tabs, two guarantee states, and an exhausted pool. Guaranteed-draw counters
  use the active tab. The completed collection disables spending.
- Unsupported native purchases remain visibly disabled and cannot grant
  currency. Their Back action works. No live purchase/ad provider was used.
- Real navigation enters a round showing `04:00`. A bounded timer fixture
  shows `01:02` for 61.1 remaining seconds and 123 coins for 1,234 points.
  Real pause/resume clicks work. Calling the ordinary physics callback with
  0.01 seconds remaining produces the timed result and its exact 123 + 20 coin
  receipt. This is not a four-minute unattended gameplay run.

The drawing observer subclasses the shipped UI and forwards every intercepted
text/panel/badge call to `super`; it neither substitutes captions nor overrides
navigation or economy logic. This establishes runtime text and control
geometry, not a browser screenshot or raster-quality comparison. It does not
certify phone GPU performance, sustained 60 FPS, audio playback, or native
purchase/reward service integration.

## Legacy regression maintenance

The four original files and their hashes are preserved in
[`before/manifest.json`](../../artifacts/retention-ui-20260929/before/manifest.json).
The exact unified changes are preserved with the final artifact manifest.

| Suite | Passing checks | Deliberate specification update |
| --- | ---: | --- |
| `title_navigation_acceptance` | 39 | Assert fresh Common starter, then explicitly grant grandfathered Core Shell before retaining all original advanced shader/color checks. |
| `ui_redesign_acceptance` | 1,871 | Use the Common starter identity; count the new map-chooser control; describe optional food counters as timed-run counters. |
| `review_ui_collection` | 188 | Assert the starter's actual page, touch back to page one, then preserve the original swipe/page/selection/transaction/restore tests. |
| `skin_skill_acceptance` | 130 | Update only fresh ownership to the Common starter. All five actual abilities and cosmetic exclusions remain exercised. |

No skin-FX assertion was removed. Total checks in these four targeted runs:
2,228. Together with the new independent UI suite: 4,671.

Two reviewer-fixture failures are retained: disabling the entire gameplay
subtree incorrectly disabled its input, and demanding exact equality between
a circular visible control and its padded finger target was too strict. The
final fixture suspends only unrelated physics, keeps input live, and explicitly
tests the existing bounded touch padding. Neither failure required a runtime
change or a relaxed engine-error filter.

## Evidence and scope

- [Final independent receipt](../../artifacts/retention-ui-20260929/review/retention_ui.json)
- [Final independent log](../../artifacts/retention-ui-20260929/review/retention_ui.log)
- [Before/after source hashes](../../artifacts/retention-ui-20260929/review/source-manifest.json)
- [Legacy receipts](../../artifacts/retention-ui-20260929/legacy)

The eight scoped source/test hashes were unchanged across the final independent
run. UI SHA-256 was
`1786f50f5f9725d793e2aae87ce76e9480c72b55542ba0cf9570aca385ca3c24`;
game SHA-256 was
`655ef8c91be52c8e90b6d59f024a251879209991d233977b3d4aaefeaabb92ca`.
All helper processes exited. All runs used headless Godot, Dummy audio, and
`--test`; no browser, user progress file, native UI capture, Git publication or
deployment was used. Full source/PCK release acceptance is owned by the parent
and is separate from this bounded review.
