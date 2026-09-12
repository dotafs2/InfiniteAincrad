# Model workflow (development execution routing)

Decision, 2026-09-11: all development execution goes to DeepSeek `deepseek-flash`.
GPT-6 discusses alternatives, challenges direction and reviews reported outcomes with
the user; it does not implement. Routing or dispatching an authorized DeepSeek task is
orchestration, not implementation.

## Launchers (verified on this machine vs. legacy machine notes)

The legacy shared launcher notes recorded an older machine's install root
(`<LEGACY_LAUNCHER_ROOT>/scripts/deepseek.py`, key and run logs under that root's
private directory, a `deepseek-flash` profile). That install does not exist here; those
paths stay only as history and are not the current instructions. Do not silently
recreate them or copy a launcher between roots, because a launcher's credential root
decides which account and ledger a run charges.

This machine's verified local native launcher is:

- Launcher: `tmp/chain-20260912/dispatch_native.py` (repository-relative, inside this
  project's ignored `tmp/` output; never committed).
- It runs one bounded native `codex exec` turn against the configured provider, passes
  the task file on stdin, and keeps the run directory (events, stderr, result) for
  usage accounting.
- Resume: pass the saved session's canonical UUID with `--resume <uuid>`. The launcher
  preflights the UUID syntax and the existence of the saved rollout file, and refuses a CLI
  fallback that would create a new session. Whether the provider actually resumed the
  requested session is observable rather than enforced by the launcher: the returned
  `thread.started.thread_id` is read from the run's own events and was independently
  verified by the supervisor for a real resumed run.
- Counting the run afterwards is offline and inference-free via `tools/deepseek_usage.py
  --run-dir <run-dir>`, which reads only `process.json`, `events.jsonl` and `result.md`.
- No automatic background run; no hard token or money cap is implied by this doc. The
  agent never reads, copies or prints a provider key and never commits one.

## Example (bounded, placeholders)

```
python tmp/chain-20260912/dispatch_native.py <authorized-task.md>
python tmp/chain-20260912/dispatch_native.py <follow-up-task.md> --resume <saved-session-uuid>
```

## Interrupted-usage continuation (supervisor operational interpretation)

The user removed the cheap-DeepSeek call cap and asked for the chain to be finished and real 10+10 tested before reporting. When a bounded paid turn is cut off (for example the GM09 code turn that exceeded its 900 s bound), its measured completed responses are recorded individually and the interrupted tail stays **unknown**: never settled, zero or fully measured. The scoped work then continues through `gm_runner.py recover --usage unknown` plus `acknowledge`, with the supervisor citation in the reconciliation note — not a new user reply, and not a waiver of the Kimi ledger, new-unknown stop or currency bounds. This is the current policy; the earlier annotation that confined every continuation to the single 2026-09-12 02:26 stream incident was too narrow relative to those later instructions and is retained only as history.

## Boundaries

- Do not copy the launcher into this worktree: that would change its credential root.
- Game NPC runtime provider changes are a separate, explicit implementation scope and are
  not performed by changing development routing.
- When DeepSeek fails, GPT-6 returns a concrete report instead of silently resuming
  implementation or dispatching Luna.
- Future helper cleanup must key on PIDs, start identity and the parent chain recorded at
  launch. Never kill by process name plus time window: that cannot prove the stopped
  processes were owned, and it cannot be verified after the fact.

## Bounded single-process build (Windows reference)

Command that completed a bounded single-process build of the Godot C# project
(`game/InfiniteAincrad.csproj`) on 2026-09-11:

```
dotnet build game/InfiniteAincrad.csproj --no-restore -v minimal -m:1 -nodeReuse:false
```

- `-m:1 -nodeReuse:false` keeps the build single-process and leaves no reusable `MSBuild`
  node behind; that combined form is the one that succeeded.
- `/p:UseSharedCompilation=false` is noted for **future** use where a shared build server
  must be avoided. It has not been tested here and is not a verified command.
- Do not change sandbox, permission or profile settings to make a build pass, and do not
  add approval ceremony.
- Certify a cleanup only from recorded PID/start/parent evidence, never from a
  process-name sweep.


## Usage accounting (offline, no inference)

Aggregate one or more finished run directories with the shared runtime. The run directory is
wherever the launcher above wrote it; the `C:\InfiniteAincrad\private\deepseek-runs` form in
the older notes is the **legacy machine's** layout, kept only as history:

```
python tools/deepseek_usage.py --run-dir <run-directory> [--run-dir <run-directory> ...]
```

- Reads only `process.json`, `events.jsonl` and `result.md`; it counts each completed
  `turn.completed.usage` once and never prints run content or any credential.
- `raw = input + output` includes cached input; `weighted_cache_hit = cached / input`;
  missing usage is reported as unknown, never as 0. Exit code 3 means at least one run was
  rejected as invalid. No ledger, money estimate or cumulative session counter is written.
- Cache numbers are counters, not a guarantee. A stable task prefix raises the measured hit
  rate (recent runs observed ~0.98), but guaranteed cache reuse is never claimed.
- These are development execution counters: zero paid NPC inference; these are paid
  DeepSeek DEVELOPMENT tasks with currency unavailable. They are not a currency bill and no
  money estimate is produced.

Reasoning effort is set by the launcher's own model configuration
(`-c model_reasoning_effort=<value>` in the generated command). An optional
`--reasoning-effort` flag was described in the legacy notes; it is **not** verified for the
current launcher and must not be advertised without checking that launcher's arguments.
