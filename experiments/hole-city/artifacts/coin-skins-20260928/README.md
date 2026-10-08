# Coin collection release evidence

- `before-ui.gd.txt`: the prior v0.6.0 interface, retained for comparison.
- `layouts/`: code-derived 2D UI reconstructions. 3D models are explicitly
  omitted. Tests supply isolated fixture state, not the user's progress.
- `release/`: source and PCK test reports, logs and delivered asset hashes.
- `verification.json`: final source/deployed-artifact hash verification.

Expected ConfigFile parse diagnostics in the coin test exercise malformed-save
preservation. They accompany explicit passing assertions; they are not script
parse failures. Browser and physical iPhone visual/performance checks are open.
