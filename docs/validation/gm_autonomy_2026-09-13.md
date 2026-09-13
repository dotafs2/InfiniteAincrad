# Autonomous GM development cycle — bounded offline validation (2026-09-13)

## Current supervisor acceptance — 2026-09-13 16:16 Asia/Shanghai

**Accepted within the local bounded engineering scope. H47 remains partial for real-model operation.** This section supersedes intermediate worker claims and pending-review notes below. GPT independently checked source corrections, actual native test output, evidence JSON, on-disk hashes, untouched main HEAD and worker exit. There is no production GM/Kimi loop running.

- Actual native test output: 83 autonomy + 17 preparation tests pass. The previous engineering turn passed 51 legacy runner/discovery/two-contribution tests in the isolated writable Git repository; these were not needlessly rerun after preparation-only corrections. Main-checkout worktree permission failures remain recorded.
- Causal repair: 21 checks pass at `tmp/gm-autonomy-20260913/runs/causal_repair-20260913T081316Z-2c87/`. Incorrect candidate bytes fail in actual Godot; the same scripted GM repairs them, and the same save consumes water once. Replaying bad bytes still fails. This establishes code causality in a fixture, not real-model discovery.
- Two deliveries: 26 checks pass at `tmp/gm-autonomy-20260913/runs/watch_two_delivery-20260913T081328Z-ca4e/`. A single watch observes ten scripted identities, completes GM02's release, then consumes queued GM07's distinct release without another supervisor assignment or observation batch. Fourteen scripted native turns and five batches are recorded. The second release probes the depleted state with zero additional draw/save mutation; it is not a second drink or real resident adoption.
- The actual compiler/interface gate, pinned host/policy/base checks, serialized installation writes, receipt binding, truthful failure feedback, preserved candidates and monotonic watch accounting are covered within these bounded interfaces. They do not establish arbitrary code safety or unattended service.
- Corrected local route: `C:/InfiniteAincrad/tmp/gm-autonomy-20260913/local-trial/local-trial-h47r2-20260913/`. Preflight plans ten GM identities, dispatches zero turns, resolves `deepseek-flash` with the existing private key path, keeps the unelevated sandbox and reports no missing requirements. No fake transport/key artifact exists in this prepared directory. The carried reference ledger preserves measured history and the interrupted unknown tail; its reference hashes are preparation-time snapshots, not a reset of mutable accounting records.
- Reuse preserves save, policy and marker bytes. The actual save SHA-256 is `85480e697d83f94ab4a739614a598446e7f3a1e155b547196048f5056ee4460c`. Old `local-trial-h47-20260913` is retained and refused as a fake-ledger route. Label containment, rechecked preflight failures and missing-input refusal passed focused tests.

Concrete reviewable entry: `python tools/prepare_gm_autonomy_local.py --label local-trial-h47r2-20260913` reuses the save and performs a no-dispatch preflight. Exact absolute argv arrays for status/preflight/cycle/watch are saved in `tmp/gm-autonomy-20260913/local-trial-h47r2-prepare-20260913.json`; independent preparation evidence is `tmp/gm-autonomy-20260913/local-trial-h47r2-verification-20260913.json`. The prepared watch is bounded by 32 native GM turns, 4 iterations and 900 seconds; this is a prepared command, not an active or authorized unbounded service. Status currently contains no real cycles.

The existing hourly GPT heartbeat is ACTIVE and read-only, quiet when unchanged. Its authoritative state is `tmp/gm-autonomy-20260913/acceptance-progress.md`. It does not start paid engineering/world loops. Follow-up real-model evidence remains the next H47 acceptance; complete town behavior and M20 are not inferred from this one-resident kernel fixture.

Engineering measurement is in `tmp/gm-autonomy-20260913/accounting-summary.json`: known batch subtotal 159,103,885 raw through the 08:15 UTC root snapshot and the final completed worker, plus the preserved interrupted development tail and later root usage. Cached input is counted once inside input, currency is not inferred, and historical fees/unknowns are neither zeroed nor recounted. The 100M direction review below remains in force; no scope expansion.

## Preserved intermediate records

The sections below retain failed attempts, rejected preparations and intermediate review states as history; they do not override the supervisor acceptance above.

## Final delivered scope of this bounded turn (2026-09-13, DeepSeek worker)

Status: **H47 stays partial pending root review.** This turn closed only the three watch review
edges and delivered ONE prepared, actually preflighted local trial route. It does not claim real
autonomous GM life, a real-model result, or continuous10+10.

Delivered:

- `tools/prepare_gm_autonomy_local.py` — prepares one unique, explicitly labelled local fixture
  under `tmp/gm-autonomy-20260913/local-trial/<label>/`, seeds the world only through the existing
  Godot `--phase=seed --allow-create=yes` fixture seed path, refuses to overwrite an existing save,
  and then runs the existing no-dispatch `gm_runner observe --dry-run` route preflight. It writes
  only non-secret route/policy/config JSON; the credential stays a `--key-file` path reference to
  `private/deepseek-api-key.txt` and is never read, copied or printed by this helper.
- `tools/test_prepare_gm_autonomy_local.py` — 9 focused preparation tests (route non-secrecy,
  absolute/key-file command arguments, save-overwrite refusal, byte-for-byte idempotent reuse,
  half-written refusal, label prefix, `local_trial` mode acceptance, provenance labels, production
  missing-input refusal).
- `tools/gm_autonomy.py` / `tools/gm_runner.py` — `local_trial` mode, explicit
  `world_origin` / `gm_transport` provenance (offline_fixture keeps its scripted-fake label), and
  the three watch corrections below.

Three watch review edges closed with focused tests in `tools/test_gm_autonomy.py`:

1. `watch_cycle_scan` reports missing/unreadable `cycle.json` instead of skipping it;
   `reconcile_watch_counters` merges persisted per-cycle counters monotonically and stops with
   `cycle_counter_unreadable_stop` (exit `ACCOUNTING`) when a previously charged cycle file is
   lost or corrupt. A recorded counter is never decreased and file loss never frees spent turns.
2. A carried `unresolved_usage` fact whose own cycle file is gone cannot be reconciled from disk,
   so it remains an `interrupted_unknown_stop`; `--reset-watch-budget` preserves it. Reset restarts
   the bound but never settles, zeroes or drops the unknown charge. `max_calls` is a documented
   **lifetime ceiling over the whole state directory**, not a fresh allowance: the ledger is a
   cumulative counter map, so a reset with `--max-calls` begins a new window whose bound
   is measured against all prior recorded turns in that state dir (a truthful conservative bound).
3. A cycle whose `payload.status` is `blocked` while its code is 0 is normalized to `RUNTIME`
   before `watch_summary` is built as well as for the process exit, so the JSON can no longer
   report `status=ok` / `last_exit_code=0` while the command fails.

Actual result of the FIRST prepared fixture (`--label local-trial-h47-20260913`) — now **UNACCEPTED** and preserved byte-for-byte; its four concrete defects and the corrected replacement are recorded in the correction section at the end of this file: status `prepared`,
preflight `ok` with `planned_gm_identities=10`, `dispatched_turns=0`, model `deepseek-flash`,
`key_file_reference=private\deepseek-api-key.txt`, `windows.sandbox=unelevated` and
`required_paths_missing=[]`. A second invocation returned `already_prepared` and left the save,
policy and marker byte-for-byte unchanged (verified by SHA-256).

