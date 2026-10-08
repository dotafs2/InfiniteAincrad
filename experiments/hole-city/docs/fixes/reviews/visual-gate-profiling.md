# Independent review: visual-quality release inputs and CPU provenance

Reviewer: food/filtering agent, separate from the root implementation author.
Date: 2026-09-28. Runtime, release files and the live preview were not edited.

## Release-input and registration review

**PASS.** The actual `input_hashes()` now
includes authored `.import` recipes and shader includes while excluding UID
metadata and `.DS_Store`. All 37 registered source/PCK suites have unique
identities, existing scripts and matching completion markers. The four added
suites cover thumbnail configuration, the runtime mip resource, reveal behavior
and its independent review. The same suite table still drives both source and
isolated candidate-package phases; error handling and rollback are unchanged.

Eleven lightweight checks passed. A separate temporary source fixture was
populated with the required input paths, then its actual atlas import recipe
was modified, removed and supplemented with a new `.import` file. The real
guard rejected every changed input set. Both new shader and recipe types are
present among 694 guarded inputs. No real source file was modified for this
probe. Exact checkpoint hashes and results are in
`artifacts/visual-quality-20260928/filtering/gate-profile-review-initial.json`.
The earlier 36-check release refusal/rollback harness was also rerun unchanged
against the current gate: every check passes. Its historical evidence was
preserved; the new run is recorded in `filtering/release-gate-regression.json`
and the adjacent log. Reviewed gate SHA-256:
`0c72beb93ca16080f208532638dbf4a77ed07340bd7aa5da8d8f7029957886b9`.

## CPU profiling review

**PASS after author corrections, 91 independent fault-injection checks.**
Including `.gdshaderinc` in the profile helper's fingerprint was correct, but
the initial helper still accepted native/shader errors, reused existing
reports and took only post-run hashes. A mocked subprocess producing an
explicit `SHADER ERROR` plus plausible JSON was accepted. This was a helper
failure-detection finding, not evidence that any recorded real run contained
that error. All identified paths are now rejected.

The initial reveal diagnostics recorded final cumulative updates and final
strength. They did not show that the entire 600-frame measurement interval
included reveal updates. Production reveal updates run from `_process`, so
disabling only game physics in the grown/soak fixture does not by itself stop
the reveal path. The corrected fixture captures the counter after warmup
frame 59 and reports the difference after frame 659: exactly the same 600
intervals used for timings. Root added strict error classification, report
freshness/metadata/sample checks and before/after input and engine fingerprints.
An intermediate validator also accepted NaN/Inf reveal values; a second author
correction requires an integer update count of exactly 600 and finite strength
in [0.99, 1]. Boolean frame intervals are rejected.

The independent refusal matrix passes native/script/shader/fatal/ANSI errors,
nonzero exits, timeout, missing marker, missing/stale/malformed report, mismatched
metadata, short/negative/nonfinite/boolean samples, incomplete reveal updates,
invalid strength, nonzero scan diagnostics, false percentiles and budget counts.
Source and engine changes prevent summary publication. Every run removes an
old report before launch; a failed run leaves no stale successful summary.
Clean fixtures and the exact allowed macOS CA diagnostic are accepted. These
were mocked subprocesses in temporary output folders: no engine, timing run,
guarded game source or live preview was involved.

Source inspection confirms reveal updates publish four global uniforms without
per-frame scene traversal. The reported zero scan field is a declared diagnostic,
not an independently instrumented profiler counter. The new fields verify the
CPU update path; they do not measure shader work.

Reproducible harness and evidence:
`artifacts/visual-quality-20260928/filtering/profile-helper-review.py`,
`profile-helper-review.json` and `profile-helper-review.log`.
Reviewed helper SHA-256:
`088f5efcf9b6d1f7afd8b624676d201b1c634ef3c6cb76a85e59b019122a947d`.
Reviewed trace fixture SHA-256:
`ba179497a8ac406d1a392595cd940b17da9c6fbd2b6f816b672173d24b1e0cc1`.

## Final stored-evidence and HTTP verifier

**PASS after corrections, 76 targeted checks.** The initial verifier accepted
empty shader/artifact receipts and a zero-repeat profile whose summary claimed
999,999 CPU samples. The reviewer reproduced that using temporary synthetic
receipts, mocked fingerprint functions and no HTTP calls. That initial result
is retained as `filtering/visual-verifier-initial.json`; it describes validation
weaknesses, not actual release evidence.

The corrected tool requires all 37 source and packaged suite receipts, exact
aggregate check totals, five core web artifacts, seven compiled shader programs,
their expected case identities and counts, all eight shader/probe source hashes,
and successful aperture/adapter numerical results. It requires positive repeat
counts and all four CPU scenarios, validates each raw trace and independently
recomputes its summary aggregates. HTTP bytes must match the release manifest;
COOP/COEP headers must enable isolation. A failed run removes an old successful
verification receipt.

The independent test matrix accepted a complete fixture and rejected missing,
failed or short scene suites; missing shader inputs/programs/cases; false
compile/coverage/midtone data; missing core artifacts; zero repeats; stale or
invalid CPU traces; inflated sample totals and false percentile summaries;
wrong delivered bytes, missing isolation headers and network errors. HTTP was
mocked throughout this review. Actual post-release HTTP verification is a
separate root-owned operation.

The shader probe's old `zip` loop could also silently ignore a missing case.
Its corrected identity checks passed four independent mocked-receipt cases:
complete evidence is accepted, truncated reveal or albedo arrays and a wrong
case identity are rejected. No GL or Godot process was started for these tests.

Reproducible verifier harness: `filtering/visual-verifier-review.py`; results:
`filtering/visual-verifier-review.json`, its log, and
`filtering/shader-receipt-review.json` under the same artifact directory.
Reviewed verifier SHA-256:
`4cf8e446a7762a25759f8fe4c52c6dff545cb974d3b0cfca78ac262d1260a89b`.
Reviewed shader-probe helper SHA-256:
`6432cdfcfdf1a0dd7ae71ee77b2246cab22243ca3758fde812d6b8606e03aa7b`.

Even successful checks establish only headless CPU/physics work and global
parameter updates. Shader rasterization, discard/dither cost, framebuffer
allocation, AA, mip sampling and browser/mobile GPU behavior remain excluded.
Zero measured CPU intervals above 16.67 ms must never be presented as proven
60 FPS on an iPhone or as rendered aperture validation.
