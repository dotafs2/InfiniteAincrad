# Independent expansion runtime review

Scope: Gate Siege only. Reviewer 1 owns focused tests and this report. **Current0.3.1 coverage runtime acceptance is complete** on immutable package `81412f9adbc68a57530cc3b556e08939c08505d59ddf2f26871860ea8f5083e0`:197 focused checks pass; four graphics modes share180 complete-campaign fingerprints; normal input wins all8 waves and idle input loses. Measured average desktop physics CPU falls42.8–73.3% in the paired stress fixture. Actual final-package active GPU scenes have no frames above50ms, while a59–94ms first constructed scene presentation remains explicitly disclosed. Physical-phone performance and exact visual identity to the reference are not certified. The older physical-packet contract and its receipts below are historical, superseded evidence.


## Preserved starting point

At the start of this review, the accepted version was0.2.1, package SHA-256 `684b08d7ccecc2ceee5627993f168b26f4e7a93a458677e52e1470e15fc8c033`, preserved in `artifacts/mobile-baseline/comparison/shadow-final.pck`. It passed 57 lifecycle, 66 mobile and 86 shadow checks on both source and isolated package. Its full-run statistics and performance are historical evidence, not promises for the expanded game.

## Specification audit

The new request requires recruitment that actually adds people, visual quality at least comparable to the newly supplied reference, additional waves, multiple monster types including wing-flapping dragons, and weapon modes. The reference-video reviewer owns visual interpretation; this reviewer will distinguish observable clip behavior from rules invented for the reconstruction.

Existing mechanics that must change or receive an explicit design decision:

| Existing behavior | Extension hazard | Required independent evidence |
| --- | --- | --- |
| `_set_player_model()` replaces one character and `_fire()` returns during recruitment. | Cosmetic duplicates or a complete squad ceasefire could masquerade as recruitment. | Existing members persist, pending recruits join only on landing, and existing units continue firing during the transfer. Each active unit has a real muzzle-origin attack contribution. |
| `_damage_crowd()` grants at least one kill for any positive damage and carries no individual HP. | Armored/elite enemies cannot survive sub-lethal hits or have meaningful health differences. | A below-HP hit leaves a damaged living target; accumulated damage kills once; front/rear targets consume physically traveled damage correctly. |
| Three boss-health entries, `wave >= 2` victory and result count based on `tier`. | Extra waves can finish early, index outside configuration or show false recruit totals. | Every configured wave spawns, ends exactly once and reaches the next configured wave; only the final wave wins; UI totals reflect actual recruits. |
| Projectile packets have tier-dependent speed and power but no weapon identity. | Weapon choices may only recolor the same attack. | Each promised weapon has a distinct observable collision, trajectory, firing cadence or area-effect behavior under equal fixtures. |
| One x/z boss collision plane ignores projectile altitude. | A flying dragon can have a visual silhouette disconnected from damage. | Explicit targeting/hitbox behavior matches visible projectile travel, including hits, misses, death and terminal attack contact. |
| Steering clamps only the single player center. | A wider squad can leave the road, camera or valid muzzle/shadow bounds. | Both steering extremes retain formation and grounded shadows, including during recruitment. |
| Existing tests hardcode three waves, 1,632 kills and tier 3. | Old assertions can reject intentional expansion or be weakened until meaningless. | Preserve lifecycle/collision invariants; revise only documented design assumptions and add new dynamic campaign checks. |

## Reference and proposed expansion contract

The second reference contact sheet was directly inspected. The independent visual reviewer additionally identifies these approximate events in extracted 2-fps frames: first gunner unlock around 4 seconds; a single gunner firing around 6 seconds; right-lane +1 collection and another gunner around 8 seconds; persistent multirow firing formation around 10–16 seconds; whole-squad class/projectile change around 18 seconds; and further +1 additions using the new class around 20–22 seconds. The clip distinguishes **headcount pickup** from **whole-roster class upgrade**. It does not establish a numeric maximum or hidden damage rules.