**World provenance is not GM transport.** The fixture world is a fresh labelled local-trial
genesis, not a migrated canonical save and not a fee-history reset. The GM transport is the real
DeepSeek route, which is **prepared and preflighted, not proved live**: no real GM or Kimi call was
made in this turn, and the historical DeepSeek usage plus the interrupted unknown tail are
referenced, never converted, zeroed or settled.

Checks run once: 92 unit tests (`tools.test_gm_autonomy` 83 + `tools.test_prepare_gm_autonomy_local`
9), host scenarios `causal_repair` and `watch_two_delivery`, and the isolated-repo compatibility
suites `test_gm_runner` + `test_gm_discovery_delivery` + `test_gm_two_contributions` (51 tests,
`tmp/gm-autonomy-20260913/isolated-repo`). In the main worktree, 6 `test_gm_runner` candidate
tests fail only because `.git/worktrees` is not writable in this sandbox; they pass in the
isolated repo.

## Older sections (history preserved: earlier partial acceptance and failures)

Supervisor direction review at15:18 Asia/Shanghai: the known measured development subtotal has
crossed100,000,000 raw tokens (110,083,005 at the current root/worker snapshots, plus the preserved
unknown interrupted tail; cached input is included once, currency is not inferred). The causal
fixture now supports one concrete gain: same-owner code repair changes actual Godot behavior and
continues the same save with exactly one water use; preserved bad bytes still fail independently.
This is offline scripted-GM evidence only. H47 remains partial: the candidate gate still needs an
actual compiler/interface unit, live pinned-binding checks need correction, and a queued second
delivery plus truthful watch accounting and a prepared local route remain open. Continue only
those requirements on the original H47 path; do not add unrelated game/platform work. Prior
failures and the test-file truncation/recovery incident remain recorded. The worker's latest
claimed20-minute overrun is contradicted by host timestamps (07:05–07:17 UTC, about12 minutes).

The completed tool logs confirm 12 offline scenarios, 43 unit tests and 34 + 15 + 2 existing
regressions passing. Those checks do not establish the full requested continuing loop. Direct
review of `tmp/gm-autonomy-20260913/runs/installed_unused-20260913T033645Z-dbb0/state/autonomy/auto-060be2be278963e8/cycle.json`
found `blocked_reason=installed_but_unused`, a feedback decision of `repair`, and no subsequent
candidate. Its acknowledgement also described the receipt outcome as `released_and_verified`.
The failure facts must be accurate and the owner's decision must actually advance bounded repair.

Other remaining acceptance work: prove a deferred claim's second delivery; propagate nonzero/guard
failures through feedback and `watch`; lock and reconcile the watch ledger across interruption;
complete publication/verification restart boundary checks. A ready real-model local invocation is
still pending. Earlier green language below describes individual offline checks, not supervisor
acceptance of the complete requested workflow.

The sole correction worker (`20260913T031050076637Z`, PID 387176) hit its 1800-second bound before
returning a completed turn. Its native session reports a measured partial total of 27,230,086 raw
tokens through 03:40:48.740 UTC; the interrupted tail remains **unknown**, never zero or settled.
The first implementation turn was fully measured at 27,204,324 raw tokens. These are separate
increments and not currency estimates. The user's replacement AGENTS carried-continuation rule
authorizes scoped development to continue while preserving this unknown tail, without another
approval solely for that bookkeeping gap. Continuation `20260913T063808913835Z` completed with
1,176,357 measured raw tokens and only the existing 43 unit tests rerun; its new repair path still
requires end-to-end evidence. Worker `20260913T064520135268Z` is now checking that path under a
bounded engineering task. Source, failed evidence and all completed check outputs are retained.

Cleanup audit found 152 recorded Windows job groups with zero groups left running; all 2,193
recorded PID/creation identities were checked against live processes and none matched a running
owned process. Both native workers and their launchers have exited. No production model loop was
started. The existing hourly GPT review heartbeat is active, reads the supervisor acceptance state,
and remains quiet when nothing meaningful changes.

Scope of this evidence: the opt-in autonomous cycle added in `tools/gm_autonomy.py` on top of the
existing `tools/gm_runner.py` and the Godot kernel. Everything below is an **offline fixture**:
the GM transport is a scripted local fake, the model provider is never contacted, and no real Kimi
or DeepSeek GM ran. A green result here proves the host-side code paths, gates and runtime wiring,
**not** real autonomous GM life, not a production release and not the 10-resident world.

The user explicitly chose a local trial and said formal operation has not started. Another PC's
maintained ten-resident save is not a prerequisite for this local delivery. Existing saves remain
preserved; scripted local fixtures do not become canonical worlds or real-model evidence.

## Deliverables

- `tools/gm_autonomy.py` — the durable cycle (`cycle`, `status`): observe → candidate → validate →
  publish → verify → feedback, with stage records persisted in `cycle.json`.
- `tools/gm_autonomy_policy.example.json` — the standing preauthorization shape.
- `tools/prepare_gm_autonomy_local.py` — prepare + no-dispatch preflight for one labelled
  local-trial fixture on the real DeepSeek route (added in the final turn).
- `tools/test_gm_autonomy.py` — offline unit / negative-gate tests (92 with the preparation suite).
- `tools/validate_gm_autonomy.py` — one-command end-to-end harness driving 12 labelled scenarios.
- `game/tests/gm_autonomy_acceptance.gd` — the real-Godot runtime verification fixture.
- `tools/gm_runner.py` — minimal opt-in additions (`--autonomy-policy`, autonomous observation
  origin, host-derived investigation, `scope` passthrough, bounded atomic `save_json` retry).
- `ROADMAP.md` H47 and `docs/STATUS.md`.

## How to run

```
# Prepare + no-dispatch route preflight one labelled local fixture (no model call):
python tools/prepare_gm_autonomy_local.py --label local-trial-h47-20260913

# Exact commands the helper prints (absolute paths; the key stays a file reference):
python tools/gm_autonomy.py status --state-dir tmp/gm-autonomy-20260913/local-trial/local-trial-h47-20260913/state
python tools/gm_runner.py observe --evidence <fixture>/evidence.json --state-dir <fixture>/state \
  --autonomy-policy <fixture>/policy.json --prior-ledger <fixture>/prior-ledger.json \
  --max-gms 10 --dry-run --config <fixture>/deepseek.local.json \
  --key-file C:/InfiniteAincrad/private/deepseek-api-key.txt --codex-home <fixture>/codex-home
python tools/gm_autonomy.py cycle --policy <fixture>/policy.json --config <fixture>/deepseek.local.json \
  --key-file C:/InfiniteAincrad/private/deepseek-api-key.txt --codex-home <fixture>/codex-home
python tools/gm_autonomy.py watch --policy <fixture>/policy.json --config <fixture>/deepseek.local.json \
  --key-file C:/InfiniteAincrad/private/deepseek-api-key.txt --codex-home <fixture>/codex-home \
  --max-iterations 2 --max-seconds 900 --max-calls 3 --idle-exits 1 --interval 5

python tools/validate_gm_autonomy.py run                     # all twelve offline scenarios
python tools/validate_gm_autonomy.py run --scenario happy    # one scenario
python tools/test_gm_autonomy.py                             # unit / negative gates
```

