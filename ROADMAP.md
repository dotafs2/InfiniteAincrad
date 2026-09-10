# One world, one first playable loop

Updated 2026-09-10. This is the only implementation roadmap in this repository. Creating this repository does not start an unattended development run or paid NPC loop.

## Goal and first release

Build a world that people can enter and affect, where residents retain their lives when AI models change. SAO's first-floor town is the initial setting reference.

First release: one street, three existing active residents, one meaningful player intervention, one real delivery/use event, a subsequent decision informed by that experience, and save/restart continuity. Preserve the experiment's 13 identities during migration; focus presentation on the existing three active residents. A new repository is not permission to reset their world.

The player may offer available material or decline to help. Residents may accept, refuse or wait according to their own information and actual conditions. A refusal is valid autonomous behavior but does not count as successful delivery. Do not rerun paid requests until a scripted outcome appears.

## Formal project direction

Godot is the intended single game runtime. World rules and persistence stay separate from scene presentation; model adapters propose actions, and authoritative rules validate and execute them. Migrate only the smallest required behavior, with explicit source provenance and checks. Keep the old UE project available as evidence and a recovery reference.

This supersedes the experiment's proposed UE-plus-Godot delivery route for this new project. It is a direction to validate, not a claim that the UE life system has been ported. If bounded migration fails, report the exact gap and stop; do not automatically add a second production engine or rewrite the entire simulation.

## Sequential acceptance gates

Active continuous authorization, 2026-09-10: the user requested ongoing iteration without another “continue” prompt after each result. Advance one visible gap at a time, with one scoped Luna worker and supervisor review. The cumulative baseline is `C:/InfiniteAincrad/tmp/continuous-20260910/budget.json`; total development stop is 3,000,000 raw tokens or 2026-09-12 12:14:22 UTC, whichever comes first, with 2,500,000 stopping new implementation. These thresholds span this turn and scheduled continuations, never restart at each heartbeat. The existing hourly heartbeat resumes only within this record. Latest paid-ledger identity/path and counts are in adjacent `progress.json`; the CNY 2 validation grant carries all prior debits and this continuous batch permits at most six new event requests. Original main-world unknown charges remain unresolved. User authorization replaces earlier no-continuation wording only for this bounded ongoing run. If accounting is unknown or a threshold is reached, save progress and pause the heartbeat; do not silently replenish budgets.

Current bounded continuation, 2026-09-10: after the MIT runtime integration, the user requested continued Luna implementation with a supervisor direction review after every round. This round addresses one existing defect: a valid resident `wait` must not be treated as failure or overridden by the 3D presentation. Verify assisted, unassisted and voluntarily deferred outcomes plus cold restore, using isolated fixtures. Keep the 3-million raw-token stop cap across supervisor and one worker, with a 55-minute wall deadline recorded in the private batch record. This does not initialize a paid ledger, reset the maintained world, pass the main-world gates, or authorize an unattended loop.

Every round ends with a short evidence-based direction review in `docs/STATUS.md`: the actual gain toward choice/consequences/continuity/playability, the most important remaining gap, and one next result. More dependencies, tests or code alone are not sufficient. If a proposed next round only repeats a fixture or adds generic infrastructure, revise its scope before dispatching Luna.

Latest scoped authorization, 2026-09-10: the independent capability trial may proceed offline while original-save/ledger verification remains blocked. Its new root and one Luna worker share a maximum of 2,000,000 raw tokens or four hours from 09:16:42 UTC, whichever arrives first. This supersedes the old G0 trial limit for this batch only, does not reset historical paid charges, and cannot satisfy main-world gates. The batch stopped with a runnable partial result; see docs/validation/capability_trial_2026-09-10.md. No automatic continuation is authorized.

At the next explicitly started implementation batch, record a baseline. Limits below are cumulative from that start; time or tokens, whichever comes first. They are stop thresholds, not estimates or guarantees of completion. The new repository does not grant an extra budget beyond the previously selected 48-hour / 3-million-raw-token batch.

| Gate | Required evidence | Cumulative wall time | Cumulative development raw tokens |
| --- | --- | --- | --- |
| G0 | Verify latest original save and carried fee ledger; demonstrate Godot export can launch; document one bounded world-rule migration and its continuity checks | 2 hours | 200,000 |
| G1 | One street displays actual resident movement/actions and authoritative event updates; evidence identifies the real world or explicitly labeled fixture | 8 hours | 800,000 |
| G2 | A validated material offer causes a real consequence; at least one delivery/use completes and its experience enters a subsequent decision in the continuing main world | 24 hours | 2,000,000 |
| G3 | Save/restart and duplicate-command checks pass; the distributable demo runs on an independent Windows environment without development editors; provide a short actual-play recording | 48 hours | 3,000,000 |

Technical fixtures can establish G0/G1 implementation behavior but cannot establish real-world migration or paid resident acceptance. Missing real-world prerequisites must remain explicitly blocked; a fixture never upgrades itself into the main save.

Each gate follows a passing previous gate. Stop on failure or limit, preserve work and evidence, and report the blocker and measured usage. No automatic extension, fallback project, model escalation loop or budget reset. Fix bounded code errors within the current gate; unresolved semantic questions require a decision before dependent work continues.

Count the root and workers together: input plus output; cached input is a subset of input, reasoning a subset of output. Do not add every cumulative log record. No automatic hard token limiter exists yet; establish reliable batch measurement before new development dispatches. At an unknown counter, stop new dispatches. In-flight calls may exceed a threshold and must be reported.

The existing carried Kimi allowance and unresolved charges remain in force privately. A future validation batch adds a maximum of 12 new request attempts within that allowance, failures included, never a requirement to consume them. Ordinary paid thinking retains at least 30 real minutes of cooldown; use existing rules for event-triggered decisions. This scaffold makes zero calls.

## After the first release

1. Switch to a second real model in the same save and continue unfinished commitments; compare actual continuity and cost.
2. Fulfill one genuinely missing resident capability: proposal, review, development, validation, versioned installation into the same save, use, and reuse by another resident.
3. Resolve demonstrated food/labor constraints before expanding to 5–10 active residents, new streets or outside exploration.

Full first-floor geography, VR, multiplayer, complete combat, automated asset factories and city-wide art replacement are outside this first release. Public local demos use explicitly separate world IDs; they are not multiple writers to the maintained world.