The root's current proposal is eight configured waves, up to 36 active members, five weapon modes (rifle, fan, rail, rocket and chain), and bruiser/shield/skitter/flapping-dragon elite varieties. These are proposed expansion choices, not facts recovered from the clip. The reviewed `docs/expansion/plan.md` and `scripts/campaign.gd` now explicitly define eight wave profiles, troop/boss HP, weapon intervals/powers and visually aimed flying targets. The mechanics specification is accepted for implementation; natural balance and visual quality are still unverified.

The agreed maximum is 36 logical members in every quality. A 36-member squad at the old 0.035-second gunner interval would create about 1,029 logical packets per second. The authored expansion rifle interval of 0.13 seconds reduces that to about 277 packets/second; scatter can still create about 310 pellets/second. Reusing the old all-crowd collision scan would multiply CPU work substantially; deterministic staggered firing and candidates selected from the actually traversed spatial rows remain necessary review points. Visual bullet caps must distribute coverage across firing members and cannot lower their logical damage. A 6×6 layout also needs group-aware steering limits or edge packing, since clamping only the leader center allows outer members to leave the runway.

A +1 pickup must be consumed once, independently of how many frames the formation remains over it. Existing members should continue firing while a class upgrade travels, with the whole roster changing class only on landing. New shots capture weapon identity and owner/muzzle position, so a later weapon selection cannot retroactively transform bullets already in flight. Wave transitions preserve the squad and selected mode; full restart resets pending actors, pickups and starting class/count.

## Planned acceptance checks

- Real recruitment uses the same damage/landing path as ordinary play, retains old members and adds exactly one active member per completed recruitment. Restart and cancellation release pending actors and shadows.
- Squad attack contributions originate at the rendered units, obey formation bounds and remain independent of visual quality caps. Selection controls do not leak UI presses into steering.
- Damage fixtures cover per-enemy health, nearest physical collision, hit accumulation, piercing/explosion behavior and multiplier gates without double application.
- Dragons have independently changing wing joints, correct idle/attack/hit/death transitions, pause freezing and cleanup. A cosmetic flap with unchanged dummy combat is insufficient.
- Every configured wave is reachable through the normal progression API; a separate uninterrupted pointer-input run demonstrates complete campaign victory or identifies balance blockers. Loss remains reachable and cannot simultaneously win.
- Quality switches preserve gameplay fingerprints, logical unit counts and damage. Large visual populations remain bounded without silently deleting logical damage.
- The final exact PCK is tested from an empty working directory with external test scripts, verified hashes, clean logs and no source-resource fallback. Actual GPU evidence is reported separately from headless checks and is never a phone frame-rate guarantee.

## First executable reproduction

`tests/expansion_review.gd` initially runs a focused five-check health contract through actual production projectile stepping. On the preserved pre-expansion source, a 3-damage packet against a fixture troop with 10 HP immediately kills the troop, awards a kill, and continues with phantom remaining damage. Four checks fail as expected; only repeated-dead-target kill counting passes. This independently confirms the source-reading concern and supplies a regression target for true per-enemy HP and absorbed-damage accounting. It is a baseline failure, not an expansion test result. The clean engine log with the expected assertion failures is `/private/tmp/gate-siege-expansion-hp-baseline.log`; the owned process exited 1 normally.

## Phase-1 mechanics decision

Accepted for implementation: real +1 additions; whole-squad upgrades on landing; 36-member cap shared by all qualities; eight configured waves; five mechanically distinct selectable modes; varied elites and articulated flying targets; pause/restart cleanup; distinct gameplay and visual budgets. The existing tested 640-pixel low limit is intentionally superseded by the newly approved 720-pixel visual requirement. The exact low/battery resolution fallback contract remains to be reflected in targeted tests. A subsequent visual review raised the current production targets to1280 long-axis pixels for Low/Battery and1600 for High; this supersedes the original720 proposal. Tier-0 scatter power is fractional (0.9), so recruit progress must preserve fractions or their remainder rather than dropping each sub-unit hit.

