# Normal map-duration acceptance

Four ordinary automatically steered rounds passed 28 checks with no failures.
The headless engine and wrapper exited successfully. All 807 guarded inputs
matched the accepted full gate before and after the run. Original phone saves
were not read, written or installed: the test used `--test`, disposable profiles,
no native SDK initialization and Dummy audio.

| Map | Seed | Actual gameplay seconds | Score | Level / radius | Feedback events | Edible targets left | Larger targets left |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: |
| Snack Garden | 1501 | 60.017 | 151 | 5 / 3.5 | 54 | 1,183 | 71 |
| Sunny City | 1502 | 90.017 | 137 | 5 / 3.5 | 71 | 295 | 72 |
| Snack Garden | 1503 | 60.017 | 151 | 5 / 3.5 | 55 | 1,183 | 71 |
| Sunny City | 1504 | 90.017 | 137 | 5 / 3.5 | 71 | 295 | 72 |

Every round produced real collection/growth and swallow-feedback events, ended
once through its normal timer and retained both edible and larger growth targets.
No player deaths occurred. At the finish, edible targets within 25 metres were
81 on Snack Garden and 3 on Sunny City. These are repeated normal runs on the two
fixed authored maps, not a broad random-layout study or evidence of human
retention. The one-physics-tick overshoot is approximately 0.017 seconds.

The original report verifies the single reward basis but does not emit numeric
wallet balances. Each score implies an expected 6-coin payout under the frozen
accepted rule: one score coin plus the single five-coin finish bonus. That value
is explicitly a source-formula calculation; actual wallet-delta acceptance is in
the dedicated economy tests. It must not be represented as another native wallet
measurement.

Evidence remains in:

- `artifacts/diamond-economy-20261002/normal-soak-01/receipt.json`: successful
  process result, exact gate/source/runner hashes, 28 checks and no failures.
- `artifacts/diamond-economy-20261002/normal-soak-01/rounds.json`: original normal
  round metrics and ten-second progression snapshots.
- `artifacts/diamond-economy-20261002/normal-soak-01/expected-payout.json`: labelled
  calculated payout, separately bound to the original report and source hash.
- `build/diamond-economy-20261002/normal-soak-01/engine.log` and
  `owned-process.json`: preserved engine output and ended owned-process record.

The owned engine PID 10067 is no longer present; its process record reports exit 0,
and unified execution session 34777 completed with exit 0. The shared heavy-work
slot has been released to the root's native device candidate preparation. No
source changes, second engine, phone update, advertisement request or new
submission was performed by this acceptance run.

This check covers base 60/90-second map durations. Additional continuation,
callback ordering, persistence rollback and legacy wallet compatibility are
covered by the dedicated economy and independent boundary suites. Native haptic
sensation, speaker output, advertising delivery, sandbox purchases and device GPU
performance require their own acceptance evidence.
