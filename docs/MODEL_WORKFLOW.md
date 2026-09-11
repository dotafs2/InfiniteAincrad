# Model workflow (development execution routing)

Decision, 2026-09-11: all development execution goes to DeepSeek `deepseek-flash`.
GPT-6 discusses alternatives, challenges direction and reviews reported outcomes with
the user; it does not implement. Routing or dispatching an authorized DeepSeek task is
orchestration, not implementation.

## Shared launcher

- Launcher: `C:/InfiniteAincrad/scripts/deepseek.py` (the one shared, launcher-root install).
- `--workdir` is optional and points the run at a specific worktree, e.g. this one.
- Profile: `infiniteaincrad-deepseek`; model: `deepseek-flash`.
- API key: `C:/InfiniteAincrad/private/deepseek-api-key.txt` (launcher-root private/).
  The agent never reads, copies or prints this key, and never commits it.
- Run logs: `C:/InfiniteAincrad/private/deepseek-runs`.
- No automatic background run; no hard token or money cap is implied by this doc.

## Example (bounded)

Invoke the existing shared launcher by absolute path, targeting this worktree, with a
bounded timeout:

```
python C:\InfiniteAincrad\scripts\deepseek.py `
  --workdir C:\Users\quchenxi\.codex\worktrees\0b50\InfiniteAincrad `
  --task-file <authorized-task.md> `
  --timeout-seconds 300
```

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

Aggregate one or more finished run directories with the shared runtime:

```
python tools/deepseek_usage.py --run-dir C:\InfiniteAincrad\private\deepseek-runs\<run-id> [--run-dir <run-id> ...]
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

Optional reasoning effort: the shared launcher accepts
`--reasoning-effort {low,medium,high}` (omitted keeps the profile value; passed through as
`-c model_reasoning_effort=<value>`).