This decision approves a concrete mechanics design to build and test. It is not an implementation pass, a rendering-quality pass or a campaign-balance pass.

## Preliminary module review

The initial `squad.gd`, `encounters.gd` and `creature_motion.gd` drafts were inspected before `game.gd` integration. The squad has persistent member IDs, individual clocks/muzzle positions and batched representations; creature motion updates articulated wing/limb nodes from an explicit clock. These are suitable foundations, not yet proof of a working integrated game.

Open integration checks sent to the implementer:

- Member 0 is the leftmost member of the leading row once the formation has multiple columns; the old single-player shadow anchor followed formation center. The leader shadow must use that member's actual position and current visual scale.
- Elite candidates are sorted internally, but collision ordering must also include nearer troops and the main boss when one simulation segment crosses several types.
- The rail helper currently retains full packet power after elite hits; this must be either an explicit piercing contract or corrected consumed-damage accounting.
- Wave completion must include live elites and any required terminal animation interval. Timed hazards and secondary rocket/chain damage must not survive into a newly spawned wave or restart.

Implementation and integration acceptance remain pending while production wiring is being written.


## Implementation findings and verified repairs

The first integrated79-check headless suite passes against the evolving source (`/private/tmp/gate-siege-expansion-core.log`). This is intermediate evidence, not a final package receipt. It covers actual projectile stepping, individual troop health, fractional recruitment, persistent36-member identity, all four class formation bounds, real card crossing/once-only consumption, in-flight pickups, whole-roster landing, snapshots of owner/weapon/tier, all five weapon effects, collision ordering, shield-core damage and terminal-loss priority.

Independent failures reported and repaired during integration:

- Elites were resolved ahead of physically nearer troops and bosses. A single swept segment could hit a rear shield first. Production now sorts gates, statue and every combat type by traveled depth; real packet fixtures verify both cross-type cases.
- Hazard damage occurred after the last loss decision. A final-frame lethal warning could clear or win at zero health. The post-encounter loss decision now precedes wave completion.
- Multiplied rocket/arc packets could discharge their entire snapshot repeatedly while preserving residual count. The first impact now consumes the packet; regression fixtures verify one explosion or one five-target chain.
- A36-member formation could not geometrically dodge a centered dragon warning when every decorative body was a hurtbox. The maximum attainable separation was only0.538m against a1.5m radius. The agreed interaction is now a visible cyan shield core, radius0.30m, centered on the controllable formation. The full formation can place the core2.019m from the warning center. Real warning countdown, steering, hit-once and pause checks pass. Decorative members retain their independent firing contributions and share that shield health.
- Paused graphics changes now immediately refresh squad shadow visibility, and the original hero's floor shadow now follows its actual front-row member position.
- Flying aim previously selected a drake's altitude but used the main boss's depth. Production now chooses one target's altitude and collision depth together; focused trajectory checks are being added.

The rail rule is explicit: full snapshot damage pierces at most six distinct combat IDs, cannot strike the same ID twice, and then retires. Ordinary rounds consume logical projectile count per struck target; shield protection consumes the incoming damage actually absorbed. Rocket and chain make one secondary discharge per packet.

## First uninterrupted campaign simulation

The reviewer-owned controller in `tests/expansion_review.gd` supplies pointer steering and weapon keys through production input. It does not modify health, enemy state, wave, damage, roster or class during the run. It reads visible hazard locations to choose an avoidance direction, so this is a deterministic state-aware simulation, not a blind human playtest. Manual1/60-second physics advances faster than wall time; the3.62-second execution time is not render FPS.

The first Low run wins all eight waves at58.90 simulated seconds with36 members, class3,100 remaining health,4374 kills (4352 troops plus22 elites),8 bosses,3 class upgrades,35 recruits and a peak341 logical packets. Wave starts are0.00,15.18,37.10,40.07,44.88,48.37,51.25 and55.80 seconds. Evidence: `/private/tmp/gate-siege-expansion-natural-low.json` and its engine log.