The `cycle`/`watch` lines above are the prepared REAL-route entry points. They are documented, not
executed: running them would dispatch real DeepSeek GM turns.

Running `cycle --policy tools/gm_autonomy_policy.example.json` with the example's inputs absent
refuses before dispatch: exit 2, `{"kind": "missing_requirements", "missing": [6 concrete inputs]}`.

Every scenario provisions its own fixture under a unique
`tmp/gm-autonomy-20260913/runs/<scenario>-<utc>-<hex>/` directory (with a `latest.json` pointer) and
removes only the worktrees it created; failed evidence is kept, never overwritten or pruned
globally. No scenario touches the development checkout, a real world save or any private directory.

## Scenario results (one `run` invocation, all ten green)

| scenario | exit | what it proves |
| --- | --- | --- |
| happy | 0 | full cycle: GM-selected work, both code attempts, host gate, publish, real Godot run, receipt |
| interrupt | 0 | pause after the candidate stage, restart resumes with no duplicate model call, completes once |
| out_of_policy | 6 | a GM-proposed excluded path is refused before coding; nothing published |
| no_action | 0 | ten GMs may find no supported work; `no_action` is a useful outcome, nothing dispatched or published |
| unknown_usage | 5 | unknown cost blocks further dispatch; the second run adds no call |
| never_passes | 1 | a failing candidate stops at `max_attempts_per_issue` with a bounded number of code dispatches |
| tamper_host_check | 1 | a coder changing a host-owned checker is refused out-of-scope and the real checker is byte-identical |
| release_conflict | 6 | a trial file that drifted from the declared base is not overwritten; the other writer's bytes survive |
| wrong_world | 3 | a runtime save from another world is refused before any dispatch |
| production_missing | 2 | production mode lists concrete missing inputs and dispatches no model |

Harness end line: `{"kind": "gm_autonomy_harness", "ok": true, "scenarios": [...10...]}`.
Per-scenario detail is written to `tmp/gm-autonomy-20260913/validate-<scenario>.json`.
## Happy path, in the world's own terms

From `tmp/gm-autonomy-20260913/happy/state/autonomy/auto-a2d364a4058f0aba/cycle.json`:

- **No preselection.** The supervisor supplied no issue and no scope. `gm-02` selected the
  evidence entry and proposed the file, objective and acceptance itself; `gm-07` also claimed and
  was deferred to serialize coding (`deferred_claims`). Observation origin is
  `autonomous_observation`, recorded in provenance, not presented as spontaneous discovery.
- **Ordinary failure returns to the same GM.** Attempt 1 wrote the manifest with `amount = 0`, so
  the host gate failed (`scope_tests_failed`, exit 1, usage measured). The cycle dispatched
  `gm_runner acknowledge` to `gm-02` and retried; attempt 2 passed (`ok`, exit 0). Two code calls,
  not more.
- **Host-derived scope.** The executed test command is the policy's host gate, not the coder's
  `test_commands` (which the scope object is not allowed to supply). `host_owned_paths` were
  re-hashed inside the candidate and matched.
- **Controlled publication.** One file was written into the disposable trial checkout:
  `capabilities/gm_autonomy_trial_well.v1.json`, sha256 `d2b91b0d2964c518…`, release digest
  `9cd3f3fcdd3f090c7c55af62b9373cf169277c1fdf6781da61f337bb36c9899e`. The development checkout
  gained no source file; the trial checkout is `.git`-inner to its own sparse repo, not the dev one.
- **Real Godot execution, continued save.** Godot 4.7.2 headless ran
  `res://tests/gm_autonomy_acceptance.gd` twice against the real `game/core/world_kernel.gd`
  copied into the trial installation (not the town scene). `phase=open` created the fixture, the
  fixture GM review approved the recorded need, the published manifest installed through the
  kernel's own `gm_install` validation, a resident step actually drew water, and the save was
  written. `phase=resume` cold-loaded the **same** save and asserted identity, plugin status,
  memory, consumption, command receipts, event history and conserved well stock, then took one
  more step. Both exited 0, `installed=true`, `used=true`, `installed_but_unused=false`,
  `continuation_ok=true`, `world_id=fixture:well-street`, `paid_model_calls=0`.
- **Honest receipt.** The originating GM `gm-02` received one
  `autonomy_release_feedback` outcome carrying the release digest, the host-gate result, the world
  id and the runtime observation, explicitly marked "a GM proposal is a hypothesis".

## Interrupt / restart

`--stop-after candidate` pauses after the paid candidate stage (`publish` still `pending`). Running
the same policy and evidence again created no new model call (the transport log still held one
observe batch and two code attempts), no new release and exactly one feedback receipt, then
completed. Cycle identity is `sha256(policy_id | policy_sha | world_id | evidence_sha)`, so this
run directory also rejects resuming under a changed policy.

## Unit and negative gates (`tools/test_gm_autonomy.py`)

43 tests, 0 failures: policy schema/mode/limits rejection, allowed/excluded/host-owned/absolute/
traversal path refusal, `max_changed_files`, coder-supplied test commands dropped, glob and
deployment mapping, placeholder resolution, absent-input preflight (offline vs production),
explicit bounded observation origin, stable cycle identity, refusal to resume under another policy,
no replay of an already-done stage, and an acknowledge dispatch that carries no provider route.
The correction round adds publication safety (every candidate byte verified against the gate hash
before any target mutation, exactly one changed file, untouched target on refusal), durable cycle
identity and an installation lock shared by deployment path across different state dirs, an
expired-deadline `run_process` that starts no process, a reservation that survives until the stage
result is durable, and a feedback acknowledgement that must echo the receipt digest.
## Existing gm_runner / discovery / two-contribution suites (environment-limited)

Those suites isolate candidates with `git worktree add`, which must create `.git/worktrees/<id>`.
This sandbox keeps the repository `.git` read-only, so in the **main checkout** every worktree
creation fails with `fatal: could not create directory of '.git/worktrees/issue-…': Permission
denied`, and two tests additionally read a ten-resident fixture save that is not on this PC.
Recorded as the initial environmental failure of the main checkout, not as a code result.

To obtain a real result without relaxing the sandbox, the same suites were re-run from a small
standalone test repository with its own Git metadata under this task's tmp directory
(`tmp/gm-autonomy-20260913/isolated-repo`; necessary code/fixtures only, no art/LFS/history).
There they are fully green, with the same byte-guard assertions:

- `tools/test_gm_runner.py`: 34 tests, 34 pass.
- `tools/test_gm_discovery_delivery.py`: 15 tests, 15 pass.
- `tools/test_gm_two_contributions.py`: 2 tests, 2 pass.

The cycle does not depend on `git worktree`: the offline policy uses the opt-in
`candidate_isolation: sparse_alternates`, which creates its own `.git` inside the writable candidate
directory and only reads the development object store.

