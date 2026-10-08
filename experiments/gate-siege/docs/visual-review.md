# Independent visual fidelity review

Reviewer: reference-audit worker. Date: 2026-10-08.

## Pass 1: first real GPU render — rejected

Evidence reviewed: `artifacts/first-render/demo-0002.png`, `demo-0300.png`, `demo-0600.png`, `demo-0900.png`, `demo-1200.png`, `demo-1500.png` and `demo-metrics.json`. Comparison source: the local video and exact-timestamp frames described in `reference-audit.md`.

These rendered captures establish that a 3D scene and gate/shooting/upgrade loop exist. They do not establish close visual fidelity, reference pacing or independent playable behavior. Frame-number suffixes are capture labels, not verified timestamps.

### Blocking fidelity gaps

| Priority | Observed gap | Concrete correction | Acceptance evidence |
| --- | --- | --- | --- |
| P1 | Severe overexposure makes the floor, crowd and recruit nearly white. Several figures are hard to distinguish at all. | Reduce environment/light energy and exposure until the runway is warm gray, enemy caps are red and recruit clothing is blue. Retain highlights without clipping material color. | An ordinary live frame with readable red troop heads, pale faces, blue clothing and gray floor simultaneously. |
| P1 | Camera is too distant/high relative to scene content. Recruit lies around screen Y 0.88 and is almost invisible. Source has player around Y 0.75–0.80 with bosses/statues dominating the upper view. | Move/reframe the camera and adjust scene dimensions. Maintain the source's perspective taper and make the player, hero statue and boss occupy comparable image area. | Matched 9:16 captures at recruit stage and minigunner stage. |
| P1 | A white right-hand runway continues all the way behind the upgrade statue. The reference has an isolated station with black void immediately behind it; only the left enemy lane continues toward the top. | End the right floor at the upgrade recess and keep the far-right area black. Model the station as a recessed/raised platform with a front plinth. | The upper right beyond the statue is dark void in an uncropped gameplay capture. |
| P1 | Crowd characters are tiny repeated dots relative to lane width. The reference front ranks show individual red caps, faces and dark bodies while keeping hundreds of bodies in ordered rows. | Enlarge crowd individuals and tune row/column spacing. Preserve a long dense formation, not a thin handful of enlarged actors. | Full view plus a crop of front ranks showing legible body silhouettes. |
| P1 | Statues and bosses occupy much less screen space than the source. The source silver gunner fills most of the upper-right station and looms much larger than the recruit. | After camera repair, separately verify actor scale, station width and rear-lane width. Do not assume one camera change solves relative actor scale. | Side-by-side ordinary recruit-stage frame with similar statue/player and boss/player area ratios. |
| P1 | The ×999 object is a flat fluorescent yellow rectangle with a simple printed label. Source has thick metallic gold cladding, embossed gold characters, irregular chipped edges, debris and an emerging blue board. | Add material depth and recognizable shell geometry; show cumulative damage by removing/reducing shell portions, not only spawning tiny dots on an intact rectangle. | Early intact gold gate plus later partially removed shell exposing the blue ×999 face. |
| P1 | Upgraded shots in `demo-1200/1500` read as thin green line segments. Source uses luminous translucent cyan bolts/trails and visibly dense replicated rows. | Shift hue from green to cyan, increase rendered body/trail width, add controlled translucency/glow, and present higher density behind active gates. | Minigunner shot stream visibly changes density at ×5 and ×2 while retaining cyan color. |
| P1 | Gate/counter typography looks thin and outline-dominated. The source uses heavy white faces and thick black outlines. Boss HP is a very thin bar rather than the source's rounded dark/red capsule. | Use a genuine bold font weight, opaque white fill, heavier dark stroke, and a readable rounded health bar. Avoid decorative text being hidden behind boards. | ×2, ×5, statue countdown and boss HP are legible at full portrait viewing size. |

### Secondary issues

- The permanent lower instruction plus a second initial tutorial line are much more obtrusive than the source. A brief introductory hint can serve usability, but it should clear before ordinary combat captures; it must not mask the recruit.
- The initial boss displays `1200` and statue `60`, while the source's observed values include `1060` and `59`. These are not the leading visual defects, and `1060` is not proven to be the source boss's initial maximum. Keep reconstruction values documented rather than claiming exact source balancing.
- The source's yellow shots are chunky teardrop/streak shapes. The initial implementation's thin straight dashes have much weaker screen presence.
- The source floor is mostly matte, while hero shells are glossy metal. A global exposure reduction alone must not eliminate that material distinction.