This proves complete normal-hit reachability. It does **not** approve campaign balance: waves3–8 last only about3–5 seconds each, including the1.7-second boss death interval. A class3×999 rail snapshot can exceed1.48million damage against a155,000-HP final boss. The implementer was asked to review pacing and monster attack exposure. Natural loss, multiple quality fingerprints, articulated-creature regressions, actual GPU budgets and the final isolated export are still pending.


## Broader balance repair and current source acceptance

At the implementer's explicit request, this reviewer edited **only boss HP values** in `scripts/campaign.gd` to measure longer authored wave pacing. This is an ownership exception to the test-only role: the reviewer does not claim independent approval of their own HP choices. The root independently reviewed the proposed pacing. The accepted late-wave HP values are130M,130M,120M,130M,120M and120M; the first two remain2400 and12,500.

Broader input policies exposed why an apparently successful HP-only result was insufficient. Later bosses walked past the multiplier planes, abruptly reducing attainable damage by orders of magnitude. A small earlier-wave timing change could shift the moving gates and turn a prior victory into an effectively unwinnable late boss. The root repaired the actual approach rule: later bosses stop with their collision plane behind the last multiplier while continuing recurring telegraphed attacks. Early bosses and advancing crowds/elites retain pressure and a natural idle loss. A focused test now checks approach, sustained behind-gate placement and repeated real warnings.

Current source results after that repair:

| Input policy | Outcome | Simulated duration | Peak packets |
| --- | --- | ---: | ---: |
| Rail-oriented campaign controller with warning avoidance | All8 waves won |121.47s|341|
| Default rifle throughout, same steering/avoidance | All8 waves won |130.40s|469|
| Cycle all currently unlocked weapons every4s | All8 waves won |127.57s|560|
| No movement or weapon selection | Lost once in wave1 |39.98s|3|

Winning policies reach36 members, class3,4374 kills and8 bosses. They finish at100 shield health because the state-aware controller dodges warning zones; this is not a claim that ordinary players will avoid damage. The reference controller's late-wave durations are13.83,15.65,13.77,15.03,13.05 and13.03 seconds, long enough to expose recurring boss attacks. Natural loss is independently reachable without injected damage. A prior no-dodge experiment reached wave8 and then lost, but it predates the approach repair and is retained only as intermediate evidence.

Low, High, Battery and Auto produce **123 identical one-second/terminal gameplay fingerprints** for the same complete campaign input policy. The expanded focused suite now passes127 checks, including actual articulated dragon/drake wing movement, pauses during flight/death, real damage and death retirement, actual target-depth aiming, all five viewport-routed weapon buttons, input consumption,36-member/180-multiplied-packet preservation on quality swaps, and actual1280/1600 long-axis budgets at1080×1920. The GPU profiler and source mechanics hash manifest are stored with copied raw logs/JSON in `artifacts/expansion-runtime/`.

## GPU stress finding still open

`tools/profile_expansion.gd` is a new helper; historical mobile profiling is preserved. It stages36 soldiers,544 high-HP troops,four mixed elites and a dragon boss, so every weapon is tested while the dense population remains present. Weapon scenes use normal real60-Hz physics; only full-crowd and pause snapshots intentionally freeze gameplay. There is no movie mode. The720×1280 desktop stress is not ordinary-gameplay average performance or a phone guarantee.

The initial M1 Pro/Compatibility Low uncapped run has128 full-scene draws and161,854 primitives. Active weapon p95 frame times are roughly5.9–8.2ms, but **each weapon scene stalls118–162ms at the first elite warning, at simulated2.0167s**. Physics/visual CPU timings at those outliers are small, so averages do not justify a smoothness claim. The root received exact outlier timestamps and is investigating warning material/mesh lifetime and pipeline warmup. Final render/performance acceptance remains open until this is addressed and rerun.


## Warning-pipeline repair accepted on current source

The root replaced newly constructed warning cylinders/materials with a strongly retained shared plane and preloaded shader, and renders that exact resource during menu warmup. Six new assertions verify shared identity across warnings/restart, independently scaled damage diameters, the actual shader clock freezing on pause, a maximum of six warnings and cleanup. The source suite now passes **133 checks**.