## Accounting, processes and cleanup

- No provider was contacted. Each scenario writes a fake-transport call log (`<scenario>/calls.jsonl`);
  the happy log holds exactly one observe batch and two code attempts.
- Root usage baseline: `tmp/gm-autonomy-20260913/usage-root.json`. Only deltas after this task are new
  work; historical API costs and unknowns are unchanged and are not re-created as zero.
- Every owned subprocess (gm_runner observe/code/acknowledge, the host gate, Godot) runs through the
  existing `tools/owned_windows_job.py` kill-on-close job. The cycle report carries the real member
  PIDs, their creation identity and their exit codes instead of an unconditional "waited" claim. A
  call is capped by the remaining pinned deadline, and an already-expired deadline starts no
  process at all.
- The harness removes only the worktrees it created (no global `git worktree prune`) and keeps all
  scenario state, including failed evidence, under `tmp/gm-autonomy-20260913/runs/`.

## Limitations (kept, not hidden)

- Offline fixture only: scripted fake GM decisions, no real DeepSeek/Kimi inference, no production
  release, no scheduler, no 10+10 run. `M20H`/`M20F` stay open.
- Runtime verification uses the repository's real `game/core/world_kernel.gd` **kernel fixture**
  copied into the trial installation and executed by real Godot headless. It is not the town scene,
  the street, or an imported art project.
- The only publication target exercised is an explicitly supplied disposable trial checkout.
  Publishing into a maintained world and handling post-publication runtime failure are still
  unverified here.
- Ten GMs observe; coding and publication are serialized by design for this first cycle.
- `save_json` gained a bounded retry for a transient Windows `PermissionError` on the atomic
  replace (observed once while running the batch); it does not relax any gate.
- The feedback acknowledgement is only proven against the scripted fake transport; because the fake
  echoes the receipt digest, this does not prove a real model would.
- A deferred claim is consumed through the bounded `watch` coordinator's generation advance; a full
  second coded release originating from a deferred claim is not yet proven end to end.
- The installation lock is machine-local (a temp lock root keyed by the resolved deployment path).
  It is not a cross-machine or cross-user guarantee.

## Correction round (unaccepted first draft -> corrected)

The first draft's scenarios and unit tests passed, but review found material defects. This round
corrects them and re-runs everything with the same offline fixtures:

- Publication snapshots and verifies every candidate byte against the validated gate hash **before
  any target mutation**, binds policy/host-owned/base hashes, refuses path-map traversal,
  symlink/reparse and source escapes, allows exactly one changed file in this version, and records a
  publication intent that recovers atomically and idempotently after a kill between replace and
  receipt. Scenario `publish_race` proves the original target stays byte-identical on refusal.
- A cycle pins its evidence bytes, deadline and counters once and resumes an unfinished cycle before
  newer evidence. An ambiguous provider interruption stops with unknown evidence and is never
  replayed; an unchanged completed/no-action evidence source costs no further model call. A plain
  `cycle` rerun is idempotent, while the bounded `watch` advances one generation to consume deferred
  claims.
- One owner-identified OS lock guards the cycle, and a separate installation lock keyed by the
  resolved deployment path (not the state dir) blocks publishing into another active writer even
  when two policies use different state directories.
- Runtime/runner work goes through `tools/owned_windows_job.py`; the report carries real owned PIDs,
  creation identity and exit codes; a child+grandchild cleanup test asserts both processes exited.
- `stage_feedback` performs a real transport turn that delivers the receipt and requires a
  structured acknowledgement echoing the receipt digest; a queued JSON item is not counted, and an
  interrupted/unknown feedback call stays stopped.
- `gm_autonomy_acceptance.gd` seeds a labelled fixture before publication; later phases LOAD it and
  assert exact prior identity/property/command/history invariants across a cold resume, bind fresh
  output to the nonce/world/issue/release, and never auto-reset an existing save.
- `gm_runner.STABLE_INSTRUCTIONS` states the autonomous observation origin honestly (legacy
  supervisor-specified defaults unchanged); dispatch batches and model-call bounds are reported
  separately, so one observe batch of ten GMs is not counted as one call.

Checks run for this correction: `python -m unittest tools.test_gm_autonomy` -> 43 tests OK;
`python tools/validate_gm_autonomy.py run` -> all 12 scenarios `ok: true`; the three gm_runner /
discovery / two-contribution suites green in the isolated repo (34 + 15 + 2).

## Continuation round (2026-09-13, DeepSeek turn 3, bounded)

Authorized by the user's replacement AGENTS.md carried-continuation rule; the earlier
"paused new dispatches" wording above is superseded for scoped engineering continuation. The
interrupted tail of `20260913T031050076637Z` stays **unknown**, never zero or settled, and no real
model dispatch was resumed.

Changed in `tools/gm_autonomy.py` only:

- `stage_verify` now records the failed stage (`status=failed`, `reason`, `failed_checks`) before
  blocking, so `failure_facts` and the owner receipt describe what actually happened instead of
  reporting `released_and_verified` for a failed runtime verification.
- The receipt outcome is derived from evidence: `released_and_verified` only when the verify stage
  finished ok; `installed_but_unused` / `verification_failed` when a failure fact exists;
  `not_released` otherwise. `published` is recorded explicitly.
- `stage_feedback` accepts an acknowledgement only when transport exit is 0, the transport status is
  `ok`, no protected host path changed, the echoed receipt digest matches, and usage is measured.
  Otherwise the stage is failed/refused and the cycle blocks with a named reason.
- `run()` now routes a measured, accepted same-owner `repair` decision through the new
  `advance_repair()`: one bounded round (default `max_repair_rounds=1`, additionally bound by the
  carried `max_dispatches`/deadline) re-opens candidate/validate/publish/verify/feedback while the
  observe stage and all counters stay intact. Unknown, interrupted in-flight, guard-refused and
  unmeasured-usage failures never advance; the failed stage records are preserved verbatim under
  `repair_history[].previous_stages`.

Checks run: `python -m py_compile tools/gm_autonomy.py` (ok) and
`python tools/test_gm_autonomy.py` (43 tests, 0 failures, 5.07 s) after the patch.

Residual gaps (not done in this bounded turn): no end-to-end scenario yet proves the new repair
advance from the recorded `installed_unused` counterexample; `watch` still returns OK for a blocked
cycle and does not lock/reconcile its ledger; the release receipt is still not saved before its
journal is removed; verify uses fresh hashes instead of pinned host/policy/base comparisons and does
not hold the installation lock; the ready local real-model route config and the deferred-claim
second-delivery proof are still open. H47 stays partial and unaccepted.


## Repair-loop round (2026-09-13, DeepSeek turn 4, bounded)

ONE visible result: a truthfully-failed world verification -> accepted same-owner repair feedback ->
an ACTUAL second candidate, second host gate and second Godot verification on the SAME save, while
unsafe repairs are refused. Offline fixture only: no model, no Kimi, no production GM, no paid
dispatch, no world reset. The scripted transport decision is labelled offline everywhere.

