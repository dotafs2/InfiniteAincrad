# Independent review: packaged review-harness portability

Status: PASS after repairing four review harnesses. Reviewer: expand_skin_catalog; repair author: fix_city_motion.

The reviewer found the same defect in the progression, food-rain, food-revision and skin-catalog harnesses: they printed a passing result, then attempted an unconditional write under res://artifacts. A source checkout happened to provide that directory. An isolated exported PCK did not, so FileAccess.open returned null and the scripts raised an error after their assertions. Direct reads of exported GDScript source text also needed an explicit unavailable state because packaged scripts can be compiled.

The author changed only these four test harnesses. Default execution writes results to stdout. An explicit --report or --output argument must provide an absolute filesystem path; resource URIs and relative paths are rejected. Opening, flushing and closing the report are checked, and any failure prevents successful termination. Scene cleanup and the progression fixture's temporary-save cleanup occur before report writing. Unavailable original script hashes are represented as null with an explanatory note, rather than an empty or invented digest. Runtime code and the shared release gate were not changed by this repair.

The reviewer retained the four pre-repair files and full unified diffs. Every original check statement is unchanged. Inspection of the complete diff confirms no gameplay fixture, route duration, assertion threshold or acceptance minimum was weakened; changes are limited to optional report output, source-hash metadata and cleanup ordering.

All six remaining review suites were executed against the existing build/package-isolation-review/index.pck with that isolated directory as the working directory. The exact release-style arguments used an absolute external review script, --main-pack, --fixed-fps 60, --quit-after 140000 and --test. The current release acceptance helper and strict unexpected-engine-error detector assessed every run.

| Suite | Checks | Result |
| --- | ---: | --- |
| Progression review | 10 | Pass |
| Food-rain review | 9 | Pass |
| Food-revision review | 11 | Pass |
| Skin-catalog review | 212 | Pass |
| Food crowd review | 17 | Pass |
| City district review | 4 | Pass |

All 263 checks pass with zero unexpected engine errors. The PCK hash and the isolated directory's file inventory remain unchanged. The tests load gameplay and assets from the package; there is no fidelity source directory in the working directory. The corrected review scripts remain explicit external test inputs, as in the release gate.

An additional packaged skin-catalog run writes an explicitly requested absolute report; its JSON exactly matches stdout. Three negative output cases—an absent parent directory, a relative path and a res:// URI—are all rejected by the strict runner with a clear report-path error and without an uncaught script exception. No unintended report appears in the package working directory. The optional-output helper is identical in all four repaired harnesses.

Actual PCK results report null for unavailable .gd source hashes and retain the real hash for the included accretion shader. Package identity is recorded separately in portability-summary.json. Every run used --test; the only progress fixture uses a PID-specific /tmp path and removes its files. No real player-progress path was requested, read or written by these fixtures. This is execution/configuration evidence, not a historical user-save checksum comparison.

Evidence: artifacts/fixes-20260928/reviews/isolated-pck/portability-summary.json, individual stdout logs and result JSON, output-portability.json, the four pre-repair snapshots and unified diffs. The final full source-and-package gate is a separate release step.
