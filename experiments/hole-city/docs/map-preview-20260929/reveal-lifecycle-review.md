# Independent return-home reveal lifecycle review

2026-09-29: **PASS, 105 checks** (30 independent natural-lifecycle checks plus the unchanged 75-check selective-reveal acceptance suite). Both processes exited zero with no unexpected engine diagnostics. The reviewer changed no runtime or registered test file.

## Defect and control-flow review

The retained author failure at `artifacts/map-preview-20260929/author/map-preview-before-return-guard.log` shows that 79 logical map-preview assertions passed while repeated `SCRIPT ERROR` diagnostics correctly failed strict acceptance. Returning home queues the old gameplay world for deletion; after deletion, the `player` field still contains a freed Object reference. Godot checks a typed `Node3D` argument before entering `reveal.tick()`, so the disabled-tick branch inside that function could not guard the stale argument.

`fidelity/game.gd:286` now returns through `reveal.reset()` when the existing activity predicate is false, before invoking the typed method. This matches the old intended inactive behavior at `fidelity/hole_reveal.gd:44`. When the predicate is true, the call remains `tick(camera, player, delta, true)`, preserving the active computation. The early pause return is unchanged.

## Independent runtime evidence

The artifact-only `lifecycle_probe.gd` keeps `Game._process` naturally enabled throughout. Both real maps enter their actual intro and playing phases; the reveal update counter and strength advance. Pause preserves the aperture and update count, and resume advances them again.

Sunny City then returns from results, and Snack Garden returns directly from pause. In both cases the old player is confirmed freed, the old world is gone, and natural unpaused home updates continue for another 30 frames. The UI clock advances by 0.5 seconds, the miniature processes normally, and reveal strength stays zero. No stale-argument error is hidden by disabling game updates.

The unmodified selective-reveal suite also passes all 75 checks, including actual blocker-material weights, 30/60/120 Hz smoothing, original appearance and physics invariants, release opacity, active/inactive lifecycle, and paused aperture preservation. This is source/runtime acceptance, not a rendered image or device-performance measurement.

Evidence: `artifacts/map-preview-20260929/reveal-return-review/{lifecycle,selective}.{json,log}`, `lifecycle_probe.gd`, and `provenance.json`. All owned helper processes exited.

| Frozen file | SHA-256 |
|---|---|
| `fidelity/game.gd` | `a62c354d94b4dd0d27a5b590c4a7d2fd649d22e6814df2603cfab6245446c9ef` |
| `fidelity/hole_reveal.gd` | `add22f020b110425f6bb5002f4b58c324ba9a387c448b354f560ffa7f22ddd6a` |
| `tests/selective_reveal_acceptance.gd` | `5450b115c7b9add252b9c0764af9be4718545307e75998e0daa0c33faa4645c6` |
| Artifact-only `lifecycle_probe.gd` | `9d72e7794349ba383c7bcb65368fc93a95fae6a6fa4332a9d121eb9bf59b04e2` |

Every listed hash was identical before and after the runs.