Fresh-process Low stress repeats remove the reproduced outliers while retaining the same36-member/544-troop/mixed-flyer setup:

| Measurement | Before repair | After repair |
| --- | ---: | ---: |
| Uncapped maximum frame |161.651ms|10.893ms|
| Uncapped frames over50ms |5|0|
|30-cap maximum frame |152.018ms|38.692ms|
|30-cap frames over50ms |5|0|
|30-cap scenario means |34.07–34.19ms in active modes|33.29–33.35ms overall|
| Full staged scene draws |128|128|

The repaired active-mode CPU means are about0.72–2.40ms for physics and0.17–0.51ms for visual updates at the30-frame cap. The largest sampled physics update is5.081ms and visual update1.015ms. These short, controlled Apple M1 Pro/Compatibility measurements include first-warning events and all five weapons; they do not establish sustained mobile/thermal performance. Reports and clean engine logs are `warning-fixed-low-uncapped.*` and `warning-fixed-low-capped.*` inside `artifacts/expansion-runtime/`. Each owned process exited normally. A short final-asset and isolated-package repeat remains required because hero materials/geometry are still being finalized.


## First isolated-package acceptance (metadata superseded)

Accepted package: `build/expansion-staging/index.pck`, preserved immutably as `artifacts/expansion-runtime/final-candidate.pck`.

- SHA-256: `db19601884767d054281242cd7ae58a038ad3d3164d7b2c75a3b3ae37d79c686`
- Size:2,115,764 bytes.
- Engine:Godot4.7.2 stable official `ed1daf0bf`.
- Empty working directory:`/private/tmp/gate-siege-expansion-acceptance-empty`.
- Absolute `--main-pack` points to the immutable copy; absolute external test/profiler scripts load `res://` only from that pack. No source directory is supplied as a project fallback.
- Final source and exact package each pass **153/153** focused checks, with clean engine logs. The final additions retain real multiplier composition/absorption and nearest-event ordering, routed HUD pause/resume, whole-state pause, touch ownership, restart/focus loss, and all imported hero cloth/hardware surfaces and distinct roughness across all36 members.
- Exact-package Low/High/Battery/Auto each win all8 waves at121.4667 simulated seconds with36 members,4374 kills and8 bosses. All123 one-second/terminal fingerprints match exactly. The isolated idle run loses once at39.9833 seconds with no injected damage. State-aware avoidance and accelerated manual physics are explicitly distinguished from human gameplay and render FPS.

The final-asset exact-PCK Low stress repeat preserves36 members,544 troops,four elites and a dragon boss. Its frozen full-scene count is **130 draws and161,862 primitives**, an increase of2 draws and8 rendered primitives over the preceding art capture. Real physics Rapid/Scatter scenes maintain the full staged population. Across these three short720×1280/30-cap scenes, mean frame durations are33.33–33.35ms, maximum37.301ms, and there are zero frames above50ms. Rapid/Scatter physics maxima are3.168/3.792ms; visual-update maxima are0.648/0.963ms. This is a short Apple M1 Pro desktop comparison, not sustained phone acceptance.

The earlier cold-process five-weapon stress remains the complete mode matrix; the final package repeat specifically validates the changed hero surfaces and previously problematic first-warning path. The two new imported material groups are present in both every prototype and each batched36-member roster. Revision3 images were independently inspected for creature silhouettes, whole-squad class presentation, visible muzzle streams and distinct cloth/hardware response; the root moved the still partly occluded core forward again before this final package. The final screenshot/movie/browser review belongs to the root and visual reviewer, not to this runtime acceptance.

The machine-readable receipt `artifacts/expansion-runtime/final-acceptance.json` contains source, asset, package, helper and evidence hashes plus exact isolation details. Exported scripts are compiled/remapped, so the profiler cannot read raw `.gd` bytes inside the PCK. Source-file hashes are reported separately rather than misrepresented as decoded package hashes. Final source game hash is `4c738d3673093f8246dce08b211bf986871aaec84771bb22acaeeac35f9671a3`; squad hash is `a9b5bd1feffe38905ab00d3b2466c4ac37d47a7668a063acc12b3f56de37c30a`; authored HP config hash is `91af8c955244f59d28ba7ccc999dab81528f55eec6c2a86a87abe051123eda49`.

