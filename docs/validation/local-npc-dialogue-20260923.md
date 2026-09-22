# Local NPC dialogue probe

This batch is a local-only inference probe. It consumes the Godot exporter shape `{fixture_only:true,cases:[{case_id,resident_id,context:{target_ids,claim_ids,action_ids},options:[{alias,description,...}],observation:...}]}`, accepts at most three cases, and makes at most one request per case. It calls the pinned loopback Ollama endpoint `http://127.0.0.1:11434/api/chat` with the installed `qwen3:8b`, `stream:false`, `think:false`, and `options.num_predict=384`. The client disables proxy use and redirects and has no configurable remote endpoint.

Each result preserves the model's raw `message.content` string exactly, records model name, HTTP status, available token counts (null when the service omits them), and latency. The probe performs only JSON decoding; a JSON object is marked `json_object_ready_for_godot` and structural receipt authority remains `DialogueReceipt.parse`. Invalid output is recorded without repair or retry. Input invariants reject duplicate case/context IDs and require exact equality between option aliases and `context.action_ids`. The output path is opened exclusively before the first request, so historical evidence cannot be overwritten; partial records are flushed after each case with `status: running`, then finalized as `status: complete`. Results are proposals only: the tool performs zero world writes and has no cloud or LocalJev fallback.

Parent health checks established that Ollama is available locally and LocalJev is currently refused. The exporter context was later supplied for the single bounded run documented below; no additional inference is authorized for this batch.

## Real bounded run

One authorized three-case run was completed against the pinned local Ollama endpoint using `qwen3:8b` around 2026-09-23 02:04 China time. No further inference was performed after this run. Reviewable copies are [exported contexts](local-npc-dialogue-20260923/contexts.json), [raw outputs](local-npc-dialogue-20260923/raw.json), and [Godot results](local-npc-dialogue-20260923/validation.json). They preserve the exact generated content strings; Git may normalize the surrounding JSON file's line endings. Engine logs remain in `private/iteration-20260923/local-dialogue-real/validation/`.

| Case | Raw latency | Input tokens | Output tokens | Godot structural result | Alias → canonical action |
| --- | ---: | ---: | ---: | --- | --- |
| `owner_repair_offer` | 6960.762 ms | 1474 | 111 | accepted | `a14` → `share-skill:shared:smith:wood_repair` |
| `smith_accept_or_wait` | 1364.013 ms | 1499 | 130 | accepted | `a16` → `contract:accept:trade_contract_fixture:offer` |
| `smith_missing_iron` | 1113.388 ms | 1558 | 113 | accepted | `a16` → `contract:reject:trade_contract_fixture:offer` |

Totals were 9,438.163 ms, 4,531 input tokens, and 354 output tokens. The service returned HTTP 200 for all three cases. The raw content was retained without repair, and all three records remained proposals; no proposal was executed and the world was not written.

Structural acceptance does not establish semantic correctness. In the first case, the model selected `a14`, the current canonical skill-sharing action, while its speech asks about repair terms; that wording should be reviewed as a possible intent/action mismatch. In the second case, `a16` is the accept-contract action and the speech offers a choice to accept or decline, so the line does not cleanly express the selected action. In the third case, `a16` is the reject-contract action in that context, while the speech asks for iron and sounds like a request to continue; this is the clearest proposal/voice mismatch. These are human or separate language-review findings, not parser failures.

The run demonstrates local request, raw preservation, and structural receipt acceptance only. It does not prove an autonomous resident lifecycle, sustained behavior, world consequences, or any measured cloud-savings baseline. Cloud savings were not estimated from these three calls.

Run offline mocks from the delivery root:

```powershell
python tools/test_probe_local_npc_dialogue.py
```

Run the bounded local batch once the exporter supplies its fixture:

```powershell
python tools/probe_local_npc_dialogue.py --input <exported-context.json> --output <raw-local-dialogue.json>
```

The 7 passing Python mock tests cover raw preservation and token usage, malformed JSON without retry, unreachable service, external endpoint rejection, the three-case request budget, exporter duplicate/mismatch invariants, and refusal to overwrite an existing output before any request. The 8 passing Godot validator checks cover structural acceptance and rejection, malformed batches, ID matching and raw types. Neither suite measures semantic truth or voice quality.

For an offline recheck without generating anything, run `res://tests/validate_local_dialogue_proposals.gd` with `--contexts=<absolute contexts.json> --input=<absolute raw.json> --out=<new absolute result.json>`. The three linked files above are sufficient. The CLI refuses an existing destination. Re-running `probe_local_npc_dialogue.py` would generate a new sample and is not needed to reproduce structural validation.
