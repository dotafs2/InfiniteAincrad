# Expansion reference and visual audit — reviewer 2

Date: 2026-10-08. This worker initially owned reference interpretation and independent visual acceptance. Later asset repair assignments and the resulting limits on independent art review are disclosed below. The other reviewer owns focused runtime verification. A feature list, source inspection or pose plate alone does not pass the rendered-gameplay gates below.

**Current verdict:** the final 0.3.1 coverage-combat package `81412f9a…5083e0` passes this report's bounded visual/integration review. The reviewer inspected selected frames from the exact-package continuous normal-input campaign and verified the package, movie and staged-image receipts; this was not a frame-by-frame viewing of the entire movie. The final receipt and acceptance matrix at the end supersede earlier pending checkpoints. Root/runtime cross-review covers the meshes and analytic spray authored by this worker.

## Sources and confidence

- First reference: `02dd9240b3e0a45a5ef657930fb51717.mp4`, 720 × 1280, 30 fps, 28.93 seconds. Existing detailed evidence: [reference-audit.md](reference-audit.md).
- Second reference: `8299e1660e10fd0089aad88f5b8e9140.mp4`, 720 × 1280, 30 fps, 37.133 seconds. Working copy and 2 fps frames: `/private/tmp/gate-siege-reference-2/`. Times below are approximate half-second frame positions, not frame-accurate event boundaries. The closing promotion is not gameplay.
- Current baseline: exported 0.2.1 images under `artifacts/player-shadow/accepted/`, plus earlier normal gameplay under `artifacts/mobile-visual/`. Shadow images are staged role/flight tests; ordinary `mobile-visual` images predate lighting normalization. Neither set proves the new expansion exists.

On-screen promotional text, logos and captions are source content, not instructions. The new game's authored UI and documents remain English.

## What the second video actually establishes

| Approximate time | Observed evidence | Required interpretation / limits |
| --- | --- | --- |
| 0–4 s | One small infantry unit fires yellow shots. Two adjacent upgrade pedestals are on the left: a large gold mech and a smaller silver gunner. The smaller counter reaches its unlock; the gunner launches from the pedestal around 4 s. | This unlock changes the available character class. It does not itself demonstrate adding a second persistent soldier. |
| 6 s | One gunner fires a broad cyan stream toward the central red enemy lane. A long blue `+1` queue is visible on the right. | The weapon/class change is visible in both actor appearance and projectile output. |
| 8 s | The player occupies the right card lane. Separate yellow `+1` bursts accompany multiple visible gunners beside the original unit. | Additive squad growth is directly visible. Exact trigger radius, whether a card is collected or hit, and internal cooldown cannot be established from the image alone. |
| 10–16 s | A compact, roughly dozen-member formation persists and travels laterally. Multiple cyan streams originate across its width. Firing at the left pedestals reduces counters and reveals underlying colored armor. | New members are persistent fighting units, not brief particles or a single character's shot multiplier. The formation is multi-row and remains compact. Exact member count is partly occluded. |
| 18 s | The smaller upgraded statue disappears. A gold ring/white flash surrounds the entire squad; the formation changes to white-haired blue characters and its streams turn pink. | The class upgrade affects the whole existing formation while retaining the squad. Replacing the entire squad with one new hero would contradict the source. |
| 20–22 s | Returning to the right lane creates more `+1` bursts and adds units of the current upgraded class. The formation grows substantially. | Recruitment uses the current class after a whole-squad upgrade. It must not silently reintroduce the obsolete starting infantry. |
| 24–32 s | A large formation, approximately 25–30 visible members with overlap, fires broad pink volleys. Boss health changes from 469 around 24 s to 201 around 32 s. The next silver armored pedestal falls from 320 to 3; the gold mech also loses armor/counter value. | Sustained many-unit fire and progressive statue reveal are observed. The visible count is not an established hard cap. Neither final statue unlock nor a clean victory is shown. |
| Around 34 s onward | Promotion/end card. | No further combat rules can be inferred. |

The scene has three readable choices: left upgrade pedestals, central enemy lane, and a right queue of addition cards. The cool blue road and distant city remain visible around them. Camera lateral tracking helps expose the active side. A winged dragon, eight discrete waves and manual selection among five weapon modes do not appear in this reference; they are requested/designed extensions and must be validated on their own terms.

## Baseline graphics shortfalls

The current 0.2.1 baseline is recognizably related to the first reference but is not at its visual quality, including in High. Increasing resolution alone will not close the following gaps.