Changed (source):
- `tools/gm_autonomy.py`
  - `advance_repair` now delegates to the explicit `repairable_failure` whitelist. Only a
    verify-stage `runtime_verification_failed` (an actionable defect the running world reported) or
    a validate-stage `host_gate_refused_candidate` whose ONLY failed check is
    `host_test_commands_pass` (an ordinary owned candidate test failure) may reopen a round.
    Guard/scope/conflict/byte-drift refusals, exhausted `max_attempts_per_issue`, unknown or
    interrupted in-flight calls, absent/unmeasured usage and installed-but-unused never advance.
  - A reopened cycle is set back to `status=running` (it previously stayed `blocked`), so a restart
    resumes the repair round instead of reporting the old failure as terminal and never replaying.
  - Counters are preserved across rounds and restarts: cumulative `carried_attempts[issue_id]`
    keeps the per-issue attempt bound (a reopened round gets NO fresh budget) and
    `feedback_attempts_total` is cumulative instead of per round.
  - `stage_candidate` re-derives the candidate from the pinned base when a repair round reopens it
    (bounded `shutil.rmtree` confined to the state dir), so a reopened round cannot re-validate and
    republish the stale bytes of the candidate that just failed; it also records `attempts_carried`.
  - `stage_verify` adds `every_phase_reported_ok` and `every_phase_bound_to_this_release`, so an
    `open` phase that truthfully reported a defect fails verification even when the later `resume`
    phase looks fine.
  - `stage_feedback` is stricter: the echoed `receipt_sha256` must be present and exactly equal to
    the host receipt digest (absent is no longer accepted), `gm_id` must be the owning GM, and
    `usage_measured` must be exactly `True`. The receipt outcome is now `<stage>_failed` for a
    non-verify failure instead of always `verification_failed`.
- `game/tests/gm_autonomy_acceptance.gd`: labelled one-shot fault injection
  (`--defect-once=<marker>`). The first verification run of a marked save reports
  `runtime_defect_observed` BEFORE any install or world mutation and consumes the marker; the
  reopened round then installs, draws and cold-loads honestly on the unchanged save.
- `tools/validate_gm_autonomy.py`: new seeded `repair_after_defect` scenario (23 checks) plus two
  new negative checks in `installed_unused` (no repair round, exactly one coding dispatch).

Checks run (actual, 2026-09-13 06:45-06:54 UTC):
- `python tools/test_gm_autonomy.py` -> 54 tests OK (43 pre-existing + 11 new; 5.6 s).
- `python tools/validate_gm_autonomy.py run --scenario repair_after_defect` -> `ok: true`.
- `python tools/validate_gm_autonomy.py run` -> all 13 scenarios `ok: true` (~70 s).
- `python tools/test_gm_runner.py` -> 34 tests, 6 failures, every one
  `candidate_creation_failed: ... .git/worktrees/...: Permission denied`. That is the pre-existing
  unelevated-sandbox limitation of the development repo, unchanged by this round; the isolated
  fixture repo is the supported path.

New end-to-end evidence (run dirs under `tmp/gm-autonomy-20260913/runs/`):
- Round 1: candidate attempt 1 -> host gate -> publish `done` -> verify **failed** with
  `runtime_verification_failed`, `installed=false`, `used=false`, `installed_but_unused=false`, the
  labelled injection failure in the run output, and `every_phase_reported_ok=false`.
- The receipt outcome was `verification_failed`; the SAME owning GM acknowledged it and asked for
  `repair`.
- Round 2: candidate attempt **2** (`attempts_carried=1`, no fresh budget), a real second coding
  dispatch (code batch 2), host gate passed, publish idempotent, and a second Godot open+resume pair
  with new nonces passed every check on the SAME save file; the final receipt is
  `released_and_verified` and the owner's final acknowledgement is a measured `accept`.
- `repair_rounds=1`; the cycle ends `completed` with `blocked_reason=null`; both receipts went to the
  one owning GM; and the save holds exactly one `autonomy-review-1` and one `autonomy-install-1`
  command receipt (no duplicated side effect on the retry).
- The preserved counterexample
  `runs/installed_unused-20260913T033645Z-dbb0/.../cycle.json` is untouched (mtime 03:36:52 UTC,
  42871 bytes) and still shows the old false `released_and_verified` outcome; it is kept as the
  original failure evidence.

Limitations (kept):
- The actionable defect is a LABELLED fault injection, not a GM-authored code fix. This proves the
  host loop (failure -> accepted feedback -> second candidate/gate/verify) and not a real model's
  repair reasoning.
- Installed-but-unused is deliberately NOT repairable: the fixture now proves the host stays stopped
  and does not force adoption even when the owner asks for a repair.
- `max_repair_rounds` still defaults to 1; the two-round counter-carry proof is a unit test.
- Deferred-claim second delivery, watch error/ledger reconciliation, verify's pinned-hash and
  installation-lock work and the real-model route remain open. H47 stays partial and unaccepted.

## 2026-09-13 06:57-07:03 UTC: evidence guards for a causal repair round (H47 stays partial)

Turn `20260913T065739Z` (worker, sequential native turn; no provider, no production run). This
round closed three honesty prerequisites for the causal repair proof. **The headline deliverable -
an offline fixture where the repaired CANDIDATE BEHAVIOR is the reason the same-save runtime
succeeds - was NOT delivered.** The earlier `repair_after_defect` result remains transport/retry
plumbing evidence only: both candidates can release the same correct well manifest, so its second
green says nothing about repaired code.

Closed in this round:

- **Conclusive-evidence gate for semantic repair** (`tools/gm_autonomy.py`). A reopened round was
  justified by the generic blocked reason `runtime_verification_failed`; that reason also covered
  timeouts, missing/stale output, a foreign nonce/world/release/issue and child processes still
  live. `conclusive_runtime_defect()` now requires every integrity check to pass - fresh exactly
  bound output (`fresh_output_for_this_nonce`, `every_phase_bound_to_this_release`,
  `release_digest_matches`, `world_id_matches`, `issue_id_matches`), fully exited owned processes
  (`owned_processes_exited`) and a new explicit `no_phase_timed_out` check - and only the world's
  own report about candidate behavior (`runtime_reports_ok`, `every_phase_reported_ok`,
  `installed`, `used_not_invented`, `same_save_continuation`, `runtime_exit_ok`) may be a failed
  check. `runtime_exit_ok` is deliberately not an integrity check: the fixture truthfully reports
  defects by exiting nonzero. Inconclusive runs stop as the new reason
  `runtime_verification_inconclusive` with **no further candidate or model turn**, and the owner
  receipt reports that outcome instead of a false `verification_failed`. Installed-but-unused is
  unchanged: its own stopped reason, never a forced adoption.
- **Cumulative publication bound.** `max_publishes` was only tested `>= 1`, so a policy allowing
  one release still let a reopened round release again. Completed releases are now counted in
  `cycle["publishes_total"]`; a further publish refuses with `max_publishes_reached` (exit 6),
  records `publishes_total` in the refusal, keeps the previous bytes, and still delivers a receipt.
  A crash-left publish intent journal is still completed idempotently rather than refused.
