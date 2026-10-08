# Reference video evidence audit

Audit date: 2026-10-08. Source: the user-provided `02dd9240b3e0a45a5ef657930fb51717.mp4`. This is an observation record, not a claim that the source game's unseen rules are known.

## Source and timing

- Video metadata: 720 × 1280, 30 frames per second, 28.933 seconds including a social-platform end card.
- Actual gameplay remains visible at 25.5 seconds; the end card is visible at 26.0 seconds. The last roughly three seconds are not a game screen.
- Local working copy and extracted evidence: `/private/tmp/video-game-reference-20261008/`.
- The supplied `frame-01.jpg` through `frame-27.jpg` were produced with `fps=1`. Their samples are approximately at half-second centers: `frame-08.jpg` matches 7.5 seconds and `frame-10.jpg` matches 9.5 seconds. Do not label the first sampled image as an exact zero-second frame.
- Independently extracted `exact-0.0.jpg`, `exact-7.5.jpg`, `exact-8.0.jpg`, `exact-8.5.jpg`, `exact-9.0.jpg`, `exact-9.5.jpg`, `exact-10.0.jpg`, `exact-25.5.jpg`, `exact-26.0.jpg` and `exact-26.5.jpg` verify critical transition times.
- Original promotional text, account watermarks and spoken/subtitle commentary are source evidence. They are not player controls or development instructions. Their presence does not establish the game's actual title, developer, availability or original engine.

## Evidence matrix

| Time | Directly visible evidence | Fidelity requirement / uncertainty |
| --- | --- | --- |
| 0.0 s | A small blue recruit stands near the lower quarter of a light gray runway. One yellow projectile moves forward. A blue ×5 gate sits in the foreground; a gold-covered ×999 gate lies farther up the runway. A fixed blue ×2 barrier spans the left enemy lane. A silver minigunner statue on a right pedestal has `59` on its plinth. A dense red crowd and a large red-vested brute are approaching in the left lane. | Start already in live combat. No visible menu, joystick, currency counter, score counter or level selector. No evidence that ×5 initially requires unlocking; it is already blue at exact zero. |
| ~0.5 s | The ×5 gate is surrounded by a yellow ring and vertical glints. Recruit is aligned left. | Brief gate activation/hit feedback is observable. It must not be asserted to be a separate unlock mechanic solely from this ring. |
| ~1.5–6.5 s | Recruit follows the left side. ×5 and ×999 sweep horizontally across the runway while retaining their forward positions. Yellow projectiles form rows after gates. Front red troops flash pale/white and disappear; replacement ranks advance. The brute becomes increasingly exposed. | Repeated automatic-looking fire plus lateral alignment, with genuine gate crossings and visible impacts. A handful of isolated enemies would miss the dense crowd appearance. |
| ~5.5–7.5 s | Yellow shots passing ×5 appear as a small row of roughly five; shots behind ×2 form a larger row. The brute has a red outlined health bar with `1060`. | ×5 followed by ×2 visibly increases the stream. Exact damage, original brute maximum HP and fire rate cannot be recovered from these samples. |
| 7.5 s | Recruit is on the right. Right pedestal reads `57`; blue color is appearing near the statue's cap. Yellow projectiles are traveling to it after ×5. | Player can choose the upgrade target instead of attacking the left wave. The upgrade is earned by hitting a numbered statue, not by walking to it or purchasing it through a menu. |
| 8.0 s | Statue counter reads `30`. Its top/body are blue while silver material fractures around the remaining lower shell. | Use progressive material reveal and falling metal fragments, rather than a single recolor at zero. |
| 8.5 s | Statue counter reads `4`; the minigunner is almost fully blue. | Hits actually reduce remaining upgrade progress. Counter should be readable as a large white numeral with a dark outline. |
| 9.0 s | The released minigunner is airborne between its now empty pedestal and the recruit. | The unlock has a visible leap/transfer transition. An instantaneous HUD-only upgrade misses an important visual event. |
| 9.5 s | A squat, broad blue minigunner occupies the player position. A gold ring surrounds him, yellow `Level up` text appears, and cyan projectiles begin replacing yellow shots. | Upgrade changes silhouette, weapon, projectile color/density and visual feedback. It is not only a hidden damage increase. |
| 10.0 s | Player is returning left while firing cyan. First brute still displays `1060`. The next gold figure begins emerging from the empty right recess. | New upgrade target enters immediately after the previous one is used; the right location is a persistent upgrade station. |
| ~10.5 s | First brute reads `0`, flashes pale, and dissolves/fades. The next right statue is a gold armored rocket soldier. | Provide a clear boss defeat event before the next approach. |
| ~11.5–12.5 s | Gold rocket soldier's pedestal reads `548`. A fresh red crowd advances down the left lane. Cyan projectiles become broad, dense rectangular volleys after ×5 and ×2. | The second upgrade has a much larger requirement. Visually render multiplied projectile rows rather than displaying only a multiplier label. |
| ~12.5–15.5 s | Player aims cyan fire at ×999. Gold cladding chips off with visible yellow fragments and cyan/white hit flashes. A blue board and large white `×999` become visible beneath the gold. | ×999 starts armored/inactive-looking. Visible erosion is required. Full removal and the behavior after activation are never demonstrated. |
| ~16.5–17.5 s | Player returns left to clear crowd through ×5 then ×2. A second, pink bare-torso heavy enemy approaches behind the formation. Gold ×999 retains a lower strip of material. | The observed choice is recurring: crowd pressure, statue progress or gate armor. Maintain enemy motion during upgrade/gate targeting. |
| ~18.5 s | Player is on the right and shoots the gold rocket figure through ×5. Its counter is `473`. The gold top shell is breaking. | Second statue also reveals the underlying blue model gradually. |
| ~19.5 s | Rocket figure reads `264`; much more blue armor is exposed, with gold chunks flying. | An incremental shell reveal should follow progress. |
| ~20.5 s | Rocket figure reads `37` and is mostly blue. Player has shifted away; ×999 receives cyan hits. | Progress persists after the player retargets. The video does not show this second hero being obtained. |
| ~21.5–23.5 s | Player attacks the second heavy through ×5 and ×2; it flashes pale on impacts and continues approaching. Right figure remains at `37`. | Boss attacks/approach and upgrade progress are separate. Do not drain statue progress simply with elapsed time. |
| 25.5 s | Second heavy shows `2310` above a partly depleted red bar. Player attacks the remaining gold along ×999. Right statue still shows `37`. | The ending is unresolved combat: no rocket-player unlock, no fully active ×999, no victory, no death and no rewards screen are shown. |
| 26.0 s onward | Social-platform search/end card. | This is an edit, not evidence of an in-game results screen. |