| Priority | Current shortfall | Concrete acceptance target |
| --- | --- | --- |
| P1 | Action objects are too small/remote in the upper half. In the first reference's opening view, the fixed gate's bottom is around 42% of portrait height; current is around 35%. The silver statue is roughly one-third of image width in the source versus about one-quarter in current. These are visual estimates, not calibrated camera measurements. | Compare equivalent gameplay moments at the same portrait dimensions. Enlarge/reframe the upper actors and platforms until their faces, weapons, counters and silhouettes occupy a comparable readable area. Do not crop boss HP behind the top HUD. Adapt composition to the second video's three-choice layout. |
| P1 | Hero/statue forms look assembled from smooth spheres and capsules. Clothing folds, straps, joints, facial planes, gun barrels and armor seams are much less defined than the targets. | Distinct readable head/face, torso costume, arm/leg articulation and weapon silhouette at gameplay size. Use authored form and restrained color/material separation; a high-poly sphere is not a substitute. Verify original art in-game, not only a large isolated preview. |
| P1 | Low/Battery produce conspicuous stair steps on characters, rails and small labels. Current normalized lighting is improved, but the road is largely uniform and the setting remains a dark void. | A quality-preserving default at the actual delivered portrait resolution. A proposed 720-pixel render width must be measured from the real 3D viewport, not inferred from CSS/window size. Clearly label any optional lower-quality fallback. Blue city/depth backdrop, road gradients/details and grounded shadows should remain readable without busy textures obscuring targets. |
| P1 | Cyan fire is a set of thin segmented rods. Source shots read as broad bright streaks, with coherent fans, tapered yellow projectiles and luminous impact bursts. | Shot origin is visibly attached to each soldier/weapon. The full squad creates a coherent but readable spread with bright cores and soft/tapered silhouettes, without excessive opaque rectangles, gaps or a permanently white screen. Effects must remain visually distinct across weapon modes. |
| P2 | Gold gate armor looks shallow, tidy and small compared with the thick embossed, irregularly chipped source plate. The source statue shells shed visible fragments and expose detailed material underneath. | If old multiplier gates are retained in the hybrid layout, preserve thick embossed type, irregular visible damage and progressive reveal. Colored underlying hero detail should become readable as the counter decreases. |
| P2 | Grounding previously failed. The latest player silhouettes now pass for infantry/gunner/mech, but simply cloning many opaque patches could turn a squad into one dark stain. | Per-member/contact grounding without giant black accumulation. Preserve direction, floor clipping and the tested landing handoff as squad size grows. See [player-shadow-review.md](player-shadow-review.md) for the accepted single-player baseline and remaining pedestal limitation. |
| P2 | Class changes and major actions currently lack the source's whole-formation scale and readable simultaneous response. | Real squad-wide class transition with a bounded ring/flash, new models/weapons, retained member count and continued visible firing after the transition. Boss/dragon movement must articulate limbs/wings rather than move the entire object as one rigid piece. |

## Scope critique

The proposed eight curated waves, five actual weapon behaviors, shield/skitter/dragon enemies and a 36-member squad are reasonable authored extension targets. They are not facts extracted from the reference. A 24-member limit may undershoot the large visible late-reference formation; 36 provides room for a comparable scale if every member remains readable, within the runway and mechanically active. The exact limit must be explicit, including what `+1` does at capacity. Quality profiles must not silently reduce the real squad or change combat rules.

A hybrid that retains first-video multiplier gates while adding second-video squad cards needs clear visual separation of **count addition**, **shot multiplication**, and **whole-squad class upgrade**. Reusing one counter or effect for all three would hide the intended choice. The first playable milestone should establish this loop before extra waves and weapons are treated as complete.

## Phase acceptance matrix

| Phase | Evidence required before passing | Reject when |
| --- | --- | --- |
| A — reference/specification | Explicit addition trigger and capacity behavior; persistent squad state; whole-squad upgrade rule; visible class/weapon progression; authored extensions separated from observed rules. | Recruitment still merely replaces one hero, or unobserved limits/rules are presented as copied facts. |
| B — art/rendering | Actual portrait GPU frames at default quality showing one unit, a medium formation and the chosen full capacity; left/right choices and counters readable; improved heroes, blue scene depth, grounded lighting, smooth projectiles. Dragon shown at both extreme wing poses and a mid pose inside the game camera. | Pose plates alone, placeholder primitives accepted as target-quality art, cropped wings/HP, low-resolution stair steps presented as the promised default, or members obscuring their own firing origins. |
| C — squad loop | Uncut normal simulation from one unit through several real additions and a class unlock. Runtime evidence that existing members remain, each new member fires from its own origin and affects damage, and all members adopt the upgraded class. At least one near-capacity view and both runway edges. | Decorative followers, centralized invisible extra damage, original members disappearing, obsolete class recruits, off-road formations, body/shadow overlap that makes count growth unreadable. |
| D — enemies and weapons | Each advertised enemy type appears in an actual wave with its promised movement/attack. Dragon wing beats have changing joint poses, an attack tell and readable hit/death response. Each of the five modes produces a distinct visible pattern and a distinct tested damage/interaction rule. | Renamed/recolored copies presented as new behaviors, rigid dragon bobbing, no functional projectile-to-airborne-target interaction, or five UI labels backed by the same shot behavior. |
| E — progression and delivery | All advertised waves reachable through ordinary gameplay, clear transitions and terminal outcome; pause/restart/quality invariance; final package/Web frames and input checks. Independent runtime report owns timing/CPU/GPU conclusions. | Staged wave jumps are the only progression proof, late-wave deadlocks or untargetable enemies remain, or Mac results are described as weak-phone FPS. |