- **Failed candidate bytes preserved.** `stage_candidate` previously `shutil.rmtree`d the candidate
  on every reopened round, destroying the failed bytes and breaking resume. Reopened round *n* now
  uses its own `candidates/<issue_id>-r<n>` checkout derived from the pinned base; nothing is
  deleted or recreated on resume, and the owner can inspect its previous change.

Checks actually run (UTC, `Get-Date -AsUTC`, this host):

- `python -m unittest tools.test_gm_autonomy` -> **55 tests OK** (5.6 s); new
  `test_inconclusive_runtime_evidence_never_reopens_a_repair_round` covers all seven integrity
  negatives plus the conclusive positive.
- `python tools/validate_gm_autonomy.py run --scenario publish_cap` -> `ok: true`, 10 labelled checks
  (`tmp/gm-autonomy-20260913/validate-publish_cap-20260913T070029Z.json`): policy `max_publishes=1`,
  round 1 really releases, the labelled defect reopens one repair round whose candidate passes the
  host gate, and the second release is `refused` with `publishes_total=1`, the deployed bytes still
  equal the first release, and the owner still receives two receipts.
- `python tools/validate_gm_autonomy.py run --scenario repair_after_defect` -> `ok: true`, 22 labelled checks (the previous 20 plus the two new preservation checks)
  (`tmp/gm-autonomy-20260913/validate-causal-repair-prereq-20260913T070116Z.json`), now with
  explicit `max_publishes=2` and new checks that the failed candidate's bytes survive on disk and
  that the repaired round has its own candidate directory.
- `python tools/validate_gm_autonomy.py run` -> all **14 scenarios `ok: true`**
  (`tmp/gm-autonomy-20260913/validate-all-20260913T070131Z.json`). Offline scripted GM, zero paid
  model calls.

Unresolved design choice to escalate (not decided here): the illustrative example - a defective
predicate that *denies* well use - surfaces in the running world as installed-but-unused, which by
the standing rule must never reopen a repair round. A causal fixture therefore needs its behaviour
defect to surface as the world's own loud failure (a reported contract/unit violation with
`installed=false`), or the installed-but-unused rule itself would have to change. That decision is
the supervisor's.

Still open, unchanged and not attempted this round: the causal GDScript behaviour-module fixture
under `game/capabilities/` with a host parse/type/unit gate; the second intentional release using
the prior accepted release bytes as its expected base (refusing third-party drift); pinned
policy/host hash comparison at release with the shared installation lock held while checking
deployed bytes and executing verification (Windows alias/case normalization); deferred-claim second
delivery; watch error/ledger reconciliation. H47 remains partial and unaccepted; no main HEAD,
world, save or credential was touched, and only the files listed above changed.

## H47 causal runtime repair fixture (2026-09-13 07:14 UTC)

Primary deliverable delivered: the missing causal repair case. `tools/validate_gm_autonomy.py`
`run --scenario causal_repair` passes 21/21 checks. A test-only GDScript module
`game/capabilities/well_stock_lookup.gd` (written only by the scripted fake GM) is released twice on
the same save. The defective first release resolves `wellWater` and the running world reports
`runtime_mechanism_error` before install/use; the same owner releases behaviourally different
corrected code that resolves `well_water`, and the same save draws and consumes exactly one water.

- bad release sha256 `87d8d1cf1a2c79722e660e7d865de726e4cd13b8f642bb109b83757270af859c` (737 B), good release sha256 `80e9eac4849ee099facdd3445378840867ed3765f0603e0232c3a1b85d2a6f26` (738 B); the second release
  records the owned first-release sha as its `previous_sha256`.
- exactly 2 permitted publications, exactly 1 reopened round, 2 real coding dispatches,
  0 disclosed/injected defect markers, 0 paid model calls.
- counterfactual: the preserved bad bytes are replayed against a freshly seeded, unmutated save
  after marker/count manipulation and still report `runtime_mechanism_error` with the save
  byte-identical; only corrected code can turn the runtime green.
- coordinator prerequisites closed minimally: a second intentional release compares against the
  same owner's last accepted release bytes (third-party drift still refused); pinned policy/host
  hashes are rechecked at release; the shared installation lock is held while deployed bytes are
  checked and the world is verified (`deployed_bytes_match_release` added as an integrity check).

Unit tests: 57 pass (`python -m unittest tools.test_gm_autonomy`). Related scenarios re-run once and
green: `causal_repair`, `repair_after_defect`, `publish_cap`, `release_conflict`, `publish_race`,
`installed_unused`, `happy`. `repair_after_defect` remains labelled transport-only evidence.

### Incident: test-file truncation and recovery

While applying a source edit, an invalid `Path.write_text(newline=...)` argument truncated
`tools/test_gm_autonomy.py` to 0 bytes. The file was rebuilt from the preserved earlier copy plus
the recorded patches; the result is 48064 bytes (the exact pre-truncation size) and compiles to a
code object identical (names, line numbers, bytecode, consts, varnames) to the `.pyc` compiled from
the intact file earlier this turn. Residual risk: comment/whitespace bytes are verified only
structurally, not byte-for-byte. Details: `tmp/gm-autonomy-20260913/test-file-truncation-incident.json`.

### Limitations

H47 remains PARTIAL for root acceptance. This is an offline fixture: the GM decisions are scripted
and no model was called. Installed-but-unused semantics are unchanged. No production/Kimi/real-GM
run, no main HEAD change, no world reset.

## 2026-09-13 closure: compile gate, pinned release bindings, installation-lock aliases

Three review findings were closed against `tools/validate_gm_autonomy.py`, `tools/gm_autonomy.py`
and the host-owned fixtures. No production/Kimi/real-GM run, no main HEAD change, no world reset;
`game/core/world_kernel.gd` is untouched. No old full-suite rerun was repeated.

1. Compile gate. The bounded Python check is now described and used as an INTERFACE guard only: it
   bounds bytes, decodes UTF-8, balances delimiters, requires the declared name and filters tokens,
   so it is not a compiler, not a sandbox and not a guarantee of no ambient IO. The new immutable
   host-owned `game/tests/gm_autonomy_module_smoke.gd` is listed in `host_owned_paths` and compiles
   the candidate bytes with the real GDScript compiler in a disposable Godot process, instantiates
   the module and calls `lookup_well_stock({})` with the declared neutral/empty unit input,
   requiring a schema-valid missing-stock error. A delimiter-balanced but unparseable module (for
   which the Python guard returns `[]`) now fails with GDScript parse error 43, while the bad and
   the corrected lookup modules both compile and both return `runtime_mechanism_error`; the smoke
   therefore still cannot tell them apart, and only the same-save snapshot integration can. In the
   real `causal_repair` run the host gate reported
   `module_smoke: [{compiled: true, code: "runtime_mechanism_error", ok: true}]` for the released
   candidate. The scratch project is created under the task-owned fixture area (never a system temp
   dir this host refuses) and removed afterwards; the Godot call is bounded by a timeout, and a
   timeout or missing report is a refusal, never a pass.

