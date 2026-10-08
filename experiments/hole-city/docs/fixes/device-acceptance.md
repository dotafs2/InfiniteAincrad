# Device acceptance and evidence capture

The target is an iPhone 14 at 60 Hz. Native headless source/PCK tests do not
establish this result. Final browser appearance, GPU work, touch latency and
thermal stability remain unverified until actual device evidence exists.

The Web Review package includes an opt-in local recorder at `?qa=1`. Ordinary
visits do not install the recorder. QA startup passes `--test --device-qa` so
it neither loads nor writes the player's progress. The recorder downloads JSON
on request; it uploads nothing. Its report includes PCK/WASM/recorder hashes,
the browser user agent, user-supplied model, display dimensions, gameplay
state, score/radius, city objectives, frame cadence and visibility/context-loss
events. Model identity is not inferred from an iPhone user agent.

## Procedure

1. Open the served build on the physical target device with `?qa=1`. The local
   loopback URL is only usable on the hosting Mac; use an appropriate reachable
   secure development URL for the phone and WebAssembly isolation headers.
2. Enter the actual device model, begin recording, and play at least ten
   active minutes on each map. Use repeated rounds to include small-hole
   openings, large collapses, crowded streets and sustained food rain.
3. Include joystick-plus-skill input, pause/resume, screen rotation/safe-area
   inspection, collection paging and unlock/re-entry. Record a device video
   for visual artifacts and perceived input latency.
4. Stop and save JSON. Associate the video, settings, charging/battery state,
   ambient conditions and observed heating with those exact build hashes.
5. Review frame cadence against a 16.67 ms budget, P95/P99, intervals above
   25/50 ms, context loss, and change from early to late gameplay. Inspect
   video for missing faces, clipping, sidewalk/car placement and individual
   falls. A report never assigns an automatic phone PASS.

The recorder uses `requestAnimationFrame` intervals during visible, active
gameplay. It captures browser presentation stalls, not a direct GPU timer.
Paused, hidden, menu and result intervals are excluded; interruption metadata
remains explicit. Live UI sorts only the latest 120 samples. Frames are
bounded at 72,000, telemetry/visibility records at 3,000 each; omitted event
counts are retained. Synthetic clock/DOM and release-injection tests validate
these rules but are not substitutes for running the exported browser game.
