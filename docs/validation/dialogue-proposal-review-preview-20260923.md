# Dialogue proposal review preview — 2026-09-23

This is a bounded, read-only replay of the three saved local Ollama proposals. It reads `docs/validation/local-npc-dialogue-20260923/contexts.json` and `raw.json`, then passes each raw string and its independently exported fixture to `DialogueProposalReview.review`. No world scene is loaded, no model or HTTP request is made, and no proposal is executed.

The screen keeps the review boundary visible: **SAVED LOCAL OUTPUT / NOT EXECUTED / INTENT CHECK ONLY**. It shows the saved spoken line, declared intent, expected intent list, canonical action selected by the structural contract, structural result, intent-review status, and the contract reason. Private thought is never rendered. `execution` must remain `not_attempted`, and `semantic_truth_verification` remains false; a review result does not establish that a claim is true or authorize a lifecycle transition.

Use `N`/`P` or the Previous/Next buttons to inspect all three cases. A deterministic capture can be requested with the managed Godot wrapper, for example:

```powershell
$godot = 'D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
$env:DOTNET_ROOT = 'C:\Program Files\dotnet'
$env:DOTNET_ROOT_X64 = $env:DOTNET_ROOT
$env:DOTNET_ROLL_FORWARD = 'LatestMajor'
python tools/run_godot.py --godot $godot --name dialogue-review-acceptance --timeout 35 --out tmp/review-check -- --headless --script res://tests/dialogue_proposal_review_preview_acceptance.gd
# Open the interactive review directly; close the window when finished.
& $godot --path game --rendering-method gl_compatibility res://scenes/dialogue_proposal_review_preview.tscn
# For a finite graphical capture, use a fresh absolute output directory.
python tools/run_godot.py --godot $godot --name dialogue-review-capture --timeout 35 --out tmp/review-capture-log -- --rendering-method gl_compatibility --resolution 1400x900 res://scenes/dialogue_proposal_review_preview.tscn -- --capture-dir=D:/tmp/dialogue-review-new --case=2
```

The capture writes `review_capture.json` and, when a graphical renderer is available, a case-specific PNG. In headless mode it records `screenshot_saved:false` without waiting for a rendering signal. The acceptance test requires exactly three loaded cases, the complete review result shape, `not_attempted` execution, false semantic verification, no private-thought leakage, and a meaningful loaded/error status rather than a default success.

The preview is fixture-only presentation evidence. It does not claim semantic correctness, execution, autonomous resident behavior, or any cloud-savings measurement.

Verification completed: the saved three-case preview acceptance suite passed, and an invalid `--case=9` capture exited 2 with `capture_valid_case:false`, without falling back to case zero. Archived logs are in `private/iteration-20260923/proposal-review-preview/`. The parent then rendered case 3 off-screen with Mono/OpenGL on the RTX 5080 and inspected the [screenshot](dialogue-proposal-review-preview-20260923/smith_missing_iron_review.png). Its [capture record](dialogue-proposal-review-preview-20260923/review_capture.json) includes the public review fields, `execution_authorized:false`, and `screenshot_saved:true`. Rendering exited 0 with all three owned processes stopped; logs are in `private/iteration-20260923/proposal-review-render/`.
