# Delivery evidence verifier review

Reviewer: city-motion subagent, independent of the verifier author. Reviewed on 2026-09-28.

Scope: read-only inspection of `artifacts/audit-fixes-20260928/verify_delivery.py`, `tools/release_web.py`, `tools/profile_maps.py`, and `tests/mobile_profile.gd`. The verifier was not executed against the changing source tree. This review does not approve the intermediate PCK as the final release and includes no browser, GPU, or physical-phone execution.

## Initial findings, subsequently corrected

1. **Bind acceptance reports to completed logs.** The verifier currently checks each report's failures and minimum count, but only searches its log for engine errors. An empty or truncated log with a stale passing report would pass. Use the release gate's exact completion prefix, parse the last matching JSON object, and require equality with the saved report. The source and package totals should continue to equal the sum of all required suites. Also bind the device-recorder self-test completion count to the release manifest if reporting it as verified.

2. **Check the served directory inventory.** Each manifest-listed file is checked against both disk and HTTP bytes, but extra stale files in `build/web` are not detected. Compare the complete relative file set with the manifest before claiming all served artifacts are covered. Reject redirects if the claim is specifically delivery from the requested local URL.

3. **Validate CPU evidence and freeze its full inputs.** The current verifier trusts aggregate sample counts and accepts any set of CPU source hashes, including an empty or incomplete set. Require the expected city/food opening/grown scenarios, the declared positive repeat count, and all raw reports and completion logs. Check map, scenario, version, headless mode, 60 Hz physics, expected sample count, no unexpected engine errors, and recompute the aggregate statistics/counts. The food rain soak needs the same report/log binding and at least 240 simulated seconds. Preserve hashes of those evidence files in the final result.

   `profile_maps.py` currently hashes only `fidelity` scripts/shaders, `tests/mobile_profile.gd`, and `project.godot`, after profiling. It does not establish an unchanged before/after snapshot or cover inherited `scripts` and loaded assets. A shared full input snapshot covering the profile runner/test and runtime/assets should surround both the repeated profiles and soak; verification should require exact key/value equality with that snapshot. Run timing measurements only after the runtime is frozen.

## Correct checks and limits

- `Path(__file__).resolve().parents[2]` correctly resolves the game project root for this verifier location.
- Exact equality with `release.source_sha256` checks both the release input inventory and bytes, rather than only a subset.
- Required acceptance-suite minima and source/package aggregate counts are checked.
- For every manifest-listed file, disk and HTTP SHA-256 hashes, response status, COOP/COEP/no-store headers are checked. WASM MIME type is checked.
- Metadata is read from the same local HTML whose bytes were compared against HTTP; PCK, WASM, recorder hashes and project version are compared correctly.
- Standard `python3` execution preserves the assertions. This review assumes the author's stated invocation without `-O`.
- The stated static-delivery/native-QA scope correctly excludes browser-rendered appearance, interactions and iPhone GPU performance. CPU wall-time samples cannot establish mobile 60 FPS.

## Follow-up independent review

Status: **PASS for the verification helpers; ready for the isolated final CPU run.** The final real release and CPU evidence have not yet been verified by this reviewer.

The author repaired all three findings. Acceptance JSON now equals its last completion marker; device-recorder counts are bound to their completion log. The published directory file inventory is exact, and HTTP redirects are rejected. CPU evidence now requires all 13 report/log/engine-log sets, three repeats of each of the four scenarios, 600 intervals in each report, correct map/scenario/version/headless/60 Hz fields, and 240 seconds of food rain accumulation. Raw percentiles, threshold counts and summary statistics are recomputed. Raw evidence hashes are bound to the provenance document.

`profile_final.py` snapshots all release inputs plus the profile test and three Python helpers before running the profiles and soak, checks the same complete snapshot afterward, and also verifies the engine executable hash. The final verifier requires that snapshot to equal the current full input set. Legacy profile-summary hash count and complete provenance input count have distinct output fields.

The `tests/mobile_profile.gd` addition only places the already-collected 600 intervals into the result after timing has completed. Its array is sorted before serialization, so it supports distribution/percentile auditing but is not a chronological frame trace. It does not add work to the measured frame loop. The profiler is still a Mac headless CPU measurement, not an iPhone or browser frame-rate measurement.

Reviewed file hashes:

| File | SHA-256 |
| --- | --- |
| `artifacts/audit-fixes-20260928/verify_delivery.py` | `7e96ec267e461df858c33ea85fa1b288781e89ec039b688bdabf6038971349c2` |
| `artifacts/audit-fixes-20260928/profile_final.py` | `4626979d84ff366f379e89420598294506896c07c93025cdaf67c4ede091828f` |
| `tests/mobile_profile.gd` | `b722ed2e2b43c09548010f66b58b1af23d2bf06abe0b52c0c1b9c3dadac5de9d` |
| `tools/profile_maps.py` | `e3a0c8f18cd96aa79ab9a7d09e491c03847c22ef9fc50413a0bd204dc9d1354a` |

Independent fault-injection fixture: `artifacts/audit-fixes-20260928/delivery-review/mock_verifier.py`; results: `mock_verifier.json` in the same directory. **20 cases passed:** one valid synthetic 7,800-frame evidence set was accepted and 19 corrupt/incomplete cases were rejected, covering missing/mismatched completion logs, stale served files, recorder count, headers, served bytes, changed helper or engine, corrupted raw data, wrong scenario/version/percentile/sample count/aggregate, insufficient soak/retained rain, unexpected engine error, missing manifest member, and HTTP redirect. The fixture used a temporary project and an in-memory HTTP response. It started no Godot process, made no network request and did not run the verifier on the mutable real release.

Remaining limits are explicit and acceptable for this helper: before/after hashing assumes the author-controlled frozen tree rather than detecting transient changes reverted during a run; subprocess success is established by the producer's checked execution, not reconstructed from raw logs. Real browser appearance/interaction and physical iPhone measurements remain outstanding, and the temporary fixtures do not establish their results. No helper or runtime changes are requested by this follow-up review.