2. Pinned release bindings. `load_cycle` now pins the trial base-manifest digest and the host-owned
   script digests when the cycle starts. `stage_publish` re-reads the LIVE `sha256_file(policy)`,
   the base manifest and the host-owned hashes and refuses with `release_binding_stale` BEFORE any
   deployment target is written when any of them drifts from that original pin, instead of
   comparing one cached digest to another. A cycle whose pin is absent (reopened repair or restarted
   process) is refused rather than silently re-bound to today's bytes. Negative tests cover an edit
   to the policy, to the base manifest and to a host-owned script between the host gate and the
   release, plus both missing-pin cases; the legitimate owned second release still compares against
   its own receipts and still refuses third-party drift.

3. Installation-lock aliases. The shared installation-lock key now normalizes the resolved checkout
   with `os.path.normcase`, so two Windows spellings of one deployment cannot take two different
   locks. The test asserts case-variant spellings share one lock directory while a different path
   still gets a different one. Lock-before-receipt ordering and the third-party drift refusal are
   unchanged.

Verification this turn: `python tools/test_gm_autonomy.py` 68/68 pass (the 57 preserved tests plus
11 new); `python tools/validate_gm_autonomy.py run --scenario causal_repair` passes with the gate
compiling the released module. No subagents, no provider calls, no commits.

## H47 continuation: watch correctness and queued-claim delivery (bounded engineering turn)

This turn changed `tools/gm_autonomy.py`, `tools/validate_gm_autonomy.py` (one guard),
`tools/test_gm_autonomy.py` and this note. No provider call, no Godot run, no commit, no world
reset; the pre-existing 68 tests are preserved.

4. The bounded watch coordinator now holds a distinct OS watch lock (`OwnerLock`, byte-range lock,
   never a PID probe) across its whole read/reconcile/write/run sequence, so a second concurrent
   invocation is refused with `watch_lock_held` and cannot spend the same persisted budget. It
   reconciles every cycle's durable `model_calls` counter (which already contains an in-flight
   reservation) from `autonomy/*/cycle.json` before computing what is left, so a crash between the
   reservation save and the watch-ledger save cannot overspend and an interrupted-unknown call
   stops with `interrupted_unknown_stop` at its own nonzero status, is never replayed and is never
   zeroed. A resumed cycle keeps its already-counted turns inside the cumulative ceiling (only the
   other cycles are subtracted), a failed or blocked cycle returns its own nonzero status
   immediately and is never reported as a bounded idle stop, `--state-dir` must agree with the
   policy `paths.state_dir`, negative or nonsensical limits are refused, and
   `--reset-watch-budget` appends the old ledger to `history` and carries `unresolved_usage`
   forward instead of erasing facts. Reporting now names native GM turn dispatches (`gm_turns`,
   compatibility alias `model_calls`) and `dispatch_batches`, explicitly not HTTP requests and not
   a currency charge.

5. A cycle now delivers a queued GM-owned claim before any new observe. `examine_queued_claims`
   rebuilds the queue from an earlier finished cycle over the SAME pinned policy and evidence,
   consumes one entry only when the same GM still owns that issue and it still carries a proposed
   scope, preserves the original owner, `owner_run_id` and observation origin, records
   `queued_from_cycle` so a source is handed over once, and makes an unresolvable queue an honest
   `no_action` instead of a second paid observation of unchanged evidence.

6. Two review corrections with one focused negative each: `godot_module_smoke` now requires
   `exit_code == 0` and appends a nonzero-exit failure even when the script wrote `ok: true`; and
   `stage_verify` re-runs `stale_release_binding` under the installation lock and before the host
   script, refusing with `release_binding_stale_after_publish` so a host script edited after
   publication is never executed.

Verification this turn: `python tools/test_gm_autonomy.py` 79/79 pass (all 68 previous tests plus
11 new) - raw output in `tmp/gm-autonomy-20260913/h48-unit-suite.txt`; the new classes are
`WatchSafetyTests` (7), `QueuedClaimTests` (2), `ModuleSmokeExitCodeTests` (1) and
`VerifyBindingTests` (1).

Remaining gaps (not claimed as done): no end-to-end two-claim delivery scenario was added, so the
serial two-claim path is verified at the mechanism level (queued-claim selection, budget
reconciliation, blocked/idle exits) and NOT yet by a real Godot run on the seeded fixture; the
watch was not exercised as the driving command in `validate_gm_autonomy.py`, and the real-model
preflight/ready route is untouched. A previous H47 edit to `tools/test_gm_autonomy.py` was backed
up at `tmp/gm-autonomy-20260913/test_gm_autonomy.py.bak` (sha256
`08C230E32C924A2B95745E65CC248194E7C324EB8DF3262C53AA500A516C26E4`, 60035 bytes) before this
turn's edits; all writes used the default newline.

## Correction round (2026-09-13, DeepSeek worker) — supersedes the first entry point

Root rejected the first prepared entry point `local-trial-h47-20260913` for four concrete defects.
That fixture, its save, ledger and preflight evidence are PRESERVED as an unaccepted first
preparation; nothing was rewritten to erase the mistake. Reusing it is now refused before any write
(`exit 4`, `refused_fake_prior_ledger`) because its prior ledger is the scripted
`fixture_prior_ledger`.

Defects fixed in `tools/prepare_gm_autonomy_local.py`, the `local_trial` provisioning branch of
`tools/validate_gm_autonomy.py`, related tests and docs:

1. `commands_for` watch preset now budgets 32 native GM turns (`--max-calls 32`), 4 iterations and
   900 seconds. The ten GM identities come from the policy `limits.max_gms` the command points at.
   These are native GM turns, NOT HTTP requests; the budget covers the initial 10-identity observe
   batch plus coding, feedback and a queued continuation, and the one-file release scope is
   unchanged. Changing prepared argv launches no model and changes no paid history.
2. `local_trial` provisioning no longer writes the fake `fixture_prior_ledger`, `fake_codex.py` or
   the fake key. It writes a NON-fake `carried_accounting_reference_ledger` linking the measured
   history in `accounting-summary.json`, `usage-root.json` and
   `deepseek-correction-usage-incomplete.json` and keeps the interrupted DeepSeek tail
   `status=unknown`; no settled or zero fee is invented. The exact generated `--prior-ledger`
   argument points at that non-fake ledger. A fake prior ledger is refused before any write in real
   local mode. The real key stays a path reference to
   `C:/InfiniteAincrad/private/deepseek-api-key.txt`; this helper never reads, copies or prints it.
3. Labels must match `[A-Za-z0-9_-]` and resolve directly inside `LABEL_ROOT`; the check runs before
   ANY write, including direct `prepare()` calls, so separators, `..` and traversal are refused
   without creating outside files.
4. Reuse preserves the save, marker and policy bytes but re-runs the requested read-only preflight
   and propagates failure; a preparation with non-empty `required_paths_missing` is never reported
   as success.

Actual corrected fixture: `tmp/gm-autonomy-20260913/local-trial/local-trial-h47r2-20260913/`.
Real preparation plus the exact no-dispatch preflight and status command showed
`planned_gm_identities=10`, `dispatched_turns=0`,
`key_file_reference=private\deepseek-api-key.txt` with the file present,
`windows.sandbox=unelevated`, `required_paths_missing=[]`,
`prior_ledger_kind=carried_accounting_reference_ledger` with the unknown tail preserved, and a reuse
that left the save, marker and policy SHA-256 values unchanged. The real route remains PREPARED, not
proved live: no provider request was made. Evidence JSON:
`tmp/gm-autonomy-20260913/local-trial-h47r2-verification-20260913.json`.

