# Independent review: portrait walking-window fixture

Reviewer: food-city implementation agent, separate from the root test author.

**PASS, 30 assertions**, rerun directly against the actual game scene with `--test`. This correction changes the observation time, not runtime movement or animation behavior.

The runtime resting condition is `fmod(game.elapsed + citizen.phase + rest_offset, rest_cycle) > rest_cycle - rest_window`, unless panicking. The diagnostic baseline started the chosen jogger at a rest-clock value of 13.851192 s and ended the forty-frame observation at 14.517859 s. Its rest window begins at 14.5 s. The character had moved approximately 0.367 m and correctly changed from Walk to Idle as the observation entered rest. The failed expectation was the final-frame Walk assertion, not an absence of locomotion.

The revised anchor is `2 * rest_cycle + 2 - phase - rest_offset`. Substituting it into the actual runtime expression gives a rest-clock value of exactly 2 s. Forty 60 Hz frames end around 2.666667 s, well inside this jogger's walking interval ending at 14.5 s. The independent phase and rest offset are included, so changing the seeded layout no longer accidentally places this observation across the rest boundary. Existing baseline/rest-only diagnostic traces corroborate that changing only this clock placement keeps Walk throughout and produces approximately 0.387 m of real movement.

The assertions remain strict: the final clip must still be Walk **and** actual world displacement must exceed 0.03 m. A nearby player must subsequently produce Run, and the explicit rest-window observation must produce Idle. Imported looping skeleton tracks and a changing thigh pose, portrait touch movement, drag ownership, pause/resume, distinct model counts and role coverage remain checked. The correction does not force the observed clip, freeze the controller or change rival behavior.

Command: `.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script res://tests/portrait_acceptance.gd --log-file /tmp/hole-portrait-fixture-review.log -- --test --report=res://artifacts/fixes-20260928/food/portrait-fixture-review.json`.

Evidence: `artifacts/fixes-20260928/food/portrait-fixture-review.json`, the adjacent `.log`, and `portrait-fixture-source-hashes.json`. Existing causal traces are in `artifacts/audit-fixes-20260928/city/portrait-diagnosis/`. All 30 assertions passed, with 64 citizens, 208 unique models and 656 city edibles. No runtime file, user save, preview, or foreground application was modified. No CPU timing claim is made from this concurrent acceptance run.