## Phase B — first actual GPU render review

The reviewer viewed `artifacts/expansion/opening.png`, `squad12.png`, `dragon36-wings-up.png`, `dragon36-wings-down.png`, `golem.png` and `skitter.png`. These are staged source renders, not final-package evidence or an uncut ordinary gameplay run. The implementation owner identified a stale HUD caused by the capture helper suppressing redraw; the visible `SQUAD 1 / 36` and `WAVE 01 / 08` are therefore not used as evidence of wrong runtime counts.

The new blue road/city, clearly multiple squad bodies and broad occupied formation area are visible improvements. The 36-member formation fills a substantial lower-screen area, and the accepted directional player-shadow appearance remains recognizable. Those improvements do not yet pass the target-quality bar.

| Priority | Actual image finding | Required next correction/evidence |
| --- | --- | --- |
| P1 | In both dragon wing-extreme images, the wings read almost entirely as long yellow sticks viewed edge-on. The membrane is not visibly broad, and the very small green head/body reads as a toy. | Redesign/orient the shoulder/elbow/membrane shape so the production camera sees substantial wing area across the flap cycle. Keep a readable dragon body/head silhouette. A changing pair of lines is insufficient evidence of a convincing flapping creature. |
| P1 | The golem is a group of clean stacked boxes with a cyan rectangle; the skitter is an oval with colored tubes and triangular fangs. Both remain visibly simpler than the reference's costume, joint and surface detail. | Replace prototype forms with authored creature anatomy/armor, distinguishable joints and deliberate material separation, then show them in the gameplay camera. The new creature names alone do not pass the art requirement. |
| P1 | Cyan and pink fire still consists of narrow, opaque segmented rods. More origins increase quantity without reproducing the target's bright cores, soft/tapered trails and impact shape. | Improve projectile shape and blending while preserving individual muzzle origins and target readability. Compare equivalent one-unit and large-squad firing views. |
| P1 | The right addition queue consists of very small low panels/labels pressed against the edge. In the reference these are large upright blue cards, a dominant readable lane choice. | Increase card face height and readable text area, define a distinct collection lane and give addition feedback at the actual collection point. Keep it clearly separate from the multiplier gates. |
| P1 | Boss HP overlaps the top-left SQUAD label in the opening image. This is a layout collision even though the label value itself is stale. | Reserve non-overlapping screen space for fixed HUD and world-space boss HP throughout approach, recruitment and camera lateral motion. |
| P1 | The supplied images are 540 × 960. Source inspection finds long-edge budgets of 1280/960/720 for High/Low/Battery, yielding approximately 720/540/405 portrait widths. Auto starts Low. | If matching the 720 × 1280 source quality is the promised default, set and verify that actual 3D render size. Do not describe a 720-pixel long edge as 720-pixel width. Resolution alone will not fix the art and effects issues above. |
| P2 | Blue buildings are repeated flat boxes with large uniform faces; the road is mostly a uniform pale surface. City color is present but environmental depth/material quality remains simple. | Add restrained depth haze, silhouette/height variation and readable facade or bevel detail without competing with combat. Keep road lighting and contact shading coherent. |
| Evidence | Golem/skitter views retain flying gold recruitment models overlapping the stationary statue, and boss HP is already zero; dragon-down also has an active statue unlock. | Reset the staging scene per creature and record known HP/recruitment state. These images are not interpreted as proof of production duplication, but the carried transitions obscure clean art/state review. |

The wing-extreme pair shows different poses, but this review has not yet accepted a continuous articulated flap cycle, attack or death. No new GPU job was run by the reviewer; the supplied GPU evidence and relevant resolution/HUD source were inspected read-only.

## Creature repair and reviewer independence

After the first rejection, the implementation owner assigned this reviewer the three creature-art repairs. Changes were restricted to `art_source/build_expansion_art.py` and the dragon/golem/skitter GLBs. The new `--creatures-only` path does not rewrite hero exports or the shared manifest. Thus this worker is now the author of those three creature meshes; their final artistic and animation acceptance requires the implementation owner's and runtime reviewer's cross-review. This worker remains independent of the squad, HUD, camera, renderer and gameplay implementation.

The meshes preserve the motion node contract. Dragon retains `Body`, `WingL`, `WingR` and `Tail`; golem retains `Body`, `ArmL/R`, `LegL/R`; skitter retains `Body` plus six `LegL/R0..2` nodes. The last creature CPU export corrected custom plate/shell winding and exited successfully. No image-rendering GPU work was performed by this worker.

| Model | Triangles / mesh parts | Final winding-corrected SHA-256 |
| --- | --- | --- |
| Dragon | 6,828 / 4 | `0ec53d03e8790736e07ab9516610ac564b905f09e151356f97cfa81287ea738c` |
| Golem | 9,088 / 5 | `ac5d03235285d28d07000412cb2161554c00f8828f6dba0c121f52b9c95829cc` |
| Skitter | 5,656 / 7 | `9196991065e35935506c4addb7aabad048f233ca49d86179f05b9c06e49d99de` |

