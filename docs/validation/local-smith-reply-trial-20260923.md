# Local Smith reply trial

`game/tests/local_smith_reply_trial.gd` uses the formal carpenter and smith IDs
on a disposable genesis. The Smith's skill notice and the carpenter's two-Col
repair offer are supplied fixture setup; only the Smith enters `Turns.step` and exports its
native alias record.

The exchange directory must be explicit and empty of `contexts.json`,
`response.json`, and `report.json`. Before any world work the trial rejects a
pre-existing artifact. It creates a PID/tick fixture, hashes the immutable
source before and after, releases writers on every exit, and deletes only that
fixture. Context options have current `TownRuntime.trade_options` descriptions,
canonical IDs, and the review gate's expected intents, including empty unmapped
families. The observation is the vetted local projection and omits
`known_rules.decision_format` and private thought.

`mock_accept` supplies a compatible raw Smith envelope. It has to pass review,
revalidate the original alias against the fresh menu, pass the normal Turns
alias gate, reserve two Col, leave the owner with eight Col, and retain the real
`axe_contract_accepted` feedback after cold reload (the immediate result is
`contract_accepted`). `mock_mismatch` uses the same
alias with an incompatible intent and must not accept or reserve funds.

`live` makes no provider request. It waits up to 120 seconds for one complete
`smith_reply` raw string written externally, ignores empty or partial JSON,
caps the file at 64 KiB, preserves the raw SHA and response metrics, and reports
review rejection, stale action, refusal, or acceptance without treating a lawful
non-acceptance as an automatic live-model failure. Speech remains a proposal and
is never delivered by this test.

## Observed result, 03:10 China time

Exactly one local Ollama `qwen3:8b` request was made, with no retry or cloud
fallback. The response took 3969.252 ms and reported 1882 input / 140 output
tokens. The model returned a canonical action ID where the independent allowlist
requires an alias (`a16`), so Godot rejected it as `unsupported_next_action`.
No acceptance action was submitted. Independently, its `ask` intent and question
about whether to accept are inconsistent with the selected acceptance action.
The raw answer has not been rewritten to repair either error.

The report's `ok: true` means the harness completed; `structural_accepted: false`
and `outcome: review_rejected` describe the failed model proposal. The latest
fixture event is still the supplied repair offer. This live rejection run did
not cold-reload or export economic-state assertions; those are covered by the
separate deterministic acceptance/mismatch runs. Turns still records its turn
bookkeeping and error, so the disposable file is not claimed byte-identical.

Reviewable evidence: [actual context](local-smith-reply-20260923/contexts.json),
[unaltered local response](local-smith-reply-20260923/response.json),
[actual result](local-smith-reply-20260923/report.json),
[scripted acceptance](local-smith-reply-20260923/mock-accept.json), and
[scripted mismatch](local-smith-reply-20260923/mock-mismatch.json).
The raw SHA is `d06de1ae088e2475af2af64dec8acca5b8dd6cced11be7dd6f3a434e59f6b116`.
The optional `private_thought` is fictional NPC output retained only in raw
evidence; public review results omit it.

Validation: Python transport/metadata suite 5 tests, final Mono acceptance 6
checks, final mismatch 6 checks, and actual live harness 3 setup checks.
The live proposal did not pass validation. All final managed process trees
exited with code 0 and empty stderr. Local process records are under
`private/iteration-20260923/local-smith-reply-mock-accept-r7/`,
`local-smith-reply-mock-mismatch-r3/`, and `local-smith-live/`.
Earlier repair attempts are superseded evidence, not extra successful trials.

## Reproduce the offline harness

Use Godot 4.7.2 **Mono**, with `DOTNET_ROOT` and `DOTNET_ROOT_X64` set to
`C:/Program Files/dotnet` and `DOTNET_ROLL_FORWARD=LatestMajor`.
From the delivery checkout, provide a fresh absolute exchange directory:

```powershell
python tools/run_godot.py --godot D:/lucidgloves/InfiniteAincrad/tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe --name smith-offline --timeout 35 -- --headless --script res://tests/local_smith_reply_trial.gd -- --mode=mock_accept --exchange-dir=D:/lucidgloves/InfiniteAincrad/tmp/overnight-20260918/delivery/private/smith-offline-new
python -m unittest discover -s tools -p test_probe_local_smith_reply.py
```

Use `mock_mismatch` with another fresh directory to check rejection. Live mode
waits for the same exchange protocol; the separate `tools/probe_local_smith_reply.py`
client is the only component that calls Ollama. Do not rerun live merely to obtain
a passing response. No cloud savings or autonomous lifecycle is established.
