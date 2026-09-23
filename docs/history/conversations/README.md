# Conversation history and continuity

Use [HISTORY.md](../../../HISTORY.md) for project findings and [ROADMAP.md](../../../ROADMAP.md) for the current direction. This directory preserves original visible user/assistant messages, including corrections and authorization context.

| Task | Original conversation | Verification | Continue |
| --- | --- | --- | --- |
| 2026-09-18: local intake, offline fixes, workflow rehearsal, English rollout, rich NPC dossiers, the fresh resident world and reusable capabilities | [Chronological Markdown](2026-09-18-01a0b299/conversation.md) · [Structured messages](2026-09-18-01a0b299/conversation.json) | [Scope, counts and SHA-256](2026-09-18-01a0b299/manifest.json) | [Current handoff](2026-09-18-01a0b299/CONTINUE.md) |
| 2026-09-18 onward: current continuation, H120–H122 live work and publication | [Chronological Markdown](2026-09-18-01a0b0b1/conversation.md) · [Structured messages](2026-09-18-01a0b0b1/conversation.json) | [Scope, counts and SHA-256](2026-09-18-01a0b0b1/manifest.json) | [Current handoff](2026-09-18-01a0b0b1/CONTINUE.md) |
| 2026-09-20: navigation MVP, third-person route preview and video capture | [Chronological Markdown](2026-09-20-01a0bdf9/conversation.md) · [Structured messages](2026-09-20-01a0bdf9/conversation.json) | [Scope, counts and SHA-256](2026-09-20-01a0bdf9/manifest.json) | [Current handoff](2026-09-20-01a0bdf9/CONTINUE.md) |
| 2026-09-20: recover the interrupted publication and verify the remote push | [Chronological Markdown](2026-09-20-01a0be82/conversation.md) · [Structured messages](2026-09-20-01a0be82/conversation.json) | [Scope, counts and SHA-256](2026-09-20-01a0be82/manifest.json) | [Current handoff](2026-09-20-01a0be82/CONTINUE.md) |
| 2026-09-21–22: current task, first local log segment; LocalJev, Starting City art and dialogue plan | [Chronological Markdown](2026-09-22-01a0c41a/conversation.md) · [Structured messages](2026-09-22-01a0c41a/conversation.json) | [Scope, counts and SHA-256](2026-09-22-01a0c41a/manifest.json) | [Segment handoff](2026-09-22-01a0c41a/CONTINUE.md) |
| 2026-09-22–23: same task, second local log segment; overnight NPC trials, cutoff and main publication request | [Chronological Markdown](2026-09-23-01a0c41a-continuation/conversation.md) · [Structured messages](2026-09-23-01a0c41a-continuation/conversation.json) | [Scope, counts and SHA-256](2026-09-23-01a0c41a-continuation/manifest.json) | [Segment handoff](2026-09-23-01a0c41a-continuation/CONTINUE.md) |

Each row covers the named task or local log segment. The two `01a0c41a` rows are successive segments of one task. These archives are not every local task, the other computer's original conversation or game GM/NPC memory. Missing messages cannot be reconstructed from summaries. Internal reasoning, system messages, tool output, credentials and private world state are excluded from the conversation archive. User-authorized new-world checkpoints and safe cost summaries are published separately under worlds/. Original Chinese conversation remains Chinese; metadata and new project documents use English.

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
