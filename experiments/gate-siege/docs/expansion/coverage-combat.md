# Coverage combat — user-authorized approximation

The user explicitly permits fake bullets, area-based damage and statistical approximation to improve low-end performance. The implementation chooses deterministic weights instead of Monte Carlo, avoiding random misses and retaining reproducible damage across graphics presets. Version0.3.1 replaces individual projectile collision with delayed coverage fields.

Each member keeps its firing clock, muzzle and current class contribution. Emissions accumulate tier-scaled energy in32 lateral cells across the runway. Every0.1seconds, at most one field per weapon is admitted. Its front starts at the rear-most contributing muzzle and advances at the weapon's authored speed. Fields expire after3seconds; at most150 can be resident even if all five modes are fired continuously. Normal play selects one mode at a time.

Only crossed depth layers are inspected: gates, troop rows, elites, the main boss and the active upgrade statue. Partial overlap transfers proportional energy. An armored gate consumes covered energy until open; an open gate multiplies its covered fraction once and fans that energy out. A target removes only the incoming energy it actually absorbs, including the pre-mitigation cost of armor. Remaining energy can reach later covered targets. Fractions are retained.

Rapid concentrates its budget. Scatter covers a wider band. Rail preserves its energy for up to six ordered contacts per cell. Rocket and Arc each discharge one grouped secondary effect per field; radius splash and a maximum of five distinct chained recipients remain separate mechanics. This grouped effect is an intentional approximation, not one explosion or chain per decorative streak.

Cosmetic GPU trails never define hits or consume combat randomness. Graphics budgets can vary displayed density while leaving energy, squad membership, enemy HP, recruitment and wave progression unchanged. The analytic shader animates bounded instance slots from birth time/direction; the CPU writes only newly emitted slots and a shared simulation clock. Pause freezes that clock. Class upgrade remains tied to landing, and recruits remain actual persistent roster entries.

The prior physical-projectile tests and movies remain historical. Acceptance must be rerun on the current solver, including quality-equivalent gameplay fingerprints, fractional conservation, ordering, bounded lifetimes, broad-input win/loss runs and measured CPU/GPU costs. Phone30FPS and thermal stability still require physical-device testing.

## Measured desktop CPU comparison

An independent helper ran the same36-member,544-high-HP-troop, four-elite and dragon scene,20 simulated seconds per mode repeated three times. It times complete60Hz physics updates, including the coverage ticks and cosmetic emission. This is a combined coverage/analytic-trail/aim-query/formation-update change, not a pure collision microbenchmark.

| Mode | Physical-packet baseline mean | Coverage mean | Reduction | Largest coverage tick |
| --- | ---: | ---: | ---: | ---: |
| Rapid |1.516ms|0.656ms|56.7%|3.123ms|
| Scatter |1.579ms|0.421ms|73.3%|2.318ms|
| Rail |0.657ms|0.353ms|46.2%|2.030ms|
| Rocket |0.659ms|0.377ms|42.8%|1.640ms|
| Arc |1.560ms|0.474ms|69.6%|2.935ms|

The baseline is immutable d543c6ec…; current source contains no live individual projectile objects. Raw evidence is `artifacts/expansion-runtime/physical-cpu-baseline.json` and `coverage-spray-cpu.json`. These accelerated headless Apple M1 Pro CPU measurements are not rendered FPS or physical-phone results. New damage/pacing differs intentionally from the superseded collision contract; the comparison does not assert identical historical damage.