## Camera, composition and rendering

The composition is portrait 9:16. A perspective camera looks down and forward from behind the player. The recruit's feet are near normalized screen Y 0.80; the upgrade player's center remains near 0.75. The near runway fills the screen width and narrows toward the top. There is no visible horizon or landscape: the outside is almost black with a subtle cool tint.

The forward battlefield is asymmetric. The left approximately 55–60% is a narrow, very long enemy lane bounded by metal rails; the right is a short raised upgrade recess/plinth. The ×2 board closes the visible front of the left lane around normalized screen Y 0.35–0.42. In the foreground, ×5 is around Y 0.54–0.64 and ×999 around Y 0.44–0.53. The exact coordinates vary modestly with camera follow and the strong perspective. The scene does not scroll forward as a runner track.

Small horizontal camera following is visible: when the recruit shifts right, the upper lane and station move left in the frame. It is not a free orbit, pan-and-zoom editor view or overhead orthographic camera. Screen framing must retain the enemy crowd, both moving gates, upgrade statue and player together.

The art is smooth, rounded, exaggerated 3D with bevels and glossy material response. Surfaces show shading, occlusion and crisp, soft-edged shadows falling toward screen-right. The floor is a plain warm/light gray. Rails are dark metal. Active boards are saturated blue with an almost translucent/glowing sheen. Gold cladding and statue shells are warm yellow metallic. Initial ammunition is bright yellow teardrop/streak shapes; minigunner ammunition is luminous translucent cyan with trailing shapes. Pale/white hit flashes on whole troops and bosses are a major readability cue.

Characters have recognizable silhouettes and visible equipment: blue recruit cap, blue clothing and tiny firearm; upgrade minigunner with wide torso, ammunition belt, blue cap and chunky multi-barrel gun; a giant red-vested brute with enormous black gloves; a second pink, bare-torso heavy with dark red trousers; a rocket soldier with helmet, broad blue shoulders and several gold-tipped rockets. Flat blocks or unadorned capsules are insufficient substitutes for the reference's close views.

The dense red formation is approximately tens of characters across and tens of ranks deep, producing hundreds of simultaneous visible bodies. Individual red caps, pale faces and dark torsos are visible at the front. The crowd has ordered rows with small variations, not a scattered swarm. The two large bosses loom over the front of the crowd and remain much larger than the player in screen space.

Labels are large, bold, white and black-outlined. ×5 and ×2 are face-on enough to remain readable despite their world placement. Statue counters are equally emphatic. Boss HP is a rounded red fill inside a dark bar with a light outline; numbers sit above/overlap it. The recorded promotional title/subtitles/watermarks are overlays and should not be treated as a requirement to reproduce third-party branding. Authored game text follows the project's English language policy.

## Movement and mechanical reconstruction

