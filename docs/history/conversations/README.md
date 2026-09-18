# Conversation history and continuity

Use [HISTORY.md](../../../HISTORY.md) for project findings and [ROADMAP.md](../../../ROADMAP.md) for the current direction. This directory preserves original visible user/assistant messages, including corrections and authorization context.

| Task | Original conversation | Verification | Continue |
| --- | --- | --- | --- |
| 2026-09-18: local intake, offline fixes, workflow rehearsal and English rollout | [Chronological Markdown](2026-09-18-01a0b299/conversation.md) · [Structured messages](2026-09-18-01a0b299/conversation.json) | [Scope, counts and SHA-256](2026-09-18-01a0b299/manifest.json) | [Current handoff](2026-09-18-01a0b299/CONTINUE.md) |

This snapshot covers one task. It is not every local task, the other computer's original conversation or game GM/NPC memory. Missing messages cannot be reconstructed from summaries. Internal reasoning, system messages, tool output, credentials and private world state are excluded. Original Chinese conversation remains Chinese; metadata and new project documents use English.

## Each delivery

1. Identify the exact local log by task ID; do not scan all tasks or copy a raw log.
2. Export to this task's existing directory. The tool rejects shortened/replaced history, identity mismatch, truncated records, unhandled attachments and suspected credentials.
3. Update CONTINUE.md and HISTORY.md with results, verification, limitations and next steps.
4. Stage only reviewed files. For an authorized upload, commit, push and verify the remote branch SHA plus downloaded archive hashes.
5. Report the actual cutoff. Later messages, including a subsequent final answer, enter the next incremental refresh.

```powershell
python -X utf8 tools/archive_conversation.py --session 'exact task JSONL path' --thread-id 'exact task ID' --out 'docs/history/conversations/task-directory'
```

The manifest hashes let another computer verify the message files. The source-log hash covers bytes read at export time; later additions do not replace earlier messages.
