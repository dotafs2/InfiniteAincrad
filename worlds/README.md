# Active world and full-history transfer

The user authorized a fresh world starting at seq0 on 2026-09-18 and publication of its state and decisions. [active.json](active.json) identifies the current lineage. The original seq450 world is still on another computer; it was not overwritten, recovered or combined with this restart.

H111 also binds ten empty persistent GM identities to this fresh world. Their complete
[bootstrap checkpoint](restart-20260918-01/gm/bootstrap.gm-state.json) and
[manifest](restart-20260918-01/gm/manifest.json) are retained byte-exactly. These records
contain no native GM session or decision yet. Do not overwrite a later local GM
continuation with this initial checkpoint. Current readiness and its limitations are
reported in [H111 validation](../docs/validation/aincrad-gm-navigation-2026-09-18.md).

Each checkpoint is an exact copy of the saved schema-2 world, including every life event from seq1 to its stated sequence, all ten complete character dossiers, resident knowledge, decisions, replies, belongings and unfinished work. Git newline conversion is disabled for these canonical files so transfer preserves their hashes. Sequence numbers are world-local event counters, not model-call counts. Waiting or receiving a rejected model reply can change state without creating a life event, so filenames contain both sequence and content hash.

The checkpoint manifest retains earlier copies and advances only after validating the prior SHA-256, the unchanged event prefix, resident identities and the unchanged reply archive. Conflicting replay evidence may only append. Different worlds cannot share a lineage. Concurrent checkpoint writers are rejected. After a crash, inspect the lock/pending manifest and hashes before removing a stale publisher lock; never silently replace history.

For each authorized continuation, retain the original cumulative ledger and provide the launcher's `--checkpoint-dir worlds/restart-20260918-01/checkpoints` option. After shutdown, produce the evidence-only report:

```powershell
python -X utf8 tools/world_observation.py --source private/worlds/restart-20260918-01/world.json --checkpoint-dir worlds/restart-20260918-01/checkpoints --report worlds/restart-20260918-01/observation.json
```

On another computer, first verify the latest manifest hash and world identity. Copy that exact checkpoint into the active local save path only when it cannot overwrite a newer local continuation. Supply the local API configuration and the same verified cumulative ledger/guard separately. Never create a zero ledger to bypass missing billing history, replay paid requests, or seed a replacement world to continue this one.

API keys, loopback authentication, raw account ledgers and backup files remain ignored local files. Public checkpoints reject credential fields rather than silently removing fields and claiming an exact copy. Safe cost receipts and the complete new world are published separately from the visible conversation archive.

The [Chinese report](restart-20260918-01/report.zh-CN.md) translates explicit model reasons and observed actions. It does not claim access to hidden thoughts. Proposed dialogue is distinct from authoritative delivered speech; accepting an action is distinct from finishing its work. [observation.json](restart-20260918-01/observation.json) retains the English evidence for every returned decision, including rejected ones.