All owned test/profile processes have exited normally. No unrelated application, world, game, save, Git history or publication was changed by this review. Production ownership was limited to the explicitly delegated campaign boss-HP tuning; those authored values received separate root review.


## Historical physical-packet delivery accepted (superseded by0.3.1)

The accepted physical-packet delivery PCK was `artifacts/expansion/delivery.pck`, independently copied to `artifacts/expansion-runtime/delivery-589468.pck`. Its SHA-256 is **`5894686cc8a52f96df33874a72a83478e7056acadd07baafa97857f5aab54469`**, and its size is2,115,924 bytes. The previous `db196018…` package and its complete receipt remain preserved as `final-candidate.pck` and `previous-db196-acceptance.json`; earlier evidence is not overwritten or relabeled.

The change corrects the shadow manifest's source-path provenance and stale scale annotation. Independent exported-filesystem inventories hash all **81 packed resources**, including compiled scripts and imported model/texture resources. **80 resources are byte-identical**. The sole changed resource is `res://assets/expansion/shadows/manifest.json`, from SHA-256 `9a0d3cc45d4aa7e2fb763f6589005c227fa2450562bc8345f1abd0e7a47a8a10` to `0fe0e3e59155e0d1a6dcb35dd1705ec9923626c7e04ac004c0537c73b2f4b9f1`. No resources are added or removed; none of the81 hashes is empty. The full evidence is `delivery-resource-equivalence.json` and the two `resources-*.json` inventories.

The new immutable package was separately rerun from the empty working directory: **153/153 focused checks pass**; Low, High, Battery and Auto each win at121.4667 seconds with36 members and4374 kills; all123 checkpoints match across modes **and match the corresponding previous package run**. Idle loss was rerun and remains39.9833 seconds. Logs are clean and all owned processes exited normally.

The prior exact-package GPU results remain explicitly associated with `db196018…`. They apply to the delivery through verified equality of every runtime/render resource; no new GPU measurement is claimed for the metadata-only change. The preserved `previous-physical-589468-final-acceptance.json` records that provenance, package hash, test logs and earlier receipt. Runtime/integration acceptance remains complete; physical-phone performance and exact visual reference identity remain outside this certification.


## User-authorized coverage combat revision — in review

The user explicitly authorized cosmetic bullets and area/Monte Carlo damage to improve performance. The agreed implementation uses deterministic coverage instead of random samples:32 lateral cells across the11.2m play strip, fixed10Hz ticks, one aggregate field per weapon per tick, and a3s lifetime. Every soldier contributes captured class-scaled energy. A shared field starts at the rearmost contributing muzzle, then advances at the weapon's speed, conservatively delaying front-row energy rather than hitting early on behalf of rear soldiers. Gate intersections multiply only covered energy; nearer intercepted damage is debited before rear targets. Rifle/scatter conserve remaining primary energy; rail permits six ordered contacts per cell; rocket/chain allow one bounded secondary discharge per field. Those are authored approximation rules, not hidden rules established by the reference video.

The156-check physical-packet helper is preserved as `artifacts/expansion-runtime/expansion-physical-156.gd`. Its packet-identity/physical-pellet assertions are superseded explicitly, while current `tests/expansion_review.gd` retains127 integration checks. The new `tests/coverage_review.gd` passes58 focused checks on the first source implementation: all36 members contribute energy; firing waits for the combat tick; rear-muzzle travel is respected; fractional HP/recruitment survives; front targets consume energy; gates handle full, half and missed coverage once; shields debit incoming energy before mitigation; rail stops after six contacts; rocket/chain are bounded and do not repeat; scatter has wider coverage; equal elapsed-time partitions resolve identical ticks; active fields and restart state are bounded. These source passes are not yet final exact-package acceptance.

