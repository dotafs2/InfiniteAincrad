---
name: git-publish
description: Authorized Git publication and conversation-archive protocol for this repository (dotafs2 identity, archive export, hash verification).
whenToUse: When the user asks to commit, push, or publish to GitHub; or to export/refresh a conversation archive before a push.
---

# Git publication & conversation archive

Follow this repository's exact publication protocol. Do not skip verification steps.

## Identity
- Commit as: `dotafs2 <148285081+dotafs2@users.noreply.github.com>`
- Never use the obsolete `dotafs@work` identity.
- Verify author and committer before committing, and that GitHub resolves them to `dotafs2` after push.

## Before an authorized push
1. Export the current task with `tools/archive_conversation.py` using its exact local session path and task ID.
2. Refresh the existing archive; preserve previous messages, user corrections, and explicit scope.
3. Update the archive's `CONTINUE.md`.
4. Inspect the staged file list (`git status`, `git diff --cached`).

## After push
- Verify the remote commit hash and the archive hashes.
- Report the actual cutoff: future messages and inaccessible tasks are not yet archived. Never claim full history from a summary.

## Hard rules
- Only merge/push `main` when the user authorizes it.
- Never upload raw session logs, internal reasoning, system messages, credentials, or unrelated private records.
- API keys and authentication tokens stay local.
- Preserve published historical commit hashes unless history rewriting is explicitly authorized.
- Keep searches bounded to the narrowest relevant files/directories.
