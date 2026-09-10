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
