# Scene QA evidence

See [the change and reproduction guide](../../docs/scene-qa-20260928.md).

- `baseline-transit.json`: old whole-fixture level-two behavior; nine collected,
  oversized route globe blocked. No independent-part capability existed.
- `first-pass-findings.json`: intermediate diagnostic run, including nine
  genuine overlap stalls and separately corrected test-runner stale references.
- `acceptance.json`, `package-acceptance.json`: current 756-check results;
  152/152 recipe objects individually accounted for by collection callbacks.
- `source.log`, `export.log`, `package.log`: guarded-release engine output.
- `release.json`: source and exported-file SHA-256 hashes for the delivered build.
- `regressions.json`: seven focused suites, 156 checks.
- `rounds.json`: full city and food round regressions.
- `city-opening.json`, `city-grown.json`: CPU traces, not device FPS evidence.

The historical failure report is retained intentionally. It is not the final
acceptance result. The public game has no QA overlay or per-frame audit cost;
these checks run in the dedicated test process.
