# Unified skin collection — 0.12.3

The user requested one collection without Classic/Special tabs, ordered from
low to high and browsable by vertical scrolling. All 44 stable skin IDs remain.
The list groups Common, Uncommon, Rare, Epic, Legendary and Prismatic in that
order, with numbered tier headings and alphabetic names within each tier.
Each entry opens at the lowest tier, retaining equipped-skin details. Unlocking
a skin brings its card into view. RATES/BACK preserves the scrolling position.

The real clipped viewport supports finger/mouse dragging, flick inertia and
mouse wheel input. Canceled touches and drags cannot equip or spend coins,
including when released over the fixed unlock button. Partially clipped cards
are excluded from keyboard activation. Only intersecting rows own 3D preview
resources (at most 12); only a visible selected card animates. Scrolling within
a row reuses the models. Off-screen textures and old controls are hidden before
deferred cleanup. Balance, detail, draw action and navigation stay fixed.

UNLOCK RANDOM and RATES now share one eligible pool. The disclosed tier weights
and 5/10/20 guarantees remain. Price advances across the combined collection
at 50/70/90/110/140 coins, capped at 140. Existing currencies, ownership,
equipment and unrelated progress are preserved. Before the first unified draw,
each shared guarantee inherits the stronger corresponding legacy counter.
Legacy records remain; the new shared record is saved atomically and is used
on subsequent cold restores. Failed writes roll back all purchase state.

## Accepted verification

The final receipt is [web-gate-02/release.json](../../artifacts/skin-collection-20261001/web-gate-02/release.json).
All 81 source and exported Web PCK suites pass 65,095 checks in each phase.
The first complete run stopped on stale drawing-method overrides in the two
train-surface test fixtures. Their original bytes, failed logs and stopped-run
input snapshot remain in `web-gate-01`. Both repairs pass focused checks. Only
these two previously unsuccessful/unexecuted test files changed; all runtime,
dependency and successful test hashes remained identical. The resumed gate
retains 69 successful source reports with per-report/script/hash provenance,
runs the remaining 12 source suites and every packaged suite under all 804
frozen current inputs. No release threshold or error detection was lowered.
The ignored resume helper's hash and exact fixture-only differences are in the
receipt. Report reuse is not described as new execution.

`skin_collection` passes 374 isolated transaction/migration checks, including
all 43 new purchases, exact charges, no duplicates, cold restore after every
purchase and failed-write rollback. Actual touch/drag review passes 1,944
checks; backing-size/preview checks pass 3,847; captured CanvasItem disclosure
review passes 7,634. Existing rarity, geometry, pointer routing, coin, train
and retention checks pass. Earlier parse/old-tab assumptions and comparison
against disabled clipped controls are retained in focused-01 through focused-03.

All 18 actual port-8768 files match the package hashes and required isolation /
no-store headers: [HTTP verification](../../artifacts/skin-collection-20261001/http-verification.json).
The isolated visual origin's PCK hash equals the published PCK. Real browser
review at 440×956 observes one collection, continuous dragging/wheel input,
all six ascending tiers, fixed navigation/detail/draw controls, locked preview
without payment and RATES/BACK preserving the bottom position. Both isolated
and live browser logs contain no captured warning/error. The live user's level
2, 390 coins, one owned starter and equipped Slate Ring remain. The temporary
viewport override was reset; the main preview stays as a deliverable.
Captures/observations are in [browser/](../../artifacts/skin-collection-20261001/browser/).
They are browser evidence, not physical-phone or frame-time certification.

## Native and release boundary

Fresh isolated 0.12.3 build 5 is `build/ios-skin-collection-20261001-05/`.
It compiles/links arm64 unsigned with the previously verified production AdMob
identifiers, all 50 SKAdNetwork buyer IDs and unchanged original vendor privacy
manifests. Its native PCK passes 8,547 desktop-engine checks across monetization,
native polish, lifecycle, collection transactions, actual collection touch,
geometry/layout and preview backing-size/resource checks. See
[native-05/production-candidate.json](../../artifacts/skin-collection-20261001/native-05/production-candidate.json).
This is neither native SDK callback evidence nor a signed/installable delivery.
It was not signed, installed, launched on the phone or uploaded. Build 4 and all
earlier output remain preserved; installed/uploaded baseline remains 0.11.2.
Before any new installation, strictly verify signing and take a fresh phone-save
backup, install the same bundle without uninstalling, compare the save bytes
before launch and record actual installation/launch receipts. Local keychain
authorization cannot be automated through the blocked SecurityAgent surface.

The earlier skin screenshot draft shows removed tabs; replace its frame with
this native interface before App Review. AdMob account/app approval, truthful
final privacy/support updates, Apple purchase agreements/products/sandbox QA,
final native store screenshots and explicit App Review authorization remain.
No new financial data/terms, root Git publication or store submission occurred.
The four-hour automation stays PAUSED. The owned gate, native and isolated
visual-server helpers completed/stopped; the port-8768 preview is preserved.

The user subsequently completed AdMob payment setup. The authenticated overview
confirms AdSense (China); account verification and store association remain
pending. This account-only follow-up does not change the accepted package.
See the [current monetization handoff](../monetization-20261001/README.md).