### Behavior and evidence limits

The metrics file reports one recruit upgrade, gate5 crossings, one gate2 crossing, no ×999 crossing and no defeated boss at elapsed 16.1 seconds. This is useful internal evidence of implemented events, but it is not sufficient to certify that the reference's crowd-clearing pressure, upgrade leap, progressive shell removal, boss death or later target choices match.

No hands-on input or continuous playback was reviewed in this pass. There is no acceptance for exact recreation. A subsequent pass must inspect improved real GPU captures and a continuous normal play segment, including lateral steering that changes which target receives damage.

## Pass 3: substantially clearer, still rejected for close fidelity

Evidence reviewed: `artifacts/third-render/demo-0300.png`, `demo-0900.png`, `demo-1800.png`, `demo-metrics.json`, and a read-only inspection of the current `scripts/game.gd`. This review does not certify later edits made after those captures.

### Improvements supported by the new evidence

- The scene is now readable: gray floor, red crowd, blue player/hero and distinct gold material.
- The false right runway is removed, leaving the correct dark void behind the station.
- Gate/countdown labels are bolder and readable.
- The gold gate has physical cladding and an embossed face; the later frame exposes the blue board and white ×999 label.
- The silver hero progressively reveals blue material. A capture at zero shows the released hero off its pedestal; the inspected code contains the 0.85-second transfer arc.
- The player is closer to the correct vertical position.

### Highest-impact remaining visual gaps

| Priority | Remaining issue | Measured/visible evidence | Required direction |
| --- | --- | --- | --- |
| P1 | Player remains substantially too small. | Recruit is about 34/864 of image height (0.039), versus about 100/1280 (0.078) in the source; minigunner is about 60/864 (0.069), versus about 150/1280 (0.117). These are approximate silhouette measurements. | Increase player models roughly 1.7–2 times, then verify weapon and shadow framing during movement. |
| P1 | Station and statue are too narrow/small relative to left lane. | Current station is roughly 90 pixels wide against 190 for the left lane, or about a 32/68 split. Source station is approximately 276 against 314, or 47/53. Current statue occupies about 0.14 image height, source about 0.29. | Widen the right station and enlarge its actor. A 30% actor-only increase is unlikely to close the full difference. |
| P1 | Dense crowd still looks like a red/green patterned carpet. | Front troop silhouettes remain roughly half the useful source size. | Larger individual bodies and predominantly red cap/coat mass, retaining dense ranks. Avoid relying on density alone. |
| P1 | Boss is small and its health label clips above the top edge. | Both early captures clip part of `1200`; the boss occupies much less image area than the source brute. | Enlarge/reposition the boss and keep its health capsule inside the viewport when close enough to engage. The source does sometimes crop at the far top, but the recreated early composition should not lose the bar as a default. |
| P1 | Upgraded ammunition still renders green and thin in these captures. | `demo-1800.png` shows detached bright green rods with sparse repetition. | Verify final rendered cyan color after material multiplication, thicken trails, and compare a gate-aligned left-lane volley. Changing instance color alone may not fix a tinted base material. |
| P2 | The lower tutorial remains prominent during the early combat frame. | Text is visible across the runway at `demo-0300.png`. | Dismiss early enough that normal action uses the sparse source layout. |

### Reference mechanics still missing or unverified

