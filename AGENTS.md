# Project instructions

Read this file, README.md and docs/STATUS.md first; then only the relevant gate in ROADMAP.md and the files needed for the task. User instructions take precedence.

- One goal: an enterable, consequential, persistent AI world whose residents survive model changes. First deliver one street, three existing active residents, one player intervention and save/resume continuity.
- This is the formal project's single-engine Godot direction. The old UE repository is a reference and recovery source; no wholesale copy, parallel engine rewrite or automatic world reset.
- Do not invent an NPC's success, knowledge, capabilities or resources. The world validates actions; models propose choices. Label fixtures, replay, local fallback and real model decisions accurately.
- Preserve private source saves and identity/history. Write migrations to separate outputs and report unsupported data. Public snapshots are not restore saves. Only one writer owns a maintained world.
- Search exact files or bounded modules first with rg; exclude binaries, cache, generated output and vendor content. Never scan the entire workspace by default. Check load before an unavoidable broad search.
- Spawn subagents only when the user explicitly requests delegation. Default to one bounded worker, at most two in parallel; do not copy the entire conversation or allow recursive delegation. Close workers when finished.
- Scope each batch to one visible result and ROADMAP.md limits. Record root and worker usage increments, not repeated cumulative counts. No automatic hard token limiter exists; unknown measurement stops new dispatches. Failure does not authorize extra time, budget or a replacement project.
- Paid model runs require their authorized scope, original carried ledger, cooldowns and a current stop condition. This repository's creation does not start such a run or reset an allowance. Never commit API keys, private configs or fee databases.
- Record owned long-lived process IDs. Clean up only processes started by the task; do not leave engines, model loops, helpers or workers running.
- Validate consequential world behavior and persistence; do not repeat engine checks for low-risk documentation edits. Report limits honestly.
- After every Luna implementation, the supervisor must assess direction using actual evidence: does this improve resident choice, visible consequences, persistence/model replacement, or delivery of the first playable street? Record one supported gain, the remaining goal gap and one next step in docs/STATUS.md. A library, passing fixture or more code alone does not establish autonomous life. Stop adding features when a round only grows infrastructure or repeats a proven demo.
- Keep Luna engineering assignments small enough to produce a first patch after at most two bounded read batches. If that is not possible, require a concrete missing interface/blocker and rescope before spending more on analysis. Do not treat hitting a token checkpoint without a patch as useful implementation progress.
- Keep a single roadmap and short status entry. Do not accumulate competing plans, expired night-run instructions or speculative platform work.
- Before publishing a migrated asset, verify redistribution and dependencies. Never import the source project's restricted character files or private state. Public visibility does not select a license.
