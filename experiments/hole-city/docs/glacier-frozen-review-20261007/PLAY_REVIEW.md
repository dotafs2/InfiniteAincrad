# Glacier map independent play and readability review

## Review 01 — baseline rejected

Reviewed October 7, 2026 by the independent gameplay/readability reviewer. This is a read-only review of source and existing evidence; no engine, export, phone, account, production save or gameplay mutation was run by this reviewer.

Evidence inspected:

- `artifacts/frostlight-village-20261006/gpu-review-anchor-final-01/frostlight-world-overview.png`
- `artifacts/frostlight-village-20261006/gpu-review-anchor-final-01/frostlight-polar-life.png`
- `artifacts/frostlight-village-20261006/gpu-asset-closeup-iteration-02/glacier-hero-closeup.png`
- The corresponding GPU capture manifest, `fidelity/frost_city.gd`, `frost_neighborhoods.gd`, `frost_ground.gdshader`, the inherited `toy_city.gd` and `toy_court.gd`, and the three Frostlight acceptance tests.
- `artifacts/frostlight-village-20261006/frostlight-gameplay-parity-08/report.json`.

The baseline does not meet the user's requested convincing icy landscape. Its working mechanics are worth preserving, but its repeated geometry and inherited town organization do not become a glacier merely because the castles have been hidden.

### Findings that affect play or environmental coherence

1. **The map reads as a tiled town/prop field.** The actual overview shows straight cyan brick roads, rectangular blocks, repeating narrow cones and a near-white ground. The larger visual targets occupy separate rectangular parcels; most wildlife and expedition bodies are peripheral and easy to miss. Route openness is useful, but the roads should read as frozen channels, snow passages or pressure cracks, with broader glacier shelves and grouped massing making some recognizable destinations.
2. **The inherited living world still looks like another map.** The Frostlight branch runs `ToyCity.build()` and retains `RoyalToyCourt` and its active court bodies/assemblies. Only five architectural kinds receive replacement art. Many small toys, vehicles and royal actors remain in the busy center, while newly added polar species are static edible bodies. Fourteen species counters do not demonstrate fourteen living behavior systems. Preserve living-world density, but make the visible roles, silhouettes and activity understandable as an expedition ecosystem.
3. **Detached snow decoration can outlive food.** `_build_snow_caps()` places each glacier's snow cap under `decor_root` using its initial world position. It is not parented to the corresponding edible body or removed on collection. A disappearing or moving glacier can therefore leave a cap suspended. The same rule should be checked for all new attached snow/ice accent geometry.
4. **Visual scale and collider scale are only partially verified.** The old architecture collider remains, while the visible glacier uses 62% of its height. The grounding test checks constant source bounds, visual floor, center and an upper envelope; it does not measure the imported mesh dynamically or demonstrate an intuitive edible width at the gameplay camera. Fresh geometry needs measured AABBs, a sensible visible footprint and no invisible shelf/arch snagging during real intake.
5. **Existing parity is a unit-level admission test, not ordinary progression evidence.** It disables rival AI and unrelated collisions, manually calls `award(240)`/`award(2400)`, teleports the hole and directly invokes `begin_swallow`. Its 12 checks prove that two selected bodies can score exactly once and feed the shared receipt. They do not prove that a new player can follow the authored food chain and reach the large edible glacier within the ordinary 90-second round.
6. **Performance evidence is missing after batching is detached.** `_detach_inherited_batches()` hides the inherited batches, restores every underlying mesh and clears body handles; each of 180 glaciers then instantiates a multi-mesh Blender scene. This can cost substantially more draws than the old map despite a low body count. Record real GPU visible objects/primitives/draw calls and a bounded ordinary run before claiming acceptable rendering cost. Preserve geometry reuse and avoid per-object lights, volumetrics or refraction passes.

### Acceptance criteria for revised candidate

- At both a whole-map view and the normal portrait gameplay camera, the world reads as a natural Arctic glacier landscape. Broad layered ice masses, breaks/shelves, snow crest coverage, visible pale-to-deep-blue material contrast and a small number of landmarks should replace the repeated needle/brick-grid impression. The hole and nearby edible objects must stay readable.
- The route system remains open and traversable. Show small, medium and late-game edible targets without making visible empty spaces appear blocked. Polar animals, a research area and a ship area should be recognizable during actual play, not only as tiny perimeter additions.
- Keep at least ten authored polar/expedition/ecology systems present. Clearly distinguish static props from living actors; do not claim counts alone prove behavior. Reskin/adapt existing court movement where practical instead of removing all life to simplify the scene.
- Imported glacier and ice-rock geometry remains closed and correctly oriented, anchored to the food body, and within a sensible collision envelope. Visual-only attachments follow their food and disappear exactly once. Test collection and support/collapse transitions with the rendered meshes intact.
- Record a normal 90-second isolated-save round using real movement and ordinary collection, without score/radius injection, target teleportation or disabled environmental collisions. Log score/radius/eaten progression and collected tiers with normal rivals enabled. A second distinct route is desirable when the first does not approach the late chain. Admit limitations if the large landmark is not naturally reached; do not use the parity fixture as a substitute.
- Keep the useful direct admission/score tests and add focused evidence for any newly exposed attachment or collider mismatch. Preserve round duration, accepted score-to-coins ratio, the other maps, all 200 skins and existing save IDs.
- Report actual desktop rendering counters at fixed initial/mid/late camera positions, with a clear distinction between real-time measurements and fixed-step capture. Draw/triangle growth must be accounted for. Do not claim phone performance without testing the phone.

