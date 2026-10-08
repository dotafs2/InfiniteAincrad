# Read-only release coverage audit — 2026-09-30

**No additional product or registration blocker found for the four focused fixes.** This is a static registration/input audit plus inspection of the existing focused receipts. It is not a successful final release receipt. Rain admission's final independent review and the restarted full source/PCK gate remain outstanding at this cutoff.

No product, test or release registration was edited. No Godot, full gate, browser, native capture or audio playback was started. A short Python read-only inspection enumerated the registered tests and calculated the gate's input hashes; its receipt is `audit.json` beside this file.

## Registered coverage

| Fix | Registered author/reviewer coverage | Additional relevant protected coverage |
| --- | --- | --- |
| Music | `music` 125; `music_review` 118 | Both Ogg files, import recipes, composer, manifest, controller and bus layout are in the frozen-input set |
| Movement BOOST | `boost` 55; `boost_review` 98 | Actual game/hole/UI scripts and both tests are protected |
| Six original skins and card light | `skin_polish` 486; `skin_polish_review` 760 | `skin_rarity_review` 1,555; mobile thumbnails 695; catalog/FX regressions remain registered |
| Food progression/layout | `food_growth` 2,202; `food_growth_review` 1,476 | Geometry finish 136, author collision 156, collision review 18,276, rain continuity 33, existing density/round/extension suites remain registered |

The inspected registry has **74 unique suites**, all resolving to existing files, and **783 guarded input files**. The newly registered `rain_admission` author suite has a 71-check minimum; its independent reviewer is still expected to add the final suite. This audit intentionally does not predict a final check total or label the forthcoming 75-suite registry as already inspected.

Both source and isolated-package passes iterate the same `SUITES` list. Each suite requires its completion marker, an empty failure list, its registered minimum and strict unexpected-engine-error acceptance. Package tests use the candidate PCK with candidate working directory, while the external harness scripts are bound in the source hash set. The inspected new suites have no dependency on excluded artifact files: the skin review embeds its old-geometry signatures and the other fixtures load real `res://` resources. Optional report writers are not required by the gate's stdout receipts.

The input manifest includes all fidelity/scripts/assets (including `.import` recipes), project/export settings, the gate itself, every registered test, `build_music.py` and `build_food_neighborhoods.py`. The six-skin module and catalog, the real UI, food builder/body/plan, audio source/bus/files and the changed tests are covered. `verify_inputs` is called after source checks and again after package checks. Publication verifies copied candidate file checksums before and after the local directory switch. These mechanisms support stable release evidence; this audit did not run or certify the switch.

Current inspected food-city SHA is `a8591b3b5b43e10440018e5b365411c64bf9d20e5addedcd97a9aaa97128b999`; UI SHA is `a712da36e7cce8e3124b5fe502e933d440c64baf34ec3b3e29a20a220e63762c`.

## Real card lighting

`make_card_preview` now puts one `WorldEnvironment` and one enabled, shadow-free `DirectionalLight3D` inside each `own_world_3d` card. The environment resource is shared; nodes are owned by their respective card. The light is warm and has positive energy, and the ambient color/energy are explicitly supplied. The model therefore no longer relies on unrelated map or hidden-preview lighting.

The existing focus function only gives `UPDATE_ALWAYS` and model processing to the selected card; others render once. The independent 760-check suite inspects these actual mounted worlds, camera bounds at two viewport sizes, natural frame advancement and freeing lights with cards. Its negative fixture rejects the old camera/model-only world. This provides scene-level evidence of the fix, not a rendered Web pixel comparison.

## Draft report corrections reported to the root author

The draft `docs/feel-20260930/README.md` was otherwise appropriately limited: it distinguishes Blender previews from gameplay captures, does not claim subjective musical acceptance, and explicitly excludes phone FPS and measured retention.

Three pending editorial corrections were identified:

1. The Delivery section still says a **73-suite gate is running**. The earlier run stopped at the rain invariant, the inspected registry is now 74, and a further independent suite is pending. Update status/count only from the actual final registration and release receipt.
2. “Three historical expectations intentionally changed” must account for the additional rain-budget expectation maintenance once its review completes. The all-time airborne maximum is not the new-admission quota when existing foods legitimately reactivate.
3. The touch-driven food route summary should visibly state that rivals are retired and rain is disabled in that reproducible fixture. The linked independent report already states these controls. Genuine input/physics does not turn a controlled route into an uncontrolled competitive playthrough.

These are reporting corrections, not reasons to change gameplay or weaken acceptance. Final package success, source stability and delivered static hashes still need the root-owned final verification. No current browser appearance or real-device sound/performance verdict is implied.

## Draft follow-up

The root author addressed all three wording findings before final acceptance: the report now marks the gate pending, includes rain-budget maintenance, and states the controlled route's disabled-rain/retired-rival scope. The revised draft SHA is recorded in `audit.json`. The audit cutoff remains **74 suites / 783 inputs**; the expected subsequent 75/784 registration is not retrospectively claimed as inspected. No present blocker remains from this audit.