1. **Boss whole-body hit flash and death fade:** in the inspected code, `_damage_boss` emits particles and wobbles the model, then immediately hides it at zero. The source turns the full body pale on hits and briefly shows a faded/ghosted body at defeat. No pass-3 capture demonstrates this effect.
2. **White troop death silhouettes:** the inspected `_damage_crowd` appends `kill_flashes`, but the inspected rendering path does not draw them. The source's front rows repeatedly turn pale before disappearing. This must be checked after later edits rather than assumed implemented because the array exists.
3. **Next statue rising into the empty station:** the source visibly begins bringing up the gold rocket figure after the minigunner transfer. A replacement model exists in the new frames; its entrance animation is not demonstrated by those static images.
4. **First boss defeat followed by the pink boss approach in one continuous segment:** the metrics at 16.65 seconds show no boss defeat, and every reviewed capture keeps the first boss at 1200. This does not prove the boss cannot be killed; it means source-like crowd suppression and wave pressure have not yet been demonstrated. The source first brute is dead by roughly 10.5 seconds and the second heavy is visible soon afterward.
5. **Dense cyan volleys through both active gates:** a right-side stream is visible, but the key reference composition of cyan rows sweeping the crowd behind ×5 and ×2 is absent from these three captures.
6. **Independent input and persistent target choices:** no hands-on steering was performed in this visual pass. A recorded automatic script is insufficient evidence that a player can independently choose crowd suppression, statue progress or gold erosion and see the corresponding state change.

The principal loop is now structurally represented. Approval remains withheld for close visual fidelity until the relative scale, final cyan rendering and continuous impact/progression evidence are resolved. Pixel identity and unseen source mechanics remain uncertifiable from the reference clip.

## Final recorded pass: core observed actions implemented; exact recreation not certified

Evidence reviewed: all eleven `artifacts/fidelity-final/time-*.png` captures, `demo-metrics.json`, and eight independently extracted frames from `gameplay.avi` at 9.3, 9.6, 9.8, 10.4, 10.7, 11.0, 11.3 and 11.6 seconds. The AVI is 486 × 864 at 30 fps and 36.033 seconds long. Temporary extracted frames are under `/private/tmp/gate-siege-final-audit/`.

This pass verifies the visual events below in the actual rendered game. It does not substitute for the separate input/runtime audit, and it does not certify the source's unseen balancing or rules.

| Observed reference action | Final rendered evidence | Assessment |
| --- | --- | --- |
| Recruit automatically fires yellow shots while moving sideways. | 0.1, 5 and 8 second images place the recruit in different lateral positions with yellow projectiles. | Visually implemented. The capture is an automatic demo, so independent manual steering must be verified separately. |
| Shots replicate after ×5 and ×2. | At 5 seconds there are repeated yellow rows before and after the left ×2. At 10.4 seconds cyan rows expand between both gates and attack the boss. | Visually implemented. |
| Dense red troops turn pale when removed. | At 5 and 35 seconds, front-row white troop silhouettes are visible in cleared channels. | Visually implemented; bounded white casualty rendering is visible. |
| Right statue counts down and progressively reveals its blue hero. | Silver figure starts at 60; at 8 seconds it is partly blue with 45 remaining; at 9 seconds it is released at zero. | Visually implemented. Values are reconstruction choices. |
| Released hero travels from station to player. | AVI extractions at 9.3 and 9.6 seconds show the hero in a visible airborne transfer, with the station empty. | Visually implemented. |
| Upgrade changes player silhouette and ammunition. | At 10 seconds the larger minigunner fires thick, correctly cyan projectiles and `LEVEL UP` appears. | Visually implemented. The earlier green-material defect is resolved. |
| The next gold hero rises into the station. | At 9.8 seconds the gold figure is partly emerged; at 10 seconds it is fully standing. | Visually implemented. |
| Boss reacts to hits, reaches zero and disappears. | At 10.4 seconds first boss is 865; at 10.7 it is 145 with white hit effect; at 11.0 it is at zero and shrinking/sinking; by 11.3 it is gone. | Implemented, with the flash rendering defect noted below in this reviewed capture. |
| Gold ×999 cladding erodes to reveal a blue active-looking board. | At 0.1 seconds the gate has its gold embossed face; at 16 seconds it has a white ×999 label over blue with a remaining gold strip. | Visually implemented. Later complete activation is a reconstructed extension because the source never shows it. |
| A distinct second pink heavy approaches. | At 28 seconds a pink heavy is visible with white impact/death feedback. | Implemented, but later in this play trace than the source. |

The final metrics report 593 shots, 270 ×5 crossings, 387 ×2 crossings, 33 ×999 crossings, two hero upgrades and two defeated bosses over 36.0167 simulation seconds. These internal counts agree with the presence of later upgrades/waves in the captures; they do not independently prove every individual collision.

### Remaining differences from the source