The owner subsequently assigned a limited hero-costume repair to this worker as well. A `--heroes-only` CPU export adds blue cloth shoulders/coats, a visible rear diagonal belt of thirteen individual brass rounds, dark back hardware, and layered blue mech armor around a recessed cockpit/reactor panel. Cloth uses a matte nonmetal palette material; hardware uses a separate moderately reflective material. Each hero has two mesh/material parts, supported by the existing squad collection path. Hero geometry is fitted back to its pre-export native bounds after simplification. The three approved creature hashes above remain unchanged.

| Hero | Triangles / mesh parts | Final costume SHA-256 |
| --- | --- | --- |
| Infantry | 3,800 / 2 | `8397f76c2b8a787070cd3ebd31aced391475e81c5f8b593c13bc437b3e139528` |
| Gunner | 7,392 / 2 | `68791434d76e55643cdca7da9cdc35d5dd7d4ab0aba4a782141cc3035b6841c0` |
| Mech | 7,264 / 2 | `0835dccac4e09d9ca7a120e1b456d21518450c5cca2173c678aaa2e88633ff33` |

The unified `assets/expansion/manifest.json` records all six models' counts, hashes, bounds and file sizes, with pre-repair hero bounds for comparison. The final hero Blender process exited successfully. The implementation owner will rebake shadows from these exact hero meshes and provide fresh GPU views. Because this worker authored these repairs, its following review remains independent for camera, UI, squad behavior and rendering integration, but final independent mesh/costume artistry approval belongs to the owner and runtime reviewer.

## Phase B — revision 2 composition review

The reviewer inspected all six fresh 720 × 1280 images under `artifacts/expansion/revision2/`. They show isolated staged states, with a deliberate firing stress view for the 12-member squad. The final creature GLBs were written at 10:34:07–08 UTC and these PNGs at 10:36:21–25 UTC, but the import-cache identity was not conclusively recorded. The owner will reimport and capture the final assets again; this section therefore accepts composition findings without asserting final mesh-cache identity.

Substantial improvements are visible: the dragon's membranes now have broad readable area at both flap extremes; golem armor, fingers and reactor details and skitter segments/mandibles are recognizable; addition cards are larger; the squad HUD no longer collides with boss HP; the city has windows and depth variation; and the projectiles have rounded luminous cores. The full formation's size and ground shadows are readable. These close most of the first render's composition and placeholder-shape concerns.

Four material concerns remain before final visual acceptance:

1. **Projectile origin/tail:** in `squad12-fire.png`, several fresh cyan/white streaks extend through and behind the shooters' boots into the lower road. Their tail length must be limited to travelled distance or otherwise anchored so a new shot does not visibly originate behind its soldier.
2. **Readable damage core:** the intended cyan squad shield/core is hidden behind the formation in the supplied full-squad views. If this is the actual shared collision target, it must remain visibly identifiable ahead of the bodies, and the warning/aim/collision contract must follow that visible location.
3. **Foreground material contrast:** haze colors the foreground road, world labels and armor broadly blue-grey. The target keeps stronger local dark seams, bright white counters and warmer skin/metal against its blue surroundings. Preserve that foreground contrast while applying most haze to the city and distant lane. This is a material/lighting issue, not a request for unobserved source-dragon identity.
4. **Main hero/statue detail:** the existing gunner and statue still have very spherical arm/torso forms compared with the target's more defined costume, face and weapon silhouette. The new creature detail does not by itself establish that the entire scene meets the requested reference-quality bar.

The large compact HP text remains readable and no longer collides with the HUD in these staged views. Reducing it to a fixed 32-point size without a projected-size check could make it too small. Validate the longest current values, such as `160M`, in the actual camera; approximately 40–48 screen pixels of text height at a 720-pixel-wide output is a reasonable trial target, not an extracted source requirement.

## Phase B — revision 3 integration acceptance

The reviewer viewed all seven images under `artifacts/expansion/revision3/`: opening, 12-member fire, both 36-member dragon wing extremes, golem, skitter and 36-member upgrade. These are fresh staged views at 720 × 1280, using the revised costumes and rebaked model footprints. The implementation owner separately inspected and accepted the revised hero/creature art; this review does not relabel the asset author's inspection as independent art approval.

The following root-owned integration issues are now closed for the supplied views:

- **Composition/readability:** the world counters and compact boss HP remain readable without colliding with the fixed HUD. The squad count is separate above the weapon row. The 12-, 24- and 36-member formations are identifiable and stay on the central runway in these centered captures.
- **Addition lane:** enlarged upright `+1` faces are readily visible beside the multiplier gates, and the `RECRUIT` label distinguishes this lane from the combat lane. This is an intentional hybrid of the two references, not an exact reproduction of either layout.
- **Projectile tails:** the luminous streaks in `squad12-fire.png` no longer extend behind the shooters' boots. They retain bright cores and rounded ends without an opaque rectangular trail. The actual continuous firing pattern still belongs to the gameplay acceptance below.
- **Foreground/city separation:** the neutral road and less fogged foreground preserve clear black outlines, blue costumes, metallic areas and gold hardware against the cooler city. No additional material or camera rework is requested on the basis of these images.
- **Grounding and upgrade presentation:** the role-specific ground silhouettes remain clear across the formation, and the staged upgrade view shows gold rings. The ring view alone does not prove natural class transfer or frame-to-frame continuity.

