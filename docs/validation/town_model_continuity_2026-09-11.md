# N3 same-identity model continuity — integration, 2026-09-11

Bounded integration of three DeepSeek worker deliveries into the single authoritative
world writer. Scope: make the NPC model an explicit, fail-closed, journal-scoped pin and
verify that the **same** resident keeps identity, personal knowledge, property, money,
contracts and an unfinished settlement chain across a controller swap and a cold reload.

## What was integrated

- `game/agents/BudgetGatewayProvider.cs` — run-scoped pinned model (`expected_model`,
  validated by `PinnedModel()`); `DefaultModel = "kimi-k2.6"`; the pin is used in the
  endpoint check, request body, response-model check and `responseModel`. Ledger, deadline
  and fail-closed budget logic untouched.
- `game/agents/OgaResidentNode.cs` — `SetupRuntime(_gatewayProvider, _gatewayProvider.ModelId)`.
- `tools/validate_gateway_adapter.py` — `pinned-model`, `model-mismatch`,
  `reply-model-mismatch` scenarios plus a shared projection whitelist assertion.
- `game/tests/town_model_continuity_acceptance.gd` — new N3 fixture suite.
- `tools/deepseek_usage.py`, `tools/test_deepseek_usage.py` — offline usage aggregator.
- `tools/run_town_model_validation.py` — added `expected_model=policy.model` to the run scope.

Test-only repair: `_reload_matches` compared a live in-memory resident (`needs.hunger` as
float `60.0`) against the JSON-decoded one (`60`); Godot's dictionary equality is
representation-strict there. The persisted bytes were already identical. A numeric
canonicaliser now compares the persisted shape; identity/story/needs, contract, item
custody and wallet assertions are unchanged in strictness.

## Verification actually run

- `dotnet build game/InfiniteAincrad.csproj --no-restore -v minimal -m:1 -nodeReuse:false`
  → succeeds; single-node build of the same sources compiles
  `BudgetGatewayProvider.cs`/`OgaResidentNode.cs`.
- The parallel `--disable-build-servers` build failed with **0 diagnostic errors** while the
  `-m:1 -nodeReuse:false` build of the same sources succeeded. The cause is **not fully
  established**: the worker's sandbox explanation was an inference, not a demonstrated
  cause, and no sandbox/permission change was made or is proposed.
- Process cleanup: the completed integrator stopped **370** `dotnet` processes, selected by
  `Get-Process` **name** plus **StartTime** between 18:35 and 18:38:30. **No ancestry proof
  was recorded**, so ownership of all 370 is **not certified** and this is **not** a
  verified-safe-cleanup claim. No damage and no security cause is asserted; the record is
  the count and the evidence limitation. Any future helper cleanup must select by PID, start
  identity and recorded parent chain, never by name plus time window.
- `town_model_continuity_acceptance.gd` → **92 checks, 0 failures**, exit 0.
- `town_online_acceptance.gd` → **63 checks, 0 failures**. `town_feedback_acceptance.gd` →
  **27 checks, 0 failures**.
- `tools/validate_gateway_adapter.py` → **15/15 cases pass**. `model-mismatch` made **0 HTTP
  calls**: the real compiled C# provider rejects a run pin the endpoint does not advertise
  before any request. `pinned-model` replay minted no second request.
- Maintained seq51 save (fictional `fixture:town-trade-validation`, 3 residents, no pending
  jobs): read-only SHA256 `F97AAA…BFB6` before **and** after, and unchanged after a
  byte-exact private copy in this worktree loaded it (world id, seq 51, 3 residents, 5
  contracts). **No writer was taken on the maintained world or its ledger.**

Suites ran headless via `tools/run_godot.py`; Godot's `user://` was redirected into the
worktree (`APPDATA`) because the sandbox cannot write the shared profile. The engine suites
were launched bounded and are a separate process class from the `dotnet` cleanup recorded
above.

## Remaining gap (honest)

This is **fixture evidence only**. The two controllers are labelled offline stand-ins for
one resident; there is no real second NPC model and **zero paid NPC inference**. There is no
currency bill here: these are paid DeepSeek DEVELOPMENT tasks with currency unavailable.
Real cross-model continuation still needs a loopback gateway that serves and prices the
pinned model in its own ledger. Model replacement in the maintained world remains
**unproven**, and the current save is a fictional test world, not the recovered original
town.

Development usage for the **five** completed DeepSeek worker runs, aggregated offline via
`tools/deepseek_usage.py`: 5 runs / 5 completed turns, **14,598,879** raw tokens
(14,356,632 input incl. 14,166,656 cached; 242,247 output, of which 159,266 reasoning;
189,976 cache-miss input; weighted cache hit 0.986767). Run ids: `20260911T102402926966Z`,
`20260911T102403352217Z`, `20260911T102402505735Z`, `20260911T103302751052Z`,
`20260911T103435909607Z`. Zero paid NPC inference; these are paid DeepSeek DEVELOPMENT tasks
with currency unavailable, and **no money estimate** is made. The totals explicitly exclude
this tiny closeout task and the root GPT-6 orchestration session. Test counts stand at
**182 Godot checks / 15 gateway cases / 16 Python tests** and were **not rerun** here.
