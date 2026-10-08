# Final large-growth CPU sample

The two final traces bind the corrected goal fixture and final release registry.
Each records 600 measured intervals after 60 warmup frames, with the ordinary
movement, rival combat, food admission, physical falls, rain, collection, ground,
camera and reveal loops active. Only the automatic food-goal finish condition
is suppressed so the controlled high-score sample can continue.

| Map | P50 | P95 | P99 | Maximum | Intervals over 16.667 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| City | 5.913 ms | 7.590 ms | 8.741 ms | 9.139 ms | 0 / 600 |
| Food | 8.951 ms | 13.069 ms | 14.170 ms | 16.218 ms | 0 / 600 |

The player starts through an actual award at level 19, radius 23.9167. City
records 350 measured collections, including 50 for the player, with sampled
dynamic/falling peaks of 96/93 and seven surviving rivals. Food records 706
collections, including 133 for the player, with sampled peaks of 205/182. One
AI is swallowed and normal collection advances the player to level 20,
radius 24.88. Body peaks are sampled at food-admission cadence, not continuously.
Each trace records 600 physics, rival, camera, reveal and ground updates and
100 admission scans. Both strict engine logs contain no unexpected errors.

These are headless Mac wall intervals including probe overhead, not GPU or
phone FPS. The earlier sample in `../before-goal-fixture/` used identical
runtime, assets, engine and probe code but had substantial outliers: Food P95
18.134 ms, maximum 95.528 ms and 33 intervals over budget. The City sample had
five intervals over budget. `comparative-context.json` confirms that only the
goal-accounting fixture and its registry minimum changed between runs. The
new timing therefore cannot be described as an optimization improvement or a
sustained-60-FPS certification. Both results remain available.

`city.json` and `food.json` retain chronological intervals, workload timelines,
actual collection receipts, combat events, sampled dynamic bodies and complete
input hashes. `summary.json` records validated aggregate values. Functional
helpers were stopped before sampling and both owned engine processes exited.
