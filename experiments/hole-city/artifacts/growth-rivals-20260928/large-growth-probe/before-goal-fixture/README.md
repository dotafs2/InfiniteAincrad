# Final large-growth CPU sample

Both bounded traces completed and passed workload validation. Source, engine and helper hashes remained unchanged throughout execution. Both engine processes exited normally, and strict engine diagnostics found no unexpected errors or native contact warnings. No runtime, existing test, or release-tool file was changed by this probe.

| Map | Frames | P50 | P95 | P99 | Maximum | Intervals above 16.667 ms |
|---|---:|---:|---:|---:|---:|---:|
| City | 600 | 6.184 ms | 8.718 ms | 16.201 ms | 39.939 ms | 5 |
| Food | 600 | 9.845 ms | 18.134 ms | 44.497 ms | 95.528 ms | 33 |

This was an active scene. During measured frames the city produced 350 real collection receipts, including 50 for the player, with sampled peaks of 96 dynamic and 93 downward-moving bodies. All seven rivals survived and no rival was swallowed. The food map produced 706 real collection receipts, including 133 for the player, with sampled peaks of 205 dynamic and 182 downward-moving bodies. One rival was swallowed, six survived, and ordinary collection increased the player from level 19/radius 23.9167 to level 20/radius 24.88.

Each map executed 600 measured physics updates, rival scans, camera updates, reveal updates and ground rebuilds, plus 100 ordinary food-admission scans. The measured simulation span was ten seconds after a one-second warmup. Dynamic-body peaks are observed at the food-admission cadence, not continuous maxima.

The food trace has material CPU outliers and its P95 exceeds a 16.667 ms frame budget. This result does not support a claim of consistently smooth 60 FPS in large food scenes. The trace alone does not isolate the cause of each spike, and no unmeasured optimization was attempted. There is one run per map, headless execution excludes GPU work, and lightweight instrumentation contributes to measured cost. It is not an iPhone or browser performance result.

`city.json` and `food.json` retain every interval in chronological order, a per-frame workload timeline, actual collection receipts, sampled dynamic state, combat events, controller counters and the complete hash manifest. `summary.json` contains the validated compact results. Engine output is retained beside each trace. These measurements should not be treated as a direct performance delta against older grown probes that disabled the game's physics loop and rival scans.