1. **The result remains visibly distinct art.** The recreated characters have rounder, simpler body parts, a different recruit outfit, minigunner equipment/back silhouette and rocket armor. The source has more detailed faces, clothing folds, belts and asymmetrical equipment. Glossy chrome/gold materials in the recreation have stronger simple highlights than the source's more nuanced shading.
2. **Upper battlefield framing is still narrower.** The source's left lane and right station together nearly fill the width near the ×2 barrier. The recreation retains larger dark side margins, narrower statue space and more empty foreground floor. Player size is now much closer, especially the minigunner, but this does not make the overall composition identical.
3. **Crowd appearance differs.** Red helmet silhouettes now read clearly and are substantially closer than the earlier carpet-like rendering. Individual fronts remain small and repetitive, and cleared channels leave long edge columns in the final play trace. The source more often clears broad front rows and maintains a solid incoming block.
4. **Projectile appearance differs despite correct cyan.** The recreation uses clean, evenly spaced rods/streaks; the source uses softer translucent trails and denser, less visually separated cyan volley sheets. Both demonstrate multiplication, but they do not render identically.
5. **HUD and hit/bar styling differ.** A wave label, green status line, sound/pause buttons and transient lower instructions are additions. The source's boss bar is a broad rounded capsule, and its level-up text/ring are more emphatic. The recreation's boss health remains a thin rectangular bar.
6. **Post-upgrade pacing differs.** First minigunner acquisition and first boss death now occur near the source's 9.5 and 10.5 second events. The recreation then spends longer clearing leftover edge columns before showing the pink heavy around 28 seconds; the source shows that heavy much earlier. Target choices in a live run naturally affect timing, so this is a trace comparison rather than proof of a fixed timer error.
7. **Later behavior is an authored extension.** The source ends with rocket statue progress still at 37, gold still on ×999 and the pink heavy alive. The recreation obtains the rocket hero, uses ×999 and continues into further waves. These additions make it a complete playable interpretation; they cannot be described as footage-verified source behavior.

### Small rendering defect reported from this capture

At 10.7 seconds, the boss hit flash is a patchwork of white and original colors. Read-only code inspection shows an exactly duplicated `boss_flash` mesh rendered at the same transform while the original `boss_model` stays visible. This creates coplanar depth fighting instead of a clean whole-body flash. The finding was sent to the implementation owner with a direct repair: hide the normal boss model while the flash copy is visible, then restore it. Any later repair must be verified against its own newer capture; the `fidelity-final` AVI remains evidence of the pre-repair state.

### Reviewer conclusion

The final recorded version implements the principal actions observable in the video and repairs the major initial defects in lighting, color, player scale, station void, shell reveal, upgrade transfer, casualty effects and cyan multiplication. It is a recognizable reconstruction of the reference's gate-shooter concept. It remains a distinct rendering and a partly inferred game design; neither pixel identity nor complete replication of the original game is certified. This visual review does not make a claim about phone performance, audio matching, save behavior or human input coverage.

## Accepted-package flash repair — concrete defect closed

Follow-up evidence: `artifacts/accepted/boss-flash.png`, captured at 10.7 seconds from the isolated final exported package, as identified by the implementation owner. The related final movie is `artifacts/accepted/gameplay.mp4`. This follow-up is limited to the reported boss flash defect and nearby HUD rendering; it does not repeat the broader review above.

The new screenshot shows a clean, continuous white boss silhouette at 145 health. The former alternating white/red surface patches are gone. Read-only inspection confirms the normal model is hidden while the flash copy is visible (`boss_model.visible = not boss_flash.visible`). The concrete coplanar rendering defect is closed. The bold ASCII HUD and `LEVEL UP` text also render legibly in this package capture.

**Accepted scope:** the principal reference-observed visual actions and the repaired boss feedback are accepted as implemented in a recognizable playable reconstruction. The separate runtime review owns its input/collision assertions; this visual follow-up does not independently recertify those tests.

**Remaining limits:** the seven source differences documented in the final recorded pass remain, including distinct authored character art, narrower upper framing, projectile texture, added HUD, differing later pacing and behavior beyond the source clip. This is not an acceptance of pixel identity or a claim that the complete original game has been reproduced. No phone-performance or source-audio match is certified.
