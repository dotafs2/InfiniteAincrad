# Formal resident axe-day fixture — 2026-09-23

`town_axe_day_formal_fixture_acceptance.gd` copies the immutable formal-resident genesis into `user://`, labels injected state and choices as an offline fixture, and never writes a production world or calls a provider. It selects current action aliases through `town_turns`, then uses the existing authoritative `town_trade` lifecycle.

The acceptance covers a damaged axe need, a specific help/reply negotiation, proposal and acceptance with escrow, delivery, sixty seconds of work, one consumed iron, one collection payment, duplicate-collection fencing, the append-only resident reply archive, and a cold restart where the same formal smith receives the accepted receipt and acceptance event in its own next personal view. A separate no-iron fixture treats unavailable acceptance as a lawful outcome.

Run with the Mono build and the established wrapper:

```powershell
python -X utf8 tools/run_godot.py --godot "D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe" --name formal-axe-day --timeout 90 --out private/iteration-20260923/formal-axe-day -- --headless --script res://tests/town_axe_day_formal_fixture_acceptance.gd
```

This is mechanism evidence only. It does not show that a live model noticed the damage, chose negotiation, accepted a contract, or completed unattended work.
