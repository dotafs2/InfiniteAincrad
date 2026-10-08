# Gate Siege continuation

Date:2026-10-08, Asia/Shanghai. Chat:`01a11a33-7474-7aa1-9f35-ff27367302fc`.

## Current local build — version0.3.1

The user requests the second clip's +1 squad growth and whole-squad upgrades, the existing visual target, more waves and creatures including flapping dragons, more weapon modes, and exactly two auditors. Earlier boss animation, protagonist-shadow and low-end30FPS requirements remain. Their latest instruction explicitly permits cosmetic bullets and area/Monte Carlo damage for performance. The implementation chooses deterministic area weights.

The game has36 persistent soldiers, eight waves and five mechanically different weapons. Recruitment adds an actual current-class member; class changes apply to the whole roster on the upgrade hero's landing. Animated brutes, golems, six-legged skitters, dragons and smaller drakes appear in combat. The visible cyan core ahead of the roster is the shared-health hurtbox for red attack warnings. Every soldier contributes firing energy.

Combat now aggregates member contributions into32 lateral cells, advances delayed coverage fronts at10Hz, and resolves partial overlap in depth order. Armor consumes incoming energy; gates multiply only covered energy once; actual target absorption is debited. Rapid, Scatter, six-contact-per-cell Rail, grouped Rocket splash and five-link Arc remain distinct. No individual gameplay projectile objects exist. The GPU animates bounded decorative streaks from birth time and fixed transforms; only emission writes slots. Split birth time preserves Compatibility precision. See [coverage combat](expansion/coverage-combat.md).

Original detailed costumes, broad articulated wing membranes and actual-mesh grounded silhouettes remain. Low/Auto/Battery keep a1280px portrait3D long axis with MSAA2×; High permits1600px and real sun shadows. Colored alpha trails preserve multipliers under full-squad fire. At36, unusable+1 cards retire and the lane shows SQUAD FULL. Quality budgets never change damage or roster state.

## Current package and evidence

Immutable package: `artifacts/coverage/coverage-release-1.pck`, SHA-256 `81412f9adbc68a57530cc3b556e08939c08505d59ddf2f26871860ea8f5083e0`,2,128,804bytes. Source hashes are in `artifacts/coverage/source-manifest.json`. The authoritative current test receipt is `artifacts/expansion-runtime/final-acceptance.json`; the final delivery manifest is under `artifacts/coverage/`. Never export over a PCK being read by another process.

Source focused checks pass197 (60 coverage+137 integration). Four graphics modes share180 complete-flow checkpoints under the sweep policy, winning at178.10 simulated seconds with36 members/4374 kills/eight bosses. Rifle-only and old cycling policies also win; idle loses naturally at41.72s. The controller supplies steering and weapon input, reads visible enemies/warnings and never injects health, damage, roster or wave state. The isolated immutable package independently passes the same197 checks,180 quality/source checkpoints and natural loss.

Same-fixture desktop CPU comparison (3×20s per weapon) reduces complete physics-update means by42.8–73.3%, from0.657–1.579ms to0.353–0.656ms depending on mode. The largest actual10Hz coverage tick is3.123ms. This combines coverage combat, analytic GPU trails, cheaper cosmetic aim queries and removal of duplicate formation updates. It does not assert identical damage under the superseded solver or physical-phone performance.

Source real-GPU active modes, including first shots/impacts/warnings, have no sampled frames over50ms: uncapped maxima8.35–10.361ms and capped maxima36.609–40.323ms. The artificial first presentation of a newly constructed36-member/wave8 pressure fixture still has a loading spike (up to128.703ms in a short repeat). Do not claim every frame is stutter-free or hide that outlier. The full frozen scene has106draw calls and161,712primitives. Final exact-package active maxima are9.647ms uncapped and38.325ms capped, with zero active>50ms frames; first frozen-scene presentation is59.079/94.419ms. These limits are retained in the runtime receipt.

Two auditors are runtime_review and reference_audit. The visual auditor authored specific art and the analytic cosmetic renderer; root independently inspected source and actual GPU output, and the runtime auditor validates API/performance and gameplay separation. Root authored the coverage solver and integration. Their reports distinguish authored work from independent acceptance: [runtime](expansion-runtime-review.md), [visual](expansion-reference-visual-audit.md).

Final staged compositions are `artifacts/coverage/accepted/`; uninterrupted actual-input capture is `artifacts/coverage/play/`, encoded as `artifacts/coverage/squad-campaign.mp4`. The movie uses fixed60Hz simulation and15FPS rendered recording, so it is not a realtime or phone FPS benchmark. Old0.3.0 physical-packet candidates, captures, failures and measurements remain historical. The mutable-PCK recording failure is explicitly rejected and never reused as acceptance.

## Preview and operation

Local play: `http://127.0.0.1:8810/`; review gallery: `/review.html`. Preserve the existing preview server recorded in `artifacts/preview-server.pid`, and unrelated user applications. Final browser checks and HTTP hash are recorded in the delivery manifest. Preserve any in-progress browser game; the final observation was active play and was left running.

Use `.build/Godot.app/Contents/MacOS/Godot` (standard4.7.2). Launch.command prefers it. Export `Web Review` into `build/expansion-staging`, copy to a fresh immutable filename, test using absolute main-pack and external helper scripts from an empty cwd, then replace served assets atomically with HTML last. Tests, art sources, helpers and reference videos are excluded from the export. Clean up only owned temporary processes.

## Boundaries and history

The provisional audience/device floor is short-session casual players with Snapdragon665/HelioG80-class Android,3–4GB RAM; older iPhones are secondary. Audience demographics, sustained physical-phone30FPS, thermals and touch latency remain unmeasured. The area solver point-samples moving targets on its10Hz ticks; this is the authorized deterministic approximation, not per-bullet physics. Original art and authored additions are not a certified pixel-identical copy of every unknown rule in the videos.

Hole Feast and resident worlds remain separate. No commit, push, public hosting, paid API or external-account action occurs. Earlier0.2.1 is preserved at `artifacts/expansion/previous-0.2.1.pck`; its55-draw/209-check result concerns the old smaller game, not this36-member stress scene.

Refresh this exact chat's visible-message archive under root `docs/history/conversations/2026-10-08-01a11a33`. Its manifest is authoritative for actual cutoff/hashes; later messages and other tasks are not included. Never publish raw sessions, reasoning, credentials or unrelated private files.
