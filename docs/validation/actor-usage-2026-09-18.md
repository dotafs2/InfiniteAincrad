# Permanent developer usage and the first fresh-world GM observation

H112 corrects H111's accounting prerequisite. This world started at seq0 by explicit user instruction. Its developer usage belongs to its own stable NPC/GM identities from genesis. Accounting from the separate original world does not prevent this world's observation or resident life. The existing provider billing ledger remains intact.

## Delivered behavior

`tools/actor_usage.py` maintains one SQLite book beside the active world. Each identity is `world_id/actor_id`; names, process restarts, model changes and native session changes do not reset it. All ten residents and ten GMs have entries. This metadata stays outside NPC observations, prompts and world rules.

The live NPC gateway records an intent before dispatch and imports the exact provider ledger receipt afterwards, including error paths. Existing calls are recovered by exact request ID and resident from the original episode, not by date or a guessed token estimate. Replayed cached receipts cannot double-count tokens. GM observation, coding and feedback use the same book; completed native sessions contribute their highwater delta. Interrupted native runs retain confirmed per-turn usage as a lower bound while keeping the tail unresolved. Currency charges are never invented from missing prices.

The portable JSON contains all per-call receipts and their append-only revisions, without prompts, replies, API keys or native reasoning. Restore validates the complete history and derived counters and refuses to overwrite an existing book. A continued world with a missing book cannot silently start from zero. The authoritative SQLite file, JSON and readable table survive ordinary restarts; migration explicitly carries the JSON checkpoint.

## Observed results

- All 32 existing fresh-world Kimi calls were attributed to their actual ten residents: **83,274 tokens**, preserving the original **CNY 0.5280753** charges. No new NPC call was made in H112. The account's existing 218 settled billing rows and guard remain unchanged.
- One real `gm-05` observation used `deepseek-flash` through the existing native route. It read code and reached the host's **90-second deadline** without returning a final observation. The run was stopped and all owned processes exited. No GM proposal was accepted, candidate installed or NPC action fabricated.
- Twenty recorded native response receipts establish **781,942 input + 10,884 output = 792,826 known tokens**. Of input, **721,664** are cached; the **6,834** reasoning-output tokens are already included in output. The native turn never completed, so these are a lower bound, not proof of the final total or currency charge. The table displays `792,826 + unknown`; the current-world GM accounting hold remains in place. No paid retry was attempted.
- The world is still the exact seq43 checkpoint, SHA-256 `a0228906f6b417db2e9b3faae335fae6cc81d2a11810f109efd93f53a55ccd2a`. Usage and GM state are separate sidecars. Original empty GM bootstrap and all world checkpoints remain retained.

Read the [developer table](../../worlds/restart-20260918-01/usage/latest.md) and [checkpoint manifest](../../worlds/restart-20260918-01/usage/manifest.json). The manifest binds the complete safe usage history and current full GM state; native session transcripts remain private.

## Verification and limits

The focused suite covers permanent identities, exact Kimi attribution, error-path accounting, repeated receipts, native resume deltas, partial usage, wrong-world rejection, tampered migration rejection, missing-book refusal, charter protection, launcher shutdown and production bridge behavior. Final results are in [checks.json](actor-usage-2026-09-18/checks.json). Initial failures exposed two minimal launcher fixtures without resident rosters and an omitted weaver identity; their fixtures now match the requests they send. A combined run that added the broader native runner fixtures exceeded a 55-second host budget and is not counted as passed. It left no owned process running.

The useful next engineering step is to constrain GM observation to the evidence and relevant interfaces so it returns a bounded result instead of repeatedly reading source. Its observed timeout and incomplete final accounting are current issues. Independently, new arbitrary capability installation still needs a concrete deployment/runtime contract, and voluntary live adoption of H110 conversation/shared visits remains unobserved. Existing NPC life is not contingent on recovering another world's GM bill.

The user also reported `The access_programs parameter is not enabled for this organization` in the current Codex conversation. No matching error appears in this GM run. Its wording indicates a service-side feature-availability rejection; the precise client feature is unconfirmed. Do not change game accounting or API credentials to guess around this separate client error.

## Transfer to another computer

Verify the usage manifest hashes and world identity, restore the latest world and GM checkpoint only into an absent destination, and then run:

```powershell
python tools/actor_usage.py --world private/worlds/restart-20260918-01/world.json --gm-state private/worlds/restart-20260918-01/gm/state.json --restore-snapshot worlds/restart-20260918-01/usage/seq000043-fa8acd92433d7d0f.usage.json
```

This imports complete usage history and binds the copied GM state to the new local book. It does not resolve the interrupted GM attempt, restore its private native session or reset the provider billing ledger. Credentials remain local. Subsequent checkpoints must append to this history; never rerun a zero-world bootstrap to continue it.