Gameplay fingerprints now include `combat.fingerprint()` and exclude visual-only bullet data and `peak_packets`. They still include member clocks/positions, actual HP, pending class state, every troop/elite/hazard, wave/boss lifecycle, gate shell, player input, logical metrics and gameplay RNG. Comparing future graphics modes will therefore detect gameplay differences without requiring cosmetic particles to match.

`tools/profile_combat_cpu.gd` independently captures the prior immutable `d543c6` package from an empty directory, using36 members,544 high-HP troops, mixed elites and a dragon boss,20 simulated seconds per weapon repeated three times. Full physics averages are about1.50ms rifle,1.58ms scatter,0.657ms rail,0.659ms rocket and1.56ms arc. One26.8ms isolated CPU outlier is retained. These accelerated fixed-step timings are CPU measurements, not rendering FPS, phone performance or ordinary play averages. Raw baseline: `artifacts/expansion-runtime/physical-cpu-baseline.json`. The new solver and duplicate formation-update removal must be compared as a combined change; the reviewer will not attribute all observed savings to collision replacement alone.

The later `d543c6` visual candidate was deliberately not promoted to final acceptance: measuring without the earlier0.75s fixture warmup exposed121–146ms first-shot/impact GPU stalls. Warming the actual spark/arc pipelines removed the immediate first-shot spike in one source test, but one116ms first-impact outlier remained. That evidence is preserved, and no smoothness claim is made for that pending candidate. Further A/B profiling was stopped at the user's newer coverage-optimization request; the forthcoming particle-renderer path must receive fresh GPU evidence.


## Coverage integration and measured source performance

The active suite now contains **60 coverage checks and137 retained integration checks**, all passing cleanly. Obsolete packet-only test functions were removed from the active helper after the complete original156-check version was preserved. Added coverage cases verify half-cell target conservation and retention of spent rail penetration when a gate fans out the field. Added integration checks verify zero actual per-projectile gameplay objects for all five modes, full damage with a zero cosmetic budget, bounded fixed ring storage, analytic shader-clock advancement, pause synchronization and restart cleanup. The headless endpoint test checks the selected drake/ground aim directly; dummy-renderer instance-buffer getters are not treated as proof of GPU trajectories.

The separate `sweep` input policy retains collection while the boss lives, then steers to mean camera-visible surviving troop X (or remaining elites). It starts with the newest unlocked weapon and cycles every4 seconds. It supplies only ordinary steering/weapon input. On source it wins at178.10 simulated seconds with36 members,class3,4374 kills,8 bosses,63 splash hits and205 chain links. Wave starts are0,11.80,16.60,56.20,80.00,105.30,130.60 and155.00 seconds. The second wave is still short4.8s; wave3 lasts39.6s while the formation fills. HP is unchanged. Rifle-only and the preserved older weapon-cycle policy also win at188.80/181.10s; idle loses naturally at41.7167s. Low,High,Battery and Auto share **180 identical one-second/terminal complete gameplay fingerprints** under the sweep policy, with peak20 coverage fields and zero moving projectile records.

The paired fixed-step CPU comparison retains every measured sample and outlier:

| Mode | Prior mean physics | Coverage/spray mean physics | Reduction | Highest new10Hz tick |
| --- | ---: | ---: | ---: | ---: |
| Rifle |1.516ms|0.656ms|56.7%|3.123ms|
| Scatter |1.579ms|0.421ms|73.3%|2.318ms|
| Rail |0.657ms|0.353ms|46.2%|2.030ms|
| Rocket |0.659ms|0.377ms|42.8%|1.640ms|
| Arc |1.560ms|0.474ms|69.6%|2.935ms|

This measures the combined coverage solver, analytic trail renderer's CPU emission path, cheaper target lookup and removal of a duplicated formation update. It does not isolate any one optimization's causal share. Concentrating damage at10Hz creates measured bursts; they are reported separately rather than hidden by the average. The unchanged high-HP fixture retains all544 troops through20 simulated seconds. Raw data and exact mean arithmetic are in `coverage-spray-cpu.json` and `coverage-cpu-comparison.json`.

