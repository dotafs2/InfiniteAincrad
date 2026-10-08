# Street-prop and full-city QA

Read [the changes and reproduction guide](../../docs/street-prop-recovery-20260928.md).

- `release.json`: authoritative delivered-source and Web-file hashes, source
  and packaged check counts.
- `source-*.json`, `package-*.json`: the four final acceptance suites.
- Matching `.log` / `.engine.log` files: actual headless runtime output.
- `regressions.json`: broader collision, controls, map and full-round checks.
- `baseline.json`: original lamp/sign/light directional probe, nine failures
  out of 48 cases before the changes.
- `full-city-first.json`, `full-city-fence-findings.json`: retained scene
  failures that led to placement and fence-spacing fixes.
- Other probe JSON files: intermediate experiments, not final acceptance.

The original and intermediate failures are retained intentionally. Final
success is established by the prefixed reports and their release manifest,
not by selecting a successful diagnostic run. Performance traces, when present,
measure headless CPU simulation only.
