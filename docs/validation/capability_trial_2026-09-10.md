# Offline capability trial — runnable, acceptance incomplete

Date: 2026-09-10. Worktree: `C:/Users/quchenxi/.codex/worktrees/0b50/InfiniteAincrad`.
Root task: `01a08a9a-b3d4-7451-8275-a1e75e329b34`.
Sole worker: `01a08a9d-0c38-7841-bff6-e6cf270b5a7d`, gpt-5.6-luna; interrupted during closeout. No recursive delegation, paid Kimi run, original save access, historical ledger reset, release or push.

## What exists

`game/project.godot` starts a native Godot courtyard UI. The resident and GM have separate panels. The package `game/capabilities/well_bucket.v1.json` describes exactly one versioned water-transfer capability. The core validates its shape and fixed semantics, controls materials, records command IDs, rejects changed payloads on reused IDs, executes draw/drink rules, and retains fixture identity and events when the capability is disabled.

The test world is `fixture:well-street`; its only resident is `fixture:luna`. One unit of water starts in the well and moves to inventory, then to the consumed counter. One rope and one bucket are spent to install. All of this is manually seeded and locally rule-driven. No historical Luna reply was imported or replayed. This is not evidence of a naturally discovered need, a real model choice, original-world continuity, or an unattended development platform.

## Actual checks

Godot 4.7.2 Mono ran the following root-owned processes; each exited 0:

| Run | PID | Evidence |
| --- | --- | --- |
| Existing core acceptance suite | 73952 | `tmp/plugin-validation/core-final.stdout.log` |
| Main scene, headless three frames | 72996 | `tmp/plugin-validation/ui-final.stdout.log` |
| Graphical UI buttons: step, validate, install, draw, drink, disable, save/reload | 31524 | `tmp/plugin-validation/visual-smoke.stdout.log`, `ui-state.json`, three `ui-*.png` captures |
| Cold write | 70928 | `tmp/plugin-validation/cold-write.stdout.log` |
| Cold read, separate engine process | 73304 | `tmp/plugin-validation/cold-read.stdout.log` |

The core suite checks rejected role/identity impersonation, invalid package fields/transfer amount, command replay, resource transfer, save/load and disabled capability retention. Cold recovery preserved fixture identity, inventory and receipt IDs. The suite's `ok:true` reports only its implemented assertions. It does not establish the unimplemented requirements below. UI automation exercised real button signals; it was not a manual playthrough or an independent exported build. Process records retain commands, PID, timeout and exit status. Test artifacts remain private under ignored `tmp/`.

## Why full acceptance failed

1. `resident_step()` directly reads core inventory, plugin state and well resources. It does not choose exclusively from `resident_view()`. The view's actions field records past actions, rather than exposing a current available-action interface. Observations still contain implementation language and can become stale. This is the main semantic gap.
2. GM installation validates a manifest, but does not require a recorded need and capability-gap assessment. The UI's check button currently validates the package only. The first wait is not a genuine model-authored need. Memory is recorded but subsequent decision causality is insufficiently demonstrated.
3. Saving directly truncates/writes the destination. There is no atomic replacement or crash recovery, and nested state/resource validation is incomplete. The GUI holds its writer lock for its lifetime, but standalone save/load calls do not yet provide a complete session ownership contract. A crash can leave a stale lock; no automatic lock stealing is provided.
4. Re-enabling a disabled package tries to charge materials again. Installation history/material accounting and repeat-install semantics need completion. No real API budget ledger is attached; the zero local GM budget field is not proof of paid-budget enforcement.
5. The UI retains diagnostic JSON/English observations, has no completed small-window/accessibility review, and does not cover every save-error path. It is a reviewable prototype.

Required next bounded result: fix those core semantics, add adversarial and crash-safe persistence acceptance, then repeat the graphical/cold-process checks. The original save and carried paid ledger remain external prerequisites for a future real-model/same-world run; they did not block this offline work.

## Metering and stop

Start: 09:16:42 UTC; deadline: 13:16:42 UTC. Combined maximum: 2,000,000 raw tokens, including cached/system/tool inputs and worker use. Fresh-task baselines were zero. The first three distinct response increments matched each log's last-response input + output. Totals use the latest cumulative counter once per task; cached input and reasoning are subsets, not added again.

At the integration checkpoint the combined count was 1,693,448: root 642,698 and worker 1,050,750. The worker exceeded its assigned 400,000 sub-budget before the root's next phase measurement; root supervision failed to stop that earlier. It was interrupted immediately upon detection. A later checkpoint was 1,828,812, with worker usage unchanged. Final measured totals and incremental checkpoints are in the private status below; any closing response not yet logged is explicitly outside that completed-response measurement. There is no hard automatic cutoff. The root stopped further engineering near the combined limit and retained this incomplete result, without adding a replacement batch.

Private monitor: `C:/InfiniteAincrad/tmp/active-plugin-batch/status.json` and `usage-checkpoints.jsonl`. Supervisor-task usage is separate and unmeasured here; it is not free. Historical paid charges are unchanged and unverified, not zeroed.

Final measured completed-response checkpoint: 2059466 raw tokens; cached input subset 1873920; measured excess over 2,000,000: 59466. Current closeout/final response may not yet be logged. No further engineering is dispatched.

Cleanup: all five root-owned Godot processes exited; worker interrupted. Automatic approval rejected a combined command containing temporary lock-directory removal (reason: blocked by policy). The empty test-only lock directory is retained.

## Resume update — 2026-09-10

The authorized continuation repaired the scoped gaps in the fixture kernel. `resident_step()` now obtains a `resident_decision_request()` and chooses only from its resident-owned view; `submit_resident_decision()` rejects GM fields and unavailable actions. An inaccessible well produces a persistent, world-language water-access need. `gm_review_need()` records an approval or rejection with a reason, and `gm_install()` requires that approval. The bucket observation is added only after installation, so the next local rule decision discovers it through the resident view. Re-enable reuses the recorded installation and does not consume rope or bucket again. `export_resident_decision_request()` writes the strict observation/request JSON for a future model adapter; this run still uses `fixture_resident_observation` and `local_rule_policy`, never a real model.

Saving now writes a flushed temporary file, uses a pending-replacement marker and backup rollback/recovery, and validates state version, world identity, quantities, required history and resident identity before assignment. A failed replacement test confirms the previous valid target remains unchanged; the tests do not simulate a power cut between filesystem rename operations.

The new core suite `core-fixed-3` exited 0 after these changes. A fresh graphical smoke run (`visual-final-v2`, PID 63216) exited 0 after the real button chain: resident wait/need, GM package-and-need check, install, resident use, disable, save/reload. Fresh separate `cold-write-final` (PID 77756) and `cold-read-final` (PID 84872) processes both exited 0 and preserved the same fixture identity, approval, capability, item and receipt IDs. The resulting screenshot is `tmp/plugin-validation/final-ui/ui-disabled-restored.png`. All processes exited; no worker remains.

The maintained-world G0 remains blocked by the unverified private original save and carried cost ledger. This fixture is still not a real Luna migration, a naturally discovered main-world need, a Kimi response, a replay, or an unattended plugin marketplace. The remaining engineering caveat is filesystem-crash coverage beyond the tested failed-replacement path; a future authorized batch should add a deterministic interruption harness before claiming crash-proof persistence.