Checks run once this round: `tools.test_prepare_gm_autonomy_local` 17 tests,
`tools.test_gm_autonomy` 83 tests, and host scenarios `causal_repair` and `watch_two_delivery`. The
previously passing isolated-repo compatibility suites were NOT re-run because no `gm_runner`
interface changed. H47 stays partial pending root acceptance.


### Prior compact status entries (preserved on final acceptance)

最新（2026-09-13 更正回合，待root复核）：H47仍为部分。root否定上一回合入口 `local-trial-h47-20260913`，四项具体缺陷已修：①watch预设 `--max-calls` 由3改为32 native GM turns（`--max-iterations 4`、`--max-seconds 900`；10个GM身份来自policy `limits.max_gms`，单文件发布范围不变；32是native GM轮次而非HTTP请求数，覆盖初始10身份批次+编码/反馈+排队续接）；②`local_trial` provisioning不再写虚假 `fixture_prior_ledger`/`fake_codex.py`/假key，改为非伪造 `carried_accounting_reference_ledger`，链接 accounting-summary.json、usage-root.json、deepseek-correction-usage-incomplete.json 的实测历史并保留中断未知尾部为unknown（不虚构结清/零费用），真实local模式在任何写入前拒绝fake prior ledger（旧入口复用exit 4/refused_fake_prior_ledger，旧文件原样保留）；③标签须匹配 `[A-Za-z0-9_-]` 且解析后位于LABEL_ROOT内，直接`prepare()`调用同样在任何写入前校验，分隔符/`..`/非法标签拒绝且不产生外部文件；④复用保留save/marker/policy字节、重新运行所请求的只读preflight并传播失败，`required_paths_missing`非空绝不再报success。实际交付新入口 `tmp/gm-autonomy-20260913/local-trial/local-trial-h47r2-20260913/`：真实prepare+no-dispatch preflight，10计划GM身份、0派发、key仅以路径引用（文件存在）、unelevated、required齐备、非假账本unknown保留，复用已证明save/marker/policy SHA-256逐字节不变。验证：17项准备单测+83项autonomy+causal_repair与watch_two_delivery各一次。真实模型未运行；H47仍部分，等待root验收。

上一回合（2026-09-13，其本地入口 `local-trial-h47-20260913` 因上述四项缺陷被root拒绝，未接受）：H47仍为部分。本轮只闭合三项watch闸门缺陷并交付**一个已准备且已实际预检**的本地试运行入口，不宣称真实自主GM生命、真实模型结果或持续10+10。watch修复：①已计费cycle文件丢失/损坏不再被静默跳过——`watch_cycle_scan`如实报告，`reconcile_watch_counters`单调合并、计数只增不减，停止码`cycle_counter_unreadable_stop`（ACCOUNTING），文件丢失绝不释放已花配额；②carried `unresolved_usage`的源cycle文件消失时仍为`interrupted_unknown_stop`，`--reset-watch-budget`保留该事实、绝不清零/结清未知费用；`--max-calls`明确记录为**state目录生命周期上限**（重置只重开窗口，不产生新配额，历史已计turns仍计入）；③cycle `payload.status=blocked`而退出码为0时，在构造`watch_summary`前即归一为RUNTIME，JSON不再出现ok/last_exit_code=0而命令失败。本地入口：`tools/prepare_gm_autonomy_local.py` 生成唯一标注目录`tmp/gm-autonomy-20260913/local-trial/local-trial-h47-20260913/`，仅经既有Godot `--phase=seed --allow-create=yes` 种子路径造档、拒绝覆盖已有save；真实结果：status=prepared、preflight ok、10个GM身份、0次派发、required paths齐备、`windows.sandbox=unelevated`、key仅以`--key-file C:/InfiniteAincrad/private/deepseek-api-key.txt`引用（helper从不读取/打印）；第二次调用`already_prepared`且save/policy/marker三个文件SHA-256逐字节不变。World provenance（新fixture genesis）与GM transport（真实DeepSeek路由，已准备未跑）分离；新增`local_trial`模式与显式provenance，`offline_fixture`仍如实标注scripted fake。实测一次：92项单测（83+9）、causal_repair与watch_two_delivery各一次、隔离仓库旧runner/discovery/two-contribution共51项全部通过（主worktree 6项candidate测试仅因`.git/worktrees`在本沙箱不可写而失败，隔离仓库内通过）。历史DeepSeek用量与中断未知尾部仅被引用，未换算/清零。下一步：root只读复核本轮；真实模型路线保持已准备未运行。

2026-09-13（GPT验收，前序）：H47本地自主GM循环部分完成，未整体接受。12个脚本场景、43项单元测试、独立测试仓库的34＋15＋2项旧回归通过；已验证GM自选范围、候选自测修错、单文件试验发布及真实Godot内核fixture同档冷恢复。独立复核发现：installed_unused场景中GM回复repair后循环仍永久blocked，回执还误称released_and_verified；排队任务第二次交付及watch错误/费用续接仍待补齐。[证据与待修项](validation/gm_autonomy_2026-09-13.md)。用户选择本地试运行、尚未正式开跑，跨机器主档不是本轮前置，没有生产GM/Kimi或10+10运行。第二个DeepSeek工程回合达到1800秒上限，已保存部分用量，尾部未知；按用户替换后的AGENTS延续规则，工程继续（未知开发尾部保留、不为该记账缺口重复审批）；第三回合已纠正回执语义与反馈接受条件并加入同一GM有界修复推进，43项单元测试复跑通过；真实生产GM/Kimi派发未启动。现有每小时GPT巡检已启用，只读监督、无变化静默。下一步为原GM收到准确失败事实后自动完成一次有界修复与复验，不扩大功能范围。第四回合（DeepSeek，2026-09-13 06:45–06:54 UTC有界）：新增repair_after_defect端到端证据——真实运行缺陷→同一GM有界修复→第二个候选/门禁/第二次Godot同档复验通过；受控缺陷为标注注入fixture；installed_unused保持不修复、无重复副作用；13场景与54项单元测试复跑通过。第五回合（DeepSeek，2026-09-13 07:05–07:15 UTC有界）：补齐因果修复fixture——测试专用GDScript行为模块（坏版查wellWater→runtime_mechanism_error；修好后查well_water），同一GM第二次编码修好、同一存档仅抽/耗一次水；恰好2次显式发布、1轮重开；反事实把坏字节在标记/计数篡改后重放仍失败。最小前置已补：第二次发布以同一owner上次接受发布字节为基线并拒绝第三方漂移、发布时核对固定策略/宿主哈希、验证期间持安装锁并校验部署字节。21/21场景检查、57项单元测试，causal_repair/repair_after_defect/publish_cap/release_conflict/publish_race/installed_unused/happy复跑通过。事故：一次无效newline参数把tools/test_gm_autonomy.py截断为0字节，已从保留副本＋记录补丁恢复为原48064字节，且与截断前.pyc代码对象逐层一致；残留风险仅注释/空白非逐字节可证。