One material usability issue remains visible in revision 3: the cyan shared damage core is still mostly occluded by the front soldiers, leaving only its upper arc visible. The owner has moved it from 1.85 to 3.2 world units ahead for the final build. This correction requires a final-package view plus agreement between visible core and warning/collision position before closure. A hidden collision target cannot be accepted merely because its numerical coordinates are correct.

The 36-member staged views still show `+1` cards. Since the helper directly sets formation counts and suppresses ordinary progression, this is not yet classified as a production cap-display defect. Final normal gameplay must show the actual capacity feedback, such as `MAX`, when addition can no longer occur.

## Revision 3 checkpoint matrix (superseded by the review below)

| Phase | Current conclusion | Evidence still required |
| --- | --- | --- |
| A — reference/specification | Accepted distinction between real count addition and whole-squad class upgrade, with new waves/modes identified as authored extensions. | No claim of an observed 36-member source cap. |
| B — visual integration | Accepted the supplied revision 3 composition, resolution, cards, projectile-tail correction, HUD, foreground contrast and centered squad grounding. New creature/hero art has owner cross-review. | Final visible shared-core position; full-capacity card feedback; final package identity. |
| C — squad loop | Staged formation sizes and upgrade rings are visible; independent runtime review owns member persistence/origin assertions. | Continuous ordinary additions, retained members, natural class transfer and edge steering in the exact package. |
| D — enemies and weapons | Distinct creatures and two broad-wing poses are visible. | Continuous flap/attack/hit/death and actual mode changes during gameplay; runtime collision/animation checks. |
| E — progression/delivery | Pending. | Actual package progression across advertised waves, outcome, input and final-frame evidence. |

This acceptance is concrete and scoped. It does not certify pixel identity, a universally superior art style, or phone performance. This worker authored the repaired creature and hero assets and therefore does not claim independent approval of its own mesh artistry. No GPU capture job has been started by this reviewer.

## Continuous campaign and final readability review

The reviewer inspected actual GPU frames from `artifacts/expansion/final-play/`, including the early recruitment sequence, successive dragon poses, ten-second progression views, and the terminal view. This run used immutable PCK SHA-256 `5894686cc8a52f96df33874a72a83478e7056acadd07baafa97857f5aab54469`. Its 137.20 simulated seconds / 2,073 rendered frames are valid complete gameplay evidence, but its projectile blending and capacity labels have since been superseded for final visual delivery. The separate unfinished `accepted/weapon-play` run is explicitly rejected because its staging package was changed during capture; none of this acceptance relies on it.

The capture helper supplies production pointer movement and weapon keys, then advances the real simulation at fixed 60 Hz and renders at 15 FPS. It does not inject health, damage, roster size, class, enemies or wave progression. Its state-aware hazard avoidance is disclosed: this is an automated normal-control campaign, not manual human play or a phone/render-FPS measurement.

| Requirement | Concrete observed evidence | Conclusion |
| --- | --- | --- |
| Additive squad growth | `frame-00030.png` shows three infantry and `+1 SOLDIER · 3 / 36`; frame 60 shows five gunners; frame 120 shows eight gunners while the next class flies; frame 180 shows thirteen mechs. Later ten-second views reach 20, 30 and 36 bodies with corresponding HUD counts. | Real visually persistent formation growth is shown. The independent runtime report verifies stable identities, actual per-member firing origins and damage contributions. |
| Whole-formation class transfer | The early sequence changes the accumulated formation from blue infantry to cartridge-belt gunners, then blue/gold mechs. Recruitment continues in the current class; visible gold rings accompany transfer. | Accepted together with independent landing-time roster/weapon assertions. This is not supported solely by the staged upgrade-ring image. |
| Grounding and steering | Early additions occur beside the right rail; the full formation later moves across the runway while maintaining clear role footprints and an exposed cyan core. `frame-01230.png` shows the formation avoiding a warning left of its visible core. | No off-road member/large shadow-accumulation blocker was found in sampled gameplay. The shared core, rather than every decorative body, is the deliberately authored damage target. |
| Articulated dragon | Frames 815, 821 and 827 show raised, broadly extended and raised-again wing membranes, with body hover, cast ground shadow, hit flash, impact particles and decreasing HP. The dragon therefore changes actual articulated poses during a normal wave. | Accepted with the independent animation/pause/death/airborne collision checks. Two staged wing extremes alone were insufficient earlier. |
| Weapon behavior | The selected weapon and actual stream patterns change during play. The completed run records 383 splash hits and 1,397 chain hits, alongside normal projectile activity. | Distinct visible modes and nonzero actual secondary interactions are established; the independent focused tests verify all five damage rules. |
| Eight-wave progression | `capture.json` records wave starts at 0.07, 15.20, 33.20, 52.20, 69.07, 85.33, 104.07 and 120.27 seconds; all eight bosses are defeated. The terminal view shows `LINE HELD`, 4,374 cleared enemies, 36 soldiers and three class upgrades. | Complete actual-input progression and a readable terminal outcome are established. |

