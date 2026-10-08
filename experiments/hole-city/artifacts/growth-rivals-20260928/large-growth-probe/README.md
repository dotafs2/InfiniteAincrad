# Bounded large-growth CPU probe

Prepared for an exclusive CPU sampling slot. Preparation does not constitute a measured result.

`large_growth_profile.gd` subclasses the current game and overrides only the completion predicate to return false. Its other overrides count calls or sample the existing active-body index, then execute the original implementation. The full gameplay physics loop, rival scans, food admission, AI controllers, gravity, collisions, food rain, camera and reveal controller remain active. The ordinary round timer has ample time for this eleven-second simulated scenario.

The player receives a real 5000-point award and starts at level 19 with radius 23.9167. Seven rivals use the existing grown-profile starting fixture: 350 points, level 8, radius 7.2, and the same distributed positions. Subsequent collections and rival encounters can change scores, radii and the number of surviving holes. The probe does not freeze actors, disable combat, reset progression, reposition food or manufacture collection receipts.

Each map runs 60 warmup frames followed by 600 measured frames at a fixed simulation step of 1/60 second. Raw wall intervals remain in chronological order. Percentiles use a separate sorted copy. Reports include actual collection signals, per-frame score/radius/surviving-rival timelines, combat events, active-body snapshots after each ordinary food scan, and measured update counts for physics, rival scans, camera and reveal. Dynamic/falling peaks are explicitly sampled at the admission cadence, approximately every 0.09 seconds. Lightweight probe bookkeeping is included in measured cost.

The Python runner executes one map at a time, enforces a 120-second process timeout per map, applies the existing strict engine diagnostic filter, verifies 600 effective updates and real measured falling/player collection, independently recomputes percentiles, and verifies the complete source/engine/helper hash manifest remained unchanged. It publishes a summary only if both map samples satisfy those checks.

Run only after the parent grants the CPU slot:

```sh
python3 artifacts/growth-rivals-20260928/large-growth-probe/run_probe.py \
  --godot .build/godot-standard/Godot.app/Contents/MacOS/Godot \
  --output artifacts/growth-rivals-20260928/large-growth-cpu
```

This is a bounded headless CPU stress trace. It excludes GPU rendering, is not a browser measurement, and cannot establish iPhone frame rate. Live combat may reduce the later load; the surviving-rival timeline and real collection counts must accompany interpretation.
