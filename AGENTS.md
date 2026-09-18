# Repository handoff and conversation continuity

- Read the current section of `ROADMAP.md`, the latest entries in `HISTORY.md`, and `docs/history/conversations/README.md` before continuing work. Historical checkpoints are not current world state.
- The user requests that authorized Git uploads include visible conversation history, not just a project summary. Export the current task with `tools/archive_conversation.py` using its exact local session path and task ID. Refresh its existing archive; preserve previous messages, user corrections, and explicit scope.
- Before an authorized push, refresh the conversation snapshot, update its `CONTINUE.md`, and inspect the staged file list. After pushing, verify the remote commit and archive hashes. Report the actual cutoff; future messages and inaccessible tasks are not yet archived. Do not claim a full history when only a summary or one task is available.
- Do not upload raw session logs, internal reasoning, system messages, credentials, private world saves, GM memory, or billing ledgers with conversation archives. The repository is public. Use the visible-message export and review its output.
- Keep searches bounded to the narrowest relevant files/directories. Do not enumerate the entire workspace or all local conversations. Use native Git for exact evidence; RTK may summarize read-only status/log/diff.
- Spawn subagents only when the user explicitly requests delegation. Record and clean up owned test/helper processes; do not stop user applications.
- The seq450 world, GM state, and ledgers are currently on another computer. Continue offline work until they are available and the applicable live-run authorization is established. Preserve unknown results/fees and existing unrelated files.