The final staged `accepted/dragon36-wings-down.png` also closes the earlier cyan-core occlusion: the whole ring is now visibly ahead of the front row. The owner moved its production location 3.2 world units forward; the independent runtime tests own agreement between this visible point and attack warnings/collision. The old staged `+1` labels at capacity were helper-state artifacts, while ordinary gameplay initially displayed `MAX` correctly.

### Late defects found and bounded corrections

The continuous campaign exposed a real issue absent from the quiet staged views: additive projectile blending produced a broad white fan around the multiplied stream and partly obscured `×999`. The 70.1-second Arc view was a clear failure of the earlier requirement to retain target/label readability. This review did not accept high shot count as justification for the whiteout.

The owner changed only trail blending and white-core shape: additive blending became alpha blending, the core exponent narrowed from 42 to 100, and white mixing decreased from 0.85 to 0.5. The reviewer inspected all four actual normal-controller source states under `effect-fix/` at 50.1, 70.1, 90.1 and 120.1 seconds. Cyan/pink color is retained, gaps and roadway are visible through the fan, and multiplier text stays readable. Logical shots, packet caps and damage were not reduced for this appearance fix.

A separate real layout collision remained: repeated `MAX` card labels overlapped a far-right `×999` gate at 90.1 seconds. The owner now retires unusable addition cards visually at 36 members and displays one `SQUAD FULL` lane label, alongside `SQUAD 36 / 36` in the HUD. The reviewer inspected the corresponding four frames under `release-stills/`: the rightmost `×999` text is fully separate and readable, capacity is explicit, and the live cyan core remains exposed. This bounded UI/FX correction is accepted. Sub-capacity cards and restart restoration are covered by the final runtime review, not inferred from full-capacity stills.

## Latest phase matrix

| Phase | Conclusion | Scope and remaining evidence |
| --- | --- | --- |
| A — reference/specification | Accepted. | Observed additions and whole-squad upgrades are distinguished from authored 36-member capacity, eight waves, new creatures and five selectable weapons. |
| B — rendering/integration | Accepted on reviewed source release stills. | 720 × 1280 output, readable cards/counters/HUD, detailed hero/creature silhouettes, whole visible core, grounded squad, and corrected saturated trails. Final replacement-PCK visual binding follows export. Asset artistry has owner/runtime cross-review because this worker authored the meshes. |
| C — squad loop | Accepted. | Continuous actual-input growth, current-class additions, natural class transfer and near/full-capacity steering, supported by independent member-origin and state assertions. |
| D — enemies/weapons | Accepted. | Normal-wave moving dragon, distinct creatures, weapon changes and actual splash/chain interactions, plus independent five-mode collision and articulated motion checks. |
| E — progression/delivery | Complete campaign accepted; final visual package receipt pending replacement export. | The recorded immutable package wins eight waves through production controls. Runtime isolation, quality invariance and final replacement tests belong to `expansion-runtime-review.md`; final shader/UI package frames must retain the accepted fixes. |

No further material visual blocker remains in the four source release states. Remaining differences are explicit scope choices: the three-lane hybrid includes multiplier gates from the older reference; the original creature/hero models, 36-member cap, shared shield core, selectable modes and longer eight-wave campaign are authored extensions. This is a reference-informed recreation with added systems, not a pixel-identical or hidden-rules-identical copy. Desktop GPU evidence does not certify weak-phone or sustained thermal performance.

## Authorized coverage-combat revision

The user subsequently explicitly authorized cosmetic bullets and coverage-area or Monte Carlo damage for performance. This changes the implementation acceptance contract: damage no longer needs to be caused by each rendered projectile or packet. The previous per-projectile assertions and immutable campaign remain historical evidence for the earlier implementation, not proof of the revised combat path. Final binding to candidate `d543c6ec50bc7f377559266d0de7706b15c4024267d89dacdb475147485e1faf` has stopped; a replacement package and actual-input run are required after the revision.

The visible squad must still be real, persistent and useful. Rendering distributed muzzle fire is sufficient for the new contract, while adding members must actually affect the aggregate firing coverage or damage contribution. A decorative count with no gameplay effect would still fail. The runtime reviewer owns deterministic weighting, off-lane exclusion, multipliers, encounter damage, weapon differentiation, timing and performance verification under this newly authorized approach.