Verdict: **REJECT / revise**. The baseline evidence is insufficient for both landscape presentation and ordinary progression acceptance. This verdict can change only after inspecting revised real renders and focused gameplay/attachment/performance evidence, not solely a passing full regression gate.

## Focused verification harness prepared

The root explicitly expanded this reviewer's ownership to two new test files:

- `tests/glacier_frozen_review_acceptance.gd`: actual imported bounds, position-welded edge closure, static-batch release, attached visual lifetime and once-only point settlement. Two isolated admission probes grant growth/reposition the hole and are labelled as such; they are not progression evidence.
- `tests/glacier_frozen_gameplay_capture.gd`: a normal 90-second portrait round using the ordinary movement direction and charged-boost APIs, all original rivals/collisions, no injected growth or target positions, isolated save, muted output, timed real GPU stills and draw/primitive counters. Optional frame sequence output supports a muted video. Fixed-step recordings must not be described as real-time performance.

No engine was run by this reviewer. Root owns compile/execution so heavy jobs remain serialized. Initial rejection remains until current runtime output and outcomes are reviewed.

## Review 02 — first revised renders, still not accepted

Inspected the actual `render-01/opening-basin.png`, `world-overview.png` and `polar-life.png`. The removed brick grid, thicker shelf silhouettes, grouped penguins/scientists and clearer snow caps are substantive improvements. There are now recognizable small-to-large ice objects and active-world polar substitutions. However, the large masses still resemble repeated tall polygonal containers, and the broad background looks like a smooth blue tabletop. The full overview retains four concentrated center clusters and evenly spaced perimeter monuments. This is better than the baseline but does not yet supply the intended glacier landscape hierarchy. No ordinary progression or performance result is available at this review point; acceptance remains pending.

Root's first acceptance parse exposed a harness inference error (`handles` from a dynamic body property). Fixed that declaration and the corresponding dynamic `initial_bodies` declaration in the capture script to explicit `int`. The failure log remains at `build/glacier-frozen-review-20261007/acceptance-01.log`. No runtime game code was changed by this reviewer and no engine was run here.

## Review 03 — revised gameplay presentation accepted; expanded lifecycle check pending

Inspected real portrait frames `gameplay-01/gameplay-000.png`, `015`, `045` and `075` plus the full `gameplay-01/report.json` and `acceptance-02.json`. The later models now have inclined broken crests, snow-covered upper faces and legible dark/light ice planes. Small scattered chips and medium bodies are easy to distinguish from surrounding landmarks. The ordinary camera retains visible movement spaces; the 75-second frame shows a glacier assembly actually descending into the hole without new exposed inner faces or detached snow hats.

The input-only 90-second route ends at score341, level7/radius6, one rival swallowed, no deaths and34coins. Player item receipts total107:65 ice chips,21 glacier bodies,11 cargo sleds,9 drones and1 penguin, spanning tiers1–6. `eaten:441` is the shared world collection counter, not the player's item count. At the finish366 edible bodies and18 larger targets remain. This establishes meaningful ordinary growth and retained later targets for this route. It does not prove that every player reaches the largest tier7–9 landmarks or that the whole map is explored in one round.

The first focused869checks pass measured imported floor alignment, closed source edges, six variants and two complete real-gravity lifecycle probes. Those two selected owners were unbatched. The test has therefore been strengthened, without changing runtime behavior: include imported ice chips, explicitly require at least three variants, prefer a genuinely batched unsupported standalone owner, check its shared pool count decreases by exactly that owner's handle count, and exercise a third chip lifecycle. Standalone owners avoid conflating a support-chain release with the intended single-body receipt assertion.

Multipart polar mesh merging substantially lowers actual normal-camera counters:464 draws at start,412/352/315/233 at15/30/45/60seconds,311 at75seconds and210 at finish. These are actual GPU draw counters; the capture was accelerated/fixed-step and cannot certify real-time phone frame rate. The older958-draw focused receipt predates that merge and must not be presented as the final ordinary-play result.

Current verdict: **ACCEPT the revised playable landscape presentation, conditional only on the expanded focused lifecycle checks and final regression gate passing.** No additional feature scope is required for this review. The species remain stylized simple geometry and the mobile device performance is unmeasured; these are documented limits, not a new request to replace the now-working map.

## Review 04 — focused gameplay and geometry acceptance confirmed

Read the actual `artifacts/glacier-frozen-review-20261007/acceptance-03.json` receipt: **2,487 checks, zero failures**. It dynamically examines609 imported edible owners across six authored mesh variants. All six unique imported meshes have zero open boundary edges, non-manifold edges and degenerate triangles. Worst floor error is approximately0.00000024 world units; visible width remains95% of the corresponding collision envelope. Detached tall snow-cap count is zero.

The newly selected rock, glacier and chip are each actual batched standalone owners. Each real admission retires exactly one batch handle; each body and its owned geometry disappears after gravity settlement, with exactly one authored score credit and one collection counter increment. Initial portrait draw calls are now464 in the focused receipt, confirming the earlier958-call cost was reduced at the same camera.

**Final reviewer verdict: ACCEPT for desktop map appearance, readable ordinary progression and the tested geometry/collection lifecycle.** The full repository/package regression gate remains the root's release requirement. Mobile GPU performance and broad human pacing are still unmeasured; this reviewer does not certify either. No extra feature demand remains.

For the final muted video, the capture harness now records every saved frame filename with its actual `game.elapsed`/remaining time, includes an explicit render seed, and lets four ordinary physics ticks settle the cut/camera before the opening still. Encoding must use recorded timestamp differences instead of assuming a constant output frame interval. These are capture-only changes; there are no gameplay grants or runtime source edits by this reviewer.
