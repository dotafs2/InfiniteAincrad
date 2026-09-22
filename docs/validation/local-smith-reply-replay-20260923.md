# Saved Smith reply replay

Open `game/scenes/local_smith_reply_replay.tscn` in Godot 4.7.2 Mono to inspect
the one actual local `qwen3:8b` proposal from the disposable axe day. The scene
reads only the committed Smith context, raw response, and report under
`docs/validation/local-smith-reply-20260923/`. It makes no network or world call.

The replay explicitly labels the speech as an undelivered proposal. The raw
line asks Rowan whether Flint should accept, declares `ask`, and puts the full
`contract:accept:trade_contract_fixture:offer` ID into `next_action`. The
independently exported action list associates that ID with allowed alias `a16`
and expected declared intent `agree`. Godot's actual response was
`unsupported_next_action`, with `provider_error` recorded by Turns and the
last trade event still `offer_repair`. The preview does not turn the failed
proposal into a valid action or claim that sentence meaning has been verified.

Before display, it checks the single Smith case, independently exported aliases,
raw SHA-256, and the saved report's structural result against a fresh
`DialogueReceipt.parse` call. It shows only bounded public strings from the raw
response; `private_thought` is never copied into UI or capture evidence. Missing
or mismatched evidence leaves the preview in an invalid state.

The focused Mono acceptance passes 11 checks, including exact rendered text,
absence of private thought, and a tampered raw response rejected by the evidence
join. Logs: `private/iteration-20260923/local-smith-reply-replay-acceptance-r2/`.
The offscreen 1400×900 render exited 0 with all managed processes stopped; its
[screenshot](local-smith-reply-replay-20260923/local_smith_reply_replay.png) was
visually inspected, and its [public capture record](local-smith-reply-replay-20260923/capture.json)
reports `screenshot_saved:true`. The first capture attempt used an invalid
renderer flag; the second used headless frame drawing and was stopped. Only the
third graphical compatibility run is visual evidence.

Reproduce the focused acceptance from the delivery checkout:

```powershell
$env:DOTNET_ROOT = 'C:/Program Files/dotnet'
$env:DOTNET_ROOT_X64 = $env:DOTNET_ROOT
$env:DOTNET_ROLL_FORWARD = 'LatestMajor'
python tools/run_godot.py --godot D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe --name smith-replay-check --timeout 35 -- --headless --script res://tests/local_smith_reply_replay_acceptance.gd
```

The scene can be opened interactively in Godot. For finite capture, pass an
absolute `--capture-dir` after the engine's user-argument separator `--` and
use the graphical `gl_compatibility` rendering method.