| Visual/gamefeel invariant | Required evidence in the revised run | Failure to flag |
| --- | --- | --- |
| Distributed squad fire | One, medium and full formations retain visible streams across their actual muzzle/formation width; growth widens or densifies the useful fire presentation. | A single central beam visually replacing every member, idle-looking added bodies, or unrelated invisible damage unrelated to the formation's aim. |
| Coverage matches feedback | HP/hit response follows the visible spray reaching a covered target. Changes of lane have coherent effects on coverage. Any designed transit delay is applied consistently. | A distant untouched target flashes or loses health immediately while the visible stream travels elsewhere; cosmetic bullets regularly pass through undamaged eligible targets without an explicit mode rule. |
| Multiplier gates and shells | Visible stream crossings, gate activation, armor chips, progressive reveal and unlock feedback remain synchronized. Multiplied fans retain the accepted saturated colors and legible labels. | Gate damage/activation on an uncovered lane, delayed flashes detached from the visible stream, or a return of the whiteout. |
| Real addition and class transfer | Each crossed `+1` adds one persistent current-class body, and accumulated members transfer together when the upgrade lands. Capacity still retires unusable cards and shows `SQUAD FULL`. | Count-only additions, outdated-class recruits, duplicated collections, class changes before the visible landing, or capacity-label collisions. |
| Five weapon signatures | Rapid remains a narrow fast stream; Scatter a broad fan; Rail a long penetrating-line presentation; Rocket a burst with readable area impact; Arc visibly links nearby targets. These differences must correspond to distinct aggregate damage/coverage rules. | Five button names backed by visually/mechanically identical fields, or an area/chain effect that never appears in actual waves. |
| Creature and campaign continuity | Dragon wing joints flap through changing poses during a wave, with hover/shadow, warning, hit and death responses. Other encounters and eight-wave progression remain reachable through ordinary inputs. | A rigid hover substitute, damage-before-warning mismatch, frozen death, skipped/untargetable encounters or staged-only progression. |
| Preserve accepted presentation | 720 × 1280 default evidence, visible shared core, readable multipliers/HP/HUD, bounded floor shadows, foreground contrast and full-capacity cleanup remain intact. | Trading away the accepted art or clarity simply because the damage computation is cheaper. |

The revision does not require a new art pass. Visual acceptance of unchanged assets/composition remains valid, while damage-feedback, weapon behavior, continuous progression and the final immutable receipt are reopened only for the affected combat path. No GPU work was started by this reviewer.

## Analytic spray implementation and normal-density source review

The owner explicitly delegated the isolated cosmetic renderer to this reviewer: `scripts/spray_visual.gd` and `assets/shaders/spray_visual.gdshader`. This is a second authoring exception, so the owner's visual cross-review and the other reviewer's runtime/performance checks provide independent approval of this worker's renderer. This worker did not edit the coverage solver or its game integration.

The renderer owns one fixed 1,600-slot QuadMesh MultiMesh and writes transforms, colors and custom data only for newly emitted slots. Its per-render update changes one simulation-clock uniform; the shader computes camera-facing motion, muzzle-clamped tail length, endpoint fade and expiry. Low/Battery/High budgets affect presentation only. Birth time is split into integer and fractional channels to avoid late-campaign half-precision stepping. The same retained material and instance layout are exposed for menu warmup. No per-trail dictionaries, collision, damage or gameplay-random draws are used. The bounded API smoke exited successfully; headless dummy instance getters were not used to claim actual GPU geometry correctness.

The reviewer inspected the four actual normal-controller source frames under `artifacts/coverage/normal-stills/` at 50.1, 70.1, 90.1 and 120.1 seconds. These pass the bounded source visual gate:

- Scatter is a warm, short, distributed fan. Rail retains longer purple streaks. Multiplier output is visibly broader than individual muzzle fire.
- The road, `×2`, `×5`, `×999`, boss HP, HUD and `SQUAD FULL` remain legible; additive whiteout and the old full-capacity label collision have not returned.
- The shared cyan core stays exposed, silhouettes remain grounded, and no backwards/behind-boot trail is visible.
- The 120.1-second Rail image is between volleys. Continuous movie evidence remains required for cadence and damage/impact synchronization; four stills are not presented as a full timing proof.

The owner independently accepted these same four frames. The earlier `revision1/squad12-fire.png` forcibly emits at 60 Hz and is retained as a renderer stress view, not ordinary-density evidence. Some missed trails leave the runway in normal views; they are cosmetic outgoing fire and do not independently demonstrate damage outside the combat field.

The runtime reviewer reports 60 coverage and 137 retained integration checks, zero logical projectile objects, unchanged damage with cosmetics disabled, and 180 matching complete-gameplay fingerprints across four quality modes. Their actual five-weapon zero-fixture-warmup GPU profiles include first fire/impact/warnings and do not reproduce the preceding first-impact stalls. A separate first frozen full-scene presentation spike remains disclosed in that report; this visual acceptance does not hide it or make a phone-FPS claim.

The replacement immutable visual candidate is `artifacts/coverage/coverage-release-1.pck`, SHA-256 `81412f9adbc68a57530cc3b556e08939c08505d59ddf2f26871860ea8f5083e0`, size 2,128,804 bytes. Exact-package normal-play and staged capture binding remains pending at this checkpoint. No further art or effect changes are requested on the reviewed source evidence.

