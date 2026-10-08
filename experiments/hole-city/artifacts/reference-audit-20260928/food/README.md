# Food reference audit evidence

Current v0.7.0, September 28, 2026. These files contain measured headless
simulation and static plan inspection, not screenshots, GPU benchmarks,
phone playback or human-play results. No runtime file was changed.

From the game project directory:

```sh
.build/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --script artifacts/reference-audit-20260928/food/probe.gd --fixed-fps 60 --log-file /tmp/food-reference-audit.engine.log -- --test
```

The probe keeps the starting mouth stationary, disables collection and rival
movement, and uses the actual rain/spawn/landing physics for 75 simulated
seconds. It then starts a fresh round, enables the normal autoplay steering,
retires opponents and observes the ordinary score/food completion condition.
No score is injected into the solo round. `--test` skips the player's save.

`probe.json` records four rain waves / 24 bodies by ten seconds and no new
waves through 75 seconds, despite all rain being nearly stationary by fifteen
seconds. It also records the solo round result, remaining building tiers and
moving bodies frozen by the result transition. `plan-metrics.json` uses the
authored JSON plan and Euclidean polyline lengths, not image estimation.

The owned Godot helper process exited normally. Its log contains a macOS
system CA certificate lookup diagnostic; this is not reported as a game bug.
The preview server and foreground applications were not touched.
