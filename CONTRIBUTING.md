# Contributing

Read [README.md](README.md), [docs/STATUS.md](docs/STATUS.md) and the current gate in [ROADMAP.md](ROADMAP.md). This project is being prepared for a first playable release; an empty scaffold is not a claim that the migration is complete.

Pick one bounded task with a concrete expected behavior, relevant files, a verification method and a stopping condition. Preserve existing local edits. Changes to world state require evidence for resource conservation, persistence and retries; documentation-only changes do not require an engine test suite.

Good initial contributions are a reproducible startup/export check, a reviewed migration fixture, or one narrowly scoped world-rule port. Do not start extra AI agents, paid runs, a new economic system or a city asset batch without an agreed task.

Record the origin and redistribution terms of any imported code or asset before committing it. No private saves, API credentials, budget ledgers, proprietary character files or unrelated reference screenshots. The repository's public visibility is not a substitute for a selected reuse license; the project-wide license is still to be decided.

Open a pull request with the problem, resulting behavior and relevant validation. A successful test or screenshot proves only what it exercises; identify fixtures, replay, fallback decisions and real model behavior separately.