## Final 0.3.1 exact-package visual receipt

The reviewer independently recomputed the immutable package hash and size above. `artifacts/coverage/accepted/capture.json` binds seven staged 720 × 1280 views to that package; the reviewer recomputed all seven PNG hashes and found every receipt entry equal. The visible full-squad dragon fixture preserves the exposed cyan core, readable counters, full-capacity cleanup, broad membranes and grounded formation. Staged fixtures remain composition evidence, not natural pacing evidence.

The separate `artifacts/coverage/play/capture.json` binds the actual-input continuous run to the same PCK, explicitly with `source_fallback: false`. The reviewer inspected early recruitment/upgrade samples, times 0.1/10.1/20.1/40.1/60.1/70.1/80.1/90.1/120.1/160.1/170.1, selected neighboring action frames and the terminal image. This is sampled review of a continuous recording, not a claim to have watched every frame. The recorded process advances production simulation at fixed 60 Hz, captures at 15 FPS, and uses only state-aware steering/weapon inputs; it does not inject combat state. Its health-preserving avoidance is an automated policy, not an ordinary-player difficulty guarantee.

The completed run wins at **178.10 simulated seconds**, with 36 members, class 3, eight bosses, 22 elites, 4,374 kills, three whole-squad upgrades, 35 additions, 63 actual splash hits and 205 actual chain hits. Peak coverage fields are 20, while moving gameplay projectile records remain zero. The terminal screen reads `LINE HELD`, `4374 ENEMIES CLEARED` and `36 SOLDIERS · 3 CLASS UPGRADES`. The 2,687-frame MP4 includes the terminal hold, so its 179.133333-second duration is longer than the simulated victory time.

- Movie: `artifacts/coverage/squad-campaign.mp4`, H.264, 720 × 1280, 15 FPS, 57,044,467 bytes.
- Independently recomputed movie SHA-256: `bbeb3ed843107b54f61486bb84277d2272a298e3c08b8b47c84aea1d4ee73dca`.
- Independent runtime receipt: `artifacts/expansion-runtime/final-acceptance.json`; report: [expansion-runtime-review.md](expansion-runtime-review.md).

### Final requirement matrix

| Phase | Final conclusion | Concrete evidence and limits |
| --- | --- | --- |
| A — reference and authorized scope | Accepted. | Real additions and whole-formation upgrades follow the observed second-video loop. The hybrid gate layout, original models, 36-member cap, five modes, eight waves and deterministic area approximation are explicitly authored/authorized choices. Exact hidden-rule or pixel identity is not claimed. |
| B — art and rendering integration | Accepted in reviewed exact-package views. | Native portrait rendering, blue city, costume/armor detail, directional grounding, visible core and separated UI remain intact. Warm Scatter, orange Rocket, purple Rail/Rapid and cyan Arc fire remain saturated and readable; multiplier bursts do not white out labels. The owner independently reviewed these visuals, since this worker authored the repaired art and spray. |
| C — persistent squad loop | Accepted. | Normal frames show one infantry, four infantry around frame 45, seven cartridge-belt gunners around frame 90, nine mechs around frame 135, ten upgraded members at 10.1 seconds, 18 at 20.1 and 35 at 40.1 before full capacity. Natural upgrade feedback and later `SQUAD FULL` are visible. Runtime assertions independently verify membership, current-class additions, landing transfer and aggregate contribution. |
| D — creatures and modes | Accepted within sampled evidence plus independent checks. | Normal dragon frames 865/871/877 show lowered/raised/lowered membranes with changing hover pose, hit/kill response and decreasing HP. Later waves retain dragon warnings around the exposed core. Rocket/Scatter/Rail/Arc have distinct visible stream patterns and the completed run includes nonzero actual splash/chain interactions. The 197-check runtime receipt owns the precise coverage and animation rules. |
| E — progression and delivery | Accepted within documented platform limits. | The exact package completes all eight waves through ordinary input. The runtime reviewer independently reran 197 checks, natural loss and 180 equal checkpoints across four qualities. The owner reports browser deployment hash verification plus natural growth, upgrade, wave-four dragon, weapon selection, pause/quality and restart checks; those browser operations were performed by the owner, not this reviewer. |

No unresolved material visual blocker was found in the reviewed final samples, and no further production edit is requested. The known limits remain explicit: a short second wave and longer third wave are the current authored pacing; the damage solver is the user-authorized area approximation; the review sampled a fixed-step automated campaign; and physical-phone/thermal performance has not been measured. The runtime report retains the first constructed full-scene startup outliers (59.079/94.419 ms in its two desktop runs) even though all five active combat profiles had no frame above 50 ms. This report does not convert that evidence into a universally stutter-free claim.

All reviewer-owned temporary helpers have exited. No GPU capture job, Git publication, unrelated project/world modification or further art change was performed during this final binding review.
