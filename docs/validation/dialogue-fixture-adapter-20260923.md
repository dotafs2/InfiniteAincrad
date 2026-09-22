# Dialogue fixture adapter — 2026-09-23

`game/agents/dialogue_fixture_adapter.gd` is test-only. It validates a dialogue receipt against the current resident view and exact alias-to-action mapping, then requires an explicit caller authorization before returning a normal `town_turns` decision. It never changes production turns, trade, prompts, or dialogue state.

The acceptance proves an invalid envelope cannot mutate a world, a caller-authorized current proposal reaches the existing alias gate and authoritative trade result, private dialogue fields stay outside turn state, authorization cannot revive an alias whose action mapping changed, and an unapproved proposal is a no-op. It does not verify semantic truth of dialogue claims.

```powershell
python -X utf8 tools/run_godot.py --godot "D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --name dialogue-fixture-adapter --timeout 90 --out private/iteration-20260923/dialogue-fixture-adapter -- --headless --script res://tests/dialogue_fixture_adapter_acceptance.gd
```