Two actual M1 Pro/Compatibility GPU profiles run all five modes, frozen full crowd and pause at720×1280, one uncapped and one30-capped. There is **zero fixture warmup**, so first shots, first impacts and first warnings are included. Each measurement uses a fresh engine process with normal engine/driver caches retained; this is not a purged-cache first-install benchmark. Active weapon scenes have no frame above50ms; maxima are8.35–10.361ms uncapped and36.609–40.323ms capped. This no longer reproduces the prior121–146ms first-shot/impact stalls. The full36 frozen snapshot has106 draws and161,712 primitives; submitted analytic trail slots are bounded at900 in Low and can include expired/unborn shader slots, so they are not described as900 live projectiles.

A remaining first-presentation cost is explicitly retained: the very first frozen full-dragon scene frame is68.089ms uncapped and107.059ms capped, atelapsed0 withzero damage. It is not an active combat hit, but prevents a blanket no-stall claim. The root identified an unwarmed static-boss shader variant and is investigating a menu warmup repair before export. The runtime report does not certify that repair until new evidence arrives. These desktop profiles are short staged stress, not sustained low-end Android acceptance. All reviewer-owned processes exited and the GPU was released before the root's follow-up probe.


The root's follow-up warms the actual static boss flash material, gunner/mech follower instancing variants and the60/92-pixel3D digit labels. Independent source review confirms shared production resources and temporary-child cleanup after two rendered frames, with no gameplay-state or RNG mutation. The root's short repeat still measures a128.703ms first frozen-scene presentation, while active rifle reaches35.125ms maximum withno frames above50ms. This is root-produced supplementary evidence, not an independently rerun profile. The loading outlier remains disclosed; further speculative shader warmup changes were stopped. Final exact-package acceptance is still pending.


## Final0.3.1 coverage package accepted within measured limits

The exact immutable final export is `artifacts/coverage/coverage-release-1.pck`, preserved independently as `artifacts/expansion-runtime/coverage-release-81412f.pck`. SHA-256 is **`81412f9adbc68a57530cc3b556e08939c08505d59ddf2f26871860ea8f5083e0`**, size2,128,804 bytes. It is tested from verified empty `/private/tmp/gate-siege-expansion-acceptance-empty`, with an absolute `--main-pack` and absolute external helpers; there is no source project fallback.

The final package passes **60/60 coverage and137/137 integration checks**,197 total, with clean logs. Low,High,Battery and Auto each win all8 waves at178.10 simulated seconds with36 members,class3,4374 kills and8 bosses. All180 one-second/terminal fingerprints are identical across modes and identical to the reviewed source run. The real idle path separately loses at41.7167s with1 member,166 kills and15 breaches, withno injected damage. Peak active coverage fields in the winning run are20; moving gameplay projectile objects remain0.

The same exact package receives new seven-scene GPU profiles both uncapped and30-capped, withzero fixture warmup and normal caches retained. All five active weapons retain36 members and544 high-HP troops; no active frame exceeds50ms. Maximum active frame duration is9.647ms uncapped and38.325ms capped. Pause maxima are20.530/40.725ms. The fixed full-scene snapshot is106 draws and161,712 primitives. The remaining first constructed full-scene frame measures59.079ms uncapped and94.419ms capped, atelapsed0 andzero damage. These outliers are reported rather than discarded, and the game is not described as universally stutter-free. The earlier paired source CPU improvement remains a combined optimization measurement, not falsely relabeled as a newly timed package CPU run.

`artifacts/expansion-runtime/final-acceptance.json` now binds the197 checks,180-checkpoint quality equality, natural loss, both new actual-package GPU reports, source/helper/art/evidence hashes and scope limits to this exact package. The former physical-packet receipt is retained without rewriting as `previous-physical-589468-final-acceptance.json`; its historical153-check result is not confused with the current197-check contract. All reviewer-owned helper processes have exited. The GPU was released before the root's final movie/browser work.