- **Player:** moves laterally near a fixed forward depth and continually faces up the runway. There is no observed jump, dodge roll, backward step, manually aimed crosshair or movement along the track. Drag/touch steering with automatic fire is a plausible implementation, but the video never shows the user's finger or input state. Keyboard/mouse alternatives are reconstruction choices.
- **Moving gates:** ×5 and ×999 move along the horizontal axis, not toward the player. Their locations are approximately opposite in phase. A full lateral oscillation takes approximately five to six seconds; sample extrema suggest roughly 5.3 seconds, but this is an estimate, not a measured source constant. Their widths are about one third to two fifths of the full foreground runway at the relevant depth. ×999 is roughly one gate-height farther forward than ×5.
- **Persistent gate:** ×2 is static and covers the left enemy lane. Projectiles can hit the right statue without traversing ×2. Gate placement should support meaningful overlap chains while both smaller gates move.
- **Projectile behavior:** a single/few initial shots expand into visible rows after crossing active gates. Through ×5 then ×2, the stream appears wider/denser. The upgraded gunner produces many more cyan projectiles and trails. A bounded visual representation may be used for large counts, but it must preserve visible gate-crossing changes and actual applied damage.
- **Upgrade targeting:** the player's lateral position directs shots toward either enemies or the right statue. Shoot-down values persist when attention switches away. Shell removal progresses downward, the minigunner leaps to the player, and its pedestal temporarily empties before the next figure rises.
- **×999 armor:** repeated direct hits remove visible gold cover. The blue label progressively emerges from above; a lower gold strip remains even at 25.5 seconds. The reference never demonstrates a completed ×999 multiplication volley.
- **Enemies:** red troops advance in ranks; white flashes and removal clear the front. Large enemies approach in the same lane. The first red-vest brute is defeated; a second pink heavy remains alive at the edit. No evidence establishes spawn RNG, wave count, exact troop health or collision rules at the player.

## Highest-priority fidelity constraints

1. Preserve the portrait perspective and asymmetric lane/station composition. A flat 2D diagram, overhead view or equal-lane runner changes the visual premise.
2. Render a dense red crowd, two distinct giant enemies and a genuinely recognizable armed player. Character silhouette and shaded volume drive resemblance more than tiny UI decoration.
3. Make ×5 and armored ×999 slide laterally in opposing phases while ×2 remains fixed. Fire must visibly multiply at an actual gate crossing.
4. Let the player trade time between crowd suppression, statue progress and gold gate erosion. Enemies must keep moving while the player attacks other targets.
5. Reproduce silver/gold shell breakage, countdown numbers, the minigunner leap, `Level up`, and the yellow-to-cyan change.
6. Match the restrained HUD. Large unrelated panels, persistent tutorial cards or score boxes would obscure the source composition.
7. Keep unresolved reference events labeled as reconstructed behavior. A playable extension may need win/loss and later upgrades, but it cannot be certified as the source's unseen rules.

## Things the clip cannot establish

The clip does not establish exact enemy health, projectile speed, rate of fire, damage, count implementation, gate durability, ×999's completed effect, the second hero's firing pattern, later waves, failure behavior, rewards, saves, monetization, menus, exact input method, audio separation, original asset sources or engine. A replay can visually imitate the shot sequence without being interactive, so runtime acceptance must include independent steering and target choices.

The screenshot samples alone also cannot prove frame-perfect animation timing. Numerical approximations above are starting points for a reconstruction and should be tuned against actual captures. A claim of “completely identical” is not supportable from this short edited reference.

## Template search

A bounded web search on 2026-10-08 checked Godot's asset catalog and primary creator repositories for a 3D shooter or multiplier-gate template. No matching gate/crowd/statue template was identified in those results; this is not proof that none exists.

- [Kenney Starter Kit FPS](https://github.com/KenneyNL/Starter-Kit-FPS) is an existing Godot 4.6 first-person template with controller, weapons and enemies. The code uses the [MIT license](https://github.com/KenneyNL/Starter-Kit-FPS/blob/main/LICENSE.md); its repository describes included art as CC0. It is a legitimate reusable base, but its first-person view, free movement and conventional shooting are a poor match for this fixed-lane composition. Importing it would still require replacing the central game loop and view.
- [Kenney Tower Defense Kit](https://kenney.nl/assets/tower-defense-kit) provides 160 CC0 3D assets according to its creator page. Its medieval castle theme does not match the modern cartoon soldiers or unlock statues in the reference, and it is an asset pack rather than this game mechanic.
- [Godot's shooter catalog](https://godotengine.org/asset-library/asset?filter=shooter&page=0&sort=updated) exposes multiple shooter examples, primarily FPS and 2D. No exact source-template relationship was verified.

Recommendation: a small standalone Godot scene implementing the observed loop is a closer starting point than retrofitting an FPS template. Original purpose-built character models can match the proportions and material language without importing an unrelated art style. No external code or asset was downloaded or integrated by this audit.
